#!/usr/bin/env python3
"""Adversarial contracts for the saved CI evidence trust boundaries."""

import hashlib
import base64
import json
import os
import pathlib
import subprocess
import tempfile
import time
import unittest
import zipfile
import ci_metrics_security as security

from ci_metrics_security import (
    CoreRequestBudget,
    bind_required_checks_by_attempt,
    comparison_request_budget_reserve,
    comparison_request_budget_record_response,
    comparison_watcher_start,
    initialize_comparison_request_budget,
    comparison_registered_runs,
    validate_comparison_registration_ledger,
    deduplicate_physical_jobs,
    safe_markdown_url,
    register_comparison_run,
    repaired_cache_stratum,
    sanitize_failure_log,
    validate_check_bindings,
    validate_comparison_reservations,
    validate_comparison_plan,
    validate_comparison_schedule,
    validate_producer_binding,
    validate_producer_commit,
    validate_repaired_control_metadata,
    validate_general_job_identity,
    validate_workflow_source,
    verified_failure_log,
    verify_snapshot_hashes,
    verified_zip_members,
)


class SecurityContractsTest(unittest.TestCase):
    def test_repaired_measurement_rejects_mutating_method_at_cli_boundary(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as temp:
            contract_path = pathlib.Path(temp) / "repaired.json"
            contract_path.write_text(json.dumps({"comparison_kind": "repaired_control_pr"}))
            result = subprocess.run([
                "bash", str(root / "scripts/ci/ci-run-metrics.sh"),
                "--collect-comparison", "--comparison-role", "before",
                "--contract", str(contract_path), "--request-method", "POST",
            ], cwd=root, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("repaired_control_measurement_get_only", result.stderr)

    def test_repaired_owner_cache_and_image_evidence_fails_closed(self):
        self.assertIn("repaired_metadata_owner_set_incomplete", validate_repaired_control_metadata([]))
        rows = []
        for owner in ("library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"):
            rows.append({"job_name": "Library tests shard" if owner == "library" else "Example Playwright shard",
                         "matrix_seam": None if owner == "library" else owner,
                         "runner_os": "Linux", "runner_arch": "X64",
                         "runner_image": {"image_os": "ubuntu24", "image_version": "20261020.1.0"},
                         "cache_outcome": {"deps": {"cache_hit": True, "exact_key": True,
                             "matched_cache_key": "key", "scope": "refs/pull/1/merge", "ref": "refs/pull/1/merge", "conditions": ["Linux", "X64"]}}})
        self.assertEqual([], validate_repaired_control_metadata(rows))
        rows[0]["cache_outcome"]["deps"]["exact_key"] = False
        self.assertIn("repaired_cache_not_exact_hit:library:deps", validate_repaired_control_metadata(rows))

    def test_repaired_cache_structured_hits_are_warm_and_base_scope_is_eligible(self):
        rows = []
        expected = {}
        for owner in ("library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase"):
            rows.append({"job_name": "Library tests shard" if owner == "library" else "Example Playwright shard",
                "matrix_seam": None if owner == "library" else owner,
                "runner_os": "Linux", "runner_arch": "X64",
                "runner_image": {"image_os": "ubuntu24", "image_version": "20261020.1.0"},
                "cache_outcome": {"deps": {"cache_hit": True, "exact_key": True,
                    "matched_cache_key": f"source-key-{owner}", "scope": "refs/heads/main",
                    "ref": "refs/pull/11/merge", "conditions": ["Linux", "X64"]}}})
            expected[owner] = {"deps": f"source-key-{owner}"}
        self.assertEqual("warm", repaired_cache_stratum(rows)[0])
        self.assertEqual([], validate_repaired_control_metadata(rows, expected_ref="refs/pull/11/merge",
            eligible_scopes={"refs/heads/main", "refs/pull/11/merge"}, expected_keys=expected))
        rows[0]["cache_outcome"]["deps"]["scope"] = "refs/pull/22/merge"
        self.assertIn("repaired_cache_scope_ineligible:library:deps", validate_repaired_control_metadata(rows,
            expected_ref="refs/pull/11/merge", eligible_scopes={"refs/heads/main", "refs/pull/11/merge"}, expected_keys=expected))

    def test_unset_comparison_window_returns_cli_diagnostic_without_traceback(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as temp:
            contract_path = pathlib.Path(temp) / "blocked-contract.json"
            contract_path.write_text(json.dumps({
                "status": "blocked", "window": {"start_utc": None, "end_utc": None}
            }))
            result = subprocess.run([
                "bash", str(root / "scripts/ci/ci-run-metrics.sh"),
                "--validate-comparison-plan", "--contract", str(contract_path), "--format", "json"
            ], cwd=root, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Traceback", result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual(report["status"], "invalid")
            self.assertIn("comparison_window_not_predeclared", report["diagnostics"])
        for value in (None, 12, True, {}, []):
            with self.subTest(value=value):
                self.assertIn("comparison_window_not_predeclared", validate_comparison_plan({
                    "window": {"start_utc": value, "end_utc": value}
                }))

    def test_collection_selects_only_authenticated_registered_role_ids(self):
        schedule=[]; reservations=[]
        for pair in range(1,21):
            for role in (("before","after") if pair%2 else ("after","before")):
                pair_id=f"pair-{pair:02d}"; slot={"pair_id":pair_id,"family_role":role}
                schedule.append(slot); reservations.append({"reservation_id":f"r-{pair_id}-{role}",**slot})
        contract={"comparison_kind":"repaired_control_pr","required_contexts":["c1","c2","c3","c4","c5"],
                  "required_check_apps":{name:15368 for name in ("c1","c2","c3","c4","c5")},
                  "status":"ready","pair_count":20,"primary_family_count":40,"comparison_schedule":schedule,
                  "family_reservations":reservations,"maximum_pair_start_gap_seconds":1800,
                  "cache_eligibility":{"default_branch_ref":"refs/heads/main","expected_keys":{
                      side:{owner:{"deps":f"key-{side}-{owner}"} for owner in
                          ("library","admin_behavior","admin_checkpoints","design_gallery","non_admin_smoke","demo_showcase")}
                      for side in ("before","after")}},
                  "preparation_compatibility":{"baseline_cache_stratum":"warm","candidate_cache_stratum":"warm","runner_image_policy":"same"},
                  "candidate_identity":{"application_sha":"b"*40,"workflow_revision":"b"*40,"workload_revision_sha256":"c"*64,"workflow_file_sha256":"d"*64},
                  "baseline_application_sha":"a"*40,"window":{"start_utc":"2026-10-12T00:00:00Z","end_utc":"2026-10-14T00:00:00Z"}}
        raw_run={"id":101,"event":"pull_request","path":".github/workflows/ci.yml","head_sha":"a"*40,
                 "created_at":"2026-10-13T00:00:00Z","status":"queued","conclusion":None,
                 "repository":{"id":1207487684},"pull_requests":[{"number":1,
                    "head":{"sha":"a"*40,"ref":"candidate","repo":{"id":1207487684}},
                    "base":{"sha":"e"*40,"ref":"main","repo":{"id":1207487684}}}]}
        raw=json.dumps(raw_run,sort_keys=True,separators=(",",":")).encode(); reservation=reservations[0]
        merge_sha,tree_sha="c"*40,"d"*40
        pr_doc={"number":1,"head":{"sha":"a"*40,"ref":"candidate","repo":{"id":1207487684}},
            "base":{"sha":"e"*40,"ref":"main","repo":{"id":1207487684}},"merge_commit_sha":merge_sha}
        merge_doc={"sha":merge_sha,"commit":{"tree":{"sha":tree_sha}},"parents":[{"sha":"a"*40},{"sha":"e"*40}]}
        ledger=register_comparison_run(contract,reservation["reservation_id"],raw_run,api_run_sha256=hashlib.sha256(raw).hexdigest(),api_run_response_bytes=raw,
            pull_request_response=pr_doc,merge_commit_response=merge_doc)
        self.assertEqual([],validate_comparison_registration_ledger(contract,ledger))
        self.assertEqual([101],[row["run_id"] for row in comparison_registered_runs(contract,ledger,"before")])
        with self.assertRaisesRegex(ValueError,"role_has_no_registered_runs"):
            comparison_registered_runs(contract,ledger,"after")

    def test_comparison_request_budget_is_shared_finite_and_hash_chained(self):
        contract={"request_budget_ledger_id":"a"*64,"status":"ready"}
        with tempfile.TemporaryDirectory() as temp:
            path=pathlib.Path(temp)/"budget.json"
            initialize_comparison_request_budget(contract,path,now=1000)
            for index in range(600):
                comparison_request_budget_reserve(contract,path,f"/request/{index}",owner="run-1",now=1000)
            with self.assertRaisesRegex(ValueError,"request_limit_exhausted"):
                comparison_request_budget_reserve(contract,path,"/request/601",owner="run-1",now=1000)
            ledger=json.loads(path.read_text())
            self.assertEqual(600,sum(row.get("kind")=="request" for row in ledger["records"]))
            ledger["records"][0]["endpoint"]="/edited"
            path.write_text(json.dumps(ledger))
            with self.assertRaisesRegex(ValueError,"chain_invalid"):
                comparison_request_budget_reserve(contract,path,"/request/602",owner="run-1",now=1000)

    def test_comparison_request_budget_stops_at_low_core_time_and_rate_limit(self):
        contract={"request_budget_ledger_id":"b"*64,"status":"ready"}
        with tempfile.TemporaryDirectory() as temp:
            path=pathlib.Path(temp)/"core.json"
            initialize_comparison_request_budget(contract,path,now=1000)
            comparison_request_budget_reserve(contract,path,"/first",owner="run-1",now=1000)
            comparison_request_budget_record_response(contract,path,core_remaining=251)
            self.assertEqual(250,comparison_request_budget_reserve(contract,path,"/last",owner="run-1",now=1001)["core_remaining"])
            with self.assertRaisesRegex(ValueError,"core_limit_stop"):
                comparison_request_budget_reserve(contract,path,"/blocked",owner="run-1",now=1002)
        with tempfile.TemporaryDirectory() as temp:
            path=pathlib.Path(temp)/"rate.json"
            initialize_comparison_request_budget(contract,path,now=1000)
            comparison_request_budget_reserve(contract,path,"/limited",owner="run-1",now=1000)
            comparison_request_budget_record_response(contract,path,reset_at=2000,stop_reason="http_rate_limit")
            with self.assertRaisesRegex(ValueError,"http_rate_limit"):
                comparison_request_budget_reserve(contract,path,"/after-limit",owner="run-1",now=1001)
        with tempfile.TemporaryDirectory() as temp:
            path=pathlib.Path(temp)/"time.json"
            initialize_comparison_request_budget(contract,path,now=1000)
            with self.assertRaisesRegex(ValueError,"time_limit_exhausted"):
                comparison_request_budget_reserve(contract,path,"/late",owner="run-1",now=4600)

    def test_watcher_is_single_owner_and_resume_keeps_the_same_ledger(self):
        contract={"request_budget_ledger_id":"c"*64,"status":"ready"}
        with tempfile.TemporaryDirectory() as temp:
            path=pathlib.Path(temp)/"watcher.json"
            initialize_comparison_request_budget(contract,path,now=1000)
            comparison_watcher_start(contract,path,123,owner="watcher-1",now=1001)
            resumed=comparison_watcher_start(contract,path,123,owner="watcher-1",now=1002)
            self.assertTrue(resumed["resumed"])
            comparison_request_budget_reserve(contract,path,"/actions/runs/123",owner="watcher:123",now=1002)
            with self.assertRaisesRegex(ValueError,"watcher_already_claimed"):
                comparison_watcher_start(contract,path,123,owner="watcher-2",now=1003)
            reopened=initialize_comparison_request_budget(contract,path,now=9999)
            self.assertEqual(1000,reopened["started_at_epoch"])
            self.assertEqual(1,sum(row.get("kind")=="request" for row in reopened["records"]))

    def test_real_cli_watcher_polls_active_registered_run_with_shared_budget(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        required = ["Library tests", "Example unit smoke (ExUnit + ConnTest)",
                    "Install smoke (fresh phx.new + sigra.install)",
                    "Example HTTP smoke (boot + curl critical routes)",
                    "Example Playwright smoke (full lifecycle)"]
        schedule=[]; reservations=[]
        for pair in range(1,21):
            for role in (("before","after") if pair%2 else ("after","before")):
                pair_id=f"pair-{pair:02d}"; schedule.append({"pair_id":pair_id,"family_role":role})
                reservations.append({"reservation_id":f"r-{pair_id}-{role}","pair_id":pair_id,"family_role":role})
        contract={"comparison_kind":"repaired_control_pr","required_contexts":required,"status":"ready",
            "required_check_apps":{name:15368 for name in required},
            "cache_eligibility":{"default_branch_ref":"refs/heads/main","expected_keys":{
                side:{owner:{"deps":f"key-{side}-{owner}"} for owner in
                    ("library","admin_behavior","admin_checkpoints","design_gallery","non_admin_smoke","demo_showcase")}
                for side in ("before","after")}},
            "request_budget_ledger_id":"a"*64,
            "pair_count":20,"primary_family_count":40,"comparison_schedule":schedule,"family_reservations":reservations,
            "maximum_pair_start_gap_seconds":1800,"preparation_compatibility":{"baseline_cache_stratum":"warm",
                "candidate_cache_stratum":"warm","runner_image_policy":"same"},
            "baseline_application_sha":"a"*40,"baseline_workload_revision_sha256":"c"*64,
            "candidate_identity":{"application_sha":"b"*40,"workflow_revision":"b"*40,
                "workload_revision_sha256":"d"*64,"workflow_file_sha256":"e"*64},
            "window":{"start_utc":"2026-10-24T00:00:00Z","end_utc":"2026-10-26T00:00:00Z"}}
        with tempfile.TemporaryDirectory() as temp:
            temp=pathlib.Path(temp); contract_path=temp/"contract.json"; contract_path.write_text(json.dumps(contract))
            run={"id":101,"event":"pull_request","path":".github/workflows/ci.yml","head_sha":"a"*40,
                "created_at":"2026-10-24T01:00:00Z","status":"in_progress","conclusion":None,
                "repository":{"id":1207487684},"pull_requests":[{"number":331,
                    "head":{"sha":"a"*40,"ref":"candidate","repo":{"id":1207487684}},
                    "base":{"sha":"f"*40,"ref":"main","repo":{"id":1207487684}}}]}
            raw=json.dumps(run,sort_keys=True,separators=(",",":")).encode()
            merge_sha,tree_sha="c"*40,"d"*40
            pr_doc={"number":331,"head":{"sha":"a"*40,"ref":"candidate","repo":{"id":1207487684}},
                "base":{"sha":"f"*40,"ref":"main","repo":{"id":1207487684}},"merge_commit_sha":merge_sha}
            merge_doc={"sha":merge_sha,"commit":{"tree":{"sha":tree_sha}},"parents":[{"sha":"a"*40},{"sha":"f"*40}]}
            ledger=register_comparison_run(contract,reservations[0]["reservation_id"],run,
                api_run_sha256=hashlib.sha256(raw).hexdigest(),api_run_response_bytes=raw,
                pull_request_response=pr_doc,merge_commit_response=merge_doc)
            registration_path=temp/"registrations.json"
            registration_path.write_text(json.dumps(ledger))
            budget_path=temp/"budget.json"
            initialize_comparison_request_budget(contract,budget_path)
            calls_path=temp/"calls.json"; calls_path.write_text("0")
            fake_bin=temp/"bin"; fake_bin.mkdir(); gh=fake_bin/"gh"
            gh.write_text("#!/usr/bin/env python3\nimport json,os,pathlib,sys\nendpoint=sys.argv[-1]\nif endpoint=='rate_limit': print(json.dumps({'resources':{'core':{'remaining':500}}})); raise SystemExit(0)\nready=pathlib.Path(os.environ.get('FAKE_GH_READY_PATH','/nonexistent'))\nif os.environ.get('FAKE_GH_BLOCK_FIRST')=='1' and not ready.exists():\n ready.write_text('ready')\n with open(os.environ['FAKE_GH_RELEASE_FIFO'],'rb') as gate: gate.read(1)\npath=pathlib.Path(os.environ['FAKE_GH_CALLS_PATH']); n=int(path.read_text())+1; path.write_text(str(n))\nrun=json.loads(os.environ['FAKE_GH_RUN_JSON']); run['status']='in_progress' if n==1 else 'completed'; run['conclusion']=None if n==1 else 'success'; print(json.dumps(run))\n")
            gh.chmod(0o755)
            output_dir=temp/"watch-output"
            release_fifo=temp/"watcher-release.fifo"; os.mkfifo(release_fifo)
            env={**os.environ,"PATH":str(fake_bin)+os.pathsep+os.environ.get("PATH",""),"FAKE_GH_CALLS_PATH":str(calls_path),
                "FAKE_GH_RUN_JSON":json.dumps(run),"CI_METRICS_TEST_MODE":"1","CI_METRICS_TEST_WATCH_INTERVAL_SECONDS":"60",
                "CI_METRICS_TEST_NO_SLEEP":"1","FAKE_GH_BLOCK_FIRST":"1",
                "FAKE_GH_READY_PATH":str(temp/"transport-ready"),"FAKE_GH_RELEASE_FIFO":str(release_fifo)}
            process=subprocess.Popen(["bash",str(root/"scripts/ci/ci-run-metrics.sh"),"--watch-comparison-runs",
                "--comparison-role","before","--contract",str(contract_path),"--registrations",str(registration_path),
                "--request-budget-ledger",str(budget_path),"--watch-output-dir",str(output_dir)],
                cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            ready=temp/"transport-ready"; deadline=time.monotonic()+10
            while not ready.exists() and process.poll() is None and time.monotonic()<deadline: pass
            self.assertTrue(ready.exists(),"first watcher did not reach the held transport request")
            locked_budget_hash=hashlib.sha256(budget_path.read_bytes()).hexdigest()
            competing=subprocess.run(["bash",str(root/"scripts/ci/ci-run-metrics.sh"),"--watch-comparison-runs",
                "--comparison-role","before","--contract",str(contract_path),"--registrations",str(registration_path),
                "--request-budget-ledger",str(budget_path),"--watch-output-dir",str(temp/"competing-output")],
                cwd=root,env=env,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(0,competing.returncode)
            self.assertIn("comparison_watcher_already_active:101",competing.stderr)
            self.assertEqual(locked_budget_hash,hashlib.sha256(budget_path.read_bytes()).hexdigest(),
                "competing owner must stop before charging or changing the shared budget")
            with open(release_fifo,"wb") as gate: gate.write(b"1")
            stdout,stderr=process.communicate(timeout=30)
            class Result: pass
            result=Result(); result.returncode=process.returncode; result.stdout=stdout; result.stderr=stderr
            self.assertEqual(0,result.returncode,result.stderr)
            report=json.loads(result.stdout)
            self.assertEqual(2,report["poll_count"])
            self.assertEqual(60,report["interval_seconds"])
            self.assertEqual(3,report["request_count"])
            self.assertEqual(2,int(calls_path.read_text()))
            budget=json.loads(budget_path.read_text())
            self.assertEqual(3,sum(row.get("kind")=="request" for row in budget["records"]))
            self.assertEqual(1,sum(row.get("kind")=="watcher" for row in budget["records"]))
            resumed=subprocess.run(["bash",str(root/"scripts/ci/ci-run-metrics.sh"),"--watch-comparison-runs",
                "--comparison-role","before","--contract",str(contract_path),"--registrations",str(registration_path),
                "--request-budget-ledger",str(budget_path),"--watch-output-dir",str(output_dir)],
                cwd=root,env=env,capture_output=True,text=True,timeout=30)
            self.assertEqual(0,resumed.returncode,resumed.stderr)
            self.assertEqual(2,json.loads(resumed.stdout)["poll_count"])
            self.assertEqual(2,int(calls_path.read_text()),"terminal run should be resumed without another poll")
            budget_hash=hashlib.sha256(budget_path.read_bytes()).hexdigest()
            poll_hashes={path.name:hashlib.sha256(path.read_bytes()).hexdigest()
                for path in output_dir.glob("run-*-poll-*.json")}
            self.assertEqual(2,len(poll_hashes))
            self.assertEqual(3,sum(row.get("kind")=="request" for row in json.loads(budget_path.read_text())["records"]))
            final_resume=subprocess.run(["bash",str(root/"scripts/ci/ci-run-metrics.sh"),"--watch-comparison-runs",
                "--comparison-role","before","--contract",str(contract_path),"--registrations",str(registration_path),
                "--request-budget-ledger",str(budget_path),"--watch-output-dir",str(output_dir)],
                cwd=root,env={**env,"FAKE_GH_BLOCK_FIRST":"0"},capture_output=True,text=True,timeout=30)
            self.assertEqual(0,final_resume.returncode,final_resume.stderr)
            self.assertEqual(2,int(calls_path.read_text()),"terminal resume must perform no GET")
            self.assertEqual(budget_hash,hashlib.sha256(budget_path.read_bytes()).hexdigest(),
                "terminal resume must preserve the spent shared budget")
            self.assertEqual(poll_hashes,{path.name:hashlib.sha256(path.read_bytes()).hexdigest()
                for path in output_dir.glob("run-*-poll-*.json")},"terminal resume must preserve raw poll receipts")

    def test_http_403_and_429_are_hard_stops_without_immediate_retry(self):
        contract={"request_budget_ledger_id":"d"*64,"status":"ready"}
        for status in (403,429):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as temp:
                path=pathlib.Path(temp)/"rate.json"
                initialize_comparison_request_budget(contract,path,now=1000)
                comparison_request_budget_reserve(contract,path,"/limited",owner="run-1",now=1000)
                comparison_request_budget_record_response(contract,path,reset_at=2000,stop_reason=f"http_{status}")
                with self.assertRaisesRegex(ValueError,f"http_{status}"):
                    comparison_request_budget_reserve(contract,path,"/retry",owner="run-1",now=1001)

    def test_attempt_job_costs_keep_failed_work_and_report_unknowns(self):
        derive=getattr(security,"derive_attempt_job_costs",None)
        self.assertTrue(callable(derive),"raw attempt job cost derivation is required")
        attempts={"1":[{"id":1,"name":"browser","conclusion":"failure","started_at":"2026-10-13T00:00:00Z","completed_at":"2026-10-13T00:00:20Z"},
                       {"id":2,"name":"cancelled","conclusion":"cancelled","started_at":"2026-10-13T00:00:00Z"}],
                  "2":[{"id":3,"name":"retry","conclusion":"success","started_at":"2026-10-13T00:00:00Z","completed_at":"2026-10-13T00:00:30Z"},
                       {"id":4,"name":"skipped","conclusion":"skipped"}]}
        result=derive(attempts)
        self.assertEqual(50,result["known_subtotal_seconds"])
        self.assertIsNone(result["total_seconds"])
        self.assertEqual(["1:2"],result["unknown_jobs"])

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
               "family_role":reservations[i]["family_role"],"created_at":stamp} for i,stamp in enumerate(("2026-10-13T00:00:00Z","2026-10-13T00:00:10Z"))]
        self.assertEqual([],validate_comparison_schedule(contract,rows))
        rows[1]["created_at"]=rows[0]["created_at"]
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

    def test_attempt_scoped_registrations_bind_attempt_and_attempt_start(self):
        schedule=[]; reservations=[]
        for pair in range(1,21):
            roles=("before","after") if pair%2 else ("after","before")
            for role in roles:
                slot={"pair_id":f"pair-{pair:02d}","family_role":role}
                schedule.append(slot); reservations.append({"reservation_id":f"r-{pair}-{role}",**slot,"run_id":77+pair,"run_attempt":pair*2+(0 if role=="before" else 1)})
        reservations[0].update({"reservation_id":"r1","run_id":77,"run_attempt":2})
        reservations[1].update({"reservation_id":"r2","run_id":77,"run_attempt":3})
        contract={"status":"ready","sample_identity":"run_id+run_attempt","baseline_application_sha":"a"*40,
                  "candidate_identity":{"application_sha":"a"*40,"workflow_revision":"a"*40,"workload_revision_sha256":"c"*64,"workflow_file_sha256":"d"*64},
                  "window":{"start_utc":"2026-10-12T10:00:00Z","end_utc":"2026-10-14T10:00:00Z"},
                  "family_reservations":reservations,"comparison_schedule":schedule,
                  "maximum_pair_start_gap_seconds":1800,"pair_count":20,"primary_family_count":40,
                  "instrumentation_identity":{"exunit":"ci-exunit/v1","playwright":"ci-playwright/v1"},
                  "preparation_compatibility":{"baseline_cache_stratum":"warm","candidate_cache_stratum":"warm","runner_image_policy":"same"}}
        ledger=None
        for reservation_id,attempt,started in (("r1",2,"2026-10-13T01:00:00Z"),("r2",3,"2026-10-13T01:10:00Z")):
            run={"id":77,"run_attempt":attempt,"run_started_at":started,"event":"pull_request","path":".github/workflows/ci.yml",
                 "head_sha":"a"*40,"created_at":"2026-10-12T22:33:57Z","status":"in_progress","conclusion":None,
                 "pull_requests":[{"number":331,"head":{"sha":"a"*40},"base":{"sha":"b"*40}}]}
            raw=json.dumps(run,sort_keys=True,separators=(",",":")).encode()
            ledger=register_comparison_run(contract,reservation_id,run,ledger,hashlib.sha256(raw).hexdigest(),raw)
        self.assertEqual([(77,2),(77,3)],[(r["run_id"],r["run_attempt"]) for r in ledger["records"]])
        self.assertEqual([],validate_comparison_registration_ledger(contract,ledger))
        self.assertEqual([2,3],[r["run_attempt"] for r in comparison_registered_runs(contract,ledger,"before") + comparison_registered_runs(contract,ledger,"after")])
        bad=dict(ledger); bad["records"]=[dict(ledger["records"][0],run_attempt=1)] + ledger["records"][1:]
        self.assertIn("comparison_registration_identity_invalid",validate_comparison_registration_ledger(contract,bad))
        with self.assertRaisesRegex(ValueError,"duplicate"):
            schedule_free={k:v for k,v in contract.items() if k!="comparison_schedule"}
            same=ledger["records"][0]
            api=json.loads(base64.b64decode(same["api_run_response_b64"]))
            raw=json.dumps(api,sort_keys=True,separators=(",",":")).encode()
            first=register_comparison_run(schedule_free,"r1",api,api_run_sha256=hashlib.sha256(raw).hexdigest(),api_run_response_bytes=raw)
            register_comparison_run(schedule_free,"r1",api,first,hashlib.sha256(raw).hexdigest(),raw)
        too_many=ledger["records"]+[dict(ledger["records"][-1],sequence=2)]*39
        self.assertIn("comparison_registration_late_or_extra",validate_comparison_schedule(contract,too_many))

    def test_attempt_wait_uses_attempt_started_at_and_attempt_cost_only(self):
        from ci_metrics_security import derive_required_result_wait, derive_attempt_job_costs
        run={"id":77,"run_attempt":3,"run_started_at":"2026-10-13T01:00:00Z","created_at":"2026-10-12T22:33:57Z","head_sha":"a"*40,"repository":{"id":1207487684}}
        job={"id":88,"run_id":77,"run_attempt":3,"head_sha":"a"*40,"name":"Required","conclusion":"success",
             "started_at":"2026-10-13T01:00:00Z","completed_at":"2026-10-13T01:02:00Z"}
        check={"id":99,"external_id":"88","name":"Required","head_sha":"a"*40,"status":"completed","conclusion":"success",
               "completed_at":"2026-10-13T01:02:00Z","app":{"slug":"github-actions"},"check_suite":{"id":777}}
        wait=derive_required_result_wait(run,{"3":[job]},[check],["Required"],attempt=3)
        self.assertEqual(120,wait["seconds"])
        self.assertEqual(120,derive_attempt_job_costs({"3":[job]})["total_seconds"])
        self.assertIsNone(derive_required_result_wait({k:v for k,v in run.items() if k!="run_started_at"},{"3":[job]},[check],["Required"],attempt=3)["seconds"])
        wrong=dict(check,external_id="100")
        self.assertIsNone(derive_required_result_wait(run,{"3":[job]},[wrong],["Required"],attempt=3)["seconds"])

    def test_raw_attempt_family_costs_do_not_include_prior_attempt_or_original_created_at(self):
        from ci_metrics_security import derive_comparison_family_costs
        with tempfile.TemporaryDirectory() as temp:
            root=pathlib.Path(temp); family=root/"raw/families/77-attempt-3"; family.mkdir(parents=True)
            run={"id":77,"run_attempt":3,"run_started_at":"2026-10-13T01:00:00Z","created_at":"2026-10-12T22:33:57Z","head_sha":"a"*40,"conclusion":"success","repository":{"id":1207487684}}
            (family/"run.json").write_text(json.dumps(run,sort_keys=True))
            job={"id":88,"run_id":77,"run_attempt":3,"head_sha":"a"*40,"name":"Required","conclusion":"success","started_at":"2026-10-13T01:00:00Z","completed_at":"2026-10-13T01:02:00Z"}
            jobs_bytes=json.dumps({"jobs":[job]},sort_keys=True).encode(); jobs_path=family/"jobs-attempt-3.json"; jobs_path.write_bytes(jobs_bytes)
            check={"id":99,"external_id":"88","name":"Required","head_sha":"a"*40,"status":"completed","conclusion":"success","completed_at":"2026-10-13T01:02:00Z","app":{"slug":"github-actions"},"check_suite":{"id":777}}
            checks_bytes=json.dumps({"check_runs":[check]},sort_keys=True).encode(); (family/"check-runs.json").write_bytes(checks_bytes)
            manifest={"detail_status":"complete","source_run_sha256":hashlib.sha256((family/"run.json").read_bytes()).hexdigest(),
                "attempt_jobs":{"3":{"path":"raw/families/77-attempt-3/jobs-attempt-3.json","sha256":hashlib.sha256(jobs_bytes).hexdigest()}},
                "check_runs_sha256":hashlib.sha256(checks_bytes).hexdigest()}
            (family/"manifest.json").write_text(json.dumps(manifest))
            result=derive_comparison_family_costs(root,77,["Required"],run_attempt=3)
            self.assertEqual(120,result["runner_seconds"])
            self.assertEqual(120,result["required_result_wait_seconds"])
            self.assertEqual("2026-10-13T01:00:00Z",result["attempt_origin_at"])
            self.assertEqual([3],[row["attempt"] for row in result["attempt_costs"]])

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
