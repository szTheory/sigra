"""Reopen completed R4/R5 controls and compare their actual inputs with the fix."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
SOURCE = 'a876647338095b6d280608cb75bcf886ab1da953'
CRITICAL = [
    'test/example/priv/playwright/tests/admin-eval.spec.ts',
    'test/example/priv/playwright/helpers/registrationControls.mjs',
    'test/example/priv/playwright/helpers/adminFlows.ts',
    'test/example/priv/playwright/playwright.registration-recovery.config.ts',
    'test/example/lib/example_web/live/registration_live.ex',
    'test/example/lib/example/accounts.ex',
    'test/example/lib/example/accounts/user.ex',
    'lib/sigra/auth.ex',
    'test/example/priv/playwright/package-lock.json', 'test/example/mix.lock',
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def native_rows(report):
    rows = []
    def visit(suite):
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                rows.append(dict(title=spec['title'], project=test['projectName'],
                    expected_status=test['expectedStatus'], status=test['status'],
                    results=[dict(status=r['status'], retry=r['retry']) for r in test['results']]))
        for child in suite.get('suites', []):
            visit(child)
    visit(report)
    return rows


def audit():
    r5_path = BASE / '253-LOAD-RECOVERY-NATIVE-EVIDENCE-R5.json'
    r5 = json.loads(r5_path.read_text())
    command = ['node','scripts/ci/ci-registration-recovery.mjs','--verify-load-recovery',str(r5_path.relative_to(ROOT)),'--stage','complete']
    verifier = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
    assert verifier.returncode == 0, verifier.stderr
    binding = r5['carried_first_window']
    raw = git('show',binding['revision_commit'] + ':' + binding['evidence_path'])
    assert sha(raw) == binding['revision_sha256']
    preserved_r4 = json.loads(raw)
    first = preserved_r4['attempts'][0]
    assert first['observed_outcome'] == 'native_rows_accepted'
    attempts = [(first, ROOT / (binding['evidence_path'] + '.raw'))] + [
        (attempt, Path(str(r5_path) + '.raw')) for attempt in r5['attempts']]
    sources = {attempt['source_commit'] for attempt,_ in attempts}
    compared = []
    for source in sorted(sources):
        for name in CRITICAL:
            before = git('show',source + ':' + name)
            assert before == git('show',SOURCE + ':' + name) == (ROOT / name).read_bytes(), name
            compared.append(dict(source=source,path=name,sha256=sha(before),unchanged=True))
    rows, traces, receipts = [], [], []
    for attempt, raw_dir in attempts:
        report_ref = attempt['files'].get('native_json') or attempt['files'].get('playwright_report')
        assert report_ref, 'native browser report reference missing'
        report_path = raw_dir / report_ref['path']
        report_bytes = report_path.read_bytes()
        assert sha(report_bytes) == report_ref['sha256']
        actual = native_rows(json.loads(report_bytes))
        for row in actual:
            assert len(row['results']) == 1 and row['results'][0]['retry'] == 0
            deliberate = row['title'] in [
                'registration stops when LiveView readiness is never released',
                'registration fails when the readiness wait is deliberately broken',
                'registration retains the first forced assertion failure trace']
            assert row['results'][0]['status'] == ('failed' if deliberate else 'passed')
            row['deliberate_failure'] = deliberate
        rows.extend(actual)
        for trace in attempt.get('traces', []):
            assert sha((raw_dir / trace['path']).read_bytes()) == trace['sha256']
            assert trace['sanitization']['navigation'] and trace['sanitization']['submission']
            traces.append(dict(project=trace['project'],title=trace['title'],sha256=trace['sha256']))
        if attempt['stage'] == 'second':
            assert attempt['prior_collision_absence']['count'] == 0
            assert attempt['created_account']['count'] == 1
            assert not attempt['traces']
            receipts.append(dict(project=attempt['project'],database=attempt['database']['name'],
                before=0,after=1,account_sha256=attempt['created_account']['account_email_sha256']))
        assert attempt['database']['absence_receipt']['stdout_count'] == 0
    assert len(rows) == 22 and sum(r['deliberate_failure'] for r in rows) == len(traces) == 9
    assert len(receipts) == len({r['database'] for r in receipts}) == 3
    return dict(status='completed_controls_reverified_no_new_runtime_needed', source=SOURCE,
        verifier_command=command,verifier_exit=0,verifier_stdout=verifier.stdout.strip(),
        evidence=str(r5_path.relative_to(ROOT)),evidence_sha256=sha(r5_path.read_bytes()),
        carried_first_revision=binding['revision_commit'],source_comparisons=compared,
        rows=rows,total=22,positive_rows=13,deliberate_negative_rows=9,
        retained_failure_traces=traces,passing_second_windows=receipts,
        runtime_changes_reviewed=['CI hot reloading disabled; fresh targeted/integration results cover the changed server',
            'HTML report moved below playwright-report/html; control source, assertions and trace policy unchanged'],
        current_turn=dict(browser_invocations=0,app_starts=0,database_starts=0,ci_launches=0,github_requests=0),
        historical_halts_unchanged=True,old_allowances_reopened=False)


if __name__ == '__main__':
    print(json.dumps(audit(),indent=2))
