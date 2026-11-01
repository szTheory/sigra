#!/usr/bin/env python3
"""Build explicitly synthetic, complete repaired-comparison replay inputs.

No network or Git object is needed. Forty independently identified recorded
families are constructed and hashed using the same schemas exercised by the
real collector integration test. They are never hosted acceptance evidence.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OWNERS = ("library", "admin_behavior", "admin_checkpoints", "design_gallery", "non_admin_smoke", "demo_showcase")
CALCULATION_FILES = (
    "scripts/ci/ci-run-metrics.sh", "scripts/ci/ci_metrics_security.py",
    "scripts/ci/ci-hosted-gate-verify.py", "scripts/ci/ci-hosted-transport.py",
    "scripts/ci/ci-browser-records.mjs", "scripts/ci/ci-browser-command.mjs",
    "scripts/ci/ci-playwright-report.mjs", "scripts/ci/exunit_timing_contract.py",
)


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")


def read(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def _source_archive(path, files):
    with Path(path).open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as archive:
            for name, raw in sorted(files.items()):
                item = tarfile.TarInfo(name)
                item.size = len(raw)
                item.mode = 0o600
                item.mtime = 0
                archive.addfile(item, io.BytesIO(raw))


def set_pair_count(input_root, count):
    """Retain all observed costs/origins, materialize only the first count pairs."""
    if type(count) is not int or not 0 <= count <= 20:
        raise ValueError("valid_pair_count_must_be_0_through_20")
    root = Path(input_root)
    for side in ("before", "after"):
        path = root / side / "manifest.json"
        manifest = read(path)
        all_rows = manifest.get("synthetic_all_comparison_families", manifest["comparison_families"])
        manifest["synthetic_all_comparison_families"] = all_rows
        manifest["comparison_families"] = all_rows[:count]
        write(path, manifest)


def build_repaired_fixture(output_root, *, valid_pair_count=20, candidate_wait_seconds=None,
                           candidate_runner_cost_seconds=120, reverse_family_order=False):
    """Return paths under a new/empty caller-owned directory.

    Default equality boundary: control median/p95=100/100, candidate=80/100,
    and both sides cost120 seconds per family. One control infrastructure retry
    remains inside its original run and costs20+50+50=120; all other families
    cost50 required-job seconds plus70 post-check seconds. Knobs modify native
    jobs/check timestamps together. Selecting fewer pairs retains all raw costs.
    """
    output = Path(output_root).resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("fixture_output_must_be_new_or_empty")
    output.mkdir(parents=True, exist_ok=True)
    waits = list(candidate_wait_seconds) if candidate_wait_seconds is not None else [80] * 18 + [100] * 2
    if len(waits) != 20 or any(not isinstance(value, (int, float)) or value < 10 for value in waits):
        raise ValueError("candidate_wait_seconds_requires_twenty_values_at_least_10")
    if not isinstance(candidate_runner_cost_seconds, (int, float)) or candidate_runner_cost_seconds < 50:
        raise ValueError("candidate_runner_cost_seconds_must_be_at_least_50")
    project = output / "inputs"
    (project / "scripts/ci").mkdir(parents=True)
    generator = (ROOT / "scripts/ci/ci-run-metrics-comparison.test.sh").read_text().split(
        'python3 - "$TMP" "$ROOT" <<\'PY\'\n', 1)[1].split("\nPY\n", 1)[0]
    subprocess.run([sys.executable, "-B", "-", str(output), str(project)], input=generator,
                   text=True, check=True, capture_output=True)
    for side in ("before", "after"):
        shutil.move(str(output / side), project / side)
    for relative in CALCULATION_FILES:
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    security = _module("repaired_fixture_security", ROOT / "scripts/ci/ci_metrics_security.py")
    native_fixture = _module("repaired_collection_seed", ROOT / "scripts/ci/ci-repaired-collection.test.py")
    contract = read(output / "contract.json")
    contract.update(comparison_kind="repaired_control_pr", synthetic_fixture=True, acceptance_samples=0,
                    required_check_apps={name: 15368 for name in contract["required_contexts"]},
                    maximum_pair_start_gap_seconds=1800,
                    replay_inputs={"before_bundle": "before", "after_bundle": "after",
                                   "baseline_source_bundle": "sources/control.tar.gz"})
    contract.pop("experiment_kind", None)
    source_dir = project / "sources"
    source_dir.mkdir()
    common_files = {"fixture/application.txt": b"Explicitly synthetic common application.\n"}
    source_rows = {}
    for role, treatment in (("common", b"common"), ("control", b"sequential"), ("candidate", b"combined")):
        files = {**common_files, "fixture/treatment.txt": treatment + b"\n"}
        archive_path = source_dir / (role + ".tar.gz")
        _source_archive(archive_path, files)
        patch = source_dir / (role + ".patch")
        patch.write_text("--- a/fixture/treatment.txt\n+++ b/fixture/treatment.txt\n@@ -1 +1 @@\n-common\n+" + treatment.decode() + "\n")
        source_rows[role] = {"archive": {"path": str(archive_path.relative_to(project)), "sha256": digest(archive_path)},
                             "patch": {"path": str(patch.relative_to(project)), "sha256": digest(patch)},
                             "synthetic_fixture": True}
    source_rows["control"]["source_sha"] = "a" * 40
    source_rows["candidate"]["source_sha"] = "b" * 40
    write(source_dir / "SOURCES.json", {"schema_version": "sigra.synthetic-repaired-sources/v1", "sources": source_rows,
        "acceptance_samples": 0, "hosted_origin_available": False})
    method_path = source_dir / "METHOD.json"
    write(method_path, {"comparison_kind": "repaired_control_pr", "pair_count": 20, "median_ratio_maximum": 0.8,
        "p95_ratio_maximum": 1, "runner_cost_ratio_maximum": 1, "minimum_successful_pairs": 20,
        "p95_method": "nearest_rank", "synthetic_fixture": True, "acceptance_samples": 0})
    contract["source_inputs"] = {"manifest_path": "sources/SOURCES.json", "manifest_sha256": digest(source_dir / "SOURCES.json"),
                                 "method_path": "sources/METHOD.json", "method_sha256": digest(method_path)}
    contract["baseline_identity"]["source_bundle_sha256"] = digest(source_dir / "control.tar.gz")
    contract["baseline_identity"].update(application_sha="a" * 40, producer_source_sha="c" * 40)
    contract["candidate_identity"]["producer_source_sha"] = "d" * 40
    keys = {side: {owner: {"deps": f"synthetic-{side}-{owner}-exact-v1"} for owner in OWNERS} for side in ("before", "after")}
    contract["cache_eligibility"] = {"default_branch_ref": "refs/heads/main", "expected_keys": keys}
    # This calculator fixture preserves the currently supported balanced
    # alternating registration schedule. Production schedule authorization is
    # a separate contract concern, never granted by this synthetic utility.
    control_first = set(range(1, 21, 2))
    schedule = []
    for number in range(1, 21):
        for side in (("before", "after") if number in control_first else ("after", "before")):
            schedule.append({"pair_id": f"pair-{number:02d}", "family_role": side})
    contract["comparison_schedule"] = schedule
    contract["family_reservations"] = [{"reservation_id": f"r-{row['pair_id']}-{row['family_role']}", **row} for row in schedule]
    contexts = contract["required_contexts"]
    early_records = {}
    base_time = dt.datetime(2026, 10, 14, 10, tzinfo=dt.timezone.utc)
    stamp = lambda value: value.isoformat().replace("+00:00", "Z")
    for side in ("before", "after"):
        bundle = project / side
        manifest = read(bundle / "manifest.json")
        rows = manifest["comparison_families"]
        all_runs, requests = [], []
        write(bundle / "raw/comparison-repository.json", {"id": 1207487684, "full_name": "szTheory/sigra", "default_branch": "main"})
        repo_ref = {"path": "raw/comparison-repository.json", "sha256": digest(bundle / "raw/comparison-repository.json"),
                    "endpoint": "/repos/szTheory/sigra"}
        manifest["comparison_collection"] = {"role": side, "origin_status": "passed", "repository_identity": repo_ref}
        manifest["required_check_apps"] = contract["required_check_apps"]
        rules = [{"type": "required_status_checks", "ruleset_id": 1, "parameters": {
            "required_status_checks": [{"context": name, "integration_id": 15368} for name in contexts]}}]
        write(bundle / "raw/effective-rules.json", rules)
        write(bundle / "raw/branch-protection.json", {"contexts": contexts,
            "checks": [{"context": name, "app_id": 15368} for name in contexts]})
        manifest["source_sha256"].update(effective_rules=digest(bundle / "raw/effective-rules.json"),
                                         branch_protection=digest(bundle / "raw/branch-protection.json"))
        for index, row in enumerate(rows, 1):
            run_id = row["run_id"]
            family = bundle / "raw/families" / str(run_id)
            head = "a" * 40 if side == "before" else "b" * 40
            merge_sha = hashlib.sha1(f"synthetic-merge-{run_id}".encode()).hexdigest()
            tree_sha = hashlib.sha1(f"synthetic-tree-{side}".encode()).hexdigest()
            base_sha = "e" * 40
            number = 4000 + run_id
            first = "before" if index in control_first else "after"
            created = base_time + dt.timedelta(seconds=(index - 1) * 400 + (0 if side == first else 180))
            wait = 100 if side == "before" else waits[index - 1]
            retry = side == "before" and index == 1
            latest = 2 if retry else 1
            minimal = {"id": 700000 + number, "number": number,
                "url": f"https://api.github.com/repos/szTheory/sigra/pulls/{number}",
                "head": {"sha": head, "ref": f"synthetic/{side}-{index:02d}", "repo": {"id": 1207487684}},
                "base": {"sha": base_sha, "ref": "main", "repo": {"id": 1207487684}}}
            run = {"id": run_id, "event": "pull_request", "path": ".github/workflows/ci.yml", "head_sha": head,
                "created_at": stamp(created), "updated_at": stamp(created + dt.timedelta(seconds=wait + 70)),
                "run_attempt": latest, "status": "completed", "conclusion": "success", "check_suite_id": 800000 + run_id,
                "repository": {"id": 1207487684, "full_name": "szTheory/sigra"}, "pull_requests": [minimal]}
            full_pr = {**minimal, "merge_commit_sha": merge_sha, "state": "open"}
            merge = {"sha": merge_sha, "tree": {"sha": tree_sha}, "parents": [{"sha": base_sha}, {"sha": head}]}
            write(family / "run.json", run)
            write(family / "pull-request.json", full_pr)
            write(family / "merge-commit.json", merge)
            job_rows, checks = [], []
            for offset, name in enumerate(contexts, 1):
                jid = run_id * 100 + offset
                job_rows.append({"id": jid, "run_id": run_id, "run_attempt": latest, "head_sha": head,
                    "name": name, "status": "completed", "conclusion": "success",
                    "started_at": stamp(created + dt.timedelta(seconds=wait - 10)), "completed_at": stamp(created + dt.timedelta(seconds=wait))})
                checks.append({"id": jid + 1000000, "external_id": str(jid), "name": name, "head_sha": head,
                    "status": "completed", "conclusion": "success", "completed_at": stamp(created + dt.timedelta(seconds=wait)),
                    "app": {"slug": "github-actions", "id": 15368}, "check_suite": {"id": run["check_suite_id"]}})
            cost = 120 if side == "before" else candidate_runner_cost_seconds
            post_cost = cost - 50 - (20 if retry else 0)
            job_rows.append({"id": run_id * 100 + 90, "run_id": run_id, "run_attempt": latest, "head_sha": head,
                "name": "post-check diagnostics", "status": "completed", "conclusion": "success",
                "started_at": stamp(created + dt.timedelta(seconds=wait)),
                "completed_at": stamp(created + dt.timedelta(seconds=wait + post_cost))})
            attempt_refs = {}
            for old in family.glob("jobs-attempt-*.json"):
                old.unlink()
            attempts = {str(latest): job_rows}
            if retry:
                attempts["1"] = [{"id": run_id * 100 + 99, "run_id": run_id, "run_attempt": 1, "head_sha": head,
                    "name": "runner infrastructure failure", "status": "completed", "conclusion": "failure",
                    "started_at": stamp(created), "completed_at": stamp(created + dt.timedelta(seconds=20))}]
            for attempt, jobs in sorted(attempts.items()):
                path = family / f"jobs-attempt-{attempt}.json"
                write(path, {"total_count": len(jobs), "jobs": jobs})
                endpoint = f"/repos/szTheory/sigra/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100"
                attempt_refs[attempt] = {"path": str(path.relative_to(bundle)), "sha256": digest(path), "endpoint": endpoint}
                requests.append(endpoint)
            write(family / "check-runs.json", {"total_count": len(checks), "check_runs": checks})
            artifacts, evidence, derived, metadata_rows = [], [], [], []
            artifact_root = family / "artifacts"
            (artifact_root / "777.zip").unlink()
            shutil.rmtree(artifact_root / "777")
            for owner_index, owner in enumerate(OWNERS):
                metadata = {"repository": "szTheory/sigra", "run_id": str(run_id), "run_attempt": str(latest),
                    "source_sha": merge_sha, "matrix_seam": None if owner == "library" else owner,
                    "job_name": "Library tests shard" if owner == "library" else "Example Playwright shard",
                    "cache_outcome": {"deps": {"cache_hit": True, "exact_key": True, "matched_cache_key": keys[side][owner]["deps"],
                        "scope": "refs/heads/main", "ref": f"refs/pull/{number}/merge", "conditions": ["Linux", "X64", owner]}}}
                native_fixture.image_proof(metadata)
                metadata_rows.append(metadata)
                aid = run_id * 1000 + owner_index + 1
                extracted = artifact_root / str(aid)
                extracted.mkdir()
                write(extracted / "ci-measurement-metadata.json", metadata)
                if owner != "library":
                    seed = artifact_root / "coverage" / owner
                    (extracted / "report.json").write_bytes((seed / "native.json").read_bytes())
                    (extracted / f"{owner}.selection.json").write_bytes((seed / "selection.json").read_bytes())
                    descriptor = read(seed / "coverage-source.json")
                    descriptor["reports"][0].update(path="report.json", selection_path="selection.json")
                    destination = artifact_root / "derived-native" / owner
                    destination.mkdir(parents=True)
                    shutil.copy2(extracted / "report.json", destination / "report.json")
                    shutil.copy2(extracted / f"{owner}.selection.json", destination / "selection.json")
                    write(destination / "coverage-source.json", descriptor)
                    derived.append({"owner": owner, "artifact_id": aid, "directory": str(destination.relative_to(bundle)),
                        "report_member_path": str((extracted / "report.json").relative_to(bundle)),
                        "file_sha256": {path.name: digest(path) for path in destination.iterdir()}})
                zip_path = artifact_root / f"{aid}.zip"
                with zipfile.ZipFile(zip_path, "w") as zipped:
                    for path in sorted(extracted.iterdir()):
                        zipped.writestr(zipfile.ZipInfo(path.name, date_time=(2026, 1, 1, 0, 0, 0)), path.read_bytes())
                artifact = {"id": aid, "name": f"synthetic-native-{owner}-{run_id}-{latest}", "expired": False,
                    "digest": "sha256:" + digest(zip_path), "workflow_run": {"id": run_id, "run_attempt": latest,
                        "head_sha": head, "repository_id": 1207487684}}
                artifacts.append(artifact)
                evidence.append({"artifact": artifact, "result": {"status": "accepted", "archive_sha256": digest(zip_path),
                    "members": [{"member": path.name, "sha256": digest(path)} for path in sorted(extracted.iterdir())]}})
            shutil.rmtree(artifact_root / "coverage")
            write(family / "artifacts-metadata.json", {"total_count": len(artifacts), "artifacts": artifacts})
            write(family / "artifact-evidence.json", evidence)
            detail = read(family / "manifest.json")
            detail.update(source_run_sha256=digest(family / "run.json"), attempt_jobs=attempt_refs,
                check_runs_sha256=digest(family / "check-runs.json"), artifact_metadata_sha256=digest(family / "artifacts-metadata.json"),
                artifact_evidence={"path": str((family / "artifact-evidence.json").relative_to(bundle)), "sha256": digest(family / "artifact-evidence.json")},
                pull_request={"path": str((family / "pull-request.json").relative_to(bundle)), "sha256": digest(family / "pull-request.json"),
                    "endpoint": f"/repos/szTheory/sigra/pulls/{number}"},
                merge_commit={"path": str((family / "merge-commit.json").relative_to(bundle)), "sha256": digest(family / "merge-commit.json"),
                    "endpoint": f"/repos/szTheory/sigra/git/commits/{merge_sha}"}, derived_native_coverage=derived)
            write(family / "manifest.json", detail)
            images = security.comparison_runner_images(metadata_rows, require_proof=True)
            row.update(created_at=run["created_at"], source_workload_revision_sha256="workload-sha",
                coverage_map_sha256=contract["native_coverage_comparison"]["mapping_sha256"],
                runner_class=images, runner_image=images, cache_components={owner: ["deps"] for owner in OWNERS},
                cache_key_scope={owner: metadata_rows[offset]["cache_outcome"] for offset, owner in enumerate(OWNERS)},
                eligible_cache_scopes=["refs/heads/main", f"refs/pull/{number}/merge"],
                pull_request_number=number, pull_request_merge_sha=merge_sha,
                attempts=[{"retry": True, "classification": "infrastructure_failure", "diagnosed": True}] if retry else [])
            all_runs.append({**run, "detail_status": "complete", "workload": "full", "attempt_jobs": attempt_refs})
            early_records[(row["pair_id"], side)] = (run, full_pr, merge)
        population_path = bundle / "raw/populations/pull_request.json"
        population = read(population_path)
        population["runs"] = all_runs
        write(population_path, population)
        write(bundle / "request-ledger.json", {"requests": requests})
        manifest["populations"]["pull_request"] = population
        manifest["source_sha256"].update(pull_request=digest(population_path), request_ledger=digest(bundle / "request-ledger.json"))
        write(bundle / "manifest.json", manifest)
    write(project / "contract.json", contract)
    ledger = None
    for reservation in contract["family_reservations"]:
        run, pr, merge = early_records[(reservation["pair_id"], reservation["family_role"])]
        early = {**run, "status": "in_progress", "conclusion": None}
        raw = (json.dumps(early, sort_keys=True, separators=(",", ":")) + "\n").encode()
        ledger = security.register_comparison_run(contract, reservation["reservation_id"], early, ledger,
            hashlib.sha256(raw).hexdigest(), raw, pr, merge,
            json.dumps(pr, sort_keys=True, separators=(",", ":")).encode() + b"\n",
            json.dumps(merge, sort_keys=True, separators=(",", ":")).encode() + b"\n")
    write(project / "registrations.json", ledger)
    set_pair_count(project, valid_pair_count)
    if reverse_family_order:
        for side in ("before", "after"):
            path = project / side / "manifest.json"
            manifest = read(path)
            manifest["comparison_families"].reverse()
            write(path, manifest)
    return {"input_root": project, "contract_path": project / "contract.json", "registrations_path": project / "registrations.json",
        "before_bundle": project / "before", "after_bundle": project / "after", "baseline_source_bundle": source_dir / "control.tar.gz",
        "source_manifest": source_dir / "SOURCES.json", "method_path": method_path,
        "calculation_files": [project / relative for relative in CALCULATION_FILES], "synthetic_fixture": True, "acceptance_samples": 0}


def evaluate_fixture(paths):
    result = subprocess.run(["bash", str(Path(paths["input_root"]) / "scripts/ci/ci-run-metrics.sh"),
        "--evaluate-comparison", "--contract", str(paths["contract_path"]), "--registrations", str(paths["registrations_path"]),
        "--before-bundle", str(paths["before_bundle"]), "--after-bundle", str(paths["after_bundle"]),
        "--baseline-source-bundle", str(paths["baseline_source_bundle"]), "--format", "json"],
        cwd=paths["input_root"], capture_output=True, text=True, timeout=180)
    if result.returncode:
        raise ValueError("fixture_evaluator_failed:" + result.stderr[-5000:])
    return json.loads(result.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    paths = build_repaired_fixture(args.output_root)
    if args.verify:
        report = evaluate_fixture(paths)
        write(Path(args.output_root) / "RESULT.json", report)
        if report.get("status") != "pass" or report.get("metrics", {}).get("native_parity", {}).get("origins_verified") != 40:
            raise SystemExit(json.dumps(report.get("diagnostics"), indent=2))
    print(json.dumps({key: str(value) if isinstance(value, Path) else [str(item) for item in value]
        if isinstance(value, list) else value for key, value in paths.items()}, sort_keys=True))
