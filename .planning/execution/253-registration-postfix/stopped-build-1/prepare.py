"""Offline-only preparation. Never starts an app, database, or browser."""
import base64
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = 'a876647338095b6d280608cb75bcf886ab1da953'
BASE = 'sha256:e5272f11689c8740c02789ca6bf3e3fc955c4550f25ac53f738e7807205c9836'
TAG = 'sigra-phase253-registration-postfix:a87664733'
PG = 'docker.io/library/postgres@sha256:c961aa287d8698297cb26cdfadfbe9fd2cbaf77e53cfffe9636e8d8a1e4d842c'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    assert not (HERE / 'preparation.json').exists(), 'preparation already sealed; retain it instead of overwriting'
    assert json.loads(subprocess.check_output(['docker', 'image', 'inspect', BASE]))[0]['Id'] == BASE
    tagged = json.loads(subprocess.check_output(['docker', 'image', 'inspect', 'sigra-phase253-registration-linux:original-4ff6c50e4']))[0]
    assert tagged['Id'] == BASE, 'base tag moved'
    assert git('show', SOURCE + ':test/example/mix.lock') == git('show', '4ff6c50e4:test/example/mix.lock'), 'cached Hex dependency lock differs'
    start = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='sigra253-postfix-build-') as tmp:
        context = Path(tmp)
        tops = [x for x in git('ls-tree', '--name-only', '-z', SOURCE).decode().split('\0') if x and x != '.planning']
        archive = git('archive', '--format=tar', SOURCE, '--', *tops)
        (context / 'source.tar').write_bytes(archive)
        files = {}
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            for member in tar.getmembers():
                if member.isfile():
                    files[member.name] = sha(tar.extractfile(member).read())
        data = dict(source=SOURCE, source_tree=git('rev-parse', SOURCE + '^{tree}').decode().strip(),
                    export='all tracked top-level paths except .planning; no dependency/build directories',
                    source_tar_sha256=sha(archive), file_sha256=files)
        (HERE / 'source-manifest.json').write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
        (context / 'source-manifest.json').write_bytes((HERE / 'source-manifest.json').read_bytes())
        (context / 'commit.raw').write_bytes(git('cat-file', 'commit', SOURCE))
        lock = json.loads(git('show', SOURCE + ':test/example/priv/playwright/package-lock.json'))
        packages = []
        for name, row in lock['packages'].items():
            if not row.get('integrity'):
                continue
            algo, encoded = row['integrity'].split('-', 1)
            raw = base64.b64decode(encoded)
            h = raw.hex()
            suffix = Path(algo) / h[:2] / h[2:4] / h[4:]
            src = Path.home() / '.npm/_cacache/content-v2' / suffix
            body = src.read_bytes()
            assert hashlib.new(algo, body).digest() == raw, 'cached npm integrity mismatch: ' + name
            dest = context / 'npm-content' / suffix
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(body)
            packages.append(dict(name=name, integrity=row['integrity']))
        for name in ['Dockerfile', 'in_container.py', 'inspect_compiled_endpoint.exs']:
            shutil.copyfile(HERE / name, context / name)
        with (HERE / 'build.log').open('wb') as log:
            subprocess.run(['docker', 'build', '--pull=false', '--network=none', '--platform=linux/amd64',
                            '--progress=plain', '-t', TAG, str(context)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        image = json.loads(subprocess.check_output(['docker', 'image', 'inspect', TAG]))[0]
        name = 'sigra253-postfix-inspect-' + str(time.time_ns())
        try:
            raw = subprocess.check_output(['docker', 'run', '--pull=never', '--name', name, '--network=none',
                    '--platform=linux/amd64', image['Id'], '--inspect'], timeout=90)
            inspect = json.loads(raw)
            assert inspect['source'] == SOURCE
            (HERE / 'inspect.json').write_text(json.dumps(inspect, indent=2) + '\n')
        finally:
            subprocess.run(['docker', 'rm', '-f', '-v', name], check=True, capture_output=True, timeout=15)
        prep = dict(source=SOURCE, image_id=image['Id'], base_image_id=BASE, postgres_image=PG,
                    source_manifest_sha256=sha((HERE / 'source-manifest.json').read_bytes()),
                    inspect_sha256=sha((HERE / 'inspect.json').read_bytes()),
                    files={n:sha((HERE/n).read_bytes()) for n in ['Dockerfile','in_container.py','inspect_compiled_endpoint.exs','prepare.py']},
                    npm_packages_verified=len(packages), build_network='none', inspect_network='none',
                    browser_invocations=0, app_started=False, database_started=False, ci_launches=0,
                    duration_seconds=time.monotonic()-start, context_removed_on_return=True)
        (HERE / 'preparation.json').write_text(json.dumps(prep, indent=2) + '\n')
        print(json.dumps(prep, indent=2))


if __name__ == '__main__':
    main()
