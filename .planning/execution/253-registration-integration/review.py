"""Independent read-only review of actual native reports, server logs and cleanup."""
import hashlib
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_tests(report):
    tests = []
    def visit(suite, parents):
        titles = parents + ([suite['title']] if suite.get('title') else [])
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                tests.append((dict(file=spec['file'], line=spec['line'], title=titles + [spec['title']],
                    project=test['projectName'], expected=test['expectedStatus']), test))
        for child in suite.get('suites', []):
            visit(child, titles)
    visit(report, [])
    return tests


def review():
    proposal = read(HERE / 'proposal.json')
    approval = read(HERE / 'approval.json')
    reservation = read(HERE / 'reservation.json')
    proposal_sha = sha(HERE / 'proposal.json')
    assert approval['proposal_sha256'] == reservation['proposal_sha256'] == proposal_sha
    assert approval['decision'] == 'approved' and approval['source'] == proposal['source']
    assert approval['scope'] == 'five-fresh-local-linux-integration-groups'
    for name, expected in proposal['file_sha256'].items():
        assert sha(HERE / name) == expected, 'frozen input changed: ' + name
    driver = read(HERE / 'runtime-output/result.json')
    assert driver['source'] == proposal['source']
    assert driver['ci_launches'] == driver['github_requests'] == 0
    expected_groups = list(proposal['selections'])
    assert [g['seam'] for g in driver['groups']] == expected_groups
    assert driver['browser_invocations'] == len(expected_groups) == 5
    assert driver['within_limit'] and driver['duration_seconds'] <= proposal['limits']['seconds_including_cleanup']
    assert driver['status'] == 'five_integration_groups_passed_phase_review_pending'
    assert not driver['phase_complete']
    groups, containers = [], []
    for group in driver['groups']:
        seam = group['seam']
        out = HERE / 'runtime-output' / seam
        assert group['status'] == 'passed' and group['container_exit'] == 0
        assert group['cleanup_complete'] and not group['cleanup_errors']
        assert group['browser_invocations'] == 1 and group['postgres_version'].startswith('postgres (PostgreSQL) 15.19 ')
        containers.extend(group['containers'])
        result = read(out / 'result.json')
        assert result['source'] == proposal['source'] and result['seam'] == seam
        assert result['status'] == 'passed' and result['browser_exit'] == 0 and result['browser_invocations'] == 1
        assert [w['path'] for w in result['warmups']] == proposal['warmup_paths']
        assert all(200 <= w['status'] < 400 for w in result['warmups'])
        tools = read(out / 'tools.json')
        assert tools['source'] == proposal['source'] and tools['otp'] == '28.5' and tools['playwright'] == '1.59.1'
        assert tools['endpoint']['reloader_calls'] == [] and not tools['endpoint']['live_reload_socket']
        assert tools['endpoint']['liveview_socket_retained']
        report = read(out / 'browser.json')
        assert not report.get('errors')
        assert report['config']['workers'] == 1 and not report['config']['fullyParallel']
        selected = native_tests(report)
        assert [identity for identity, _ in selected] == proposal['inventory'][seam]
        for identity, test in selected:
            assert identity['expected'] == 'passed' and test['status'] == 'expected'
            assert len(test['results']) == 1
            assert test['results'][0]['status'] == 'passed' and test['results'][0]['retry'] == 0
        assert report['stats']['expected'] == len(selected)
        assert report['stats']['unexpected'] == report['stats']['flaky'] == report['stats']['skipped'] == 0
        app_log = (out / 'app.log').read_text(errors='replace')
        original_errors = app_log.count('function Ecto.Queryable.to_query/1 is undefined')
        assert original_errors == 0, 'original module error recurred'
        for name in group['containers']:
            assert name in (out / (name + '-cleanup.log')).read_text().splitlines()
        groups.append(dict(seam=seam, passed=len(selected), browser_invocations=1, retries=0, skips=0,
            duration_ms=report['stats']['duration'],
            original_module_errors=original_errors,
            registration_saves=app_log.count('HANDLE EVENT "save" in ExampleWeb.RegistrationLive'),
            account_inserts=app_log.count('INSERT INTO "auth"."users"'),
            login_posts=app_log.count('POST /users/log_in'),
            native_report_sha256=sha(out / 'browser.json'), server_log_sha256=sha(out / 'app.log'),
            tools_sha256=sha(out / 'tools.json'), container_result_sha256=sha(out / 'result.json')))
    assert len(containers) == len(set(containers)) == 10
    remaining = subprocess.check_output(['docker','ps','-aq','--filter','label=sigra.phase253=registration-integration'], text=True, timeout=10).strip()
    assert not remaining, 'owned containers remain'
    assert sum(g['passed'] for g in groups) == 108
    return dict(status='five_integration_groups_passed', source=proposal['source'],
        image_id=proposal['image_id'], postgres_image=proposal['postgres_image'],
        proposal_sha256=proposal_sha, approval_sha256=sha(HERE / 'approval.json'), reservation_sha256=sha(HERE / 'reservation.json'),
        driver_result_sha256=sha(HERE / 'runtime-output/result.json'),
        groups=groups, passed=108, browser_invocations=5, retries=0, skips=0,
        duration_seconds=driver['duration_seconds'], cleanup_complete=True, containers_removed=10,
        ci_launches=0, github_requests=0, allowance_consumed=True, phase_complete=False,
        remaining=['readiness/isolation/trace browser controls and review','canonical whole-phase verification'])


if __name__ == '__main__':
    print(json.dumps(review(), indent=2))
