#!/usr/bin/env python3
"""Read-only GitHub shape probe for Phase 253 (253-126). Run only by Jon's operator runner (253-127).

The probe sends a committed, enumerated list of GET requests, each strictly through scripts/ci/ci-hosted-transport.py
(request_one, fetch_pages, follow_download), so every policy decision stays in the 253-125 transport: the live origin,
the run_logs-only results-receiver hop, header scrubbing, query redaction, the ledger and its budgets. This driver opens
no socket of its own and imports no HTTP client.

Modes:

* ``--check-requests REQUESTS``: validate the full request-list schema offline (no socket, no token).
* ``--check-only --requests R --allocation A --approval AP``: everything above, plus the binding: one sha256 for the
  request list, the approval's section_sha256 and the allocation's source_sha256; an approve decision; and an allocation
  whose window, caps, category table and exact ordered download_hosts equal the request list's.
* ``--run`` (the same three plus ``--ledger L --evidence E --bodies B``): ``--check-only``, then each request in order.
  Evidence and bodies are written after every request. On the first transport error the evidence says ``halted`` with
  the code and the request id and the driver exits 1; it never retries.

Exit status: 0 success; 1 a refusal or a halted window; 2 a usage error.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True  # the transport import must not leave scripts/ci/__pycache__ in the checkout

REPO_ROOT = Path(__file__).resolve().parents[2]
TRANSPORT_PATH = Path(__file__).resolve().with_name("ci-hosted-transport.py")
DRIVER_REL = "scripts/ci/ci-shape-probe.py"
TRANSPORT_REL = "scripts/ci/ci-hosted-transport.py"
REQUESTS_SCHEMA = "sigra.phase253.shape-probe-requests/v1"
APPROVAL_SCHEMA = "sigra.phase253.shape-probe-approval/v1"
ALLOCATION_SCHEMA = "sigra.phase253.http-allocation/v1"
EVIDENCE_SCHEMA = "sigra.phase253.shape-probe-evidence/v1"
BODIES_SCHEMA = "sigra.phase253.shape-probe-bodies/v1"
REPOSITORY = "szTheory/sigra"
LIST_FIELDS = ("schema_version", "repository", "window_id", "max_requests", "max_elapsed_seconds", "max_response_bytes",
               "max_pages", "max_hops", "category_limits", "download_hosts", "source_pointers", "driver_commit", "requests")
ITEM_FIELDS = ("id", "route_id", "method", "category", "params", "query", "mode")
APPROVAL_FIELDS = ("schema_version", "decision", "decided_by", "decision_text", "note", "section", "section_sha256",
                   "requests_path", "authorizes", "excludes", "recorded_at")
ALLOCATION_FIELDS = ("schema_version", "allocation_kind", "mode", "repository", "window_id", "source_sha256",
                     "max_requests", "max_elapsed_seconds", "max_response_bytes", "max_pages", "max_hops",
                     "category_limits", "bound_documents", "download_hosts")
# Fields of the allocation that must EQUAL the request list's (download_hosts as an exact ordered list).
BOUND_FIELDS = ("repository", "window_id", "max_requests", "max_elapsed_seconds", "max_response_bytes", "max_pages",
                "max_hops", "category_limits", "download_hosts")
# The only routes a probe may name: route -> (route parameters, permitted query keys, permitted modes).
PROBE_ROUTES = {
    "rate_limit": (frozenset(), frozenset(), frozenset({"one"})),
    "run": (frozenset({"run_id"}), frozenset(), frozenset({"one"})),
    "run_jobs": (frozenset({"run_id"}), frozenset({"per_page"}), frozenset({"one", "pages"})),
    "run_logs": (frozenset({"run_id"}), frozenset(), frozenset({"one", "follow"})),
    "job_logs": (frozenset({"job_id"}), frozenset(), frozenset({"one"})),
}
SCOPED_REF_MARKER = "253-replan"
MAX_LIST_BYTES = 256 * 1024
MAX_REQUESTS = 12
MAX_ELAPSED_SECONDS = 600
MAX_RESPONSE_BYTES = 4 * 1024 * 1024
FULL_BODY_LIMIT = 262144
HEAD_SAMPLE_BYTES = 2048
MEMBER_SAMPLE_READ = 65536
SCAN_LIMIT = 64 * 1024 * 1024
TOKEN_PATTERN = re.compile(rb"gh[pousr]_|github_pat_|bearer|authorization|[?&](?:sig|signature|x-amz-signature)=", re.I)
SHA = re.compile(r"[a-f0-9]{64}")
COMMIT = re.compile(r"[a-f0-9]{40}")
ITEM_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,63}")
ISO_UTC = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ")
URL = re.compile(r"https://[^/?#]+(/[^?#]*)?(\?[^#]*)?")
UUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")


class Refusal(Exception):
    def __init__(self, field: str, reason: str):
        super().__init__(reason)
        self.field = field
        self.reason = reason


class _Interrupted(Exception):
    pass


def _load_transport():
    spec = importlib.util.spec_from_file_location("ci_hosted_transport_for_shape_probe", TRANSPORT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


transport = _load_transport()


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _exact_int(value) -> bool:
    return type(value) is int


def _same(left, right) -> bool:
    """Equality that also requires equal JSON types (so true never equals 1)."""
    return json.dumps(left, sort_keys=True) == json.dumps(right, sort_keys=True)


def _git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(REPO_ROOT), *args], capture_output=True, check=False)


def _read_json(path: Path, field: str, limit: int = MAX_LIST_BYTES) -> tuple[dict, bytes]:
    try:
        raw = Path(path).read_bytes()
    except OSError as exc:
        raise Refusal(field, f"cannot read {path}: {type(exc).__name__}") from exc
    if len(raw) > limit:
        raise Refusal(field, "file exceeds its size limit")
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise Refusal(field, "file is not valid JSON") from exc
    if not isinstance(value, dict):
        raise Refusal(field, "file must hold a JSON object")
    return value, raw


def _exact_fields(value: dict, fields, prefix: str) -> None:
    for name in fields:
        if name not in value:
            raise Refusal(f"{prefix}.{name}", "required field is missing")
    for name in value:
        if name not in fields:
            raise Refusal(f"{prefix}.{name}", "unknown field")


def _resolve(recorded: str) -> str:
    path = Path(recorded)
    return os.path.realpath(path if path.is_absolute() else REPO_ROOT / path)


def _json_pointer(document, pointer: str):
    if pointer == "":
        return document
    if not pointer.startswith("/"):
        raise KeyError(pointer)
    for raw in pointer[1:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        document = document[int(key)] if isinstance(document, list) else document[key]
    return document


# ------------------------------------------------------------------------------------------------ request list
def _check_source_pointers(pointers) -> None:
    if not isinstance(pointers, list) or not pointers:
        raise Refusal("list.source_pointers", "must be a non-empty list")
    for index, item in enumerate(pointers):
        field = f"list.source_pointers[{index}]"
        if not isinstance(item, dict):
            raise Refusal(field, "must be an object")
        locators = [name for name in ("pointer", "sequence") if name in item]
        if len(locators) != 1 or set(item) != {"path", "sha256", locators[0]}:
            raise Refusal(field, "must be exactly {path, sha256} plus one of pointer or sequence")
        rel = item["path"]
        if not isinstance(rel, str) or not rel or Path(rel).is_absolute() or ".." in Path(rel).parts:
            raise Refusal(f"{field}.path", "must be a relative checkout path")
        if not isinstance(item["sha256"], str) or not SHA.fullmatch(item["sha256"]):
            raise Refusal(f"{field}.sha256", "must be a lowercase SHA-256")
        committed = _git("show", f"HEAD:{rel}")
        if committed.returncode:
            raise Refusal(f"{field}.path", "is not a committed file at HEAD")
        if _sha256(committed.stdout) != item["sha256"]:
            raise Refusal(f"{field}.sha256", "differs from the committed file")
        try:
            working = (REPO_ROOT / rel).read_bytes()
        except OSError as exc:
            raise Refusal(f"{field}.path", "is unreadable in the working tree") from exc
        if working != committed.stdout:
            raise Refusal(f"{field}.path", "the working-tree file differs from HEAD")
        try:
            document = json.loads(committed.stdout)
        except (ValueError, UnicodeDecodeError) as exc:
            raise Refusal(f"{field}.path", "is not a JSON document") from exc
        if "pointer" in item:
            if not isinstance(item["pointer"], str):
                raise Refusal(f"{field}.pointer", "must be a JSON pointer string")
            try:
                _json_pointer(document, item["pointer"])
            except (KeyError, IndexError, ValueError, TypeError) as exc:
                raise Refusal(f"{field}.pointer", "does not resolve") from exc
        else:
            sequence = item["sequence"]
            rows = [row for row in (document.get("transactions") if isinstance(document, dict) else None) or []
                    if isinstance(row, dict) and row.get("sequence") == sequence]
            if not _exact_int(sequence) or len(rows) != 1:
                raise Refusal(f"{field}.sequence", "names no single ledger transaction")


def _check_driver_commit(commit) -> None:
    field = "list.driver_commit"
    if not isinstance(commit, str) or not COMMIT.fullmatch(commit):
        raise Refusal(field, "must be a full lowercase commit id")
    if _git("cat-file", "-e", f"{commit}^{{commit}}").returncode:
        raise Refusal(field, "is not a commit in this repository")
    if _git("merge-base", "--is-ancestor", commit, "HEAD").returncode:
        raise Refusal(field, "is not an ancestor of HEAD")
    for rel in (DRIVER_REL, TRANSPORT_REL):
        if _git("cat-file", "-e", f"{commit}:{rel}").returncode or _git("cat-file", "-e", f"HEAD:{rel}").returncode:
            raise Refusal(field, f"{rel} is not committed at driver_commit and HEAD")
    if _git("diff", "--quiet", commit, "HEAD", "--", DRIVER_REL, TRANSPORT_REL).returncode:
        raise Refusal(field, "the driver or the transport changed between driver_commit and HEAD")
    if _git("diff", "--quiet", "HEAD", "--", DRIVER_REL, TRANSPORT_REL).returncode:
        raise Refusal(field, "the working-tree driver or transport differs from HEAD")


def _check_request_item(index: int, item, doc: dict) -> tuple[dict, int]:
    """Validate one request; return its transport envelope and its worst-case request cost."""
    field = f"list.requests[{index}]"
    if not isinstance(item, dict):
        raise Refusal(field, "must be an object")
    if SCOPED_REF_MARKER in json.dumps(item):
        raise Refusal(field, "names a gsd/253-replan ref; no probe request may read or touch a scoped ref")
    _exact_fields(item, ITEM_FIELDS, field)
    if not isinstance(item["id"], str) or not ITEM_ID.fullmatch(item["id"]):
        raise Refusal(f"{field}.id", "must be a short lowercase id")
    route_id = item["route_id"]
    if route_id not in PROBE_ROUTES:
        raise Refusal(f"{field}.route_id", "is not one of the read-only probe routes "
                                           "(rate_limit, run, run_jobs, run_logs, job_logs)")
    if item["method"] != "GET" or transport.ROUTES[route_id][0] != "GET":
        raise Refusal(f"{field}.method", "must be GET")
    param_names, query_names, modes = PROBE_ROUTES[route_id]
    if item["mode"] not in modes:
        raise Refusal(f"{field}.mode", f"mode {item['mode']!r} is not permitted for {route_id}; only run_logs may follow")
    if not isinstance(item["category"], str) or item["category"] not in doc["category_limits"]:
        raise Refusal(f"{field}.category", "is not in category_limits")
    if not isinstance(item["params"], dict) or set(item["params"]) != param_names:
        raise Refusal(f"{field}.params", f"must name exactly {sorted(param_names)}")
    if not isinstance(item["query"], dict) or set(item["query"]) - query_names:
        raise Refusal(f"{field}.query", f"may name only {sorted(query_names)}")
    envelope = {"route_id": route_id, "method": "GET", "category": item["category"], "params": item["params"],
                "query": item["query"]}
    try:
        _, _, _, path = transport._route(envelope, {"mode": "live", "repository": REPOSITORY,
                                                    "max_pages": doc["max_pages"]})
    except transport.TransportError as exc:
        raise Refusal(field, f"the transport refuses it: {exc.code}: {exc}") from exc
    if SCOPED_REF_MARKER in path:
        raise Refusal(field, "its path names a gsd/253-replan ref")
    cost = {"one": 1, "pages": doc["max_pages"], "follow": 1 + doc["max_hops"]}[item["mode"]]
    return envelope, cost


def check_requests(path) -> tuple[dict, bytes, list[dict]]:
    """Validate the whole request list; return it, its bytes and the transport envelopes."""
    doc, raw = _read_json(path, "list")
    _exact_fields(doc, LIST_FIELDS, "list")
    if doc["schema_version"] != REQUESTS_SCHEMA:
        raise Refusal("list.schema_version", f"must be {REQUESTS_SCHEMA}")
    if doc["repository"] != REPOSITORY:
        raise Refusal("list.repository", f"must be {REPOSITORY}")
    window = doc["window_id"]
    if not isinstance(window, str) or not window or len(window) > 128 or SCOPED_REF_MARKER in window:
        raise Refusal("list.window_id", "must be a short non-empty string")
    for name, low, high in (("max_requests", 1, MAX_REQUESTS), ("max_elapsed_seconds", 1, MAX_ELAPSED_SECONDS),
                            ("max_response_bytes", 1, MAX_RESPONSE_BYTES)):
        if not _exact_int(doc[name]) or not low <= doc[name] <= high:
            raise Refusal(f"list.{name}", f"must be an integer from {low} through {high}")
    if not _exact_int(doc["max_pages"]) or doc["max_pages"] not in (1, 2):
        raise Refusal("list.max_pages", "must be 1 or 2")
    if not _exact_int(doc["max_hops"]) or doc["max_hops"] != 2:
        raise Refusal("list.max_hops", "must be 2")
    limits = doc["category_limits"]
    if (not isinstance(limits, dict) or not limits
            or any(not isinstance(key, str) or not key or not _exact_int(value) or value < 1 for key, value in limits.items())
            or sum(limits.values()) != doc["max_requests"]):
        raise Refusal("list.category_limits", "must be positive integers that sum to max_requests")
    hosts = doc["download_hosts"]
    if not isinstance(hosts, list) or not hosts or len(set(map(str, hosts))) != len(hosts):
        raise Refusal("list.download_hosts", "must be a non-empty list of unique hosts")
    for index, host in enumerate(hosts):
        if not isinstance(host, str) or not (transport._pre_r11_download_host(host) or host == transport.RESULTS_RECEIVER_HOST):
            raise Refusal(f"list.download_hosts[{index}]", "is outside the 253-125 transport host predicate")
    _check_source_pointers(doc["source_pointers"])
    _check_driver_commit(doc["driver_commit"])
    items = doc["requests"]
    if not isinstance(items, list) or not items or len(items) > doc["max_requests"]:
        raise Refusal("list.requests", "must be a non-empty list no longer than max_requests")
    envelopes, spend, ids = [], {}, set()
    for index, item in enumerate(items):
        envelope, cost = _check_request_item(index, item, doc)
        if item["id"] in ids:
            raise Refusal(f"list.requests[{index}].id", "repeats an earlier id")
        ids.add(item["id"])
        spend[item["category"]] = spend.get(item["category"], 0) + cost
        envelopes.append(envelope)
    for category, cost in spend.items():
        if cost > limits[category]:
            raise Refusal("list.category_limits", f"category {category} worst case {cost} exceeds its limit {limits[category]}")
    if sum(spend.values()) > doc["max_requests"]:
        raise Refusal("list.max_requests", "the worst-case request count exceeds max_requests")
    return doc, raw, envelopes


# ------------------------------------------------------------------------------------------------ binding
def _check_approval(path, requests_path, digest: str) -> bytes:
    approval, raw = _read_json(path, "approval")
    _exact_fields(approval, APPROVAL_FIELDS, "approval")
    if approval["schema_version"] != APPROVAL_SCHEMA:
        raise Refusal("approval.schema_version", f"must be {APPROVAL_SCHEMA}")
    if approval["section"] != "shape_probe":
        raise Refusal("approval.section", "must be shape_probe")
    if approval["decision"] != "approve":
        raise Refusal("approval.decision", "is not approve")
    if approval["section_sha256"] != digest:
        raise Refusal("approval.section_sha256", "differs from the request list's sha256 (edited after approval?)")
    if not isinstance(approval["requests_path"], str) or _resolve(approval["requests_path"]) != os.path.realpath(requests_path):
        raise Refusal("approval.requests_path", "does not name the request list given on the command line")
    for name in ("decided_by", "decision_text", "note"):
        if not isinstance(approval[name], str):
            raise Refusal(f"approval.{name}", "must be a string")
    for name in ("authorizes", "excludes"):
        if not isinstance(approval[name], list) or not all(isinstance(item, str) for item in approval[name]):
            raise Refusal(f"approval.{name}", "must be a list of strings")
    if not isinstance(approval["recorded_at"], str) or not ISO_UTC.fullmatch(approval["recorded_at"]):
        raise Refusal("approval.recorded_at", "must be a UTC second-resolution time")
    return raw


def _check_allocation(path, doc: dict, digest: str, requests_path, approval_path, approval_raw: bytes) -> tuple[dict, bytes]:
    allocation, raw = _read_json(path, "allocation", transport.MAX_ALLOCATION_BYTES)
    _exact_fields(allocation, ALLOCATION_FIELDS, "allocation")
    if allocation["schema_version"] != ALLOCATION_SCHEMA:
        raise Refusal("allocation.schema_version", f"must be {ALLOCATION_SCHEMA}")
    if allocation.get("mode") != "live":
        raise Refusal("allocation.mode", "must be live; a probe never runs a test or hermetic allocation")
    if allocation["allocation_kind"] != "canary":
        raise Refusal("allocation.allocation_kind", "must be canary; a production allocation is refused")
    if allocation["source_sha256"] != digest:
        raise Refusal("allocation.source_sha256", "differs from the request list's sha256")
    for name in BOUND_FIELDS:
        if not _same(allocation[name], doc[name]):
            raise Refusal(f"allocation.{name}", "differs from the request list (download_hosts must match in order)")
    documents = allocation["bound_documents"]
    expected = [(os.path.realpath(requests_path), digest), (os.path.realpath(approval_path), _sha256(approval_raw))]
    if (not isinstance(documents, list) or len(documents) != 2
            or any(not isinstance(item, dict) or set(item) != {"path", "sha256"} or not isinstance(item["path"], str)
                   for item in documents)
            or [(_resolve(item["path"]), item["sha256"]) for item in documents] != expected):
        raise Refusal("allocation.bound_documents", "must be exactly [request list, approval] with their sha256")
    return allocation, raw


def check_only(requests_path, allocation_path, approval_path) -> dict:
    doc, raw, envelopes = check_requests(requests_path)
    digest = _sha256(raw)
    approval_raw = _check_approval(approval_path, requests_path, digest)
    allocation, allocation_raw = _check_allocation(allocation_path, doc, digest, requests_path, approval_path,
                                                   approval_raw)
    try:
        transport._validate_allocation(allocation)
        transport._check_bound_documents(allocation)
        for envelope in envelopes:
            transport._route(envelope, allocation)
            transport._request_category(envelope, allocation)
    except transport.TransportError as exc:
        raise Refusal("transport", f"{exc.code}: {exc}") from exc
    return {"doc": doc, "requests_sha256": digest, "approval_sha256": _sha256(approval_raw),
            "allocation_sha256": _sha256(allocation_raw)}


# ------------------------------------------------------------------------------------------------ observation
def _path_pattern(path: str) -> str:
    return re.sub(r"\d+", "{n}", re.sub(r"[0-9a-fA-F]{20,}", "{hex}", UUID.sub("{uuid}", path)))


def _observe(row: dict) -> dict:
    headers = row.get("scrubbed_headers") or {}
    match = URL.fullmatch(row.get("url") or "")
    path = (match.group(1) if match else None) or "/"
    location = headers.get("location")
    length = headers.get("content-length")
    return {"sequence": row.get("sequence"), "hop_ordinal": row.get("hop_ordinal") or 0,
            "page_ordinal": row.get("page_ordinal"), "host": row.get("host"), "status": row.get("actual_status"),
            "state": row.get("state"), "path_pattern": _path_pattern(path), "has_query": bool(match and match.group(2)),
            "content_type": headers.get("content-type"),
            "content_length": int(length) if isinstance(length, str) and length.isdigit() else length,
            "safe_header_names": sorted(headers),
            "location": ({"host": location.get("host"), "path_pattern": _path_pattern(str(location.get("path", ""))),
                          "has_query": location.get("has_query"), "port": location.get("port")}
                         if isinstance(location, dict) else None)}


def _scan(chunks) -> tuple[str, bool]:
    """Token-pattern scan over byte chunks (with overlap); return (clean|matched, complete)."""
    tail, total = b"", 0
    for chunk in chunks:
        total += len(chunk)
        if TOKEN_PATTERN.search(tail + chunk):
            return "matched", True
        if total > SCAN_LIMIT:
            return "matched", False
        tail = chunk[-256:]
    return "clean", True


def _member_chunks(archive: zipfile.ZipFile, info: zipfile.ZipInfo):
    with archive.open(info) as stream:
        while True:
            chunk = stream.read(65536)
            if not chunk:
                return
            yield chunk


def _head_sample(data: bytes) -> str:
    text = transport._scrub_text(data.decode("utf-8", errors="replace"), [])
    return base64.b64encode(text.encode("utf-8")[:HEAD_SAMPLE_BYTES]).decode("ascii")


def download_body_record(request_id: str, hop: int, data: bytes, content_type) -> dict:
    record = {"id": request_id, "hop_ordinal": hop, "kind": "download", "sha256": _sha256(data), "bytes": len(data),
              "magic_hex": data[:8].hex(), "content_type": content_type, "zip_members": None}
    archive = None
    if data[:4] == b"PK\x03\x04":
        try:
            archive = zipfile.ZipFile(io.BytesIO(data))
        except zipfile.BadZipFile:
            archive = None
    if archive is None:
        scan, complete = _scan([data])
        record["head_sample_base64"] = _head_sample(data)
    else:
        with archive:
            infos = archive.infolist()
            record["zip_members"] = [{"name": info.filename, "size": info.file_size,
                                      "compressed_size": info.compress_size, "crc": info.CRC} for info in infos]
            samples, scan, complete = [], "clean", True
            try:
                for info in infos:
                    with archive.open(info) as stream:
                        samples.append({"name": info.filename, "head_sample_base64": _head_sample(stream.read(MEMBER_SAMPLE_READ))})
                scans = [_scan([data])] + [_scan(_member_chunks(archive, info)) for info in infos]
                scan = "matched" if any(item[0] == "matched" for item in scans) else "clean"
                complete = all(item[1] for item in scans)
            except (zipfile.BadZipFile, OSError, RuntimeError, NotImplementedError, EOFError):
                scan, complete = "matched", False
            record["head_sample_base64"] = samples
    record["token_scan"] = scan
    record["token_scan_complete"] = complete
    record["full_base64"] = (base64.b64encode(data).decode("ascii")
                             if len(data) <= FULL_BODY_LIMIT and scan == "clean" and complete else None)
    return record


# ------------------------------------------------------------------------------------------------ run
def _ledger(path: Path) -> dict:
    if not path.exists():
        return {"transactions": []}
    return json.loads(path.read_text())


def _raise_interrupted(signum, _frame):
    raise _Interrupted(f"signal {signum}")


def run(requests_path, allocation_path, approval_path, ledger_path, evidence_path, bodies_path) -> int:
    context = check_only(requests_path, allocation_path, approval_path)
    ledger_path, evidence_path, bodies_path = Path(ledger_path), Path(evidence_path), Path(bodies_path)
    lock_path = Path(str(ledger_path) + ".lock")
    for name, path in (("ledger", ledger_path), ("evidence", evidence_path), ("bodies", bodies_path),
                       ("ledger", lock_path)):
        if path.exists():
            raise Refusal(name, f"{path} already exists; a probe window is never resumed or retried")
    doc = context["doc"]
    head = _git("rev-parse", "HEAD").stdout.decode().strip()
    evidence = {"schema_version": EVIDENCE_SCHEMA, "window_id": doc["window_id"],
                "requests_sha256": context["requests_sha256"], "approval_sha256": context["approval_sha256"],
                "allocation_sha256": context["allocation_sha256"], "driver_commit": head,
                "window_wall_start_epoch": None, "ended_epoch": None, "elapsed_seconds": None, "request_count": 0,
                "status": "halted", "stop": None, "results": [], "transport_ledger": None}
    bodies = {"schema_version": BODIES_SCHEMA, "window_id": doc["window_id"], "entries": []}

    def write(status, stop):
        ledger = _ledger(ledger_path)
        now = int(time.time())
        evidence.update(status=status, stop=stop, ended_epoch=now, request_count=len(ledger.get("transactions", [])),
                        elapsed_seconds=now - evidence["window_wall_start_epoch"], transport_ledger=ledger)
        transport._atomic_json(evidence_path, evidence)
        transport._atomic_json(bodies_path, bodies)

    work = Path(tempfile.mkdtemp(prefix="sigra-shape-probe-"))
    previous = {sig: signal.signal(sig, _raise_interrupted) for sig in (signal.SIGTERM, signal.SIGHUP)}
    try:
        evidence["window_wall_start_epoch"] = int(time.time())
        for index, item in enumerate(doc["requests"]):
            envelope = {"route_id": item["route_id"], "method": "GET", "category": item["category"],
                        "params": item["params"], "query": item["query"]}
            request_file, receipt_file, body_file = work / f"{index}-request.json", work / f"{index}-receipt.json", \
                work / f"{index}-body.bin"
            request_file.write_text(json.dumps(envelope))
            before = len(_ledger(ledger_path).get("transactions", []))
            result = {"id": item["id"], "route_id": item["route_id"], "mode": item["mode"], "category": item["category"],
                      "status": "halted", "receipts": [], "observed": {"hops": []}}
            stop = None
            try:
                if item["mode"] == "one":
                    receipt, _, _, _ = transport.request_one(Path(allocation_path), ledger_path, request_file, receipt_file,
                                                             body_file)
                    receipts = [receipt]
                elif item["mode"] == "pages":
                    receipts = transport.fetch_pages(Path(allocation_path), ledger_path, request_file, receipt_file,
                                                     None)["receipts"]
                else:
                    receipt = transport.follow_download(Path(allocation_path), ledger_path, request_file, receipt_file,
                                                        body_file)
                    receipts = receipt.get("hops") or [receipt]
            except transport.TransportError as exc:
                stop = {"code": exc.code, "message": str(exc), "request_id": item["id"]}
            except (KeyboardInterrupt, _Interrupted) as exc:
                stop = {"code": "interrupted", "message": str(exc) or "interrupted", "request_id": item["id"]}
            except Exception as exc:  # noqa: BLE001 - any other failure halts the window with its type, never retried
                stop = {"code": "driver_error", "message": type(exc).__name__, "request_id": item["id"]}
            rows = _ledger(ledger_path).get("transactions", [])[before:]
            result["observed"]["hops"] = [_observe(row) for row in rows]
            if stop is not None:
                result["receipts"] = rows
                evidence["results"].append(result)
                write("halted", stop)
                return 1
            result.update(status="complete", receipts=receipts)
            evidence["results"].append(result)
            route_kind = transport.ROUTES[item["route_id"]][2]
            if route_kind == "download":
                final = rows[-1]
                data = body_file.read_bytes() if body_file.exists() else b""
                if _sha256(data) != final.get("raw_observation_sha256"):
                    write("halted", {"code": "body_digest_mismatch", "message": "retained body differs from its receipt",
                                     "request_id": item["id"]})
                    return 1
                bodies["entries"].append(download_body_record(item["id"], final.get("hop_ordinal") or 0, data,
                                                              (final.get("scrubbed_headers") or {}).get("content-type")))
            else:
                for row in rows:
                    bodies["entries"].append({"id": item["id"], "hop_ordinal": row.get("hop_ordinal") or 0,
                                              "page_ordinal": row.get("page_ordinal"), "kind": "json",
                                              "sha256": row.get("raw_observation_sha256"), "bytes": row.get("response_bytes")})
            last = index == len(doc["requests"]) - 1
            write("complete" if last else "halted",
                  None if last else {"code": "incomplete", "message": "window in progress; a crash leaves this record",
                                     "request_id": doc["requests"][index + 1]["id"]})
        return 0
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        shutil.rmtree(work, ignore_errors=True)
        lock_path.unlink(missing_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-requests", metavar="REQUESTS")
    mode.add_argument("--check-only", action="store_true")
    mode.add_argument("--run", action="store_true")
    for name in ("--requests", "--allocation", "--approval", "--ledger", "--evidence", "--bodies"):
        parser.add_argument(name)
    args = parser.parse_args(argv)
    try:
        if args.check_requests:
            _, raw, envelopes = check_requests(args.check_requests)
            print(f"ci-shape-probe: check-requests OK requests_sha256={_sha256(raw)} requests={len(envelopes)}")
            return 0
        needed = ["requests", "allocation", "approval"] + (["ledger", "evidence", "bodies"] if args.run else [])
        missing = [name for name in needed if not getattr(args, name)]
        if missing:
            parser.error("missing " + ", ".join(f"--{name}" for name in missing))
        if args.check_only:
            context = check_only(args.requests, args.allocation, args.approval)
            print(f"ci-shape-probe: check-only OK requests_sha256={context['requests_sha256']} "
                  f"allocation_sha256={context['allocation_sha256']}")
            return 0
        status = run(args.requests, args.allocation, args.approval, args.ledger, args.evidence, args.bodies)
        evidence = json.loads(Path(args.evidence).read_text())
        print("ci-shape-probe: " + json.dumps({"status": evidence["status"], "stop": evidence["stop"],
                                               "request_count": evidence["request_count"],
                                               "elapsed_seconds": evidence["elapsed_seconds"]}, sort_keys=True))
        return status
    except Refusal as exc:
        print(f"ci-shape-probe: REFUSED: {exc.field}: {exc.reason}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
