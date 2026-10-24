#!/usr/bin/env python3
"""Assertions for the native Mix CI receiver observer."""

import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("ci_mix_receivers", "scripts/ci/ci-mix-receivers.py")
RECEIVERS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECEIVERS)
ROOT = pathlib.Path(__file__).resolve().parents[2]


class MixReceiverReportTest(unittest.TestCase):
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

if __name__ == "__main__":
    unittest.main(verbosity=2)
