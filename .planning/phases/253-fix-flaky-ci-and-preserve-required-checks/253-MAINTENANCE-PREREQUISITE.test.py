#!/usr/bin/env python3
"""Local prerequisite tests. Disposable fixtures are not actual acceptance proof."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
PHASE = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
SPEC = importlib.util.spec_from_file_location('successor', ROOT / PHASE / '253-RECOVERY-SUCCESSOR.py')
s = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(s)
CHECKS = '.planning/quick/261020-swa-phase-253-reconnect-acceptance-prerequis/CHECKS.json'

class MaintenancePrerequisiteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sigra253-maintenance-prerequisite-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        subprocess.run(['git', 'clone', '--quiet', '--shared', '--no-checkout', str(ROOT), str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'checkout', '--quiet', s.MAINTENANCE_BASELINE], check=True)
        # Scoped ref is deliberately copied from the retained real capture; no network.
        diagnostic = json.loads((ROOT / s.MAINTENANCE_RESULT).read_bytes())
        subprocess.run(['git', '-C', str(self.root), 'update-ref', diagnostic['diagnostic_ref'], diagnostic['diagnostic_commit']], check=True)
        for rel in s.MAINTENANCE_SOURCES:
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / rel).read_bytes())
        self.bindings = {rel:s.sha256((self.root / rel).read_bytes()) for rel in s.MAINTENANCE_SOURCES}
        checks = {'status':'passed', 'source_sha256':self.bindings, 'acceptance_attempts':0,
                  'github_requests':0, 'historical183_status':'halted', 'synthetic_test_fixture':True}
        target = self.root / CHECKS
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(checks))
        self.authority = {'schema':'sigra.phase253.maintenance-prerequisite/v1',
                          'status':'verified_local_maintenance', 'repair_task':s.MAINTENANCE_TASK,
                          'baseline_commit':s.MAINTENANCE_BASELINE, 'budget_renewal':False,
                          'acceptance_attempts':0, 'github_requests':0,
                          'requirements':{'CIREL-01':'partial_not_reproduced','CIREL-02':'unaccepted'},
                          'phase_verification_status':'not_started', 'source_sha256':self.bindings,
                          'validation':{'path':CHECKS,'sha256':s.sha256(target.read_bytes())}}
        self.write_authority()

    def write_authority(self):
        (self.root / s.MAINTENANCE_AUTHORITY).write_text(json.dumps(self.authority))

    def test_current_maintenance_replaces_halted_dependency_without_launch(self):
        with mock.patch.object(s, 'validate_review183', side_effect=AssertionError('old route invoked')):
            self.assertEqual(s.acceptance_prerequisite(self.root), (s.MAINTENANCE_TASK,s.MAINTENANCE_AUTHORITY))
        self.assertRegex((self.root / PHASE / '253-183-SUMMARY.md').read_text(), r'(?m)^status: halted$')
        self.assertFalse((self.root / s.RECEIPT_179).exists())
        for number in (179,180):
            rel=f'{PHASE}/253-{number}-PLAN.md'
            original=s.git(self.root,'show',f'{s.MAINTENANCE_BASELINE}:{rel}').decode()
            self.assertEqual(re.findall(r'<automated>(.*?)</automated>',original,re.S),
                             re.findall(r'<automated>(.*?)</automated>',(self.root/rel).read_text(),re.S))

    def test_budget_and_acceptance_claims_refuse(self):
        for field,value in [('budget_renewal',True),('acceptance_attempts',1),('github_requests',1),
                            ('phase_verification_status','passed')]:
            with self.subTest(field=field):
                old=self.authority[field];self.authority[field]=value;self.write_authority()
                with self.assertRaisesRegex(s.ContractError,'budgets or claims acceptance'):
                    s.validate_maintenance_prerequisite(self.root)
                self.authority[field]=old
        self.write_authority();s.validate_maintenance_prerequisite(self.root)

    def test_changed_source_or_rehashed_command_refuses(self):
        rel=s.PLAN_179;target=self.root/rel;old=target.read_bytes()
        target.write_bytes(old+b'changed\n')
        with self.assertRaisesRegex(s.ContractError,'tested source changed'):
            s.validate_maintenance_prerequisite(self.root)
        target.write_bytes(old.replace(b'exec bash',b'exec sh',1))
        self.authority['source_sha256'][rel]=s.sha256(target.read_bytes());self.write_authority()
        with self.assertRaisesRegex(s.ContractError,'changed an acceptance command'):
            s.validate_maintenance_prerequisite(self.root)

    def test_historical_halt_and_budget_bytes_refuse_even_if_source_rehashed(self):
        for rel in (f'{PHASE}/253-183-SUMMARY.md',s.R12_CONTRACT,'scripts/ci/ci-git-publication.test.py'):
            with self.subTest(path=rel):
                target=self.root/rel;old=target.read_bytes();target.write_bytes(old+b'changed\n')
                with self.assertRaisesRegex(s.ContractError,'historical/budget source changed'):
                    s.validate_maintenance_prerequisite(self.root)
                target.write_bytes(old)
        s.validate_maintenance_prerequisite(self.root)

    def test_only_bridge_consumer_can_defer_active_plan_checks(self):
        target=self.root/PHASE/'253-168-PLAN.md';target.write_bytes(target.read_bytes()+b'fixture amendment\n')
        with self.assertRaisesRegex(s.ContractError,'historical/budget source changed'):
            s.validate_maintenance_prerequisite(self.root)
        # The real receipt consumer must still run its separate exact bridge validator.
        s.validate_maintenance_prerequisite(self.root,bridge_consumer=True)
        target=self.root/PHASE/'253-183-SUMMARY.md';target.write_bytes(target.read_bytes()+b'changed\n')
        with self.assertRaisesRegex(s.ContractError,'historical/budget source changed'):
            s.validate_maintenance_prerequisite(self.root,bridge_consumer=True)

    def test_missing_stale_validation_and_retained_capture_refuse(self):
        target=self.root/CHECKS;old=target.read_bytes();target.write_bytes(old+b' ')
        with self.assertRaises(s.ContractError):s.validate_maintenance_prerequisite(self.root)
        target.write_bytes(old)
        value=json.loads(old);value['status']='failed';target.write_text(json.dumps(value))
        self.authority['validation']['sha256']=s.sha256(target.read_bytes());self.write_authority()
        with self.assertRaisesRegex(s.ContractError,'validation is missing or stale'):
            s.validate_maintenance_prerequisite(self.root)
        target.write_bytes(old);self.authority['validation']['sha256']=s.sha256(old);self.write_authority()
        result=json.loads((self.root/s.MAINTENANCE_RESULT).read_bytes())
        subprocess.run(['git','-C',str(self.root),'update-ref',result['diagnostic_ref'],s.MAINTENANCE_BASELINE],check=True)
        with self.assertRaisesRegex(s.ContractError,'diagnostic ref'):
            s.validate_maintenance_prerequisite(self.root)

if __name__=='__main__':unittest.main(verbosity=2)
