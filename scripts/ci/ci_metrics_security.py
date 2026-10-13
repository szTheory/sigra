"""Pure validators for data crossing the Phase 252 CI evidence trust boundaries."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import base64
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

    try:
        ledger = json.loads((bundle / "request-ledger.json").read_text())
        requests = set(ledger.get("requests", []))
        repository = manifest.get("repository")
        population_runs = []
        for event in ("pull_request", "push_main", "schedule"):
            data = json.loads((bundle / "raw" / "populations" / f"{event}.json").read_text())
            population_runs.extend(data.get("runs", []))
    except (OSError, ValueError, TypeError):
        requests, population_runs, repository = set(), [], None

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
        run_path = family / "run.json"
        try:
            family_run = json.loads(run_path.read_text())
            matches = [row for row in population_runs if str(row.get("id")) == str(family_run.get("id"))]
            identity_keys = ("id", "head_sha", "event", "path", "run_attempt", "created_at", "pull_requests")
            if len(matches) != 1 or any(matches[0].get(key) != family_run.get(key) for key in identity_keys):
                diagnostics.append(f"family_run_population_binding_invalid:{family.name}")
            if repository != "szTheory/sigra" or facts.get("run_id") != family_run.get("id"):
                diagnostics.append(f"family_repository_or_run_identity_invalid:{family.name}")
        except (OSError, ValueError, TypeError):
            family_run = {}
            diagnostics.append(f"family_run_identity_invalid:{family.name}")
        refs = [("run", facts.get("source_run_sha256"), family / "run.json")]
        for item in facts.get("changed_path_pages", []):
            rel = item.get("path", "")
            path = bundle / rel
            if (not rel or not path.resolve().is_relative_to(bundle.resolve())
                    or not _matches(path, item.get("sha256"))):
                diagnostics.append(f"changed_path_page_hash_mismatch:{family.name}:{item.get('page', 'unknown')}")
        actual_pages = sorted(family.glob("changed-paths-page-*.json"))
        referenced = {str(item.get("path", "")) for item in facts.get("changed_path_pages", [])}
        expected_pages = {path.relative_to(bundle).as_posix() for path in actual_pages}
        if referenced != expected_pages:
            diagnostics.append(f"changed_path_page_hash_reference_set_mismatch:{family.name}")
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
            expected_rel = f"raw/families/{family.name}/jobs-attempt-{attempt}.json"
            request = f"/repos/{repository}/actions/runs/{family_run.get('id')}/attempts/{attempt}/jobs?per_page=100"
            if (rel != expected_rel or not path.resolve().is_relative_to(bundle.resolve())
                    or not _matches(path, ref.get("sha256")) or request not in requests):
                diagnostics.append(f"family_attempt_hash_mismatch:{family.name}:{attempt}")
        for item in facts.get("changed_path_pages", []):
            try:
                pr_number = family_run["pull_requests"][0]["number"]
                expected_request = f"/repos/{repository}/pulls/{pr_number}/files?per_page=100&page={item.get('page')}"
            except (KeyError, IndexError, TypeError):
                expected_request = ""
            if expected_request not in requests:
                diagnostics.append(f"changed_path_page_api_request_missing:{family.name}:{item.get('page', 'unknown')}")
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
                # Every JSON member the collector may consume must have a recorded digest,
                # and later readers must use the bytes returned from this verified ZIP.
                if recorded_json_members != all_extracted_json:
                    diagnostics.append(f"artifact_json_members_not_fully_hash_bound:{family.name}:{artifact_id}")
            except (OSError, ValueError, KeyError, zipfile.BadZipFile):
                diagnostics.append(f"artifact_member_verification_failed:{family.name}:{artifact_id}")
    return sorted(set(diagnostics))


def validate_check_bindings(run: dict, attempt: int, jobs: list[dict], checks: list[dict], required: list[str]) -> list[str]:
    errors, by_attempt, _ = bind_required_checks_by_attempt(run, {str(attempt): jobs}, checks, required)
    if errors:
        return errors
    current = by_attempt.get(str(attempt), {})
    diagnostics = []
    for name in required:
        check = current.get(name)
        if not check or check.get("status") != "completed" or check.get("conclusion") != "success":
            diagnostics.append(f"required_check_result_invalid:{name}")
    return sorted(set(diagnostics))


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


def validate_workflow_source(source_sha: str, tree: dict, workflow_bytes: bytes, expected_sha256: str, expected_tree_sha: str | None = None) -> list[str]:
    entries = [item for item in tree.get("tree", []) if item.get("path") == ".github/workflows/ci.yml" and item.get("type") == "blob"]
    blob_sha = hashlib.sha1(b"blob " + str(len(workflow_bytes)).encode() + b"\0" + workflow_bytes).hexdigest()
    commit_tree_sha = expected_tree_sha or tree.get("_expected_commit_tree_sha")
    if (tree.get("sha") is None or not re.fullmatch(r"[0-9a-f]{40}", source_sha or "")
            or not re.fullmatch(r"[0-9a-f]{40}", str(tree.get("sha") or ""))
            or (commit_tree_sha is not None and tree.get("sha") != commit_tree_sha)):
        return ["producer_workflow_tree_origin_unverified"]
    if len(entries) != 1 or entries[0].get("sha") != blob_sha or hashlib.sha256(workflow_bytes).hexdigest() != expected_sha256:
        return ["producer_workflow_source_hash_mismatch"]
    return []


def validate_general_job_identity(
    run: dict, attempt: int, job: dict, repository: str = "szTheory/sigra", *, request_bound: bool = False
) -> list[str]:
    """Check native API identity; request context may fill only genuinely absent fields."""
    expected_repo_id = 1207487684 if repository == "szTheory/sigra" else None
    diagnostics = []
    for native, expected in (("run_id", run.get("id")), ("run_attempt", attempt), ("head_sha", run.get("head_sha"))):
        value = job.get(native)
        if value is not None:
            if str(value) != str(expected):
                diagnostics.append("ranking_job_native_identity_conflict")
        elif not request_bound:
            diagnostics.append("ranking_job_native_identity_missing")
    # Collector assertions are supplementary evidence only. They can never mask a
    # conflicting native API field, and callers enable request_bound only after
    # validating the exact hashed request endpoint for this response.
    for asserted, expected in (("source_run_id", run.get("id")), ("source_run_attempt", attempt),
                               ("source_head_sha", run.get("head_sha")), ("source_repository", repository),
                               ("source_repository_id", expected_repo_id)):
        value = job.get(asserted)
        if value is not None and str(value) != str(expected):
            diagnostics.append("ranking_job_request_assertion_conflict")
    repo = job.get("repository")
    if repo is not None and repo != repository:
        diagnostics.append("ranking_job_repository_conflict")
    if not str(job.get("id", "")).isdigit():
        diagnostics.append("ranking_job_id_invalid")
    return sorted(set(diagnostics))


def bind_required_checks_by_attempt(run: dict, jobs_by_attempt: dict, checks: list[dict], required: list[str], repository: str = "szTheory/sigra") -> tuple[list[str], dict, float | None]:
    """Validate every required check against the exact attempt job set before exposing endpoints or cost."""
    diagnostics = []
    repository_id = ((run.get("repository") or {}).get("id")
                     or (((run.get("pull_requests") or [{}])[0].get("head") or {}).get("repo") or {}).get("id"))
    if repository == "szTheory/sigra" and repository_id != 1207487684:
        diagnostics.append("family_repository_identity_invalid")
    job_by_id = {}
    runner_seconds = 0.0
    runner_complete = True
    seen_physical_ids = set()
    for attempt_text, jobs in sorted(jobs_by_attempt.items(), key=lambda item: int(item[0])):
        attempt = int(attempt_text)
        for job in jobs:
            row_errors = validate_general_job_identity(run, attempt, job, repository, request_bound=True)
            diagnostics.extend(row_errors)
            job_id = str(job.get("id", ""))
            if not job_id.isdigit() or row_errors:
                continue
            if job_id in job_by_id and job_by_id[job_id] != job:
                diagnostics.append("ranking_job_physical_identity_conflict")
                continue
            job_by_id[job_id] = {**job, "_verified_attempt": attempt}
            if job_id not in seen_physical_ids:
                seen_physical_ids.add(job_id)
                if job.get("conclusion") == "skipped":
                    continue
                try:
                    start, end = _utc(job["started_at"]), _utc(job["completed_at"])
                    if end < start:
                        raise ValueError
                    runner_seconds += (end - start).total_seconds()
                except (KeyError, TypeError, ValueError):
                    runner_complete = False
    endpoints = {}
    seen_checks = set()
    for check in checks:
        name = check.get("name")
        if name not in required:
            continue
        check_id = str(check.get("id", ""))
        external_id = str(check.get("external_id", ""))
        candidates = {key: row for key, row in job_by_id.items()
                     if key == check_id or (external_id.isdigit() and key == external_id)
                     or (row.get("check_run_url") is not None
                         and row.get("check_run_url", "").endswith(f"/check-runs/{check_id}"))}
        job = next(iter(candidates.values())) if len(candidates) == 1 else None
        if job is None or job.get("name") != name:
            diagnostics.append(f"required_check_job_binding_invalid:{name}")
            continue
        if (check.get("head_sha") != run.get("head_sha")
                or (check.get("app") or {}).get("slug") != "github-actions"
                or (check.get("check_suite") or {}).get("id") is None):
            diagnostics.append(f"required_check_origin_invalid:{name}")
            continue
        attempt = job["_verified_attempt"]
        key = (attempt, name)
        if key in seen_checks:
            diagnostics.append(f"required_check_duplicate:{name}:attempt-{attempt}")
            continue
        seen_checks.add(key)
        endpoints.setdefault(str(attempt), {})[name] = {
            "id": check.get("id"), "external_id": check.get("external_id"),
            "job_id": job.get("id"), "attempt": attempt,
            "head_sha": check.get("head_sha"), "status": check.get("status"),
            "conclusion": check.get("conclusion"),
            "started_at": check.get("started_at"), "completed_at": check.get("completed_at"),
        }
    if diagnostics:
        return sorted(set(diagnostics)), {}, None
    return [], endpoints, runner_seconds if runner_complete else None


def verified_failure_log(root: pathlib.Path, relative: str, expected_sha256: str) -> bytes:
    """Return a retained log only when its path is contained and bytes match the audited hash."""
    root = pathlib.Path(root).resolve()
    rel = pathlib.PurePosixPath(relative or "")
    if not relative or rel.is_absolute() or ".." in rel.parts:
        raise ValueError("failure_log_path_invalid")
    path = (root / pathlib.Path(*rel.parts)).resolve()
    if not path.is_relative_to(root) or not _matches(path, expected_sha256):
        raise ValueError("failure_log_hash_or_containment_invalid")
    return path.read_bytes()


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
        candidate = re.sub(r"^\s*(?:(?:\+{1,}|\$|>)+\s*)?", "", line)
        candidate = re.sub(r"^(?:declare\s+(?:-[A-Za-z]+|--)|export)\s+", "", candidate)
        if (re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*=", candidate)
                or re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s+.+$", candidate) and "=" in candidate.split(" ", 1)[-1]
                or re.search(r"(?i)(?:\bprintenv\b|\benv\s+(?:dump|--all|\||$)|\benv\s*$|\bdeclare\s+-p\b|\bcompgen\s+-e\b|\bgithub_env\b|environment variables|^set\s*$|set\s+-o\s+posix)", candidate)):
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


def escape_markdown_text(value: object) -> str:
    """Render untrusted data as inert text in a Markdown report."""
    text = str(value if value is not None else "unknown")
    replacements = {
        "&": "&amp;", "<": "&lt;", ">": "&gt;", "`": "&#96;",
        "[": "&#91;", "]": "&#93;", "(": "&#40;", ")": "&#41;",
        "!": "&#33;", "*": "&#42;", "_": "&#95;", "|": "&#124;",
        "\\": "&#92;", "#": "&#35;", "\n": " ", "\r": " ",
    }
    return "".join(replacements.get(char, char) for char in text)


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


def register_comparison_run(contract: dict, reservation_id: str, api_run: dict, ledger: dict | None = None, api_run_sha256: str | None = None, api_run_response_bytes: bytes | None = None) -> dict:
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
    raw_api = api_run_response_bytes if api_run_response_bytes is not None else json.dumps(api_run, sort_keys=True, separators=(",", ":")).encode()
    if hashlib.sha256(raw_api).hexdigest() != api_run_sha256:
        raise ValueError("comparison_registration_api_response_hash_mismatch")
    try:
        if json.loads(raw_api) != api_run:
            raise ValueError("comparison_registration_api_response_content_mismatch")
    except (ValueError, TypeError) as error:
        raise ValueError("comparison_registration_api_response_invalid") from error
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
        "api_run_response_b64": base64.b64encode(raw_api).decode("ascii"),
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
        try:
            raw = base64.b64decode(row.get("api_run_response_b64", ""), validate=True)
            api_run = json.loads(raw)
            valid_raw = hashlib.sha256(raw).hexdigest() == row.get("api_run_sha256")
            valid_raw = valid_raw and str(api_run.get("id")) == str(row.get("run_id"))
            valid_raw = valid_raw and api_run.get("status") in ("queued", "in_progress") and api_run.get("conclusion") is None
            valid_raw = valid_raw and api_run.get("created_at") == row.get("created_at") and api_run.get("head_sha") == row.get("head_sha")
            valid_raw = valid_raw and api_run.get("event") == "pull_request" and api_run.get("path") == ".github/workflows/ci.yml"
            valid_raw = valid_raw and len(api_run.get("pull_requests") or []) == 1
            valid_raw = valid_raw and api_run["pull_requests"][0].get("head", {}).get("sha") == row.get("pull_request_head_sha")
        except (ValueError, TypeError, KeyError):
            valid_raw = False
        if not valid_raw:
            diagnostics.append("comparison_registration_api_response_invalid")
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


def diagnose_snapshot(bundle: pathlib.Path, archive: pathlib.Path, baseline: pathlib.Path) -> dict:
    """A companion, never a rewrite of the immutable metrics replay."""
    saved = json.loads(baseline.read_text())
    errors = verify_snapshot_hashes(bundle)
    if _digest(archive) != saved.get('source_bundle_sha256'):
        errors.append('source_bundle_hash_mismatch')
    result = {'schema_version': 'sigra.ci-diagnosis/v1',
              'source_bundle_sha256': _digest(archive), 'baseline_sha256': _digest(baseline),
              'source_errors': sorted(set(errors)), 'records': [],
              'cause_claim': 'observations_only; no current flake or application cause proved'}
    if errors:
        result['status'] = 'incomplete'
        return result
    for selected in saved.get('failure_analysis', {}).get('families', []):
        run_id = str(selected['run']['id'])
        family = bundle / 'raw/families' / run_id
        if not (family / 'manifest.json').is_file():
            result['records'].append({'run_id': run_id, 'attempt': selected['run'].get('run_attempt'),
                'source_sha': selected['run'].get('head_sha'), 'event': selected.get('event'),
                'job_id': None, 'job_name': None, 'step_name': None, 'step_number': None,
                'original_native_outcome': selected['run'].get('conclusion'),
                'corrected_category': 'unknown_failure', 'completeness': 'incomplete',
                'missing_details': ['family_jobs_and_logs_not_retained'], 'cause_status': 'unproved'})
            continue
        facts = json.loads((family / 'manifest.json').read_text())
        run = json.loads((family / 'run.json').read_text())
        for attempt, ref in sorted(facts.get('attempt_jobs', {}).items()):
            jobs_path = bundle / ref['path']
            jobs = json.loads(jobs_path.read_text())['jobs']
            failed = [j for j in jobs if j.get('conclusion') in ('failure', 'timed_out', 'cancelled')]
            log_ref = next((d.get('result', {}) for d in facts.get('artifact_diagnostics', [])
                            if d.get('kind') == 'failed_job_log'), {})
            # The old collector retained exactly the FIRST failing job in the LAST
            # attempt. It did not retain a log for the rest. Never reuse that log.
            logged_job = next((j['id'] for j in jobs if j.get('conclusion') in ('failure', 'timed_out')), None)
            for job in failed:
                steps = [s for s in job.get('steps', []) if s.get('conclusion') in ('failure', 'timed_out', 'cancelled')]
                for step in steps or [{'name': None, 'number': None, 'conclusion': job.get('conclusion')}]:
                    record = {'run_id': run_id, 'attempt': int(attempt), 'source_sha': run['head_sha'],
                              'event': run['event'], 'job_id': job['id'], 'job_name': job['name'],
                              'step_name': step['name'], 'step_number': step['number'],
                              'original_native_outcome': step['conclusion'], 'original_job_outcome': job['conclusion'],
                              'jobs_sha256': _digest(jobs_path), 'log_sha256': None,
                              'corrected_category': 'unknown_failure', 'observed_test': None,
                              'observed_command_exit': None, 'completeness': 'incomplete',
                              'missing_details': [], 'cause_status': 'unproved'}
                    if str(attempt) != str(run['run_attempt']) or job['id'] != logged_job or not log_ref.get('sha256'):
                        record['missing_details'].append('producer_log_not_retained')
                    else:
                        try:
                            raw = verified_failure_log(bundle, log_ref.get('path'), log_ref.get('sha256'))
                            record['log_sha256'] = log_ref['sha256']
                            lines = raw.decode('utf-8', 'replace').splitlines()
                            relevant = []
                            start, end = _utc(step['started_at']), _utc(step['completed_at'])
                            for number, line in enumerate(lines, 1):
                                try:
                                    stamp = _utc(line.split(' ', 1)[0])
                                except (ValueError, IndexError):
                                    continue
                                # GitHub step bounds have whole-second precision;
                                # log timestamps have fractional seconds.
                                if start <= stamp and stamp.timestamp() < end.timestamp() + 1:
                                    relevant.append((number, line))
                            text = '\n'.join(line for _, line in relevant)
                            exits = re.findall(r'Process completed with exit code (\d+)', text)
                            if exits:
                                record['observed_command_exit'] = int(exits[-1])
                            if (step['name'] == 'CI run metrics self-test'
                                    and re.search(r'FAIL: legacy timing bundle did not fail closed', text)
                                    and 'Test Z:' in text):
                                record.update(corrected_category='historical_metrics_dependency_failure',
                                              observed_test='Test Z', cause_status='observed_dependency_error')
                                record['rejected_signature_status'] = ('passing_test_d' if any(
                                    'PASS: Test D: lint of --add result exits 0 (round-trip valid)' in line for line in lines) else 'unknown')
                            if not exits:
                                record['missing_details'].append('native_command_exit_not_retained')
                            if not relevant:
                                record['missing_details'].append('selected_step_context_not_retained')
                            if '[LOG EXCERPT TRUNCATED]' in text:
                                record['missing_details'].append('selected_log_truncated')
                            record['completeness'] = 'incomplete' if record['missing_details'] else 'complete'
                        except (OSError, ValueError, KeyError) as exc:
                            record['missing_details'].append('log_or_step_identity_invalid:' + str(exc))
                    result['records'].append(record)
    result['status'] = 'incomplete' if any(r['completeness'] != 'complete' for r in result['records']) else 'complete'
    return result
