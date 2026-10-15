#!/usr/bin/env python3
"""Offline route-mapping regressions for ci-gate-canary.sh (253-100).

The real api_get, download_no_follow, transport_call, request_category and
record_budget functions are extracted from the script text and run in bash
with a recording stub transport. The stub records each request envelope the
real transport_call builds and returns a canned 200 receipt. Nothing reaches
any network: gh and curl on PATH are recorders that fail the test if called.
"""
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'scripts/ci/ci-gate-canary.sh'
SHA = '84ebcea60024c9e8caee405d55cad1c76b0e858a'
BRANCH = 'gsd/253-replan-fixture'
EXTRACTED = ('request_category', 'transport_call', 'record_budget', 'api_get', 'download_no_follow')

STUB_TRANSPORT = r'''
import json, os, sys
args = sys.argv[1:]
def value(flag):
    return args[args.index(flag) + 1]
request = json.load(open(value('--request')))
flags = [a for a in args if a in ('--fetch-pages', '--follow-download')]
with open(os.environ['ROUTE_RECORD'], 'a') as handle:
    handle.write(json.dumps({'envelope': request, 'flags': flags}) + '\n')
target = value('--body-output')
if target != '/dev/null':
    with open(target, 'w') as handle:
        handle.write('{}')
with open(value('--output'), 'w') as handle:
    json.dump({'sequence': 1, 'actual_status': 200}, handle)
'''


def extract(source, name):
    match = re.search(rf'^{name}\(\) \{{.*?^\}}', source, re.M | re.S)
    return match.group(0) if match else None


class CanaryRouteMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = RUNNER.read_text()
        cls.functions = {name: extract(source, name) for name in EXTRACTED}

    def test_extracted_functions_were_found(self):
        for name, text in self.functions.items():
            with self.subTest(function=name):
                self.assertIsNotNone(text, f'{name}() not found in {RUNNER}')

    def _drive(self, call):
        """Run one real driver call against the recording stub; return (result, records, network calls)."""
        for name, text in self.functions.items():
            self.assertIsNotNone(text, f'{name}() not found in {RUNNER}')
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            stub = tmp / 'stub-transport.py'
            stub.write_text(STUB_TRANSPORT)
            record = tmp / 'records.jsonl'
            marker = tmp / 'network-calls'
            bin_dir = tmp / 'bin'
            bin_dir.mkdir()
            for name in ('gh', 'curl'):
                recorder = bin_dir / name
                recorder.write_text(f'#!/bin/sh\nprintf "{name} %s\\n" "$*" >> "$NETWORK_MARKER"\nexit 99\n')
                recorder.chmod(0o755)
            prelude = (
                'set -euo pipefail\n'
                'export PYTHONDONTWRITEBYTECODE=1\n'
                'fail() { printf "ci-gate-canary: FAIL: %s\\n" "$*" >&2; exit 1; }\n'
                f'WORK_DIR="{tmp}"\n'
                f'TRANSPORT_MODULE="{stub}"\n'
                f'REQUEST_LEDGER="{tmp}/absent-ledger.json"\n'
                f'EVIDENCE="{tmp}/absent-evidence.json"\n'
                'LIVE_ALLOCATION=stub-allocation\nREQUEST_COUNT=0\nCANARY_STARTED_EPOCH=0\n'
                'LAST_REQUEST_STATUS=""\n'
            )
            body = '\n'.join(self.functions.values()) + '\n' + call + '\necho route-call-returned\n'
            env = {**os.environ, 'PATH': f'{bin_dir}:{os.environ["PATH"]}', 'ROUTE_RECORD': str(record),
                   'NETWORK_MARKER': str(marker), 'PYTHONDONTWRITEBYTECODE': '1'}
            result = subprocess.run(['bash', '-c', prelude + body], cwd=tmp, env=env, text=True,
                                    capture_output=True, timeout=60)
            records = [json.loads(line) for line in record.read_text().splitlines()] if record.exists() else []
            network = marker.read_text() if marker.exists() else ''
        return result, records, network

    def _assert_route(self, call, route_id, category, params, query, flags):
        result, records, network = self._drive(call)
        self.assertEqual(network, '', 'a network client was invoked')
        self.assertEqual(result.returncode, 0, f'driver call failed: {result.stderr.strip()}')
        self.assertIn('route-call-returned', result.stdout)
        self.assertEqual(len(records), 1, f'expected exactly one transport call, got {records}')
        envelope = records[0]['envelope']
        self.assertEqual(envelope['route_id'], route_id)
        self.assertEqual(envelope['method'], 'GET')
        self.assertEqual(envelope['category'], category)
        self.assertEqual(envelope['params'], params)
        for key in ('workflow_id', 'run_id', 'artifact_id'):
            if key in params:
                self.assertIs(type(envelope['params'][key]), int, f'{key} must be a JSON number')
        self.assertEqual(envelope['query'], query)
        self.assertIsNone(envelope['body'])
        self.assertEqual(records[0]['flags'], flags)

    def test_route_rate_limit(self):
        self._assert_route('api_get rate_limit "$WORK_DIR/out.json"', 'rate_limit', 'preflight', {}, {}, [])

    def test_route_rules_main(self):
        self._assert_route("api_get 'rules/branches/main?per_page=100' \"$WORK_DIR/out.json\"",
                           'rules_main', 'preflight', {}, {'per_page': 100}, ['--fetch-pages'])

    def test_route_branch_protection(self):
        self._assert_route('api_get branches/main/protection "$WORK_DIR/out.json" true',
                           'branch_protection', 'preflight', {}, {}, [])

    def test_route_check_runs(self):
        self._assert_route(f'api_get "commits/{SHA}/check-runs?per_page=100" "$WORK_DIR/out.json"',
                           'check_runs', 'preflight', {'commit_sha': SHA}, {'per_page': 100}, ['--fetch-pages'])

    def test_route_workflow(self):
        self._assert_route('api_get actions/workflows/259268962 "$WORK_DIR/out.json"',
                           'workflow', 'preflight', {'workflow_id': 259268962}, {}, [])

    def test_route_workflow_runs(self):
        self._assert_route(
            f'api_get "actions/workflows/259268962/runs?event=workflow_dispatch&branch={BRANCH}&per_page=100" "$WORK_DIR/out.json"',
            'workflow_runs', 'run_discovery', {'workflow_id': 259268962},
            {'event': 'workflow_dispatch', 'branch': BRANCH, 'per_page': 100}, ['--fetch-pages'])

    def test_route_run_jobs(self):
        self._assert_route('api_get "actions/runs/24680135/jobs?per_page=100" "$WORK_DIR/out.json"',
                           'run_jobs', 'attempt_jobs', {'run_id': 24680135}, {'per_page': 100}, ['--fetch-pages'])

    def test_route_run_artifacts(self):
        self._assert_route('api_get "actions/runs/24680135/artifacts?per_page=100" "$WORK_DIR/out.json"',
                           'run_artifacts', 'artifact_metadata', {'run_id': 24680135}, {'per_page': 100}, ['--fetch-pages'])

    def test_route_run(self):
        self._assert_route('api_get actions/runs/24680135 "$WORK_DIR/out.json"',
                           'run', 'terminal_polls', {'run_id': 24680135}, {}, [])

    def test_route_get_ref(self):
        self._assert_route(f'api_get git/ref/heads/{BRANCH} "$WORK_DIR/out.json"',
                           'get_ref', 'publication', {'branch': BRANCH}, {}, [])

    def test_route_run_logs_download(self):
        self._assert_route(
            'download_no_follow https://api.github.com/repos/szTheory/sigra/actions/runs/24680135/logs "$WORK_DIR/logs.zip" 0',
            'run_logs', 'failure_logs', {'run_id': 24680135}, {}, ['--follow-download'])

    def test_route_artifact_zip_download(self):
        self._assert_route(
            'download_no_follow https://api.github.com/repos/szTheory/sigra/actions/artifacts/97531/zip "$WORK_DIR/a.zip" 1024',
            'artifact_zip', 'artifact_downloads', {'artifact_id': 97531}, {}, ['--follow-download'])

    def test_route_suite_covers_every_typed_get_route(self):
        covered = {name[len('test_route_'):] for name in dir(self) if name.startswith('test_route_')} - {'suite_covers_every_typed_get_route'}
        self.assertEqual(covered, {'rate_limit', 'rules_main', 'branch_protection', 'check_runs', 'workflow',
                                   'workflow_runs', 'run_jobs', 'run_artifacts', 'run', 'get_ref',
                                   'run_logs_download', 'artifact_zip_download'})


REQUIRED_NAMES = ('Library tests', 'Example unit smoke (ExUnit + ConnTest)',
                  'Install smoke (fresh phx.new + sigra.install)',
                  'Example HTTP smoke (boot + curl critical routes)',
                  'Example Playwright smoke (full lifecycle)')
SERVER_PARENT = SHA
CANDIDATE = 'ce89eb7319c20596850a0c8a0b6e5661e197c86a'


def native_run(name, index, sha=SERVER_PARENT, conclusion='success', **overrides):
    run = {'name': name, 'head_sha': sha, 'status': 'completed', 'conclusion': conclusion,
           'app': {'id': 15368, 'slug': 'github-actions'},
           'html_url': f'https://github.com/szTheory/sigra/actions/runs/1/job/{index}'}
    run.update(overrides)
    return run


class CanaryPreflightCheckSourceTests(unittest.TestCase):
    """Run the real preflight read block of ci-gate-canary.sh with a recording api_get stub (D-12 decision)."""

    @classmethod
    def setUpClass(cls):
        source = RUNNER.read_text()
        match = re.search(r'^RATE_RESPONSE="\$\(mktemp .*?(?=^store_preflight "\$RATE_RESPONSE")', source, re.M | re.S)
        cls.block = match.group(0) if match else None

    def _preflight(self, check_runs, check_source_sha=SERVER_PARENT):
        self.assertIsNotNone(self.block, 'preflight read block not found in ci-gate-canary.sh')
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            rules = [{'type': 'required_status_checks', 'parameters': {'required_status_checks': [
                {'context': name, 'integration_id': 15368} for name in REQUIRED_NAMES]}}]
            responses = {
                'rate': {'resources': {'core': {'remaining': 5000}}},
                'rules': rules,
                'protection': {'required_status_checks': {}},
                'checks': check_runs,
                'workflow': {'id': 259268962, 'path': '.github/workflows/ci.yml', 'state': 'active'},
            }
            for name, value in responses.items():
                (tmp / f'{name}.json').write_text(json.dumps(value))
            (tmp / 'ledger.json').write_text(json.dumps({'transactions': [
                {'route_id': 'rules_main', 'response_body_base64': base64.b64encode(json.dumps(rules).encode()).decode()}]}))
            calls = tmp / 'calls'
            stubs = (
                'set -euo pipefail\n'
                'fail() { printf "ci-gate-canary: FAIL: %s\\n" "$*" >&2; exit 1; }\n'
                f'WORK_DIR="{tmp}"\nREQUEST_LEDGER="{tmp}/ledger.json"\nWORKFLOW_ID=259268962\n'
                f'CANDIDATE_SHA={CANDIDATE}\nCHECK_SOURCE_SHA="{check_source_sha}"\n'
                'api_get() {\n'
                f'  printf "%s\\n" "$1" >> "{calls}"\n'
                '  case "$1" in\n'
                f'    rate_limit) cp "{tmp}/rate.json" "$2" ;;\n'
                f'    rules/*) cp "{tmp}/rules.json" "$2" ;;\n'
                f'    branches/*) cp "{tmp}/protection.json" "$2" ;;\n'
                f'    commits/*) cp "{tmp}/checks.json" "$2" ;;\n'
                f'    actions/workflows/*) cp "{tmp}/workflow.json" "$2" ;;\n'
                '    *) echo "unexpected endpoint $1" >&2; exit 9 ;;\n'
                '  esac\n'
                '}\n'
            )
            result = subprocess.run(['bash', '-c', stubs + self.block + '\necho preflight-reads-passed\n'],
                                    cwd=tmp, text=True, capture_output=True, timeout=60)
            endpoints = calls.read_text().splitlines() if calls.exists() else []
        return result, endpoints

    def _checks(self, runs):
        return {'total_count': len(runs), 'check_runs': runs}

    def test_preflight_reads_check_sources_from_the_frozen_server_parent(self):
        runs = [native_run(name, index) for index, name in enumerate(REQUIRED_NAMES, 1)]
        result, endpoints = self._preflight(self._checks(runs))
        check_reads = [endpoint for endpoint in endpoints if endpoint.startswith('commits/')]
        self.assertEqual(check_reads, [f'commits/{SERVER_PARENT}/check-runs?per_page=100'])
        self.assertFalse(any(CANDIDATE in endpoint for endpoint in endpoints), endpoints)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('preflight-reads-passed', result.stdout)

    def test_preflight_records_identity_without_requiring_success(self):
        conclusions = ('failure', 'success', 'cancelled', None, 'timed_out')
        runs = [native_run(name, index, conclusion=conclusion)
                for index, (name, conclusion) in enumerate(zip(REQUIRED_NAMES, conclusions), 1)]
        result, endpoints = self._preflight(self._checks(runs))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'commits/{SERVER_PARENT}/check-runs?per_page=100', endpoints)

    def test_preflight_rejects_missing_duplicated_or_foreign_identity(self):
        base = [native_run(name, index) for index, name in enumerate(REQUIRED_NAMES, 1)]
        cases = {
            'four producers': base[:4],
            'duplicated producer': base + [native_run(REQUIRED_NAMES[0], 9)],
            'missing app slug': [native_run(REQUIRED_NAMES[0], 1, app={'id': 15368})] + base[1:],
            'missing source': [native_run(REQUIRED_NAMES[0], 1, html_url=None)] + base[1:],
            'non-https source': [native_run(REQUIRED_NAMES[0], 1, html_url='http://example.test/job/1')] + base[1:],
            'run of a different commit': [native_run(REQUIRED_NAMES[0], 1, sha=CANDIDATE)] + base[1:],
        }
        for label, runs in cases.items():
            with self.subTest(case=label):
                result, _ = self._preflight(self._checks(runs))
                self.assertNotEqual(result.returncode, 0, label)
                self.assertIn('native check-run app/source identity is missing or duplicated', result.stderr)

    def test_preflight_refuses_a_missing_or_malformed_check_source_before_any_request(self):
        runs = [native_run(name, index) for index, name in enumerate(REQUIRED_NAMES, 1)]
        for value in ('', SERVER_PARENT[:39], SERVER_PARENT.upper()):
            with self.subTest(check_source=value):
                result, endpoints = self._preflight(self._checks(runs), check_source_sha=value)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(endpoints, [])
                self.assertIn('frozen server-parent check source is missing or malformed', result.stderr)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    def flatten(item):
        return [leaf for child in item for leaf in flatten(child)] if isinstance(item, unittest.TestSuite) else [item]
    route_tests = [test for test in flatten(suite) if test.id().split('.')[-1].startswith('test_route_')]
    if not route_tests:
        print('ci-gate-canary-flow: no route tests discovered', file=sys.stderr)
        sys.exit(1)
    unittest.main(verbosity=2)
