#!/usr/bin/env python3
"""Verify a hosted Phase 253 canary receipt from GitHub API snapshots."""

import argparse
import base64
import hashlib
import json
import re
import sys
import io
import zipfile
from pathlib import Path

SCHEMA = "sigra.hosted-gate-canary/v1"
RESULT_SCHEMA = "sigra.gate-canary-result/v1"
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
SCENARIOS = ("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled")
FIXTURE_NAME = "Phase 253 Gate Canary"
WORKFLOW_PATH = ".github/workflows/ci.yml"


class VerificationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_evidence(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError(f"evidence unreadable or malformed: {error}") from error
    require(isinstance(value, dict), "evidence root must be an object")
    require(value.get("schema_version") == SCHEMA, "unsupported evidence schema")
    require(value.get("repository") == "szTheory/sigra", "wrong repository")
    budget = value.get("budget")
    require(isinstance(budget, dict) and budget.get("max_requests") == 120 and budget.get("max_jobs") == 45
            and type(budget.get("request_count")) is int and 0 <= budget["request_count"] <= 120
            and type(budget.get("actual_jobs")) is int and 0 <= budget["actual_jobs"] <= 45
            and type(budget.get("elapsed_seconds")) is int and 0 <= budget["elapsed_seconds"] <= 3600,
            "fixed hosted request, job, or time budget is missing or exceeded")
    ledger = value.get("transport_ledger")
    transactions = ledger.get("transactions") if isinstance(ledger, dict) else None
    require(isinstance(transactions, list), "actual HTTP transport ledger is missing")
    require(len(transactions) == budget["request_count"], "reported request count differs from actual transport ledger")
    for sequence, transaction in enumerate(transactions, 1):
        require(isinstance(transaction, dict) and transaction.get("sequence") == sequence
                and transaction.get("method") in ("GET", "POST", "DELETE")
                and isinstance(transaction.get("url"), str) and transaction["url"].startswith("https://")
                and type(transaction.get("status")) is int and 100 <= transaction["status"] <= 599,
                "transport ledger has an incomplete, duplicated, or uncharged HTTP transaction")
        require(transaction["status"] not in (403, 429), "transport was rate limited; stop until GitHub reset")
    observed = value.get("transport_trace")
    if observed is not None:
        require(isinstance(observed, list) and len(observed) == len(transactions),
                "mocked transport trace contains an uncharged poll, page, redirect, or request")
        for actual, charged in zip(observed, transactions):
            require(isinstance(actual, dict) and all(actual.get(key) == charged.get(key)
                    for key in ("sequence", "method", "url", "status")),
                    "observed transport differs from the charged request ledger")
    inputs = value.get("dispatch_inputs")
    require(isinstance(inputs, dict) and len(inputs) <= 10
            and sum(len(str(key)) + len(str(item)) for key, item in inputs.items()) <= 65535,
            "dispatch input count or combined character limit exceeded")
    dispatches = [item for item in transactions if item.get("method") == "POST" and item.get("url", "").endswith("/dispatches")]
    metrics = value.get("dispatch_input_metrics", [])
    require(isinstance(metrics, list) and len(metrics) == len(dispatches),
            "not every workflow dispatch has a bounded input receipt")
    for metric, transaction in zip(metrics, dispatches):
        require(isinstance(metric, dict) and metric.get("sequence") == transaction.get("sequence")
                and type(metric.get("key_count")) is int and 0 <= metric["key_count"] <= 10
                and type(metric.get("combined_chars")) is int and 0 <= metric["combined_chars"] <= 65535
                and transaction.get("input_keys") == metric["key_count"]
                and transaction.get("input_chars") == metric["combined_chars"],
                "workflow dispatch input receipt is missing, unbounded, or differs from transport")
    return value


def expected_outcome(scenario):
    return {"full-pass": "success", "docs-only": "success", "actual-failure": "failure",
            "missing-seam": "failure", "unexpected-skip": "failure", "cancelled": "cancelled"}[scenario]


def validate_record(record, scenario, run_id, attempt, expected):
    require(isinstance(record, dict), "retained canary record missing")
    require(record.get("schema_version") == RESULT_SCHEMA, "retained record schema mismatch")
    require(record.get("scenario") == scenario, "retained record scenario mismatch")
    require(str(record.get("run_id")) == str(run_id) and str(record.get("run_attempt")) == str(attempt),
            "retained record run or attempt mismatch")
    require(record.get("candidate_sha") == expected.get("candidate_sha"), "candidate helper commit mismatch")
    require(record.get("fixture_workflow_sha") == expected.get("workflow_sha"), "fixture workflow commit mismatch")
    require(record.get("fixture_workflow_blob") == expected.get("workflow_blob"), "fixture workflow blob mismatch")
    require(record.get("synthetic") is True, "synthetic command receipt must be labeled synthetic")
    wanted_code = 0 if scenario in ("full-pass", "docs-only") else 1
    require(record.get("validator_exit_code") == wanted_code, "candidate validator exit status differs from scenario")
    require(record.get("status") == ("passed" if wanted_code == 0 else "rejected"), "retained source status differs from scenario")
    wanted_skip_code = 0 if scenario in ("full-pass", "docs-only") else 1
    require(record.get("honest_skip_exit_code") == wanted_skip_code, "candidate honest-skip exit status differs from scenario")
    honest = record.get("honest_skip_verdict")
    require(isinstance(honest, dict) and honest.get("verdict") == ("PASS" if wanted_skip_code == 0 else "FAIL"),
            "candidate honest-skip verdict differs from scenario")
    logical_event = "pull_request" if scenario == "docs-only" else "workflow_dispatch"
    logical_docs_only = "true" if scenario == "docs-only" else "false"
    require(honest.get("event") == logical_event and honest.get("docs_only") == logical_docs_only,
            "candidate honest-skip logical event or docs-only input mismatch")
    if scenario == "docs-only":
        require(record.get("actual_event") == "workflow_dispatch", "docs-only receipt lost actual dispatch event")
        require(record.get("logical_event") == "pull_request" and record.get("classifier_result") == "success"
                and record.get("docs_only") is True, "docs-only logical PR input is not explicit and successful")
        require(record.get("production_dispatch_exemption") is False, "synthetic docs-only case cannot authorize production dispatch")
    return record


def verify_scenario(receipt, scenario, evidence):
    require(scenario in SCENARIOS, f"unknown scenario: {scenario}")
    require(isinstance(receipt, dict), f"scenario receipt missing: {scenario}")
    expected = evidence.get("expected")
    require(isinstance(expected, dict), "expected identity missing")
    for key in ("candidate_sha", "workflow_sha", "workflow_blob"):
        require(isinstance(expected.get(key), str) and re.fullmatch(r"[0-9a-f]{40}", expected[key]), f"invalid expected {key}")
    fixture_ref = expected.get("fixture_ref")
    require(isinstance(fixture_ref, str) and fixture_ref.startswith("refs/heads/gsd/253-gate-canary-fixture-"),
            "fixture ref is outside the scoped namespace")
    require(expected.get("fixture_ref_state") == "verified", "scoped fixture ref was not read back before dispatch")
    require(expected.get("workflow_id") == 259268962 and expected.get("workflow_path") == WORKFLOW_PATH
            and expected.get("workflow_name") == FIXTURE_NAME, "registered fixture workflow identity mismatch")
    run = receipt.get("run")
    require(isinstance(run, dict), "GitHub workflow run metadata missing")
    require(str(run.get("id", "")) == str(receipt.get("run_id", "")), "run metadata ID mismatch")
    require(str(run.get("run_attempt", "")) == str(receipt.get("run_attempt", "")), "run attempt mismatch")
    require(run.get("event") == "workflow_dispatch", "actual GitHub event is not workflow_dispatch")
    require(run.get("head_branch") == fixture_ref.removeprefix("refs/heads/"), "run came from an unexpected branch")
    require(run.get("head_sha") == expected["workflow_sha"], "fixture workflow source commit mismatch")
    require(run.get("workflow_id") == expected["workflow_id"] and str(run.get("path", "")).split("@", 1)[0] == WORKFLOW_PATH
            and run.get("name") == FIXTURE_NAME, "run workflow identity mismatch")
    require(run.get("status") == "completed" and run.get("conclusion") == expected_outcome(scenario),
            f"actual terminal conclusion does not match {scenario}")

    jobs_doc = receipt.get("jobs")
    require(isinstance(jobs_doc, dict) and isinstance(jobs_doc.get("jobs"), list), "GitHub jobs response missing")
    jobs = jobs_doc["jobs"]
    require(jobs_doc.get("total_count") == len(jobs), "jobs response is incomplete")
    names = [job.get("name") for job in jobs if isinstance(job, dict)]
    required_names = [f"producer ({seam})" for seam in SEAMS] + ["Browser verdict", "verifier"]
    require(sorted(names) == sorted(required_names), "hosted job set is missing, duplicated, or unexpected")
    require(all(job.get("run_id") == run.get("id") and job.get("run_attempt") == run.get("run_attempt")
                and job.get("conclusion") is not None for job in jobs), "hosted job run identity or terminal result mismatch")
    auxiliary = next(job for job in jobs if job.get("name") == "verifier")
    require(auxiliary.get("conclusion") == "skipped", "auxiliary verifier must be skipped in source scenarios")
    executed = sum(job.get("conclusion") != "skipped" for job in jobs)
    require(evidence["budget"]["actual_jobs"] >= executed, "reported job budget omits executed hosted jobs")
    if scenario == "cancelled":
        require(sorted(names) == sorted(required_names) and all(job.get("run_id") == run.get("id")
                and job.get("run_attempt") == run.get("run_attempt") for job in jobs)
                and any(job.get("conclusion") == "cancelled" for job in jobs),
                "cancellation was not observed on a hosted fixture job")
    else:
        require(sorted(names) == sorted(required_names), "hosted job set is missing, duplicated, or unexpected")
        verdict = next((job for job in jobs if job.get("name") == "Browser verdict"), None)
        require(verdict is not None and verdict.get("conclusion") == expected_outcome(scenario),
                "browser verdict job conclusion mismatch")
        require(verdict.get("run_attempt") == run.get("run_attempt") and verdict.get("run_id") == run.get("id"),
                "browser verdict run identity mismatch")
        verdict_steps = verdict.get("steps")
        require(isinstance(verdict_steps, list) and any(step.get("name") == "Verify immutable fixture and candidate checkout identities"
                and step.get("conclusion") == "success" for step in verdict_steps),
                "immutable fixture and candidate checkout identity check did not pass")
        for seam in SEAMS:
            producer = next((job for job in jobs if job.get("name") == f"producer ({seam})"), None)
            wanted_producer_conclusion = "failure" if scenario == "actual-failure" and seam == "admin_behavior" else "success"
            require(producer is not None and producer.get("conclusion") == wanted_producer_conclusion,
                    f"producer has unexpected conclusion: {seam}")
            steps = producer.get("steps")
            require(isinstance(steps, list) and steps, f"producer steps unavailable: {seam}")
            wanted_tiny = "failure" if wanted_producer_conclusion == "failure" else "success"
            require(any(step.get("name") == "Run the named synthetic tiny command" and step.get("conclusion") == wanted_tiny for step in steps),
                    f"tiny producer step did not have the expected outcome: {seam}")
            require(producer.get("run_attempt") == run.get("run_attempt") and producer.get("run_id") == run.get("id"),
                    f"producer run identity mismatch: {seam}")
        require(isinstance(verdict_steps, list) and any(step.get("name") == "Shared browser record validator"
                and step.get("conclusion") == expected_outcome(scenario) for step in verdict_steps),
                "shared candidate verdict step is missing or has the wrong conclusion")

    artifacts_doc = receipt.get("artifacts")
    require(isinstance(artifacts_doc, dict) and isinstance(artifacts_doc.get("artifacts"), list),
            "GitHub artifact API response missing")
    artifacts = artifacts_doc["artifacts"]
    require(artifacts_doc.get("total_count") == len(artifacts), "artifact response is incomplete")
    wanted_name = f"gate-canary-{scenario}-{receipt['run_id']}-{receipt['run_attempt']}"
    matches = [artifact for artifact in artifacts if artifact.get("name") == wanted_name]
    if scenario == "cancelled":
        require(not matches, "cancelled source must not be replaced by a synthetic successful artifact")
        return {"scenario": scenario, "status": "verified_non_green", "run_id": str(run["id"]),
                "conclusion": run["conclusion"], "artifacts": 0}
    require(len(matches) == 1, "expected exactly one same-run canary artifact")
    artifact = matches[0]
    require(type(artifact.get("size_in_bytes")) is int and 0 <= artifact["size_in_bytes"] <= 2 * 1024 * 1024,
            "compressed artifact exceeds the 2 MiB limit or has no trusted size")
    require(artifact.get("expired") is False and str(artifact.get("id")) == str(receipt.get("retained_artifact", {}).get("artifact_id")),
            "artifact is expired or does not match downloaded artifact ID")
    require(artifact.get("workflow_run", {}).get("id") == run["id"], "artifact API origin does not match producing run")
    retained = receipt.get("retained_artifact")
    require(isinstance(retained, dict), "downloaded artifact evidence missing")
    digest = artifact.get("digest")
    require(isinstance(digest, str) and digest.startswith("sha256:"), "GitHub artifact API digest unavailable")
    archive_base64 = retained.get("archive_base64")
    require(isinstance(archive_base64, str), "downloaded artifact archive bytes are required")
    try:
        archive_bytes = base64.b64decode(archive_base64, validate=True)
    except (ValueError, base64.binascii.Error) as error:
        raise VerificationError("downloaded artifact archive encoding is invalid") from error
    archive_digest = sha256(archive_bytes)
    require(len(archive_bytes) <= 2 * 1024 * 1024, "downloaded artifact exceeds the 2 MiB compressed limit")
    require(archive_digest == digest.removeprefix("sha256:"), "downloaded archive digest differs from GitHub API")
    require(retained.get("archive_sha256") == archive_digest, "recorded archive digest differs from downloaded bytes")
    files = retained.get("files")
    require(isinstance(files, dict) and set(files) == {"canary-result.json"}, "artifact contents are missing or unexpected")
    file_entry = files["canary-result.json"]
    require(isinstance(file_entry, dict) and isinstance(file_entry.get("json"), dict), "canary result JSON is malformed")
    result_bytes = file_entry.get("content")
    require(isinstance(result_bytes, str), "retained artifact bytes are required for digest verification")
    require(sha256(result_bytes.encode("utf-8")) == file_entry.get("sha256"), "retained result file digest mismatch")
    try:
        with zipfile.ZipFile(io.BytesIO(archive_bytes)) as bundle:
            names = [name for name in bundle.namelist() if not name.endswith("/")]
            require(names == ["canary-result.json"], "downloaded archive has unexpected or duplicate files")
            info = bundle.getinfo("canary-result.json")
            require(info.file_size <= 4 * 1024 * 1024, "extracted artifact exceeds the 4 MiB limit")
            archived_result = bundle.read("canary-result.json")
    except (OSError, zipfile.BadZipFile, KeyError) as error:
        raise VerificationError(f"downloaded artifact archive is not a valid canary ZIP: {error}") from error
    require(archived_result == result_bytes.encode("utf-8"), "retained result bytes are not present in the digest-checked archive")
    try:
        decoded = json.loads(result_bytes)
    except json.JSONDecodeError as error:
        raise VerificationError(f"retained artifact JSON malformed: {error}") from error
    require(decoded == file_entry["json"], "parsed retained result differs from archived bytes")
    record = validate_record(decoded, scenario, run["id"], run["run_attempt"], expected)
    return {"scenario": scenario, "status": "verified" if run["conclusion"] == "success" else "verified_non_green",
            "run_id": str(run["id"]), "conclusion": run["conclusion"], "artifact_id": artifact["id"],
            "artifact_digest": digest, "synthetic": record["synthetic"]}


def verify_sources(evidence):
    scenarios = evidence.get("scenarios")
    require(isinstance(scenarios, dict), "scenario matrix missing")
    require(set(scenarios) == set(SCENARIOS), "scenario matrix contains missing or unknown cases")
    results = [verify_scenario(scenarios.get(name), name, evidence) for name in SCENARIOS]
    count = sum(job.get("conclusion") != "skipped" for receipt in scenarios.values() for job in receipt["jobs"]["jobs"])
    require(evidence["budget"]["actual_jobs"] >= count, "reported job budget omits source matrix executions")
    return results, count


def verify_separate_verifier(evidence, source_count):
    verifier = evidence.get("separate_verifier")
    require(isinstance(verifier, dict) and verifier.get("status") == "passed" and verifier.get("job_conclusion") == "success",
            "separate hosted verifier job has not passed")
    run = verifier.get("run")
    expected = evidence.get("expected", {})
    require(isinstance(run, dict) and str(run.get("id")) == str(verifier.get("run_id"))
            and run.get("event") == "workflow_dispatch" and run.get("status") == "completed"
            and run.get("conclusion") == "success" and run.get("workflow_id") == 259268962
            and str(run.get("path", "")).split("@", 1)[0] == WORKFLOW_PATH and run.get("name") == FIXTURE_NAME
            and run.get("head_branch") == expected.get("fixture_ref", "").removeprefix("refs/heads/")
            and run.get("head_sha") == expected.get("workflow_sha"),
            "separate hosted verifier run identity or conclusion mismatch")
    document = verifier.get("jobs")
    require(isinstance(document, dict) and isinstance(document.get("jobs"), list), "separate hosted verifier jobs missing")
    jobs = document["jobs"]
    require(document.get("total_count") == len(jobs), "separate hosted verifier job list is incomplete")
    names = [job.get("name") for job in jobs]
    expanded = [f"producer ({seam})" for seam in SEAMS] + ["Browser verdict", "verifier"]
    require(sorted(names) in (sorted(expanded), sorted(["producers", "Browser verdict", "verifier"])),
            "separate hosted verifier job set is unexpected")
    require(all(job.get("run_id") == run.get("id") and job.get("run_attempt") == run.get("run_attempt")
                and job.get("conclusion") == ("success" if job.get("name") == "verifier" else "skipped") for job in jobs),
            "separate hosted verifier job identity or result mismatch")
    job = next(job for job in jobs if job.get("name") == "verifier")
    steps = job.get("steps")
    require(isinstance(steps, list) and all(any(step.get("name") == name and step.get("conclusion") == "success"
                for step in steps) for name in ["Verify immutable candidate verifier checkout", "Verify retained source matrix independently"]),
            "separate verifier did not confirm its candidate checkout and source matrix")
    require(evidence["budget"]["actual_jobs"] == source_count + 1, "executed job budget differs from hosted receipts")
    return verifier


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, help="captured GitHub API and artifact receipt JSON")
    parser.add_argument("--scenario", required=True, choices=(*SCENARIOS, "sources", "matrix"))
    args = parser.parse_args()
    evidence = read_evidence(args.evidence)
    if args.scenario in ("sources", "matrix"):
        results, count = verify_sources(evidence)
        if args.scenario == "sources":
            return {"status": "sources_verified", "scenarios": results, "executed_jobs": count}
        return {"status": "verified", "scenarios": results, "separate_verifier": verify_separate_verifier(evidence, count)}
    receipt = evidence.get("scenarios", {}).get(args.scenario) if "scenarios" in evidence else evidence
    return verify_scenario(receipt, args.scenario, evidence)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2, sort_keys=True))
    except (VerificationError, KeyError, TypeError) as error:
        print(f"hosted-gate-verify: FAIL: {error}", file=sys.stderr)
        sys.exit(1)
