#!/usr/bin/env python3
"""Adversarial contracts for the saved CI evidence trust boundaries."""

import hashlib
import json
import pathlib
import tempfile
import unittest
import zipfile

from ci_metrics_security import (
    CoreRequestBudget,
    safe_markdown_url,
    sanitize_failure_log,
    validate_check_bindings,
    validate_comparison_reservations,
    validate_producer_binding,
    validate_producer_commit,
    verify_snapshot_hashes,
    verified_zip_members,
)


class SecurityContractsTest(unittest.TestCase):
    def test_snapshot_hashes_cover_manual_release_and_family_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "request-ledger.json").write_text("{}")
            (root / "selection-ledger.json").write_text("{}")
            raw = root / "raw"
            (raw / "populations").mkdir(parents=True)
            (raw / "families" / "42").mkdir(parents=True)
            files = {}
            for name in ("pull_request", "push_main", "schedule", "manual", "release_push"):
                path = raw / "populations" / f"{name}.json"
                path.write_text(json.dumps({"runs": []}))
                files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
            family = raw / "families" / "42"
            run = family / "run.json"
            run.write_text('{"id":42}')
            attempt = family / "jobs-attempt-1.json"
            attempt.write_text('{"jobs":[]}')
            (family / "manifest.json").write_text(json.dumps({
                "run_id": 42,
                "source_run_sha256": hashlib.sha256(run.read_bytes()).hexdigest(),
                "attempt_jobs": {"1": {"path": "raw/families/42/jobs-attempt-1.json", "sha256": hashlib.sha256(attempt.read_bytes()).hexdigest()}},
            }))
            manifest = {
                "source_sha256": {
                    "request_ledger": hashlib.sha256((root / "request-ledger.json").read_bytes()).hexdigest(),
                    "selection_ledger": hashlib.sha256((root / "selection-ledger.json").read_bytes()).hexdigest(),
                    **files,
                },
                "populations": {name: {"runs": []} for name in files},
            }
            (root / "manifest.json").write_text(json.dumps(manifest))
            self.assertEqual([], verify_snapshot_hashes(root))
            release = raw / "populations" / "release_push.json"
            release.write_text('{"runs":[{"id":99}]}')
            self.assertIn("snapshot_hash_mismatch:release_push", verify_snapshot_hashes(root))

    def test_check_runs_are_bound_to_exact_run_attempt_job_and_head(self):
        run = {"id": 7, "head_sha": "a" * 40, "event": "pull_request", "run_attempt": 2}
        jobs = [{"id": 88, "run_id": 7, "run_attempt": 2, "head_sha": "a" * 40,
                 "name": "Library tests", "conclusion": "success",
                 "check_run_url": "https://api.github.com/repos/szTheory/sigra/check-runs/88"}]
        checks = [{"id": 88, "name": "Library tests", "head_sha": "a" * 40,
                   "status": "completed", "conclusion": "success",
                   "app": {"slug": "github-actions"}, "check_suite": {"id": 9}}]
        self.assertEqual([], validate_check_bindings(run, 2, jobs, checks, ["Library tests"]))
        wrong_attempt = [dict(jobs[0], run_attempt=1)]
        self.assertIn("required_check_job_binding_invalid:Library tests",
                      validate_check_bindings(run, 2, wrong_attempt, checks, ["Library tests"]))
        wrong_check = [dict(checks[0], id=99)]
        self.assertIn("required_check_job_binding_invalid:Library tests",
                      validate_check_bindings(run, 2, jobs, wrong_check, ["Library tests"]))

    def test_artifact_member_bytes_are_read_from_verified_zip(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "artifact.zip"
            payload = b'{"complete":true}'
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("report.json", payload)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            member_hash = hashlib.sha256(payload).hexdigest()
            self.assertEqual({"report.json": payload}, verified_zip_members(path, digest, {"report.json": member_hash}))
            self.assertIn("artifact_member_hash_mismatch:report.json",
                          verified_zip_members(path, digest, {"report.json": "0" * 64}))

    def test_producer_requires_independent_job_upload_artifact_and_source_commit(self):
        run = {"id": 7, "head_sha": "a" * 40, "run_attempt": 1, "event": "pull_request",
               "pull_requests": [{"number": 3, "head": {"sha": "a" * 40}, "base": {"sha": "b" * 40}}]}
        job = {"id": 88, "run_id": 7, "run_attempt": 1, "name": "Library tests shard", "conclusion": "success",
               "steps": [{"name": "Upload library test timing", "conclusion": "success",
                          "started_at": "2026-10-12T10:00:00Z", "completed_at": "2026-10-12T10:00:10Z"}]}
        artifact = {"id": 101, "name": "library-test-timing-7-1", "created_at": "2026-10-12T10:00:05Z",
                    "workflow_run": {"id": 7, "head_sha": "a" * 40}}
        metadata = {"repository": "szTheory/sigra", "run_id": "7", "run_attempt": "1", "event": "pull_request",
                    "job_name": "Library tests shard", "source_sha": "c" * 40,
                    "timing_artifact_name": "library-test-timing-7-1"}
        self.assertEqual([], validate_producer_binding(run, job, artifact, metadata, "Library tests shard"))
        altered = dict(artifact, name="library-test-timing-8-1")
        self.assertTrue(validate_producer_binding(run, job, altered, metadata, "Library tests shard"))
        commit = {"sha": "c" * 40, "parents": [{"sha": "b" * 40}, {"sha": "a" * 40}]}
        self.assertEqual([], validate_producer_commit(metadata["source_sha"], commit, run))
        self.assertTrue(validate_producer_commit(metadata["source_sha"], {"sha": "c" * 40, "parents": [{"sha": "x" * 40}]}, run))

    def test_log_redaction_is_bounded_and_excludes_environment_dumps(self):
        raw = (b"assertion failed: useful diagnosis\nGITHUB_TOKEN=ghp_" + b"a" * 40 + b"\n"
               b"AWS_SECRET_ACCESS_KEY=secret-value\nurl=https://example.invalid/x?sig=secret\n"
               + b"ordinary log line\n" * 10000)
        result = sanitize_failure_log(raw, max_input_bytes=65536, max_output_bytes=2048)
        self.assertLessEqual(len(result["text"].encode()), 2048)
        self.assertIn("assertion failed", result["text"])
        for secret in ("ghp_", "secret-value", "sig=secret", "example.invalid"):
            self.assertNotIn(secret, result["text"])
        self.assertTrue(result["truncated"])
        self.assertIn("[ENVIRONMENT", result["text"])

    def test_markdown_links_allow_only_canonical_repository_urls(self):
        self.assertEqual("https://github.com/szTheory/sigra/actions/runs/123", safe_markdown_url("https://github.com/szTheory/sigra/actions/runs/123"))
        self.assertIsNone(safe_markdown_url("https://attacker.invalid/[x](https://evil.invalid)"))
        self.assertIsNone(safe_markdown_url("https://github.com/szTheory/sigra/actions/runs/123?token=secret"))

    def test_core_budget_decrements_on_each_attempt_from_251(self):
        budget = CoreRequestBudget(remaining=251)
        self.assertTrue(budget.reserve())
        self.assertFalse(budget.reserve())
        self.assertEqual(250, budget.remaining)
        budget.refresh(900)
        self.assertTrue(budget.reserve())
        budget.refresh(250)
        self.assertFalse(budget.reserve())

    def test_comparison_family_registration_binds_run_and_window(self):
        contract = {"window": {"start_utc": "2026-10-12T10:00:00Z", "end_utc": "2026-10-14T10:00:00Z"},
                    "family_reservations": [{"pair_id": "p1", "family_role": "before", "run_id": 7,
                                             "created_at": "2026-10-13T00:00:00Z"}]}
        self.assertEqual([], validate_comparison_reservations(contract, contract["family_reservations"]))
        replacement = [dict(contract["family_reservations"][0], run_id=8)]
        self.assertTrue(validate_comparison_reservations(contract, replacement))
        out_of_window = [dict(contract["family_reservations"][0], created_at="2026-10-15T00:00:00Z")]
        self.assertTrue(validate_comparison_reservations(contract, out_of_window))


if __name__ == "__main__":
    unittest.main()
