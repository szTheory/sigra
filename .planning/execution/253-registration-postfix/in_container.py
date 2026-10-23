"""Candidate source verification and explicitly selected post-fix checks."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.request

ROOT = Path('/work')
APP = ROOT / 'test/example'
PW = APP / 'priv/playwright'
META = Path('/postfix')
OUT = Path('/evidence')
PROJECTS = ['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']
TITLE = 'render bundle: board-mg-9/populated'


def command(args, cwd=APP, **kwargs):
    return subprocess.run(args, cwd=cwd, check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest():
    return json.loads((META / 'source-manifest.json').read_text())


def install_source():
    # Remove old tracked source; preserve only the cached, untracked build/dependency assets.
    old = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).split(b'\0')
    for item in old:
        if item:
            path = ROOT / os.fsdecode(item)
            if path.is_file() or path.is_symlink():
                path.unlink()
    shutil.rmtree(ROOT / '.git')
    (PW / '.phase253-linux.config.ts').unlink(missing_ok=True)
    with tarfile.open(META / 'source.tar') as archive:
        archive.extractall(ROOT, filter='data')
    # Real commit object copied byte-for-byte, with no invented commit/history.
    # This metadata supports the eval harness's rev-parse; source checks use the manifest.
    command(['git', 'init', '-q'], ROOT)
    sha = command(['git', 'hash-object', '-t', 'commit', '-w', '--stdin'], ROOT,
                  input=(META / 'commit.raw').read_bytes(), capture_output=True).stdout.decode().strip()
    assert sha == manifest()['source']
    (ROOT / '.git/HEAD').write_text(sha + '\n')
    verify_source()


def verify_source():
    data = manifest()
    for name, sha in data['file_sha256'].items():
        assert digest(ROOT / name) == sha, 'candidate file changed: ' + name
    assert command(['git', 'rev-parse', 'HEAD'], ROOT, capture_output=True, text=True).stdout.strip() == data['source']
    assert os.environ.get('CI') == 'true'
    assert not os.environ.get('SIGRA_REGISTRATION_CONTROL_STAGE'), 'old control windows must remain inactive'
    return data


def browser_command(project, collect=False):
    assert project in PROJECTS
    args = ['node', 'node_modules/playwright/cli.js', 'test', 'tests/admin-eval.spec.ts',
            '--project=' + project, '--grep=' + TITLE + '$', '--workers=1', '--retries=0',
            '--max-failures=1', '--trace=retain-on-failure', '--reporter=json']
    return args + (['--list'] if collect else ['--output=/evidence/test-results'])


def collect():
    verify_source()
    reports = {}
    for project in PROJECTS:
        reports[project] = json.loads(command(browser_command(project, True), PW, capture_output=True, text=True).stdout)
    return reports


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def http_status(url):
    try:
        with urllib.request.build_opener(NoRedirect).open(url, timeout=2) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def inspect():
    data = verify_source()
    assert command(['uname', '-m'], capture_output=True, text=True).stdout.strip() == 'x86_64'
    assert Path('/opt/otp/releases/28/OTP_VERSION').read_text().strip() == '28.5'
    assert command(['node', '--version'], capture_output=True, text=True).stdout.strip() == 'v20.20.2'
    assert command(['node', '-p', "require('playwright/package.json').version"], PW, capture_output=True, text=True).stdout.strip() == '1.59.1'
    endpoint = json.loads(command(['elixir', '/postfix/inspect_compiled_endpoint.exs'], capture_output=True, text=True).stdout)
    assert endpoint['live_reload_socket'] is False and endpoint['reloader_calls'] == []
    assert endpoint['liveview_socket_retained'] is True
    # Recheck installed browser dependencies against the candidate lockfile.
    command(['npm', 'ls', '--all', '--json'], PW, capture_output=True)
    return dict(source=data['source'], source_manifest_sha256=digest(META / 'source-manifest.json'),
                otp='28.5', node='20.20.2', playwright='1.59.1',
                endpoint=endpoint, collection=json.loads((META / 'collection.json').read_text()),
                browser_invocations=0, app_started=False, database_started=False)


def run(project):
    tools = inspect()
    OUT.mkdir(exist_ok=True)
    app = None
    result = dict(source=tools['source'], project=project, title=TITLE, browser_invocations=0, outcome='stopped')
    try:
        (OUT / 'tools.json').write_text(json.dumps(tools, indent=2) + '\n')
        with (OUT / 'setup.log').open('wb') as log:
            for args in [['mix', 'ecto.create'], ['mix', 'ecto.migrate'], ['mix', 'run', 'priv/repo/seeds.exs']]:
                command(args, stdout=log, stderr=subprocess.STDOUT, timeout=90)
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
                assert time.monotonic() < deadline, 'app readiness deadline exceeded'
                time.sleep(.25)  # readiness condition polling, no browser sleeps
            result['warmup_status'] = http_status('http://localhost:4011/admin/_design')
            assert result['warmup_status'] == 302
            (OUT / 'browser-started.json').write_text(json.dumps({'project': project, 'monotonic': time.monotonic()}))
            result['browser_invocations'] = 1
            with (OUT / 'browser.json').open('wb') as stdout, (OUT / 'browser.stderr').open('wb') as stderr:
                proc = command(browser_command(project), PW, stdout=stdout, stderr=stderr, timeout=120)
            result.update(browser_exit=proc.returncode, outcome='browser_passed_pending_host_validation')
    finally:
        if app is not None and app.poll() is None:
            os.killpg(app.pid, signal.SIGTERM)
            try:
                app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(app.pid, signal.SIGKILL)
                app.wait()
        (OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == '--install-source':
        install_source()
    elif mode == '--collect':
        print(json.dumps(collect()))
    elif mode == '--inspect':
        print(json.dumps(inspect()))
    else:
        assert mode == '--run' and len(sys.argv) == 3
        run(sys.argv[2])
