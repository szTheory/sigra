#!/usr/bin/env python3
"""Independent caller integration checks, without importing the amendment renderer."""
from pathlib import Path
import re
import subprocess
import unittest
ROOT = Path(__file__).resolve().parents[2].parent
PHASE = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
BASE = '17d79ca4ca7270b78510e67e40f0e3bfdb5de2d5'
PREFIX = 'python3 -B ' + PHASE + '/253-RECOVERY-BRIDGE-V3.py verify-receipt --consumer 168 || exit $?;'

def receipt_bodies():
    found=[]
    for number in range(168,173):
        text=(ROOT / PHASE / f'253-{number}-PLAN.md').read_text()
        for body in re.findall(r'<automated>(.*?)</automated>',text,re.S):
            if 'verify-receipt' in body:found.append((number,body))
    return found

class CallerTests(unittest.TestCase):
    def test_every_live_receipt_caller_uses_current_consumer_and_exits_on_failure(self):
        bodies=receipt_bodies()
        self.assertEqual([n for n,b in bodies],[168,168,172])
        for n,b in bodies:
            with self.subTest(plan=n):self.assertTrue(b.startswith(PREFIX), b[:200])

    def test_current_instructions_override_old_174_and_inventory_assumptions(self):
        text=(ROOT/PHASE/'253-172-PLAN.md').read_text()
        match=re.search(r'<execution_contract>\n<current_receipt_contract>(.*?)</current_receipt_contract>',text,re.S)
        self.assertIsNotNone(match, 'missing current receipt instruction override')
        for required in ['174 remains halted', '179 local acceptance', '180 local bridge',
                         '73 disposition targets', '28 halted plans', 'PLAN pins 01-183',
                         'supersedes every later reference', 'never hosted completion links']:
            self.assertIn(required,match.group(1))

    def test_plan172_other_work_is_unchanged(self):
        rel=PHASE+'/253-172-PLAN.md'
        original=subprocess.check_output(['git','show',BASE+':'+rel],cwd=ROOT,text=True)
        current=(ROOT/rel).read_text()
        old='python3 '+PHASE+'/253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168 &&'
        self.assertEqual(original.count(old),1)
        self.assertEqual(current, original.replace(old,PREFIX,1))

if __name__=='__main__':unittest.main(verbosity=2)
