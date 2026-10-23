#!/usr/bin/env python3
"""Adversarial contracts for the saved CI evidence trust boundaries."""

import hashlib
import base64
import json
import pathlib
import tempfile
import unittest
import zipfile

from ci_metrics_security import (
    CoreRequestBudget,
    bind_required_checks_by_attempt,
    deduplicate_physical_jobs,
    safe_markdown_url,
    register_comparison_run,
    sanitize_failure_log,
    validate_check_bindings,
    validate_comparison_reservations,
    validate_comparison_plan,
    validate_comparison_schedule,
    validate_producer_binding,
    validate_producer_commit,
    validate_general_job_identity,
    validate_workflow_source,
    verified_failure_log,
    verify_snapshot_hashes,
    verified_zip_members,
)


class SecurityContractsTest(unittest.TestCase):
    def test_comparison_plan_freezes_balanced_order_and_rejects_tied_pair_starts(self):
        schedule=[]; reservations=[]
        for pair in range(1,21):
            roles=("before","after") if pair % 2 else ("after","before")
            for role in roles:
                pair_id=f"pair-{pair:02d}"
                schedule.append({"pair_id":pair_id,"family_role":role})
                reservations.append({"reservation_id":f"r-{pair_id}-{role}","pair_id":pair_id,"family_role":role})
        contract={"status":"ready","pair_count":20,"primary_family_count":40,"comparison_schedule":schedule,
                  "family_reservations":reservations,"maximum_pair_start_gap_seconds":1800,
                  "preparation_compatibility":{"baseline_cache_stratum":"warm","candidate_cache_stratum":"warm","runner_image_policy":"same"},
                  "candidate_identity":{"application_sha":"a","workflow_revision":"b","workload_revision_sha256":"c","workflow_file_sha256":"d"},
                  "window":{"start_utc":"2026-10-12T00:00:00Z","end_utc":"2026-10-14T00:00:00Z"}}
        self.assertEqual([],validate_comparison_plan(contract))
        rows=[{"reservation_id":reservations[i]["reservation_id"],"pair_id":reservations[i]["pair_id"],
               "family_role":reservations[i]["family_role"],"created_at":"2026-10-13T00:00:00Z"} for i in range(2)]
        self.assertIn("comparison_pair_start_not_ordered",validate_comparison_schedule(contract,rows))

    def test_snapshot_hashes_cover_manual_release_and_family_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "request-ledger.json").write_text(json.dumps({"requests": [
                "/repos/szTheory/sigra/actions/runs/42/attempts/1/jobs?per_page=100",
                "/repos/szTheory/sigra/pulls/331/files?per_page=100&page=1",
            ]}))
            (root / "selection-ledger.json").write_text("{}")
            raw = root / "raw"
            (raw / "populations").mkdir(parents=True)
            (raw / "families" / "42").mkdir(parents=True)
            files = {}
            run_object={"id":42,"head_sha":"a"*40,"event":"pull_request","path":".github/workflows/ci.yml","run_attempt":1,"created_at":"2026-10-12T00:00:00Z","repository":{"id":1207487684},"pull_requests":[{"number":331,"head":{"repo":{"id":1207487684}},"base":{"repo":{"id":1207487684}}}]}
            for name in ("pull_request", "push_main", "schedule", "manual", "release_push"):
                path = raw / "populations" / f"{name}.json"
                path.write_text(json.dumps({"runs": [run_object] if name == "pull_request" else []}))
                files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
            for name, value in (("rate-limit.json", {}), ("effective-rules.json", []),
                                ("branch-protection.json", {}), ("rulesets.json", [])):
                path = raw / name
                path.write_text(json.dumps(value))
                files[name[:-5].replace("-", "_")] = hashlib.sha256(path.read_bytes()).hexdigest()
            family = raw / "families" / "42"
            run = family / "run.json"
            run.write_text(json.dumps(run_object))
            attempt = family / "jobs-attempt-1.json"
            attempt.write_text('{"jobs":[]}')
            changed = family / "changed-paths-page-1.json"
            changed.write_text('[{"filename":"lib/a.ex"}]')
            (family / "manifest.json").write_text(json.dumps({
                "run_id": 42,
                "source_run_sha256": hashlib.sha256(run.read_bytes()).hexdigest(),
                "changed_path_pages": [{"page": 1, "path": "raw/families/42/changed-paths-page-1.json", "sha256": hashlib.sha256(changed.read_bytes()).hexdigest()}],
                "attempt_jobs": {"1": {"path": "raw/families/42/jobs-attempt-1.json", "sha256": hashlib.sha256(attempt.read_bytes()).hexdigest()}},
            }))
            manifest = {
                "source_sha256": {
                    "request_ledger": hashlib.sha256((root / "request-ledger.json").read_bytes()).hexdigest(),
                    "selection_ledger": hashlib.sha256((root / "selection-ledger.json").read_bytes()).hexdigest(),
                    **files,
                },
                "repository": "szTheory/sigra",
                "populations": {name: {"runs": [run_object] if name == "pull_request" else []} for name in files},
            }
            (root / "manifest.json").write_text(json.dumps(manifest))
            self.assertEqual([], verify_snapshot_hashes(root))
            facts_path = raw / "families" / "42" / "manifest.json"
            facts = json.loads(facts_path.read_text()); facts.pop("changed_path_pages")
            facts_path.write_text(json.dumps(facts))
            self.assertIn("changed_path_page_hash_reference_set_mismatch:42", verify_snapshot_hashes(root))
            release = raw / "populations" / "release_push.json"
            release.write_text('{"runs":[{"id":99}]}')
            self.assertIn("snapshot_hash_mismatch:release_push", verify_snapshot_hashes(root))

    def test_check_runs_are_bound_to_exact_run_attempt_job_and_head(self):
        run = {"id": 7, "head_sha": "a" * 40, "event": "pull_request", "run_attempt": 2,
               "pull_requests": [{"head": {"repo": {"id": 1207487684}}}]}
        jobs = [{"id": 88, "run_id": 7, "run_attempt": 2, "head_sha": "a" * 40,
                 "name": "Library tests", "conclusion": "success",
                 "check_run_url": "https://api.github.com/repos/szTheory/sigra/check-runs/88"}]
        checks = [{"id": 88, "external_id": "88", "name": "Library tests", "head_sha": "a" * 40,
                   "status": "completed", "conclusion": "success",
                   "app": {"slug": "github-actions"}, "check_suite": {"id": 9}}]
        self.assertEqual([], validate_check_bindings(run, 2, jobs, checks, ["Library tests"]))
        wrong_attempt = [dict(jobs[0], run_attempt=1)]
        self.assertTrue(validate_check_bindings(run, 2, wrong_attempt, checks, ["Library tests"]))
        wrong_check = [dict(checks[0], id=99, external_id="99")]
        self.assertIn("required_check_job_binding_invalid:Library tests",
                      validate_check_bindings(run, 2, jobs, wrong_check, ["Library tests"]))
        wrong_repo = [dict(jobs[0], source_repository="attacker/repo", source_repository_id=9)]
        self.assertTrue(validate_check_bindings(run, 2, wrong_repo, checks, ["Library tests"]))

    def test_required_check_binding_rejects_foreign_duplicates_before_selecting_latest_attempt(self):
        run = {"id": 7, "head_sha": "a" * 40, "run_attempt": 2, "repository": {"id": 1207487684}}
        first = {"id": 88, "run_id": 7, "run_attempt": 1, "head_sha": "a" * 40, "name": "Library tests",
                 "started_at": "2026-10-12T00:00:00Z", "completed_at": "2026-10-12T00:00:20Z"}
        latest = {"id": 99, "run_id": 7, "run_attempt": 2, "head_sha": "a" * 40, "name": "Library tests",
                  "started_at": "2026-10-12T00:01:00Z", "completed_at": "2026-10-12T00:01:30Z"}
        def check(job, check_id):
            return {"id": check_id, "external_id": str(job["id"]), "name": job["name"], "head_sha": "a" * 40,
                    "status": "completed", "conclusion": "success", "started_at": job["started_at"],
                    "completed_at": job["completed_at"], "app": {"slug": "github-actions"}, "check_suite": {"id": check_id + 10}}
        checks = [check(first, 88), check(latest, 99)]
        errors, endpoints, runner = bind_required_checks_by_attempt(run, {"1": [first], "2": [latest]}, checks, ["Library tests"])
        self.assertEqual([], errors)
        self.assertEqual(99, endpoints["2"]["Library tests"]["id"])
        self.assertEqual(50.0, runner)
        foreign = {**check(latest, 299), "external_id": "999999"}
        errors, endpoints, _ = bind_required_checks_by_attempt(run, {"1": [first], "2": [latest]}, checks + [foreign], ["Library tests"])
        self.assertIn("required_check_job_binding_invalid:Library tests", errors)
        self.assertEqual({}, endpoints)

    def test_native_job_identity_cannot_be_overridden_by_collector_assertions(self):
        run = {"id": 7, "head_sha": "a" * 40}
        forged = {"id": 88, "run_id": 999, "run_attempt": 9, "head_sha": "b" * 40,
                  "source_run_id": 7, "source_run_attempt": 1, "source_head_sha": "a" * 40}
        errors = validate_general_job_identity(run, 1, forged, request_bound=True)
        self.assertIn("ranking_job_native_identity_conflict", errors)
        self.assertTrue(validate_general_job_identity(run, 1, {"id": 88}, request_bound=False))
        self.assertEqual([], validate_general_job_identity(run, 1, {"id": 88}, request_bound=True))

    def test_general_ranked_job_requires_run_attempt_head_and_repo(self):
        run = {"id": 7, "head_sha": "a" * 40}
        job = {"id": 88, "run_id": 7, "run_attempt": 2, "head_sha": "a" * 40}
        self.assertEqual([], validate_general_job_identity(run, 2, job))
        self.assertTrue(validate_general_job_identity(run, 1, job))
        self.assertTrue(validate_general_job_identity(run, 2, dict(job, head_sha="b" * 40)))

    def test_artifact_member_bytes_are_read_from_verified_zip(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "artifact.zip"
            payload = b'{"complete":true}'
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("report.json", payload)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            member_hash = hashlib.sha256(payload).hexdigest()
            self.assertEqual({"report.json": payload}, verified_zip_members(path, digest, {"report.json": member_hash}))
            with self.assertRaisesRegex(ValueError, "artifact_member_hash_mismatch:report.json"):
                verified_zip_members(path, digest, {"report.json": "0" * 64})

    def test_producer_requires_independent_job_upload_artifact_and_source_commit(self):
        run = {"id": 7, "head_sha": "a" * 40, "run_attempt": 1, "event": "pull_request",
               "pull_requests": [{"number": 3, "head": {"sha": "a" * 40}, "base": {"sha": "b" * 40}}]}
        job = {"id": 88, "run_id": 7, "run_attempt": 1, "name": "Library tests shard", "conclusion": "success",
               "steps": [{"name": "Upload library test timing", "conclusion": "success",
                          "started_at": "2026-10-12T10:00:00Z", "completed_at": "2026-10-12T10:00:10Z"}]}
        artifact = {"id": 101, "name": "library-test-timing-7-1", "created_at": "2026-10-12T10:00:05Z",
                    "workflow_run": {"id": 7, "head_sha": "a" * 40, "repository_id": 1207487684, "head_repository_id": 1207487684}}
        metadata = {"repository": "szTheory/sigra", "run_id": "7", "run_attempt": "1", "event": "pull_request",
                    "job_name": "Library tests shard", "source_sha": "c" * 40,
                    "timing_artifact_name": "library-test-timing-7-1"}
        self.assertEqual([], validate_producer_binding(run, job, artifact, metadata, "Library tests shard"))
        altered = dict(artifact, name="library-test-timing-8-1")
        self.assertTrue(validate_producer_binding(run, job, altered, metadata, "Library tests shard"))
        fork_artifact = {**artifact, "workflow_run": {**artifact["workflow_run"], "head_repository_id": 777}}
        self.assertTrue(validate_producer_binding(run, job, fork_artifact, metadata, "Library tests shard"))
        commit = {"sha": "c" * 40, "parents": [{"sha": "b" * 40}, {"sha": "a" * 40}]}
        self.assertEqual([], validate_producer_commit(metadata["source_sha"], commit, run))
        self.assertTrue(validate_producer_commit(metadata["source_sha"], {"sha": "c" * 40, "parents": [{"sha": "x" * 40}]}, run))
        workflow = b"name: CI\n"
        blob = hashlib.sha1(b"blob " + str(len(workflow)).encode() + b"\0" + workflow).hexdigest()
        tree = {"sha": "d" * 40, "tree": [{"path": ".github/workflows/ci.yml", "type": "blob", "sha": blob}]}
        self.assertEqual([], validate_workflow_source("c" * 40, tree, workflow, hashlib.sha256(workflow).hexdigest(), "d" * 40))
        self.assertIn("producer_workflow_tree_origin_unverified", validate_workflow_source("c" * 40, tree, workflow, hashlib.sha256(workflow).hexdigest(), "e" * 40))
        self.assertTrue(validate_workflow_source("c" * 40, tree, b"tampered", hashlib.sha256(workflow).hexdigest()))

    def test_log_redaction_is_bounded_and_excludes_environment_dumps(self):
        raw = (b"assertion failed: useful diagnosis\nGITHUB_TOKEN=ghp_" + b"a" * 40 + b"\n"
               b"AWS_SECRET_ACCESS_KEY=secret-value\nurl=https://example.invalid/x?sig=secret\n"
               b"+ AWS_SECRET_ACCESS_KEY=secret-value-traced\n+ export CLOUD_KEY=exported-secret\ndeclare -x DB_PASSWORD=declared-secret\n"
               + b"ordinary log line\n" * 10000)
        result = sanitize_failure_log(raw, max_input_bytes=65536, max_output_bytes=2048)
        self.assertLessEqual(len(result["text"].encode()), 2048)
        self.assertIn("assertion failed", result["text"])
        for secret in ("ghp_", "secret-value", "exported-secret", "declared-secret", "sig=secret", "example.invalid"):
            self.assertNotIn(secret, result["text"])
        self.assertTrue(result["truncated"])
        self.assertIn("[ENVIRONMENT", result["text"])

    def test_markdown_links_allow_only_canonical_repository_urls(self):
        self.assertEqual("https://github.com/szTheory/sigra/actions/runs/123", safe_markdown_url("https://github.com/szTheory/sigra/actions/runs/123"))
        self.assertIsNone(safe_markdown_url("https://attacker.invalid/[x](https://evil.invalid)"))
        self.assertIsNone(safe_markdown_url("https://github.com/szTheory/sigra/actions/runs/123?token=secret"))
        from ci_metrics_security import escape_markdown_text
        escaped = escape_markdown_text("[x](javascript:alert(1)) [y](//host) `code` *bold* _em_ # heading")
        for unsafe in ("](javascript", "](//host", "`", "*bold*", "_em_", "# heading"):
            self.assertNotIn(unsafe, escaped)

    def test_failure_log_reader_rejects_alternate_paths_and_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp); good = root / "raw/families/42/failed-job.log"; good.parent.mkdir(parents=True); good.write_bytes(b"assertion failed")
            digest = hashlib.sha256(good.read_bytes()).hexdigest()
            self.assertEqual(b"assertion failed", verified_failure_log(root, "raw/families/42/failed-job.log", digest))
            with self.assertRaisesRegex(ValueError, "path_invalid"):
                verified_failure_log(root, "../outside.log", digest)
            with self.assertRaisesRegex(ValueError, "hash_or_containment"):
                verified_failure_log(root, "raw/families/42/failed-job.log", "0" * 64)

    def test_core_budget_decrements_on_each_attempt_from_251(self):
        budget = CoreRequestBudget(remaining=251)
        self.assertTrue(budget.reserve())
        self.assertFalse(budget.reserve())
        self.assertEqual(250, budget.remaining)
        budget.refresh(900)
        self.assertFalse(budget.reserve())
        fresh = CoreRequestBudget(remaining=900)
        self.assertTrue(fresh.reserve())
        fresh.refresh(250)
        self.assertFalse(fresh.reserve())

    def test_comparison_family_registration_binds_run_and_window(self):
        reservations=[]; families=[]; runs=[]; registrations=[]; previous="0"*64
        for role,base,sha in (("before",100,"a"*40),("after",200,"b"*40)):
            for i in range(1,21):
                run_id=base+i; created="2026-10-13T00:00:00Z"
                reservation={"reservation_id":f"r{run_id}","pair_id":f"p{i}","family_role":role,"run_id":run_id,"created_at":created}
                reservations.append(reservation)
                api_run={"id":run_id,"event":"pull_request","path":".github/workflows/ci.yml","head_sha":sha,"created_at":created,"status":"in_progress","conclusion":None,"pull_requests":[{"number":331,"head":{"sha":sha},"base":{"sha":"c"*40}}]}
                raw_api=json.dumps(api_run,sort_keys=True,separators=(",",":")).encode()
                row={"sequence":len(registrations),"previous_sha256":previous,**reservation,"head_sha":sha,"pull_request_head_sha":sha,"pull_request_number":331,"pull_request_base_sha":"c"*40,"event":"pull_request","workflow_path":".github/workflows/ci.yml","api_run_sha256":hashlib.sha256(raw_api).hexdigest(),"api_run_response_b64":base64.b64encode(raw_api).decode()}
                row["record_sha256"]=hashlib.sha256(json.dumps(row,sort_keys=True,separators=(",",":")).encode()).hexdigest()
                registrations.append(row); previous=row["record_sha256"]
                families.append(dict(reservation))
                runs.append({"id":run_id,"event":"pull_request","head_sha":sha,"created_at":created,"detail_status":"complete"})
        contract={"status":"ready","window":{"start_utc":"2026-10-12T10:00:00Z","end_utc":"2026-10-14T10:00:00Z"},"family_reservations":reservations,"family_registrations":registrations,"baseline_application_sha":"a"*40,"candidate_identity":{"application_sha":"b"*40}}
        self.assertEqual([], validate_comparison_reservations(contract,families,runs))
        substituted=[dict(families[0],run_id=999)]+families[1:]
        self.assertIn("comparison_family_api_origin_mismatch",validate_comparison_reservations(contract,substituted,runs))
        out_of_window=[dict(families[0],created_at="2026-10-15T00:00:00Z")]+families[1:]
        self.assertIn("comparison_family_outside_frozen_window",validate_comparison_reservations(contract,out_of_window,runs))
        self.assertIn("comparison_registration_chain_invalid",validate_comparison_reservations({**contract,"family_registrations":registrations[::-1]},families,runs))

    def test_registration_records_api_identity_without_recording_outcome(self):
        contract={"status":"ready","baseline_application_sha":"a"*40,"candidate_identity":{"application_sha":"a"*40},"window":{"start_utc":"2026-10-12T10:00:00Z","end_utc":"2026-10-14T10:00:00Z"},"family_reservations":[{"reservation_id":"reserve-1","pair_id":"p1","family_role":"before"}]}
        api_run={"id":77,"event":"pull_request","path":".github/workflows/ci.yml","head_sha":"a"*40,"created_at":"2026-10-13T00:00:00Z","status":"queued","conclusion":None,"pull_requests":[{"number":331,"head":{"sha":"a"*40},"base":{"sha":"b"*40}}]}
        raw=json.dumps(api_run,sort_keys=True,separators=(",",":")).encode()
        ledger=register_comparison_run(contract,"reserve-1",api_run,api_run_sha256=hashlib.sha256(raw).hexdigest(),api_run_response_bytes=raw)
        self.assertEqual("77",str(ledger["records"][0]["run_id"]))
        self.assertNotIn("conclusion",ledger["records"][0])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), ledger["records"][0]["api_run_sha256"])
        self.assertEqual(raw, base64.b64decode(ledger["records"][0]["api_run_response_b64"]))
        with self.assertRaisesRegex(ValueError,"duplicate"):
            register_comparison_run(contract,"reserve-1",api_run,ledger,hashlib.sha256(raw).hexdigest(),raw)
        with self.assertRaisesRegex(ValueError,"contract_hash"):
            register_comparison_run({**contract,"frozen_note":"changed"},"reserve-1",api_run,ledger,hashlib.sha256(raw).hexdigest(),raw)
        completed={**api_run,"status":"completed","conclusion":"failure"}
        with self.assertRaisesRegex(ValueError,"does_not_match_reservation"):
            completed_raw=json.dumps(completed,sort_keys=True,separators=(",",":")).encode()
            register_comparison_run(contract,"reserve-1",completed,api_run_sha256=hashlib.sha256(completed_raw).hexdigest(),api_run_response_bytes=completed_raw)

    def test_rerun_failed_reused_job_ids_are_counted_once(self):
        attempts = {
            "1": [{"id": 1, "seconds": 10}, {"id": 2, "seconds": 20}],
            "2": [{"id": 1, "seconds": 10}, {"id": 2, "seconds": 20}, {"id": 3, "seconds": 30}],
        }
        counted, history = deduplicate_physical_jobs(attempts)
        self.assertEqual(60, sum(x["job"]["seconds"] for x in counted))
        self.assertEqual(2, sum(not x["counted"] for x in history))


if __name__ == "__main__":
    unittest.main()
