#!/usr/bin/env python3
"""Prepare and publish a bounded, unsigned Git object graph through measured HTTPS."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
TRANSPORT = ROOT / "scripts/ci/ci-hosted-transport.py"
REPO = "szTheory/sigra"
BODY_LIMIT = 2 * 1024 * 1024
REQUEST_LIMIT = 24
PUBLISH_SCHEMA = "sigra.phase253.git-publication/v1"
CONFIG_SHA = "8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d"
CONFIG_REF = "refs/gsd/phase253-recovery-execution-unrelated-config"
CONFIG_STATUS = b" M .planning/config.json\0"
FIXTURE = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml"
DOCS_PATH = "guides/reference/phase253-docs-only-proof.md"


class PublicationError(Exception):
    pass


def git(repo: Path, *args: str, data: bytes | None = None) -> bytes:
    result = subprocess.run(["git", "-C", str(repo), *args], input=data, capture_output=True)
    if result.returncode:
        raise PublicationError(f"git {args[0]} failed: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout


def json_bytes(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8", "strict")


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(json.dumps(value, sort_keys=True, ensure_ascii=False, indent=2).encode("utf-8") + b"\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def object_sha(kind: str, data: bytes) -> str:
    return hashlib.sha1(f"{kind} {len(data)}\0".encode() + data).hexdigest()


def tree_entries(repo: Path, commit: str) -> dict[str, dict]:
    raw = git(repo, "ls-tree", "-rz", "-r", commit)
    result = {}
    for row in raw.split(b"\0"):
        if not row:
            continue
        meta, path = row.split(b"\t", 1)
        mode, kind, sha = meta.decode("ascii").split()
        name = path.decode("utf-8", "strict")
        result[name] = {"path": name, "mode": mode, "type": kind, "sha": sha}
    return result


def commit_tree(repo: Path, entries: dict[str, dict]) -> str:
    def build(prefix: str) -> str:
        direct: dict[str, dict] = {}
        dirs: set[str] = set()
        for path, entry in entries.items():
            if not path.startswith(prefix):
                continue
            remainder = path[len(prefix):]
            if "/" in remainder:
                dirs.add(remainder.split("/", 1)[0])
            else:
                direct[remainder] = entry
        rows = []
        for name, entry in direct.items():
            rows.append(f"{entry['mode']} {entry['type']} {entry['sha']}\t{name}\0".encode())
        for name in dirs:
            sha = build(prefix + name + "/")
            rows.append(f"040000 tree {sha}\t{name}\0".encode())
        return git(repo, "mktree", "-z", data=b"".join(rows)).decode().strip()
    return build("")


def clean_source(repo: Path) -> dict:
    product_status = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--", ".", ":(exclude).planning/**")
    config_status = git(repo, "status", "--porcelain=v1", "-z", "--", ".planning/config.json")
    config = repo / ".planning/config.json"
    config_sha = hashlib.sha256(config.read_bytes()).hexdigest() if config.exists() else None
    config_blob = None
    if config_status:
        preserved_ref = subprocess.run(["git", "-C", str(repo), "show-ref", "--verify", "--hash", CONFIG_REF],
                                       capture_output=True, check=False)
        config_blob = preserved_ref.stdout.decode().strip() if preserved_ref.returncode == 0 else None
    preserved = False
    if config_status == CONFIG_STATUS and config_sha == CONFIG_SHA and config_blob:
        prior = git(repo, "show", CONFIG_REF)
        preserved = hashlib.sha256(prior).hexdigest() == CONFIG_SHA
    if product_status or (config_status and not preserved):
        raise PublicationError("source working tree is dirty outside the exact preserved config bytes/status exception")
    return {"product_status_hex": product_status.hex(),
            "config_status_hex": config_status.hex(), "config_sha256": config_sha,
            "config_ref": CONFIG_REF if preserved else None,
            "clean": not product_status and (not config_status or preserved)}


def make_commit(repo: Path, tree: str, parent: str, message: str, when: str) -> str:
    if not message.endswith("\n") or "\x00" in message:
        raise PublicationError("commit message must be UTF-8 text terminated by exactly a newline")
    dt = datetime.strptime(when, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    epoch = int(dt.timestamp())
    author = "Sigra Publication Bot <sigra-publication@users.noreply.github.com>"
    raw = (f"tree {tree}\nparent {parent}\nauthor {author} {epoch} +0000\n"
           f"committer {author} {epoch} +0000\n\n{message}").encode("utf-8")
    sha = git(repo, "hash-object", "-w", "-t", "commit", "--stdin", data=raw).decode().strip()
    parsed = git(repo, "cat-file", "commit", sha)
    if parsed != raw or b"gpgsig " in parsed or b"mergetag " in parsed:
        raise PublicationError("canonical unsigned commit read-back differed")
    return sha


def changed_paths(parent: dict[str, dict], target: dict[str, dict], repo: Path) -> tuple[list[dict], int]:
    entries = []
    binary = 0
    for path in sorted(parent.keys() | target.keys()):
        old, new = parent.get(path), target.get(path)
        if old == new:
            continue
        if new is None:
            entries.append({"path": path, "mode": old["mode"], "type": "blob", "sha": None})
            continue
        data = git(repo, "cat-file", "blob", new["sha"])
        try:
            text = data.decode("utf-8", "strict")
        except UnicodeDecodeError:
            binary += 1
            entries.append({"path": path, "mode": new["mode"], "type": "blob", "sha": new["sha"], "binary_upload": True})
            continue
        if "\x00" in text:
            binary += 1
            entries.append({"path": path, "mode": new["mode"], "type": "blob", "sha": new["sha"], "binary_upload": True})
        else:
            entries.append({"path": path, "mode": new["mode"], "type": "blob", "content": text})
    return entries, binary


def tree_body(repo: Path, base_tree: str, base: dict[str, dict], target: dict[str, dict]) -> tuple[dict, int, int]:
    entries, binary = changed_paths(base, target, repo)
    wire_entries = []
    for entry in entries:
        if entry.get("binary_upload"):
            wire_entries.append({k: v for k, v in entry.items() if k != "binary_upload"})
        else:
            wire_entries.append(entry)
    body = {"base_tree": base_tree, "tree": wire_entries}
    encoded = json_bytes(body)
    return body, binary, len(encoded)


def pack_tree_requests(repo: Path, name: str, base_tree: str, base: dict[str, dict],
                       target: dict[str, dict]) -> tuple[list[dict], int]:
    """Pack sorted changed entries into a deterministic chain of bounded tree writes."""
    entries, binary_total = changed_paths(base, target, repo)
    groups: list[list[dict]] = []
    current: list[dict] = []
    for entry in entries:
        candidate = current + [entry]
        candidate_body = {"base_tree": base_tree, "tree": [
            {key: value for key, value in item.items() if key != "binary_upload"} for item in candidate
        ]}
        if len(json_bytes(candidate_body)) > BODY_LIMIT and current:
            groups.append(current)
            current = [entry]
        else:
            current = candidate
    if current or not groups:
        groups.append(current)

    working = dict(base)
    chain_base = base_tree
    requests = []
    for index, group in enumerate(groups, 1):
        wire_entries = [{key: value for key, value in item.items() if key != "binary_upload"} for item in group]
        body = {"base_tree": chain_base, "tree": wire_entries}
        body_size = len(json_bytes(body))
        for item in group:
            path = item["path"]
            if item.get("sha") is None and "content" not in item:
                working.pop(path, None)
            else:
                sha = item.get("sha") or object_sha("blob", item["content"].encode("utf-8", "strict"))
                working[path] = {"path": path, "mode": item["mode"], "type": "blob", "sha": sha}
        tree_sha = commit_tree(repo, working)
        request_name = name if len(groups) == 1 else f"{name}-part-{index:02d}"
        requests.append({"name": request_name, "variant": name, "sequence": index,
                         "base_tree_sha": chain_base, "tree_sha": tree_sha, "body": body,
                         "body_bytes": body_size,
                         "binary_blobs": sum(1 for item in group if item.get("binary_upload")),
                         "changed_entries": len(group)})
        chain_base = tree_sha
    return requests, binary_total


def source_variants(repo: Path, source: str, parent: str, frozen_date: str | None = None) -> dict:
    if not re.fullmatch(r"[a-f0-9]{40}", source) or not re.fullmatch(r"[a-f0-9]{40}", parent):
        raise PublicationError("source and server parent must be full lowercase commit SHAs")
    if git(repo, "cat-file", "-t", source).strip() != b"commit" or git(repo, "cat-file", "-t", parent).strip() != b"commit":
        raise PublicationError("candidate source and server parent must resolve to commits")
    current_head = git(repo, "rev-parse", "HEAD").decode().strip()
    if current_head != source:
        raise PublicationError("candidate source must be the current source HEAD; branch movement or stale source is not allowed")
    cleanliness = clean_source(repo)
    source_tree = git(repo, "rev-parse", f"{source}^{{tree}}").decode().strip()
    parent_tree = git(repo, "rev-parse", f"{parent}^{{tree}}").decode().strip()
    source_files, parent_files = tree_entries(repo, source), tree_entries(repo, parent)
    merged = {path: entry for path, entry in source_files.items() if not path.startswith(".planning/")}
    merged.update({path: entry for path, entry in parent_files.items() if path.startswith(".planning/")})
    candidate_tree = commit_tree(repo, merged)
    now = frozen_date or datetime.now(timezone.utc).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")
    candidate_message = "Phase 253 frozen CI candidate\n"
    candidate = make_commit(repo, candidate_tree, parent, candidate_message, now)
    fixture_content = FIXTURE.read_bytes()
    fixture_path = ".github/workflows/phase-253-gate-canary.yml"
    fixture_entries = dict(merged)
    fixture_blob = git(repo, "hash-object", "-w", "--stdin", data=fixture_content).decode().strip()
    fixture_entries[fixture_path] = {"path": fixture_path, "mode": "100644", "type": "blob", "sha": fixture_blob}
    fixture_tree = commit_tree(repo, fixture_entries)
    fixture_commit = make_commit(repo, fixture_tree, candidate, "Phase 253 isolated gate canary fixture\n", now)
    ci_path = ".github/workflows/ci.yml"
    ci_data = git(repo, "cat-file", "blob", merged[ci_path]["sha"])
    old_trigger = b"  pull_request:\n    branches: [main]\n"
    new_trigger = b"  pull_request:\n    branches: [main, gsd/253-replan-docs-*]\n"
    if ci_data.count(old_trigger) != 1:
        raise PublicationError("docs base cannot isolate the single CI pull_request branch-filter line")
    docs_base_entries = dict(merged)
    docs_base_ci = ci_data.replace(old_trigger, new_trigger, 1)
    docs_base_blob = git(repo, "hash-object", "-w", "--stdin", data=docs_base_ci).decode().strip()
    docs_base_entries[ci_path] = {"path": ci_path, "mode": merged[ci_path]["mode"], "type": "blob", "sha": docs_base_blob}
    docs_base_tree = commit_tree(repo, docs_base_entries)
    docs_base_commit = make_commit(repo, docs_base_tree, candidate, "Phase 253 docs probe base workflow exception\n", now)
    docs_entries = dict(docs_base_entries)
    docs_bytes = ("# Phase 253 docs-only CI probe\n\nThis one-file change checks the reviewed docs-only trigger path.\n").encode()
    docs_blob = git(repo, "hash-object", "-w", "--stdin", data=docs_bytes).decode().strip()
    docs_entries[DOCS_PATH] = {"path": DOCS_PATH, "mode": "100644", "type": "blob", "sha": docs_blob}
    docs_tree = commit_tree(repo, docs_entries)
    docs_commit = make_commit(repo, docs_tree, docs_base_commit, "Phase 253 docs-only probe head\n", now)
    candidate_requests, parent_binary = pack_tree_requests(repo, "candidate", parent_tree, parent_files, merged)
    fixture_requests, fixture_binary = pack_tree_requests(repo, "fixture", candidate_tree, merged, fixture_entries)
    tree_requests = candidate_requests + fixture_requests
    docs_base_changes, docs_base_binary, docs_base_body = tree_body(repo, candidate_tree, merged, docs_base_entries)
    docs_head_changes, docs_head_binary, docs_head_body = tree_body(repo, docs_base_tree, docs_base_entries, docs_entries)
    fixture_changes, _, _ = tree_body(repo, candidate_tree, merged, fixture_entries)
    if [item["path"] for item in fixture_changes["tree"]] != [fixture_path]:
        raise PublicationError("fixture commit must change exactly the frozen canary workflow file")
    if [item["path"] for item in docs_base_changes["tree"]] != [ci_path] or [item["path"] for item in docs_head_changes["tree"]] != [DOCS_PATH]:
        raise PublicationError("docs probe variants must change only the branch filter, then exactly one guide file")
    product_paths_source = {p: e for p, e in source_files.items() if not p.startswith(".planning/")}
    product_paths_candidate = {p: e for p, e in merged.items() if not p.startswith(".planning/")}
    source_product_tree = commit_tree(repo, product_paths_source)
    candidate_product_tree = commit_tree(repo, product_paths_candidate)
    parity = {"source_product_tree": source_product_tree, "parent_product_tree": parent_tree,
              "source_product_files": len(product_paths_source), "candidate_product_files": len(product_paths_candidate),
              "candidate_product_tree": candidate_product_tree,
              "same_paths_modes_blobs": product_paths_source == product_paths_candidate and source_product_tree == candidate_product_tree}
    largest = max(item["body_bytes"] for item in tree_requests)
    total = 1 + parent_binary + fixture_binary + 12 + len(tree_requests)
    reasons = []
    if not parity["same_paths_modes_blobs"]:
        reasons.append("candidate product tree differs from candidate source")
    if parent_binary + fixture_binary > 10:
        reasons.append("binary blob count exceeds the frozen limit of ten")
    if any(item["body_bytes"] > BODY_LIMIT for item in tree_requests):
        reasons.append("a single complete tree entry exceeds the 2 MiB serialized tree body limit")
    if total > REQUEST_LIMIT:
        reasons.append("parent preflight plus object/ref calls exceed the 24-request publication allocation")
    status = "blocked" if reasons else "ready-local-proposal"
    return {"schema_version": PUBLISH_SCHEMA, "status": status, "source_sha": source,
            "server_parent_sha": parent, "parent_tree_sha": parent_tree,
            "candidate_source_commit": source, "candidate_helper_commit": candidate,
            "fixture_workflow_commit": fixture_commit, "fixture_workflow_blob": fixture_blob,
            "fixture_tree_sha": fixture_tree,
            "docs_base_commit": docs_base_commit, "docs_head_commit": docs_commit,
            "docs_head_path": DOCS_PATH, "workflow_path": fixture_path,
            "commit_metadata": {"author": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
                                "committer": "Sigra Publication Bot", "date_utc_second": now,
                                "message_newline_terminated": True, "unsigned": True},
            "product_tree_parity": parity, "source_cleanliness": cleanliness,
            "candidate_tree_sha": candidate_tree,
            "tree_requests": [{key: item[key] for key in ("name", "variant", "sequence", "base_tree_sha", "tree_sha", "body_bytes", "binary_blobs", "changed_entries")}
                              for item in tree_requests],
            "docs_variants_local_only": [{"name": "docs-base", "body_bytes": docs_base_body, "binary_blobs": docs_base_binary,
                                           "changed_paths": [item["path"] for item in docs_base_changes["tree"]]},
                                          {"name": "docs-head", "body_bytes": docs_head_body, "binary_blobs": docs_head_binary,
                                           "changed_paths": [item["path"] for item in docs_head_changes["tree"]]}],
            "server_parent_availability": "proposal-only; fresh availability must be proved in the authorized publication window",
            "projection": {"parent_preflight_requests": 1, "fixed_non_tree_requests": 12,
                           "tree_request_count": len(tree_requests),
                           "binary_blob_requests": parent_binary + fixture_binary, "projected_total_requests": total,
                           "max_requests": REQUEST_LIMIT, "largest_tree_body_bytes": largest,
                           "max_tree_body_bytes": BODY_LIMIT, "complete_product_delta_dropped": False},
            "blockers": reasons, "server_object_receipts": [], "source_git_status": cleanliness["product_status_hex"],
            "_candidate_entries": merged, "_fixture_entries": fixture_entries}


def validate_manifest(value: object) -> dict:
    if not isinstance(value, dict) or value.get("schema_version") != PUBLISH_SCHEMA:
        raise PublicationError("manifest schema is not recognized")
    for field in ("source_sha", "server_parent_sha", "candidate_helper_commit", "fixture_workflow_commit",
                  "fixture_workflow_blob", "candidate_tree_sha", "fixture_tree_sha"):
        if not isinstance(value.get(field), str) or not re.fullmatch(r"[a-f0-9]{40}", value[field]):
            raise PublicationError(f"manifest {field} must be a full lowercase Git object SHA")
    if value.get("status") not in {"blocked", "ready-local-proposal"} or not isinstance(value.get("tree_requests"), list):
        raise PublicationError("manifest status or tree request table is invalid")
    projection = value.get("projection")
    if (not isinstance(projection, dict) or projection.get("max_requests") != REQUEST_LIMIT
            or projection.get("complete_product_delta_dropped") is not False
            or not isinstance(projection.get("projected_total_requests"), int)
            or (projection["projected_total_requests"] > REQUEST_LIMIT and value.get("status") != "blocked")):
        raise PublicationError("manifest projection is fake, incomplete, or over budget")
    integer_fields = ("parent_preflight_requests", "fixed_non_tree_requests", "tree_request_count",
                      "binary_blob_requests", "projected_total_requests", "largest_tree_body_bytes", "max_tree_body_bytes")
    if any(isinstance(projection.get(field), bool) or not isinstance(projection.get(field), int) or projection[field] < 0
           for field in integer_fields):
        raise PublicationError("manifest projection has missing or invalid numeric fields")
    if (projection["parent_preflight_requests"] != 1 or projection["fixed_non_tree_requests"] != 12
            or projection["tree_request_count"] != len(value["tree_requests"])
            or projection["max_tree_body_bytes"] != BODY_LIMIT
            or projection["projected_total_requests"] != 1 + 12 + projection["tree_request_count"] + projection["binary_blob_requests"]):
        raise PublicationError("manifest projection does not account for every parent, object, workflow, and ref request")
    if not value["tree_requests"] or any(not isinstance(item, dict) for item in value["tree_requests"]):
        raise PublicationError("manifest must declare an ordered candidate and fixture tree request chain")
    binary_total = 0
    if any(not isinstance(item, dict) or not isinstance(item.get("body_bytes"), int)
           or item["body_bytes"] > BODY_LIMIT for item in value["tree_requests"]):
        if value.get("status") != "blocked":
            raise PublicationError("manifest claims readiness with an over-budget tree request")
    chain_base = value.get("parent_tree_sha")
    prior_variant = "candidate"
    sequence = 0
    candidate_final = None
    fixture_started = False
    for item in value["tree_requests"]:
        variant = item.get("variant")
        if variant not in {"candidate", "fixture"} or (fixture_started and variant != "fixture"):
            raise PublicationError("tree chain variants must contain candidate requests before fixture requests")
        if variant != prior_variant:
            if prior_variant == "candidate":
                candidate_final = chain_base
                chain_base = value.get("candidate_tree_sha")
                fixture_started = True
            prior_variant = variant
            sequence = 0
        if (item.get("sequence") != sequence + 1 or item.get("base_tree_sha") != chain_base
                or not re.fullmatch(r"[a-f0-9]{40}", str(item.get("tree_sha", "")))):
            raise PublicationError("tree chain has a broken base, sequence, or native tree SHA")
        sequence += 1
        chain_base = item["tree_sha"]
        if not isinstance(item.get("name"), str) or not item["name"]:
            raise PublicationError("tree chain request name is invalid")
        for field in ("body_bytes", "binary_blobs", "changed_entries"):
            if isinstance(item.get(field), bool) or not isinstance(item.get(field), int) or item[field] < 0:
                raise PublicationError("manifest tree request has invalid counts")
        binary_total += item["binary_blobs"]
    if not fixture_started:
        candidate_final = chain_base
    if (candidate_final != value.get("candidate_tree_sha")
            or value["tree_requests"][-1].get("variant") != "fixture"
            or value["tree_requests"][-1].get("tree_sha") != value.get("fixture_tree_sha")):
        raise PublicationError("tree chain does not end at the exact candidate and fixture commit trees")
    if binary_total != projection["binary_blob_requests"] or binary_total > 10:
        raise PublicationError("manifest binary blob count differs from its request projection")
    if projection["largest_tree_body_bytes"] != max(item["body_bytes"] for item in value["tree_requests"]):
        raise PublicationError("manifest largest tree body does not match its complete tree requests")
    parity = value.get("product_tree_parity")
    if not isinstance(parity, dict) or parity.get("same_paths_modes_blobs") is not True:
        raise PublicationError("manifest does not prove exact product-tree parity")
    if not value.get("source_cleanliness", {}).get("clean"):
        raise PublicationError("manifest source cleanliness does not pass the exact status/config rule")
    if value.get("status") == "blocked" and not value.get("blockers"):
        raise PublicationError("blocked manifest has no explicit blocker")
    if value.get("status") == "ready-local-proposal" and value.get("blockers"):
        raise PublicationError("ready manifest still declares blockers")
    return value


def transport_call(allocation: Path, ledger: Path, request: dict) -> tuple[dict, bytes]:
    with tempfile.TemporaryDirectory(prefix="sigra-git-object-request-") as tmp:
        request_path = Path(tmp) / "request.json"
        receipt_path = Path(tmp) / "receipt.json"
        body_path = Path(tmp) / "response.body"
        request_path.write_bytes(json_bytes(request))
        result = subprocess.run([sys.executable, str(TRANSPORT), "--allocation", str(allocation), "--ledger", str(ledger),
                                 "--request", str(request_path), "--output", str(receipt_path), "--body-output", str(body_path)],
                                cwd=ROOT, capture_output=True, text=True)
        if not receipt_path.exists():
            raise PublicationError(f"measured transport stopped before a durable receipt: {result.stderr.strip()}")
        receipt = json.loads(receipt_path.read_text())
        if result.returncode:
            raise PublicationError(f"measured request failed after being charged: {receipt.get('error') or result.stderr.strip()}")
        return receipt, body_path.read_bytes() if body_path.exists() else b""


def api_request(allocation: Path, ledger: Path, route: str, method: str, params: dict | None = None,
                body: dict | None = None, expected: set[int] | None = None) -> tuple[dict, dict | None]:
    request = {"route_id": route, "method": method}
    if params is not None:
        request["params"] = params
    if body is not None:
        request["body"] = body
    receipt, raw = transport_call(allocation, ledger, request)
    status = receipt.get("actual_status")
    if expected is not None and status not in expected:
        raise PublicationError(f"{route} returned HTTP {status}; expected {sorted(expected)}")
    try:
        decoded = json.loads(raw) if raw else None
    except (ValueError, UnicodeDecodeError) as exc:
        raise PublicationError(f"{route} response was not JSON") from exc
    return receipt, decoded


def publish(manifest_path: Path, allocation_path: Path, ledger_path: Path, receipt_path: Path,
            repo: Path | None = None) -> None:
    manifest = validate_manifest(json.loads(manifest_path.read_text()))
    if manifest["status"] != "ready-local-proposal":
        raise PublicationError("publication blocked: local complete product delta or request allocation does not fit")
    allocation = json.loads(allocation_path.read_text())
    if allocation.get("max_requests") != REQUEST_LIMIT or allocation.get("repository", REPO) != REPO:
        raise PublicationError("allocation must reserve exactly 24 requests for szTheory/sigra")
    if allocation.get("source_sha256") != hashlib.sha256(manifest_path.read_bytes()).hexdigest():
        raise PublicationError("allocation source digest does not bind this exact frozen manifest")
    repo = repo or Path(git(ROOT, "rev-parse", "--show-toplevel").decode().strip())
    parent = manifest["server_parent_sha"]
    local_parent_tree = git(repo, "rev-parse", f"{parent}^{{tree}}").decode().strip()
    variants = source_variants(repo, manifest["source_sha"], parent,
                               manifest["commit_metadata"]["date_utc_second"])
    for field in ("candidate_helper_commit", "fixture_workflow_commit", "fixture_workflow_blob",
                  "candidate_tree_sha", "fixture_tree_sha", "docs_base_commit", "docs_head_commit"):
        if variants[field] != manifest[field]:
            raise PublicationError(f"local {field} changed since manifest preparation")
    prepared = []
    total_binary = 0
    for label, commit_sha, target_entries, parent_sha, base_tree, ref_name in [
        ("candidate", manifest["candidate_helper_commit"], variants["_candidate_entries"], parent,
         local_parent_tree, "gsd/253-replan-candidate"),
        ("fixture", manifest["fixture_workflow_commit"], variants["_fixture_entries"], manifest["candidate_helper_commit"],
         git(repo, "rev-parse", f"{manifest['candidate_helper_commit']}^{{tree}}").decode().strip(),
         "gsd/253-replan-fixture"),
    ]:
        tree_sha = git(repo, "rev-parse", f"{commit_sha}^{{tree}}").decode().strip()
        chunks, binary_count = pack_tree_requests(repo, label, base_tree,
                                                  tree_entries(repo, parent_sha), target_entries)
        if not chunks or chunks[-1]["tree_sha"] != tree_sha:
            raise PublicationError(f"{label} packed tree chain does not reconstruct its exact final tree")
        if binary_count > 10:
            raise PublicationError("binary blob count exceeds ten")
        declared = [row for row in manifest["tree_requests"] if row.get("variant") == label]
        if len(declared) != len(chunks) or any(
                any(declared[index].get(field) != chunks[index][field]
                    for field in ("name", "sequence", "base_tree_sha", "tree_sha", "body_bytes", "binary_blobs", "changed_entries"))
                for index in range(len(chunks))):
            raise PublicationError(f"{label} tree chain changed since manifest preparation")
        total_binary += binary_count
        prepared.append((label, commit_sha, tree_sha, chunks, parent_sha, ref_name))
    actual_projection = 1 + 12 + len(manifest["tree_requests"]) + total_binary
    if actual_projection > REQUEST_LIMIT or actual_projection != manifest["projection"]["projected_total_requests"]:
        raise PublicationError("complete preflight request projection no longer fits the frozen 24-request allocation")
    receipts = []
    ref_jobs = []
    _, parent_data = api_request(allocation_path, ledger_path, "git_get_commit", "GET", {"sha": parent}, expected={200})
    if (not parent_data or parent_data.get("sha") != parent
            or parent_data.get("tree", {}).get("sha") != local_parent_tree):
        raise PublicationError("fresh server parent readback did not match the frozen parent SHA")
    receipts.append({"kind": "parent-preflight", "sha": parent, "tree": parent_data.get("tree", {}).get("sha")})
    for label, commit_sha, tree_sha, chunks, parent_sha, ref_name in prepared:
        for chunk in chunks:
            body = chunk["body"]
            for item in body["tree"]:
                if item.get("sha") and not item.get("content"):
                    blob_data = git(repo, "cat-file", "blob", item["sha"])
                    blob_body = {"content": base64.b64encode(blob_data).decode(), "encoding": "base64"}
                    _, response = api_request(allocation_path, ledger_path, "git_create_blob", "POST", body=blob_body, expected={201})
                    if response.get("sha") != item["sha"]:
                        raise PublicationError("server returned a different binary blob SHA")
                    receipts.append({"kind": "blob", "sha": response["sha"], "path": item["path"]})
            _, tree_response = api_request(allocation_path, ledger_path, "git_create_tree", "POST", body=body, expected={201})
            if not tree_response or tree_response.get("sha") != chunk["tree_sha"]:
                raise PublicationError(f"server tree identity differs for {chunk['name']}")
            variant_name = label if chunk is chunks[-1] else chunk["name"]
            receipts.append({"kind": "tree", "sha": chunk["tree_sha"], "variant": variant_name,
                             "base_tree": chunk["base_tree_sha"], "sequence": chunk["sequence"]})
        author = {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
                  "date": manifest["commit_metadata"]["date_utc_second"]}
        message = "Phase 253 frozen CI candidate\n" if label == "candidate" else "Phase 253 isolated gate canary fixture\n"
        commit_body = {"message": message, "tree": tree_sha, "parents": [parent_sha], "author": author, "committer": author}
        _, commit_response = api_request(allocation_path, ledger_path, "git_create_commit", "POST", body=commit_body, expected={201})
        if not commit_response or commit_response.get("sha") != commit_sha:
            raise PublicationError(f"server commit identity differs for {label}")
        _, readback = api_request(allocation_path, ledger_path, "git_get_commit", "GET", {"sha": commit_sha}, expected={200})
        if (not readback or readback.get("sha") != commit_sha or readback.get("tree", {}).get("sha") != tree_sha
                or [p.get("sha") for p in readback.get("parents", [])] != [parent_sha]
                or readback.get("message") != message or readback.get("author") != author or readback.get("committer") != author):
            raise PublicationError(f"server commit readback differs for {label}")
        receipts.append({"kind": "commit", "sha": commit_sha, "tree": tree_sha, "variant": label,
                         "parent": parent_sha, "message": message})
        workflow_blob = manifest["fixture_workflow_blob"] if label == "fixture" else git(repo, "rev-parse", f"{commit_sha}:.github/workflows/ci.yml").decode().strip()
        _, workflow_readback = api_request(allocation_path, ledger_path, "git_get_blob", "GET", {"sha": workflow_blob}, expected={200})
        try:
            workflow_bytes = base64.b64decode(workflow_readback.get("content", ""), validate=False) if workflow_readback else b""
        except (ValueError, TypeError):
            workflow_bytes = b""
        expected_workflow = git(repo, "cat-file", "blob", workflow_blob)
        if (not workflow_readback or workflow_readback.get("sha") != workflow_blob
                or workflow_readback.get("size") != len(expected_workflow) or workflow_bytes != expected_workflow
                or object_sha("blob", workflow_bytes) != workflow_blob):
            raise PublicationError(f"server workflow blob readback differs for {label}")
        receipts.append({"kind": "workflow-blob", "sha": workflow_blob, "commit": commit_sha, "variant": label})
        ref_jobs.append((label, commit_sha, tree_sha, ref_name, workflow_blob))
    for label, commit_sha, tree_sha, ref_name, workflow_blob in ref_jobs:
        ref_body = {"ref": "refs/heads/" + ref_name, "sha": commit_sha}
        ref_probe, existing = api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={200, 404})
        if ref_probe.get("actual_status") == 200:
            if existing.get("object", {}).get("sha") != commit_sha:
                raise PublicationError(f"scoped ref {ref_name} already points to a different commit")
            prior = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
            if (prior.get("manifest_sha256") != hashlib.sha256(manifest_path.read_bytes()).hexdigest()
                    or prior.get("allocation_sha256") != hashlib.sha256(allocation_path.read_bytes()).hexdigest()
                    or not any(item.get("kind") == label and item.get("sha") == commit_sha
                               for item in prior.get("server_object_receipts", []) if isinstance(item, dict))):
                raise PublicationError("existing exact ref has no matching prior publication receipt")
        else:
            _, created = api_request(allocation_path, ledger_path, "create_ref", "POST", body=ref_body, expected={201})
            if not created or created.get("object", {}).get("sha") != commit_sha:
                raise PublicationError("create-only reference response did not match the frozen commit")
            _, readback_ref = api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={200})
            if not readback_ref or readback_ref.get("object", {}).get("sha") != commit_sha:
                raise PublicationError("scoped reference readback lost or changed the created commit")
        receipts.append({"kind": "ref", "sha": commit_sha, "tree": tree_sha, "ref": "refs/heads/" + ref_name,
                         "variant": label, "workflow_blob": workflow_blob})
    final_ledger = json.loads(ledger_path.read_text())
    journal_entries = final_ledger.get("transactions", [])
    if len(journal_entries) > REQUEST_LIMIT:
        raise PublicationError("measured transport ledger exceeded 24 requests")
    candidate_workflow_blob = git(repo, "rev-parse", f"{manifest['candidate_helper_commit']}:.github/workflows/ci.yml").decode().strip()
    candidate_tree_sha = git(repo, "rev-parse", f"{manifest['candidate_helper_commit']}^{{tree}}").decode().strip()
    fixture_tree_sha = git(repo, "rev-parse", f"{manifest['fixture_workflow_commit']}^{{tree}}").decode().strip()
    result = {"schema_version": "sigra.phase253.git-publication-receipt/v1", "status": "published-local-fixture",
              "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
              "allocation_sha256": hashlib.sha256(allocation_path.read_bytes()).hexdigest(),
              "ledger_sha256": hashlib.sha256(ledger_path.read_bytes()).hexdigest(),
              "ledger_path": str(ledger_path.resolve()),
              "request_count": len(journal_entries), "server_object_receipts": receipts,
              "source_sha": manifest["source_sha"], "server_parent_sha": parent,
              "candidate_sha": manifest["candidate_helper_commit"],
              "fixture_sha": manifest["fixture_workflow_commit"],
              "candidate_ref": "refs/heads/gsd/253-replan-candidate",
              "fixture_ref": "refs/heads/gsd/253-replan-fixture",
              "candidate_tree_sha": candidate_tree_sha, "fixture_tree_sha": fixture_tree_sha,
              "candidate_workflow_blob": candidate_workflow_blob,
              "fixture_workflow_blob": manifest["fixture_workflow_blob"],
              "production_publish_performed": False}
    atomic_json(receipt_path, result)


def verify_publication(path: Path) -> None:
    value = json.loads(path.read_text())
    if (not isinstance(value, dict) or value.get("schema_version") != "sigra.phase253.git-publication-receipt/v1"
            or value.get("status") != "published-local-fixture" or value.get("production_publish_performed") is not False
            or not isinstance(value.get("server_object_receipts"), list)):
        raise PublicationError("publication receipt is missing, incomplete, or claims live publication")
    for row in value["server_object_receipts"]:
        if not isinstance(row, dict) or not re.fullmatch(r"[a-f0-9]{40}", str(row.get("sha", ""))):
            raise PublicationError("publication receipt contains an invalid server object identity")
    identities = {(row.get("kind"), row.get("variant"), row.get("sha"), row.get("ref"))
                  for row in value["server_object_receipts"] if isinstance(row, dict)}
    required = {
        ("parent-preflight", None, value.get("server_parent_sha"), None),
        ("tree", "candidate", value.get("candidate_tree_sha"), None),
        ("tree", "fixture", value.get("fixture_tree_sha"), None),
        ("commit", "candidate", value.get("candidate_sha"), None),
        ("commit", "fixture", value.get("fixture_sha"), None),
        ("workflow-blob", "candidate", value.get("candidate_workflow_blob"), None),
        ("workflow-blob", "fixture", value.get("fixture_workflow_blob"), None),
        ("ref", "candidate", value.get("candidate_sha"), value.get("candidate_ref")),
        ("ref", "fixture", value.get("fixture_sha"), value.get("fixture_ref")),
    }
    if not all(item in identities for item in required):
        raise PublicationError(f"publication receipt is missing required parent, object, workflow, or scoped-ref proof: {sorted(required - identities, key=str)}")
    if (value.get("candidate_sha") == value.get("fixture_sha")
            or not re.fullmatch(r"[a-f0-9]{40}", str(value.get("source_sha", "")))
            or value.get("candidate_ref") != "refs/heads/gsd/253-replan-candidate"
            or value.get("fixture_ref") != "refs/heads/gsd/253-replan-fixture"):
        raise PublicationError("publication receipt identities or scoped refs are inconsistent")
    ledger_path = Path(value.get("ledger_path", ""))
    if not ledger_path.is_file() or hashlib.sha256(ledger_path.read_bytes()).hexdigest() != value.get("ledger_sha256"):
        raise PublicationError("publication receipt no longer matches its measured request ledger")
    ledger = json.loads(ledger_path.read_text())
    transactions = ledger.get("transactions") if isinstance(ledger, dict) else None
    if (not isinstance(transactions, list) or len(transactions) != value.get("request_count")
            or not isinstance(value.get("request_count"), int) or len(transactions) > REQUEST_LIMIT
            or any(not isinstance(tx, dict) or tx.get("state") != "complete" for tx in transactions)):
        raise PublicationError("publication ledger has unaccounted, failed, or over-budget requests")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--candidate-source")
    parser.add_argument("--server-parent")
    parser.add_argument("--output")
    parser.add_argument("--repo-root", help=argparse.SUPPRESS)
    parser.add_argument("--check-manifest")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--manifest")
    parser.add_argument("--allocation")
    parser.add_argument("--ledger")
    parser.add_argument("--receipt")
    parser.add_argument("--verify-publication")
    args = parser.parse_args()
    try:
        if args.prepare:
            if not (args.candidate_source and args.server_parent and args.output):
                raise PublicationError("--prepare requires candidate source, server parent, and output")
            proposal = source_variants(Path(args.repo_root).resolve() if args.repo_root else ROOT,
                                       args.candidate_source, args.server_parent)
            public = {key: value for key, value in proposal.items() if not key.startswith("_")}
            atomic_json(Path(args.output), public)
            print(json.dumps({"status": proposal["status"], "projected_requests": proposal["projection"]["projected_total_requests"],
                              "largest_tree_body_bytes": proposal["projection"]["largest_tree_body_bytes"],
                              "blockers": proposal["blockers"]}, sort_keys=True))
            return 0
        if args.check_manifest:
            manifest = validate_manifest(json.loads(Path(args.check_manifest).read_text()))
            print(json.dumps({"status": manifest["status"], "valid": True, "blockers": manifest.get("blockers", [])}, sort_keys=True))
            return 0
        if args.publish:
            if not all((args.manifest, args.allocation, args.ledger, args.receipt)):
                raise PublicationError("--publish requires manifest, allocation, ledger, and receipt paths")
            publish(Path(args.manifest), Path(args.allocation), Path(args.ledger), Path(args.receipt),
                    Path(args.repo_root).resolve() if args.repo_root else None)
            return 0
        if args.verify_publication:
            verify_publication(Path(args.verify_publication))
            print("publication receipt valid")
            return 0
        parser.error("choose --prepare, --check-manifest, --publish, or --verify-publication")
    except (PublicationError, OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"ci-git-publication: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
