"""Fresh Linux app, original warmup and selection. No retry or acceptance claim."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path('/work')
APP = ROOT / 'test/example'
PW = APP / 'priv/playwright'
OUT = Path('/evidence')
SOURCE = '4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def http_status(url):
    # Match the original action's curl without -L: redirects are not followed.
    try:
        with urllib.request.build_opener(NoRedirect).open(url, timeout=2) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def command(args, cwd=APP, **kwargs):
    return subprocess.run(args, cwd=cwd, check=True, **kwargs)


def inspect():
    assert command(['git', 'rev-parse', 'HEAD'], ROOT, capture_output=True, text=True).stdout.strip() == SOURCE
    assert not command(['git', 'status', '--porcelain', '--untracked-files=no'], ROOT, capture_output=True).stdout
    assert command(['uname', '-m'], capture_output=True, text=True).stdout.strip() == 'x86_64'
    assert command(['node', '--version'], capture_output=True, text=True).stdout.strip() == 'v20.20.2'
    otp = Path('/opt/otp/releases/28/OTP_VERSION').read_text().strip()
    assert otp == '28.5', 'OTP version differs: ' + otp
    assert command(['node', '-p', "require('playwright/package.json').version"], PW, capture_output=True, text=True).stdout.strip() == '1.59.1'
    return dict(source=SOURCE, uname=command(['uname', '-a'], capture_output=True, text=True).stdout.strip(),
                os_release=Path('/etc/os-release').read_text(),
                mix=command(['mix', '--version'], capture_output=True, text=True).stdout,
                node='v20.20.2', otp=otp, playwright='1.59.1', browser_invocations=0,
                erl_aflags=os.environ.get('ERL_AFLAGS'),
                collection=json.loads(Path('/diagnostic/collection.json').read_text()))


def main(mode):
    if mode == '--inspect':
        print(json.dumps(inspect()))
        return
    assert mode in ('--setup-only', '--run'), 'unknown container mode'
    OUT.mkdir(exist_ok=True)
    start = time.monotonic()
    result = dict(kind='development_diagnostic' if mode == '--run' else 'development_setup',
                  source=SOURCE, browser_invocations=0, acceptance=False, outcome='stopped')
    app = None
    try:
        tools = inspect()
        tools.pop('collection')
        (OUT / 'tools.json').write_text(json.dumps(tools, indent=2) + '\n')
        with (OUT / 'setup.log').open('wb') as log:
            command(['mix', 'ecto.create'], stdout=log, stderr=subprocess.STDOUT, timeout=90)
            command(['mix', 'ecto.migrate'], stdout=log, stderr=subprocess.STDOUT, timeout=90)
            command(['mix', 'run', 'priv/repo/seeds.exs'], stdout=log, stderr=subprocess.STDOUT, timeout=90)
        with (OUT / 'app.log').open('wb') as log:
            app = subprocess.Popen(['mix', 'phx.server'], cwd=APP, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + 90
            while True:
                assert app.poll() is None, 'app exited before readiness'
                try:
                    if 200 <= http_status('http://localhost:4011/') < 400:
                        break
                except (OSError, TimeoutError):
                    pass
                if time.monotonic() >= deadline:
                    raise TimeoutError('app readiness deadline exceeded')
                time.sleep(.25)  # condition polling; no sleeps in the browser tests
            # The selected original job overrides the action default with this one route.
            result['warmup_status'] = http_status('http://localhost:4011/admin/_design')
            if mode == '--setup-only':
                result['outcome'] = 'setup_and_app_ready'
            else:
                result['browser_invocations'] = 1
                (OUT / 'browser-started.json').write_text(json.dumps({'monotonic': time.monotonic()}))
                with (OUT / 'browser.json').open('wb') as browser_log:
                    proc = subprocess.run(['node', 'node_modules/playwright/cli.js', 'test', 'tests/admin-eval.spec.ts',
                        '--config=.phase253-linux.config.ts', '--workers=1', '--retries=0', '--max-failures=1',
                        '--trace=retain-on-failure', '--reporter=json', '--output=/evidence/test-results'],
                        cwd=PW, stdout=browser_log, stderr=(OUT / 'browser.stderr').open('wb'))
                result['browser_exit'] = proc.returncode
                result['outcome'] = 'completed_not_reproduced' if proc.returncode == 0 else 'browser_failed_needs_diagnosis'
                if proc.returncode:
                    raise subprocess.CalledProcessError(proc.returncode, 'playwright')
    except Exception as error:
        result['error'] = str(error)
        raise
    finally:
        if app is not None and app.poll() is None:
            os.killpg(app.pid, signal.SIGTERM)
            try:
                app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(app.pid, signal.SIGKILL)
                app.wait()
        result['duration_seconds'] = time.monotonic() - start
        (OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    assert len(sys.argv) == 2
    main(sys.argv[1])
