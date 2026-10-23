"""Protocol tests; fixtures are not integration results and Docker is never invoked."""
import copy
import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch
import selection
import validate


def native():
    return dict(config=dict(workers=1, fullyParallel=False), errors=[],
        stats=dict(expected=1, unexpected=0, flaky=0, skipped=0),
        suites=[dict(title='spec.ts', specs=[dict(title='registers', file='spec.ts', line=10,
            tests=[dict(projectName='chromium', expectedStatus='passed', status='expected',
                        results=[dict(retry=0,status='passed')])])])])


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.report = native()
        self.frozen = selection.identities(self.report)

    def test_complete_native_pass(self):
        selection.check_report(self.report, self.frozen)

    def test_missing_duplicate_changed_tests_refused(self):
        for mutation in ['missing','duplicate','project','line','title']:
            with self.subTest(mutation=mutation):
                report = copy.deepcopy(self.report)
                spec = report['suites'][0]['specs'][0]
                if mutation == 'missing': spec['tests'] = []
                elif mutation == 'duplicate': spec['tests'] *= 2
                elif mutation == 'project': spec['tests'][0]['projectName'] = 'mobile'
                elif mutation == 'line': spec['line'] = 11
                else: spec['title'] = 'another test'
                with self.assertRaises(AssertionError): selection.check_report(report, self.frozen)

    def test_retry_skip_failure_and_expected_failure_refused(self):
        for mutation in ['retry','skip','failure','missing','twice','expected_failure','global','flaky','parallel']:
            with self.subTest(mutation=mutation):
                report = copy.deepcopy(self.report)
                test = report['suites'][0]['specs'][0]['tests'][0]
                if mutation == 'retry': test['results'][0]['retry'] = 1
                elif mutation == 'skip': test['results'][0]['status'] = 'skipped'
                elif mutation == 'failure': test['results'][0]['status'] = 'failed'
                elif mutation == 'missing': test['results'] = []
                elif mutation == 'twice': test['results'] *= 2
                elif mutation == 'expected_failure': test['expectedStatus'] = 'failed'
                elif mutation == 'global': report['errors'] = ['compile failed']
                elif mutation == 'flaky': report['stats']['flaky'] = 1
                else: report['config']['workers'] = 2
                with self.assertRaises(AssertionError): selection.check_report(report, self.frozen)

    def test_collection_must_have_no_executions(self):
        with self.assertRaisesRegex(AssertionError, 'executed'): selection.check_report(self.report, self.frozen, collection=True)
        self.report['suites'][0]['specs'][0]['tests'][0]['results'] = []
        selection.check_report(self.report, self.frozen, collection=True)


class WorkflowTests(unittest.TestCase):
    def test_all_five_native_pairs(self):
        text = (selection.ROOT / '.github/workflows/ci.yml').read_text()
        selected = selection.selections(text)
        self.assertEqual(list(selected), selection.SEAMS)
        self.assertIn('@snapshot', selected['design_gallery'])
        self.assertIn('--grep-invert', selected['design_gallery'])
        self.assertEqual(len([v for v in selected['admin_checkpoints'] if v.startswith('--project=')]), 3)

    def test_workflow_pair_drift_refused(self):
        text = (selection.ROOT / '.github/workflows/ci.yml').read_text()
        # A unique execution-only change cannot silently shrink the frozen selection.
        anchor = 'SIGRA_PLAYWRIGHT_JSON=playwright-report/demo-showcase.json npx playwright test'
        self.assertEqual(text.count(anchor), 1)
        changed = text.replace(anchor, anchor + ' --grep=only-one')
        with self.assertRaises(AssertionError): selection.selections(changed)


class AuthorizationTests(unittest.TestCase):
    def test_unapproved_execute_stops_before_reservation_or_docker(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(validate, 'HERE', Path(tmp)), \
             patch.object(validate, 'preflight', return_value={}), patch.object(validate.subprocess, 'run') as docker:
            with self.assertRaisesRegex(AssertionError, 'not approved'): validate.execute()
            docker.assert_not_called()
            self.assertEqual(list(Path(tmp).iterdir()), [])


class RuntimeTests(unittest.TestCase):
    def exercise(self, fail=False):
        proposal = dict(source='fixture', image_id='fixture-image', postgres_image='fixture-pg',
            limits=dict(seconds_including_cleanup=3600, per_group_seconds=1800),
            inventory={s:selection.identities(native()) for s in selection.SEAMS})
        calls = []
        def docker(args, **kwargs):
            calls.append(args)
            if args[:2] == ['docker','run'] and '--init' in args:
                if fail: return subprocess.CompletedProcess(args, 1)
                out = Path(args[args.index('--mount')+1].split('src=',1)[1].split(',dst=',1)[0])
                (out / 'browser-started.json').write_text('{}')
                (out / 'browser.json').write_text(json.dumps(native()))
                (out / 'app.log').write_text('ready')
            return subprocess.CompletedProcess(args, 0)
        def output(args, **kwargs):
            return 'postgres (PostgreSQL) 15.19 fixture' if 'postgres' in args else ''
        with tempfile.TemporaryDirectory() as tmp, patch.object(validate, 'HERE', Path(tmp)), \
             patch.object(validate, 'preflight', return_value=proposal), patch.object(validate, 'authorize'), \
             patch.object(validate.subprocess, 'run', side_effect=docker), \
             patch.object(validate.subprocess, 'check_output', side_effect=output):
            (Path(tmp) / 'proposal.json').write_text('{}')
            if fail:
                with self.assertRaisesRegex(AssertionError, 'group failed'): validate.execute()
            else:
                validate.execute()
            result = json.loads((Path(tmp) / 'runtime-output/result.json').read_text())
            self.assertTrue(all(g['cleanup_complete'] for g in result['groups']))
            self.assertFalse(result['phase_complete'])
        return calls, result

    def test_first_failure_stops_and_cleans_both_containers(self):
        calls, result = self.exercise(fail=True)
        self.assertEqual(len(result['groups']), 1)
        self.assertEqual(len([c for c in calls if c[:2] == ['docker','rm']]), 2)
        self.assertEqual(len([c for c in calls if c[:2] == ['docker','run']]), 2)

    def test_five_groups_use_five_distinct_databases_no_external_network(self):
        calls, result = self.exercise()
        self.assertEqual(result['browser_invocations'], 5)
        self.assertEqual([g['seam'] for g in result['groups']], selection.SEAMS)
        databases = [c[c.index('--name')+1] for c in calls if c[:2] == ['docker','run'] and '-d' in c]
        self.assertEqual(len(set(databases)), 5)
        for c in calls:
            if c[:2] == ['docker','run']:
                network = c[c.index('--network')+1] if '--network' in c else next(a.split('=',1)[1] for a in c if a.startswith('--network='))
                self.assertTrue(network == 'none' or network.startswith('container:'))


class SealedBundleTests(unittest.TestCase):
    def test_live_offline_bundle(self):
        validate.preflight(inspect_images=False)

    def test_changed_runner_refused(self):
        real = validate.digest
        def changed(path): return 'changed' if path.name == 'validate.py' else real(path)
        with patch.object(validate, 'digest', side_effect=changed):
            with self.assertRaisesRegex(AssertionError, 'sealed bundle changed'): validate.preflight(False)

    def test_approval_for_another_proposal_refused(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(validate, 'HERE', Path(tmp)):
            (Path(tmp) / 'proposal.json').write_text('{}\n')
            (Path(tmp) / 'approval.json').write_text(json.dumps(dict(decision='approved', proposal_sha256='wrong')))
            with self.assertRaisesRegex(AssertionError, 'another proposal'): validate.authorize({})

    def test_consumed_reservation_stops_before_docker(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(validate, 'HERE', Path(tmp)), \
             patch.object(validate, 'preflight', return_value={}), patch.object(validate, 'authorize'), \
             patch.object(validate.subprocess, 'run') as docker:
            marker = Path(tmp) / 'reservation.json'
            marker.write_bytes(b'prior spent allowance\n')
            with self.assertRaises(FileExistsError): validate.execute()
            self.assertEqual(marker.read_bytes(), b'prior spent allowance\n')
            docker.assert_not_called()


if __name__ == '__main__':
    unittest.main()
