#!/usr/bin/env python3
"""Local repaired-control tracer: real child processes, no hosted observations."""
import hashlib
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


if __name__ == '__main__':
    unittest.main()
