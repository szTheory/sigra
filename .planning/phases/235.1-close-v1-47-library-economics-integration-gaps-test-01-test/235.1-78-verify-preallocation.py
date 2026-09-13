#!/usr/bin/env python3
"""Derive and verify Plan 78's zero-effect preallocation authority."""

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
SCHEMA = "sigra.phase235.1-plan78-preallocation-validation/v1"
ROOT_TEMPLATE = "/private/tmp/sigra-p2351-plan78-canonical-paths.XXXXXXXX"

PREDECESSORS = {
    "235.1-76-PLAN.md": "9521f1263e242204dc27406fa46ca0df6168f168009072f465ba93cedaa6a84b",
    "235.1-76-SUMMARY.md": "da8632f927ede7e6054f2d44aa3713a93a1a7c4d227171a977a8cdcdb454ca0c",
    "235.1-76-PREALLOCATION-VALIDATION.json": "1f18e5eea1d75e05107d5cfb12bbf84bffb874f2baad13c588b7e318dab7e17f",
    "235.1-76-HOME-PROBE.json": "c6ec362e1fc99f62ca22238c9937129829631a306c8e450ab266e309f35f9fc7",
    "235.1-76-PREREQUISITE-VALIDATION.json": "e7df44f4c5165c5c04320bfeb094217a439f03c3bcd340264e2327dc8d11b213",
    "235.1-77-PLAN.md": "49156197bd74c6556b4e17f205f7fdc32cab701cf084e067ed52d5f81c94a71b",
    "235.1-77-SUMMARY.md": "e555b1d66c3aab4427a162f34da051ec167ba40c897d51aff22818cd1091424b",
    "235.1-77-PREALLOCATION-VALIDATION.json": "ee2100d18b6228f5c035217c8c7336fad61d30829c6962ed4e169fe43efef7cd",
}

SOURCES = {
    "test/support/ci/ex_unit_timing_formatter.ex": "e9ad6dbaaba24528c60be38f54ddd8d1e946ab539943dd744a1602eba4a29d0c",
    "scripts/ci/library-partitions.sh": "deae1229e1bfabea6924d2512db1293026d6904497c2ac804f0478afc04471dd",
    "scripts/ci/install-golden.sh": "b68dfd02687486459b4fd1fb04bddc23844e4301e68a94373d5005967d29c89a",
    "scripts/ci/install-golden.test.sh": "9240eed665210ab2316cb83f1325222571c55bcc43b56ff1f94485073a1f1f9b",
    "scripts/ci/verify-library-install-golden.sh": "2d8e838951229c406d4295844d87c48f148c2743139dc93289deee6e210e6aa4",
    "scripts/ci/verify-library-install-golden.test.sh": "2e008e515f2be91dd1c98ef9f363541bc7cb21cee846a002b3167dc2975eaa20",
    "test/support/ci/library_test_partitions.exs": "9384fce2c84de95681d1e1ef08c7efec5bf993c2bd0abf9837c169f2fdefb103",
    "test/support/install_fixture.ex": "e31568e6ff5103d775afdf546420644493e4bdbc8ecf5a40bb3b27e1926157dc",
    ".github/workflows/ci.yml": "ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682",
    "test/sigra/planning/phase_235_1_library_economics_contract_test.exs": "d81f71a2e1008756e6f8a988f30e1426ff900aee61fbacd90136d09040b9e06b",
    "test/support/ci/phase_235_1_evidence_state_contract.exs": "6cb58e74e463d977c228be94efbde05aa7609e4ca1357ca94509e90077bd7921",
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
    "repeat_children": 4,
    "exact_six": 1,
    "candidate_push": 1,
    "capture_pull_request": 1,
    "capture_workflow_dispatch": 1,
    "evidence_child_push": 1,
    "validation_pull_request": 1,
    "validation_workflow_dispatch": 1,
}
ASSUMPTIONS = [
    {
        "id": "EDGE-TEST-01-UNCLASSIFIED",
        "status": "unverified",
        "flagged": True,
        "statement": "With no phase SPEC, TEST-01 behavior for an otherwise valid timing receipt containing an unclassified ordinary test path remains unspecified; this plan admits only the exact current 225-path universe.",
    },
    {
        "id": "EDGE-TEST-02-ADJACENCY",
        "status": "unverified",
        "flagged": True,
        "statement": "With no phase SPEC, TEST-02 behavior when valid partition receipts are not adjacent in capture order remains unspecified; this plan preserves the existing evidence schema.",
    },
    {
        "id": "EDGE-TEST-02-EMPTY",
        "status": "unverified",
        "flagged": True,
        "statement": "With no phase SPEC, TEST-02 behavior for an empty otherwise well-formed partition remains unspecified; this plan admits only the known non-empty 114/111 universe.",
    },
    {
        "id": "EDGE-TEST-02-ORDERING",
        "status": "unverified",
        "flagged": True,
        "statement": "With no phase SPEC, TEST-02 behavior for reordered otherwise valid timing rows remains unspecified; this plan preserves deterministic formatter ordering.",
    },
    {
        "id": "EDGE-TEST-03-UNCLASSIFIED",
        "status": "unverified",
        "flagged": True,
        "statement": "With no phase SPEC, TEST-03 behavior for an additional tracked scaffold-tagged path remains unspecified; this plan requires exact equality with the current six-path repository universe and fails closed on drift.",
    },
]
PLAN76_AUTHORITY = {
    "retry": False,
    "canonical_pair_admitted": True,
    "canonical_pair_receipt_sha256": "864d2b33994d4eb783f4e7e36ac3fe017eef234b6b0270d49f22feeb68810159",
    "canonical_partition_receipt_sha256": [
        "e1a3a629be9c236818ec58b664798d30a9b686b5043f9be6b297b7b75eb06e22",
        "e57b188e22cf7ac1a80176811173f595167aa7e82d9d4fcfe94ab590270e933e",
    ],
    "canonical_partition_cardinalities": [114, 111],
    "canonical_unique_paths": 225,
    "canonical_durations_ms": [12056, 12949],
    "failed_repeat_admitted": False,
    "failed_repeat_process_sha256": "4f9d455818fcdebfea2d962d74c20cd4c4a20582bca386c518ffdbee164b2be3",
    "failed_repeat_process_id": 92841,
    "failed_repeat_receipt_present": False,
    "failure_receipt_sha256": "7b9d98e5668b275ed5c3a2618e9f726a5cf26f1785b3e6f6fd2d43f449421583",
    "positive_pair_count": 1,
    "positive_receipt_count": 2,
    "excluded_failure_count": 1,
}
PLAN77_ACTIONS = [f"plan77-repeat-{repeat}-partition-{partition}" for repeat in (1, 2) for partition in (1, 2)]
PLAN77_ARCHIVES = [f"local/archive/repeat-{repeat}-partition-{partition}.json" for repeat in (1, 2) for partition in (1, 2)]
REMOTE_IDS = [
    "plan78-candidate-push",
    "plan78-capture-pull-request",
    "plan78-capture-workflow-dispatch",
    "plan78-evidence-child-push",
    "plan78-validation-pull-request",
    "plan78-validation-workflow-dispatch",
]


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
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        raise VerificationError(f"cannot no-follow open {path}: {exc}") from exc
    try:
        opened = os.fstat(fd)
        require(stat.S_ISREG(opened.st_mode), f"opened input is not regular: {path}")
        require(opened.st_nlink == 1, f"opened input is multiply linked: {path}")
        require((before.st_dev, before.st_ino) == (opened.st_dev, opened.st_ino), f"input changed during open: {path}")
        chunks = []
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
        if key in result:
            raise VerificationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_bytes(data: bytes, label: str) -> Any:
    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=pairs_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"invalid JSON in {label}: {exc}") from exc


def authenticate(root: Path, mapping: dict[str, str], prefix: Path | None = None) -> dict[str, bytes]:
    result = {}
    for relative, expected in mapping.items():
        path = root / (prefix / relative if prefix else Path(relative))
        data = load_bytes(path)
        require(sha256(data) == expected, f"SHA-256 mismatch: {path}")
        result[relative] = data
    return result


def text(data: bytes, label: str) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise VerificationError(f"non-UTF-8 input: {label}") from exc


def extract_block(source: str, pattern: str, label: str) -> str:
    match = re.search(pattern, source, re.S | re.M)
    require(match is not None, f"cannot derive {label}")
    return match.group("body")


def derive_runner_paths(source: str) -> list[str]:
    body = extract_block(source, r"^receiver_paths=\(\n(?P<body>.*?)\n\)$", "runner receiver paths")
    return [line.strip() for line in body.splitlines() if line.strip() and not line.lstrip().startswith("#")]


def derive_quoted_paths(source: str, pattern: str, label: str) -> list[str]:
    body = extract_block(source, pattern, label)
    return re.findall(r'"(test/[^"\n]+\.exs)"', body)


def derive_live_paths(root: Path) -> list[str]:
    proc = subprocess.run(
        ["git", "ls-files", "--", "test/**/*_test.exs", "test/*_test.exs"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=20,
        check=False,
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


def derive_fixed(formatter: str, wrapper: str, partition: str) -> dict[str, Any]:
    formatter_paths = sorted(set(re.findall(r'"(/tmp/sigra-library-[12]-timings\.json)"', formatter)))
    wrapper_map = dict(re.findall(r'^TIMING_([12])="([^"]+)"$', wrapper, re.M))
    partition_block = extract_block(partition, r"^\s*@timing_paths\s*%\{(?P<body>.*?)^\s*\}", "partition timing paths")
    partition_map = dict(re.findall(r'(\d)\s*=>\s*"([^"]+)"', partition_block))
    require(formatter_paths == sorted(FIXED.values()), "formatter fixed paths drifted")
    require(wrapper_map == FIXED, "wrapper fixed-path map drifted")
    require(partition_map == FIXED, "partition authority fixed-path map drifted")
    return {"formatter_allowlist": formatter_paths, "wrapper_partition_map": wrapper_map, "partition_authority_map": partition_map}


def validate_workflow(workflow: str) -> dict[str, Any]:
    job = extract_block(workflow, r"^  library_install_golden_non_pr:\n(?P<body>.*?)(?=^  [a-zA-Z0-9_]+:\n|\Z)", "non-PR workflow job")
    require("github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'" in job, "non-PR event gate drifted")
    require("MIX_ENV=test bash scripts/ci/install-golden.sh" in job, "non-PR runner drifted")
    require("if: always()\n        run: bash scripts/ci/verify-library-install-golden.sh" in job, "fail-closed verifier drifted")
    for name, path in (
        ("library-install-golden-${{ github.run_id }}-${{ github.run_attempt }}", "/tmp/sigra-library-install-golden.json"),
        ("library-install-diagnostics-${{ github.run_id }}-${{ github.run_attempt }}", "/tmp/sigra-install-golden-diagnostics.json"),
    ):
        require(name in job and path in job, f"workflow artifact drifted: {name}")
    require(job.count("if-no-files-found: error") == 2, "workflow missing-file policy drifted")
    aggregate = extract_block(workflow, r"^  library_tests:\n(?P<body>.*?)(?=^  [a-zA-Z0-9_]+:\n|\Z)", "library aggregate")
    gate = extract_block(workflow, r"^  ci-gate:\n(?P<body>.*?)(?=^  [a-zA-Z0-9_]+:\n|\Z)", "ci-gate")
    require("library_install_golden_non_pr" not in aggregate and "library_install_golden_non_pr" not in gate, "scaffold job entered PR ownership")
    return {
        "events": ["schedule", "workflow_dispatch"],
        "runner": "MIX_ENV=test bash scripts/ci/install-golden.sh",
        "verifier_always": True,
        "artifact_names": [
            "library-install-golden-${github.run_id}-${github.run_attempt}",
            "library-install-diagnostics-${github.run_id}-${github.run_attempt}",
        ],
        "if_no_files_found": "error",
        "absent_from": ["library_tests", "ci-gate"],
    }


def validate_plan77_summary(source: str) -> dict[str, Any]:
    front = extract_block(source, r"\A---\n(?P<body>.*?)\n---", "Plan 77 summary frontmatter")
    require(re.search(r"^status:\s*halted\s*$", front, re.M) is not None, "Plan 77 summary is not halted")
    require(re.search(r"^\s*tasks:\s*1\s*$", front, re.M) is not None, "Plan 77 summary actual tasks drifted")
    require(re.search(r"\*\*Tasks:\*\*\s*1/3 complete", source) is not None, "Plan 77 Task-1-only body drifted")
    require(re.search(r"\*\*Plan 77 roots allocated:\*\*\s*0", source) is not None, "Plan 77 root count drifted")
    require(re.search(r"\*\*Plan 77 Mix processes:\*\*\s*0", source) is not None, "Plan 77 Mix count drifted")
    require(re.search(r"\*\*Plan 77 GitHub actions:\*\*\s*0", source) is not None, "Plan 77 GitHub count drifted")
    return {"status": "halted", "completed_tasks": 1, "total_tasks": 3, "root_count": 0, "mix_process_count": 0, "github_action_count": 0}


def validate_plan77_receipt(value: Any, plan77_plan: str) -> dict[str, Any]:
    require(isinstance(value, dict), "Plan 77 receipt is not an object")
    require(value.get("schema") == "sigra.phase235.1-plan77-preallocation-validation/v1", "Plan 77 schema drifted")
    require(value.get("status") == "PASS", "Plan 77 preallocation was not PASS")
    require(value.get("effects") == EFFECTS, "Plan 77 zero-effect map drifted")
    require(value.get("unspent_one_shot_budgets") == BUDGETS, "Plan 77 unspent ledger drifted")
    pre = value.get("precondition")
    require(isinstance(pre, dict) and pre.get("status") == "PASS", "Plan 77 precondition drifted")
    require(pre.get("plan76_root_count") == 1 and pre.get("plan77_root_count") == 0 and pre.get("plan77_process_record_count") == 0, "Plan 77 predecessor counts drifted")
    require(value.get("pinned_artifacts") == {key: PREDECESSORS[key] for key in list(PREDECESSORS)[:5]}, "Plan 77 predecessor pins drifted")
    require(value.get("source_digests") == {key: SOURCES[key] for key in list(SOURCES)[:2]}, "Plan 77 source pins drifted")
    require(value.get("plan76") == PLAN76_AUTHORITY, "Plan 76 authority in Plan 77 drifted")
    inventory = {"rows": 16, "regular_files": 14, "sha256": "5a700098dc7e461ee1fdb88bd9efee93aaa7e23919bbfa9f42f7a9ca89fe469b"}
    require(value.get("frozen_root_inventory_before") == inventory and value.get("frozen_root_inventory_after") == inventory, "Plan 76 frozen inventory authority drifted")
    schedule = value.get("schedule")
    require(isinstance(schedule, list) and len(schedule) == 4, "Plan 77 schedule cardinality drifted")
    require([row.get("action_id") for row in schedule] == PLAN77_ACTIONS, "Plan 77 action identities drifted")
    require([row.get("archive_label") for row in schedule] == PLAN77_ARCHIVES, "Plan 77 archive identities drifted")
    for literal in PLAN77_ACTIONS + PLAN77_ARCHIVES + ["sigra-p2351-plan77-fixed-receipts.*"]:
        require(literal in plan77_plan or literal in json.dumps(value, sort_keys=True), f"cannot derive Plan 77 blacklist literal: {literal}")
    return {"schema": value["schema"], "status": value["status"], "effects": value["effects"], "unspent_one_shot_budgets": value["unspent_one_shot_budgets"], "precondition": pre}


def validate_plan76_root(plan77: dict[str, Any]) -> dict[str, Any]:
    roots76 = glob.glob("/private/tmp/sigra-p2351-plan76-build-links.*")
    roots77 = glob.glob("/private/tmp/sigra-p2351-plan77-fixed-receipts.*")
    roots78 = glob.glob("/private/tmp/sigra-p2351-plan78-canonical-paths.*")
    require(len(roots76) == 1 and os.path.realpath(roots76[0]) == plan77["precondition"]["plan76_root"], "Plan 76 root identity drifted")
    require(not roots77, "Plan 77 root exists")
    require(not roots78, "Plan 78 root already exists")
    root = Path(roots76[0])
    regular = 0
    rows = 0
    for current, directories, files in os.walk(root, followlinks=False):
        rows += len(directories) + len(files)
        for name in directories:
            p = Path(current) / name
            require(not p.is_symlink(), f"symlink in frozen Plan 76 root: {p}")
        for name in files:
            p = Path(current) / name
            load_bytes(p)
            regular += 1
    require((rows, regular) == (16, 14), "Plan 76 frozen root inventory count drifted")
    return {"status": "PASS", "plan76_root": str(root), "plan76_root_count": 1, "plan77_root_count": 0, "plan77_process_record_count": 0, "plan78_root_count": 0, "plan78_process_record_count": 0}


def derive_schedule() -> list[dict[str, Any]]:
    rows = []
    for repeat in (1, 2):
        for partition in (1, 2):
            action = f"plan78-repeat-{repeat}-partition-{partition}"
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


def run_contract(root: Path, argv: list[str], environment: dict[str, str], selected: int | None) -> dict[str, Any]:
    env = os.environ.copy()
    env.update(environment)
    try:
        proc = subprocess.run(argv, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, check=False)
    except subprocess.TimeoutExpired as exc:
        raise VerificationError(f"bounded contract timed out: {argv}") from exc
    require(proc.returncode == 0, f"bounded contract failed ({proc.returncode}): {argv}\n{proc.stderr.decode(errors='replace')}")
    observed = None
    if selected is not None:
        combined = (proc.stdout + proc.stderr).decode(errors="replace")
        matches = re.findall(r"(\d+) tests?, 0 failures", combined)
        require(matches, "bounded Mix contract reported no selected tests")
        observed = int(matches[-1])
        require(observed == selected, f"bounded Mix selected-test count drifted: {observed}")
    return {"argv": argv, "environment": environment, "timeout_seconds": 60, "exit_status": 0, "selected_test_count": observed, "result": "PASS"}


def run_contracts(root: Path) -> list[dict[str, Any]]:
    phase_test = "test/sigra/planning/phase_235_1_library_economics_contract_test.exs"
    return [
        run_contract(root, ["bash", "scripts/ci/install-golden.test.sh"], {}, None),
        run_contract(root, ["bash", "scripts/ci/verify-library-install-golden.test.sh"], {}, None),
        run_contract(root, ["mix", "test", f"{phase_test}:570", f"{phase_test}:761", f"{phase_test}:781", "--max-failures", "1"], {"ASDF_ERLANG_VERSION": "28.4.1", "MIX_ENV": "test"}, 3),
    ]


def derive_expected(root: Path) -> dict[str, Any]:
    predecessor_bytes = authenticate(root, PREDECESSORS, PHASE)
    source_bytes = authenticate(root, SOURCES)
    plan77_plan = text(predecessor_bytes["235.1-77-PLAN.md"], "Plan 77 plan")
    plan77_summary = validate_plan77_summary(text(predecessor_bytes["235.1-77-SUMMARY.md"], "Plan 77 summary"))
    plan77_receipt_value = load_json_bytes(predecessor_bytes["235.1-77-PREALLOCATION-VALIDATION.json"], "Plan 77 preallocation")
    plan77 = validate_plan77_receipt(plan77_receipt_value, plan77_plan)
    precondition = validate_plan76_root(plan77)

    sources = {key: text(value, key) for key, value in source_bytes.items()}
    runner_paths = derive_runner_paths(sources["scripts/ci/install-golden.sh"])
    live_paths = derive_live_paths(root)
    partition_paths = sorted(derive_quoted_paths(sources["test/support/ci/library_test_partitions.exs"], r"^\s*@scaffold_paths\s+MapSet\.new\(\[(?P<body>.*?)^\s*\]\)", "partition scaffold paths"))
    evidence_block = extract_block(sources["test/support/ci/phase_235_1_evidence_state_contract.exs"], r"^\s*@receiver_paths\s+~w\((?P<body>.*?)^\s*\)", "evidence receiver paths")
    evidence_paths = [line.strip() for line in evidence_block.splitlines() if line.strip()]
    phase_contract = sources["test/sigra/planning/phase_235_1_library_economics_contract_test.exs"]
    require("assert receiver_paths == live_scaffold_paths()" in phase_contract, "phase contract live equality drifted")
    for path in RECEIVERS:
        require(path in phase_contract, f"phase contract missing receiver path: {path}")
    require(runner_paths == RECEIVERS, "runner receiver order drifted")
    require(live_paths == sorted(RECEIVERS), "live tracked scaffold universe drifted")
    require(partition_paths == sorted(RECEIVERS), "partition scaffold universe drifted")
    require(evidence_paths == RECEIVERS, "evidence receiver order drifted")
    variants = derive_variants(sources["test/support/install_fixture.ex"])
    require(variants == VARIANTS, "prepared fixture variant order drifted")
    fixed = derive_fixed(sources["test/support/ci/ex_unit_timing_formatter.ex"], sources["scripts/ci/library-partitions.sh"], sources["test/support/ci/library_test_partitions.exs"])
    workflow = validate_workflow(sources[".github/workflows/ci.yml"])
    plan78_plan = text(load_bytes(root / PHASE / "235.1-78-PLAN.md"), "Plan 78 plan")
    for assumption in ASSUMPTIONS:
        require(assumption["id"] in plan78_plan and assumption["statement"] in plan78_plan, f"Plan 78 assumption drifted: {assumption['id']}")
    schedule = derive_schedule()
    identities = [row["action_id"] for row in schedule] + [row["raw_process_path"] for row in schedule] + [row["archive_path"] for row in schedule] + REMOTE_IDS + [ROOT_TEMPLATE]
    for identity in identities:
        require("plan77-" not in identity and "sigra-p2351-plan77-fixed-receipts" not in identity, f"Plan 77 identity reused: {identity}")
    blacklist = {
        "action_ids": PLAN77_ACTIONS,
        "archive_paths": PLAN77_ARCHIVES,
        "id_prefix": "plan77-",
        "root_namespace": "/private/tmp/sigra-p2351-plan77-fixed-receipts.*",
        "further_literals": [],
    }

    return {
        "schema": SCHEMA,
        "status": "PASS",
        "assumption_delta": "no-change",
        "precondition": precondition,
        "predecessor_digests": PREDECESSORS,
        "source_digests": SOURCES,
        "plan77_summary": plan77_summary,
        "plan77": plan77,
        "plan76": PLAN76_AUTHORITY,
        "canonical_scaffold": {
            "receiver_paths": RECEIVERS,
            "receiver_count": 6,
            "receiver_derivations": {
                "runner_ordered": runner_paths,
                "live_tracked_sorted": live_paths,
                "partition_authority_sorted": partition_paths,
                "phase_contract_equal": True,
                "evidence_contract_ordered": evidence_paths,
            },
            "fixture_variants": variants,
            "variant_count": 6,
        },
        "fixed_receipt_authority": fixed,
        "workflow_authority": workflow,
        "root_template": ROOT_TEMPLATE,
        "identity_schedule": schedule,
        "remote_action_ids": REMOTE_IDS,
        "plan77_blacklist": blacklist,
        "assumptions": ASSUMPTIONS,
        "plan78_one_shot_budgets": BUDGETS,
        "effects": EFFECTS,
        "bounded_contracts": run_contracts(root),
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
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(args.repo_root).resolve(strict=True)
    require((root / ".git").exists(), "repo root is not a git checkout")
    receipt = Path(args.receipt)
    if not receipt.is_absolute():
        receipt = root / receipt
    expected = derive_expected(root)
    if args.write:
        require(not receipt.exists() and not receipt.is_symlink(), "refusing to overwrite preallocation receipt")
        atomic_write(receipt, expected)
    actual = load_json_bytes(load_bytes(receipt), str(receipt))
    require(actual == expected, "preallocation receipt does not exactly match independently derived authority")
    print("plan78-preallocation: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except VerificationError as exc:
        print(f"plan78-preallocation: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
