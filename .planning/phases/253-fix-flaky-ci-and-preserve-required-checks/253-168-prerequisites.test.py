#!/usr/bin/env python3
"""Independent instruction checks: no amendment renderer is imported."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2].parent
PHASE = Path('.planning/phases/253-fix-flaky-ci-and-preserve-required-checks')
BASE = 'e87b56fe32466749aedaf1ac8b47735a54cbf030'
PLAN = str(PHASE / '253-168-PLAN.md')

def check_instructions(text):
    forbidden = [r'require completed 174', r'174 SUMMARY is complete',
                 r'completed 174.s permission', r'post-253-174 tree',
                 r'sigra\.phase253\.git-permission-recovery/v1',
                 r'SIGRA_253_174_RECEIPT_CONSUMER',
                 r'174, which owns new acceptance']
    for pattern in forbidden:
        if re.search(pattern, text, re.I):
            raise ValueError('stale Plan 174 prerequisite: ' + pattern)
    for required in ['253-179 SUMMARY is complete', '253-180 SUMMARY is complete',
                     '253-174 SUMMARY remains halted',
                     'schema sigra.phase253.successor-acceptance/v1',
                     '253-179-RECOVERY-RECEIPT.json']:
        if required not in text:
            raise ValueError('missing actual prerequisite: ' + required)
    bodies = re.findall(r'<automated>(.*?)</automated>', text, re.S)
    if len(bodies) != 2 or any(not b.startswith('python3 -B ' + str(PHASE) +
           '/253-RECOVERY-BRIDGE-V3.py verify-receipt --consumer 168 || exit $?;') for b in bodies):
        raise ValueError('both tasks must start with the additive receipt check')

class IndependentPrerequisiteTests(unittest.TestCase):
    def test_current_plan_has_real_prerequisites(self):
        check_instructions((ROOT / PLAN).read_text())

    def test_original_contradiction_is_rejected(self):
        original = subprocess.check_output(['git', 'show', BASE + ':' + PLAN], cwd=ROOT, text=True)
        with self.assertRaisesRegex(ValueError, 'stale Plan 174 prerequisite'):
            check_instructions(original)

    def test_mutations_reject_stale_completion_schema_and_consumer(self):
        current = (ROOT / PLAN).read_text()
        check_instructions(current)
        mutations = [('253-179 SUMMARY is complete', '253-174 SUMMARY is complete'),
                     ('sigra.phase253.successor-acceptance/v1', 'sigra.phase253.git-permission-recovery/v1'),
                     ('253-RECOVERY-BRIDGE-V3.py', '253-RECOVERY-BRIDGE-V2.py'),
                     ('253-180 SUMMARY is complete', '253-180 SUMMARY is pending')]
        for old, new in mutations:
            with self.subTest(old=old):
                self.assertIn(old, current)
                changed = current.replace(old, new)
                self.assertNotEqual(current, changed)
                with self.assertRaises(ValueError):
                    check_instructions(changed)
        check_instructions(current)

    def test_original_automated_work_and_budgets_are_unchanged(self):
        original = subprocess.check_output(['git', 'show', BASE + ':' + PLAN], cwd=ROOT, text=True)
        current = (ROOT / PLAN).read_text()
        bodies = lambda t: [b.split('|| exit $?;', 1)[1] for b in re.findall(r'<automated>(.*?)</automated>', t, re.S)]
        self.assertEqual(bodies(original), bodies(current))
        # The entire deadline guard and the two task bodies survive verbatim.
        deadline = lambda t: re.search(r'The R15 deadline guard.*?</precondition>', t, re.S).group(0)
        self.assertEqual(deadline(original), deadline(current))

    def test_actual_receipt_and_summary_statuses(self):
        for n, status in [(174, 'halted'), (179, 'complete'), (180, 'complete')]:
            text = (ROOT / PHASE / f'253-{n}-SUMMARY.md').read_text()
            self.assertRegex(text, rf'(?m)^status: {status}$')
        receipt = json.loads((ROOT / PHASE / '253-179-RECOVERY-RECEIPT.json').read_text())
        self.assertEqual(receipt['schema'], 'sigra.phase253.successor-acceptance/v1')
        self.assertEqual(receipt['attempt_count'], 1)
        self.assertEqual(receipt['full_paged_stop']['cap'], 7)

if __name__ == '__main__':
    unittest.main(verbosity=2)
