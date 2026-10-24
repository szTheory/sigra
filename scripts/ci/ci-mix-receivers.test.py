#!/usr/bin/env python3
"""Assertions for the native Mix CI receiver observer."""

import importlib.util
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
import zipfile


SPEC = importlib.util.spec_from_file_location("ci_mix_receivers", "scripts/ci/ci-mix-receivers.py")
RECEIVERS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECEIVERS)
ROOT = pathlib.Path(__file__).resolve().parents[2]


class MixReceiverReportTest(unittest.TestCase):
    def test_finalize_persists_real_receiver_reports_and_explains_missing_legs(self):
        with tempfile.TemporaryDirectory(prefix="sigra-receiver-finalize-") as temp:
            root = pathlib.Path(temp)
            (root / "legs/ordinary").mkdir(parents=True)
            (root / "legs/ordinary/exunit.json").write_text(json.dumps({"seed": 11, "tests": [{"test_id": "A.one", "status": "passed"}], "complete": True}))
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.py"), "finalize",
                 "--output", str(root), "--report-output", str(root / "MIX-RECEIVERS.json"),
                 "--primary-exit", "42"],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            report = json.loads((root / "MIX-RECEIVERS.json").read_text())
            self.assertEqual(42, report["primary_exit_code"])
            self.assertEqual(11, report["ordinary"]["seed"])
            self.assertEqual("A.one", report["ordinary"]["tests"][0]["test_id"])
            self.assertIn("legs/scaffold/exunit.json", {row["path"] for row in report["missing_reports"]})
            self.assertTrue((root / "legs/ordinary/exunit.json").is_file(), "finalize must not remove child reports")

    def test_real_receiver_child_report_survives_exit_and_is_finalized(self):
        with tempfile.TemporaryDirectory(prefix="sigra-receiver-child-") as temp:
            root = pathlib.Path(temp)
            env = os.environ.copy()
            env["SIGRA_CI_RECEIVER_OUTPUT"] = str(root)
            child = (
                "import json,os,pathlib; "
                "pathlib.Path(os.environ['SIGRA_EXUNIT_TIMING_JSON']).write_text(json.dumps({"
                "'seed': 73, 'tests': [{'test_id': 'Native.actual', 'status': 'passed'}], "
                "'complete': True, 'failed_count': 0, 'failed_test_ids': []}))"
            )
            leg = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.py"), "leg", "ordinary", "--",
                 sys.executable, "-c", child], cwd=ROOT, env=env, capture_output=True, text=True,
                check=False, timeout=10,
            )
            report_path = root / "legs/ordinary/exunit.json"
            self.assertEqual(0, leg.returncode, leg.stdout + leg.stderr)
            self.assertTrue(report_path.is_file(), "receiver child output must survive process completion")
            finalized = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.py"), "finalize",
                 "--output", str(root), "--report-output", str(root / "MIX-RECEIVERS.json"), "--primary-exit", "0"],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(1, finalized.returncode, "success cannot qualify when expected receiver files are missing")
            assembled = json.loads((root / "MIX-RECEIVERS.json").read_text())
            self.assertEqual(73, assembled["ordinary"]["seed"])
            self.assertEqual("Native.actual", assembled["ordinary"]["tests"][0]["test_id"])
            self.assertEqual(0, assembled["leg_command_records"]["ordinary"]["primary_exit_code"])

            manifest_path = root / "manifest.json"
            manifest = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-diagnostics-canary.py"), "manifest",
                 "--invocation-root", str(root), "--output", str(manifest_path),
                 "--invocation-id", "library-123-1", "--source-sha", "a" * 40,
                 "--run-id", "123", "--run-attempt", "1", "--job-id", "library_tests_shard",
                 "--seam", "library_ci", "--file", "MIX-RECEIVERS.json=report"],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, manifest.returncode, manifest.stdout + manifest.stderr)
            staged_path = root / "safe.zip"
            staged = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-diagnostic-bundle.py"), "stage",
                 "--invocation-root", str(root), "--manifest", str(manifest_path), "--output", str(staged_path)],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, staged.returncode, staged.stdout + staged.stderr)
            verified = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-diagnostic-bundle.py"), "verify",
                 "--bundle", str(staged_path), "--manifest", str(manifest_path)],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, verified.returncode, verified.stdout + verified.stderr)
            manifest_data = json.loads(manifest_path.read_text())
            self.assertEqual(hashlib.sha256((root / "MIX-RECEIVERS.json").read_bytes()).hexdigest(),
                             manifest_data["files"][0]["sha256"])
            (root / "MIX-RECEIVERS.json").write_text(json.dumps({"debug": "ghp_1234567890123456789012345678"}))
            unsafe_manifest_path = root / "unsafe-manifest.json"
            unsafe_manifest = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-diagnostics-canary.py"), "manifest",
                 "--invocation-root", str(root), "--output", str(unsafe_manifest_path),
                 "--invocation-id", "library-123-1", "--source-sha", "a" * 40,
                 "--run-id", "123", "--run-attempt", "1", "--job-id", "library_tests_shard",
                 "--seam", "library_ci", "--file", "MIX-RECEIVERS.json=report"],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, unsafe_manifest.returncode, unsafe_manifest.stdout + unsafe_manifest.stderr)
            unsafe_stage = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-diagnostic-bundle.py"), "stage",
                 "--invocation-root", str(root), "--manifest", str(unsafe_manifest_path),
                 "--output", str(root / "unsafe.zip")],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, unsafe_stage.returncode, unsafe_stage.stdout + unsafe_stage.stderr)
            self.assertIn("secret_sentinel_detected", unsafe_stage.stdout)
            with zipfile.ZipFile(root / "unsafe.zip") as archive:
                self.assertNotIn(b"ghp_1234567890123456789012345678", archive.read("bundle-manifest.json"))

    def test_finalize_keeps_primary_failure_when_receivers_are_unavailable(self):
        with tempfile.TemporaryDirectory(prefix="sigra-receiver-failed-") as temp:
            root = pathlib.Path(temp)
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.py"), "finalize",
                 "--output", str(root), "--report-output", str(root / "MIX-RECEIVERS.json"),
                 "--primary-exit", "42"],
                cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            report = json.loads((root / "MIX-RECEIVERS.json").read_text())
            self.assertEqual(42, report["primary_exit_code"])
            self.assertEqual("failure", report["primary_status"])
            self.assertTrue(report["missing_reports"])

    def test_plan_native_cli_accepts_a_report_file_output(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.test.py"), "--native", "--help"],
            cwd=ROOT, capture_output=True, text=True, check=False, timeout=10,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("--output OUTPUT", result.stdout)

    def test_accepts_exact_ordinary_scaffold_and_dep_off_identities(self):
        ordinary = {"tests": [{"module": "Sigra.AuthTest", "test_id": "Sigra.AuthTest.login"}], "seed": 81, "failed_test_ids": [], "complete": True, "failed_count": 0}
        scaffold = {"tests": [{"module": module, "test_id": f"{module}.case"} for module in RECEIVERS.SCAFFOLD], "seed": 82, "failed_test_ids": [], "complete": True, "failed_count": 0}
        threadline = {"tests": [{"module": "Sigra.ConfigForwardersTest", "test_id": "Sigra.ConfigForwardersTest.absent"}], "seed": 83, "failed_test_ids": [], "complete": True, "failed_count": 0}
        value = {
            "ordinary": ordinary,
            "scaffold": scaffold,
            "threadline_guard": threadline,
            "leg_records": ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"],
            "leg_command_records": {
                "ordinary": {"primary_exit_code": 0},
                "scaffold": {"primary_exit_code": 0},
                "dep-off": {"primary_exit_code": 0},
            },
        }
        ok, errors = RECEIVERS.validate_native_report(value)
        self.assertTrue(ok, errors)
        self.assertEqual([], errors)

    def test_rejects_missing_scaffold_identity_even_if_leg_returned_green(self):
        value = {
            "ordinary": {"tests": [{"module": "Sigra.AuthTest", "test_id": "Sigra.AuthTest.login"}], "seed": 81},
            "scaffold": {"tests": [{"module": "Sigra.Install.GoldenDiffTest", "test_id": "GoldenDiff.case"}], "seed": 82},
            "threadline_guard": {"tests": [{"module": "Sigra.ConfigForwardersTest", "test_id": "ConfigForwarders.absent"}], "seed": 83},
            "leg_records": ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"],
        }
        ok, errors = RECEIVERS.validate_native_report(value)
        self.assertFalse(ok)
        self.assertIn("missing_scaffold:Sigra.UpgradeIntegrationTest", errors)

    def test_dep_off_guard_failure_remains_primary_when_restore_fails(self):
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/ci/test-sigra-dep-off.sh"), "--case", "failure_plus_cleanup"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_non_test_command_failure_has_null_seed_and_not_applicable_reason(self):
        with tempfile.TemporaryDirectory(prefix="sigra-receiver-seed-") as temp:
            output = pathlib.Path(temp)
            env = os.environ.copy()
            env["SIGRA_CI_RECEIVER_OUTPUT"] = str(output)
            command = [sys.executable, str(ROOT / "scripts/ci/ci-mix-receivers.py"), "leg", "ordinary", "--",
                       sys.executable, "-c", "import sys; sys.exit(42)"]
            result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, check=False, timeout=20)
            record = json.loads((output / "commands/ordinary/record.json").read_text())
            self.assertEqual(42, result.returncode)
            self.assertIsNone(record["seed"])
            self.assertEqual("not_applicable", record["seed_reason"])

    def test_native_receiver_records_round_trip_each_observed_seed_and_failure_identity(self):
        report = json.loads((ROOT / ".planning/execution/255-local/MIX-RECEIVERS.json").read_text())
        for receiver, suite in (("ordinary", "ordinary"), ("scaffold", "scaffold"), ("dep-off", "threadline_guard")):
            command_record = report["leg_command_records"][receiver]
            suite_report = report[suite]
            self.assertEqual(suite_report["seed"], command_record["seed"])
            self.assertEqual(suite_report["failed_test_ids"], command_record["failed_test_ids"])
            self.assertEqual(suite, command_record["test_invocation"])

    def test_required_gate_rejects_missing_phx_new_but_standalone_mode_keeps_opt_in_skip(self):
        with tempfile.TemporaryDirectory(prefix="sigra-hidden-phx-new-") as mix_home:
            elixir_lib = subprocess.check_output(
                ["elixir", "-e", "IO.puts(:code.lib_dir(:elixir))"], text=True, timeout=10
            ).strip()
            installed_root = pathlib.Path(elixir_lib).parent.parent
            archives_installed = installed_root / ".mix/archives"
            hex_versions = sorted(archives_installed.glob("hex-*"))
            self.assertTrue(hex_versions, f"installed Hex archive is missing under {archives_installed}")
            archives = pathlib.Path(mix_home) / "archives"
            archives.mkdir()
            os.symlink(hex_versions[-1], archives / hex_versions[-1].name)
            env = os.environ.copy()
            env["MIX_ENV"] = "test"
            env["MIX_HOME"] = mix_home
            env["SIGRA_CI_REQUIRED"] = "1"
            required = subprocess.run(
                ["mix", "test", "--no-compile", "test/sigra/planning/ci_timing_formatter_test.exs"],
                cwd=ROOT, env=env, capture_output=True, text=True, check=False, timeout=30,
            )
            self.assertNotEqual(0, required.returncode, required.stdout + required.stderr)
            self.assertIn("SIGRA_CI_REQUIRED=1: required phx_new 1.8.8 archive is unavailable", required.stdout + required.stderr)

            env.pop("SIGRA_CI_REQUIRED")
            standalone = subprocess.run(
                ["mix", "test", "--no-compile", "test/sigra/planning/ci_timing_formatter_test.exs"],
                cwd=ROOT, env=env, capture_output=True, text=True, check=False, timeout=30,
            )
            self.assertEqual(0, standalone.returncode, standalone.stdout + standalone.stderr)
            self.assertIn("Excluding tags: [:upgrade]", standalone.stdout)

    def test_required_gate_rejects_unavailable_test_database_with_explicit_diagnostic(self):
        env = os.environ.copy()
        env["MIX_ENV"] = "test"
        env["SIGRA_CI_REQUIRED"] = "1"
        env["SIGRA_TEST_PG_DATABASE"] = "sigra_required_gate_missing_database"
        result = subprocess.run(
            ["mix", "test", "--no-compile", "test/sigra/planning/ci_timing_formatter_test.exs"],
            cwd=ROOT, env=env, capture_output=True, text=True, check=False, timeout=30,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("SIGRA_CI_REQUIRED=1: required test PostgreSQL query failed", result.stdout + result.stderr)

if __name__ == "__main__":
    if sys.argv[1:2] == ["--native"]:
        raise SystemExit(RECEIVERS.main())
    unittest.main(verbosity=2)
