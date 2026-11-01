#!/usr/bin/env python3
"""Offline versioned-consumer checks; all amendments/SDK simulations stay in /tmp."""
from pathlib import Path
import contextlib
import ast
import os
import copy
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
PHASE = '.planning/phases/253-fix-flaky-ci-and-preserve-required-checks'
SPEC = importlib.util.spec_from_file_location('bridge_v2', ROOT / PHASE / '253-RECOVERY-BRIDGE-V2.py')
v2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(v2)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE)


@contextlib.contextmanager
def changed(path, raw):
    before = path.read_bytes()
    try:
        path.write_bytes(raw)
        yield
    finally:
        path.write_bytes(before)


class ConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        evidence = os.environ.get('SIGRA_V2_TEST_EVIDENCE_DIR')
        cls.temp = tempfile.TemporaryDirectory(prefix='sigra253-v2-tests-') if not evidence else None
        cls.work = Path(evidence).resolve() if evidence else Path(cls.temp.name)
        if evidence:
            if cls.work == ROOT or ROOT in cls.work.parents:
                raise AssertionError('Test evidence must remain outside the checkout')
            cls.work.mkdir(parents=True, exist_ok=False)
        cls.root = cls.work / 'project'
        subprocess.run(['git','clone','--shared','--no-checkout','--quiet',str(ROOT),str(cls.root)],check=True)
        git(cls.root,'checkout','--quiet','--detach','HEAD')
        git(cls.root,'config','user.name','Versioned Consumer Fixture')
        git(cls.root,'config','user.email','fixture@example.invalid')
        # Include exactly the current additive implementation, never alter pinned inputs.
        for name in ['253-RECOVERY-BRIDGE-V2.py','253-RECOVERY-BRIDGE-V2.test.py']:
            shutil.copyfile(ROOT / PHASE / name,cls.root / PHASE / name)
        cls.receipt=json.loads((cls.root / v2.RECEIPT_179).read_text())
        cls.source=cls.receipt['source_commit']
        git(cls.root,'update-ref',v2.ORIGINALS_180,cls.source)
        cls.original={f'{PHASE}/253-{n}-PLAN.md':git(cls.root,'show',f'{cls.source}:{PHASE}/253-{n}-PLAN.md') for n in (168,169,170,171,172,176,177)}
        cls.original_summaries={p.name:p.read_bytes() for p in (cls.root/PHASE).glob('*-SUMMARY.md')}
        cls.render_dir=cls.work/'render'
        cls.render=v2.render_amendments(cls.root,cls.render_dir)
        for rel in cls.render['plans']:
            shutil.copyfile(cls.render_dir/Path(rel).name,cls.root/rel)
        git(cls.root,'add','.planning')
        git(cls.root,'commit','--quiet','-m','Synthetic current v2 consumer and five amended plans')
        cls.record={'schema':v2.BRIDGE_SCHEMA,'stage':'complete','source_commit':cls.source,'preservation_ref':v2.ORIGINALS_180,
                    'originals':{rel:{'blob':git(cls.root,'rev-parse',f'{cls.source}:{rel}').decode().strip(),'sha256':v2.sha256(raw),'bytes':len(raw)} for rel,raw in cls.original.items()},
                    'protected_source_bindings':cls.receipt['historical_sha256'],
                    'amended_sha256':{rel:row['amended_sha256'] for rel,row in cls.render['plans'].items()},'dispositions_for':[]}
        # This executes four real installed-SDK queries in an additional disposable committed copy.
        cls.report=v2.run_sdk_copy(cls.root,cls.record,v2.BRIDGE_180)
        report_path=cls.work/'sdk-report.json';report_path.write_text(json.dumps(cls.report,indent=2)+'\n')
        cls.record['sdk_copy']={'report_path':str(report_path),'report_sha256':v2.sha256(report_path.read_bytes())}
        (cls.root/v2.BRIDGE_180).write_text(json.dumps(cls.record,indent=2)+'\n')
        cls.index=json.loads(cls.report['sdk_queries']['readiness_index']['stdout'])
        cls.init=json.loads(cls.report['sdk_queries']['readiness_init']['stdout'])

    @classmethod
    def tearDownClass(cls):
        if cls.temp is not None:
            cls.temp.cleanup()

    def test_01_real_sdk_copy_preserves_all28_halts_and_every_existing_summary(self):
        self.assertEqual(self.report['post_chain_halted'],28)
        self.assertEqual(self.report['post_chain_incomplete'],0)
        self.assertIn('253-183',self.report['post_chain_halted_ids'])
        for name,raw in self.original_summaries.items():
            self.assertEqual((self.root/PHASE/name).read_bytes(),raw)
            self.assertEqual(self.report['preserved_summary_sha256'][name],v2.sha256(raw))
        self.assertNotIn(f'{PHASE}/253-183-SUMMARY.md',self.report['source_manifest_exclusions']['simulation_summaries'])

    def test_02_versioned_bridge_accepts_exact_amendments_and_raw_sdk_report(self):
        self.assertEqual(v2.validate_bridge(self.root,'complete',v2.BRIDGE_180)['status'],'verified')

    def test_03_old_index_validator_still_refuses_current28_halt_copy(self):
        with self.assertRaisesRegex(v2.ContractError,'exact27'):
            v2.legacy.validate_sdk_index_rows(self.index['plans'],self.init,'readiness')
        self.assertEqual(v2.legacy.ACTIVE_HALT_COUNT,27)

    def test_04_versioned_index_refuses_forged183_completion(self):
        rows=copy.deepcopy(self.index['plans']);row=next(x for x in rows if x['id']=='253-183');row['halted']=False
        with self.assertRaisesRegex(v2.ContractError,'exact28'):
            v2.validate_sdk_index_rows(rows,self.init,'readiness')

    def test_05_duplicate_and_missing_plan_rows_refuse(self):
        for rows in [self.index['plans'][:-1],self.index['plans'][:-1]+[self.index['plans'][0]]]:
            with self.subTest(size=len(rows)),self.assertRaises(v2.ContractError):v2.validate_sdk_index_rows(rows,self.init,'readiness')

    def test_06_169_uses_exact28_halts183_pins73_targets_and_no_halted_proof_owner(self):
        text=(self.root/PHASE/'253-169-PLAN.md').read_text();v2.validate_169_executable_contract(text,self.root)
        self.assertIn('183 -> [179, 180]',text);self.assertNotIn('[183, 179]',text)
        self.assertNotIn('164, 165, 166, 174, 168, 170, 171',text)
        self.assertNotRegex(text,r'completed 174|174 is complete|Twenty-two halted|twenty-two halted')
        self.assertIn('176 partition members',text)

    def test_07_frozen_hash_literals_and_deadline_commands_are_unchanged(self):
        for number in (168,169,170,171,172):
            old=self.original[f'{PHASE}/253-{number}-PLAN.md'].decode();new=(self.root/PHASE/f'253-{number}-PLAN.md').read_text()
            self.assertEqual(re.findall(r'\b[a-f0-9]{64}\b',old),re.findall(r'\b[a-f0-9]{64}\b',new))
            pattern=r"\$HOME/\.asdf/installs/nodejs/20\.18\.1/bin/node -e '.*?' "+re.escape(PHASE)+r'/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R12\.json 1'
            self.assertEqual(re.findall(pattern,old,re.S),re.findall(pattern,new,re.S))

    def test_08_hosted_operator_tasks_and_all_eight_completion_links_unchanged(self):
        for number in (170,171):
            old=self.original[f'{PHASE}/253-{number}-PLAN.md'].decode();new=(self.root/PHASE/f'253-{number}-PLAN.md').read_text()
            self.assertEqual(re.findall(r'<task\b.*?</task>',old,re.S),re.findall(r'<task\b.*?</task>',new,re.S))
        old=self.original[f'{PHASE}/253-172-PLAN.md'].decode();new=(self.root/PHASE/'253-172-PLAN.md').read_text();pat=r'(?m)^\s*-\s+([a-z0-9_]+)\s*=\s*([^;\n]+)'
        self.assertEqual(len(re.findall(pat,old)),8);self.assertEqual(re.findall(pat,old),re.findall(pat,new))

    def test_09_tampered_hosted_tasks_and_caps_refuse_even_with_rehashed_record(self):
        rel=f'{PHASE}/253-170-PLAN.md';path=self.root/rel
        old_record=(self.root/v2.BRIDGE_180).read_bytes()
        try:
            for anchor,replacement in [('120','121'),('<action>','<action>Changed operator contract. ')]:
                raw=path.read_bytes();self.assertIn(anchor.encode(),raw);new=raw.replace(anchor.encode(),replacement.encode(),1)
                record=copy.deepcopy(self.record);record['amended_sha256'][rel]=v2.sha256(new)
                with changed(path,new):
                    (self.root/v2.BRIDGE_180).write_text(json.dumps(record))
                    with self.assertRaises(v2.ContractError):v2.validate_bridge(self.root,'complete',v2.BRIDGE_180)
        finally:(self.root/v2.BRIDGE_180).write_bytes(old_record)

    def test_10_changed_receipt_pinned_helper_or_historical_halt_refuses(self):
        for rel in [f'{PHASE}/253-RECOVERY-SUCCESSOR.py',f'{PHASE}/253-183-SUMMARY.md']:
            with self.subTest(rel=rel),changed(self.root/rel,(self.root/rel).read_bytes()+b'\nchanged\n'):
                with self.assertRaisesRegex(v2.ContractError,'unapproved protected file'):v2.validate_bridge(self.root,'complete',v2.BRIDGE_180)

    def test_11_169_stale_counts_and_wrong_owner_refuse(self):
        path=self.root/PHASE/'253-169-PLAN.md';old=path.read_text()
        for anchor,replacement in [('length!==28','length!==27'),('183 -> [179, 180]','183 -> [183, 179]')]:
            self.assertIn(anchor,old)
            with self.subTest(anchor=anchor),changed(path,old.replace(anchor,replacement,1).encode()):
                with self.assertRaises(v2.ContractError):v2.validate_bridge(self.root,'complete',v2.BRIDGE_180)

    def test_12_report_missing_native_query_or_wrong_hash_refuses(self):
        for key in ['readiness_init','readiness_index','post_init','post_index']:
            report=copy.deepcopy(self.report);report['sdk_queries'][key]['stdout']='{}'
            with self.subTest(key=key),self.assertRaises(v2.ContractError):v2.validate_sdk_copy_report_data(self.root,report)

    def test_13_report_rehashed_forged183_completion_still_refuses(self):
        report=copy.deepcopy(self.report);q=report['sdk_queries']['post_index'];j=json.loads(q['stdout']);next(x for x in j['plans'] if x['id']=='253-183')['halted']=False;q['stdout']=json.dumps(j);q['stdout_sha256']=v2.sha256(q['stdout'].encode());report['post_chain_index_sha256']=q['stdout_sha256']
        with self.assertRaisesRegex(v2.ContractError,'exact28'):v2.validate_sdk_copy_report_data(self.root,report)

    def test_14_no_disposition_for_a_halt_and_no_budget_replenishment(self):
        record=copy.deepcopy(self.record);record['dispositions_for']=['253-183']
        path=self.root/v2.BRIDGE_180
        with changed(path,json.dumps(record).encode()):
            with self.assertRaisesRegex(v2.ContractError,'may not disposition'):v2.validate_bridge(self.root,'complete',v2.BRIDGE_180)
        self.assertEqual(self.receipt['full_paged_stop'],{'category':'attempt_jobs','used':7,'cap':7,'source':f'{PHASE}/253-167-SUMMARY.md','new_retry':False})

    def test_15_render_rejects_checkout_destination_and_nonempty_directory(self):
        for path in [self.root/'new-render',self.render_dir]:
            with self.subTest(path=str(path)),self.assertRaises(v2.ContractError):v2.render_amendments(self.root,path)

    def test_16_cli_has_no_acceptance_or_ci_commands(self):
        for command in ['prepare','enter','write-receipt','dispatch']:
            r=subprocess.run(['python3','-B',str(ROOT/PHASE/'253-RECOVERY-BRIDGE-V2.py'),command],capture_output=True)
            self.assertEqual(r.returncode,2)


    def test_17_native_receipt_verification_checks_are_unchanged(self):
        def function(path,name):
            tree=ast.parse(path.read_text())
            return ast.dump(next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name),include_attributes=False)
        self.assertEqual(function(ROOT/PHASE/'253-RECOVERY-BRIDGE-V2.py','verify_receipt'),function(ROOT/PHASE/'253-RECOVERY-SUCCESSOR.py','verify_receipt'))



    def test_18_cli_saves_real_sdk_copy_report_externally_and_refuses_overwrite(self):
        output=self.work/'cli-sdk-report.json'
        args=['python3','-B',str(ROOT/PHASE/'253-RECOVERY-BRIDGE-V2.py'),'--root',str(self.root),'sdk-copy','--output',str(output)]
        result=subprocess.run(args,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        row=json.loads(result.stdout);self.assertEqual(row['post_chain_halted'],28);self.assertEqual(row['post_chain_incomplete'],0)
        self.assertEqual(v2.sha256(output.read_bytes()),row['report_sha256'])
        report=json.loads(output.read_text());v2.validate_sdk_copy_report_data(self.root,report)
        before=output.read_bytes();again=subprocess.run(args,capture_output=True,text=True)
        self.assertNotEqual(again.returncode,0);self.assertIn('fresh external file',again.stderr);self.assertEqual(output.read_bytes(),before)



if __name__=='__main__':unittest.main(verbosity=2)
