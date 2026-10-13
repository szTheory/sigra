#!/usr/bin/env python3
"""Offline regressions for the fixture and halted canary runner."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
PHASE = ROOT / '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
RUNNER = ROOT / 'scripts/ci/ci-gate-canary.sh'
FIXTURE = PHASE / '253-CANARY-WORKFLOW.yml'
SEAMS = ('non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase')


class CanaryRecoveryTests(unittest.TestCase):
    def test_halted_evidence_stops_before_any_github_command(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            gh = tmp / 'gh'
            gh.write_text('#!/bin/sh\nprintf called >> "$GITHUB_CALL_MARKER"\nexit 99\n')
            gh.chmod(0o755)
            evidence = tmp / 'halted.json'
            evidence.write_text(json.dumps({'status': 'halted', 'diagnostics': {'full_pass': {'source_status': 'unverified'}}}))
            original = evidence.read_bytes()
            env = {**os.environ, 'PATH': f'{tmp}:{os.environ["PATH"]}', 'GITHUB_CALL_MARKER': str(tmp / 'calls')}
            result = subprocess.run(['bash', str(RUNNER), '--scenario', 'full-pass', '--evidence', str(evidence)],
                                    env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('halted evidence', result.stderr)
            self.assertFalse((tmp / 'calls').exists(), result.stderr)
            self.assertEqual(evidence.read_bytes(), original)

    def test_expected_watch_failure_returns_without_changing_errexit(self):
        source = RUNNER.read_text()
        function = re.search(r'^watch_run\(\) \{.*?^\}', source, re.M | re.S).group(0)
        stubs = '''set -euo pipefail
api_get() { printf '{"resources":{"core":{"remaining":5000}}}' > "$2"; }
check_budget() { :; }
log_request() { :; }
record_budget() { :; }
gh() { return 1; }
sleep() { command sleep 0.01; }
REQUEST_COUNT=0
WATCH_RESERVATION=8
'''
        result = subprocess.run(['bash', '-c', stubs + function + '''
watch_status=0
if watch_run 901 fixture; then watch_status=0; else watch_status=$?; fi
[[ "$watch_status" == 1 ]]
[[ "$-" == *e* ]]
echo completion-can-be-captured
'''], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('completion-can-be-captured', result.stdout)
        self.assertNotIn('set +e', function)
        self.assertNotIn('set -e', function)

    def test_fixture_uses_actual_github_identity_as_input_only(self):
        workflow = yaml.safe_load(FIXTURE.read_text())
        step = next(step for step in workflow['jobs']['verdict']['steps'] if step.get('id') == 'shared_verdict')
        self.assertFalse(any(key.startswith('GITHUB_') for key in step['env']))
        script = step['run']
        candidate = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        for scenario in ('full-pass', 'docs-only', 'actual-failure', 'missing-seam', 'unexpected-skip'):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                tmp = Path(directory)
                shutil.copytree(ROOT / 'scripts/ci', tmp / 'candidate/scripts/ci', ignore=shutil.ignore_patterns('__pycache__'))
                (tmp / 'candidate/.github/workflows').mkdir(parents=True)
                shutil.copyfile(ROOT / '.github/workflows/ci.yml', tmp / 'candidate/.github/workflows/ci.yml')
                shutil.copyfile(ROOT / '.github/ci-skip-manifest.tsv', tmp / 'candidate/.github/ci-skip-manifest.tsv')
                for seam in SEAMS:
                    if scenario == 'missing-seam' and seam == 'admin_checkpoints':
                        continue
                    receipt = tmp / f'producer-artifacts/gate-canary-producer-{seam}-901-1/producer.json'
                    receipt.parent.mkdir(parents=True)
                    receipt.write_text(json.dumps({'schema_version': 'sigra.gate-canary-producer/v1', 'scenario': scenario,
                        'seam': seam, 'actual_event': 'workflow_dispatch', 'synthetic': True}))
                env = {**os.environ, 'SCENARIO': scenario, 'CANDIDATE_SHA': candidate, 'FIXTURE_SHA': 'b' * 40,
                    'FIXTURE_BLOB': 'c' * 40, 'GITHUB_SHA': 'b' * 40, 'GITHUB_WORKFLOW_SHA': 'b' * 40,
                    'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_WORKFLOW_REF': 'szTheory/sigra/.github/workflows/ci.yml@fixture',
                    'GITHUB_RUN_ID': '901', 'GITHUB_RUN_ATTEMPT': '1',
                    'CLASSIFIER_RESULT': 'success' if scenario == 'docs-only' else '',
                    'DOCS_ONLY': 'true' if scenario == 'docs-only' else 'false',
                    'NATIVE_PRODUCERS_RESULT': 'failure' if scenario == 'actual-failure' else 'success'}
                result = subprocess.run(['bash', '-c', script], cwd=tmp, env=env, capture_output=True, text=True)
                wanted = 0 if scenario in ('full-pass', 'docs-only') else 1
                self.assertEqual(result.returncode, wanted, result.stderr)
                record = json.loads((tmp / 'canary-output/canary-result.json').read_text())
                self.assertEqual(record['validator_exit_code'], wanted)
                self.assertEqual(record['honest_skip_exit_code'], wanted)
                self.assertEqual(record['actual_event'], 'workflow_dispatch')
                self.assertFalse(record['production_dispatch_exemption'])
                if scenario == 'actual-failure':
                    self.assertIn('native', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
