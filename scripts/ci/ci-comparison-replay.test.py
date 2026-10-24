#!/usr/bin/env python3
"""Real saved-input replay contract; never dispatch collection."""
import hashlib
import importlib.util
import io
import tarfile
from unittest.mock import patch
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
    def test_distribution_commands_are_exposed(self):
        run = subprocess.run([sys.executable, '-B', str(CLI), '--help'],
                             cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn('distribute', run.stdout)
        self.assertIn('verify-distribution', run.stdout)

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

    @staticmethod
    def module():
        spec = importlib.util.spec_from_file_location('replay', CLI)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_missing_receipt_blob_blocks_preflight_with_path(self):
        mod = self.module()
        actual_git = mod.git
        missing = f'{mod.MEASUREMENT}/requests/pair-01/raw-before/manifest.json'
        def unavailable(root, *args):
            if args[0] == 'show' and args[1] == mod.RECEIPTS['before'] + ':' + missing:
                raise ValueError('unavailable_git_object:' + args[1])
            return actual_git(root, *args)
        with patch.object(mod, 'git', unavailable):
            manifest, _ = mod.preflight_sources(ROOT)
        self.assertEqual(manifest['status'], 'blocked')
        self.assertTrue(any(row.get('path') == missing for row in manifest['missing']))

    def test_missing_corrupt_or_changed_dependencies_are_rejected(self):
        mod = self.module()
        manifest, data = mod.preflight_sources(ROOT)
        self.assertEqual(manifest['status'], 'ready')
        names = [f'{mod.MEASUREMENT}/requests/pair-01/raw-before/manifest.json',
                 'scripts/ci/ci_metrics_security.py', mod.TIMING]
        for name in names:
            for operation in ['remove', 'corrupt']:
                with self.subTest(path=name, operation=operation), tempfile.TemporaryDirectory() as tmp:
                    changed = dict(data)
                    if operation == 'remove':
                        del changed[name]
                    else:
                        changed[name] += b'corrupt'
                    with self.assertRaisesRegex(ValueError, name):
                        mod.materialize_inputs(manifest, changed, Path(tmp))
                    self.assertEqual(list(Path(tmp).iterdir()), [])
        self.assertIn(mod.TIMING, data)
        self.assertIn('scripts/ci/exunit_timing_contract.py', data)

    def test_unsafe_archives_are_rejected_before_extraction(self):
        mod = self.module()
        for name, kind in [('../escape', 'file'), ('/absolute', 'file'), ('safe', 'symlink'),
                           ('safe', 'hardlink'), ('safe', 'duplicate'), ('a/./b', 'file')]:
            with self.subTest(name=name, kind=kind), tempfile.TemporaryDirectory() as tmp:
                package = Path(tmp) / 'bad.tar.gz'
                with tarfile.open(package, 'w:gz') as archive:
                    member = tarfile.TarInfo(name)
                    if kind in ['symlink', 'hardlink']:
                        member.type = tarfile.SYMTYPE if kind == 'symlink' else tarfile.LNKTYPE
                        member.linkname = '../../escape'
                        archive.addfile(member)
                    else:
                        member.size = 1
                        archive.addfile(member, io.BytesIO(b'x'))
                        if kind == 'duplicate':
                            archive.addfile(member, io.BytesIO(b'x'))
                with self.assertRaises(ValueError):
                    mod.verify_package(package)

    def test_package_manifest_and_null_family_costs_are_literal(self):
        mod = self.module()
        manifest, data = mod.preflight_sources(ROOT)
        before = json.loads(data[f'{mod.MEASUREMENT}/requests/pair-01/raw-before/manifest.json'])
        self.assertIsNone(before.get('comparison_families'))
        result = mod.replay_comparison(manifest, data)
        costs = {row['family_role']: row for row in result['metrics']['family_attempt_costs']}
        self.assertEqual(costs['before']['conclusion'], 'failure')
        self.assertEqual(costs['after']['conclusion'], 'success')
        self.assertEqual(costs['before']['attempts'], [{'attempt': 2, 'known_subtotal_seconds': 2046}])
        self.assertEqual(costs['after']['attempts'], [{'attempt': 2, 'known_subtotal_seconds': 1589}])
        self.assertEqual(result['metrics']['native_parity']['origins_verified'], 1)
        self.assertEqual(result['metrics']['native_parity']['status'], 'insufficient_data')
        self.assertIn('before_family_inputs_missing', [row['reason'] for row in result['diagnostics']])


if __name__ == '__main__':
    unittest.main(verbosity=2)
