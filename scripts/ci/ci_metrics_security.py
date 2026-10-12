"""Pure validators for data crossing the Phase 252 CI evidence trust boundaries."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import urllib.parse
import zipfile


def _digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _matches(path: pathlib.Path, expected: object) -> bool:
    return isinstance(expected, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected)) and path.is_file() and _digest(path) == expected


def verify_snapshot_hashes(bundle: pathlib.Path) -> list[str]:
    """Check every source file that replay may consume before parsing any of them."""
    bundle = pathlib.Path(bundle)
    diagnostics: list[str] = []
    try:
        manifest = json.loads((bundle / "manifest.json").read_text())
    except (OSError, ValueError):
        return ["snapshot_manifest_invalid"]
    hashes = manifest.get("source_sha256") or {}
    paths = {
        "request_ledger": bundle / "request-ledger.json",
        "selection_ledger": bundle / "selection-ledger.json",
    }
    for event in ("pull_request", "push_main", "schedule", "manual", "release_push"):
        paths[event] = bundle / "raw" / "populations" / f"{event}.json"
    for key, filename in (("rate_limit", "rate-limit.json"), ("effective_rules", "effective-rules.json"),
                          ("branch_protection", "branch-protection.json"), ("rulesets", "rulesets.json")):
        paths[key] = bundle / "raw" / filename
    for key, path in paths.items():
        if not _matches(path, hashes.get(key)):
            diagnostics.append(f"snapshot_hash_mismatch:{key}")

    for name, expected in (manifest.get("source_file_sha256") or {}).items():
        path = bundle / "source" / name
        if not path.resolve().is_relative_to((bundle / "source").resolve()) or not _matches(path, expected):
            diagnostics.append(f"snapshot_source_file_hash_mismatch:{name}")

    for family in sorted((bundle / "raw" / "families").glob("*")):
        manifest_path = family / "manifest.json"
        if not manifest_path.is_file():
            continue
        try:
            facts = json.loads(manifest_path.read_text())
        except (OSError, ValueError):
            diagnostics.append(f"family_manifest_invalid:{family.name}")
            continue
        refs = [("run", facts.get("source_run_sha256"), family / "run.json")]
        if facts.get("artifact_metadata_sha256"):
            refs.append(("artifact_metadata", facts["artifact_metadata_sha256"], family / "artifacts-metadata.json"))
        if facts.get("check_runs_sha256"):
            refs.append(("check_runs", facts["check_runs_sha256"], family / "check-runs.json"))
        if facts.get("artifact_evidence"):
            ref = facts["artifact_evidence"]
            refs.append(("artifact_evidence", ref.get("sha256"), bundle / ref.get("path", "")))
        for attempt, ref in (facts.get("attempt_jobs") or {}).items():
            rel = ref.get("path") or f"raw/families/{family.name}/jobs-attempt-{attempt}.json"
            path = bundle / rel
            if not path.resolve().is_relative_to(bundle.resolve()) or not _matches(path, ref.get("sha256")):
                diagnostics.append(f"family_attempt_hash_mismatch:{family.name}:{attempt}")
        for label, digest, path in refs:
            if not _matches(path, digest):
                diagnostics.append(f"family_source_hash_mismatch:{family.name}:{label}")

        metadata_path = family / "artifacts-metadata.json"
        evidence_path = family / "artifact-evidence.json"
        if metadata_path.is_file() and not facts.get("artifact_metadata_sha256"):
            diagnostics.append(f"artifact_metadata_hash_missing:{family.name}")
        if not metadata_path.is_file() and not evidence_path.is_file():
            continue
        try:
            metadata = json.loads(metadata_path.read_text()) if metadata_path.is_file() else {"artifacts": []}
            evidence = json.loads(evidence_path.read_text()) if evidence_path.is_file() else []
        except (OSError, ValueError):
            diagnostics.append(f"artifact_metadata_invalid:{family.name}")
            continue
        by_id = {str(item.get("id")): item for item in metadata.get("artifacts", [])}
        records = evidence if isinstance(evidence, list) else []
        for record in records:
            artifact = record.get("artifact") or {}
            result = record.get("result") or {}
            if result.get("status") not in ("accepted", "verified"):
                continue
            artifact_id = str(artifact.get("id", ""))
            source = by_id.get(artifact_id, artifact)
            zip_path = family / "artifacts" / f"{artifact_id}.zip"
            expected = (result.get("archive_sha256") or "").removeprefix("sha256:")
            if not artifact_id.isdigit() or not _matches(zip_path, expected):
                diagnostics.append(f"artifact_zip_hash_mismatch:{family.name}:{artifact_id}")
                continue
            try:
                member_records = [item for item in result.get("members", []) if isinstance(item, dict) and item.get("member")]
                if any(not item.get("sha256") for item in member_records):
                    diagnostics.append(f"artifact_member_hash_missing:{family.name}:{artifact_id}")
                    continue
                verified_zip_members(zip_path, expected, {item["member"]: item["sha256"] for item in member_records})
                with zipfile.ZipFile(zip_path) as archive:
                    zip_members = {info.filename for info in archive.infolist() if not info.is_dir()}
                recorded_json_members = {item.get("member") for item in member_records}
                with zipfile.ZipFile(zip_path) as archive:
                    all_extracted_json = {n for n in zip_members if pathlib.PurePosixPath(n).suffix.lower() == ".json" and pathlib.PurePosixPath(n).name.lower() in {
                        "report.json", "playwright-report.json", "test-results.json", "timing.json", "ci-timing.json", "metrics.json", "manifest.json", "ci-measurement-metadata.json", "ci-exunit-timing-main.json", "ci-exunit-timing-threadline-guard.json", "admin-behavior.json", "admin-checkpoints.json", "design-gallery-pr-behavior.json", "design-gallery-nonpr-snapshots.json", "design-gallery-nonpr-behavior.json", "non-admin-smoke.json", "demo-showcase.json"}}
                if all_extracted_json != recorded_json_members:
                    diagnostics.append(f"artifact_json_member_coverage_mismatch:{family.name}:{artifact_id}")
                for item in member_records:
                    member = item.get("member")
                    extracted = family / "artifacts" / artifact_id / pathlib.PurePosixPath(member).name
                    if member not in zip_members or not extracted.resolve().is_relative_to(bundle.resolve()):
                        diagnostics.append(f"artifact_extracted_member_invalid:{family.name}:{artifact_id}")
                        continue
                    with zipfile.ZipFile(zip_path) as archive:
                        payload = archive.read(member)
                    if not extracted.is_file() or extracted.read_bytes() != payload:
                        diagnostics.append(f"artifact_extracted_member_mismatch:{family.name}:{artifact_id}:{member}")
            except (OSError, ValueError, KeyError, zipfile.BadZipFile):
                diagnostics.append(f"artifact_member_verification_failed:{family.name}:{artifact_id}")
    return sorted(set(diagnostics))


def validate_check_bindings(run: dict, attempt: int, jobs: list[dict], checks: list[dict], required: list[str]) -> list[str]:
    diagnostics = []
    run_id = str(run.get("id"))
    head_sha = run.get("head_sha")
    for name in required:
        matching_jobs = [j for j in jobs if j.get("name") == name]
        matching_checks = [c for c in checks if c.get("name") == name]
        valid = len(matching_jobs) == 1 and len(matching_checks) == 1
        if valid:
            job, check = matching_jobs[0], matching_checks[0]
            check_url = urllib.parse.urlsplit(job.get("check_run_url", ""))
            check_id = check_url.path.rstrip("/").split("/")[-1]
            valid = (
                str(job.get("run_id")) == run_id
                and int(job.get("run_attempt", -1)) == int(attempt)
                and job.get("head_sha") == head_sha
                and str(job.get("id")) == check_id == str(check.get("id"))
                and check.get("head_sha") == head_sha
                and check.get("status") == "completed"
                and check.get("conclusion") == "success"
                and (check.get("app") or {}).get("slug") == "github-actions"
                and check.get("check_suite", {}).get("id") is not None
            )
        if not valid:
            diagnostics.append(f"required_check_job_binding_invalid:{name}")
    return diagnostics


def validate_producer_binding(run: dict, job: dict, artifact: dict, metadata: dict, expected_job: str) -> list[str]:
    diagnostics = []
    run_id, attempt = str(run.get("id")), str(job.get("run_attempt"))
    seam = metadata.get("matrix_seam")
    if expected_job == "Library tests shard":
        expected_job_names = {"Library tests shard"}
        timing_name = f"library-test-timing-{run_id}-{attempt}"
        metadata_name = f"library-measurement-metadata-{run_id}-{attempt}"
        artifact_steps = {
            timing_name: "Upload library test timing",
            metadata_name: "Upload library measurement metadata",
        }
        expected_artifacts = {timing_name, metadata_name}
    elif expected_job.startswith("Example Playwright shard (") and isinstance(seam, str):
        expected_job_names = {f"Example Playwright shard ({seam})"}
        timing_name = f"example-playwright-{seam}-{run_id}"
        metadata_name = f"playwright-measurement-metadata-{seam}-{run_id}-{attempt}"
        artifact_steps = {timing_name: "Upload shard diagnostics", metadata_name: "Upload Playwright measurement metadata"}
        expected_artifacts = {timing_name, metadata_name}
    else:
        return ["producer_job_contract_unknown"]
    artifact_name = artifact.get("name")
    artifact_run = artifact.get("workflow_run") or {}
    upload_step_name = artifact_steps.get(artifact_name)
    steps = [s for s in job.get("steps", []) if s.get("name") == upload_step_name and s.get("conclusion") == "success"] if upload_step_name else []
    try:
        artifact_time = _utc(artifact.get("created_at"))
        in_step = any(_utc(s["started_at"]) <= artifact_time <= _utc(s["completed_at"]) for s in steps)
    except (KeyError, TypeError, ValueError):
        in_step = False
    valid = (
        str(job.get("run_id")) == run_id and str(job.get("run_attempt")) == attempt
        and job.get("name") in expected_job_names and job.get("conclusion") == "success"
        and str(artifact.get("workflow_run", {}).get("id")) == run_id
        and artifact.get("workflow_run", {}).get("head_sha") == run.get("head_sha")
        and artifact_run.get("repository_id") == 1207487684
        and artifact_run.get("head_repository_id") == 1207487684
        and artifact_name in expected_artifacts
        and (metadata.get("timing_artifact_name") in (None, "", timing_name))
        and str(metadata.get("run_id")) == run_id and str(metadata.get("run_attempt")) == attempt
        and metadata.get("job_name") == ("Library tests shard" if expected_job == "Library tests shard" else "Example Playwright shard") and metadata.get("event") == run.get("event")
        and metadata.get("repository") == "szTheory/sigra" and in_step
    )
    if not valid:
        diagnostics.append("producer_metadata_not_bound_to_successful_job_upload")
    return diagnostics


def validate_producer_commit(source_sha: str, commit: dict, run: dict) -> list[str]:
    prs = run.get("pull_requests") or []
    if len(prs) != 1:
        return ["producer_commit_pull_request_origin_unavailable"]
    pr = prs[0]
    expected = {pr.get("head", {}).get("sha"), pr.get("base", {}).get("sha")}
    parents = {p.get("sha") for p in commit.get("parents", [])}
    if commit.get("sha") != source_sha or not re.fullmatch(r"[0-9a-f]{40}", source_sha or "") or parents != expected:
        return ["producer_merge_commit_origin_unverified"]
    if pr.get("number") is None or run.get("head_sha") != pr.get("head", {}).get("sha"):
        return ["producer_pr_head_binding_invalid"]
    return []


def validate_workflow_source(source_sha: str, tree: dict, workflow_bytes: bytes, expected_sha256: str) -> list[str]:
    entries = [item for item in tree.get("tree", []) if item.get("path") == ".github/workflows/ci.yml" and item.get("type") == "blob"]
    blob_sha = hashlib.sha1(b"blob " + str(len(workflow_bytes)).encode() + b"\0" + workflow_bytes).hexdigest()
    if tree.get("sha") is None or not re.fullmatch(r"[0-9a-f]{40}", source_sha or ""):
        return ["producer_workflow_tree_origin_unverified"]
    if len(entries) != 1 or entries[0].get("sha") != blob_sha or hashlib.sha256(workflow_bytes).hexdigest() != expected_sha256:
        return ["producer_workflow_source_hash_mismatch"]
    return []


def verified_zip_members(archive_path: pathlib.Path, expected_archive_sha256: str, member_hashes: dict) -> dict[str, bytes]:
    archive_path = pathlib.Path(archive_path)
    if not _matches(archive_path, expected_archive_sha256):
        raise ValueError("artifact_zip_hash_mismatch")
    values = {}
    with zipfile.ZipFile(archive_path) as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        if len(names) != len(set(names)):
            raise ValueError("duplicate_archive_member")
        for name, expected in member_hashes.items():
            if name not in names:
                raise ValueError(f"artifact_member_missing:{name}")
            payload = archive.read(name)
            if not _matches_bytes(payload, expected):
                raise ValueError(f"artifact_member_hash_mismatch:{name}")
            values[name] = payload
    return values


def _matches_bytes(data: bytes, expected: object) -> bool:
    return isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected) is not None and hashlib.sha256(data).hexdigest() == expected


def sanitize_failure_log(raw: bytes, max_input_bytes: int = 1024 * 1024, max_output_bytes: int = 16384) -> dict:
    clipped = len(raw) > max_input_bytes
    raw = raw[:max_input_bytes]
    text = raw.decode("utf-8", "replace")
    output = []
    env_count = 0
    for line in text.splitlines():
        if re.match(r"^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=", line) or re.search(r"(?i)(?:printenv|env\s+dump|github_env|environment variables)", line):
            if not env_count:
                output.append("[ENVIRONMENT DUMP REDACTED]")
            env_count += 1
            continue
        if env_count:
            env_count = 0
        output.append(line)
    text = "\n".join(output)
    text = re.sub(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b", "[REDACTED_TOKEN]", text)
    text = re.sub(r"(?i)\bBearer\s+[^\s,;]+", "Bearer [REDACTED]", text)
    text = re.sub(r"https?://[^\s<>\]\[()]+", "[URL REDACTED]", text)
    encoded = text.encode("utf-8")
    if len(encoded) > max_output_bytes:
        text = encoded[:max_output_bytes].decode("utf-8", "ignore")
        clipped = True
    if clipped:
        suffix = "\n[LOG EXCERPT TRUNCATED]"
        text = text.encode("utf-8")[:max(0, max_output_bytes - len(suffix))].decode("utf-8", "ignore") + suffix
    return {"text": text, "truncated": clipped, "input_bytes": len(raw), "output_bytes": len(text.encode("utf-8"))}


def safe_markdown_url(value: str) -> str | None:
    try:
        parsed = urllib.parse.urlsplit(value)
        if parsed.scheme != "https" or parsed.netloc != "github.com" or parsed.query or parsed.fragment or parsed.username or parsed.password:
            return None
        if re.fullmatch(r"/szTheory/sigra/actions/runs/[1-9][0-9]*(?:/job/[1-9][0-9]*)?", parsed.path):
            return value
        if re.fullmatch(r"/szTheory/sigra/pull/[1-9][0-9]*", parsed.path):
            return value
        return None
    except (TypeError, ValueError):
        return None


class CoreRequestBudget:
    def __init__(self, remaining: int | None):
        self.remaining = remaining

    def refresh(self, observed: int | None) -> None:
        if observed is not None:
            self.remaining = observed if self.remaining is None else min(self.remaining, observed)

    def reserve(self) -> bool:
        if self.remaining is not None and self.remaining <= 250:
            return False
        if self.remaining is not None:
            self.remaining -= 1
        return True


def deduplicate_physical_jobs(attempts: dict) -> tuple[list[dict], list[dict]]:
    """Count each GitHub job ID once; retain reused API rows as explicit history."""
    seen = set()
    counted, rows = [], []
    for attempt, jobs in sorted(attempts.items(), key=lambda item: int(item[0])):
        for job in jobs:
            job_id = str(job.get("id", ""))
            if not job_id or job_id in seen:
                rows.append({"attempt": int(attempt), "job": job, "counted": False})
                continue
            seen.add(job_id)
            row = {"attempt": int(attempt), "job": job, "counted": True}
            counted.append(row)
            rows.append(row)
    return counted, rows


def comparison_contract_sha256(contract: dict) -> str:
    frozen = {k: v for k, v in contract.items() if k not in ("family_registrations", "registration_ledger_sha256")}
    return hashlib.sha256(json.dumps(frozen, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def register_comparison_run(contract: dict, reservation_id: str, api_run: dict, ledger: dict | None = None, api_run_sha256: str | None = None) -> dict:
    """Create an append-only identity record without reading the API outcome fields."""
    reservations = [x for x in contract.get("family_reservations", []) if x.get("reservation_id") == reservation_id]
    if len(reservations) != 1:
        raise ValueError("comparison_reservation_unknown_or_duplicate")
    reservation = reservations[0]
    expected_sha = contract.get("baseline_application_sha") if reservation.get("family_role") == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
    try:
        start, end = _utc(contract["window"]["start_utc"]), _utc(contract["window"]["end_utc"])
        created = _utc(api_run["created_at"])
    except (KeyError, TypeError, ValueError):
        raise ValueError("comparison_run_identity_or_window_invalid")
    pull_requests = api_run.get("pull_requests") or []
    if (contract.get("status") != "ready" or not expected_sha or len(pull_requests) != 1
            or not isinstance(api_run.get("id"), int) or api_run.get("id") <= 0 or api_run.get("event") != "pull_request"
            or api_run.get("status") not in ("queued", "in_progress") or api_run.get("conclusion") is not None
            or not re.fullmatch(r"[0-9a-f]{64}", api_run_sha256 or "")
            or api_run.get("path") != ".github/workflows/ci.yml" or api_run.get("head_sha") != expected_sha
            or not start <= created <= end or reservation.get("pair_id") is None):
        raise ValueError("comparison_run_identity_does_not_match_reservation")
    pr = pull_requests[0]
    if pr.get("head", {}).get("sha") != expected_sha:
        raise ValueError("comparison_run_pull_request_head_mismatch")
    previous_rows = (ledger or {}).get("records", [])
    if (ledger and ledger.get("contract_sha256") != comparison_contract_sha256(contract)):
        raise ValueError("comparison_registration_contract_hash_mismatch")
    if any(x.get("reservation_id") == reservation_id or str(x.get("run_id")) == str(api_run["id"]) for x in previous_rows):
        raise ValueError("comparison_registration_duplicate")
    identity = {
        "reservation_id": reservation_id,
        "pair_id": reservation["pair_id"],
        "family_role": reservation["family_role"],
        "run_id": api_run["id"],
        "created_at": api_run["created_at"],
        "event": api_run["event"],
        "workflow_path": api_run["path"],
        "head_sha": api_run["head_sha"],
        "pull_request_number": pr.get("number"),
        "pull_request_head_sha": pr.get("head", {}).get("sha"),
        "pull_request_base_sha": pr.get("base", {}).get("sha"),
        "api_run_sha256": api_run_sha256,
    }
    record = {"sequence": len(previous_rows), "previous_sha256": previous_rows[-1]["record_sha256"] if previous_rows else "0" * 64, **identity}
    record["record_sha256"] = hashlib.sha256(json.dumps(record, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schema_version": "sigra.ci-comparison-registration/v1", "contract_sha256": comparison_contract_sha256(contract), "records": previous_rows + [record]}


def validate_comparison_reservations(contract: dict, families: list[dict], source_runs: list[dict], registration_ledger: dict | None = None) -> list[str]:
    reservations = contract.get("family_reservations") or []
    registration_ledger = registration_ledger or {"contract_sha256": comparison_contract_sha256(contract), "records": contract.get("family_registrations") or []}
    registrations = registration_ledger.get("records") or []
    reserved = {(x.get("pair_id"), x.get("family_role")): x for x in reservations}
    runs = {str(x.get("id")): x for x in source_runs if x.get("event") == "pull_request"}
    diagnostics = []
    if registration_ledger.get("contract_sha256") != comparison_contract_sha256(contract):
        diagnostics.append("comparison_registration_contract_hash_mismatch")
    if len(reservations) != 40 or len(reserved) != 40 or len({x.get("reservation_id") for x in reservations}) != 40:
        diagnostics.append("comparison_reservation_set_incomplete")
    if len(registrations) != 40:
        diagnostics.append("comparison_registration_set_incomplete")
    previous = "0" * 64
    registration_by_key = {}
    for index, row in enumerate(registrations):
        record = {k: v for k, v in row.items() if k != "record_sha256"}
        canonical = json.dumps(record, sort_keys=True, separators=(",", ":")).encode()
        digest = hashlib.sha256(canonical).hexdigest()
        if row.get("sequence") != index or row.get("previous_sha256") != previous or row.get("record_sha256") != digest:
            diagnostics.append("comparison_registration_chain_invalid")
        previous = row.get("record_sha256", "")
        registration_by_key[row.get("reservation_id")] = row
    window = contract.get("window") or {}
    if not window.get("start_utc") or not window.get("end_utc"):
        diagnostics.append("comparison_window_not_predeclared")
        return diagnostics
    try:
        start, end = _utc(window["start_utc"]), _utc(window["end_utc"])
        if end - start != __import__("datetime").timedelta(hours=48):
            diagnostics.append("comparison_window_duration_invalid")
    except (KeyError, TypeError, ValueError):
        diagnostics.append("comparison_window_invalid")
        return sorted(set(diagnostics))
    seen = set()
    for family in families:
        key = (family.get("pair_id"), family.get("family_role"))
        reservation = reserved.get(key)
        registration = registration_by_key.get((reservation or {}).get("reservation_id"))
        if reservation is None or registration is None or reservation.get("reservation_id") != registration.get("reservation_id"):
            diagnostics.append("comparison_family_run_not_reserved")
            continue
        if key in seen:
            diagnostics.append("comparison_family_reservation_duplicate")
        seen.add(key)
        try:
            created = _utc(family.get("created_at"))
        except (TypeError, ValueError):
            diagnostics.append("comparison_family_created_at_invalid")
            continue
        run = runs.get(str(family.get("run_id")))
        expected_sha = contract.get("baseline_application_sha") if family.get("family_role") == "before" else (contract.get("candidate_identity") or {}).get("application_sha")
        if (family.get("run_id") != registration.get("run_id")
                or family.get("pair_id") != registration.get("pair_id")
                or family.get("family_role") != registration.get("family_role")
                or family.get("created_at") != registration.get("created_at")
                or not run or run.get("created_at") != family.get("created_at")
                or run.get("head_sha") != expected_sha or run.get("detail_status") != "complete"
                or registration.get("head_sha") != expected_sha or registration.get("pull_request_head_sha") != expected_sha
                or not re.fullmatch(r"[0-9a-f]{64}", registration.get("api_run_sha256") or "")):
            diagnostics.append("comparison_family_api_origin_mismatch")
        if not start <= created <= end:
            diagnostics.append("comparison_family_outside_frozen_window")
    if seen != set(reserved):
        diagnostics.append("comparison_family_reservation_incomplete")
    return sorted(set(diagnostics))


def _utc(value: str):
    import datetime
    return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
