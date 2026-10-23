"""Development checks of approval/cleanup boundaries and actual native report reading."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('diagnostic', HERE / 'diagnostic.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class NativeResultTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads((HERE.parent / '253-registration-order-recovery/full-prefix-output/browser.log').read_text())
        cls.expected = m.selection(cls.report)
        assert len(cls.expected) == 161

    def test_retained_real_mac_report_does_not_claim_reproduction(self):
        self.assertEqual(m.classify_browser(self.report, self.expected), 'not_reproduced')

    def mutated(self, index, status):
        report = copy.deepcopy(self.report)
        tests = []
        def walk(s):
            for spec in s.get('specs', []):
                tests.extend(spec['tests'])
            for child in s.get('suites', []):
                walk(child)
        walk(report)
        tests[index]['results'][0]['status'] = status
        return report, tests

    def test_target_failure_is_a_reproduction_not_a_fixed_cause(self):
        report, tests = self.mutated(160, 'failed')
        tests[160]['results'][0]['errors'] = [{'message': 'page.waitForURL: Timeout 10000ms exceeded.; registration diagnostics={"registrationRequest":null,"registrationPost":null,"registrationRequestFailure":null}'}]
        self.assertEqual(m.classify_browser(report, self.expected), 'selected_failure_reproduced_cause_unproved')

    def test_same_target_with_different_error_is_not_registration_reproduction(self):
        report, tests = self.mutated(160, 'failed')
        tests[160]['results'][0]['errors'] = [{'message': 'expect(screenshot).toMatchSnapshot() failed'}]
        self.assertEqual(m.classify_browser(report, self.expected), 'other_failure_needs_diagnosis')

    def test_earlier_failure_is_not_target_reproduction(self):
        report, _ = self.mutated(0, 'failed')
        self.assertEqual(m.classify_browser(report, self.expected), 'other_failure_needs_diagnosis')

    def test_skipped_target_is_not_reproduction(self):
        report, _ = self.mutated(160, 'skipped')
        self.assertEqual(m.classify_browser(report, self.expected), 'other_failure_needs_diagnosis')

    def test_retry_cannot_be_accepted(self):
        report, tests = self.mutated(160, 'passed')
        tests[160]['results'][0]['retry'] = 1
        with self.assertRaisesRegex(AssertionError, 'retries'):
            m.classify_browser(report, self.expected)

    def test_report_errors_cannot_be_accepted(self):
        report = copy.deepcopy(self.report)
        report['errors'] = [{'message': 'worker process crashed'}]
        with self.assertRaisesRegex(AssertionError, 'global errors'):
            m.classify_browser(report, self.expected)

    def test_wrong_project_order_rejected(self):
        expected = list(self.expected)
        expected[0] = (expected[0][0], 'admin-eval-dark')
        with self.assertRaisesRegex(AssertionError, 'order differs'):
            m.classify_browser(self.report, expected)


class ExecutionBoundaryTests(unittest.TestCase):
    def test_python_optimization_cannot_disable_the_guards(self):
        result = subprocess.run([sys.executable, '-O', str(HERE / 'diagnostic.py'), '--run'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('optimization disables required checks', result.stderr)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.here = Path(self.temp.name)
        p = patch.object(m, 'HERE', self.here)
        p.start()
        self.addCleanup(p.stop)
        self.prep = {'postgres': 'pinned-postgres', 'image_id': 'immutable-image'}
        p = patch.object(m, 'preflight', return_value=self.prep)
        p.start()
        self.addCleanup(p.stop)
        self.proposal = {'file_sha256': {}, 'limits': {'seconds_including_cleanup': 2400}}
        (self.here / 'proposal.json').write_text(json.dumps(self.proposal))

    def approve(self):
        (self.here / 'approval.json').write_text(json.dumps({'decision': 'approved', 'proposal_sha256': m.digest(self.here / 'proposal.json')}))

    def test_no_new_approval_means_no_allocation(self):
        with patch.object(m.subprocess, 'run') as run:
            with self.assertRaisesRegex(AssertionError, 'own approval'):
                m.execute()
            run.assert_not_called()
        self.assertFalse((self.here / 'reservation.json').exists())

    def test_old_or_wrong_approval_rejected_before_allocation(self):
        (self.here / 'approval.json').write_text(json.dumps({'decision': 'approved', 'proposal_sha256': 'old-completed-proposal'}))
        with patch.object(m.subprocess, 'run') as run:
            with self.assertRaisesRegex(AssertionError, 'does not match'):
                m.execute()
            run.assert_not_called()

    def test_consumed_marker_prevents_second_allocation(self):
        self.approve()
        (self.here / 'reservation.json').write_text('original reservation')
        with patch.object(m.subprocess, 'run') as run:
            with self.assertRaises(FileExistsError):
                m.execute()
            run.assert_not_called()
        self.assertEqual((self.here / 'reservation.json').read_text(), 'original reservation')

    def test_changed_approved_file_rejected(self):
        owned = self.here / 'runner.py'
        owned.write_text('before')
        self.proposal['file_sha256']['runner.py'] = m.digest(owned)
        (self.here / 'proposal.json').write_text(json.dumps(self.proposal))
        self.approve()
        owned.write_text('after')
        with patch.object(m.subprocess, 'run') as run:
            with self.assertRaisesRegex(AssertionError, 'approved file changed'):
                m.execute()
            run.assert_not_called()

    def test_timeout_removes_owned_app_and_database_and_keeps_reservation(self):
        self.approve()
        calls = []
        def run(args, **kw):
            calls.append(args)
            if '--mount' in args:
                raise subprocess.TimeoutExpired(args, 2360)
            return subprocess.CompletedProcess(args, 0)
        def output(args, **kw):
            return 'postgres (PostgreSQL) 15.19 (Debian)' if '--version' in args else ''
        with patch.object(m.subprocess, 'run', side_effect=run), patch.object(m.subprocess, 'check_output', side_effect=output):
            with self.assertRaises(subprocess.TimeoutExpired):
                m.execute()
        result = json.loads((self.here / 'diagnostic-output/host-result.json').read_text())
        self.assertTrue(result['cleanup_complete'])
        self.assertEqual(len([c for c in calls if c[1:4] == ['rm', '-f', '-v']]), 2)
        self.assertTrue((self.here / 'reservation.json').exists())
        self.assertFalse(result['acceptance'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
