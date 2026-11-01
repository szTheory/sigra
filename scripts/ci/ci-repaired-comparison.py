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


TREATMENT_PATHS = (
    'test/example/priv/playwright/tests/admin-theme.spec.ts',
    'test/example/priv/playwright/tests/organizations.spec.ts',
    '.github/actions/example-playwright-boot/action.yml',
    '.github/workflows/ci.yml',
)
HISTORICAL_THEME_PARENT = 'f89de5b11a502b9034180446b15ba7777c9147c5'
HISTORICAL_THEME_SELECTED = '20614c85e929c19d52b9a6ffd9e909aff23aeeef'
HISTORICAL_BASE = 'd4dcc1939bd1f1590f6ca01d55b861e31acc745f'


def sha256_text(text):
    return hashlib.sha256(text.encode()).hexdigest()


def replace_exact(text, old, new, count):
    if text.count(old) != count:
        raise ValueError('treatment_anchor_count_changed:' + old[:50])
    return text.replace(old, new)


def build_control(candidate_files, repository):
    """Reverse only reviewed speed work; keep later diagnostics and repairs.

    Theme inputs are pinned to their retained selected bytes. If later edits
    arrive, refuse to discard them and require a newly reviewed hunk mapping.
    """
    files = dict(candidate_files)
    theme_path, org_path, action_path, workflow_path = TREATMENT_PATHS
    historical = git('show', f'{HISTORICAL_THEME_SELECTED}:{theme_path}', repository=repository) + '\n'
    if files[theme_path] != historical:
        raise ValueError('admin_theme_source_changed_requires_hunk_review')
    old_theme = git('show', f'{HISTORICAL_THEME_PARENT}:{theme_path}', repository=repository) + '\n'
    # Backend restoration was a correctness fix, so carry its exact current
    # implementation into the anonymous/per-test-registration control.
    cleanup = historical.split('async function restoreBrandingDefaults(', 1)[1].split('\ntest.describe(', 1)[0]
    cleanup = 'async function restoreBrandingDefaults(' + cleanup.replace('adminThemeTest.afterEach', 'test.afterEach')
    files[theme_path] = replace_exact(old_theme, 'test.describe("admin theme switch",',
                                     cleanup + '\ntest.describe("admin theme switch",', 1)
    files[org_path] = replace_exact(files[org_path],
        '  await registerAndConfirmUser(page, ownerEmail, ownerPassword);\n  await assertAuthenticatedZeroOrganizationState(page);',
        '  await registerAndConfirmUser(page, ownerEmail, ownerPassword);\n  await logInIfNeeded(page, ownerEmail, ownerPassword);\n  await assertAuthenticatedZeroOrganizationState(page);', 2)
    combined = 'mix do deps.get + compile --warnings-as-errors + ecto.create + ecto.migrate + run priv/repo/seeds.exs'
    separate = "bash -c 'mix deps.get && mix compile --warnings-as-errors && mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs'"
    files[action_path] = replace_exact(files[action_path], combined, separate, 2)
    start = files[workflow_path].index('\n  library_tests_shard:')
    end_match = re.search(r'\n  [A-Za-z_]+:', files[workflow_path][start + 1:])
    end = start + 1 + end_match.start() if end_match else len(files[workflow_path])
    library = files[workflow_path][start:end]
    duplicate = ('      - name: Install Hex + Rebar\n        run: |\n'
                 '          mix local.hex --force\n          mix local.rebar --force\n')
    library = replace_exact(library, '      - name: Install phx_new archive\n',
                            duplicate + '      - name: Install phx_new archive\n', 1)
    files[workflow_path] = files[workflow_path][:start] + library + files[workflow_path][end:]
    descriptions = (
        'Reverse invocation-local auth reuse; retain identical tests, real registration/lockout, and branding restoration.',
        'Restore two redundant owner logins; retain authentication-state assertions and invitee lifecycle.',
        'Run the same five native preparation tasks in separate Mix VMs; retain outer recorder, all env/readiness/cache/OS dependencies.',
        'Restore duplicate Hex/Rebar installation after pinned setup-beam; retain cold fetch and sole seven-leg mix ci.',
    )
    changes = {name: {'control_sha256': sha256_text(files[name]),
                      'candidate_sha256': sha256_text(candidate_files[name]), 'classification': description}
               for name, description in zip(TREATMENT_PATHS, descriptions)}
    return files, changes


def validate_treatment_files(control, candidate, changes):
    differing = {name for name in set(control) | set(candidate) if control.get(name) != candidate.get(name)}
    if differing != set(changes):
        raise ValueError('treatment_file_set_mismatch')
    for name, row in changes.items():
        if sha256_text(control[name]) != row['control_sha256'] or sha256_text(candidate[name]) != row['candidate_sha256']:
            raise ValueError('treatment_bytes_mismatch:' + name)


def validate_warm_receipts(rows, requirements, producer_origins=None):
    """Validate all frozen cache components against independent producer facts.

    requirements comes from the frozen experiment; producer_origins must come
    from the existing independent run/job/artifact verifier, never from these
    report rows. This pure check does not acquire or authorize hosted evidence.
    Unknown future PR refs or producer identities cannot qualify as warm.
    """
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        return ['cache_receipts_invalid']
    if not isinstance(requirements, dict) or not isinstance(requirements.get('owners'), dict):
        return ['frozen_cache_requirements_missing']
    expected_owners = requirements['owners']
    names = [row.get('owner') for row in rows]
    if (any(not isinstance(name, str) for name in names) or len(names) != len(OWNERS)
            or set(names) != set(OWNERS) or set(expected_owners) != set(OWNERS)):
        return ['six_unique_cache_owner_receipts_required']
    consumer = requirements.get('consumer') or {}
    if not isinstance(consumer, dict):
        return ['frozen_consumer_refs_missing']
    branch_refs = [consumer.get(field) for field in ('head_ref', 'base_ref', 'default_ref')]
    if (any(not isinstance(ref, str) or not re.fullmatch(r'refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*', ref)
            or '..' in ref or '//' in ref or ref.endswith(('/', '.lock')) for ref in branch_refs)
            or not re.fullmatch(r'refs/pull/[1-9][0-9]*/merge', str(consumer.get('merge_ref', '')))):
        return ['frozen_consumer_refs_missing_or_invalid']
    eligible = set(branch_refs + [consumer['merge_ref']])
    errors = []
    producer_origins = producer_origins if isinstance(producer_origins, dict) else {}
    for row in rows:
        owner = row['owner']
        frozen = expected_owners[owner]
        if not isinstance(frozen, dict):
            errors.append('frozen_owner_invalid:' + owner)
            continue
        expected_caches = frozen.get('caches')
        actual_caches = row.get('caches')
        mandatory = {'dependencies'} if owner == 'library_tests_shard' else {'dependencies', 'browser_binaries'}
        if (not isinstance(expected_caches, dict) or not mandatory.issubset(expected_caches)
                or any(not isinstance(component, str) for component in expected_caches)):
            errors.append('frozen_required_cache_components_missing:' + owner)
            continue
        if not isinstance(actual_caches, dict) or set(actual_caches) != set(expected_caches):
            errors.append('cache_components_missing_or_unexpected:' + owner)
            continue
        origin, actual_producer = producer_origins.get(owner), row.get('producer')
        if (not isinstance(origin, dict) or not isinstance(actual_producer, dict)
                or not re.fullmatch('[0-9a-f]{64}', str(origin.get('api_evidence_sha256', '')))):
            errors.append('independent_cache_producer_origin_required:' + owner)
        else:
            identity_fields = ('source_sha', 'workflow_sha256', 'run_id', 'run_attempt', 'job_id')
            if (not re.fullmatch('[0-9a-f]{40}', str(frozen.get('source_sha', '')))
                    or not re.fullmatch('[0-9a-f]{64}', str(frozen.get('workflow_sha256', '')))
                    or any(type(origin.get(field)) is not int or origin[field] < 1
                           for field in ('run_id', 'run_attempt', 'job_id'))
                    or any(actual_producer.get(field) != origin.get(field) for field in identity_fields)
                    or any(origin.get(field) != frozen.get(field) for field in ('source_sha', 'workflow_sha256'))):
                errors.append('cache_producer_not_bound_to_frozen_source:' + owner)
        for component, expected in expected_caches.items():
            actual = actual_caches.get(component)
            label = owner + ':' + component
            if not isinstance(expected, dict) or not isinstance(actual, dict):
                errors.append('cache_component_invalid:' + label)
                continue
            independent_caches = origin.get('cache_receipts', {}) if isinstance(origin, dict) else {}
            independent = independent_caches.get(component) if isinstance(independent_caches, dict) else None
            if (not isinstance(independent, dict)
                    or not re.fullmatch('[0-9a-f]{64}', str(independent.get('evidence_sha256', '')))
                    or any(independent.get(field) != actual.get(field)
                           for field in ('key', 'matched_key', 'version', 'scope', 'restore'))):
                errors.append('independent_cache_component_receipt_required:' + label)
            scopes = expected.get('eligible_scopes')
            if (not isinstance(scopes, list) or not scopes or any(not isinstance(ref, str) or ref not in eligible for ref in scopes)
                    or actual.get('scope') not in scopes):
                errors.append('cache_scope_ineligible:' + label)
            if (not isinstance(expected.get('key'), str) or not expected['key']
                    or not isinstance(expected.get('version'), str) or not expected['version']
                    or actual.get('restore') != 'exact' or actual.get('key') != expected['key']
                    or actual.get('matched_key') != expected['key'] or actual.get('version') != expected['version']):
                errors.append('cache_restore_key_or_version_not_exact:' + label)
    return errors


def validate_pr_identity(observed, expected):
    return ['pr_identity_mismatch:' + key for key in ('head', 'base', 'merge_tree')
            if not expected.get(key) or observed.get(key) != expected[key]]


def job_block(workflow, name):
    match = re.search(r'^  ' + re.escape(name) + r':\s*$', workflow, re.M)
    if not match:
        raise ValueError('required_job_missing:' + name)
    rest = workflow[match.end():]
    next_job = re.search(r'^  [A-Za-z_][A-Za-z_0-9]*:\s*$', rest, re.M)
    return rest[:next_job.start()] if next_job else rest


def inspect_workflow(workflow, action):
    library = job_block(workflow, 'library_tests_shard')
    browser = job_block(workflow, 'example_playwright_shard')
    def required(pattern, text, label):
        match = re.search(pattern, text, re.M)
        if not match:
            raise ValueError('workflow_shape_changed:' + label)
        return match.group(1)
    example_key = required(r'^        key: (.+-example-dev-port.+)$', action, 'example_key')
    example_restore = required(r'^        restore-keys: (.+)$', action, 'example_restore')
    library_key = required(r'^          key: (.+)$', library, 'library_key')
    library_restore = required(r'^          restore-keys: (.+)$', library, 'library_restore')
    rows = [{'owner': OWNERS[0], 'key_expression': library_key, 'restore_prefix': library_restore,
             'paths': ['deps', '_build'], 'condition': 'needs.release_ref_guard succeeds',
             'mix_env': 'test', 'port': None, 'browsers_key_expression': None}]
    for owner in OWNERS[1:]:
        match = re.search(r'^          - seam: ' + owner + r'\n(.*?)(?=^          - seam:|^    services:)', browser, re.M | re.S)
        if not match:
            raise ValueError('browser_owner_missing:' + owner)
        block = match.group(1)
        port = required(r'^            port: "(\d+)"$', block, 'port:' + owner)
        binary_key = required(r'^            browser_cache_key: (.+)$', block, 'browser_key:' + owner)
        rows.append({'owner': owner, 'key_expression': example_key.replace('${{ inputs.app-port }}', port),
                     'restore_prefix': example_restore.replace('${{ inputs.app-port }}', port),
                     'paths': ['test/example/deps', 'test/example/_build'],
                     'browsers_key_expression': '${{ runner.os }}-' + binary_key,
                     'browsers_paths': ['~/.cache/ms-playwright'],
                     'condition': 'PR classifier success and docs_only != true; per-seam native step; not cancelled',
                     'mix_env': 'dev', 'ci': 'true', 'port': port})
    for row in rows:
        row.update({'eligible_shared_scope': 'refs/heads/main', 'pr_scope': 'refs/pull/<number>/merge',
                    'eligible_scope_rules': ['default branch', 'actual PR base branch',
                                             'same actual head branch', 'same actual PR merge ref'],
                    'scope_status': 'rules_only_actual_consumer_refs_not_frozen',
                    'sibling_pr_scope_eligible': False, 'hosted_warm_status': 'unproved',
                    'matched_key': None, 'runner_label': 'ubuntu-24.04', 'actual_runner_os': None,
                    'actual_runner_arch': None, 'actual_runner_image': None,
                    'runtime_isolation': '.tool-versions OTP/Elixir, MIX_ENV and endpoint PORT in compiled cache',
                    'exact_restore_required': True, 'fallback_qualifies_as_warm': False})
    return {'owners': rows,
            'trigger_main_pr': bool(re.search(r'^  pull_request:\s*\n\s+branches: \[main\]', workflow, re.M)),
            'distinct_pr_concurrency': bool(re.search(r'^  group: \$\{\{ github\.workflow \}\}-\$\{\{ github\.event\.pull_request\.number \|\| github\.run_id \}\}\s*$', workflow, re.M)),
            'preserved_commands': [command for command in ('npm ci', 'ci-playwright-os-deps.py', 'npx playwright install $BROWSERS') if command in action]}


def archive_source(repository, sha, output):
    # Planning evidence is separately retained; archive every tracked top-level
    # production entry, with the exclusion explicitly recorded in SOURCES.
    entries = git('ls-tree', '--name-only', sha, repository=repository).splitlines()
    entries = [name for name in entries if name != '.planning']
    with Path(output).open('xb') as stream:
        subprocess.run(['git', 'archive', '--format=tar.gz', sha, '--', *entries],
                       cwd=repository, stdout=stream, stderr=subprocess.PIPE, check=True, timeout=90)
    return {'path': Path(output).name, 'sha256': digest(output), 'excluded_top_level': ['.planning']}


def merge_preview(repository, base, head, expected_tree):
    child = subprocess.run(['git', 'merge-tree', '--write-tree', base, head],
                           cwd=repository, capture_output=True, text=True, timeout=60)
    lines = child.stdout.splitlines()
    if child.returncode not in (0, 1) or not lines or not re.fullmatch('[0-9a-f]{40}', lines[0]):
        raise ValueError('merge_preview_unavailable')
    conflicts = sorted({line.split('\t', 1)[1] for line in lines[1:]
                        if re.match(r'^[0-7]{6} [0-9a-f]{40} [123]\t', line)})
    ready = child.returncode == 0 and lines[0] == expected_tree
    return {'status': 'ready' if ready else 'blocked', 'exit_code': child.returncode,
            'base_sha': base, 'head_sha': head, 'expected_tree': expected_tree,
            'computed_tree': lines[0], 'conflicting_paths': conflicts,
            'reason': None if ready else 'merge_conflicts' if child.returncode else 'merge_tree_differs_from_frozen_source',
            'stdout': child.stdout, 'stderr': child.stderr}


def materialize_sources(source, output, base='origin/main', repository=ROOT):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    source_sha = git('rev-parse', '--verify', '--end-of-options', source + '^{commit}', repository=repository)
    base_sha = git('rev-parse', '--verify', '--end-of-options', base + '^{commit}', repository=repository)
    original_base = git('rev-parse', '--verify', HISTORICAL_BASE + '^{commit}', repository=repository)
    with tempfile.TemporaryDirectory(prefix='sigra-repaired-sources-') as temp:
        checkout = Path(temp) / 'source'
        run(['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--shared', '--no-checkout',
             '--', str(repository), str(checkout)], timeout=60)
        git('checkout', '--detach', source_sha, repository=checkout)
        candidate_files = {name: (checkout / name).read_text() for name in TREATMENT_PATHS}
        control_files, changes = build_control(candidate_files, repository)
        validate_treatment_files(control_files, candidate_files, changes)
        for name, text in control_files.items():
            (checkout / name).write_text(text)
        git('add', '--', *TREATMENT_PATHS, repository=checkout)
        control_tree = git('write-tree', repository=checkout)
        proposed_control_sha = run(['git', '-c', 'user.name=Sigra local feasibility', '-c', 'user.email=local@sigra.invalid',
                           'commit-tree', control_tree, '-p', source_sha, '-m',
                           'Repaired control for Phase 255.1; local construction only'], cwd=checkout)
        durable_ref = 'refs/evidence/phase255-1/source-control-' + source_sha[:12]
        existing_ref = subprocess.run(['git', 'show-ref', '--verify', '--quiet', durable_ref], cwd=repository).returncode == 0
        control_sha = git('rev-parse', durable_ref, repository=repository) if existing_ref else proposed_control_sha
        if existing_ref and (git('rev-parse', control_sha + '^{tree}', repository=repository) != control_tree
                             or git('rev-parse', control_sha + '^', repository=repository) != source_sha):
            raise ValueError('source_preservation_ref_already_exists_with_different_source')
        candidate_tree = git('rev-parse', source_sha + '^{tree}', repository=checkout)
        patch = subprocess.check_output(['git', 'diff', '--binary', control_sha, source_sha,
                                         '--', *TREATMENT_PATHS], cwd=checkout)
        (output / 'treatment.patch').write_bytes(patch)
        changed_paths = git('diff', '--name-only', control_sha, source_sha, repository=checkout).splitlines()
        if set(changed_paths) != set(TREATMENT_PATHS):
            raise ValueError('unexpected_source_diff_outside_declared_treatment')
        git('checkout', '--detach', control_sha, repository=checkout)
        run(['git', 'apply', '--index', str(output / 'treatment.patch')], cwd=checkout)
        if git('write-tree', repository=checkout) != candidate_tree:
            raise ValueError('treatment_round_trip_tree_mismatch')
        # Persist the exact new Git objects under a scoped local ref. This is
        # local Git transport, never a network fetch or a default-branch change.
        temp_ref = 'refs/heads/phase255-1-repaired-control'
        git('update-ref', temp_ref, control_sha, repository=checkout)
        if not existing_ref:
            git('fetch', '--no-tags', str(checkout), temp_ref + ':' + durable_ref, repository=repository)
        if git('rev-parse', durable_ref + '^{tree}', repository=repository) != control_tree:
            raise ValueError('control_source_ref_readback_failed')
        common_patch = subprocess.check_output(['git', 'diff', '--binary', original_base, control_sha,
                                                '--', *[name for name in git('ls-tree', '--name-only', source_sha, repository=checkout).splitlines() if name != '.planning']], cwd=checkout)
        (output / 'common-repairs.patch').write_bytes(common_patch)
        records = {}
        for role, sha in (('control', control_sha), ('candidate', source_sha)):
            archive = archive_source(checkout, sha, output / (role + '.tar.gz'))
            file_hashes = {}
            for name in (*TREATMENT_PATHS, 'mix.exs', 'mix.lock', '.tool-versions',
                         'scripts/ci/ci-mix-receivers.py', 'scripts/ci/ci-run-metrics.sh',
                         'scripts/ci/docs-only-classify.sh', 'test/example/priv/static/assets/js/app.js',
                         'test/example/priv/playwright/playwright.config.ts'):
                blob = subprocess.check_output(['git', 'show', f'{sha}:{name}'], cwd=checkout)
                file_hashes[name] = hashlib.sha256(blob).hexdigest()
            tree = git('rev-parse', sha + '^{tree}', repository=checkout)
            merge = merge_preview(checkout, base_sha, sha, tree)
            write_new(output / (role + '-merge.json'), merge)
            records[role] = {'source_sha': sha, 'tree_sha': git('rev-parse', sha + '^{tree}', repository=checkout),
                             'source_ref': durable_ref if role == 'control' else source_sha,
                             'producer_sha': sha, 'application_sha': sha,
                             'workflow_revision': sha, 'file_sha256': file_hashes,
                             'workflow_sha256': file_hashes['.github/workflows/ci.yml'],
                             'archive': archive, 'proposed_pr_base_sha': base_sha,
                             'merge_preview': merge,
                             'proposed_merge_tree': merge['computed_tree'] if merge['status'] == 'ready' else None,
                             'proposed_pr_head_sha': sha, 'proposed_target_branch': 'main',
                             'pr_number': None, 'hosted_merge_sha': None}
        return {'schema_version': 'sigra.ci-repaired-sources/v1', 'status': 'constructed',
                'local_only': True, 'acceptance_samples': 0, 'remote_requests': 0,
                'candidate_capture_sha': source_sha, 'constructor_sha256': digest(__file__),
                'historical_source_unchanged': original_base,
                'common_repaired_source': control_sha, 'common_tree': control_tree,
                'common_patch': {'path': 'common-repairs.patch', 'sha256': digest(output / 'common-repairs.patch')},
                'treatment_patch': {'path': 'treatment.patch', 'sha256': digest(output / 'treatment.patch')},
                'treatment_round_trip_tree_equal': True, 'treatment_files': changes,
                'sources': records, 'base_ref_input': base, 'base_sha': base_sha,
                'base_ref_freshness': 'local snapshot only; no remote request authorized',
                'control_ref_readback_equal': True}


def evaluate_feasibility(sources, repository=ROOT):
    """Keep local plan prerequisites separate from later hosted acceptance.

    In particular, Plan02 produces the work receipt and cannot be made a
    prerequisite to beginning Plan02. Missing hosted facts never become a pass.
    """
    candidate = sources['sources']['candidate']['source_sha']
    workflow = git('show', candidate + ':.github/workflows/ci.yml', repository=repository) + '\n'
    action = git('show', candidate + ':.github/actions/example-playwright-boot/action.yml', repository=repository) + '\n'
    inspected = inspect_workflow(workflow, action)
    local_blockers, diagnostics = [], []
    if (sources.get('status') != 'constructed' or sources.get('treatment_round_trip_tree_equal') is not True
            or sources.get('control_ref_readback_equal') is not True
            or set(sources.get('sources', {})) != {'control', 'candidate'}):
        local_blockers.append('clean_source_treatment_construction_not_proved')
    for role, record in sources['sources'].items():
        preview = record.get('merge_preview') or {}
        if (preview.get('status') != 'ready' or preview.get('computed_tree') != record.get('tree_sha')
                or preview.get('expected_tree') != record.get('tree_sha')
                or preview.get('head_sha') != record.get('source_sha')
                or preview.get('base_sha') != sources['base_sha']):
            local_blockers.append('proposed_PR_merge_blocked:' + role + ':' + str(preview.get('reason') or 'source_binding_mismatch'))
        # Run the source's existing classifier, rather than infer useful work
        # from a nonempty diff or a historical browser row count.
        changed = git('diff', '--name-only', sources['base_sha'] + '...' + record['source_sha'], repository=repository)
        classifier = git('show', record['source_sha'] + ':scripts/ci/docs-only-classify.sh', repository=repository)
        classification = subprocess.run(['bash', '-c', classifier], input=changed + '\n',
            cwd=repository, env=sanitized_environment(), capture_output=True, text=True, timeout=15)
        if classification.returncode or classification.stdout.strip() != 'docs_only=false':
            local_blockers.append('proposed_PR_not_full_workload:' + role)
    if not inspected['trigger_main_pr']:
        local_blockers.append('main_pull_request_trigger_missing')
    if not inspected['distinct_pr_concurrency']:
        local_blockers.append('distinct_PR_cancellation_groups_not_proved')
    if len(inspected['owners']) != 6 or len(inspected['preserved_commands']) != 3:
        local_blockers.append('six_owner_cache_or_native_setup_structure_missing')
    base = sources['base_sha']
    # Resolve exact hashFiles inputs from Git objects rather than assuming
    # identical key expressions mean identical compiled cache keys.
    patterns = ('test/example/mix.lock', 'test/example/config/**', 'test/example/lib/**/*.ex',
                'lib/**/*.ex', 'mix.exs')
    import fnmatch
    def cache_input_identity(sha):
        names = git('ls-tree', '-r', '--name-only', sha, repository=repository).splitlines()
        variants = set(patterns)
        for pattern in patterns:
            variants.add(pattern.replace('**/', ''))
        selected = sorted(name for name in names if any(fnmatch.fnmatchcase(name, pattern) for pattern in variants))
        payload = b''
        for name in selected:
            blob = subprocess.check_output(['git', 'show', f'{sha}:{name}'], cwd=repository)
            payload += name.encode() + b'\0' + hashlib.sha256(blob).digest()
        # This is an input-byte comparison, NOT an emulation of Actions hashFiles.
        return hashlib.sha256(payload).hexdigest(), selected
    base_inputs, _ = cache_input_identity(base)
    candidate_inputs, input_paths = cache_input_identity(candidate)
    if base_inputs != candidate_inputs:
        diagnostics.append('local_main_compiled_cache_inputs_differ_from_repaired_sources')
    hosted_blockers = ['current_main_source_and_branch_rules_not_independently_observed',
                       'eligible_exact_cache_entries_not_observed',
                       'actual_PR_head_base_merge_and_producer_not_observed',
                       'complete_equivalent_work_receipt_pending_plan02',
                       'six_owner_actual_exact_warm_restores_pending_separate_approval']
    local_ready = not local_blockers
    return {'schema_version': 'sigra.ci-repaired-feasibility/v1', 'status': 'blocked',
            'local_status': 'ready' if local_ready else 'blocked', 'hosted_status': 'blocked',
            'next_local_plan': '255.1-02' if local_ready else None,
            'local_only': True, 'acceptance_samples': 0, 'performance_verdict': 'insufficient_data',
            'remote_requests': 0, 'remote_mutations': 0,
            'source_status': 'constructed_treatment_only', 'work_status': 'pending_plan02',
            'trigger_status': 'local_main_filter_verified' if inspected['trigger_main_pr'] else 'blocked',
            'merge_status': 'local_only_ready' if not any(item.startswith('proposed_PR_merge_blocked:') for item in local_blockers) else 'blocked',
            'cache_structure_status': 'local_rules_enumerated_actual_eligibility_unproved',
            'hosted_warm_status': 'unproved', 'six_owner_cache_rows': inspected['owners'],
            'cache_inputs': {'method': 'compare Git path/blob bytes selected by key input globs; not an Actions key emulator',
                             'base_identity': base_inputs, 'candidate_identity': candidate_inputs,
                             'same_inputs': base_inputs == candidate_inputs, 'input_paths': input_paths},
            'local_blocking_items': local_blockers, 'hosted_blocking_items': hosted_blockers,
            'blocking_items': local_blockers + hosted_blockers, 'diagnostics': diagnostics,
            'source_sha': candidate, 'base_sha': base,
            'trigger_main_pr': inspected['trigger_main_pr'], 'distinct_PR_concurrency': inspected['distinct_pr_concurrency'],
            'smallest_corrective_step': ('Continue local Plan02 to retain and compare complete useful work; keep hosted preparation and collection unauthorized.' if local_ready else
                'Resolve the named local source/merge/trigger/workload prerequisite, then repeat this check. Later hosted facts do not block local Plan02.'),
            'requirements': {'CISPEED-01': 'open', 'CISPEED-02': 'open'}}


def preflight(source, output, base='origin/main'):
    output = Path(output).resolve()
    if output.exists():
        raise ValueError('output_exists_preserve_prior_bytes_before_refresh')
    sources_path = output.parent / 'SOURCES.json'
    if sources_path.exists():
        raise ValueError('sources_exists_preserve_prior_bytes_before_refresh')
    try:
        sources_dir = output.parent / ('sources-' + str(time.time_ns()))
        sources = materialize_sources(source, sources_dir, base)
        # All payload paths are relative to SOURCES.json, not to a temporary checkout.
        for record in sources['sources'].values():
            record['archive']['path'] = sources_dir.name + '/' + record['archive']['path']
        for field in ('common_patch', 'treatment_patch'):
            sources[field]['path'] = sources_dir.name + '/' + sources[field]['path']
        sources['artifact_directory'] = sources_dir.name
        write_new(sources_path, sources)
        result = evaluate_feasibility(sources)
        write_new(output, result)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        # A failed prerequisite still leaves a machine-readable result. Do not
        # copy tool stderr or environment contents into retained diagnostics.
        if isinstance(error, subprocess.CalledProcessError):
            code = ('source_or_base_object_unresolved' if 'rev-parse' in error.cmd
                    else 'local_preflight_command_failed:' + str(error.returncode))
        else:
            code = str(error) if isinstance(error, ValueError) else type(error).__name__
        result = {'schema_version': 'sigra.ci-repaired-feasibility/v1', 'status': 'blocked',
                  'local_status': 'blocked', 'hosted_status': 'blocked', 'next_local_plan': None,
                  'local_only': True, 'acceptance_samples': 0, 'performance_verdict': 'insufficient_data',
                  'source_requested': source, 'base_requested': base,
                  'remote_requests': 0, 'remote_mutations': 0,
                  'local_blocking_items': [code], 'hosted_blocking_items': ['local_prerequisites_failed'],
                  'blocking_items': [code, 'local_prerequisites_failed'],
                  'requirements': {'CISPEED-01': 'open', 'CISPEED-02': 'open'}}
        write_new(output, result)
    print(json.dumps({'status': result['status'], 'local_status': result['local_status'],
                      'hosted_status': result['hosted_status'], 'next_local_plan': result['next_local_plan'],
                      'output': str(output), 'blockers': result['blocking_items']}))
    return 0 if result['local_status'] == 'ready' else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    tracer = sub.add_parser('local-tracer')
    tracer.add_argument('--source', required=True)
    tracer.add_argument('--output', required=True)
    prep = sub.add_parser('preflight')
    prep.add_argument('--source', required=True)
    prep.add_argument('--output', required=True)
    prep.add_argument('--base', default='origin/main')
    args = parser.parse_args()
    try:
        if args.command == 'preflight':
            return preflight(args.source, args.output, args.base)
        return local_tracer(args.source, args.output)
    except (ValueError, OSError) as error:
        print(type(error).__name__ + ': ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
