#!/usr/bin/env python3
"""Verify a hosted Phase 253 canary receipt from GitHub API snapshots."""

import argparse
import base64
import hashlib
import json
import re
import sys
import io
import gzip
import importlib.util
import copy
import os
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import urlsplit

SCHEMA = "sigra.hosted-gate-canary/v1"
RESULT_SCHEMA = "sigra.gate-canary-result/v1"
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
SCENARIOS = ("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled")
FIXTURE_NAME = "Phase 253 Gate Canary"
WORKFLOW_PATH = ".github/workflows/ci.yml"
REPLAN_SCHEMA = "sigra.phase253.hosted-replan-evidence/v2"
REQUIRED_NAMES = (
    "Library tests", "Example unit smoke (ExUnit + ConnTest)",
    "Install smoke (fresh phx.new + sigra.install)",
    "Example HTTP smoke (boot + curl critical routes)",
    "Example Playwright smoke (full lifecycle)",
)
MAX_INPUT_SCALARS = 65535
MAX_INPUT_BYTES = 65535
MAX_ZIP_BYTES = 2 * 1024 * 1024
MAX_MEMBER_BYTES = 4 * 1024 * 1024


class VerificationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def serialize_dispatch_inputs(inputs, schema=None):
    """Serialize only typed workflow_dispatch fields with explicit byte limits."""
    try:
        transport_path = Path(__file__).with_name("ci-hosted-transport.py")
        spec = importlib.util.spec_from_file_location("ci_hosted_transport", transport_path)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        encoded = transport.serialize_dispatch_inputs(inputs, schema=schema)
    except Exception as error:
        if isinstance(error, VerificationError):
            raise
        raise VerificationError(str(error)) from error
    scalar_count = len(encoded.decode("utf-8", "strict"))
    require(scalar_count <= MAX_INPUT_SCALARS, "compact dispatch inputs JSON exceeds 65535 Unicode scalar characters")
    require(len(encoded) <= MAX_INPUT_BYTES, "compact dispatch inputs JSON exceeds the conservative 65535 UTF-8-byte limit")
    return encoded


def verify_transport_v2(evidence):
    """Independently reconcile a v2 ledger, response receipts and server journal."""
    require(evidence.get("schema_version") == REPLAN_SCHEMA, "new acceptance requires hosted replan evidence v2")
    origin = evidence.get("origin")
    ledger = evidence.get("transport_ledger")
    require(isinstance(origin, dict) and origin.get("kind") == "measured-v2", "measured-v2 transport origin is required")
    require(isinstance(ledger, dict) and ledger.get("schema_version") == "sigra.phase253.http-ledger/v2",
            "measured HTTP ledger v2 is required")
    require(ledger.get("window_id") == origin.get("window_id") and ledger.get("source_sha256") == origin.get("source_sha256"),
            "transport ledger window or source differs from the measured origin")
    require(ledger.get("terminal_stop") in (None, {}), "measured transport ledger has a terminal stop")
    budget = evidence.get("budget")
    transactions = ledger.get("transactions")
    receipts = evidence.get("transport_receipts")
    journal = evidence.get("server_journal")
    require(isinstance(budget, dict) and isinstance(transactions, list), "v2 request budget or transaction ledger is missing")
    require(type(budget.get("request_count")) is int and budget["request_count"] == len(transactions),
            "request count differs from retained measured transactions")
    require(isinstance(receipts, list) and len(receipts) == len(transactions), "retained response receipts are incomplete")
    if origin.get("channel") == "hermetic-https":
        require(isinstance(journal, list) and len(journal) == len(transactions), "independent HTTPS server journal is incomplete")
    elif journal is not None:
        require(isinstance(journal, list) and len(journal) == len(transactions), "optional server journal is incomplete")
    require(type(budget.get("max_requests")) is int and 0 <= len(transactions) <= budget["max_requests"], "measured request budget exceeded")
    seen_pages = set()
    seen_hops = set()
    observed_rows = journal if isinstance(journal, list) else [None] * len(transactions)
    for index, (transaction, receipt, observed) in enumerate(zip(transactions, receipts, observed_rows), 1):
        require(isinstance(transaction, dict) and isinstance(receipt, dict)
                and (observed is None or isinstance(observed, dict)), "transport records must be objects")
        require(transaction.get("sequence") == index and receipt.get("sequence") == index
                and (observed is None or observed.get("sequence") == index),
                "transport sequence is duplicated, missing or inconsistent")
        for field in ("method", "url", "url_sha256", "route_id", "page_ordinal", "hop_ordinal", "actual_status", "scrubbed_headers",
                      "response_sha256", "source_sha256", "window_id", "request_sha256", "request_body_base64",
                      "response_body_base64", "response_bytes", "scrubbed_response_bytes", "dispatch_inputs",
                      "input_key_count", "input_unicode_scalars", "input_utf8_bytes", "input_sha256"):
            require(receipt.get(field) == transaction.get(field)
                    and (observed is None or observed.get(field) == transaction.get(field)),
                    f"transport {field} differs across ledger, receipt and journal")
        require(transaction.get("window_id") == origin["window_id"] and transaction.get("source_sha256") == origin["source_sha256"],
                "transaction escaped the measured source window")
        require(transaction.get("state") == "complete" and type(transaction.get("actual_status")) is int
                and 100 <= transaction["actual_status"] <= 599, "transaction lacks its actual completed HTTP status")
        require(isinstance(transaction.get("url_sha256"), str) and re.fullmatch(r"[a-f0-9]{64}", transaction["url_sha256"]),
                "measured request URL digest is malformed")
        if "?[REDACTED]" not in transaction["url"]:
            require(sha256(transaction["url"].encode()) == transaction["url_sha256"], "measured request URL digest differs from retained URL")
        require(transaction["actual_status"] not in (401, 403, 429), "authentication or rate limit requires a terminal stop")
        body_b64 = transaction.get("response_body_base64")
        require(isinstance(body_b64, str), "measured response body bytes are missing")
        try:
            body = base64.b64decode(body_b64, validate=True)
        except (ValueError, base64.binascii.Error) as error:
            raise VerificationError("measured response body encoding is invalid") from error
        require(sha256(body) == transaction.get("response_sha256"), "measured response digest differs from retained bytes")
        require(type(transaction.get("response_bytes")) is int and transaction["response_bytes"] >= 0
                and type(transaction.get("scrubbed_response_bytes")) is int
                and transaction["scrubbed_response_bytes"] == len(body),
                "measured response or scrubbed-byte count differs from retained bytes")
        content_length = transaction.get("scrubbed_headers", {}).get("content-length")
        if isinstance(content_length, str) and content_length.isdigit():
            require(int(content_length) == transaction["response_bytes"], "actual Content-Length differs from measured response bytes")
        page = transaction.get("page_ordinal")
        hop = transaction.get("hop_ordinal")
        if page is not None:
            require(type(page) is int and page >= 1 and (transaction.get("route_id"), page) not in seen_pages,
                    "unknown or duplicate page ordinal")
            seen_pages.add((transaction.get("route_id"), page))
        if hop not in (None, 0) or transaction.get("request_group") is not None:
            require(type(hop) is int and hop >= 0 and isinstance(transaction.get("request_group"), str)
                    and (transaction["request_group"], hop) not in seen_hops, "unknown or duplicate redirect hop")
            seen_hops.add((transaction["request_group"], hop))
        if transaction.get("method") == "POST" and transaction.get("route_id") == "dispatch":
            inputs = transaction.get("dispatch_inputs")
            canonical = serialize_dispatch_inputs(inputs)
            workflow_id = evidence.get("expected", {}).get("workflow_id")
            require(type(workflow_id) is int and transaction.get("url") ==
                    f"https://api.github.com/repos/szTheory/sigra/actions/workflows/{workflow_id}/dispatches",
                    "dispatch request origin or workflow identity differs from the frozen canary")
            try:
                request_body = base64.b64decode(transaction.get("request_body_base64", ""), validate=True)
                request_json = json.loads(request_body.decode("utf-8", "strict"))
            except (ValueError, base64.binascii.Error, UnicodeError, json.JSONDecodeError) as error:
                raise VerificationError("dispatch request body bytes are missing or malformed") from error
            require(sha256(request_body) == transaction.get("request_sha256")
                    and isinstance(request_json, dict) and request_json.get("inputs") == inputs
                    and canonical in request_body,
                    "dispatch input metrics differ from exact transmitted request bytes")
            require(transaction.get("input_key_count") == len(inputs)
                    and transaction.get("input_unicode_scalars") == len(canonical.decode("utf-8"))
                    and transaction.get("input_utf8_bytes") == len(canonical)
                    and transaction.get("input_sha256") == sha256(canonical),
                    "dispatch metrics do not match exact transmitted inputs bytes")
    grouped_pages = {}
    for route, page in seen_pages:
        grouped_pages.setdefault(route, []).append(page)
    for route, pages in grouped_pages.items():
        require(sorted(pages) == list(range(1, max(pages) + 1)), f"page sequence for {route} has a gap or unknown page")
    grouped_hops = {}
    for group, hop in seen_hops:
        grouped_hops.setdefault(group, []).append(hop)
    for group, hops in grouped_hops.items():
        require(sorted(hops) == list(range(0, max(hops) + 1)), f"redirect hop sequence for {group} has a gap or unknown hop")
    return {"status": "transport_verified", "requests": len(transactions), "window_id": origin["window_id"]}


def verify_effective_checks(evidence):
    """Require complete branch and legacy rules plus native producer app identity."""
    checks = evidence.get("effective_checks")
    require(isinstance(checks, dict), "fresh effective branch rules are missing")
    require(checks.get("endpoint") == "/repos/szTheory/sigra/rules/branches/main"
            and checks.get("query") == {"per_page": 100}, "fresh rules must come from the main branch endpoint with per_page=100")
    require(checks.get("complete") is True and checks.get("terminal_page") in (1, 2), "branch rules pagination is incomplete")
    require(checks.get("ruleset_summary") is not True, "ruleset summary metadata cannot establish effective branch rules")
    transactions = evidence["transport_ledger"]["transactions"]
    by_sequence = {item["sequence"]: item for item in transactions}
    pages = checks.get("rules_pages")
    require(isinstance(pages, list) and len(pages) == checks.get("terminal_page"), "fresh branch rules page bodies are incomplete")
    raw_required = []
    for expected_page, page in enumerate(pages, 1):
        require(isinstance(page, dict) and page.get("page") == expected_page, "branch rules page order is incomplete")
        tx = by_sequence.get(page.get("sequence"))
        require(isinstance(tx, dict) and tx.get("route_id") == "rules_main" and tx.get("actual_status") == 200
                and tx.get("page_ordinal") == expected_page, "rules page is not tied to a measured main-branch request")
        expected_url = f"https://api.github.com/repos/szTheory/sigra/rules/branches/main?per_page=100&page={expected_page}"
        require(tx.get("url") == expected_url, "rules page used the wrong endpoint, page or per_page value")
        records = page.get("records")
        require(isinstance(records, list) and len(records) <= 100, "branch rules page exceeds the GitHub page limit")
        try:
            actual_body = json.loads(base64.b64decode(tx["response_body_base64"], validate=True).decode("utf-8", "strict"))
        except (KeyError, ValueError, UnicodeError, json.JSONDecodeError) as error:
            raise VerificationError("fresh rules response body is malformed") from error
        require(actual_body == records, "retained branch rules differ from measured response bytes")
        for rule in records:
            if isinstance(rule, dict) and rule.get("type") == "required_status_checks":
                values = rule.get("parameters", {}).get("required_status_checks")
                require(isinstance(values, list), "required-status-check rule is malformed")
                raw_required.extend(values)
        link = tx.get("scrubbed_headers", {}).get("link", [])
        has_next = any(isinstance(item, dict) and item.get("rel") == "next" for item in link)
        if expected_page == 1 and (len(records) == 100 or has_next):
            require(len(pages) == 2, "full or continued first rules page requires one charged next page")
        if expected_page == 2:
            require(not has_next and len(records) < 100, "full second rules page or unexhausted pagination blocks completeness")
        if expected_page == 1 and len(records) < 100 and not has_next:
            require(len(pages) == 1, "terminal first rules page has an unexpected additional page")
    legacy = checks.get("legacy_protection")
    require(isinstance(legacy, dict), "legacy branch-protection response is missing")
    legacy_tx = by_sequence.get(legacy.get("sequence"))
    require(isinstance(legacy_tx, dict) and legacy_tx.get("route_id") == "branch_protection"
            and legacy_tx.get("url") == "https://api.github.com/repos/szTheory/sigra/branches/main/protection",
            "legacy branch-protection status is not tied to its typed measured request")
    require(legacy.get("status") == legacy_tx.get("actual_status"), "legacy branch-protection status differs from actual HTTP status")
    if legacy_tx["actual_status"] == 404:
        require(legacy.get("present") is False and legacy.get("required") == [], "legacy 404 was reinterpreted as an active check list")
    else:
        require(legacy_tx["actual_status"] == 200 and legacy.get("present") is True,
                "legacy branch-protection response is neither a real 200 nor 404")
        raw_legacy = legacy.get("required")
        require(isinstance(raw_legacy, list), "legacy required-check list is malformed")
        raw_required.extend(raw_legacy)
    required = checks.get("required")
    require(isinstance(required, list) and len(required) == 5, "effective required-check inventory must contain exactly five entries")
    by_name = {}
    for item in required:
        require(isinstance(item, dict) and isinstance(item.get("context"), str), "required-check entry is malformed")
        name = item["context"]
        require(name not in by_name, "effective required-check inventory contains a duplicate name")
        by_name[name] = item
    require(set(by_name) == set(REQUIRED_NAMES), "effective required-check names differ from the frozen five")
    raw_by_name = {}
    for item in raw_required:
        require(isinstance(item, dict) and isinstance(item.get("context"), str), "raw effective rule entry is malformed")
        name = item["context"]
        require(name not in raw_by_name, "raw branch and legacy rules duplicate a required-check name")
        raw_by_name[name] = item
    require(set(raw_by_name) == set(REQUIRED_NAMES), "raw measured rules do not establish the exact five required names")
    for name, rule in by_name.items():
        raw = raw_by_name[name]
        raw_app = raw.get("app_id", raw.get("integration_id"))
        app_id = rule.get("app_id", rule.get("integration_id"))
        require(app_id == raw_app, f"normalized app scope differs from measured rule for {name}")
    producers = evidence.get("producer_checks")
    require(isinstance(producers, list) and len(producers) == 5, "native producer check inventory must contain exactly five entries")
    producer_by_name = {}
    for producer in producers:
        require(isinstance(producer, dict) and producer.get("name") in REQUIRED_NAMES, "native producer check is missing or unknown")
        name = producer["name"]
        require(name not in producer_by_name, "native producer check is duplicated")
        require(type(producer.get("app_id")) is int and producer["app_id"] > 0
                and isinstance(producer.get("source"), str) and producer["source"], "native producer app/source identity is missing")
        producer_by_name[name] = producer
    source_receipt = checks.get("native_check_runs")
    require(isinstance(source_receipt, dict), "native check-run source receipt is missing")
    source_tx = by_sequence.get(source_receipt.get("sequence"))
    expected_sha = evidence.get("expected", {}).get("candidate_sha")
    require(isinstance(source_tx, dict) and source_tx.get("route_id") == "check_runs" and source_tx.get("actual_status") == 200,
            "native check-run metadata is not tied to a successful measured API response")
    require(isinstance(expected_sha, str) and len(expected_sha) == 40
            and source_tx.get("url") == f"https://api.github.com/repos/szTheory/sigra/commits/{expected_sha}/check-runs?per_page=100&page=1",
            "native check-run source uses a different candidate SHA or incomplete page")
    try:
        native_body = json.loads(base64.b64decode(source_tx["response_body_base64"], validate=True).decode("utf-8", "strict"))
    except (KeyError, ValueError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError("native check-run response body is malformed") from error
    native_runs = native_body.get("check_runs") if isinstance(native_body, dict) else None
    require(isinstance(native_runs, list) and native_body.get("total_count") == len(native_runs) and len(native_runs) < 100,
            "native check-run response is incomplete or needs another charged page")
    native_by_name = {}
    for run in native_runs:
        if not isinstance(run, dict) or run.get("name") not in REQUIRED_NAMES:
            continue
        name = run["name"]
        app = run.get("app")
        require(name not in native_by_name and isinstance(app, dict) and type(app.get("id")) is int and app["id"] > 0
                and isinstance(app.get("slug"), str) and app["slug"]
                and isinstance(run.get("html_url"), str) and run["html_url"].startswith("https://"),
                f"native check app or source identity is missing or duplicated: {name}")
        native_by_name[name] = {"app_id": app["id"], "app_slug": app["slug"],
                                "source": run["html_url"], "conclusion": run.get("conclusion")}
    require(set(native_by_name) == set(REQUIRED_NAMES), "native check-run response does not contain exactly the five producer sources")
    for name in REQUIRED_NAMES:
        rule = by_name[name]
        producer = producer_by_name[name]
        require({key: producer.get(key) for key in ("app_id", "app_slug", "source", "conclusion")} == native_by_name[name],
                f"declared producer app/source differs from native check-run metadata for {name}")
        app_id = rule.get("app_id", rule.get("integration_id"))
        require(app_id is None or type(app_id) is int and app_id > 0 or app_id == -1,
                f"effective app scope for {name} is malformed")
        if app_id is None or app_id == -1:
            require(type(producer.get("app_id")) is int and producer["app_id"] > 0,
                    f"any-app rule for {name} lacks a native matching producer app")
        else:
            require(producer["app_id"] == app_id, f"native producer app differs from effective rule for {name}")
        require(isinstance(producer.get("source"), str) and producer["source"]
                and rule.get("source") == producer.get("source"), f"native producer source differs from effective rule for {name}")
        require(producer.get("conclusion") == "success", f"native producer did not pass: {name}")
    return {"status": "effective_checks_verified", "names": list(REQUIRED_NAMES)}


def hydrate_effective_checks(evidence):
    """Build the v2 check inventory from measured response bodies, never names alone."""
    ledger = evidence.get("transport_ledger")
    require(isinstance(ledger, dict) and isinstance(ledger.get("transactions"), list), "measured transport ledger is missing")
    transactions = ledger["transactions"]
    def body(tx):
        try:
            return json.loads(base64.b64decode(tx["response_body_base64"], validate=True).decode("utf-8", "strict"))
        except (KeyError, ValueError, UnicodeError, json.JSONDecodeError) as error:
            raise VerificationError("a fresh rules/check response is missing valid retained body bytes") from error
    rule_txs = [tx for tx in transactions if tx.get("route_id") == "rules_main"]
    legacy_txs = [tx for tx in transactions if tx.get("route_id") == "branch_protection"]
    check_txs = [tx for tx in transactions if tx.get("route_id") == "check_runs"]
    require(rule_txs and len(rule_txs) <= 2 and len(legacy_txs) == 1 and len(check_txs) == 1,
            "measured preflight is missing branch rules, legacy protection or native check-run request")
    pages = []
    raw_required = []
    for number, tx in enumerate(rule_txs, 1):
        records = body(tx)
        require(isinstance(records, list) and tx.get("page_ordinal") == number and tx.get("actual_status") == 200,
                "measured effective rules page is incomplete or out of order")
        pages.append({"page": number, "sequence": tx["sequence"], "records": records})
        for rule in records:
            if isinstance(rule, dict) and rule.get("type") == "required_status_checks":
                required = rule.get("parameters", {}).get("required_status_checks")
                require(isinstance(required, list), "required-status-check response is malformed")
                raw_required.extend(required)
    last_page_len = len(pages[-1]["records"])
    require(last_page_len < 100 and (len(pages) == 2 or len(pages[0]["records"]) < 100),
            "rules pagination is not explicitly complete")
    legacy_tx = legacy_txs[0]
    if legacy_tx.get("actual_status") == 404:
        legacy = {"present": False, "status": 404, "sequence": legacy_tx["sequence"], "required": []}
    else:
        require(legacy_tx.get("actual_status") == 200, "legacy branch protection returned neither 200 nor 404")
        protected = body(legacy_tx)
        legacy_checks = protected.get("required_status_checks", {}) if isinstance(protected, dict) else None
        require(isinstance(legacy_checks, dict), "legacy branch-protection checks are malformed")
        contexts = legacy_checks.get("contexts", [])
        checks = legacy_checks.get("checks", [])
        require(isinstance(contexts, list) and isinstance(checks, list), "legacy required check arrays are malformed")
        legacy_required = [{"context": name, "app_id": None} for name in contexts]
        legacy_required += [{"context": item.get("context"), "app_id": item.get("app_id")} for item in checks if isinstance(item, dict)]
        raw_required.extend(legacy_required)
        legacy = {"present": True, "status": 200, "sequence": legacy_tx["sequence"], "required": legacy_required}
    check_tx = check_txs[0]
    check_url = check_tx.get("url", "")
    expected_sha = evidence.get("expected", {}).get("candidate_sha")
    require(check_tx.get("actual_status") == 200 and isinstance(expected_sha, str)
            and check_url == f"https://api.github.com/repos/szTheory/sigra/commits/{expected_sha}/check-runs?per_page=100&page=1",
            "native check-run request is not tied to the frozen source commit")
    native_doc = body(check_tx)
    native_runs = native_doc.get("check_runs") if isinstance(native_doc, dict) else None
    require(isinstance(native_runs, list) and native_doc.get("total_count") == len(native_runs) and len(native_runs) < 100,
            "native check-run response is incomplete or needs another charged page")
    native_by_name = {}
    for run in native_runs:
        if not isinstance(run, dict) or run.get("name") not in REQUIRED_NAMES:
            continue
        app = run.get("app")
        name = run["name"]
        require(name not in native_by_name and isinstance(app, dict) and type(app.get("id")) is int
                and isinstance(app.get("slug"), str) and isinstance(run.get("html_url"), str),
                f"native check source is missing or duplicated: {name}")
        native_by_name[name] = {"name": name, "app_id": app["id"], "app_slug": app["slug"],
                                "source": run["html_url"], "conclusion": run.get("conclusion")}
    require(set(native_by_name) == set(REQUIRED_NAMES), "native check-run response does not establish exactly five producers")
    raw_by_name = {}
    for item in raw_required:
        require(isinstance(item, dict) and isinstance(item.get("context"), str), "raw required check rule is malformed")
        name = item["context"]
        require(name not in raw_by_name, "effective branch and legacy rules duplicate a check name")
        raw_by_name[name] = item
    require(set(raw_by_name) == set(REQUIRED_NAMES), "complete fresh rules do not establish the exact five names")
    normalized = []
    for name in REQUIRED_NAMES:
        raw = raw_by_name[name]
        app_id = raw.get("app_id", raw.get("integration_id"))
        require(app_id is None or type(app_id) is int and app_id > 0 or app_id == -1,
                f"effective source scope is malformed for {name}")
        native = native_by_name[name]
        normalized.append({"context": name, "app_id": app_id, "integration_id": raw.get("integration_id"),
                           "app_slug": native["app_slug"], "source": native["source"]})
    evidence["effective_checks"] = {"endpoint": "/repos/szTheory/sigra/rules/branches/main", "query": {"per_page": 100},
        "complete": True, "terminal_page": len(pages), "rules_pages": pages, "legacy_protection": legacy,
        "native_check_runs": {"sequence": check_tx["sequence"]}, "required": normalized}
    evidence["producer_checks"] = list(native_by_name.values())


def verify_attempt_jobs(evidence):
    """Count every actually executed job across original and retry run attempts."""
    attempts = evidence.get("run_attempts")
    require(isinstance(attempts, list) and attempts, "all original and retry run-attempt job receipts are required")
    identities = set()
    executed = 0
    for attempt in attempts:
        require(isinstance(attempt, dict) and isinstance(attempt.get("run_id"), (str, int))
                and type(attempt.get("run_attempt")) is int and attempt["run_attempt"] >= 1,
                "run-attempt identity is malformed")
        jobs = attempt.get("jobs")
        require(isinstance(jobs, list) and jobs, "run-attempt job receipts are missing")
        for job in jobs:
            require(isinstance(job, dict) and isinstance(job.get("job_id"), (str, int))
                    and isinstance(job.get("name"), str), "native job receipt is malformed")
            identity = (str(attempt["run_id"]), attempt["run_attempt"], str(job["job_id"]))
            require(identity not in identities, "duplicate job receipt across run attempts")
            identities.add(identity)
            conclusion = job.get("conclusion")
            require(conclusion in {"success", "failure", "cancelled", "timed_out", "action_required", "neutral", "skipped"},
                    "job receipt has no actual terminal conclusion")
            actual = conclusion != "skipped"
            require(job.get("executed") is actual, "job execution claim differs from native conclusion")
            executed += int(actual)
    budget = evidence.get("budget", {})
    require(type(budget.get("actual_jobs")) is int and budget["actual_jobs"] == executed,
            "actual job budget differs from original/retry/cancelled/verifier job receipts")
    return executed


def validate_single_result_zip(archive_bytes):
    """Validate and stream one bounded regular result member without extracting paths."""
    import stat
    import struct
    require(isinstance(archive_bytes, bytes) and len(archive_bytes) <= MAX_ZIP_BYTES, "compressed result ZIP exceeds 2 MiB")
    require(len(archive_bytes) >= 22, "result ZIP is truncated")
    eocd = archive_bytes.rfind(b"PK\x05\x06")
    require(eocd >= 0 and eocd + 22 <= len(archive_bytes), "result ZIP end record is missing")
    comment_len = struct.unpack_from("<H", archive_bytes, eocd + 20)[0]
    require(eocd + 22 + comment_len == len(archive_bytes), "result ZIP has trailing bytes or a concatenated archive")
    try:
        with zipfile.ZipFile(io.BytesIO(archive_bytes)) as bundle:
            entries = bundle.infolist()
            require(len(entries) == 1, "result ZIP must contain exactly one member")
            info = entries[0]
            require(info.filename == "canary-result.json" and not info.is_dir(), "result ZIP member path is unsafe or unexpected")
            mode = (info.external_attr >> 16) & 0xFFFF
            file_type = stat.S_IFMT(mode)
            require(not stat.S_ISLNK(mode) and file_type in (0, stat.S_IFREG), "result ZIP member is not a safe regular file")
            require(not info.flag_bits & 1 and info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED),
                    "result ZIP is encrypted or uses an unsupported compression method")
            require(info.file_size <= MAX_MEMBER_BYTES and info.compress_size <= MAX_ZIP_BYTES, "result ZIP member metadata exceeds limits")
            require(info.header_offset == 0 and archive_bytes[:4] == b"PK\x03\x04", "result ZIP has a prefix or invalid local header")
            local = struct.unpack_from("<IHHHHHIIIHH", archive_bytes, 0)
            signature, _version, local_flags, local_method, _time, _date, local_crc, local_compressed, local_uncompressed, local_name_len, local_extra_len = local
            require(signature == 0x04034B50 and local_flags == info.flag_bits and local_method == info.compress_type,
                    "ZIP local flags or compression method differs from the central directory")
            local_name = archive_bytes[30:30 + local_name_len]
            require(local_name.decode("utf-8" if info.flag_bits & 0x800 else "cp437") == info.filename,
                    "ZIP local and central member names differ")
            data_start = 30 + local_name_len + local_extra_len
            require(data_start + info.compress_size <= eocd, "ZIP member stream is truncated or overlaps its directory")
            if info.flag_bits & 0x08:
                descriptor = data_start + info.compress_size
                if archive_bytes[descriptor:descriptor + 4] == b"PK\x07\x08":
                    descriptor += 4
                desc_crc, desc_compressed, desc_uncompressed = struct.unpack_from("<III", archive_bytes, descriptor)
                require((desc_crc, desc_compressed, desc_uncompressed) == (info.CRC, info.compress_size, info.file_size),
                        "ZIP data descriptor differs from central member metadata")
            else:
                require((local_crc, local_compressed, local_uncompressed) == (info.CRC, info.compress_size, info.file_size),
                        "ZIP local sizes or CRC differ from central member metadata")
            output = bytearray()
            with bundle.open(info, "r") as stream:
                while True:
                    chunk = stream.read(min(65536, MAX_MEMBER_BYTES + 1 - len(output)))
                    if not chunk:
                        break
                    output.extend(chunk)
                    require(len(output) <= MAX_MEMBER_BYTES, "streamed result ZIP member exceeds 4 MiB")
            require(len(output) == info.file_size, "streamed result member length differs from ZIP metadata")
            return bytes(output)
    except (OSError, UnicodeError, zipfile.BadZipFile, zipfile.LargeZipFile, struct.error, RuntimeError) as error:
        if isinstance(error, VerificationError):
            raise
        raise VerificationError(f"result ZIP is malformed: {error}") from error


def decode_matrix_payload(value):
    """Strictly decode one bounded base64+gzip JSON object, rejecting stream tails."""
    import zlib
    require(isinstance(value, str) and len(value) <= 4 * ((MAX_MEMBER_BYTES + 2) // 3), "matrix payload encoding exceeds its fixed bound")
    try:
        compressed = base64.b64decode(value, validate=True)
    except (ValueError, base64.binascii.Error) as error:
        raise VerificationError("matrix payload base64 is malformed") from error
    require(len(compressed) <= MAX_MEMBER_BYTES, "compressed matrix payload exceeds 4 MiB")
    decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
    try:
        output = decoder.decompress(compressed, MAX_MEMBER_BYTES + 1)
        require(len(output) <= MAX_MEMBER_BYTES and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail,
                "matrix gzip stream is truncated, concatenated, trailing or oversized")
    except zlib.error as error:
        raise VerificationError("matrix gzip payload is malformed") from error
    try:
        text = output.decode("utf-8", "strict")
        decoded = json.loads(text)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError("matrix payload is not one UTF-8 JSON object") from error
    require(isinstance(decoded, dict), "matrix payload root must be one JSON object")
    return decoded


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
    require(isinstance(fixture_ref, str) and fixture_ref.startswith("refs/heads/gsd/253-replan-"),
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
    require(len(archive_base64) <= 4 * ((MAX_ZIP_BYTES + 2) // 3),
            "base64 archive representation exceeds the compressed artifact bound")
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
    archived_result = validate_single_result_zip(archive_bytes)
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


# --------------------------------------------------------------------------------------------------
# Phase 253 plan 42: independent actual-PR proof (normal/docs-only) and accepted-only completion.
# Everything below compares exact UTF-8 strings: no strip, casefold, or Unicode normalization.
# --------------------------------------------------------------------------------------------------
def fail_closed(function):
    """Malformed shapes (missing keys, wrong types) are verification failures, never crashes or silent passes."""
    import functools

    @functools.wraps(function)
    def wrapper(*args, **kwargs):
        try:
            return function(*args, **kwargs)
        except VerificationError:
            raise
        except (KeyError, TypeError, AttributeError, IndexError, ValueError, UnicodeError, OSError) as error:
            raise VerificationError(f"{function.__name__}: malformed evidence ({type(error).__name__}: {error})") from error
    return wrapper


PR_SCHEMA = "sigra.phase253.pr-proof-evidence/v1"
PR_FREEZE_SCHEMA = "sigra.phase253.pr-proof-freeze/v1"
COMPLETION_SCHEMA = "sigra.phase253.completion-evidence/v1"
REPOSITORY = "szTheory/sigra"
WORKFLOW_ID = 259268962
DOCS_PATH = "guides/reference/phase253-docs-only-proof.md"
CLASSIFIER_JOB = "Detect docs-only change"
PR_FAMILIES = ("normal", "docs-only")
MAX_PR_EVIDENCE_BYTES = 128 * 1024 * 1024
MAX_PRODUCER_ZIP_BYTES = 4 * 1024 * 1024
MAX_PRODUCER_MEMBER_BYTES = 64 * 1024 * 1024
MAX_PRODUCER_TOTAL_BYTES = 256 * 1024 * 1024
TERMINAL_POLL_LIMITS = {"normal": 15, "docs-only": 12}
SHA40 = re.compile(r"[a-f0-9]{40}")
SHA64 = re.compile(r"[a-f0-9]{64}")
REPO_ROOT = Path(__file__).resolve().parents[2]
_TRANSPORT = None


def transport_module():
    global _TRANSPORT
    if _TRANSPORT is None:
        spec = importlib.util.spec_from_file_location("ci_hosted_transport", Path(__file__).with_name("ci-hosted-transport.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _TRANSPORT = module
    return _TRANSPORT


def b64(value, what):
    try:
        return base64.b64decode(value, validate=True)
    except (TypeError, ValueError, base64.binascii.Error) as error:
        raise VerificationError(f"{what} base64 is malformed") from error


def tx_json(tx, what):
    try:
        return json.loads(b64(tx.get("response_body_base64"), what).decode("utf-8", "strict"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError(f"{what} response body is not valid UTF-8 JSON") from error


def git_blob_sha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def canonical_digest(value):
    return sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


@fail_closed
def verify_pr_transport(evidence):
    """Reconcile the combined production ledger, allocation purpose, category predebits and independent server journal."""
    require(evidence.get("repository") == REPOSITORY, "wrong repository in PR proof")
    ledger = evidence.get("transport_ledger")
    require(isinstance(ledger, dict) and ledger.get("schema_version") == "sigra.phase253.http-ledger/v2"
            and isinstance(ledger.get("transactions"), list), "measured production HTTP ledger is missing")
    raw_allocation = b64(evidence.get("allocation_base64"), "allocation")
    try:
        allocation = json.loads(raw_allocation.decode("utf-8", "strict"))
        transport_module()._validate_allocation(allocation)
    except Exception as error:
        raise VerificationError(f"production allocation is invalid: {error}") from error
    require(allocation.get("allocation_kind") == "production" and allocation.get("max_requests") == 120
            and allocation.get("category_limits") == transport_module().PRODUCTION_CATEGORY_LIMITS,
            "PR proof requires the separate production allocation with exactly 120 requests and the frozen categories")
    require(ledger.get("allocation_sha256") == sha256(raw_allocation) and ledger.get("window_id") == allocation["window_id"]
            and ledger.get("source_sha256") == allocation["source_sha256"], "ledger identity differs from the frozen allocation bytes")
    require(ledger.get("terminal_stop") in (None, {}), "measured production ledger has a terminal stop")
    require(allocation["max_elapsed_seconds"] <= 3600, "production clock exceeds 60 minutes")
    hermetic = allocation["mode"] == "hermetic-test"
    require(evidence.get("synthetic") is hermetic, "synthetic label must match the allocation origin (local HTTPS is synthetic, never live)")
    transactions = ledger["transactions"]
    limits = allocation["category_limits"]
    require(0 < len(transactions) <= allocation["max_requests"], "production request count is zero or over its allocation")
    counts, pages, hops = {}, {}, {}
    for index, tx in enumerate(transactions, 1):
        require(isinstance(tx, dict) and tx.get("sequence") == index and tx.get("state") == "complete"
                and type(tx.get("actual_status")) is int and 100 <= tx["actual_status"] <= 599,
                "transaction is missing, out of order, pending or lacks an actual HTTP status")
        require(tx.get("window_id") == allocation["window_id"] and tx.get("source_sha256") == allocation["source_sha256"],
                "transaction escaped the frozen window or source")
        category = tx.get("category")
        require(category in limits, "transaction lacks a frozen category")
        counts[category] = counts.get(category, 0) + 1
        require(counts[category] <= limits[category], f"category {category} exceeded its frozen limit")
        require(tx.get("family") in ("normal", "docs-only", "shared"), "transaction lacks a typed family")
        require(tx["actual_status"] not in (401, 403, 429), "authentication or rate limit requires a terminal stop")
        if hermetic:
            require(tx.get("host") == urlsplit(allocation["test_origin"]).hostname, "synthetic transaction left the local origin")
        else:
            require(tx.get("host") == "api.github.com" or tx.get("host") in allocation.get("download_hosts", []),
                    "live transaction used a host outside api.github.com and the frozen download hosts")
        body = b64(tx.get("response_body_base64"), "response body")
        require(sha256(body) == tx.get("response_sha256") and tx.get("scrubbed_response_bytes") == len(body),
                "retained response bytes differ from their digest")
        if "?[REDACTED]" not in tx.get("url", ""):
            require(sha256(tx["url"].encode()) == tx.get("url_sha256"), "request URL digest differs from retained URL")
        page, hop = tx.get("page_ordinal"), tx.get("hop_ordinal")
        if page is not None:
            key = (tx["family"], tx["route_id"])
            require(type(page) is int and page >= 1 and page not in pages.setdefault(key, []), "unknown or duplicate page ordinal")
            pages[key].append(page)
        if tx.get("request_group") is not None:
            require(type(hop) is int and hop >= 0 and hop not in hops.setdefault(tx["request_group"], []), "unknown or duplicate redirect hop")
            hops[tx["request_group"]].append(hop)
    for key, values in pages.items():
        require(sorted(values) == list(range(1, max(values) + 1)), f"page sequence for {key} has a gap")
    for group, values in hops.items():
        require(sorted(values) == list(range(0, max(values) + 1)) and max(values) <= 2, f"redirect hop sequence for {group} has a gap or exceeds two hops")
    journal = evidence.get("server_journal")
    if hermetic:
        require(isinstance(journal, list) and len(journal) == len(transactions), "independent local HTTPS server journal is incomplete")
        for tx, observed in zip(transactions, journal):
            require(isinstance(observed, dict) and observed.get("method") == tx["method"]
                    and observed.get("status") == tx["actual_status"], "server-observed method or status differs from the ledger")
            path = observed.get("path")
            require(isinstance(path, str) and urlsplit(tx["url"]).path == path.split("?", 1)[0], "server-observed path differs from the ledger")
            if "?[REDACTED]" not in tx["url"]:
                require(urlsplit(tx["url"]).query == (path.split("?", 1)[1] if "?" in path else ""), "server-observed query differs from the ledger")
            require(observed.get("body_sha256") == tx.get("raw_observation_sha256"), "server-served bytes differ from the client observation")
            require(observed.get("request_body_sha256") == tx.get("request_body_sha256"), "server-received request body differs from the ledger")
            require(observed.get("authorization") is None, "credentials reached the local synthetic origin")
    elif journal is not None:
        require(isinstance(journal, list) and len(journal) == len(transactions), "optional server journal is incomplete")
    return allocation, counts


def _family(transactions, family, route):
    return [tx for tx in transactions if tx["family"] == family and tx["route_id"] == route]


def _view_for_checks(evidence, family, allocation, head_sha, check_tx):
    """Build the exact-five effective-check view from shared preflight plus this family's native check response."""
    hermetic = allocation["mode"] == "hermetic-test"
    origin = f"https://{urlsplit(allocation['test_origin']).hostname}" if hermetic else None
    transactions = []
    for tx in evidence["transport_ledger"]["transactions"]:
        keep = (tx["family"] == "shared" and tx["route_id"] in ("rules_main", "branch_protection")) or tx is check_tx
        if keep:
            row = copy.deepcopy(tx)
            if hermetic and row["url"].startswith(origin):
                row["url"] = "https://api.github.com" + row["url"][len(origin):]
            transactions.append(row)
    return {"transport_ledger": {"transactions": transactions}, "expected": {"candidate_sha": head_sha}}


def validate_producer_zip(archive, size_limit=MAX_PRODUCER_ZIP_BYTES):
    """Strict bounded multi-member producer ZIP intake: flat unique regular members, no links or traversal."""
    import stat
    require(isinstance(archive, bytes) and 22 <= len(archive) <= size_limit, "producer ZIP size is outside its bound")
    eocd = archive.rfind(b"PK\x05\x06")
    require(eocd >= 0 and eocd + 22 <= len(archive), "producer ZIP end record is missing")
    comment_len = struct.unpack_from("<H", archive, eocd + 20)[0]
    require(eocd + 22 + comment_len == len(archive), "producer ZIP has trailing bytes or a concatenated archive")
    members, total, names = {}, 0, set()
    try:
        with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
            entries = bundle.infolist()
            require(1 <= len(entries) <= 64, "producer ZIP member count is outside its bound")
            ranges = []
            for info in entries:
                name = info.filename
                require(isinstance(name, str) and name and name not in names, "producer ZIP has a duplicate or empty member")
                names.add(name)
                require(not info.is_dir() and "/" not in name and "\\" not in name and name not in (".", "..")
                        and not name.startswith("/") and "\x00" not in name and name == name.encode("utf-8", "strict").decode("utf-8"),
                        "producer ZIP member path is unsafe, nested, or a directory")
                mode = (info.external_attr >> 16) & 0xFFFF
                require(not stat.S_ISLNK(mode) and stat.S_IFMT(mode) in (0, stat.S_IFREG), "producer ZIP member is not a regular file")
                require(not info.flag_bits & 1 and info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED),
                        "producer ZIP member is encrypted or uses an unsupported method")
                require(info.file_size <= MAX_PRODUCER_MEMBER_BYTES, "producer ZIP member exceeds its bound")
                total += info.file_size
                require(total <= MAX_PRODUCER_TOTAL_BYTES, "producer ZIP expands beyond its aggregate bound")
                signature, _v, _flags, _method, _t, _d, _crc, csize, _usize, name_len, extra_len = struct.unpack_from("<IHHHHHIIIHH", archive, info.header_offset)
                require(signature == 0x04034B50 and archive[info.header_offset + 30:info.header_offset + 30 + name_len].decode(
                    "utf-8" if info.flag_bits & 0x800 else "cp437") == name, "ZIP local and central member names differ")
                start = info.header_offset + 30 + name_len + extra_len
                end = start + info.compress_size
                require(end <= eocd, "producer ZIP member stream is truncated or overlaps the directory")
                ranges.append((info.header_offset, end))
                output = bytearray()
                with bundle.open(info, "r") as stream:
                    while True:
                        chunk = stream.read(min(65536, MAX_PRODUCER_MEMBER_BYTES + 1 - len(output)))
                        if not chunk:
                            break
                        output.extend(chunk)
                        require(len(output) <= MAX_PRODUCER_MEMBER_BYTES, "streamed producer member exceeds its bound")
                require(len(output) == info.file_size, "streamed member length differs from ZIP metadata")
                members[name] = bytes(output)
            ranges.sort()
            for (first_start, first_end), (second_start, _e) in zip(ranges, ranges[1:]):
                require(first_end <= second_start, "producer ZIP members overlap")
    except (OSError, UnicodeError, zipfile.BadZipFile, zipfile.LargeZipFile, struct.error, RuntimeError) as error:
        if isinstance(error, VerificationError):
            raise
        raise VerificationError(f"producer ZIP is malformed: {error}") from error
    return members


def _run_browser_policy(workflow_bytes, producers, identity):
    """Invoke ci-browser-records.mjs, the one policy owner, from a copy rooted at the retained workflow."""
    node = shutil.which("node")
    require(node is not None, "node is required to run the browser-record policy owner")
    with tempfile.TemporaryDirectory(prefix="sigra-pr-proof-policy-") as raw_tmp:
        tmp = str(Path(raw_tmp).resolve())  # the policy owner only runs as main when argv[1] equals its real path
        root = Path(tmp) / "root"
        (root / "scripts/ci").mkdir(parents=True)
        (root / ".github/workflows").mkdir(parents=True)
        for name in ("ci-browser-records.mjs", "ci-playwright-report.mjs"):
            shutil.copyfile(Path(__file__).with_name(name), root / "scripts/ci" / name)
        (root / ".github/workflows/ci.yml").write_bytes(workflow_bytes)
        aggregate = Path(tmp) / "aggregate"
        for directory, members in producers.items():
            target = aggregate / directory
            target.mkdir(parents=True)
            for name, data in members.items():
                (target / name).write_bytes(data)
        identity_file = Path(tmp) / "identity.json"
        identity_file.write_text(json.dumps(identity))
        result = subprocess.run([node, str(root / "scripts/ci/ci-browser-records.mjs"), "--verify", "--directory", str(aggregate),
                                 "--identity", str(identity_file), "--native-result", "success"],
                                capture_output=True, text=True, timeout=120, check=False)
        require(result.returncode == 0, f"browser execution policy owner rejected the producer set: {result.stderr.strip()[:400]}")
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise VerificationError("browser execution policy owner returned malformed output") from error


@fail_closed
def verify_pr_family(evidence, family, _capture=None):
    """Independently verify one actual PR family from retained measured API bytes and producer artifacts."""
    require(family in PR_FAMILIES, "family must be normal or docs-only")
    require(isinstance(evidence, dict) and evidence.get("schema_version") == PR_SCHEMA and evidence.get("family") == family,
            "PR proof schema or family differs from the requested family")
    allocation, counts = verify_pr_transport(evidence)
    collection = evidence.get("collection")
    require(isinstance(collection, dict) and collection.get("complete") is True and collection.get("stop") is None,
            "collection did not complete (an honest stop is preserved but never accepted)")
    freeze = evidence.get("freeze")
    require(isinstance(freeze, dict) and freeze.get("schema_version") == PR_FREEZE_SCHEMA, "frozen PR proof document is missing")
    stated = freeze.get("freeze_sha256")
    require(stated == canonical_digest({key: value for key, value in freeze.items() if key != "freeze_sha256"}),
            "frozen PR proof digest differs from its content")
    require(freeze.get("workflow") == {"id": WORKFLOW_ID, "path": WORKFLOW_PATH}, "frozen workflow identity mismatch")
    require(freeze.get("required_names") == list(REQUIRED_NAMES), "frozen required-check names differ from the exact five")
    spec = freeze.get(family)
    require(isinstance(spec, dict), "frozen family specification is missing")
    for key in ("head_sha", "workflow_blob"):
        require(isinstance(spec.get(key), str) and SHA40.fullmatch(spec[key]), f"frozen {key} is malformed")
    head_sha, head_ref, base_ref = spec["head_sha"], spec.get("head_ref"), spec.get("base_ref")
    expected_refs = ({"head": "gsd/253-replan-candidate", "base": "main"} if family == "normal"
                     else {"head": "gsd/253-replan-docs-head", "base": "gsd/253-replan-docs-base"})
    require(head_ref == expected_refs["head"] and base_ref == expected_refs["base"], "frozen PR head/base refs are not the exact proof refs")
    transactions = evidence["transport_ledger"]["transactions"]
    shared = [tx for tx in transactions if tx["family"] == "shared"]
    require(sum(1 for tx in shared if tx["route_id"] == "branch_protection") == 1
            and 1 <= sum(1 for tx in shared if tx["route_id"] == "rules_main") <= 2, "exactly one shared fresh preflight is required")

    if family == "docs-only":
        publications = [tx for tx in transactions if tx["family"] == family and tx["category"] == "docs_publication"]
        require(len(publications) == 14 and all(tx["actual_status"] in (200, 201, 404) for tx in publications),
                "docs base/head object and ref publication must use exactly its 14 reserved requests")
        by_route = {}
        for tx in publications:
            by_route.setdefault(tx["route_id"], []).append(tx)
        publication = spec.get("publication") or {}
        require([tx_json(tx, "docs tree").get("sha") for tx in by_route.get("git_create_tree", [])] == [publication.get("docs_base_tree"), publication.get("docs_head_tree")],
                "server docs trees differ from the frozen trees")
        require([tx_json(tx, "docs commit").get("sha") for tx in by_route.get("git_create_commit", [])] == [spec.get("base_sha"), head_sha],
                "server docs commits differ from the frozen base and head commits")
        require([tx["actual_status"] for tx in by_route.get("get_ref", [])] == [404, 200, 404, 200]
                and [tx_json(tx, "docs ref").get("object", {}).get("sha") for tx in by_route.get("create_ref", [])] == [spec.get("base_sha"), head_sha],
                "scoped docs refs were not created exactly once from absent and read back")
        require(spec.get("local_diff_paths") == [DOCS_PATH] and spec.get("base_local_diff_paths") == [WORKFLOW_PATH],
                "frozen docs local diffs are not exactly the trigger-only base and the one documentation file")
        readbacks = [tx_json(tx, "docs commit readback") for tx in by_route.get("git_get_commit", [])]
        require(len(readbacks) == 2 and [r.get("sha") for r in readbacks] == [spec.get("base_sha"), head_sha]
                and [[p.get("sha") for p in r.get("parents", [])] for r in readbacks] == [[publication.get("candidate_sha")], [spec.get("base_sha")]]
                and [r.get("message") for r in readbacks] == ["Phase 253 docs probe base workflow exception\n", "Phase 253 docs-only probe head\n"],
                "docs base must be one unsigned child of the exact candidate and docs head one child of the docs base")

    creates = _family(transactions, family, "pr_create")
    require(len(creates) == 1 and creates[0]["actual_status"] == 201 and creates[0]["category"] == "pr_create", "exactly one draft PR creation is required")
    created = tx_json(creates[0], "PR creation")
    require(isinstance(created, dict) and type(created.get("number")) is int and created["number"] > 0, "created PR number is missing")
    number = created["number"]

    def check_pr(pr, label):
        require(isinstance(pr, dict) and pr.get("number") == number and pr.get("draft") is True and pr.get("merged") is False
                and pr.get("state") == "open", f"{label} is not the same open unmerged draft PR")
        head, base = pr.get("head") or {}, pr.get("base") or {}
        require(head.get("ref") == head_ref and head.get("sha") == head_sha, f"{label} head differs from the frozen published head")
        require(base.get("ref") == base_ref and (base.get("repo") or {}).get("full_name") == REPOSITORY
                and (head.get("repo") or {}).get("full_name") == REPOSITORY, f"{label} base or repository identity differs")
        return base.get("sha")

    check_pr(created, "created PR")
    reads = [tx for tx in transactions if tx["family"] == family and tx["route_id"] == "pr_read"]
    require(len(reads) >= 1 and all(tx["actual_status"] == 200 for tx in reads), "the PR must be re-read after the run for its tested merge commit")
    merges, bases = set(), set()
    for tx in reads:
        document = tx_json(tx, "PR read")
        bases.add(check_pr(document, "read PR"))
        merge = document.get("merge_commit_sha")
        require(isinstance(merge, str) and SHA40.fullmatch(merge) and merge != head_sha, "PR has no distinct tested merge commit")
        merges.add(merge)
    require(len(merges) == 1 and len(bases) == 1 and None not in bases, "tested merge commit or base changed during the proof")
    merge_sha, base_sha = merges.pop(), bases.pop()

    compares = _family(transactions, family, "compare")
    require(len(compares) == (2 if family == "docs-only" else 1) and all(tx["actual_status"] == 200 for tx in compares),
            "the PR compare (and for docs the candidate-to-docs-base compare) is required")
    require(urlsplit(compares[0]["url"]).path.endswith(f"/compare/{base_sha}...{head_sha}"), "compare is not bound to the PR base and head")
    if family == "docs-only":
        require(base_sha == spec.get("base_sha"), "docs PR base is not the frozen docs base commit")
        candidate_sha = (spec.get("publication") or {}).get("candidate_sha")
        require(urlsplit(compares[1]["url"]).path.endswith(f"/compare/{candidate_sha}...{base_sha}"), "base compare is not candidate to docs base")
        base_compare = tx_json(compares[1], "docs base compare")
        require([item.get("filename") for item in base_compare.get("files", [])] == [WORKFLOW_PATH]
                and base_compare.get("ahead_by") == 1 and base_compare.get("behind_by") == 0,
                "docs base must change only the workflow file as one commit ahead of the exact candidate")
    compare = tx_json(compares[0], "PR compare")
    files = compare.get("files") if isinstance(compare, dict) else None
    require(isinstance(files, list) and files and len(files) < 100 and all(isinstance(item, dict) and isinstance(item.get("filename"), str) for item in files),
            "compare file inventory is empty, malformed or incomplete")
    api_paths = [item["filename"] for item in files]
    require(len(set(api_paths)) == len(api_paths), "compare file inventory has duplicates")
    local = spec.get("local_diff_paths")
    require(isinstance(local, list) and local and all(isinstance(item, str) for item in local), "frozen local diff is missing")
    is_doc = lambda path: path.endswith(".md") or path.startswith(".planning/")
    if family == "docs-only":
        require(api_paths == [DOCS_PATH] and local == [DOCS_PATH], "docs-only API and local diffs must be exactly the one documentation file")
        require(compare.get("ahead_by") == 1 and compare.get("behind_by") == 0, "docs-only head is not one commit ahead of the docs base")
    else:
        require(set(api_paths) <= set(local) and any(not is_doc(path) for path in api_paths) and any(not is_doc(path) for path in local),
                "normal PR diff must include non-documentation paths present in the frozen local diff")

    contents = _family(transactions, family, "repo_contents")
    wanted = {WORKFLOW_PATH: spec["workflow_blob"]}
    if family == "docs-only":
        require(isinstance(spec.get("docs_blob"), str) and SHA40.fullmatch(spec["docs_blob"]), "frozen documentation blob is malformed")
        wanted[DOCS_PATH] = spec["docs_blob"]
    require(len(contents) == len(wanted) and all(tx["actual_status"] == 200 for tx in contents), "exact source/blob reads are incomplete")
    workflow_bytes = None
    seen_paths = set()
    for tx in contents:
        parsed = urlsplit(tx["url"])
        path = parsed.path.split("/contents/", 1)[1] if "/contents/" in parsed.path else None
        require(path in wanted and path not in seen_paths and parsed.query == f"ref={merge_sha}", "source read is not the exact proof file at the tested merge")
        seen_paths.add(path)
        document = tx_json(tx, "source read")
        require(isinstance(document, dict) and document.get("type") == "file" and document.get("encoding") == "base64"
                and document.get("path") == path, "source read is not a base64 file response")
        data = b64(str(document.get("content", "")).replace("\n", ""), "source content")
        require(git_blob_sha(data) == document.get("sha") == wanted[path], "source blob differs from the frozen blob")
        if path == WORKFLOW_PATH:
            workflow_bytes = data
    require(workflow_bytes is not None, "workflow source at the tested merge is missing")
    if _capture is not None:
        _capture["workflow_bytes"] = workflow_bytes

    runs = _family(transactions, family, "workflow_runs")
    polls = _family(transactions, family, "run")
    require(runs and polls, "run discovery and terminal polls are required")
    require(len(polls) <= TERMINAL_POLL_LIMITS[family], "terminal polls exceed the family allocation")
    discovered = {run["id"] for tx in runs if tx["actual_status"] == 200 for run in (tx_json(tx, "run discovery").get("workflow_runs") or [])
                  if run.get("head_sha") == head_sha and run.get("event") == "pull_request"}
    require(len(discovered) == 1, "exactly one discovered pull_request run for the PR head is required")
    run = tx_json(polls[-1], "terminal run")
    require(polls[-1]["actual_status"] == 200 and run.get("id") in discovered, "terminal run is not the discovered run")
    run_id, attempt = run["id"], run.get("run_attempt")
    require(run.get("event") == "pull_request" and run.get("head_sha") == head_sha and run.get("head_branch") == head_ref
            and run.get("workflow_id") == WORKFLOW_ID and str(run.get("path", "")).split("@", 1)[0] == WORKFLOW_PATH
            and type(attempt) is int and attempt >= 1, "run is not the actual PR workflow run for the published head")
    require((run.get("repository") or {}).get("full_name") == REPOSITORY and (run.get("head_repository") or {}).get("full_name") == REPOSITORY,
            "run repository identity differs")
    require(any(isinstance(item, dict) and item.get("number") == number for item in run.get("pull_requests") or []),
            "run is not linked to the proof PR")
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "actual terminal run conclusion is not success")
    for tx in polls[:-1]:
        require(tx_json(tx, "earlier poll").get("status") != "completed", "polling continued after a terminal run response")
    require(reads[-1]["sequence"] > polls[-1]["sequence"], "the PR must be re-read after the terminal run")

    job_pages = _family(transactions, family, "attempt_jobs")
    require(job_pages, "attempt job pages are required")
    jobs, total = [], None
    for tx in sorted(job_pages, key=lambda item: item["page_ordinal"]):
        require(tx["actual_status"] == 200 and tx["url"].find(f"/runs/{run_id}/attempts/{attempt}/jobs") >= 0, "job page is not for the terminal run attempt")
        document = tx_json(tx, "jobs")
        require(isinstance(document, dict) and isinstance(document.get("jobs"), list), "jobs page is malformed")
        jobs.extend(document["jobs"])
        total = document.get("total_count")
    require(total == len(jobs) and jobs, "job inventory is empty or incomplete")
    by_name = {}
    for job in jobs:
        require(isinstance(job, dict) and isinstance(job.get("name"), str) and job.get("run_id") == run_id and job.get("run_attempt") == attempt
                and job.get("status") == "completed" and job.get("conclusion") in {"success", "failure", "cancelled", "timed_out", "skipped", "neutral", "action_required"},
                "job is not a terminal job of the proof run attempt")
        by_name.setdefault(job["name"], []).append(job)
    for name in (*REQUIRED_NAMES, CLASSIFIER_JOB, *[f"Example Playwright shard ({seam})" for seam in SEAMS]):
        found = by_name.get(name, [])
        require(len(found) == 1 and found[0]["conclusion"] == "success", f"required job missing, duplicated or not successful: {name}")
    classifier_steps = by_name[CLASSIFIER_JOB][0].get("steps")
    require(isinstance(classifier_steps, list) and sum(1 for step in classifier_steps if step.get("name") == CLASSIFIER_JOB
            and step.get("conclusion") == "success") == 1, "classifier step did not succeed exactly once")
    if family == "normal":
        shards = [job for name, found in by_name.items() if name.startswith("Library tests shard") for job in found]
        require(shards and all(job["conclusion"] == "success" for job in shards), "ordinary library test owner did not run and pass")

    check_txs = _family(transactions, family, "check_runs")
    require(len(check_txs) == 1 and check_txs[0]["actual_status"] == 200 and check_txs[0]["page_ordinal"] == 1, "exactly one complete native check page is required")
    view = _view_for_checks(evidence, family, allocation, head_sha, check_txs[0])
    hydrate_effective_checks(view)
    verify_effective_checks(view)
    native = {item["name"]: item for item in tx_json(check_txs[0], "native checks")["check_runs"] if item.get("name") in REQUIRED_NAMES}
    for name in REQUIRED_NAMES:
        check, job = native[name], by_name[name][0]
        require(check.get("head_sha") == head_sha and check.get("status") == "completed" and check.get("conclusion") == "success"
                and job["conclusion"] == "success", f"native check is not a successful check of the PR head: {name}")
        match = re.search(r"/job/([0-9]+)$", check.get("html_url", ""))
        require(match is not None and match.group(1) == str(job.get("id")), f"native check does not belong to the attempt job: {name}")

    artifact_pages = _family(transactions, family, "run_artifacts")
    require(artifact_pages, "artifact metadata pages are required")
    artifacts, total = [], None
    for tx in sorted(artifact_pages, key=lambda item: item["page_ordinal"]):
        require(tx["actual_status"] == 200, "artifact metadata page failed")
        document = tx_json(tx, "artifacts")
        require(isinstance(document, dict) and isinstance(document.get("artifacts"), list), "artifact metadata is malformed")
        artifacts.extend(document["artifacts"])
        total = document.get("total_count")
    require(total == len(artifacts), "artifact metadata is incomplete")
    expected_names = [f"browser-execution-{seam}-{run_id}-{attempt}" for seam in SEAMS]
    producers = [item for item in artifacts if isinstance(item, dict) and isinstance(item.get("name"), str) and item["name"].startswith("browser-execution-")]
    require(sorted(item["name"] for item in producers) == sorted(expected_names),
            "exactly five producer artifacts with the exact run and attempt names are required (empty, single, duplicate or unknown inventories fail)")
    digests = {}
    for item in producers:
        require(item.get("expired") is False and type(item.get("id")) is int and (item.get("workflow_run") or {}).get("id") == run_id
                and (item.get("workflow_run") or {}).get("head_sha") == head_sha and type(item.get("size_in_bytes")) is int
                and 0 < item["size_in_bytes"] <= MAX_PRODUCER_ZIP_BYTES and isinstance(item.get("digest"), str)
                and re.fullmatch(r"sha256:[a-f0-9]{64}", item["digest"]), f"producer artifact identity is incomplete: {item.get('name')}")
        digests[item["name"]] = item

    downloads = evidence.get("downloads")
    require(isinstance(downloads, list) and len(downloads) == 5, "all five producer artifact downloads are required")
    by_download = {}
    for entry in downloads:
        require(isinstance(entry, dict) and entry.get("name") in digests and entry["name"] not in by_download, "download is unknown or duplicated")
        by_download[entry["name"]] = entry
    producer_dirs, record_cache = {}, {}
    for seam in SEAMS:
        name = f"browser-execution-{seam}-{run_id}-{attempt}"
        entry, artifact = by_download[name], digests[name]
        require(entry.get("artifact_id") == artifact["id"], "download artifact ID differs from API metadata")
        archive = b64(entry.get("zip_base64"), "producer ZIP")
        group = [tx for tx in transactions if tx.get("request_group") == entry.get("request_group") and entry.get("request_group")]
        require(group and all(tx["family"] == family and tx["route_id"] == "artifact_zip" and tx["category"] == "artifact_downloads" for tx in group),
                "download hops are missing from the measured ledger")
        group.sort(key=lambda tx: tx["hop_ordinal"])
        require(urlsplit(group[0]["url"]).path.endswith(f"/actions/artifacts/{artifact['id']}/zip"), "download is not the artifact ZIP route")
        require(all(tx["actual_status"] in (301, 302, 303, 307, 308) for tx in group[:-1]) and group[-1]["actual_status"] == 200,
                "download did not end in one actual successful ZIP response")
        final = group[-1]
        require(final.get("raw_observation_sha256") == sha256(archive) == artifact["digest"].removeprefix("sha256:")
                and final.get("response_bytes") == len(archive), "ZIP bytes differ from the measured response and GitHub artifact digest")
        members = validate_producer_zip(archive)
        try:
            record = json.loads(members["execution-record.json"].decode("utf-8", "strict"))
        except (KeyError, UnicodeError, json.JSONDecodeError) as error:
            raise VerificationError(f"producer artifact lacks a valid execution record: {name}") from error
        expected_members = {"execution-record.json"}
        for step in record.get("selected_steps", []) if isinstance(record, dict) else []:
            for reference in step.get("reports", []) if isinstance(step, dict) else []:
                expected_members.update((reference.get("path"), reference.get("selection_path")))
        require(set(members) == expected_members, f"producer artifact members differ from its record inventory: {name}")
        producer_dirs[name] = members
        record_cache[seam] = record

    docs_only = family == "docs-only"
    identity = {"run_id": str(run_id), "run_attempt": str(attempt), "source_sha": merge_sha, "event": "pull_request",
                "workflow_ref": f"{REPOSITORY}/{WORKFLOW_PATH}@refs/pull/{number}/merge", "workflow_sha": merge_sha,
                "classifier_result": "success", "docs_only": "true" if docs_only else "false"}
    policy = _run_browser_policy(workflow_bytes, producer_dirs, identity)
    require(policy.get("status") == "passed" and isinstance(policy.get("seams"), list) and len(policy["seams"]) == 5
            and all(item.get("docs_only") is docs_only for item in policy["seams"]), "browser execution policy owner did not accept all five seams")
    return {"status": "synthetic_pr_family_verified" if evidence["synthetic"] else "pr_family_verified", "family": family,
            "accepted_live": not evidence["synthetic"], "pr_number": number, "run_id": run_id, "run_attempt": attempt,
            "head_sha": head_sha, "merge_sha": merge_sha, "requests": len(transactions), "category_counts": counts,
            "window_id": allocation["window_id"]}


DOCS_OLD_TRIGGER = b"  pull_request:\n    branches: [main]\n"
DOCS_NEW_TRIGGER = b"  pull_request:\n    branches: [main, gsd/253-replan-docs-*]\n"


def verify_docs_workflow_relation(candidate, docs):
    """The docs base may differ from the candidate only by the exact named pull_request branch allowance."""
    require(isinstance(candidate, bytes) and isinstance(docs, bytes) and candidate.count(DOCS_OLD_TRIGGER) == 1
            and docs.count(DOCS_NEW_TRIGGER) == 1 and docs == candidate.replace(DOCS_OLD_TRIGGER, DOCS_NEW_TRIGGER, 1),
            "docs base workflow differs from the candidate by more than the exact pull_request branch allowance")


@fail_closed
def verify_pr_pair(normal, docs):
    """Verify both actual PR families and prove they share one non-reset production allocation."""
    captured_normal, captured_docs = {}, {}
    first = verify_pr_family(normal, "normal", captured_normal)
    second = verify_pr_family(docs, "docs-only", captured_docs)
    verify_docs_workflow_relation(captured_normal["workflow_bytes"], captured_docs["workflow_bytes"])
    ledgers = [normal["transport_ledger"], docs["transport_ledger"]]
    require(normal["allocation_base64"] == docs["allocation_base64"], "families used different allocations (budget reset)")
    require(all(ledger["allocation_sha256"] == ledgers[0]["allocation_sha256"] and ledger["window_id"] == ledgers[0]["window_id"] for ledger in ledgers),
            "families used different windows (budget reset)")
    shorter, longer = sorted((ledgers[0]["transactions"], ledgers[1]["transactions"]), key=len)
    require(longer[:len(shorter)] == shorter, "family ledgers are not one append-only measured window")
    require(len(longer) <= 120, "combined families exceed the single 120-request allocation")
    require(normal["freeze"]["freeze_sha256"] == docs["freeze"]["freeze_sha256"], "families used different frozen PR proofs")
    require(first["pr_number"] != second["pr_number"] and first["run_id"] != second["run_id"], "families did not use two distinct actual PRs and runs")
    require(first["accepted_live"] == second["accepted_live"], "families mix synthetic and live origins")
    return {"status": "synthetic_pr_pair_verified" if not first["accepted_live"] else "pr_pair_verified",
            "accepted_live": first["accepted_live"], "normal": first, "docs-only": second, "requests": len(longer)}


def read_json_file(path, limit=MAX_PR_EVIDENCE_BYTES):
    try:
        raw = Path(path).read_bytes()
        require(len(raw) <= limit, "evidence exceeds its fixed size limit")
        value = json.loads(raw.decode("utf-8", "strict"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError(f"evidence unreadable or malformed: {error}") from error
    require(isinstance(value, dict), "evidence root must be an object")
    return value


def verify_canary_matrix(evidence):
    """Whole hosted canary: measured transport, exact checks, six sources, attempts and separate verifier."""
    transport_result = verify_transport_v2(evidence)
    if "effective_checks" not in evidence:
        hydrate_effective_checks(evidence)
    checks_result = verify_effective_checks(evidence)
    results, source_jobs = verify_sources(evidence)
    executed = verify_attempt_jobs(evidence)
    require(executed >= source_jobs, "complete attempt receipts omit a selected source job")
    return {"status": "canary_verified", "transport": transport_result, "checks": checks_result,
            "scenarios": results, "separate_verifier": verify_separate_verifier(evidence, source_jobs), "executed_jobs": executed}


LITERAL_LIMITATIONS = (
    "historical failed native and hosted outcomes remain failures and are never rewritten as successful execution",
    "the chronology of the historical failures is lost and is not reconstructed",
    "the preceding execution order of the original failures is missing",
    "the actual HTTP request count of old hosted run 38347679431 is unknown; it is not asserted to be 120",
)
LINKS = (
    ("phase252_replay", "original Phase252 replay"), ("phase252_diagnosis", "original Phase252 diagnosis"),
    ("load_controls", "native load controls"), ("load_acceptance", "accepted target and fresh repeats"),
    ("publication", "measured publication"), ("canary", "hosted canary, six outcomes and separate verifier"),
    ("pr_normal", "actual normal PR"), ("pr_docs_only", "actual docs-only PR"),
)
LOAD_CHECKS = {
    "load_controls": ["--verify-load-recovery", "{path}", "--stage", "complete"],
    "load_acceptance": ["--verify-load-acceptance", "{path}", "--require-target-accepted"],
}

# With the production checker, completion may re-open only the R5 native controls and the acceptance evidence; the halted
# v1, R2, R3 and R4 native evidence (and the halted 253-40 record) can never satisfy these links. argv above is unchanged.
LOAD_PATHS = {
    "load_controls": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-EVIDENCE-R5.json",
    "load_acceptance": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json",
}
LOAD_PATH_ERRORS = {
    "load_controls": "load_controls must link the R5 native evidence",
    "load_acceptance": "load_acceptance must link the accepted load acceptance evidence",
}

# 253-90 (D-24): a human-approved not_reproduced disposition is verifiable as "dispositioned", never as "accepted". The two
# optional links are not in LINKS, so they can never make a record accepted; both or neither must be present.
DISPOSITION_LINKS = ("load_target_disposition", "load_target_disposition_approval")
DISPOSITION_PATHS = {
    "load_target_disposition": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TARGET-DISPOSITION.json",
    "load_target_disposition_approval": ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TARGET-DISPOSITION-APPROVAL.json",
}
DISPOSITION_PATH_ERRORS = {
    "load_target_disposition": "load_target_disposition must link the reviewed target disposition record",
    "load_target_disposition_approval": "load_target_disposition_approval must link the reviewed target disposition approval record",
}
# The runner re-opens the committed disposition and approval itself; the acceptance evidence path is the checked argument.
DISPOSITION_CHECK = ["--verify-load-acceptance", "{path}", "--require-target-disposition"]
DISPOSITION_GAP = "disposition:CIREL-01:not_reproduced (Jon-approved disposition; target neither reproduced nor fixed)"
DISPOSITION_LIMITATION = ("the selected registration flake was not reproduced; CIREL-01 is partial under a human-approved "
                          "not_reproduced disposition")
STRICT_REJECTION_EXIT = 3


def _default_checker(kind, path):
    script = Path(__file__).with_name("ci-registration-recovery.mjs")
    node = shutil.which("node")
    if node is None:
        return 127, "node unavailable"
    template = DISPOSITION_CHECK if kind == "load_target_disposition" else LOAD_CHECKS[kind]
    argv = [node, str(script), *[part.format(path=path) for part in template]]
    result = subprocess.run(argv, capture_output=True, text=True, timeout=300, check=False)
    return result.returncode, (result.stderr or result.stdout)[:400]


@fail_closed
def verify_completion(evidence, require_accepted=False, root=REPO_ROOT, load_checker=None, require_dispositioned=False):
    """Re-open every linked proof; embedded acceptance claims are never trusted."""
    require(isinstance(evidence, dict) and evidence.get("schema_version") == COMPLETION_SCHEMA
            and evidence.get("repository") == REPOSITORY, "completion evidence schema or repository mismatch")
    links = evidence.get("links")
    require(isinstance(links, dict) and set(links) <= {key for key, _ in LINKS} | set(DISPOSITION_LINKS),
            "completion links are malformed or unknown")
    require(not require_accepted or not require_dispositioned, "--require-accepted and --require-dispositioned are mutually exclusive")
    require(sum(key in links for key in DISPOSITION_LINKS) in (0, len(DISPOSITION_LINKS)),
            "the target disposition and its approval must be linked together")
    checker = load_checker or _default_checker
    gaps, opened, windows, synthetic = [], {}, {}, False
    disposition_opened = {}
    for key in DISPOSITION_LINKS:
        link = links.get(key)
        if link is None:
            continue
        require(isinstance(link, dict) and set(link) == {"path", "sha256"} and isinstance(link["path"], str)
                and isinstance(link["sha256"], str) and SHA64.fullmatch(link["sha256"]), f"link {key} is malformed")
        target = Path(link["path"])
        target = target if target.is_absolute() else Path(root) / target
        if load_checker is None:
            require(target.resolve() == (Path(root) / DISPOSITION_PATHS[key]).resolve(), DISPOSITION_PATH_ERRORS[key])
        try:
            raw = target.read_bytes()
        except OSError as error:
            raise VerificationError(f"linked proof cannot be re-opened: {key}") from error
        require(sha256(raw) == link["sha256"], f"linked proof bytes differ from their recorded SHA-256: {key}")
        disposition_opened[key] = (target, raw)
    dispositioned = False
    for key, label in LINKS:
        link = links.get(key)
        if link is None:
            gaps.append(f"missing:{key}:{label}")
            continue
        require(isinstance(link, dict) and set(link) == {"path", "sha256"} and isinstance(link["path"], str)
                and isinstance(link["sha256"], str) and SHA64.fullmatch(link["sha256"]), f"link {key} is malformed")
        target = Path(link["path"])
        target = target if target.is_absolute() else Path(root) / target
        if load_checker is None and key in LOAD_PATHS:
            require(target.resolve() == (Path(root) / LOAD_PATHS[key]).resolve(), LOAD_PATH_ERRORS[key])
        try:
            raw = target.read_bytes()
        except OSError as error:
            raise VerificationError(f"linked proof cannot be re-opened: {key}") from error
        require(sha256(raw) == link["sha256"], f"linked proof bytes differ from their recorded SHA-256: {key}")
        opened[key] = (target, raw)
    for key in ("phase252_replay", "phase252_diagnosis"):
        if key in opened:
            parsed = json.loads(opened[key][1].decode("utf-8", "strict"))
            require(isinstance(parsed, (dict, list)) and bool(parsed), f"original Phase252 record is empty or null: {key}")
    for key in ("load_controls", "load_acceptance"):
        if key not in opened:
            continue
        code, detail = checker(key, str(opened[key][0]))
        route_disposition = False
        if code != 0:
            if not (key == "load_acceptance" and code == STRICT_REJECTION_EXIT and disposition_opened):
                raise VerificationError(f"strict native checker rejected {key}: {detail}")
            disposition_code, disposition_detail = checker("load_target_disposition", str(opened[key][0]))
            if disposition_code != 0:
                raise VerificationError(f"target disposition rejected for {key}: {disposition_detail}")
            route_disposition = True
        document = json.loads(opened[key][1].decode("utf-8", "strict"))
        require(isinstance(document, dict) and document, f"{key} evidence is empty")
        if route_disposition:
            historical = document.get("historical_cause") if isinstance(document.get("historical_cause"), dict) else {}
            require(document.get("target_status") == "open" and historical.get("status") == "diagnosis_incomplete",
                    "a target disposition applies only to an open, diagnosis_incomplete acceptance record")
            dispositioned = True
            gaps.append(DISPOSITION_GAP)
        elif key == "load_acceptance":
            assessment = document.get("assessment") if isinstance(document.get("assessment"), dict) else {}
            if assessment.get("kind") == "justified_no_flake":
                selected, explained = assessment.get("selected_failures"), assessment.get("explained_failures")
                require(isinstance(selected, list) and selected and isinstance(explained, list) and set(selected) <= set(explained)
                        and assessment.get("cause") in (None, ""), "cause-less no-flake must explain every selected failure")
            else:
                require(isinstance(assessment.get("cause"), str) and assessment["cause"], "accepted target needs a demonstrated cause or a justified no-flake assessment")
    if "publication" in opened:
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("ci-git-publication.py")), "--verify-publication", str(opened["publication"][0])],
                                capture_output=True, text=True, timeout=60, check=False)
        require(result.returncode == 0, f"publication receipt rejected: {result.stderr.strip()[:300]}")
    if "canary" in opened:
        canary = json.loads(opened["canary"][1].decode("utf-8", "strict"))
        verify_canary_matrix(canary)
        origin = canary.get("origin", {})
        windows["canary"] = (origin.get("window_id"), canary["transport_ledger"].get("allocation_sha256"))
    pr_result = None
    if "pr_normal" in opened and "pr_docs_only" in opened:
        normal = json.loads(opened["pr_normal"][1].decode("utf-8", "strict"))
        docs = json.loads(opened["pr_docs_only"][1].decode("utf-8", "strict"))
        pr_result = verify_pr_pair(normal, docs)
        for item in (normal.get("freeze") or {}).get("bound_documents") or []:
            bound = Path(item["path"])
            bound = bound if bound.is_absolute() else Path(root) / bound
            try:
                actual = sha256(bound.read_bytes())
            except OSError as error:
                raise VerificationError(f"frozen source link cannot be re-opened: {item['path']}") from error
            require(actual == item["sha256"], f"frozen source link changed since the freeze: {item['path']}")
        windows["pr"] = (normal["transport_ledger"]["window_id"], normal["transport_ledger"]["allocation_sha256"])
        synthetic = synthetic or not pr_result["accepted_live"]
        if not pr_result["accepted_live"]:
            gaps.append("synthetic:pr:synthetic local-HTTPS PR evidence cannot satisfy live acceptance")
    elif "pr_normal" in opened or "pr_docs_only" in opened:
        gaps.append("missing:pr_pair:both actual PR families are required together")
    seen = {}
    for name, (window, allocation_hash) in windows.items():
        require(seen.setdefault(window, allocation_hash) == allocation_hash, "a window was reused with a different allocation (budget reset)")
    require(len({window for window, _ in windows.values()}) == len(windows), "proofs reused one window instead of separate allocations (budget reset)")
    claimed = evidence.get("accepted") is True or evidence.get("status") in ("accepted", "complete", "passed")
    if claimed and gaps:
        raise VerificationError("embedded acceptance claim contradicts the re-opened links: " + "; ".join(gaps))
    complete = not synthetic and len(opened) == len(LINKS)
    status = "accepted" if not gaps and complete else "open"
    live = complete and not [gap for gap in gaps if gap != DISPOSITION_GAP]
    if require_accepted and status != "accepted":
        raise VerificationError("accepted-only completion failed: " + "; ".join(gaps or ["not every linked proof is live and accepted"]))
    if require_dispositioned:
        if dispositioned and live:
            status = "dispositioned"
        elif status != "accepted":
            raise VerificationError("dispositioned completion failed: " + "; ".join(gaps or ["not every linked proof is live and accepted"]))
    cirel_01 = "accepted" if status == "accepted" else ("partial_not_reproduced" if dispositioned else "open")
    result = {"status": status, "gaps": gaps, "linked": sorted(opened), "phase_verification": "not_started",
              "limitations": list(LITERAL_LIMITATIONS),
              "requirements": {"CIREL-01": cirel_01, "CIREL-02": "accepted" if status == "accepted" or live else "open"}}
    if dispositioned:
        result["dispositioned"] = True
        result["limitations"].append(DISPOSITION_LIMITATION)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, help="captured GitHub API and artifact receipt JSON")
    parser.add_argument("--mode", choices=("legacy", "transport", "preflight", "canary", "pr", "completion"), default="legacy")
    parser.add_argument("--family", choices=("normal", "docs-only", "both"), default="normal")
    parser.add_argument("--docs-evidence", help="docs-only PR evidence when --mode pr --family both")
    strictness = parser.add_mutually_exclusive_group()
    strictness.add_argument("--require-accepted", action="store_true")
    strictness.add_argument("--require-dispositioned", action="store_true")
    parser.add_argument("--scenario", choices=(*SCENARIOS, "sources", "matrix"), default="full-pass")
    args = parser.parse_args()
    if args.mode == "legacy":
        evidence = read_evidence(args.evidence)
        if args.scenario in ("sources", "matrix"):
            results, count = verify_sources(evidence)
            if args.scenario == "sources":
                return {"status": "sources_verified", "scenarios": results, "executed_jobs": count}
            return {"status": "verified", "scenarios": results, "separate_verifier": verify_separate_verifier(evidence, count)}
        receipt = evidence.get("scenarios", {}).get(args.scenario) if "scenarios" in evidence else evidence
        return verify_scenario(receipt, args.scenario, evidence)
    if args.mode == "pr":
        first = read_json_file(args.evidence)
        if args.family == "both":
            require(args.docs_evidence, "--family both requires --docs-evidence")
            return verify_pr_pair(first, read_json_file(args.docs_evidence))
        return verify_pr_family(first, args.family)
    if args.mode == "completion":
        return verify_completion(read_json_file(args.evidence), require_accepted=args.require_accepted,
                                 require_dispositioned=args.require_dispositioned)
    evidence = read_replan_evidence(args.evidence)
    transport_result = verify_transport_v2(evidence)
    if args.mode == "transport":
        return transport_result
    if "effective_checks" not in evidence:
        hydrate_effective_checks(evidence)
    checks_result = verify_effective_checks(evidence)
    if args.mode == "preflight":
        return {"status": "preflight_verified", "transport": transport_result, "checks": checks_result}
    if args.scenario in ("sources", "matrix"):
        results, source_jobs = verify_sources(evidence)
        if args.scenario == "sources":
            return {"status": "sources_verified", "transport": transport_result,
                    "checks": checks_result, "scenarios": results, "executed_jobs": source_jobs}
        executed = verify_attempt_jobs(evidence)
        require(executed >= source_jobs, "complete attempt receipts omit a selected source job")
        return {"status": "canary_verified", "transport": transport_result, "checks": checks_result,
                "scenarios": results, "separate_verifier": verify_separate_verifier(evidence, source_jobs),
                "executed_jobs": executed}
    receipt = evidence.get("scenarios", {}).get(args.scenario) if "scenarios" in evidence else evidence
    return {"status": "canary_scenario_verified", "scenario": verify_scenario(receipt, args.scenario, evidence),
            "transport": transport_result, "checks": checks_result}


def read_replan_evidence(path):
    try:
        raw = Path(path).read_bytes()
        require(len(raw) <= 16 * 1024 * 1024, "v2 evidence exceeds the fixed 16 MiB limit")
        value = json.loads(raw.decode("utf-8", "strict"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError(f"v2 evidence unreadable or malformed: {error}") from error
    require(isinstance(value, dict) and value.get("schema_version") == REPLAN_SCHEMA,
            "new acceptance requires sigra.phase253.hosted-replan-evidence/v2; v1 remains disclosure-only")
    require(value.get("repository") == "szTheory/sigra", "wrong repository in v2 evidence")
    return value


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2, sort_keys=True))
    except (VerificationError, KeyError, TypeError) as error:
        print(f"hosted-gate-verify: FAIL: {error}", file=sys.stderr)
        sys.exit(1)
