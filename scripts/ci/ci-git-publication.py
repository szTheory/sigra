#!/usr/bin/env python3
"""Prepare and publish a bounded, unsigned Git object graph through measured HTTPS."""

from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

sys.dont_write_bytecode = True  # importing sibling helpers must never leave untracked bytecode in the frozen product tree
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
LEGACY_WORKFLOW_PATH = ".github/workflows/phase-253-gate-canary.yml"
REGISTERED_WORKFLOW_PATH = ".github/workflows/ci.yml"
API_HOST = "api.github.com"
RECEIPT_SCHEMA = "sigra.phase253.git-publication-receipt/v1"
APPROVAL_SCHEMA = "sigra.phase253.outward-action-approval/v1"
FREEZE_SCHEMA = "sigra.phase253.load-recovery-canary-freeze/v1"
SECTIONS = ("canary", "docs_and_prs")
CANARY_PUBLICATION_LIMIT = 24
DOCS_PUBLICATION_LIMIT = 14
CANARY_REQUEST_LIMIT = 117
PRODUCTION_REQUEST_LIMIT = 120
ACTUAL_STATUS = "published-actual-github"
HERMETIC_STATUS = "published-local-fixture"


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


def commit_message_matches(server_message, sent_message) -> bool:
    """True only for the sent message or the sent message minus exactly one trailing newline.

    GitHub's commit JSON drops one trailing newline from the stored message while the
    stored object (and its sha) keeps the newline-terminated bytes. Nothing else is tolerated.
    """
    if not isinstance(server_message, str) or not isinstance(sent_message, str):
        return False
    return server_message == sent_message or server_message + "\n" == sent_message


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


def resolve_fixture(repo: Path, fixture_file: str | None) -> tuple[str | None, Path]:
    """Return the repo-relative fixture path (None for the superseded default) and its absolute file."""
    if fixture_file is None:
        return None, FIXTURE
    candidate = PurePosixPath(fixture_file)
    if candidate.is_absolute() or ".." in candidate.parts or not candidate.parts:
        raise PublicationError("fixture file must be a repository-relative path without traversal")
    absolute = (repo / fixture_file).resolve()
    try:
        absolute.relative_to(repo.resolve())
    except ValueError as error:
        raise PublicationError("fixture file resolves outside the repository") from error
    if not absolute.is_file():
        raise PublicationError(f"fixture file does not exist: {fixture_file}")
    return fixture_file, absolute


def check_workflow_path(workflow_path: str) -> str:
    if not re.fullmatch(r"\.github/workflows/[A-Za-z0-9._-]+\.ya?ml", workflow_path or ""):
        raise PublicationError("fixture workflow path must be a single file under .github/workflows")
    return workflow_path


def source_variants(repo: Path, source: str, parent: str, frozen_date: str | None = None,
                    fixture_file: str | None = None, workflow_path: str | None = None,
                    allow_planning_descendant: bool = False) -> dict:
    if not re.fullmatch(r"[a-f0-9]{40}", source) or not re.fullmatch(r"[a-f0-9]{40}", parent):
        raise PublicationError("source and server parent must be full lowercase commit SHAs")
    if git(repo, "cat-file", "-t", source).strip() != b"commit" or git(repo, "cat-file", "-t", parent).strip() != b"commit":
        raise PublicationError("candidate source and server parent must resolve to commits")
    fixture_rel, fixture_abs = resolve_fixture(repo, fixture_file)
    fixture_path = check_workflow_path(workflow_path or LEGACY_WORKFLOW_PATH)
    if allow_planning_descendant:
        validate_frozen_product_source(repo, source)
    else:
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
    fixture_content = fixture_abs.read_bytes()
    fixture_entries = dict(merged)
    fixture_blob = git(repo, "hash-object", "-w", "--stdin", data=fixture_content).decode().strip()
    fixture_mode = merged[fixture_path]["mode"] if fixture_path in merged else "100644"
    fixture_entries[fixture_path] = {"path": fixture_path, "mode": fixture_mode, "type": "blob", "sha": fixture_blob}
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
            "fixture_file": {"path": fixture_rel, "sha256": hashlib.sha256(fixture_content).hexdigest()},
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
            "_candidate_entries": merged, "_fixture_entries": fixture_entries,
            "_docs_base_entries": docs_base_entries, "_docs_entries": docs_entries}


def validate_manifest(value: object) -> dict:
    if not isinstance(value, dict) or value.get("schema_version") != PUBLISH_SCHEMA:
        raise PublicationError("manifest schema is not recognized")
    for field in ("source_sha", "server_parent_sha", "candidate_helper_commit", "fixture_workflow_commit",
                  "fixture_workflow_blob", "candidate_tree_sha", "fixture_tree_sha"):
        if not isinstance(value.get(field), str) or not re.fullmatch(r"[a-f0-9]{40}", value[field]):
            raise PublicationError(f"manifest {field} must be a full lowercase Git object SHA")
    fixture_file = value.get("fixture_file")
    if fixture_file is not None and (not isinstance(fixture_file, dict) or set(fixture_file) != {"path", "sha256"}
                                      or not re.fullmatch(r"[a-f0-9]{64}", str(fixture_file.get("sha256", "")))
                                      or not (fixture_file["path"] is None or isinstance(fixture_file["path"], str))):
        raise PublicationError("manifest fixture file binding is malformed")
    if not re.fullmatch(r"\.github/workflows/[A-Za-z0-9._-]+\.ya?ml", str(value.get("workflow_path", ""))):
        raise PublicationError("manifest workflow path is not a single workflow file")
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


def canonical_bytes(value) -> bytes:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def product_status(repo: Path) -> bytes:
    return git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--", ".", ":(exclude).planning/**")


def product_tree_sha(repo: Path, commit: str) -> str:
    entries = {path: entry for path, entry in tree_entries(repo, commit).items() if not path.startswith(".planning/")}
    return commit_tree(repo, entries)


def validate_frozen_product_source(repo: Path, frozen_source: str, frozen_product_tree: str | None = None) -> dict:
    """The frozen source is an ancestor of HEAD, no product file is dirty, and the whole current product
    path/mode/blob tree equals the frozen one. Planning-only HEAD movement is the only movement allowed."""
    repo = Path(repo)
    if not re.fullmatch(r"[a-f0-9]{40}", str(frozen_source)):
        raise PublicationError("frozen source must be a full lowercase commit SHA")
    if subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{frozen_source}^{{commit}}"], capture_output=True).returncode:
        raise PublicationError("frozen source commit is not present in this repository")
    if subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", frozen_source, "HEAD"], capture_output=True).returncode:
        raise PublicationError("frozen source commit is not an ancestor of HEAD")
    if product_status(repo):
        raise PublicationError("product working tree has uncommitted dirt; the frozen product source is not what would be published")
    frozen_tree = product_tree_sha(repo, frozen_source)
    if frozen_product_tree is not None and frozen_tree != frozen_product_tree:
        raise PublicationError("frozen source product tree differs from the product tree recorded in the freeze")
    head = git(repo, "rev-parse", "HEAD").decode().strip()
    if product_tree_sha(repo, "HEAD") != frozen_tree:
        raise PublicationError("current product path/mode/blob tree differs from the frozen product source")
    return {"frozen_source": frozen_source, "head": head, "product_tree_sha": frozen_tree,
            "planning_only_movement": head != frozen_source}


validateFrozenProductSource = validate_frozen_product_source


# ---------------------------------------------------------------------------------- section approvals
def section_sha256(freeze: dict, section: str) -> str:
    if section not in SECTIONS:
        raise PublicationError(f"unknown outward-action section: {section}")
    actions = freeze.get("outward_actions")
    stated = freeze.get("outward_actions_sha256")
    if not isinstance(actions, dict) or not isinstance(actions.get(section), dict) or not isinstance(stated, dict):
        raise PublicationError("freeze has no enumerated outward_actions section")
    computed = sha256_hex(canonical_bytes(actions[section]))
    if stated.get(section) != computed:
        raise PublicationError(f"freeze section digest for {section} differs from its content")
    return computed


def load_freeze(path: Path) -> tuple[dict, bytes]:
    raw = Path(path).read_bytes()
    value = json.loads(raw)
    if not isinstance(value, dict) or value.get("schema_version") != FREEZE_SCHEMA:
        raise PublicationError("freeze schema is not recognized")
    return value, raw


def check_section_approval(approval_path: str | Path | None, freeze: dict, section: str, repo: Path) -> dict:
    """Shared rule for every live mode: the approval is tracked, present in HEAD, byte-equal to HEAD,
    decision approve, and bound to this exact section digest. Whole-manifest and wrong-section records fail."""
    if not approval_path:
        raise PublicationError(f"a committed {section} section approval is required (--action-approval)")
    expected = section_sha256(freeze, section)
    repo = Path(repo).resolve()
    path = Path(approval_path)
    path = (path if path.is_absolute() else Path.cwd() / path).resolve()
    try:
        rel = path.relative_to(repo).as_posix()
    except ValueError as error:
        raise PublicationError("approval record must live inside the repository") from error
    if not path.is_file():
        raise PublicationError("approval record does not exist")
    if subprocess.run(["git", "-C", str(repo), "ls-files", "--error-unmatch", "--", rel], capture_output=True).returncode:
        raise PublicationError("approval record is not tracked by git")
    in_head = subprocess.run(["git", "-C", str(repo), "show", f"HEAD:{rel}"], capture_output=True)
    if in_head.returncode:
        raise PublicationError("approval record is not committed in HEAD")
    raw = path.read_bytes()
    if in_head.stdout != raw:
        raise PublicationError("approval record differs from its committed HEAD bytes")
    try:
        record = json.loads(raw)
    except ValueError as error:
        raise PublicationError("approval record is not JSON") from error
    if not isinstance(record, dict) or record.get("schema_version") != APPROVAL_SCHEMA:
        raise PublicationError("approval record schema is not recognized")
    if record.get("decision") != "approve":
        raise PublicationError("approval record decision is not approve")
    if record.get("section") != section:
        raise PublicationError(f"approval record is bound to section {record.get('section')!r}, not {section}")
    if record.get("section_sha256") != expected:
        raise PublicationError(f"approval record digest is not the {section} section digest")
    commit = git(repo, "rev-list", "-1", "HEAD", "--", rel).decode().strip()
    return {"path": rel, "sha256": sha256_hex(raw), "section": section, "section_sha256": expected,
            "commit": commit, "window_wall_start_epoch": None}


def write_receipt_stub(receipt_path: Path, approval: dict, window_start: int | None = None) -> None:
    """Persist the approval record before the first request leaves the process. A window already recorded for
    the same approval is never moved; a caller-supplied start (the canary shell's) is recorded as given."""
    existing = {}
    if receipt_path.exists():
        try:
            existing = json.loads(receipt_path.read_text())
        except ValueError:
            existing = {}
    prior = existing.get("action_approval") if isinstance(existing.get("action_approval"), dict) else {}
    if prior.get("section_sha256") == approval.get("section_sha256") and isinstance(prior.get("window_wall_start_epoch"), int):
        if window_start is not None and window_start != prior["window_wall_start_epoch"]:
            raise PublicationError("the receipt's recorded window start differs from the caller's; the window is never moved")
        approval["window_wall_start_epoch"] = prior["window_wall_start_epoch"]
    else:
        approval["window_wall_start_epoch"] = window_start if window_start is not None else int(time.time())
    existing["action_approval"] = approval
    existing.setdefault("schema_version", RECEIPT_SCHEMA)
    existing.setdefault("status", "in-progress")
    atomic_json(receipt_path, existing)


# ------------------------------------------------------------------------------------ ledger origin
def ledger_identities(ledger: dict) -> set:
    found = set()
    for tx in ledger.get("transactions", []):
        if not isinstance(tx, dict) or tx.get("state") != "complete" or tx.get("actual_status") not in (200, 201):
            continue
        try:
            body = json.loads(base64.b64decode(tx.get("response_body_base64") or "", validate=True))
        except (ValueError, TypeError):
            continue
        if not isinstance(body, dict):
            continue
        route = tx.get("route_id")
        if route in ("git_get_commit", "git_create_commit") and isinstance(body.get("sha"), str):
            found.add(("commit", body["sha"], (body.get("tree") or {}).get("sha")))
        elif route == "git_create_tree" and isinstance(body.get("sha"), str):
            found.add(("tree", body["sha"]))
        elif route == "git_get_blob" and isinstance(body.get("sha"), str):
            found.add(("blob", body["sha"]))
        elif route in ("create_ref", "get_ref") and isinstance(body.get("ref"), str):
            found.add(("ref", body["ref"], (body.get("object") or {}).get("sha")))
    return found


def derive_origin(allocation: dict, ledger: dict) -> dict:
    """Label the publication. A live allocation whose every measured transaction went to api.github.com is
    actual-github; anything routed to a local test origin is hermetic and never acceptable as live proof."""
    transactions = ledger.get("transactions", [])
    hosts = sorted({str(tx.get("host")) for tx in transactions if isinstance(tx, dict)})
    if allocation.get("mode") == "live":
        if hosts != [API_HOST] or any(tx.get("state") != "complete" for tx in transactions):
            raise PublicationError("live allocation ledger contains a non-GitHub host or an incomplete transaction")
        return {"kind": "actual-github", "host": API_HOST, "allocation_mode": "live",
                "transactions": len(transactions), "identities_from_ledger": True}
    return {"kind": "hermetic", "allocation_mode": allocation.get("mode"), "hosts": hosts, "transactions": len(transactions)}


def required_identities(value: dict) -> set:
    required = {("commit", value.get("server_parent_sha"), None)}
    for label in ("candidate", "fixture"):
        tree = value.get(f"{label}_tree_sha")
        required.add(("tree", tree))
        required.add(("commit", value.get(f"{label}_sha"), tree))
        required.add(("blob", value.get(f"{label}_workflow_blob")))
        required.add(("ref", value.get(f"{label}_ref"), value.get(f"{label}_sha")))
    return required


def identity_present(found: set, wanted: tuple) -> bool:
    if wanted[0] == "commit" and wanted[2] is None:
        return any(item[0] == "commit" and item[1] == wanted[1] for item in found)
    return wanted in found


# The seven measured requests of one docs stage, in order: tree, commit, commit readback, blob readback,
# ref probe (404), create-only ref, ref readback. ci-pr-proof.sh recognizes a finished publication by this table.
DOCS_STAGE_ROUTES = ("git_create_tree", "git_create_commit", "git_get_commit", "git_get_blob", "get_ref", "create_ref", "get_ref")


def category_rows(ledger: dict, category: str) -> list:
    return [tx for tx in ledger.get("transactions", []) if isinstance(tx, dict) and tx.get("category") == category]


def category_count(ledger_path: Path, category: str) -> int:
    if not ledger_path.exists():
        return 0
    return sum(1 for tx in json.loads(ledger_path.read_text()).get("transactions", []) if tx.get("category") == category)


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


class Meter:
    """Predebits one request category against its frozen limit before every measured request."""

    def __init__(self, category: str | None, limit: int, ledger: Path):
        self.category, self.limit, self.ledger = category, limit, ledger

    def check(self) -> None:
        if self.category is None:
            return
        used = category_count(self.ledger, self.category)
        if used + 1 > self.limit:
            raise PublicationError(f"category {self.category} predebit would exceed {self.limit} requests (used {used})")


def api_request(allocation: Path, ledger: Path, route: str, method: str, params: dict | None = None,
                body: dict | None = None, expected: set[int] | None = None, meter: Meter | None = None) -> tuple[dict, dict | None]:
    request = {"route_id": route, "method": method}
    if meter is not None and meter.category is not None:
        meter.check()
        request["category"] = meter.category
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
            repo: Path | None = None, freeze_path: Path | None = None, approval_path: Path | None = None,
            window_start: int | None = None) -> None:
    manifest = validate_manifest(json.loads(manifest_path.read_text()))
    if manifest["status"] != "ready-local-proposal":
        raise PublicationError("publication blocked: local complete product delta or request allocation does not fit")
    allocation = json.loads(allocation_path.read_text())
    repo = repo or Path(git(ROOT, "rev-parse", "--show-toplevel").decode().strip())
    approval = None
    if freeze_path is None and allocation.get("mode") == "live":
        raise PublicationError("a live allocation requires the reviewed freeze and its committed canary section approval (--freeze)")
    if freeze_path is not None:
        freeze, freeze_raw = load_freeze(freeze_path)
        approval = check_section_approval(approval_path, freeze, "canary", repo)
        bound = (freeze.get("bound_documents") or {}).get("publication_manifest") or {}
        if bound.get("sha256") != sha256_hex(manifest_path.read_bytes()):
            raise PublicationError("manifest differs from the freeze's bound publication_manifest digest")
        limits = allocation.get("category_limits")
        if (allocation.get("repository", REPO) != REPO or allocation.get("allocation_kind", "canary") != "canary"
                or not isinstance(allocation.get("max_requests"), int) or allocation["max_requests"] > CANARY_REQUEST_LIMIT
                or allocation.get("source_sha256") != sha256_hex(freeze_raw)
                or (limits is not None and limits.get("publication") != CANARY_PUBLICATION_LIMIT)):
            raise PublicationError("allocation is not the canary allocation bound to this exact freeze (117 requests, publication 24)")
        meter = Meter("publication", CANARY_PUBLICATION_LIMIT, ledger_path)
    else:
        if allocation.get("max_requests") != REQUEST_LIMIT or allocation.get("repository", REPO) != REPO:
            raise PublicationError("allocation must reserve exactly 24 requests for szTheory/sigra")
        if allocation.get("source_sha256") != hashlib.sha256(manifest_path.read_bytes()).hexdigest():
            raise PublicationError("allocation source digest does not bind this exact frozen manifest")
        meter = Meter(None, REQUEST_LIMIT, ledger_path)
    parent = manifest["server_parent_sha"]
    local_parent_tree = git(repo, "rev-parse", f"{parent}^{{tree}}").decode().strip()
    fixture_binding = manifest.get("fixture_file") or {}
    variants = source_variants(repo, manifest["source_sha"], parent,
                               manifest["commit_metadata"]["date_utc_second"],
                               fixture_file=fixture_binding.get("path"), workflow_path=manifest["workflow_path"],
                               allow_planning_descendant=True)
    if variants["fixture_file"]["sha256"] != fixture_binding.get("sha256", variants["fixture_file"]["sha256"]):
        raise PublicationError("fixture file changed since manifest preparation")
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
    if approval is not None:
        write_receipt_stub(receipt_path, approval, window_start)
    receipts = []
    ref_jobs = []
    _, parent_data = api_request(allocation_path, ledger_path, "git_get_commit", "GET", {"sha": parent}, expected={200}, meter=meter)
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
                    _, response = api_request(allocation_path, ledger_path, "git_create_blob", "POST", body=blob_body, expected={201}, meter=meter)
                    if response.get("sha") != item["sha"]:
                        raise PublicationError("server returned a different binary blob SHA")
                    receipts.append({"kind": "blob", "sha": response["sha"], "path": item["path"]})
            _, tree_response = api_request(allocation_path, ledger_path, "git_create_tree", "POST", body=body, expected={201}, meter=meter)
            if not tree_response or tree_response.get("sha") != chunk["tree_sha"]:
                raise PublicationError(f"server tree identity differs for {chunk['name']}")
            variant_name = label if chunk is chunks[-1] else chunk["name"]
            receipts.append({"kind": "tree", "sha": chunk["tree_sha"], "variant": variant_name,
                             "base_tree": chunk["base_tree_sha"], "sequence": chunk["sequence"]})
        author = {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
                  "date": manifest["commit_metadata"]["date_utc_second"]}
        message = "Phase 253 frozen CI candidate\n" if label == "candidate" else "Phase 253 isolated gate canary fixture\n"
        commit_body = {"message": message, "tree": tree_sha, "parents": [parent_sha], "author": author, "committer": author}
        _, commit_response = api_request(allocation_path, ledger_path, "git_create_commit", "POST", body=commit_body, expected={201}, meter=meter)
        if not commit_response or commit_response.get("sha") != commit_sha:
            raise PublicationError(f"server commit identity differs for {label}")
        _, readback = api_request(allocation_path, ledger_path, "git_get_commit", "GET", {"sha": commit_sha}, expected={200}, meter=meter)
        if (not readback or readback.get("sha") != commit_sha or readback.get("tree", {}).get("sha") != tree_sha
                or [p.get("sha") for p in readback.get("parents", [])] != [parent_sha]
                or not commit_message_matches(readback.get("message"), message) or readback.get("author") != author or readback.get("committer") != author):
            raise PublicationError(f"server commit readback differs for {label}")
        server_message_form = "verbatim" if readback.get("message") == message else "trailing_newline_stripped"
        receipts.append({"kind": "commit", "sha": commit_sha, "tree": tree_sha, "variant": label,
                         "parent": parent_sha, "message": message, "server_message_form": server_message_form})
        workflow_blob = manifest["fixture_workflow_blob"] if label == "fixture" else git(
            repo, "rev-parse", f"{commit_sha}:.github/workflows/ci.yml").decode().strip()
        _, workflow_readback = api_request(allocation_path, ledger_path, "git_get_blob", "GET", {"sha": workflow_blob}, expected={200}, meter=meter)
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
        ref_probe, existing = api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={200, 404}, meter=meter)
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
            _, created = api_request(allocation_path, ledger_path, "create_ref", "POST", body=ref_body, expected={201}, meter=meter)
            if not created or created.get("object", {}).get("sha") != commit_sha:
                raise PublicationError("create-only reference response did not match the frozen commit")
            _, readback_ref = api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={200}, meter=meter)
            if not readback_ref or readback_ref.get("object", {}).get("sha") != commit_sha:
                raise PublicationError("scoped reference readback lost or changed the created commit")
        receipts.append({"kind": "ref", "sha": commit_sha, "tree": tree_sha, "ref": "refs/heads/" + ref_name,
                         "variant": label, "workflow_blob": workflow_blob})
    final_ledger = json.loads(ledger_path.read_text())
    journal_entries = final_ledger.get("transactions", [])
    own = [tx for tx in journal_entries if tx.get("category") == "publication"] if meter.category else journal_entries
    if len(own) > REQUEST_LIMIT:
        raise PublicationError("measured transport ledger exceeded 24 publication requests")
    candidate_workflow_blob = git(repo, "rev-parse", f"{manifest['candidate_helper_commit']}:.github/workflows/ci.yml").decode().strip()
    candidate_tree_sha = git(repo, "rev-parse", f"{manifest['candidate_helper_commit']}^{{tree}}").decode().strip()
    fixture_tree_sha = git(repo, "rev-parse", f"{manifest['fixture_workflow_commit']}^{{tree}}").decode().strip()
    origin = derive_origin(allocation, {"transactions": own})
    actual = origin["kind"] == "actual-github"
    result = {"schema_version": RECEIPT_SCHEMA, "status": ACTUAL_STATUS if actual else HERMETIC_STATUS,
              "origin": origin,
              "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
              "allocation_sha256": hashlib.sha256(allocation_path.read_bytes()).hexdigest(),
              "allocation_path": str(allocation_path.resolve()),
              "ledger_sha256": hashlib.sha256(ledger_path.read_bytes()).hexdigest(),
              "ledger_path": str(ledger_path.resolve()),
              "request_count": len(own),
              "publication_transactions": [{"sequence": tx["sequence"], "sha256": sha256_hex(canonical_bytes(tx))} for tx in own],
              "server_object_receipts": receipts,
              "source_sha": manifest["source_sha"], "server_parent_sha": parent,
              "candidate_sha": manifest["candidate_helper_commit"],
              "fixture_sha": manifest["fixture_workflow_commit"],
              "candidate_ref": "refs/heads/gsd/253-replan-candidate",
              "fixture_ref": "refs/heads/gsd/253-replan-fixture",
              "candidate_tree_sha": candidate_tree_sha, "fixture_tree_sha": fixture_tree_sha,
              "candidate_workflow_blob": candidate_workflow_blob,
              "fixture_workflow_blob": manifest["fixture_workflow_blob"],
              "production_publish_performed": actual}
    if approval is not None:
        result["action_approval"] = approval
    atomic_json(receipt_path, result)


def verify_publication(path: Path, require_live_origin: bool = False) -> None:
    value = json.loads(path.read_text())
    status = value.get("status") if isinstance(value, dict) else None
    origin = value.get("origin") if isinstance(value, dict) else None
    actual = status == ACTUAL_STATUS
    if (not isinstance(value, dict) or value.get("schema_version") != RECEIPT_SCHEMA
            or status not in (HERMETIC_STATUS, ACTUAL_STATUS) or value.get("production_publish_performed") is not actual
            or not isinstance(value.get("server_object_receipts"), list)):
        raise PublicationError("publication receipt is missing, incomplete, or claims live publication")
    if require_live_origin and not actual:
        raise PublicationError("hermetic or legacy local-fixture origin is rejected at live acceptance")
    if actual and (not isinstance(origin, dict) or origin.get("kind") != "actual-github"):
        raise PublicationError("actual-github publication receipt has no actual-github origin label")
    if not actual and isinstance(origin, dict) and origin.get("kind") == "actual-github":
        raise PublicationError("origin claims actual-github but the receipt status does not")
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
    if not ledger_path.is_file():
        raise PublicationError("publication receipt no longer matches its measured request ledger")
    ledger = json.loads(ledger_path.read_text())
    transactions = ledger.get("transactions") if isinstance(ledger, dict) else None
    pinned = value.get("publication_transactions")
    if pinned is None:
        # Legacy receipts pin the whole ledger file; they cannot survive later requests in the same ledger.
        if hashlib.sha256(ledger_path.read_bytes()).hexdigest() != value.get("ledger_sha256"):
            raise PublicationError("publication receipt no longer matches its measured request ledger")
        own = []
        if isinstance(transactions, list):
            legacy_rows = [tx for tx in transactions if tx.get("category") == "publication"]
            own = legacy_rows if legacy_rows else transactions
    else:
        if not isinstance(transactions, list) or not isinstance(pinned, list):
            raise PublicationError("publication ledger has unaccounted, failed, or over-budget requests")
        sequences = [item.get("sequence") for item in pinned if isinstance(item, dict)]
        if len(sequences) != len(pinned) or len(set(sequences)) != len(sequences):
            raise PublicationError("pinned publication transactions must be unique")
        by_sequence = {tx.get("sequence"): tx for tx in transactions if isinstance(tx, dict)}
        own = []
        for item in pinned:
            tx = by_sequence.get(item.get("sequence")) if isinstance(item, dict) else None
            if tx is None or sha256_hex(canonical_bytes(tx)) != item.get("sha256"):
                raise PublicationError("a pinned publication transaction no longer matches its measured request ledger")
            own.append(tx)
    if (not isinstance(transactions, list)
            or not isinstance(value.get("request_count"), int) or value["request_count"] > REQUEST_LIMIT
            or any(not isinstance(tx, dict) or tx.get("state") != "complete" for tx in own)
            or len(own) != value["request_count"]):
        raise PublicationError("publication ledger has unaccounted, failed, or over-budget requests")
    if actual:
        allocation_path = Path(value.get("allocation_path", ""))
        if (not allocation_path.is_file() or hashlib.sha256(allocation_path.read_bytes()).hexdigest() != value.get("allocation_sha256")
                or ledger.get("allocation_sha256") != value.get("allocation_sha256")):
            raise PublicationError("actual-github receipt is not bound to its allocation and ledger")
        allocation = json.loads(allocation_path.read_text())
        if allocation.get("mode") != "live" or {"test_origin", "test_ca_file"} & set(allocation):
            raise PublicationError("actual-github receipt is bound to a hermetic allocation")
        if derive_origin(allocation, {"transactions": own})["kind"] != "actual-github":
            raise PublicationError("actual-github ledger is not entirely api.github.com")
        found = ledger_identities({"transactions": own})
        missing = [item for item in sorted(required_identities(value), key=str) if not identity_present(found, item)]
        if missing:
            raise PublicationError(f"actual-github identities are not present in the measured server responses: {missing}")


def publish_docs(freeze_path: Path, allocation_path: Path, ledger_path: Path, receipt_path: Path,
                 repo: Path | None, approval_path: Path | None, window_start: int | None = None) -> None:
    repo = Path(repo) if repo else Path(git(ROOT, "rev-parse", "--show-toplevel").decode().strip())
    freeze, freeze_raw = load_freeze(freeze_path)
    approval = check_section_approval(approval_path, freeze, "docs_and_prs", repo)
    check_revision_freeze(freeze_path, repo)  # the same full policy gate the canary applies (reruns, native_target, bounds, source)
    allocation = json.loads(allocation_path.read_text())
    transport_limits = (allocation.get("category_limits") or {})
    if (allocation.get("allocation_kind") != "production" or allocation.get("max_requests") != PRODUCTION_REQUEST_LIMIT
            or allocation.get("repository", REPO) != REPO or allocation.get("source_sha256") != sha256_hex(freeze_raw)
            or transport_limits.get("docs_publication") != DOCS_PUBLICATION_LIMIT):
        raise PublicationError("allocation is not the production allocation bound to this exact freeze (120 requests, docs_publication 14)")
    bound = (freeze.get("bound_documents") or {}).get("publication_manifest") or {}
    manifest_file = safe_repo_file(repo, bound.get("path"), "publication manifest path")
    if not manifest_file.is_file() or sha256_hex(manifest_file.read_bytes()) != bound.get("sha256"):
        raise PublicationError("publication manifest differs from the freeze's bound digest")
    manifest = validate_manifest(json.loads(manifest_file.read_text()))
    fixture_binding = manifest.get("fixture_file") or {}
    variants = source_variants(repo, manifest["source_sha"], manifest["server_parent_sha"],
                               manifest["commit_metadata"]["date_utc_second"], fixture_file=fixture_binding.get("path"),
                               workflow_path=manifest["workflow_path"], allow_planning_descendant=True)
    if variants["docs_base_commit"] != manifest["docs_base_commit"] or variants["docs_head_commit"] != manifest["docs_head_commit"]:
        raise PublicationError("local docs variants differ from the frozen docs base/head commits")
    ci_path = ".github/workflows/ci.yml"
    author = {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com",
              "date": manifest["commit_metadata"]["date_utc_second"]}

    def blob_text(commit: str, path: str) -> tuple[str, str]:
        sha = git(repo, "rev-parse", f"{commit}:{path}").decode().strip()
        return sha, git(repo, "cat-file", "blob", sha).decode("utf-8", "strict")

    stages = [
        ("docs-base", "gsd/253-replan-docs-base", manifest["docs_base_commit"], manifest["candidate_tree_sha"],
         manifest["candidate_helper_commit"], "Phase 253 docs probe base workflow exception\n", ci_path),
        ("docs-head", "gsd/253-replan-docs-head", manifest["docs_head_commit"],
         git(repo, "rev-parse", f"{manifest['docs_base_commit']}^{{tree}}").decode().strip(),
         manifest["docs_base_commit"], "Phase 253 docs-only probe head\n", DOCS_PATH),
    ]
    meter = Meter("docs_publication", DOCS_PUBLICATION_LIMIT, ledger_path)
    write_receipt_stub(receipt_path, approval, window_start)
    receipts = []
    for label, ref_name, commit, base_tree, parent_commit, message, path in stages:
        tree = git(repo, "rev-parse", f"{commit}^{{tree}}").decode().strip()
        blob_sha, text = blob_text(commit, path)
        mode = git(repo, "ls-tree", commit, path).decode().split()[0]
        body = {"base_tree": base_tree, "tree": [{"path": path, "mode": mode, "type": "blob", "content": text}]}
        _, created_tree = api_request(allocation_path, ledger_path, "git_create_tree", "POST", body=body, expected={201}, meter=meter)
        if not created_tree or created_tree.get("sha") != tree:
            raise PublicationError(f"{label}: server tree differs from the frozen tree")
        commit_body = {"message": message, "tree": tree, "parents": [parent_commit], "author": author, "committer": author}
        _, created = api_request(allocation_path, ledger_path, "git_create_commit", "POST", body=commit_body, expected={201}, meter=meter)
        if not created or created.get("sha") != commit:
            raise PublicationError(f"{label}: server commit differs from the frozen commit")
        _, readback = api_request(allocation_path, ledger_path, "git_get_commit", "GET", {"sha": commit}, expected={200}, meter=meter)
        if not readback or readback.get("sha") != commit or readback.get("tree", {}).get("sha") != tree:
            raise PublicationError(f"{label}: commit readback differs")
        _, blob = api_request(allocation_path, ledger_path, "git_get_blob", "GET", {"sha": blob_sha}, expected={200}, meter=meter)
        if not blob or blob.get("sha") != blob_sha:
            raise PublicationError(f"{label}: blob readback differs")
        api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={404}, meter=meter)
        _, ref_created = api_request(allocation_path, ledger_path, "create_ref", "POST",
                                     body={"ref": "refs/heads/" + ref_name, "sha": commit}, expected={201}, meter=meter)
        if not ref_created or ref_created.get("object", {}).get("sha") != commit:
            raise PublicationError(f"{label}: create-only reference response differs")
        _, ref_readback = api_request(allocation_path, ledger_path, "get_ref", "GET", {"branch": ref_name}, expected={200}, meter=meter)
        if not ref_readback or ref_readback.get("object", {}).get("sha") != commit:
            raise PublicationError(f"{label}: scoped reference readback differs")
        receipts.append({"kind": label, "commit": commit, "tree": tree, "ref": "refs/heads/" + ref_name, "blob": blob_sha})
    ledger = json.loads(ledger_path.read_text())
    own = category_rows(ledger, "docs_publication")
    if len(own) != len(DOCS_STAGE_ROUTES) * len(stages):
        raise PublicationError("docs publication did not use exactly the frozen two-stage request sequence")
    origin = derive_origin(allocation, {"transactions": own})
    atomic_json(receipt_path, {
        "schema_version": "sigra.phase253.docs-publication-receipt/v1",
        "status": "docs-published-actual-github" if origin["kind"] == "actual-github" else "docs-published-local-fixture",
        "origin": origin, "request_count": category_count(ledger_path, "docs_publication"), "stages": receipts,
        "docs_base_commit": manifest["docs_base_commit"], "docs_head_commit": manifest["docs_head_commit"],
        "freeze_sha256": sha256_hex(freeze_raw), "allocation_sha256": sha256_hex(allocation_path.read_bytes()),
        "ledger_sha256": sha256_hex(ledger_path.read_bytes()), "action_approval": approval})


# ------------------------------------------------------------------------- bounded canary payloads
MATRIX_KEYS = ("schema_version", "repository", "expected", "scenarios", "budget")
DISPATCH_INPUT_CAP = 65535
MATRIX_PAYLOAD_LIMIT = DISPATCH_INPUT_CAP - 1024  # leaves room for the other four dispatch inputs
ARTIFACT_COMPRESSED_LIMIT = 2 * 1024 * 1024
ARTIFACT_EXTRACTED_LIMIT = 4 * 1024 * 1024


def compact_matrix(evidence_path: Path) -> str:
    """Bounded gzip+base64 receipts for the separate verifier: only what verify_sources needs, no ledger."""
    evidence = json.loads(Path(evidence_path).read_text())
    if not isinstance(evidence, dict):
        raise PublicationError("evidence root must be an object")
    compact = {key: evidence[key] for key in MATRIX_KEYS if key in evidence}
    if isinstance(compact.get("budget"), dict):
        compact["budget"] = {"actual_jobs": compact["budget"].get("actual_jobs")}
    raw = json.dumps(compact, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    payload = base64.b64encode(gzip.compress(raw, mtime=0)).decode("ascii")
    if len(payload) > MATRIX_PAYLOAD_LIMIT:
        raise PublicationError(f"compact matrix payload is {len(payload)} characters; the dispatch input cap is {DISPATCH_INPUT_CAP} "
                               f"including the other inputs")
    return payload


def extract_canary_artifact(path: Path) -> dict:
    """One same-run result ZIP: exactly canary-result.json, <=2 MiB compressed, <=4 MiB extracted, JSON object."""
    raw = Path(path).read_bytes()
    if len(raw) > ARTIFACT_COMPRESSED_LIMIT:
        raise PublicationError("compressed canary artifact exceeds 2 MiB")
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as bundle:
            members = [info for info in bundle.infolist() if not info.filename.endswith("/")]
            if [info.filename for info in members] != ["canary-result.json"]:
                raise PublicationError("unexpected canary artifact contents: " + repr([info.filename for info in members]))
            info = members[0]
            if info.flag_bits & 0x1 or info.file_size > ARTIFACT_EXTRACTED_LIMIT:
                raise PublicationError("extracted canary result exceeds 4 MiB or is encrypted")
            with bundle.open(info) as stream:
                content = stream.read(ARTIFACT_EXTRACTED_LIMIT + 1)
    except zipfile.BadZipFile as error:
        raise PublicationError(f"canary artifact is not a valid ZIP: {error}") from error
    if len(content) > ARTIFACT_EXTRACTED_LIMIT:
        raise PublicationError("extracted canary result exceeds 4 MiB")
    try:
        record = json.loads(content)
    except ValueError as error:
        raise PublicationError("canary result is not JSON") from error
    if not isinstance(record, dict):
        raise PublicationError("canary result root must be an object")
    return {"archive_sha256": sha256_hex(raw), "archive_base64": base64.b64encode(raw).decode("ascii"),
            "file": {"content": content.decode("utf-8"), "sha256": sha256_hex(content), "json": record}}


# ---------------------------------------------------------------------------------------- freeze
PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
HELPER_PATHS = (
    "scripts/ci/ci-gate-canary.sh", "scripts/ci/ci-gate-canary.test.sh",
    "scripts/ci/ci-git-publication.py", "scripts/ci/ci-git-publication.test.py",
    "scripts/ci/ci-hosted-gate-verify.py", "scripts/ci/ci-hosted-gate-verify.test.py",
    "scripts/ci/ci-hosted-transport.py", "scripts/ci/ci-pr-proof.sh", "scripts/ci/ci-pr-proof.test.sh",
    "scripts/ci/ci-browser-records.mjs", "scripts/ci/honest-skip-verdict.sh", ".github/workflows/ci.yml",
)
SCENARIO_CASES = (("full-pass", "success"), ("docs-only", "success"), ("actual-failure", "failure"),
                  ("missing-seam", "failure"), ("unexpected-skip", "failure"), ("cancelled", "cancelled"))
REQUIRED_CHECKS = ["Library tests", "Example unit smoke (ExUnit + ConnTest)", "Install smoke (fresh phx.new + sigra.install)",
                   "Example HTTP smoke (boot + curl critical routes)", "Example Playwright smoke (full lifecycle)"]
# Frozen from 253-LOAD-RECOVERY-BUDGETS.md "Hosted canary: unchanged approved categories" (sum 117).
CANARY_CATEGORIES = {
    "preflight": 8, "publication": 24, "dispatch": 7, "run_discovery": 7, "pre_watch_rate": 7, "terminal_polls": 18,
    "attempt_jobs": 7, "artifact_metadata": 7, "artifact_downloads": 12, "failure_logs": 6, "cancellation": 1,
    "infrastructure_retry": 13,
}
PRODUCTION_CATEGORIES = {
    "preflight": 8, "docs_publication": 14, "pr_create": 2, "pr_identity": 8, "run_discovery": 4, "pre_watch_rate": 2,
    "terminal_polls": 27, "attempt_jobs": 4, "native_checks": 4, "artifact_metadata": 4, "artifact_downloads": 20,
    "failure_logs": 2, "infrastructure_rerun": 21,
}
RERUN_REASON = "no implemented rerun route; an infrastructure fault halts"
NATIVE_NOTE = ("CIREL-01 partial: target not reproduced; the nine D-20 acceptance slots expired unused; "
               "the normal PR runs each browser seam once as integration coverage only")
PROHIBITED = ["rerun", "merge", "auto_merge", "push", "force_update", "delete_ref", "rule_change", "release", "tag"]
WORKFLOW_ID = 259268962
CANARY_BRANCH = "gsd/253-replan-fixture"
BOUNDS = {"max_requests": 120, "new_measured_max_requests": 117, "historical_command_allocations": 3,
          "max_actual_tiny_jobs": 45, "max_minutes": 60, "max_dispatch_input_keys": 10, "max_dispatch_input_chars": 65535,
          "max_artifact_compressed_bytes": 2097152, "max_artifact_extracted_bytes": 4194304}


def build_outward_actions(identity: dict) -> tuple[dict, dict]:
    """Every GitHub mutation the next two plans may perform, in order, with exact identities and maxima."""
    candidate, fixture = identity["candidate_helper_commit"], identity["fixture_workflow_commit"]
    blob = identity["fixture_workflow_blob"]
    dispatches = [{"action": "workflow_dispatch", "workflow_id": WORKFLOW_ID, "ref": CANARY_BRANCH,
                   "inputs": {"scenario": name, "candidate_sha": candidate, "fixture_sha": fixture, "fixture_blob": blob}}
                  for name, _ in SCENARIO_CASES]
    canary = {"max_requests": 117, "reruns": 0, "prohibited": PROHIBITED, "actions": [
        {"action": "publish_git_objects", "category": "publication", "max_requests": CANARY_PUBLICATION_LIMIT,
         "candidate_commit": candidate, "fixture_commit": fixture, "manifest": "bound_documents.publication_manifest"},
        {"action": "create_ref", "ref": "refs/heads/gsd/253-replan-candidate", "sha": candidate},
        {"action": "create_ref", "ref": "refs/heads/" + CANARY_BRANCH, "sha": fixture},
        *dispatches,
        {"action": "cancel_run", "scenario": "cancelled", "max": 1,
         "run_identity": {"workflow_id": WORKFLOW_ID, "event": "workflow_dispatch", "head_branch": CANARY_BRANCH,
                          "head_sha": fixture, "display_title_prefix": "Phase 253 Gate Canary / cancelled /"}},
        {"action": "workflow_dispatch", "workflow_id": WORKFLOW_ID, "ref": CANARY_BRANCH,
         "inputs": {"scenario": "verifier", "candidate_sha": candidate, "fixture_sha": fixture, "fixture_blob": blob,
                    "matrix_evidence": "compact gzip+base64 receipts of the six verified sources; digest recorded at dispatch"}},
    ]}
    docs = {"max_requests": 120, "reruns": 0, "prohibited": PROHIBITED, "actions": [
        {"action": "publish_docs_objects", "category": "docs_publication", "max_requests": DOCS_PUBLICATION_LIMIT,
         "docs_base_commit": identity["docs_base_commit"], "docs_head_commit": identity["docs_head_commit"],
         "refs": [{"ref": "refs/heads/gsd/253-replan-docs-base", "sha": identity["docs_base_commit"]},
                  {"ref": "refs/heads/gsd/253-replan-docs-head", "sha": identity["docs_head_commit"]}]},
        {"action": "pr_create", "family": "normal", "head": "gsd/253-replan-candidate", "base": "main", "draft": True},
        {"action": "pr_create", "family": "docs-only", "head": "gsd/253-replan-docs-head",
         "base": "gsd/253-replan-docs-base", "draft": True},
    ]}
    sections = {"canary": canary, "docs_and_prs": docs}
    return sections, {name: sha256_hex(canonical_bytes(value)) for name, value in sections.items()}


def porcelain_outside_config(repo: Path) -> list[str]:
    rows = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all").split(b"\0")
    return [row.decode("utf-8", "replace") for row in rows if row and row != b" M .planning/config.json"]


def safe_repo_file(repo: Path, rel: object, label: str) -> Path:
    """Resolve a repository-relative path; absolute paths, traversal and symlink escapes are refused."""
    candidate = PurePosixPath(str(rel))
    if not isinstance(rel, str) or not rel or candidate.is_absolute() or ".." in candidate.parts:
        raise PublicationError(f"{label} must be a repository-relative path without traversal")
    target = (Path(repo) / rel).resolve()
    try:
        target.relative_to(Path(repo).resolve())
    except ValueError as error:
        raise PublicationError(f"{label} resolves outside the repository") from error
    return target


def doc_binding(repo: Path, rel: str) -> dict:
    path = (repo / rel).resolve()
    try:
        path.relative_to(repo.resolve())
    except ValueError as error:
        raise PublicationError(f"bound document must live inside the repository: {rel}") from error
    if not path.is_file():
        raise PublicationError(f"bound document is missing: {rel}")
    return {"path": rel, "sha256": sha256_hex(path.read_bytes())}


def static_freeze_sections() -> dict:
    """The parts of the freeze that never vary with the source: policy, bounds, categories, expired reruns."""
    return {
        "scenarios": {"count": 6, "optional_infrastructure_retry": 0, "retry_status": "expired", "retry_reason": RERUN_REASON,
                      "cases": [{"name": name, "expected_outcome": outcome} for name, outcome in SCENARIO_CASES]},
        "expired_reruns": {
            "canary": {"category": "infrastructure_retry", "status": "expired", "requests": 13, "jobs": 6, "used": 0, "reason": RERUN_REASON},
            "pull_requests": {"category": "infrastructure_rerun", "status": "expired", "requests": 21, "used": 0, "reason": RERUN_REASON}},
        "bounds": BOUNDS, "categories": {"canary": CANARY_CATEGORIES, "production": PRODUCTION_CATEGORIES},
        "clock": {"minutes": 60, "begins": "before_first_preflight_or_publication_request"},
        "required_checks": REQUIRED_CHECKS,
        "workflow": {"name": "Phase 253 Gate Canary", "path": REGISTERED_WORKFLOW_PATH, "trigger": ["workflow_dispatch"],
                     "permissions": {"contents": "read"}, "registered_workflow_id": WORKFLOW_ID,
                     "jobs": {"tiny_producers": 5, "verdict": 1, "independent_verifier": 1, "observer_trigger": False}},
        "historical": {"previous_accounted_or_reserved_requests": 20, "previous_exact_http_count_proven": False,
                       "note": "old run 38347679431, epoch 1791909792, 34-second halt and three known commands remain closed; historical actual HTTP is unknown"},
    }


NATIVE_ROUTES = ("not_reproduced_disposition", "accepted_target")


def rehash_binding(repo: Path, item: object, label: str) -> None:
    if not isinstance(item, dict) or set(item) != {"path", "sha256"} or not isinstance(item.get("path"), str) \
            or not re.fullmatch(r"[a-f0-9]{64}", str(item.get("sha256", ""))):
        raise PublicationError(f"native_target {label} needs exactly a path and a lowercase sha256")
    candidate = PurePosixPath(item["path"])
    if candidate.is_absolute() or ".." in candidate.parts:
        raise PublicationError(f"native_target {label} path must be repository-relative")
    target = (Path(repo) / item["path"]).resolve()
    try:
        target.relative_to(Path(repo).resolve())
    except ValueError as error:
        raise PublicationError(f"native_target {label} path escapes the repository") from error
    if not target.is_file():
        raise PublicationError(f"native_target {label} file is missing: {item['path']}")
    if sha256_hex(target.read_bytes()) != item["sha256"]:
        raise PublicationError(f"native_target {label} differs from its frozen sha256: {item['path']}")


def check_native_target(freeze: dict, repo: Path) -> None:
    native = freeze.get("native_target")
    if not isinstance(native, dict):
        raise PublicationError("the freeze has no native_target section")
    route = native.get("route")
    if route not in NATIVE_ROUTES:
        raise PublicationError("native_target route must be not_reproduced_disposition or accepted_target")
    rehash_binding(repo, native.get("acceptance_evidence"), "acceptance_evidence")
    expected_keys = {"route", "acceptance_evidence", "note"}
    if route == "not_reproduced_disposition":
        rehash_binding(repo, native.get("disposition"), "disposition")
        rehash_binding(repo, native.get("disposition_approval"), "disposition_approval")
        expected_keys |= {"disposition", "disposition_approval"}
        if native.get("note") != NATIVE_NOTE:
            raise PublicationError("native_target note must state the partial, not-reproduced disposition")
    if set(native) != expected_keys:
        raise PublicationError("native_target has missing or unexpected members")


def build_freeze(repo: Path, manifest_rel: str, output: Path, acceptance_rel: str | None = None,
                 disposition_rel: str | None = None, approval_rel: str | None = None,
                 native_route: str = "not_reproduced_disposition") -> dict:
    repo = Path(repo)
    dirty = porcelain_outside_config(repo)
    if dirty:
        raise PublicationError(f"the freeze is derived only from a committed, clean tree; dirty paths: {dirty[:5]}")
    manifest_binding = doc_binding(repo, manifest_rel)
    manifest = validate_manifest(json.loads((repo / manifest_rel).read_text()))
    if manifest["status"] != "ready-local-proposal":
        raise PublicationError("the publication manifest is not ready")
    fixture_binding = manifest.get("fixture_file") or {}
    if not fixture_binding.get("path") or manifest["workflow_path"] != REGISTERED_WORKFLOW_PATH:
        raise PublicationError("the freeze needs the registered ci.yml fixture child and its bound fixture file")
    source = manifest["source_sha"]
    state = validate_frozen_product_source(repo, source)
    helper_blobs = {}
    for rel in HELPER_PATHS:
        probe = subprocess.run(["git", "-C", str(repo), "rev-parse", f"{source}:{rel}"], capture_output=True, text=True)
        if probe.returncode:
            raise PublicationError(f"called helper is missing at the frozen source: {rel}")
        helper_blobs[rel] = probe.stdout.strip()
    acceptance_rel = acceptance_rel or f"{PHASE_REL}/253-LOAD-RECOVERY-ACCEPTANCE-EVIDENCE.json"
    native = {"route": native_route, "acceptance_evidence": doc_binding(repo, acceptance_rel), "note": NATIVE_NOTE}
    if native_route == "not_reproduced_disposition":
        native["disposition"] = doc_binding(repo, disposition_rel or f"{PHASE_REL}/253-LOAD-RECOVERY-TARGET-DISPOSITION.json")
        native["disposition_approval"] = doc_binding(repo, approval_rel or f"{PHASE_REL}/253-LOAD-RECOVERY-TARGET-DISPOSITION-APPROVAL.json")
    identity = {
        "candidate_helper_commit": manifest["candidate_helper_commit"], "candidate_tree_sha": manifest["candidate_tree_sha"],
        "candidate_ref": "refs/heads/gsd/253-replan-candidate",
        "fixture_workflow_commit": manifest["fixture_workflow_commit"], "fixture_workflow_blob": manifest["fixture_workflow_blob"],
        "fixture_tree_sha": manifest["fixture_tree_sha"], "fixture_ref": "refs/heads/" + CANARY_BRANCH,
        "workflow_path": manifest["workflow_path"], "server_parent_sha": manifest["server_parent_sha"],
        "docs_base_commit": manifest["docs_base_commit"], "docs_head_commit": manifest["docs_head_commit"],
        "old_failed_run_id": "38347679431", "old_failed_epoch": 1791909792, "old_failed_halt_seconds": 34,
        "old_known_commands": 3,
    }
    sections, digests = build_outward_actions(identity)
    freeze = {
        "schema_version": FREEZE_SCHEMA, "plan": "253-91",
        "source": {"commit": source, "product_tree_sha": state["product_tree_sha"],
                   "product_files": manifest["product_tree_parity"]["source_product_files"]},
        "identity": identity, "helper_blobs": helper_blobs,
        "bound_documents": {"publication_manifest": manifest_binding, "fixture_workflow": doc_binding(repo, fixture_binding["path"])},
        **static_freeze_sections(),
        "native_target": native, "outward_actions": sections, "outward_actions_sha256": digests,
    }
    atomic_json(repo / output if not Path(output).is_absolute() else Path(output), freeze)
    return freeze


def check_revision_freeze(freeze_path: Path, repo: Path) -> dict:
    """Validate the revision freeze against the committed tree. Returns the parsed freeze."""
    repo = Path(repo)
    freeze, _ = load_freeze(freeze_path)
    source = freeze.get("source") or {}
    validate_frozen_product_source(repo, source.get("commit", ""), source.get("product_tree_sha"))
    identity = freeze.get("identity") or {}
    for field in ("candidate_helper_commit", "fixture_workflow_commit", "fixture_workflow_blob", "candidate_tree_sha",
                  "fixture_tree_sha", "server_parent_sha", "docs_base_commit", "docs_head_commit"):
        if not re.fullmatch(r"[a-f0-9]{40}", str(identity.get(field, ""))):
            raise PublicationError(f"freeze identity {field} is not a full lowercase Git object SHA")
    if (identity.get("fixture_ref") != "refs/heads/" + CANARY_BRANCH or identity.get("candidate_ref") != "refs/heads/gsd/253-replan-candidate"
            or identity.get("workflow_path") != REGISTERED_WORKFLOW_PATH):
        raise PublicationError("freeze fixture or candidate ref, or workflow path, is not the scoped registered identity")
    for field in ("candidate_helper_commit", "fixture_workflow_commit"):
        if subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{identity[field]}^{{commit}}"], capture_output=True).returncode:
            raise PublicationError(f"freeze {field} is not present locally")
    if git(repo, "rev-parse", f"{identity['fixture_workflow_commit']}:{REGISTERED_WORKFLOW_PATH}").decode().strip() != identity["fixture_workflow_blob"]:
        raise PublicationError("fixture blob does not match the fixture commit's registered workflow")
    for rel, expected in (freeze.get("helper_blobs") or {}).items():
        if git(repo, "rev-parse", f"{source['commit']}:{rel}").decode().strip() != expected:
            raise PublicationError(f"helper blob differs from the frozen source: {rel}")
    if set(freeze.get("helper_blobs") or {}) != set(HELPER_PATHS):
        raise PublicationError("freeze helper blob set is incomplete or unexpected")
    bound = freeze.get("bound_documents") or {}
    for name in ("publication_manifest", "fixture_workflow"):
        item = bound.get(name) or {}
        path = safe_repo_file(repo, item.get("path"), f"bound document {name} path")
        if not path.is_file() or sha256_hex(path.read_bytes()) != item.get("sha256"):
            raise PublicationError(f"bound document {name} is missing or differs from its digest")
    manifest = validate_manifest(json.loads(safe_repo_file(repo, bound["publication_manifest"]["path"], "publication manifest path").read_text()))
    for field in ("candidate_helper_commit", "fixture_workflow_commit", "fixture_workflow_blob", "candidate_tree_sha",
                  "fixture_tree_sha", "docs_base_commit", "docs_head_commit", "server_parent_sha"):
        if manifest[field] != identity[field]:
            raise PublicationError(f"freeze identity {field} differs from the bound publication manifest")
    if manifest["source_sha"] != source.get("commit"):
        raise PublicationError("freeze source differs from the publication manifest source")
    for key, expected in static_freeze_sections().items():
        if freeze.get(key) != expected:
            raise PublicationError(f"freeze {key} differs from the frozen policy (expired reruns, bounds, categories, clock, history)")
    if sum(CANARY_CATEGORIES.values()) != 117 or sum(PRODUCTION_CATEGORIES.values()) != 120:
        raise PublicationError("category tables do not add up to the 117/120 allocations")
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_hosted_transport_for_freeze", TRANSPORT)
    transport = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(transport)
    if PRODUCTION_CATEGORIES != transport.PRODUCTION_CATEGORY_LIMITS:
        raise PublicationError("production categories differ from the transport's frozen category table")
    for field, value in (("old_failed_run_id", "38347679431"), ("old_failed_epoch", 1791909792),
                         ("old_failed_halt_seconds", 34), ("old_known_commands", 3)):
        if identity.get(field) != value:
            raise PublicationError(f"freeze must retain the closed historical window: {field}")
    check_native_target(freeze, repo)
    sections, digests = build_outward_actions(identity)
    if freeze.get("outward_actions") != sections or freeze.get("outward_actions_sha256") != digests:
        raise PublicationError("outward_actions are not the enumerated actions derived from the frozen identities")
    for section in SECTIONS:
        section_sha256(freeze, section)
    return freeze


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--candidate-source")
    parser.add_argument("--server-parent")
    parser.add_argument("--output")
    parser.add_argument("--fixture-file", help="repository-relative fixture workflow file (default: the superseded recovery fixture)")
    parser.add_argument("--workflow-path", help="workflow file the fixture child changes (default: the superseded unregistered path)")
    parser.add_argument("--repo-root", help=argparse.SUPPRESS)
    parser.add_argument("--check-manifest")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--publish-docs", action="store_true")
    parser.add_argument("--manifest")
    parser.add_argument("--allocation")
    parser.add_argument("--ledger")
    parser.add_argument("--receipt")
    parser.add_argument("--freeze")
    parser.add_argument("--action-approval")
    parser.add_argument("--section", choices=SECTIONS)
    parser.add_argument("--check-approval", action="store_true")
    parser.add_argument("--verify-publication")
    parser.add_argument("--require-live-origin", action="store_true")
    parser.add_argument("--validate-frozen-source")
    parser.add_argument("--build-freeze", action="store_true")
    parser.add_argument("--check-freeze")
    parser.add_argument("--acceptance-evidence")
    parser.add_argument("--disposition")
    parser.add_argument("--disposition-approval")
    parser.add_argument("--window-wall-start-epoch", type=int, help="window start already recorded by the caller (shared with the evidence)")
    parser.add_argument("--compact-matrix")
    parser.add_argument("--extract-canary-artifact")
    args = parser.parse_args()
    repo_arg = Path(args.repo_root).resolve() if args.repo_root else None
    try:
        if args.prepare:
            if not (args.candidate_source and args.server_parent and args.output):
                raise PublicationError("--prepare requires candidate source, server parent, and output")
            proposal = source_variants(repo_arg or ROOT, args.candidate_source, args.server_parent,
                                       fixture_file=args.fixture_file, workflow_path=args.workflow_path)
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
            publish(Path(args.manifest), Path(args.allocation), Path(args.ledger), Path(args.receipt), repo_arg,
                    Path(args.freeze) if args.freeze else None, Path(args.action_approval) if args.action_approval else None,
                    args.window_wall_start_epoch)
            return 0
        if args.publish_docs:
            if not all((args.freeze, args.allocation, args.ledger, args.receipt)):
                raise PublicationError("--publish-docs requires freeze, allocation, ledger, and receipt paths")
            publish_docs(Path(args.freeze), Path(args.allocation), Path(args.ledger), Path(args.receipt), repo_arg,
                         Path(args.action_approval) if args.action_approval else None, args.window_wall_start_epoch)
            return 0
        if args.check_approval:
            if not (args.freeze and args.section):
                raise PublicationError("--check-approval requires --freeze and --section")
            freeze, _ = load_freeze(Path(args.freeze))
            print(json.dumps(check_section_approval(args.action_approval, freeze, args.section, repo_arg or ROOT), sort_keys=True))
            return 0
        if args.verify_publication:
            verify_publication(Path(args.verify_publication), args.require_live_origin)
            print("publication receipt valid")
            return 0
        if args.validate_frozen_source:
            print(json.dumps(validate_frozen_product_source(repo_arg or ROOT, args.validate_frozen_source), sort_keys=True))
            return 0
        if args.build_freeze:
            if not (args.manifest and args.output):
                raise PublicationError("--build-freeze requires --manifest and --output")
            freeze = build_freeze(repo_arg or ROOT, args.manifest, Path(args.output), args.acceptance_evidence,
                                  args.disposition, args.disposition_approval)
            print(json.dumps({"status": "freeze_built", "canary_sha256": freeze["outward_actions_sha256"]["canary"],
                              "docs_and_prs_sha256": freeze["outward_actions_sha256"]["docs_and_prs"]}, sort_keys=True))
            return 0
        if args.compact_matrix:
            print(compact_matrix(Path(args.compact_matrix)))
            return 0
        if args.extract_canary_artifact:
            print(json.dumps(extract_canary_artifact(Path(args.extract_canary_artifact))))
            return 0
        if args.check_freeze:
            check_revision_freeze(Path(args.check_freeze), repo_arg or ROOT)
            print(json.dumps({"status": "freeze_valid", "network_requests": 0}, sort_keys=True))
            return 0
        parser.error("choose --prepare, --check-manifest, --publish, --publish-docs, --check-approval, --verify-publication, "
                     "--validate-frozen-source, --build-freeze, or --check-freeze")
    except (PublicationError, OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"ci-git-publication: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
