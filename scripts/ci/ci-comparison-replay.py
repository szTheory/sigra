#!/usr/bin/env python3
"""Calculate the closed Phase 254 comparison from verified, immutable inputs.

Requires Python 3.10+, Bash, Node, jq and Git for evidence materialization.
Replay never invokes the collection driver. Package replay needs no Git objects.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
ANALYSIS = 'd5b7300c809ce7cd474e87aa55fda278b3a09cbc'
CLOSEOUT = '9e944b90b0f7914246017ac4c834470988eb2673'
MEASUREMENT = '.planning/execution/254-environment-recovery/MEASUREMENT'
BASELINE = '.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz'
TIMING = '.planning/phases/252-measure-current-ci/252-03-EXUNIT-TIMING.json'
MAP = '.planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json'
RECEIPTS = {'before': '1c1cc0f786e52cacddb8e69a07a5855c0b74045c',
            'after': '5df0b52e9773364de9fa1aa8a37b831133c56600'}
SOURCES = ['fb2d3faa4b25918d14415dd00a51545f0a9c6683', 'ebb1d3ef0207d64f5f22f409032cf6125abab941']
TOOLS = ['ci-run-metrics.sh', 'ci_metrics_security.py', 'ci-browser-records.mjs',
         'ci-playwright-report.mjs', 'ci-hosted-gate-verify.py', 'ci-hosted-transport.py',
         'exunit_timing_contract.py']
SCHEMA = 'sigra.ci-comparison-inputs/v1'
MAX_BYTES = 512 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(Path(path).read_bytes())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def safe_path(name):
    path = PurePosixPath(name)
    if (not isinstance(name, str) or not name or '\\' in name or '\x00' in name
            or path.is_absolute() or any(p in ('', '.', '..') for p in name.split('/'))
            or path.as_posix() != name):
        raise ValueError('unsafe_input_path:' + str(name))
    return name


def git(root, *args):
    result = subprocess.run(['git', *args], cwd=root, capture_output=True)
    if result.returncode:
        raise ValueError('unavailable_git_object:' + ' '.join(args))
    return result.stdout


def preflight_sources(root):
    """Resolve every receipt and dependency before any calculation or extraction."""
    root = Path(root).resolve()
    members, data, missing = {}, {}, []

    def add(commit, name, expected=None):
        safe_path(name)
        try:
            raw = git(root, 'show', commit + ':' + name)
            sha = digest(raw)
            if expected and sha != expected:
                raise ValueError('input_sha256_mismatch:' + name)
            if name in data and data[name] != raw:
                raise ValueError('input_collision:' + name)
            data[name] = raw
            members[name] = {'path': name, 'source_commit': commit,
                             'source_blob': git(root, 'rev-parse', commit + ':' + name).decode().strip(),
                             'size': len(raw), 'sha256': sha}
        except ValueError as error:
            missing.append({'path': name, 'source_commit': commit, 'reason': str(error)})

    for sha in [*SOURCES, ANALYSIS, *RECEIPTS.values()]:
        try:
            git(root, 'cat-file', '-e', sha + '^{commit}')
        except ValueError as error:
            missing.append({'commit': sha, 'reason': str(error)})
    for name in ['CONTRACT.json', 'REGISTRATIONS.json', 'EVALUATION-COSTS.json', 'REPLAYED-COSTS.json']:
        add(CLOSEOUT if name == 'EVALUATION-COSTS.json' else ANALYSIS, MEASUREMENT + '/' + name)
    for name in [BASELINE, TIMING, MAP, *['scripts/ci/' + tool for tool in TOOLS]]:
        add(ANALYSIS, name)
    counts = {}
    for role, commit in RECEIPTS.items():
        name = f'{MEASUREMENT}/requests/pair-01/CAPTURE-{role}.json'
        add(ANALYSIS, name)
        if name not in data:
            continue
        receipt = json.loads(data[name])
        if receipt['commit'] != commit:
            missing.append({'path': name, 'reason': 'receipt_commit_mismatch'})
        counts[role] = len(receipt['files'])
        for path, expected in receipt['files'].items():
            add(commit, path, expected)
    runtimes = {}
    for name in ['python3', 'bash', 'node', 'jq', 'git']:
        binary = shutil.which(name)
        if not binary:
            missing.append({'runtime': name, 'reason': 'not_on_PATH'})
        else:
            p = subprocess.run([binary, '--version'], capture_output=True, text=True)
            runtimes[name] = {'path': binary, 'version': (p.stdout or p.stderr).splitlines()[0]}
    manifest = {'schema_version': SCHEMA, 'status': 'blocked' if missing else 'ready',
                'source_identity': {'commit': git(root, 'rev-parse', 'HEAD').decode().strip(),
                                    'branch': git(root, 'branch', '--show-current').decode().strip(),
                                    'status': git(root, 'status', '--porcelain=v1').decode()},
                'analysis_identity': ANALYSIS, 'measured_sources': SOURCES,
                'members': sorted(members.values(), key=lambda row: row['path']),
                'runtime_requirements': runtimes, 'receipt_counts': counts, 'missing': missing,
                'producer_identity': 'Synthetic commits need no local objects; captured producer payloads are receipt-verified.'}
    return manifest, data


def materialize_inputs(manifest, data, root):
    if manifest.get('status') != 'ready' or manifest.get('schema_version') != SCHEMA:
        raise ValueError('input_manifest_not_ready')
    listed = set()
    for row in manifest['members']:
        name = safe_path(row['path'])
        if name in listed:
            raise ValueError('duplicate_input:' + name)
        listed.add(name)
        raw = data.get(name)
        if raw is None:
            raise ValueError('missing_input:' + name)
        if len(raw) != row['size'] or digest(raw) != row['sha256']:
            raise ValueError('input_sha256_mismatch:' + name)
    if listed != set(data):
        raise ValueError('unlisted_package_inputs')
    # No writes until the complete manifest has been validated.
    for name, raw in data.items():
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)


def replay_comparison(manifest, data):
    with tempfile.TemporaryDirectory(prefix='sigra-comparison-replay-') as tmp:
        root = Path(tmp).resolve()
        materialize_inputs(manifest, data, root)
        hashes = {name: digest(raw) for name, raw in data.items()}
        deny = root / 'deny-network'
        deny.mkdir()
        log = deny / 'attempts'
        for name in ['gh', 'curl', 'wget', 'ssh', 'git', 'npm', 'npx']:
            stub = deny / name
            stub.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$SIGRA_REPLAY_NETWORK_LOG"\nexit 97\n')
            stub.chmod(0o700)
        env = {**os.environ, 'PATH': str(deny) + os.pathsep + os.environ['PATH'],
               'PYTHONDONTWRITEBYTECODE': '1', 'SIGRA_REPLAY_NETWORK_LOG': str(log)}
        command = ['bash', str(root / 'scripts/ci/ci-run-metrics.sh'), '--evaluate-comparison',
                   '--contract', str(root / MEASUREMENT / 'CONTRACT.json'),
                   '--registrations', str(root / MEASUREMENT / 'REGISTRATIONS.json'),
                   '--before-bundle', str(root / MEASUREMENT / 'requests/pair-01/raw-before'),
                   '--after-bundle', str(root / MEASUREMENT / 'requests/pair-01/raw-after'),
                   '--baseline-source-bundle', str(root / BASELINE), '--format', 'json']
        result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=180)
        if log.exists():
            raise ValueError('replay_network_command_attempted:' + log.read_text())
        if result.returncode:
            raise ValueError('calculation_failed:' + result.stderr[-4000:])
        changed = [name for name, expected in hashes.items() if digest((root / name).read_bytes()) != expected]
        if changed:
            raise ValueError('replay_changed_inputs:' + ','.join(changed))
        return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['preflight', 'replay']:
        p = sub.add_parser(name)
        p.add_argument('--root', type=Path, default=ROOT)
        p.add_argument('--output', type=Path, required=True)
        if name == 'replay':
            source = p.add_mutually_exclusive_group(required=True)
            source.add_argument('--from-evidence', action='store_true')
            source.add_argument('--package', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        manifest, data = preflight_sources(args.root)
        if args.command == 'preflight':
            write(args.output, manifest)
            return int(manifest['status'] != 'ready')
        if manifest['status'] != 'ready':
            raise ValueError('preflight_blocked:' + json.dumps(manifest['missing']))
        write(args.output, replay_comparison(manifest, data))
        return 0
    except (ValueError, OSError, KeyError, tarfile.TarError, subprocess.TimeoutExpired) as error:
        print(json.dumps({'status': 'blocked', 'diagnostic': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
