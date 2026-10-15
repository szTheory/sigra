#!/usr/bin/env python3
"""Offline gate tests for ci-gate-canary-dryrun.py and the driver behaviour it exposes (253-101).

Every run happens in a temporary clone against the local HTTPS fake. The runner is invoked with --overlay-worktree so
the tests exercise the checkout's current scripts/ci files; nothing reaches GitHub (no credentials, recorder gh/curl).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/ci/ci-gate-canary-dryrun.py"
DRIVER_REL = "scripts/ci/ci-gate-canary.sh"
R7_DRIVER = "97665bd2a56443a2bb10f894aafd46c5f06e4ce9"


def load_runner():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_gate_canary_dryrun_under_test", RUNNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def clean_env():
    env = {key: value for key, value in os.environ.items()
           if key not in {"GH_TOKEN", "GITHUB_TOKEN"} and not key.startswith("SIGRA_CANARY_TEST_")}
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def run_gate(*args, timeout=1800):
    """Run the dry-run gate; returns (exit code, summary)."""
    result = subprocess.run([sys.executable, str(RUNNER), "--overlay-worktree", *args], cwd=ROOT, env=clean_env(),
                            capture_output=True, text=True, timeout=timeout)
    try:
        summary = json.loads(result.stdout)
    except ValueError:
        raise AssertionError(f"runner printed no JSON summary (exit {result.returncode}): {result.stderr[-2000:]}")
    return result.returncode, summary


class LiveOverrideRefusalTests(unittest.TestCase):
    """With a live allocation every SIGRA_CANARY_TEST_* override stops the driver before any request or evidence."""

    @classmethod
    def setUpClass(cls):
        cls.runner = load_runner()
        cls.work = Path(tempfile.mkdtemp(prefix="sigra-253-override-")).resolve()
        args = argparse.Namespace(overlay_worktree=True, driver_from=None, driver_patch=None, revision_freeze=None,
                                  server_parent=None, ref_pair=None, overlaid=[])
        cls.prepared = cls.runner.prepare_clone(args, cls.work)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def live_allocation(self):
        freeze_path = self.prepared["freeze_path"]
        value = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "253-101-override-refusal",
                 "source_sha256": hashlib.sha256(freeze_path.read_bytes()).hexdigest(), "max_requests": 117,
                 "max_elapsed_seconds": 3600, "max_response_bytes": 4 * 1024 * 1024, "max_pages": 3, "max_hops": 2,
                 "repository": "szTheory/sigra", "download_hosts": [], "mode": "live", "allocation_kind": "canary",
                 "category_limits": self.prepared["freeze"]["categories"]["canary"]}
        path = self.work / "live-allocation.json"
        path.write_text(json.dumps(value))
        return path

    def test_every_test_override_is_refused_with_a_live_allocation_before_any_request(self):
        clone, phase = self.prepared["clone"], self.prepared["phase"]
        allocation = self.live_allocation()
        for variable in ("SIGRA_CANARY_TEST_POLL_SECONDS", "SIGRA_CANARY_TEST_SERVER_JOURNAL",
                         "SIGRA_CANARY_TEST_DISCOVERY_WAIT_SECONDS", "SIGRA_CANARY_TEST_ANYTHING"):
            for mode in (["--publish-only"], ["--scenario", "full-pass"], ["--remaining-scenarios"]):
                with self.subTest(variable=variable, mode=mode[0]):
                    evidence, ledger = phase / "override-evidence.json", phase / "override-ledger.json"
                    env = self.runner.scrubbed_env(self.work, {variable: "1"})
                    marker = self.work / "network-commands"
                    result = subprocess.run(
                        ["bash", str(clone / DRIVER_REL), *mode, "--revision-freeze", str(self.prepared["freeze_path"]),
                         "--action-approval", str(self.prepared["approval"]), "--http-allocation", str(allocation),
                         "--requests", str(ledger), "--evidence", str(evidence)],
                        cwd=clone, env=env, capture_output=True, text=True, timeout=300)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(variable, result.stderr)
                    self.assertIn("refused with a live allocation", result.stderr)
                    self.assertFalse(evidence.exists(), "evidence was written before the override refusal")
                    self.assertFalse(ledger.exists(), "a request was charged before the override refusal")
                    self.assertFalse(marker.exists(), "a network command ran before the override refusal")

    def test_the_same_live_allocation_without_overrides_gets_past_the_refusal(self):
        clone, phase = self.prepared["clone"], self.prepared["phase"]
        env = self.runner.scrubbed_env(self.work)
        result = subprocess.run(
            ["bash", str(clone / DRIVER_REL), "--scenario", "full-pass", "--revision-freeze", str(self.prepared["freeze_path"]),
             "--action-approval", str(self.prepared["approval"]), "--http-allocation", str(self.live_allocation()),
             "--requests", str(phase / "control-ledger.json"), "--evidence", str(phase / "control-evidence.json")],
            cwd=clone, env=env, capture_output=True, text=True, timeout=300)
        # Positive control: with no override the live path proceeds to its first request, which the recorder gh
        # refuses for lack of credentials (nothing leaves the machine).
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("refused with a live allocation", result.stderr)
        ledger = json.loads((phase / "control-ledger.json").read_text())
        self.assertEqual(ledger["transactions"][0]["error"]["code"], "authentication_unavailable")
        self.assertEqual((self.work / "network-commands").read_text().split()[:3], ["gh", "auth", "token"])


_DEFAULT_RUN = []


def default_run():
    """The default full sequence, run once per test process and shared by the classes that only read its summary."""
    if not _DEFAULT_RUN:
        _DEFAULT_RUN.append(run_gate())
    return _DEFAULT_RUN[0]


class PreflightOnceTests(unittest.TestCase):
    """Commit C: the fresh preflight runs once per evidence window; a later invocation re-verifies it offline."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.summary = default_run()
        cls.invocations = {item["mode"]: item for item in cls.summary.get("invocations", [])}

    def test_the_second_invocation_issues_zero_preflight_requests_and_reverifies_the_retained_preflight(self):
        self.assertIn("remaining", self.invocations, self.summary)
        self.assertEqual(self.invocations["full-pass"]["requests_by_category"].get("preflight"), 5, self.summary)
        self.assertEqual(self.invocations["remaining"]["requests_by_category"].get("preflight", 0), 0, self.summary)
        self.assertTrue(self.invocations["remaining"]["retained_preflight_reverified"], self.summary)

    def test_the_window_ledger_holds_exactly_one_check_runs_transaction_within_the_preflight_category(self):
        self.assertEqual(self.summary["requests_by_route"].get("check_runs"), 1, self.summary)
        self.assertLessEqual(self.summary["requests_by_category"].get("preflight", 0), 8, self.summary)

    def test_the_five_preflight_copies_sit_next_to_the_explicit_evidence(self):
        expected = sorted(f"253-DRYRUN-CANARY-EVIDENCE-PREFLIGHT-{name}.json" for name in
                          ("rate", "effective-rules", "registered-workflow", "legacy-protection", "check-runs"))
        self.assertEqual(self.summary["preflight_copies"], expected, self.summary)


class FullSequenceTests(unittest.TestCase):
    """The whole canary in two invocations, then the verifier's --mode canary --scenario matrix, all synthetic."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.summary = default_run()

    def test_the_default_run_completes_every_scenario_the_cancel_and_the_verifier(self):
        self.assertEqual(self.code, 0, self.summary)
        self.assertEqual(self.summary["status"], "passed", self.summary)
        self.assertEqual(self.summary["scenarios"], ["full-pass", "docs-only", "actual-failure", "missing-seam",
                                                     "unexpected-skip", "cancelled"])
        self.assertEqual(self.summary["verifier"]["status"], "passed", self.summary)
        self.assertEqual(self.summary["requests_by_category"].get("cancellation"), 1)
        self.assertEqual(self.summary["requests_by_category"].get("dispatch"), 7, "six scenarios plus the separate verifier")
        self.assertEqual([item["mode"] for item in self.summary["invocations"]], ["publish-only", "full-pass", "remaining"])

    def test_the_run_is_synthetic_and_reconciled_against_the_server_journal(self):
        self.assertIs(self.summary["synthetic"], True)
        self.assertEqual(self.summary["freeze_plan"], "253-91")
        self.assertEqual(self.summary["journal_requests"], self.summary["requests_total"])
        self.assertIsNone(self.summary["evidence_status"], "a passing window must not be halted")
        self.assertLessEqual(self.summary["requests_total"], 117)


SERVER_PARENT = "84ebcea60024c9e8caee405d55cad1c76b0e858a"  # the R7 freeze's server parent, used by the derived freeze


class HaltMarkingTests(unittest.TestCase):
    """Commit D: every nonzero exit after the evidence exists leaves it halted, and the guard refuses re-entry."""

    def assert_halted_and_guarded(self, summary, named):
        self.assertEqual(summary["status"], "failed", summary)
        self.assertEqual(summary["evidence_status"], "halted", summary)
        messages = " ".join(item.get("message", "") for item in summary.get("evidence_diagnostics") or [])
        self.assertIn(named, messages, summary)
        reentry = summary.get("reentry") or {}
        self.assertNotEqual(reentry.get("exit"), 0, summary)
        self.assertIn("halted evidence", reentry.get("stop") or "", summary)
        self.assertEqual(reentry.get("requests"), 0, "the halted guard let a request through on re-entry")

    def test_a_route_refused_by_the_transport_marks_the_evidence_halted(self):
        route = f"GET /repos/szTheory/sigra/commits/{SERVER_PARENT}/check-runs=403"
        code, summary = run_gate("--stop-after", "full-pass", "--inject", route, "--reenter")
        self.assertNotEqual(code, 0)
        self.assertIn("http_403", summary["stop"] or "", summary)
        self.assert_halted_and_guarded(summary, "check-runs")

    def test_a_verifier_failure_marks_the_evidence_halted(self):
        code, summary = run_gate("--stop-after", "full-pass", "--fault", "artifact-digest", "--reenter")
        self.assertNotEqual(code, 0)
        self.assertIn("digest", summary["stop"] or "", summary)
        self.assert_halted_and_guarded(summary, "ci-hosted-gate-verify.py")


if __name__ == "__main__":
    unittest.main(verbosity=2)
