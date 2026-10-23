"""Protocol tests use native collection fixtures and fake Docker; never run browsers."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('postfix_validate', HERE/'validate.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


def native(project='admin-eval'):
    report = copy.deepcopy(json.loads((HERE/'inspect.json').read_text())['collection'][project])
    test = v.rows(report)[0][2]
    test['results'] = [dict(retry=0, status='passed')]
    test['status'] = 'expected'
    return report


class NativeReport(unittest.TestCase):
    def test_each_real_collection_has_exact_candidate_selection(self):
        data=json.loads((HERE/'inspect.json').read_text())
        for project in v.PROJECTS:
            v.check_report(data['collection'][project],project,True)

    def test_successful_single_native_result(self):
        v.check_report(native(),'admin-eval')

    def test_wrong_project_and_title_rejected(self):
        with self.assertRaisesRegex(AssertionError,'selection'):
            v.check_report(native(),'admin-eval-dark')
        report=native()
        # Locate spec through the actual native suite nesting.
        def change(suite):
            for spec in suite.get('specs',[]):spec['title']='wrong board'
            for child in suite.get('suites',[]):change(child)
        change(report)
        with self.assertRaisesRegex(AssertionError,'selection'):v.check_report(report,'admin-eval')

    def test_empty_report_rejected(self):
        with self.assertRaisesRegex(AssertionError,'selection'):v.check_report({},'admin-eval')

    def test_missing_or_duplicate_result_rejected(self):
        for results in [[],[dict(status='passed',retry=0)]*2]:
            report=native();v.rows(report)[0][2]['results']=results
            with self.assertRaisesRegex(AssertionError,'duplicate execution'):v.check_report(report,'admin-eval')

    def test_retry_skipped_failure_and_expected_failure_rejected(self):
        for field,value in [('retry',1),('status','skipped'),('status','failed'),('status','timedOut')]:
            report=native();v.rows(report)[0][2]['results'][0][field]=value
            with self.assertRaises(AssertionError):v.check_report(report,'admin-eval')
        report=native();v.rows(report)[0][2]['expectedStatus']='failed'
        with self.assertRaisesRegex(AssertionError,'expected status'):v.check_report(report,'admin-eval')

    def test_global_error_rejected(self):
        report=native();report['errors']=[{'message':'producer failed'}]
        with self.assertRaisesRegex(AssertionError,'global native errors'):v.check_report(report,'admin-eval')


class RuntimeBoundary(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='sigra253-postfix-test-')
        self.addCleanup(self.tmp.cleanup)
        self.here=Path(self.tmp.name)
        self.proposal=json.loads((HERE/'proposal.json').read_text())
        (self.here/'proposal.json').write_bytes((HERE/'proposal.json').read_bytes())
        self.ctx=patch.object(v,'HERE',self.here);self.ctx.start();self.addCleanup(self.ctx.stop)

    def approve(self, **changes):
        record=dict(decision='approved',proposal_sha256=v.digest(self.here/'proposal.json'),
                    source=self.proposal['source'],scope='nine-fresh-local-linux-postfix-invocations')
        record.update(changes)
        (self.here/'approval.json').write_text(json.dumps(record))

    def test_missing_approval_never_allocates_or_reserves(self):
        with patch.object(v,'preflight',return_value=self.proposal),patch.object(v.subprocess,'run') as run:
            with self.assertRaisesRegex(AssertionError,'not approved'):v.execute()
            run.assert_not_called()
        self.assertFalse((self.here/'reservation.json').exists())

    def test_old_or_changed_approval_rejected(self):
        for changes in [dict(proposal_sha256='old'),dict(source='old'),dict(scope='original-linux-replay')]:
            self.approve(**changes)
            with self.assertRaises(AssertionError):v.authorize(self.proposal)

    def test_matching_new_approval_accepted(self):
        self.approve();v.authorize(self.proposal)

    def test_spent_scope_cannot_allocate(self):
        self.approve();(self.here/'reservation.json').write_text('spent')
        with patch.object(v,'preflight',return_value=self.proposal),patch.object(v.subprocess,'run') as run:
            with self.assertRaises(FileExistsError):v.execute()
            run.assert_not_called()

    def test_failure_stops_and_removes_both_owned_containers(self):
        self.approve();calls=[]
        def run(args,**kwargs):
            calls.append(args)
            if args[:2]==['docker','run'] and '--init' in args:return subprocess.CompletedProcess(args,1)
            return subprocess.CompletedProcess(args,0)
        def output(args,**kwargs):
            if 'postgres' in args:return 'postgres (PostgreSQL) 15.19 (fixture)'
            return ''
        with patch.object(v,'preflight',return_value=self.proposal),patch.object(v.subprocess,'run',side_effect=run),patch.object(v.subprocess,'check_output',side_effect=output):
            with self.assertRaisesRegex(AssertionError,'candidate runtime failed'):v.execute()
        self.assertEqual(len([c for c in calls if c[:2]==['docker','rm']]),2)
        self.assertEqual(len([c for c in calls if c[:2]==['docker','run']]),2)
        result=json.loads((self.here/'runtime-output/result.json').read_text())
        self.assertEqual(len(result['cases']),1)
        self.assertTrue(result['cases'][0]['cleanup_complete'])
        self.assertEqual(result['status'],'stopped')


    def test_nine_successes_use_nine_distinct_databases_and_exact_projects(self):
        self.approve();calls=[]
        def run(args,**kwargs):
            calls.append(args)
            if args[:2]==['docker','run'] and '--init' in args:
                mount=args[args.index('--mount')+1]
                out=Path(mount.split('src=',1)[1].split(',dst=',1)[0])
                (out/'browser-started.json').write_text('{}')
                (out/'browser.json').write_text(json.dumps(native(args[-1])))
                (out/'app.log').write_text('ready')
            return subprocess.CompletedProcess(args,0)
        def output(args,**kwargs):
            return 'postgres (PostgreSQL) 15.19 (fixture)' if 'postgres' in args else ''
        with patch.object(v,'preflight',return_value=self.proposal),patch.object(v.subprocess,'run',side_effect=run),patch.object(v.subprocess,'check_output',side_effect=output):
            v.execute()
        databases=[c[c.index('--name')+1] for c in calls if c[:2]==['docker','run'] and '-d' in c]
        self.assertEqual(len(set(databases)),9)
        result=json.loads((self.here/'runtime-output/result.json').read_text())
        self.assertEqual(result['browser_invocations'],9)
        self.assertEqual([r['project'] for r in result['cases']],[p for p in v.PROJECTS for _ in range(3)])
        self.assertTrue(all(r['cleanup_complete'] for r in result['cases']))
        self.assertFalse(result['phase_complete'])


class SealedBundle(unittest.TestCase):
    def test_current_bundle(self):v.preflight(inspect_image=False)

    def test_changed_runner_refused(self):
        original=v.digest
        def changed(path):return 'changed' if path.name=='validate.py' else original(path)
        with patch.object(v,'digest',side_effect=changed):
            with self.assertRaisesRegex(AssertionError,'sealed bundle changed'):v.preflight(False)


if __name__=='__main__':unittest.main()
