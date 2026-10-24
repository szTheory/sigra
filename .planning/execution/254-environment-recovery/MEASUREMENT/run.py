#!/usr/bin/env python3
"""Single-owner fixed comparison driver; --check-only is entirely offline.

CONTRACT.json is frozen beside this file. INITIAL-CAPTURES.json maps before/after
to repository-relative receipt paths. Existing EVENTS.jsonl requires explicit
human/root reconciliation; this driver never restarts or replaces an attempt.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

SCOPE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[4]
CONTRACT = SCOPE / 'CONTRACT.json'
INITIAL = SCOPE / 'INITIAL-CAPTURES.json'
REGISTRATIONS = SCOPE / 'REGISTRATIONS.json'
EVENTS = SCOPE / 'EVENTS.jsonl'
METRICS = ROOT / 'scripts/ci/ci-run-metrics.sh'
BASELINE = ROOT / '.planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz'
sys.path.insert(0, str(ROOT / 'scripts/ci'))
from ci_metrics_security import (  # noqa: E402
    _comparison_budget_read, comparison_request_budget_record_response,
    initialize_comparison_request_budget, validate_comparison_pass_reservation,
    validate_comparison_plan, validate_registered_run_observation,
    verify_durable_attempt_capture, verify_snapshot_hashes,
)


def load(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value, *, replace=False):
    temporary = path.with_name(path.name + '.tmp') if replace else path
    with temporary.open('x') as output:
        json.dump(value, output, indent=2); output.write('\n'); output.flush(); os.fsync(output.fileno())
    if replace:
        os.replace(temporary, path)


def event(kind, **values):
    row = {'at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'kind': kind, **values}
    with EVENTS.open('a') as output:
        output.write(json.dumps(row, sort_keys=True) + '\n'); output.flush(); os.fsync(output.fileno())
    write(SCOPE / 'PROGRESS.json', row, replace=True)
    print(json.dumps(row, sort_keys=True), flush=True)


def confined(relative):
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError('path_outside_repository')
    return path


def check():
    contract = load(CONTRACT)
    issues = validate_comparison_plan(contract)
    if issues or contract.get('sample_identity') != 'run_id+run_attempt':
        raise ValueError('comparison_plan_invalid:' + ','.join(issues))
    passes = contract.get('collection_passes') or []
    if len(passes) != 20 or [row['pair_id'] for row in passes] != [f'pair-{i:02d}' for i in range(1, 21)]:
        raise ValueError('twenty_ordered_collection_passes_required')
    if len({confined(row['ledger_path']).parent for row in passes}) != 20:
        raise ValueError('each_pair_requires_its_own_output_directory')
    reservations = contract['family_reservations']
    for index, item in enumerate(passes):
        path = confined(item['ledger_path'])
        expected = [row['reservation_id'] for row in reservations[index * 2:index * 2 + 2]]
        if item['reservation_ids'] != expected:
            raise ValueError('pass_schedule_mismatch')
        for reservation_id in expected:
            validate_comparison_pass_reservation(contract, path, reservation_id)
        if path.exists():
            raise ValueError('pass_already_initialized_requires_reconciliation')
    previous = {role: confined(path) for role, path in load(INITIAL).items()}
    if set(previous) != {'before', 'after'} or digest(BASELINE) != contract['baseline_identity']['source_bundle_sha256']:
        raise ValueError('initial_sources_or_receipts_invalid')
    for role, path in previous.items():
        first = next(row for row in reservations if row['family_role'] == role)
        source = contract['baseline_application_sha'] if role == 'before' else contract['candidate_identity']['application_sha']
        verify_durable_attempt_capture(load(path), ROOT, first['run_id'], first['run_attempt'] - 1, source)
    if REGISTRATIONS.exists() or EVENTS.exists():
        raise ValueError('prior_execution_requires_reconciliation_no_automatic_resume')
    return contract, previous


def global_rate_guard(contract):
    now = time.time()
    for item in contract['collection_passes']:
        path = confined(item['ledger_path'])
        if not path.exists():
            continue
        ledger = _comparison_budget_read(path, contract)
        for row in ledger['records']:
            if row.get('stop_reason') == 'http_rate_limit':
                raise ValueError('global_http_rate_stop_reset:' + str(row.get('reset_at')))
        latest = next((row for row in reversed(ledger['records']) if row['kind'] in ('policy', 'request')), {})
        remaining = latest.get('core_remaining')
        reset = next((row['reset_at'] for row in reversed(ledger['records']) if row.get('reset_at') is not None), None)
        if remaining is not None and remaining <= 250 and (reset is None or now < reset):
            raise ValueError('global_core_rate_stop_reset:' + str(reset))


def call(contract, frozen_hash, arguments, log, *, budget=None, network=False):
    if digest(CONTRACT) != frozen_hash:
        raise ValueError('frozen_contract_bytes_changed')
    if network:
        global_rate_guard(contract)
        if time.time() > datetime.datetime.fromisoformat(contract['window']['end_utc'].replace('Z', '+00:00')).timestamp():
            raise ValueError('frozen_window_expired')
    command = ['bash', str(METRICS), *arguments, '--contract', str(CONTRACT)]
    if budget is not None:
        command += ['--request-budget-ledger', str(budget)]
    with log.open('x') as output, log.with_name(log.name + '.stderr').open('x') as error:
        return subprocess.run(command, cwd=ROOT, stdout=output, stderr=error).returncode


def preserve(capture, reservation, budget):
    selected = [path for path in capture.rglob('*') if path.is_file()]
    if any(path.is_symlink() for path in capture.rglob('*')):
        raise ValueError('capture_symlink_rejected')
    selected += [REGISTRATIONS, budget]
    files = {path.relative_to(ROOT).as_posix(): digest(path) for path in selected}
    with tempfile.TemporaryDirectory(prefix='sigra254-measure-preserve-') as temporary:
        env = {**os.environ, 'GIT_INDEX_FILE': str(Path(temporary) / 'index')}
        def git(*args, **kwargs):
            return subprocess.check_output(['git', *args], cwd=ROOT, env=env, **kwargs)
        parent = git('rev-parse', 'HEAD').decode().strip(); git('read-tree', parent)
        git('add', '-f', '--', *files)
        tree = git('write-tree').decode().strip()
        commit = git('commit-tree', tree, '-p', parent, input=b'preserve(254): measured original attempt\n').decode().strip()
        ref = f"refs/evidence/phase254-measurement-{reservation['pair_id']}-{reservation['family_role']}-attempt-{reservation['run_attempt']}"
        git('update-ref', ref, commit, '0' * 40)
        for name, expected in files.items():
            if hashlib.sha256(git('show', ref + ':' + name)).hexdigest() != expected:
                raise ValueError('capture_git_readback_failed')
    receipt = {'capture_path': capture.relative_to(ROOT).as_posix(), 'ref': ref,
               'commit': commit, 'files': files, 'readback_verified': True}
    path = capture.parent / f"CAPTURE-{reservation['family_role']}.json"
    write(path, receipt)
    event('preserved', reservation_id=reservation['reservation_id'], receipt=str(path.relative_to(ROOT)), ref=ref, commit=commit)
    return path


def registration_count():
    return len(load(REGISTRATIONS)['records']) if REGISTRATIONS.exists() else 0


def pair_check(contract, frozen_hash, captures, directory):
    output = directory / 'PAIR-CHECK.json'
    args = ['--evaluate-comparison', '--registrations', str(REGISTRATIONS), '--before-bundle', str(captures['before']),
            '--after-bundle', str(captures['after']), '--baseline-source-bundle', str(BASELINE), '--format', 'json']
    if call(contract, frozen_hash, args, output):
        raise ValueError('pair_replay_failed')
    result = load(output); metrics = result['metrics']; native = metrics['native_parity']
    # The evaluator deliberately reports its final twenty-pair size/allocation
    # checks for this single-pair view. No source, schedule, image, native or
    # cost failure belongs in this list; CLI exit zero is not a passing verdict.
    expected_partial = {'comparison_registration_set_incomplete', 'comparison_family_reservation_incomplete',
        'before_family_count', 'after_family_count', 'before_unique_family_count', 'after_unique_family_count',
        'pair_identity_mismatch', 'insufficient_equivalent_successful_pairs', 'cache_stratum_allocation_mismatch'}
    if (any(row['reason'] not in expected_partial for row in result['diagnostics'])
            or metrics['comparable_successful_pairs'] != 1 or native['status'] != 'passed'
            or native['origin_status'] != 'passed' or native['origins_verified'] != 2
            or metrics['baseline_runner_seconds'] is None or metrics['candidate_runner_seconds'] is None):
        raise ValueError('pair_source_native_image_or_cost_prerequisite_failed')
    for capture in captures.values():
        family = load(capture / 'manifest.json')['comparison_families']
        if len(family) != 1 or family[0]['cache_stratum'] != 'warm' or family[0]['conclusion'] != 'success':
            raise ValueError('pair_not_successful_and_warm')


def execute(contract, previous):
    frozen_hash = digest(CONTRACT)
    event('started', contract_sha256=frozen_hash, measured_samples=0)
    start = datetime.datetime.fromisoformat(contract['window']['start_utc'].replace('Z', '+00:00')).timestamp()
    while time.time() < start:
        time.sleep(min(60, start - time.time()))
    indexes = {'before': [], 'after': []}
    for index, item in enumerate(contract['collection_passes']):
        global_rate_guard(contract)
        budget = confined(item['ledger_path']); directory = budget.parent; directory.mkdir(parents=True, exist_ok=True)
        initialize_comparison_request_budget(contract, budget)
        rows = contract['family_reservations'][index * 2:index * 2 + 2]
        for row in rows:
            role = row['family_role']; prefix = directory / role
            args = ['--bounded-request', f"/repos/szTheory/sigra/actions/runs/{row['run_id']}/rerun", '--request-method', 'POST',
                    '--reservation-id', row['reservation_id'], '--comparison-role', role, '--registrations', str(REGISTRATIONS),
                    '--capture-receipt', str(previous[role]), '--output', str(prefix.with_suffix('.trigger.json'))]
            event('triggering_once', reservation_id=row['reservation_id'])
            if call(contract, frozen_hash, args, prefix.with_suffix('.trigger.log'), budget=budget, network=True):
                raise ValueError('trigger_failed_no_retry')
            count = registration_count()
            for retry in (0, 1):
                args = ['--register-comparison-run', '--run-id', str(row['run_id']), '--reservation-id', row['reservation_id'], '--registrations', str(REGISTRATIONS)]
                code = call(contract, frozen_hash, args, directory / f'{role}.register-{retry}.log', budget=budget, network=True)
                if not code:
                    break
                if retry or registration_count() != count:
                    raise ValueError('early_registration_failed_or_ambiguous_no_trigger_retry')
                time.sleep(60)
            event('registered', reservation_id=row['reservation_id'], measured_samples=registration_count())
        completed = {}; due = {row['family_role']: time.monotonic() + 60 for row in rows}; sequence = 0
        while len(completed) != 2:
            for row in rows:
                role = row['family_role']
                if role in completed or time.monotonic() < due[role]:
                    continue
                sequence += 1; output = directory / f'{role}.status-{sequence:03d}.json'
                args = ['--bounded-request', f"/repos/szTheory/sigra/actions/runs/{row['run_id']}/attempts/{row['run_attempt']}", '--output', str(output)]
                if call(contract, frozen_hash, args, output.with_suffix('.log'), budget=budget, network=True):
                    raise ValueError('watch_failed_no_replacement')
                due[role] = time.monotonic() + 60; observation = load(output)
                registered = next(record for record in load(REGISTRATIONS)['records'] if record['reservation_id'] == row['reservation_id'])
                if validate_registered_run_observation(registered, observation):
                    raise ValueError('registered_attempt_identity_changed')
                event('status', reservation_id=row['reservation_id'], status=observation['status'], conclusion=observation.get('conclusion'))
                if observation['status'] == 'completed':
                    completed[role] = observation
            if len(completed) != 2:
                time.sleep(min(60, max(0.1, min(due[role] for role in due if role not in completed) - time.monotonic())))
        captures = {}; errors = []
        for row in rows:
            role = row['family_role']; capture = directory / ('raw-' + role); captures[role] = capture
            args = ['--collect-comparison', '--comparison-role', role, '--reservation-id', row['reservation_id'],
                    '--registrations', str(REGISTRATIONS), '--source-bundle', str(capture)]
            try:
                if call(contract, frozen_hash, args, directory / f'{role}.collect.log', budget=budget, network=True):
                    errors.append(role + ':collection_failed')
            except Exception as error:
                errors.append(role + ':collection_blocked:' + str(error))
        ledger = _comparison_budget_read(budget, contract)
        if not any(row.get('stop_reason') for row in ledger['records']):
            comparison_request_budget_record_response(contract, budget, stop_reason='pair_collection_complete')
        receipts = {}
        for row in rows:
            role = row['family_role']
            if captures[role].is_dir():
                receipts[role] = preserve(captures[role], row, budget)
            else:
                errors.append(role + ':capture_missing')
            if completed[role].get('conclusion') != 'success':
                errors.append(role + ':' + str(completed[role].get('conclusion')))
        if errors:
            raise ValueError('pair_stopped_after_retention:' + ','.join(errors))
        pair_check(contract, frozen_hash, captures, directory)
        for row in rows:
            role = row['family_role']; source = contract['baseline_application_sha'] if role == 'before' else contract['candidate_identity']['application_sha']
            verify_durable_attempt_capture(load(receipts[role]), ROOT, row['run_id'], row['run_attempt'], source)
            if verify_snapshot_hashes(captures[role]):
                raise ValueError('retained_snapshot_hash_failed')
            previous[role] = receipts[role]
            indexes[role].append({'path': str(captures[role]), 'manifest_sha256': digest(captures[role] / 'manifest.json')})
        event('pair_complete', pair_id=item['pair_id'], measured_samples=registration_count())
    assembled = SCOPE / 'assembled'; assembled.mkdir()
    for role, rows in indexes.items():
        index_path = SCOPE / f'INDEX-{role}.json'; write(index_path, rows)
        args = ['--assemble-comparison', '--source-pages', str(index_path), '--source-bundle', str(assembled / role)]
        if call(contract, frozen_hash, args, SCOPE / f'ASSEMBLE-{role}.log'):
            raise ValueError('offline_assembly_failed')
    args = ['--evaluate-comparison', '--before-bundle', str(assembled / 'before'), '--after-bundle', str(assembled / 'after'),
            '--baseline-source-bundle', str(BASELINE), '--registrations', str(REGISTRATIONS), '--format', 'json']
    if call(contract, frozen_hash, args, SCOPE / 'RESULT.json'):
        raise ValueError('final_offline_evaluation_failed')
    event('finished', measured_samples=registration_count(), result_status=load(SCOPE / 'RESULT.json')['status'])


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check-only', action='store_true'); args = parser.parse_args()
    os.chdir(ROOT); owned_events = False
    try:
        contract, previous = check()
        if args.check_only:
            print(json.dumps({'status': 'offline_preflight_passed', 'pairs': 20, 'measured_samples': 0})); return 0
        with EVENTS.open('x'):
            owned_events = True
        execute(contract, previous); return 0
    except Exception as error:
        if owned_events:
            event('stopped', diagnostic=str(error), measured_samples=registration_count(), automatic_resume=False)
        else:
            print(json.dumps({'status': 'preflight_failed', 'diagnostic': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
