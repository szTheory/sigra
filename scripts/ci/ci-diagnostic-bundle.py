#!/usr/bin/env python3
"""Stage and verify a bounded, invocation-bound diagnostics ZIP."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
import tempfile
import zipfile
from datetime import datetime, timezone

from ci_metrics_security import sanitize_failure_log, verified_failure_log, verified_zip_members


SCHEMA = "sigra.ci-diagnostic-bundle/v1"
MAX_FILE_BYTES = 5 * 1024 * 1024
MAX_BUNDLE_BYTES = 20 * 1024 * 1024
LOG_KINDS = {"log", "command_stdout", "command_stderr", "cleanup_stdout", "cleanup_stderr"}
SECRET_SENTINEL = re.compile(
    rb"(?i)(SECRET[_ -]?SENTINEL|DO[_ -]?NOT[_ -]?UPLOAD|GH[pousr]_[A-Za-z0-9_]{20,}|"
    rb"github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)"
)


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def valid_relative_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw:
        raise ValueError("manifest_path_invalid")
    path = pathlib.PurePosixPath(raw)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts) or path.as_posix() != raw:
        raise ValueError(f"manifest_path_invalid:{raw}")
    return raw


def identity_from_manifest(manifest: dict) -> dict:
    required = ("invocation_id", "source_sha", "run_id", "run_attempt", "job_id", "seam")
    if manifest.get("schema_version") != "sigra.ci-diagnostic-invocation/v1":
        raise ValueError("invocation_manifest_schema_invalid")
    if any(not isinstance(manifest.get(key), (str, int)) or str(manifest.get(key)) == "" for key in required):
        raise ValueError("invocation_identity_incomplete")
    if not re.fullmatch(r"[0-9a-f]{40}(?:[0-9a-f]{24})?", str(manifest["source_sha"])):
        raise ValueError("source_sha_invalid")
    try:
        if int(manifest["run_attempt"]) < 1:
            raise ValueError
    except (ValueError, TypeError):
        raise ValueError("run_attempt_invalid") from None
    for key in ("invocation_id", "run_id", "job_id", "seam"):
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", str(manifest[key])):
            raise ValueError(f"{key}_invalid")
    return {key: manifest[key] for key in required}


def load_manifest(path: pathlib.Path, invocation_root: pathlib.Path | None = None) -> dict:
    path = pathlib.Path(path)
    if path.is_symlink():
        raise ValueError("invocation_manifest_symlink_rejected")
    if invocation_root is not None:
        root = pathlib.Path(invocation_root).resolve()
        if not path.resolve().is_relative_to(root):
            raise ValueError("invocation_manifest_outside_root")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValueError(f"invocation_manifest_unreadable:{error}") from None
    if not isinstance(value, dict):
        raise ValueError("invocation_manifest_invalid")
    identity_from_manifest(value)
    return value


def list_manifest_files(manifest: dict) -> list[dict]:
    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise ValueError("manifest_files_invalid")
    seen = set()
    result = []
    for item in entries:
        if not isinstance(item, dict):
            raise ValueError("manifest_file_entry_invalid")
        path = valid_relative_path(item.get("path"))
        if path == "bundle-manifest.json":
            raise ValueError("manifest_path_reserved:bundle-manifest.json")
        if path in seen:
            raise ValueError(f"duplicate_manifest_path:{path}")
        seen.add(path)
        if not isinstance(item.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
            raise ValueError(f"manifest_file_hash_invalid:{path}")
        if not isinstance(item.get("kind"), str) or not item["kind"]:
            raise ValueError(f"manifest_file_kind_invalid:{path}")
        result.append({"path": path, "sha256": item["sha256"], "kind": item["kind"]})
    return result


def auth_path(path: str) -> bool:
    parts = (part.lower() for part in pathlib.PurePosixPath(path).parts)
    return any(part in {".auth", "storagestate.json", "storage-state.json"} for part in parts)


def source_bytes(root: pathlib.Path, relative: str, expected: str) -> bytes:
    root = pathlib.Path(root).resolve()
    path = root.joinpath(*pathlib.PurePosixPath(relative).parts)
    cursor = root
    for part in pathlib.PurePosixPath(relative).parts:
        cursor = cursor / part
        try:
            if stat.S_ISLNK(cursor.lstat().st_mode):
                raise ValueError(f"symlink_path_rejected:{relative}")
        except FileNotFoundError:
            raise ValueError(f"promised_file_missing:{relative}") from None
    resolved = path.resolve()
    if not resolved.is_relative_to(root):
        raise ValueError(f"path_escapes_invocation_root:{relative}")
    if not resolved.is_file():
        raise ValueError(f"promised_file_missing:{relative}")
    try:
        payload = verified_failure_log(root, relative, expected)
    except (OSError, ValueError) as error:
        raise ValueError(f"file_hash_or_containment_invalid:{relative}:{error}") from None
    if len(payload) > MAX_FILE_BYTES:
        raise ValueError(f"file_size_limit_exceeded:{relative}")
    return payload


def unsafe_content(payload: bytes) -> str | None:
    if SECRET_SENTINEL.search(payload):
        return "secret_sentinel_detected"
    lowered = payload[:MAX_FILE_BYTES].lower()
    if b"storagestate" in lowered or b"storage-state" in lowered or b"playwright/.auth" in lowered:
        return "auth_state_content_detected"
    return None


def stage_bundle(invocation_root: pathlib.Path, manifest_path: pathlib.Path, output: pathlib.Path) -> dict:
    root = pathlib.Path(invocation_root).resolve()
    if not root.is_dir():
        raise ValueError("invocation_root_missing")
    manifest = load_manifest(pathlib.Path(manifest_path), root)
    identity = identity_from_manifest(manifest)
    entries = list_manifest_files(manifest)
    output = pathlib.Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() or output.is_symlink():
        raise ValueError("output_already_exists")

    members: dict[str, dict] = {}
    payloads: dict[str, bytes] = {}
    withheld: list[dict] = []
    total_bytes = 0
    for entry in entries:
        relative, kind = entry["path"], entry["kind"]
        if auth_path(relative) or kind == "auth":
            withheld.append({"path": relative, "reason": "auth_state_excluded"})
            continue
        if kind == "trace":
            provenance = manifest.get("trace_provenance") or {}
            if provenance.get("synthetic_account") is not True or provenance.get("registered") is not True:
                withheld.append({"path": relative, "reason": "trace_provenance_missing"})
                continue
        raw = source_bytes(root, relative, entry["sha256"])
        unsafe = unsafe_content(raw)
        if unsafe:
            withheld.append({"path": relative, "reason": unsafe})
            continue
        payload = raw
        details = {"kind": kind, "source_sha256": entry["sha256"], "size": len(raw)}
        if kind in LOG_KINDS:
            excerpt = sanitize_failure_log(raw, max_input_bytes=MAX_FILE_BYTES, max_output_bytes=64 * 1024)
            payload = excerpt["text"].encode("utf-8")
            details.update({"sanitized": True, "truncated": excerpt["truncated"],
                            "source_size": excerpt["input_bytes"]})
        unsafe_after_sanitizing = unsafe_content(payload)
        if unsafe_after_sanitizing:
            withheld.append({"path": relative, "reason": unsafe_after_sanitizing})
            continue
        total_bytes += len(payload)
        if total_bytes > MAX_BUNDLE_BYTES:
            raise ValueError("bundle_size_limit_exceeded")
        payloads[relative] = payload
        members[relative] = {**details, "sha256": digest(payload)}

    metadata = {
        "schema_version": SCHEMA,
        **identity,
        "members": members,
        "withheld": withheld,
        "trace_unavailable_reason": manifest.get("trace_unavailable_reason"),
        "trace_content_note": "Traces can contain authentication requests and DOM content; .auth exclusion alone does not prove trace safety.",
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    metadata_payload = (json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
    fd, temporary_name = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
    os.close(fd)
    temporary = pathlib.Path(temporary_name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("bundle-manifest.json", metadata_payload)
            for relative in sorted(payloads):
                archive.writestr(relative, payloads[relative])
        if temporary.stat().st_size > MAX_BUNDLE_BYTES:
            raise ValueError("bundle_size_limit_exceeded")
        # Exclusive installation avoids replacing an archive from an earlier invocation.
        os.link(temporary, output)
    except (OSError, zipfile.BadZipFile):
        raise
    finally:
        temporary.unlink(missing_ok=True)
    return {"status": "staged", "bundle": str(output), "invocation_id": identity["invocation_id"],
            "member_count": len(members), "withheld": withheld}


def verify_bundle(bundle: pathlib.Path, manifest_path: pathlib.Path) -> dict:
    archive_path = pathlib.Path(bundle)
    manifest = load_manifest(pathlib.Path(manifest_path))
    identity = identity_from_manifest(manifest)
    entries = list_manifest_files(manifest)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            infos = archive.infolist()
            names = [info.filename for info in infos]
            if len(names) != len(set(names)):
                raise ValueError("duplicate_archive_member")
            if any(info.is_dir() for info in infos):
                raise ValueError("archive_directory_member_rejected")
            for info in infos:
                name = valid_relative_path(info.filename)
                mode = (info.external_attr >> 16) & 0o170000
                if mode == stat.S_IFLNK:
                    raise ValueError(f"archive_symlink_rejected:{name}")
            metadata = json.loads(archive.read("bundle-manifest.json"))
            if not isinstance(metadata, dict) or metadata.get("schema_version") != SCHEMA:
                raise ValueError("bundle_manifest_invalid")
            if any(metadata.get(key) != value for key, value in identity.items()):
                raise ValueError("bundle_identity_mismatch")
            hashes = {name: item.get("sha256") for name, item in (metadata.get("members") or {}).items()}
            expected_names = {"bundle-manifest.json", *hashes.keys()}
            if set(names) != expected_names:
                raise ValueError("archive_member_allowlist_mismatch")
            allowed = {entry["path"] for entry in entries}
            if not set(hashes).issubset(allowed) or set(hashes) & {entry["path"] for entry in entries if auth_path(entry["path"]) or entry["kind"] == "auth"}:
                raise ValueError("archive_member_not_manifest_allowlisted")
            if set(hashes) & {entry["path"] for entry in entries if entry["kind"] == "trace"}:
                provenance = manifest.get("trace_provenance") or {}
                if provenance.get("synthetic_account") is not True or provenance.get("registered") is not True:
                    raise ValueError("trace_provenance_missing")
            withheld = metadata.get("withheld") or []
            if not isinstance(withheld, list) or any(not isinstance(item, dict) for item in withheld):
                raise ValueError("bundle_withheld_manifest_invalid")
            withheld_paths = {item.get("path") for item in withheld}
            if (any(path not in allowed or not isinstance(item.get("reason"), str) or not item["reason"]
                    for item in withheld for path in [item.get("path")])
                    or len(withheld_paths) != len(withheld)
                    or set(hashes) & withheld_paths
                    or set(hashes) | withheld_paths != allowed):
                raise ValueError("bundle_withheld_allowlist_mismatch")
            expected_archive_hash = digest(archive_path.read_bytes())
            verified = verified_zip_members(archive_path, expected_archive_hash,
                                             {"bundle-manifest.json": digest(archive.read("bundle-manifest.json")), **hashes})
            for name, payload in verified.items():
                unsafe = unsafe_content(payload)
                if unsafe:
                    raise ValueError(f"unsafe_archive_content:{name}:{unsafe}")
            source_by_path = {entry["path"]: entry for entry in entries}
            invocation_root = pathlib.Path(manifest_path).parent.resolve()
            for name, details in metadata["members"].items():
                source_entry = source_by_path[name]
                if (details.get("kind") != source_entry["kind"]
                        or details.get("source_sha256") != source_entry["sha256"]):
                    raise ValueError(f"archive_member_source_binding_invalid:{name}")
                original = source_bytes(invocation_root, name, source_entry["sha256"])
                expected_payload = original
                if source_entry["kind"] in LOG_KINDS:
                    expected_payload = sanitize_failure_log(original, max_input_bytes=MAX_FILE_BYTES,
                                                             max_output_bytes=64 * 1024)["text"].encode("utf-8")
                if verified[name] != expected_payload:
                    raise ValueError(f"archive_member_source_bytes_mismatch:{name}")
    except (OSError, zipfile.BadZipFile, KeyError, json.JSONDecodeError) as error:
        if isinstance(error, ValueError):
            raise
        raise ValueError(f"bundle_unreadable:{error}") from None
    return {"status": "verified", "bundle": str(archive_path), "invocation_id": identity["invocation_id"],
            "member_count": len(hashes), "withheld_count": len(metadata.get("withheld") or [])}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    stage = subparsers.add_parser("stage", help="stage an invocation-owned diagnostics ZIP")
    stage.add_argument("--invocation-root", required=True, type=pathlib.Path)
    stage.add_argument("--manifest", required=True, type=pathlib.Path)
    stage.add_argument("--output", required=True, type=pathlib.Path)
    verify = subparsers.add_parser("verify", help="inspect a finished bundle and verify its members")
    verify.add_argument("--bundle", required=True, type=pathlib.Path)
    verify.add_argument("--manifest", required=True, type=pathlib.Path)
    args = parser.parse_args()
    try:
        result = stage_bundle(args.invocation_root, args.manifest, args.output) if args.mode == "stage" else verify_bundle(args.bundle, args.manifest)
    except (OSError, ValueError, TypeError) as error:
        print(f"ci-diagnostic-bundle: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
