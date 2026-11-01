#!/usr/bin/env python3
"""Hermetic transfer diagnostics: no packages, sudo, network or GitHub access."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name('ci-apt-transfer-probe.sh')
PAYLOAD = b'authenticated package bytes'
DIGEST = hashlib.sha256(PAYLOAD).hexdigest()


class TransferProbeTest(unittest.TestCase):
    def invoke(self, mode='normal'):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            binaries = root / 'bin'
            binaries.mkdir()
            shim = binaries / 'shim'
            shim.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,json
name=pathlib.Path(sys.argv[0]).name;args=sys.argv[1:];mode=os.environ['PROBE_TEST_MODE']
with open(os.environ['PROBE_TEST_CALLS'],'a') as f:f.write(json.dumps([name,*args])+'\\n')
data=b'authenticated package bytes'
if name=='apt-config':
 print("http_dl_limit='50'\\nhttps_timeout='15'\\nProxy='https://secret:password@example.test?token=SECRET'")
elif name=='apt-get':
 if '--print-uris' in args:
  url='http://azure.archive.ubuntu.com/ubuntu/pool/universe/f/flite/libflite1_2.2-6build3_amd64.deb'
  if mode=='secret_uri':url+='?token=SECRET'
  print("'%s' libflite1_2.2-6build3_amd64.deb %s SHA256:%s"%(url,len(data),os.environ['PROBE_TEST_DIGEST']))
 else:
  if mode=='apt_timeout' and 'Acquire::http::Dl-Limit=0' not in args:sys.exit(124)
  pathlib.Path('libflite1_2.2-6build3_amd64.deb').write_bytes(data)
elif name=='timeout':
 import subprocess
 sys.exit(subprocess.call(args[3:]))
elif name=='curl':
 target=pathlib.Path(args[args.index('--output')+1])
 target.write_bytes(b'tampered' if mode=='tamper' else data)
 print('200 %s 1000000'%len(data),end='')
''')
            shim.chmod(0o755)
            for name in ['apt-config', 'apt-get', 'timeout', 'curl']:
                (binaries / name).symlink_to(shim)
            calls = root / 'calls'
            output = root / 'report.json'
            env = {**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH'],
                   'PROBE_TEST_MODE': mode, 'PROBE_TEST_CALLS': str(calls), 'PROBE_TEST_DIGEST': DIGEST}
            process = subprocess.run(['bash', str(SCRIPT), '--output', str(output)], env=env,
                                     capture_output=True, text=True, timeout=15)
            return process, json.loads(output.read_text()), [json.loads(x) for x in calls.read_text().splitlines()]

    def test_records_all_four_paths_and_checks_package_hashes_without_install(self):
        process, report, calls = self.invoke()
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(len(report['probes']), 4)
        self.assertTrue(all(row['status'] == 'complete' and row['apt_sha256_verified'] for row in report['probes']))
        self.assertEqual(report['effective_apt_acquire']['http_dl_limit'], 50)
        self.assertNotIn('SECRET', json.dumps(report) + process.stdout + process.stderr)
        self.assertNotIn('password', json.dumps(report))
        for call in calls:
            self.assertNotIn('install', call)
            self.assertNotIn('update', call)
            self.assertNotIn('--allow-unauthenticated', call)
        curls = [row for row in calls if row[0] == 'curl']
        self.assertEqual(curls[1][-1], 'https://archive.ubuntu.com/ubuntu/pool/universe/f/flite/libflite1_2.2-6build3_amd64.deb')
        self.assertTrue(all(row[row.index('--max-time')+1] == '30' for row in curls))

    def test_timeout_is_recorded_and_cap_override_still_executed_once(self):
        process, report, calls = self.invoke('apt_timeout')
        self.assertEqual(process.returncode, 0)
        self.assertEqual(report['probes'][0]['exit_code'], 124)
        self.assertEqual(report['probes'][0]['status'], 'incomplete')
        self.assertEqual(report['probes'][1]['status'], 'complete')
        downloads = [row for row in calls if row[0] == 'apt-get' and '--print-uris' not in row]
        self.assertEqual(len(downloads), 2)
        self.assertIn('Acquire::http::Dl-Limit=0', downloads[1])

    def test_tampered_curl_download_is_never_reported_complete(self):
        process, report, _ = self.invoke('tamper')
        self.assertEqual(process.returncode, 0)
        self.assertTrue(all(row['status'] == 'incomplete' and not row['apt_sha256_verified'] for row in report['probes'][2:]))

    def test_secret_uri_fails_closed_without_transport_or_leak(self):
        process, report, calls = self.invoke('secret_uri')
        self.assertEqual(process.returncode, 1)
        self.assertEqual(report['diagnostics'], ['package_uri_contains_nonpublic_components'])
        self.assertFalse(any(row[0] in ('curl', 'timeout') for row in calls))
        self.assertNotIn('SECRET', json.dumps(report) + process.stdout + process.stderr)


if __name__ == '__main__':
    unittest.main()
