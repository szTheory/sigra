#!/usr/bin/env python3
"""Local repaired-control tracer: real child processes, no hosted observations."""
import hashlib
import copy
import importlib.util
import json
import os
import shutil
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

    def test_real_cli_materializes_source_runs_receiver_and_evaluates_fixture(self):
        # Native prerequisites are hermetic executables. The CLI, Git checkout,
        # receiver, command recorder, policy resolver and evaluator are real.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'repo'
            root.mkdir()
            for name in ('ci-repaired-comparison.py', 'ci-mix-receivers.py',
                         'ci-command-record.py', 'ci-browser-command.mjs',
                         'ci-run-metrics.sh', 'ci_metrics_security.py'):
                target = root / 'scripts/ci' / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / 'scripts/ci' / name, target)
            for name in ('.github/workflows/ci.yml', 'mix.exs', 'mix.lock', '.tool-versions',
                         'test/example/priv/static/assets/js/app.js',
                         'test/example/priv/playwright/playwright.config.ts'):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            (root / '.gitignore').write_text('deps/\n_build/\n')
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            subprocess.run(['git', 'add', '.'], cwd=root, check=True)
            subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                            '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture source'], cwd=root, check=True)
            for name in ('deps', '_build'):
                (root / name).mkdir()
            binaries = Path(tmp) / 'bin'
            binaries.mkdir()
            mix = binaries / 'mix'
            mix.write_text('#!' + sys.executable + "\n" +
                "import json,os,pathlib,sys\n" +
                "if sys.argv[1:]==['archive']: print('phx_new-1.8.8')\n" +
                "elif sys.argv[1:]==['--version']: print('Mix 1.19.5')\n" +
                "elif sys.argv[1:]==['test','test/sigra/config_test.exs']:\n" +
                " p=pathlib.Path(os.environ['SIGRA_EXUNIT_TIMING_JSON'])\n" +
                " p.write_text(json.dumps({'complete':True,'seed':17,'failed_count':0," +
                "'failed_test_ids':[],'tests':[{'test_id':'fixture config child','result':'passed'}]}))\n" +
                "else: sys.exit(31)\n")
            for name, text in (('elixir', 'Erlang/OTP 28 [fixture]\nElixir 1.19.5 (fixture)'), ('psql', '1')):
                (binaries / name).write_text('#!' + sys.executable + '\nprint(' + repr(text) + ')\n')
            for binary in binaries.iterdir():
                binary.chmod(0o755)
            output = Path(tmp) / 'receipt.json'
            env = {**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH']}
            child = subprocess.run([sys.executable, '-B', str(root / 'scripts/ci/ci-repaired-comparison.py'),
                                    'local-tracer', '--source', 'HEAD', '--output', str(output)],
                                   cwd=root, env=env, capture_output=True, text=True, timeout=60)
            receipt = json.loads(output.read_text())
            self.assertEqual(child.returncode, 0, str(receipt))
            self.assertEqual(receipt['status'], 'passed')
            self.assertEqual(receipt['observation']['seed'], 17)
            self.assertEqual(receipt['observation']['test_ids'], ['fixture config child'])
            self.assertEqual(receipt['evaluation']['status'], 'insufficient_data')
            self.assertEqual(receipt['acceptance_samples'], 0)
            self.assertEqual(receipt['remote_requests'], 0)
            self.assertEqual(receipt['remote_mutations'], 0)
            self.assertEqual(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root), b'')

    def test_existing_receipt_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'receipt.json'
            output.write_bytes(b'preserve these exact prior bytes\n')
            child = subprocess.run([sys.executable, '-B', str(CLI), 'local-tracer',
                                    '--source', 'HEAD', '--output', str(output)],
                                   cwd=ROOT, capture_output=True, timeout=30)
            self.assertNotEqual(child.returncode, 0)
            self.assertEqual(output.read_bytes(), b'preserve these exact prior bytes\n')


class SourceFeasibilityTests(unittest.TestCase):
    def test_control_keeps_repairs_and_restores_only_declared_treatments(self):
        module = load()
        files = {name: (ROOT / name).read_text() for name in module.TREATMENT_PATHS}
        control, changes = module.build_control(files, ROOT)
        self.assertEqual(set(changes), set(module.TREATMENT_PATHS))
        theme = control[module.TREATMENT_PATHS[0]]
        self.assertIn('async function restoreBrandingDefaults', theme)
        self.assertIn('test.afterEach', theme)
        # Eighteen restored calls plus the unchanged lockout registration.
        self.assertEqual(theme.count('await logInAsPlatformAdmin(page);'), 19)
        org = control[module.TREATMENT_PATHS[1]]
        self.assertEqual(org.count('await logInIfNeeded(page, ownerEmail, ownerPassword);'), 2)
        self.assertEqual(org.count('await assertAuthenticatedZeroOrganizationState(page);'), 2)
        self.assertIn('ci-command-record.py', control[module.TREATMENT_PATHS[2]])
        self.assertIn('CI: "true"', control[module.TREATMENT_PATHS[2]])
        self.assertIn('npm ci', control[module.TREATMENT_PATHS[2]])
        self.assertIn('mix local.hex --force', control[module.TREATMENT_PATHS[3]])
        self.assertIn('--invocation library-ci -- mix ci', control[module.TREATMENT_PATHS[3]])
        module.validate_treatment_files(control, files, changes)
        for name in files:
            altered = dict(files)
            altered[name] += '\nextra unreviewed hunk\n'
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'treatment'):
                module.validate_treatment_files(control, altered, changes)

    def test_unreviewed_admin_source_is_rejected_instead_of_discarded(self):
        module = load()
        files = {name: (ROOT / name).read_text() for name in module.TREATMENT_PATHS}
        files[module.TREATMENT_PATHS[0]] += '\nnew test assertions\n'
        with self.assertRaisesRegex(ValueError, 'admin_theme_source_changed'):
            module.build_control(files, ROOT)

    def warm_fixture(self):
        module = load()
        consumer = {'default_ref': 'refs/heads/main', 'base_ref': 'refs/heads/main',
                    'head_ref': 'refs/heads/measurement-control-01', 'merge_ref': 'refs/pull/123/merge'}
        requirements = {'consumer': consumer, 'owners': {}}
        origins = {}
        rows = []
        for index, owner in enumerate(module.OWNERS):
            components = ('dependencies',) if owner == 'library_tests_shard' else ('dependencies', 'browser_binaries')
            caches = {name: {'key': owner + '-' + name, 'version': 'cache-version-1',
                             'eligible_scopes': ['refs/heads/main']} for name in components}
            producer = {'source_sha': 'a' * 40, 'workflow_sha256': 'b' * 64,
                        'run_id': 200, 'run_attempt': 1, 'job_id': 300 + index}
            requirements['owners'][owner] = {'source_sha': 'a' * 40, 'workflow_sha256': 'b' * 64, 'caches': caches}
            origins[owner] = {**producer, 'api_evidence_sha256': 'c' * 64}
            rows.append({'owner': owner, 'producer': producer, 'caches': {
                name: {'key': value['key'], 'matched_key': value['key'], 'version': value['version'],
                       'scope': 'refs/heads/main', 'restore': 'exact'} for name, value in caches.items()}})
            origins[owner]['cache_receipts'] = {name: {**value, 'evidence_sha256': 'd' * 64}
                                                for name, value in rows[-1]['caches'].items()}
        return module, requirements, origins, rows

    def test_every_frozen_warm_component_and_independent_origin_is_required(self):
        module, requirements, origins, rows = self.warm_fixture()
        self.assertEqual(module.validate_warm_receipts(rows, requirements, origins), [])
        self.assertTrue(module.validate_warm_receipts(rows, requirements))
        for mutation in ('sibling', 'fallback', 'missing_owner', 'duplicate_owner', 'wrong_key',
                         'missing_binaries', 'binary_miss', 'wrong_version', 'wrong_producer',
                         'missing_origin', 'missing_required_component_declaration', 'independent_binary_miss',
                         'missing_independent_binary_receipt', 'malformed_frozen_scope'):
            changed, frozen, origin = copy.deepcopy(rows), copy.deepcopy(requirements), copy.deepcopy(origins)
            binary = changed[1]['caches']['browser_binaries']
            if mutation == 'sibling': binary['scope'] = 'refs/pull/99/merge'
            if mutation == 'fallback': binary['restore'] = 'fallback'
            if mutation == 'missing_owner': changed.pop()
            if mutation == 'duplicate_owner': changed.append(copy.deepcopy(changed[0]))
            if mutation == 'wrong_key': binary['matched_key'] = 'stale-key'
            if mutation == 'missing_binaries': changed[1]['caches'].pop('browser_binaries')
            if mutation == 'binary_miss': binary['restore'] = 'miss'
            if mutation == 'wrong_version': binary['version'] = 'other-compression-or-path-version'
            if mutation == 'wrong_producer': changed[1]['producer']['run_attempt'] = 2
            if mutation == 'missing_origin': origin.pop(changed[1]['owner'])
            if mutation == 'missing_required_component_declaration': frozen['owners'][changed[1]['owner']]['caches'].pop('browser_binaries')
            if mutation == 'independent_binary_miss': origin[changed[1]['owner']]['cache_receipts']['browser_binaries']['restore'] = 'miss'
            if mutation == 'missing_independent_binary_receipt': origin[changed[1]['owner']]['cache_receipts'].pop('browser_binaries')
            if mutation == 'malformed_frozen_scope': frozen['owners'][changed[1]['owner']]['caches']['browser_binaries']['eligible_scopes'] = [{}]
            with self.subTest(mutation=mutation):
                self.assertTrue(module.validate_warm_receipts(changed, frozen, origin))

    def test_only_actual_head_base_default_or_same_pr_scope_can_be_eligible(self):
        module, requirements, origins, rows = self.warm_fixture()
        for eligible in requirements['consumer'].values():
            changed, frozen, origin = copy.deepcopy(rows), copy.deepcopy(requirements), copy.deepcopy(origins)
            for row in changed:
                for value in row['caches'].values(): value['scope'] = eligible
            for producer in origin.values():
                for value in producer['cache_receipts'].values(): value['scope'] = eligible
            for owner in frozen['owners'].values():
                for value in owner['caches'].values(): value['eligible_scopes'] = [eligible]
            with self.subTest(eligible=eligible):
                self.assertEqual(module.validate_warm_receipts(changed, frozen, origin), [])
        # A declared allowlist cannot make an unrelated branch or PR eligible.
        for sibling in ('refs/heads/prep-control', 'refs/pull/99/merge'):
            changed, frozen = copy.deepcopy(rows), copy.deepcopy(requirements)
            changed[1]['caches']['dependencies']['scope'] = sibling
            frozen['owners'][changed[1]['owner']]['caches']['dependencies']['eligible_scopes'] = [sibling]
            self.assertTrue(module.validate_warm_receipts(changed, frozen, origins))
        expected = {'head': 'a' * 40, 'base': 'b' * 40, 'merge_tree': 'c' * 40}
        self.assertEqual(module.validate_pr_identity(expected, expected), [])
        for field in expected:
            self.assertTrue(module.validate_pr_identity({**expected, field: 'd' * 40}, expected))

    def test_local_source_readiness_permits_next_plan_without_hosted_proof(self):
        module = load()
        # Exercise real Git source reads and the real docs classifier. No API
        # state or successful hosted family is manufactured by this fixture.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null',
                    *args], cwd=root, stderr=subprocess.DEVNULL, text=True).strip()
            git('init', '-q')
            for name in ('.github/workflows/ci.yml', '.github/actions/example-playwright-boot/action.yml',
                         'scripts/ci/docs-only-classify.sh'):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                # Immutable pre-reconciliation inputs avoid other workers' edits.
                target.write_bytes(subprocess.check_output(['git', 'show', 'c8db62539:' + name], cwd=ROOT))
            (root / 'mix.exs').write_text('fixture old source\n')
            git('add', '.')
            git('commit', '-qm', 'base fixture')
            base = git('rev-parse', 'HEAD')
            (root / 'mix.exs').write_text('fixture repaired source\n')
            git('commit', '-qam', 'candidate fixture')
            head, tree = git('rev-parse', 'HEAD'), git('rev-parse', 'HEAD^{tree}')
            record = {'source_sha': head, 'tree_sha': tree,
                      'merge_preview': module.merge_preview(root, base, head, tree)}
            sources = {'status': 'constructed', 'base_sha': base,
                       'treatment_round_trip_tree_equal': True, 'control_ref_readback_equal': True,
                       'sources': {'control': copy.deepcopy(record), 'candidate': copy.deepcopy(record)}}
            result = module.evaluate_feasibility(sources, root)
            self.assertEqual(result['local_status'], 'ready', result)
            self.assertEqual(result['local_blocking_items'], [])
            self.assertEqual(result['next_local_plan'], '255.1-02')
            self.assertEqual(result['status'], 'blocked')
            self.assertEqual(result['hosted_status'], 'blocked')
            self.assertEqual(result['performance_verdict'], 'insufficient_data')
            self.assertEqual(result['acceptance_samples'], 0)
            self.assertIn('complete_equivalent_work_receipt_pending_plan02', result['hosted_blocking_items'])
            self.assertIn('local_main_compiled_cache_inputs_differ_from_repaired_sources', result['diagnostics'])
            # Actual source conflicts still close the local gate.
            bad = copy.deepcopy(sources)
            bad['sources']['control']['merge_preview'].update(status='blocked', reason='merge_conflicts')
            self.assertEqual(module.evaluate_feasibility(bad, root)['local_status'], 'blocked')
            # Docs-only work cannot qualify a full workload, even on clean merges.
            docs = copy.deepcopy(sources)
            (root / 'notes.md').write_text('docs only\n')
            git('add', '.')
            git('commit', '-qm', 'docs fixture')
            docs_head, docs_tree = git('rev-parse', 'HEAD'), git('rev-parse', 'HEAD^{tree}')
            docs['base_sha'] = head
            for value in docs['sources'].values():
                value.update(source_sha=docs_head, tree_sha=docs_tree,
                             merge_preview=module.merge_preview(root, head, docs_head, docs_tree))
            rejected = module.evaluate_feasibility(docs, root)
            self.assertEqual(rejected['local_status'], 'blocked')
            self.assertIn('proposed_PR_not_full_workload:candidate', rejected['local_blocking_items'])

    def test_real_preflight_cli_unblocks_local_successor_without_hosted_acceptance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'repo'
            subprocess.run(['git', 'clone', '--shared', '--no-checkout', '--quiet', str(ROOT), str(root)], check=True)
            base = '09df342a82e03c3d5d40173c912b70e827f7eadc'
            tree = subprocess.check_output(['git', 'rev-parse', 'c8db62539^{tree}'], cwd=root, text=True).strip()
            # Test-only history: make unchanged fixture bytes descend from the
            # saved main, so the test isolates gating rather than production's
            # competing changes. This is never proposed as a source repair.
            head = subprocess.check_output(['git', '-c', 'user.name=Fixture',
                '-c', 'user.email=fixture@example.invalid', 'commit-tree', tree, '-p', base,
                '-m', 'test-only source ancestry fixture'], cwd=root, text=True).strip()
            subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', 'checkout', '--detach', '--quiet', head], cwd=root, check=True)
            shutil.copyfile(CLI, root / 'scripts/ci/ci-repaired-comparison.py')
            output = Path(tmp) / 'output/FEASIBILITY.json'
            child = subprocess.run([sys.executable, '-B', str(root / 'scripts/ci/ci-repaired-comparison.py'),
                'preflight', '--source', head, '--base', base, '--output', str(output)],
                cwd=root, capture_output=True, text=True, timeout=90)
            self.assertEqual(child.returncode, 0, child.stdout + child.stderr)
            result = json.loads(output.read_text())
            self.assertEqual(result['local_status'], 'ready')
            self.assertEqual(result['next_local_plan'], '255.1-02')
            self.assertEqual(result['hosted_status'], 'blocked')
            self.assertEqual(result['status'], 'blocked')
            self.assertEqual(result['acceptance_samples'], 0)
            self.assertEqual(result['remote_requests'], 0)
            self.assertEqual(result['remote_mutations'], 0)
            sources = json.loads((output.parent / 'SOURCES.json').read_text())
            self.assertTrue(sources['treatment_round_trip_tree_equal'])
            self.assertEqual(set(sources['treatment_files']), set(load().TREATMENT_PATHS))
            self.assertTrue(all(row['merge_preview']['status'] == 'ready' for row in sources['sources'].values()))
            # Existing outputs are never replaced by a second run.
            prior = output.read_bytes()
            repeated = subprocess.run(child.args, cwd=root, capture_output=True, text=True, timeout=15)
            self.assertEqual(repeated.returncode, 2)
            self.assertEqual(output.read_bytes(), prior)

    def test_preflight_missing_object_has_a_durable_blocked_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'FEASIBILITY.json'
            child = subprocess.run([sys.executable, '-B', str(CLI), 'preflight',
                '--source', 'missing-preflight-source', '--base', '09df342a82e03c3d5d40173c912b70e827f7eadc',
                '--output', str(output)], cwd=ROOT, capture_output=True, text=True, timeout=15)
            self.assertEqual(child.returncode, 2, child.stdout + child.stderr)
            result = json.loads(output.read_text())
            self.assertEqual(result['local_status'], 'blocked')
            self.assertEqual(result['hosted_status'], 'blocked')
            self.assertEqual(result['acceptance_samples'], 0)
            self.assertIn('source_or_base_object_unresolved', result['local_blocking_items'])

    def test_real_git_merge_conflicts_and_wrong_frozen_tree_stay_blocked(self):
        module = load()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null',
                    *args], cwd=root, stderr=subprocess.DEVNULL, text=True).strip()
            git('init', '-q')
            (root / 'app.ex').write_text('original\n')
            git('add', '.')
            git('commit', '-qm', 'original')
            ancestor = git('rev-parse', 'HEAD')
            (root / 'app.ex').write_text('main correction\n')
            git('commit', '-qam', 'main')
            base = git('rev-parse', 'HEAD')
            git('checkout', '-q', '--detach', ancestor)
            (root / 'app.ex').write_text('candidate correction\n')
            git('commit', '-qam', 'candidate')
            head = git('rev-parse', 'HEAD')
            tree = git('rev-parse', 'HEAD^{tree}')
            conflict = module.merge_preview(root, base, head, tree)
            self.assertEqual(conflict['status'], 'blocked')
            self.assertEqual(conflict['reason'], 'merge_conflicts')
            self.assertEqual(conflict['conflicting_paths'], ['app.ex'])
            clean = module.merge_preview(root, ancestor, head, tree)
            self.assertEqual(clean['status'], 'ready')
            wrong = module.merge_preview(root, ancestor, head, '0' * 40)
            self.assertEqual(wrong['status'], 'blocked')
            self.assertEqual(wrong['reason'], 'merge_tree_differs_from_frozen_source')

    def test_workflow_cache_enumeration_does_not_call_missing_receipts_warm(self):
        module = load()
        result = module.inspect_workflow((ROOT / '.github/workflows/ci.yml').read_text(),
                                         (ROOT / '.github/actions/example-playwright-boot/action.yml').read_text())
        self.assertEqual({row['owner'] for row in result['owners']}, set(module.OWNERS))
        self.assertTrue(result['trigger_main_pr'])
        for row in result['owners']:
            self.assertEqual(row['hosted_warm_status'], 'unproved')
            self.assertTrue(row['key_expression'])
            self.assertTrue(row['restore_prefix'])
            self.assertEqual(row['eligible_shared_scope'], 'refs/heads/main')
        self.assertIn('npm ci', result['preserved_commands'])
        unchanged_comments = (ROOT / '.github/workflows/ci.yml').read_text().replace(
            '  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}',
            '  group: all-PRs-collide')
        self.assertFalse(module.inspect_workflow(unchanged_comments,
            (ROOT / '.github/actions/example-playwright-boot/action.yml').read_text())['distinct_pr_concurrency'])
        broken = (ROOT / '.github/workflows/ci.yml').read_text().replace('branches: [main]', 'branches: [other]')
        self.assertFalse(module.inspect_workflow(broken,
                         (ROOT / '.github/actions/example-playwright-boot/action.yml').read_text())['trigger_main_pr'])


if __name__ == '__main__':
    unittest.main()
