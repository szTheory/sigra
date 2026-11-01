#!/usr/bin/env python3
"""Bounded, one-request-at-a-time HTTPS transport for Phase 253 evidence."""

from __future__ import annotations

import argparse
import base64
import contextlib
import fcntl
import hashlib
import http.client
import json
import os
import re
import ssl
import subprocess
import tempfile
import time
import uuid
from pathlib import Path
from datetime import datetime
from urllib.parse import parse_qs, quote, urlsplit, urlunsplit


SCHEMA = "sigra.phase253.http-ledger/v2"
API_HOST = "api.github.com"
# 253-125: GitHub's run-log redirect host (R10 ledger sequence 47). Trusted only as hop 1 of run_logs, by exact name.
RESULTS_RECEIVER_HOST = "results-receiver.actions.githubusercontent.com"
DEFAULT_REPO = "szTheory/sigra"
# 253-146: GitHub names live pagination links by the repository's numeric id (/repositories/<id>/<route suffix>), as the
# R12 canary's check_runs Link did (ledger sequence 21; also R11 evidence full-pass run.repository.id). Validated only.
GITHUB_REPOSITORY_ID = 1207487684
MAX_REQUEST_BYTES = 2 * 1024 * 1024
MAX_REQUEST_ENVELOPE_BYTES = MAX_REQUEST_BYTES + 65536
MAX_ALLOCATION_BYTES = 64 * 1024
MAX_INPUT_KEYS = 10
MAX_INPUT_SCALARS = 65535
MAX_INPUT_BYTES = 65535
DISPATCH_INPUT_TYPES = {
    "scenario": str, "candidate_sha": str, "fixture_sha": str, "fixture_blob": str,
    "matrix_evidence": str, "docs_only": bool, "production_dispatch_exemption": bool,
}
SAFE_HEADERS = {
    "content-type", "content-length", "date", "etag", "last-modified",
    "x-github-request-id", "x-ratelimit-limit", "x-ratelimit-remaining",
    "x-ratelimit-reset", "x-ratelimit-resource", "retry-after",
}
ROUTES = {
    "rate_limit": ("GET", "/rate_limit", "json"),
    "rules_main": ("GET", "/repos/{repo}/rules/branches/main", "json"),
    "branch_protection": ("GET", "/repos/{repo}/branches/main/protection", "json"),
    "check_runs": ("GET", "/repos/{repo}/commits/{commit_sha}/check-runs", "json"),
    "workflow": ("GET", "/repos/{repo}/actions/workflows/{workflow_id}", "json"),
    "workflow_runs": ("GET", "/repos/{repo}/actions/workflows/{workflow_id}/runs", "json"),
    "run": ("GET", "/repos/{repo}/actions/runs/{run_id}", "json"),
    "run_jobs": ("GET", "/repos/{repo}/actions/runs/{run_id}/jobs", "json"),
    "run_artifacts": ("GET", "/repos/{repo}/actions/runs/{run_id}/artifacts", "json"),
    "cancel_run": ("POST", "/repos/{repo}/actions/runs/{run_id}/cancel", "json"),
    "dispatch": ("POST", "/repos/{repo}/actions/workflows/{workflow_id}/dispatches", "json"),
    "git_get_blob": ("GET", "/repos/{repo}/git/blobs/{sha}", "json"),
    "git_create_blob": ("POST", "/repos/{repo}/git/blobs", "json"),
    "git_get_tree": ("GET", "/repos/{repo}/git/trees/{sha}", "json"),
    "git_create_tree": ("POST", "/repos/{repo}/git/trees", "json"),
    "git_get_commit": ("GET", "/repos/{repo}/git/commits/{sha}", "json"),
    "git_create_commit": ("POST", "/repos/{repo}/git/commits", "json"),
    "get_ref": ("GET", "/repos/{repo}/git/ref/heads/{branch}", "json"),
    "create_ref": ("POST", "/repos/{repo}/git/refs", "json"),
    "artifact_zip": ("GET", "/repos/{repo}/actions/artifacts/{artifact_id}/zip", "download"),
    "run_logs": ("GET", "/repos/{repo}/actions/runs/{run_id}/logs", "download"),
    "job_logs": ("GET", "/repos/{repo}/actions/jobs/{job_id}/logs", "download"),
    "pr_create": ("POST", "/repos/{repo}/pulls", "json"),
    "pr_read": ("GET", "/repos/{repo}/pulls/{pull_number}", "json"),
    "compare": ("GET", "/repos/{repo}/compare/{base_sha}...{head_sha}", "json"),
    "repo_contents": ("GET", "/repos/{repo}/contents/{content_path}", "json"),
    "attempt_jobs": ("GET", "/repos/{repo}/actions/runs/{run_id}/attempts/{attempt}/jobs", "json"),
    "test_probe": ("GET", "/probe", "test"),
    "test_page": ("GET", "/page/{page_ordinal}", "test"),
}


ALLOCATION_KINDS = ("canary", "production")
# Every route ci-gate-canary.sh and its publisher use; only these follow a canary-kind hermetic allocation locally.
HERMETIC_CANARY_ROUTES = frozenset({
    "rate_limit", "rules_main", "branch_protection", "check_runs", "workflow", "workflow_runs", "run", "run_jobs",
    "run_artifacts", "dispatch", "cancel_run", "get_ref", "create_ref", "git_get_blob", "git_create_blob",
    "git_get_tree", "git_create_tree", "git_get_commit", "git_create_commit", "artifact_zip", "run_logs",
})
CANARY_MAX_REQUESTS = 117
PRODUCTION_MAX_REQUESTS = 120
# Frozen from 253-LOAD-RECOVERY-BUDGETS.md "Actual normal/docs PRs: one combined allocation" (sum 120).
PRODUCTION_CATEGORY_LIMITS = {
    "preflight": 8, "docs_publication": 14, "pr_create": 2, "pr_identity": 8, "run_discovery": 4,
    "pre_watch_rate": 2, "terminal_polls": 27, "attempt_jobs": 4, "native_checks": 4,
    "artifact_metadata": 4, "artifact_downloads": 20, "failure_logs": 2, "infrastructure_rerun": 21,
}
REPO_ROOT = next(p for p in Path(__file__).resolve().parents if (p / ".git").exists())
PR_HEAD_REFS = {"gsd/253-replan-proof-16800f431-candidate", "gsd/253-replan-proof-16800f431-docs-head"}
PR_BASE_REFS = {"main", "gsd/253-replan-proof-16800f431-docs-base"}
CONTENT_PATHS = {".github/workflows/ci.yml", "guides/reference/phase253-docs-only-proof.md"}
PR_CREATE_FIELDS = {"title", "head", "base", "body", "draft"}


class TransportError(Exception):
    def __init__(self, code: str, message: str, exit_code: int = 1):
        super().__init__(message)
        self.code = code
        self.exit_code = exit_code


def serialize_dispatch_inputs(inputs: dict, schema: dict | None = None) -> bytes:
    """Return the canonical UTF-8 bytes for a bounded, typed dispatch input object."""
    declared_types = DISPATCH_INPUT_TYPES if schema is None else schema
    if (not isinstance(declared_types, dict) or any(kind not in (str, bool) for kind in declared_types.values())
            or not isinstance(inputs, dict) or len(inputs) > MAX_INPUT_KEYS or set(inputs) - set(declared_types)):
        raise TransportError("dispatch_inputs_invalid", "dispatch input keys are unknown or exceed the ten-key limit")
    for name, value in inputs.items():
        if value is None or type(value) is not declared_types[name]:
            raise TransportError("dispatch_inputs_invalid", f"dispatch input {name} has an invalid type")
    try:
        payload = json.dumps(inputs, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8", "strict")
    except (UnicodeError, TypeError, ValueError) as exc:
        raise TransportError("dispatch_inputs_invalid", "dispatch inputs contain invalid Unicode or JSON values") from exc
    if len(payload.decode("utf-8", "strict")) > MAX_INPUT_SCALARS:
        raise TransportError("dispatch_inputs_too_large", "dispatch inputs exceed 65535 Unicode scalar characters")
    if len(payload) > MAX_INPUT_BYTES:
        raise TransportError("dispatch_inputs_too_large", "dispatch inputs exceed the conservative 65535 UTF-8-byte limit")
    return payload


def _json(path: Path, limit: int) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) > limit:
        raise TransportError("input_too_large", "transport input exceeds its fixed size limit")
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise TransportError("invalid_json", "transport input is not valid JSON") from exc
    if not isinstance(value, dict):
        raise TransportError("invalid_shape", "transport input must be a JSON object")
    return value, raw


def _atomic_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
        dir_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temp_name)


def _preserve(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        import subprocess as sp
        status = sp.run(["git", "status", "--porcelain=v1", "--", str(path)], text=True,
                        capture_output=True, check=False).stdout.rstrip("\n")
        before = path.read_bytes()
        digest = hashlib.sha256(before).hexdigest()
        if status.strip():
            blob = sp.run(["git", "hash-object", "-w", str(path)], text=True, capture_output=True)
            if blob.returncode:
                raise TransportError("preservation_failed", "could not preserve the prior dirty ledger")
            ref = f"refs/gsd/phase253-http-ledger/{digest}"
            existing = sp.run(["git", "show-ref", "--verify", "--hash", ref], text=True, capture_output=True)
            if existing.returncode:
                update = sp.run(["git", "update-ref", ref, blob.stdout.strip()], capture_output=True)
                if update.returncode:
                    raise TransportError("preservation_failed", "could not anchor the prior dirty ledger")
            readback = sp.run(["git", "show", ref], capture_output=True)
            if readback.returncode or hashlib.sha256(readback.stdout).hexdigest() != digest:
                raise TransportError("preservation_failed", "prior dirty ledger read-back did not match")
            if path.read_bytes() != before or sp.run(["git", "status", "--porcelain=v1", "--", str(path)],
                    text=True, capture_output=True).stdout.rstrip("\n") != status:
                raise TransportError("preservation_failed", "prior ledger changed during preservation")
            return {"path": str(path), "status": status, "sha256": digest, "ref": ref}
        return {"path": str(path), "status": "clean", "sha256": digest, "ref": None}
    except FileNotFoundError:
        # A hermetic fixture outside a Git checkout has no prior version to anchor.
        return {"path": str(path), "status": "untracked-fixture", "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "ref": None}


def _scrub_text(value: str, secrets: list[str]) -> str:
    for secret in secrets:
        if secret:
            value = value.replace(secret, "[REDACTED]")
    value = re.sub(r"(?i)\b(gh[pousr]_[A-Za-z0-9_]{10,}|github_pat_[A-Za-z0-9_]{10,})", "[REDACTED]", value)
    value = re.sub(r"(?i)(authorization|cookie|set-cookie)\s*[:=]\s*[^\s,;]+", r"\1=[REDACTED]", value)
    value = re.sub(r'''(?i)(["']?(?:access_token|token|secret|password|client_secret)["']?\s*:\s*["'])[^"']*(["'])''',
                   r"\1[REDACTED]\2", value)
    value = re.sub(r"(?i)(https?://[^\s\"'<>?#]+)\?[^\s\"'<>#]*", r"\1?[REDACTED]", value)
    return value


def _safe_location(raw: str) -> dict:
    try:
        parsed = urlsplit(raw)
        port = parsed.port
        if (parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password
                or parsed.fragment or (port is not None and not (1 <= port <= 65535)) or not parsed.path.startswith("/")):
            raise ValueError
        return {"host": parsed.hostname.lower(), "port": port, "path": parsed.path, "has_query": bool(parsed.query)}
    except (ValueError, TypeError):
        raise TransportError("malformed_location", "response Location is malformed")


def scrub_receipt(headers, body: bytes, secrets: list[str], raw_headers: list[tuple[str, str]]) -> tuple[dict, bytes]:
    counts = {}
    for name, _ in raw_headers:
        lowered = name.lower()
        counts[lowered] = counts.get(lowered, 0) + 1
    for key in ("location", "link", "content-length", "content-type", "retry-after"):
        if counts.get(key, 0) > 1:
            raise TransportError("duplicate_header", f"response has duplicate {key} headers")

    safe = {}
    links = []
    for name, value in headers:
        key = name.lower()
        if key == "location":
            safe["location"] = _safe_location(value)
        elif key == "link":
            for segment in value.split(","):
                match = re.match(r"\s*<([^>]*)>\s*(.*)", segment)
                if not match:
                    raise TransportError("malformed_link", "response Link header is malformed")
                target, attributes = match.groups()
                safe_target = _safe_location(target) if target.startswith("https://") else None
                rel = re.search(r'(?:^|;)\s*rel="?([A-Za-z0-9_-]+)', attributes)
                links.append({"destination": safe_target, "rel": rel.group(1) if rel else None})
            safe["link"] = links
        elif key in SAFE_HEADERS:
            safe[key] = _scrub_text(value, secrets)

    # Redact decoded values, never JSON syntax: a patch can contain escaped
    # quotes after a URL, and a text regex can otherwise eat the escape byte.
    try:
        value = json.loads(body)
    except (ValueError, UnicodeDecodeError):
        scrubbed = _scrub_text(body.decode("utf-8", errors="replace"), secrets).encode("utf-8")
    else:
        sensitive = re.compile(r"^(access_token|token|secret|password|client_secret|authorization|cookie|set-cookie)$", re.I)

        def scrub_value(node):
            if isinstance(node, dict):
                return {_scrub_text(key, secrets): "[REDACTED]" if sensitive.fullmatch(key) else scrub_value(item)
                        for key, item in node.items()}
            if isinstance(node, list):
                return [scrub_value(item) for item in node]
            if isinstance(node, str):
                return _scrub_text(node, secrets)
            return node

        scrubbed = json.dumps(scrub_value(value), ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return safe, scrubbed


def _positive(value, name: str, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1 or value > maximum:
        raise TransportError("invalid_route_parameter", f"{name} must be an integer from 1 through {maximum}")
    return value


def _route(request: dict, allocation: dict) -> tuple[str, str, bytes | None, str]:
    route_id = request.get("route_id")
    if route_id not in ROUTES:
        raise TransportError("route_rejected", "route ID is not approved")
    expected_method, template, kind = ROUTES[route_id]
    method = request.get("method")
    if method != expected_method:
        raise TransportError("method_rejected", "HTTP method is not approved for this route")
    if kind == "test":
        if allocation.get("mode") != "hermetic-test":
            raise TransportError("test_origin_rejected", "test-only route is forbidden by a live allocation")
        origin = urlsplit(str(allocation.get("test_origin", "")))
        if (origin.scheme != "https" or origin.hostname not in {"localhost", "127.0.0.1"}
                or origin.port is None or origin.username or origin.password or origin.query or origin.fragment):
            raise TransportError("test_origin_rejected", "hermetic test origin must be local HTTPS")
        if route_id == "test_page":
            page = _positive(request.get("page_ordinal"), "page_ordinal", allocation.get("max_pages", 1))
            template = template.format(page_ordinal=page)
        return origin.hostname, origin.port, None, template

    git_object_route = route_id.startswith("git_") or route_id in {"get_ref", "create_ref"}
    hermetic_collector = allocation.get("mode") == "hermetic-test" and allocation.get("allocation_kind") == "production"
    # 253-101: an explicitly canary-kind hermetic allocation routes every canary route to its local test origin, so the
    # whole canary can run offline. A live allocation never reaches this branch and still goes only to api.github.com.
    hermetic_canary = (allocation.get("mode") == "hermetic-test" and allocation.get("allocation_kind") == "canary"
                       and route_id in HERMETIC_CANARY_ROUTES)
    hermetic_collector = hermetic_collector or hermetic_canary
    if (git_object_route or hermetic_collector) and allocation.get("mode") == "hermetic-test":
        origin = urlsplit(str(allocation.get("test_origin", "")))
        if (origin.scheme != "https" or origin.hostname not in {"localhost", "127.0.0.1"}
                or origin.port is None or origin.username or origin.password or origin.query or origin.fragment):
            raise TransportError("test_origin_rejected", "hermetic Git object route must use local HTTPS")
        route_host, route_port = origin.hostname, origin.port
    elif allocation.get("mode") == "live":
        route_host, route_port = API_HOST, 443
    else:
        raise TransportError("live_allocation_required", "Git object routes require live or local hermetic allocation")

    if allocation.get("mode") != "live" and not ((git_object_route or hermetic_collector) and allocation.get("mode") == "hermetic-test"):
        raise TransportError("live_allocation_required", "GitHub routes require a live frozen allocation")
    params = request.get("params", {})
    if not isinstance(params, dict):
        raise TransportError("invalid_route_parameter", "route parameters must be an object")
    repo = allocation.get("repository", DEFAULT_REPO)
    if repo != DEFAULT_REPO:
        raise TransportError("repository_rejected", "allocation repository is not the approved repository")
    values = {"repo": repo}
    for name in ("workflow_id", "run_id", "artifact_id", "job_id", "pull_number", "attempt"):
        if f"{{{name}}}" in template:
            values[name] = str(_positive(params.get(name), name, 10**16))
    for name in ("base_sha", "head_sha"):
        if f"{{{name}}}" in template:
            value = params.get(name)
            if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{40}", value):
                raise TransportError("invalid_route_parameter", f"{name} must be a full lowercase Git SHA")
            values[name] = value
    if "{content_path}" in template:
        content_path = params.get("content_path")
        if not isinstance(content_path, str) or content_path not in CONTENT_PATHS:
            raise TransportError("invalid_route_parameter", "content path is outside the frozen proof file allow-list")
        values["content_path"] = quote(content_path, safe="/-._")
    if "{commit_sha}" in template:
        commit_sha = params.get("commit_sha")
        if not isinstance(commit_sha, str) or not re.fullmatch(r"[a-f0-9]{40}", commit_sha):
            raise TransportError("invalid_route_parameter", "commit_sha must be a full lowercase Git SHA")
        values["commit_sha"] = commit_sha
    if "{sha}" in template:
        sha = params.get("sha")
        if not isinstance(sha, str) or not re.fullmatch(r"[a-f0-9]{40}", sha):
            raise TransportError("invalid_route_parameter", "Git object sha must be a full lowercase Git SHA")
        values["sha"] = sha
    if "{branch}" in template:
        branch = params.get("branch")
        if not isinstance(branch, str) or not re.fullmatch(r"[A-Za-z0-9._/-]{1,160}", branch) or ".." in branch.split("/"):
            raise TransportError("invalid_route_parameter", "branch is not a safe route component")
        values["branch"] = quote(branch, safe="/-._")
    try:
        path = template.format(**values)
    except KeyError as exc:
        raise TransportError("invalid_route_parameter", "required route parameter is missing") from exc
    query = request.get("query", {})
    if not isinstance(query, dict):
        raise TransportError("invalid_route_parameter", "query must be an object")
    permitted = {
        "rules_main": {"per_page", "page"}, "check_runs": {"per_page", "page"},
        "workflow_runs": {"event", "branch", "head_sha", "per_page", "page"},
        "run_jobs": {"per_page", "page"}, "run_artifacts": {"per_page", "page"},
        "attempt_jobs": {"per_page", "page"}, "compare": {"per_page", "page"}, "repo_contents": {"ref"},
    }.get(route_id, set())
    if set(query) - permitted:
        raise TransportError("query_rejected", "route query contains an unapproved key")
    query_parts = []
    for key, value in query.items():
        if key in {"per_page", "page"}:
            number = _positive(value, key, 100)
            query_parts.append(f"{key}={number}")
        elif key == "event" and value in ("workflow_dispatch", "pull_request"):
            query_parts.append(f"event={value}")
        elif key in {"head_sha", "ref"}:
            if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{40}", value) or (
                    key == "head_sha" and route_id != "workflow_runs") or (key == "ref" and route_id != "repo_contents"):
                raise TransportError("invalid_route_parameter", f"{key} must be a full lowercase Git SHA on its typed route")
            query_parts.append(f"{key}={value}")
        elif key == "branch" and route_id == "workflow_runs":
            if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9._/-]{1,160}", value):
                raise TransportError("invalid_route_parameter", "branch query is malformed")
            query_parts.append("branch=" + quote(value, safe="/-._"))
        else:
            raise TransportError("query_rejected", "route query value is not approved")
    if query_parts:
        path += "?" + "&".join(query_parts)
    body = request.get("body")
    if method == "POST":
        if not isinstance(body, dict):
            raise TransportError("invalid_body", "POST route requires a JSON object body")
        if route_id == "dispatch":
            inputs = body.get("inputs")
            canonical_inputs = serialize_dispatch_inputs(inputs)
            body_bytes = json.dumps(body, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode("utf-8", "strict")
            if canonical_inputs not in body_bytes:
                raise TransportError("dispatch_inputs_invalid", "serialized dispatch inputs differ from transmitted request body")
        else:
            body_bytes = json.dumps(body, separators=(",", ":"), ensure_ascii=False).encode()
        if route_id == "create_ref":
            ref, sha = body.get("ref"), body.get("sha")
            if (not isinstance(ref, str) or not re.fullmatch(
                    r"refs/heads/gsd/253-replan-proof-16800f431-(?:candidate|fixture|docs-base|docs-head)", ref)
                    or not isinstance(sha, str) or not re.fullmatch(r"[a-f0-9]{40}", sha)
                    or set(body) != {"ref", "sha"}):
                raise TransportError("ref_rejected", "reference creation is limited to exact gsd/253-replan-* commit refs")
        elif route_id == "pr_create":
            if (set(body) != PR_CREATE_FIELDS or body.get("draft") is not True or body.get("head") not in PR_HEAD_REFS
                    or body.get("base") not in PR_BASE_REFS or not isinstance(body.get("title"), str) or not body["title"]
                    or not isinstance(body.get("body"), str)):
                raise TransportError("pr_body_rejected", "pull request creation is limited to a typed draft from an exact proof head to an exact base")
        elif route_id == "git_create_blob":
            if (set(body) != {"content", "encoding"} or not isinstance(body.get("content"), str)
                    or body.get("encoding") not in {"utf-8", "base64"}):
                raise TransportError("git_blob_body_rejected", "Git blob body requires content and utf-8 or base64 encoding")
            try:
                body["content"].encode("utf-8", "strict") if body["encoding"] == "utf-8" else base64.b64decode(body["content"], validate=True)
            except (UnicodeError, ValueError) as exc:
                raise TransportError("git_blob_body_rejected", "Git blob content is not valid for its declared encoding") from exc
        elif route_id == "git_create_tree":
            if (set(body) - {"base_tree", "tree"} or not isinstance(body.get("tree"), list)
                    or ("base_tree" in body and (not isinstance(body["base_tree"], str)
                    or not re.fullmatch(r"[a-f0-9]{40}", body["base_tree"])) )):
                raise TransportError("git_tree_body_rejected", "Git tree body has an invalid base or entries list")
            seen_paths = set()
            for item in body["tree"]:
                if not isinstance(item, dict) or set(item) - {"path", "mode", "type", "sha", "content"}:
                    raise TransportError("git_tree_body_rejected", "Git tree entry has unknown fields")
                entry_path, mode = item.get("path"), item.get("mode")
                if (not isinstance(entry_path, str) or entry_path.startswith("/") or "\x00" in entry_path
                        or any(part in {"", ".", ".."} for part in entry_path.split("/"))
                        or item.get("type") != "blob" or mode not in {"100644", "100755", "120000"}
                        or (("sha" in item) == ("content" in item))):
                    raise TransportError("git_tree_body_rejected", "Git tree entry path, mode, type, or content is unsafe")
                if entry_path in seen_paths:
                    raise TransportError("git_tree_body_rejected", "Git tree request contains a duplicate path")
                seen_paths.add(entry_path)
                if item.get("sha") is not None and (not isinstance(item["sha"], str) or not re.fullmatch(r"[a-f0-9]{40}", item["sha"])):
                    raise TransportError("git_tree_body_rejected", "Git tree blob sha is malformed")
                if "content" in item:
                    if not isinstance(item["content"], str) or "\x00" in item["content"]:
                        raise TransportError("git_tree_body_rejected", "inline tree content must be NUL-free UTF-8 text")
                    try:
                        item["content"].encode("utf-8", "strict")
                    except UnicodeError as exc:
                        raise TransportError("git_tree_body_rejected", "inline tree content is not valid UTF-8") from exc
                if item.get("sha") is None and "content" not in item:
                    continue
        elif route_id == "git_create_commit":
            fields = {"message", "tree", "parents", "author", "committer"}
            if (set(body) != fields or not isinstance(body.get("message"), str) or not body["message"].endswith("\n")
                    or not isinstance(body.get("tree"), str) or not re.fullmatch(r"[a-f0-9]{40}", body["tree"])
                    or "\x00" in body["message"] or not isinstance(body.get("parents"), list) or len(body["parents"]) != 1
                    or any(not isinstance(parent, str) or not re.fullmatch(r"[a-f0-9]{40}", parent) for parent in body["parents"])):
                raise TransportError("git_commit_body_rejected", "Git commit body must be an unsigned complete commit with a newline-terminated message")
            for identity in (body.get("author"), body.get("committer")):
                if (not isinstance(identity, dict) or set(identity) != {"name", "email", "date"}
                        or not isinstance(identity.get("name"), str) or not identity["name"] or "\n" in identity["name"] or "\x00" in identity["name"]
                        or not isinstance(identity.get("email"), str) or "\n" in identity["email"] or "\x00" in identity["email"]
                        or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", str(identity.get("date")))):
                    raise TransportError("git_commit_body_rejected", "Git commit identities require explicit names, emails, and UTC second-resolution dates")
                try:
                    datetime.strptime(identity["date"], "%Y-%m-%dT%H:%M:%SZ")
                except ValueError as exc:
                    raise TransportError("git_commit_body_rejected", "Git commit date is not a real UTC second-resolution time") from exc
        if len(body_bytes) > MAX_REQUEST_BYTES:
            raise TransportError("request_body_too_large", "request body exceeds the fixed 2 MiB limit")
    else:
        if body is not None:
            raise TransportError("invalid_body", "GET route cannot carry a body")
        body_bytes = None
    return route_host, route_port, body_bytes, path


def _validate_allocation(allocation: dict) -> None:
    if allocation.get("schema_version") != "sigra.phase253.http-allocation/v1":
        raise TransportError("allocation_schema", "allocation schema is not recognized")
    mode = allocation.get("mode")
    if mode not in {"live", "hermetic-test"}:
        raise TransportError("allocation_mode", "allocation mode must be live or hermetic-test")
    common = {"schema_version", "window_id", "source_sha256", "max_requests", "max_elapsed_seconds",
              "max_response_bytes", "max_pages", "max_hops", "repository", "mode", "download_hosts",
              "allocation_kind", "category_limits", "bound_documents"}
    test_only = {"test_origin", "test_ca_file"}
    allowed = common | test_only if mode == "hermetic-test" else common
    if set(allocation) - allowed:
        raise TransportError("allocation_field_rejected", "allocation contains unapproved fields")
    if mode == "live" and set(allocation) & test_only:
        raise TransportError("test_origin_rejected", "live allocations cannot name test origins or certificates")
    if not isinstance(allocation.get("window_id"), str) or not allocation["window_id"] or len(allocation["window_id"]) > 128:
        raise TransportError("allocation_incomplete", "allocation window identity is missing or malformed")
    if not isinstance(allocation.get("source_sha256"), str) or not re.fullmatch(r"[a-f0-9]{64}", allocation["source_sha256"]):
        raise TransportError("allocation_incomplete", "source digest is malformed")
    for field, upper in (("max_elapsed_seconds", 3600), ("max_response_bytes", 4 * 1024 * 1024),
                         ("max_pages", 100), ("max_hops", 2)):
        value = allocation.get(field)
        if isinstance(value, bool) or not isinstance(value, int) or value < 1 or value > upper:
            raise TransportError("allocation_limit_invalid", f"{field} must be from one through {upper}")
    kind = allocation.get("allocation_kind", "canary")  # legacy allocations predate the typed purpose and are canary-kind
    if kind not in ALLOCATION_KINDS:
        raise TransportError("allocation_kind_rejected", "allocation kind must be canary or production")
    max_requests = allocation.get("max_requests")
    min_requests = 0 if mode == "hermetic-test" else 1
    if kind == "production":
        # Only the production purpose may use 120; it is exactly 120 so a smaller window cannot silently stand in.
        in_range = max_requests == PRODUCTION_MAX_REQUESTS
    elif mode == "live":
        in_range = isinstance(max_requests, int) and min_requests <= max_requests <= CANARY_MAX_REQUESTS
    else:
        in_range = isinstance(max_requests, int) and min_requests <= max_requests <= CANARY_MAX_REQUESTS
    if isinstance(max_requests, bool) or not isinstance(max_requests, int) or not in_range:
        raise TransportError("allocation_limit_invalid", "max_requests is outside its approved allocation range")
    limits = allocation.get("category_limits")
    if kind == "production":
        if limits != PRODUCTION_CATEGORY_LIMITS or any(type(value) is not int for value in (limits or {}).values()):
            raise TransportError("category_limits_invalid", "production category limits must equal the frozen budget table exactly")
    elif limits is not None:
        if (not isinstance(limits, dict) or not limits or any(not isinstance(key, str) or not key or len(key) > 64 or
                type(value) is not int or value < 1 for key, value in limits.items())
                or sum(limits.values()) > max_requests):
            raise TransportError("category_limits_invalid", "category limits must be positive integers that fit the allocation")
    documents = allocation.get("bound_documents")
    if documents is not None:
        if (not isinstance(documents, list) or len(documents) > 16 or any(
                not isinstance(item, dict) or set(item) != {"path", "sha256"} or not isinstance(item["path"], str)
                or not item["path"] or not isinstance(item["sha256"], str) or not re.fullmatch(r"[a-f0-9]{64}", item["sha256"])
                for item in documents)):
            raise TransportError("bound_documents_invalid", "bound documents must be path and lowercase SHA-256 pairs")
    if allocation.get("repository", DEFAULT_REPO) != DEFAULT_REPO:
        raise TransportError("repository_rejected", "allocation repository is not the approved repository")
    if mode == "live":
        hosts = allocation.get("download_hosts")
        if not isinstance(hosts, list) or len(set(hosts)) != len(hosts):
            raise TransportError("download_host_allocation", "live allocation requires a unique trusted download-host list")
        for host in hosts:
            if host != RESULTS_RECEIVER_HOST and not _pre_r11_download_host(host):
                raise TransportError("download_host_allocation", "live allocation contains a host outside the trusted policy")
    elif not allocation.get("test_origin") or not allocation.get("test_ca_file"):
        raise TransportError("test_origin_rejected", "hermetic allocation requires its local TLS origin and test CA")


def _check_bound_documents(allocation: dict) -> None:
    for item in allocation.get("bound_documents") or []:
        candidate = Path(item["path"])
        resolved = candidate if candidate.is_absolute() else REPO_ROOT / candidate
        try:
            actual = hashlib.sha256(resolved.read_bytes()).hexdigest()
        except OSError as exc:
            raise TransportError("bound_document_mismatch", "a frozen bound document is unreadable") from exc
        if actual != item["sha256"]:
            raise TransportError("bound_document_mismatch", "a frozen bound document differs from its SHA-256 binding")


def _request_category(request: dict, allocation: dict):
    limits = allocation.get("category_limits")
    category = request.get("category")
    if limits is None:
        if category is not None and not isinstance(category, str):
            raise TransportError("category_rejected", "request category must be a string")
        return category
    if not isinstance(category, str) or category not in limits:
        raise TransportError("category_rejected", "request category is missing or not in the frozen allocation")
    return category


def _load_ledger(path: Path, allocation: dict, allocation_hash: str) -> dict:
    if path.exists():
        ledger, _ = _json(path, 8 * 1024 * 1024)
        if (ledger.get("schema_version") != SCHEMA or ledger.get("window_id") != allocation["window_id"]
                or ledger.get("allocation_sha256") != allocation_hash
                or ledger.get("source_sha256") != allocation["source_sha256"]):
            raise TransportError("ledger_identity_mismatch", "ledger window, allocation or source identity changed")
        if ledger.get("terminal_stop"):
            raise TransportError("terminal_stop", "ledger records a terminal stop; no more network requests are allowed")
        if any(entry.get("state") == "pending" for entry in ledger.get("transactions", [])):
            raise TransportError("incomplete_pending", "ledger contains an incomplete charged request")
        return ledger
    return {"schema_version": SCHEMA, "window_id": allocation["window_id"],
            "allocation_sha256": allocation_hash, "source_sha256": allocation["source_sha256"],
            "transactions": [], "terminal_stop": None, "preserved_revisions": []}


def _lock(path: Path):
    lock_path = Path(str(path) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    stream = lock_path.open("a+")
    fcntl.flock(stream.fileno(), fcntl.LOCK_EX)
    return stream


def _connect(host: str, port: int, allocation: dict) -> http.client.HTTPSConnection:
    context = ssl.create_default_context()
    if allocation.get("mode") == "hermetic-test":
        ca_file = allocation.get("test_ca_file")
        if not ca_file or not Path(ca_file).is_file():
            raise TransportError("test_ca_missing", "hermetic TLS certificate is unavailable")
        context.load_verify_locations(cafile=ca_file)
    return http.client.HTTPSConnection(host, port, timeout=30, context=context)


def request_one(allocation_path: Path, ledger_path: Path, request_path: Path,
                output_path: Path, body_output: Path | None = None,
                destination: tuple[str, int, str] | None = None) -> tuple[dict, str | None, bytes, list[tuple[str, str]]]:
    from execution_guard import authorize_request
    authorize_request(allocation_path, ledger_path, request_path)
    allocation, allocation_raw = _json(allocation_path, MAX_ALLOCATION_BYTES)
    request, _ = _json(request_path, MAX_REQUEST_ENVELOPE_BYTES)
    _validate_allocation(allocation)
    host, port, body, path = _route(request, allocation)
    category = _request_category(request, allocation)
    family = request.get("family")
    if family is not None and family not in {"normal", "docs-only", "shared"}:
        raise TransportError("family_rejected", "request family must be normal, docs-only, or shared")
    _check_bound_documents(allocation)
    if destination is not None:
        host, port, path = destination
        if not host or not (1 <= port <= 65535) or not path.startswith("/") or "#" in path or "\r" in path or "\n" in path:
            raise TransportError("redirect_rejected", "redirect destination is malformed")
    if allocation.get("mode") != "hermetic-test":
        # 253-107: hop 0 (or no destination) is api.github.com:443 only. A later hop is only the follow_download
        # destination _approved_redirect accepted, re-validated here with the same predicate, on a download route.
        hop_ordinal = request.get("hop_ordinal", 0)
        if destination is None or not hop_ordinal:
            if host != API_HOST or port != 443:
                raise TransportError("origin_rejected", "live transport is restricted to api.github.com")
        elif (ROUTES[request["route_id"]][2] != "download" or isinstance(hop_ordinal, bool) or not isinstance(hop_ordinal, int)
                or hop_ordinal < 1 or hop_ordinal > allocation["max_hops"]
                or not _trusted_download_host(host, port, allocation, request["route_id"], hop_ordinal)):
            raise TransportError("origin_rejected", "live redirect hop is not an approved trusted download host")

    allocation_hash = hashlib.sha256(allocation_raw).hexdigest()
    start_ns = time.monotonic_ns()
    lock = _lock(ledger_path)
    try:
        ledger = _load_ledger(ledger_path, allocation, allocation_hash)
        if len(ledger["transactions"]) >= allocation["max_requests"]:
            ledger["terminal_stop"] = {"code": "request_budget_exhausted", "at_monotonic_ns": start_ns}
            _atomic_json(ledger_path, ledger)
            raise TransportError("request_budget_exhausted", "request allocation is exhausted")
        elapsed = (start_ns - ledger.get("started_monotonic_ns", start_ns)) / 1e9
        if elapsed >= allocation["max_elapsed_seconds"]:
            ledger["terminal_stop"] = {"code": "time_budget_exhausted", "at_monotonic_ns": start_ns}
            _atomic_json(ledger_path, ledger)
            raise TransportError("time_budget_exhausted", "request allocation time limit is exhausted")
        limits = allocation.get("category_limits")
        if limits is not None and sum(1 for item in ledger["transactions"] if item.get("category") == category) >= limits[category]:
            ledger["terminal_stop"] = {"code": "category_budget_exhausted", "category": category, "at_monotonic_ns": start_ns}
            _atomic_json(ledger_path, ledger)
            raise TransportError("category_budget_exhausted", f"category {category} allocation is exhausted")
        prior = _preserve(ledger_path)
        if prior:
            ledger["preserved_revisions"].append(prior)
        ledger.setdefault("started_monotonic_ns", start_ns)
        sequence = len(ledger["transactions"]) + 1
        request_url_actual = f"https://{host}{path}"
        redact_query = request.get("hop_ordinal", 0) > 0 or ROUTES[request["route_id"]][2] == "download"
        request_url = request_url_actual
        if redact_query and "?" in request_url:
            request_url = request_url.split("?", 1)[0] + "?[REDACTED]"
        # The typed request body (a dict), not the serialized bytes: the dispatch metrics come from the exact inputs (253-101).
        request_body = request.get("body")
        dispatch_inputs = (request_body.get("inputs") if request.get("route_id") == "dispatch" and isinstance(request_body, dict)
                           else None)
        dispatch_bytes = serialize_dispatch_inputs(dispatch_inputs) if dispatch_inputs is not None else None
        entry = {"sequence": sequence, "request_kind": request.get("request_kind", request["route_id"]),
                 "method": request["method"], "route_id": request["route_id"], "host": host,
                 "url": request_url, "url_sha256": hashlib.sha256(request_url_actual.encode()).hexdigest(),
                 "request_sha256": hashlib.sha256(body or b"").hexdigest() if body is not None else None,
                 "page_ordinal": request.get("page_ordinal"), "hop_ordinal": request.get("hop_ordinal"),
                 "request_group": request.get("request_group"), "window_id": allocation["window_id"],
                 "source_sha256": allocation["source_sha256"], "category": category, "family": family,
                 "request_body_base64": base64.b64encode(body).decode("ascii") if request["route_id"] == "dispatch" and body is not None else None,
                 "request_body_bytes": len(body) if body is not None else None,
                 "request_body_sha256": hashlib.sha256(body).hexdigest() if body is not None else None,
                 "dispatch_inputs": dispatch_inputs,
                 "input_key_count": len(dispatch_inputs) if dispatch_bytes is not None else None,
                 "input_unicode_scalars": len(dispatch_bytes.decode("utf-8")) if dispatch_bytes is not None else None,
                 "input_utf8_bytes": len(dispatch_bytes) if dispatch_bytes is not None else None,
                 "input_sha256": hashlib.sha256(dispatch_bytes).hexdigest() if dispatch_bytes is not None else None,
                 "state": "pending", "started_monotonic_ns": start_ns, "ended_monotonic_ns": None,
                 "actual_status": None, "scrubbed_headers": {}, "response_sha256": None,
                 "raw_observation_sha256": None, "response_bytes": None, "scrubbed_response_bytes": None}
        ledger["transactions"].append(entry)
        _atomic_json(ledger_path, ledger)
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()

    token = ""
    if host == API_HOST:
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""
        if not token:
            result = subprocess.run(["gh", "auth", "token"], text=True, capture_output=True, check=False, timeout=10)
            token = result.stdout.strip() if result.returncode == 0 else ""
        if not token:
            _finish_failure(ledger_path, sequence, "authentication_unavailable", "GitHub authentication is unavailable")
            raise TransportError("authentication_unavailable", "GitHub authentication is unavailable")

    headers = {"Accept": "application/vnd.github+json" if host == API_HOST else "application/json",
               "Connection": "close", "User-Agent": "sigra-phase253-transport"}
    secrets = [token]
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        headers["Content-Type"] = "application/json"

    connection = None
    actual_status = None
    response_headers = []
    response_body = b""
    error_code = None
    error_message = None
    deadline = time.monotonic() + 30
    try:
        connection = _connect(host, port, allocation)
        connection.timeout = max(0.1, deadline - time.monotonic())
        connection.request(request["method"], path, body=body, headers=headers)
        response = connection.getresponse()
        actual_status = response.status
        response_headers = response.getheaders()
        cap = allocation["max_response_bytes"]
        chunks = []
        byte_count = 0
        while byte_count <= cap:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                error_code = "request_deadline"
                error_message = "request exceeded its 30-second deadline"
                break
            if connection.sock is not None:
                connection.sock.settimeout(remaining)
            chunk = response.read(min(65536, cap + 1 - byte_count))
            if not chunk:
                break
            chunks.append(chunk)
            byte_count += len(chunk)
        response_body = b"".join(chunks)
        if len(response_body) > cap:
            error_code = "response_too_large"
            error_message = "response exceeded its frozen byte limit"
        if time.monotonic() > deadline:
            error_code = "request_deadline"
            error_message = "request exceeded its 30-second deadline"
    except (OSError, ssl.SSLError, http.client.HTTPException, TimeoutError) as exc:
        error_code = "connection_failure"
        error_message = _scrub_text(type(exc).__name__, secrets)
    finally:
        if connection is not None:
            connection.close()

    if actual_status is not None:
        try:
            safe_headers, scrubbed_body = scrub_receipt(response_headers, response_body, secrets, response_headers)
        except TransportError as exc:
            safe_headers, scrubbed_body = {}, b""
            error_code, error_message = exc.code, exc.code
    else:
        safe_headers, scrubbed_body = {}, b""
    core_remaining = safe_headers.get("x-ratelimit-remaining") if safe_headers.get("x-ratelimit-resource") == "core" else None
    hard_stop = actual_status in {401, 403, 429} or (core_remaining is not None and str(core_remaining).isdigit() and int(core_remaining) <= 250)
    if error_code:
        hard_stop = True
    end_ns = time.monotonic_ns()
    lock = _lock(ledger_path)
    try:
        ledger = _load_ledger_allow_pending(ledger_path, allocation, allocation_hash)
        entry = next(item for item in ledger["transactions"] if item["sequence"] == sequence)
        entry.update({"state": "failed" if error_code else "complete", "ended_monotonic_ns": end_ns,
                      "actual_status": actual_status, "scrubbed_headers": safe_headers,
                      "response_sha256": hashlib.sha256(scrubbed_body).hexdigest() if actual_status is not None else None,
                      "raw_observation_sha256": hashlib.sha256(response_body).hexdigest() if actual_status is not None else None,
                      "response_bytes": len(response_body), "scrubbed_response_bytes": len(scrubbed_body),
                      "response_body_base64": base64.b64encode(scrubbed_body).decode("ascii"),
                      "error": {"code": error_code, "message": error_message} if error_code else None})
        if hard_stop:
            ledger["terminal_stop"] = {"code": error_code or (f"http_{actual_status}" if actual_status in {401, 403, 429} else "core_budget_stop"),
                                       "status": actual_status, "retry_after": safe_headers.get("retry-after"),
                                       "rate_limit_reset": safe_headers.get("x-ratelimit-reset"),
                                       "at_monotonic_ns": end_ns}
        _atomic_json(ledger_path, ledger)
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()

    receipt = {"schema_version": "sigra.phase253.http-receipt/v1", "window_id": allocation["window_id"],
               "allocation_sha256": allocation_hash, "source_sha256": allocation["source_sha256"],
               "sequence": sequence, "method": request["method"], "route_id": request["route_id"], "host": host,
               "page_ordinal": request.get("page_ordinal"), "hop_ordinal": request.get("hop_ordinal"),
               "actual_status": actual_status, "scrubbed_headers": safe_headers,
               "response_sha256": hashlib.sha256(scrubbed_body).hexdigest() if actual_status is not None else None,
               "raw_observation_sha256": hashlib.sha256(response_body).hexdigest() if actual_status is not None else None,
               "response_bytes": len(response_body), "scrubbed_response_bytes": len(scrubbed_body),
               "url": request_url, "url_sha256": hashlib.sha256(request_url_actual.encode()).hexdigest(),
               "request_sha256": hashlib.sha256(body or b"").hexdigest() if body is not None else None,
               "request_group": request.get("request_group"),
               "request_body_base64": base64.b64encode(body).decode("ascii") if request["route_id"] == "dispatch" and body is not None else None,
               "request_body_bytes": len(body) if body is not None else None,
               "request_body_sha256": hashlib.sha256(body).hexdigest() if body is not None else None,
               "dispatch_inputs": dispatch_inputs,
               "input_key_count": len(dispatch_inputs) if dispatch_bytes is not None else None,
               "input_unicode_scalars": len(dispatch_bytes.decode("utf-8")) if dispatch_bytes is not None else None,
               "input_utf8_bytes": len(dispatch_bytes) if dispatch_bytes is not None else None,
               "input_sha256": hashlib.sha256(dispatch_bytes).hexdigest() if dispatch_bytes is not None else None,
               "response_body_base64": base64.b64encode(scrubbed_body).decode("ascii"),
               "error": {"code": error_code, "message": error_message} if error_code else None,
               "terminal_stop": hard_stop}
    _atomic_json(output_path, receipt)
    route_kind = ROUTES[request["route_id"]][2]
    retained_body = response_body if route_kind == "download" else scrubbed_body
    if body_output is not None and actual_status is not None and not error_code:
        body_output.parent.mkdir(parents=True, exist_ok=True)
        body_output.write_bytes(retained_body)
    if error_code:
        raise TransportError(error_code, error_message or "request failed")
    raw_location = [value for name, value in response_headers if name.lower() == "location"]
    if hard_stop:
        stop = (ledger.get("terminal_stop") or {}).get("code", "terminal_stop")
        raise TransportError(stop, "HTTP response requires a terminal stop")
    return receipt, raw_location[0] if raw_location else None, scrubbed_body, response_headers


def _pre_r11_download_host(host) -> bool:
    """The pre-R11 trusted download-host set, unchanged for every route and hop."""
    return host == "pipelines.actions.githubusercontent.com" or bool(
        re.fullmatch(r"productionresultssa[0-9]+\.blob\.core\.windows\.net", str(host)))


def _trusted_download_host(host, port, allocation: dict, route_id, hop_ordinal) -> bool:
    """The single live download-hop predicate shared by _approved_redirect and request_one (253-107).

    253-125: results-receiver is admitted by exact name, only as hop 1 of the run_logs route, only when listed.
    """
    if port not in (None, 443) or not isinstance(host, str):
        return False
    if host not in (allocation.get("download_hosts") or []):
        return False
    if _pre_r11_download_host(host):
        return True
    return host == RESULTS_RECEIVER_HOST and route_id == "run_logs" and type(hop_ordinal) is int and hop_ordinal == 1


def _approved_redirect(location: str, allocation: dict, route_id, hop_ordinal) -> tuple[str, int, str]:
    try:
        parsed = urlsplit(location)
        port = parsed.port
    except ValueError as exc:
        raise TransportError("redirect_rejected", "redirect URL is malformed") from exc
    if (parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password
            or parsed.fragment or not parsed.path.startswith("/") or "\r" in location or "\n" in location):
        raise TransportError("redirect_rejected", "redirect URL contains a forbidden component")
    host = parsed.hostname.lower()
    if allocation.get("mode") == "hermetic-test":
        test_origin = urlsplit(allocation["test_origin"])
        if host != test_origin.hostname or port != test_origin.port:
            raise TransportError("redirect_rejected", "hermetic redirect left its exact local test origin")
    elif not _trusted_download_host(host, port, allocation, route_id, hop_ordinal):
        raise TransportError("redirect_rejected", "redirect host is outside the frozen download-host list or trusted download policy")
    target = urlunsplit(("", "", parsed.path, parsed.query, ""))
    return host, port or 443, target


def follow_download(allocation_path: Path, ledger_path: Path, request_path: Path,
                    output_path: Path, body_output: Path | None = None) -> dict:
    request, _ = _json(request_path, MAX_REQUEST_BYTES)
    allocation, _ = _json(allocation_path, MAX_ALLOCATION_BYTES)
    _route(request, allocation)
    kind = ROUTES[request["route_id"]][2]
    if request["method"] != "GET" or kind not in {"download", "test"}:
        raise TransportError("redirect_route_rejected", "redirect following is limited to approved GET download routes")
    max_hops = allocation.get("max_hops", 0)
    if isinstance(max_hops, bool) or not isinstance(max_hops, int) or max_hops < 0 or max_hops > 2:
        raise TransportError("hop_budget_invalid", "download hop allocation must be from zero through two")
    hop = 0
    request_group = uuid.uuid4().hex
    seen = set()
    destination = None
    hop_receipts = []
    while True:
        hop_request = dict(request)
        hop_request["hop_ordinal"] = hop
        hop_request["request_group"] = request_group
        temp_fd, temp_name = tempfile.mkstemp(prefix="ci-http-hop-request-")
        os.close(temp_fd)
        temp_request = Path(temp_name)
        try:
            temp_request.write_text(json.dumps(hop_request))
            receipt, location, _, _ = request_one(allocation_path, ledger_path, temp_request,
                                                   output_path, body_output, destination)
        finally:
            temp_request.unlink(missing_ok=True)
        hop_receipts.append(receipt)
        if receipt["actual_status"] not in {301, 302, 303, 307, 308}:
            if len(hop_receipts) > 1:
                # 253-101: keep every charged hop's receipt (the final one stays at the top level for existing readers).
                receipt = dict(receipt, hops=hop_receipts)
                _atomic_json(output_path, receipt)
            return receipt
        if location is None or hop >= max_hops:
            _terminalize(ledger_path, "redirect_budget_exhausted", receipt["actual_status"])
            raise TransportError("redirect_budget_exhausted", "redirect is missing Location or exceeds its frozen hop count")
        try:
            destination = _approved_redirect(location, allocation, request["route_id"], hop + 1)
        except TransportError as exc:
            _terminalize(ledger_path, exc.code, receipt["actual_status"])
            raise
        key = (destination[0], destination[1], destination[2])
        if key in seen:
            _terminalize(ledger_path, "redirect_cycle", receipt["actual_status"])
            raise TransportError("redirect_cycle", "redirect destination repeated")
        seen.add(key)
        hop += 1


def _terminalize(path: Path, code: str, status: int | None) -> None:
    lock = _lock(path)
    try:
        ledger, _ = _json(path, 8 * 1024 * 1024)
        ledger["terminal_stop"] = {"code": code, "status": status, "at_monotonic_ns": time.monotonic_ns()}
        _atomic_json(path, ledger)
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()


def fetch_pages(allocation_path: Path, ledger_path: Path, request_path: Path,
                output_path: Path, body_output: Path | None = None) -> dict:
    initial, _ = _json(request_path, MAX_REQUEST_BYTES)
    allocation, _ = _json(allocation_path, MAX_ALLOCATION_BYTES)
    _route(initial, allocation)
    if initial.get("method") != "GET" or initial.get("route_id") not in {"workflow_runs", "rules_main", "check_runs", "run_jobs", "run_artifacts", "attempt_jobs", "compare", "test_page"}:
        raise TransportError("pagination_route_rejected", "route is not an approved paginated GET")
    max_pages = allocation.get("max_pages", 0)
    if isinstance(max_pages, bool) or not isinstance(max_pages, int) or max_pages < 1 or max_pages > 100:
        raise TransportError("page_budget_invalid", "page allocation must be from one through one hundred")
    if initial["route_id"] == "rules_main":
        max_pages = min(max_pages, 2)
    pages, receipts, seen = [], [], set()
    page = 1
    while True:
        current = dict(initial)
        current["page_ordinal"] = page
        if current["route_id"] != "test_page":
            query = dict(current.get("query", {}))
            query["page"] = page
            current["query"] = query
        temp_fd, temp_name = tempfile.mkstemp(prefix="ci-http-page-request-")
        os.close(temp_fd)
        temp_request = Path(temp_name)
        try:
            temp_request.write_text(json.dumps(current))
            receipt, _, raw_body, raw_headers = request_one(
                allocation_path, ledger_path, temp_request, output_path, None
            )
            receipts.append(receipt)
            try:
                parsed_body = json.loads(raw_body.decode("utf-8", errors="replace"))
            except (ValueError, UnicodeDecodeError) as exc:
                _terminalize(ledger_path, "invalid_page_json", receipt["actual_status"])
                raise TransportError("invalid_page_json", "paginated response was not valid JSON") from exc
            pages.append(parsed_body)
            links = [value for name, value in raw_headers if name.lower() == "link"]
            if len(links) > 1:
                _terminalize(ledger_path, "malformed_link", receipt["actual_status"])
                raise TransportError("malformed_link", "response contains duplicate Link headers")
            try:
                next_url = _next_page_url(links[0], current, allocation) if links else None
            except TransportError as exc:
                _terminalize(ledger_path, exc.code, receipt["actual_status"])
                raise
            if initial["route_id"] == "rules_main":
                if not isinstance(parsed_body, list):
                    _terminalize(ledger_path, "invalid_rules_shape", receipt["actual_status"])
                    raise TransportError("invalid_rules_shape", "effective branch rules page must be an array")
                if page == 2 and len(parsed_body) == 100:
                    _terminalize(ledger_path, "rules_completeness_unknown", receipt["actual_status"])
                    raise TransportError("rules_completeness_unknown", "a full second rules page does not prove terminal completeness")
                if len(parsed_body) < 100 and next_url is not None:
                    _terminalize(ledger_path, "rules_total_disagreement", receipt["actual_status"])
                    raise TransportError("rules_total_disagreement", "a short rules page unexpectedly advertises another page")
                if page == 1 and len(parsed_body) == 100 and next_url is None:
                    if page >= max_pages:
                        _terminalize(ledger_path, "rules_completeness_unknown", receipt["actual_status"])
                        raise TransportError("rules_completeness_unknown", "full first rules page needs one charged second page")
                    parsed = urlsplit(f"https://{API_HOST}{_route(current, allocation)[3]}")
                    query = parse_qs(parsed.query)
                    query["page"] = ["2"]
                    next_url = urlunsplit(("https", API_HOST, parsed.path,
                                           "&".join(f"{key}={values[0]}" for key, values in query.items()), ""))
            if next_url is None:
                break
            if next_url in seen or page >= max_pages:
                _terminalize(ledger_path, "page_budget_or_cycle", receipt["actual_status"])
                raise TransportError("page_budget_or_cycle", "pagination repeated a destination or exceeded its frozen page count")
            seen.add(next_url)
            page += 1
        finally:
            temp_request.unlink(missing_ok=True)
    route_id = initial["route_id"]
    if route_id == "rules_main":
        aggregate = [item for item in pages for item in item] if all(isinstance(item, list) for item in pages) else pages
    else:
        collection_key = {"workflow_runs": "workflow_runs", "run_jobs": "jobs", "attempt_jobs": "jobs",
                          "run_artifacts": "artifacts", "check_runs": "check_runs", "compare": "files"}.get(route_id)
        if collection_key:
            aggregate = dict(pages[-1])
            aggregate[collection_key] = [item for page_data in pages for item in page_data.get(collection_key, [])]
        else:
            aggregate = pages
    result = {"schema_version": "sigra.phase253.http-pages/v1", "page_count": len(pages),
              "receipts": receipts}
    _atomic_json(output_path, result)
    if body_output is not None:
        _atomic_json(body_output, aggregate)
    return result


def _next_page_url(link_value: str, request: dict, allocation: dict) -> str | None:
    segments = re.split(r",\s*(?=<)", link_value)
    next_targets = []
    for segment in segments:
        match = re.fullmatch(r'\s*<([^>]*)>\s*((?:;\s*[A-Za-z0-9_-]+=(?:"[^"]*"|[^;\s]+))*)\s*', segment)
        if not match:
            raise TransportError("malformed_link", "response Link header is malformed")
        target, attrs = match.groups()
        rel = re.search(r'(?:^|;)\s*rel="?([A-Za-z0-9_-]+)', attrs)
        if rel and rel.group(1) == "next":
            next_targets.append(target)
    if not next_targets:
        return None
    if len(next_targets) != 1:
        raise TransportError("malformed_link", "response Link header has duplicate next destinations")
    target = next_targets[0]
    parsed = urlsplit(target)
    if allocation.get("mode") == "hermetic-test" and request.get("route_id") == "test_page":
        origin = urlsplit(allocation["test_origin"])
        valid = parsed.scheme == "https" and parsed.hostname == origin.hostname and parsed.port == origin.port
        expected_path = f"/page/{request.get('page_ordinal', 0) + 1}"
        if not valid or parsed.path != expected_path or parsed.query or parsed.fragment or parsed.username or parsed.password:
            raise TransportError("pagination_destination_rejected", "test pagination link left its typed local page route")
        return target
    if allocation.get("mode") == "hermetic-test":
        origin = urlsplit(allocation["test_origin"])
        if parsed.scheme != "https" or parsed.hostname != origin.hostname or parsed.port != origin.port or parsed.username or parsed.password or parsed.fragment:
            raise TransportError("pagination_destination_rejected", "hermetic pagination link left its exact local origin")
        _, _, _, expected_path = _route(request, allocation)
        if parsed.path != expected_path.split("?", 1)[0]:
            raise TransportError("pagination_destination_rejected", "pagination link changed its approved API route")
        query = parse_qs(parsed.query, keep_blank_values=True, strict_parsing=True)
        page_value = query.get("page", [None])[0]
        if (set(query) - {"page", "per_page", "event", "branch", "head_sha"} or any(len(v) != 1 for v in query.values())
                or not page_value or not page_value.isdigit() or int(page_value) != request.get("page_ordinal", 0) + 1):
            raise TransportError("pagination_destination_rejected", "pagination link did not advance exactly one page")
        return urlunsplit(("https", parsed.hostname, parsed.path, parsed.query, ""))
    if parsed.scheme != "https" or parsed.hostname != API_HOST or parsed.port not in (None, 443) or parsed.username or parsed.password or parsed.fragment:
        raise TransportError("pagination_destination_rejected", "pagination link must stay on api.github.com")
    _, _, _, expected_path = _route(request, allocation)
    approved_path = expected_path.split("?", 1)[0]
    # 253-146: GitHub may name the same route by repository id; only this repository's id and the identical route suffix.
    suffix = approved_path.removeprefix(f"/repos/{DEFAULT_REPO}/")
    id_path = f"/repositories/{GITHUB_REPOSITORY_ID}/{suffix}"
    if suffix == approved_path or parsed.path not in (approved_path, id_path):
        raise TransportError("pagination_destination_rejected", "pagination link changed its approved API route")
    query = parse_qs(parsed.query, keep_blank_values=True, strict_parsing=True)
    if set(query) - {"page", "per_page", "event", "branch", "head_sha"} or any(len(values) != 1 for values in query.values()):
        raise TransportError("pagination_destination_rejected", "pagination link has an unapproved or repeated query key")
    page_value = query.get("page", [None])[0]
    if not page_value or not page_value.isdigit() or int(page_value) != request.get("page_ordinal", 0) + 1:
        raise TransportError("pagination_destination_rejected", "pagination link did not advance exactly one page")
    return urlunsplit(("https", API_HOST, parsed.path, parsed.query, ""))


def _load_ledger_allow_pending(path: Path, allocation: dict, allocation_hash: str) -> dict:
    ledger, _ = _json(path, 8 * 1024 * 1024)
    if (ledger.get("schema_version") != SCHEMA or ledger.get("window_id") != allocation["window_id"]
            or ledger.get("allocation_sha256") != allocation_hash or ledger.get("source_sha256") != allocation["source_sha256"]):
        raise TransportError("ledger_identity_mismatch", "ledger identity changed while request was active")
    return ledger


def _finish_failure(path: Path, sequence: int, code: str, message: str) -> None:
    lock = _lock(path)
    try:
        ledger, _ = _json(path, 8 * 1024 * 1024)
        entry = next(item for item in ledger["transactions"] if item["sequence"] == sequence)
        now = time.monotonic_ns()
        entry.update({"state": "failed", "ended_monotonic_ns": now, "error": {"code": code, "message": message}})
        ledger["terminal_stop"] = {"code": code, "at_monotonic_ns": now}
        _atomic_json(path, ledger)
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()


def _cli() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allocation", required=True)
    parser.add_argument("--ledger", required=True)
    parser.add_argument("--request", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--body-output")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--follow-download", action="store_true")
    parser.add_argument("--fetch-pages", action="store_true")
    args = parser.parse_args()
    try:
        if args.check_only:
            allocation, _ = _json(Path(args.allocation), MAX_ALLOCATION_BYTES)
            _validate_allocation(allocation)
            request, _ = _json(Path(args.request), MAX_REQUEST_ENVELOPE_BYTES)
            _route(request, allocation)
            return 0
        arguments = (Path(args.allocation), Path(args.ledger), Path(args.request), Path(args.output),
                     Path(args.body_output) if args.body_output else None)
        if args.follow_download:
            follow_download(*arguments)
        elif args.fetch_pages:
            fetch_pages(*arguments)
        else:
            request_one(*arguments)
        return 0
    except TransportError as exc:
        print(f"ci-hosted-transport: {exc.code}: {exc}", file=__import__("sys").stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(_cli())
