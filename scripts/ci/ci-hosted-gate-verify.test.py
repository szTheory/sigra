#!/usr/bin/env python3
"""Offline contracts for independently checking hosted canary receipts."""
import copy
import hashlib
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
        "run": {
            "id": 901,
            "run_id": 901,
            "run_attempt": 1,
            "event": "workflow_dispatch",
            "head_sha": workflow_sha,
            "head_branch": "gsd/253-replan-canary-fixture-20261013-040000",
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
    """The production checker binds the two load links to the R4 artifacts; the injected-checker tests above stay unchanged."""

    R4 = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R4.json"
    ACCEPT = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json"
    HALTED = (
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json",
        ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R3.json",
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
        evidence["links"]["load_controls"] = self.link_at(controls or self.R4)
        document = {"assessment": {"kind": "cause_repair", "cause": "loader race"}}
        path = self.root / (acceptance or self.ACCEPT)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(document))
        evidence["links"]["load_acceptance"] = {"path": acceptance or self.ACCEPT, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        return evidence

    def run_production(self, evidence):
        return self.module.verify_completion(evidence, require_accepted=True, root=self.root)

    def test_the_r4_native_evidence_and_the_acceptance_evidence_are_accepted_through_the_production_checker(self):
        result = self.run_production(self.production())
        self.assertEqual(result["status"], "accepted")
        self.assertEqual([kind for kind, _ in self.checked], ["load_controls", "load_acceptance"])

    def test_halted_v1_r2_r3_and_253_40_native_evidence_is_rejected_before_the_checker_runs(self):
        for halted in self.HALTED:
            with self.subTest(path=halted):
                self.checked.clear()
                with self.assertRaises(self.module.VerificationError) as caught:
                    self.run_production(self.production(controls=halted))
                self.assertIn("load_controls must link the R4 native evidence", str(caught.exception))
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
