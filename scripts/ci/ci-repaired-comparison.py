#!/usr/bin/env python3
"""Local source/report feasibility for the separately authorized repaired comparison.

No operation in this module calls GitHub, pushes refs, or creates acceptance samples.
An incomplete local observation deliberately cannot satisfy the hosted evaluator.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OWNERS = ('library_tests_shard', 'admin_behavior', 'admin_checkpoints',
          'design_gallery', 'non_admin_smoke', 'demo_showcase')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x') as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write('\n')


def run(argv, *, cwd=ROOT, env=None, timeout=30):
    return subprocess.run(argv, cwd=cwd, env=env, capture_output=True, text=True,
                          timeout=timeout, check=True).stdout.strip()


def git(*args, repository=ROOT):
    return run(['git', '-c', 'core.hooksPath=/dev/null', *args], cwd=repository)


def validate_local_report(path, expected_digest, identity, native_exit):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or digest(path) != expected_digest:
        raise ValueError('native_report_digest_or_path_invalid')
    value = json.loads(path.read_text())
    if any(key in value for key in ('run_id', 'run_attempt', 'performance_verdict')):
        raise ValueError('invented_hosted_result_in_local_report')
    if native_exit != 0 or value.get('complete') is not True:
        raise ValueError('native_report_incomplete_or_failed')
    if type(value.get('seed')) is not int:
        raise ValueError('native_report_seed_missing')
    tests = value.get('tests')
    if not tests or not isinstance(tests, list):
        raise ValueError('native_report_test_ids_missing')
    identities = [row.get('test_id') for row in tests]
    if (any(not isinstance(item, str) or not item for item in identities)
            or len(set(identities)) != len(identities)
            or any(row.get('result') != 'passed' for row in tests)
            or value.get('failed_count') != 0 or value.get('failed_test_ids') != []):
        raise ValueError('native_report_test_status_invalid')
    if not re.fullmatch(r'[0-9a-f]{40}', identity.get('source_sha', '')):
        raise ValueError('source_identity_missing')
    return {**identity, 'local_only': True, 'acceptance_samples': 0,
            'report_sha256': expected_digest, 'seed': value['seed'],
            'test_ids': identities, 'test_statuses': [row['result'] for row in tests],
            'native_exit_code': native_exit}


def evaluate_local_observation(repository, output, observation):
    """Use the production evaluator, retaining zero fabricated GitHub families.

    The validated native receipt is retained in its contract. The old evaluator
    cannot accept local timing as a PR sample: its exact missing-hosted-input
    diagnostics are the result of this tracer, not a second calculation engine.
    """
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for label in ('before', 'after'):
        bundle = output / label
        bundle.mkdir()
        write_new(bundle / 'request-ledger.json', {'requests': []})
        write_new(bundle / 'selection-ledger.json', {'populations': []})
        write_new(bundle / 'manifest.json', {
            'schema_version': 'sigra.ci-run-metrics/snapshot-v1',
            'repository': 'szTheory/sigra', 'workflow': 'ci.yml',
            'status': 'incomplete', 'request_count': 0,
            'stop_reason': 'local_only_no_hosted_families',
            'source_sha256': {
                'request_ledger': digest(bundle / 'request-ledger.json'),
                'selection_ledger': digest(bundle / 'selection-ledger.json')}})
    write_new(output / 'contract.json', {
        'status': 'local_only', 'pair_count': 20, 'primary_family_count': 40,
        'window_duration_hours': 48, 'local_observation': observation})
    argv = ['bash', str(repository / 'scripts/ci/ci-run-metrics.sh'),
            '--evaluate-comparison', '--contract', str(output / 'contract.json'),
            '--before-bundle', str(output / 'before'), '--after-bundle', str(output / 'after'),
            '--format', 'json']
    result = json.loads(run(argv, cwd=repository, env=sanitized_environment(), timeout=60))
    if result.get('status') != 'insufficient_data' or result.get('performance_verdict') != 'insufficient_data':
        raise ValueError('local_observation_must_not_establish_hosted_performance')
    write_new(output / 'result.json', result)
    return result


def sanitized_environment():
    # Code execution receives no orchestration authority. Never print env values.
    env = {key: value for key, value in os.environ.items()
           if not any(part in key.upper() for part in ('TOKEN', 'SECRET', 'CREDENTIAL', 'ACCESS_KEY'))
           and key not in ('GIT_ASKPASS', 'SSH_AUTH_SOCK', 'NODE_OPTIONS', 'BASH_ENV', 'ENV', 'PYTHONPATH')}
    env.update({'MIX_ENV': 'test', 'HEX_OFFLINE': '1', 'GIT_TERMINAL_PROMPT': '0',
                'PYTHONDONTWRITEBYTECODE': '1'})
    return env


def local_tracer(source, output, repository=ROOT):
    output = Path(output).resolve()
    if output.exists():
        raise ValueError('output_exists_preserve_prior_bytes_before_refresh')
    receipt = {'schema_version': 'sigra.ci-repaired-local-tracer/v1',
               'captured_at': dt.datetime.now(dt.timezone.utc).isoformat(),
               'status': 'blocked', 'local_only': True, 'acceptance_samples': 0,
               'performance_verdict': 'insufficient_data', 'blockers': [],
               'source_requested': source, 'remote_requests': 0, 'remote_mutations': 0}
    started = time.monotonic()
    try:
        try:
            sha = git('rev-parse', '--verify', '--end-of-options', source + '^{commit}', repository=repository)
        except subprocess.CalledProcessError:
            raise ValueError('source_unresolved') from None
        receipt['source_sha'] = sha
        receipt['source_tree'] = git('rev-parse', sha + '^{tree}', repository=repository)
        receipt['driver_sha256'] = digest(__file__)
        data_root = output.parent / (output.stem + '-data-' + str(time.time_ns()))
        data_root.mkdir(parents=True)
        receipt['data_root'] = str(data_root.relative_to(output.parent))
        for tool in ('mix', 'elixir', 'psql', 'node', 'jq'):
            if not shutil.which(tool):
                raise ValueError('tool_missing:' + tool)
        with tempfile.TemporaryDirectory(prefix='sigra-local-tracer-') as temp:
            checkout = Path(temp) / 'source'
            run(['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--shared', '--no-checkout',
                 '--', str(repository), str(checkout)], timeout=60)
            git('checkout', '--detach', sha, repository=checkout)
            if git('status', '--porcelain', '--untracked-files=all', repository=checkout):
                raise ValueError('materialized_source_not_clean')
            receipt['materialization'] = {'method': 'local shared clone; detached exact commit',
                                          'source_sha': sha, 'clean_before_native': True}
            source_files = ('.github/workflows/ci.yml', 'mix.exs', 'mix.lock', '.tool-versions',
                            'scripts/ci/ci-mix-receivers.py', 'scripts/ci/ci-command-record.py',
                            'test/example/priv/static/assets/js/app.js',
                            'test/example/priv/playwright/playwright.config.ts')
            receipt['source_file_sha256'] = {name: digest(checkout / name) for name in source_files}
            env = sanitized_environment()
            versions = run(['elixir', '--version'], cwd=checkout, env=env)
            receipt['runtime'] = versions
            pins = (checkout / '.tool-versions').read_text()
            elixir_pin = re.search(r'^elixir (\S+)', pins, re.M).group(1).split('-')[0]
            otp_pin = re.search(r'^erlang (\S+)', pins, re.M).group(1).split('.')[0]
            if f'Elixir {elixir_pin} ' not in versions or f'Erlang/OTP {otp_pin} ' not in versions:
                raise ValueError('pinned_runtime_unavailable')
            if 'phx_new-1.8.8' not in run(['mix', 'archive'], cwd=checkout, env=env):
                raise ValueError('required_phx_new_1.8.8_archive_missing')
            pg_env = {**env, 'PGPASSWORD': os.environ.get('SIGRA_TEST_PG_PASSWORD', 'postgres')}
            try:
                run(['psql', '-X', '-w', '-h', os.environ.get('SIGRA_TEST_PG_HOSTNAME', 'localhost'),
                     '-p', os.environ.get('SIGRA_TEST_PG_PORT', '5432'),
                     '-U', os.environ.get('SIGRA_TEST_PG_USERNAME', 'postgres'),
                     '-d', os.environ.get('SIGRA_TEST_PG_DATABASE', 'sigra_test'),
                     '-tAc', 'SELECT 1'], cwd=checkout, env=pg_env, timeout=10)
            except subprocess.CalledProcessError:
                raise ValueError('configured_test_postgresql_query_failed') from None
            if digest(repository / 'mix.lock') != digest(checkout / 'mix.lock'):
                raise ValueError('installed_dependency_lock_differs_from_source')
            for name in ('deps', '_build'):
                if not (repository / name).is_dir():
                    raise ValueError('locked_local_dependency_directory_missing:' + name)
                shutil.copytree(repository / name, checkout / name, symlinks=True)
            # Resolve the production browser policy in a real Node process; this
            # does not run/list browser cases or invent a browser result.
            policy_js = "import {browserInvocations} from './scripts/ci/ci-browser-command.mjs'; console.log(JSON.stringify(Object.fromEntries(process.argv.slice(1).map(x=>[x,browserInvocations(x,'pull_request')]))));"
            policies = json.loads(run(['node', '--input-type=module', '-e', policy_js, *OWNERS[1:]], cwd=checkout))
            write_new(data_root / 'browser-policy.json', policies)
            env['SIGRA_CI_RECEIVER_OUTPUT'] = str(data_root / 'receiver')
            argv = [sys.executable, '-B', str(checkout / 'scripts/ci/ci-mix-receivers.py'),
                    'leg', 'ordinary', '--', 'mix', 'test', 'test/sigra/config_test.exs']
            receipt['command'] = ['python3', '-B', 'scripts/ci/ci-mix-receivers.py', *argv[3:]]
            receipt['timeout_seconds'] = 600
            with (data_root / 'receiver.stdout.log').open('xb') as stdout, (data_root / 'receiver.stderr.log').open('xb') as stderr:
                process = subprocess.Popen(argv, cwd=checkout, env=env, stdout=stdout,
                                           stderr=stderr, start_new_session=True)
                try:
                    native_exit = process.wait(timeout=max(1, 600 - (time.monotonic() - started)))
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    raise ValueError('native_tracer_timeout_600_seconds') from None
            receipt['native_exit_code'] = native_exit
            report = data_root / 'receiver/legs/ordinary/exunit.json'
            receipt['native_report'] = str(report.relative_to(output.parent))
            if not report.is_file():
                raise ValueError('native_report_missing_after_exit:' + str(native_exit))
            identity = {'source_sha': sha, 'workflow_sha256': receipt['source_file_sha256']['.github/workflows/ci.yml']}
            observation = validate_local_report(report, digest(report), identity, native_exit)
            receipt['observation'] = observation
            result = evaluate_local_observation(repository, data_root / 'evaluation', observation)
            receipt['evaluation'] = result
            receipt['evaluation_limitation'] = 'Native receipt validated locally; production evaluator sees zero GitHub families. Local timing is not a PR performance sample.'
            receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        # Tool output can contain credentials; retain only a classified message.
        code = str(error) if isinstance(error, ValueError) else type(error).__name__
        receipt['blockers'].append(code)
    receipt['local_elapsed_seconds'] = round(time.monotonic() - started, 3)
    write_new(output, receipt)
    print(json.dumps({'status': receipt['status'], 'output': str(output), 'blockers': receipt['blockers'],
                      'performance_verdict': receipt['performance_verdict']}))
    return 0 if receipt['status'] == 'passed' else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    tracer = sub.add_parser('local-tracer')
    tracer.add_argument('--source', required=True)
    tracer.add_argument('--output', required=True)
    args = parser.parse_args()
    try:
        return local_tracer(args.source, args.output)
    except (ValueError, OSError) as error:
        print(type(error).__name__ + ': ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
