#!/usr/bin/env python3
"""Mutation checks for the additive consumer, isolated from the real checkout."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2].parent
PHASE = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
spec = importlib.util.spec_from_file_location('v3', ROOT / PHASE / '253-RECOVERY-BRIDGE-V3.py')
v3 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v3)

class ConsumerTests(unittest.TestCase):
    def test_168_mode_does_not_authorize_later_169_source_changes(self):
        with self.assertRaisesRegex(ValueError, 'history changed'):
            v3.validate_current(ROOT)

    def test_scoped_correction_matches_current(self):
        original, count = v3.validate_current(ROOT, '172')
        self.assertGreater(count, 100)
        self.assertEqual(v3.corrected_plan(original), (ROOT / v3.PLAN).read_bytes())

    def test_mutated_plan_receipt_and_history_are_rejected(self):
        rows = v3.git(ROOT, 'ls-tree', '-rz', '--name-only', v3.BASE, '--', PHASE,
                      '.planning/phases/252-measure-current-ci').decode().rstrip('\0').split('\0')
        with tempfile.TemporaryDirectory(prefix='sigra168-mutations-') as directory:
            root = Path(directory)
            (root / '.git').symlink_to(ROOT / '.git', target_is_directory=True)
            for rel in rows:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(ROOT / rel)
            for rel in [v3.EXECUTION_169, PHASE + '/253-169-SUMMARY.md']:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(ROOT / rel)
            v3.validate_current(root, '172')
            mutations = [(v3.PLAN, b'wrong receipt schema'),
                         (v3.PLAN_172, b'wrong receipt prefix'),
                         (v3.TOOLING_169[0], b'changed reconciliation source'),
                         (v3.EXECUTION_169, b'{}'),
                         (PHASE + '/253-179-RECOVERY-RECEIPT.json', b'{}'),
                         (PHASE + '/253-180-BRIDGE-V2-RECORD.json', b'{}'),
                         (PHASE + '/253-174-SUMMARY.md', b'status: complete\n'),
                         (PHASE + '/253-183-SUMMARY.md', b'status: complete\n')]
            for rel, data in mutations:
                with self.subTest(rel=rel):
                    target = root / rel
                    original = target.read_bytes()
                    self.assertNotEqual(original, data)
                    target.unlink()  # replace only the temporary symlink
                    try:
                        target.write_bytes(data)
                        with self.assertRaisesRegex(ValueError, 'differs|history changed'):
                            v3.validate_current(root, '172')
                    finally:
                        target.unlink()
                        target.symlink_to(ROOT / rel)
                    self.assertEqual((ROOT / rel).read_bytes(), original)
            v3.validate_current(root, '172')

if __name__ == '__main__':
    unittest.main(verbosity=2)
