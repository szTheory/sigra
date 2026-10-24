#!/usr/bin/env python3
"""Local repaired-control tracer: real child processes, no hosted observations."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / 'scripts/ci/ci-repaired-comparison.py'


def load():
    spec = importlib.util.spec_from_file_location('repaired_comparison', CLI)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LocalTracerTests(unittest.TestCase):
    def test_real_cli_missing_source_is_blocked_and_retained(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'receipt.json'
            child = subprocess.run([sys.executable, '-B', str(CLI), 'local-tracer',
                                    '--source', 'no-such-repaired-source', '--output', str(output)],
                                   cwd=ROOT, text=True, capture_output=True, timeout=30)
            self.assertEqual(child.returncode, 2, child.stderr)
            receipt = json.loads(output.read_text())
            self.assertEqual(receipt['status'], 'blocked')
            self.assertIn('source_unresolved', receipt['blockers'])
            self.assertTrue(receipt['local_only'])
            self.assertEqual(receipt['acceptance_samples'], 0)

    def test_actual_evaluator_reads_local_receipt_path_without_hosted_success(self):
        module = load()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            native = root / 'native.json'
            native.write_text(json.dumps({'complete': True, 'seed': 17, 'failed_count': 0,
                                         'failed_test_ids': [], 'tests': [
                                             {'test_id': 'Fixture.test actual child', 'result': 'passed'}]}))
            identity = {'source_sha': 'a' * 40, 'workflow_sha256': 'b' * 64}
            observation = module.validate_local_report(native, module.digest(native), identity, 0)
            result = module.evaluate_local_observation(ROOT, root / 'evaluation', observation)
            self.assertEqual(result['status'], 'insufficient_data')
            self.assertEqual(result['performance_verdict'], 'insufficient_data')
            self.assertEqual(result['metrics']['comparable_successful_pairs'], 0)
            self.assertEqual(observation['seed'], 17)
            self.assertEqual(observation['test_ids'], ['Fixture.test actual child'])
            self.assertEqual(observation['report_sha256'], hashlib.sha256(native.read_bytes()).hexdigest())
            # Retained contract carries the actual digest-bound observation, never API runs.
            contract = json.loads((root / 'evaluation/contract.json').read_text())
            self.assertEqual(contract['local_observation'], observation)
            self.assertEqual(json.loads((root / 'evaluation/before/manifest.json').read_text())['status'], 'incomplete')

    def test_digest_change_missing_seed_and_fabricated_hosted_success_rejected(self):
        module = load()
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / 'report.json'
            base = {'complete': True, 'seed': 3, 'failed_count': 0,
                    'failed_test_ids': [], 'tests': [{'test_id': 'test one', 'result': 'passed'}]}
            report.write_text(json.dumps(base))
            identity = {'source_sha': 'a' * 40, 'workflow_sha256': 'b' * 64}
            with self.assertRaisesRegex(ValueError, 'digest'):
                module.validate_local_report(report, '0' * 64, identity, 0)
            for change in ({'seed': None}, {'complete': False}, {'tests': []},
                           {'failed_count': 1}, {'performance_verdict': 'pass'},
                           {'run_id': 42}, {'tests': [{'test_id': 'test one', 'result': 'failed'}]}):
                report.write_text(json.dumps({**base, **change}))
                with self.subTest(change=change), self.assertRaises(ValueError):
                    module.validate_local_report(report, module.digest(report), identity, 0)
            report.unlink()
            with self.assertRaises(ValueError):
                module.validate_local_report(report, '0' * 64, identity, 0)

    def test_existing_receipt_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'receipt.json'
            output.write_bytes(b'preserve these exact prior bytes\n')
            child = subprocess.run([sys.executable, '-B', str(CLI), 'local-tracer',
                                    '--source', 'HEAD', '--output', str(output)],
                                   cwd=ROOT, capture_output=True, timeout=30)
            self.assertNotEqual(child.returncode, 0)
            self.assertEqual(output.read_bytes(), b'preserve these exact prior bytes\n')


if __name__ == '__main__':
    unittest.main()
