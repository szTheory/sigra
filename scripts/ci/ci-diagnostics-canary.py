#!/usr/bin/env python3
"""Freeze, charge, run, retrieve, and verify a bounded CI diagnostics canary."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone


SCHEMA = "sigra.ci-diagnostics-canary/v1"
HARD_LIMITS = {
    "max_invocations": 4,
    "max_controller_requests": 120,
    "max_elapsed_seconds": 3600,
    "max_pushes": 2,
    "max_infrastructure_retries": 1,
    "max_test_retries": 0,
}
REPOSITORY = "szTheory/sigra"
WORKFLOW = ".github/workflows/release-receipt-canary.yml"
ACTION = ".github/actions/ci-diagnostic-upload/action.yml"
BOOT_ACTION = ".github/actions/example-playwright-boot/action.yml"
CONTROLLER = "scripts/ci/ci-diagnostics-canary.py"
BUNDLE_HELPER = "scripts/ci/ci-diagnostic-bundle.py"
BROWSER_COMMAND = "scripts/ci/ci-browser-command.mjs"
SCENARIOS = {"success", "failure", "cancellation"}


class CanaryError(RuntimeError):
    pass


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def git(root: pathlib.Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=root, check=False, capture_output=True, text=True)
    if result.returncode:
        raise CanaryError(f"git_{args[0]}_failed:{result.stderr.strip()}")
    return result.stdout.strip()


def local_evidence_preflight(root: pathlib.Path) -> dict:
    """Verify the previously created evidence blob and its exact local ref read-back."""
    ref = "refs/evidence/phase255-local-evidence-preflight"
    object_sha = git(root, "rev-parse", "--verify", ref)
    object_type = git(root, "cat-file", "-t", object_sha)
    if object_type != "blob":
        raise CanaryError("local_evidence_preflight_not_blob")
    payload = subprocess.run(["git", "cat-file", "-p", object_sha], cwd=root,
                             check=False, capture_output=True)
    if payload.returncode:
        raise CanaryError("local_evidence_preflight_readback_failed")
    recomputed = subprocess.run(["git", "hash-object", "--stdin"], cwd=root,
                                input=payload.stdout, check=False, capture_output=True)
    if recomputed.returncode or recomputed.stdout.decode("ascii", "strict").strip() != object_sha:
        raise CanaryError("local_evidence_preflight_hash_mismatch")
    return {"ref": ref, "expected_old_oid": "0" * len(object_sha), "object_type": object_type,
            "object_sha": object_sha, "readback_sha256": sha256_bytes(payload.stdout),
            "readback_bytes": len(payload.stdout), "readback_exact": True}


def file_digest(root: pathlib.Path, relative: str) -> str:
    path = root / relative
    if path.is_symlink() or not path.is_file():
        raise CanaryError(f"source_file_missing_or_symlink:{relative}")
    return sha256_bytes(path.read_bytes())


def safe_owned_path(root: pathlib.Path, relative: str) -> pathlib.Path:
    pure = pathlib.PurePosixPath(relative)
    if (not relative or "\\" in relative or pure.is_absolute() or pure.as_posix() != relative
            or any(part in {"", ".", ".."} for part in pure.parts)):
        raise CanaryError(f"manifest_path_invalid:{relative}")
    candidate = root
    for part in pure.parts:
        candidate = candidate / part
        if candidate.is_symlink():
            raise CanaryError(f"manifest_symlink_rejected:{relative}")
    resolved = candidate.resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise CanaryError(f"manifest_path_invalid:{relative}")
    return resolved


def source_identity(root: pathlib.Path, source_sha: str | None = None) -> dict:
    source_sha = source_sha or git(root, "rev-parse", "HEAD")
    tree = git(root, "rev-parse", f"{source_sha}^{{tree}}")
    files = {path: file_digest(root, path) for path in (".github/workflows/ci.yml", ACTION, BOOT_ACTION,
        CONTROLLER, BUNDLE_HELPER, BROWSER_COMMAND)}
    return {"source_sha": source_sha, "tree": tree, "files": files}


def atomic_json(path: pathlib.Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        pathlib.Path(name).unlink(missing_ok=True)


def write_manifest(invocation_root: pathlib.Path, output: pathlib.Path, identity: dict,
                   file_specs: list[str], trace_registry: pathlib.Path | None = None,
                   synthetic_account: bool = False) -> dict:
    """Write an explicit, hashed file allowlist; absent outputs remain recorded as missing."""
    root = pathlib.Path(invocation_root).resolve()
    required = ("invocation_id", "source_sha", "run_id", "run_attempt", "job_id", "seam")
    if any(not isinstance(identity.get(key), (str, int)) or str(identity.get(key)) == "" for key in required):
        raise CanaryError("invocation_identity_incomplete")
    if not re.fullmatch(r"[0-9a-f]{40}(?:[0-9a-f]{24})?", str(identity["source_sha"])):
        raise CanaryError("source_sha_invalid")
    entries, missing, seen = [], [], set()
    trace_paths = []
    for spec in file_specs:
        if "=" not in spec:
            raise CanaryError("file_spec_invalid")
        relative, kind = spec.rsplit("=", 1)
        if kind not in {"log", "command_stdout", "command_stderr", "cleanup_stdout", "cleanup_stderr", "report", "trace", "auth"}:
            raise CanaryError(f"manifest_file_kind_invalid:{kind}")
        path = safe_owned_path(root, relative)
        if not path.exists():
            missing.append(relative)
            continue
        if not path.is_file():
            raise CanaryError(f"manifest_path_invalid:{relative}")
        if relative in seen:
            raise CanaryError(f"manifest_duplicate_path:{relative}")
        seen.add(relative)
        entries.append({"path": relative, "kind": kind, "sha256": sha256_bytes(path.read_bytes())})
    synthetic_trace = False
    if trace_registry is not None:
        registry = pathlib.Path(trace_registry)
        if not registry.is_absolute():
            registry = root / registry
        if registry.is_symlink() or not registry.resolve().is_relative_to(root):
            raise CanaryError("trace_registry_path_invalid")
        if registry.exists():
            for line_number, line in enumerate(registry.read_text(encoding="utf-8").splitlines(), 1):
                if not line.strip():
                    continue
                try:
                    registration = json.loads(line)
                except ValueError:
                    raise CanaryError(f"trace_registry_line_invalid:{line_number}") from None
                trace_path = registration.get("path")
                if registration.get("registered") is not True or registration.get("synthetic_account") is not True or not isinstance(trace_path, str):
                    continue
                raw_candidate = (registry.parent / trace_path)
                try:
                    relative = raw_candidate.relative_to(root)
                except ValueError:
                    raise CanaryError(f"registered_trace_path_invalid:{trace_path}") from None
                candidate = safe_owned_path(root, relative.as_posix())
                if not candidate.is_file():
                    raise CanaryError(f"registered_trace_path_invalid:{trace_path}")
                relative = candidate.relative_to(root).as_posix()
                if relative in seen:
                    raise CanaryError(f"manifest_duplicate_path:{relative}")
                seen.add(relative)
                entries.append({"path": relative, "kind": "trace", "sha256": sha256_bytes(candidate.read_bytes())})
                trace_paths.append(relative)
                synthetic_trace = True
    if (synthetic_trace or synthetic_account) and "native-report.json" in seen:
        report_path = root / "native-report.json"
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            raise CanaryError(f"native_report_unreadable:{error}") from None
        pending = list(report.get("suites") or [])
        while pending:
            suite = pending.pop()
            pending.extend(suite.get("suites") or [])
            for spec in suite.get("specs") or []:
                for test in spec.get("tests") or []:
                    for result in test.get("results") or []:
                        for attachment in result.get("attachments") or []:
                            if attachment.get("name") != "trace" or attachment.get("contentType") != "application/zip":
                                continue
                            raw_path = attachment.get("path")
                            if not isinstance(raw_path, str):
                                continue
                            candidate = pathlib.Path(raw_path)
                            try:
                                relative = candidate.relative_to(root) if candidate.is_absolute() else candidate
                            except ValueError:
                                raise CanaryError(f"native_report_trace_path_invalid:{raw_path}") from None
                            candidate = safe_owned_path(root, relative.as_posix())
                            if not candidate.is_file():
                                raise CanaryError(f"native_report_trace_path_invalid:{raw_path}")
                            relative = candidate.relative_to(root).as_posix()
                            if relative not in seen:
                                seen.add(relative)
                                entries.append({"path": relative, "kind": "trace", "sha256": sha256_bytes(candidate.read_bytes())})
                                trace_paths.append(relative)
    value = {"schema_version": "sigra.ci-diagnostic-invocation/v1", **identity, "files": entries,
        "missing_files": missing, "trace_provenance": {"synthetic_account": synthetic_trace or (synthetic_account and bool(trace_paths)),
             "registered": bool(trace_paths)}, "trace_unavailable_reason": None, "created_at": utc_now()}
    atomic_json(output, value)
    return value


def load_freeze(path: pathlib.Path) -> dict:
    if path.is_symlink():
        raise CanaryError("freeze_symlink_rejected")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise CanaryError(f"freeze_unreadable:{error}") from None
    if not isinstance(data, dict) or data.get("schema_version") != SCHEMA:
        raise CanaryError("freeze_schema_invalid")
    limits = data.get("limits")
    if not isinstance(limits, dict) or any(limits.get(key) != value for key, value in HARD_LIMITS.items()):
        raise CanaryError("freeze_limits_invalid")
    return data


def freeze_canary(root: pathlib.Path, output: pathlib.Path, evidence_ref: str, fixture_commit: str,
                  fixture_sha256: str, initial_rate_read: dict | None = None) -> dict:
    """Bind the unchanged production code and fixture overlay to the finite allowance."""
    root = pathlib.Path(root).resolve()
    production = source_identity(root)
    for path, digest in production["files"].items():
        committed = subprocess.run(["git", "show", f"{production['source_sha']}:{path}"], cwd=root,
                                   check=False, capture_output=True)
        if committed.returncode or sha256_bytes(committed.stdout) != digest:
            raise CanaryError(f"working_source_differs_from_commit:{path}")
    if git(root, "rev-parse", f"{fixture_commit}^{{commit}}") != fixture_commit:
        raise CanaryError("fixture_commit_missing")
    if not re.fullmatch(r"[0-9a-f]{64}", fixture_sha256):
        raise CanaryError("fixture_workflow_sha256_invalid")
    fixture_bytes = subprocess.run(["git", "show", f"{fixture_commit}:{WORKFLOW}"], cwd=root,
                                   check=False, capture_output=True)
    if fixture_bytes.returncode or sha256_bytes(fixture_bytes.stdout) != fixture_sha256:
        raise CanaryError("fixture_workflow_hash_mismatch")
    if not re.fullmatch(r"refs/heads/evidence/phase255-[A-Za-z0-9._/-]+", evidence_ref):
        raise CanaryError("evidence_ref_outside_phase255_namespace")
    freeze = {
        "schema_version": SCHEMA,
        "frozen_at": utc_now(),
        "repository": REPOSITORY,
        "source_identity": production,
        "local_evidence_preflight": local_evidence_preflight(root),
        "fixture": {
            "commit": fixture_commit,
            "workflow": WORKFLOW,
            "workflow_sha256": fixture_sha256,
            "evidence_ref": evidence_ref,
            "publishing": False,
            "write_content_token": False,
            "secrets": [],
        },
        "limits": dict(HARD_LIMITS),
        "usage": {
            "invocations": 0,
            "controller_requests": 1,
            "pushes": 0,
            "infrastructure_retries": 0,
            "test_retries": 0,
            "elapsed_started_at": None,
            "charges": [{"operation": "precondition-rate-limit-read", "at": None,
                         "request": True, "precharged_before_freeze": False,
                         "reported_remaining": 4051 if initial_rate_read is None else initial_rate_read.get("remaining"),
                         "raw_receipt_available": False}],
            "precondition_rate_read": initial_rate_read or {
                "reported_remaining": 4051,
                "raw_receipt": None,
                "observed_at": None,
                "verified": False,
                "provenance": "executor summary from the earlier precondition rate read; exact HTTP receipt and timestamp unavailable",
            },
        },
        "deadline": None,
    }
    atomic_json(output, freeze)
    return freeze


def assert_source_identity(freeze: dict, root: pathlib.Path) -> None:
    expected = freeze["source_identity"]
    sha = expected["source_sha"]
    if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "HEAD"], cwd=root, check=False).returncode:
        raise CanaryError("production_source_commit_not_ancestor")
    for path, digest in expected["files"].items():
        committed = subprocess.run(["git", "show", f"{sha}:{path}"], cwd=root, check=False, capture_output=True)
        if committed.returncode or sha256_bytes(committed.stdout) != digest or file_digest(root, path) != digest:
            raise CanaryError(f"production_source_file_changed:{path}")


def charge_request(freeze_path: pathlib.Path, operation: str, *, invocation: bool = False,
                   infrastructure_retry: bool = False, push: bool = False,
                   test_retry: bool = False, scenario: str | None = None,
                   now_epoch: float | None = None) -> dict:
    """Persist the charge before the corresponding network operation starts."""
    data = load_freeze(freeze_path)
    usage, limits = data["usage"], data["limits"]
    now_epoch = time.time() if now_epoch is None else now_epoch
    if usage["controller_requests"] >= limits["max_controller_requests"]:
        raise CanaryError("controller_request_budget_exhausted")
    if invocation and usage["invocations"] >= limits["max_invocations"]:
        raise CanaryError("fixture_invocation_budget_exhausted")
    if infrastructure_retry and usage["infrastructure_retries"] >= limits["max_infrastructure_retries"]:
        raise CanaryError("infrastructure_retry_budget_exhausted")
    if test_retry and usage["test_retries"] >= limits["max_test_retries"]:
        raise CanaryError("test_retry_budget_exhausted")
    if push and usage["pushes"] >= limits["max_pushes"]:
        raise CanaryError("push_budget_exhausted")
    if usage["elapsed_started_at"] is None:
        usage["elapsed_started_at"] = now_epoch
        data["deadline"] = datetime.fromtimestamp(now_epoch + limits["max_elapsed_seconds"], timezone.utc).isoformat(timespec="seconds")
    if now_epoch - float(usage["elapsed_started_at"]) >= limits["max_elapsed_seconds"]:
        raise CanaryError("elapsed_time_budget_exhausted")
    charge = {"operation": operation, "at": utc_now(), "request": True,
              "invocation": invocation, "infrastructure_retry": infrastructure_retry,
              "push": push, "test_retry": test_retry, "scenario": scenario}
    usage["controller_requests"] += 1
    if invocation:
        usage["invocations"] += 1
    if infrastructure_retry:
        usage["infrastructure_retries"] += 1
    if push:
        usage["pushes"] += 1
    if test_retry:
        usage["test_retries"] += 1
    usage["charges"].append(charge)
    atomic_json(freeze_path, data)
    return charge


def record_rate_observation(freeze_path: pathlib.Path, operation: str, receipt: dict,
                            remaining: int | None, raw_body: str | None = None) -> dict:
    """Retain the exact, non-secret rate response after its request was precharged."""
    data = load_freeze(freeze_path)
    charges = data["usage"]["charges"]
    match = next((item for item in reversed(charges) if item.get("operation") == operation
                  and item.get("response") is None), None)
    if match is None:
        raise CanaryError("rate_response_without_precharge")
    match["response"] = receipt
    match["raw_receipt"] = raw_body
    match["response_remaining_header"] = remaining
    match["response_observed_at"] = utc_now()
    atomic_json(freeze_path, data)
    return match


def verify_run_identity(expected: dict, run: dict) -> dict:
    """Require an actual workflow run on the frozen overlay with a unique attempt."""
    required = {"id", "run_attempt", "head_sha", "head_branch", "path", "status", "conclusion", "display_title"}
    if not isinstance(run, dict) or not required.issubset(run):
        raise CanaryError("run_identity_incomplete")
    if run["head_sha"] != expected["fixture"]["commit"]:
        raise CanaryError("run_fixture_commit_mismatch")
    if run["head_branch"] != expected["fixture"]["evidence_ref"].removeprefix("refs/heads/"):
        raise CanaryError("run_evidence_branch_mismatch")
    if str(run["path"]).split("@", 1)[0] != expected["fixture"]["workflow"]:
        raise CanaryError("run_workflow_path_mismatch")
    if int(run["run_attempt"]) < 1 or int(run["id"]) <= 0:
        raise CanaryError("run_attempt_or_id_invalid")
    return {key: run[key] for key in sorted(required)}


def verify_bundle_bytes(payload: bytes, expected_identity: dict) -> dict:
    try:
        with zipfile.ZipFile(__import__("io").BytesIO(payload)) as archive:
            infos = archive.infolist()
            names = [item.filename for item in infos]
            if len(names) != len(set(names)) or "bundle-manifest.json" not in names:
                raise CanaryError("artifact_archive_member_set_invalid")
            if any(item.is_dir() or pathlib.PurePosixPath(item.filename).is_absolute() or ".." in pathlib.PurePosixPath(item.filename).parts for item in infos):
                raise CanaryError("artifact_archive_path_invalid")
            manifest = json.loads(archive.read("bundle-manifest.json"))
            for key in ("source_sha", "run_id", "run_attempt", "job_id", "seam", "invocation_id"):
                if str(manifest.get(key)) != str(expected_identity.get(key)):
                    raise CanaryError(f"artifact_identity_mismatch:{key}")
            members = manifest.get("members")
            if not isinstance(members, dict) or not members:
                raise CanaryError("artifact_has_no_members")
            for name, detail in members.items():
                lower_name = name.lower()
                if any(part in {".auth", "storagestate.json", "storage-state.json"}
                       for part in pathlib.PurePosixPath(lower_name).parts):
                    raise CanaryError(f"artifact_auth_path_rejected:{name}")
                if name not in names or sha256_bytes(archive.read(name)) != detail.get("sha256"):
                    raise CanaryError(f"artifact_member_hash_mismatch:{name}")
                content = archive.read(name)
                if b"SECRET_SENTINEL_DO_NOT_UPLOAD" in content or b"DO_NOT_UPLOAD" in content:
                    raise CanaryError(f"artifact_secret_sentinel_detected:{name}")
            if set(names) != {"bundle-manifest.json", *members.keys()}:
                raise CanaryError("artifact_contains_unlisted_member")
            return {"archive_sha256": sha256_bytes(payload), "manifest": manifest,
                    "member_hashes": {name: item["sha256"] for name, item in members.items()}}
    except (OSError, zipfile.BadZipFile, KeyError, ValueError) as error:
        if isinstance(error, CanaryError):
            raise
        raise CanaryError(f"artifact_unreadable:{error}") from None


def retrieve_bundle(freeze_path: pathlib.Path, root: pathlib.Path, artifact_id: int,
                    output: pathlib.Path, expected_identity: dict) -> dict:
    outer_path = output.with_name(output.stem + "-github-artifact.zip")
    outer = download_artifact(freeze_path, root, artifact_id, outer_path)
    try:
        with zipfile.ZipFile(__import__("io").BytesIO(outer)) as archive:
            infos = archive.infolist()
            files = [item for item in infos if not item.is_dir()]
            if len(files) != 1 or not files[0].filename.endswith(".zip"):
                raise CanaryError("github_artifact_payload_set_invalid")
            if pathlib.PurePosixPath(files[0].filename).is_absolute() or ".." in pathlib.PurePosixPath(files[0].filename).parts:
                raise CanaryError("github_artifact_payload_path_invalid")
            payload = archive.read(files[0])
    except (OSError, zipfile.BadZipFile, KeyError) as error:
        if isinstance(error, CanaryError):
            raise
        raise CanaryError(f"github_artifact_archive_invalid:{error}") from None
    verify_bundle_bytes(payload, expected_identity)
    if output.exists() or output.is_symlink():
        raise CanaryError("artifact_output_exists")
    output.write_bytes(payload)
    return {"payload": payload, "outer_path": str(outer_path), "outer_sha256": sha256_bytes(outer),
            "bundle_path": str(output), "bundle_sha256": sha256_bytes(payload)}


def cancel_fixture_run(freeze_path: pathlib.Path, run_id: int, expected: dict,
                       observed_run: dict, readiness_verified: bool, root: pathlib.Path | None = None) -> dict:
    if not readiness_verified:
        raise CanaryError("cancellation_readiness_not_verified")
    identity = verify_run_identity(expected, observed_run)
    if int(identity["id"]) != int(run_id) or identity["status"] != "in_progress":
        raise CanaryError("cancellation_target_not_exact_owned_in_progress_run")
    response, remaining = api_request(freeze_path, root or pathlib.Path.cwd(), "POST",
        f"/repos/{REPOSITORY}/actions/runs/{run_id}/cancel", operation=f"cancel-run:{run_id}")
    if remaining is not None and remaining <= 250:
        raise CanaryError(f"core_budget_stop:{remaining}")
    return {"run_id": run_id, "requested_at": utc_now(), "response": response}


def verify_terminal_results(freeze: dict, result: dict) -> dict:
    scenarios = result.get("scenarios")
    if not isinstance(scenarios, dict) or set(scenarios) != SCENARIOS:
        raise CanaryError("scenario_set_incomplete")
    expected_conclusions = {"success": "success", "failure": "failure", "cancellation": "cancelled"}
    expected_source = (freeze.get("source_identity") or {}).get("source_sha")
    expected_fixture = (freeze.get("fixture") or {}).get("commit")
    for name, conclusion in expected_conclusions.items():
        scenario = scenarios[name]
        if scenario.get("actual_conclusion") != conclusion:
            raise CanaryError(f"scenario_conclusion_mismatch:{name}")
        if not scenario.get("run_id") or not scenario.get("run_attempt") or not scenario.get("source_sha") or not scenario.get("invocation_id"):
            raise CanaryError(f"scenario_identity_missing:{name}")
        if expected_source and scenario.get("source_sha") != expected_source:
            raise CanaryError(f"scenario_source_mismatch:{name}")
        if scenario.get("seam") != name or scenario.get("job_id") != "diagnostic-fixture":
            raise CanaryError(f"scenario_job_or_seam_mismatch:{name}")
        if expected_fixture and scenario.get("fixture_commit") != expected_fixture:
            raise CanaryError(f"scenario_fixture_commit_mismatch:{name}")
        artifacts = scenario.get("artifacts")
        if not artifacts:
            raise CanaryError(f"scenario_artifact_missing:{name}")
        for artifact in artifacts:
            members = artifact.get("members")
            if (not re.fullmatch(r"[0-9a-f]{64}", str(artifact.get("sha256", "")))
                    or not re.fullmatch(r"[0-9a-f]{64}", str(artifact.get("github_archive_sha256", "")))
                    or not isinstance(members, dict) or not members
                    or any(not re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in members.values())):
                raise CanaryError(f"scenario_artifact_hash_missing:{name}")
        if name == "cancellation":
            partial = scenario.get("partial_capture")
            if not isinstance(partial, dict) or partial.get("state") != "partial" or partial.get("readiness_verified") is not True:
                raise CanaryError("cancellation_partial_capture_missing")
            if set(partial.get("missing_files") or []) != {"final-output.log", "final-trace.zip"}:
                raise CanaryError("cancellation_missing_files_not_preserved")
    usage = freeze["usage"]
    limits = freeze["limits"]
    for used, maximum in (("invocations", "max_invocations"), ("controller_requests", "max_controller_requests"),
                          ("pushes", "max_pushes"), ("infrastructure_retries", "max_infrastructure_retries"),
                          ("test_retries", "max_test_retries")):
        if usage[used] > limits[maximum]:
            raise CanaryError(f"budget_exceeded:{used}")
    return {"status": "verified", "scenario_conclusions": expected_conclusions,
            "budget_usage": {key: usage[key] for key in ("invocations", "controller_requests", "pushes", "infrastructure_retries", "test_retries")}}


def github_token() -> str:
    result = subprocess.run(["gh", "auth", "token"], check=False, capture_output=True, text=True)
    if result.returncode or not result.stdout.strip():
        raise CanaryError("github_auth_unavailable")
    return result.stdout.strip()


def api_request(freeze_path: pathlib.Path, root: pathlib.Path, method: str, endpoint: str,
                *, body: dict | None = None, operation: str | None = None,
                invocation: bool = False, scenario: str | None = None,
                push: bool = False) -> tuple[object, int | None]:
    freeze = load_freeze(freeze_path)
    assert_source_identity(freeze, root)
    charge_request(freeze_path, operation or f"{method}:{endpoint}", invocation=invocation,
                   scenario=scenario, push=push)
    payload = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request("https://api.github.com" + endpoint, data=payload, method=method,
        headers={"Authorization": f"Bearer {github_token()}", "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            value = response.headers.get("X-RateLimit-Remaining", "")
            remaining = int(value) if value.isdigit() else None
            if not raw:
                decoded = {"status": response.status}
                if endpoint == "/rate_limit":
                    record_rate_observation(freeze_path, operation or f"{method}:{endpoint}", decoded, remaining, "")
                return decoded, remaining
            try:
                decoded = json.loads(raw)
                if endpoint == "/rate_limit" and isinstance(decoded, dict):
                    record_rate_observation(freeze_path, operation or f"{method}:{endpoint}", decoded, remaining, raw.decode("utf-8"))
                return decoded, remaining
            except ValueError:
                return raw, remaining
    except urllib.error.HTTPError as error:
        if error.code in (403, 429):
            retry = error.headers.get("Retry-After") or error.headers.get("X-RateLimit-Reset")
            raise CanaryError(f"rate_limit_stop:http_{error.code}:retry={retry or 'unknown'}") from None
        raise CanaryError(f"github_http_{error.code}:{endpoint}") from None
    except (urllib.error.URLError, TimeoutError) as error:
        raise CanaryError(f"github_transport_failure:{endpoint}:{type(error).__name__}") from None


def github_json(freeze_path: pathlib.Path, root: pathlib.Path, endpoint: str) -> dict:
    api_endpoint = endpoint if endpoint == "/rate_limit" or endpoint.startswith("/repos/") else f"/repos/{REPOSITORY}/{endpoint.lstrip('/')}"
    response, remaining = api_request(freeze_path, root, "GET", api_endpoint)
    if remaining is not None and remaining <= 250:
        raise CanaryError(f"core_budget_stop:{remaining}")
    if not isinstance(response, dict):
        raise CanaryError(f"github_response_invalid:{endpoint}")
    return response


def download_artifact(freeze_path: pathlib.Path, root: pathlib.Path, artifact_id: int,
                      output: pathlib.Path) -> bytes:
    freeze = load_freeze(freeze_path)
    assert_source_identity(freeze, root)
    charge_request(freeze_path, f"artifact-download-url:{artifact_id}")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{artifact_id}/zip",
        headers={"Authorization": f"Bearer {github_token()}", "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28"})
    try:
        with urllib.request.build_opener(_NoRedirect()).open(request, timeout=30) as response:
            payload = response.read()
            remaining = response.headers.get("X-RateLimit-Remaining", "")
            if remaining.isdigit() and int(remaining) <= 250:
                raise CanaryError(f"core_budget_stop:{remaining}")
    except urllib.error.HTTPError as redirect:
        if redirect.code not in (301, 302, 303, 307, 308):
            if redirect.code in (403, 429):
                raise CanaryError(f"rate_limit_stop:http_{redirect.code}") from None
            raise CanaryError(f"artifact_download_http_{redirect.code}") from None
        location = redirect.headers.get("Location", "")
        parts = urllib.parse.urlsplit(location)
        if parts.scheme != "https" or not parts.hostname or parts.username or parts.password or not parts.path:
            raise CanaryError("artifact_redirect_url_invalid")
        host = parts.hostname.lower()
        if not (host == "github.com" or host.endswith(".githubusercontent.com") or
                host.endswith(".blob.core.windows.net") or host.endswith(".amazonaws.com")):
            raise CanaryError("artifact_redirect_host_untrusted")
        rate_value = redirect.headers.get("X-RateLimit-Remaining", "")
        if rate_value.isdigit() and int(rate_value) <= 250:
            raise CanaryError(f"core_budget_stop:{rate_value}")
        charge_request(freeze_path, f"artifact-storage-download:{artifact_id}")
        try:
            with urllib.request.urlopen(urllib.request.Request(location), timeout=60) as response:
                payload = response.read()
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as error:
            raise CanaryError(f"artifact_storage_download_failed:{type(error).__name__}") from None
    except urllib.error.URLError as error:
        raise CanaryError(f"artifact_download_transport_failure:{type(error).__name__}") from None
    if output.exists() or output.is_symlink():
        raise CanaryError("artifact_output_exists")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    return payload


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def run_scenario(root: pathlib.Path, freeze_path: pathlib.Path, scenario: str) -> dict:
    if scenario not in SCENARIOS:
        raise CanaryError("scenario_invalid")
    freeze = load_freeze(freeze_path)
    assert_source_identity(freeze, root)
    usage = freeze["usage"]
    if scenario in {item.get("scenario") for item in usage.get("charges", []) if item.get("invocation")}:
        raise CanaryError("scenario_already_dispatched")
    rate = github_json(freeze_path, root, "/rate_limit")
    remaining = int(rate.get("resources", {}).get("core", {}).get("remaining", 0))
    if remaining <= 250:
        raise CanaryError(f"core_budget_stop:{remaining}")
    probe_id = f"phase255-{scenario}-{int(time.time())}"
    branch = freeze["fixture"]["evidence_ref"].removeprefix("refs/heads/")
    _, remaining = api_request(freeze_path, root, "POST",
        f"/repos/{REPOSITORY}/actions/workflows/release-receipt-canary.yml/dispatches",
        body={"ref": branch, "inputs": {"scenario": scenario, "probe_id": probe_id,
             "tested_source_sha": freeze["source_identity"]["source_sha"]}},
        operation=f"dispatch:{scenario}", invocation=True, scenario=scenario)
    if remaining is not None and remaining <= 250:
        raise CanaryError(f"core_budget_stop:{remaining}")
    result_path = freeze_path.parent / "RESULT.json"
    results = json.loads(result_path.read_text()) if result_path.exists() else {
        "schema_version": "sigra.ci-diagnostics-canary-result/v1",
        "source_identity": freeze["source_identity"], "scenarios": {}}
    results["scenarios"][scenario] = {"probe_id": probe_id, "status": "dispatched", "started_at": utc_now()}
    atomic_json(result_path, results)

    deadline = time.time() + freeze["limits"]["max_elapsed_seconds"]
    listing_endpoint = (f"/repos/{REPOSITORY}/actions/workflows/release-receipt-canary.yml/runs?branch="
                        f"{urllib.parse.quote(branch)}&per_page=100")
    run = None
    while run is None and time.time() < deadline:
        listing = github_json(freeze_path, root, listing_endpoint)
        matches = [item for item in listing.get("workflow_runs", []) if probe_id in str(item.get("display_title", ""))]
        if len(matches) > 1:
            raise CanaryError("multiple_fixture_runs_match_probe")
        if matches:
            run = matches[0]
            break
        time.sleep(60)
    if run is None:
        raise CanaryError("fixture_run_discovery_deadline_exceeded")
    verify_run_identity(freeze, run)

    readiness = False
    terminal = None
    while time.time() < deadline:
        current, remaining = api_request(freeze_path, root, "GET", f"/repos/{REPOSITORY}/actions/runs/{run['id']}")
        if remaining is not None and remaining <= 250:
            raise CanaryError(f"core_budget_stop:{remaining}")
        verify_run_identity(freeze, current)
        if scenario == "cancellation" and current.get("status") == "in_progress" and not readiness:
            jobs, remaining = api_request(freeze_path, root, "GET", f"/repos/{REPOSITORY}/actions/runs/{run['id']}/jobs?per_page=100")
            if remaining is not None and remaining <= 250:
                raise CanaryError(f"core_budget_stop:{remaining}")
            readiness = any(step.get("name") == "Upload source-bound diagnostics" and step.get("conclusion") == "success"
                for job in jobs.get("jobs", []) for step in job.get("steps", []))
            if readiness:
                cancel_fixture_run(freeze_path, int(run["id"]), freeze, current, True, root)
        if current.get("status") == "completed":
            terminal = current
            break
        time.sleep(60)
    if terminal is None:
        raise CanaryError("fixture_run_deadline_exceeded")

    run_identity = verify_run_identity(freeze, terminal)
    expected_conclusion = {"success": "success", "failure": "failure", "cancellation": "cancelled"}[scenario]
    if terminal.get("conclusion") != expected_conclusion:
        raise CanaryError(f"fixture_conclusion_unexpected:{scenario}:{terminal.get('conclusion')}")
    artifacts, remaining = api_request(freeze_path, root, "GET", f"/repos/{REPOSITORY}/actions/runs/{run['id']}/artifacts?per_page=100")
    if remaining is not None and remaining <= 250:
        raise CanaryError(f"core_budget_stop:{remaining}")
    artifact_name = (f"sigra-ci-{freeze['source_identity']['source_sha']}-{run['id']}-{run['run_attempt']}"
                     f"-diagnostic-fixture-{scenario}-{probe_id}")
    matching = [item for item in artifacts.get("artifacts", []) if item.get("name") == artifact_name]
    if len(matching) != 1 or matching[0].get("expired"):
        raise CanaryError("expected_fixture_artifact_missing_or_expired")
    artifact_run = matching[0].get("workflow_run") or {}
    if str(artifact_run.get("id")) != str(run["id"]) or str(artifact_run.get("run_attempt")) != str(run["run_attempt"]):
        raise CanaryError("artifact_run_identity_mismatch")
    expected_identity = {"source_sha": freeze["source_identity"]["source_sha"], "run_id": run["id"],
        "run_attempt": run["run_attempt"], "job_id": "diagnostic-fixture", "seam": scenario,
        "invocation_id": probe_id, "artifact_name": artifact_name}
    artifact_path = freeze_path.parent / "artifacts" / f"{scenario}-{run['id']}-{run['run_attempt']}.zip"
    retrieved = retrieve_bundle(freeze_path, root, int(matching[0]["id"]), artifact_path, expected_identity)
    payload = retrieved["payload"]
    bundle = verify_bundle_bytes(payload, expected_identity)
    with zipfile.ZipFile(__import__("io").BytesIO(payload)) as archive:
        diagnostic = json.loads(archive.read("scenario.json"))
    expected_record = {"scenario": scenario, "probe_id": probe_id,
        "source_sha": freeze["source_identity"]["source_sha"], "fixture_commit": run["head_sha"],
        "run_id": run["id"], "run_attempt": run["run_attempt"], "job_id": "diagnostic-fixture"}
    for key, value in expected_record.items():
        if str(diagnostic.get(key)) != str(value):
            raise CanaryError(f"fixture_record_identity_mismatch:{key}")
    missing_files = diagnostic.get("expected_missing", [])
    if scenario == "cancellation":
        if diagnostic.get("capture_state") != "partial" or set(missing_files) != {"final-output.log", "final-trace.zip"}:
            raise CanaryError("fixture_partial_capture_contract_invalid")
    elif diagnostic.get("capture_state") != "complete" or missing_files:
        raise CanaryError("fixture_final_capture_contract_invalid")
    partial = {"state": diagnostic.get("capture_state"), "readiness_verified": readiness,
               "captured_at": diagnostic.get("captured_at"), "missing_files": missing_files} if scenario == "cancellation" else None
    scenario_result = {"scenario": scenario, "probe_id": probe_id, "run_id": run["id"],
        "run_attempt": run["run_attempt"], "source_sha": freeze["source_identity"]["source_sha"],
        "fixture_commit": run["head_sha"], "job_id": "diagnostic-fixture", "invocation_id": probe_id,
        "seam": scenario, "actual_conclusion": terminal["conclusion"], "structured_run_summary": run_identity,
        "artifact_id": matching[0]["id"], "artifact_name": artifact_name,
        "retention_expires_at": matching[0].get("expires_at"),
        "artifacts": [{"path": str(artifact_path), "sha256": bundle["archive_sha256"],
                       "github_archive_path": retrieved["outer_path"], "github_archive_sha256": retrieved["outer_sha256"],
                       "members": bundle["member_hashes"]}],
        "missing_files": missing_files, "partial_capture": partial}
    results = json.loads(result_path.read_text())
    results["scenarios"][scenario] = scenario_result
    results["budget_usage"] = load_freeze(freeze_path)["usage"]
    atomic_json(result_path, results)
    return scenario_result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    freeze = sub.add_parser("freeze")
    freeze.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    freeze.add_argument("--output", type=pathlib.Path, required=True)
    freeze.add_argument("--evidence-ref", required=True)
    freeze.add_argument("--fixture-commit", required=True)
    freeze.add_argument("--fixture-sha256", required=True)
    run = sub.add_parser("run")
    run.add_argument("--freeze", type=pathlib.Path, required=True)
    run.add_argument("--scenario", choices=sorted(SCENARIOS), required=True)
    run.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    verify = sub.add_parser("verify")
    verify.add_argument("--freeze", type=pathlib.Path, required=True)
    verify.add_argument("--output", type=pathlib.Path, required=True)
    rate = sub.add_parser("rate")
    rate.add_argument("--freeze", type=pathlib.Path, required=True)
    charge = sub.add_parser("charge")
    charge.add_argument("--freeze", type=pathlib.Path, required=True)
    charge.add_argument("--operation", required=True)
    charge.add_argument("--push", action="store_true")
    charge.add_argument("--infrastructure-retry", action="store_true")
    manifest = sub.add_parser("manifest")
    manifest.add_argument("--invocation-root", type=pathlib.Path, required=True)
    manifest.add_argument("--output", type=pathlib.Path, required=True)
    manifest.add_argument("--invocation-id", required=True)
    manifest.add_argument("--source-sha", required=True)
    manifest.add_argument("--run-id", required=True)
    manifest.add_argument("--run-attempt", required=True)
    manifest.add_argument("--job-id", required=True)
    manifest.add_argument("--seam", required=True)
    manifest.add_argument("--file", action="append", default=[])
    manifest.add_argument("--trace-registry", type=pathlib.Path)
    manifest.add_argument("--synthetic-account", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "freeze":
            result = freeze_canary(args.root, args.output, args.evidence_ref, args.fixture_commit, args.fixture_sha256)
        elif args.command == "run":
            result = run_scenario(args.root, args.freeze, args.scenario)
        elif args.command == "verify":
            freeze_data = load_freeze(args.freeze)
            result_data = json.loads(args.output.read_text(encoding="utf-8"))
            result = verify_terminal_results(freeze_data, result_data)
            result_data["verification"] = result
            atomic_json(args.output, result_data)
        elif args.command == "rate":
            result = github_json(args.freeze, pathlib.Path.cwd(), "/rate_limit")
        elif args.command == "charge":
            result = charge_request(args.freeze, args.operation, push=args.push,
                                    infrastructure_retry=args.infrastructure_retry)
        else:
            result = write_manifest(args.invocation_root, args.output, {
                "invocation_id": args.invocation_id, "source_sha": args.source_sha,
                "run_id": args.run_id, "run_attempt": args.run_attempt,
                "job_id": args.job_id, "seam": args.seam,
            }, args.file, args.trace_registry, args.synthetic_account)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (CanaryError, OSError, ValueError) as error:
        print(f"ci-diagnostics-canary: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
