"""Read retained native reports and server flow independently; never execute runtime work."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def rows(report):
    found = []
    def walk(suite):
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                found.append((spec, test))
        for child in suite.get('suites', []):
            walk(child)
    walk(report)
    return found


def review():
    proposal = read(HERE/'proposal.json')
    approval = read(HERE/'approval.json')
    reservation = read(HERE/'reservation.json')
    result = read(HERE/'runtime-output/result.json')
    assert approval['proposal_sha256'] == reservation['proposal_sha256'] == sha(HERE/'proposal.json')
    assert approval['source'] == result['source'] == proposal['source']
    assert result['status'] == 'nine_targeted_passes_integration_and_phase_verification_pending'
    assert result['within_limit'] is True and result['duration_seconds'] <= 1200
    assert result['browser_invocations'] == len(result['cases']) == len(proposal['cases']) == 9
    assert result['ci_launches'] == result['github_requests'] == result['old_slots_reopened'] == 0
    reports = []
    containers = []
    for index, (case, expected) in enumerate(zip(result['cases'], proposal['cases']), 1):
        out = HERE/'runtime-output'/str(index)
        assert case['project'] == expected['project'] and case['repeat'] == expected['repeat']
        assert case['status'] == 'passed' and case['cleanup_complete'] is True
        assert case['container_exit'] == 0 and case['browser_invocations'] == 1 and not case['cleanup_errors']
        assert case['postgres_version'].startswith('postgres (PostgreSQL) 15.19 ')
        containers.extend(case['containers'])
        report, tools, container = read(out/'browser.json'), read(out/'tools.json'), read(out/'result.json')
        assert not report.get('errors')
        assert report['stats']['expected'] == 1 and all(report['stats'][k] == 0 for k in ['skipped','unexpected','flaky'])
        native = rows(report)
        assert len(native) == 1
        spec, test = native[0]
        assert spec['title'] == proposal['title'] and test['projectName'] == case['project']
        assert test['expectedStatus'] == 'passed' and test['status'] == 'expected'
        assert len(test['results']) == 1 and test['results'][0]['status'] == 'passed' and test['results'][0]['retry'] == 0
        assert tools['source'] == proposal['source'] == container['source']
        assert tools['source_manifest_sha256'] == sha(HERE/'source-manifest.json')
        assert tools['endpoint']['reloader_calls'] == [] and tools['endpoint']['live_reload_socket'] is False
        assert tools['endpoint']['liveview_socket_retained'] is True
        assert container['browser_invocations'] == 1 and container['warmup_status'] == 302
        assert container['outcome'] == 'browser_passed_pending_host_validation' and container['browser_exit'] == 0
        log = re.sub(r'\x1b\[[0-9;]*m', '', (out/'app.log').read_text())
        flow = dict(registration_save=len(re.findall(r'HANDLE EVENT "save"', log)),
                    user_insert=len(re.findall(r'INSERT INTO "auth"\."users"', log)),
                    login_post=len(re.findall(r'POST /users/log_in', log)),
                    original_module_error=log.count('function Ecto.Queryable.to_query/1 is undefined'))
        assert flow == dict(registration_save=1,user_insert=1,login_post=1,original_module_error=0), flow
        reports.append(dict(case=index,project=case['project'],repeat=case['repeat'],title=spec['title'],
                            status='passed',retry=0,duration_ms=test['results'][0]['duration'],
                            registration_flow=flow,browser_json_sha256=sha(out/'browser.json'),
                            tools_json_sha256=sha(out/'tools.json'),app_log_sha256=sha(out/'app.log')))
    assert len(containers) == len(set(containers)) == 18, 'containers were reused'
    assert not subprocess.check_output(['docker','ps','-aq','--filter','label=sigra.phase253=registration-postfix']).strip()
    return dict(status='nine_fresh_targeted_runs_passed',source=proposal['source'],image_id=proposal['image_id'],
                proposal_sha256=sha(HERE/'proposal.json'),approval_sha256=sha(HERE/'approval.json'),
                reservation_sha256=sha(HERE/'reservation.json'),native_result_sha256=sha(HERE/'runtime-output/result.json'),
                cases=reports,selected_tests_passed=9,retries=0,skips=0,
                duration_seconds=result['duration_seconds'],cleanup_complete=True,distinct_owned_containers=18,
                ci_launches=0,github_requests=0,old_slots_reopened=0,
                original_postfix_slots_still_expired=9,approval_scope_complete=True,additional_native_authorized=False,
                CIREL_01='targeted_postfix_validation_passed_integration_and_phase_review_pending',
                CIREL_02='complete_unchanged',phase_complete=False,
                remaining=['normal integration selections on candidate source',
                           'review remaining CIREL-01 deterministic controls and canonical phase verification'],
                limitations=proposal['limitations'])


if __name__ == '__main__':
    print(json.dumps(review(),indent=2))
