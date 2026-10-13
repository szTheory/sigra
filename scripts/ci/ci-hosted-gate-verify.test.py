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
