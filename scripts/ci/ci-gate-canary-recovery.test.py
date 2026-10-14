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

    def _run_watch(self, tmp, body, api_get):
        """Run the real watch_run function with stubbed transport inside a hermetic TMPDIR."""
        source = RUNNER.read_text()
        function = re.search(r'^watch_run\(\) \{.*?^\}', source, re.M | re.S).group(0)
        stubs = (
            'set -euo pipefail\n'
            # BSD mktemp only substitutes trailing X characters; route legacy /tmp templates
            # into the hermetic TMPDIR so a stale literal name collides here, not in /tmp.
            'mktemp() { local a=() x; for x in "$@"; do a+=("${x/#\\/tmp\\//$TMPDIR/}"); done; command mktemp "${a[@]}"; }\n'
            'WORK_DIR="$(mktemp -d "$TMPDIR/253-canary-test.XXXXXX")"\n'
            + api_get +
            'check_budget() { :; }\n'
            'fail() { echo "FAIL: $*" >&2; exit 1; }\n'
            'sleep() { command sleep 0.01; }\n'
            'MAX_MINUTES=60\nPOLL_INTERVAL=0\n'
            'TERMINAL_RUN_JSON="$WORK_DIR/terminal-run.json"\n'
        )
        env = {**os.environ, 'TMPDIR': str(tmp)}
        return subprocess.run(['bash', '-c', stubs + function + body], text=True, capture_output=True, env=env, timeout=60), function

    def test_expected_watch_failure_returns_without_changing_errexit(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            for stale in ('253-canary-watch-rate.XXXXXX.json', '253-canary-terminal-run.XXXXXX.json'):
                (tmp / stale).write_text('stale')
            (tmp / '253-canary-poll-901.lock').mkdir()  # another poller already owns the run
            result, function = self._run_watch(tmp, '''
watch_status=0
if (watch_run 901 fixture); then watch_status=0; else watch_status=$?; fi
[[ "$watch_status" == 1 ]]
[[ "$-" == *e* ]]
echo completion-can-be-captured
''', 'api_get() { printf \'{"resources":{"core":{"remaining":5000}}}\' > "$2"; }\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('completion-can-be-captured', result.stdout)
        self.assertIn('another poller already owns run 901', result.stderr)
        self.assertNotIn('File exists', result.stderr)
        self.assertNotIn('set +e', function)
        self.assertNotIn('set -e', function)

    def test_terminal_run_is_captured_with_stale_temp_names_present(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            for stale in ('253-canary-watch-rate.XXXXXX.json', '253-canary-terminal-run.XXXXXX.json'):
                (tmp / stale).write_text('stale')
            api_get = (
                'api_get() { case "$1" in rate_limit) printf \'{"resources":{"core":{"remaining":5000}}}\' > "$2" ;;'
                ' *) printf \'{"status":"completed","conclusion":"success"}\' > "$2" ;; esac; }\n')
            result, _ = self._run_watch(tmp, '''
watch_run 901 fixture
[[ "$-" == *e* ]]
jq -e '.conclusion == "success"' "$TERMINAL_RUN_JSON" >/dev/null
echo terminal-run-captured
''', api_get)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('terminal-run-captured', result.stdout)
            self.assertNotIn('File exists', result.stderr)
            self.assertFalse((tmp / '253-canary-poll-901.lock').exists())

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
