#!/usr/bin/env python3
"""Regression fixtures for repaired-control PR timing and physical costs."""

import unittest
import hashlib
import json
import pathlib
import subprocess
import tempfile

from ci_metrics_security import (
    deduplicate_physical_jobs,
    derive_attempt_job_costs,
    derive_required_result_wait,
    validate_repaired_control_metadata,
)


def job(job_id, attempt, start, end, name="required", run_id=101):
    return {
        "id": job_id, "run_id": run_id, "run_attempt": attempt,
        "head_sha": "a" * 40, "name": name, "status": "completed",
        "conclusion": "success", "started_at": start, "completed_at": end,
    }


def check(check_id, name, job_id, head="a" * 40, conclusion="success", completed="2026-10-24T00:20:00Z"):
    return {
        "id": check_id, "external_id": str(job_id), "name": name, "head_sha": head,
        "app": {"slug": "github-actions"}, "check_suite": {"id": check_id},
        "status": "completed", "conclusion": conclusion, "completed_at": completed,
    }


class RepairedTimingTest(unittest.TestCase):
    def test_independent_verifier_rejects_wrong_merge_workflow_app_and_job(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        required = ["Library tests", "Example unit smoke (ExUnit + ConnTest)",
                    "Install smoke (fresh phx.new + sigra.install)",
                    "Example HTTP smoke (boot + curl critical routes)",
                    "Example Playwright smoke (full lifecycle)"]
        def digest(path):
            return hashlib.sha256(path.read_bytes()).hexdigest()
        for mutation in ("merge", "workflow", "app", "job"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                root_dir = pathlib.Path(temp)
                bundle = root_dir / "bundle"
                family = bundle / "raw" / "families" / "301"
                family.mkdir(parents=True)
                sha = "a" * 40
                pr = {"number": 331, "head": {"sha": sha, "repo": {"id": 1207487684}},
                      "base": {"sha": "b" * 40, "repo": {"id": 1207487684}},
                      "merge_commit_sha": "wrong-merge" if mutation == "merge" else "merge-sha"}
                run = {"id": 301, "event": "pull_request", "path": ".github/workflows/other.yml" if mutation == "workflow" else ".github/workflows/ci.yml",
                    "head_sha": sha, "created_at": "2026-10-24T00:00:00Z", "run_attempt": 1,
                    "repository": {"id": 1207487684, "full_name": "szTheory/sigra"}, "pull_requests": [pr]}
                run_path = family / "run.json"
                run_path.write_text(json.dumps(run, sort_keys=True))
                jobs = []
                checks = []
                for index, name in enumerate(required):
                    jid = 3100 + index
                    jobs.append({"id": jid, "run_id": 301, "run_attempt": 1, "head_sha": sha,
                        "name": name, "conclusion": "success", "started_at": "2026-10-24T00:01:00Z",
                        "completed_at": "2026-10-24T00:02:00Z"})
                    checks.append({"id": jid + 1000, "external_id": str(jid + 1 if mutation == "job" and index == 0 else jid),
                        "name": name, "head_sha": sha, "status": "completed", "conclusion": "success",
                        "completed_at": "2026-10-24T00:02:00Z",
                        "app": {"slug": "other-app" if mutation == "app" and index == 0 else "github-actions"},
                        "check_suite": {"id": 3200 + index}})
                jobs_path = family / "jobs-attempt-1.json"
                jobs_path.write_text(json.dumps({"total_count": len(jobs), "jobs": jobs}, sort_keys=True))
                checks_path = family / "check-runs.json"
                checks_path.write_text(json.dumps({"check_runs": checks}, sort_keys=True))
                (bundle / "raw" / "families" / "301" / "manifest.json").write_text(json.dumps({
                    "schema_version": "sigra.ci-run-metrics/family-detail-v1", "detail_status": "complete",
                    "run_id": 301, "source_run_sha256": digest(run_path), "check_runs_sha256": digest(checks_path),
                    "attempt_jobs": {"1": {"path": "raw/families/301/jobs-attempt-1.json", "sha256": digest(jobs_path)}}}))
                registration = {"comparison_kind": "repaired_control_pr", "family_role": "before", "run_id": 301, "event": "pull_request",
                    "workflow_path": ".github/workflows/ci.yml", "head_sha": sha, "created_at": run["created_at"],
                    "pull_request_number": 331, "pull_request_head_sha": sha, "pull_request_base_sha": "b" * 40,
                    "pull_request_merge_sha": "merge-sha"}
                registration_path = root_dir / "registration.json"
                registration_path.write_text(json.dumps(registration))
                result = subprocess.run(["python3", "-B", str(root / "scripts/ci/ci-hosted-gate-verify.py"),
                    "--mode", "comparison-family", "--evidence", str(bundle), "--registration", str(registration_path),
                    "--required-contexts", json.dumps(required)], cwd=root, capture_output=True, text=True, timeout=30)
                self.assertNotEqual(0, result.returncode)
                expected = {"merge": "pull request merge tree differs", "workflow": "collected run origin differs",
                    "app": "required check to job binding failed", "job": "required check to job binding failed"}[mutation]
                self.assertIn(expected, result.stderr + result.stdout)

    def test_real_evaluator_cli_keeps_single_family_insufficient_data(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        required = ["Library tests", "Example unit smoke (ExUnit + ConnTest)",
                    "Install smoke (fresh phx.new + sigra.install)",
                    "Example HTTP smoke (boot + curl critical routes)",
                    "Example Playwright smoke (full lifecycle)"]
        def digest(path):
            return hashlib.sha256(path.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as temp:
            temp = pathlib.Path(temp)
            source_bundle = temp / "baseline-source.tar"
            source_bundle.write_bytes(b"baseline source fixture")
            bundles = {}
            for side, app_sha, role in (("before", "a" * 40, "before"), ("after", "b" * 40, "after")):
                bundle = temp / side
                raw = bundle / "raw"
                pops = raw / "populations"
                pops.mkdir(parents=True)
                (bundle / "selection-ledger.json").write_text(json.dumps({"populations": []}))
                hashes = {"selection_ledger": digest(bundle / "selection-ledger.json")}
                population_runs = []
                for name in ("pull_request", "push_main", "schedule", "manual", "release_push"):
                    path = pops / (name + ".json")
                    path.write_text(json.dumps({"population": name, "api_total_count": 0,
                        "population_capped": False, "population_exhausted": True, "runs": [], "pages": []}))
                    hashes[name] = digest(path)
                for filename, key, payload in (("rate-limit.json", "rate_limit", {}),
                    ("effective-rules.json", "effective_rules", []),
                    ("branch-protection.json", "branch_protection", {"status": "not_configured"}),
                    ("rulesets.json", "rulesets", [])):
                    path = raw / filename
                    path.write_text(json.dumps(payload))
                    hashes[key] = digest(path)
                (bundle / "request-ledger.json").write_text(json.dumps({"requests": []}))
                hashes["request_ledger"] = digest(bundle / "request-ledger.json")
                family = {"pair_id": "pair-01", "family_role": role, "run_id": 101 if side == "before" else 201,
                    "created_at": "2026-10-13T00:00:00Z", "conclusion": "success", "workload": "full",
                    "workload_sha": "e" * 64, "runner_class": {"all": "linux-x64"},
                    "runner_image": {"all": "ubuntu24-20261020.1.0"}, "cache_stratum": "warm",
                    "exunit_instrumentation": "exunit-v1", "playwright_instrumentation": "pw-v1",
                    "required_result_wait_seconds": 1200 if side == "before" else 800, "runner_seconds": 900}
                family["cache_key_scope"] = {owner: {"deps": {"matched_cache_key": "key-linux-abc",
                    "scope": "refs/pull/331/merge", "ref": "refs/pull/331/merge", "exact_key": True,
                    "cache_hit": True, "conditions": ["Linux", "X64"]}} for owner in
                    ("library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")}
                raw_family = raw / "families" / str(family["run_id"])
                raw_family.mkdir(parents=True)
                created = "2026-10-13T00:00:00Z"
                run_doc = {"id": family["run_id"], "head_sha": app_sha, "created_at": created,
                    "updated_at": created, "event": "pull_request", "path": ".github/workflows/ci.yml",
                    "run_attempt": 2, "conclusion": "success", "repository": {"id": 1207487684},
                    "pull_requests": [{"number": 331, "head": {"sha": app_sha}, "base": {"sha": "f" * 40}, "merge_commit_sha": "merge-tree"}]}
                run_path = raw_family / "run.json"
                run_path.write_text(json.dumps(run_doc, sort_keys=True))
                attempt_refs = {}
                attempt_jobs = {}
                for attempt in (1, 2):
                    rows = []
                    if attempt == 1:
                        rows.append(job(1000 + family["run_id"], 1, created, "2026-10-13T00:04:00Z", "Library tests", family["run_id"]))
                        rows[0]["conclusion"] = "failure"
                    else:
                        endpoint_seconds = 1200 if side == "before" else 800
                        endpoint = f"2026-10-13T00:{endpoint_seconds // 60:02d}:00Z"
                        for index, context in enumerate(required):
                            jid = family["run_id"] * 100 + index + 1
                            rows.append(job(jid, 2, "2026-10-13T00:19:00Z" if side == "before" else "2026-10-13T00:12:00Z", endpoint, context, family["run_id"]))
                        rows.append(job(family["run_id"] * 100 + 99, 2, endpoint, "2026-10-13T00:25:00Z", "post-check diagnostics", family["run_id"]))
                    for row in rows:
                        row["head_sha"] = app_sha
                    attempt_jobs[str(attempt)] = rows
                    attempt_path = raw_family / f"jobs-attempt-{attempt}.json"
                    attempt_path.write_text(json.dumps({"jobs": rows}, sort_keys=True))
                    attempt_refs[str(attempt)] = {"path": f"raw/families/{family['run_id']}/jobs-attempt-{attempt}.json",
                        "sha256": digest(attempt_path), "endpoint": f"/repos/szTheory/sigra/actions/runs/{family['run_id']}/attempts/{attempt}/jobs?per_page=100"}
                checks = []
                for index, context in enumerate(required):
                    jid = family["run_id"] * 100 + index + 1
                    checks.append({"id": jid + 10000, "external_id": str(jid), "name": context,
                        "head_sha": app_sha, "status": "completed", "conclusion": "success",
                        "completed_at": "2026-10-13T00:20:00Z" if side == "before" else "2026-10-13T00:13:20Z",
                        "app": {"slug": "github-actions"}, "check_suite": {"id": jid + 20000}})
                checks.append({"id": 9001, "external_id": str(1000 + family["run_id"]), "name": "Library tests",
                    "head_sha": app_sha, "status": "completed", "conclusion": "failure",
                    "completed_at": "2026-10-13T00:04:00Z", "app": {"slug": "github-actions"}, "check_suite": {"id": 9002}})
                checks_path = raw_family / "check-runs.json"
                checks_path.write_text(json.dumps({"check_runs": checks}, sort_keys=True))
                detail = {"run_id": family["run_id"], "detail_status": "complete",
                    "source_run_sha256": digest(run_path), "attempt_jobs": attempt_refs,
                    "check_runs_sha256": digest(checks_path)}
                (raw_family / "manifest.json").write_text(json.dumps(detail, sort_keys=True))
                source_run = {**run_doc, "detail_status": "complete", "workload": "full",
                    "attempt_jobs": attempt_refs}
                population_runs.append(source_run)
                identity = {"application_sha": app_sha, "workflow_revision": app_sha,
                    "workflow_file_sha256": "c" * 64, "workload_revision_sha256": "e" * 64}
                manifest = {"schema_version": "sigra.ci-run-metrics/snapshot-v1", "repository": "szTheory/sigra",
                    "workflow": "ci.yml", "status": "complete", "cutoff_utc": "2026-10-14T00:00:00Z",
                    "captured_at_utc": "2026-10-14T00:01:00Z", "window_start_utc": "2026-10-12T00:00:00Z",
                    "request_count": 0, "source_sha": app_sha, "workflow_sha256": "c" * 64,
                    "workflow_blob_sha": "blob-c", "measured_pr_identity": identity,
                    "required_contexts": required, "required_rule_provenance": [], "active_rulesets": [],
                    "source_file_sha256": {}, "source_sha256": hashes,
                    "populations": {"pull_request": {"api_total_count": len(population_runs), "population_capped": False,
                        "population_exhausted": True, "runs": population_runs}, "push_main": {"api_total_count": 0,
                        "population_capped": False, "population_exhausted": True, "runs": []},
                        "schedule": {"api_total_count": 0, "population_capped": False,
                        "population_exhausted": True, "runs": []}, "manual": {"records": []}, "release_push": {"records": []}},
                    "comparison_families": [family]}
                population_path = pops / "pull_request.json"
                population_path.write_text(json.dumps({"population": "pull_request", "api_total_count": len(population_runs),
                    "population_capped": False, "population_exhausted": True, "runs": population_runs, "pages": []}))
                hashes["pull_request"] = digest(population_path)
                request_rows = [ref["endpoint"] for ref in attempt_refs.values()]
                ledger_path = bundle / "request-ledger.json"
                ledger_path.write_text(json.dumps({"requests": request_rows}))
                hashes["request_ledger"] = digest(ledger_path)
                (bundle / "manifest.json").write_text(json.dumps(manifest))
                bundles[side] = bundle
            contract = {"comparison_kind": "repaired_control_pr", "status": "ready", "pair_count": 20,
                "primary_family_count": 40, "window_duration_hours": 48,
                "required_contexts": required,
                "comparison_schedule": [{"pair_id": "pair-01", "family_role": "before"},
                    {"pair_id": "pair-01", "family_role": "after"}],
                "baseline_identity": {"source_bundle_sha256": digest(source_bundle),
                    "workload_revision_sha256": "e" * 64}, "baseline_application_sha": "a" * 40,
                "baseline_workload_revision_sha256": "e" * 64, "baseline_workflow_sha256": "c" * 64,
                "candidate_identity": {"application_sha": "b" * 40, "workflow_revision": "b" * 40,
                    "workload_revision_sha256": "e" * 64, "workflow_file_sha256": "c" * 64},
                "window": {"start_utc": "2026-10-12T00:00:00Z", "end_utc": "2026-10-14T00:00:00Z"},
                "cache_stratum_allocation": [{"stratum_id": "warm", "pair_count": 20}]}
            contract_path = temp / "contract.json"
            contract_path.write_text(json.dumps(contract))
            result = subprocess.run(["bash", str(root / "scripts/ci/ci-run-metrics.sh"),
                "--evaluate-comparison", "--contract", str(contract_path),
                "--before-bundle", str(bundles["before"]), "--after-bundle", str(bundles["after"]),
                "--baseline-source-bundle", str(source_bundle)], cwd=root, capture_output=True, text=True, timeout=60)
            self.assertEqual(0, result.returncode, result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual("insufficient_data", report["status"])
            self.assertEqual(1, report["metrics"]["comparable_successful_pairs"])
            self.assertEqual(1200, report["metrics"]["baseline_median_seconds"])
            self.assertEqual(800, report["metrics"]["candidate_median_seconds"])
            self.assertEqual(840, report["metrics"]["family_attempt_costs"][0]["runner_seconds"])
    def test_wait_starts_at_original_run_creation_and_ends_at_retry_success(self):
        run = {"id": 101, "head_sha": "a" * 40, "created_at": "2026-10-24T00:00:00Z", "repository": {"id": 1207487684}}
        jobs = {"1": [job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z")],
                "2": [job(21, 2, "2026-10-24T00:15:00Z", "2026-10-24T00:20:00Z")]}
        checks = [check(11, "required", 11, conclusion="failure", completed="2026-10-24T00:05:00Z"),
                  check(21, "required", 21, completed="2026-10-24T00:20:00Z")]
        result = derive_required_result_wait(run, jobs, checks, ["required"])
        self.assertEqual(1200, result["seconds"])
        self.assertEqual([], result["diagnostics"])
        self.assertEqual(21, result["bound_required_jobs"]["required"]["job_id"])
        self.assertEqual("2026-10-24T00:20:00Z", result["required_result_completed_at"])

    def test_later_failed_same_name_check_cannot_be_hidden_by_old_success(self):
        run = {"id": 101, "head_sha": "a" * 40, "created_at": "2026-10-24T00:00:00Z", "repository": {"id": 1207487684}}
        jobs = {"1": [job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z")],
                "2": [job(21, 2, "2026-10-24T00:15:00Z", "2026-10-24T00:20:00Z")]}
        checks = [check(11, "required", 11, completed="2026-10-24T00:05:00Z"),
                  check(21, "required", 21, conclusion="failure", completed="2026-10-24T00:20:00Z")]
        result = derive_required_result_wait(run, jobs, checks, ["required"])
        self.assertIsNone(result["seconds"])
        self.assertTrue(result["diagnostics"])

    def test_repeated_physical_job_is_counted_once_across_attempts(self):
        repeated = job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z")
        repeated_again = {**repeated, "run_attempt": 2}
        costs = derive_attempt_job_costs({"1": [repeated], "2": [repeated_again]})
        self.assertEqual(240, costs["total_seconds"])
        self.assertEqual([], costs["unknown_jobs"])

    def test_conflicting_repeated_physical_job_invalidates_total(self):
        first = job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z")
        conflicting = {**first, "run_attempt": 2, "completed_at": "2026-10-24T00:06:00Z"}
        costs = derive_attempt_job_costs({"1": [first], "2": [conflicting]})
        self.assertIsNone(costs["total_seconds"])
        self.assertTrue(costs["unknown_jobs"])

    def test_missing_duration_invalidates_total(self):
        costs = derive_attempt_job_costs({"1": [{"id": 11, "status": "completed", "conclusion": "failure"}]})
        self.assertIsNone(costs["total_seconds"])
        self.assertTrue(costs["unknown_jobs"])

    def test_failed_cancelled_and_post_endpoint_jobs_still_cost_runner_time(self):
        costs = derive_attempt_job_costs({"1": [
            job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z"),
            {**job(12, 1, "2026-10-24T00:05:00Z", "2026-10-24T00:08:00Z"), "conclusion": "failure"},
            {**job(13, 1, "2026-10-24T00:21:00Z", "2026-10-24T00:26:00Z"), "conclusion": "cancelled"},
        ]})
        self.assertEqual(720, costs["total_seconds"])

    def test_deduplicate_physical_jobs_surfaces_inconsistent_repeat(self):
        first = job(11, 1, "2026-10-24T00:01:00Z", "2026-10-24T00:05:00Z")
        conflict = {**first, "run_attempt": 2, "completed_at": "2026-10-24T00:06:00Z"}
        counted, history = deduplicate_physical_jobs({"1": [first], "2": [conflict]})
        self.assertEqual(1, len(counted))
        self.assertTrue(any(row.get("conflict") for row in history))

    def test_exact_cache_and_native_identity_required_for_all_six_owners(self):
        owners = ["library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"]
        metadata = []
        for owner in owners:
            metadata.append({
                "job_name": "Library tests shard" if owner == "library" else "Example Playwright shard",
                "matrix_seam": None if owner == "library" else owner,
                "runner_os": "Linux", "runner_arch": "X64",
                "runner_image": {"image_os": "ubuntu24", "image_version": "20261020.1.0"},
                "cache_outcome": {"dependencies": {"cache_hit": True, "exact_key": True,
                    "matched_cache_key": "deps-linux-abc", "scope": "refs/pull/1/merge", "ref": "refs/pull/1/merge", "conditions": ["Linux", "X64"]}},
            })
        self.assertEqual([], validate_repaired_control_metadata(metadata))
        self.assertEqual([], validate_repaired_control_metadata(metadata, expected_ref="refs/pull/1/merge"))
        self.assertIn("repaired_cache_ref_scope_mismatch:admin_behavior:dependencies",
            validate_repaired_control_metadata(metadata, expected_ref="refs/heads/main"))
        metadata[2]["cache_outcome"]["dependencies"]["exact_key"] = False
        self.assertIn("repaired_cache_not_exact_hit:admin_checkpoints:dependencies", validate_repaired_control_metadata(metadata))

    def test_unknown_or_missing_native_owner_image_is_rejected(self):
        self.assertIn("repaired_metadata_owner_set_incomplete", validate_repaired_control_metadata([]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
