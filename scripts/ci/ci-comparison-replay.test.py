#!/usr/bin/env python3
"""Real saved-input replay contract; never dispatch collection."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / 'scripts/ci/ci-comparison-replay.py'
SAVED = ROOT / '.planning/execution/254-environment-recovery/MEASUREMENT'


class ReplayTest(unittest.TestCase):
    def test_saved_result_is_calculated_without_changing_inputs(self):
        originals = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in SAVED.rglob('*') if p.is_file()}
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'result.json'
            command = [sys.executable, '-B', str(CLI), 'replay', '--from-evidence', '--output', str(output)]
            run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, 'saved comparison must calculate: ' + run.stderr)
            result = json.loads(output.read_text())
            self.assertEqual(result, json.loads((SAVED / 'EVALUATION-COSTS.json').read_text()))
            self.assertEqual(result['performance_verdict'], 'insufficient_data')
            self.assertEqual(result['metrics']['comparable_successful_pairs'], 0)
            self.assertEqual(result['metrics']['baseline_runner_seconds'], 2046)
            self.assertEqual(result['metrics']['candidate_runner_seconds'], 1589)
            for role in ['baseline', 'candidate']:
                for stat in ['median', 'p95']:
                    self.assertIsNone(result['metrics'][f'{role}_{stat}_seconds'])
        self.assertEqual(originals, {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in originals})

    def test_portable_package_calculates_in_an_empty_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            package = tmp / 'inputs.tar.gz'
            pack = subprocess.run([sys.executable, '-B', str(CLI), 'pack', '--output', str(package)],
                                  cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(pack.returncode, 0, 'portable packaging must succeed: ' + pack.stderr)
            output = tmp / 'result.json'
            replay = subprocess.run([sys.executable, '-B', str(CLI), 'replay', '--package', str(package),
                                     '--output', str(output)], cwd=tmp, capture_output=True, text=True)
            self.assertEqual(replay.returncode, 0, replay.stderr)
            self.assertEqual(json.loads(output.read_text()), json.loads((SAVED / 'EVALUATION-COSTS.json').read_text()))


if __name__ == '__main__':
    unittest.main(verbosity=2)
