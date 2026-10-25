#!/usr/bin/env python3
"""Compare real native library and browser work on two exact Phase 255 sources."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
OWNERS = ("admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")
LIBRARY_RECEIVERS = ("ordinary", "scaffold", "dep_off")
REPORT_SCHEMA = "sigra.repaired-work/v1"
WORKLOAD_MAP = ".planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return digest(path.read_bytes())


def normalize_inventory(rows: list | None) -> list[str] | None:
    if not isinstance(rows, list):
        return None
    return sorted(json.dumps(item, ensure_ascii=False, sort_keys=True, separators=(",", ":")) for item in rows)


def validate_pair_shape(pair: dict, errors: list[str], kind: str, owner: str) -> bool:
    if not isinstance(pair, dict) or not {"control", "candidate"} <= set(pair):
        errors.append(f"{kind}_source_pair_missing:{owner}")
        return False
    if set(pair) - {"control", "candidate", "comparison"}:
        errors.append(f"{kind}_source_pair_invalid:{owner}")
        return False
    comparison = pair.get("comparison")
    if comparison is not None and (not isinstance(comparison, dict) or comparison.get("status") != "passed"):
        errors.append(f"{kind}_comparison_not_passed:{owner}")
    return True


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def source_rows(path: Path) -> dict:
    """Verify the immutable source archives and return their declared identities."""
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data.get("sources"), dict), "sources_json_invalid")
    result = {}
    for role in ("control", "candidate"):
        source = data["sources"].get(role)
        require(isinstance(source, dict), f"source_missing:{role}")
        archive = source.get("archive") or {}
        archive_path = (path.parent / archive.get("path", "")).resolve()
        require(path.parent.resolve() in archive_path.parents, f"archive_path_outside_execution_root:{role}")
        require(archive_path.is_file(), f"source_archive_missing:{role}")
        archive_sha = sha_file(archive_path)
        require(archive_sha == archive.get("sha256"), f"source_archive_digest_mismatch:{role}")
        require(source.get("merge_preview", {}).get("status") == "ready", f"source_merge_not_ready:{role}")
        require(source.get("tree_sha") == source.get("merge_preview", {}).get("expected_tree"),
                f"source_tree_mismatch:{role}")
        result[role] = {
            "source_sha": source.get("source_sha"),
            "application_sha": source.get("application_sha"),
            "tree_sha": source.get("tree_sha"),
            "archive_path": archive_path,
            "archive_sha256": archive_sha,
            "source_ref": source.get("source_ref"),
        }
        require(isinstance(result[role]["source_sha"], str) and len(result[role]["source_sha"]) == 40,
                f"source_sha_invalid:{role}")
    require(result["control"]["source_sha"] != result["candidate"]["source_sha"], "source_roles_are_identical")
    return result


def run(command: list[str], *, cwd: Path, env: dict[str, str], timeout: int = 1800) -> dict:
    """Capture full command output outside the tracked proof and preserve the exit."""
    started = time.time()
    try:
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True,
                                check=False, timeout=timeout)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
        signal_number = None
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else (error.stdout or "")
        stderr = error.stderr.decode(errors="replace") if isinstance(error.stderr, bytes) else (error.stderr or "")
        code, signal_number = 124, None
    except OSError as error:
        stdout, stderr, code, signal_number = "", f"{type(error).__name__}: {error}", 127, None
    return {"command": command, "cwd": str(cwd), "exit_code": code, "signal": signal_number,
            "duration_seconds": round(time.time() - started, 3), "stdout": stdout, "stderr": stderr,
            "status": "passed" if code == 0 else "failed"}


def native_process_environment(source_env: dict[str, str], scratch: Path) -> dict[str, str]:
    result = dict(source_env)
    result["PATH"] = source_env.get("PATH", os.defpath)
    if not result.get("HEX_HOME"):
        hex_home = scratch / "hex-home"
        hex_home.mkdir(mode=0o700, parents=True, exist_ok=True)
        result["HEX_HOME"] = str(hex_home)
    return result


def unavailable_native_toolchain(runtime: dict[str, str | None]) -> list[str]:
    return [name for name in ("node", "elixir", "mix") if not runtime.get(name)]


def verify_report_digest(row: dict, root: Path) -> bool:
    try:
        path = root / row["path"]
        return path.is_file() and not path.is_symlink() and sha_file(path) == row["sha256"]
    except (KeyError, OSError, TypeError):
        return False


def validate_equivalent_work(value: dict, *, report_root: Path | None = None) -> tuple[bool, list[str]]:
    """Fail closed on missing/mismatched identities; local proof never means hosted proof."""
    errors: list[str] = []
    if not isinstance(value, dict) or value.get("schema_version") != REPORT_SCHEMA:
        return False, ["schema_mismatch"]
    if value.get("acceptance_samples") != 0:
        errors.append("acceptance_samples_not_zero")
    if value.get("hosted_status") != "blocked" or value.get("hosted_origin_available") is not False:
        errors.append("local_record_claims_hosted_origin")
    sources = value.get("sources")
    if not isinstance(sources, dict) or set(sources) != {"control", "candidate"}:
        errors.append("source_roles_incomplete")
    else:
        for role, source in sources.items():
            if not isinstance(source, dict) or source.get("source_sha") is None or source.get("archive_sha256") is None:
                errors.append(f"source_identity_incomplete:{role}")
    receivers = (value.get("library") or {}).get("receivers")
    if not isinstance(receivers, dict) or set(receivers) != set(LIBRARY_RECEIVERS):
        errors.append("library_receivers_incomplete")
    else:
        for receiver, pair in receivers.items():
            if not validate_pair_shape(pair, errors, "library", receiver):
                continue
            for role, row in pair.items():
                if role not in {"control", "candidate"}:
                    continue
                if not isinstance(row, dict) or row.get("exit_code") != 0 or row.get("complete") is not True:
                    errors.append(f"library_receiver_failed:{receiver}:{role}")
                    continue
                if not isinstance(row.get("seed"), int) or not isinstance(row.get("tests"), list) or not row["tests"]:
                    errors.append(f"library_report_incomplete:{receiver}:{role}")
                identities = [test.get("test_id") for test in row.get("tests", []) if isinstance(test, dict)]
                if len(identities) != len(set(identities)) or None in identities:
                    errors.append(f"library_identity_invalid:{receiver}:{role}")
                if any(test.get("status") not in {"passed", "skipped"} for test in row.get("tests", []) if isinstance(test, dict)):
                    errors.append(f"library_unexpected_status:{receiver}:{role}")
                for key in ("skipped", "excluded"):
                    inventory = row.get(key)
                    if (not isinstance(inventory, list)
                            or any(not isinstance(item, dict) or not item.get("test_id") or not item.get("reason")
                                   for item in inventory)):
                        errors.append(f"library_skip_or_exclusion_invalid:{receiver}:{role}")
                        continue
                    inventory_ids = [item["test_id"] for item in inventory]
                    if len(inventory_ids) != len(set(inventory_ids)):
                        errors.append(f"library_skip_or_exclusion_duplicate:{receiver}:{role}")
                skipped_ids = {item.get("test_id") for item in row.get("skipped", []) if isinstance(item, dict)}
                expected_skips = {item.get("test_id") for item in row.get("tests", [])
                                  if isinstance(item, dict) and item.get("status") == "skipped"}
                if skipped_ids != expected_skips:
                    errors.append(f"library_skip_inventory_mismatch:{receiver}:{role}")
                excluded_ids = {item.get("test_id") for item in row.get("excluded", []) if isinstance(item, dict)}
                if excluded_ids.intersection(identities):
                    errors.append(f"library_exclusion_was_executed:{receiver}:{role}")
                if report_root is not None and not verify_report_digest(row, report_root):
                    errors.append(f"library_report_digest_invalid:{receiver}:{role}")
            left, right = pair.get("control"), pair.get("candidate")
            if isinstance(left, dict) and isinstance(right, dict):
                left_rows = sorted((item.get("test_id"), item.get("status")) for item in left.get("tests", []) if isinstance(item, dict))
                right_rows = sorted((item.get("test_id"), item.get("status")) for item in right.get("tests", []) if isinstance(item, dict))
                if left_rows != right_rows:
                    errors.append(f"library_identity_or_status_mismatch:{receiver}")
                if (normalize_inventory(left.get("excluded")) != normalize_inventory(right.get("excluded"))
                        or normalize_inventory(left.get("skipped")) != normalize_inventory(right.get("skipped"))):
                    errors.append(f"library_skip_or_exclusion_mismatch:{receiver}")
    browser_owners = value.get("browser_owners")
    if not isinstance(browser_owners, dict) or set(browser_owners) != set(OWNERS):
        errors.append("browser_owner_set_incomplete")
    else:
        for owner, pair in browser_owners.items():
            if not validate_pair_shape(pair, errors, "browser", owner):
                continue
            rows_by_role = {}
            for role, row in pair.items():
                if role not in {"control", "candidate"}:
                    continue
                if not isinstance(row, dict) or row.get("exit_code") != 0 or row.get("cleanup_status") != "passed":
                    errors.append(f"browser_owner_failed:{owner}:{role}")
                    continue
                if row.get("source_sha") != (sources.get(role) or {}).get("source_sha"):
                    errors.append(f"browser_source_sha_mismatch:{owner}:{role}")
                identities = row.get("identities")
                if not isinstance(identities, list) or not identities:
                    errors.append(f"browser_identities_missing:{owner}:{role}")
                    continue
                keys = [json.dumps(item.get("identity"), ensure_ascii=False, separators=(",", ":"))
                        for item in identities if isinstance(item, dict)]
                if len(keys) != len(identities) or len(keys) != len(set(keys)):
                    errors.append(f"browser_identity_invalid:{owner}:{role}")
                if any(item.get("owner") != owner or item.get("status") not in {"passed", "skipped"}
                       for item in identities if isinstance(item, dict)):
                    errors.append(f"browser_status_or_owner_invalid:{owner}:{role}")
                if any(item.get("classification") not in {"product", "setup"} or
                       item.get("expected_status") not in {"passed", "skipped"}
                       for item in identities if isinstance(item, dict)):
                    errors.append(f"browser_classification_or_expected_status_invalid:{owner}:{role}")
                if any((item.get("expected_status") == "skipped") != (item.get("status") == "skipped")
                       for item in identities if isinstance(item, dict)):
                    errors.append(f"browser_unexpected_skip:{owner}:{role}")
                expected_skips = sorted(json.dumps(item.get("identity"), ensure_ascii=False, separators=(",", ":"))
                                        for item in identities if isinstance(item, dict) and item.get("status") == "skipped")
                actual_skips = sorted(json.dumps(item, ensure_ascii=False, separators=(",", ":"))
                                      for item in row.get("skipped", []) if isinstance(item, list))
                if expected_skips != actual_skips:
                    errors.append(f"browser_skip_inventory_invalid:{owner}:{role}")
                if report_root is not None:
                    for report in row.get("reports", []):
                        if not verify_report_digest(report, report_root):
                            errors.append(f"browser_report_digest_invalid:{owner}:{role}:{report.get('path')}")
                rows_by_role[role] = sorted((key, item.get("status"), item.get("expected_status"), item.get("classification"))
                                            for key, item in zip(keys, identities))
            left, right = rows_by_role.get("control"), rows_by_role.get("candidate")
            if left is not None and right is not None and left != right:
                errors.append(f"browser_identity_status_or_classification_mismatch:{owner}")
            for field in ("excluded", "skipped"):
                lvalue = pair.get("control", {}).get(field) if isinstance(pair.get("control"), dict) else None
                rvalue = pair.get("candidate", {}).get(field) if isinstance(pair.get("candidate"), dict) else None
                if lvalue != rvalue:
                    errors.append(f"browser_{field}_mismatch:{owner}")
    reports = value.get("reports")
    if not isinstance(reports, list) or len(reports) != 16:
        errors.append("report_manifest_missing")
    else:
        expected = {(kind, role, owner) for kind, owners in (("library", LIBRARY_RECEIVERS), ("browser", OWNERS))
                    for role in ("control", "candidate") for owner in owners}
        actual = set()
        for report in reports:
            if not isinstance(report, dict) or report.get("source_role") not in {"control", "candidate"}:
                errors.append("report_manifest_row_invalid")
                continue
            actual.add((report.get("kind"), report["source_role"], report.get("owner")))
            source = sources.get(report["source_role"], {}) if isinstance(sources, dict) else {}
            if report.get("source_sha") != source.get("source_sha") or not isinstance(report.get("sha256"), str):
                errors.append(f"report_source_or_digest_invalid:{report.get('owner')}")
            if not isinstance(report.get("path"), str) or not isinstance(report.get("report"), dict):
                errors.append(f"report_payload_missing:{report.get('owner')}")
        if actual != expected:
            errors.append("report_manifest_owner_set_invalid")
    return not errors, errors


def selected_rows(report: dict) -> list[dict]:
    """Extract the exact five-field Playwright native identity and terminal status."""
    rows = []

    def visit(suites: list, parents: tuple[str, ...] = ()) -> None:
        for suite in suites:
            title_path = (*parents, suite["title"])
            for spec in suite.get("specs", []):
                for test in spec.get("tests", []):
                    identity = [test["projectId"], spec["file"].replace("\\", "/"), list(title_path), spec["id"], spec["title"]]
                    results = test.get("results") or []
                    if test.get("status") == "skipped" and not results:
                        status = "skipped"
                    elif results:
                        status = results[-1].get("status")
                    else:
                        status = "missing"
                    rows.append({"identity": identity, "project": test.get("projectName"),
                                 "expected_status": test.get("expectedStatus"), "status": status})
            visit(suite.get("suites", []), title_path)

    visit(report.get("suites", []))
    return sorted(rows, key=lambda item: json.dumps(item["identity"], ensure_ascii=False, separators=(",", ":")))


def validate_browser_profile_artifacts(profile: dict, report_root: Path, owner: str, *,
                                       expected_source_sha: str, checkout_source_sha: str,
                                       repo_root: Path = ROOT) -> tuple[list[dict], list[dict], list[str]]:
    errors = []
    if checkout_source_sha != expected_source_sha:
        errors.append("browser_checkout_source_sha_mismatch")
    if profile.get("source_sha") != expected_source_sha:
        errors.append("browser_profile_source_sha_mismatch")
    refs = profile.get("native_reports")
    if not isinstance(refs, list) or not refs:
        return [], [], errors + ["browser_native_reports_missing"]

    root = report_root.resolve()
    base = repo_root.resolve()
    validated = {}
    report_rows = []
    for ref in refs:
        if not isinstance(ref, dict):
            errors.append("browser_native_report_ref_invalid")
            continue
        relative = ref.get("path")
        expected_digest = ref.get("sha256")
        if not isinstance(relative, str) or not relative or Path(relative).is_absolute() or ".." in Path(relative).parts:
            errors.append("browser_native_report_path_invalid")
            continue
        if not isinstance(expected_digest, str) or len(expected_digest) != 64:
            errors.append(f"browser_native_report_digest_missing:{relative}")
            continue
        candidate = root / relative
        if candidate.is_symlink():
            errors.append(f"browser_native_report_symlink:{relative}")
            continue
        path = candidate.resolve()
        try:
            path.relative_to(root)
        except ValueError:
            errors.append(f"browser_native_report_path_outside_root:{relative}")
            continue
        if path.is_symlink() or not path.is_file():
            errors.append(f"browser_native_report_missing:{relative}")
            continue
        actual_digest = sha_file(path)
        if actual_digest != expected_digest:
            errors.append(f"browser_native_report_digest_mismatch:{relative}")
            continue
        if relative in validated:
            errors.append(f"browser_native_report_duplicate_ref:{relative}")
            continue
        try:
            stored_path = str(path.relative_to(base))
        except ValueError:
            errors.append(f"browser_native_report_outside_repository:{relative}")
            continue
        kind = "browser_selection" if path.name.endswith(".selection.json") else "browser_report"
        validated[relative] = path
        report_rows.append({"path": stored_path, "sha256": actual_digest, "kind": kind,
                            "source_sha": profile.get("source_sha"), "owner": owner})

    selections = {}
    reports = {}
    for relative, path in validated.items():
        name = Path(relative).name
        if name.endswith(".selection.json"):
            reports_key = relative[:-len(".selection.json")] + ".json"
            selections[reports_key] = path
        elif name == ".last-run.json":
            continue
        else:
            reports[relative] = path
    if set(reports) != set(selections):
        errors.append("browser_report_selection_pair_mismatch")

    identities = []
    for relative in sorted(set(reports) & set(selections)):
        try:
            result_rows = selected_rows(json.loads(reports[relative].read_text(encoding="utf-8")))
            selection_rows = selected_rows(json.loads(selections[relative].read_text(encoding="utf-8")))
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
            errors.append(f"browser_native_report_parse_failed:{relative}:{type(error).__name__}")
            continue
        result_keys = [(json.dumps(row["identity"], ensure_ascii=False, separators=(",", ":")),
                        row.get("expected_status")) for row in result_rows]
        selection_keys = [(json.dumps(row["identity"], ensure_ascii=False, separators=(",", ":")),
                           row.get("expected_status")) for row in selection_rows]
        result_identities = [row[0] for row in result_keys]
        selection_identities = [row[0] for row in selection_keys]
        if (len(result_identities) != len(set(result_identities))
                or len(selection_identities) != len(set(selection_identities))):
            errors.append(f"browser_selection_or_result_duplicate_identity:{relative}")
        if Counter(result_keys) != Counter(selection_keys):
            errors.append(f"browser_selection_result_identity_or_expected_status_mismatch:{relative}")
        if any(row.get("expected_status") not in {"passed", "skipped"} for row in result_rows + selection_rows):
            errors.append(f"browser_expected_status_invalid:{relative}")
        if any(row.get("status") not in {"passed", "skipped"} for row in result_rows):
            errors.append(f"browser_result_status_invalid:{relative}")
        if any((row.get("expected_status") == "skipped") != (row.get("status") == "skipped")
               for row in result_rows):
            errors.append(f"browser_unexpected_skip:{relative}")
        identities.extend(result_rows)
    return identities, report_rows, errors


def browser_cleanup_succeeded(profile: dict) -> bool:
    cleanup = profile.get("cleanup") or {}
    if cleanup.get("server_stopped") is not True:
        return False
    components = [row for row in (profile.get("components") or []) if isinstance(row, dict)]
    direct = next((row for row in components if row.get("name") == "database-cleanup"), {})
    if direct.get("exit_code") == 0 and direct.get("status") == "measured":
        return True
    recovery = next((row for row in components if row.get("name") == "database-cleanup-recovery"), {})
    return (direct.get("recovered_by") == "database-cleanup-recovery"
            and recovery.get("exit_code") == 0 and recovery.get("status") == "measured")


def native_profile_report_root(scratch: Path, role: str, owner: str) -> Path:
    return scratch / f"native-{role}-{owner}"


def materialize_checkout(role: str, source: dict, scratch: Path, parent_env: dict[str, str]) -> tuple[Path, dict]:
    """Checkout exact Git source, then prove it matches the verified archive bytes."""
    checkout = scratch / f"source-{role}"
    clone = run(["git", "clone", "--quiet", "--shared", "--no-checkout", str(ROOT), str(checkout)],
                cwd=ROOT, env=parent_env, timeout=120)
    require(clone["exit_code"] == 0, f"clone_failed:{role}:{clone['stderr'][-1000:]}")
    selected = run(["git", "-C", str(checkout), "checkout", "--quiet", "--detach", source["source_sha"]],
                   cwd=ROOT, env=parent_env, timeout=120)
    require(selected["exit_code"] == 0, f"source_checkout_failed:{role}:{selected['stderr'][-1000:]}")
    actual_sha = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    tree_sha = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD^{tree}"], text=True).strip()
    require(actual_sha == source["source_sha"], f"checkout_sha_mismatch:{role}")
    require(tree_sha == source["tree_sha"], f"checkout_tree_mismatch:{role}")
    with tarfile.open(source["archive_path"], "r:gz") as archive:
        checked = 0
        archived_paths = set()
        for member in archive.getmembers():
            name = member.name.removeprefix("./")
            if not name:
                continue
            relative = PurePosixPath(name)
            require(not relative.is_absolute() and ".." not in relative.parts, f"archive_member_unsafe:{role}:{name}")
            if member.isdir():
                continue
            require(member.isfile(), f"archive_member_not_regular:{role}:{name}")
            archived_paths.add(str(relative))
            checkout_file = checkout.joinpath(*relative.parts)
            require(checkout_file.is_file() and not checkout_file.is_symlink(), f"archive_file_missing_in_checkout:{role}:{name}")
            body = archive.extractfile(member).read()
            require(checkout_file.read_bytes() == body, f"archive_content_mismatch:{role}:{name}")
            checked += 1
    require(checked > 0, f"archive_has_no_files:{role}")
    tracked = subprocess.check_output(["git", "-C", str(checkout), "ls-tree", "-r", "--name-only", "-z", "HEAD"])
    tracked_paths = {path.decode("utf-8") for path in tracked.split(b"\0") if path and not path.startswith(b".planning/")}
    require(archived_paths == tracked_paths, f"archive_file_inventory_mismatch:{role}")
    status = subprocess.check_output(["git", "-C", str(checkout), "status", "--porcelain=v1", "-z", "--untracked-files=all"])
    require(status == b"", f"source_checkout_dirty:{role}")
    return checkout, {"source_sha": actual_sha, "tree_sha": tree_sha, "clean_before": True,
                      "archive_files_verified": checked, "archive_sha256": source["archive_sha256"]}


def report_library(checkout: Path, role: str, scratch: Path, env: dict[str, str]) -> dict:
    output_root = scratch / f"library-{role}"
    output_root.mkdir(parents=True, exist_ok=True)
    report_path = output_root / "MIX-RECEIVERS.json"
    # The workflow fetches dependencies before the sole `mix ci` owner. Each
    # checkout gets its own build directory but uses the exact locked sources
    # already materialized from the active repository's dependency cache.
    dependency_dir = checkout / "deps"
    if not dependency_dir.exists():
        dependency_dir.symlink_to(ROOT / "deps", target_is_directory=True)
    build_dir = scratch / f"library-build-{role}"
    command = [sys.executable, str(checkout / "scripts/ci/ci-mix-receivers.py"), "--native",
               "--output", str(report_path)]
    native_env = dict(env)
    native_env.update({"MIX_ENV": "test", "PGHOST": env.get("PGHOST", "localhost"),
                       "PGPORT": env.get("PGPORT", "5432"), "PGUSER": env.get("PGUSER", "postgres"),
                       "PGPASSWORD": env.get("PGPASSWORD", "postgres"), "PGDATABASE": "sigra_test",
                       "MIX_BUILD_PATH": str(build_dir)})
    dependency_fetch = run(["mix", "deps.get"], cwd=checkout, env=native_env, timeout=600)
    (scratch / f"library-{role}-deps-get.json").write_text(json.dumps(dependency_fetch, indent=2) + "\n")
    if dependency_fetch["exit_code"] != 0:
        return {"command": command, "exit_code": dependency_fetch["exit_code"], "status": "failed",
                "duration_seconds": dependency_fetch["duration_seconds"], "stderr": dependency_fetch["stderr"],
                "native_report_path": None, "primary_exit_code": dependency_fetch["exit_code"]}
    outcome = run(command, cwd=checkout, env=native_env, timeout=3600)
    native = json.loads(report_path.read_text()) if report_path.is_file() else {}
    normalized = {}
    report_names = {"ordinary": "ordinary", "scaffold": "scaffold", "dep_off": "threadline_guard"}
    for owner, key in report_names.items():
        report = native.get(key) or {}
        relative = (native.get("receiver_reports") or {}).get(key)
        native_runs = sorted(output_root.glob("native-run-*"))
        source_report = native_runs[-1] / relative if relative and native_runs else None
        report_rel = str(source_report.relative_to(ROOT)) if source_report and source_report.is_file() else None
        report_hash = sha_file(source_report) if source_report and source_report.is_file() else None
        tests = [{"test_id": row.get("test_id"), "status": row.get("result")} for row in report.get("tests", [])]
        skipped = [{"test_id": row.get("test_id"), "reason": "ExUnit reported skipped status"}
                   for row in report.get("tests", []) if row.get("result") == "skipped"]
        excluded = [{"test_id": row.get("test_id"), "reason": "ExUnit reported excluded status"}
                    for row in report.get("excluded_tests", []) if isinstance(row, dict) and row.get("test_id")]
        normalized[owner] = {"complete": report.get("complete") is True, "seed": report.get("seed"),
            "tests": tests, "skipped": skipped, "excluded": excluded,
                             "failed_test_ids": report.get("failed_test_ids", []), "path": report_rel,
                             "sha256": report_hash, "report": report, "command": outcome["command"],
                             "exit_code": outcome["exit_code"]}
    outcome["normalized_reports"] = normalized
    outcome["native_report_path"] = str(report_path)
    outcome["native_report_sha256"] = sha_file(report_path) if report_path.is_file() else None
    outcome["primary_exit_code"] = native.get("native_exit_code")
    return outcome


def browser_profile(checkout: Path, role: str, owner: str, scratch: Path, env: dict[str, str],
                    expected_source_sha: str) -> dict:
    output = scratch / f"browser-{role}-{owner}.json"
    command = ["node", str(ROOT / "scripts/ci/ci-prep-profile.mjs"), "--root", str(checkout),
               "--output", str(output), "--scope", owner, "--mode", "workload", "--workload-map", WORKLOAD_MAP,
               "--report-root", str(native_profile_report_root(scratch, role, owner))]
    native_env, _ = browser_workflow_environment(env, checkout, role, owner, scratch)
    result = run(command, cwd=checkout, env=native_env, timeout=1800)
    profile = json.loads(output.read_text()) if output.is_file() else {}
    checkout_source = subprocess.run(["git", "-C", str(checkout), "rev-parse", "HEAD"],
                                     capture_output=True, text=True, check=False)
    checkout_source_sha = checkout_source.stdout.strip() if checkout_source.returncode == 0 else None
    identities, reports, evidence_errors = validate_browser_profile_artifacts(
        profile, output.parent, owner, expected_source_sha=expected_source_sha,
        checkout_source_sha=checkout_source_sha)
    # Assign classification from the actual Playwright project. Setup is selected
    # work too and must remain visible in parity comparisons.
    for row in identities:
        row["owner"] = owner
        row["classification"] = "setup" if str(row.get("project", "")).startswith("admin-design-setup-") else "product"
    expected = len(identities) == len({json.dumps(row["identity"], ensure_ascii=False, separators=(",", ":")) for row in identities})
    cleanup_ok = browser_cleanup_succeeded(profile)
    profile_ok = (profile.get("status") == "profiled" and expected and bool(identities) and cleanup_ok
                  and not evidence_errors and result["exit_code"] == 0)
    failing_components = [component for component in profile.get("components", [])
                          if component.get("exit_code") not in (None, 0)]
    failure_code = result["exit_code"] or next((component.get("exit_code") for component in failing_components), 1)
    return {"command": command, "command_exit_code": result["exit_code"], "exit_code": 0 if profile_ok else failure_code,
            "cleanup_status": "passed" if cleanup_ok else "failed",
            "source_sha": profile.get("source_sha"), "checkout_source_sha": checkout_source_sha,
            "expected_source_sha": expected_source_sha, "evidence_errors": evidence_errors,
            "owner": owner, "status": profile.get("status"),
            "identities": identities, "reports": reports,
            "skipped": sorted(row["identity"] for row in identities if row["status"] == "skipped"),
            "excluded": profile.get("excluded_inventory", []), "profile_path": str(output.relative_to(scratch)),
            "profile_sha256": sha_file(output) if output.is_file() else None,
            "failure": profile.get("failure"), "components": profile.get("components", [])}


def make_report_rows(local: dict) -> list[dict]:
    rows = []
    for receiver, pairs in local.get("library", {}).get("receivers", {}).items():
        for role, data in pairs.items():
            if data.get("path") and data.get("sha256"):
                rows.append({"kind": "library", "source_role": role, "source_sha": data.get("source_sha"),
                             "owner": receiver, "path": data["path"], "sha256": data["sha256"], "report": data.get("report")})
    for owner, pairs in local.get("browser_owners", {}).items():
        for role, data in pairs.items():
            if data.get("report_path") and data.get("report_sha256"):
                rows.append({"kind": "browser", "source_role": role, "source_sha": data.get("source_sha"),
                             "owner": owner, "path": data["report_path"], "sha256": data["report_sha256"],
                             "report": data.get("report")})
    return rows


def compare_library_pair(left: dict | None, right: dict | None) -> dict:
    if not all(isinstance(row, dict) and row.get("complete") is True and row.get("exit_code") == 0
               and isinstance(row.get("tests"), list) and row["tests"] for row in (left, right)):
        return {"status": "blocked", "reason": "missing_incomplete_or_failed_receiver"}
    normalize = lambda row: sorted((item.get("test_id"), item.get("status")) for item in row["tests"])
    same = (normalize(left) == normalize(right)
            and normalize_inventory(left.get("excluded")) == normalize_inventory(right.get("excluded"))
            and normalize_inventory(left.get("skipped")) == normalize_inventory(right.get("skipped")))
    return {"status": "passed" if same else "failed"}


def compare_browser_pair(left: dict | None, right: dict | None) -> dict:
    if not all(isinstance(row, dict) and row.get("exit_code") == 0 and row.get("cleanup_status") == "passed"
               and isinstance(row.get("identities"), list) and row["identities"] for row in (left, right)):
        return {"status": "blocked", "reason": "missing_incomplete_or_failed_owner"}
    normalize = lambda row: sorted((json.dumps(item.get("identity"), ensure_ascii=False, separators=(",", ":")),
                                   item.get("owner"), item.get("classification"), item.get("expected_status"),
                                   item.get("status")) for item in row["identities"])
    same = (normalize(left) == normalize(right) and left.get("skipped") == right.get("skipped")
            and left.get("excluded") == right.get("excluded"))
    return {"status": "passed" if same else "failed"}


def browser_workflow_environment(env: dict[str, str], checkout: Path, role: str, owner: str,
                                scratch: Path) -> tuple[dict[str, str], Path]:
    diagnostic_root = scratch / f"diagnostics-{role}-{owner}"
    runner_temp = scratch / f"runner-temp-{role}-{owner}"
    diagnostic_root.mkdir(mode=0o700, parents=True, exist_ok=False)
    runner_temp.mkdir(mode=0o700, parents=True, exist_ok=False)
    result = dict(env)
    result.update({"GITHUB_WORKSPACE": str(checkout), "RUNNER_TEMP": str(runner_temp),
                   "DIAGNOSTICS_ROOT": str(diagnostic_root), "DIAGNOSTICS_PREFIX": f"repaired-{role}-{owner}",
                   "SIGRA_CI_DIAGNOSTICS": "1", "SIGRA_CI_DIAGNOSTICS_ROOT": str(diagnostic_root),
                   "SIGRA_CI_TRACE_REGISTRY": str(diagnostic_root / "trace-registry.jsonl"),
                   "MATRIX_SEAM": owner, "GITHUB_EVENT_NAME": "pull_request",
                   "SIGRA_CI_INVOCATION_ID": f"{owner}-{role}", "SIGRA_CI_NATIVE_IDENTITY": f"ci:{owner}"})
    return result, diagnostic_root


def source_preflight(checkout: Path, role: str, scratch: Path, env: dict[str, str],
                     native_commands: list[dict]) -> None:
    dependency_dir = checkout / "deps"
    if not dependency_dir.exists():
        dependency_dir.symlink_to(ROOT / "deps", target_is_directory=True)
    format_env = dict(env)
    format_env.update({"MIX_ENV": "test", "MIX_BUILD_PATH": str(ROOT / "_build")})
    format_command = ["mix", "format", "--check-formatted"]
    formatted = run(format_command, cwd=checkout, env=format_env, timeout=300)
    native_commands.append({"kind": "preflight", "source_role": role, "owner": "source_format",
                            "command": format_command, "exit_code": formatted["exit_code"],
                            "status": formatted["status"]})
    require(formatted["exit_code"] == 0, f"source_format_preflight_failed:{role}")

    profile_env, _ = browser_workflow_environment(env, checkout, role, "preflight", scratch)
    profile_command = ["node", str(ROOT / "scripts/ci/ci-prep-profile.mjs"), "--root", str(checkout),
                       "--output", str(scratch / f"preflight-{role}.json"), "--scope", "admin_behavior",
                       "--mode", "workload", "--workload-map", WORKLOAD_MAP, "--check-only"]
    checked = run(profile_command, cwd=checkout, env=profile_env, timeout=120)
    native_commands.append({"kind": "preflight", "source_role": role, "owner": "browser_workflow",
                            "command": profile_command, "exit_code": checked["exit_code"],
                            "status": checked["status"]})
    require(checked["exit_code"] == 0, f"browser_workflow_preflight_failed:{role}")


def build_native(args: argparse.Namespace) -> tuple[dict, int]:
    source_index = Path(args.sources).resolve()
    sources = source_rows(source_index)
    output = Path(args.output).resolve()
    require(not output.exists(), f"refusing_to_overwrite_output:{output}")
    scratch_root = ROOT / ".gsd/255.1-repaired-work"
    scratch_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    scratch = Path(tempfile.mkdtemp(prefix="native-", dir=scratch_root))
    os.chmod(scratch, 0o700)
    process_env = native_process_environment(os.environ, scratch)
    runtime = {"python": sys.version.split()[0], "node": None, "elixir": None, "mix": None}
    for name, command in (("node", ["node", "--version"]), ("elixir", ["elixir", "--version"]), ("mix", ["mix", "--version"])):
        version = run(command, cwd=ROOT, env=process_env, timeout=30)
        runtime[name] = version["stdout"].strip() if version["exit_code"] == 0 else None
    local = {"schema_version": REPORT_SCHEMA, "status": "running", "local_status": "running",
             "hosted_status": "blocked", "hosted_origin_available": False, "acceptance_samples": 0,
             "sources": {}, "library": {"receivers": {}}, "browser_owners": {owner: {} for owner in OWNERS},
             "reports": [], "toolchain": runtime, "native_commands": [], "hosted_delivery_gaps": [
                 "New library receiver reports and their changed terminal-outcome manifest payload have no hosted artifact API producer/run/attempt proof.",
                 "This local comparison does not prove artifact upload, retention, retrieval, or workflow terminal delivery.",
                 "Phase 255 diagnostic canary producer/path contracts remain historical; only the manifest and bundle staging helpers are reused locally.",
             ], "raw_storage": str(scratch.relative_to(ROOT))}
    process_env.setdefault("PGHOST", "localhost")
    process_env.setdefault("PGPORT", "5432")
    process_env.setdefault("PGUSER", "postgres")
    process_env.setdefault("PGPASSWORD", "postgres")
    role_checkouts = {}
    try:
        unavailable = unavailable_native_toolchain(runtime)
        if unavailable:
            local["blocked_prerequisites"] = [f"native_toolchain_unavailable:{name}" for name in unavailable]
            raise ValueError("native_toolchain_unavailable")
        for role in ("control", "candidate"):
            checkout, identity = materialize_checkout(role, sources[role], scratch, process_env)
            role_checkouts[role] = checkout
            local["sources"][role] = identity
        for role in ("control", "candidate"):
            source_preflight(role_checkouts[role], role, scratch, process_env, local["native_commands"])
        for role in ("control", "candidate"):
            checkout = role_checkouts[role]
            result = report_library(checkout, role, scratch, process_env)
            reports = result.get("normalized_reports", {})
            for receiver in LIBRARY_RECEIVERS:
                record = reports.get(receiver)
                if record is not None:
                    record.update(source_sha=sources[role]["source_sha"], command_exit_code=result["exit_code"])
                    local["library"]["receivers"].setdefault(receiver, {})[role] = record
                local["native_commands"].append({"kind": "library", "source_role": role,
                                                 "owner": receiver, "command": result["command"],
                                                 "exit_code": result["exit_code"], "duration_seconds": result["duration_seconds"],
                                                 "status": result["status"], "primary_exit_code": result.get("primary_exit_code"),
                                                 "native_report_sha256": result.get("native_report_sha256"),
                                                 "stderr": result["stderr"][-2000:]})
            for owner in OWNERS:
                result = browser_profile(checkout, role, owner, scratch, process_env,
                                         expected_source_sha=sources[role]["source_sha"])
                # One normalized row per actual owner invocation, with every
                # native report identity retained. Keep the raw report refs too.
                browser_report = {"complete": result["exit_code"] == 0,
                                  "tests": [{"identity": item["identity"], "owner": owner,
                                             "classification": item["classification"],
                                             "expected_status": item["expected_status"],
                                             "result": item["status"]}
                                            for item in result["identities"]],
                                  "skipped": [{"identity": item["identity"], "reason": "Playwright reported skipped status"}
                                              for item in result["identities"] if item["status"] == "skipped"],
                                  "excluded": result["excluded"]}
                normalized_path = scratch / f"browser-{role}-{owner}.normalized.json"
                normalized_path.write_text(json.dumps(browser_report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                result["report_path"] = str(normalized_path.relative_to(ROOT))
                result["report_sha256"] = sha_file(normalized_path)
                result["report"] = browser_report
                local["browser_owners"][owner][role] = result
                local["native_commands"].append({"kind": "browser", "source_role": role,
                                                 "owner": owner, "command": result["command"],
                                                 "exit_code": result["exit_code"], "status": result["status"],
                                                 "profile_sha256": result.get("profile_sha256"),
                                                 "failure": result.get("failure")})
        for receiver, pair in local["library"]["receivers"].items():
            pair["comparison"] = compare_library_pair(pair.get("control"), pair.get("candidate"))
        for owner, pair in local["browser_owners"].items():
            left, right = pair.get("control"), pair.get("candidate")
            comparison = compare_browser_pair(left, right)
            pair["comparison"] = {**comparison,
                                   "before_rows": len(left.get("identities", [])) if isinstance(left, dict) else 0,
                                   "after_rows": len(right.get("identities", [])) if isinstance(right, dict) else 0,
                                   "before_setup_rows": sum(1 for row in left.get("identities", []) if str(row.get("project", "")).startswith("admin-design-setup-")) if isinstance(left, dict) else 0,
                                   "after_setup_rows": sum(1 for row in right.get("identities", []) if str(row.get("project", "")).startswith("admin-design-setup-")) if isinstance(right, dict) else 0}
        local["reports"] = make_report_rows(local)
        ok, errors = validate_equivalent_work(local)
        local["validation_errors"] = errors
        local["local_status"] = "passed" if ok else "blocked"
        local["status"] = "passed" if ok else "blocked"
    except Exception as error:
        local["status"] = "blocked"
        local["local_status"] = "blocked"
        local.setdefault("validation_errors", []).append(f"native_harness_error:{type(error).__name__}:{error}")
    finally:
        local["completed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        local["reports"] = make_report_rows(local)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(local, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return local, 0 if local["local_status"] == "passed" else 1


class RepairedWorkContractTest(unittest.TestCase):
    def fixture(self):
        source = {"control": {"source_sha": "a" * 40, "archive_sha256": "1" * 64},
                  "candidate": {"source_sha": "b" * 40, "archive_sha256": "2" * 64}}
        report = {"path": "report.json", "sha256": "3" * 64, "complete": True, "seed": 123,
                  "exit_code": 0, "excluded": [{"test_id": "M.excluded", "reason": "excluded"}],
                  "skipped": [{"test_id": "M.skip", "reason": "expected skip"}],
                  "tests": [{"test_id": "M.case", "status": "passed"}, {"test_id": "M.skip", "status": "skipped"}]}
        browser = {"exit_code": 0, "cleanup_status": "passed", "source_sha": "a" * 40,
                   "identities": [{"owner": OWNERS[0], "identity": ["chromium", "a.spec.ts", ["suite"], "id", "title"],
                                   "status": "passed", "expected_status": "passed", "classification": "product"}],
                   "reports": [] , "skipped": [], "excluded": []}
        browser_candidate = json.loads(json.dumps(browser))
        browser_candidate["source_sha"] = "b" * 40
        return {"schema_version": REPORT_SCHEMA, "status": "passed", "local_status": "passed", "hosted_status": "blocked",
                "hosted_origin_available": False, "acceptance_samples": 0, "sources": source,
                "library": {"receivers": {name: {"control": json.loads(json.dumps(report)),
                                                   "candidate": json.loads(json.dumps(report)),
                                                   "comparison": {"status": "passed"}}
                                                  for name in LIBRARY_RECEIVERS}},
                "browser_owners": {owner: {
                    "control": dict(browser, owner=owner, identities=[dict(browser["identities"][0], owner=owner)]),
                    "candidate": dict(browser_candidate, owner=owner, identities=[dict(browser_candidate["identities"][0], owner=owner)]),
                    "comparison": {"status": "passed"}}
                    for owner in OWNERS},
                "reports": ([{"kind": "library", "source_role": role, "source_sha": source[role]["source_sha"],
                               "owner": owner, "path": "report.json", "sha256": "3" * 64, "report": report}
                              for role in source for owner in LIBRARY_RECEIVERS] +
                            [{"kind": "browser", "source_role": role, "source_sha": source[role]["source_sha"],
                              "owner": owner, "path": "browser.json", "sha256": "4" * 64,
                              "report": {"complete": True, "tests": [{"identity": ["chromium", "a.spec.ts", ["suite"], "id", "title"],
                                         "owner": owner, "classification": "product", "expected_status": "passed", "result": "passed"}],
                                         "skipped": [], "excluded": []}}
                             for role in source for owner in OWNERS])}

    def test_accepts_matching_complete_local_work_but_keeps_hosted_blocked(self):
        ok, errors = validate_equivalent_work(self.fixture())
        self.assertTrue(ok, errors)

    def test_full_native_report_shape_accepts_comparison_and_rejects_unknown_pair_role(self):
        value = self.fixture()
        self.assertTrue(all(pair["comparison"]["status"] == "passed"
                            for pair in value["library"]["receivers"].values()))
        self.assertTrue(all(pair["comparison"]["status"] == "passed"
                            for pair in value["browser_owners"].values()))
        ok, errors = validate_equivalent_work(value)
        self.assertTrue(ok, errors)
        value["library"]["receivers"]["ordinary"]["unexpected_role"] = {}
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn("library_source_pair_invalid:ordinary", errors)

    def test_rejects_missing_library_receiver_seed_or_identity(self):
        value = self.fixture()
        del value["library"]["receivers"]["ordinary"]["control"]["seed"]
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn("library_report_incomplete:ordinary:control", errors)

    def test_library_validator_ignores_row_order_and_rejects_duplicate_exclusion_identity(self):
        value = self.fixture()
        for pair in value["library"]["receivers"].values():
            candidate = pair["candidate"]
            for key in ("tests", "excluded", "skipped"):
                candidate[key].reverse()
        ok, errors = validate_equivalent_work(value)
        self.assertTrue(ok, errors)
        value["library"]["receivers"]["ordinary"]["control"]["excluded"].append(
            dict(value["library"]["receivers"]["ordinary"]["control"]["excluded"][0]))
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn("library_skip_or_exclusion_duplicate:ordinary:control", errors)

    def test_rejects_library_status_mismatch_and_unexpected_skip(self):
        value = self.fixture()
        value["library"]["receivers"]["ordinary"]["candidate"]["tests"][0]["status"] = "skipped"
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn("library_identity_or_status_mismatch:ordinary", errors)

    def test_rejects_wrong_source_origin_digest_and_attempt_to_claim_hosted_proof(self):
        value = self.fixture()
        value["reports"][0]["source_sha"] = "c" * 40
        value["hosted_status"] = "ready"
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn("local_record_claims_hosted_origin", errors)
        self.assertIn("report_source_or_digest_invalid:ordinary", errors)

    def test_rejects_browser_project_identity_status_owner_and_skip_drift(self):
        value = self.fixture()
        value["browser_owners"][OWNERS[0]]["candidate"]["identities"][0]["identity"][0] = "mobile"
        value["browser_owners"][OWNERS[0]]["candidate"]["identities"][0]["status"] = "skipped"
        ok, errors = validate_equivalent_work(value)
        self.assertFalse(ok)
        self.assertIn(f"browser_identity_status_or_classification_mismatch:{OWNERS[0]}", errors)

    def test_incomplete_or_failed_native_pairs_are_blocked_not_reported_as_matching(self):
        self.assertEqual(compare_library_pair(None, None)["status"], "blocked")
        self.assertEqual(compare_library_pair({"complete": True, "exit_code": 1, "tests": []},
                                              {"complete": True, "exit_code": 1, "tests": []})["status"], "blocked")
        self.assertEqual(compare_browser_pair(None, None)["status"], "blocked")
        self.assertEqual(compare_browser_pair({"exit_code": 2, "cleanup_status": "failed", "identities": []},
                                              {"exit_code": 2, "cleanup_status": "failed", "identities": []})["status"], "blocked")

    def test_browser_cleanup_requires_server_stop_and_successful_drop_or_recovery(self):
        self.assertFalse(browser_cleanup_succeeded({
            "cleanup": {"server_stopped": True, "database_drop_recorded": True},
            "components": [{"name": "database-cleanup", "status": "failed", "exit_code": 1}],
        }))
        self.assertTrue(browser_cleanup_succeeded({
            "cleanup": {"server_stopped": True},
            "components": [{"name": "database-cleanup", "status": "measured", "exit_code": 0}],
        }))
        self.assertTrue(browser_cleanup_succeeded({
            "cleanup": {"server_stopped": True},
            "components": [{"name": "database-cleanup", "status": "failed", "exit_code": 1,
                            "recovered_by": "database-cleanup-recovery"},
                           {"name": "database-cleanup-recovery", "status": "measured", "exit_code": 0}],
        }))
        self.assertFalse(browser_cleanup_succeeded({
            "cleanup": {"server_stopped": False},
            "components": [{"name": "database-cleanup", "status": "measured", "exit_code": 0}],
        }))

    def test_each_source_owner_gets_an_isolated_native_report_root(self):
        with tempfile.TemporaryDirectory() as directory:
            roots = [native_profile_report_root(Path(directory), role, owner)
                     for role in ("control", "candidate") for owner in OWNERS]
        self.assertEqual(len(roots), len(set(roots)))
        self.assertTrue(all(root.parent == Path(directory) for root in roots))

    def test_native_environment_preserves_linux_or_macos_caller_toolchain(self):
        paths = (
            "/opt/hostedtoolcache/node/20.19.5/bin:/opt/elixir/bin:/usr/bin:/bin",
            "/Users/example/.asdf/installs/nodejs/20.19.5/bin:/opt/homebrew/bin:/usr/bin:/bin",
        )
        for path in paths:
            with self.subTest(path=path), tempfile.TemporaryDirectory() as directory:
                scratch = Path(directory)
                supplied_hex = str(scratch / "caller-hex")
                environment = native_process_environment({"PATH": path, "HEX_HOME": supplied_hex}, scratch)
                self.assertEqual(environment["PATH"], path)
                self.assertEqual(environment["HEX_HOME"], supplied_hex)
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory)
            defaulted = native_process_environment({"PATH": "/opt/bin:/usr/bin"}, scratch)
            self.assertEqual(defaulted["HEX_HOME"], str(scratch / "hex-home"))
            self.assertTrue((scratch / "hex-home").is_dir())
        self.assertEqual(unavailable_native_toolchain({"node": None, "elixir": "1.19.5", "mix": None}),
                         ["node", "mix"])

    def test_browser_extractor_checks_source_selection_identity_status_and_digests(self):
        with tempfile.TemporaryDirectory() as directory:
            repo_root = Path(directory)
            report_root = repo_root / "reports"
            report_root.mkdir()
            sha_bytes = lambda value: digest(value)
            identity = {"projectId": "chromium", "projectName": "chromium", "file": "tests/a.spec.ts",
                        "id": "spec-1", "title": "case", "expectedStatus": "passed",
                        "status": "expected", "results": [{"status": "passed"}]}

            def report_for(tests):
                tests = tests if isinstance(tests, list) else [tests]
                test = tests[0] if tests else identity
                return {"suites": [{"title": "Suite", "specs": [{"file": test["file"], "id": test["id"],
                        "title": test["title"], "tests": tests}]}]}

            def extract(selection_test=None, result_test=None, selection_tests=None, result_tests=None, *, source_sha="a" * 40,
                        checkout_sha="a" * 40, selection_ref=True, bad_digest=False):
                selection_test = selection_test or dict(identity, status="expected", results=[])
                result_test = result_test or dict(identity)
                selection_tests = selection_tests if selection_tests is not None else [selection_test]
                result_tests = result_tests if result_tests is not None else [result_test]
                result_path = report_root / "admin_behavior.json"
                selection_path = report_root / "admin_behavior.selection.json"
                result_bytes = json.dumps(report_for(result_tests)).encode()
                selection_bytes = json.dumps(report_for(selection_tests)).encode()
                result_path.write_bytes(result_bytes)
                selection_path.write_bytes(selection_bytes)
                refs = [{"path": result_path.name, "sha256": sha_bytes(result_bytes)}]
                if selection_ref:
                    refs.append({"path": selection_path.name,
                                 "sha256": ("0" * 64) if bad_digest else sha_bytes(selection_bytes)})
                return validate_browser_profile_artifacts(
                    {"source_sha": source_sha, "native_reports": refs}, report_root, "admin_behavior",
                    expected_source_sha="a" * 40, checkout_source_sha=checkout_sha, repo_root=repo_root)

            rows, refs, errors = extract()
            self.assertEqual(len(rows), 1)
            self.assertEqual({row["kind"] for row in refs}, {"browser_report", "browser_selection"})
            self.assertEqual(errors, [])
            self.assertIn("browser_profile_source_sha_mismatch", extract(source_sha="b" * 40)[2])
            self.assertIn("browser_checkout_source_sha_mismatch", extract(checkout_sha="b" * 40)[2])
            self.assertIn("browser_report_selection_pair_mismatch", extract(selection_ref=False)[2])
            self.assertTrue(any("digest_mismatch" in error for error in extract(bad_digest=True)[2]))
            wrong_expected = dict(identity, expectedStatus="skipped", status="expected", results=[])
            self.assertIn("browser_selection_result_identity_or_expected_status_mismatch",
                          extract(selection_test=wrong_expected)[2][0])
            self.assertTrue(any("identity_or_expected_status_mismatch" in error
                                for error in extract(result_tests=[])[2]))
            extra = dict(identity, id="spec-extra", title="extra")
            self.assertTrue(any("identity_or_expected_status_mismatch" in error
                                for error in extract(result_tests=[dict(identity), extra])[2]))
            duplicate = {"suites": [{"title": "Suite", "specs": [{"file": identity["file"], "id": identity["id"],
                         "title": identity["title"], "tests": [dict(identity), dict(identity)]}]}]}
            duplicate_path = report_root / "admin_behavior.json"
            duplicate_bytes = json.dumps(duplicate).encode()
            duplicate_path.write_bytes(duplicate_bytes)
            refs = [{"path": duplicate_path.name, "sha256": sha_bytes(duplicate_bytes)},
                    {"path": "admin_behavior.selection.json",
                     "sha256": sha_bytes((report_root / "admin_behavior.selection.json").read_bytes())}]
            _, _, duplicate_errors = validate_browser_profile_artifacts(
                {"source_sha": "a" * 40, "native_reports": refs}, report_root, "admin_behavior",
                expected_source_sha="a" * 40, checkout_source_sha="a" * 40, repo_root=repo_root)
            self.assertTrue(any("duplicate_identity" in error for error in duplicate_errors))

    def test_library_comparison_ignores_seed_order_but_preserves_exclusion_and_skip_identity(self):
        left = {"complete": True, "exit_code": 0,
                "tests": [{"test_id": "M.first", "status": "passed"},
                          {"test_id": "M.skip", "status": "skipped"}],
                "excluded": [{"test_id": "M.excluded-a", "reason": "excluded"},
                             {"test_id": "M.excluded-b", "reason": "excluded"}],
                "skipped": [{"test_id": "M.skip", "reason": "expected skip"}]}
        right = {"complete": True, "exit_code": 0,
                 "tests": list(reversed(left["tests"])),
                 "excluded": list(reversed(left["excluded"])),
                 "skipped": list(reversed(left["skipped"]))}
        self.assertEqual(compare_library_pair(left, right)["status"], "passed")
        right["excluded"] = [dict(item) for item in right["excluded"]]
        right["excluded"][0]["test_id"] = "M.different-excluded"
        self.assertEqual(compare_library_pair(left, right)["status"], "failed")
        right = {**left, "tests": list(left["tests"]), "excluded": list(left["excluded"]),
                 "skipped": list(left["skipped"])}
        right["tests"].pop()
        self.assertEqual(compare_library_pair(left, right)["status"], "failed")
        right = {**left, "tests": list(left["tests"]), "excluded": list(left["excluded"]),
                 "skipped": list(left["skipped"])}
        right["tests"].append(dict(right["tests"][0]))
        self.assertEqual(compare_library_pair(left, right)["status"], "failed")
        right = {**left, "tests": [dict(item) for item in left["tests"]],
                 "excluded": list(left["excluded"]), "skipped": list(left["skipped"])}
        right["tests"][0]["status"] = "failed"
        self.assertEqual(compare_library_pair(left, right)["status"], "failed")

    def test_browser_workflow_environment_matches_recorded_action_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            checkout = Path(directory) / "source"
            scratch = Path(directory) / "scratch"
            checkout.mkdir()
            scratch.mkdir(mode=0o700)
            env, diagnostic_root = browser_workflow_environment({}, checkout, "control", "admin_behavior", scratch)
            self.assertEqual(env["GITHUB_WORKSPACE"], str(checkout))
            self.assertEqual(env["RUNNER_TEMP"], str(scratch / "runner-temp-control-admin_behavior"))
            self.assertEqual(env["DIAGNOSTICS_ROOT"], str(diagnostic_root))
            self.assertEqual(env["DIAGNOSTICS_PREFIX"], "repaired-control-admin_behavior")
            self.assertEqual(env["SIGRA_CI_DIAGNOSTICS_ROOT"], str(diagnostic_root))
            self.assertEqual(env["SIGRA_CI_TRACE_REGISTRY"], str(diagnostic_root / "trace-registry.jsonl"))
            self.assertEqual(env["MATRIX_SEAM"], "admin_behavior")
            self.assertEqual(env["GITHUB_EVENT_NAME"], "pull_request")


def main(argv: list[str]) -> int:
    if argv[:1] == ["--native"]:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--native", action="store_true")
        parser.add_argument("--sources", required=True)
        parser.add_argument("--output", required=True)
        args = parser.parse_args(argv)
        value, code = build_native(args)
        print(json.dumps({"status": value.get("status"), "local_status": value.get("local_status"),
                          "hosted_status": value.get("hosted_status"), "acceptance_samples": 0,
                          "output": args.output, "validation_errors": value.get("validation_errors", [])}, sort_keys=True))
        return code
    unittest.main(argv=[sys.argv[0]], verbosity=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
