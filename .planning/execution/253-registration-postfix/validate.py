"""Finite post-fix validation; --preflight is read-only and never starts containers."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
PROJECTS = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']
TITLE = 'render bundle: board-mg-9/populated'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((HERE / name).read_text())


def rows(report):
    result = []
    def walk(suite):
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                result.append((spec['title'], test['projectName'], test))
        for child in suite.get('suites', []):
            walk(child)
    walk(report)
    return result


def check_report(report, project, collection=False):
    assert not report.get('errors'), 'global native errors'
    selected = rows(report)
    assert [(t, p) for t, p, _ in selected] == [(TITLE, project)], 'wrong or incomplete native selection'
    test = selected[0][2]
    assert test['expectedStatus'] == 'passed', 'changed expected status'
    results = test.get('results', [])
    if collection:
        assert not results, 'collection unexpectedly contains execution results'
    else:
        assert len(results) == 1, 'missing result or duplicate execution'
        assert results[0]['retry'] == 0, 'browser retry'
        assert results[0]['status'] == 'passed', 'native test did not pass'
        assert test['status'] == 'expected', 'unexpected native outcome'


def preflight(inspect_image=True):
    proposal = read('proposal.json')
    for name, sha in proposal['file_sha256'].items():
        assert digest(HERE / name) == sha, 'sealed bundle changed: ' + name
    prep = read('preparation.json')
    tools = read('inspect.json')
    for name, sha in prep['files'].items():
        assert digest(HERE / name) == sha, 'image build input changed: ' + name
    assert proposal['source'] == prep['source'] == tools['source'] == read('source-manifest.json')['source']
    assert digest(HERE / 'source-manifest.json') == prep['source_manifest_sha256']
    assert digest(HERE / 'inspect.json') == prep['inspect_sha256']
    assert proposal['image_id'] == prep['image_id']
    assert proposal['cases'] == [{'project': p, 'repeat': n} for p in PROJECTS for n in [1,2,3]]
    assert proposal['limits'] == dict(browser_invocations=9, seconds_including_cleanup=1200,
                                    retries=0, stop_at_first_failure=True, github_requests=0,
                                    ci_launches=0, old_slots_reopened=0)
    for project in PROJECTS:
        check_report(tools['collection'][project], project, collection=True)
    if inspect_image:
        for identity in [prep['image_id'], prep['postgres_image']]:
            image = json.loads(subprocess.check_output(['docker','image','inspect',identity], timeout=15))[0]
            assert image['Architecture'] == 'amd64' and image['Os'] == 'linux'
    return proposal


def authorize(proposal):
    assert (HERE / 'approval.json').exists(), 'STOP: offline-only scope; new nine-run proposal is not approved'
    approval = read('approval.json')
    assert approval['decision'] == 'approved', 'new runtime approval required'
    assert approval['proposal_sha256'] == digest(HERE / 'proposal.json'), 'approval is for another proposal'
    assert approval['source'] == proposal['source'], 'approval is for another source'
    assert approval['scope'] == 'nine-fresh-local-linux-postfix-invocations', 'wrong approval scope'


def execute():
    proposal = preflight()
    authorize(proposal)
    # Spend this new scope before any app/database allocation. No --setup-only bypass.
    with (HERE / 'reservation.json').open('x') as stream:
        stream.write(json.dumps(dict(proposal_sha256=digest(HERE / 'proposal.json'), started_at=time.time())) + '\n')
        stream.flush()
        __import__('os').fsync(stream.fileno())
    output = HERE / 'runtime-output'
    output.mkdir(exist_ok=False)
    deadline = time.monotonic() + proposal['limits']['seconds_including_cleanup']
    result = dict(source=proposal['source'], status='stopped', cases=[], browser_invocations=0,
                  ci_launches=0, github_requests=0, old_slots_reopened=0, phase_complete=False)
    try:
        for index, case in enumerate(proposal['cases']):
            assert time.monotonic() < deadline - 60, 'remaining total time cannot cover another fresh setup/cleanup'
            out = output / str(index + 1)
            out.mkdir()
            prefix = 'sigra253-postfix-' + str(time.time_ns())
            pg, app = prefix + '-pg', prefix + '-app'
            record = dict(**case, containers=[pg, app], cleanup_complete=False)
            result['cases'].append(record)
            try:
                subprocess.run(['docker','run','--pull=never','-d','--name',pg,'--platform=linux/amd64',
                    '--network=none','--label','sigra.phase253=registration-postfix',
                    '--env','POSTGRES_PASSWORD=postgres','--env','POSTGRES_INITDB_ARGS=--encoding=UTF8',
                    proposal['postgres_image']], check=True, capture_output=True, timeout=20)
                ready_deadline = min(time.monotonic() + 90, deadline - 50)
                while True:
                    ready = subprocess.run(['docker','exec',pg,'pg_isready','-h','127.0.0.1','-U','postgres'], capture_output=True, timeout=5)
                    if ready.returncode == 0:
                        break
                    assert time.monotonic() < ready_deadline, 'fresh database readiness deadline exceeded'
                    time.sleep(.25)
                version = subprocess.check_output(['docker','exec',pg,'postgres','--version'], text=True, timeout=5).strip()
                assert version.startswith('postgres (PostgreSQL) 15.19 '), 'database version differs'
                record['postgres_version'] = version
                with (out / 'container.log').open('wb') as log:
                    proc = subprocess.run(['docker','run','--pull=never','--name',app,'--init','--platform=linux/amd64',
                        '--network=container:' + pg,'--cpuset-cpus=0-3','--cpus=4','--shm-size=1g',
                        '--label','sigra.phase253=registration-postfix',
                        '--mount','type=bind,src=' + str(out) + ',dst=/evidence',
                        proposal['image_id'],'--run',case['project']], stdout=log, stderr=subprocess.STDOUT,
                        timeout=max(1,min(300,deadline-time.monotonic()-40)))
                record['container_exit'] = proc.returncode
                assert proc.returncode == 0, 'candidate runtime failed'
                check_report(json.loads((out/'browser.json').read_text()),case['project'])
                log = (out/'app.log').read_text(errors='replace')
                assert 'function Ecto.Queryable.to_query/1 is undefined' not in log, 'original module error recurred'
                assert 'GenServer' not in log or 'terminating' not in log, 'server process terminated; inspect log'
                record['status'] = 'passed'
            finally:
                record['browser_invocations'] = int((out/'browser-started.json').exists())
                result['browser_invocations'] += record['browser_invocations']
                record['cleanup_errors'] = []
                for name in [app,pg]:
                    try:
                        with (out/(name+'-cleanup.log')).open('wb') as log:
                            subprocess.run(['docker','rm','-f','-v',name],stdout=log,stderr=subprocess.STDOUT,timeout=12)
                    except Exception as error:
                        record['cleanup_errors'].append(str(error))
                remaining = subprocess.check_output(['docker','ps','-aq','--filter','name='+prefix],text=True,timeout=5).strip()
                record['cleanup_complete'] = not remaining
                assert record['cleanup_complete'], 'owned containers remain'
        result['status'] = 'nine_targeted_passes_integration_and_phase_verification_pending'
    except BaseException as error:
        result['error'] = str(error)
        raise
    finally:
        result['duration_seconds'] = proposal['limits']['seconds_including_cleanup'] - (deadline-time.monotonic())
        result['within_limit'] = time.monotonic() <= deadline
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    assert result['within_limit'], 'total runtime limit exceeded'


if __name__ == '__main__':
    assert len(sys.argv) == 2 and sys.argv[1] in ['--preflight','--run']
    if sys.argv[1] == '--preflight':
        preflight()
        print(json.dumps(dict(status='preflight_passed', selected_tests=9, browser_invocations=0, runtime_approved=(HERE/'approval.json').exists())))
    else:
        execute()
