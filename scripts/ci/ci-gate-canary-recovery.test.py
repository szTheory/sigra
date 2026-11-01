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
    def _recorders(self, tmp):
        """Fake gh and curl on PATH that record any invocation; returns (env, marker path)."""
        marker = tmp / 'calls'
        for name in ('gh', 'curl'):
            stub = tmp / name
            stub.write_text(f'#!/bin/sh\nprintf "{name} %s\\n" "$*" >> "$GITHUB_CALL_MARKER"\nexit 99\n')
            stub.chmod(0o755)
        env = {**os.environ, 'PATH': f'{tmp}:{os.environ["PATH"]}', 'GITHUB_CALL_MARKER': str(marker)}
        return env, marker

    def test_missing_recovery_freeze_refuses_before_any_github_command(self):
        # Since 253-11 (307dd9591) the reviewed-freeze requirement precedes the halted-evidence check.
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            env, marker = self._recorders(tmp)
            evidence = tmp / 'halted.json'
            evidence.write_text(json.dumps({'status': 'halted', 'diagnostics': {'full_pass': {'source_status': 'unverified'}}}))
            original = evidence.read_bytes()
            result = subprocess.run(['bash', str(RUNNER), '--scenario', 'full-pass', '--evidence', str(evidence)],
                                    env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stderr, 'ci-gate-canary: FAIL: hosted execution requires the separately reviewed recovery freeze\n')
            self.assertFalse(marker.exists(), result.stderr)
            self.assertEqual(evidence.read_bytes(), original)

    def _synthetic_repo(self, tmp):
        """Disposable git repo with a self-consistent recovery freeze (mirrors ci-gate-canary.test.sh)."""
        repo = tmp / 'repo'
        phase = repo / PHASE.relative_to(ROOT)
        (repo / 'scripts/ci').mkdir(parents=True)
        (repo / '.github/workflows').mkdir(parents=True)
        phase.mkdir(parents=True)
        for name in ('ci-gate-canary.sh', 'ci-gate-canary.test.sh', 'ci-hosted-gate-verify.py', 'ci-hosted-gate-verify.test.py',
                     'ci-browser-records.mjs', 'honest-skip-verdict.sh', 'ci-hosted-transport.py'):
            shutil.copyfile(ROOT / 'scripts/ci' / name, repo / 'scripts/ci' / name)
        for name in ('ci-observe.yml', 'release-pr-automerge.yml', 'release-run-observer.yml'):
            shutil.copyfile(ROOT / '.github/workflows' / name, repo / '.github/workflows' / name)
        (repo / '.github/workflows/ci.yml').write_text(
            'name: Phase 253 Gate Canary\non:\n  workflow_dispatch:\n    inputs: {}\npermissions:\n  contents: read\n'
            'jobs:\n  producers:\n    strategy:\n      matrix:\n        seam: [non_admin_smoke, admin_behavior, admin_checkpoints, design_gallery, demo_showcase]\n'
            '  verdict: {}\n  verifier:\n    permissions:\n      contents: read\n      actions: read\n')
        shutil.copyfile(PHASE / '253-RECOVERY-CANARY-WORKFLOW.yml', phase / '253-RECOVERY-CANARY-WORKFLOW.yml')
        (phase / '253-PREHOST-REVIEW.md').write_text('# review\n')

        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid',
                                            *args], text=True).strip()
        git('init', '-q', '-b', 'main')
        git('add', 'scripts/ci', '.github/workflows', str(phase.relative_to(repo)))
        git('commit', '-qm', 'candidate')
        candidate = git('rev-parse', 'HEAD')
        blob = git('rev-parse', 'HEAD:.github/workflows/ci.yml')
        git('commit', '--allow-empty', '-qm', 'fixture')
        fixture = git('rev-parse', 'HEAD')
        ref = 'refs/heads/gsd/253-replan-canary-fixture-recovery-test'
        git('update-ref', ref, fixture)
        paths = ('scripts/ci/ci-gate-canary.sh', 'scripts/ci/ci-gate-canary.test.sh', 'scripts/ci/ci-hosted-gate-verify.py',
                 'scripts/ci/ci-hosted-gate-verify.test.py', 'scripts/ci/ci-hosted-transport.py')
        outcomes = [('full-pass', 'success'), ('docs-only', 'success'), ('actual-failure', 'failure'),
                    ('missing-seam', 'failure'), ('unexpected-skip', 'failure'), ('cancelled', 'cancelled')]
        freeze = {
            'schema_version': 'sigra.recovery-canary-freeze/v1',
            'identity': {'candidate_helper_commit': candidate, 'fixture_workflow_commit': fixture, 'fixture_workflow_blob': blob,
                         'fixture_ref': ref, 'old_failed_run_id': '38347679431',
                         'old_failed_fixture_ref': 'refs/heads/old-failed-fixture', 'old_failed_fixture_blob': '0' * 40},
            'scenarios': {'count': 6, 'optional_infrastructure_retry': 1,
                          'cases': [{'name': n, 'expected_outcome': o} for n, o in outcomes]},
            'bounds': {'max_requests': 120, 'max_actual_tiny_jobs': 45, 'max_minutes': 60, 'max_infrastructure_retries': 1,
                       'max_dispatch_input_keys': 10, 'max_dispatch_input_chars': 65535,
                       'max_artifact_compressed_bytes': 2097152, 'max_artifact_extracted_bytes': 4194304},
            'required_checks': ['Library tests', 'Example unit smoke (ExUnit + ConnTest)',
                                'Install smoke (fresh phx.new + sigra.install)',
                                'Example HTTP smoke (boot + curl critical routes)', 'Example Playwright smoke (full lifecycle)'],
            'workflow': {'permissions': {'contents': 'read'}, 'trigger': ['workflow_dispatch'],
                         'jobs': {'tiny_producers': 5, 'verdict': 1, 'independent_verifier': 1, 'observer_trigger': False}},
            'historical': {'previous_accounted_or_reserved_requests': 20, 'previous_exact_http_count_proven': False},
            'source_sha256': {n: __import__('hashlib').sha256((repo / n).read_bytes()).hexdigest() for n in paths},
        }
        freeze_path = phase / '253-RECOVERY-CANARY-FREEZE.json'
        freeze_path.write_text(json.dumps(freeze, indent=2) + '\n')
        return repo, phase, freeze_path

    def test_halted_evidence_with_reviewed_freeze_stops_before_any_github_command(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            env, marker = self._recorders(tmp)
            repo, phase, freeze = self._synthetic_repo(tmp)
            evidence = phase / '253-RECOVERY-CANARY-EVIDENCE.json'
            evidence.write_text(json.dumps({'status': 'halted', 'diagnostics': {'full_pass': {'source_status': 'unverified'}}}))
            original = evidence.read_bytes()
            result = subprocess.run(['bash', str(repo / 'scripts/ci/ci-gate-canary.sh'), '--scenario', 'full-pass',
                                     '--evidence', str(evidence), '--recovery-freeze', str(freeze)],
                                    cwd=repo, env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stderr,
                'ci-gate-canary: FAIL: halted evidence requires a separately authorized new freeze; '
                'existing diagnostics cannot be retried\n')
            self.assertFalse(marker.exists(), result.stderr)
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
