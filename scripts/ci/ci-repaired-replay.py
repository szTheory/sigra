#!/usr/bin/env python3
"""Package and replay new repaired-control CI comparisons without Git objects."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile

SCHEMA = "sigra.ci-repaired-comparison-inputs/v1"
MAX_BYTES = 512 * 1024 * 1024
MAX_FILES = 8192
CALCULATION_FILES = (
    "scripts/ci/ci-run-metrics.sh",
    "scripts/ci/ci_metrics_security.py",
    "scripts/ci/ci-hosted-gate-verify.py",
    "scripts/ci/ci-hosted-transport.py",
    "scripts/ci/ci-browser-records.mjs",
    "scripts/ci/ci-browser-command.mjs",
    "scripts/ci/ci-playwright-report.mjs",
    "scripts/ci/exunit_timing_contract.py",
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(name):
    if (not isinstance(name, str) or not name or "\\" in name or "\x00" in name):
        raise ValueError("unsafe_input_path:" + str(name))
    path = PurePosixPath(name)
    if (path.is_absolute()
            or any(part in ("", ".", "..") for part in name.split("/"))
            or path.as_posix() != name):
        raise ValueError("unsafe_input_path:" + str(name))
    return name


def contained(root, value):
    root = Path(root).resolve()
    path = Path(value).resolve()
    if path != root and root not in path.parents:
        raise ValueError("input_path_outside_root:" + str(value))
    relative = path.relative_to(root)
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise ValueError("input_symlink_rejected:" + str(value))
    return relative.as_posix()


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("invalid_json:" + str(path)) from error


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _validate_source_members(contract, files):
    sources = contract.get("source_inputs") or {}
    refs = {
        "manifest": (sources.get("manifest_path"), sources.get("manifest_sha256")),
        "method": (sources.get("method_path"), sources.get("method_sha256")),
    }

    def member(path, expected, label):
        safe_path(path)
        raw = files.get(path)
        if raw is None:
            raise ValueError("source_input_missing:" + label + ":" + path)
        if sha256(raw) != expected:
            raise ValueError("source_input_sha256_mismatch:" + label + ":" + path)
        return raw

    if any(not isinstance(path, str) or not isinstance(expected, str)
           for path, expected in refs.values()):
        raise ValueError("source_manifest_or_method_reference_missing")
    source_doc = json.loads(member(*refs["manifest"], "manifest"))
    method_doc = json.loads(member(*refs["method"], "method"))
    source_rows = source_doc.get("sources") or {}
    if set(source_rows) != {"common", "control", "candidate"}:
        raise ValueError("source_manifest_roles_invalid")
    source_hashes = {}
    for role in ("common", "control", "candidate"):
        row = source_rows[role]
        source_hashes[role] = {}
        for kind in ("archive", "patch"):
            ref = row.get(kind) or {}
            raw = member(ref.get("path"), ref.get("sha256"), role + "_" + kind)
            source_hashes[role][kind] = sha256(raw)
    baseline_path = (contract.get("replay_inputs") or {}).get("baseline_source_bundle")
    baseline = files.get(baseline_path)
    expected_baseline = ((contract.get("baseline_identity") or {}).get("source_bundle_sha256"))
    if baseline is None or not isinstance(expected_baseline, str) or sha256(baseline) != expected_baseline:
        raise ValueError("baseline_source_bundle_hash_mismatch")
    if sha256(files[source_rows["control"]["archive"]["path"]]) != expected_baseline:
        raise ValueError("control_archive_is_not_pinned_baseline")
    if method_doc.get("comparison_kind") != "repaired_control_pr":
        raise ValueError("frozen_method_comparison_kind_invalid")
    return {"manifest_sha256": refs["manifest"][1], "method_sha256": refs["method"][1],
            "source_hashes": source_hashes, "baseline_source_bundle_sha256": expected_baseline}


def package_inputs(contract_path, registrations_path, input_root, output):
    if Path(input_root).is_symlink():
        raise ValueError("input_root_symlink_rejected")
    root = Path(input_root).resolve()
    contract_rel = contained(root, contract_path)
    registrations_rel = contained(root, registrations_path)
    contract = read_json(root / contract_rel)
    if contract.get("comparison_kind") != "repaired_control_pr":
        raise ValueError("comparison_kind_must_be_repaired_control_pr")
    _validate_comparability_contract(contract)
    replay_paths = contract.get("replay_inputs") or {}
    if set(replay_paths) != {"before_bundle", "after_bundle", "baseline_source_bundle"}:
        raise ValueError("replay_input_paths_incomplete")
    for name, relative in replay_paths.items():
        safe_path(relative)
        target = root / relative
        expected_type = target.is_dir() if name in ("before_bundle", "after_bundle") else target.is_file()
        if not target.exists() or target.is_symlink() or not expected_type:
            raise ValueError("replay_input_missing_or_symlinked:" + name + ":" + relative)
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError("package_output_already_exists")
    output_resolved = output.resolve()
    if output_resolved == root or root in output_resolved.parents:
        raise ValueError("package_output_inside_input_root")

    allowed = {contract_rel, registrations_rel, *CALCULATION_FILES}

    def add_declared_path(value, label):
        relative = safe_path(value)
        contained(root, root / relative)
        allowed.add(relative)
        return relative

    for name in replay_paths.values():
        safe_path(name)
    for bundle_name in (replay_paths["before_bundle"], replay_paths["after_bundle"]):
        bundle_root = root / bundle_name
        for path in sorted(bundle_root.rglob("*")):
            if path.is_symlink():
                raise ValueError("input_symlink_rejected:" + path.relative_to(root).as_posix())
            if path.is_file():
                allowed.add(safe_path(path.relative_to(root).as_posix()))

    source_inputs = contract.get("source_inputs") or {}
    manifest_rel = add_declared_path(source_inputs.get("manifest_path"), "source_manifest")
    method_rel = add_declared_path(source_inputs.get("method_path"), "frozen_method")
    source_doc = read_json(root / manifest_rel)
    source_rows = source_doc.get("sources") or {}
    if set(source_rows) != {"common", "control", "candidate"}:
        raise ValueError("source_manifest_roles_invalid")
    for role in ("common", "control", "candidate"):
        row = source_rows[role]
        for kind in ("archive", "patch"):
            add_declared_path((row.get(kind) or {}).get("path"), role + "_" + kind)
    add_declared_path(replay_paths["baseline_source_bundle"], "baseline_source_bundle")
    coverage = contract.get("native_coverage_comparison") or {}
    for path_field, digest_field in (("mapping_path", "mapping_sha256"),
                                     ("parity_receipt_path", "parity_receipt_sha256")):
        relative = add_declared_path(coverage.get(path_field), path_field)
        expected = coverage.get(digest_field)
        if (not isinstance(expected, str)
                or sha256((root / relative).read_bytes()) != expected):
            raise ValueError("native_coverage_input_digest_mismatch:" + path_field)

    actual = set()
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError("input_symlink_rejected:" + path.relative_to(root).as_posix())
        if path.is_file():
            relative = safe_path(path.relative_to(root).as_posix())
            if relative.startswith("scripts/ci/__pycache__/"):
                continue
            actual.add(relative)
    unexpected = sorted(actual - allowed)
    if unexpected:
        raise ValueError("unexpected_input_file:" + unexpected[0])
    missing = sorted(allowed - actual)
    if missing:
        if missing[0] in CALCULATION_FILES:
            raise ValueError("calculation_dependency_missing:" + missing[0])
        raise ValueError("declared_input_missing:" + missing[0])

    files = {}
    total = 0
    for name in sorted(allowed):
        path = root / name
        raw = path.read_bytes()
        total += len(raw)
        if total > MAX_BYTES or len(files) >= MAX_FILES:
            raise ValueError("package_size_limit")
        files[name] = raw
    source_identity = _validate_source_members(contract, files)
    members = [{"path": name, "size": len(raw), "sha256": sha256(raw)}
               for name, raw in sorted(files.items())]
    manifest = {
        "schema_version": SCHEMA,
        "calculation_version": {name: sha256(files[name]) for name in CALCULATION_FILES},
        "contract_path": contract_rel,
        "registrations_path": registrations_rel,
        "replay_inputs": replay_paths,
        "source_identity": source_identity,
        "members": members,
        "package_status": "ready",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output, "w:gz") as archive:
        entries = [("INPUTS.json", (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode())]
        entries.extend(sorted(files.items()))
        for name, raw in entries:
            info = tarfile.TarInfo(safe_path(name))
            info.size = len(raw)
            info.mode = 0o600
            archive.addfile(info, io.BytesIO(raw))
    return manifest


def _validate_comparability_contract(contract):
    contexts = contract.get("required_contexts")
    apps = contract.get("required_check_apps")
    if (not isinstance(contexts, list) or len(contexts) != 5 or len(set(contexts)) != 5
            or not isinstance(apps, dict) or set(apps) != set(contexts)
            or any(type(value) is not int or value <= 0 for value in apps.values())):
        raise ValueError("required_check_apps_must_bind_exact_five_contexts")
    cache = contract.get("cache_eligibility") or {}
    owners = {"library", "admin_behavior", "admin_checkpoints", "design_gallery",
              "non_admin_smoke", "demo_showcase"}
    role_keys = cache.get("expected_keys") or {}
    if not isinstance(cache.get("default_branch_ref"), str) or not cache["default_branch_ref"].startswith("refs/heads/"):
        raise ValueError("cache_default_branch_ref_missing")
    if set(role_keys) != {"before", "after"}:
        raise ValueError("cache_expected_key_roles_invalid")
    for role in ("before", "after"):
        owner_keys = role_keys.get(role)
        if not isinstance(owner_keys, dict) or set(owner_keys) != owners:
            raise ValueError("cache_expected_key_owners_incomplete:" + role)
        for owner, components in owner_keys.items():
            if (not isinstance(components, dict) or not components
                    or any(not isinstance(component, str) or not component
                           or not isinstance(key, str) or not key
                           for component, key in components.items())):
                raise ValueError("cache_expected_component_key_missing:" + role + ":" + owner)


def stable_family_order(rows):
    """Order diagnostics by observed wait, then immutable family ID; null waits stay last."""
    return sorted(rows, key=lambda row: (
        not isinstance(row.get("required_result_wait_seconds"), (int, float)),
        row.get("required_result_wait_seconds")
        if isinstance(row.get("required_result_wait_seconds"), (int, float)) else 0,
        str(row.get("family_id") or "")))


def verify_package(package):
    files = {}
    total = 0
    try:
        with tarfile.open(package, "r:gz") as archive:
            for member in archive:
                name = safe_path(member.name)
                if name in files or not member.isfile() or member.size < 0:
                    raise ValueError("unsafe_or_duplicate_archive_member:" + name)
                total += member.size
                if total > MAX_BYTES or len(files) >= MAX_FILES:
                    raise ValueError("package_size_limit")
                stream = archive.extractfile(member)
                if stream is None:
                    raise ValueError("archive_member_unreadable:" + name)
                files[name] = stream.read()
    except (tarfile.TarError, OSError) as error:
        raise ValueError("package_archive_invalid") from error
    if "INPUTS.json" not in files:
        raise ValueError("package_manifest_missing")
    manifest = json.loads(files.pop("INPUTS.json"))
    if manifest.get("schema_version") != SCHEMA or manifest.get("package_status") != "ready":
        raise ValueError("package_manifest_invalid")
    rows = manifest.get("members")
    if not isinstance(rows, list):
        raise ValueError("package_members_invalid")
    declared = {}
    for row in rows:
        name = safe_path(row.get("path"))
        if name in declared:
            raise ValueError("duplicate_input:" + name)
        declared[name] = row
    for name in declared:
        parts = PurePosixPath(name).parts
        if any("/".join(parts[:index]) in declared for index in range(1, len(parts))):
            raise ValueError("package_path_collision:" + name)
    if set(declared) != set(files):
        missing = sorted(set(declared) - set(files))
        extra = sorted(set(files) - set(declared))
        raise ValueError("package_member_set_mismatch:missing=" + ",".join(missing) + ";extra=" + ",".join(extra))
    for name, raw in files.items():
        row = declared[name]
        if len(raw) != row.get("size") or sha256(raw) != row.get("sha256"):
            raise ValueError("input_sha256_mismatch:" + name)
    for name in CALCULATION_FILES:
        if name not in files or manifest.get("calculation_version", {}).get(name) != sha256(files[name]):
            raise ValueError("calculation_dependency_digest_mismatch:" + name)
    contract = json.loads(files[safe_path(manifest.get("contract_path"))])
    if _validate_source_members(contract, files) != manifest.get("source_identity"):
        raise ValueError("source_manifest_identity_mismatch")
    return manifest, files


def _unpack_verified(manifest, files, root):
    # Every member and digest has been checked before the first filesystem write.
    root = Path(root)
    for name, raw in files.items():
        target = root / safe_path(name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)


def _replay_in_root(root, manifest):
    contract_path = root / safe_path(manifest["contract_path"])
    registrations_path = root / safe_path(manifest["registrations_path"])
    contract = read_json(contract_path)
    if contract.get("comparison_kind") != "repaired_control_pr":
        raise ValueError("comparison_kind_must_be_repaired_control_pr")
    _validate_comparability_contract(contract)
    paths = contract.get("replay_inputs") or {}
    if paths != manifest.get("replay_inputs"):
        raise ValueError("replay_path_manifest_mismatch")
    before = root / safe_path(paths["before_bundle"])
    after = root / safe_path(paths["after_bundle"])
    baseline = root / safe_path(paths["baseline_source_bundle"])
    hashes = {name: sha256(raw) for name, raw in ((p.relative_to(root).as_posix(), p.read_bytes())
                                                   for p in root.rglob("*") if p.is_file())}
    deny = Path(tempfile.mkdtemp(prefix="sigra-repaired-replay-deny-"))
    log = deny / "network-attempts"
    for command in ("gh", "curl", "wget", "ssh", "git", "npm", "npx"):
        stub = deny / command
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >>"$SIGRA_REPLAY_NETWORK_LOG"\nexit 97\n')
        stub.chmod(0o700)
    env = {**os.environ, "PATH": str(deny) + os.pathsep + os.environ.get("PATH", ""),
           "PYTHONDONTWRITEBYTECODE": "1", "SIGRA_REPLAY_NETWORK_LOG": str(log),
           "PYTHONPATH": str(root / "scripts/ci")}
    command = ["bash", str(root / "scripts/ci/ci-run-metrics.sh"), "--evaluate-comparison",
               "--contract", str(contract_path), "--registrations", str(registrations_path),
               "--before-bundle", str(before), "--after-bundle", str(after),
               "--baseline-source-bundle", str(baseline), "--format", "json"]
    sandbox = shutil.which("sandbox-exec")
    if sandbox:
        command = [sandbox, "-p", "(version 1) (deny network*)", *command]
    else:
        network_ns = shutil.which("unshare")
        if not network_ns:
            raise ValueError("network_sandbox_unavailable")
        command = [network_ns, "--user", "--map-root-user", "--net", *command]
    try:
        result = subprocess.run(command, cwd=root, env=env, capture_output=True,
                                text=True, timeout=300)
        if log.exists():
            raise ValueError("replay_network_command_attempted:" + log.read_text())
        if result.returncode:
            raise ValueError("calculation_failed:" + result.stderr[-5000:] + result.stdout[-1000:])
        changed = [name for name, expected in hashes.items()
                   if not (root / name).is_file() or sha256((root / name).read_bytes()) != expected]
        if changed:
            raise ValueError("replay_changed_inputs:" + ",".join(changed))
        try:
            value = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise ValueError("calculator_output_invalid_json") from error
        return value, hashes
    finally:
        shutil.rmtree(deny, ignore_errors=True)


def replay_inputs(package, output):
    manifest, files = verify_package(package)
    with tempfile.TemporaryDirectory(prefix="sigra-repaired-replay-") as tmp:
        root = Path(tmp).resolve()
        _unpack_verified(manifest, files, root)
        result, input_hashes = _replay_in_root(root, manifest)
    result = {**result, "replay": {"schema_version": SCHEMA,
                                  "package_sha256": sha256(Path(package).read_bytes()),
                                  "input_hashes": input_hashes,
                                  "calculation_version": manifest["calculation_version"],
                                  "network_disabled": True}}
    write_json(output, result)
    return result


def render_report(package, result_path, output):
    manifest, files = verify_package(package)
    result = read_json(result_path)
    if result.get("replay", {}).get("schema_version") != SCHEMA:
        raise ValueError("result_is_not_repaired_replay")
    replay_identity = result["replay"]
    if replay_identity.get("package_sha256") != sha256(Path(package).read_bytes()):
        raise ValueError("result_package_identity_mismatch")
    expected_input_hashes = {row["path"]: row["sha256"] for row in manifest["members"]}
    if replay_identity.get("input_hashes") != expected_input_hashes:
        raise ValueError("result_input_hashes_mismatch")
    if replay_identity.get("calculation_version") != manifest["calculation_version"]:
        raise ValueError("result_calculation_version_mismatch")
    contract = json.loads(files[manifest["contract_path"]])
    registrations = json.loads(files[manifest["registrations_path"]])
    metrics = result.get("metrics") or {}
    replay_paths = manifest["replay_inputs"]
    family_observations = []
    for role, input_name in (("before", "before_bundle"), ("after", "after_bundle")):
        family_manifest = safe_path(replay_paths[input_name] + "/manifest.json")
        raw = files.get(family_manifest)
        if raw is None:
            raise ValueError("family_manifest_missing:" + family_manifest)
        families = json.loads(raw).get("comparison_families")
        if not isinstance(families, list):
            raise ValueError("family_inputs_missing:" + role)
        for row in families:
            family_observations.append({
                "family_role": role,
                "pair_id": row.get("pair_id"),
                "family_id": row.get("family_id"),
                "run_id": row.get("run_id"),
                "run_attempt": row.get("run_attempt"),
                "conclusion": row.get("conclusion"),
                "required_result_wait_seconds": row.get("required_result_wait_seconds"),
                "runner_seconds": row.get("runner_seconds"),
                "cache_stratum": row.get("cache_stratum"),
                "cache_key_scope": row.get("cache_key_scope"),
                "runner_image": row.get("runner_image"),
                "attempts": row.get("attempts"),
            })
    report = {
        "schema_version": "sigra.ci-repaired-comparison-report/v1",
        "experiment": "new repaired-control comparison; synthetic fixture inputs are not acceptance evidence",
        "status": result.get("status"),
        "performance_verdict": result.get("performance_verdict"),
        "sample_count": metrics.get("comparable_successful_pairs"),
        "window": contract.get("window"),
        "estimators": {key: metrics.get(key) for key in (
            "baseline_median_seconds", "candidate_median_seconds", "baseline_p95_seconds",
            "candidate_p95_seconds", "baseline_runner_seconds", "candidate_runner_seconds", "p95_method")},
        "thresholds": {"candidate_median_max_ratio": 0.8,
                       "candidate_p95_max_ratio": 1.0,
                       "candidate_runner_seconds_max_ratio": 1.0,
                       "inclusive": True},
        "family_attempt_costs": sorted(metrics.get("family_attempt_costs") or [],
                                        key=lambda row: (str(row.get("pair_id") or ""),
                                                         str(row.get("family_role") or ""))),
        "family_observations": stable_family_order(family_observations),
        "pair_count": metrics.get("pair_count"),
        "diagnostics": result.get("diagnostics"),
        "native_parity": metrics.get("native_parity"),
        "identities": {"contract_sha256": sha256(files[manifest["contract_path"]]),
                       "registrations_sha256": sha256(files[manifest["registrations_path"]]),
                       "input_package_sha256": replay_identity.get("package_sha256"),
                       "calculation_source_sha256": manifest["calculation_version"],
                       "source_manifest_sha256": manifest["source_identity"]["manifest_sha256"],
                       "method_sha256": manifest["source_identity"]["method_sha256"],
                       "baseline_source_bundle_sha256": manifest["source_identity"]["baseline_source_bundle_sha256"],
                       "source_hashes": manifest["source_identity"]["source_hashes"],
                       "registered_families": len(registrations.get("records") or [])},
        "limitations": ["Empirical p95 describes this sample and does not guarantee future tail latency.",
                        "The repaired-control experiment is separate from the unchanged Phase 252 baseline and Phase 254 historical insufficient_data result.",
                        "Local synthetic fixtures are implementation checks, not hosted speed acceptance."],
    }
    write_json(output, report)
    return report


def verify_result(package, result_path):
    manifest, files = verify_package(package)
    expected = read_json(result_path)
    replay = expected.get("replay") or {}
    if replay.get("schema_version") != SCHEMA:
        raise ValueError("result_is_not_repaired_replay")
    if replay.get("package_sha256") != sha256(Path(package).read_bytes()):
        raise ValueError("result_package_identity_mismatch")
    if replay.get("network_disabled") is not True:
        raise ValueError("result_does_not_record_network_isolation")
    if replay.get("input_hashes") != {row["path"]: row["sha256"] for row in manifest["members"]}:
        raise ValueError("result_input_hashes_mismatch")
    if replay.get("calculation_version") != manifest["calculation_version"]:
        raise ValueError("result_calculation_version_mismatch")
    with tempfile.TemporaryDirectory(prefix="sigra-repaired-result-check-") as tmp:
        root = Path(tmp).resolve()
        _unpack_verified(manifest, files, root)
        actual, hashes = _replay_in_root(root, manifest)
    expected_result = {key: value for key, value in expected.items() if key != "replay"}
    if actual != expected_result:
        raise ValueError("result_does_not_match_replay")
    if replay.get("input_hashes") != hashes or replay.get("package_sha256") != sha256(Path(package).read_bytes()):
        raise ValueError("result_replay_identity_mismatch")
    return {"status": "verified", "package_sha256": replay["package_sha256"],
            "result_sha256": sha256(Path(result_path).read_bytes()), "network_disabled": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    package = commands.add_parser("package", help="validate and package every declared replay input")
    package.add_argument("--contract", required=True)
    package.add_argument("--registrations", required=True)
    package.add_argument("--input-root", required=True)
    package.add_argument("--output", required=True)
    replay = commands.add_parser("replay", help="run the pinned existing evaluator offline")
    replay.add_argument("--package", required=True)
    replay.add_argument("--output", required=True)
    report = commands.add_parser("report", help="render a full observation report from a verified package")
    report.add_argument("--package", required=True)
    report.add_argument("--result", required=True)
    report.add_argument("--output", required=True)
    check = commands.add_parser("verify-result", help="recalculate and verify a saved result")
    check.add_argument("--package", required=True)
    check.add_argument("--result", required=True)
    args = parser.parse_args()
    try:
        if args.command == "package":
            value = package_inputs(args.contract, args.registrations, args.input_root, args.output)
        elif args.command == "replay":
            value = replay_inputs(args.package, args.output)
        elif args.command == "report":
            value = render_report(args.package, args.result, args.output)
        else:
            value = verify_result(args.package, args.result)
        print(json.dumps(value, sort_keys=True))
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        print("ci-repaired-replay: FAIL: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
