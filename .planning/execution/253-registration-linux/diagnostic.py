"""One separately approved Linux development diagnostic. Never reopens old slots."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

if not __debug__:
    raise RuntimeError('Python optimization disables required checks; run without -O or PYTHONOPTIMIZE')

HERE = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def selection(report):
    rows = []
    def walk(suite):
        for spec in suite.get('specs', []):
            for test in spec.get('tests', []):
                rows.append((spec['title'], test['projectName']))
        for child in suite.get('suites', []):
            walk(child)
    walk(report)
    return rows


def preflight():
    prep = json.loads((HERE / 'preparation.json').read_text())
    original_environment = json.loads((HERE / 'original-environment.json').read_text())
    assert prep['postgres'].split('@')[1] == original_environment['postgres_image'].split('@')[1], 'database image differs from archived original digest'
    assert digest(HERE / 'Dockerfile') == prep['dockerfile_sha256'], 'Dockerfile changed after build'
    assert digest(HERE / 'in_container.py') == prep['container_runner_sha256'], 'container runner changed after build'
    assert digest(HERE / 'inspect.json') == prep['inspect_sha256'], 'inspection changed'
    inspect = json.loads((HERE / 'inspect.json').read_text())
    recovered = json.loads((HERE.parent / '253-registration-order-recovery/recovered-order.json').read_text())
    expected = [(row['title'].split(' › ')[-1], row['project']) for row in recovered['native_rows'][:161]]
    assert selection(inspect['collection']) == expected, 'test order differs from original 161-test prefix'
    assert prep['source'] == inspect['source'] == recovered['source_commit'], 'source differs'
    assert inspect['collection']['stats']['expected'] == 0, 'collection is not an execution'
    image = json.loads(subprocess.check_output(['docker', 'image', 'inspect', prep['image_id']]))[0]
    assert image['Architecture'] == 'amd64' and image['Os'] == 'linux', 'wrong image platform'
    assert 'Ubuntu' in inspect['os_release'] and '24.04' in inspect['os_release'], 'wrong Ubuntu version'
    assert 'Mix 1.19.5' in inspect['mix'], 'wrong Mix version'
    assert inspect['otp'] == '28.5', 'wrong Erlang/OTP version'
    return prep


def authorize(proposal, approval):
    assert approval['decision'] == 'approved', 'new diagnostic approval required'
    assert approval['proposal_sha256'] == digest(HERE / 'proposal.json'), 'approval does not match proposal'
    for name, sha in proposal['file_sha256'].items():
        assert digest(HERE / name) == sha, 'approved file changed: ' + name


def classify_browser(report, expected):
    actual = selection(report)
    assert not report.get('errors'), 'browser reporter contains global errors'
    assert actual == expected[:len(actual)] and actual, 'native result order differs'
    tests = []
    def walk(suite):
        for spec in suite.get('specs', []):
            tests.extend(spec.get('tests', []))
        for child in suite.get('suites', []):
            walk(child)
    walk(report)
    failures = []
    for i, test in enumerate(tests):
        results = test.get('results', [])
        assert len(results) == 1 and results[0]['retry'] == 0, 'retries, missing result or duplicate execution'
        assert test['expectedStatus'] == 'passed', 'changed expected status'
        if results[0]['status'] != 'passed':
            failures.append(i)
    if not failures:
        assert len(tests) == 161, 'incomplete passing selection'
        return 'not_reproduced'
    if failures == [160] and len(tests) == 161 and tests[160]['results'][0]['status'] in ('failed', 'timedOut'):
        errors = tests[160]['results'][0].get('errors', [])
        signature = ['page.waitForURL: Timeout 10000ms exceeded.', 'registration diagnostics=',
                     '"registrationRequest":null', '"registrationPost":null', '"registrationRequestFailure":null']
        if any(all(part in error.get('message', '') for part in signature) for error in errors):
            return 'selected_failure_reproduced_cause_unproved'
    return 'other_failure_needs_diagnosis'


def execute(setup_only=False):
    prep = preflight()
    if not setup_only:
        proposal = json.loads((HERE / 'proposal.json').read_text())
        assert (HERE / 'approval.json').exists(), 'STOP: this new diagnostic needs its own approval; old approvals remain spent'
        authorize(proposal, json.loads((HERE / 'approval.json').read_text()))
        # Exclusive creation happens before any container or database allocation.
        with (HERE / 'reservation.json').open('x') as marker:
            marker.write(json.dumps({'started_at': time.time(), 'proposal_sha256': digest(HERE / 'proposal.json')}) + '\n')
    kind = 'setup' if setup_only else 'diagnostic'
    output = HERE / (kind + '-output')
    output.mkdir(exist_ok=False)
    prefix = 'sigra253-linux-' + str(time.time_ns())
    pg, app = prefix + '-pg', prefix + '-app'
    start = time.monotonic()
    limit = 360 if setup_only else proposal['limits']['seconds_including_cleanup']
    result = dict(kind=kind, acceptance=False, browser_invocations=0, github_requests=0, ci_launches=0,
                  old_slots_reopened=0, status='stopped', container_names=[pg, app], cleanup_complete=False,
                  image_id=prep['image_id'], postgres_image=prep['postgres'])
    try:
        subprocess.run(['docker', 'run', '-d', '--name', pg, '--platform=linux/amd64', '--network=none',
            '--label', 'sigra.phase253=registration-linux-diagnostic', '--env', 'POSTGRES_PASSWORD=postgres',
            '--env', 'POSTGRES_INITDB_ARGS=--encoding=UTF8', prep['postgres']], check=True, capture_output=True, timeout=30)
        ready_deadline = time.monotonic() + 90
        while True:
            ready = subprocess.run(['docker', 'exec', pg, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'], capture_output=True, timeout=5)
            if ready.returncode == 0:
                break
            if time.monotonic() >= ready_deadline:
                raise TimeoutError('PostgreSQL readiness deadline exceeded')
            time.sleep(.25)
        version = subprocess.check_output(['docker', 'exec', pg, 'postgres', '--version'], text=True, timeout=10).strip()
        assert version.startswith('postgres (PostgreSQL) 15.19 '), 'PostgreSQL version differs: ' + version
        result['postgres_version'] = version
        with (output / 'container.log').open('wb') as log:
            proc = subprocess.run(['docker', 'run', '--name', app, '--init', '--platform=linux/amd64',
                '--network=container:' + pg, '--cpuset-cpus=0-3', '--cpus=4', '--shm-size=1g',
                '--label', 'sigra.phase253=registration-linux-diagnostic',
                '--mount', 'type=bind,src=' + str(output) + ',dst=/evidence', prep['image_id'],
                '--setup-only' if setup_only else '--run'], stdout=log, stderr=subprocess.STDOUT,
                timeout=max(1, limit - 40 - (time.monotonic() - start)))
        result['container_exit'] = proc.returncode
        result['status'] = 'container_finished' if proc.returncode == 0 else 'container_failed'
    except (Exception, KeyboardInterrupt) as error:
        result['error'] = str(error)
        raise
    finally:
        for name in [app, pg]:
            with (output / (name + '-cleanup.log')).open('wb') as log:
                subprocess.run(['docker', 'rm', '-f', '-v', name], stdout=log, stderr=subprocess.STDOUT, timeout=15)
        remaining = subprocess.check_output(['docker', 'ps', '-aq', '--filter', 'name=' + prefix], text=True, timeout=10).strip()
        result['cleanup_complete'] = not remaining
        result['duration_seconds'] = time.monotonic() - start
        result['browser_invocations'] = int((output / 'browser-started.json').exists())
        if (output / 'browser.json').exists():
            try:
                original = json.loads((HERE / 'inspect.json').read_text())['collection']
                result['native_verdict'] = classify_browser(json.loads((output / 'browser.json').read_text()), selection(original))
            except Exception as error:
                result['native_verdict'] = 'unusable_native_report'
                result['native_report_error'] = str(error)
        result['within_limit'] = result['duration_seconds'] <= limit
        (output / 'host-result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
        assert result['cleanup_complete'], 'owned containers were not removed'
    assert result.get('container_exit') == 0 and result['within_limit'], 'diagnostic failed; inspect retained result'


if __name__ == '__main__':
    assert len(sys.argv) == 2 and sys.argv[1] in ('--preflight', '--setup-only', '--run'), 'choose --preflight, --setup-only or --run'
    if sys.argv[1] == '--preflight':
        prep = preflight()
        print(json.dumps({'status': 'preflight_passed', 'selected_tests': 161, 'image_id': prep['image_id'], 'browser_invocations': 0}))
    else:
        execute(setup_only=sys.argv[1] == '--setup-only')
