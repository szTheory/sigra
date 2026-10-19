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
        self.assertEqual(self.invocations["full-pass"]["requests_by_category"].get("preflight"), 7, self.summary)
        self.assertEqual(self.invocations["remaining"]["requests_by_category"].get("preflight", 0), 0, self.summary)
        self.assertTrue(self.invocations["remaining"]["retained_preflight_reverified"], self.summary)

    def test_the_window_ledger_holds_one_contiguous_three_page_check_runs_read_within_the_preflight_category(self):
        self.assertEqual(self.summary["requests_by_route"].get("check_runs"), 3, self.summary)
        self.assertEqual([read for read in self.summary.get("paginated_reads") or [] if read.get("route") == "check_runs"],
                         [{"route": "check_runs", "pages": 3, "next_link_forms": ["repos"]}], self.summary.get("paginated_reads"))
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

    def test_every_served_run_has_the_recorded_github_shape_including_the_verifier_run(self):
        # 253-117: the response_shape block covers every scenario run and the separate verifier run.
        shape = self.summary.get("response_shape") or {}
        self.assertIs(shape.get("ok"), True, shape)
        self.assertIs(shape.get("verifier_run_checked"), True, shape)
        self.assertEqual(sorted(shape.get("scenarios_checked") or []),
                         sorted(["full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled",
                                 "verifier"]), shape)
        # 253-128: the three failed-log chains are checked against GitHub's recorded chain (253-127 probe).
        self.assertIs(shape.get("run_logs_checked"), True, shape)
        self.assertEqual(shape.get("run_logs_chains_checked"), 3, shape)
        # 253-128: the cancelled run and its jobs are checked against GitHub's recorded cancelled run (253-127 probe).
        self.assertIs(shape.get("cancelled_run_checked"), True, shape)

    def test_every_served_job_step_and_artifact_has_the_recorded_github_shape(self):
        # 253-117 Task 2: jobs, steps and artifacts (R9 seq 28/29) are checked too, in this hermetic full sequence.
        shape = self.summary.get("response_shape") or {}
        for key in ("jobs_checked", "steps_checked", "artifacts_checked"):
            self.assertGreater(shape.get(key, 0), 0, shape)
        self.assertEqual(self.summary.get("verifier_job_model"), "scenario-set", self.summary)


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


class TimingModelTests(unittest.TestCase):
    """Commit E: a run is listable only after a delay, so discovery waits (request-free) before its one listing."""

    def test_a_three_second_visibility_delay_is_found_by_one_listing_after_the_discovery_wait(self):
        code, summary = run_gate("--stop-after", "full-pass", "--visibility-delay", "3", "--discovery-wait", "4")
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary["requests_by_category"].get("run_discovery"), 1, "exactly one charged listing")
        self.assertEqual(summary["scenarios"], ["full-pass"])

    def test_the_modeled_polls_count_from_a_first_poll_after_one_interval(self):
        code, summary = run_gate("--stop-after", "full-pass", "--visibility-delay", "3", "--discovery-wait", "4",
                                 "--poll-seconds", "2")
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary["requests_by_category"].get("terminal_polls"), 3, "3 modeled polls for full-pass")
        # The pre-watch rate read and the first poll are separated by one full (shortened) interval, not by a few
        # process start-ups.
        self.assertGreaterEqual(summary["first_poll_delays"][0], 2.0, summary)


class AccountingTests(unittest.TestCase):
    def test_one_more_poll_than_the_category_allows_halts_with_a_budget_message(self):
        code, summary = run_gate("--polls", "full-pass=4")
        self.assertNotEqual(code, 0)
        self.assertIn("terminal_polls", summary["stop"] or "", summary)
        self.assertIn("exhausted", summary["stop"] or "", summary)
        self.assertEqual(summary["evidence_status"], "halted", summary)
        self.assertEqual(summary["requests_by_category"].get("terminal_polls"), 18)

    def test_every_category_of_the_default_run_is_within_the_frozen_table_and_retry_is_unused(self):
        code, summary = default_run()
        self.assertEqual(code, 0, summary)
        frozen = {"preflight": 8, "publication": 24, "dispatch": 7, "run_discovery": 7, "pre_watch_rate": 7,
                  "terminal_polls": 18, "attempt_jobs": 7, "artifact_metadata": 7, "artifact_downloads": 12,
                  "failure_logs": 6, "cancellation": 1, "infrastructure_retry": 13}
        for category, used in summary["requests_by_category"].items():
            with self.subTest(category=category):
                self.assertLessEqual(used, frozen[category])
        self.assertEqual(summary["requests_by_category"].get("infrastructure_retry", 0), 0)


def patch_file(directory, name, old, new):
    path = Path(directory) / f"{name}.json"
    path.write_text(json.dumps({"name": name, "old": old, "new": new}))
    return path


class SensitivityControlTests(unittest.TestCase):
    """Each control reintroduces one fixed defect into a copy of the driver; the gate must fail at its named point."""

    def control(self, name, old, new, *extra):
        with tempfile.TemporaryDirectory() as directory:
            text = (ROOT / DRIVER_REL).read_text()
            self.assertEqual(text.count(old), 1, f"reintroduction patch {name} must apply exactly once")
            code, summary = run_gate("--driver-patch", str(patch_file(directory, name, old, new)), *extra)
        self.assertNotEqual(code, 0, f"the gate is blind to {name}: {summary}")
        self.assertEqual(summary["status"], "failed")
        self.assertEqual(summary["driver_patch"], name)
        return summary

    def test_check_source_candidate(self):
        summary = self.control("check-source-candidate",
                               'api_get "commits/$CHECK_SOURCE_SHA/check-runs?per_page=100" "$CHECK_RUNS_RESPONSE"',
                               'api_get "commits/$CANDIDATE_SHA/check-runs?per_page=100" "$CHECK_RUNS_RESPONSE"',
                               "--stop-after", "full-pass")
        self.assertIn("native check-run app/source identity is missing", summary["stop"], summary)
        self.assertEqual(summary["invocations"][-1]["mode"], "full-pass")

    def test_errexit_tail(self):
        summary = self.control("errexit-tail",
                               "  # The guard above is false for every expected outcome; without this the function returned 1 and set -e ended the run.\n  return 0\n}",
                               "}", "--stop-after", "full-pass")
        # Without the explicit success return the function ends on its negative-source guard, which returns 1 for
        # every expected outcome; the ERR trap names that guard line and the run ends right after the full-pass receipt.
        self.assertIn('"$case_name" == unexpected-skip ]]', summary["stop"], summary)
        self.assertEqual(summary["invocations"][-1]["mode"], "full-pass")
        self.assertEqual(summary["scenarios"], ["full-pass"], "it stops right after the full-pass receipt")
        self.assertEqual(summary["evidence_status"], "halted")

    def test_preflight_repeat(self):
        summary = self.control("preflight-repeat", "if retained_preflight; then", "if false && retained_preflight; then")
        self.assertEqual(summary["invocations"][-1]["mode"], "remaining")
        self.assertIn("category preflight allocation is exhausted", summary["stop"], summary)

    def test_halt_unmarked(self):
        route = f"GET /repos/szTheory/sigra/commits/{SERVER_PARENT}/check-runs=403"
        summary = self.control("halt-unmarked", "trap 'on_command_error \"$?\" \"$LINENO\" \"$BASH_COMMAND\"' ERR\n", "",
                               "--stop-after", "full-pass", "--inject", route)
        self.assertIn("http_403", summary["stop"], summary)
        self.assertIsNone(summary["evidence_status"], "with the fail routing removed the refusal leaves no halt")

    def test_discovery_race(self):
        summary = self.control("discovery-race", 'sleep "$DISCOVERY_WAIT"', "sleep 0", "--stop-after", "full-pass",
                               "--visibility-delay", "3", "--discovery-wait", "4")
        self.assertIn("dispatch receipt not found", summary["stop"], summary)

    def test_the_frozen_r7_driver_fails_at_the_check_runs_preflight_before_any_verifier_call(self):
        code, summary = run_gate("--driver-from", R7_DRIVER, "--stop-after", "full-pass")
        self.assertNotEqual(code, 0)
        self.assertEqual(summary["status"], "failed")
        self.assertIn("invalid_route_parameter", summary["stop"], summary)
        self.assertEqual(summary["requests_by_category"].get("preflight"), 3, "rate, rules and protection only")
        self.assertNotIn("check_runs", summary["requests_by_route"])


class CreateOnlyTests(unittest.TestCase):
    def test_the_two_legacy_refs_stop_publish_only_with_no_ref_updated(self):
        code, summary = run_gate("--seed-legacy-refs")
        self.assertNotEqual(code, 0)
        self.assertEqual(summary["invocations"][-1]["mode"], "publish-only")
        self.assertIn("already points to a different commit", summary["stop"], summary)
        self.assertIs(summary["seeded_refs_changed"], False)
        self.assertNotIn("create_ref", summary["requests_by_route"])
        self.assertEqual(summary["evidence_status"], "halted")


class FakeGitHubStrictnessTests(unittest.TestCase):
    """The fake rejects any request GitHub's API would not take for that route."""

    @classmethod
    def setUpClass(cls):
        cls.runner = load_runner()

    def test_unknown_paths_queries_bodies_and_credentials_are_refused_and_recorded(self):
        import http.client
        import ssl
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory).resolve()
            clone = work / "clone"
            subprocess.run(["git", "clone", "-q", "--shared", "--no-checkout", str(ROOT), str(clone)], check=True)
            parent = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
            server, thread, cert = self.runner.start_fake(work, clone, work / "ledger.json", work / "journal.json", parent,
                                                          None, 0.0, dict(self.runner.DEFAULT_POLLS), False)
            try:
                server.refs["gsd/253-replan-fixture"] = parent
                context = ssl.create_default_context(cafile=str(cert))
                cases = [
                    ("GET", "/repos/szTheory/sigra/actions/workflows/259268962/runs?event=push&branch=x&per_page=100&page=1", None, {}),
                    ("GET", "/repos/szTheory/sigra/rules/branches/main?per_page=30&page=1", None, {}),
                    ("GET", "/repos/szTheory/sigra/actions/runs/1/jobs", None, {}),
                    ("POST", "/repos/szTheory/sigra/actions/workflows/259268962/dispatches",
                     {"ref": "gsd/253-replan-fixture", "inputs": {"scenario": "full-pass", "unknown": "x"}}, {}),
                    ("POST", "/repos/szTheory/sigra/actions/workflows/259268962/dispatches",
                     {"ref": "gsd/does-not-exist", "inputs": {"scenario": "full-pass", "candidate_sha": "a", "fixture_sha": "b",
                                                              "fixture_blob": "c"}}, {}),
                    ("POST", "/repos/szTheory/sigra/actions/runs/1/cancel", {"force": True}, {}),
                    ("DELETE", "/repos/szTheory/sigra/git/refs/heads/main", None, {}),
                    ("GET", "/rate_limit", None, {"Authorization": "Bearer ghp_dryruntokenvalue"}),
                ]
                statuses = []
                for method, path, body, headers in cases:
                    connection = http.client.HTTPSConnection("localhost", server.server_address[1], context=context, timeout=10)
                    payload = json.dumps(body).encode() if body is not None else None
                    connection.request(method, path, body=payload, headers={"Content-Type": "application/json", **headers})
                    statuses.append(connection.getresponse().status)
                    connection.close()
                self.assertTrue(all(status >= 400 for status in statuses), statuses)
                self.assertGreaterEqual(len(server.violations), len(cases) - 1, server.violations)
                self.assertTrue(any("credential" in item for item in server.violations))
                self.assertEqual(server.runs, {}, "a refused dispatch must not create a run")
            finally:
                server.shutdown()
                server.server_close()


# ------------------------------------------------------------------------------------- 253-108 live-policy mode
PHASE_DIR = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
R8_ALLOCATION = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json"
BLOB_HOST = r"^productionresultssa[0-9]+[.]blob[.]core[.]windows[.]net$"
RESULTS_RECEIVER_HOST = "results-receiver.actions.githubusercontent.com"
_LIVE_RUNS = {}


def live_run(*args):
    """A live-policy gate run, cached per argument list for the classes that only read its summary."""
    if args not in _LIVE_RUNS:
        try:
            _LIVE_RUNS[args] = run_gate("--live-policy", *args)
        except AssertionError as error:  # no summary: every reader then fails on its own assertion
            _LIVE_RUNS[args] = (None, {"runner_error": str(error)[-600:]})
    return _LIVE_RUNS[args]


class LivePolicyFullPassTests(unittest.TestCase):
    """253-108 Task 1: publish-only and full-pass through the LIVE transport policy, below which only the shim differs."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.summary = live_run("--stop-after", "full-pass")

    def test_live_policy_publish_only_and_full_pass_pass_end_to_end(self):
        self.assertEqual(self.code, 0, self.summary)
        self.assertEqual(self.summary.get("status"), "passed", self.summary)
        self.assertEqual(self.summary.get("mode"), "live-policy")
        self.assertIs(self.summary.get("synthetic"), True)
        self.assertEqual(self.summary.get("scenarios"), ["full-pass"])
        self.assertEqual([item["mode"] for item in self.summary.get("invocations", [])], ["publish-only", "full-pass"])

    def test_the_allocation_is_live_with_the_trusted_hosts_and_no_test_fields(self):
        allocation = self.summary.get("allocation") or {}
        self.assertTrue(allocation, self.summary)
        self.assertEqual(allocation.get("mode"), "live")
        self.assertEqual(allocation.get("allocation_kind"), "canary")
        self.assertTrue(str(allocation.get("window_id")).startswith("253-dryrun-live-policy-"), allocation)
        self.assertNotIn("test_origin", allocation.get("fields", ["test_origin"]))
        self.assertNotIn("test_ca_file", allocation.get("fields", ["test_origin"]))
        # 253-128: the R8 trusted list plus results-receiver, GitHub's run-log host (transport: run_logs hop 1 only).
        self.assertEqual(allocation.get("download_hosts"), json.loads(R8_ALLOCATION.read_text())["download_hosts"]
                         + ["results-receiver.actions.githubusercontent.com"])
        self.assertEqual((allocation.get("max_requests"), allocation.get("max_pages"), allocation.get("max_hops")), (117, 10, 2))
        self.assertEqual(self.summary.get("test_overrides"), [], "no SIGRA_CANARY_TEST_* variable in live-policy mode")

    def test_artifact_zip_is_a_302_on_api_github_com_then_a_200_on_the_blob_host(self):
        hops = [hop for hop in self.summary.get("live_hops") or [] if hop["route"] == "artifact_zip"]
        self.assertEqual(len(hops), 1, self.summary.get("live_hops"))
        self.assertEqual(hops[0]["hop_ordinal"], 1) if hops else None
        self.assertRegex(hops[0]["host"], BLOB_HOST)
        self.assertEqual(hops[0]["status"], 200)
        self.assertEqual((self.summary.get("requests_by_route") or {}).get("artifact_zip"), 2, "hop 0 (302) plus hop 1 (200)")

    def test_the_token_reaches_every_api_request_and_no_blob_request(self):
        authorization = self.summary.get("authorization") or {}
        self.assertGreater(authorization.get("api_with", 0), 0, authorization)
        self.assertEqual(authorization.get("api_without"), 0, authorization)
        self.assertEqual(authorization.get("blob_with"), 0, authorization)

    def test_the_shim_refused_nothing_and_the_fake_recorded_no_violation(self):
        self.assertEqual(self.summary.get("shim_refusals"), [])
        self.assertEqual(self.summary.get("violations"), [])
        self.assertEqual(sorted(self.summary.get("shim_connect_hosts") or []),
                         ["api.github.com", "productionresultssa17.blob.core.windows.net"], self.summary.get("shim_connect_hosts"))

    def test_the_live_publication_is_actual_github_verified_and_labelled_with_its_dry_run_window(self):
        publication = self.summary.get("publication") or {}
        self.assertEqual(publication.get("origin_kind"), "actual-github", publication)
        self.assertEqual(publication.get("fixture_ref_state"), "verified", publication)
        # The 253-107 completion guard can only gap a dry-run publication that carries its window identity.
        self.assertTrue(str(publication.get("origin_window_id")).startswith("253-dryrun-live-policy-"), publication)
        self.assertIs(publication.get("verifier_dryrun_window"), True, publication)


TRANSPORT_REL = "scripts/ci/ci-hosted-transport.py"
REDIRECT_FIX_SUBJECT = "allow the live approved-redirect hop"


def git_lines(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).split()


def redirect_fix_commit():
    """The 253-107 redirect fix, resolved by its unique subject and pinned to the 253-107 SUMMARY's redirect_fix_commit."""
    found = git_lines("log", "--format=%H", "--fixed-strings", f"--grep={REDIRECT_FIX_SUBJECT}", "--", TRANSPORT_REL)
    if len(found) != 1:
        raise AssertionError(f"the redirect-fix subject must match exactly one commit, found {found}")
    if f"redirect_fix_commit: {found[0]}" not in (PHASE_DIR / "253-107-SUMMARY.md").read_text():
        raise AssertionError("the subject's commit is not the 253-107 SUMMARY's redirect_fix_commit")
    return found[0]


class TransportSensitivityTests(unittest.TestCase):
    """253-108 Task 2: the live-policy gate fails on the exact 253-104 defect and passes once it is fixed."""

    @classmethod
    def setUpClass(cls):
        cls.fix = redirect_fix_commit()
        cls.pre_fix = cls.fix + "^"

    def test_the_fix_is_not_the_latest_fix_253_107_commit(self):
        # Positive control on the trap the plan forbids: the latest fix(253-107) commit is the later hole fix.
        latest = git_lines("log", "-1", "--format=%H", "--grep=fix(253-107)")
        self.assertEqual(len(latest), 1)
        self.assertNotEqual(latest[0], self.fix)

    def test_the_pre_fix_transport_fails_the_live_policy_gate_at_artifact_zip_with_origin_rejected(self):
        code, summary = live_run("--transport-from", self.pre_fix, "--stop-after", "full-pass")
        self.assertNotEqual(code, 0, f"the live-policy gate cannot see the 253-104 defect: {summary}")
        self.assertEqual(summary.get("status"), "failed", summary)
        self.assertEqual(summary.get("transport_from"), self.pre_fix, summary)
        self.assertIn("origin_rejected", summary.get("stop") or "", summary)
        self.assertEqual([item["mode"] for item in summary.get("invocations", [])], ["publish-only", "full-pass"])
        self.assertEqual((summary.get("requests_by_route") or {}).get("artifact_zip"), 1, "hop 0 only; hop 1 never sent")
        self.assertEqual([hop for hop in summary.get("live_hops") or [] if hop.get("hop_ordinal", 0) >= 1], [])
        self.assertEqual(summary.get("shim_connect_hosts"), ["api.github.com"], "no hop-1 connection to the blob host")
        self.assertEqual(summary.get("evidence_status"), "halted", summary)

    def test_the_redirect_fix_transport_passes_the_same_gate(self):
        code, summary = live_run("--transport-from", self.fix, "--stop-after", "full-pass")
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary.get("status"), "passed", summary)
        self.assertEqual(summary.get("transport_from"), self.fix, summary)
        hops = [hop for hop in summary.get("live_hops") or [] if hop.get("route") == "artifact_zip"]
        self.assertEqual(len(hops), 1, summary.get("live_hops"))
        self.assertRegex(hops[0]["host"], BLOB_HOST)

    def test_the_hermetic_mode_result_for_the_pre_fix_transport_is_recorded(self):
        # Recorded, not gated: the hermetic allocation is exempt from the live origin check, which is why 253-101's
        # gate could not see the 253-104 defect.
        code, summary = run_gate("--transport-from", self.pre_fix, "--stop-after", "full-pass")
        self.assertEqual(summary.get("transport_from"), self.pre_fix, summary)
        self.assertEqual(summary.get("mode"), "hermetic", summary)
        sys.stderr.write(f"\nhermetic --transport-from {self.pre_fix}: exit {code}, status {summary.get('status')}, "
                         f"stop {summary.get('stop')}\n")


FROZEN_CANARY = {"preflight": 8, "publication": 24, "dispatch": 7, "run_discovery": 7, "pre_watch_rate": 7,
                 "terminal_polls": 18, "attempt_jobs": 7, "artifact_metadata": 7, "artifact_downloads": 12,
                 "failure_logs": 6, "cancellation": 1, "infrastructure_retry": 13}


class LivePolicyFullSequenceTests(unittest.TestCase):
    """253-108 Task 3: the whole canary through the live policy, live 20/60-second waits, seeded r8 refs untouched."""

    @classmethod
    def setUpClass(cls):
        cls.code, cls.summary = live_run("--seed-r8-refs")
        cls.categories = cls.summary.get("requests_by_category") or {}
        cls.routes = cls.summary.get("requests_by_route") or {}

    def hops(self, route):
        return [hop for hop in self.summary.get("live_hops") or [] if hop.get("route") == route]

    def test_every_scenario_and_the_separate_verifier_pass_synthetic(self):
        self.assertEqual(self.code, 0, self.summary)
        self.assertEqual(self.summary.get("status"), "passed", self.summary)
        self.assertEqual(self.summary.get("mode"), "live-policy")
        self.assertIs(self.summary.get("synthetic"), True)
        self.assertEqual(sorted(self.summary.get("scenarios") or []), sorted(["full-pass", "docs-only", "actual-failure",
                                                                              "missing-seam", "unexpected-skip", "cancelled"]))
        self.assertEqual((self.summary.get("verifier") or {}).get("status"), "passed", self.summary)
        self.assertEqual([item["mode"] for item in self.summary.get("invocations", [])], ["publish-only", "full-pass", "remaining"])

    def test_every_served_run_has_the_recorded_github_shape_including_the_verifier_run(self):
        # 253-117: the same response_shape assertion through the live policy.
        shape = self.summary.get("response_shape") or {}
        self.assertIs(shape.get("ok"), True, shape)
        self.assertIs(shape.get("verifier_run_checked"), True, shape)
        self.assertIs(shape.get("run_logs_checked"), True, shape)  # 253-128
        self.assertIs(shape.get("cancelled_run_checked"), True, shape)  # 253-128
        self.assertEqual(sorted(shape.get("scenarios_checked") or []),
                         sorted(["full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled",
                                 "verifier"]), shape)

    def test_every_served_job_step_and_artifact_has_the_recorded_github_shape(self):
        shape = self.summary.get("response_shape") or {}
        for key in ("jobs_checked", "steps_checked", "artifacts_checked"):
            self.assertGreater(shape.get(key, 0), 0, shape)

    def test_the_verifier_job_ran_verify_sources_on_the_compact_matrix(self):
        # 253-117 Task 2: the fake's verifier job concludes from the candidate's verify_sources on the decoded compact
        # matrix, as the hosted verifier job does; the dispatched payload stays within its bounded input.
        self.assertEqual(self.summary.get("status"), "passed", self.summary)
        self.assertEqual(self.summary.get("verifier_job_model"), "verify_sources", self.summary)
        job = self.summary.get("verifier_job") or {}
        self.assertEqual(job.get("result"), "sources_verified", job)
        self.assertEqual(job.get("executed_jobs"), 35, job)  # 5 x 6 jobs + cancelled: 5 producers
        self.assertIsInstance(job.get("matrix_payload_chars"), int, job)
        self.assertLessEqual(job["matrix_payload_chars"], 64511, job)

    def test_every_category_is_within_the_frozen_table_and_reconciled_with_the_fake(self):
        self.assertLessEqual(self.summary.get("requests_total", 999), 117)
        self.assertEqual(self.summary.get("journal_requests"), self.summary.get("requests_total"))
        self.assertEqual(self.categories.get("infrastructure_retry", 0), 0)
        self.assertTrue(self.categories, self.summary)
        for category, used in self.categories.items():
            with self.subTest(category=category):
                self.assertLessEqual(used, FROZEN_CANARY[category])

    def test_every_download_is_a_302_hop_then_a_200_on_its_recorded_download_host(self):
        # 253-128: artifacts on the blob host; failed logs on results-receiver, GitHub's recorded run-log chain (253-127).
        artifacts, logs = self.hops("artifact_zip"), self.hops("run_logs")
        self.assertEqual(len(artifacts), 5, "full-pass, docs-only, actual-failure, missing-seam, unexpected-skip")
        self.assertEqual(len(logs), 3, "actual-failure, missing-seam, unexpected-skip")
        for hop in artifacts + logs:
            self.assertEqual((hop["hop_ordinal"], hop["status"]), (1, 200), hop)
        for hop in artifacts:
            self.assertRegex(hop["host"], BLOB_HOST)
        for hop in logs:
            self.assertEqual(hop["host"], RESULTS_RECEIVER_HOST, hop)
        self.assertIs((self.summary.get("response_shape") or {}).get("run_logs_checked"), True, self.summary.get("response_shape"))
        self.assertEqual(self.routes.get("artifact_zip"), 2 * len(artifacts))
        self.assertEqual(self.routes.get("run_logs"), 2 * len(logs))
        self.assertEqual(self.categories.get("artifact_downloads"), 2 * len(artifacts))
        self.assertEqual(self.categories.get("failure_logs"), 2 * len(logs))

    def test_the_live_discovery_and_poll_waits_are_requested_unchanged(self):
        sleeps = self.summary.get("requested_sleeps") or {}
        self.assertTrue(sleeps.get("discovery"), sleeps)
        self.assertTrue(all(value == 20 for value in sleeps["discovery"]), sleeps)
        self.assertEqual(len(sleeps["discovery"]), self.categories.get("dispatch"), "one wait after every dispatch")
        self.assertTrue(sleeps.get("poll"), sleeps)
        self.assertTrue(all(value == 60 for value in sleeps["poll"]), sleeps)
        self.assertEqual(len(sleeps["poll"]), self.categories.get("terminal_polls"), "one interval before every poll")
        self.assertEqual(sleeps.get("other"), [])
        self.assertEqual(self.summary.get("test_overrides"), [])

    def test_the_token_shim_and_fake_stay_clean_over_the_whole_sequence(self):
        authorization = self.summary.get("authorization") or {}
        self.assertEqual((authorization.get("api_without"), authorization.get("blob_with")), (0, 0), authorization)
        self.assertEqual(authorization.get("results_receiver_with"), 0, authorization)
        self.assertGreater(authorization.get("api_with", 0), 0)
        self.assertEqual(self.summary.get("shim_refusals"), [])
        self.assertEqual(self.summary.get("violations"), [])
        # 253-128: the full sequence connects to results-receiver for the three failed-log hop-1 requests.
        self.assertEqual(sorted(self.summary.get("shim_connect_hosts") or []),
                         ["api.github.com", "productionresultssa17.blob.core.windows.net", RESULTS_RECEIVER_HOST],
                         self.summary.get("shim_connect_hosts"))

    def test_the_seeded_r8_refs_never_move(self):
        self.assertIs(self.summary.get("seeded_r8_refs_changed"), False, self.summary)

    def test_the_live_publication_is_verified_and_the_evidence_stays_synthetic(self):
        publication = self.summary.get("publication") or {}
        self.assertEqual((publication.get("origin_kind"), publication.get("fixture_ref_state")), ("actual-github", "verified"))
        self.assertIs(publication.get("verifier_dryrun_window"), True, publication)


class LivePolicyCreateOnlyTests(unittest.TestCase):
    def test_an_r8_pair_publication_stops_on_the_seeded_r8_refs_with_no_ref_created(self):
        code, summary = live_run("--ref-pair", "r8", "--seed-r8-refs")
        self.assertNotEqual(code, 0, summary)
        self.assertEqual([item["mode"] for item in summary.get("invocations", [])], ["publish-only"], summary)
        self.assertIn("already points to a different commit", summary.get("stop") or "", summary)
        self.assertIs(summary.get("seeded_r8_refs_changed"), False, summary)
        self.assertNotIn("create_ref", summary.get("requests_by_route") or {"create_ref": 1})
        self.assertEqual(summary.get("evidence_status"), "halted", summary)


class LivePolicyHaltMarkingTests(HaltMarkingTests):
    """The 253-101 halt-marking and re-entry tests, repeated through the live policy."""

    def test_a_route_refused_by_the_transport_marks_the_evidence_halted(self):
        route = f"GET /repos/szTheory/sigra/commits/{SERVER_PARENT}/check-runs=403"
        code, summary = live_run("--stop-after", "full-pass", "--inject", route, "--reenter")
        self.assertNotEqual(code, 0)
        self.assertEqual(summary.get("mode"), "live-policy", summary)
        self.assertIn("http_403", summary.get("stop") or "", summary)
        self.assert_halted_and_guarded(summary, "check-runs")

    def test_a_verifier_failure_marks_the_evidence_halted(self):
        code, summary = live_run("--stop-after", "full-pass", "--fault", "artifact-digest", "--reenter")
        self.assertNotEqual(code, 0)
        self.assertEqual(summary.get("mode"), "live-policy", summary)
        self.assertIn("digest", summary.get("stop") or "", summary)
        self.assert_halted_and_guarded(summary, "ci-hosted-gate-verify.py")


# -------------------------------------------------------------------------- 253-117 GitHub's recorded response shapes
R9_LEDGER = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json"
R8_LEDGER = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json"
NESTED_RUN_OBJECTS = ("repository", "head_repository", "head_commit", "actor", "triggering_actor")


def ledger_body(path, route, sequence=None):
    """The decoded response body GitHub returned for this route (first match, or the given sequence)."""
    import base64
    for row in json.loads(Path(path).read_text())["transactions"]:
        if row.get("route_id") == route and (sequence is None or row.get("sequence") == sequence):
            return json.loads(base64.b64decode(row["response_body_base64"]))
    raise AssertionError(f"no {route} transaction in {path}")


class ResponseShapeTests(unittest.TestCase):
    """253-117 Task 1: every run the fake serves has GitHub's recorded shape, and the gate fails if that drifts."""

    @classmethod
    def setUpClass(cls):
        cls.runner = load_runner()
        cls.real = {"R9 seq 27": ledger_body(R9_LEDGER, "run", 27), "R8 run poll": ledger_body(R8_LEDGER, "run")}

    def fake_run(self, scenario="full-pass", bare_name=False):
        record = {"id": 40000000123, "run_number": 501, "scenario": scenario, "head_branch": "gsd/253-replan-r9-fixture",
                  "head_sha": "aa7014893b716f279b60ceb545b8aee5ca15b10c"}
        head_commit = {"sha": record["head_sha"], "tree": {"sha": "ef2956c05d5bcde97b1b40141aa36a7ac8932b56"},
                       "message": "Phase 253 isolated gate canary fixture\n",
                       "author": {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
                                  "date": "2026-10-16T10:06:58Z"},
                       "committer": {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
                                     "date": "2026-10-16T10:06:58Z"}}
        return self.runner.build_run(record, "completed", "success", commit=head_commit, bare_name=bare_name)

    def test_fake_run_object_matches_the_recorded_github_shape(self):
        for scenario in ("full-pass", "cancelled", "verifier"):
            fake = self.fake_run(scenario)
            title = f"Phase 253 Gate Canary / {scenario} / 40000000123-1"
            for label, real in self.real.items():
                with self.subTest(scenario=scenario, sample=label):
                    self.assertEqual(real["name"], real["display_title"], f"{label}: GitHub's name is the run-name")
                    self.assertEqual(sorted(fake), sorted(real))
                    for key in NESTED_RUN_OBJECTS:
                        self.assertIsInstance(fake[key], dict, key)
                        self.assertEqual(sorted(fake[key]), sorted(real[key]), key)
                    self.assertEqual(real["path"], ".github/workflows/ci.yml")
            self.assertEqual(fake["name"], title)
            self.assertEqual(fake["display_title"], title)
            self.assertEqual(fake["path"], ".github/workflows/ci.yml")
            self.assertEqual((fake["workflow_id"], fake["event"], fake["run_attempt"]), (259268962, "workflow_dispatch", 1))
            self.assertEqual((fake["pull_requests"], fake["previous_attempt_url"]), ([], None))
            self.assertEqual(fake["head_commit"]["id"], "aa7014893b716f279b60ceb545b8aee5ca15b10c")
            self.assertEqual(fake["head_commit"]["tree_id"], "ef2956c05d5bcde97b1b40141aa36a7ac8932b56")
            self.assertTrue(all("40000000123" in fake[key] for key in ("url", "html_url", "jobs_url", "logs_url",
                                                                       "artifacts_url", "cancel_url", "rerun_url")))
        # The shape check accepts the real-shape fake and names name and path on the old bare-name shape.
        reference = self.runner.load_reference()
        good = self.runner.check_run_shape(self.fake_run(), "full-pass", reference)
        self.assertEqual(good, [])
        bad = self.runner.check_run_shape(self.fake_run(bare_name=True), "full-pass", reference)
        self.assertTrue(any("name" in item for item in bad), bad)
        self.assertTrue(any("path" in item for item in bad), bad)

    def test_job_step_and_artifact_shape_checks_refuse_the_pre_253_117_fake_shapes(self):
        # 253-117 Task 2: the real-shape builders pass; the old fake's minimal objects are refused (positive control).
        reference = self.runner.load_reference()
        real = {"jobs": ledger_body(R9_LEDGER, "run_jobs", 28), "artifacts": ledger_body(R9_LEDGER, "run_artifacts", 29)}
        record = {"id": 40000000123, "run_number": 501, "scenario": "full-pass", "head_branch": "gsd/253-replan-r9-fixture",
                  "head_sha": "aa7014893b716f279b60ceb545b8aee5ca15b10c"}
        producer = self.runner.reference_steps(reference, "producer")
        verdict = self.runner.reference_steps(reference, "Browser verdict")
        self.assertEqual(producer, ["Set up job", "Run the named synthetic tiny command",
                                    "Upload this producer's synthetic receipt", "Complete job"])
        self.assertEqual(verdict, [step["name"] for step in next(job for job in real["jobs"]["jobs"]
                                                               if job["name"] == "Browser verdict")["steps"]])
        jobs = [self.runner.build_job(record, 1, "producer (non_admin_smoke)", "success",
                                      self.runner.build_steps(producer, None, True), reference),
                self.runner.build_job(record, 2, "Browser verdict", "success", self.runner.build_steps(verdict, None, True), reference),
                self.runner.build_job(record, 3, "verifier", "skipped", [], reference)]
        for job in jobs:
            self.assertEqual(sorted(job), sorted(real["jobs"]["jobs"][0]))
            for step in job["steps"]:
                self.assertEqual(sorted(step), sorted(real["jobs"]["jobs"][0]["steps"][0]))
        artifact = self.runner.build_artifact(record, 900001, "gate-canary-full-pass-40000000123-1", 10, "0" * 64, reference)
        self.assertEqual(sorted(artifact), sorted(real["artifacts"]["artifacts"][0]))
        self.assertEqual(sorted(artifact["workflow_run"]), sorted(real["artifacts"]["artifacts"][0]["workflow_run"]))
        good, _, _ = self.runner.check_jobs_shape({"total_count": 3, "jobs": jobs}, record["id"], record, reference)
        self.assertEqual([item for item in good if item], [])
        good, _ = self.runner.check_artifacts_shape({"total_count": 1, "artifacts": [artifact]}, record["id"], reference)
        self.assertEqual([item for item in good if item], [])
        old_job = {"id": 1, "run_id": record["id"], "run_attempt": 1, "name": "producer (non_admin_smoke)", "status": "completed",
                   "conclusion": "success", "head_sha": record["head_sha"],
                   "steps": [{"name": "Run the named synthetic tiny command", "status": "completed", "conclusion": "success",
                              "number": 1}]}
        bad, _, _ = self.runner.check_jobs_shape({"total_count": 1, "jobs": [old_job]}, record["id"], record, reference)
        bad = " ".join(item for item in bad if item)
        self.assertIn("keys differ", bad)
        self.assertIn("steps", bad)
        old_artifact = {"id": 900001, "name": "x", "size_in_bytes": 1, "expired": False, "digest": "sha256:" + "0" * 64,
                        "archive_download_url": "https://api.github.com/x",
                        "workflow_run": {"id": record["id"], "head_branch": "b", "head_sha": "c"}}
        bad, _ = self.runner.check_artifacts_shape({"total_count": 1, "artifacts": [old_artifact]}, record["id"], reference)
        bad = " ".join(item for item in bad if item)
        self.assertIn("workflow_run keys differ", bad)

    def test_response_shape_fault_fails_the_gate(self):
        code, summary = run_gate("--ref-pair", "r9", "--seed-r8-refs", "--stop-after", "full-pass",
                                 "--fault", "run-shape-bare-name")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        shape = summary.get("response_shape") or {}
        self.assertIs(shape.get("ok"), False, summary)
        self.assertGreaterEqual(shape.get("runs_checked", 0), 1, shape)
        mismatches = " ".join(shape.get("mismatches") or [])
        self.assertIn("name", mismatches)
        self.assertIn("path", mismatches)
        # The verifier accepts the bare-name run by design (253-116), so only the shape assertion fails the gate.
        self.assertEqual(summary.get("scenarios"), ["full-pass"], summary)
        self.assertTrue(all(item["exit"] == 0 for item in summary.get("invocations", [])), summary.get("invocations"))
        self.assertTrue(any("response_shape" in problem for problem in summary.get("problems", [])), summary.get("problems"))

    def test_both_quick_gates_report_a_passing_response_shape(self):
        for code, summary in (run_gate("--ref-pair", "r9", "--seed-r8-refs", "--stop-after", "full-pass"),
                              live_run("--ref-pair", "r9", "--seed-r8-refs", "--stop-after", "full-pass")):
            with self.subTest(mode=summary.get("mode")):
                self.assertEqual(code, 0, summary)
                shape = summary.get("response_shape") or {}
                self.assertIs(shape.get("ok"), True, shape)
                self.assertGreaterEqual(shape.get("runs_checked", 0), 1, shape)
                self.assertIn("full-pass", shape.get("scenarios_checked") or [], shape)
                self.assertEqual(shape.get("reference", {}).get("sha256"),
                                 hashlib.sha256(R9_LEDGER.read_bytes()).hexdigest(), shape)


# --------------------------------------------------------------- 253-128 GitHub's recorded run-log chain (253-127 probe)
PROBE_LEDGER = PHASE_DIR / "253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json"
PROBE_EVIDENCE = PHASE_DIR / "253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json"
PROBE_BODIES = PHASE_DIR / "253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json"
R10_LEDGER = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json"
RESULTS_RECEIVER = RESULTS_RECEIVER_HOST


def ledger_rows(path):
    return {row["sequence"]: row for row in json.loads(Path(path).read_text())["transactions"]}


class FakeChainHarness:
    """Starts the dry-run fake (hermetic or live-policy) and fetches one run's failed-log chain the way the transport
    does: a charged pending ledger row per hop, hop 0 on api.github.com, then the Location it was given."""

    def __init__(self, runner, live, faults=()):
        import ssl
        self.runner, self.live = runner, live
        self.directory = tempfile.TemporaryDirectory(prefix="sigra-253-128-chain-")
        self.work = Path(self.directory.name).resolve()
        clone = self.work / "clone"
        subprocess.run(["git", "clone", "-q", "--shared", "--no-checkout", str(ROOT), str(clone)], check=True)
        parent = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
        self.ledger, self.journal = self.work / "ledger.json", self.work / "journal.json"
        self.server, _, self.cert = runner.start_fake(self.work, clone, self.ledger, self.journal, parent, None, 0.0,
                                                      dict(runner.DEFAULT_POLLS), False, live=live)
        self.server.faults = set(faults)
        self.port = self.server.server_address[1]
        self.ssl = ssl

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.directory.cleanup()

    def add_failed_run(self, run_id=40000000777, scenario="actual-failure"):
        self.server.runs[run_id] = {"id": run_id, "run_number": 777, "scenario": scenario, "inputs": {},
                                    "head_branch": "gsd/253-replan-r10-fixture", "head_sha": "0" * 40, "visible_at": 0,
                                    "polls": 3, "needed": 3, "cancel_requested": False, "completed": True,
                                    "conclusion": "failure"}
        return run_id

    def get(self, host, path, hop):
        import http.client
        url = f"https://{host}{path.split('?', 1)[0]}" + ("?[REDACTED]" if "?" in path else "")
        self.ledger.write_text(json.dumps({"transactions": [{"state": "pending", "method": "GET", "url": url,
                                                             "route_id": "run_logs", "hop_ordinal": hop, "host": host}]}))
        if self.live:
            shim = load_shim_module()
            with shim.patched({host: self.port}, self.cert, self.work / "connect.jsonl"):
                connection = http.client.HTTPSConnection(host, 443, context=self.ssl.create_default_context(), timeout=10)
                headers = {"Authorization": f"Bearer {self.runner.LIVE_TOKEN}"} if host == "api.github.com" else {}
                connection.request("GET", path, headers=headers)
                response = connection.getresponse()
                result = (response.status, response.getheaders(), response.read())
                connection.close()
        else:
            context = self.ssl.create_default_context(cafile=str(self.cert))
            connection = http.client.HTTPSConnection("localhost", self.port, context=context, timeout=10)
            connection.request("GET", path)
            response = connection.getresponse()
            result = (response.status, response.getheaders(), response.read())
            connection.close()
        self.ledger.unlink()
        return result

    def chain(self, run_id):
        from urllib.parse import urlsplit
        hops = [self.get("api.github.com" if self.live else "localhost", f"/repos/szTheory/sigra/actions/runs/{run_id}/logs", 0)]
        while hops[-1][0] in (301, 302, 303, 307, 308) and len(hops) <= 2:
            location = dict((name.lower(), value) for name, value in hops[-1][1])["location"]
            parsed = urlsplit(location)
            hops.append(self.get(parsed.hostname, parsed.path + ("?" + parsed.query if parsed.query else ""), len(hops)))
        return hops


def load_shim_module():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_live_policy_shim_for_dryrun_test", ROOT / "scripts/ci/ci-live-policy-shim.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RunLogsShapeTests(unittest.TestCase):
    """253-128 Task 1: the fake's failed-log chain is GitHub's recorded one (253-127 probe, R10 ledger seq 47)."""

    @classmethod
    def setUpClass(cls):
        cls.runner = load_runner()
        evidence = json.loads(PROBE_EVIDENCE.read_text())
        cls.probe_hops = next(item for item in evidence["results"] if item["id"] == "run-log-chain")["observed"]["hops"]
        cls.probe_body = next(item for item in json.loads(PROBE_BODIES.read_text())["entries"] if item["id"] == "run-log-chain")
        cls.seq47 = ledger_rows(R10_LEDGER)[47]
        cls.probe_rows = [row for row in ledger_rows(PROBE_LEDGER).values() if row["route_id"] == "run_logs"]

    def test_fake_log_redirect_matches_the_probe_recorded_chain(self):
        import io
        import zipfile
        from urllib.parse import urlsplit
        # The committed references agree with each other: the probe's two run_logs rows, its evidence hops and seq 47.
        self.assertEqual([(row["hop_ordinal"], row["host"], row["actual_status"]) for row in self.probe_rows],
                         [(0, "api.github.com", 302), (1, RESULTS_RECEIVER, 200)])
        self.assertEqual([hop["status"] for hop in self.probe_hops], [302, 200])
        self.assertEqual(self.seq47["actual_status"], self.probe_hops[0]["status"])
        self.assertEqual(self.seq47["scrubbed_headers"]["content-type"], self.probe_hops[0]["content_type"])
        self.assertEqual(self.seq47["scrubbed_headers"]["location"]["host"], self.probe_hops[0]["location"]["host"])
        reference = self.runner.load_log_reference()
        self.assertEqual(reference["hops"], self.probe_hops)
        self.assertEqual(reference["files"][self.runner.PROBE_EVIDENCE_REL], hashlib.sha256(PROBE_EVIDENCE.read_bytes()).hexdigest())
        self.assertEqual(reference["files"][self.runner.PROBE_BODIES_REL], hashlib.sha256(PROBE_BODIES.read_bytes()).hexdigest())
        self.assertEqual(reference["files"][self.runner.PROBE_LEDGER_REL], hashlib.sha256(PROBE_LEDGER.read_bytes()).hexdigest())
        self.assertEqual(reference["files"][self.runner.R10_LEDGER_REL], hashlib.sha256(R10_LEDGER.read_bytes()).hexdigest())
        for live in (False, True):
            with self.subTest(mode="live-policy" if live else "hermetic"):
                harness = FakeChainHarness(self.runner, live)
                try:
                    run_id = harness.add_failed_run()
                    hops = harness.chain(run_id)
                    journal = json.loads(harness.journal.read_text())
                    # Positive control: the fake really answered both hops (so the empty-mismatch result below is a check).
                    self.assertEqual(len(hops), len(self.probe_hops), [hop[0] for hop in hops])
                    self.assertEqual(len(journal), len(self.probe_hops))
                    problems, chains = self.runner.check_run_logs(journal, reference, live, harness.port)
                    self.assertEqual(problems, [])
                    self.assertEqual(chains, 1)
                    for (status, headers, body), row, probe in zip(hops, journal, self.probe_hops):
                        self.assertEqual(status, probe["status"])
                        self.assertEqual(sorted(row["scrubbed_headers"]), probe["safe_header_names"])
                        self.assertEqual(row["scrubbed_headers"].get("content-type"), probe["content_type"])
                        self.assertEqual(row["scrubbed_headers"].get("content-length"),
                                         None if probe["content_length"] is None else str(probe["content_length"]))
                        if live:
                            self.assertEqual(row["host"], probe["host"])
                    location = journal[0]["scrubbed_headers"]["location"]
                    recorded = self.probe_hops[0]["location"]
                    self.assertEqual(location["host"], recorded["host"] if live else "localhost")
                    self.assertEqual(location["port"], recorded["port"] if live else harness.port)
                    self.assertEqual(location["has_query"], recorded["has_query"])
                    self.assertRegex(location["path"], r"^/rest/runs/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/logs$")
                    self.assertEqual(self.runner.path_pattern(location["path"]), recorded["path_pattern"])
                    self.assertEqual(self.runner.path_pattern(self.seq47["scrubbed_headers"]["location"]["path"]),
                                     recorded["path_pattern"])
                    self.assertNotIn("location", journal[1]["scrubbed_headers"], "GitHub's hop 1 is final: no hop 2")
                    body = hops[1][2]
                    self.assertEqual(body[:8].hex(), self.probe_body["magic_hex"])
                    names = zipfile.ZipFile(io.BytesIO(body)).namelist()
                    self.assertEqual(self.runner.log_member_problems(names), [])
                    self.assertEqual(self.runner.log_member_problems([member["name"] for member in self.probe_body["zip_members"]]), [])
                    self.assertEqual(len(names), 2 * 6, "a numbered log and a system.txt per executed job")
                    self.assertNotEqual(urlsplit(dict(hops[0][1]).get("Location", "")).hostname, self.runner.BLOB_HOST)
                    # The pre-R11 blob log path no longer exists in the fake (without the legacy fault).
                    stale = harness.get(self.runner.BLOB_HOST if live else "localhost",
                                        f"/_downloads/logs/{run_id}?sv=2025&sig=dry-run-signature" if live
                                        else f"/_downloads/logs/{run_id}?sig=dry-run-signature", 1)
                    self.assertEqual(stale[0], 404)
                finally:
                    harness.close()

    def test_run_logs_legacy_blob_fault_fails_the_gate(self):
        code, summary = live_run("--ref-pair", "r10", "--seed-r8-refs", "--seed-r9-refs", "--fault", "run-logs-legacy-blob-redirect")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        shape = summary.get("response_shape") or {}
        self.assertIs(shape.get("ok"), False, shape)
        mismatches = " ".join(shape.get("mismatches") or [])
        self.assertIn("Location host", mismatches)
        self.assertIn(self.runner.BLOB_HOST, mismatches)
        # The retained pre-R11 transport predicate still follows the blob redirect, and the driver and verifier accept the
        # run: only the shape assertion fails the gate (positive control on the assertion, not the transport).
        self.assertTrue(all(item["exit"] == 0 for item in summary.get("invocations", [])), summary.get("invocations"))
        self.assertEqual(sorted(summary.get("scenarios") or []), sorted(["full-pass", "docs-only", "actual-failure",
                                                                         "missing-seam", "unexpected-skip", "cancelled"]))
        self.assertEqual((summary.get("verifier") or {}).get("status"), "passed", summary)
        logs = [hop for hop in summary.get("live_hops") or [] if hop["route"] == "run_logs"]
        self.assertEqual(len(logs), 3, logs)
        self.assertTrue(all(hop["host"] == self.runner.BLOB_HOST for hop in logs), logs)
        problems = summary.get("problems") or []
        self.assertTrue(problems and all(problem.startswith("response_shape") for problem in problems), problems)


class CancelledShapeTests(unittest.TestCase):
    """253-128 Task 2: the fake's cancelled run and jobs carry the shape GitHub returned for real cancelled run
    38141825287 (253-127 probe ledger seq 2 and 3, both 200)."""

    @classmethod
    def setUpClass(cls):
        import base64
        cls.runner = load_runner()
        rows = ledger_rows(PROBE_LEDGER)
        evidence = {item["id"]: item for item in json.loads(PROBE_EVIDENCE.read_text())["results"]}
        cls.sequences = {name: evidence[name]["observed"]["hops"][0]["sequence"] for name in ("cancelled-run", "cancelled-jobs")}
        cls.statuses = {name: rows[sequence]["actual_status"] for name, sequence in cls.sequences.items()}
        cls.real_run = json.loads(base64.b64decode(rows[cls.sequences["cancelled-run"]]["response_body_base64"]))
        cls.real_jobs = json.loads(base64.b64decode(rows[cls.sequences["cancelled-jobs"]]["response_body_base64"]))

    def record(self):
        return {"id": 40000000999, "run_number": 999, "scenario": "cancelled", "inputs": {},
                "head_branch": "gsd/253-replan-r10-fixture", "head_sha": "aa7014893b716f279b60ceb545b8aee5ca15b10c",
                "completed": True, "conclusion": "cancelled"}

    def test_fake_cancelled_run_matches_the_probe_recorded_shape(self):
        # The probe captured both with 200, so the captured branch applies (not the unavailable marker).
        self.assertEqual(self.statuses, {"cancelled-run": 200, "cancelled-jobs": 200})
        self.assertEqual((self.real_run["status"], self.real_run["conclusion"], self.real_run["id"]),
                         ("completed", "cancelled", 38141825287))
        reference = self.runner.load_cancelled_reference()
        self.assertIs(reference["available"], True, reference)
        self.assertEqual(reference["files"][self.runner.PROBE_LEDGER_REL], hashlib.sha256(PROBE_LEDGER.read_bytes()).hexdigest())
        record = self.record()
        run = self.runner.build_run(record, "completed", "cancelled")
        page = self.runner.build_jobs_page(record)
        self.assertEqual(sorted(run), sorted(self.real_run))
        for key in NESTED_RUN_OBJECTS:
            self.assertEqual(sorted(run[key]), sorted(self.real_run[key]), key)
        self.assertEqual((run["status"], run["conclusion"]), ("completed", "cancelled"))
        self.assertEqual(type(run["pull_requests"]), type(self.real_run["pull_requests"]))
        self.assertEqual(sorted(page), sorted(self.real_jobs))
        real_job, real_step = self.real_jobs["jobs"][0], next(job for job in self.real_jobs["jobs"] if job["steps"])["steps"][0]
        recorded_jobs = {(job["status"], job["conclusion"]) for job in self.real_jobs["jobs"]}
        recorded_steps = {(step["status"], step["conclusion"]) for job in self.real_jobs["jobs"] for step in job["steps"] or []}
        for job in page["jobs"]:
            self.assertEqual(sorted(job), sorted(real_job), job["name"])
            self.assertIn((job["status"], job["conclusion"]), recorded_jobs, job["name"])
            for step in job["steps"]:
                self.assertEqual(sorted(step), sorted(real_step))
                self.assertIn((step["status"], step["conclusion"]), recorded_steps, (job["name"], step["name"]))
        cancelled = [job for job in page["jobs"] if job["conclusion"] == "cancelled"]
        self.assertTrue(cancelled, "a cancelled run lists at least one cancelled job, as GitHub's does")
        self.assertEqual(self.runner.check_cancelled_shape(run, page, reference), [])
        # Positive controls: the drift fault's jobs page and an event-typed field change are both named.
        drift = self.runner.build_jobs_page(record, faults={"cancelled-shape-drift"})
        problems = " ".join(self.runner.check_cancelled_shape(run, drift, reference))
        self.assertIn("cancelled", problems)
        self.assertIn("failure", " ".join(json.dumps(job["conclusion"]) for job in drift["jobs"]))
        retyped = dict(run, pull_requests=None)
        self.assertTrue(any("pull_requests" in item for item in self.runner.check_cancelled_shape(retyped, page, reference)))

    def test_cancelled_shape_drift_fault_fails_the_gate(self):
        code, summary = run_gate("--ref-pair", "r10", "--seed-r8-refs", "--seed-r9-refs", "--fault", "cancelled-shape-drift")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        shape = summary.get("response_shape") or {}
        self.assertIs(shape.get("ok"), False, shape)
        self.assertTrue(any("cancelled" in item for item in shape.get("mismatches") or []), shape)
        self.assertTrue(any(problem.startswith("response_shape") for problem in summary.get("problems", [])), summary.get("problems"))


class SeededR9RefsTests(unittest.TestCase):
    """253-119: --seed-r9-refs pre-seeds the two r9 refs 253-113 created on GitHub, at their real SHAs, beside the r8 pair."""

    def test_the_seeded_pairs_are_the_real_github_shas_and_r8_is_unchanged(self):
        runner = load_runner()
        self.assertEqual(runner.R8_REFS, {"gsd/253-replan-r8-candidate": "7a1ba235a502c1f7b379a6109698fa59b65b6c8a",
                                          "gsd/253-replan-r8-fixture": "ad015ec1005b7f19d8722ce3650aa1eb777b8f44"})
        self.assertEqual(runner.R9_REFS, {"gsd/253-replan-r9-candidate": "b9720d8e00e69e11c965ed7cf5029e3a0008783a",
                                          "gsd/253-replan-r9-fixture": "aa7014893b716f279b60ceb545b8aee5ca15b10c"})
        freeze = json.loads((ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
                             "253-LOAD-RECOVERY-CANARY-FREEZE-R9.json").read_text())["identity"]
        self.assertEqual({freeze["candidate_ref"].removeprefix("refs/heads/"): freeze["candidate_helper_commit"],
                          freeze["fixture_ref"].removeprefix("refs/heads/"): freeze["fixture_workflow_commit"]}, runner.R9_REFS)

    def test_an_r10_quick_gate_with_both_earlier_pairs_seeded_passes_in_both_modes_and_moves_neither(self):
        for label, (code, summary) in (
                ("hermetic", run_gate("--ref-pair", "r10", "--seed-r8-refs", "--seed-r9-refs", "--stop-after", "full-pass")),
                ("live-policy", live_run("--ref-pair", "r10", "--seed-r8-refs", "--seed-r9-refs", "--stop-after", "full-pass"))):
            with self.subTest(mode=label):
                self.assertEqual(code, 0, summary)
                self.assertEqual(summary.get("status"), "passed", summary)
                self.assertIs(summary.get("seeded_r8_refs_changed"), False, summary)
                self.assertIs(summary.get("seeded_r9_refs_changed"), False, summary)
                self.assertIs((summary.get("response_shape") or {}).get("ok"), True, summary)
                self.assertEqual(summary.get("requests_by_route", {}).get("create_ref"), 2, summary)

    def test_an_r9_named_run_with_the_r9_refs_seeded_stops_on_the_first_get_ref_and_moves_nothing(self):
        code, summary = run_gate("--ref-pair", "r9", "--seed-r9-refs", "--stop-after", "full-pass")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        self.assertIn("scoped ref gsd/253-replan-r9-candidate already points to a different commit", summary.get("stop") or "", summary)
        self.assertIs(summary.get("seeded_r9_refs_changed"), False, summary)
        self.assertNotIn("seeded_r8_refs_changed", summary)
        self.assertNotIn("create_ref", summary.get("requests_by_route") or {"create_ref": 1})
        self.assertEqual(summary.get("evidence_status"), "halted", summary)


class SeededR10RefsTests(unittest.TestCase):
    """253-130: --seed-r10-refs pre-seeds the two r10 refs 253-122 created on GitHub, at their real SHAs, beside r8 and r9."""

    def test_the_seeded_r10_pair_is_freeze_r10s_commits_and_r8_r9_are_unchanged(self):
        runner = load_runner()
        self.assertEqual(runner.R8_REFS, {"gsd/253-replan-r8-candidate": "7a1ba235a502c1f7b379a6109698fa59b65b6c8a",
                                          "gsd/253-replan-r8-fixture": "ad015ec1005b7f19d8722ce3650aa1eb777b8f44"})
        self.assertEqual(runner.R9_REFS, {"gsd/253-replan-r9-candidate": "b9720d8e00e69e11c965ed7cf5029e3a0008783a",
                                          "gsd/253-replan-r9-fixture": "aa7014893b716f279b60ceb545b8aee5ca15b10c"})
        self.assertEqual(runner.R10_REFS, {"gsd/253-replan-r10-candidate": "d16617f77223ff136a0c9e04bc3cd067bc6370cf",
                                           "gsd/253-replan-r10-fixture": "06bb7dfb7dad0221d49292b9342ad871685a673b"})
        phase = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
        freeze = json.loads((phase / "253-LOAD-RECOVERY-CANARY-FREEZE-R10.json").read_text())["identity"]
        self.assertEqual({freeze["candidate_ref"].removeprefix("refs/heads/"): freeze["candidate_helper_commit"],
                          freeze["fixture_ref"].removeprefix("refs/heads/"): freeze["fixture_workflow_commit"]}, runner.R10_REFS)
        receipt = json.loads((phase / "253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R10.json").read_text())
        created = {row["ref"].removeprefix("refs/heads/"): row["sha"] for row in receipt["server_object_receipts"] if row.get("kind") == "ref"}
        self.assertEqual(created, runner.R10_REFS)

    def test_seeded_scoped_refs_merges_exactly_the_requested_pairs(self):
        runner = load_runner()
        flags = argparse.Namespace
        self.assertEqual(runner.seeded_scoped_refs(flags()), {})
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r10_refs=True)), runner.R10_REFS)
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r8_refs=True, seed_r9_refs=True)), {**runner.R8_REFS, **runner.R9_REFS})
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r8_refs=True, seed_r9_refs=True, seed_r10_refs=True)),
                         {**runner.R8_REFS, **runner.R9_REFS, **runner.R10_REFS})

    def test_an_r11_quick_gate_with_all_three_earlier_pairs_seeded_passes_in_both_modes_and_moves_none(self):
        flags = ("--ref-pair", "r11", "--seed-r8-refs", "--seed-r9-refs", "--seed-r10-refs", "--stop-after", "full-pass")
        for label, (code, summary) in (("hermetic", run_gate(*flags)), ("live-policy", live_run(*flags))):
            with self.subTest(mode=label):
                self.assertEqual(code, 0, summary)
                self.assertEqual(summary.get("status"), "passed", summary)
                for pair in ("r8", "r9", "r10"):
                    self.assertIs(summary.get(f"seeded_{pair}_refs_changed"), False, summary)
                self.assertIs((summary.get("response_shape") or {}).get("ok"), True, summary)
                self.assertEqual(summary.get("requests_by_route", {}).get("create_ref"), 2, summary)

    def test_an_r10_named_run_with_the_r10_refs_seeded_stops_on_the_first_get_ref_and_moves_nothing(self):
        code, summary = run_gate("--ref-pair", "r10", "--seed-r10-refs", "--stop-after", "full-pass")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        self.assertIn("scoped ref gsd/253-replan-r10-candidate already points to a different commit", summary.get("stop") or "", summary)
        self.assertIs(summary.get("seeded_r10_refs_changed"), False, summary)
        self.assertNotIn("seeded_r8_refs_changed", summary)
        self.assertNotIn("seeded_r9_refs_changed", summary)
        self.assertNotIn("create_ref", summary.get("requests_by_route") or {"create_ref": 1})
        self.assertEqual(summary.get("evidence_status"), "halted", summary)


class SeededR11RefsTests(unittest.TestCase):
    """253-137: --seed-r11-refs pre-seeds the two r11 refs 253-133 created on GitHub, at their real SHAs, beside r8, r9 and r10."""

    def test_the_seeded_r11_pair_is_freeze_r11s_commits_and_r8_r9_r10_are_unchanged(self):
        runner = load_runner()
        self.assertEqual(runner.R8_REFS, {"gsd/253-replan-r8-candidate": "7a1ba235a502c1f7b379a6109698fa59b65b6c8a",
                                          "gsd/253-replan-r8-fixture": "ad015ec1005b7f19d8722ce3650aa1eb777b8f44"})
        self.assertEqual(runner.R9_REFS, {"gsd/253-replan-r9-candidate": "b9720d8e00e69e11c965ed7cf5029e3a0008783a",
                                          "gsd/253-replan-r9-fixture": "aa7014893b716f279b60ceb545b8aee5ca15b10c"})
        self.assertEqual(runner.R10_REFS, {"gsd/253-replan-r10-candidate": "d16617f77223ff136a0c9e04bc3cd067bc6370cf",
                                           "gsd/253-replan-r10-fixture": "06bb7dfb7dad0221d49292b9342ad871685a673b"})
        phase = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
        freeze = json.loads((phase / "253-LOAD-RECOVERY-CANARY-FREEZE-R11.json").read_text())["identity"]
        self.assertEqual({freeze["candidate_ref"].removeprefix("refs/heads/"): freeze["candidate_helper_commit"],
                          freeze["fixture_ref"].removeprefix("refs/heads/"): freeze["fixture_workflow_commit"]}, runner.R11_REFS)
        receipt = json.loads((phase / "253-LOAD-RECOVERY-CANARY-PUBLICATION-RECEIPT-R11.json").read_text())
        created = {row["ref"].removeprefix("refs/heads/"): row["sha"] for row in receipt["server_object_receipts"] if row.get("kind") == "ref"}
        self.assertEqual(created, runner.R11_REFS)
        self.assertEqual(len(runner.R11_REFS), 2)

    def test_seeded_scoped_refs_merges_exactly_the_requested_pairs_including_r11(self):
        runner = load_runner()
        flags = argparse.Namespace
        self.assertEqual(runner.seeded_scoped_refs(flags()), {})
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r11_refs=True)), runner.R11_REFS)
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r10_refs=True)), runner.R10_REFS)
        self.assertEqual(runner.seeded_scoped_refs(flags(seed_r8_refs=True, seed_r9_refs=True, seed_r10_refs=True, seed_r11_refs=True)),
                         {**runner.R8_REFS, **runner.R9_REFS, **runner.R10_REFS, **runner.R11_REFS})

    def test_an_r12_quick_gate_with_all_four_earlier_pairs_seeded_passes_in_both_modes_and_moves_none(self):
        flags = ("--ref-pair", "r12", "--seed-r8-refs", "--seed-r9-refs", "--seed-r10-refs", "--seed-r11-refs", "--stop-after", "full-pass")
        for label, (code, summary) in (("hermetic", run_gate(*flags)), ("live-policy", live_run(*flags))):
            with self.subTest(mode=label):
                self.assertEqual(code, 0, summary)
                self.assertEqual(summary.get("status"), "passed", summary)
                for pair in ("r8", "r9", "r10", "r11"):
                    self.assertIs(summary.get(f"seeded_{pair}_refs_changed"), False, summary)
                self.assertIs((summary.get("response_shape") or {}).get("ok"), True, summary)
                self.assertEqual(summary.get("requests_by_route", {}).get("create_ref"), 2, summary)

    def test_an_r11_named_run_with_the_r11_refs_seeded_stops_on_the_first_get_ref_and_moves_nothing(self):
        code, summary = run_gate("--ref-pair", "r11", "--seed-r11-refs", "--stop-after", "full-pass")
        self.assertNotEqual(code, 0, summary)
        self.assertNotEqual(summary.get("status"), "passed", summary)
        self.assertIn("scoped ref gsd/253-replan-r11-candidate already points to a different commit", summary.get("stop") or "", summary)
        self.assertIs(summary.get("seeded_r11_refs_changed"), False, summary)
        for pair in ("r8", "r9", "r10"):
            self.assertNotIn(f"seeded_{pair}_refs_changed", summary)
        self.assertNotIn("create_ref", summary.get("requests_by_route") or {"create_ref": 1})
        self.assertEqual(summary.get("evidence_status"), "halted", summary)


class RefPairHelpTests(unittest.TestCase):
    def test_the_ref_pair_help_is_truthful_and_names_the_publishers_ref_pairs(self):
        result = subprocess.run([sys.executable, str(RUNNER), "--help"], cwd=ROOT, env=clean_env(),
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        text = " ".join(result.stdout.split())
        self.assertNotIn("never passed here", text)
        self.assertIn("REF_PAIRS", text)
        self.assertIn("--build-freeze", text)
        self.assertIn("derived synthetic freeze", text)
        import importlib.util
        spec = importlib.util.spec_from_file_location("ci_git_publication_for_help", ROOT / "scripts/ci/ci-git-publication.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name in module.REF_PAIRS:
            self.assertIn(name, text)


class DryRunR12MainRecordTests(unittest.TestCase):
    """253-138: the derived-freeze path of prepare_clone satisfies the r12 main-freshness guard with a synthetic main-fetch
    record committed inside its temporary clone and bound to its own synthetic server parent; it never skips the guard,
    and the real checkout's refs are never written. Earlier pairs are unchanged."""

    PAIRS = ("r12", "r11", None)
    REAL_REFS = ("refs/remotes/origin/main", "refs/heads/main")
    RECORD_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DRYRUN-MAIN-FETCH-R12.json"
    RECORD_SUBJECT = "dry-run: synthetic main-fetch record (fetched_main_sha = server parent)"

    @classmethod
    def git(cls, repo, *args, check=True):
        result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
        if check and result.returncode:
            raise AssertionError(f"git {' '.join(args)} failed: {result.stderr}")
        return result.stdout.strip()

    @classmethod
    def setUpClass(cls):
        cls.runner = load_runner()
        cls.real_before = {ref: cls.git(ROOT, "rev-parse", ref) for ref in cls.REAL_REFS}
        cls.works, cls.prepared = [], {}
        try:
            for pair in cls.PAIRS:
                work = Path(tempfile.mkdtemp(prefix=f"sigra-253-main-record-{pair or 'default'}-")).resolve()
                cls.works.append(work)
                args = argparse.Namespace(overlay_worktree=True, driver_from=None, driver_patch=None, revision_freeze=None,
                                          server_parent=None, ref_pair=pair, overlaid=[])
                cls.prepared[pair] = cls.runner.prepare_clone(args, work)
        finally:
            cls.real_after = {ref: cls.git(ROOT, "rev-parse", ref) for ref in cls.REAL_REFS}

    @classmethod
    def tearDownClass(cls):
        for work in cls.works:
            shutil.rmtree(work, ignore_errors=True)

    def manifest(self, prepared):
        rel = prepared["freeze"]["bound_documents"]["publication_manifest"]["path"]
        return json.loads((prepared["clone"] / rel).read_text())

    def test_the_r12_clone_commits_a_synthetic_main_record_bound_to_its_server_parent(self):
        prepared = self.prepared["r12"]
        clone, freeze = prepared["clone"], prepared["freeze"]
        parent = freeze["identity"]["server_parent_sha"]
        record_path = clone / self.RECORD_REL
        record = json.loads(record_path.read_text())
        self.assertEqual((record["schema_version"], record["status"], record["synthetic"], record["decided_by"]),
                         ("sigra.phase253.main-fetch/r12", "fetched", True, "dry-run-synthetic"))
        self.assertEqual((record["fetched_main_sha"], record["fetch_head_sha"]), (parent, parent))
        self.assertEqual(self.git(clone, "ls-files", "--error-unmatch", self.RECORD_REL), self.RECORD_REL)
        self.assertEqual(self.git(clone, "status", "--porcelain", "--", self.RECORD_REL), "")
        self.assertEqual(self.git(clone, "rev-parse", "refs/remotes/origin/main"), parent)
        manifest = self.manifest(prepared)
        fresh = manifest["main_freshness"]
        self.assertEqual(fresh["fetched_main_sha"], parent)
        self.assertEqual(fresh["record_path"], self.RECORD_REL)
        self.assertIs(fresh["merge_preflight"]["clean"], True)
        self.assertIs(fresh["candidate_parent_is_fetched_main"], True)
        record_sha = hashlib.sha256(record_path.read_bytes()).hexdigest()
        self.assertEqual(freeze["bound_documents"]["main_freshness_record"], {"path": self.RECORD_REL, "sha256": record_sha})
        # The record has its own commit, before the publication commit, and the candidate source is the commit before it.
        subjects = self.git(clone, "log", "--format=%s", "-n", "6").splitlines()
        self.assertIn(self.RECORD_SUBJECT, subjects)
        self.assertLess(subjects.index("dry-run: synthetic publication manifest"), subjects.index(self.RECORD_SUBJECT))
        record_commit = self.git(clone, "log", "--format=%H", "--fixed-strings", f"--grep={self.RECORD_SUBJECT}", "-n", "1")
        self.assertEqual(self.git(clone, "diff-tree", "--no-commit-id", "--name-only", "-r", record_commit), self.RECORD_REL)
        self.assertEqual(manifest["source_sha"], self.git(clone, "rev-parse", f"{record_commit}^"))

    def test_a_manifest_stripped_of_main_freshness_is_refused_inside_the_same_clone(self):
        prepared = self.prepared["r12"]
        clone = prepared["clone"]
        publisher = clone / "scripts/ci/ci-git-publication.py"
        manifest = self.manifest(prepared)
        del manifest["main_freshness"]
        stripped_rel = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DRYRUN-STRIPPED-PUBLICATION.json"
        (clone / stripped_rel).write_text(json.dumps(manifest, indent=2) + "\n")
        self.git(clone, "add", stripped_rel)
        self.git(clone, "commit", "-qm", "dry-run test: manifest stripped of main_freshness")

        def build(manifest_rel, output_rel):
            return subprocess.run([sys.executable, str(publisher), "--build-freeze", "--manifest", manifest_rel, "--output",
                                   output_rel, "--repo-root", str(clone), "--ref-pair", "r12"],
                                  cwd=ROOT, env=clean_env(), capture_output=True, text=True)
        refused_rel = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DRYRUN-STRIPPED-FREEZE.json"
        refused = build(stripped_rel, refused_rel)
        self.assertNotEqual(refused.returncode, 0, "the stripped manifest built an r12 freeze: the guard was bypassed")
        self.assertIn("main_freshness", refused.stderr)
        self.assertFalse((clone / refused_rel).exists())
        # Positive control: the harness's own manifest still builds an r12 freeze in the same clone.
        control_rel = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DRYRUN-CONTROL-FREEZE.json"
        control = build(prepared["freeze"]["bound_documents"]["publication_manifest"]["path"], control_rel)
        self.assertEqual(control.returncode, 0, control.stderr)
        (clone / control_rel).unlink()

    def test_earlier_pairs_get_no_synthetic_record_main_freshness_or_binding(self):
        for pair in ("r11", None):
            with self.subTest(pair=pair):
                prepared = self.prepared[pair]
                self.assertFalse((prepared["clone"] / self.RECORD_REL).exists())
                self.assertNotIn("main_freshness", self.manifest(prepared))
                self.assertEqual(set(prepared["freeze"]["bound_documents"]), {"publication_manifest", "fixture_workflow"})
                self.assertNotIn(self.RECORD_SUBJECT, self.git(prepared["clone"], "log", "--format=%s", "-n", "6"))

    def test_the_real_checkout_refs_never_move_and_the_clone_ref_is_its_own(self):
        self.assertEqual(self.real_after, self.real_before)
        clone_main = self.git(self.prepared["r12"]["clone"], "rev-parse", "refs/remotes/origin/main")
        # Positive control: the clone's origin/main is the R7 synthetic parent, not the real checkout's origin/main.
        self.assertEqual(clone_main, self.prepared["r12"]["freeze"]["identity"]["server_parent_sha"])
        self.assertNotEqual(clone_main, self.real_before["refs/remotes/origin/main"])


class DryRunPaginatedCheckRunsTests(unittest.TestCase):
    """253-146: the server parent is the fetched main as 253-143 read it (209 check runs, three pages, GitHub's Link
    header). Live-policy emits GitHub's /repositories/<id>/ next links, hermetic the local /repos/ form; both must pass the
    preflight with exactly 3 check_runs pages (preflight 7 of 8) and reach the workflow lookup and full-pass."""

    FLAGS = ("--ref-pair", "r12", "--seed-r8-refs", "--seed-r9-refs", "--seed-r10-refs", "--seed-r11-refs", "--stop-after", "full-pass")

    def check_quick_gate(self, code, summary, form):
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary.get("status"), "passed", summary)
        reads = [read for read in summary.get("paginated_reads") or [] if read.get("route") == "check_runs"]
        self.assertEqual(len(reads), 1, summary.get("paginated_reads"))
        self.assertEqual(reads[0]["pages"], 3, reads)
        self.assertEqual(reads[0]["next_link_forms"], [form], reads)
        self.assertEqual(summary.get("requests_by_category", {}).get("preflight"), 7, summary.get("requests_by_category"))
        self.assertEqual(summary.get("requests_by_route", {}).get("check_runs"), 3, summary.get("requests_by_route"))
        self.assertEqual(summary.get("requests_by_route", {}).get("workflow"), 1, summary.get("requests_by_route"))
        self.assertIn("full-pass", summary.get("scenarios") or [], summary)
        for pair in ("r8", "r9", "r10", "r11"):
            self.assertIs(summary.get(f"seeded_{pair}_refs_changed"), False, summary)

    def test_live_policy_quick_gate_reads_three_repositories_id_pages_within_preflight_seven(self):
        code, summary = live_run(*self.FLAGS)
        self.check_quick_gate(code, summary, "repositories-id")
        self.assertEqual(summary.get("mode"), "live-policy")
        self.assertEqual(summary.get("shim_refusals"), [], summary)
        self.assertEqual((summary.get("authorization") or {}).get("blob_with"), 0, summary)
        self.assertEqual((summary.get("authorization") or {}).get("results_receiver_with"), 0, summary)

    def test_hermetic_quick_gate_reads_three_repos_form_pages_within_preflight_seven(self):
        code, summary = run_gate(*self.FLAGS)
        self.check_quick_gate(code, summary, "repos")
        self.assertEqual(summary.get("mode"), "hermetic")

    FULL_FLAGS = FLAGS[:-2]

    def check_full_gate(self, code, summary, form):
        """253-155: the whole window (six scenarios and the verifier) spends exactly 7 preflight requests: one 3-page
        check_runs read, which the remaining step re-verifies offline instead of reading again."""
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary.get("status"), "passed", summary)
        self.assertEqual(summary.get("requests_by_category", {}).get("preflight"), 7, summary.get("requests_by_category"))
        self.assertEqual(summary.get("requests_by_route", {}).get("check_runs"), 3, summary.get("requests_by_route"))
        reads = [read for read in summary.get("paginated_reads") or [] if read.get("route") == "check_runs"]
        self.assertEqual(reads, [{"route": "check_runs", "pages": 3, "next_link_forms": [form]}], summary.get("paginated_reads"))
        invocations = {item["mode"]: item for item in summary.get("invocations", [])}
        self.assertIn("remaining", invocations, summary)
        self.assertEqual(invocations["remaining"]["requests_by_category"].get("preflight", 0), 0, invocations["remaining"])
        self.assertTrue(invocations["remaining"]["retained_preflight_reverified"], invocations["remaining"])
        self.assertEqual(sorted(summary.get("scenarios") or []), sorted(["full-pass", "docs-only", "actual-failure",
                                                                         "missing-seam", "unexpected-skip", "cancelled"]), summary)
        self.assertEqual((summary.get("verifier") or {}).get("status"), "passed", summary)
        for pair in ("r8", "r9", "r10", "r11"):
            self.assertIs(summary.get(f"seeded_{pair}_refs_changed"), False, summary)

    def test_hermetic_full_gate_retains_the_three_page_preflight_within_preflight_seven(self):
        code, summary = run_gate(*self.FULL_FLAGS)
        self.check_full_gate(code, summary, "repos")
        self.assertEqual(summary.get("mode"), "hermetic")

    def test_live_policy_full_gate_retains_the_three_page_preflight_within_preflight_seven(self):
        code, summary = live_run(*self.FULL_FLAGS)
        self.check_full_gate(code, summary, "repositories-id")
        self.assertEqual(summary.get("mode"), "live-policy")
        self.assertEqual(summary.get("shim_refusals"), [], summary)

    def test_the_retained_preflight_is_exactly_one_contiguous_check_runs_read(self):
        """The driver's real retained_preflight, run on window ledgers: only one contiguous 1..n read of one commit with
        n = ceil(total_count/100) from page 1 is a retained preflight."""
        import base64
        import re
        source = (ROOT / DRIVER_REL).read_text()
        match = re.search(r"^retained_preflight\(\) \{\n.*?^\}\n", source, re.M | re.S)
        self.assertIsNotNone(match, "retained_preflight not found in the driver")
        sha, other = "1" * 40, "2" * 40
        def row(page, total=209, commit=sha, status=200):
            body = base64.b64encode(json.dumps({"total_count": total, "check_runs": []}).encode()).decode()
            return {"route_id": "check_runs", "page_ordinal": page, "actual_status": status, "response_body_base64": body,
                    "url": f"https://api.github.com/repos/szTheory/sigra/commits/{commit}/check-runs?per_page=100&page={page}"}
        cases = {
            "three contiguous pages of 209": ([row(1), row(2), row(3)], 0),
            "one page of 7": ([row(1, total=7)], 0),
            "pages 1 and 3": ([row(1), row(3)], 1),
            "two separate page-1 reads": ([row(1, total=7), row(1, total=7)], 1),
            "short read (2 of 3)": ([row(1), row(2)], 1),
            "a page that is not a 200": ([row(1), row(2, status=500), row(3)], 1),
            "pages of two commits": ([row(1), row(2, commit=other), row(3)], 1),
            "no check_runs read": ([], 1),
        }
        for label, (rows, expected) in cases.items():
            with self.subTest(case=label), tempfile.TemporaryDirectory() as directory:
                tmp = Path(directory)
                (tmp / "evidence.json").write_text(json.dumps({"preflight": {"initial_rate_limit": {}}}))
                (tmp / "ledger.json").write_text(json.dumps({"transactions": [{"route_id": "rate_limit"}, *rows]}))
                (tmp / "rate.json").write_text("{}")
                script = (f'EVIDENCE="{tmp}/evidence.json"\nREQUEST_LEDGER="{tmp}/ledger.json"\nRATE_SOURCE="{tmp}/rate.json"\n'
                          + match.group(0) + "retained_preflight\n")
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=60)
                self.assertEqual(result.returncode, expected, f"{label}: {result.stderr}")

    def test_the_fake_serves_209_runs_over_100_100_9_with_githubs_link_rels(self):
        runner = load_runner()
        self.assertEqual(runner.GITHUB_REPOSITORY_ID, 1207487684)
        self.assertEqual(runner.SERVER_PARENT_CHECK_PAGES, (100, 100, 9))
        runs = runner.server_parent_check_runs("f" * 40, 209)
        self.assertEqual(len(runs), 209)
        # 253-155 (restatement h): page 1 is the real 253-143 page, so required names repeat (2-3x), all of one app.
        for name in runner.REQUIRED_CHECKS:
            self.assertGreaterEqual(sum(1 for run in runs if run["name"] == name), 1, name)
            self.assertEqual({(run["app"]["id"], run["app"]["slug"]) for run in runs if run["name"] == name},
                             {(15368, "github-actions")}, name)
        self.assertTrue(any(sum(1 for run in runs if run["name"] == name) >= 2 for name in runner.REQUIRED_CHECKS), runs[:5])
        ledger = {"transactions": [
            {"route_id": "check_runs", "page_ordinal": page, "hop_ordinal": 0, "scrubbed_headers": {"link": links}}
            for page, links in ((1, [{"rel": "next", "destination": {"path": "/repositories/1207487684/commits/x/check-runs"}},
                                     {"rel": "last", "destination": {"path": "/repositories/1207487684/commits/x/check-runs"}}]),
                                (2, [{"rel": "prev", "destination": {"path": "/repos/szTheory/sigra/commits/x/check-runs"}},
                                     {"rel": "next", "destination": {"path": "/repositories/1207487684/commits/x/check-runs"}}]),
                                (3, [{"rel": "prev", "destination": {"path": "/repositories/1207487684/commits/x/check-runs"}}]))]
            + [{"route_id": "workflow", "page_ordinal": 1, "hop_ordinal": 0, "scrubbed_headers": {}}]}
        self.assertEqual(runner.paginated_reads(ledger), [{"route": "check_runs", "pages": 3, "next_link_forms": ["repositories-id"]}])
        # A second page-1 read of the same route is a separate read, never a continuation.
        twice = {"transactions": ledger["transactions"][:1] + ledger["transactions"][:1]}
        self.assertEqual(runner.paginated_reads(twice), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
