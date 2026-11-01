#!/usr/bin/env python3
"""Single owner for the two approved preparation runs; no trigger or retry path."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
SCOPE = Path(__file__).resolve().parent
METRICS = ROOT / 'scripts/ci/ci-run-metrics.sh'
CONTRACT = SCOPE / 'CONTRACT.json'
BUDGET = SCOPE / 'REQUEST-BUDGET.json'
RUNS = json.loads((SCOPE / 'RUNS.json').read_text())


def event(kind, **values):
    row = {'at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'kind': kind, **values}
    with (SCOPE / 'WATCH.jsonl').open('a') as out:
        out.write(json.dumps(row, sort_keys=True) + '\n')
        out.flush()
        os.fsync(out.fileno())
    print(json.dumps(row, sort_keys=True), flush=True)


def call(args, log):
    with log.open('x') as out:
        return subprocess.run(['bash', str(METRICS), *args, '--contract', str(CONTRACT),
            '--request-budget-ledger', str(BUDGET)], cwd=ROOT, stdout=out, stderr=subprocess.STDOUT).returncode


def preserve(role, attempt):
    # A separate index writes a recoverable ref without changing the working index or branch.
    relative = SCOPE.relative_to(ROOT).as_posix()
    files = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in SCOPE.rglob('*') if p.is_file() and not p.is_symlink()}
    with tempfile.TemporaryDirectory(prefix='sigra254-preserve-') as temp:
        env = {**os.environ, 'GIT_INDEX_FILE': str(Path(temp) / 'index')}
        def git(*args, **kwargs):
            return subprocess.check_output(['git', *args], cwd=ROOT, env=env, **kwargs)
        parent = git('rev-parse', 'HEAD').decode().strip()
        git('read-tree', parent)
        git('add', '--', relative)
        tree = git('write-tree').decode().strip()
        commit = git('commit-tree', tree, '-p', parent,
            input=f'preserve(254): {role} preparation attempt {attempt}\n'.encode()).decode().strip()
        ref = f'refs/evidence/phase254-parity-preparation-{role}-attempt-{attempt}'
        git('update-ref', ref, commit, '0' * 40)
        for name, digest in files.items():
            if hashlib.sha256(git('show', f'{ref}:{name}')).hexdigest() != digest:
                raise RuntimeError('preservation_readback_failed:' + name)
    receipt = {'ref': ref, 'commit': commit, 'files': files, 'readback_verified': True}
    (SCOPE / f'PRESERVATION-{role}.json').write_text(json.dumps(receipt, indent=2) + '\n')
    event('preserved', role=role, ref=ref, commit=commit, files=len(files))


def main():
    if (SCOPE / 'WATCH.jsonl').exists():
        raise RuntimeError('watch_already_started_no_automatic_restart')
    event('started', runs=[{'role': r, 'run_id': i, 'attempt': a} for r, i, a, _ in RUNS])
    completed = set()
    # The last root reads preceded this handoff. Respect one read per run per minute.
    next_poll = time.monotonic() + 60
    sequence = 0
    while len(completed) < len(RUNS):
        remaining = json.loads(BUDGET.read_text())['started_at_epoch'] + 3600 - time.time()
        if remaining <= 0:
            event('stopped', reason='approved_preparation_time_limit', completed=sorted(completed))
            return 2
        delay = min(max(0, next_poll-time.monotonic()), remaining)
        if delay:
            time.sleep(min(delay, 60))
            continue
        sequence += 1
        for role, run_id, attempt, early in RUNS:
            if role in completed:
                continue
            output = SCOPE / f'WATCH-{role}-{sequence:02d}.json'
            rc = call(['--bounded-request', f'/repos/szTheory/sigra/actions/runs/{run_id}/attempts/{attempt}',
                       '--output', str(output)], SCOPE / f'WATCH-{role}-{sequence:02d}.log')
            if rc:
                event('stopped', reason='bounded_status_request_failed', role=role, log=f'WATCH-{role}-{sequence:02d}.log')
                return 2
            run = json.loads(output.read_text())
            event('status', role=role, run_id=run_id, attempt=attempt,
                  status=run['status'], conclusion=run.get('conclusion'))
            if run['status'] != 'completed':
                continue
            # This is the only completed-run summary fetch. The collector retains raw inputs next.
            destination = SCOPE / f'RAW-{role}'
            rc = call(['--collect-preparation', '--comparison-role', role, '--run-json', str(SCOPE / early),
                       '--source-bundle', str(destination)], SCOPE / f'COLLECT-{role}.log')
            event('captured', role=role, collection_exit_code=rc, source_bundle=str(destination.relative_to(ROOT)))
            preserve(role, attempt)
            completed.add(role)
        next_poll = time.monotonic() + 60
    event('finished', completed=sorted(completed), measured_samples=0)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
