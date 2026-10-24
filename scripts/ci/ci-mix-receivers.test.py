#!/usr/bin/env python3
"""Assertions for the native Mix CI receiver observer."""

import importlib.util
import unittest


SPEC = importlib.util.spec_from_file_location("ci_mix_receivers", "scripts/ci/ci-mix-receivers.py")
RECEIVERS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECEIVERS)


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

if __name__ == "__main__":
    unittest.main(verbosity=2)
