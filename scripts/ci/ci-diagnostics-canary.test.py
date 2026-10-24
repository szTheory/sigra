#!/usr/bin/env python3
"""Contract tests for the bounded hosted diagnostics canary."""

from __future__ import annotations

import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class CanaryContractTests(unittest.TestCase):
    def test_shared_upload_action_stages_explicit_bundle_with_seven_day_retention(self):
        action = ROOT / ".github/actions/ci-diagnostic-upload/action.yml"
        self.assertTrue(action.is_file(), "the shared production diagnostic upload action must exist")
        source = action.read_text(encoding="utf-8")
        self.assertIn("ci-diagnostic-bundle.py stage", source)
        self.assertIn("retention-days: 7", source)
        self.assertIn("if-no-files-found: error", source)
        self.assertIn("actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a", source)

    def test_controller_exposes_frozen_budget_and_identity_gates(self):
        controller = ROOT / "scripts/ci/ci-diagnostics-canary.py"
        self.assertTrue(controller.is_file(), "the finite-budget canary controller must exist")
        source = controller.read_text(encoding="utf-8")
        for function in (
            "freeze_canary",
            "charge_request",
            "verify_run_identity",
            "cancel_fixture_run",
            "retrieve_bundle",
            "verify_terminal_results",
        ):
            self.assertRegex(source, rf"def {function}\\(")

    def test_ci_owners_use_shared_upload_without_changing_required_gate_names(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertIn("uses: ./.github/actions/ci-diagnostic-upload", workflow)
        self.assertIn("library-ci-diagnostics", workflow)
        self.assertIn("browser-ci-diagnostics", workflow)
        for required_name in (
            "Library CI",
            "Example Playwright smoke (full lifecycle)",
            "Example Playwright shard (${{ matrix.seam }})",
        ):
            self.assertIn(required_name, workflow)

    def test_controller_source_hash_checks_happen_before_budget_charges(self):
        controller = ROOT / "scripts/ci/ci-diagnostics-canary.py"
        self.assertTrue(controller.is_file(), "source and budget enforcement must be implemented")
        source = controller.read_text(encoding="utf-8")
        self.assertRegex(source, r"def (?:assert_source_identity|verify_source_identity)\\(")
        self.assertIn("controller_requests", source)
        self.assertIn("max_invocations", source)
        self.assertIn("infrastructure_retries", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
