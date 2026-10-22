"""Build and inspect a pinned Linux diagnostic; never invokes the browser tests."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request

if not __debug__:
    raise RuntimeError('Python optimization disables required checks; run without -O or PYTHONOPTIMIZE')

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = '4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97'
BASE = 'mcr.microsoft.com/playwright@sha256:eac9b0a5312cdab40ee8c2429df5bf19bffdccf8f3bf3c42268e173f97541645'
PG = 'docker.io/library/postgres@sha256:c961aa287d8698297cb26cdfadfbe9fd2cbaf77e53cfffe9636e8d8a1e4d842c'
IMAGE = 'sigra-phase253-registration-linux:original-4ff6c50e4'
ASSETS = {
    'otp.tar.gz': 'https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-28.5.tar.gz',
    'elixir.zip': 'https://builds.hex.pm/builds/elixir/v1.19.5-otp-28.zip',
    'node.tar.xz': 'https://nodejs.org/dist/v20.20.2/node-v20.20.2-linux-x64.tar.xz',
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    if (HERE / 'preparation.json').exists():
        n = len(list(HERE.glob('preparation-superseded-*.json'))) + 1
        (HERE / 'preparation.json').rename(HERE / f'preparation-superseded-{n}.json')
    if (HERE / 'preparation-start.json').exists():
        return build(json.loads((HERE / 'preparation-start.json').read_text()))
    context = Path(tempfile.mkdtemp(prefix='sigra-253-linux-build-'))
    (context / 'assets').mkdir()
    assets = {}
    for name, url in ASSETS.items():
        print('Downloading', name, flush=True)
        with urllib.request.urlopen(url, timeout=90) as response, (context / 'assets' / name).open('wb') as out:
            shutil.copyfileobj(response, out)
        assets[name] = dict(url=url, sha256=digest(context / 'assets' / name))
    with urllib.request.urlopen('https://nodejs.org/dist/v20.20.2/SHASUMS256.txt', timeout=30) as response:
        sums = response.read().decode()
    expected = next(line.split()[0] for line in sums.splitlines() if line.endswith('  node-v20.20.2-linux-x64.tar.xz'))
    assert assets['node.tar.xz']['sha256'] == expected, 'Node upstream checksum differs'
    (context / 'assets' / 'SHA256SUMS').write_text(''.join(f"{value['sha256']}  {name}\n" for name, value in assets.items()))
    source = context / 'source'
    subprocess.run(['git', 'init', '-q', str(source)], check=True)
    subprocess.run(['git', '-C', str(source), 'fetch', '-q', '--depth=1', '--no-tags', ROOT.as_uri(), SOURCE], check=True)
    subprocess.run(['git', '-C', str(source), 'checkout', '-q', '--detach', 'FETCH_HEAD'], check=True)
    for name in ['Dockerfile', 'in_container.py']:
        shutil.copyfile(HERE / name, context / name)
    shutil.copyfile(HERE.parent / '253-registration-order-recovery/full-prefix.config.ts', context / 'full-prefix.config.ts')
    record = dict(source=SOURCE, context=str(context), image_tag=IMAGE, base=BASE, postgres=PG,
                  platform='linux/amd64', assets=assets, browser_invocations=0, github_requests=0,
                  ci_launches=0, acceptance=False)
    (HERE / 'preparation-start.json').write_text(json.dumps(record, indent=2) + '\n')
    build(record)


def build(record):
    context = Path(record['context'])
    record['postgres'] = PG
    for name in ['Dockerfile', 'in_container.py']:
        shutil.copyfile(HERE / name, context / name)
    if (HERE / 'build.log').exists():
        n = len(list(HERE.glob('build-stopped-*.log'))) + 1
        (HERE / 'build.log').rename(HERE / f'build-stopped-{n}.log')
    with (HERE / 'build.log').open('wb') as log:
        result = subprocess.run(['docker', 'build', '--platform=linux/amd64', '--progress=plain',
            '--build-arg', 'PLAYWRIGHT_IMAGE=' + BASE, '-t', IMAGE, str(context)], stdout=log, stderr=subprocess.STDOUT, timeout=3600,
            env={**os.environ, 'BUILDX_CONFIG': str(context / 'buildx')})
    assert result.returncode == 0, 'image build failed; read build.log; no browser was launched'
    subprocess.run(['docker', 'pull', '--platform=linux/amd64', PG], check=True, timeout=300)
    record['image_id'] = subprocess.check_output(['docker', 'image', 'inspect', IMAGE, '--format', '{{.Id}}'], text=True).strip()
    record['dockerfile_sha256'] = digest(context / 'Dockerfile')
    record['container_runner_sha256'] = digest(context / 'in_container.py')
    inspected = subprocess.check_output(['docker', 'run', '--rm', '--platform=linux/amd64', '--network=none',
        '--cpuset-cpus=0-3', '--cpus=4', record['image_id'], '--inspect'], timeout=120)
    (HERE / 'inspect.json').write_bytes(inspected)
    record['inspect_sha256'] = digest(HERE / 'inspect.json')
    (HERE / 'preparation.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Built and inspected Linux x64 image. Browser invocations: 0.', flush=True)


if __name__ == '__main__':
    main()
