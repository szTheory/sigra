#!/usr/bin/env python3
"""Derive and verify Plan 80's zero-effect sequential-authority preallocation."""

from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


PHASE = Path(
    ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
)
SCHEMA = "sigra.phase235.1-plan80-preallocation-validation/v1"
ROOT_TEMPLATE = "/private/tmp/sigra-p2351-plan80-sequential-authority.XXXXXXXX"
PLAN76_ROOT = Path("/private/tmp/sigra-p2351-plan76-build-links.josc17x6")
PLAN78_ROOT = Path("/private/tmp/sigra-p2351-plan78-canonical-paths.0NFrtEIL")
PLAN79_ROOT = Path("/private/tmp/sigra-p2351-plan79-status-recovery.ULG0YI9N")

PREDECESSORS = {
    "235.1-04-PLAN.md": "b439e6898660f92ec8a9a232ebf7dbf77517f6de3b18ec7b8847e726f785f213",
    "235.1-04-SUMMARY.md": "2931fc78869aa5b3662c5a49723312bf822945d3761f171f8764990f941acf99",
    "235.1-10-PLAN.md": "c92c963057f17d7d89cbeee2535c8252dcc93e09d87271b1296a0caf460b1bc2",
    "235.1-10-SUMMARY.md": "86a4ac133a9f5426a577234862cb8b9b2b84876d9e019f446a12f5bfcc784281",
    "235.1-12-PLAN.md": "e7c9433802f9bc390434e33cadb5f4df952db833dad62ebb74d063179a7b48fc",
    "235.1-12-SUMMARY.md": "585c6c3db40bf4473172f61d83f42b84f62a2bb54194a982c58b1cd0eb09428c",
    "235.1-15-PLAN.md": "9ac2f664e2d99999e71a74408ec1d863a892c53ed571fa53535ba3103aff3f61",
    "235.1-15-SUMMARY.md": "e487b0ec66eb89f7bc439eba843c267a79d4bf08151c807cfbf996064a235522",
    "235.1-70-PLAN.md": "884bc14f1a616245244e8277ede4f56462eb672ee1bc60796413b8de614cc409",
    "235.1-76-PLAN.md": "9521f1263e242204dc27406fa46ca0df6168f168009072f465ba93cedaa6a84b",
    "235.1-76-SUMMARY.md": "da8632f927ede7e6054f2d44aa3713a93a1a7c4d227171a977a8cdcdb454ca0c",
    "235.1-76-PREALLOCATION-VALIDATION.json": "1f18e5eea1d75e05107d5cfb12bbf84bffb874f2baad13c588b7e318dab7e17f",
    "235.1-76-HOME-PROBE.json": "c6ec362e1fc99f62ca22238c9937129829631a306c8e450ab266e309f35f9fc7",
    "235.1-76-PREREQUISITE-VALIDATION.json": "e7df44f4c5165c5c04320bfeb094217a439f03c3bcd340264e2327dc8d11b213",
    "235.1-77-PLAN.md": "49156197bd74c6556b4e17f205f7fdc32cab701cf084e067ed52d5f81c94a71b",
    "235.1-77-SUMMARY.md": "e555b1d66c3aab4427a162f34da051ec167ba40c897d51aff22818cd1091424b",
    "235.1-77-PREALLOCATION-VALIDATION.json": "ee2100d18b6228f5c035217c8c7336fad61d30829c6962ed4e169fe43efef7cd",
    "235.1-78-PLAN.md": "bb7a996f6c5bf9c7d71b0f39464df6e6ec24cfca73cff12e284fc2a33d1a557a",
    "235.1-78-SUMMARY.md": "39bce31a5b03f2c5ad326e8eb6d0897ffcb0340183dc8091127c38c5c2883a2f",
    "235.1-78-verify-preallocation.py": "8df1699ab9ed643f8a65be8cda82231fcac067238244862133b76cb91bc4d2a0",
    "235.1-78-PREALLOCATION-VALIDATION.json": "9565b723530790827aa3b28f67077e14b3d008b7b188ce1c6c3eecde6088c912",
    "235.1-79-PLAN.md": "a29fff147433101a9b39c79d903aa9b81777571f56dfce621725b569b350dbef",
    "235.1-79-SUMMARY.md": "965d8b5c7e219a112923d7622e0b3fa6deb4fc5c33ba260a165f96891568b380",
    "235.1-79-verify-preallocation.py": "d5763688e0e156afa5516489db841ba81800f06f0c6216970b6b8107cd109779",
    "235.1-79-PREALLOCATION-VALIDATION.json": "e3d4884ddd1ee3c5a541d6fac78034b3b09495dfacefb7bdfb8f5c4c1c87b58a",
}

TOOLS = {
    "/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs": "e563417cf4b03401f609cf1bb97f611afba9210bbc4716172891adcb27810504",
    "/Users/jon/.codex/gsd-core/bin/lib/plan-dependency-graph.cjs": "d0b053bdbe4fad0010b4adb95e2f55af786cb7c1bf3da036ed6302db5f7e5cbc",
    "/Users/jon/.codex/gsd-core/bin/lib/plan-scan.cjs": "11731a44cf7b1f3d8a7e0fa469425b3b4317598cf9118a97f976243a96f61d8e",
}

SOURCES = {
    ".github/workflows/ci.yml": "ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682",
    "scripts/ci/install-golden.sh": "b68dfd02687486459b4fd1fb04bddc23844e4301e68a94373d5005967d29c89a",
    "scripts/ci/install-golden.test.sh": "9240eed665210ab2316cb83f1325222571c55bcc43b56ff1f94485073a1f1f9b",
    "scripts/ci/verify-library-install-golden.sh": "2d8e838951229c406d4295844d87c48f148c2743139dc93289deee6e210e6aa4",
    "scripts/ci/verify-library-install-golden.test.sh": "2e008e515f2be91dd1c98ef9f363541bc7cb21cee846a002b3167dc2975eaa20",
    "test/sigra/planning/phase_235_1_library_economics_contract_test.exs": "d81f71a2e1008756e6f8a988f30e1426ff900aee61fbacd90136d09040b9e06b",
    "test/support/ci/ex_unit_timing_formatter.ex": "e9ad6dbaaba24528c60be38f54ddd8d1e946ab539943dd744a1602eba4a29d0c",
    "scripts/ci/library-partitions.sh": "deae1229e1bfabea6924d2512db1293026d6904497c2ac804f0478afc04471dd",
    "test/support/ci/library_test_partitions.exs": "9384fce2c84de95681d1e1ef08c7efec5bf993c2bd0abf9837c169f2fdefb103",
    "test/support/ci/phase_235_1_evidence_state_contract.exs": "6cb58e74e463d977c228be94efbde05aa7609e4ca1357ca94509e90077bd7921",
    "test/support/install_fixture.ex": "e31568e6ff5103d775afdf546420644493e4bdbc8ecf5a40bb3b27e1926157dc",
}

RECEIVERS = [
    "test/sigra/install/features/passkeys_js_test.exs",
    "test/sigra/install/generator_passkeys_opt_out_test.exs",
    "test/sigra/install/golden_diff_test.exs",
    "test/sigra/install/idempotency_test.exs",
    "test/sigra/install/vault_promotion_test.exs",
    "test/upgrade_test.exs",
]
VARIANTS = [
    "default_installed",
    "passkeys_standard",
    "passkeys_nonstandard_app_js",
    "no_passkeys",
    "no_org_no_passkeys",
    "no_org_installed",
]
FIXED = {"1": "/tmp/sigra-library-1-timings.json", "2": "/tmp/sigra-library-2-timings.json"}
MANIFESTS = {
    1: "8edff82ae153955c27c0389ee742fb6cbdcebe8398b3212e40c84b32a169b3fb",
    2: "a55e32b413dffb5abe12cf49aeafb4acf5e7322809648218f04d3931aca64a91",
}
PAIR_KEYS = {"execution_mode", "ordinary_universe", "partitions", "schema_version"}
UNIVERSE_KEYS = {"count", "duplicate", "missing", "paths", "scaffold_leaks", "stale"}
PARTITION_KEYS = {
    "conclusion", "duration_ms", "end_ms", "exit_status", "id", "manifest_sha256",
    "paths", "start_ms", "timing_receipt_path",
}
EFFECTS = {
    "mix": 0,
    "postgresql": 0,
    "filesystem_root_allocation": 0,
    "formatter_receipt_output": 0,
    "exact_six": 0,
    "git": 0,
    "github_api": 0,
    "watcher": 0,
    "capture": 0,
    "validation": 0,
    "reconciliation": 0,
}
BUDGETS = {
    "filesystem_root_allocation": 1,
    "local_terminal_launcher": 1,
    "timing_children": 4,
    "exact_six": 1,
    "candidate_push": 1,
    "capture_pull_request": 1,
    "capture_workflow_dispatch": 1,
    "evidence_child_push": 1,
    "validation_pull_request": 1,
    "validation_workflow_dispatch": 1,
}
REMOTE_IDS = [
    "plan80-candidate-push",
    "plan80-capture-pull-request",
    "plan80-capture-workflow-dispatch",
    "plan80-evidence-child-push",
    "plan80-validation-pull-request",
    "plan80-validation-workflow-dispatch",
]
DIAGNOSTIC = {
    "action_id": "plan80-classified-transient-diagnostic-retry",
    "run_attempt_identity_slot": "plan80-classified-transient-diagnostic-run-attempt",
    "monitor_identity_slot": "plan80-classified-transient-diagnostic-monitor",
    "budgets": {"action": 1, "monitor_identity": 1, "run_attempt_identity": 1},
    "eligible_primaries": [REMOTE_IDS[1], REMOTE_IDS[2], REMOTE_IDS[4], REMOTE_IDS[5]],
    "consumed": {"action": 0, "monitor_identity": 0, "run_attempt_identity": 0},
}


class VerificationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def load_bytes(path: Path) -> bytes:
    try:
        before = os.lstat(path)
    except OSError as exc:
        raise VerificationError(f"cannot stat {path}: {exc}") from exc
    require(stat.S_ISREG(before.st_mode), f"not a regular file: {path}")
    require(before.st_nlink == 1, f"multiply linked input: {path}")
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        opened = os.fstat(fd)
        require(stat.S_ISREG(opened.st_mode), f"opened input is not regular: {path}")
        require(opened.st_nlink == 1, f"opened input is multiply linked: {path}")
        require((before.st_dev, before.st_ino) == (opened.st_dev, opened.st_ino), f"input changed during open: {path}")
        chunks: list[bytes] = []
        while True:
            chunk = os.read(fd, 1_048_576)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(fd)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pairs_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> Any:
    try:
        return json.loads(load_bytes(path).decode("utf-8"), object_pairs_hook=pairs_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"invalid JSON in {path}: {exc}") from exc


def text(data: bytes, label: str) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise VerificationError(f"non-UTF-8 input: {label}") from exc


def authenticate(root: Path, mapping: dict[str, str], prefix: Path | None = None) -> dict[str, bytes]:
    observed: dict[str, bytes] = {}
    for relative, expected in mapping.items():
        path = root / (prefix / relative if prefix else Path(relative))
        data = load_bytes(path)
        require(sha256(data) == expected, f"SHA-256 mismatch: {path}")
        observed[relative] = data
    return observed


def extract_block(source: str, pattern: str, label: str) -> str:
    match = re.search(pattern, source, re.S | re.M)
    require(match is not None, f"cannot derive {label}")
    return match.group("body")


def front_status(source: str, label: str) -> str:
    front = extract_block(source, r"\A---\n(?P<body>.*?)\n---", label)
    values = re.findall(r"^status:\s*([^\s#]+)\s*$", front, re.M)
    require(len(values) == 1, f"ambiguous status: {label}")
    return values[0]


def derive_runner_paths(source: str) -> list[str]:
    body = extract_block(source, r"^receiver_paths=\(\n(?P<body>.*?)\n\)$", "runner receiver paths")
    return [line.strip() for line in body.splitlines() if line.strip() and not line.lstrip().startswith("#")]


def derive_quoted_paths(source: str, pattern: str, label: str) -> list[str]:
    return re.findall(r'"(test/[^"\n]+\.exs)"', extract_block(source, pattern, label))


def derive_live_paths(root: Path) -> list[str]:
    proc = subprocess.run(
        ["git", "ls-files", "--", "test/**/*_test.exs", "test/*_test.exs"],
        cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20, check=False,
    )
    require(proc.returncode == 0, f"git tracked-file discovery failed: {proc.stderr.decode(errors='replace')}")
    discovered = []
    for raw in proc.stdout.decode().splitlines():
        if re.search(r"^\s*@moduletag\s+:scaffold\s*$", text(load_bytes(root / raw), raw), re.M):
            discovered.append(raw)
    return sorted(discovered)


def derive_variants(source: str) -> list[str]:
    body = extract_block(source, r"^\s*@variant_names\s*\[(?P<body>.*?)^\s*\]", "fixture variants")
    return re.findall(r":([a-z][a-z0-9_]*)", body)


def validate_plan76_pair() -> dict[str, Any]:
    pair_path = PLAN76_ROOT / "local/timing-pair-1.json"
    partition_paths = [
        PLAN76_ROOT / "local/timing-pair-1-partition-1.json",
        PLAN76_ROOT / "local/timing-pair-1-partition-2.json",
    ]
    expected_hashes = [
        "864d2b33994d4eb783f4e7e36ac3fe017eef234b6b0270d49f22feeb68810159",
        "e1a3a629be9c236818ec58b664798d30a9b686b5043f9be6b297b7b75eb06e22",
        "e57b188e22cf7ac1a80176811173f595167aa7e82d9d4fcfe94ab590270e933e",
    ]
    for path, expected in zip([pair_path, *partition_paths], expected_hashes):
        require(sha256(load_bytes(path)) == expected, f"Plan 76 receipt SHA drifted: {path}")
    pair = load_json(pair_path)
    require(isinstance(pair, dict) and set(pair) == PAIR_KEYS, "Plan 76 pair top-level schema drifted")
    require(pair["schema_version"] == "sigra.library-partitions/v1", "Plan 76 pair schema version drifted")
    require(pair["execution_mode"] == "sequential", "Plan 76 execution mode is not literal sequential")
    universe = pair["ordinary_universe"]
    require(isinstance(universe, dict) and set(universe) == UNIVERSE_KEYS, "Plan 76 universe schema drifted")
    require(universe["count"] == 225, "Plan 76 universe count drifted")
    for key in ("duplicate", "missing", "scaffold_leaks", "stale"):
        require(universe[key] == [], f"Plan 76 universe negative set is non-empty: {key}")
    require(len(universe["paths"]) == len(set(universe["paths"])) == 225, "Plan 76 universe paths drifted")
    partitions = pair["partitions"]
    require(isinstance(partitions, list) and len(partitions) == 2, "Plan 76 pair partition count drifted")
    expected_counts = {1: 114, 2: 111}
    expected_durations = {1: 12056, 2: 12949}
    admitted: set[str] = set()
    partition_receipts: list[dict[str, Any]] = []
    for row, receipt_path in zip(partitions, partition_paths):
        require(isinstance(row, dict) and set(row) == PARTITION_KEYS, "Plan 76 partition key schema drifted")
        pid = row["id"]
        require(pid in (1, 2), "Plan 76 partition id drifted")
        require(row["conclusion"] == "success" and row["exit_status"] == 0, f"Plan 76 partition {pid} is not green")
        require(row["manifest_sha256"] == MANIFESTS[pid], f"Plan 76 partition {pid} manifest drifted")
        require(row["timing_receipt_path"] == FIXED[str(pid)], f"Plan 76 partition {pid} fixed path drifted")
        require(row["duration_ms"] == expected_durations[pid] > 0, f"Plan 76 partition {pid} duration drifted")
        require(row["start_ms"] < row["end_ms"] and row["end_ms"] - row["start_ms"] == row["duration_ms"], f"Plan 76 partition {pid} timing is not monotonic")
        require(len(row["paths"]) == len(set(row["paths"])) == expected_counts[pid], f"Plan 76 partition {pid} cardinality drifted")
        require(admitted.isdisjoint(row["paths"]), "Plan 76 partitions overlap")
        admitted.update(row["paths"])
        receipt = load_json(receipt_path)
        require(isinstance(receipt, dict) and set(receipt) == {"excluded", "failed", "invalid", "partition", "passed", "schema_version", "skipped", "tests", "total"}, f"Plan 76 partition {pid} timing receipt schema drifted")
        require(receipt["schema_version"] == 1 and receipt["partition"] == str(pid), f"Plan 76 partition {pid} receipt identity drifted")
        require(receipt["failed"] == 0 and receipt["invalid"] == 0 and receipt["total"] > 0, f"Plan 76 partition {pid} receipt is not green")
        partition_receipts.append({"path": str(receipt_path), "sha256": expected_hashes[pid], "total": receipt["total"]})
    require(admitted == set(universe["paths"]), "Plan 76 pair does not cover its complete universe")
    return {
        "schema_version": pair["schema_version"],
        "execution_mode": pair["execution_mode"],
        "pair_path": str(pair_path),
        "pair_sha256": expected_hashes[0],
        "partition_receipts": partition_receipts,
        "partition_cardinalities": [114, 111],
        "partition_durations_ms": [12056, 12949],
        "unique_paths": 225,
        "pair_count_admitted": 1,
    }


def validate_plan79(inputs: dict[str, bytes]) -> dict[str, Any]:
    summary = text(inputs["235.1-79-SUMMARY.md"], "Plan 79 summary")
    receipt = json.loads(text(inputs["235.1-79-PREALLOCATION-VALIDATION.json"], "Plan 79 receipt"), object_pairs_hook=pairs_object)
    require(front_status(summary, "Plan 79 summary") == "halted", "Plan 79 summary is not halted")
    for literal in (
        str(PLAN79_ROOT), "16777229", "303572057",
        "c67ddc70f248934b8908a0c11509714792da9931b252ee03e1188da947079d10",
        "7c92062af05dafaf741482a20b183254919bdcb9cc0612e61f95fbb43a32f15b",
        "019d186e100a8764e4b9f06ebf4c3dfc67f5fbc186936c7260389c7f5947538b",
        "a475469c4156c3f50bbc282d9eba344d1f655c4ebe332f17525533be41dc2065",
    ):
        require(literal in summary, f"Plan 79 summary missing frozen authority: {literal}")
    st = os.lstat(PLAN79_ROOT)
    identity = {"device": st.st_dev, "inode": st.st_ino, "uid": st.st_uid, "gid": st.st_gid, "mode": format(stat.S_IMODE(st.st_mode), "04o")}
    require(stat.S_ISDIR(st.st_mode) and identity == {"device": 16777229, "inode": 303572057, "uid": 501, "gid": 0, "mode": "0700"}, "Plan 79 root identity drifted")
    expected_files = {
        ".allocation.once": "c67ddc70f248934b8908a0c11509714792da9931b252ee03e1188da947079d10",
        "local/root-identity.json": "7c92062af05dafaf741482a20b183254919bdcb9cc0612e61f95fbb43a32f15b",
        "local/verify-plan79-terminal.py": "019d186e100a8764e4b9f06ebf4c3dfc67f5fbc186936c7260389c7f5947538b",
        "local/task2-local-failure.json": "a475469c4156c3f50bbc282d9eba344d1f655c4ebe332f17525533be41dc2065",
    }
    live_files = sorted(str(path.relative_to(PLAN79_ROOT)) for path in PLAN79_ROOT.rglob("*") if path.is_file())
    require(live_files == sorted(expected_files), "Plan 79 root contains unexpected or missing files")
    for relative, expected in expected_files.items():
        require(sha256(load_bytes(PLAN79_ROOT / relative)) == expected, f"Plan 79 frozen file drifted: {relative}")
    failure = load_json(PLAN79_ROOT / "local/task2-local-failure.json")
    require(failure.get("schema") == "sigra.phase235.1-plan79-local-failure/v1" and failure.get("status") == "FAIL", "Plan 79 failure schema drifted")
    require(failure.get("failure", {}).get("actual_execution_mode") == "sequential" and failure.get("failure", {}).get("expected_by_embedded_verifier") == "parallel", "Plan 79 mismatch authority drifted")
    require(failure.get("failure", {}).get("stage", "").endswith("before first Plan 79 timing child"), "Plan 79 failure stage drifted")
    require(failure.get("consumed") == {"filesystem_root_allocation": 1, "local_terminal_launcher": 1, "timing_children": 0, "exact_six": 0, "git_remote_actions": 0, "github_api": 0, "watchers": 0}, "Plan 79 consumed ledger drifted")
    require(failure.get("remaining") == {"timing_children": 4, "exact_six": 1, "candidate_push": 1, "capture_pull_request": 1, "capture_workflow_dispatch": 1, "evidence_child_push": 1, "validation_pull_request": 1, "validation_workflow_dispatch": 1, "diagnostic_retry_triplet": 1}, "Plan 79 remaining ledger drifted")
    require(failure.get("retry_permitted") is False, "Plan 79 retry authority drifted")
    require(receipt.get("status") == "PASS" and receipt.get("effects") == EFFECTS, "Plan 79 preallocation authority drifted")
    return {"status": "halted", "root": str(PLAN79_ROOT), "identity": identity, "files": expected_files, "failure": failure, "preallocation_status": "PASS"}


def validate_plan77(inputs: dict[str, bytes]) -> dict[str, Any]:
    summary = text(inputs["235.1-77-SUMMARY.md"], "Plan 77 summary")
    receipt = json.loads(text(inputs["235.1-77-PREALLOCATION-VALIDATION.json"], "Plan 77 receipt"), object_pairs_hook=pairs_object)
    require(front_status(summary, "Plan 77 summary") == "halted", "Plan 77 summary is not halted")
    require("**Plan 77 roots allocated:** 0" in summary and "**Plan 77 Mix processes:** 0" in summary and "**Plan 77 GitHub actions:** 0" in summary, "Plan 77 zero-effect summary drifted")
    require(receipt.get("status") == "PASS" and receipt.get("effects") == EFFECTS, "Plan 77 receipt zero-effect authority drifted")
    require(receipt.get("unspent_one_shot_budgets") == {key: value for key, value in BUDGETS.items() if key not in ("filesystem_root_allocation", "local_terminal_launcher") and key != "timing_children"} | {"repeat_children": 4}, "Plan 77 unspent ledger drifted")
    return {"status": "halted", "root_count": 0, "mix_process_count": 0, "github_action_count": 0, "unspent_one_shot_budgets": receipt["unspent_one_shot_budgets"]}


def validate_plan78(inputs: dict[str, bytes]) -> dict[str, Any]:
    summary = text(inputs["235.1-78-SUMMARY.md"], "Plan 78 summary")
    receipt = json.loads(text(inputs["235.1-78-PREALLOCATION-VALIDATION.json"], "Plan 78 receipt"), object_pairs_hook=pairs_object)
    require(front_status(summary, "Plan 78 summary") == "halted" and receipt.get("status") == "PASS", "Plan 78 halt authority drifted")
    st = os.lstat(PLAN78_ROOT)
    identity = {"device": st.st_dev, "inode": st.st_ino, "uid": st.st_uid, "gid": st.st_gid, "mode": format(stat.S_IMODE(st.st_mode), "04o")}
    require(identity == {"device": 16777229, "inode": 302331219, "uid": 501, "gid": 0, "mode": "0700"}, "Plan 78 root identity drifted")
    process_path = PLAN78_ROOT / "local/process/plan78-repeat-1-partition-2.json"
    require(sha256(load_bytes(process_path)) == "337bd0c8f66b55da48feb5d03980aebe19e72c72c5ca7c15a86cbb22627aea61", "Plan 78 failure process drifted")
    require("repeat-1 partition-1 passed" in summary.lower() and "repeat-1 partition-2 exited 2" in summary.lower(), "Plan 78 orphan/failure facts drifted")
    return {"status": "halted", "root": str(PLAN78_ROOT), "identity": identity, "orphan_pairs_admitted": 0, "failure_process_sha256": sha256(load_bytes(process_path))}


def derive_schedule() -> list[dict[str, Any]]:
    rows = []
    for repeat in (1, 2):
        for partition in (1, 2):
            action = f"plan80-repeat-{repeat}-partition-{partition}"
            rows.append({
                "repeat": repeat,
                "partition_id": partition,
                "action_id": action,
                "raw_process_path": f"local/process/{action}.json",
                "archive_path": f"local/archive/{action}.json",
                "fixed_formatter_path": FIXED[str(partition)],
                "remove_fixed_output_before_child": True,
                "persist_raw_process_before_parse": True,
                "nofollow_reopen": True,
                "validate_receipt": True,
                "immediate_archive_before_reuse": True,
            })
    return rows


def run_json(root: Path, argv: list[str]) -> tuple[Any, str]:
    proc = subprocess.run(argv, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30, check=False)
    require(proc.returncode == 0, f"scheduler command failed: {argv}: {proc.stderr.decode(errors='replace')}")
    try:
        parsed = json.loads(proc.stdout, object_pairs_hook=pairs_object)
    except json.JSONDecodeError as exc:
        raise VerificationError(f"scheduler returned invalid JSON: {argv}: {exc}") from exc
    return parsed, sha256(proc.stdout)


def scheduler_authority(root: Path, inputs: dict[str, bytes]) -> dict[str, Any]:
    index, index_sha = run_json(root, ["node", "/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs", "phase-plan-index", "235.1", "--raw"])
    init, init_sha = run_json(root, ["node", "/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs", "query", "init.execute-phase", "235.1", "--raw"])
    raw = {
        "phase_plan_index": {"incomplete": index.get("incomplete"), "runnable": index.get("runnable"), "stdout_sha256": index_sha},
        "init_execute_phase": {"incomplete_plans": init.get("incomplete_plans"), "runnable_plans": init.get("runnable_plans"), "stdout_sha256": init_sha},
    }
    require(raw["phase_plan_index"]["incomplete"] == ["235.1-70", "235.1-80"] and raw["phase_plan_index"]["runnable"] == ["235.1-70", "235.1-80"], "phase-plan-index active set drifted")
    require(raw["init_execute_phase"]["incomplete_plans"] == ["235.1-70-PLAN.md", "235.1-80-PLAN.md"] and raw["init_execute_phase"]["runnable_plans"] == ["235.1-70-PLAN.md", "235.1-80-PLAN.md"], "init.execute-phase active set drifted")
    p80 = text(load_bytes(root / PHASE / "235.1-80-PLAN.md"), "Plan 80")
    p70 = text(inputs["235.1-70-PLAN.md"], "Plan 70")
    require(re.search(r"^wave:\s*1$", p80, re.M) and re.search(r"^depends_on:\s*\[\]$", p80, re.M), "Plan 80 dependency metadata drifted")
    require(re.search(r"^wave:\s*2$", p70, re.M) and re.search(r"^depends_on:\s*\[235\.1-80\]$", p70, re.M), "Plan 70 dependency metadata drifted")
    require("Plan 80" in p70 and "five" in p70 and "PASS" in p70, "Plan 70 success authority drifted")
    return {"raw": raw, "derived": {"execution_chain": ["235.1-80", "235.1-70"], "superseded_absent": ["235.1-04", "235.1-10", "235.1-12", "235.1-15"]}}


def run_contract(root: Path, argv: list[str], env_add: dict[str, str], selected: int | None) -> dict[str, Any]:
    env = os.environ.copy()
    env.update(env_add)
    proc = subprocess.run(argv, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90, check=False)
    require(proc.returncode == 0, f"bounded contract failed ({proc.returncode}): {argv}\n{proc.stderr.decode(errors='replace')}")
    observed = None
    if selected is not None:
        matches = re.findall(r"(\d+) tests?, 0 failures", (proc.stdout + proc.stderr).decode(errors="replace"))
        require(matches and int(matches[-1]) == selected, f"bounded Mix selected-test count drifted: {matches}")
        observed = int(matches[-1])
    return {"argv": argv, "environment": env_add, "timeout_seconds": 90, "exit_status": 0, "selected_test_count": observed, "result": "PASS"}


def run_contracts(root: Path) -> list[dict[str, Any]]:
    phase_test = "test/sigra/planning/phase_235_1_library_economics_contract_test.exs"
    return [
        run_contract(root, ["bash", "scripts/ci/install-golden.test.sh"], {}, None),
        run_contract(root, ["bash", "scripts/ci/verify-library-install-golden.test.sh"], {}, None),
        run_contract(root, ["mix", "test", f"{phase_test}:654", "--max-failures", "1"], {"ASDF_ERLANG_VERSION": "28.4.1", "MIX_ENV": "test"}, 1),
        run_contract(root, ["mix", "test", phase_test, "--only", "receipt_contract", "--max-failures", "1"], {"ASDF_ERLANG_VERSION": "28.4.1", "MIX_ENV": "test"}, 2),
    ]


def derive_expected(root: Path) -> dict[str, Any]:
    inputs = authenticate(root, PREDECESSORS, PHASE)
    source_bytes = authenticate(root, SOURCES)
    tool_bytes = {path: load_bytes(Path(path)) for path in TOOLS}
    require({path: sha256(data) for path, data in tool_bytes.items()} == TOOLS, "GSD toolchain digest drifted")
    for number in ("04", "10", "12", "15"):
        require(front_status(text(inputs[f"235.1-{number}-PLAN.md"], number), f"Plan {number}") == "superseded", f"Plan {number} is not superseded")
        require(front_status(text(inputs[f"235.1-{number}-SUMMARY.md"], number), f"Summary {number}") == "blocked", f"Summary {number} is not blocked")
    roots80 = glob.glob("/private/tmp/sigra-p2351-plan80-sequential-authority.*")
    require(not roots80, "Plan 80 root already exists before allocation")
    plan80_processes = [line for line in subprocess.check_output(["ps", "-axo", "command="], text=True).splitlines() if "plan80-" in line and "235.1-80-verify-preallocation.py" not in line]
    require(not plan80_processes, "Plan 80 process identity exists before allocation")
    plan76 = validate_plan76_pair()
    plan77 = validate_plan77(inputs)
    plan78 = validate_plan78(inputs)
    plan79 = validate_plan79(inputs)
    sources = {key: text(value, key) for key, value in source_bytes.items()}
    runner_paths = derive_runner_paths(sources["scripts/ci/install-golden.sh"])
    partition_paths = sorted(derive_quoted_paths(sources["test/support/ci/library_test_partitions.exs"], r"^\s*@scaffold_paths\s+MapSet\.new\(\[(?P<body>.*?)^\s*\]\)", "partition scaffold paths"))
    evidence_block = extract_block(sources["test/support/ci/phase_235_1_evidence_state_contract.exs"], r"^\s*@receiver_paths\s+~w\((?P<body>.*?)^\s*\)", "evidence receiver paths")
    evidence_paths = [line.strip() for line in evidence_block.splitlines() if line.strip()]
    require(runner_paths == RECEIVERS, "runner receiver order drifted")
    require(derive_live_paths(root) == sorted(RECEIVERS), "live scaffold universe drifted")
    require(partition_paths == sorted(RECEIVERS), "partition scaffold universe drifted")
    require(evidence_paths == RECEIVERS, "evidence receiver order drifted")
    variants = derive_variants(sources["test/support/install_fixture.ex"])
    require(variants == VARIANTS, "fixture variants drifted")
    wrapper = sources["scripts/ci/library-partitions.sh"]
    require("run_partition 1" in wrapper and "run_partition 2" in wrapper and wrapper.index("run_partition 1") < wrapper.index("run_partition 2"), "partition producer is not fixed sequential order")
    schedule = derive_schedule()
    new_identities = [row["action_id"] for row in schedule] + [row["raw_process_path"] for row in schedule] + [row["archive_path"] for row in schedule] + REMOTE_IDS + [ROOT_TEMPLATE, "plan80-local-terminal-launch", "plan80-install-golden-canonical-receiver", *DIAGNOSTIC.values()]
    for identity in map(str, new_identities):
        require(not any(prefix in identity for prefix in ("plan77-", "plan78-", "plan79-")), f"retired identity reused: {identity}")
    scheduler = scheduler_authority(root, inputs)
    contracts = run_contracts(root)
    plan_head = subprocess.check_output(["git", "log", "-1", "--format=%H", "--", str(PHASE / "235.1-80-PLAN.md")], cwd=root, text=True).strip()
    require(bool(re.fullmatch(r"[0-9a-f]{40}", plan_head)), "cannot bind Plan 80 introducing commit")
    return {
        "schema": SCHEMA,
        "status": "PASS",
        "repository": {"root": str(root), "authenticated_plan_head": plan_head},
        "precondition": {"status": "PASS", "plan80_root_count": 0, "plan80_process_record_count": 0},
        "predecessor_digests": PREDECESSORS,
        "source_digests": SOURCES,
        "toolchain_digests": TOOLS,
        "scheduler": scheduler,
        "plan76": plan76,
        "plan77": plan77,
        "plan78": plan78,
        "plan79": plan79,
        "canonical_scaffold": {"receiver_paths": RECEIVERS, "receiver_count": 6, "fixture_variants": variants, "variant_count": 6},
        "partition_authority": {"producer": "fixed_sequential", "plan80_child_orchestration": "serial_one_shot_children", "fixed_receipt_paths": FIXED, "manifest_sha256": MANIFESTS},
        "root_template": ROOT_TEMPLATE,
        "local_terminal_launcher": "plan80-local-terminal-launch",
        "identity_schedule": schedule,
        "exact_six_action_id": "plan80-install-golden-canonical-receiver",
        "remote_action_ids": REMOTE_IDS,
        "diagnostic_retry": DIAGNOSTIC,
        "blacklists": {
            "plan77": {"root_namespace": "/private/tmp/sigra-p2351-plan77-fixed-receipts.*", "id_prefix": "plan77-", "action_ids": [f"plan77-repeat-{r}-partition-{p}" for r in (1, 2) for p in (1, 2)], "archive_names": [f"local/archive/repeat-{r}-partition-{p}.json" for r in (1, 2) for p in (1, 2)]},
            "plan78": {"root_namespace": "/private/tmp/sigra-p2351-plan78-canonical-paths.*", "exact_root": str(PLAN78_ROOT), "id_prefix": "plan78-"},
            "plan79": {"root_namespace": "/private/tmp/sigra-p2351-plan79-status-recovery.*", "exact_root": str(PLAN79_ROOT), "id_prefix": "plan79-", "timing_action_ids": [f"plan79-repeat-{r}-partition-{p}" for r in (1, 2) for p in (1, 2)], "exact_six_action_id": "plan79-install-golden-canonical-receiver", "launcher": "plan79-local-terminal-launch", "remote_action_ids": [value.replace("plan80-", "plan79-") for value in REMOTE_IDS], "diagnostic_ids": ["plan79-classified-transient-diagnostic-retry", "plan79-classified-transient-diagnostic-run-attempt", "plan79-classified-transient-diagnostic-monitor"]},
        },
        "budgets": BUDGETS,
        "effects": EFFECTS,
        "bounded_contracts": contracts,
        "prohibitions": {"prior_artifacts_mutable": False, "source_changes_allowed": False, "receipt_self_authentication": False},
        "verdict": {"independently_computed": True, "allocation_authorized": True},
    }


def atomic_write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        require(load_bytes(path) == payload, "receipt bytes changed after atomic write")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default=str(PHASE / "235.1-80-PREALLOCATION-VALIDATION.json"))
    args = parser.parse_args()
    root = Path(args.repo_root).resolve(strict=True)
    require((root / ".git").exists(), "repo root is not a git checkout")
    receipt = Path(args.output)
    if not receipt.is_absolute():
        receipt = root / receipt
    expected = derive_expected(root)
    if receipt.exists():
        actual = load_json(receipt)
        require(actual == expected, "preallocation receipt does not exactly match independently derived authority")
    else:
        require(not receipt.is_symlink(), "refusing symlink preallocation receipt")
        atomic_write(receipt, expected)
    print("plan80-preallocation: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except VerificationError as exc:
        print(f"plan80-preallocation: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
