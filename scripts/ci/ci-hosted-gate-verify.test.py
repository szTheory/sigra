#!/usr/bin/env python3
"""Offline contracts for independently checking hosted canary receipts."""
import copy
import hashlib
import base64
import io
import json
import re
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts/ci/ci-hosted-gate-verify.py"
CANARY = ROOT / "scripts/ci/ci-gate-canary.sh"
REAL_LEDGER_R9 = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json"
_REAL_BODIES = {}
FIXTURE_TIME = "2026-10-13T04:00:00Z"
VERIFIER_JOB_STEPS = ("Set up job", "Checkout candidate verifier by pinned commit", "Verify immutable candidate verifier checkout",
                      "Verify retained source matrix independently", "Retain separate verifier result",
                      "Post Checkout candidate verifier by pinned commit", "Complete job")


def real_bodies():
    """253-117: GitHub's recorded bodies for run 38906314106 (R9 ledger seq 27 run, 28 jobs, 29 artifacts), read from the
    committed ledger; the fixtures below take their key sets and step lists from these, never from a copied file."""
    if not _REAL_BODIES:
        rows = {row["sequence"]: row for row in json.loads(REAL_LEDGER_R9.read_text())["transactions"]}
        for name, sequence in (("run", 27), ("jobs", 28), ("artifacts", 29)):
            _REAL_BODIES[name] = json.loads(base64.b64decode(rows[sequence]["response_body_base64"]))
    return copy.deepcopy(_REAL_BODIES)


def real_step_names(job_name):
    jobs = real_bodies()["jobs"]["jobs"]
    return [step["name"] for step in next(job for job in jobs if job["name"] == job_name)["steps"]]


def real_run(run_id, scenario, head_sha, head_branch, conclusion, attempt=1):
    """A run object with GitHub's recorded shape: name == display_title == the fixture's run-name, path exact."""
    run = real_bodies()["run"]
    title = f"Phase 253 Gate Canary / {scenario} / {run_id}-{attempt}"
    api = f"https://api.github.com/repos/szTheory/sigra/actions/runs/{run_id}"
    run.update(id=run_id, name=title, display_title=title, head_sha=head_sha, head_branch=head_branch, status="completed",
               conclusion=conclusion, run_attempt=attempt, url=api, html_url=f"https://github.com/szTheory/sigra/actions/runs/{run_id}",
               jobs_url=f"{api}/jobs", logs_url=f"{api}/logs", artifacts_url=f"{api}/artifacts", cancel_url=f"{api}/cancel",
               rerun_url=f"{api}/rerun", created_at=FIXTURE_TIME, updated_at=FIXTURE_TIME, run_started_at=FIXTURE_TIME)
    run["head_commit"]["id"] = head_sha
    return run


def real_steps(names, conclusions=None):
    return [{"name": name, "status": "completed", "conclusion": (conclusions or {}).get(name, "success"), "number": number,
             "started_at": FIXTURE_TIME, "completed_at": FIXTURE_TIME} for number, name in enumerate(names, 1)]


def real_job(run, job_id, name, conclusion, steps):
    """A job object with GitHub's recorded key set (seq 28); a skipped job lists no steps and has no runner."""
    job = real_bodies()["jobs"]["jobs"][0]
    ran = conclusion != "skipped"
    job.update(id=job_id, run_id=run["id"], workflow_name=run["name"], head_branch=run["head_branch"],
               run_url=run["url"], run_attempt=run["run_attempt"], node_id=f"CR_fixture{job_id}", head_sha=run["head_sha"],
               url=f"https://api.github.com/repos/szTheory/sigra/actions/jobs/{job_id}",
               html_url=f"https://github.com/szTheory/sigra/actions/runs/{run['id']}/job/{job_id}", status="completed",
               conclusion=conclusion, created_at=FIXTURE_TIME, started_at=FIXTURE_TIME, completed_at=FIXTURE_TIME, name=name,
               steps=steps if ran else [], check_run_url=f"https://api.github.com/repos/szTheory/sigra/check-runs/{job_id}",
               runner_id=1000000000 + job_id if ran else None, runner_name=f"GitHub Actions {1000000000 + job_id}" if ran else None,
               runner_group_id=0 if ran else None, runner_group_name="GitHub Actions" if ran else None)
    return job


def real_artifact(run, artifact_id, name, size, digest):
    """An artifact object with GitHub's recorded key set (seq 29), workflow_run included."""
    artifact = real_bodies()["artifacts"]["artifacts"][0]
    api = "https://api.github.com/repos/szTheory/sigra/actions/artifacts"
    artifact.update(id=artifact_id, node_id=f"ART_fixture{artifact_id}", name=name, size_in_bytes=size, url=f"{api}/{artifact_id}",
                    archive_download_url=f"{api}/{artifact_id}/zip", expired=False, digest="sha256:" + digest,
                    created_at=FIXTURE_TIME, updated_at=FIXTURE_TIME, expires_at="2026-10-20T04:00:00Z")
    artifact["workflow_run"].update(id=run["id"], head_branch=run["head_branch"], head_sha=run["head_sha"])
    return artifact


def source_jobs(run, scenario):
    """The seven source-run jobs with the real step lists; conclusions per scenario as the fixture workflow produces them."""
    outcome = {"full-pass": "success", "docs-only": "success", "cancelled": "cancelled"}.get(scenario, "failure")
    jobs = []
    for index, seam in enumerate(("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")):
        conclusion = outcome if scenario in ("actual-failure", "cancelled") and seam == "admin_behavior" else "success"
        steps = {"Run the named synthetic tiny command": conclusion}
        if scenario == "missing-seam" and seam == "admin_checkpoints":
            steps["Upload this producer's synthetic receipt"] = "skipped"
        jobs.append(real_job(run, index + 1, f"producer ({seam})", conclusion,
                             real_steps(real_step_names("producer (non_admin_smoke)"), steps)))
    verdict = "skipped" if scenario == "cancelled" else outcome
    jobs.append(real_job(run, 6, "Browser verdict", verdict,
                         real_steps(real_step_names("Browser verdict"), {"Shared browser record validator": verdict})))
    jobs.append(real_job(run, 7, "verifier", "skipped", []))
    return {"total_count": len(jobs), "jobs": jobs}


def verifier_run_receipt(run_id, producers=("producer (${{ matrix.seam }})",), head_sha="aa7014893b716f279b60ceb545b8aee5ca15b10c",
                         head_branch="gsd/253-replan-r9-fixture", first_job_id=None, conclusions=None):
    """The separate verifier run and its jobs in GitHub's recorded shapes: the given skipped producer job name(s), Browser
    verdict skipped, and the verifier job with the fixture workflow's named steps (no real sample: it never ran yet)."""
    run = real_run(run_id, "verifier", head_sha, head_branch, "success")
    first = 8 if first_job_id is None else first_job_id
    jobs = []
    for index, name in enumerate((*producers, "Browser verdict", "verifier")):
        conclusion = (conclusions or {}).get(index, "success" if name == "verifier" else "skipped")
        jobs.append(real_job(run, first + index, name, conclusion,
                             real_steps(VERIFIER_JOB_STEPS) if name == "verifier" else []))
    return run, {"total_count": len(jobs), "jobs": jobs}


def fixture():
    candidate = "a" * 40
    workflow_sha = "b" * 40
    workflow_blob = "c" * 40
    result_record = {"schema_version": "sigra.gate-canary-result/v1", "scenario": "full-pass",
                     "run_id": "901", "run_attempt": "1", "candidate_sha": candidate,
                     "fixture_workflow_sha": workflow_sha, "fixture_workflow_blob": workflow_blob,
                     "status": "passed", "validator_exit_code": 0, "honest_skip_exit_code": 0,
                     "honest_skip_verdict": {"event": "workflow_dispatch", "docs_only": "false", "verdict": "PASS"},
                     "synthetic": True}
    file_bytes = json.dumps(result_record, sort_keys=True, separators=(",", ":")) + "\n"
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr("canary-result.json", file_bytes.encode())
    payload = archive.getvalue()
    run = real_run(901, "full-pass", workflow_sha, "gsd/253-replan-canary-fixture-20261013-040000", "success")
    return {
        "schema_version": "sigra.hosted-gate-canary/v1",
        "repository": "szTheory/sigra",
        "scenario": "full-pass",
        "expected": {
            "candidate_sha": candidate,
            "fixture_ref": "refs/heads/gsd/253-replan-canary-fixture-20261013-040000",
            "fixture_ref_state": "verified",
            "workflow_id": 259268962,
            "workflow_path": ".github/workflows/ci.yml",
            "workflow_name": "Phase 253 Gate Canary",
            "workflow_sha": workflow_sha,
            "workflow_blob": workflow_blob,
        },
        "run_id": 901,
        "run_attempt": 1,
        "budget": {"max_requests": 120, "request_count": 4, "max_jobs": 45, "actual_jobs": 6, "elapsed_seconds": 30},
        "dispatch_inputs": {"scenario": "full-pass", "candidate_sha": candidate,
                            "fixture_sha": workflow_sha, "fixture_blob": workflow_blob},
        "dispatch_input_metrics": [],
        "transport_ledger": {"transactions": [
            {"sequence": index, "method": "GET", "url": f"https://api.github.com/mock/{index}", "status": 200}
            for index in range(1, 5)
        ]},
        # 253-117: GitHub's recorded run, job, step and artifact shapes (R9 seq 27/28/29); see real_run and source_jobs.
        "run": run,
        "jobs": source_jobs(run, "full-pass"),
        "artifacts": {"total_count": 1, "artifacts": [
            real_artifact(run, 77, "gate-canary-full-pass-901-1", len(payload), __import__("hashlib").sha256(payload).hexdigest())]},
        "retained_artifact": {
            "artifact_id": 77,
            "archive_sha256": __import__("hashlib").sha256(payload).hexdigest(),
            "archive_base64": base64.b64encode(payload).decode(),
            "files": {"canary-result.json": {"sha256": __import__("hashlib").sha256(file_bytes.encode()).hexdigest(),
                                               "content": file_bytes, "json": result_record}},
        },
    }


def scenario_fixture(scenario, run_id):
    document = fixture()
    code = 0 if scenario in ('full-pass', 'docs-only') else 1
    conclusion = 'cancelled' if scenario == 'cancelled' else 'success' if code == 0 else 'failure'
    document['scenario'] = scenario
    document['run_id'] = run_id
    # 253-117: the real shapes for this scenario's run and jobs (name == display_title == the run-name).
    document['run'] = real_run(run_id, scenario, document['run']['head_sha'], document['run']['head_branch'], conclusion)
    document['jobs'] = source_jobs(document['run'], scenario)
    if scenario == 'cancelled':
        document['artifacts'] = {'total_count': 0, 'artifacts': []}
        return document
    record = document['retained_artifact']['files']['canary-result.json']['json']
    record.update(scenario=scenario, run_id=str(run_id), validator_exit_code=code,
                  honest_skip_exit_code=code, status='passed' if code == 0 else 'rejected',
                  actual_event='workflow_dispatch', logical_event='pull_request' if scenario == 'docs-only' else 'workflow_dispatch',
                  classifier_result='success' if scenario == 'docs-only' else '', docs_only=scenario == 'docs-only',
                  production_dispatch_exemption=False)
    record['honest_skip_verdict'] = {'event': record['logical_event'], 'docs_only': 'true' if record['docs_only'] else 'false',
                                    'verdict': 'PASS' if code == 0 else 'FAIL'}
    file_bytes = json.dumps(record, sort_keys=True, separators=(',', ':')) + '\n'
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr('canary-result.json', file_bytes.encode())
    digest = __import__('hashlib').sha256(archive.getvalue()).hexdigest()
    document['retained_artifact'].update(archive_base64=base64.b64encode(archive.getvalue()).decode(), archive_sha256=digest)
    document['retained_artifact']['files']['canary-result.json'].update(content=file_bytes,
        sha256=__import__('hashlib').sha256(file_bytes.encode()).hexdigest())
    document['artifacts']['artifacts'][0] = real_artifact(document['run'], 77, f'gate-canary-{scenario}-{run_id}-1',
                                                          len(archive.getvalue()), digest)
    return document


def matrix_fixture():
    document = fixture()
    names = ('full-pass', 'docs-only', 'actual-failure', 'missing-seam', 'unexpected-skip', 'cancelled')
    document['scenarios'] = {name: scenario_fixture(name, 901 + index) for index, name in enumerate(names)}
    document['budget']['actual_jobs'] = sum(job['conclusion'] != 'skipped' for receipt in document['scenarios'].values()
                                           for job in receipt['jobs']['jobs'])
    document['separate_verifier'] = {'status': 'pending'}
    return document


class HostedGateVerifierTests(unittest.TestCase):
    def invoke(self, document):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            return subprocess.run(["python3", str(VERIFY), "--evidence", str(path), "--scenario", document.get("scenario", "full-pass")],
                                  text=True, capture_output=True, check=False)

    def test_accepts_matching_fixture_origin_and_retained_digest(self):
        result = self.invoke(fixture())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"status": "verified"', result.stdout)

    def test_rejects_running_or_wrong_origin_auxiliary_verifier(self):
        for field, value in [('conclusion', 'success'), ('run_id', 902), ('run_attempt', 2)]:
            document = fixture()
            document['jobs']['jobs'][-1][field] = value
            with self.subTest(field=field):
                self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_sources_can_pass_before_separate_verifier_but_matrix_cannot(self):
        document = matrix_fixture()
        document['scenario'] = 'sources'
        result = self.invoke(document)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('sources_verified', result.stdout)
        document['scenario'] = 'matrix'
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_final_matrix_checks_separate_verifier_and_recounts_executions(self):
        document = matrix_fixture()
        document['scenario'] = 'matrix'
        # 253-117: the separate verifier run and jobs in GitHub's recorded shapes (verifier_run_receipt).
        run, jobs = verifier_run_receipt(999, ('producers',), head_sha=document['run']['head_sha'],
                                         head_branch=document['run']['head_branch'])
        document['separate_verifier'] = {'status': 'passed', 'job_conclusion': 'success', 'run_id': '999',
                                         'run': run, 'jobs': jobs}
        document['budget']['actual_jobs'] += 1
        result = self.invoke(document)
        self.assertEqual(result.returncode, 0, result.stderr)
        document['budget']['actual_jobs'] -= 1
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_negative_boolean_or_underreported_budget(self):
        for field in ('request_count', 'actual_jobs', 'elapsed_seconds'):
            for value in (-1, True):
                document = fixture()
                document['budget'][field] = value
                with self.subTest(field=field, value=value):
                    self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        document['budget']['actual_jobs'] = 5
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_reconciles_actual_transport_transactions_and_dispatch_input_bounds(self):
        document = fixture()
        document["budget"]["request_count"] = 5
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        document["transport_ledger"]["transactions"].append(
            {"sequence": 5, "method": "GET", "url": "https://api.github.com/hidden-poll", "status": 200})
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        document["dispatch_inputs"]["extra"] = "x"
        document["dispatch_inputs"]["too_long"] = "x" * 65536
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_mocked_dispatch_poll_artifact_independent_verifier_path(self):
        document = fixture()
        urls = [
            ("POST", "https://api.github.com/repos/szTheory/sigra/actions/workflows/259268962/dispatches", 204),
            ("GET", "https://api.github.com/repos/szTheory/sigra/actions/runs?event=workflow_dispatch", 200),
            ("GET", "https://api.github.com/repos/szTheory/sigra/actions/runs/901", 200),
            ("GET", "https://api.github.com/repos/szTheory/sigra/actions/runs/901/jobs", 200),
            ("GET", "https://api.github.com/repos/szTheory/sigra/actions/runs/901/artifacts", 200),
            ("GET", "https://api.github.com/repos/szTheory/sigra/actions/artifacts/77/zip", 302),
            ("GET", "https://productionresultssa123.blob.core.windows.net/result/archive", 200),
        ]
        document["transport_ledger"]["transactions"] = [
            {"sequence": i, "method": method, "url": url, "status": status}
            for i, (method, url, status) in enumerate(urls, 1)
        ]
        document["transport_ledger"]["transactions"][0].update(input_keys=4, input_chars=178)
        document["dispatch_input_metrics"] = [{"sequence": 1, "key_count": 4, "combined_chars": 178}]
        document["transport_trace"] = copy.deepcopy(document["transport_ledger"]["transactions"])
        document["budget"]["request_count"] = len(urls)
        result = self.invoke(document)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"status": "verified"', result.stdout)
        document["dispatch_input_metrics"] = []
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_hidden_page_redirect_and_rate_limited_transport(self):
        base = fixture()
        base["transport_trace"] = copy.deepcopy(base["transport_ledger"]["transactions"])
        for extra in (
            {"method": "GET", "url": "https://api.github.com/mock/hidden-poll", "status": 200},
            {"method": "GET", "url": "https://api.github.com/mock/page-2", "status": 200},
            {"method": "GET", "url": "https://productionresultssa123.blob.core.windows.net/second-hop", "status": 200},
            {"method": "GET", "url": "https://api.github.com/mock/rate", "status": 403},
            {"method": "GET", "url": "https://api.github.com/mock/rate", "status": 429},
        ):
            document = copy.deepcopy(base)
            if extra["status"] == 429:
                document["transport_ledger"]["transactions"][0].update(extra, sequence=1)
            else:
                sequence = len(document["transport_trace"]) + 1
                document["transport_trace"].append({"sequence": sequence, **extra})
            with self.subTest(extra=extra):
                self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_oversized_artifact_and_extra_archive_member(self):
        document = fixture()
        document["artifacts"]["artifacts"][0]["size_in_bytes"] = 2 * 1024 * 1024 + 1
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        raw = base64.b64decode(document["retained_artifact"]["archive_base64"])
        with zipfile.ZipFile(io.BytesIO(raw)) as old:
            result_bytes = old.read("canary-result.json")
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", result_bytes)
            bundle.writestr("unexpected.txt", b"extra")
        payload = archive.getvalue()
        document["retained_artifact"]["archive_base64"] = base64.b64encode(payload).decode()
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        result_bytes = document["retained_artifact"]["files"]["canary-result.json"]["content"].encode()
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", result_bytes + b" " * (4 * 1024 * 1024 + 1 - len(result_bytes)))
        payload = archive.getvalue()
        document["retained_artifact"]["archive_base64"] = base64.b64encode(payload).decode()
        document["artifacts"]["artifacts"][0]["size_in_bytes"] = len(payload)
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_wrong_run_attempt_and_source_identity(self):
        for field, value in (("run_attempt", 2), ("head_sha", "d" * 40)):
            document = fixture()
            document["run"][field] = value
            with self.subTest(field=field):
                self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_wrong_fixture_workflow_identity_and_unexpected_job(self):
        for field, value in (("name", "CI"), ("path", ".github/workflows/other.yml"), ("workflow_id", 1)):
            document = fixture()
            document["run"][field] = value
            with self.subTest(field=field):
                self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        # 253-117: the real step list starts with Set up job; the tiny command step is found by name.
        next(step for step in document["jobs"]["jobs"][0]["steps"]
             if step["name"] == "Run the named synthetic tiny command")["conclusion"] = "failure"
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_missing_or_expired_artifact_and_altered_digest(self):
        document = fixture()
        document["artifacts"]["artifacts"] = []
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        document["artifacts"]["artifacts"][0]["expired"] = True
        self.assertNotEqual(self.invoke(document).returncode, 0)
        document = fixture()
        document["retained_artifact"]["archive_sha256"] = "0" * 64
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_self_attested_artifact_and_malformed_json(self):
        document = fixture()
        document["retained_artifact"]["files"]["canary-result.json"]["json"]["synthetic"] = False
        self.assertNotEqual(self.invoke(document).returncode, 0)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text("{not-json", encoding="utf-8")
            result = subprocess.run(["python3", str(VERIFY), "--evidence", str(path), "--scenario", "full-pass"],
                                    text=True, capture_output=True, check=False)
            self.assertNotEqual(result.returncode, 0)

    def test_rejects_honest_skip_verdict_for_a_different_logical_event(self):
        document = fixture()
        document["retained_artifact"]["files"]["canary-result.json"]["json"]["honest_skip_verdict"]["event"] = "pull_request"
        file_entry = document["retained_artifact"]["files"]["canary-result.json"]
        file_entry["content"] = json.dumps(file_entry["json"], sort_keys=True, separators=(",", ":")) + "\n"
        file_entry["sha256"] = __import__("hashlib").sha256(file_entry["content"].encode()).hexdigest()
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", file_entry["content"].encode())
        archive_bytes = archive.getvalue()
        document["retained_artifact"]["archive_base64"] = base64.b64encode(archive_bytes).decode()
        document["retained_artifact"]["archive_sha256"] = __import__("hashlib").sha256(archive_bytes).hexdigest()
        document["artifacts"]["artifacts"][0]["digest"] = "sha256:" + __import__("hashlib").sha256(archive_bytes).hexdigest()
        self.assertNotEqual(self.invoke(document).returncode, 0)

    def test_rejects_result_bytes_not_present_in_digest_checked_archive(self):
        document = fixture()
        file_entry = document["retained_artifact"]["files"]["canary-result.json"]
        file_entry["json"]["injected_unarchived_claim"] = True
        file_entry["content"] = json.dumps(file_entry["json"], sort_keys=True, separators=(",", ":")) + "\n"
        file_entry["sha256"] = __import__("hashlib").sha256(file_entry["content"].encode()).hexdigest()
        self.assertNotEqual(self.invoke(document).returncode, 0)


class CanaryCliTests(unittest.TestCase):
    def test_help_describes_only_bounded_scenarios(self):
        result = subprocess.run(["bash", str(CANARY), "--help"], text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--scenario", result.stdout)
        self.assertIn("full-pass", result.stdout)


class V2VerifierContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def transport_fixture(self):
        response = b'{"rules":[]}'
        legacy_response = b'{"message":"not found"}'
        native_response = b'{"total_count":0,"check_runs":[]}'
        def entry(sequence, route, url, status, body):
            return {"sequence": sequence, "method": "GET", "url": url, "route_id": route,
                "page_ordinal": 1 if route == "rules_main" else None, "hop_ordinal": 0, "state": "complete",
                "actual_status": status, "scrubbed_headers": {"content-type": "application/json", "content-length": str(len(body))},
                "response_sha256": __import__("hashlib").sha256(body).hexdigest(),
                "response_body_base64": base64.b64encode(body).decode(), "response_bytes": len(body),
                "scrubbed_response_bytes": len(body),
                "url_sha256": __import__("hashlib").sha256(url.encode()).hexdigest(),
                "request_sha256": "d" * 64, "source_sha256": "e" * 64, "window_id": "fixture-window"}
        first = entry(1, "rules_main", "https://api.github.com/repos/szTheory/sigra/rules/branches/main?per_page=100&page=1", 200, response)
        second = entry(2, "branch_protection", "https://api.github.com/repos/szTheory/sigra/branches/main/protection", 404, legacy_response)
        third = entry(3, "check_runs", "https://api.github.com/repos/szTheory/sigra/commits/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/check-runs?per_page=100&page=1", 200, native_response)
        return {"schema_version": "sigra.phase253.hosted-replan-evidence/v2",
                "origin": {"kind": "measured-v2", "source_sha256": "e" * 64, "window_id": "fixture-window"},
                "expected": {"candidate_sha": "a" * 40},
                "budget": {"request_count": 3, "max_requests": 117, "actual_jobs": 0, "max_jobs": 45, "elapsed_seconds": 1},
                "transport_ledger": {"schema_version": "sigra.phase253.http-ledger/v2", "window_id": "fixture-window",
                                     "source_sha256": "e" * 64, "transactions": [first, second, third]},
                "transport_receipts": [copy.deepcopy(first), copy.deepcopy(second), copy.deepcopy(third)],
                "server_journal": [copy.deepcopy(first), copy.deepcopy(second), copy.deepcopy(third)]}

    def test_v2_transport_reconciles_receipt_status_headers_and_digests(self):
        self.assertTrue(callable(getattr(self.module, "verify_transport_v2", None)),
                        "planned transport verifier must reconcile measured v2 evidence")
        evidence = self.transport_fixture()
        evidence["expected"]["workflow_id"] = 259268962
        self.module.verify_transport_v2(evidence)
        for mutate in (
            lambda e: e["transport_receipts"][0].update(actual_status=404),
            lambda e: e["server_journal"][0].update(sequence=2),
            lambda e: e["transport_ledger"]["transactions"][0].update(response_sha256="0" * 64),
            lambda e: e["transport_receipts"][0]["scrubbed_headers"].update(**{"content-type": "text/plain"}),
            lambda e: e["transport_ledger"]["transactions"][0].update(hop_ordinal=1),
        ):
            broken = self.transport_fixture()
            mutate(broken)
            with self.subTest(broken=broken):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_transport_v2(broken)

    def test_dispatch_metrics_are_bound_to_exact_transmitted_request_bytes(self):
        evidence = self.transport_fixture()
        evidence["expected"]["workflow_id"] = 259268962
        inputs = {"scenario": "full-pass", "candidate_sha": "a" * 40}
        encoded = self.module.serialize_dispatch_inputs(inputs)
        request_body = b'{"ref":"fixture","inputs":' + encoded + b'}'
        transaction = evidence["transport_ledger"]["transactions"][0]
        transaction.update(method="POST", route_id="dispatch",
            url="https://api.github.com/repos/szTheory/sigra/actions/workflows/259268962/dispatches", dispatch_inputs=inputs,
            request_body_base64=base64.b64encode(request_body).decode(),
            request_sha256=__import__("hashlib").sha256(request_body).hexdigest(),
            input_key_count=len(inputs), input_unicode_scalars=len(encoded.decode()),
            input_utf8_bytes=len(encoded), input_sha256=__import__("hashlib").sha256(encoded).hexdigest())
        transaction["url_sha256"] = __import__("hashlib").sha256(transaction["url"].encode()).hexdigest()
        for record in (evidence["transport_receipts"][0], evidence["server_journal"][0]):
            record.update(transaction)
        evidence["transport_ledger"]["transactions"][1].update(sequence=2)
        evidence["transport_receipts"][1].update(sequence=2)
        evidence["server_journal"][1].update(sequence=2)
        evidence["transport_ledger"]["transactions"][2].update(sequence=3)
        evidence["transport_receipts"][2].update(sequence=3)
        evidence["server_journal"][2].update(sequence=3)
        evidence["budget"]["request_count"] = 3
        broken = copy.deepcopy(evidence)
        broken["transport_ledger"]["transactions"][0]["request_sha256"] = "0" * 64
        broken["transport_receipts"][0]["request_sha256"] = "0" * 64
        broken["server_journal"][0]["request_sha256"] = "0" * 64
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_transport_v2(broken)

    # -- 253-101: offline hermetic-https canary evidence ------------------------------------------------------
    def dispatch_evidence(self, url, channel=None, transmitted=None):
        evidence = self.transport_fixture()
        evidence["expected"]["workflow_id"] = 259268962
        if channel:
            evidence["origin"]["channel"] = channel
        inputs = transmitted or {"scenario": "full-pass", "candidate_sha": "a" * 40}
        encoded = self.module.serialize_dispatch_inputs(inputs)
        request_body = b'{"ref":"fixture","inputs":' + encoded + b'}'
        transaction = evidence["transport_ledger"]["transactions"][0]
        transaction.update(method="POST", route_id="dispatch", url=url, page_ordinal=1,
            dispatch_inputs=dict(sorted(inputs.items())),  # the ledger is written with sorted keys
            request_body_base64=base64.b64encode(request_body).decode(),
            request_sha256=hashlib.sha256(request_body).hexdigest(),
            input_key_count=len(inputs), input_unicode_scalars=len(encoded.decode()),
            input_utf8_bytes=len(encoded), input_sha256=hashlib.sha256(encoded).hexdigest())
        transaction["url_sha256"] = hashlib.sha256(url.encode()).hexdigest()
        for record in (evidence["transport_receipts"][0], evidence["server_journal"][0]):
            record.update(copy.deepcopy(transaction))
        return evidence

    def test_dispatch_metrics_follow_the_transmitted_input_order_not_the_sorted_ledger_copy(self):
        live = "https://api.github.com/repos/szTheory/sigra/actions/workflows/259268962/dispatches"
        evidence = self.dispatch_evidence(live, transmitted={"scenario": "full-pass", "candidate_sha": "a" * 40})
        self.assertNotEqual(list(evidence["transport_ledger"]["transactions"][0]["dispatch_inputs"]), ["scenario", "candidate_sha"])
        self.module.verify_transport_v2(evidence)
        changed = self.dispatch_evidence(live)
        for record in (changed["transport_ledger"]["transactions"][0], changed["transport_receipts"][0], changed["server_journal"][0]):
            record["dispatch_inputs"] = {"scenario": "docs-only", "candidate_sha": "a" * 40}
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_transport_v2(changed)

    def test_a_local_dispatch_url_is_read_as_api_github_com_only_for_hermetic_https_evidence(self):
        local = "https://localhost/repos/szTheory/sigra/actions/workflows/259268962/dispatches"
        self.module.verify_transport_v2(self.dispatch_evidence(local, channel="hermetic-https"))
        for channel in (None, "github-api"):
            with self.subTest(channel=channel):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_transport_v2(self.dispatch_evidence(local, channel=channel))
        elsewhere = "https://example.com/repos/szTheory/sigra/actions/workflows/259268962/dispatches"
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_transport_v2(self.dispatch_evidence(elsewhere, channel="hermetic-https"))

    def test_repeated_page_one_requests_pass_and_a_later_page_must_follow_its_predecessor(self):
        evidence = self.transport_fixture()
        for index in (1, 2):
            for record in (evidence["transport_ledger"]["transactions"][index], evidence["transport_receipts"][index],
                           evidence["server_journal"][index]):
                record["page_ordinal"] = 1
        self.module.verify_transport_v2(evidence)
        for record in (evidence["transport_ledger"]["transactions"][2], evidence["transport_receipts"][2], evidence["server_journal"][2]):
            record["page_ordinal"] = 2  # page 2 of check_runs directly after branch_protection's page 1
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_transport_v2(evidence)

    # -- 253-110: the live canary transaction host rule -----------------------------------------------------
    BLOB = "productionresultssa17.blob.core.windows.net"

    def hop_rows(self, evidence, hops, group="artifact-zip-group-1"):
        """Append one redirected download (hop 0, hop 1, ...) to all three records; hops are (url, status, host)."""
        body = b""
        for hop, (url, status, host) in enumerate(hops):
            sequence = len(evidence["transport_ledger"]["transactions"]) + 1
            row = {"sequence": sequence, "method": "GET", "url": url, "route_id": "artifact_zip", "page_ordinal": None,
                   "hop_ordinal": hop, "request_group": group, "state": "complete", "actual_status": status,
                   "scrubbed_headers": {"content-length": "0"}, "response_sha256": hashlib.sha256(body).hexdigest(),
                   "response_body_base64": "", "response_bytes": 0, "scrubbed_response_bytes": 0,
                   "url_sha256": hashlib.sha256(url.encode()).hexdigest(), "request_sha256": "d" * 64,
                   "source_sha256": "e" * 64, "window_id": evidence["transport_ledger"]["window_id"]}
            if host is not None:
                row["host"] = host
            for records in (evidence["transport_ledger"]["transactions"], evidence["transport_receipts"], evidence["server_journal"]):
                records.append(copy.deepcopy(row))
        evidence["budget"]["request_count"] = len(evidence["transport_ledger"]["transactions"])
        return evidence

    def download(self, hop0="https://api.github.com/repos/szTheory/sigra/actions/artifacts/77/zip",
                 hop1=f"https://{BLOB}/x/a.zip?[REDACTED]", host0="api.github.com", host1=BLOB, channel=None):
        evidence = self.transport_fixture()
        if channel:
            evidence["origin"]["channel"] = channel
        return self.hop_rows(evidence, [(hop0, 302, host0), (hop1, 200, host1)])

    def test_live_canary_transactions_hop_zero_on_api_github_com_and_later_hops_on_trusted_download_hosts_only(self):
        # Positive cases: the shapes a live (or live-policy dry-run) canary ledger really has.
        self.module.verify_transport_v2(self.download())
        self.module.verify_transport_v2(self.download(hop1="https://pipelines.actions.githubusercontent.com/logs/run.zip?[REDACTED]",
                                                      host1="pipelines.actions.githubusercontent.com"))
        self.module.verify_transport_v2(self.download(host0=None, host1=None))  # host read from the digest-bound URL
        rejected = {
            "hop 0 on a blob host": dict(hop0=f"https://{self.BLOB}/x/a.zip", host0=self.BLOB),
            "hop 1 on an untrusted host": dict(hop1="https://evil.example.com/a.zip?[REDACTED]", host1="evil.example.com"),
            "hop 1 on a lookalike host": dict(hop1=f"https://{self.BLOB}.evil.example/a.zip?[REDACTED]",
                                              host1=f"{self.BLOB}.evil.example"),
            "hop 1 back on api.github.com": dict(hop1="https://api.github.com/x/a.zip?[REDACTED]", host1="api.github.com"),
            "hop 1 on port 8443": dict(hop1=f"https://{self.BLOB}:8443/x/a.zip?[REDACTED]"),
            "hop 1 over http": dict(hop1=f"http://{self.BLOB}/x/a.zip?[REDACTED]"),
            "host field disagrees with the URL": dict(host1="evil.example.com"),
            "hop 0 on an untrusted host": dict(hop0="https://evil.example.com/repos/szTheory/sigra/actions/artifacts/77/zip",
                                               host0="evil.example.com"),
        }
        for label, overrides in rejected.items():
            for channel in (None, "github-api"):
                with self.subTest(case=label, channel=channel):
                    with self.assertRaises(self.module.VerificationError):
                        self.module.verify_transport_v2(self.download(channel=channel, **overrides))

    def test_hermetic_https_canary_evidence_is_unaffected_by_the_live_host_rule(self):
        local = "https://localhost:4555/repos/szTheory/sigra/actions/artifacts/77/zip"
        self.module.verify_transport_v2(self.download(hop0=local, hop1="https://localhost:4555/x/a.zip?[REDACTED]",
                                                      host0="localhost", host1="localhost", channel="hermetic-https"))

    def test_the_halted_r8_live_ledger_rows_satisfy_the_live_host_rule(self):
        # Positive control on real live data (read-only): the 30 rows the 253-104 window measured on api.github.com.
        rule = getattr(self.module, "verify_live_transaction_host", None)
        self.assertTrue(callable(rule), "the live canary transaction host rule is missing")
        ledger = json.loads((ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
                                    "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json").read_text())
        rows = ledger["transactions"]
        self.assertEqual(len(rows), 30)
        self.assertEqual({row["host"] for row in rows}, {"api.github.com"})
        for row in rows:
            rule(row)
        tampered = dict(rows[0], host=self.BLOB, url=rows[0]["url"].replace("api.github.com", self.BLOB))
        with self.assertRaises(self.module.VerificationError):
            rule(tampered)

    def test_hermetic_https_scenarios_require_hermetic_unverified_and_live_ones_require_verified(self):
        for channel, state, accepted in (("hermetic-https", "hermetic-unverified", True), ("hermetic-https", "verified", False),
                                         (None, "verified", True), (None, "hermetic-unverified", False),
                                         ("github-api", "hermetic-unverified", False)):
            with self.subTest(channel=channel, state=state):
                receipt = scenario_fixture("full-pass", 901)
                evidence = copy.deepcopy(receipt)
                evidence["expected"]["fixture_ref_state"] = state
                if channel:
                    evidence["origin"] = {"channel": channel}
                if accepted:
                    self.module.verify_scenario(receipt, "full-pass", evidence)
                else:
                    with self.assertRaises(self.module.VerificationError):
                        self.module.verify_scenario(receipt, "full-pass", evidence)

    def test_rejects_zip_local_header_that_disagrees_with_central_metadata(self):
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", b'{"ok":true}')
        payload = bytearray(archive.getvalue())
        payload[14] ^= 0x01  # Local-header CRC; the central directory remains intact.
        with self.assertRaises(self.module.VerificationError):
            self.module.validate_single_result_zip(bytes(payload))

    def test_dispatch_serializer_uses_typed_unicode_scalars_and_separate_byte_limit(self):
        encode = self.module.serialize_dispatch_inputs
        ten_key_schema = {f"k{index}": str for index in range(10)}
        ten_keys = {name: "v" for name in ten_key_schema}
        self.assertEqual(len(json.loads(encode(ten_keys, schema=ten_key_schema))), 10)
        with self.assertRaises(self.module.VerificationError):
            encode({**ten_keys, "k10": "v"}, schema={**ten_key_schema, "k10": str})
        self.assertEqual(json.loads(encode({"enabled": True}, schema={"enabled": bool})), {"enabled": True})
        with self.assertRaises(self.module.VerificationError):
            encode({"enabled": 1}, schema={"enabled": bool})
        self.assertEqual(json.loads(encode({"scenario": "full-pass"})), {"scenario": "full-pass"})
        for invalid in ({"scenario": None}, {"scenario": ["full-pass"]}, {"scenario": "\ud800"},
                        {"unknown": "x"}, {"scenario": "é" * 40000}, {"scenario": "🙂" * 20000}):
            with self.subTest(keys=list(invalid)):
                with self.assertRaises(self.module.VerificationError):
                    encode(invalid)
        max_ascii = "a" * 65520
        self.assertEqual(len(encode({"scenario": max_ascii})), 65535)
        with self.assertRaises(self.module.VerificationError):
            encode({"scenario": max_ascii + "a"})

    def test_matrix_gzip_decoder_rejects_truncated_concatenated_and_trailing_streams(self):
        import gzip
        valid = gzip.compress(b'{"scenarios":[]}')
        self.assertEqual(self.module.decode_matrix_payload(base64.b64encode(valid).decode()), {"scenarios": []})
        for malformed in (valid[:-1], valid + gzip.compress(b'{"extra":true}'), valid + b"tail", b"%%%"):
            with self.subTest(length=len(malformed)):
                with self.assertRaises(self.module.VerificationError):
                    self.module.decode_matrix_payload(base64.b64encode(malformed).decode())

    def test_rejects_duplicate_symlink_and_trailing_zip_streams(self):
        result = b'{"ok":true}'
        cases = []
        duplicate = io.BytesIO()
        with zipfile.ZipFile(duplicate, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", result)
            bundle.writestr("canary-result.json", result)
        cases.append(duplicate.getvalue())
        symlink = io.BytesIO()
        with zipfile.ZipFile(symlink, "w") as bundle:
            info = zipfile.ZipInfo("canary-result.json")
            info.create_system = 3
            info.external_attr = (0o120777 << 16)
            bundle.writestr(info, result)
        cases.append(symlink.getvalue())
        base = io.BytesIO()
        with zipfile.ZipFile(base, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("canary-result.json", result)
        cases.append(base.getvalue() + b"trailing")
        for payload in cases:
            with self.assertRaises(self.module.VerificationError):
                self.module.validate_single_result_zip(payload)

    def test_new_acceptance_modes_reject_historical_v1_while_legacy_remains_disclosable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "v1.json"
            path.write_text(json.dumps(fixture()), encoding="utf-8")
            legacy = subprocess.run(["python3", str(VERIFY), "--mode", "legacy", "--evidence", str(path),
                                     "--scenario", "full-pass"], text=True, capture_output=True)
            self.assertEqual(legacy.returncode, 0, legacy.stderr)
            fresh = subprocess.run(["python3", str(VERIFY), "--mode", "preflight", "--evidence", str(path)],
                                   text=True, capture_output=True)
            self.assertNotEqual(fresh.returncode, 0)

    def test_fresh_rules_require_complete_exact_five_native_sources(self):
        self.assertTrue(callable(getattr(self.module, "verify_effective_checks", None)),
                        "planned rules verifier must reconcile complete effective checks")
        names = ["Library tests", "Example unit smoke (ExUnit + ConnTest)",
                 "Install smoke (fresh phx.new + sigra.install)",
                 "Example HTTP smoke (boot + curl critical routes)",
                 "Example Playwright smoke (full lifecycle)"]
        evidence = self.transport_fixture()
        page_records = [{"type": "required_status_checks", "parameters": {"required_status_checks": [
            {"context": name, "integration_id": 123, "source": "workflow"} for name in names]}}]
        page_bytes = json.dumps(page_records, separators=(",", ":")).encode()
        page = evidence["transport_ledger"]["transactions"][0]
        page.update(response_body_base64=base64.b64encode(page_bytes).decode(),
                    response_sha256=__import__("hashlib").sha256(page_bytes).hexdigest(), response_bytes=len(page_bytes))
        evidence["transport_receipts"][0].update(page)
        evidence["server_journal"][0].update(page)
        native_runs = [{"name": name, "app": {"id": 123, "slug": "github-actions"},
                        "html_url": f"https://github.com/szTheory/sigra/actions/runs/99/job/{index}",
                        "conclusion": "success"} for index, name in enumerate(names, 1)]
        native_bytes = json.dumps({"total_count": 5, "check_runs": native_runs}, separators=(",", ":")).encode()
        native = evidence["transport_ledger"]["transactions"][2]
        native.update(response_body_base64=base64.b64encode(native_bytes).decode(),
                      response_sha256=__import__("hashlib").sha256(native_bytes).hexdigest(), response_bytes=len(native_bytes))
        evidence["transport_receipts"][2].update(native)
        evidence["server_journal"][2].update(native)
        evidence["effective_checks"] = {"endpoint": "/repos/szTheory/sigra/rules/branches/main",
            "query": {"per_page": 100}, "complete": True, "terminal_page": 1,
            "legacy_protection": {"present": False, "status": 404, "sequence": 2, "required": []},
            "native_check_runs": {"sequence": 3},
            "rules_pages": [{"page": 1, "sequence": 1, "records": page_records}], "required": [
                {"context": name, "app_id": 123, "integration_id": 123, "app_slug": "github-actions",
                 "source": f"https://github.com/szTheory/sigra/actions/runs/99/job/{index}"}
                for index, name in enumerate(names, 1)]}
        evidence["producer_checks"] = [{"name": name, "app_id": 123, "app_slug": "github-actions",
                                        "source": f"https://github.com/szTheory/sigra/actions/runs/99/job/{index}",
                                        "conclusion": "success"} for index, name in enumerate(names, 1)]
        self.module.verify_effective_checks(evidence)
        for mutate in (
            lambda e: e["effective_checks"].update(complete=False),
            lambda e: e["effective_checks"]["required"].pop(),
            lambda e: e["effective_checks"]["required"][0].update(app_id="123"),
            lambda e: e["producer_checks"][0].update(app_id=456),
            lambda e: e["effective_checks"]["required"].append(dict(e["effective_checks"]["required"][0])),
        ):
            broken = copy.deepcopy(evidence)
            mutate(broken)
            with self.assertRaises(self.module.VerificationError):
                self.module.verify_effective_checks(broken)

        full_page = copy.deepcopy(evidence)
        raw = full_page["effective_checks"]["rules_pages"][0]["records"]
        raw.extend({"type": "other"} for _ in range(99))
        body = json.dumps(raw, separators=(",", ":")).encode()
        for collection in (full_page["transport_ledger"]["transactions"], full_page["transport_receipts"], full_page["server_journal"]):
            collection[0].update(response_body_base64=base64.b64encode(body).decode(),
                                 response_sha256=__import__("hashlib").sha256(body).hexdigest(), response_bytes=len(body))
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_effective_checks(full_page)

        byte_variant = copy.deepcopy(evidence)
        byte_variant["producer_checks"][0]["source"] = byte_variant["producer_checks"][0]["source"].upper()
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_effective_checks(byte_variant)


CHECK_NAMES = ("Library tests", "Example unit smoke (ExUnit + ConnTest)",
               "Install smoke (fresh phx.new + sigra.install)",
               "Example HTTP smoke (boot + curl critical routes)",
               "Example Playwright smoke (full lifecycle)")
SERVER_PARENT = "84ebcea60024c9e8caee405d55cad1c76b0e858a"
CANARY_CANDIDATE = "a" * 40


def check_run(name, index, conclusion="success", **overrides):
    run = {"name": name, "app": {"id": 123, "slug": "github-actions"},
           "html_url": f"https://github.com/szTheory/sigra/actions/runs/99/job/{index}", "conclusion": conclusion}
    run.update(overrides)
    return run


def set_body(evidence, index, body_bytes, url=None):
    for collection in (evidence["transport_ledger"]["transactions"], evidence["transport_receipts"], evidence["server_journal"]):
        row = collection[index]
        row.update(response_body_base64=base64.b64encode(body_bytes).decode(),
                   response_sha256=hashlib.sha256(body_bytes).hexdigest(), response_bytes=len(body_bytes),
                   scrubbed_response_bytes=len(body_bytes))
        row["scrubbed_headers"] = {**row["scrubbed_headers"], "content-length": str(len(body_bytes))}
        if url is not None:
            row.update(url=url, url_sha256=hashlib.sha256(url.encode()).hexdigest())


class CanaryCheckSourceTests(unittest.TestCase):
    """D-12 decision server-parent-identity: canary check sources are read from the frozen server parent."""

    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_check_source", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def evidence(self, runs, check_sha=SERVER_PARENT, role="server_parent", source_sha=SERVER_PARENT):
        evidence = V2VerifierContractTests.transport_fixture(self)
        rules = [{"type": "required_status_checks", "parameters": {"required_status_checks": [
            {"context": name, "integration_id": 123} for name in CHECK_NAMES]}}]
        set_body(evidence, 0, json.dumps(rules, separators=(",", ":")).encode())
        url = f"https://api.github.com/repos/szTheory/sigra/commits/{check_sha}/check-runs?per_page=100&page=1"
        set_body(evidence, 2, json.dumps({"total_count": len(runs), "check_runs": runs}, separators=(",", ":")).encode(), url)
        evidence["repository"] = "szTheory/sigra"
        evidence["expected"] = {"candidate_sha": CANARY_CANDIDATE}
        if role is not None:
            evidence["expected"].update(check_source_sha=source_sha, check_source_role=role)
        return evidence

    def bind_receipt(self, evidence, root, server_parent=SERVER_PARENT, candidate=CANARY_CANDIDATE, digest=None, path="receipt.json"):
        raw = json.dumps({"schema_version": "sigra.phase253.git-publication-receipt/v1",
                          "candidate_sha": candidate, "server_parent_sha": server_parent}).encode()
        (Path(root) / "receipt.json").write_bytes(raw)
        evidence["publication"] = {"receipt_path": path, "receipt_sha256": digest or hashlib.sha256(raw).hexdigest()}
        return evidence

    def five(self, conclusions=("success",) * 5):
        return [check_run(name, index, conclusion) for index, (name, conclusion) in enumerate(zip(CHECK_NAMES, conclusions), 1)]

    def verify(self, evidence, root):
        verify = getattr(self.module, "verify_canary_checks", None)
        self.assertTrue(callable(verify), "verify_canary_checks(evidence, root) must bind canary check sources")
        return verify(evidence, root=root)

    def test_server_parent_identity_accepts_any_conclusion_and_records_it_literally(self):
        conclusions = ("failure", "success", "cancelled", None, "timed_out")
        with tempfile.TemporaryDirectory() as root:
            evidence = self.bind_receipt(self.evidence(self.five(conclusions)), root)
            result = self.verify(evidence, root)
        self.assertEqual(result["status"], "effective_checks_verified")
        self.assertEqual([item["conclusion"] for item in evidence["producer_checks"]], list(conclusions))

    def test_candidate_bound_or_wrong_sha_check_runs_are_rejected(self):
        cases = {
            "candidate url": dict(check_sha=CANARY_CANDIDATE),
            "other url": dict(check_sha="b" * 40),
            "candidate as source": dict(check_sha=CANARY_CANDIDATE, source_sha=CANARY_CANDIDATE),
            "no check source role": dict(role=None, check_sha=CANARY_CANDIDATE),
            "candidate role": dict(role="candidate"),
            "malformed source sha": dict(source_sha=SERVER_PARENT.upper()),
        }
        for label, overrides in cases.items():
            with self.subTest(case=label), tempfile.TemporaryDirectory() as root:
                evidence = self.bind_receipt(self.evidence(self.five(), **overrides), root)
                self.assertTrue(callable(getattr(self.module, "verify_canary_checks", None)))
                with self.assertRaises(self.module.VerificationError):
                    self.verify(evidence, root)

    def test_check_source_must_be_the_server_parent_of_the_rehashed_publication_receipt(self):
        cases = {
            "no publication": lambda e, root: e,
            "digest mismatch": lambda e, root: self.bind_receipt(e, root, digest="0" * 64),
            "different server parent": lambda e, root: self.bind_receipt(e, root, server_parent="c" * 40),
            "different candidate": lambda e, root: self.bind_receipt(e, root, candidate="d" * 40),
            "path outside root": lambda e, root: self.bind_receipt(e, root, path="../receipt.json"),
            "absolute path": lambda e, root: self.bind_receipt(e, root, path=str(Path(root) / "receipt.json")),
            "missing file": lambda e, root: self.bind_receipt(e, root, path="absent.json"),
        }
        for label, bind in cases.items():
            with self.subTest(case=label), tempfile.TemporaryDirectory() as root:
                evidence = bind(self.evidence(self.five()), root)
                self.assertTrue(callable(getattr(self.module, "verify_canary_checks", None)))
                with self.assertRaises(self.module.VerificationError):
                    self.verify(evidence, root)

    def test_producer_count_app_and_source_identity_are_still_enforced(self):
        base = self.five()
        cases = {
            "four producers": base[:4],
            "six producers": base + [check_run(CHECK_NAMES[0], 9)],
            "foreign app": [check_run(CHECK_NAMES[0], 1, app={"id": 456, "slug": "other-app"})] + base[1:],
            "missing source": [check_run(CHECK_NAMES[0], 1, html_url=None)] + base[1:],
            "non-https source": [check_run(CHECK_NAMES[0], 1, html_url="http://github.com/x/job/1")] + base[1:],
            "missing app slug": [check_run(CHECK_NAMES[0], 1, app={"id": 123})] + base[1:],
        }
        for label, runs in cases.items():
            with self.subTest(case=label), tempfile.TemporaryDirectory() as root:
                evidence = self.bind_receipt(self.evidence(runs), root)
                self.assertTrue(callable(getattr(self.module, "verify_canary_checks", None)))
                with self.assertRaises(self.module.VerificationError):
                    self.verify(evidence, root)

    def test_preflight_cli_rejects_the_superseded_candidate_bound_contract(self):
        evidence = self.evidence(self.five(), check_sha=CANARY_CANDIDATE, role=None)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text(json.dumps(evidence), encoding="utf-8")
            result = subprocess.run(["python3", "-B", str(VERIFY), "--mode", "preflight", "--evidence", str(path)],
                                    text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("canary check source must be the frozen server parent", result.stderr)

    def test_pr_family_view_still_requires_five_successful_checks_on_its_head(self):
        head = "e" * 40
        def family_view(conclusions):
            evidence = self.evidence(self.five(conclusions), check_sha=head, role=None)
            ledger = evidence["transport_ledger"]["transactions"]
            for row, family in zip(ledger, ("shared", "shared", "normal")):
                row["family"] = family
            return self.module._view_for_checks(evidence, "normal", {"mode": "live"}, head, ledger[2])
        view = family_view(("success",) * 5)
        self.module.hydrate_effective_checks(view)
        self.module.verify_effective_checks(view)
        for conclusions in (("failure",) + ("success",) * 4, ("success",) * 4 + (None,)):
            with self.subTest(conclusions=conclusions):
                view = family_view(conclusions)
                self.module.hydrate_effective_checks(view)
                with self.assertRaisesRegex(self.module.VerificationError, "native producer did not pass"):
                    self.module.verify_effective_checks(view)
        source = Path(VERIFY).read_text()
        pr_family = source[source.index("def verify_pr_family"):source.index("def verify_docs_workflow_relation")]
        self.assertIn("    hydrate_effective_checks(view)\n    verify_effective_checks(view)\n", pr_family)


class PRVerifierContractTests(unittest.TestCase):
    """Offline contracts for the PR-family and completion CLI/entry points; full chains live in ci-pr-proof.test.sh."""

    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_pr", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def test_empty_null_and_wrongly_labeled_pr_inputs_never_verify(self):
        for evidence in (None, {}, [], {"schema_version": "sigra.phase253.pr-proof-evidence/v1"},
                         {"schema_version": "sigra.phase253.pr-proof-evidence/v1", "family": "normal", "transport_ledger": None},
                         {"schema_version": "sigra.phase253.pr-proof-evidence/v1", "family": "normal",
                          "transport_ledger": {"schema_version": "sigra.phase253.http-ledger/v2", "transactions": []},
                          "allocation_base64": ""}):
            with self.subTest(evidence=evidence):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_pr_family(evidence, "normal")
        for family in ("both", "Normal", "normal ", "docs_only", None):
            with self.subTest(family=family):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_pr_family({"schema_version": "sigra.phase253.pr-proof-evidence/v1", "family": family}, family)

    def test_253_102_normal_head_is_one_of_the_four_candidate_names_and_docs_refs_stay_exact(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("publisher_for_pr_heads", ROOT / "scripts/ci/ci-git-publication.py")
        publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(publisher)
        self.assertEqual(set(self.module.PR_NORMAL_HEADS), {pair["candidate"] for pair in publisher.REF_PAIRS.values()})
        self.assertEqual(set(self.module.PR_NORMAL_HEADS),
                         {"gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-r9-candidate",
                          "gsd/253-replan-r10-candidate"})
        for head in ("gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-r9-candidate",
                     "gsd/253-replan-r10-candidate"):
            with self.subTest(accepted=head):
                self.module.require_pr_refs("normal", head, "main")
        self.module.require_pr_refs("docs-only", "gsd/253-replan-docs-head", "gsd/253-replan-docs-base")
        refused = [("normal", "gsd/253-replan-fixture", "main"), ("normal", "gsd/253-replan-r8-fixture", "main"),
                   ("normal", "gsd/253-replan-r11-candidate", "main"), ("normal", "refs/heads/gsd/253-replan-r8-candidate", "main"),
                   ("normal", "gsd/253-replan-r9-fixture", "main"), ("normal", "gsd/253-replan-r9-candidate", "gsd/253-replan-docs-base"),
                   ("docs-only", "gsd/253-replan-r9-candidate", "gsd/253-replan-docs-base"),
                   ("normal", "gsd/253-replan-docs-head", "main"), ("normal", "gsd/253-replan-r8-candidate", "gsd/253-replan-docs-base"),
                   ("normal", None, "main"), ("docs-only", "gsd/253-replan-r8-candidate", "gsd/253-replan-docs-base"),
                   ("docs-only", "gsd/253-replan-candidate", "gsd/253-replan-docs-base"),
                   ("docs-only", "gsd/253-replan-docs-head", "main")]
        for family, head, base in refused:
            with self.subTest(refused=(family, head, base)):
                with self.assertRaisesRegex(self.module.VerificationError, "frozen PR head/base refs are not the exact proof refs"):
                    self.module.require_pr_refs(family, head, base)
        source = Path(VERIFY).read_text()
        pr_family = source[source.index("def verify_pr_family"):source.index("def verify_docs_workflow_relation")]
        self.assertIn("require_pr_refs(family, head_ref, base_ref)", pr_family)

    def test_253_119_the_r10_candidate_is_a_normal_head_and_nothing_else_r10_is_accepted(self):
        self.assertEqual(len(self.module.PR_NORMAL_HEADS), 4)
        self.assertEqual(len(set(self.module.PR_NORMAL_HEADS)), 4)
        self.module.require_pr_refs("normal", "gsd/253-replan-r10-candidate", "main")
        self.assertEqual(self.module.PR_DOCS_REFS, ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base"))
        refused = [("normal", "gsd/253-replan-r11-candidate", "main"), ("normal", "gsd/253-replan-r10-fixture", "main"),
                   ("normal", "gsd/253-replan-r10-candidate", "gsd/253-replan-docs-base"),
                   ("docs-only", "gsd/253-replan-r10-candidate", "gsd/253-replan-docs-base"),
                   ("docs-only", "gsd/253-replan-docs-head", "gsd/253-replan-r10-candidate"),
                   ("normal", "refs/heads/gsd/253-replan-r10-candidate", "main"), ("normal", "gsd/253-replan-r10-candidate ", "main"),
                   ("normal", "gsd/253-replan-R10-candidate", "main"), ("normal", "gsd/253-replan-r1-candidate", "main")]
        for family, head, base in refused:
            with self.subTest(refused=(family, head, base)):
                with self.assertRaisesRegex(self.module.VerificationError, "frozen PR head/base refs are not the exact proof refs"):
                    self.module.require_pr_refs(family, head, base)

    def test_253_111_the_dryrun_window_marker_never_matches_a_real_window_id(self):
        phase = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
        real = set()
        for name in ("253-LOAD-RECOVERY-CANARY-HTTP-LEDGER.json", "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R7.json",
                     "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json", "253-LOAD-RECOVERY-CANARY-ALLOCATION.json",
                     "253-LOAD-RECOVERY-CANARY-ALLOCATION-R7.json", "253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json"):
            real.add(json.loads((phase / name).read_text())["window_id"])
        self.assertEqual(real, {"253-92-canary-window-1", "253-97-canary-window-1", "253-104-canary-window-1"})
        # Plan-named windows put digits after "253-"; the marker puts a letter there, so no plan-named window can match.
        for window in sorted(real) + ["253-113-canary-window-1", "253-113-pr-window-1", "253-dryrun", "253-DRYRUN-x", "x-253-dryrun-y"]:
            with self.subTest(window=window):
                self.assertFalse(self.module.dryrun_window({"origin": {"window_id": window}, "transport_ledger": {"window_id": window}}))
        # Positive control: the marker itself and the dry-run harness prefix are labelled.
        for window in ("253-dryrun-x", "253-dryrun-live-policy-123"):
            with self.subTest(marker=window):
                self.assertTrue(self.module.dryrun_window({"origin": {"window_id": window}}))
                self.assertTrue(self.module.dryrun_window({"transport_ledger": {"window_id": window}}))

    def test_pr_cli_requires_known_modes_and_both_evidence_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.json"
            path.write_text("{}")
            for extra in (["--mode", "pr", "--family", "normal"], ["--mode", "pr", "--family", "both"],
                          ["--mode", "pr", "--family", "docs-only"], ["--mode", "completion", "--require-accepted"],
                          ["--mode", "pr", "--family", "nonsense"]):
                with self.subTest(extra=extra):
                    result = subprocess.run(["python3", str(VERIFY), "--evidence", str(path), *extra], text=True, capture_output=True)
                    self.assertNotEqual(result.returncode, 0)

    def test_the_five_required_names_are_exact_utf8_byte_strings(self):
        names = self.module.REQUIRED_NAMES
        self.assertEqual(len(names), 5)
        self.assertEqual(len(set(names)), 5)
        for name in names:
            self.assertEqual(name, name.encode("utf-8").decode("utf-8"))
            self.assertEqual(name, name.strip())
            self.assertTrue(name.isascii())


class LivePRTransportHostTests(unittest.TestCase):
    """253-110: the live side of verify_pr_transport's host rule and of api_view, offline."""

    BLOB = "productionresultssa17.blob.core.windows.net"

    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_live_pr", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def live_evidence(self, hosts=("api.github.com", "api.github.com", BLOB)):
        transport = self.module.transport_module()
        allocation = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "253-114-pr-window-1",
                      "source_sha256": "e" * 64, "max_requests": 120, "max_elapsed_seconds": 3600,
                      "max_response_bytes": 4 * 1024 * 1024, "max_pages": 3, "max_hops": 2, "repository": "szTheory/sigra",
                      "mode": "live", "allocation_kind": "production",
                      "download_hosts": ["pipelines.actions.githubusercontent.com", self.BLOB],
                      "category_limits": dict(transport.PRODUCTION_CATEGORY_LIMITS)}
        raw = json.dumps(allocation).encode()
        shapes = [("rate_limit", "preflight", None, None, 200), ("artifact_zip", "artifact_downloads", 0, "g-1", 302),
                  ("artifact_zip", "artifact_downloads", 1, "g-1", 200)]
        transactions = []
        for sequence, ((route, category, hop, group, status), host) in enumerate(zip(shapes, hosts), 1):
            url = f"https://{host}/r/{sequence}" + ("?[REDACTED]" if hop else "")
            transactions.append({"sequence": sequence, "state": "complete", "actual_status": status, "method": "GET",
                                 "route_id": route, "category": category, "family": "shared", "host": host, "url": url,
                                 "url_sha256": hashlib.sha256(url.encode()).hexdigest(), "page_ordinal": None,
                                 "hop_ordinal": hop, "request_group": group, "window_id": allocation["window_id"],
                                 "source_sha256": allocation["source_sha256"], "response_body_base64": "",
                                 "response_sha256": hashlib.sha256(b"").hexdigest(), "scrubbed_response_bytes": 0})
        return {"repository": "szTheory/sigra", "synthetic": False, "server_journal": None,
                "allocation_base64": base64.b64encode(raw).decode(),
                "transport_ledger": {"schema_version": "sigra.phase253.http-ledger/v2", "window_id": allocation["window_id"],
                                     "source_sha256": allocation["source_sha256"], "terminal_stop": None,
                                     "allocation_sha256": hashlib.sha256(raw).hexdigest(), "transactions": transactions}}

    def test_a_live_pr_ledger_on_api_github_com_and_a_frozen_download_host_verifies(self):
        allocation, counts = self.module.verify_pr_transport(self.live_evidence())
        self.assertEqual((allocation["mode"], counts), ("live", {"preflight": 1, "artifact_downloads": 2}))

    def test_a_live_pr_transaction_on_any_other_host_is_rejected(self):
        for label, hosts in {
            "untrusted API-side host": ("evil.example.com", "api.github.com", self.BLOB),
            "untrusted redirect host": ("api.github.com", "api.github.com", "evil.example.com"),
            "policy-trusted host absent from download_hosts": ("api.github.com", "api.github.com",
                                                              "productionresultssa41.blob.core.windows.net"),
            "the hermetic local origin": ("localhost", "api.github.com", self.BLOB),
        }.items():
            with self.subTest(case=label):
                with self.assertRaisesRegex(self.module.VerificationError, "live transaction used a host outside"):
                    self.module.verify_pr_transport(self.live_evidence(hosts))

    def test_a_live_pr_ledger_labelled_synthetic_is_rejected(self):
        evidence = self.live_evidence()
        evidence["synthetic"] = True
        with self.assertRaisesRegex(self.module.VerificationError, "synthetic label must match"):
            self.module.verify_pr_transport(evidence)

    def test_api_view_returns_live_evidence_unchanged_and_rewrites_only_hermetic_evidence(self):
        local = "https://localhost:4555/repos/szTheory/sigra/rate_limit"
        for channel in (None, "github-api"):
            with self.subTest(channel=channel):
                evidence = {"origin": {"channel": channel}, "transport_ledger": {"transactions": [{"url": local}]}}
                self.assertIs(self.module.api_view(evidence), evidence)
                self.assertEqual(evidence["transport_ledger"]["transactions"][0]["url"], local)
        hermetic = {"origin": {"channel": "hermetic-https"}, "transport_ledger": {"transactions": [{"url": local}]}}
        view = self.module.api_view(hermetic)
        self.assertEqual(view["transport_ledger"]["transactions"][0]["url"], "https://api.github.com/repos/szTheory/sigra/rate_limit")
        self.assertEqual(hermetic["transport_ledger"]["transactions"][0]["url"], local, "the original is never mutated")


class DocsCommitMessageToleranceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_message", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def test_only_the_frozen_message_or_one_stripped_trailing_newline_matches(self):
        frozen = "Phase 253 docs-only probe head\n"
        for server_message in (frozen, frozen[:-1]):
            self.assertTrue(self.module.commit_message_matches(server_message, frozen), server_message)
        for server_message in (frozen + "\n", frozen[:-2], frozen[:-1] + "\r\n", frozen[:-1] + " ", "", None, 5, [frozen], "other\n"):
            self.assertFalse(self.module.commit_message_matches(server_message, frozen), repr(server_message))


class DocsWorkflowRelationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_docs", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def test_docs_base_may_only_add_the_exact_named_branch_allowance(self):
        candidate = b"name: CI\non:\n  push:\n    branches: [main]\n  pull_request:\n    branches: [main]\njobs: {}\n"
        docs = candidate.replace(b"  pull_request:\n    branches: [main]\n", b"  pull_request:\n    branches: [main, gsd/253-replan-docs-*]\n")
        self.module.verify_docs_workflow_relation(candidate, docs)
        for label, broken in {
            "identical": candidate, "wrong glob": docs.replace(b"docs-*", b"*"), "extra edit": docs + b"# edit\n",
            "push widened": docs.replace(b"  push:\n    branches: [main]", b"  push:\n    branches: [main, gsd/253-replan-docs-*]"),
            "empty": b"", "case variant": docs.replace(b"gsd/", b"GSD/"),
        }.items():
            with self.subTest(label):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_docs_workflow_relation(candidate, broken)
        for candidate_bad in (b"", b"name: CI\n", candidate + candidate, "not bytes"):
            with self.subTest(candidate=candidate_bad):
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_docs_workflow_relation(candidate_bad, docs)


class CompletionContractTests(unittest.TestCase):
    """Accepted-only completion with stubbed sub-verifiers; each stub's own contracts are tested separately."""

    LINKS = ("phase252_replay", "phase252_diagnosis", "load_controls", "load_acceptance", "publication", "canary", "pr_normal", "pr_docs_only")

    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_completion", VERIFY)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.calls = []

        class Done:
            returncode = 0
            stderr = ""
            stdout = ""

        class FakeSubprocess:
            @staticmethod
            def run(argv, **_kw):
                self.calls.append(argv)
                return Done()

        self.module.subprocess = FakeSubprocess
        self.module.verify_pr_pair = lambda normal, docs: {"accepted_live": not normal.get("synthetic", False), "status": "stub"}
        self.module.verify_canary_matrix = lambda canary: {"status": "stub"}
        self.documents = {
            "phase252_replay": {"original": "replay"}, "phase252_diagnosis": {"original": "diagnosis"},
            "load_controls": {"controls": 22}, "load_acceptance": {"assessment": {"kind": "cause_repair", "cause": "loader race"}},
            "publication": {"receipt": True},
            "canary": {"origin": {"window_id": "canary-window"}, "transport_ledger": {"allocation_sha256": "a" * 64}},
            "pr_normal": {"transport_ledger": {"window_id": "pr-window", "allocation_sha256": "b" * 64}},
            "pr_docs_only": {"transport_ledger": {"window_id": "pr-window", "allocation_sha256": "b" * 64}},
        }

    def evidence(self, omit=(), **extra):
        links = {}
        for key, document in self.documents.items():
            if key in omit:
                continue
            path = self.root / f"{key}.json"
            path.write_text(json.dumps(document))
            links[key] = {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        return {"schema_version": "sigra.phase253.completion-evidence/v1", "repository": "szTheory/sigra", "links": links, **extra}

    def verify(self, evidence, require_accepted=False, code=0):
        return self.module.verify_completion(evidence, require_accepted=require_accepted, root=self.root,
                                             load_checker=lambda kind, path: (code, "stub checker"))

    def test_old_failures_chronology_order_and_http_count_stay_literal_limitations(self):
        for omit in ((), ("canary",)):
            record = self.verify(self.evidence(omit=omit))
            text = " ".join(record["limitations"])
            self.assertEqual(len(record["limitations"]), 4)
            for needle in ("remain failures", "chronology", "execution order", "38347679431", "unknown"):
                self.assertIn(needle, text)
            self.assertNotIn("accepted_by", text)

    def test_every_linked_live_proof_present_and_reopened_is_accepted(self):
        result = self.verify(self.evidence(), require_accepted=True)
        self.assertEqual(result["status"], "accepted")
        self.assertEqual(result["gaps"], [])
        self.assertEqual(result["phase_verification"], "not_started")
        self.assertEqual(result["requirements"], {"CIREL-01": "accepted", "CIREL-02": "accepted"})

    def test_each_missing_proof_leaves_an_honest_open_record_and_fails_strict_completion(self):
        for key in self.LINKS:
            with self.subTest(missing=key):
                evidence = self.evidence(omit=(key,))
                record = self.verify(evidence)
                self.assertEqual(record["status"], "open")
                self.assertTrue(any(gap.startswith("missing:") for gap in record["gaps"]))
                self.assertEqual(record["requirements"], {"CIREL-01": "open", "CIREL-02": "open"})
                with self.assertRaises(self.module.VerificationError):
                    self.verify(evidence, require_accepted=True)

    def test_embedded_acceptance_claims_are_ignored_and_contradictions_rejected(self):
        for claim in ({"accepted": True}, {"status": "accepted"}, {"status": "complete"}, {"status": "passed"}):
            with self.subTest(claim=claim):
                with self.assertRaises(self.module.VerificationError):
                    self.verify(self.evidence(omit=("canary",), **claim))
        self.assertEqual(self.verify(self.evidence(accepted=True))["status"], "accepted")  # claim is irrelevant when every link verifies

    def test_hash_mismatch_unreadable_and_malformed_links_are_errors_not_open_records(self):
        evidence = self.evidence()
        evidence["links"]["canary"]["sha256"] = "0" * 64
        with self.assertRaises(self.module.VerificationError):
            self.verify(evidence)
        evidence = self.evidence()
        (self.root / "canary.json").unlink()
        with self.assertRaises(self.module.VerificationError):
            self.verify(evidence)
        for bad in ({"path": "x"}, {"path": "x", "sha256": "z"}, "x", {"path": 1, "sha256": "0" * 64}):
            with self.subTest(bad=bad):
                evidence = self.evidence()
                evidence["links"]["canary"] = bad
                with self.assertRaises(self.module.VerificationError):
                    self.verify(evidence)
        with self.assertRaises(self.module.VerificationError):
            self.verify(dict(self.evidence(), links={"unknown": {"path": "x", "sha256": "0" * 64}}))
        with self.assertRaises(self.module.VerificationError):
            self.verify({"schema_version": "other"})

    def test_strict_native_checker_failure_and_empty_records_reject(self):
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence(), code=1)
        self.documents["phase252_replay"] = {}
        (self.root / "phase252_replay.json").write_text("{}")
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence())

    def test_cause_less_no_flake_and_causeless_acceptance_are_rejected(self):
        for assessment in (
            {"kind": "justified_no_flake", "selected_failures": ["a", "b"], "explained_failures": ["a"], "cause": None},
            {"kind": "justified_no_flake", "selected_failures": [], "explained_failures": [], "cause": None},
            {"kind": "justified_no_flake", "selected_failures": ["a"], "explained_failures": ["a"], "cause": "invented"},
            {"kind": "cause_repair", "cause": ""},
            {"kind": "cause_repair"},
            {},
        ):
            with self.subTest(assessment=assessment):
                self.documents["load_acceptance"] = {"assessment": assessment}
                with self.assertRaises(self.module.VerificationError):
                    self.verify(self.evidence(), require_accepted=True)
        self.documents["load_acceptance"] = {"assessment": {"kind": "justified_no_flake", "selected_failures": ["a"], "explained_failures": ["a", "b"], "cause": None}}
        self.assertEqual(self.verify(self.evidence(), require_accepted=True)["status"], "accepted")

    def test_synthetic_pr_evidence_and_budget_resets_cannot_be_accepted(self):
        self.documents["pr_normal"]["synthetic"] = True
        record = self.verify(self.evidence())
        self.assertEqual(record["status"], "open")
        self.assertTrue(any(gap.startswith("synthetic:pr") for gap in record["gaps"]))
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence(), require_accepted=True)
        self.documents["pr_normal"].pop("synthetic")
        self.documents["canary"]["origin"]["window_id"] = "pr-window"
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence())
        self.documents["canary"]["origin"]["window_id"] = "canary-window"
        self.documents["canary"]["transport_ledger"]["allocation_sha256"] = "b" * 64
        self.assertEqual(self.verify(self.evidence())["status"], "accepted", "distinct windows are separate allocations, not resets")

    def test_frozen_source_links_are_reopened_and_must_still_match(self):
        bound = self.root / "bound-budget.md"
        bound.write_text("frozen budget")
        digest = hashlib.sha256(b"frozen budget").hexdigest()
        self.documents["pr_normal"]["freeze"] = {"bound_documents": [{"path": str(bound), "sha256": digest}]}
        self.assertEqual(self.verify(self.evidence(), require_accepted=True)["status"], "accepted")
        bound.write_text("changed after freeze")
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence())
        bound.unlink()
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence())

    def test_a_hermetic_canary_link_is_a_synthetic_gap_and_never_makes_cirel_02_accepted(self):
        self.documents["canary"]["origin"]["channel"] = "hermetic-https"
        record = self.verify(self.evidence())
        self.assertEqual(record["status"], "open")
        self.assertTrue(any(gap.startswith("synthetic:canary") for gap in record["gaps"]), record["gaps"])
        self.assertEqual(record["requirements"]["CIREL-02"], "open")
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence(), require_accepted=True)
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence(accepted=True))  # an embedded claim cannot override the synthetic gap
        self.documents["canary"]["origin"]["channel"] = "github-api"
        self.assertEqual(self.verify(self.evidence())["status"], "accepted", "the live channel is unaffected")

    def test_publication_receipt_rejection_and_one_sided_pr_evidence_fail_closed(self):
        class Bad:
            returncode = 1
            stderr = "receipt rejected"
            stdout = ""
        self.module.subprocess = type("Fake", (), {"run": staticmethod(lambda argv, **_kw: Bad())})
        with self.assertRaises(self.module.VerificationError):
            self.verify(self.evidence())
        self.setUp()
        record = self.verify(self.evidence(omit=("pr_docs_only",)))
        self.assertEqual(record["status"], "open")
        self.assertTrue(any("pr_pair" in gap for gap in record["gaps"]))


class CompletionLoadLinkBindingTests(unittest.TestCase):
    """The production checker binds the two load links to the R5 artifacts; the injected-checker tests above stay unchanged."""

    R5 = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R5.json"
    ACCEPT = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json"
    HALTED = (
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R3.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R4.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-40-NATIVE-CONTROLS-EVIDENCE.json",
    )

    setUpClass = classmethod(CompletionContractTests.setUpClass.__func__)
    evidence = CompletionContractTests.evidence
    verify = CompletionContractTests.verify

    def setUp(self):
        CompletionContractTests.setUp(self)
        self.checked = []
        self.module._default_checker = lambda kind, path: (self.checked.append((kind, path)) or (0, "recorded"))

    def link_at(self, relative):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"bound": relative}))
        return {"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def production(self, controls=None, acceptance=None):
        evidence = self.evidence(omit=("load_controls", "load_acceptance"))
        evidence["links"]["load_controls"] = self.link_at(controls or self.R5)
        document = {"assessment": {"kind": "cause_repair", "cause": "loader race"}}
        path = self.root / (acceptance or self.ACCEPT)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(document))
        evidence["links"]["load_acceptance"] = {"path": acceptance or self.ACCEPT, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        return evidence

    def run_production(self, evidence):
        return self.module.verify_completion(evidence, require_accepted=True, root=self.root)

    def test_the_r5_native_evidence_and_the_acceptance_evidence_are_accepted_through_the_production_checker(self):
        result = self.run_production(self.production())
        self.assertEqual(result["status"], "accepted")
        self.assertEqual([kind for kind, _ in self.checked], ["load_controls", "load_acceptance"])

    def test_halted_v1_r2_r3_r4_and_253_40_native_evidence_is_rejected_before_the_checker_runs(self):
        for halted in self.HALTED:
            with self.subTest(path=halted):
                self.checked.clear()
                with self.assertRaises(self.module.VerificationError) as caught:
                    self.run_production(self.production(controls=halted))
                self.assertIn("load_controls must link the R5 native evidence", str(caught.exception))
                self.assertEqual(self.checked, [])

    def test_the_acceptance_link_is_bound_to_the_acceptance_evidence_path(self):
        with self.assertRaises(self.module.VerificationError) as caught:
            self.run_production(self.production(acceptance=".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/other-acceptance.json"))
        self.assertIn("load_acceptance must link", str(caught.exception))
        self.assertEqual(self.checked, [])

    def test_an_absolute_path_that_resolves_to_a_different_file_is_rejected(self):
        evidence = self.production()
        decoy = self.root / "decoy.json"
        decoy.write_text("{\"x\": 1}")
        evidence["links"]["load_controls"] = {"path": str(decoy), "sha256": hashlib.sha256(decoy.read_bytes()).hexdigest()}
        with self.assertRaises(self.module.VerificationError):
            self.run_production(evidence)

    def test_load_checks_argv_is_unchanged(self):
        self.assertEqual(self.module.LOAD_CHECKS, {
            "load_controls": ["--verify-load-recovery", "{path}", "--stage", "complete"],
            "load_acceptance": ["--verify-load-acceptance", "{path}", "--require-target-accepted"],
        })

    def test_an_injected_checker_keeps_its_tmp_path_fixtures(self):
        self.assertEqual(self.verify(self.evidence(), require_accepted=True)["status"], "accepted")


class CompletionDispositionTests(unittest.TestCase):
    """253-90: an honest, human-approved not_reproduced disposition is verifiable as 'dispositioned', never as 'accepted'."""

    P = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
    DISPOSITION = P + "253-LOAD-RECOVERY-TARGET-DISPOSITION.json"
    APPROVAL = P + "253-LOAD-RECOVERY-TARGET-DISPOSITION-APPROVAL.json"
    GAP = "disposition:CIREL-01:not_reproduced (Jon-approved disposition; target neither reproduced nor fixed)"

    setUpClass = classmethod(CompletionContractTests.setUpClass.__func__)
    evidence = CompletionContractTests.evidence

    def setUp(self):
        CompletionContractTests.setUp(self)
        self.documents["load_acceptance"] = {"target_status": "open", "historical_cause": {"status": "diagnosis_incomplete"}}
        self.documents["load_target_disposition"] = {"status": "not_reproduced"}
        self.documents["load_target_disposition_approval"] = {"decision": "approve"}
        self.kinds = []
        self.strict = 3
        self.disposition = 0

    def checker(self, kind, path):
        self.kinds.append(kind)
        if kind == "load_acceptance":
            return self.strict, "strict stub"
        if kind == "load_target_disposition":
            return self.disposition, "disposition stub"
        return 0, "stub"

    def run_completion(self, evidence, **flags):
        return self.module.verify_completion(evidence, root=self.root, load_checker=self.checker, **flags)

    def dispositioned(self, **extra):
        return self.evidence(**extra)

    def test_the_disposition_route_is_dispositioned_not_accepted(self):
        result = self.run_completion(self.dispositioned(), require_dispositioned=True)
        self.assertEqual(result["status"], "dispositioned")
        self.assertTrue(result["dispositioned"])
        self.assertEqual(result["gaps"], [self.GAP])
        self.assertEqual(result["requirements"], {"CIREL-01": "partial_not_reproduced", "CIREL-02": "accepted"})
        self.assertEqual(result["phase_verification"], "not_started")
        self.assertEqual(self.kinds[-2:], ["load_acceptance", "load_target_disposition"])
        self.assertEqual(len(result["limitations"]), 5)
        self.assertIn("not reproduced", result["limitations"][-1])
        self.assertIn("CIREL-01 is partial", result["limitations"][-1])

    def test_require_accepted_still_fails_on_a_dispositioned_record(self):
        with self.assertRaises(self.module.VerificationError) as caught:
            self.run_completion(self.dispositioned(), require_accepted=True)
        self.assertIn("disposition:CIREL-01", str(caught.exception))

    def test_without_a_flag_the_record_stays_open_with_honest_requirement_statuses(self):
        result = self.run_completion(self.dispositioned())
        self.assertEqual(result["status"], "open")
        self.assertEqual(result["requirements"], {"CIREL-01": "partial_not_reproduced", "CIREL-02": "accepted"})

    def test_strict_rejection_without_disposition_links_raises_exactly_as_before(self):
        with self.assertRaises(self.module.VerificationError) as caught:
            self.run_completion(self.evidence(omit=("load_target_disposition", "load_target_disposition_approval")), require_dispositioned=True)
        self.assertIn("strict native checker rejected load_acceptance", str(caught.exception))
        self.assertNotIn("load_target_disposition", self.kinds)

    def test_a_single_disposition_link_is_rejected(self):
        for omit in ("load_target_disposition", "load_target_disposition_approval"):
            with self.subTest(omit=omit):
                with self.assertRaises(self.module.VerificationError):
                    self.run_completion(self.evidence(omit=(omit,)), require_dispositioned=True)

    def test_strict_exit_other_than_three_is_never_dispositioned(self):
        for code in (1, 2, 127):
            with self.subTest(code=code):
                self.strict = code
                with self.assertRaises(self.module.VerificationError):
                    self.run_completion(self.dispositioned(), require_dispositioned=True)

    def test_a_rejected_disposition_raises(self):
        self.disposition = 3
        with self.assertRaises(self.module.VerificationError) as caught:
            self.run_completion(self.dispositioned(), require_dispositioned=True)
        self.assertIn("disposition", str(caught.exception))

    def test_the_disposition_route_needs_an_open_diagnosis_incomplete_acceptance_record(self):
        for document in ({"target_status": "accepted", "historical_cause": {"status": "diagnosis_incomplete"}},
                         {"target_status": "open", "historical_cause": {"status": "demonstrated"}},
                         {"target_status": "open"}, {"historical_cause": {"status": "diagnosis_incomplete"}}):
            with self.subTest(document=document):
                self.documents["load_acceptance"] = document
                with self.assertRaises(self.module.VerificationError):
                    self.run_completion(self.dispositioned(), require_dispositioned=True)

    def test_embedded_acceptance_claims_on_a_dispositioned_record_are_contradicted(self):
        for claim in ({"accepted": True}, {"status": "accepted"}, {"status": "complete"}, {"status": "passed"}):
            with self.subTest(claim=claim):
                with self.assertRaises(self.module.VerificationError):
                    self.run_completion(self.dispositioned(**claim), require_dispositioned=True)

    def test_a_missing_or_synthetic_link_blocks_dispositioned_and_leaves_cirel_02_open(self):
        for key in CompletionContractTests.LINKS:
            if key == "load_acceptance":
                continue
            with self.subTest(missing=key):
                evidence = self.evidence(omit=(key,))
                record = self.run_completion(evidence)
                self.assertEqual(record["requirements"]["CIREL-02"], "open")
                self.assertEqual(record["requirements"]["CIREL-01"], "partial_not_reproduced")
                with self.assertRaises(self.module.VerificationError):
                    self.run_completion(evidence, require_dispositioned=True)
        self.documents["pr_normal"]["synthetic"] = True
        record = self.run_completion(self.evidence())
        self.assertEqual(record["requirements"]["CIREL-02"], "open")
        with self.assertRaises(self.module.VerificationError):
            self.run_completion(self.evidence(), require_dispositioned=True)

    def test_the_strict_accepted_route_is_unchanged_and_ignores_unused_disposition_links(self):
        self.strict = 0
        self.documents["load_acceptance"] = {"assessment": {"kind": "cause_repair", "cause": "loader race"}}
        result = self.run_completion(self.evidence(), require_dispositioned=True)
        self.assertEqual(result["status"], "accepted")
        self.assertEqual(result["gaps"], [])
        self.assertFalse(result.get("dispositioned", False))
        self.assertEqual(result["requirements"], {"CIREL-01": "accepted", "CIREL-02": "accepted"})
        self.assertEqual(len(result["limitations"]), 4)
        self.assertNotIn("load_target_disposition", self.kinds)
        self.assertEqual(self.run_completion(self.evidence(), require_accepted=True)["status"], "accepted")

    def test_unknown_link_keys_are_still_rejected(self):
        with self.assertRaises(self.module.VerificationError):
            self.run_completion(dict(self.evidence(), links={**self.evidence()["links"], "other": {"path": "x", "sha256": "0" * 64}}))

    def test_the_disposition_checker_argv_is_the_runner_predicate_and_the_strict_argv_is_untouched(self):
        self.assertEqual(self.module.DISPOSITION_CHECK, ["--verify-load-acceptance", "{path}", "--require-target-disposition"])
        self.assertEqual(self.module.LOAD_CHECKS["load_acceptance"], ["--verify-load-acceptance", "{path}", "--require-target-accepted"])
        self.assertEqual(set(self.module.DISPOSITION_PATHS), {"load_target_disposition", "load_target_disposition_approval"})
        self.assertEqual(self.module.DISPOSITION_PATHS["load_target_disposition"], self.DISPOSITION)
        self.assertEqual(self.module.DISPOSITION_PATHS["load_target_disposition_approval"], self.APPROVAL)

    def test_with_the_production_checker_the_disposition_links_are_bound_to_the_reviewed_paths(self):
        self.module._default_checker = lambda kind, path: (self.kinds.append(kind) or (3 if kind == "load_acceptance" else 0, "recorded"))
        evidence = self.production_evidence()
        result = self.module.verify_completion(evidence, require_dispositioned=True, root=self.root)
        self.assertEqual(result["status"], "dispositioned")
        for key, wrong in (("load_target_disposition", self.APPROVAL), ("load_target_disposition_approval", self.DISPOSITION),
                           ("load_target_disposition", "elsewhere/disposition.json")):
            with self.subTest(key=key, wrong=wrong):
                self.kinds.clear()
                evidence = self.production_evidence(**{key: wrong})
                with self.assertRaises(self.module.VerificationError) as caught:
                    self.module.verify_completion(evidence, require_dispositioned=True, root=self.root)
                self.assertIn("must link the reviewed", str(caught.exception))
                self.assertEqual(self.kinds, [])

    def production_evidence(self, **paths):
        evidence = self.evidence(omit=("load_controls", "load_acceptance", "load_target_disposition", "load_target_disposition_approval"))
        wanted = {"load_controls": CompletionLoadLinkBindingTests.R5, "load_acceptance": CompletionLoadLinkBindingTests.ACCEPT,
                  "load_target_disposition": self.DISPOSITION, "load_target_disposition_approval": self.APPROVAL, **paths}
        for key, relative in wanted.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            document = self.documents.get(key, {"bound": relative}) if key != "load_controls" else {"bound": relative}
            path.write_text(json.dumps(document))
        for key, relative in wanted.items():
            evidence["links"][key] = {"path": relative, "sha256": hashlib.sha256((self.root / relative).read_bytes()).hexdigest()}
        return evidence

    def test_the_cli_flags_are_mutually_exclusive(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "completion.json"
            path.write_text("{}")
            result = subprocess.run(["python3", "-B", str(VERIFY), "--evidence", str(path), "--mode", "completion",
                                     "--require-accepted", "--require-dispositioned"], text=True, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("not allowed with", result.stderr)
            result = subprocess.run(["python3", "-B", str(VERIFY), "--evidence", str(path), "--mode", "completion", "--require-dispositioned"],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("completion evidence schema", result.stderr)


class CompletionDispositionEndToEndTests(unittest.TestCase):
    """The real runner (no injected checker) re-opens the real committed 253-89 disposition and approval through a subprocess."""

    P = CompletionDispositionTests.P

    def setUp(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_dispo_e2e", VERIFY)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        if not (ROOT / CompletionDispositionTests.DISPOSITION).exists():
            self.skipTest("the committed 253-89 disposition records are not part of this checkout")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tmp_root = Path(self.tmp.name)
        real = subprocess

        class Done:
            returncode = 0
            stderr = ""
            stdout = ""

        class Delegating:
            CalledProcessError = real.CalledProcessError
            TimeoutExpired = real.TimeoutExpired

            @staticmethod
            def run(argv, **kw):
                if any(str(part).endswith("ci-registration-recovery.mjs") for part in argv):
                    return real.run(argv, **kw)
                return Done()

        self.module.subprocess = Delegating
        self.module.verify_pr_pair = lambda normal, docs: {"accepted_live": True, "status": "stub"}
        self.module.verify_canary_matrix = lambda canary: {"status": "stub"}

    def link(self, relative):
        data = (ROOT / relative).read_bytes()
        return {"path": relative, "sha256": hashlib.sha256(data).hexdigest()}

    def stub_link(self, name, document):
        path = self.tmp_root / f"{name}.json"
        path.write_text(json.dumps(document))
        return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def evidence(self, with_disposition=True):
        links = {
            "phase252_replay": self.stub_link("replay", {"original": "replay"}),
            "phase252_diagnosis": self.stub_link("diagnosis", {"original": "diagnosis"}),
            "load_controls": self.link(CompletionLoadLinkBindingTests.R5),
            "load_acceptance": self.link(CompletionLoadLinkBindingTests.ACCEPT),
            "publication": self.stub_link("publication", {"receipt": True}),
            "canary": self.stub_link("canary", {"origin": {"window_id": "canary-window"}, "transport_ledger": {"allocation_sha256": "a" * 64}}),
            "pr_normal": self.stub_link("normal", {"transport_ledger": {"window_id": "pr-window", "allocation_sha256": "b" * 64}}),
            "pr_docs_only": self.stub_link("docs", {"transport_ledger": {"window_id": "pr-window", "allocation_sha256": "b" * 64}}),
        }
        if with_disposition:
            links["load_target_disposition"] = self.link(CompletionDispositionTests.DISPOSITION)
            links["load_target_disposition_approval"] = self.link(CompletionDispositionTests.APPROVAL)
        return {"schema_version": "sigra.phase253.completion-evidence/v1", "repository": "szTheory/sigra", "links": links}

    def test_the_real_runner_proves_the_disposition_route_and_strict_acceptance_still_rejects(self):
        result = self.module.verify_completion(self.evidence(), require_dispositioned=True)
        self.assertEqual(result["status"], "dispositioned")
        self.assertEqual(result["requirements"], {"CIREL-01": "partial_not_reproduced", "CIREL-02": "accepted"})
        with self.assertRaises(self.module.VerificationError):
            self.module.verify_completion(self.evidence(), require_accepted=True)
        with self.assertRaises(self.module.VerificationError) as caught:
            self.module.verify_completion(self.evidence(with_disposition=False), require_dispositioned=True)
        self.assertIn("strict native checker rejected load_acceptance", str(caught.exception))



class DryRunWindowGuardTests(unittest.TestCase):
    """253-107: evidence on a 253-dryrun- window is synthetic everywhere and can never satisfy live acceptance."""

    DRY = "253-dryrun-108-live-policy-1"
    REAL_CANARY = "253-113-canary-window-1"
    REAL_PR = "253-114-pr-window-1"
    CANARY_MODES = (("transport", "full-pass"), ("preflight", "full-pass"), ("canary", "full-pass"),
                    ("canary", "sources"), ("canary", "matrix"))

    def setUp(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("hosted_gate_verify_dryrun_guard", VERIFY)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def canary_evidence(self, ledger_window, origin_window=None, channel=None):
        origin = {"kind": "measured-v2", "window_id": origin_window if origin_window is not None else ledger_window}
        if channel:
            origin["channel"] = channel
        return {"schema_version": "sigra.phase253.hosted-replan-evidence/v2", "repository": "szTheory/sigra",
                "origin": origin, "transport_ledger": {"window_id": ledger_window, "allocation_sha256": "a" * 64}}

    def run_main(self, evidence, mode, scenario):
        import sys
        self.module.read_replan_evidence = lambda _path: evidence
        self.module.replan_result = lambda _args, _evidence: {"status": "stub"}
        argv = sys.argv
        sys.argv = ["ci-hosted-gate-verify.py", "--evidence", "unused.json", "--mode", mode, "--scenario", scenario]
        try:
            return self.module.main()
        finally:
            sys.argv = argv

    def test_every_canary_mode_result_on_a_dryrun_window_is_synthetic_live_policy_dry_run(self):
        for ledger_window, origin_window in ((self.DRY, self.DRY), (self.DRY, "other"), ("other", self.DRY)):
            for mode, scenario in self.CANARY_MODES:
                with self.subTest(ledger=ledger_window, origin=origin_window, mode=mode, scenario=scenario):
                    result = self.run_main(self.canary_evidence(ledger_window, origin_window), mode, scenario)
                    self.assertIs(result["synthetic"], True)
                    self.assertEqual(result["channel"], "live-policy-dry-run")

    def test_hermetic_evidence_keeps_its_hermetic_https_channel(self):
        for window in (self.DRY, "253-101-dry-run-1"):
            for mode, scenario in self.CANARY_MODES:
                with self.subTest(window=window, mode=mode, scenario=scenario):
                    result = self.run_main(self.canary_evidence(window, channel="hermetic-https"), mode, scenario)
                    self.assertIs(result["synthetic"], True)
                    self.assertEqual(result["channel"], "hermetic-https")

    def test_a_real_canary_window_is_not_flagged(self):
        for window in (self.REAL_CANARY, "253-104-canary-window-1", "x-253-dryrun-1", "253-dryrun"):
            for mode, scenario in self.CANARY_MODES:
                with self.subTest(window=window, mode=mode, scenario=scenario):
                    result = self.run_main(self.canary_evidence(window), mode, scenario)
                    self.assertNotIn("synthetic", result)
                    self.assertNotIn("channel", result)

    def windowed_transport_fixture(self, window):
        evidence = V2VerifierContractTests.transport_fixture(self)
        evidence["repository"] = "szTheory/sigra"
        evidence["origin"]["window_id"] = window
        evidence["transport_ledger"]["window_id"] = window
        for group in ("transactions",):
            for record in evidence["transport_ledger"][group]:
                record["window_id"] = window
        for record in evidence["transport_receipts"] + evidence["server_journal"]:
            record["window_id"] = window
        return evidence

    def test_transport_cli_end_to_end_labels_a_dryrun_window_and_not_a_real_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            for window, flagged in ((self.DRY, True), (self.REAL_CANARY, False)):
                with self.subTest(window=window):
                    path = Path(tmp) / f"{window}.json"
                    path.write_text(json.dumps(self.windowed_transport_fixture(window)))
                    result = subprocess.run(["python3", str(VERIFY), "--mode", "transport", "--evidence", str(path)],
                                            text=True, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    output = json.loads(result.stdout)
                    self.assertEqual(output["status"], "transport_verified")
                    if flagged:
                        self.assertEqual((output.get("synthetic"), output.get("channel")), (True, "live-policy-dry-run"))
                    else:
                        self.assertNotIn("synthetic", output)

    def test_canary_matrix_result_on_a_dryrun_window_is_synthetic(self):
        module = self.module
        module.verify_transport_v2 = lambda _e: {"status": "transport_verified"}
        module.verify_canary_checks = lambda _e: {"status": "checks"}
        module.verify_sources = lambda _e: ({}, 0)
        module.verify_attempt_jobs = lambda _e: 0
        module.verify_separate_verifier = lambda _e, _count: {"status": "separate"}
        module.verify_canary_bindings = lambda _e, _scenarios, verifier=False: []
        self.assertIs(module.verify_canary_matrix(self.canary_evidence(self.DRY))["synthetic"], True)
        self.assertNotIn("synthetic", module.verify_canary_matrix(self.canary_evidence(self.REAL_CANARY)))

    def pr_documents(self, window):
        ledger = {"window_id": window, "allocation_sha256": "b" * 64, "transactions": []}
        common = {"allocation_base64": "YQ==", "freeze": {"freeze_sha256": "c" * 64}}
        return dict(common, transport_ledger=dict(ledger)), dict(common, transport_ledger=dict(ledger))

    def stub_pr_family(self):
        def family(evidence, name, capture=None):
            if capture is not None:
                capture["workflow_bytes"] = b"workflow"
            number = 1 if name == "normal" else 2
            return {"status": "pr_family_verified", "family": name, "accepted_live": True, "pr_number": number,
                    "run_id": 10 + number, "window_id": evidence["transport_ledger"]["window_id"]}
        self.module.verify_pr_family = family
        self.module.verify_docs_workflow_relation = lambda _candidate, _docs: None

    def test_pr_pair_on_a_dryrun_window_is_synthetic_even_when_both_families_look_live(self):
        self.stub_pr_family()
        result = self.module.verify_pr_pair(*self.pr_documents(self.DRY))
        self.assertEqual(result["status"], "synthetic_pr_pair_verified")
        self.assertIs(result["accepted_live"], False)
        self.assertIs(result["synthetic"], True)
        real = self.module.verify_pr_pair(*self.pr_documents(self.REAL_PR))
        self.assertEqual(real["status"], "pr_pair_verified")
        self.assertIs(real["accepted_live"], True)
        self.assertNotIn("synthetic", real)

    def test_pr_family_result_on_a_dryrun_window_is_synthetic_and_wired_into_verify_pr_family(self):
        live = {"status": "pr_family_verified", "family": "normal", "accepted_live": True, "pr_number": 1}
        for key in ("transport_ledger", "origin"):
            with self.subTest(key=key):
                labelled = self.module.dryrun_pr_result(dict(live), {key: {"window_id": self.DRY}})
                self.assertEqual((labelled["status"], labelled["accepted_live"], labelled["synthetic"]),
                                 ("synthetic_pr_family_verified", False, True))
        self.assertEqual(self.module.dryrun_pr_result(dict(live), {"transport_ledger": {"window_id": self.REAL_PR}}), live)
        source = Path(VERIFY).read_text()
        family = source[source.index("def verify_pr_family"):source.index("def verify_docs_workflow_relation")]
        self.assertIn("return dryrun_pr_result(", family)

    def completion(self):
        holder = CompletionContractTests("test_every_linked_live_proof_present_and_reopened_is_accepted")
        holder.module = self.module
        CompletionContractTests.setUp(holder)
        self.addCleanup(holder.tmp.cleanup)
        holder.documents["canary"]["origin"]["window_id"] = self.REAL_CANARY
        holder.documents["publication"] = {"receipt": True, "origin": {"window_id": "253-113-publication-window-1"}}
        for key in ("pr_normal", "pr_docs_only"):
            holder.documents[key]["transport_ledger"]["window_id"] = self.REAL_PR
        return holder

    def test_completion_gaps_every_live_link_on_a_dryrun_window(self):
        placements = {
            "canary": lambda docs: docs["canary"]["origin"].update(window_id=self.DRY),
            "publication": lambda docs: docs["publication"]["origin"].update(window_id=self.DRY),
            "pr_normal": lambda docs: docs["pr_normal"]["transport_ledger"].update(window_id=self.DRY),
            "pr_docs_only": lambda docs: docs["pr_docs_only"]["transport_ledger"].update(window_id=self.DRY),
        }
        for link, place in placements.items():
            with self.subTest(link=link):
                holder = self.completion()
                place(holder.documents)
                evidence = holder.evidence()
                record = holder.verify(evidence)
                self.assertEqual(record["status"], "open")
                self.assertIn(f"synthetic:{link}:dry-run window cannot satisfy live acceptance", record["gaps"])
                self.assertEqual(record["requirements"]["CIREL-02"], "open")
                with self.assertRaises(self.module.VerificationError):
                    holder.verify(evidence, require_accepted=True)
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_completion(evidence, require_dispositioned=True, root=holder.root,
                                                  load_checker=lambda kind, path: (0, "stub checker"))

    def test_completion_with_real_window_ids_is_not_flagged(self):
        holder = self.completion()
        record = holder.verify(holder.evidence(), require_accepted=True)
        self.assertEqual(record["status"], "accepted")
        self.assertFalse([gap for gap in record["gaps"] if "dry-run" in gap])


REGISTERED_FIXTURE = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml"
PUBLISHER = ROOT / "scripts/ci/ci-git-publication.py"
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")


def step_script(workflow, job, name):
    return next(step for step in workflow["jobs"][job]["steps"] if step.get("name") == name)["run"]


class RegisteredFixtureTests(unittest.TestCase):
    """The six-scenario registered-path fixture and its separate one-job verifier (253-91)."""

    @classmethod
    def setUpClass(cls):
        import yaml
        cls.workflow = yaml.safe_load(REGISTERED_FIXTURE.read_text())
        cls.text = REGISTERED_FIXTURE.read_text()

    def test_fixture_is_dispatch_only_read_only_and_pins_the_same_actions_as_the_superseded_fixture(self):
        self.assertEqual(self.workflow["name"], "Phase 253 Gate Canary")
        triggers = self.workflow.get("on", self.workflow.get(True))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        self.assertEqual(self.workflow["permissions"], {"contents": "read"})
        self.assertEqual(set(self.workflow["jobs"]), {"producers", "verdict", "verifier"})
        self.assertEqual(self.workflow["jobs"]["producers"]["strategy"]["matrix"]["seam"], list(SEAMS))
        self.assertEqual(self.workflow["jobs"]["verifier"]["permissions"], {"contents": "read", "actions": "read"})
        options = triggers["workflow_dispatch"]["inputs"]["scenario"]["options"]
        self.assertEqual(options, ["full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled", "verifier"])
        old = (ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml").read_text()
        import re
        pins = lambda text: sorted(set(re.findall(r"uses: (\S+)", text)))
        self.assertEqual(pins(self.text), pins(old))
        self.assertTrue(all("@" in pin and len(pin.split("@")[1]) == 40 for pin in pins(self.text)))
        for path in (".github/workflows/ci-observe.yml", ".github/workflows/release-pr-automerge.yml", ".github/workflows/release-run-observer.yml"):
            self.assertNotIn("Phase 253 Gate Canary", (ROOT / path).read_text())
        self.assertIn("if: ${{ always() && inputs.scenario != 'cancelled' && inputs.scenario != 'verifier' }}", self.text)

    def test_native_sources_fail_and_pass_exactly_as_each_scenario_requires(self):
        import os, shutil
        script = step_script(self.workflow, "verdict", "Shared browser record validator")
        candidate = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        for scenario in ("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                tmp = Path(directory)
                shutil.copytree(ROOT / "scripts/ci", tmp / "candidate/scripts/ci", ignore=shutil.ignore_patterns("__pycache__"))
                (tmp / "candidate/.github/workflows").mkdir(parents=True)
                shutil.copyfile(ROOT / ".github/workflows/ci.yml", tmp / "candidate/.github/workflows/ci.yml")
                shutil.copyfile(ROOT / ".github/ci-skip-manifest.tsv", tmp / "candidate/.github/ci-skip-manifest.tsv")
                for seam in SEAMS:
                    if scenario == "missing-seam" and seam == "admin_checkpoints":
                        continue
                    receipt = tmp / f"producer-artifacts/gate-canary-producer-{seam}-901-1/producer.json"
                    receipt.parent.mkdir(parents=True)
                    receipt.write_text(json.dumps({"schema_version": "sigra.gate-canary-producer/v1", "scenario": scenario,
                                                   "seam": seam, "actual_event": "workflow_dispatch", "synthetic": True}))
                env = {**os.environ, "SCENARIO": scenario, "CANDIDATE_SHA": candidate, "FIXTURE_SHA": "b" * 40, "FIXTURE_BLOB": "c" * 40,
                       "GITHUB_SHA": "b" * 40, "GITHUB_WORKFLOW_SHA": "b" * 40, "GITHUB_EVENT_NAME": "workflow_dispatch",
                       "GITHUB_WORKFLOW_REF": "szTheory/sigra/.github/workflows/ci.yml@fixture", "GITHUB_RUN_ID": "901",
                       "GITHUB_RUN_ATTEMPT": "1", "CLASSIFIER_RESULT": "success" if scenario == "docs-only" else "",
                       "DOCS_ONLY": "true" if scenario == "docs-only" else "false",
                       "NATIVE_PRODUCERS_RESULT": "failure" if scenario == "actual-failure" else "success"}
                result = subprocess.run(["bash", "-c", script.replace("/tmp/", f"{tmp}/")], cwd=tmp, env=env, capture_output=True, text=True)
                wanted = 0 if scenario in ("full-pass", "docs-only") else 1
                self.assertEqual(result.returncode, wanted, result.stderr)
                record = json.loads((tmp / "canary-output/canary-result.json").read_text())
                self.assertEqual(record["validator_exit_code"], wanted)
                self.assertEqual(record["honest_skip_exit_code"], wanted)
                self.assertEqual(record["actual_event"], "workflow_dispatch")
                self.assertFalse(record["production_dispatch_exemption"])

    def test_cancellation_scenario_has_a_stalled_producer_and_no_verdict_job(self):
        producers = self.workflow["jobs"]["producers"]["steps"][0]["run"]
        self.assertIn("cancelled", producers)
        self.assertIn("sleep 900", producers)
        self.assertIn("inputs.scenario != 'cancelled'", self.workflow["jobs"]["verdict"]["if"])

    def run_verifier_step(self, payload):
        script = step_script(self.workflow, "verifier", "Verify retained source matrix independently")
        import os
        with tempfile.TemporaryDirectory() as directory:
            return subprocess.run(["bash", "-c", script.replace("/tmp/", f"{directory}/")], cwd=ROOT, text=True, capture_output=True,
                                  env={**os.environ, "MATRIX_EVIDENCE": payload})

    def compact(self, document):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.json"
            path.write_text(json.dumps(document))
            result = subprocess.run(["python3", str(PUBLISHER), "--compact-matrix", str(path)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.strip()

    def valid_matrix(self):
        document = matrix_fixture()
        document["schema_version"] = "sigra.phase253.hosted-replan-evidence/v2"
        return document

    def test_separate_verifier_accepts_a_compact_matrix_and_rejects_wrong_ref_blob_source_or_origin(self):
        accepted = self.run_verifier_step(self.compact(self.valid_matrix()))
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        self.assertIn("sources_verified", accepted.stdout)
        mutations = {
            "wrong fixture ref": lambda d: d["expected"].update(fixture_ref="refs/heads/gsd/other"),
            "wrong workflow blob": lambda d: d["expected"].update(workflow_blob="not-a-sha"),
            "wrong source commit": lambda d: d["scenarios"]["full-pass"]["run"].update(head_sha="f" * 40),
            "wrong event origin": lambda d: d["scenarios"]["full-pass"]["run"].update(event="push"),
            "halted window under-reports jobs": lambda d: d["budget"].update(actual_jobs=0),
            "missing scenario": lambda d: d["scenarios"].pop("cancelled"),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                document = self.valid_matrix()
                mutate(document)
                rejected = self.run_verifier_step(self.compact(document))
                self.assertNotEqual(rejected.returncode, 0, label)
        self.assertNotEqual(self.run_verifier_step("not-base64!").returncode, 0)
        import gzip
        trailing = base64.b64encode(gzip.compress(b"{}") + b"tail").decode()
        self.assertNotEqual(self.run_verifier_step(trailing).returncode, 0)

    def test_the_existing_evidence_verifiers_tolerate_the_extra_action_approval_key(self):
        record = {"path": ".planning/x.json", "sha256": "a" * 64, "section": "canary", "section_sha256": "b" * 64,
                  "commit": "c" * 40, "window_wall_start_epoch": 1791909792}
        document = matrix_fixture()
        document["scenario"] = "sources"
        baseline = HostedGateVerifierTests.invoke(self, document)
        self.assertEqual(baseline.returncode, 0, baseline.stderr)
        document["action_approval"] = record
        with_record = HostedGateVerifierTests.invoke(self, document)
        self.assertEqual(with_record.returncode, 0, with_record.stderr)
        self.assertEqual(json.loads(baseline.stdout), json.loads(with_record.stdout))
        import importlib.util
        spec = importlib.util.spec_from_file_location("verify_for_extra_key", VERIFY)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "v2.json"
            path.write_text(json.dumps({"schema_version": module.REPLAN_SCHEMA, "repository": "szTheory/sigra", "action_approval": record}))
            self.assertEqual(module.read_replan_evidence(path)["action_approval"], record)


PHASE_DIR = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
EVIDENCE_R9 = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-EVIDENCE-R9.json"
EVIDENCE_R9_SHA256 = "a3ca8cc0b562b2a060540f6b55fc1c0d29907c7103f87db970e1f4f678043aba"
LEDGER_R8 = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R8.json"
FIRST_CANARY_RUN = PHASE_DIR / "253-CANARY-FAILED-RUN-38347679431.json"
IDENTITY = "run workflow identity mismatch"


def load_verifier(name):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, VERIFY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def decoded_body(transaction):
    return json.loads(base64.b64decode(transaction["response_body_base64"], validate=True).decode("utf-8"))


class RunIdentityTests(unittest.TestCase):
    """253-116 (D-18/D-21): the run identity GitHub actually returns. The positive controls read committed real bytes:
    EVIDENCE-R9 (run 38906314106, halted 253-113), the R8 ledger's run poll (38791286863) and the first canary run
    38347679431. Each negative changes one field of the real R9 run object."""

    def setUp(self):
        self.module = load_verifier("hosted_gate_verify_run_identity")
        self.raw = EVIDENCE_R9.read_bytes()
        self.evidence = json.loads(self.raw)

    def receipt(self):
        return copy.deepcopy(self.evidence["scenarios"]["full-pass"])

    def title(self, scenario, run_id="38906314106", attempt="1"):
        return f"Phase 253 Gate Canary / {scenario} / {run_id}-{attempt}"

    def test_live_r9_real_full_pass_run_is_accepted(self):
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(), EVIDENCE_R9_SHA256)
        receipt = self.evidence["scenarios"]["full-pass"]
        self.assertEqual(receipt["run"]["name"], self.title("full-pass"))
        result = self.module.verify_scenario(receipt, "full-pass", self.evidence)
        self.assertEqual((result["status"], result["run_id"]), ("verified", "38906314106"))
        polls = [tx for tx in self.evidence["transport_ledger"]["transactions"] if tx["route_id"] == "run"]
        self.assertEqual([tx["sequence"] for tx in polls], [27])
        run = decoded_body(polls[0])
        self.assertEqual((run["name"], run["display_title"]), (self.title("full-pass"),) * 2)
        self.module.require_run_title(run, "full-pass")

    def test_live_r9_cli_accepts_the_real_full_pass_evidence_offline(self):
        result = subprocess.run(["python3", str(VERIFY), "--mode", "canary", "--scenario", "full-pass", "--evidence", str(EVIDENCE_R9)],
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual((output["status"], output["scenario"]["run_id"], output["transport"]["status"]),
                         ("canary_scenario_verified", "38906314106", "transport_verified"))
        self.assertEqual(hashlib.sha256(EVIDENCE_R9.read_bytes()).hexdigest(), EVIDENCE_R9_SHA256)

    def test_live_r8_real_run_poll_title_is_accepted(self):
        ledger = json.loads(LEDGER_R8.read_text())
        polls = [tx for tx in ledger["transactions"] if tx["route_id"] == "run"]
        self.assertEqual(len(polls), 1)
        run = decoded_body(polls[0])
        self.assertEqual(run["id"], 38791286863)
        self.assertNotEqual(run["name"], self.module.FIXTURE_NAME)
        self.module.require_run_title(run, "full-pass")
        with self.assertRaisesRegex(self.module.VerificationError, IDENTITY):
            self.module.require_run_title(run, "docs-only")

    def test_live_first_canary_run_title_is_accepted(self):
        run = json.loads(FIRST_CANARY_RUN.read_text())["run"]
        self.assertEqual(run["id"], 38347679431)
        self.assertNotEqual(run["name"], self.module.FIXTURE_NAME)
        self.module.require_run_title(run, "full-pass")
        with self.assertRaisesRegex(self.module.VerificationError, IDENTITY):
            self.module.require_run_title(dict(run, run_attempt=2), "full-pass")

    def test_bare_name_with_bound_display_title_is_accepted(self):
        receipt = self.receipt()
        receipt["run"]["name"] = "Phase 253 Gate Canary"
        self.module.require_run_title(receipt["run"], "full-pass")
        self.module.verify_scenario(receipt, "full-pass", self.evidence)

    def test_every_wrong_title_is_refused_with_the_identity_message(self):
        good = self.title("full-pass")
        cases = {
            "scenario docs-only in the title": {"name": self.title("docs-only"), "display_title": self.title("docs-only")},
            "another run id in the title": {"name": self.title("full-pass", "38906314107"),
                                            "display_title": self.title("full-pass", "38906314107")},
            "attempt 2 in the title": {"name": self.title("full-pass", attempt="2"), "display_title": self.title("full-pass", attempt="2")},
            "extra suffix": {"name": good + " / x", "display_title": good + " / x"},
            "trailing space": {"name": good + " ", "display_title": good + " "},
            "prefix Canary2": {"name": good.replace("Phase 253 Gate Canary / ", "Phase 253 Gate Canary2 / ", 1),
                               "display_title": good.replace("Phase 253 Gate Canary / ", "Phase 253 Gate Canary2 / ", 1)},
            "prefix CI": {"name": good.replace("Phase 253 Gate Canary / ", "CI / ", 1),
                          "display_title": good.replace("Phase 253 Gate Canary / ", "CI / ", 1)},
            "name templated, display_title bare": {"name": good, "display_title": "Phase 253 Gate Canary"},
            "name templated, display_title another run": {"name": good, "display_title": self.title("full-pass", "38906314107")},
            "display_title missing": {"name": good, "display_title": None},
            "name None": {"name": None, "display_title": good},
            "bare name, display_title missing": {"name": "Phase 253 Gate Canary", "display_title": None},
            "bare name, display_title another scenario": {"name": "Phase 253 Gate Canary", "display_title": self.title("docs-only")},
        }
        for label, fields in cases.items():
            with self.subTest(label=label):
                receipt = self.receipt()
                for key, value in fields.items():
                    if value is None and key == "display_title":
                        receipt["run"].pop("display_title")
                    else:
                        receipt["run"][key] = value
                with self.assertRaisesRegex(self.module.VerificationError, IDENTITY):
                    self.module.verify_scenario(receipt, "full-pass", self.evidence)

    def test_unchanged_run_checks_keep_refusing(self):
        for field, value in (("workflow_id", 259268963), ("path", ".github/workflows/other.yml"), ("head_branch", "gsd/253-replan-r8-fixture"),
                             ("head_sha", "f" * 40), ("event", "push"), ("conclusion", "failure")):
            with self.subTest(field=field):
                receipt = self.receipt()
                receipt["run"][field] = value
                with self.assertRaises(self.module.VerificationError):
                    self.module.verify_scenario(receipt, "full-pass", self.evidence)

    def separate_verifier_evidence(self, title):
        evidence = copy.deepcopy(self.evidence)
        # 253-117: real-shape verifier run and jobs (verifier_run_receipt); only the title varies.
        run, jobs = verifier_run_receipt(38906399999, ("producers",))
        run.update(name=title, display_title=title)
        evidence["separate_verifier"] = {"status": "passed", "job_conclusion": "success", "run_id": "38906399999",
                                         "run": run, "jobs": jobs}
        evidence["budget"]["actual_jobs"] = 7
        return evidence

    def test_separate_verifier_requires_its_own_verifier_title(self):
        self.module.verify_separate_verifier(self.separate_verifier_evidence(self.title("verifier", "38906399999")), 6)
        bare = self.separate_verifier_evidence(self.title("verifier", "38906399999"))
        bare["separate_verifier"]["run"]["name"] = "Phase 253 Gate Canary"
        self.module.verify_separate_verifier(bare, 6)
        for label, title in (("title for full-pass", self.title("full-pass", "38906399999")),
                             ("title for another verifier run id", self.title("verifier", "38906399998"))):
            with self.subTest(label=label):
                with self.assertRaisesRegex(self.module.VerificationError, IDENTITY):
                    self.module.verify_separate_verifier(self.separate_verifier_evidence(title), 6)


LEDGER_R9 = PHASE_DIR / "253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json"
NESTED_RUN_OBJECTS = ("repository", "head_repository", "head_commit", "actor", "triggering_actor")


class FixtureShapeFidelityTests(unittest.TestCase):
    """253-117 (D-18/D-24): the verifier fixtures carry GitHub's recorded shapes. Three real samples: R9 ledger seq 27/28/29
    (run 38906314106), the R8 run poll (38791286863) and run 38347679431 with its failure-shaped Browser verdict."""

    @classmethod
    def setUpClass(cls):
        rows = {row["sequence"]: row for row in json.loads(LEDGER_R9.read_text())["transactions"]}
        r8 = next(row for row in json.loads(LEDGER_R8.read_text())["transactions"] if row["route_id"] == "run")
        first = json.loads(FIRST_CANARY_RUN.read_text())
        cls.runs = {"R9 seq 27": decoded_body(rows[27]), "R8 run poll": decoded_body(r8), "run 38347679431": first["run"]}
        cls.jobs = {"R9 seq 28": decoded_body(rows[28]), "run 38347679431": first["jobs"]}
        cls.artifacts = decoded_body(rows[29])

    def assert_run_shape(self, run, label):
        for sample, real in self.runs.items():
            with self.subTest(fixture=label, sample=sample):
                self.assertEqual(real["name"], real["display_title"], f"{sample}: GitHub's name is the run-name")
                self.assertEqual(sorted(run), sorted(real))
                for key in NESTED_RUN_OBJECTS:
                    self.assertEqual(sorted(run[key]), sorted(real[key]), key)
        self.assertEqual(run["name"], run["display_title"], label)
        self.assertEqual(run["name"], f"Phase 253 Gate Canary / {label.split(':')[0]} / {run['id']}-{run['run_attempt']}")

    def real_steps(self, sample, name):
        return [step["name"] for step in next(job for job in self.jobs[sample]["jobs"] if job["name"] == name)["steps"]]

    def assert_jobs_shape(self, document, label):
        producer = self.real_steps("R9 seq 28", "producer (non_admin_smoke)")
        verdict = self.real_steps("R9 seq 28", "Browser verdict")
        self.assertEqual(verdict, self.real_steps("run 38347679431", "Browser verdict"))
        for sample, real in self.jobs.items():
            with self.subTest(fixture=label, sample=sample):
                self.assertEqual(sorted(document), sorted(real))
                for job in document["jobs"]:
                    self.assertEqual(sorted(job), sorted(real["jobs"][0]), job["name"])
                    for step in job["steps"]:
                        self.assertEqual(sorted(step), sorted(real["jobs"][0]["steps"][0]), (job["name"], step.get("name")))
        for job in document["jobs"]:
            with self.subTest(fixture=label, job=job["name"]):
                if job["conclusion"] == "skipped":
                    self.assertEqual(job["steps"], [], "GitHub lists no steps for a skipped job")
                elif job["name"].startswith("producer ("):
                    self.assertEqual([step["name"] for step in job["steps"]], producer)
                elif job["name"] == "Browser verdict":
                    self.assertEqual([step["name"] for step in job["steps"]], verdict)

    def assert_artifacts_shape(self, document, label):
        with self.subTest(fixture=label):
            self.assertEqual(sorted(document), sorted(self.artifacts))
            for artifact in document["artifacts"]:
                self.assertEqual(sorted(artifact), sorted(self.artifacts["artifacts"][0]))
                self.assertEqual(sorted(artifact["workflow_run"]), sorted(self.artifacts["artifacts"][0]["workflow_run"]))

    def test_verifier_fixtures_match_the_recorded_github_shapes(self):
        document = fixture()
        self.assert_run_shape(document["run"], "full-pass: fixture()")
        self.assert_jobs_shape(document["jobs"], "fixture()")
        self.assert_artifacts_shape(document["artifacts"], "fixture()")
        for index, scenario in enumerate(("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip",
                                          "cancelled")):
            receipt = scenario_fixture(scenario, 901 + index)
            self.assert_run_shape(receipt["run"], f"{scenario}: scenario_fixture")
            self.assert_jobs_shape(receipt["jobs"], f"scenario_fixture({scenario})")
            self.assert_artifacts_shape(receipt["artifacts"], f"scenario_fixture({scenario})")
        failure = scenario_fixture("actual-failure", 903)
        verdict = next(job for job in failure["jobs"]["jobs"] if job["name"] == "Browser verdict")
        real = next(job for job in self.jobs["run 38347679431"]["jobs"] if job["name"] == "Browser verdict")
        self.assertEqual([(step["name"], step["conclusion"]) for step in verdict["steps"]],
                         [(step["name"], step["conclusion"]) for step in real["steps"]], "failure-shaped Browser verdict")
        for producers in (("producers",), ("producer (${{ matrix.seam }})",)):
            run, jobs = verifier_run_receipt(38906399999, producers)
            self.assert_run_shape(run, f"verifier: verifier_run_receipt{producers}")
            self.assert_jobs_shape(jobs, f"verifier_run_receipt{producers}")


class SkippedProducerFormTests(unittest.TestCase):
    """253-117 (D-17/D-22): the verifier run's producer matrix job is skipped by its job-level if. GitHub has never been
    observed reporting it for this fixture; the nearest real sample (the Phase 252 bundle's skipped install_matrix job)
    is one job under its literal, unexpanded name. Exactly four forms are accepted, every non-verifier job skipped."""

    UNEXPANDED = "producer (${{ matrix.seam }})"
    EXPANDED = [f"producer ({seam})" for seam in ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery",
                                                   "demo_showcase")]

    def setUp(self):
        self.module = load_verifier("hosted_gate_verify_skipped_producer_forms")
        self.evidence = json.loads(EVIDENCE_R9.read_bytes())

    def evidence_with(self, names, conclusions=None):
        evidence = copy.deepcopy(self.evidence)
        run = real_run(38906399999, "verifier", "aa7014893b716f279b60ceb545b8aee5ca15b10c", "gsd/253-replan-r9-fixture", "success")
        conclusions = conclusions or {}
        jobs = [real_job(run, 8 + index, name, conclusions.get(index, "success" if name == "verifier" else "skipped"),
                         real_steps(VERIFIER_JOB_STEPS) if name == "verifier" else [])
                for index, name in enumerate(names)]
        evidence["separate_verifier"] = {"status": "passed", "job_conclusion": "success", "run_id": "38906399999",
                                         "run": run, "jobs": {"total_count": len(jobs), "jobs": jobs}}
        evidence["budget"]["actual_jobs"] = 6 + sum(job["conclusion"] != "skipped" for job in jobs)
        return evidence

    def test_each_of_the_four_skipped_producer_forms_is_accepted(self):
        forms = {"five expanded names": self.EXPANDED, "the job id": ["producers"],
                 "the unexpanded matrix name": [self.UNEXPANDED], "the empty-evaluation name": ["producer ()"]}
        for label, producers in forms.items():
            for order in ("producers first", "verifier first"):
                names = [*producers, "Browser verdict", "verifier"]
                if order == "verifier first":
                    names = ["verifier", "Browser verdict", *producers]
                with self.subTest(form=label, order=order):
                    self.module.verify_separate_verifier(self.evidence_with(names), 6)

    def test_any_other_producer_form_is_refused(self):
        cases = {
            "bare producer": ["producer", "Browser verdict", "verifier"],
            "one expanded name alone": ["producer (non_admin_smoke)", "Browser verdict", "verifier"],
            "duplicate unexpanded name": [self.UNEXPANDED, self.UNEXPANDED, "Browser verdict", "verifier"],
            "duplicate empty-evaluation name": ["producer ()", "producer ()", "Browser verdict", "verifier"],
            "unexpanded plus expanded": [self.UNEXPANDED, *self.EXPANDED, "Browser verdict", "verifier"],
            "unexpanded plus job id": [self.UNEXPANDED, "producers", "Browser verdict", "verifier"],
            "a space-padded empty name": ["producer ( )", "Browser verdict", "verifier"],
            "another expression": ["producer (${{ matrix.other }})", "Browser verdict", "verifier"],
            "Browser verdict missing": [self.UNEXPANDED, "verifier"],
            "an extra job": [self.UNEXPANDED, "Browser verdict", "verifier", "verifier (extra)"],
        }
        for label, names in cases.items():
            with self.subTest(case=label):
                with self.assertRaisesRegex(self.module.VerificationError, "separate hosted verifier job set is unexpected"):
                    self.module.verify_separate_verifier(self.evidence_with(names), 6)

    def test_an_unexpanded_or_empty_producer_that_was_not_skipped_is_refused(self):
        for name in (self.UNEXPANDED, "producer ()", "producers"):
            for conclusion in ("success", "failure", "cancelled"):
                with self.subTest(name=name, conclusion=conclusion):
                    evidence = self.evidence_with([name, "Browser verdict", "verifier"], {0: conclusion})
                    with self.assertRaisesRegex(self.module.VerificationError, "job identity or result mismatch"):
                        self.module.verify_separate_verifier(evidence, 6)


BINDING = "canary receipt not bound to the measured ledger: "


class CanaryBindingTests(unittest.TestCase):
    """253-116 (D-18): on the replan path every canary receipt is re-bound to the measured ledger. The real positive
    control is EVIDENCE-R9's full-pass receipt; each tamper is a scratch deep copy changed in one place, with the
    transport ledger, receipts and counts kept self-consistent so only the binding can refuse it."""

    def setUp(self):
        self.module = load_verifier("hosted_gate_verify_canary_binding")
        self.base = json.loads(EVIDENCE_R9.read_bytes())

    def evidence(self):
        return copy.deepcopy(self.base)

    def replan(self, evidence, scenario="full-pass"):
        import argparse
        return self.module.replan_result(argparse.Namespace(mode="canary", scenario=scenario), evidence)

    def rows(self, evidence, sequence):
        """The ledger transaction and its retained response receipt (and journal row, when present) for one sequence."""
        found = [evidence["transport_ledger"]["transactions"][sequence - 1], evidence["transport_receipts"][sequence - 1]]
        if isinstance(evidence.get("server_journal"), list):
            found.append(evidence["server_journal"][sequence - 1])
        for row in found:
            self.assertEqual(row["sequence"], sequence)
        return found

    def test_live_r9_real_full_pass_receipt_binds_to_its_ledger(self):
        evidence = self.evidence()
        self.assertEqual(self.replan(evidence)["status"], "canary_scenario_verified")
        bound = self.module.verify_canary_bindings(evidence, ["full-pass"])
        self.assertEqual(bound, [{"scenario": "full-pass", "run_id": "38906314106", "dispatch": 24, "discovery": 25, "polls": [27],
                                  "jobs": [28], "artifacts": [29],
                                  "archive": {"sequences": [30, 31], "artifact_id": "12048052856", "response_bytes": 933,
                                              "raw_observation_sha256": "6ff02bc720f8242e368679d0393eec4105dd9e441399bbcc7972dc8c492eb5f4"}}])

    def tamper_dispatch_scenario(self, evidence):
        inputs = None
        for row in self.rows(evidence, 24):
            body = base64.b64decode(row["request_body_base64"])
            self.assertIn(b'"scenario":"full-pass"', body)
            body = body.replace(b'"scenario":"full-pass"', b'"scenario":"docs-only"', 1)
            transmitted = json.loads(body)["inputs"]
            canonical = self.module.serialize_dispatch_inputs(transmitted)
            row.update(request_body_base64=base64.b64encode(body).decode(), request_sha256=hashlib.sha256(body).hexdigest(),
                       request_body_sha256=hashlib.sha256(body).hexdigest(), request_body_bytes=len(body), dispatch_inputs=transmitted,
                       input_key_count=len(transmitted), input_unicode_scalars=len(canonical.decode("utf-8")),
                       input_utf8_bytes=len(canonical), input_sha256=hashlib.sha256(canonical).hexdigest())
            inputs = transmitted
        evidence["dispatch_inputs"] = inputs
        evidence["dispatch_input_metrics"][0].update(sha256=hashlib.sha256(self.module.serialize_dispatch_inputs(inputs)).hexdigest())

    def tamper_zip_artifact_id(self, evidence):
        for row in self.rows(evidence, 30):
            row["url"] = row["url"].replace("/actions/artifacts/12048052856/zip", "/actions/artifacts/12048052857/zip")
            row["url_sha256"] = hashlib.sha256(row["url"].encode()).hexdigest()

    def tamper_final_hop_digest(self, evidence):
        for row in self.rows(evidence, 31):
            row["raw_observation_sha256"] = "0" * 64

    def remove_run_poll(self, evidence):
        for key in ("transactions",):
            del evidence["transport_ledger"][key][26]
        del evidence["transport_receipts"][26]
        if isinstance(evidence.get("server_journal"), list):
            del evidence["server_journal"][26]
        rows = evidence["transport_ledger"]["transactions"][26:] + evidence["transport_receipts"][26:]
        for row in rows:
            row["sequence"] -= 1
        evidence["budget"]["request_count"] -= 1

    def test_tampered_receipts_and_ledgers_are_refused_with_the_binding_prefix(self):
        tampers = {
            "253-113 control: receipt run.name set to the bare FIXTURE_NAME":
                lambda e: e["scenarios"]["full-pass"]["run"].update(name="Phase 253 Gate Canary"),
            "receipt job runner_name changed": lambda e: e["scenarios"]["full-pass"]["jobs"]["jobs"][0].update(runner_name="other runner"),
            "receipt artifacts created_at changed":
                lambda e: e["scenarios"]["full-pass"]["artifacts"]["artifacts"][0].update(created_at="2026-10-16T13:14:26Z"),
            "artifact_zip hop 0 names another artifact id": self.tamper_zip_artifact_id,
            "final hop raw_observation_sha256 changed": self.tamper_final_hop_digest,
            "dispatch transmitted scenario changed to docs-only": self.tamper_dispatch_scenario,
            "run poll removed": self.remove_run_poll,
        }
        for label, tamper in tampers.items():
            with self.subTest(label=label):
                evidence = self.evidence()
                tamper(evidence)
                # The tamper keeps the measured transport self-consistent: only the binding can refuse it.
                self.module.verify_transport_v2(evidence)
                with self.assertRaisesRegex(self.module.VerificationError, "^" + BINDING):
                    self.replan(evidence)

    def test_cli_refuses_the_253_113_receipt_only_edit(self):
        evidence = self.evidence()
        evidence["scenarios"]["full-pass"]["run"]["name"] = "Phase 253 Gate Canary"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tampered.json"
            path.write_text(json.dumps(evidence))
            result = subprocess.run(["python3", str(VERIFY), "--mode", "canary", "--scenario", "full-pass", "--evidence", str(path)],
                                    text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("FAIL: " + BINDING, result.stderr)

    def append_get(self, evidence, route, url, body):
        transactions = evidence["transport_ledger"]["transactions"]
        sequence = len(transactions) + 1
        data = json.dumps(body, sort_keys=True).encode()
        row = dict(copy.deepcopy(transactions[27]), sequence=sequence, route_id=route, request_kind=route, url=url,
                   url_sha256=hashlib.sha256(url.encode()).hexdigest(), response_body_base64=base64.b64encode(data).decode(),
                   response_sha256=hashlib.sha256(data).hexdigest(), raw_observation_sha256=hashlib.sha256(data).hexdigest(),
                   response_bytes=len(data), scrubbed_response_bytes=len(data), page_ordinal=1 if "per_page" in url else None)
        row["scrubbed_headers"] = dict(row["scrubbed_headers"], **{"content-length": str(len(data))})
        receipt = dict(copy.deepcopy(evidence["transport_receipts"][27]))
        receipt.update({key: row[key] for key in receipt if key in row})
        transactions.append(row)
        evidence["transport_receipts"].append(receipt)
        evidence["budget"]["request_count"] = len(transactions)

    def append_dispatch(self, evidence, scenario):
        transactions = evidence["transport_ledger"]["transactions"]
        template = copy.deepcopy(transactions[23])
        body = base64.b64decode(template["request_body_base64"]).replace(b'"scenario":"full-pass"', f'"scenario":"{scenario}"'.encode(), 1)
        transmitted = json.loads(body)["inputs"]
        canonical = self.module.serialize_dispatch_inputs(transmitted)
        template.update(sequence=len(transactions) + 1, request_body_base64=base64.b64encode(body).decode(),
                        request_sha256=hashlib.sha256(body).hexdigest(), request_body_sha256=hashlib.sha256(body).hexdigest(),
                        request_body_bytes=len(body), dispatch_inputs=transmitted, input_key_count=len(transmitted),
                        input_unicode_scalars=len(canonical.decode("utf-8")), input_utf8_bytes=len(canonical),
                        input_sha256=hashlib.sha256(canonical).hexdigest())
        receipt = dict(copy.deepcopy(evidence["transport_receipts"][23]))
        receipt.update({key: template[key] for key in receipt if key in template})
        transactions.append(template)
        evidence["transport_receipts"].append(receipt)
        evidence["budget"]["request_count"] = len(transactions)

    def verifier_evidence(self, dispatch_scenario="verifier"):
        """EVIDENCE-R9 extended with a modeled separate verifier (dispatch, discovery, terminal poll, jobs) appended to its
        own ledger; the R9 rows are untouched."""
        evidence = self.evidence()
        api = "https://api.github.com/repos/szTheory/sigra/actions"
        run_id = 38906399999
        # 253-117: the verifier run and jobs in GitHub's recorded shapes (verifier_run_receipt).
        run, jobs = verifier_run_receipt(run_id, ("producers",), first_job_id=900)
        self.append_dispatch(evidence, dispatch_scenario)
        self.append_get(evidence, "workflow_runs",
                        f"{api}/workflows/259268962/runs?event=workflow_dispatch&branch=gsd/253-replan-r9-fixture&per_page=100&page=1",
                        {"total_count": 1, "workflow_runs": [run]})
        self.append_get(evidence, "run", f"{api}/runs/{run_id}", run)
        self.append_get(evidence, "run_jobs", f"{api}/runs/{run_id}/jobs?per_page=100&page=1", jobs)
        evidence["separate_verifier"] = {"status": "passed", "run_id": str(run_id), "job_conclusion": "success",
                                         "run": copy.deepcopy(run), "jobs": copy.deepcopy(jobs)}
        evidence["run_attempts"].append({"run_id": str(run_id), "run_attempt": 1, "jobs": [
            {"job_id": job["id"], "name": job["name"], "conclusion": job["conclusion"], "executed": job["conclusion"] != "skipped"}
            for job in jobs["jobs"]]})
        return evidence

    def test_the_separate_verifier_receipt_binds_to_its_own_ledger_rows(self):
        evidence = self.verifier_evidence()
        self.module.verify_transport_v2(evidence)
        bound = self.module.verify_canary_bindings(evidence, ["full-pass"], verifier=True)
        self.assertEqual(bound[-1], {"scenario": "verifier", "run_id": "38906399999", "dispatch": 32, "discovery": 33,
                                     "polls": [34], "jobs": [35], "artifacts": [], "archive": None})
        tampers = {
            "verifier receipt run updated_at edited": lambda e: e["separate_verifier"]["run"].update(updated_at="2026-10-16T13:20:00Z"),
            "verifier receipt job edited": lambda e: e["separate_verifier"]["jobs"]["jobs"][2].update(runner_name="other runner"),
            "verifier run_attempts entry edited": lambda e: e["run_attempts"][-1]["jobs"][2].update(conclusion="failure", executed=True),
        }
        for label, tamper in tampers.items():
            with self.subTest(label=label):
                broken = self.verifier_evidence()
                tamper(broken)
                with self.assertRaisesRegex(self.module.VerificationError, "^" + BINDING):
                    self.module.verify_canary_bindings(broken, ["full-pass"], verifier=True)
        with self.assertRaisesRegex(self.module.VerificationError, "^" + BINDING):
            self.module.verify_canary_bindings(self.verifier_evidence(dispatch_scenario="full-pass"), ["full-pass"], verifier=True)

    def test_legacy_mode_and_verify_sources_on_a_compact_matrix_are_unchanged(self):
        def refuse(*_args, **_kwargs):
            raise AssertionError("the ledger binding must not run here")
        self.module.verify_canary_bindings = refuse
        document = matrix_fixture()
        document["schema_version"] = "sigra.phase253.hosted-replan-evidence/v2"
        document.pop("transport_ledger")
        results, count = self.module.verify_sources(document)
        self.assertEqual([item["scenario"] for item in results], list(self.module.SCENARIOS))
        self.assertEqual(count, document["budget"]["actual_jobs"])
        legacy = HostedGateVerifierTests.invoke(self, fixture())
        self.assertEqual(legacy.returncode, 0, legacy.stderr)



# --------------------------------------------------------------------------------------------------
# 253-118 (D-18/D-21/D-23): response-shape real-source checks. Each test reads committed real bytes or the real workflow
# source; none edits an expectation to fit a fake.
# --------------------------------------------------------------------------------------------------
CI_YML = ROOT / ".github/workflows/ci.yml"
PHASE252_BUNDLE = ROOT / ".planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz"
PHASE252_BUNDLE_SHA256 = "95334957b5b05494028ec72be5c95ee00e9ed4328e53fa78b35264c482a5af30"
PHASE252_PR_RUN = "./raw/families/38317383419/"
PHASE252_PUSH_RUN = "./raw/families/38146312411/"
JOB_NAME_EXPRESSION = re.compile(r"\$\{\{\s*matrix\.([A-Za-z0-9_]+)\s*\}\}")


def _yaml_scalar(raw):
    """One plain, single- or double-quoted YAML scalar on a line, with any trailing comment removed."""
    value = raw.strip()
    if value[:1] in ("'", '"'):
        quote = value[0]
        end = value.find(quote, 1)
        return value[1:end] if end > 0 else value[1:]
    return re.sub(r"\s+#.*$", "", value).strip()


def parse_workflow_jobs(text):
    """A narrow line parser over a workflow's jobs block (standard library only): for each job id, its name (default:
    the id), its matrix (include rows or value lists) and its step names. Indentation is GitHub's two-space layout."""
    lines = text.splitlines()
    start = next(index for index, line in enumerate(lines) if line == "jobs:")
    jobs, current, section, matrix_key, include = {}, None, None, None, None
    for line in lines[start + 1:]:
        if line and not line.startswith(" ") and not line.startswith("#"):
            break
        job = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if job:
            current = jobs.setdefault(job.group(1), {"name": job.group(1), "matrix": {}, "include": [], "steps": []})
            section = matrix_key = include = None
            continue
        if current is None or not line.strip() or line.strip().startswith("#"):
            continue
        name = re.match(r"^    name:(.*)$", line)
        if name:
            current["name"] = _yaml_scalar(name.group(1))
            continue
        top = re.match(r"^    ([A-Za-z_-]+):", line)
        if top:
            section = top.group(1)
            matrix_key = include = None
            continue
        if section == "strategy":
            if re.match(r"^      matrix:\s*$", line):
                continue
            key = re.match(r"^        ([A-Za-z0-9_-]+):\s*(.*)$", line)
            if key:
                matrix_key = key.group(1)
                if matrix_key != "include" and key.group(2).strip().startswith("["):
                    current["matrix"][matrix_key] = [_yaml_scalar(item) for item in key.group(2).strip()[1:-1].split(",")]
                elif matrix_key != "include":
                    current["matrix"][matrix_key] = []
                continue
            item = re.match(r"^          - (.*)$", line)
            if item and matrix_key == "include":
                include = {}
                current["include"].append(include)
                pair = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", item.group(1))
                if pair:
                    include[pair.group(1)] = _yaml_scalar(pair.group(2))
                continue
            if item and matrix_key:
                current["matrix"][matrix_key].append(_yaml_scalar(item.group(1)))
                continue
            pair = re.match(r"^            ([A-Za-z0-9_-]+):\s*(.*)$", line)
            if pair and include is not None:
                include[pair.group(1)] = _yaml_scalar(pair.group(2))
        elif section == "steps":
            step = re.match(r"^      (?:- |  )name:(.*)$", line)
            if step:
                current["steps"].append(_yaml_scalar(step.group(1)))
    return jobs


def expanded_job_names(job):
    """The check and job names GitHub reports for one workflow job after matrix expansion.

    A name with ${{ matrix.KEY }} is rendered per matrix row (Phase 252 bundle: "Example Playwright shard
    (admin_behavior)"); a matrix job whose name has no matrix expression gets " (values)" of its non-empty matrix values,
    and none for an all-empty row (bundle: "Install matrix (flag combinations)" and "... (--no-passkeys)")."""
    rows = list(job["include"])
    for key, values in job["matrix"].items():
        rows = [dict(row, **{key: value}) for row in (rows or [{}]) for value in values]
    if not rows:
        return [job["name"]]
    names = []
    for row in rows:
        if JOB_NAME_EXPRESSION.search(job["name"]):
            names.append(JOB_NAME_EXPRESSION.sub(lambda match: str(row.get(match.group(1), "")), job["name"]))
        else:
            values = [str(value) for value in row.values() if str(value)]
            names.append(f"{job['name']} ({', '.join(values)})" if values else job["name"])
    return names


def pr_inventory_problems(text, module):
    """Every way the workflow source fails to provide the jobs verify_pr_family requires (empty list: none)."""
    jobs = parse_workflow_jobs(text)
    names = [name for job in jobs.values() for name in expanded_job_names(job)]
    problems = []
    for name in (*module.REQUIRED_NAMES, module.CLASSIFIER_JOB, *[f"Example Playwright shard ({seam})" for seam in module.SEAMS]):
        if names.count(name) != 1:
            problems.append(f"{name!r} appears {names.count(name)} times after matrix expansion")
    if not any(name.startswith("Library tests shard") for name in names):
        problems.append("no Library tests shard job exists")
    classifier = [job for job in jobs.values() if module.CLASSIFIER_JOB in expanded_job_names(job)]
    if len(classifier) != 1 or classifier[0]["steps"].count(module.CLASSIFIER_JOB) != 1:
        problems.append(f"the classifier job does not have exactly one step named {module.CLASSIFIER_JOB!r}")
    return problems, names


def bundle_member(name, run_dir=PHASE252_PR_RUN):
    import tarfile
    raw = PHASE252_BUNDLE.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == PHASE252_BUNDLE_SHA256, "the Phase 252 bundle changed"
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as bundle:
        return json.loads(bundle.extractfile(run_dir + name).read())


class PRRealShapeTests(unittest.TestCase):
    """253-118: the PR family's job inventory against the real ci.yml, and its job, run and check-run shapes against
    GitHub's recorded responses for the real pull_request run 38317383419 (Phase 252 bundle) and canary run 38906314106."""

    @classmethod
    def setUpClass(cls):
        cls.module = load_verifier("hosted_gate_verify_pr_real_shape")
        rows = {row["sequence"]: row for row in json.loads(REAL_LEDGER_R9.read_text())["transactions"]}
        cls.r9 = {sequence: decoded_body(rows[sequence]) for sequence in (21, 27, 28)}

    def test_live_ci_yml_provides_every_job_name_the_pr_verifier_requires(self):
        problems, names = pr_inventory_problems(CI_YML.read_text(), self.module)
        self.assertEqual(problems, [], names)
        for seam in self.module.SEAMS:
            self.assertEqual(names.count(f"Example Playwright shard ({seam})"), 1)
        print(f"\nci.yml expanded job names ({len(names)}): {json.dumps(names)}")
        # Negative controls on scratch copies: one required job renamed, and the classifier step duplicated.
        text = CI_YML.read_text()
        renamed = text.replace("    name: Example HTTP smoke (boot + curl critical routes)\n",
                               "    name: Example HTTP smoke (renamed)\n", 1)
        self.assertNotEqual(renamed, text)
        with tempfile.TemporaryDirectory(prefix="sigra-253-118-ci-yml-") as scratch:
            copy_path = Path(scratch) / "ci.yml"
            copy_path.write_text(renamed)
            broken, _ = pr_inventory_problems(copy_path.read_text(), self.module)
        self.assertIn("'Example HTTP smoke (boot + curl critical routes)' appears 0 times after matrix expansion", broken)
        doubled = text.replace("      - name: Detect docs-only change\n",
                               "      - name: Detect docs-only change\n        run: true\n      - name: Detect docs-only change\n", 1)
        self.assertNotEqual(doubled, text)
        broken, _ = pr_inventory_problems(doubled, self.module)
        self.assertTrue(any("exactly one step named" in item for item in broken), broken)

    def test_live_matrix_expansion_matches_the_names_github_reported_for_a_real_pull_request_run(self):
        # The expansion rule is itself checked against GitHub's rendering: the real attempt jobs of pull_request run
        # 38317383419 (an expression rendered per seam) and push run 38146312411 (a matrix job named without one).
        real = {job["name"] for job in bundle_member("jobs-attempt-1.json")["jobs"]}
        for seam in self.module.SEAMS:
            self.assertIn(f"Example Playwright shard ({seam})", real)
        pushed = [job["name"] for job in bundle_member("jobs-attempt-1.json", PHASE252_PUSH_RUN)["jobs"]]
        self.assertEqual(sorted(name for name in pushed if name.startswith("Install matrix")),
                         sorted(["Install matrix (flag combinations)", "Install matrix (flag combinations) (--no-passkeys)",
                                 "Install matrix (flag combinations) (--no-organizations)",
                                 "Install matrix (flag combinations) (--no-organizations --no-passkeys)"]))
        job = {"name": "Install matrix (flag combinations)", "matrix": {"flags": ["", "--no-passkeys"]}, "include": [], "steps": []}
        self.assertEqual(expanded_job_names(job), ["Install matrix (flag combinations)", "Install matrix (flag combinations) (--no-passkeys)"])

    def test_live_attempt_jobs_and_run_jobs_share_one_job_schema_in_real_responses(self):
        attempt = bundle_member("jobs-attempt-1.json")
        run_jobs = self.r9[28]
        self.assertEqual(set(attempt), set(run_jobs))
        self.assertEqual({frozenset(job) for job in attempt["jobs"]}, {frozenset(job) for job in run_jobs["jobs"]})
        self.assertEqual({frozenset(step) for job in attempt["jobs"] for step in job["steps"]},
                         {frozenset(step) for job in run_jobs["jobs"] for step in job["steps"]})
        run = bundle_member("run.json")
        self.assertEqual(set(run), set(self.r9[27]))
        self.assertEqual(run["event"], "pull_request")
        self.assertEqual(attempt["total_count"], len(attempt["jobs"]))
        for job in attempt["jobs"]:
            self.assertEqual((job["run_id"], job["run_attempt"], job["status"]), (run["id"], run["run_attempt"], "completed"))
        self.assertTrue(any(type(item.get("number")) is int for item in run["pull_requests"]))
        self.assertEqual((run["repository"]["full_name"], run["head_repository"]["full_name"]), (self.module.REPOSITORY,) * 2)
        classifier = [job for job in attempt["jobs"] if job["name"] == self.module.CLASSIFIER_JOB]
        self.assertEqual(len(classifier), 1)
        self.assertEqual(sum(step["name"] == self.module.CLASSIFIER_JOB and step["conclusion"] == "success"
                             for step in classifier[0]["steps"]), 1)

    def test_live_real_pr_check_runs_link_each_required_check_to_its_attempt_job(self):
        checks = bundle_member("check-runs.json")
        jobs = {job["name"]: job for job in bundle_member("jobs-attempt-1.json")["jobs"]}
        native = {item["name"]: item for item in checks["check_runs"] if item["name"] in self.module.REQUIRED_NAMES}
        self.assertEqual(set(native), set(self.module.REQUIRED_NAMES))
        for name, check in native.items():
            with self.subTest(check=name):
                match = re.search(r"/job/([0-9]+)$", check["html_url"])
                self.assertIsNotNone(match)
                self.assertEqual(match.group(1), str(jobs[name]["id"]))
                self.assertEqual((check["head_sha"], check["status"]), (jobs[name]["head_sha"], "completed"))
                self.assertTrue(type(check["app"]["id"]) is int and check["app"]["slug"])
                self.assertEqual(check["conclusion"], jobs[name]["conclusion"])

    def test_live_r9_preflight_responses_satisfy_the_canary_driver_reads(self):
        canary = CANARY.read_text()
        evidence = json.loads(EVIDENCE_R9.read_text())
        rows = {row["sequence"]: row for row in evidence["transport_ledger"]["transactions"]}
        filters = {
            18: [".resources.core.remaining // 0"],
            19: ['type == "array" and length <= 200',
                 '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | sort == '
                 '(["Library tests","Example unit smoke (ExUnit + ConnTest)","Install smoke (fresh phx.new + sigra.install)",'
                 '"Example HTTP smoke (boot + curl critical routes)","Example Playwright smoke (full lifecycle)"] | sort)'],
            20: ['type=="object" and ((.required_status_checks // {})|type=="object")'],
            21: ['type=="object" and (.check_runs|type=="array")'],
            22: ['.id == 259268962 and .path == ".github/workflows/ci.yml" and .state == "active"'],
        }
        per_check = ('([.check_runs[] | select(.name==$name)] | length == 1) and ([.check_runs[] | select(.name==$name and '
                     '.head_sha==$sha and (.app.id|type=="number") and .app.id > 0 and (.app.slug|type=="string") and .app.slug != "" '
                     'and (.html_url|type=="string") and (.html_url|startswith("https://")))] | length == 1)')
        for expression in [*[item for items in filters.values() for item in items], per_check]:
            self.assertIn(f"'{expression}'", canary, "a pinned preflight read is no longer the canary driver's expression")
        for sequence, expressions in filters.items():
            body = base64.b64decode(rows[sequence]["response_body_base64"])
            for expression in expressions:
                with self.subTest(sequence=sequence, expression=expression[:40]):
                    result = subprocess.run(["jq", "-e", expression], input=body, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
        remaining = subprocess.run(["jq", "-r", filters[18][0]], input=base64.b64decode(rows[18]["response_body_base64"]),
                                   capture_output=True, check=True).stdout.decode().strip()
        self.assertGreater(int(remaining), 250)
        source = evidence["expected"]["check_source_sha"]
        for name in self.module.REQUIRED_NAMES:
            with self.subTest(check=name):
                result = subprocess.run(["jq", "-e", "--arg", "name", name, "--arg", "sha", source, per_check],
                                        input=base64.b64decode(rows[21]["response_body_base64"]), capture_output=True, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
        # Negative control: the same read against the real workflow body with its state changed must fail.
        workflow = json.loads(base64.b64decode(rows[22]["response_body_base64"]))
        workflow["state"] = "disabled_manually"
        refused = subprocess.run(["jq", "-e", filters[22][0]], input=json.dumps(workflow).encode(), capture_output=True, check=False)
        self.assertEqual(refused.returncode, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
