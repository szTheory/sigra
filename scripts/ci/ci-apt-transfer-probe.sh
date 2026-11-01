#!/usr/bin/env bash
# Diagnostic downloads only: no apt update, package install, source edits or auth bypass.
set -euo pipefail
[[ $# == 2 && "$1" == --output ]] || { echo 'usage: ci-apt-transfer-probe.sh --output NEW_REPORT.json' >&2; exit 2; }
python3 - "$2" <<'PY'
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse

output = pathlib.Path(sys.argv[1])
if output.exists():
    raise SystemExit('probe_output_already_exists')
report = {'schema_version': 'sigra.ci-apt-transfer-probe/v1', 'package': 'libflite1',
          'captured_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'installs_packages': False, 'changes_apt_configuration': False,
          'apt_authentication_disabled': False, 'probes': [], 'diagnostics': []}

def run(args, *, cwd=None, seconds=20):
    started = time.monotonic()
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=seconds)
        return result.returncode, result.stdout, time.monotonic() - started
    except subprocess.TimeoutExpired:
        return 124, '', time.monotonic() - started
    except OSError:
        return 127, '', time.monotonic() - started

def endpoint(value):
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme in ('http', 'https') and parsed.hostname:
        return {'scheme': parsed.scheme, 'host': parsed.hostname}
    return {'scheme': 'local_mirror_list' if value.startswith('mirror+file:') else 'unsupported'}

def check_file(path, expected_size, digest):
    size = path.stat().st_size if path.is_file() else 0
    actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    valid = size == expected_size and (digest is None or actual == digest)
    return size, actual, valid

try:
    keys = {'retries': 'Acquire::Retries', 'http_timeout': 'Acquire::http::Timeout',
            'https_timeout': 'Acquire::https::Timeout', 'http_dl_limit': 'Acquire::http::Dl-Limit',
            'https_dl_limit': 'Acquire::https::Dl-Limit'}
    args = ['apt-config', 'shell']
    for label, key in keys.items():
        args += [label, key]
    code, text, _ = run(args)
    # Never log raw configuration: proxies may contain credentials.
    config = {key: None for key in keys}
    for line in text.splitlines():
        match = re.fullmatch(r"([a-z_]+)='([0-9]+)'", line)
        if match and match[1] in config:
            config[match[1]] = int(match[2])
    report['effective_apt_acquire'] = config
    report['apt_config_exit_code'] = code
    mirrors = []
    for path in (pathlib.Path('/etc/apt/apt-mirrors.txt'), pathlib.Path('/etc/apt/sources.list'),
                 *sorted(pathlib.Path('/etc/apt/sources.list.d').glob('*.sources'))):
        if path.is_file():
            for line in path.read_text().splitlines():
                if line.lstrip().startswith('#'):
                    continue
                for value in re.findall(r'(?:https?|mirror\+file):[^\s]+', line):
                    item = endpoint(value)
                    if item not in mirrors:
                        mirrors.append(item)
    report['configured_endpoints'] = mirrors
    code, text, _ = run(['apt-get', '--print-uris', 'download', 'libflite1'])
    rows = []
    for line in text.splitlines():
        # apt documents URI, output filename, size and optional hash for --print-uris.
        match = re.fullmatch(r"'([^']+)'\s+(\S+)\s+(\d+)(?:\s+(\S+))?", line)
        if match:
            rows.append(match.groups())
    if code or len(rows) != 1:
        raise ValueError('package_uri_unavailable_or_ambiguous')
    uri, filename, size, hash_field = rows[0]
    size = int(size)
    if not (0 < size <= 32 * 1024 * 1024) or not re.fullmatch(r'libflite1_[A-Za-z0-9.+~:%_-]+\.deb', filename):
        raise ValueError('package_identity_or_size_invalid')
    digest_match = re.fullmatch(r'SHA256:([0-9a-fA-F]{64})', hash_field or '')
    digest = digest_match[1].lower() if digest_match else None
    parsed = urllib.parse.urlsplit(uri)
    if parsed.query or parsed.fragment or parsed.username or parsed.password:
        raise ValueError('package_uri_contains_nonpublic_components')
    pool = re.search(r'(/pool/[A-Za-z0-9/_.+~%:-]+\.deb)$', parsed.path)
    if not pool:
        raise ValueError('package_uri_not_ubuntu_pool')
    current_uri = uri
    if uri.startswith('mirror+file:'):
        mirror_path = pathlib.Path(parsed.path.split('/pool/')[0])
        if mirror_path != pathlib.Path('/etc/apt/apt-mirrors.txt'):
            raise ValueError('package_mirror_list_not_standard')
        candidates = [line.split()[0] for line in mirror_path.read_text().splitlines()
                      if line.strip() and not line.lstrip().startswith('#')]
        current_uri = next((value.rstrip('/') + pool[1] for value in candidates
                            if urllib.parse.urlsplit(value).scheme in ('http', 'https')), None)
        report['current_curl_endpoint_selection'] = 'first_http_mirror_list_entry_not_proof_of_apt_backend'
    if current_uri:
        candidate = urllib.parse.urlsplit(current_uri)
        if candidate.scheme not in ('http', 'https') or candidate.query or candidate.fragment or candidate.username or candidate.password:
            raise ValueError('current_mirror_uri_unsafe')
    official_uri = 'https://archive.ubuntu.com/ubuntu' + pool[1]
    report['package_metadata'] = {'filename': filename, 'size_bytes': size,
                                  'apt_sha256': digest, 'source_endpoint': endpoint(uri)}
    with tempfile.TemporaryDirectory(prefix='sigra-apt-probe-') as temp:
        root = pathlib.Path(temp)
        for label, options in [('apt_current', []), ('apt_no_download_cap',
                ['-o', 'Acquire::http::Dl-Limit=0', '-o', 'Acquire::https::Dl-Limit=0'])]:
            directory = root / label
            directory.mkdir()
            code, _, elapsed = run(['timeout', '--signal=TERM', '--kill-after=5s', '60s',
                                    'apt-get', *options, 'download', 'libflite1'], cwd=directory, seconds=70)
            files = list(directory.glob('*.deb'))
            path = files[0] if len(files) == 1 else directory / filename
            received, actual, valid = check_file(path, size, digest)
            report['probes'].append({'name': label, 'exit_code': code, 'elapsed_seconds': round(elapsed, 3),
                'size_bytes': received, 'bytes_per_second': round(received / max(elapsed, .001), 1),
                'status': 'complete' if code == 0 and valid else 'incomplete',
                'sha256': actual if code == 0 and valid else None,
                'apt_sha256_verified': bool(digest and code == 0 and valid),
                'uses_original_apt_authentication': True, 'maximum_seconds': 60})
        for label, target in [('curl_current_endpoint', current_uri), ('curl_official_https', official_uri)]:
            if not target:
                report['probes'].append({'name': label, 'status': 'unavailable'})
                continue
            path = root / (label + '.deb')
            code, stats, elapsed = run(['curl', '--disable', '--fail', '--location', '--silent', '--show-error',
                '--proto', '=http,https', '--proto-redir', '=http,https', '--max-redirs', '3',
                '--connect-timeout', '10', '--max-time', '30', '--speed-limit', '102400', '--speed-time', '10',
                '--max-filesize', str(size), '--output', str(path),
                '--write-out', '%{http_code} %{size_download} %{speed_download}', target], seconds=40)
            received, actual, valid = check_file(path, size, digest)
            values = stats.strip().split()
            http_status = int(values[0]) if values and re.fullmatch(r'[0-9]{3}', values[0]) else None
            speed = float(values[2]) if len(values) == 3 and re.fullmatch(r'[0-9.]+', values[2]) else None
            report['probes'].append({'name': label, 'endpoint': endpoint(target), 'exit_code': code,
                'http_status': http_status, 'elapsed_seconds': round(elapsed, 3), 'size_bytes': received,
                'bytes_per_second': speed, 'status': 'complete' if code == 0 and valid else 'incomplete',
                'sha256': actual if code == 0 and valid else None,
                'apt_sha256_verified': bool(digest and code == 0 and valid),
                'diagnostic_download_only_never_installed': True, 'maximum_seconds': 30,
                'minimum_bytes_per_second_over_10_seconds': 102400})
    report['status'] = 'diagnostic_complete'
except (OSError, ValueError) as error:
    report['status'] = 'diagnostic_failed'
    # Only fixed diagnostic names are surfaced, never transport stderr or raw URIs.
    report['diagnostics'].append(str(error) if isinstance(error, ValueError) else 'local_io_error')
output.parent.mkdir(parents=True, exist_ok=True)
with output.open('x') as destination:
    json.dump(report, destination, indent=2)
    destination.write('\n')
print(json.dumps({'status': report['status'], 'probe_count': len(report['probes'])}))
raise SystemExit(0 if report['status'] == 'diagnostic_complete' else 1)
PY
