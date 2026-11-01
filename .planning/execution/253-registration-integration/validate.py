"""Five finite fresh integration groups. Preflight has no runtime side effects."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from selection import SEAMS, check_report, digest, load, selections

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PRIOR = HERE.parent / '253-registration-postfix'


def preflight(inspect_images=True):
    proposal = load(HERE / 'proposal.json')
    for name, sha in proposal['file_sha256'].items():
        assert digest(HERE / name) == sha, 'sealed bundle changed: ' + name
    for name, sha in proposal['prior_bundle_sha256'].items():
        assert digest(PRIOR / name) == sha, 'candidate image metadata changed: ' + name
    assert digest(ROOT / '.github/workflows/ci.yml') == proposal['candidate_workflow_sha256']
    assert digest(ROOT / '.github/actions/example-playwright-boot/action.yml') == proposal['boot_action_sha256']
    assert proposal['selections'] == selections((ROOT / '.github/workflows/ci.yml').read_text())
    assert list(proposal['selections']) == SEAMS
    assert proposal['source'] == load(PRIOR / 'preparation.json')['source'] == load(HERE / 'collection.json')['source']
    assert proposal['image_id'] == load(PRIOR / 'preparation.json')['image_id']
    assert proposal['limits'] == dict(browser_invocations=5, seconds_including_cleanup=3600,
        per_group_seconds=1800, retries=0, stop_at_first_failure=True, github_requests=0, ci_launches=0, old_slots_reopened=0)
    for seam in SEAMS:
        check_report(load(HERE / 'collection.json')['reports'][seam], proposal['inventory'][seam], collection=True)
    if inspect_images:
        for identity in [proposal['image_id'], proposal['postgres_image']]:
            record = json.loads(subprocess.check_output(['docker','image','inspect',identity], timeout=15))[0]
            assert record['Architecture'] == 'amd64' and record['Os'] == 'linux'
    return proposal


def authorize(proposal):
    assert (HERE / 'approval.json').exists(), 'STOP: offline-only scope; five-group integration proposal is not approved'
    approval = load(HERE / 'approval.json')
    assert approval['decision'] == 'approved'
    assert approval['proposal_sha256'] == digest(HERE / 'proposal.json'), 'approval names another proposal'
    assert approval['source'] == proposal['source']
    assert approval['scope'] == 'five-fresh-local-linux-integration-groups'


def execute():
    proposal = preflight()
    authorize(proposal)
    with (HERE / 'reservation.json').open('x') as stream:
        stream.write(json.dumps(dict(proposal_sha256=digest(HERE / 'proposal.json'), started_at=time.time())) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    output = HERE / 'runtime-output'
    output.mkdir(exist_ok=False)
    start = time.monotonic()
    deadline = start + proposal['limits']['seconds_including_cleanup']
    result = dict(source=proposal['source'], status='stopped', groups=[], browser_invocations=0,
                  ci_launches=0, github_requests=0, phase_complete=False)
    try:
        for seam in SEAMS:
            assert time.monotonic() < deadline - 300, 'insufficient total time for another setup/cleanup'
            group_deadline = min(deadline, time.monotonic() + proposal['limits']['per_group_seconds'])
            out = output / seam
            out.mkdir()
            prefix = 'sigra253-integration-' + str(time.time_ns())
            pg, app = prefix + '-pg', prefix + '-app'
            record = dict(seam=seam, containers=[pg,app], status='stopped', cleanup_complete=False)
            result['groups'].append(record)
            try:
                subprocess.run(['docker','run','--pull=never','-d','--name',pg,'--platform=linux/amd64',
                    '--network=none','--label','sigra.phase253=registration-integration',
                    '--env','POSTGRES_PASSWORD=postgres','--env','POSTGRES_INITDB_ARGS=--encoding=UTF8',
                    proposal['postgres_image']], check=True, capture_output=True, timeout=20)
                ready_deadline = min(time.monotonic()+90, group_deadline-60)
                while True:
                    ready = subprocess.run(['docker','exec',pg,'pg_isready','-h','127.0.0.1','-U','postgres'], capture_output=True, timeout=5)
                    if ready.returncode == 0:
                        break
                    assert time.monotonic() < ready_deadline, 'database readiness deadline exceeded'
                    time.sleep(.25)
                version = subprocess.check_output(['docker','exec',pg,'postgres','--version'], text=True, timeout=5).strip()
                assert version.startswith('postgres (PostgreSQL) 15.19 ')
                record['postgres_version'] = version
                with (out / 'container.log').open('wb') as log:
                    proc = subprocess.run(['docker','run','--pull=never','--name',app,'--init','--platform=linux/amd64',
                        '--network=container:' + pg,'--cpuset-cpus=0-3','--cpus=4','--shm-size=1g',
                        '--label','sigra.phase253=registration-integration',
                        '--mount','type=bind,src=' + str(out) + ',dst=/evidence',
                        '--mount','type=bind,src=' + str(HERE) + ',dst=/integration,readonly',
                        '--entrypoint','python3',proposal['image_id'],'/integration/in_container.py','--run',seam],
                        stdout=log, stderr=subprocess.STDOUT, timeout=max(1,group_deadline-time.monotonic()-40))
                record['container_exit'] = proc.returncode
                assert proc.returncode == 0, 'integration group failed'
                check_report(load(out / 'browser.json'), proposal['inventory'][seam])
                log = (out / 'app.log').read_text(errors='replace')
                assert 'function Ecto.Queryable.to_query/1 is undefined' not in log, 'original module error recurred'
                record['status'] = 'passed'
            finally:
                record['browser_invocations'] = int((out / 'browser-started.json').exists())
                result['browser_invocations'] += record['browser_invocations']
                record['cleanup_errors'] = []
                for name in [app,pg]:
                    try:
                        with (out / (name + '-cleanup.log')).open('wb') as log:
                            subprocess.run(['docker','rm','-f','-v',name], stdout=log, stderr=subprocess.STDOUT, timeout=12)
                    except Exception as error:
                        record['cleanup_errors'].append(str(error))
                record['cleanup_complete'] = not subprocess.check_output(['docker','ps','-aq','--filter','name=' + prefix], text=True, timeout=5).strip()
                assert record['cleanup_complete'], 'owned containers remain'
                assert time.monotonic() <= group_deadline, 'group limit exceeded'
        result['status'] = 'five_integration_groups_passed_phase_review_pending'
    except BaseException as error:
        result['error'] = str(error)
        raise
    finally:
        result['duration_seconds'] = time.monotonic() - start
        result['within_limit'] = time.monotonic() <= deadline
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    assert result['within_limit'], 'total limit exceeded'


if __name__ == '__main__':
    assert len(sys.argv) == 2 and sys.argv[1] in ['--preflight','--run']
    if sys.argv[1] == '--preflight':
        proposal = preflight()
        print(json.dumps(dict(status='preflight_passed', counts={k:len(v) for k,v in proposal['inventory'].items()},
            browser_invocations=0, runtime_approved=(HERE / 'approval.json').exists())))
    else:
        execute()
