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
import zipfile
from pathlib import Path

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


def serialize_dispatch_inputs(inputs):
    """Serialize only typed workflow_dispatch fields with explicit byte limits."""
    try:
        transport_path = Path(__file__).with_name("ci-hosted-transport.py")
        spec = importlib.util.spec_from_file_location("ci_hosted_transport", transport_path)
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        encoded = transport.serialize_dispatch_inputs(inputs)
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
        for field in ("method", "url", "route_id", "page_ordinal", "hop_ordinal", "actual_status", "scrubbed_headers",
                      "response_sha256", "source_sha256", "window_id"):
            require(receipt.get(field) == transaction.get(field)
                    and (observed is None or observed.get(field) == transaction.get(field)),
                    f"transport {field} differs across ledger, receipt and journal")
        require(transaction.get("window_id") == origin["window_id"] and transaction.get("source_sha256") == origin["source_sha256"],
                "transaction escaped the measured source window")
        require(transaction.get("state") == "complete" and type(transaction.get("actual_status")) is int
                and 100 <= transaction["actual_status"] <= 599, "transaction lacks its actual completed HTTP status")
        require(transaction["actual_status"] not in (401, 403, 429), "authentication or rate limit requires a terminal stop")
        body_b64 = transaction.get("response_body_base64")
        require(isinstance(body_b64, str), "measured response body bytes are missing")
        try:
            body = base64.b64decode(body_b64, validate=True)
        except (ValueError, base64.binascii.Error) as error:
            raise VerificationError("measured response body encoding is invalid") from error
        require(sha256(body) == transaction.get("response_sha256"), "measured response digest differs from retained bytes")
        require(type(transaction.get("response_bytes")) is int and transaction["response_bytes"] == len(body),
                "measured response byte count differs from retained bytes")
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
            require(transaction.get("input_key_count") == len(inputs)
                    and transaction.get("input_unicode_scalars") == len(canonical.decode("utf-8"))
                    and transaction.get("input_utf8_bytes") == len(canonical)
                    and transaction.get("input_sha256") == sha256(canonical),
                    "dispatch metrics do not match exact transmitted inputs bytes")
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
            local_name_len, local_extra_len = struct.unpack_from("<HH", archive_bytes, 26)
            local_name = archive_bytes[30:30 + local_name_len]
            require(local_name.decode("utf-8" if info.flag_bits & 0x800 else "cp437") == info.filename,
                    "ZIP local and central member names differ")
            data_start = 30 + local_name_len + local_extra_len
            require(data_start + info.compress_size <= eocd, "ZIP member stream is truncated or overlaps its directory")
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, help="captured GitHub API and artifact receipt JSON")
    parser.add_argument("--mode", choices=("legacy", "transport", "preflight", "canary"), default="legacy")
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
