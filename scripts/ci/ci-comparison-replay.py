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
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from urllib.parse import urlsplit, urlunsplit

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
PACKAGE = '.planning/execution/255-replay/input-package.tar.gz'
PACKAGE_MANIFEST = '.planning/execution/255-replay/INPUTS.json'
EVIDENCE_ROOT = '.planning/execution/255-replay/distributed'
EVIDENCE_PACKAGE = EVIDENCE_ROOT + '/input-package.tar.gz'
EVIDENCE_MANIFEST = EVIDENCE_ROOT + '/INPUTS.json'
DISTRIBUTION_FREEZE = '.planning/execution/255-replay/DISTRIBUTION-FREEZE.json'


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
                'input_hashes_before': {name: digest(raw) for name, raw in sorted(data.items())},
                'input_hashes_after': {name: digest(raw) for name, raw in sorted(data.items())},
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


def pack_inputs(manifest, data, output):
    if manifest['status'] != 'ready':
        raise ValueError('preflight_blocked:' + json.dumps(manifest['missing']))
    # Validate independently before opening the output.
    with tempfile.TemporaryDirectory() as tmp:
        materialize_inputs(manifest, data, Path(tmp))
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output, 'w:gz') as archive:
        for name, raw in [('INPUTS.json', (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode()), *sorted(data.items())]:
            member = tarfile.TarInfo(name)
            member.size = len(raw)
            member.mode = 0o600
            archive.addfile(member, io.BytesIO(raw))
    write(output.parent / 'INPUTS.json', manifest)


def verify_package(package):
    data, total = {}, 0
    with tarfile.open(package, 'r:gz') as archive:
        for member in archive:
            name = safe_path(member.name)
            if name in data or not member.isfile() or member.size < 0:
                raise ValueError('unsafe_or_duplicate_archive_member:' + name)
            total += member.size
            if total > MAX_BYTES or len(data) >= 4096:
                raise ValueError('package_size_limit')
            data[name] = archive.extractfile(member).read()
    if 'INPUTS.json' not in data:
        raise ValueError('missing_input:INPUTS.json')
    manifest = json.loads(data.pop('INPUTS.json'))
    with tempfile.TemporaryDirectory() as tmp:
        materialize_inputs(manifest, data, Path(tmp))
    return manifest, data


def distribution_ref(package_sha256):
    if not re.fullmatch(r'[0-9a-f]{64}', package_sha256):
        raise ValueError('invalid_package_sha256')
    return 'refs/heads/evidence/phase255-replay-' + package_sha256[:20]


def safe_remote_url(root, remote):
    raw = subprocess.run(['git', 'remote', 'get-url', remote], cwd=root,
                         capture_output=True, text=True, check=False)
    if raw.returncode or not raw.stdout.strip():
        raise ValueError('remote_unavailable:' + remote)
    value = raw.stdout.strip()
    if value.startswith('https://') or value.startswith('http://'):
        parsed = urlsplit(value)
        if parsed.username or parsed.password:
            raise ValueError('credential_bearing_remote_url')
        return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, '', ''))
    if re.match(r'^[^/@:]+@[^/:]+:', value):
        return value
    if value.startswith('ssh://'):
        parsed = urlsplit(value)
        if parsed.username or parsed.password:
            raise ValueError('credential_bearing_remote_url')
        return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, '', ''))
    raise ValueError('unsupported_remote_url')


def package_secret_findings(data):
    """Reject credential-like package content while allowing the known fake PAT fixture."""
    patterns = [
        re.compile(rb'gh[pousr]_[A-Za-z0-9_]{20,}'),
        re.compile(rb'github_pat_[A-Za-z0-9_]{20,}'),
        re.compile(rb'AKIA[0-9A-Z]{16}'),
        re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
        re.compile(rb'(?i)bearer\s+[A-Za-z0-9._~-]{24,}'),
    ]
    findings = []
    for path, raw in data.items():
        for pattern in patterns:
            for match in pattern.finditer(raw):
                value = match.group()
                # Historical API fixtures contain this public, intentionally fake sample.
                if value == b'ghp_abcdefghijklmnopqrstuvwxyz01234567890':
                    continue
                findings.append(path)
                break
    return sorted(set(findings))


def git_command(root, *args, env=None, timeout=120):
    result = subprocess.run(['git', *args], cwd=root, env=env, capture_output=True,
                            text=True, timeout=timeout)
    if result.returncode:
        raise ValueError('git_command_failed:' + ' '.join(args) + ':' + result.stderr[-2000:])
    return result.stdout.strip()


def remote_ref_oid(root, remote, ref):
    result = subprocess.run(['git', 'ls-remote', '--refs', remote, ref], cwd=root,
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError('remote_ref_lookup_failed:' + result.stderr[-2000:])
    rows = [line.split() for line in result.stdout.splitlines() if line.strip()]
    if not rows:
        return None
    if len(rows) != 1 or rows[0][1] != ref:
        raise ValueError('remote_ref_lookup_ambiguous')
    return rows[0][0]


def clean_git_env():
    env = os.environ.copy()
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY',
                 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_INDEX_FILE', 'GIT_PREFIX',
                 'GIT_CONFIG', 'GIT_CONFIG_COUNT'):
        env.pop(name, None)
    return env


def create_evidence_commit(root, remote_ref, manifest_bytes, package_bytes):
    helper_source = git_command(root, 'rev-parse', 'HEAD')
    if git_command(root, 'rev-parse', 'HEAD:scripts/ci/ci-comparison-replay.py') == '':
        raise ValueError('helper_source_missing')
    with tempfile.TemporaryDirectory(prefix='sigra255-evidence-worktree-') as temp:
        worktree = Path(temp) / 'checkout'
        git_command(root, 'worktree', 'add', '--detach', str(worktree), helper_source)
        try:
            package_path = worktree / EVIDENCE_PACKAGE
            manifest_path = worktree / EVIDENCE_MANIFEST
            package_path.parent.mkdir(parents=True, exist_ok=True)
            package_path.write_bytes(package_bytes)
            manifest_path.write_bytes(manifest_bytes)
            git_command(worktree, 'add', '--', EVIDENCE_PACKAGE, EVIDENCE_MANIFEST)
            git_command(worktree, 'commit', '-m', 'chore(255-07): preserve replay package for independent retrieval')
            commit = git_command(worktree, 'rev-parse', 'HEAD')
            parent = git_command(worktree, 'rev-parse', commit + '^')
            if parent != helper_source:
                raise ValueError('evidence_commit_parent_mismatch')
            if git_command(root, 'cat-file', '-e', commit + '^{commit}') != '':
                raise ValueError('evidence_commit_unavailable')
            for path, expected in ((EVIDENCE_PACKAGE, package_bytes),
                                   (EVIDENCE_MANIFEST, manifest_bytes)):
                actual = subprocess.run(['git', 'show', commit + ':' + path], cwd=root,
                                        capture_output=True, check=False)
                if actual.returncode or actual.stdout != expected:
                    raise ValueError('evidence_object_readback_mismatch:' + path)
            # Pin the exact local object under a scoped ref before remote mutation.
            local_ref = remote_ref.replace('refs/heads/', 'refs/evidence/', 1)
            create = subprocess.run(['git', 'update-ref', local_ref, commit, '0' * 40],
                                    cwd=root, capture_output=True, text=True, check=False)
            if create.returncode:
                existing = git_command(root, 'rev-parse', '--verify', local_ref)
                if existing != commit:
                    raise ValueError('local_evidence_ref_exists_with_different_commit')
            if git_command(root, 'rev-parse', '--verify', local_ref) != commit:
                raise ValueError('local_evidence_ref_readback_mismatch')
            return helper_source, commit, local_ref
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(worktree)], cwd=root,
                           capture_output=True, text=True, check=False)


def isolated_fetch_and_replay(root, remote_url, remote_ref, expected_commit, package_sha256):
    env = clean_git_env()
    with tempfile.TemporaryDirectory(prefix='sigra255-independent-retrieval-') as temp:
        checkout = Path(temp) / 'fresh-checkout'
        checkout.mkdir()
        git_command(checkout, 'init', '--quiet', '--initial-branch=main', env=env)
        git_command(checkout, 'fetch', '--no-tags', remote_url, remote_ref, env=env, timeout=180)
        fetched = git_command(checkout, 'rev-parse', 'FETCH_HEAD^{commit}', env=env)
        if fetched != expected_commit:
            raise ValueError('retrieved_commit_mismatch')
        git_command(checkout, 'checkout', '--quiet', '--detach', fetched, env=env)
        if (checkout / '.git/objects/info/alternates').exists():
            raise ValueError('fresh_checkout_has_alternates')
        package_path = checkout / EVIDENCE_PACKAGE
        manifest_path = checkout / EVIDENCE_MANIFEST
        package_bytes = package_path.read_bytes()
        if digest(package_bytes) != package_sha256:
            raise ValueError('retrieved_package_sha256_mismatch')
        manifest = json.loads(manifest_path.read_bytes())
        if manifest.get('schema_version') != SCHEMA or manifest.get('status') != 'ready':
            raise ValueError('retrieved_manifest_invalid')
        packaged_manifest, data = verify_package(package_path)
        if packaged_manifest != manifest:
            raise ValueError('retrieved_manifest_package_mismatch')
        if manifest.get('input_hashes_before') != manifest.get('input_hashes_after'):
            raise ValueError('input_hashes_changed_in_manifest')
        for name, expected in manifest['input_hashes_before'].items():
            if name not in data or digest(data[name]) != expected:
                raise ValueError('retrieved_input_hash_mismatch:' + name)
        source = checkout / 'packaged-replay'
        source.mkdir()
        materialize_inputs(manifest, data, source)
        deny = Path(temp) / 'deny-network'
        deny.mkdir()
        network_log = Path(temp) / 'network-attempts'
        for name in ('gh', 'curl', 'wget', 'ssh', 'git', 'npm', 'npx'):
            stub = deny / name
            stub.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$SIGRA_REPLAY_NETWORK_LOG"\nexit 97\n')
            stub.chmod(0o700)
        env = {**env, 'PATH': str(deny) + os.pathsep + os.environ['PATH'],
               'PYTHONDONTWRITEBYTECODE': '1', 'SIGRA_REPLAY_NETWORK_LOG': str(network_log)}
        output = Path(temp) / 'replay-result.json'
        command = ['python3', '-B', str(source / 'scripts/ci/ci-comparison-replay.py'),
                   'replay', '--package', str(package_path), '--output', str(output)]
        result = subprocess.run(command, cwd=source, env=env, capture_output=True, text=True,
                                timeout=240)
        if result.returncode:
            raise ValueError('offline_replay_failed:' + result.stderr[-4000:])
        if network_log.exists():
            raise ValueError('offline_replay_attempted_network_command:' + network_log.read_text())
        replayed = json.loads(output.read_text())
        expected = json.loads(data[f'{MEASUREMENT}/EVALUATION-COSTS.json'])
        if replayed != expected:
            raise ValueError('offline_replay_result_mismatch')
        return {'status': 'passed', 'checkout': 'independent fresh repository fetched from configured remote',
                'fetched_commit': fetched, 'package_sha256': package_sha256,
                'package_size': len(package_bytes), 'member_count': len(data),
                'network_command_attempts': 0, 'input_hashes_unchanged': True,
                'performance_verdict': replayed['performance_verdict'],
                'comparable_successful_pairs': replayed['metrics']['comparable_successful_pairs'],
                'baseline_runner_seconds': replayed['metrics']['baseline_runner_seconds'],
                'candidate_runner_seconds': replayed['metrics']['candidate_runner_seconds'],
                'median_seconds': replayed['metrics']['baseline_median_seconds'],
                'p95_seconds': replayed['metrics']['baseline_p95_seconds']}


def distribute_inputs(root, remote, output):
    root = Path(root).resolve()
    package = root / PACKAGE
    package_bytes = package.read_bytes()
    package_sha = digest(package_bytes)
    manifest, data = verify_package(package)
    freeze = load(root / DISTRIBUTION_FREEZE)
    expected_limits = {'successful_create_only_pushes': 1, 'transient_transport_retries': 1,
                       'fresh_checkout_retrieval_attempts': 2, 'workflow_dispatches': 0}
    if (freeze.get('status') != 'frozen' or freeze.get('package_sha256') != package_sha
            or freeze.get('charged_limits') != expected_limits):
        raise ValueError('distribution_budget_not_frozen_for_package')
    if manifest != load(root / PACKAGE_MANIFEST):
        raise ValueError('local_manifest_package_mismatch')
    if package_secret_findings(data):
        raise ValueError('package_secret_scan_failed:' + ','.join(package_secret_findings(data)))
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode()
    if manifest_bytes != (root / PACKAGE_MANIFEST).read_bytes():
        raise ValueError('local_manifest_bytes_mismatch')
    remote_url = safe_remote_url(root, remote)
    ref = distribution_ref(package_sha)
    if remote_ref_oid(root, remote, ref) is not None:
        raise ValueError('remote_evidence_ref_already_exists')
    helper_source, commit, local_ref = create_evidence_commit(root, ref, manifest_bytes, package_bytes)
    if remote_ref_oid(root, remote, ref) is not None:
        raise ValueError('remote_evidence_ref_created_during_preflight')
    push_command = ['git', 'push', '--porcelain', '--force-with-lease=' + ref + ':',
                    remote, commit + ':' + ref]
    push_env = clean_git_env()
    push_retry_used = False
    push = subprocess.run(push_command, cwd=root, env=push_env, capture_output=True,
                          text=True, timeout=180)
    reconciled = None
    if push.returncode:
        for attempt in range(3):
            reconciled = remote_ref_oid(root, remote, ref)
            if reconciled is not None:
                break
            if attempt < 2:
                time.sleep(5)
        if reconciled != commit:
            transient = any(term in (push.stderr + push.stdout).lower() for term in
                             ('timed out', 'timeout', 'connection reset', 'remote end hung up',
                              'early eof', 'could not read from remote', 'connection closed'))
            if not transient or reconciled is not None:
                raise ValueError('evidence_push_failed:' + push.stderr[-2000:])
            push_retry_used = True
            retry = subprocess.run(push_command, cwd=root, env=push_env, capture_output=True,
                                   text=True, timeout=180)
            reconciled = remote_ref_oid(root, remote, ref)
            if retry.returncode and reconciled != commit:
                raise ValueError('evidence_push_retry_failed:' + retry.stderr[-2000:])
    remote_commit = remote_ref_oid(root, remote, ref)
    if remote_commit != commit:
        raise ValueError('remote_evidence_commit_readback_mismatch')
    replay = isolated_fetch_and_replay(root, remote_url, ref, commit, package_sha)
    record = {'schema_version': 'sigra.phase255.distribution/v1', 'status': 'distributed_and_replayed',
              'remote_name': remote, 'remote_url': remote_url, 'remote_ref': ref,
              'evidence_commit': commit, 'evidence_parent': git_command(root, 'rev-parse', commit + '^'),
              'helper_source': helper_source, 'package_path': PACKAGE,
              'evidence_package_path': EVIDENCE_PACKAGE,
              'evidence_manifest_path': EVIDENCE_MANIFEST, 'package_sha256': package_sha,
              'package_size': len(package_bytes), 'member_count': len(data),
              'package_manifest_sha256': digest(manifest_bytes),
              'budget': {'freeze': DISTRIBUTION_FREEZE, 'charged_limits': expected_limits,
                         'used': {'successful_create_only_pushes': 1,
                                  'transient_transport_retries': int(push_retry_used),
                                  'fresh_checkout_retrieval_attempts': 1,
                                  'workflow_dispatches': 0}},
              'push_result': 'created_once', 'push_retries': 0, 'remote_readback_commit': remote_commit,
              'retrieval_result': {'status': 'passed', 'attempts': 1, 'checkout_commit': replay['fetched_commit']},
              'offline_replay_result': replay}
    write(output, record)
    return record


def verify_distribution(root, record_path):
    root = Path(root).resolve()
    record_path = Path(record_path)
    record = load(record_path)
    if record.get('schema_version') != 'sigra.phase255.distribution/v1':
        raise ValueError('distribution_record_invalid')
    expected_ref = distribution_ref(record.get('package_sha256', ''))
    if record.get('remote_ref') != expected_ref:
        raise ValueError('distribution_ref_package_mismatch')
    if record.get('status') != 'distributed_and_replayed':
        raise ValueError('distribution_not_complete')
    ref_oid = remote_ref_oid(root, record['remote_name'], expected_ref)
    if ref_oid != record.get('evidence_commit'):
        raise ValueError('remote_evidence_commit_changed')
    replay = isolated_fetch_and_replay(root, record['remote_url'], expected_ref,
                                       record['evidence_commit'], record['package_sha256'])
    record['independent_verification'] = {'status': 'passed', 'attempts': 1,
                                           'checkout_commit': replay['fetched_commit'],
                                           'replay': replay}
    record['retrieval_result']['total_attempts'] = 2
    record['status'] = 'verified'
    write(record_path, record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['preflight', 'pack', 'replay']:
        p = sub.add_parser(name)
        p.add_argument('--root', type=Path, default=ROOT)
        p.add_argument('--output', type=Path, required=True)
        if name == 'replay':
            source = p.add_mutually_exclusive_group(required=True)
            source.add_argument('--from-evidence', action='store_true')
            source.add_argument('--package', type=Path)
    distribute_parser = sub.add_parser('distribute')
    distribute_parser.add_argument('--remote', required=True)
    distribute_parser.add_argument('--output', type=Path, required=True)
    verify_parser = sub.add_parser('verify-distribution')
    verify_parser.add_argument('--record', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'distribute':
            record = distribute_inputs(ROOT, args.remote, args.output)
            print(json.dumps(record, indent=2, sort_keys=True))
            return 0
        if args.command == 'verify-distribution':
            record = verify_distribution(ROOT, args.record)
            print(json.dumps(record, indent=2, sort_keys=True))
            return 0
        if args.command == 'replay' and args.package:
            manifest, data = verify_package(args.package)
        else:
            manifest, data = preflight_sources(args.root)
        if args.output.resolve() in {(args.root / row['path']).resolve() for row in manifest['members']}:
            raise ValueError('output_would_replace_original_input:' + str(args.output))
        if args.command == 'preflight':
            write(args.output, manifest)
            return int(manifest['status'] != 'ready')
        if manifest['status'] != 'ready':
            raise ValueError('preflight_blocked:' + json.dumps(manifest['missing']))
        if args.command == 'pack':
            pack_inputs(manifest, data, args.output)
        else:
            write(args.output, replay_comparison(manifest, data))
        return 0
    except (ValueError, OSError, KeyError, tarfile.TarError, subprocess.TimeoutExpired) as error:
        print(json.dumps({'status': 'blocked', 'diagnostic': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
