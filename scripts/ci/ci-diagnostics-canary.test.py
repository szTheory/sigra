#!/usr/bin/env python3
"""Contract tests for the bounded hosted diagnostics canary."""

from __future__ import annotations

import pathlib
import re
import importlib.util
import hashlib
import json
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ci_diagnostics_canary", ROOT / "scripts/ci/ci-diagnostics-canary.py")
CANARY = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(CANARY)


class CanaryContractTests(unittest.TestCase):
    def test_shared_upload_action_stages_explicit_bundle_with_seven_day_retention(self):
        action = ROOT / ".github/actions/ci-diagnostic-upload/action.yml"
        self.assertTrue(action.is_file(), "the shared production diagnostic upload action must exist")
        source = action.read_text(encoding="utf-8")
        self.assertIn("ci-diagnostic-bundle.py\" stage", source)
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
            self.assertRegex(source, rf"def {function}\(")

    def test_ci_owners_use_shared_upload_without_changing_required_gate_names(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        browser_shard = workflow.split("  example_playwright_shard:", 2)[1].split("\n  example_playwright_smoke:", 2)[0]
        self.assertIn("uses: ./.github/actions/ci-diagnostic-upload", workflow, "CI owners must call the shared uploader")
        self.assertIn("library-ci-diagnostics", workflow, "library diagnostics manifest must be wired")
        self.assertIn("Prepare browser diagnostics manifest", workflow, "browser diagnostics manifest must be wired")
        self.assertIn("name: Upload shard diagnostics", browser_shard, "historical producer-step identity must remain usable")
        self.assertIn("name: example-playwright-${{ matrix.seam }}-${{ github.run_id }}", browser_shard)
        self.assertIn("path: ${{ runner.temp }}/ci-diagnostics/browser/reports/*.json", browser_shard)
        metrics = (ROOT / "scripts/ci/ci-run-metrics.sh").read_text(encoding="utf-8")
        self.assertIn('startswith("sigra-ci-")', metrics,
            "the nested verified diagnostic bundle must not be mistaken for a flat metrics artifact")
        self.assertNotIn("path: |\n            test/example/priv/playwright/playwright-report/", browser_shard,
            "the broad browser workspace upload must be removed")
        for required_name in (
            "Library tests",
            "Example Playwright smoke (full lifecycle)",
            "Example Playwright shard (${{ matrix.seam }})",
        ):
            self.assertIn(required_name, workflow)

    def test_controller_source_hash_checks_happen_before_budget_charges(self):
        controller = ROOT / "scripts/ci/ci-diagnostics-canary.py"
        self.assertTrue(controller.is_file(), "source and budget enforcement must be implemented")
        source = controller.read_text(encoding="utf-8")
        self.assertRegex(source, r"def assert_source_identity\(")
        self.assertIn("controller_requests", source)
        self.assertIn("max_invocations", source)
        self.assertIn("infrastructure_retries", source)

    def test_charge_is_persisted_before_request_and_never_exceeds_allowance(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "FREEZE.json"
            freeze = {
                "schema_version": CANARY.SCHEMA,
                "limits": dict(CANARY.HARD_LIMITS),
                "usage": {"invocations": 3, "controller_requests": 119, "pushes": 0,
                          "infrastructure_retries": 0, "test_retries": 0,
                          "elapsed_started_at": 1000, "charges": []},
            }
            CANARY.atomic_json(path, freeze)
            CANARY.charge_request(path, "final-request", invocation=True, now_epoch=1001)
            charged = json.loads(path.read_text())
            self.assertEqual(charged["usage"]["controller_requests"], 120)
            self.assertEqual(charged["usage"]["invocations"], 4)
            with self.assertRaisesRegex(CANARY.CanaryError, "controller_request_budget_exhausted"):
                CANARY.charge_request(path, "must-not-run", now_epoch=1002)

    def test_rate_observation_is_attached_only_after_a_durable_request_charge(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "FREEZE.json"
            CANARY.atomic_json(path, {"schema_version": CANARY.SCHEMA, "limits": dict(CANARY.HARD_LIMITS),
                "usage": {"invocations": 0, "controller_requests": 0, "pushes": 0,
                    "infrastructure_retries": 0, "test_retries": 0, "elapsed_started_at": None, "charges": []}})
            with self.assertRaisesRegex(CANARY.CanaryError, "rate_response_without_precharge"):
                CANARY.record_rate_observation(path, "GET:/rate_limit", {"resources": {}}, 1000)
            CANARY.charge_request(path, "GET:/rate_limit", now_epoch=1000)
            CANARY.record_rate_observation(path, "GET:/rate_limit", {"resources": {"core": {"remaining": 999}}}, 999,
                '{"resources":{"core":{"remaining":999}}}\n')
            charge = json.loads(path.read_text())["usage"]["charges"][-1]
            self.assertEqual(charge["response"]["resources"]["core"]["remaining"], 999)
            self.assertEqual(charge["response_remaining_header"], 999)
            self.assertEqual(charge["raw_receipt"], '{"resources":{"core":{"remaining":999}}}\n')
            self.assertIsNotNone(charge["response_observed_at"])

    def test_run_identity_refuses_different_source_or_branch(self):
        expected = {"fixture": {"commit": "a" * 40, "evidence_ref": "refs/heads/evidence/phase255-canary",
                                "workflow": CANARY.WORKFLOW}}
        run = {"id": 12, "run_attempt": 1, "head_sha": "a" * 40,
               "head_branch": "evidence/phase255-canary", "path": CANARY.WORKFLOW,
               "status": "in_progress", "conclusion": None, "display_title": "phase255"}
        self.assertEqual(CANARY.verify_run_identity(expected, run)["id"], 12)
        run["head_sha"] = "b" * 40
        with self.assertRaisesRegex(CANARY.CanaryError, "run_fixture_commit_mismatch"):
            CANARY.verify_run_identity(expected, run)

    def test_cancellation_requires_exact_owned_in_progress_run_and_readiness(self):
        expected = {"fixture": {"commit": "a" * 40, "evidence_ref": "refs/heads/evidence/phase255-canary",
                                "workflow": CANARY.WORKFLOW}}
        run = {"id": 12, "run_attempt": 1, "head_sha": "a" * 40,
               "head_branch": "evidence/phase255-canary", "path": CANARY.WORKFLOW,
               "status": "in_progress", "conclusion": None, "display_title": "phase255"}
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "FREEZE.json"
            CANARY.atomic_json(path, {"schema_version": CANARY.SCHEMA, "limits": dict(CANARY.HARD_LIMITS),
                "usage": {"invocations": 1, "controller_requests": 1, "pushes": 0,
                          "infrastructure_retries": 0, "test_retries": 0,
                          "elapsed_started_at": 1000, "charges": []}})
            with self.assertRaisesRegex(CANARY.CanaryError, "cancellation_readiness_not_verified"):
                CANARY.cancel_fixture_run(path, 12, expected, run, False)
            run["status"] = "completed"
            with self.assertRaisesRegex(CANARY.CanaryError, "cancellation_target_not_exact_owned_in_progress_run"):
                CANARY.cancel_fixture_run(path, 12, expected, run, True)

    def test_manifest_contains_only_explicit_files_and_records_absent_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "record.json").write_text('{"exit":0}\n')
            manifest = CANARY.write_manifest(root, root / "manifest.json", {
                "invocation_id": "invocation-01", "source_sha": "a" * 40, "run_id": "12",
                "run_attempt": "1", "job_id": "fixture-job", "seam": "success",
            }, ["record.json=report", "absent.log=command_stderr"])
            self.assertEqual([entry["path"] for entry in manifest["files"]], ["record.json"])
            self.assertEqual(manifest["missing_files"], ["absent.log"])
            symlink = root / "outside.log"
            try:
                symlink.symlink_to(root / "record.json")
            except OSError:
                self.skipTest("symlinks unavailable on this filesystem")
            with self.assertRaisesRegex(CANARY.CanaryError, "manifest_symlink_rejected"):
                CANARY.write_manifest(root, root / "rejected.json", {
                    "invocation_id": "invocation-02", "source_sha": "a" * 40, "run_id": "12",
                    "run_attempt": "1", "job_id": "fixture-job", "seam": "success",
                }, ["outside.log=report"])

    def test_shared_stager_and_verifier_accept_only_the_invocation_bound_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            base = pathlib.Path(directory)
            root = base / "invocation"
            root.mkdir()
            payload = b"synthetic failure command output\n"
            (root / "stdout.bin").write_bytes(payload)
            manifest_path = root / "manifest.json"
            CANARY.write_manifest(root, manifest_path, {
                "invocation_id": "invocation-01", "source_sha": "a" * 40, "run_id": "12",
                "run_attempt": "1", "job_id": "fixture-job", "seam": "success",
            }, ["stdout.bin=command_stdout"])
            bundle = base / "bundle.zip"
            helper = ROOT / "scripts/ci/ci-diagnostic-bundle.py"
            for mode in ("stage", "verify"):
                args = (["stage", "--invocation-root", str(root), "--manifest", str(manifest_path), "--output", str(bundle)]
                        if mode == "stage" else ["verify", "--bundle", str(bundle), "--manifest", str(manifest_path)])
                result = subprocess.run(["python3", "-B", str(helper), *args], cwd=ROOT,
                    check=False, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, f"{mode} failed: {result.stderr}")
            import zipfile
            with zipfile.ZipFile(bundle) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertEqual(metadata["source_sha"], "a" * 40)
                member = archive.read("stdout.bin")
                self.assertEqual(metadata["members"]["stdout.bin"]["sha256"], hashlib.sha256(member).hexdigest())
                self.assertEqual(metadata["members"]["stdout.bin"]["source_sha256"], hashlib.sha256(payload).hexdigest())
                self.assertNotEqual(member, payload, "command output is sanitized before retention")

    def test_retrieval_unwraps_github_artifact_and_verifies_inner_bundle(self):
        import zipfile
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            identity = {"source_sha": "a" * 40, "run_id": 12, "run_attempt": 1,
                "job_id": "fixture-job", "seam": "success", "invocation_id": "probe-1"}
            bundle_bytes = (root / "bundle.zip")
            with zipfile.ZipFile(bundle_bytes, "w") as bundle:
                member = b'{"scenario":"success"}\n'
                manifest = {"source_sha": identity["source_sha"], "run_id": identity["run_id"],
                    "run_attempt": identity["run_attempt"], "job_id": identity["job_id"],
                    "seam": identity["seam"], "invocation_id": identity["invocation_id"],
                    "members": {"scenario.json": {"sha256": hashlib.sha256(member).hexdigest()}}}
                bundle.writestr("bundle-manifest.json", json.dumps(manifest))
                bundle.writestr("scenario.json", member)
            outer_path = root / "github-artifact.zip"
            with zipfile.ZipFile(outer_path, "w") as outer:
                outer.write(bundle_bytes, "phase255-diagnostics.zip")
            outer_bytes = outer_path.read_bytes()
            original_download = CANARY.download_artifact
            def mocked_download(freeze_path, project_root, artifact_id, output):
                output.write_bytes(outer_bytes)
                return outer_bytes
            CANARY.download_artifact = mocked_download
            try:
                freeze_path = root / "FREEZE.json"
                CANARY.atomic_json(freeze_path, {"schema_version": CANARY.SCHEMA, "limits": dict(CANARY.HARD_LIMITS),
                    "usage": {"invocations": 0, "controller_requests": 0, "pushes": 0,
                        "infrastructure_retries": 0, "test_retries": 0, "elapsed_started_at": None, "charges": []}})
                target = root / "retrieved.zip"
                result = CANARY.retrieve_bundle(freeze_path, root, 42, target, identity)
                self.assertEqual(result["outer_sha256"], hashlib.sha256(outer_bytes).hexdigest())
                self.assertEqual(pathlib.Path(result["outer_path"]).read_bytes(), outer_bytes)
                self.assertEqual(result["bundle_sha256"], hashlib.sha256(bundle_bytes.read_bytes()).hexdigest())
                self.assertEqual(result["payload"], bundle_bytes.read_bytes())
            finally:
                CANARY.download_artifact = original_download

    def test_legacy_browser_report_members_are_directly_extractable_by_metrics_validator(self):
        import zipfile
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            archive = root / "legacy-browser-artifact.zip"
            members = {
                "reports/admin-behavior.json": b'{"complete":true,"tests":[]}\n',
                "reports/admin-behavior.selection.json": b'{"selected_count":1}\n',
            }
            with zipfile.ZipFile(archive, "w") as zipped:
                for name, payload in members.items():
                    zipped.writestr(name, payload)
            destination = root / "extracted"
            result = subprocess.run(["bash", str(ROOT / "scripts/ci/ci-run-metrics.sh"),
                "--extract-timing-zip", str(archive), "--output-dir", str(destination)],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            for name, payload in members.items():
                output = destination / pathlib.PurePosixPath(name)
                if pathlib.PurePosixPath(name).name == "admin-behavior.json":
                    output = destination / "admin-behavior.json"
                self.assertEqual(output.read_bytes(), payload)

    def test_terminal_verifier_requires_real_outcomes_and_literal_partial_files(self):
        freeze = {"source_identity": {"source_sha": "a" * 40},
            "fixture": {"commit": "d" * 40},
            "limits": dict(CANARY.HARD_LIMITS), "usage": {
            "invocations": 3, "controller_requests": 12, "pushes": 1,
            "infrastructure_retries": 0, "test_retries": 0,
        }}
        scenarios = {}
        for name, conclusion in (("success", "success"), ("failure", "failure"), ("cancellation", "cancelled")):
            scenarios[name] = {"actual_conclusion": conclusion, "run_id": 100 + len(scenarios),
                "run_attempt": 1, "source_sha": "a" * 40, "fixture_commit": "d" * 40,
                "job_id": "diagnostic-fixture", "seam": name, "invocation_id": f"probe-{name}",
                "artifacts": [{"sha256": "b" * 64, "github_archive_sha256": "e" * 64,
                    "members": {"scenario.json": "c" * 64}}],
                "partial_capture": {"state": "partial", "readiness_verified": True,
                    "missing_files": ["final-output.log", "final-trace.zip"]} if name == "cancellation" else None}
        result = {"scenarios": scenarios}
        self.assertEqual(CANARY.verify_terminal_results(freeze, result)["status"], "verified")
        scenarios["cancellation"]["partial_capture"]["missing_files"] = []
        with self.assertRaisesRegex(CANARY.CanaryError, "cancellation_missing_files_not_preserved"):
            CANARY.verify_terminal_results(freeze, result)


if __name__ == "__main__":
    unittest.main(verbosity=2)
