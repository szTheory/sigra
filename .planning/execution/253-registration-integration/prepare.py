"""List tests in a network-isolated unit container; no browser/app/DB starts."""
import json
from pathlib import Path
import subprocess
import time
from selection import digest, identities, selections

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PRIOR = HERE.parent / '253-registration-postfix'


def main():
    assert not (HERE / 'collection.json').exists(), 'retain the original collection'
    previous = json.loads((PRIOR / 'proposal.json').read_text())
    for name in ['.github/workflows/ci.yml', '.github/actions/example-playwright-boot/action.yml']:
        assert (ROOT / name).read_bytes() == subprocess.check_output(['git','show',previous['source'] + ':' + name], cwd=ROOT)
    name = 'sigra253-integration-collect-' + str(time.time_ns())
    try:
        with (HERE / 'collection.json').open('xb') as stdout, (HERE / 'collection.stderr').open('xb') as stderr:
            proc = subprocess.run(['docker','run','--pull=never','--name',name,'--network=none',
                '--platform=linux/amd64','--cpus=4','--cpuset-cpus=0-3',
                '--mount','type=bind,src=' + str(HERE) + ',dst=/integration,readonly',
                '--entrypoint','python3',previous['image_id'],'/integration/in_container.py','--collect'],
                stdout=stdout, stderr=stderr, timeout=300)
        assert proc.returncode == 0, 'collection failed; retain diagnostics'
    finally:
        subprocess.run(['docker','rm','-f','-v',name], capture_output=True, check=True, timeout=15)
        assert not subprocess.check_output(['docker','ps','-aq','--filter','name=' + name], text=True, timeout=5).strip()
    report = json.loads((HERE / 'collection.json').read_text())
    assert report['source'] == previous['source']
    assert report['selections'] == selections((ROOT / '.github/workflows/ci.yml').read_text())
    inventory = {seam:identities(native) for seam,native in report['reports'].items()}
    action = (ROOT / '.github/actions/example-playwright-boot/action.yml').read_text()
    import re
    warmups = re.search(r'  warmup-paths:\n.*?    default: (.*)', action, re.S)[1].splitlines()[0].split()
    proposal = dict(schema='sigra.phase253.integration/v1', status='prepared_not_approved',
        source=previous['source'], image_id=previous['image_id'], postgres_image=previous['postgres_image'],
        selections=report['selections'], inventory=inventory, warmup_paths=warmups,
        limits=dict(browser_invocations=5, seconds_including_cleanup=3600, per_group_seconds=1800,
                    retries=0, stop_at_first_failure=True, github_requests=0, ci_launches=0, old_slots_reopened=0),
        approval_received=False, command='python3 .planning/execution/253-registration-integration/validate.py --run',
        file_sha256={n:digest(HERE / n) for n in ['selection.py','in_container.py','validate.py','test_validate.py','prepare.py','collection.json']},
        prior_bundle_sha256={n:digest(PRIOR / n) for n in ['source-manifest.json','preparation.json','inspect.json','in_container.py']},
        candidate_workflow_sha256=digest(ROOT / '.github/workflows/ci.yml'),
        boot_action_sha256=digest(ROOT / '.github/actions/example-playwright-boot/action.yml'),
        limitations=['Local Linux x64 emulation on ARM with Erlang +JMsingle true; not a hosted PR run',
                     'PR behavior selections only; non-PR design screenshot matrix is outside this scope',
                     'Readiness/isolation browser controls and canonical phase review remain separate',
                     'Total deadline may stop later groups; no automatic extra time or retry'])
    (HERE / 'proposal.json').write_text(json.dumps(proposal, indent=2) + '\n')
    print(json.dumps(dict(status='prepared_not_approved',counts={k:len(v) for k,v in inventory.items()},
        browser_invocations=0,app_started=False,database_started=False,cleanup_complete=True)))


if __name__ == '__main__':
    main()
