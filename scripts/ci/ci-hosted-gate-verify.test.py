#!/usr/bin/env python3
"""Offline contracts for independently checking hosted canary receipts."""
import copy
import base64
import io
import json
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts/ci/ci-hosted-gate-verify.py"
CANARY = ROOT / "scripts/ci/ci-gate-canary.sh"


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
    return {
        "schema_version": "sigra.hosted-gate-canary/v1",
        "repository": "szTheory/sigra",
        "scenario": "full-pass",
        "expected": {
            "candidate_sha": candidate,
            "fixture_ref": "refs/heads/gsd/253-gate-canary-fixture-20261013-040000",
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
        "run": {
            "id": 901,
            "run_id": 901,
            "run_attempt": 1,
            "event": "workflow_dispatch",
            "head_sha": workflow_sha,
            "head_branch": "gsd/253-gate-canary-fixture-20261013-040000",
            "workflow_id": 259268962,
            "path": ".github/workflows/ci.yml",
            "name": "Phase 253 Gate Canary",
            "status": "completed",
            "conclusion": "success",
        },
        "jobs": {
            "total_count": 7,
            "jobs": [
                {"id": index + 1, "run_id": 901, "run_attempt": 1, "name": f"producer ({seam})", "conclusion": "success", "steps": [{"name": "Run the named synthetic tiny command", "conclusion": "success"}]}
                for index, seam in enumerate(("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase"))
            ] + [{"id": 6, "run_id": 901, "run_attempt": 1, "name": "Browser verdict", "conclusion": "success", "steps": [
                {"name": "Verify immutable fixture and candidate checkout identities", "conclusion": "success"},
                {"name": "Shared browser record validator", "conclusion": "success"}]},
                {"id": 7, "run_id": 901, "run_attempt": 1, "name": "verifier", "conclusion": "skipped", "steps": []}],
        },
        "artifacts": {
            "total_count": 1,
            "artifacts": [{"id": 77, "name": "gate-canary-full-pass-901-1", "expired": False,
                           "size_in_bytes": len(payload),
                           "digest": "sha256:" + __import__("hashlib").sha256(payload).hexdigest(),
                           "workflow_run": {"id": 901, "run_attempt": 1}}],
        },
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
    document['run'].update(id=run_id, run_id=run_id, conclusion=conclusion)
    for job in document['jobs']['jobs']:
        job['run_id'] = run_id
        if job['name'] == 'Browser verdict':
            job['conclusion'] = 'skipped' if scenario == 'cancelled' else conclusion
            job['steps'][-1]['conclusion'] = conclusion
        if scenario in ('actual-failure', 'cancelled') and job['name'] == 'producer (admin_behavior)':
            job['conclusion'] = conclusion
            job['steps'][0]['conclusion'] = conclusion
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
    document['artifacts']['artifacts'][0].update(name=f'gate-canary-{scenario}-{run_id}-1', size_in_bytes=len(archive.getvalue()), digest='sha256:' + digest,
                                                workflow_run={'id': run_id, 'run_attempt': 1})
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
        run = copy.deepcopy(document['run'])
        run.update(id=999, run_id=999)
        jobs = [{'id': 8, 'run_id': 999, 'run_attempt': 1, 'name': name,
                 'conclusion': 'success' if name == 'verifier' else 'skipped', 'steps': []}
                for name in ('producers', 'Browser verdict', 'verifier')]
        jobs[-1]['steps'] = [{'name': name, 'conclusion': 'success'} for name in
                            ('Verify immutable candidate verifier checkout', 'Verify retained source matrix independently')]
        document['separate_verifier'] = {'status': 'passed', 'job_conclusion': 'success', 'run_id': '999',
                                         'run': run, 'jobs': {'total_count': 3, 'jobs': jobs}}
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
        document["jobs"]["jobs"][0]["steps"][0]["conclusion"] = "failure"
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
