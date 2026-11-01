"""Run only frozen existing PR selections; candidate source remains unchanged."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

sys.path.insert(0, '/postfix')
import in_container as candidate
sys.path.insert(0, '/integration')
from selection import check_report, identities, load, selections

HERE = Path('/integration')
OUT = Path('/evidence')


def cli(args, collect=False):
    return ['node', 'node_modules/playwright/cli.js', 'test', *args,
            '--reporter=json', '--trace=retain-on-failure'] + (
            ['--list'] if collect else ['--max-failures=1', '--output=/evidence/test-results'])


def collect():
    tools = candidate.inspect()
    selection = selections((candidate.ROOT / '.github/workflows/ci.yml').read_text())
    reports = {}
    for seam, args in selection.items():
        report = json.loads(candidate.command(cli(args, True), candidate.PW, capture_output=True, text=True, timeout=60).stdout)
        check_report(report, identities(report), collection=True)
        reports[seam] = report
    return dict(source=tools['source'], tools={k:v for k,v in tools.items() if k != 'collection'},
                selections=selection, reports=reports, browser_invocations=0,
                app_started=False, database_started=False)


def run(seam):
    proposal = load(HERE / 'proposal.json')
    assert seam in proposal['selections']
    tools = candidate.inspect()
    assert tools['source'] == proposal['source']
    args = selections((candidate.ROOT / '.github/workflows/ci.yml').read_text())[seam]
    assert args == proposal['selections'][seam]
    app = None
    result = dict(source=tools['source'], seam=seam, status='stopped', browser_invocations=0)
    try:
        (OUT / 'tools.json').write_text(json.dumps(tools, indent=2) + '\n')
        with (OUT / 'setup.log').open('wb') as log:
            for cmd in [['mix','ecto.create'], ['mix','ecto.migrate'], ['mix','run','priv/repo/seeds.exs']]:
                candidate.command(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        with (OUT / 'app.log').open('wb') as log:
            app = subprocess.Popen(['mix','phx.server'], cwd=candidate.APP, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + 90
            while True:
                assert app.poll() is None, 'app exited before readiness'
                try:
                    if 200 <= candidate.http_status('http://localhost:4011/') < 400:
                        break
                except (OSError, TimeoutError):
                    pass
                assert time.monotonic() < deadline, 'app readiness timed out'
                time.sleep(.25)
            # Same route warmups as the ordinary composite action, following redirects.
            from urllib.request import urlopen
            warmups = []
            for path in proposal['warmup_paths']:
                with urlopen('http://localhost:4011' + path, timeout=15) as response:
                    assert 200 <= response.status < 400
                    warmups.append(dict(path=path, status=response.status))
            result['warmups'] = warmups
            (OUT / 'browser-started.json').write_text(json.dumps(dict(seam=seam, monotonic=time.monotonic())) + '\n')
            result['browser_invocations'] = 1
            with (OUT / 'browser.json').open('wb') as stdout, (OUT / 'browser.stderr').open('wb') as stderr:
                proc = subprocess.run(cli(args), cwd=candidate.PW, stdout=stdout, stderr=stderr, timeout=proposal['limits']['per_group_seconds'] - 300)
            result['browser_exit'] = proc.returncode
            assert proc.returncode == 0, 'browser group failed'
            check_report(load(OUT / 'browser.json'), proposal['inventory'][seam])
            result['status'] = 'passed'
    finally:
        if app is not None and app.poll() is None:
            os.killpg(app.pid, signal.SIGTERM)
            try:
                app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(app.pid, signal.SIGKILL)
                app.wait(timeout=5)
        (OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    if sys.argv[1:] == ['--collect']:
        print(json.dumps(collect()))
    else:
        assert len(sys.argv) == 3 and sys.argv[1] == '--run'
        run(sys.argv[2])
