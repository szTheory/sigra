#!/usr/bin/env python3
"""Prepare and verify the one-shot Phase 253 successor acceptance contract.

This module uses only the Python standard library. It never launches acceptance
from a verification command; ``enter`` only creates an exclusive attempt marker.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


PHASE = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
PLAN_174 = f"{PHASE}/253-174-PLAN.md"
PLAN_175 = f"{PHASE}/253-175-PLAN.md"
PLAN_176 = f"{PHASE}/253-176-PLAN.md"
PLAN_177 = f"{PHASE}/253-177-PLAN.md"
PLAN_178 = f"{PHASE}/253-178-PLAN.md"
PLAN_179 = f"{PHASE}/253-179-PLAN.md"
PLAN_180 = f"{PHASE}/253-180-PLAN.md"
REVIEW_173 = f"{PHASE}/253-173-RECOVERY-REVIEW.json"
REVIEW_175 = f"{PHASE}/253-175-REPAIR-REVIEW.json"
REVIEW_178 = f"{PHASE}/253-178-REPAIR-REVIEW.json"
RECEIPT_179 = f"{PHASE}/253-179-RECOVERY-RECEIPT.json"
BRIDGE_180 = f"{PHASE}/253-180-BRIDGE-RECORD.json"
SUCCESSOR_SCHEMA = "sigra.phase253.successor-acceptance/v1"
REVIEW_SCHEMA = "sigra.phase253.successor-repair-review/v1"
BRIDGE_SCHEMA = "sigra.phase253.successor-bridge/v1"
BODY_174_SHA256 = "090350ba19dbfd1311feb14134286c0a3c4eaf0a2d004a43f21e154506c4ddcc"
REVIEW_173_SHA256 = "30cb16fd6ee27ff440512767d113b61b859da059de61571ac87f9da649201e48"
PUBLISHER_SHA256 = "7bf205869e74ce2101e0df91e8615af81f75393e3eadd2b5fd01dd126681d5b6"
DRYRUN_SHA256 = "b6e6be484112926539e8b53aab685dd61d4b72105c063044576c449f94b27ae6"
HISTORICAL_174_LOG_SHA256 = "a53f6b0e9174accd8da1a7cbe68287429305f6b927ece2b56262079088250b3a"
R12_CONTRACT = f"{PHASE}/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT-R12.json"
R12_CONTRACT_SHA256 = "d36a2ab07ff2e716d777bc784432b12ab6c01cef987c81e170fd852dcdefc45c"
HISTORICAL_SHA256 = {
    f"{PHASE}/253-167-PLAN.md": "7ffcb319bc5bf0dd15435b1c27c403cde3474e5da6c606f1e3832e30a925eaae",
    f"{PHASE}/253-167-SUMMARY.md": "c7012462da9613261479be4494e6a56f8aecc9a0c2dfef1fbb716feebe5c53be",
    f"{PHASE}/253-173-PLAN.md": "6efea294ec389717480364909414989b9d9b1b1e5a467051711c26c2b05e253c",
    f"{PHASE}/253-173-SUMMARY.md": "dd698ccee469ac4d685b31df599c1941bc93a13cb0a23b6a50e352f052f7e68b",
    f"{PHASE}/253-173-REGRESSION.log": "aeb25e295e13b263424cb23f29bdce33282046439c063b236453bea7e49111f9",
    f"{PHASE}/253-173-RECOVERY-REVIEW.json": REVIEW_173_SHA256,
    f"{PHASE}/253-173-EXECUTION-RECORD.json": "eb085f4e109ac383b04ee52cf03fe339a578450c1a19322f7cccaeaacf144393",
    f"{PHASE}/253-174-PLAN.md": "24bbae3b3c3f2cf265339129d5ea63657fd292ca7f54a3769c921154de59c453",
    f"{PHASE}/253-174-SUMMARY.md": "90af2a0ffcd088195023c694a9c19b3871858d229d8c8f9fff332ed41f4223f2",
    f"{PHASE}/253-174-REGRESSION.log": HISTORICAL_174_LOG_SHA256,
    f"{PHASE}/253-174-PERMISSION-PREFLIGHT.json": "11b9156eb6afd9e60d6871de55d91cc34411a563a3cc85cb9ad6c93cee0ae77b",
    f"{PHASE}/253-174-EXECUTION-RECORD.json": "b4b4edf630de91bee762f74f345fc3ab939cc494f3364c3141c33743a232bd27",
    f"{PHASE}/253-175-PLAN.md": "8cb8b78ed8283860c1daff28c689ef9c556311f6c46826b0dbc6820b3292ae65",
    f"{PHASE}/253-175-SUMMARY.md": "74059b7ca4e1730dde91d21b5bf260090332aef7be20cc8ab258c41437482098",
    f"{PHASE}/253-175-REPAIR-REVIEW.json": "dc9a7ed14f881a2f8d7428d9e4121a89f7b49a9a9144a544f1e8bc545511b603",
    f"{PHASE}/253-175-EXECUTION-RECORD.json": "a6e068c80db579e093ac5c374fb57db471c207a01be46ac77a10ee1b388f8c00",
}
FROZEN_175_COMMITS = {
    f"{PHASE}/253-175-PLAN.md": "6b8bccad1a51a3455ab27d88360064d7ac8d30c8",
    f"{PHASE}/253-175-SUMMARY.md": "071f9894e7ed8625462b894f1df3fc0be3598928",
    f"{PHASE}/253-175-REPAIR-REVIEW.json": "071f9894e7ed8625462b894f1df3fc0be3598928",
    f"{PHASE}/253-175-EXECUTION-RECORD.json": "fea8f29e79f7d6e96f1bf2c6f15cfa6eee73681d",
}
TREE_CAP = 2 * 1024 * 1024
SHARED = (".planning/config.json", ".planning/state.json", ".planning/STATE.md", ".planning/HANDOFF.json")
SUITES = (
    ("hermetic-live-audit", "python3 scripts/ci/ci-hermetic-live-audit.test.py"),
    ("git-publication", "python3 scripts/ci/ci-git-publication.test.py"),
    ("hosted-transport", "python3 scripts/ci/ci-hosted-transport.test.py"),
    ("shape-probe", "python3 scripts/ci/ci-shape-probe.test.py"),
    ("pr-proof", "bash scripts/ci/ci-pr-proof.test.sh"),
    ("hosted-gate-verify", "python3 scripts/ci/ci-hosted-gate-verify.test.py"),
    ("gate-canary-flow", "python3 scripts/ci/ci-gate-canary-flow.test.py"),
    ("full-dryrun", "python3 scripts/ci/ci-gate-canary-dryrun.test.py"),
    ("gate-canary-shell", "bash scripts/ci/ci-gate-canary.test.sh"),
    ("gate-canary-recovery", "python3 scripts/ci/ci-gate-canary-recovery.test.py"),
)
EXPECTED_173_FINDINGS = 10


class ContractError(Exception):
    """An input failed a named successor contract."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_bytes(root: Path, rel: str) -> bytes:
    path = root / rel
    if path.is_symlink() or not path.is_file():
        raise ContractError(f"required regular file missing: {rel}")
    raw = path.read_bytes()
    if not raw:
        raise ContractError(f"required file is empty: {rel}")
    return raw


def read_source_bytes(root: Path, rel: str) -> bytes:
    """Read a source-bound regular file, preserving legitimately empty blobs."""
    path = root / rel
    if path.is_symlink() or not path.is_file():
        raise ContractError(f"source-bound regular file missing: {rel}")
    return path.read_bytes()


def read_json(root: Path, rel: str) -> dict:
    try:
        value = json.loads(read_bytes(root, rel))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ContractError(f"invalid JSON in {rel}: {error}") from error
    if not isinstance(value, dict):
        raise ContractError(f"JSON root must be an object: {rel}")
    return value


def git(root: Path, *args: str, input_bytes: bytes | None = None) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *args], input=input_bytes,
                            capture_output=True, check=False)
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace").strip()
        raise ContractError(f"git {' '.join(args)} failed ({result.returncode}): {detail}")
    return result.stdout


def command_body(raw: bytes, plan_path: str) -> str:
    try:
        source = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"PLAN is not UTF-8: {plan_path}") from error
    bodies = re.findall(r"<automated>(.*?)</automated>", source, re.S)
    if not bodies:
        raise ContractError(f"no automated body in {plan_path}")
    return bodies[0]


def suite_command(name: str, invocation: str) -> str:
    if name not in {item[0] for item in SUITES} or "\n" in name:
        raise ContractError(f"unknown suite name: {name}")
    return f"( printf 'SUITE-START {name}\\n'; {invocation} && printf 'SUITE-PASS {name}\\n' )"


def expected_acceptance_body(body: str) -> tuple[str, dict]:
    """Apply only the attempt-id, product allow-list, and suite-marker edits."""
    if sha256(body.encode("utf-8")) != BODY_174_SHA256:
        raise ContractError("174 first automated body hash differs from the reviewed source")
    transformed = body
    identifier_count = transformed.count("253-174")
    if identifier_count < 5:
        raise ContractError("174 attempt identifier substitution count is unexpectedly small")
    transformed = transformed.replace("253-174", "253-179")

    allow_old = "grep -v -e '^$' -e '^scripts/ci/ci-hermetic-live-audit.test.py$'"
    allow_new = ("grep -v -e '^$' -e '^scripts/ci/ci-hermetic-live-audit.test.py$' "
                 "-e '^scripts/ci/ci-git-publication.test.py$'")
    if transformed.count(allow_old) != 1:
        raise ContractError("expected exactly one final PRODUCT_DIFF allow-list")
    transformed = transformed.replace(allow_old, allow_new, 1)

    suite_counts = {}
    for name, invocation in SUITES:
        count = transformed.count(invocation)
        if count != 1:
            raise ContractError(f"expected one {name} suite invocation, found {count}")
        suite_counts[name] = count
        start = f"printf 'SUITE-START {name}\\n' && "
        passed = f"printf 'SUITE-PASS {name}\\n'"
        if name == "full-dryrun":
            # Its existing block preserves native output/FULL_RC. Mark completion only
            # after the block returns zero; the command and test count remain untouched.
            needle = "{ python3 scripts/ci/ci-gate-canary-dryrun.test.py >"
            if transformed.count(needle) != 1:
                raise ContractError("full-dryrun command block changed")
            transformed = transformed.replace(needle, start + "{ python3 scripts/ci/ci-gate-canary-dryrun.test.py >", 1)
            tail = "printf 'FULL-DRYRUN-COUNT %s\\n' \"$DRYRUN_TEST_COUNT\""
            if transformed.count(tail) != 1:
                raise ContractError("full-dryrun native count gate changed")
            transformed = transformed.replace(tail, tail + " && " + passed, 1)
        else:
            transformed = transformed.replace(invocation, suite_command(name, invocation), 1)

    stats = {
        "attempt_identifier_substitutions": identifier_count,
        "product_allowlist_substitutions": 1,
        "suite_start_markers": len(SUITES),
        "suite_pass_markers": len(SUITES),
        "suite_invocations": suite_counts,
    }
    return transformed, stats


def original_bindings(root: Path) -> dict:
    """Bind every tracked Phase 253/252 path to its producing Git blob and bytes."""
    commit = git(root, "rev-parse", "HEAD").decode().strip()
    entries = git(root, "ls-tree", "-rz", "-r", commit, "--", PHASE, ".planning/phases/252-measure-current-ci")
    bindings = {}
    for row in entries.split(b"\0"):
        if not row:
            continue
        meta, path_raw = row.split(b"\t", 1)
        mode, kind, oid = meta.decode("ascii").split()
        rel = path_raw.decode("utf-8", "strict")
        if kind != "blob":
            continue
        raw = git(root, "cat-file", "blob", oid)
        bindings[rel] = {"path": rel, "commit": commit, "blob": oid,
                         "sha256": sha256(raw), "bytes": len(raw)}
    if not bindings:
        raise ContractError("no committed Phase 253/252 source bindings found")
    return {"source_commit": commit, "files": bindings}


def check_historical_inputs(root: Path) -> dict:
    for rel, expected in HISTORICAL_SHA256.items():
        if sha256(read_bytes(root, rel)) != expected:
            raise ContractError(f"original halted evidence changed: {rel}")
    for rel, commit in FROZEN_175_COMMITS.items():
        if git(root, "show", f"{commit}:{rel}") != read_bytes(root, rel):
            raise ContractError(f"175 historical producing-commit bytes differ: {rel}")
    review173 = read_json(root, REVIEW_173)
    raw_review173 = read_bytes(root, REVIEW_173)
    if sha256(raw_review173) != REVIEW_173_SHA256:
        raise ContractError("the original 173 review bytes differ from their pinned hash")
    if review173.get("schema") != "sigra.phase253.execution-halt-review/v1" or review173.get("status") != "reviewed_for_new_acceptance":
        raise ContractError("the original 173 review schema/status is invalid")
    dispositions = review173.get("status_dispositions")
    if not isinstance(dispositions, dict) or dispositions.get("product_changes") != []:
        raise ContractError("173 status_dispositions.product_changes must remain empty")
    if len(review173.get("findings", [])) != EXPECTED_173_FINDINGS:
        raise ContractError("173 review must retain all ten reviewed findings")

    summary174 = read_bytes(root, f"{PHASE}/253-174-SUMMARY.md").decode("utf-8")
    execution174 = read_json(root, f"{PHASE}/253-174-EXECUTION-RECORD.json")
    log174 = read_bytes(root, f"{PHASE}/253-174-REGRESSION.log")
    if not re.search(r"^status: halted$", summary174, re.M):
        raise ContractError("174 must remain halted")
    if sha256(log174) != HISTORICAL_174_LOG_SHA256 or log174.decode("utf-8").splitlines()[-1] != "VERIFY-EXIT 1":
        raise ContractError("174 original failure log is not byte-identical")
    result174 = execution174.get("result", {})
    if result174.get("status") != "halted" or result174.get("acceptance_exit") != 1 or result174.get("attempt_count") != 1:
        raise ContractError("174 execution record no longer records its failed acceptance")
    preflight174 = read_json(root, f"{PHASE}/253-174-PERMISSION-PREFLIGHT.json")
    if preflight174.get("schema") != "sigra.phase253.git-permission-preflight/v1" or preflight174.get("status") != "passed":
        raise ContractError("174's successful permission probe must remain distinct from failed acceptance")
    summary167 = read_bytes(root, f"{PHASE}/253-167-SUMMARY.md").decode("utf-8")
    summary173 = read_bytes(root, f"{PHASE}/253-173-SUMMARY.md").decode("utf-8")
    log173 = read_bytes(root, f"{PHASE}/253-173-REGRESSION.log").decode("utf-8")
    if not re.search(r"^status: halted$", summary167, re.M) or not re.search(r"^status: halted$", summary173, re.M):
        raise ContractError("167 and173 original summaries must remain halted")
    summary175 = read_bytes(root, f"{PHASE}/253-175-SUMMARY.md").decode("utf-8", "strict")
    review175 = read_json(root, REVIEW_175)
    execution175 = read_json(root, f"{PHASE}/253-175-EXECUTION-RECORD.json")
    if not re.search(r"(?m)^status: halted$", summary175):
        raise ContractError("175 must remain halted")
    if review175.get("status") != "halted" or execution175.get("status") != "halted":
        raise ContractError("175 review/execution record no longer preserves its halted result")
    if log173.splitlines()[-1] != "VERIFY-EXIT 1":
        raise ContractError("173's original failure sentinel changed")
    for number in (173, 174, 175, 176, 177):
        if (root / f"{PHASE}/253-{number}-RECOVERY-RECEIPT.json").exists():
            raise ContractError(f"historical/superseded {number} success receipt must remain absent")
    for number in (176, 177):
        if (root / f"{PHASE}/253-{number}-SUMMARY.md").exists():
            raise ContractError(f"unexecuted {number} must not have a summary")
    return {"review173_sha256": sha256(raw_review173), "findings": len(review173["findings"]),
            "historical_sha256": HISTORICAL_SHA256,
            "174_log_sha256": sha256(log174), "174_status": "halted", "174_exit": 1,
            "173_status": "halted", "173_exit": 1, "167_status": "halted",
            "175_status": "halted", "175_commits": FROZEN_175_COMMITS}


def clean_status(root: Path) -> bytes:
    return git(root, "status", "--porcelain", "--untracked-files=all")


def run_deadline_guards(root: Path) -> dict:
    plan = read_bytes(root, f"{PHASE}/253-168-PLAN.md").decode("utf-8")
    pattern = (r"\$HOME/\.asdf/installs/nodejs/20\.18\.1/bin/node -e '.*?' "
               r"\.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
               r"253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R12\.json 1")
    match = re.search(pattern, plan, re.S)
    if not match:
        raise ContractError("exact168 deadline guard command is missing")
    command_one = match.group(0)
    command_twenty = command_one[:-1] + "20"
    good = subprocess.run(["bash", "-c", command_one], cwd=root, capture_output=True, text=True)
    control = subprocess.run(["bash", "-c", command_twenty], cwd=root, capture_output=True, text=True)
    if good.returncode != 0 or not good.stdout.startswith("R13 canary deadline guard:"):
        raise ContractError(f"168 deadline guard margin1 failed: {good.stdout.strip()} {good.stderr.strip()}")
    if control.returncode == 0 or not control.stdout.startswith("R13 canary deadline guard:"):
        raise ContractError("168 margin20 positive refusal control did not fail")
    return {"margin1_exit": good.returncode, "margin1_output": good.stdout.strip(),
            "margin20_exit": control.returncode, "margin20_output": control.stdout.strip(),
            "command_sha256": sha256(command_one.encode())}


def validate_review178(root: Path) -> dict:
    summary = read_bytes(root, f"{PHASE}/253-178-SUMMARY.md").decode("utf-8", "strict")
    if not re.search(r"(?m)^status: complete$", summary):
        raise ContractError("178 repair summary is not complete")
    review = read_json(root, REVIEW_178)
    if (review.get("schema") != REVIEW_SCHEMA or review.get("status") != "reviewed_for_new_acceptance"
            or review.get("repair_plan") != "253-178" or review.get("acceptance_plan") != "253-179"
            or review.get("bridge_plan") != "253-180"):
        raise ContractError("178 review identity or status is invalid")
    if review.get("unresolved_implementation_findings") != [] or review.get("acceptance_attempts") != 0:
        raise ContractError("178 review has unresolved findings or records an acceptance attempt")
    if review.get("requirements") != {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"}:
        raise ContractError("178 review overstates unresolved CIREL requirements")
    if review.get("phase_verification_status") != "not_started":
        raise ContractError("178 review overstates phase verification")
    required = {f"{PHASE}/253-RECOVERY-SUCCESSOR.py", f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
                PLAN_178, PLAN_179, PLAN_180, "scripts/ci/ci-git-publication.test.py",
                "scripts/ci/ci-git-publication.py", "scripts/ci/ci-gate-canary-dryrun.py"}
    files, commits = review.get("source_files"), review.get("source_commits")
    if not isinstance(files, dict) or set(files) != required or not isinstance(commits, dict) or set(commits) != required:
        raise ContractError("178 review does not bind the complete helper/test/plan/product-source set")
    for rel in sorted(required):
        if sha256(read_bytes(root, rel)) != files[rel]:
            raise ContractError(f"178 reviewed source hash differs: {rel}")
        commit = commits[rel]
        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ContractError(f"178 producing commit is missing: {rel}")
        if git(root, "show", f"{commit}:{rel}") != read_bytes(root, rel):
            raise ContractError(f"178 producing commit does not contain exact reviewed bytes: {rel}")
    if review.get("scope", {}).get("product_changes") != ["scripts/ci/ci-git-publication.test.py"]:
        raise ContractError("178 review product scope differs from the single reviewed test repair")
    if review.get("scope", {}).get("product_changes_during_178") != []:
        raise ContractError("178 review records product changes during the repair")
    return review


def prepare(root: Path, attempt_dir: Path) -> dict:
    root = root.resolve()
    attempt_dir = attempt_dir.resolve()
    if attempt_dir == root or root in attempt_dir.parents:
        raise ContractError("attempt directory must be outside the checkout")
    if attempt_dir.exists() and any(attempt_dir.iterdir()):
        raise ContractError("attempt directory must be fresh and empty")
    attempt_dir.mkdir(parents=True, exist_ok=True)
    status = clean_status(root)
    if status:
        raise ContractError("prepare requires clean committed source inputs")
    validate_review178(root)
    if sha256(read_bytes(root, "scripts/ci/ci-git-publication.py")) != PUBLISHER_SHA256:
        raise ContractError("production publisher pin changed")
    if sha256(read_bytes(root, "scripts/ci/ci-gate-canary-dryrun.py")) != DRYRUN_SHA256:
        raise ContractError("dry-run source pin changed")
    main_record = read_json(root, f"{PHASE}/253-LOAD-RECOVERY-MAIN-FETCH-R12.json")
    main_sha = main_record.get("fetched_main_sha")
    if main_sha != "09df342a82e03c3d5d40173c912b70e827f7eadc":
        raise ContractError("R12 main parent differs from the reviewed acceptance input")
    origin_main = git(root, "rev-parse", "refs/remotes/origin/main").decode().strip()
    if origin_main != main_sha:
        raise ContractError("origin/main differs from MAIN-FETCH-R12; preparation refuses stale source")
    check_historical_inputs(root)
    deadline = run_deadline_guards(root)
    if any((root / f"{PHASE}/253-179-{name}").exists() for name in
           ("PERMISSION-PREFLIGHT.json", "REGRESSION.log", "RECOVERY-RECEIPT.json", "SUMMARY.md")):
        raise ContractError("179 acceptance artifacts already exist")
    source174 = read_bytes(root, PLAN_174)
    body174 = command_body(source174, PLAN_174)
    generated, transformations = expected_acceptance_body(body174)
    source179 = read_bytes(root, PLAN_179)
    body179 = command_body(source179, PLAN_179)
    body179_hash = sha256(body179.encode("utf-8"))
    bindings = original_bindings(root)
    shared = {rel: sha256(read_bytes(root, rel)) for rel in SHARED}
    prepared = {
        "schema": "sigra.phase253.successor-prepared/v1",
        "source_commit": bindings["source_commit"],
        "plan174_body_sha256": sha256(body174.encode("utf-8")),
        "plan179_body_sha256": body179_hash,
        "generated_script_sha256": sha256(generated.encode("utf-8")),
        "transformations": transformations,
        "historical": check_historical_inputs(root),
        "publisher_sha256": PUBLISHER_SHA256,
        "dryrun_sha256": DRYRUN_SHA256,
        "deadline_guards": deadline,
        "shared_sha256": shared,
        "source_bindings": bindings["files"],
    }
    (attempt_dir / "acceptance.sh").write_text(generated, encoding="utf-8", newline="")
    (attempt_dir / "prepared.json").write_text(json.dumps(prepared, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    syntax = subprocess.run(["bash", "-n", str(attempt_dir / "acceptance.sh")], capture_output=True, text=True)
    if syntax.returncode:
        raise ContractError(f"generated acceptance syntax check failed: {syntax.stderr.strip()}")
    return prepared


def enter(root: Path, attempt_dir: Path) -> None:
    root = root.resolve()
    attempt_dir = attempt_dir.resolve()
    if attempt_dir == root or root in attempt_dir.parents:
        raise ContractError("attempt directory must remain outside the checkout")
    prepared = json.loads((attempt_dir / "prepared.json").read_bytes())
    script = read_bytes(attempt_dir, "acceptance.sh")
    if sha256(script) != prepared.get("generated_script_sha256"):
        raise ContractError("prepared script hash changed before entry")
    if git(root, "rev-parse", "HEAD").decode().strip() != prepared.get("source_commit"):
        raise ContractError("source commit changed after preparation")
    if clean_status(root):
        raise ContractError("source tree changed after preparation")
    marker = attempt_dir / "attempt.started"
    try:
        fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as error:
        raise ContractError("acceptance attempt has already been entered") from error
    with os.fdopen(fd, "wb") as stream:
        stream.write((prepared["source_commit"] + "\n").encode())


def bound_file(root: Path, value: dict, name: str) -> bytes:
    if not isinstance(value, dict) or set(value) != {"path", "sha256"}:
        raise ContractError(f"{name} must contain exactly path and sha256")
    rel = value["path"]
    if not isinstance(rel, str) or Path(rel).is_absolute() or ".." in Path(rel).parts:
        raise ContractError(f"{name} path is unsafe")
    raw = read_bytes(root, rel)
    if sha256(raw) != value["sha256"]:
        raise ContractError(f"{name} hash mismatch: {rel}")
    return raw


def parse_log(log: bytes) -> dict:
    try:
        text = log.decode("utf-8", "strict")
    except UnicodeDecodeError as error:
        raise ContractError(f"regression log is not UTF-8: {error}") from error
    if not text:
        raise ContractError("regression log is empty")
    lines = text.splitlines()
    if not lines or lines[-1] != "VERIFY-EXIT 0":
        raise ContractError("regression log must end with VERIFY-EXIT 0")
    counts = re.findall(r"^FULL-DRYRUN-COUNT ([0-9]+)$", text, re.M)
    if len(counts) != 1 or int(counts[0]) < 79:
        raise ContractError("log needs exactly one native full-dryrun count of at least 79")
    starts = re.findall(r"^SUITE-START ([a-z0-9-]+)$", text, re.M)
    passes = re.findall(r"^SUITE-PASS ([a-z0-9-]+)$", text, re.M)
    expected = [name for name, _ in SUITES]
    if starts != expected or passes != expected:
        raise ContractError("log suite start/pass markers are absent, duplicated, or out of order")
    if any(text.index(f"SUITE-START {name}") > text.index(f"SUITE-PASS {name}") for name in expected):
        raise ContractError("a suite PASS precedes its START")
    for name, _ in SUITES:
        start = text.index(f"SUITE-START {name}\n") + len(f"SUITE-START {name}\n")
        end = text.index(f"SUITE-PASS {name}\n", start)
        native = text[start:end]
        if name == "full-dryrun":
            native_counts = re.findall(r"(?m)^Ran ([1-9][0-9]*) tests? in [0-9.]+s$", native)
            if native_counts != counts:
                raise ContractError("full-dryrun native count is absent or differs from FULL-DRYRUN-COUNT")
        if name == "gate-canary-shell":
            if "ci-gate-canary tests passed (synthetic fixture repo; no active phase refs or ledgers)" not in native:
                raise ContractError("gate-canary-shell lacks its native successful termination row")
        elif not (re.search(r"(?m)^Ran [1-9][0-9]* tests? in [0-9.]+s$", native)
                  and re.search(r"(?m)^OK(?: \([^)]+\))?$", native)):
            raise ContractError(f"{name} lacks native unittest Ran/OK termination rows")
    json_rows = {}
    for marker in ("PROJECTION", "HERMETIC-GATE", "LIVE-POLICY-GATE", "PAGED-FULL-PASS"):
        values = [line[len(marker) + 1:] for line in lines if line.startswith(marker + " ")]
        if len(values) != 1:
            raise ContractError(f"log needs exactly one {marker} JSON row")
        try:
            json_rows[marker] = json.loads(values[0])
        except json.JSONDecodeError as error:
            raise ContractError(f"invalid {marker} JSON: {error}") from error
        if not isinstance(json_rows[marker], dict):
            raise ContractError(f"{marker} JSON root must be an object")
    projection = json_rows["PROJECTION"]
    if projection.get("status") != "ready-local-proposal" or projection.get("server_parent_sha") != "09df342a82e03c3d5d40173c912b70e827f7eadc":
        raise ContractError("projection status or main parent differs from the pinned R13 source")
    projection_data = projection.get("projection", {})
    if (type(projection_data.get("projected_total_requests")) is not int
            or projection_data["projected_total_requests"] > 22
            or type(projection_data.get("binary_blob_requests")) is not int
            or projection_data["binary_blob_requests"] > 10):
        raise ContractError("projection exceeds request or binary limits")
    tree_rows = projection.get("tree_requests")
    if not isinstance(tree_rows, list) or not tree_rows:
        raise ContractError("projection tree_requests must be a nonempty list")
    bodies = [row.get("body_bytes") if isinstance(row, dict) else None for row in tree_rows]
    if any(type(size) is not int or size <= 0 or size > TREE_CAP for size in bodies):
        raise ContractError("projection has an empty or over-cap serialized tree body")
    largest = max(bodies)
    if (projection_data.get("largest_tree_body_bytes") != largest
            or projection_data.get("max_tree_body_bytes") != TREE_CAP):
        raise ContractError("projection largest-tree measurement or declared cap differs from serialized bodies")
    merge_preflight = projection.get("main_freshness", {}).get("merge_preflight")
    if (not isinstance(merge_preflight, dict) or merge_preflight.get("clean") is not True
            or merge_preflight.get("exit") != 0 or merge_preflight.get("conflicts") != []):
        raise ContractError("projection merge_preflight is not a clean successful result")
    for marker in ("HERMETIC-GATE", "LIVE-POLICY-GATE", "PAGED-FULL-PASS"):
        row = json_rows[marker]
        if row.get("status") != "passed" or row.get("synthetic") is not True:
            raise ContractError(f"{marker} is not a passing local synthetic contract")
        if row.get("requests_by_category", {}).get("preflight") != 7:
            raise ContractError(f"{marker} preflight count changed")
        for version in ("r8", "r9", "r10", "r11", "r12"):
            if row.get(f"seeded_{version}_refs_changed") is not False:
                raise ContractError(f"{marker} changed seeded {version} refs")
    if json_rows["PAGED-FULL-PASS"].get("stop") is not None:
        raise ContractError("paged full-pass contract did not complete")
    native_source = re.findall(r"^ACCEPTANCE-SOURCE ([0-9a-f]{40})$", text, re.M)
    pids = re.findall(r"^ACCEPTANCE-PID ([0-9]+)$", text, re.M)
    probes = [line[len("PERMISSION-PREFLIGHT "):] for line in lines if line.startswith("PERMISSION-PREFLIGHT ")]
    if len(native_source) != 1 or len(pids) != 1 or len(probes) != 1:
        raise ContractError("log needs one acceptance source, PID and same-process permission probe")
    return {"text": text, "count": int(counts[0]), "json": json_rows,
            "source_commit": native_source[0], "pid": int(pids[0]),
            "probe": json.loads(probes[0]), "largest_tree_body_bytes": max(bodies),
            "remaining_tree_bytes": TREE_CAP - max(bodies)}


def validate_preflight(root: Path, preflight: dict, parsed: dict, prepared: dict, attempt_dir: Path) -> None:
    if preflight.get("schema") != "sigra.phase253.git-permission-preflight/v1" or preflight.get("status") != "passed":
        raise ContractError("176 permission preflight schema/status invalid")
    if preflight.get("acceptance_status") != "passed" or preflight.get("acceptance_exit") != 0 or preflight.get("once_only") is not True:
        raise ContractError("176 preflight must record exactly one successful acceptance")
    if preflight.get("acceptance_source") != prepared["source_commit"] or parsed["source_commit"] != prepared["source_commit"]:
        raise ContractError("acceptance source does not match prepared commit")
    if preflight.get("acceptance_pid") != parsed["pid"]:
        raise ContractError("acceptance PID does not match native log")
    probe = preflight.get("probe")
    if not isinstance(probe, dict) or probe != parsed["probe"]:
        raise ContractError("permission probe differs from the exact native log row")
    if probe.get("schema") != "sigra.phase253.git-permission-probe/v1" or probe.get("source_commit") != prepared["source_commit"]:
        raise ContractError("permission probe source/schema mismatch")
    if probe.get("shell_pid") != parsed["pid"] or probe.get("write_exit") != 0 or probe.get("read_exit") != 0 or probe.get("readback") != "exact":
        raise ContractError("permission probe does not prove successful same-process readback")
    if probe.get("command") != ["git", "hash-object", "-w", "--stdin"]:
        raise ContractError("permission probe command changed")
    if probe.get("payload_sha256") != probe.get("readback_sha256") or probe.get("payload_bytes", 0) <= 0:
        raise ContractError("permission probe payload readback differs")
    launch = preflight.get("launch")
    if not isinstance(launch, dict) or launch.get("tool") != "exec_command" or launch.get("sandbox_permissions") != "require_escalated" or launch.get("executor") != "root":
        raise ContractError("actual root require_escalated launch metadata is missing")
    if launch.get("block_sha256") != prepared.get("plan179_body_sha256"):
        raise ContractError("root launch did not bind the exact179 automated body")
    if not isinstance(launch.get("tool_call_id"), str) or not launch["tool_call_id"].strip() or not launch.get("session_id"):
        raise ContractError("actual tool call/session identity is missing")
    if launch.get("generated_script_sha256") != prepared.get("generated_script_sha256"):
        raise ContractError("launch record generated-script hash differs")
    if preflight.get("generated_script_sha256") != prepared.get("generated_script_sha256"):
        raise ContractError("preflight generated script hash differs")
    if preflight.get("plan_command_sha256") != prepared.get("plan179_body_sha256"):
        raise ContractError("preflight exact179 plan-command hash differs")
    if parsed["json"]["PAGED-FULL-PASS"].get("mode") != "live-policy":
        raise ContractError("paged pass mode changed")


def validate_probe_object(root: Path, probe: dict) -> None:
    oid = probe.get("object_oid")
    if not isinstance(oid, str) or not re.fullmatch(r"[0-9a-f]{40}", oid):
        raise ContractError("permission probe object id is invalid")
    common = Path(git(root, "rev-parse", "--git-common-dir").decode().strip())
    if not common.is_absolute():
        common = (root / common).resolve()
    else:
        common = common.resolve()
    if probe.get("git_common_dir") != str(common) or probe.get("object_dir") != str((common / "objects").resolve()):
        raise ContractError("permission probe Git object directory differs from the real checkout")
    stored = git(root, "cat-file", "blob", oid)
    if len(stored) != probe.get("payload_bytes") or sha256(stored) != probe.get("payload_sha256"):
        raise ContractError("permission probe blob readback differs from its recorded payload")


def expected_receipt(root: Path, attempt_dir: Path) -> dict:
    prepared = json.loads(read_bytes(attempt_dir, "prepared.json"))
    log = read_bytes(attempt_dir, "253-179-REGRESSION.log")
    preflight = read_json(attempt_dir, "253-179-PERMISSION-PREFLIGHT.json")
    parsed = parse_log(log)
    validate_preflight(root, preflight, parsed, prepared, attempt_dir)
    history = check_historical_inputs(root)
    source = prepared["source_commit"]
    if parsed["source_commit"] != source:
        raise ContractError("receipt source does not match committed source")
    git(root, "merge-base", "--is-ancestor", source, "HEAD")
    if git(root, "diff", "--name-only", source, "HEAD", "--", ".", ":(exclude).planning/**"):
        raise ContractError("product source changed between acceptance and receipt creation")
    for rel, digest in prepared["shared_sha256"].items():
        if sha256(read_bytes(root, rel)) != digest:
            raise ContractError(f"shared planning bytes changed during176: {rel}")
    for rel, binding in prepared["source_bindings"].items():
        current = read_source_bytes(root, rel)
        if sha256(current) != binding["sha256"]:
            raise ContractError(f"protected source file changed after preparation: {rel}")
    projection = parsed["json"]["PROJECTION"]
    return {
        "schema": SUCCESSOR_SCHEMA,
        "status": "verified_local_success",
        "recovery_plan": "253-179",
        "repair_plan": "253-178",
        "bridge_plan": "253-180",
        "attempt_count": 1,
        "next_plan": "253-180",
        "source_commit": source,
        "plan_command_sha256": prepared["plan179_body_sha256"],
        "generated_script_sha256": prepared["generated_script_sha256"],
        "historical": history,
        "historical_sha256": {rel: row["sha256"] for rel, row in prepared["source_bindings"].items()},
        "shared_sha256": prepared["shared_sha256"],
        "review": {"path": REVIEW_173, "sha256": REVIEW_173_SHA256},
        "repair_review": {"path": REVIEW_178, "sha256": sha256(read_bytes(root, REVIEW_178))},
        "permission_preflight": {"path": f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json", "sha256": sha256(read_bytes(attempt_dir, "253-179-PERMISSION-PREFLIGHT.json"))},
        "regression_log": {"path": f"{PHASE}/253-179-REGRESSION.log", "sha256": sha256(log)},
        "projection": projection,
        "hermetic": parsed["json"]["HERMETIC-GATE"],
        "live_policy": parsed["json"]["LIVE-POLICY-GATE"],
        "paged": parsed["json"]["PAGED-FULL-PASS"],
        "verify_exit": 0,
        "full_dryrun_count": parsed["count"],
        "largest_tree_body_bytes": parsed["largest_tree_body_bytes"],
        "remaining_tree_bytes": parsed["remaining_tree_bytes"],
        "paged_scope": "--stop-after full-pass",
        "full_paged_stop": {"category": "attempt_jobs", "used": 7, "cap": 7,
                             "source": f"{PHASE}/253-167-SUMMARY.md", "new_retry": False},
        "scope": {"github_requests": 0, "native_browser_launches": 0, "synthetic": True,
                  "product_changes": ["scripts/ci/ci-git-publication.test.py"],
                  "product_changes_during_attempt": []},
        "requirements": {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"},
        "phase_verification_status": "not_started",
    }


def write_receipt(root: Path, attempt_dir: Path) -> dict:
    receipt = expected_receipt(root.resolve(), attempt_dir.resolve())
    target = root / RECEIPT_179
    if target.exists():
        raise ContractError("179 receipt already exists")
    target.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return receipt


def verify_receipt(root: Path, consumer: str | None = None) -> dict:
    root = root.resolve()
    receipt = read_json(root, RECEIPT_179)
    if receipt.get("schema") != SUCCESSOR_SCHEMA or receipt.get("status") != "verified_local_success":
        raise ContractError("179 successor receipt schema/status invalid")
    for rel, field in ((REVIEW_173, "review"), (REVIEW_178, "repair_review"),
                       (f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json", "permission_preflight"),
                       (f"{PHASE}/253-179-REGRESSION.log", "regression_log")):
        bound_file(root, receipt.get(field), field)
        if receipt[field]["path"] != rel:
            raise ContractError(f"{field} points at the wrong canonical path")
    if receipt["review"]["sha256"] != REVIEW_173_SHA256:
        raise ContractError("original173 review binding changed")
    review = read_json(root, REVIEW_173)
    if review.get("schema") != "sigra.phase253.execution-halt-review/v1" or review.get("status") != "reviewed_for_new_acceptance":
        raise ContractError("nested173 review is not the original reviewed schema/status")
    if review.get("status_dispositions", {}).get("product_changes") != []:
        raise ContractError("nested173 product_changes disposition is not empty")
    if len(review.get("findings", [])) != EXPECTED_173_FINDINGS:
        raise ContractError("nested173 review does not retain all ten findings")
    history = check_historical_inputs(root)
    if receipt.get("historical") != history:
        raise ContractError("receipt historical outcomes differ from reopened original evidence")
    validate_review178(root)
    parsed = parse_log(bound_file(root, receipt["regression_log"], "regression log"))
    preflight = read_json(root, receipt["permission_preflight"]["path"])
    body174 = command_body(read_bytes(root, PLAN_174), PLAN_174)
    generated, _ = expected_acceptance_body(body174)
    body179 = command_body(read_bytes(root, PLAN_179), PLAN_179)
    if sha256(body179.encode()) != receipt.get("plan_command_sha256"):
        raise ContractError("receipt plan command hash is not the exact179 first body")
    if sha256(generated.encode()) != receipt.get("generated_script_sha256"):
        raise ContractError("receipt generated script hash is not the reviewed174-to-179 transformation")
    prepared = {"source_commit": receipt.get("source_commit"),
                "plan179_body_sha256": receipt.get("plan_command_sha256"),
                "generated_script_sha256": receipt.get("generated_script_sha256"),
                "shared_sha256": receipt.get("shared_sha256", {}),
                "source_bindings": {rel: {"sha256": value} for rel, value in receipt.get("historical_sha256", {}).items()}}
    validate_preflight(root, preflight, parsed, prepared, root)
    validate_probe_object(root, preflight["probe"])
    if receipt.get("recovery_plan") != "253-179" or receipt.get("repair_plan") != "253-178" or receipt.get("bridge_plan") != "253-180":
        raise ContractError("receipt plan lineage is incorrect")
    if receipt.get("attempt_count") != 1 or receipt.get("next_plan") != "253-180":
        raise ContractError("receipt attempt count or next plan is incorrect")
    if receipt.get("verify_exit") != 0 or receipt.get("full_dryrun_count") != parsed["count"]:
        raise ContractError("receipt native result differs from the log")
    for field, marker in (("projection", "PROJECTION"), ("hermetic", "HERMETIC-GATE"),
                          ("live_policy", "LIVE-POLICY-GATE"), ("paged", "PAGED-FULL-PASS")):
        if receipt.get(field) != parsed["json"][marker]:
            raise ContractError(f"receipt {field} object differs from its native log row")
    if receipt.get("scope") != {"github_requests": 0, "native_browser_launches": 0, "synthetic": True,
                                "product_changes": ["scripts/ci/ci-git-publication.test.py"],
                                "product_changes_during_attempt": []}:
        raise ContractError("receipt scope or attempt-time product diff changed")
    if receipt.get("requirements") != {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"} or receipt.get("phase_verification_status") != "not_started":
        raise ContractError("receipt overstates requirement or phase status")
    if receipt.get("paged_scope") != "--stop-after full-pass" or receipt.get("full_paged_stop") != {
            "category": "attempt_jobs", "used": 7, "cap": 7, "source": f"{PHASE}/253-167-SUMMARY.md", "new_retry": False}:
        raise ContractError("receipt altered the original paging limitation")
    if receipt.get("largest_tree_body_bytes") != parsed["largest_tree_body_bytes"] or receipt.get("remaining_tree_bytes") != parsed["remaining_tree_bytes"]:
        raise ContractError("receipt tree-body measurements differ from projection")
    source = receipt.get("source_commit")
    if not re.fullmatch(r"[0-9a-f]{40}", str(source)):
        raise ContractError("receipt source commit is invalid")
    for rel, digest in receipt.get("shared_sha256", {}).items():
        source_bytes = git(root, "show", f"{source}:{rel}")
        if sha256(source_bytes) != digest:
            raise ContractError(f"receipt source shared bytes differ: {rel}")
        if consumer != "168" and sha256(read_bytes(root, rel)) != digest:
            raise ContractError(f"current shared bytes differ from source: {rel}")
    if set(receipt.get("shared_sha256", {})) != set(SHARED):
        raise ContractError("receipt must bind exactly four shared planning files")
    historical = receipt.get("historical_sha256")
    if not isinstance(historical, dict) or not historical:
        raise ContractError("receipt historical bindings are empty")
    source_paths = set()
    for row in git(root, "ls-tree", "-rz", "-r", source, "--", PHASE,
                   ".planning/phases/252-measure-current-ci").split(b"\0"):
        if row:
            source_paths.add(row.split(b"\t", 1)[1].decode("utf-8", "strict"))
    if set(historical) != source_paths:
        raise ContractError("receipt does not bind every and only existing Phase253/252 source path")
    changed_originals = []
    for rel, digest in historical.items():
        if not rel.startswith((PHASE + "/", ".planning/phases/252-measure-current-ci/")):
            raise ContractError(f"receipt historical path outside Phase253/252: {rel}")
        data = git(root, "show", f"{source}:{rel}")
        if sha256(data) != digest:
            raise ContractError(f"historical source binding differs: {rel}")
        current = root / rel
        if not current.exists():
            raise ContractError(f"current historical source path is missing: {rel}")
        if sha256(read_source_bytes(root, rel)) != digest:
            if consumer == "168" and rel in {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)}:
                changed_originals.append(rel)
            else:
                raise ContractError(f"current historical bytes differ: {rel}")
    if consumer == "168":
        bridge_rel = BRIDGE_180
        bridge_file = root / bridge_rel
        if changed_originals and not bridge_file.exists():
            raise ContractError("168 consumer requires the180 durable bridge record after plan amendments")
        if bridge_file.exists():
            bridge_record = read_json(root, bridge_rel)
            if bridge_record.get("source_commit") != source:
                raise ContractError("180 bridge source commit differs from the179 receipt")
            validate_bridge(root, bridge_record.get("stage"), bridge_rel)
            allowed = ({f"{PHASE}/253-{n}-PLAN.md" for n in (168, 169)}
                       if bridge_record.get("stage") == "entry"
                       else {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)})
            if set(bridge_record.get("amended_sha256", {})) != allowed:
                raise ContractError("180 bridge does not scope exactly the active-stage plan amendments")
    if clean_status(root):
        raise ContractError("receipt verification requires a clean committed tree")
    return {"status": "verified", "source_commit": source, "count": parsed["count"]}


def sdk_identity() -> dict:
    sdk = Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs"
    node = Path.home() / ".asdf/installs/nodejs/20.18.1/bin/node"
    if not sdk.is_file() or not node.is_file():
        raise ContractError("installed GSD SDK or pinned Node runtime is unavailable")
    return {"path": str(sdk), "sha256": sha256(sdk.read_bytes()),
            "node": str(node), "node_sha256": sha256(node.read_bytes())}


def _git_manifest(root: Path, commit: str) -> list[dict]:
    """Read a committed .planning tree through Git objects, excluding only the bridge record."""
    if not re.fullmatch(r"[0-9a-f]{40}", str(commit)):
        raise ContractError("SDK source input commit is invalid")
    tree = git(root, "ls-tree", "-rz", "-r", commit, "--", ".planning")
    entries = {}
    for raw in tree.split(b"\0"):
        if not raw:
            continue
        meta, path_raw = raw.split(b"\t", 1)
        mode, kind, oid = meta.decode("ascii").split()
        path = path_raw.decode("utf-8", "strict")
        if kind != "blob" or not path.startswith(".planning/"):
            continue
        if path in SDK_MANIFEST_EXCLUSIONS:
            continue
        entries[path] = {"path": path, "blob": oid, "mode": mode}
    if not entries:
        raise ContractError("SDK source commit contains no committed planning inputs")
    oids = list(dict.fromkeys(row["blob"] for row in entries.values()))
    batch = git(root, "cat-file", "--batch", input_bytes=("\n".join(oids) + "\n").encode())
    offset = 0
    blobs = {}
    for requested in oids:
        header_end = batch.find(b"\n", offset)
        if header_end < 0:
            raise ContractError("Git source manifest blob header is truncated")
        header = batch[offset:header_end].decode("ascii").split()
        if len(header) != 3 or header[0] != requested or header[1] != "blob":
            raise ContractError("Git source manifest blob identity differs")
        size = int(header[2])
        start, end = header_end + 1, header_end + 1 + size
        if end >= len(batch) or batch[end:end + 1] != b"\n":
            raise ContractError("Git source manifest blob bytes are truncated")
        blobs[requested] = batch[start:end]
        offset = end + 1
    manifest = []
    for path in sorted(entries):
        row = entries[path]
        content = blobs[row["blob"]]
        manifest.append({"path": path, "blob": row["blob"], "bytes": len(content),
                         "sha256": sha256(content)})
    return manifest


def _filesystem_manifest(root: Path) -> list[dict]:
    planning = root / ".planning"
    files = {}
    for path in sorted(planning.rglob("*")):
        if not path.is_file() and not path.is_symlink():
            continue
        rel = path.relative_to(root).as_posix()
        if rel in SDK_MANIFEST_EXCLUSIONS:
            continue
        if path.is_symlink():
            raise ContractError(f"SDK planning input may not be a symlink: {rel}")
        raw = path.read_bytes()
        files[rel] = {"path": rel, "bytes": len(raw), "sha256": sha256(raw)}
    return [files[path] for path in sorted(files)]


def _assert_sdk_source_binding(root: Path, commit: str, manifest: object,
                               require_current: bool = False) -> list[dict]:
    if not isinstance(manifest, list):
        raise ContractError("SDK committed source manifest must be a list")
    expected = _git_manifest(root, commit)
    clean_rows = [{key: row.get(key) for key in ("path", "blob", "bytes", "sha256")}
                  for row in manifest if isinstance(row, dict)]
    if len(clean_rows) != len(manifest) or clean_rows != expected:
        raise ContractError("SDK committed source manifest differs from Git source bytes")
    if require_current:
        current = _filesystem_manifest(root)
        expected_files = [{"path": row["path"], "bytes": row["bytes"], "sha256": row["sha256"]}
                          for row in expected]
        if current != expected_files:
            raise ContractError("SDK current planning input differs from its committed source manifest")
    head = git(root, "rev-parse", "HEAD").decode("ascii").strip()
    result = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", commit, head],
                            capture_output=True, check=False)
    if result.returncode:
        raise ContractError("SDK source input commit is not an ancestor of the consuming project HEAD")
    return expected


def validate_sdk_index_rows(rows: object, init: dict, stage: str) -> dict:
    """Validate raw index rows before a caller can turn them into an ID-keyed map."""
    if stage not in ("readiness", "final"):
        raise ContractError("SDK index stage must be readiness or final")
    if not isinstance(rows, list) or len(rows) != 181:
        raise ContractError("SDK index must contain exactly181 raw plan rows")
    if not isinstance(init, dict):
        raise ContractError("SDK init output must be an object")
    ids = []
    for row in rows:
        if not isinstance(row, dict):
            raise ContractError("SDK index rows must be objects before ID conversion")
        plan_id = row.get("id")
        if not isinstance(plan_id, str) or re.fullmatch(r"253-(?:0[1-9]|[1-9][0-9]{1,2})", plan_id) is None:
            raise ContractError("SDK index plan ID is malformed")
        ids.append(plan_id)
        if not isinstance(row.get("has_summary"), bool) or not isinstance(row.get("halted"), bool):
            raise ContractError(f"SDK index summary/halt fields are malformed for {plan_id}")
        if not isinstance(row.get("gap_closure"), bool):
            raise ContractError(f"SDK index gap_closure field is malformed for {plan_id}")
        if "ready" in row and not isinstance(row["ready"], bool):
            raise ContractError(f"SDK index readiness field is malformed for {plan_id}")
        blocked = row.get("blocked_by")
        if (not isinstance(blocked, list) or
                any(not isinstance(item, str) or re.fullmatch(
                    r"253-(?:0[1-9]|[1-9][0-9]{1,2})", item) is None for item in blocked)):
            raise ContractError(f"SDK index blocked_by is malformed for {plan_id}")
    if len(set(ids)) != 181:
        raise ContractError("SDK index contains duplicate plan IDs")
    if set(ids) != set(EXPECTED_PLAN_IDS):
        raise ContractError("SDK index plan IDs differ from the exact 253-01 through253-181 universe")
    if type(init.get("plan_count")) is not int or init["plan_count"] != 181:
        raise ContractError("SDK init plan_count differs from the exact181-row index")
    by_id = {row["id"]: row for row in rows}
    halted = sorted(plan_id for plan_id, row in by_id.items() if row["halted"] is True)
    expected_halted = sorted(f"253-{number:02d}" for number in HISTORICAL_HALT_IDS)
    if halted != expected_halted:
        raise ContractError("SDK index halted plan IDs differ from the exact25 halted set")
    incomplete = sorted(f"{plan_id}-PLAN.md" for plan_id, row in by_id.items()
                        if row["has_summary"] is not True)
    incomplete_count = init.get("incomplete_count")
    incomplete_plans = init.get("incomplete_plans")
    if (type(incomplete_count) is not int or not isinstance(incomplete_plans, list) or
            any(not isinstance(item, str) for item in incomplete_plans) or
            incomplete_count != len(incomplete) or sorted(incomplete_plans) != incomplete):
        raise ContractError("SDK init incomplete fields disagree with raw plan summary rows")
    runnable = init.get("runnable_plans")
    runnable_pattern = re.compile(r"253-(?:0[1-9]|[1-9][0-9]{1,2})-PLAN\.md")
    if (not isinstance(runnable, list) or any(not isinstance(item, str) or
                                               runnable_pattern.fullmatch(item) is None for item in runnable) or
            len(set(runnable)) != len(runnable)):
        raise ContractError("SDK init runnable field is malformed or duplicated")
    if stage == "readiness":
        row168 = by_id["253-168"]
        if row168["has_summary"] or row168["halted"] or row168["blocked_by"] != []:
            raise ContractError(f"SDK readiness168 row must be summary-absent, unhalted and unblocked: {row168}")
        if "253-168-PLAN.md" not in runnable:
            raise ContractError("SDK readiness init does not list168 as runnable")
    for item in runnable:
        plan_id = item.removesuffix("-PLAN.md")
        row = by_id.get(plan_id)
        if row is None or row["has_summary"] or row["halted"] or row["blocked_by"]:
            raise ContractError(f"SDK init runnable plan disagrees with raw index row: {item}")
    ready_plans = {f"{plan_id}-PLAN.md" for plan_id, row in by_id.items() if row.get("ready") is True}
    if not ready_plans.issubset(set(runnable)):
        raise ContractError("SDK init runnable fields omit a raw index row marked ready")
    if stage == "final":
        if incomplete or init.get("incomplete_count") != 0 or init.get("incomplete_plans") != []:
            raise ContractError("SDK final index must have zero incomplete summaries")
        # blocked_by reports dependency graph ancestry, including valid
        # dispositions behind preserved halted plans. It differs from a
        # summary whose own status is `blocked`, checked by the copy producer.
    return by_id


def sdk_query(project: Path, command: str, phase: str = "253") -> tuple[dict, bytes, dict]:
    identity = sdk_identity()
    sdk = Path(identity["path"])
    node = Path(identity["node"])
    argv = [str(node), str(sdk), "query", command, phase,
            "--project-dir", str(project), "--raw"]
    result = subprocess.run(argv,
                            capture_output=True, check=False)
    if result.returncode:
        raise ContractError(f"installed SDK {command} failed ({result.returncode}): "
                            f"{result.stderr.decode('utf-8', 'replace').strip()}")
    try:
        value = json.loads(result.stdout)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ContractError(f"installed SDK {command} did not return JSON: {error}") from error
    if not isinstance(value, dict):
        raise ContractError(f"installed SDK {command} returned a non-object")
    return value, result.stdout, {"argv": argv, "returncode": result.returncode}


def sdk_write_summary(project: Path, number: int, status: str, suffix: str) -> None:
    phase_dir = project / PHASE
    summary = phase_dir / f"253-{number:02d}-SUMMARY.md"
    if summary.exists():
        # Historical results and any already-completed real plan are inputs, never
        # fixtures to rewrite. The copy must preserve their bytes exactly.
        return
    summary.write_text(f"---\nphase: 253-fix-flaky-ci-and-preserve-required-checks\n"
                       f"plan: \"{number}\"\nstatus: {status}\n---\n\n"
                       f"# Simulated SDK fixture {number}\n\n{suffix}\n", encoding="utf-8")


NEVER_RAN_IDS = (144, 145, *range(147, 155), *range(156, 164))
HISTORICAL_HALT_IDS = (2, 7, 9, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97,
                       104, 113, 122, 134, 143, 146, 155, 167, 173, 174, 175, 178)
ORIGINALS_180 = "refs/gsd/phase253-successor-180-plan-originals"
EXPECTED_PLAN_IDS = tuple(f"253-{number:02d}" for number in range(1, 182))
SDK_MANIFEST_EXCLUSIONS = (BRIDGE_180,)


def validate_169_executable_contract(plan: str, root: Path) -> None:
    """Inspect the actual original third automated check, not appended prose."""
    bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
    if len(bodies) < 3:
        raise ContractError("169 executable reconciliation assertion body is missing")
    scripts = re.findall(r'(?:node|\"\$N\")\s+-e\s+\'(.*?)\'', bodies[2], re.S)
    if len(scripts) != 1:
        raise ContractError("169 third automated body must contain one executable reconciliation assertion")
    script = scripts[0]
    expected_script = expected_169_script(root)
    try:
        r12 = read_json(root, R12_CONTRACT)
        if sha256(read_bytes(root, R12_CONTRACT)) != R12_CONTRACT_SHA256:
            raise ContractError("169 exact target source differs from frozen R12 bytes")
        expected_targets = [row["plan"] for row in r12["responsibilities"]]
    except (KeyError, TypeError) as error:
        raise ContractError(f"169 exact target source is malformed: {error}") from error
    expected_targets.extend(f"253-{number:02d}" for number in NEVER_RAN_IDS + (176, 177))
    expected_halts = [f"253-{number:02d}" for number in HISTORICAL_HALT_IDS]
    expected_plans = [f"253-{number:02d}" for number in range(1, 181)]
    for name, expected, reason in (
        ("EXPECTED_TARGET_IDS", expected_targets, "exact73 target set"),
        ("EXPECTED_HALT_IDS", expected_halts, "exact24 halt set"),
        ("EXPECTED_PLAN_IDS", expected_plans, "exact180 plan-pin set"),
    ):
        match = re.search(rf"const {name}=(\[.*?\]);", script, re.S)
        if not match:
            raise ContractError(f"169 executable {reason} comparison is missing")
        try:
            actual = json.loads(match.group(1))
        except json.JSONDecodeError as error:
            raise ContractError(f"169 executable {reason} is not a JSON array") from error
        if actual != expected:
            label = {"exact73 target set": "73 target set", "exact24 halt set": "24 halt set",
                     "exact180 plan-pin set": "180-plan-pin set"}[reason]
            raise ContractError(f"169 executable {label} differs from the authoritative source")
        actual_rows = {"EXPECTED_TARGET_IDS": "targets", "EXPECTED_HALT_IDS": "halts",
                       "EXPECTED_PLAN_IDS": "pins"}[name]
        if f"JSON.stringify(sort({actual_rows}))!==JSON.stringify(sort({name}))" not in script:
            raise ContractError(f"169 executable {reason} is not compared with actual rows")
    if not all(needle in script for needle in (
        "c.responsibilities.length!==73", "c.plan_pins.length!==180", "c.halted_plans.length!==24")):
        raise ContractError("169 executable reconciliation assertion has a stale count")
    if script != expected_script:
        raise ContractError("169 executable reconciliation assertion contains an unapproved executable or comment change")


def expected_169_script(root: Path) -> str:
    r12 = read_json(root, R12_CONTRACT)
    if sha256(read_bytes(root, R12_CONTRACT)) != R12_CONTRACT_SHA256:
        raise ContractError("169 exact target source differs from frozen R12 bytes")
    target_ids = [row["plan"] for row in r12["responsibilities"]]
    target_ids.extend(f"253-{number:02d}" for number in NEVER_RAN_IDS + (176, 177))
    halt_ids = [f"253-{number:02d}" for number in HISTORICAL_HALT_IDS]
    plan_ids = [f"253-{number:02d}" for number in range(1, 181)]
    return (
        'const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
        'const t=JSON.stringify(c); '
        f'const EXPECTED_TARGET_IDS={json.dumps(target_ids,separators=(",",":"))}; '
        f'const EXPECTED_HALT_IDS={json.dumps(halt_ids,separators=(",",":"))}; '
        f'const EXPECTED_PLAN_IDS={json.dumps(plan_ids,separators=(",",":"))}; '
        'const sort=(xs)=>[...xs].sort(); '
        'const targets=c.responsibilities.map(r=>r.plan); '
        'const halts=c.halted_plans.map(r=>r.plan); '
        'const pins=c.plan_pins.map(r=>r.plan); '
        'if(c.responsibilities.length!==73||c.plan_pins.length!==180||c.halted_plans.length!==24||'
        'c.application.bundle_requires_final_summary_of!=="253-172"||'
        'c.application.accepted_only_predicate!=="scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"||'
        'JSON.stringify(sort(targets))!==JSON.stringify(sort(EXPECTED_TARGET_IDS))||'
        'JSON.stringify(sort(halts))!==JSON.stringify(sort(EXPECTED_HALT_IDS))||'
        'JSON.stringify(sort(pins))!==JSON.stringify(sort(EXPECTED_PLAN_IDS))||'
        '!t.includes("pagination_destination_rejected")||!t.includes("ci-gate-canary-flow.test.py")||'
        '!t.includes("TransportSensitivityTests")) process.exit(1)'
    )


def _replace_exactly_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise ContractError(f"ambiguous or missing {label} source anchor (found {count})")
    return text.replace(old, new, 1)


def validate_168_receipt_placement(plan: str) -> None:
    bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
    prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
              "253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 || exit $?;")
    if len(bodies) != 2 or any(body.count("verify-receipt --consumer 168") != 1 or
                                not body.lstrip().startswith(prefix) for body in bodies):
        raise ContractError("168 receipt check must appear exactly once at the start of both automated bodies")


def expected_plan_amendment(original: str, number: int, root: Path) -> str:
    """Return the only permitted complete future-plan rewrite from its pinned bytes."""
    if number == 168:
        current = _replace_exactly_once(original, "wave: 2", "wave: 4", "168 wave")
        current = _replace_exactly_once(current, 'depends_on: ["253-174"]',
                                        'depends_on: ["253-180"]', "168 dependency")
        bodies = re.findall(r"<automated>(.*?)</automated>", current, re.S)
        if len(bodies) != 2:
            raise ContractError("168 must retain exactly two original automated bodies")
        old_matches = list(re.finditer(
            r'python3 -c \'import os,pathlib,re,subprocess; p=pathlib\.Path\("[^"]*253-174-PLAN\.md"\);.*?\' \|\| exit \$\?; ?',
            bodies[0], re.S))
        if len(old_matches) != 1:
            raise ContractError("ambiguous or missing 168 original receipt preamble")
        bodies[0] = bodies[0].replace(old_matches[0].group(0), "", 1)
        prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
                  "253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 || exit $?; ")
        body_index = 0
        def prefix_body(_match: re.Match) -> str:
            nonlocal body_index
            body = bodies[body_index]
            body_index += 1
            return "<automated>" + prefix + body + "</automated>"
        current, replacements = re.subn(r"<automated>.*?</automated>", prefix_body,
                                        current, count=2, flags=re.S)
        if replacements != 2 or body_index != 2:
            raise ContractError("168 original automated bodies could not be amended exactly once")
        return _replace_exactly_once(current, "253-174-RECOVERY-RECEIPT.json",
                                     "253-179-RECOVERY-RECEIPT.json", "168 receipt path")
    if number == 169:
        current = _replace_exactly_once(original, "wave: 3", "wave: 5", "169 wave")
        for old, new, label in (
            ("22 halted", "24 halted", "169 halt count"), ("22) and", "24) and", "169 halt predicate"),
            ("23 halted", "24 halted", "169 prior halt count"), ("23) and", "24) and", "169 prior halt predicate"),
            ("71 unstarted", "73 unstarted", "169 target count"), ("71-target", "73-target", "169 target label"),
            ("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json", "169 receipt path"),
            ("253-174", "253-179", "169 recovery identity"),
            ("149 -> 174", "149 -> 179", "149 owner"), ("158 -> 174", "158 -> 179", "158 owner"),
            ("167 -> 174", "167 -> 179", "167 proof owner"), ("173 -> 174", "173 -> 179", "173 proof owner"),
            ("154 -> 169 and 172;", "154 -> 169 and 172, 176 -> 179, 177 -> 180;", "new responsibility rows"),
            ("154 -> 169, 172 (all completion links plus load_target_disposition);",
             "154 -> 169, 172 (all completion links plus load_target_disposition), 176 -> 179, 177 -> 180;", "new proof rows"),
            ("173 -> 179.", "173 -> 179; 174 -> [178, 179]; 175 -> [178, 179].", "failed attempt owners"),
        ):
            # 253-174 has two distinct references after the receipt path is rewritten.
            if label == "169 recovery identity":
                if current.count(old) == 0:
                    raise ContractError(f"missing {label} source anchor")
                current = current.replace(old, new)
            else:
                # The original plan can legitimately contain no stale prose
                # occurrence for one of these optional compatibility strings.
                # When present, transform every original occurrence. Exact
                # whole-file comparison still rejects any added duplicate.
                current = current.replace(old, new)
        current = _replace_exactly_once(current, "253-179 amendment to",
            "253-179 amendment: verify-receipt --consumer 168 is required before each contract consumer; preserve halted 253-175-PLAN.md, 253-175-SUMMARY.md, 253-175-REPAIR-REVIEW.json and 253-175-EXECUTION-RECORD.json. 253-179 amendment to",
            "169 preserved historical evidence clause")
        old_script = expected_169_script(root)
        bodies = re.findall(r"<automated>(.*?)</automated>", original, re.S)
        if len(bodies) < 3:
            raise ContractError("169 third automated source body is missing")
        scripts = re.findall(r'(?:node|\"\$N\")\s+-e\s+\'(.*?)\'', bodies[2], re.S)
        if len(scripts) != 1:
            raise ContractError("169 third automated source body is ambiguous")
        return _replace_exactly_once(current, scripts[0], old_script, "169 executable assertion")
    if number in (170, 171):
        old_wave, new_wave = ((4, 6) if number == 170 else (5, 7))
        return _replace_exactly_once(original, f"wave: {old_wave}", f"wave: {new_wave}", f"{number} wave")
    if number == 172:
        current = _replace_exactly_once(original, "wave: 6", "wave: 8", "172 wave")
        current = _replace_exactly_once(current,
            "<automated>N=\"$HOME/.asdf/installs/nodejs/20.18.1/bin/node\";",
            "<automated>python3 .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 && N=\"$HOME/.asdf/installs/nodejs/20.18.1/bin/node\";",
            "172 receipt verifier preamble")
        for old, new, label in (
            ("Twenty-two halted", "Twenty-four halted", "172 halt prose"),
            ("22 halted", "24 halted", "172 halt count"),
            ("71 targets", "73 targets", "172 target count"),
            ("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json", "172 receipt"),
            ("253-174-RECOVERY-SUCCESSOR.py", "253-RECOVERY-SUCCESSOR.py", "172 verifier"),
        ):
            current = current.replace(old, new)
        bodies = re.findall(r"<automated>(.*?)</automated>", current, re.S)
        if len(bodies) != 2:
            raise ContractError("172 automated command bodies are missing or duplicated")
        scripts = list(re.finditer(r'"?\$N"?\s+-e\s+\'(const b=JSON\.parse\(require\("fs"\).*?process\.exit\(1\))\' \$P/253-LOAD-RECOVERY-SUPERSESSION-SUMMARIES-R13\.json', bodies[1], re.S))
        if len(scripts) != 1:
            raise ContractError("172 original executable bundle assertion is missing or ambiguous")
        r12 = read_json(root, R12_CONTRACT)
        targets = [row["plan"] for row in r12["responsibilities"]]
        targets.extend(f"253-{n:02d}" for n in NEVER_RAN_IDS + (176, 177))
        new_script = (
            'const b=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
            'const paths=(b.entries||[]).map(e=>e.path||e.disposition_path||""); '
            f'const EXPECTED={json.dumps([f"{n}-SUMMARY.md" for n in targets],separators=(",",":"))}; '
            'const sort=(xs)=>[...xs].sort(); '
            'if(paths.length!==73||new Set(paths).size!==73||'
            'JSON.stringify(sort(paths))!==JSON.stringify(sort(EXPECTED))) process.exit(1)'
        )
        body = bodies[1]
        old_script = scripts[0].group(1)
        current = current.replace(old_script, new_script, 1)
        return current
    raise ContractError(f"no exact amendment specification for plan {number}")


def validate_169_owner_contract(plan: str, original: str, root: Path) -> None:
    expected = expected_plan_amendment(original, 169, root)
    if plan != expected:
        raise ContractError("169 ownership table or other instruction bytes differ from the exact original-derived amendment")


def run_sdk_copy(root: Path, record: dict, record_path: str) -> dict:
    """Run installed GSD queries on a committed, disposable copy of the real planning tree."""
    planning = root / ".planning"
    if not planning.is_dir():
        raise ContractError("SDK copy requires a complete .planning tree")
    r12_raw = read_bytes(root, R12_CONTRACT)
    if sha256(r12_raw) != R12_CONTRACT_SHA256:
        raise ContractError("the R12 disposition source bytes differ from their frozen pin")
    r12 = json.loads(r12_raw)
    targets = [row["plan"] for row in r12.get("responsibilities", [])]
    targets.extend(f"253-{number:02d}" for number in NEVER_RAN_IDS + (176, 177))
    disposition_ids = tuple(int(plan.removeprefix("253-")) for plan in targets)
    if len(disposition_ids) != 73 or len(set(disposition_ids)) != 73:
        raise ContractError("the frozen original71 plus176/177 disposition set is not73 unique plans")
    plan168 = read_bytes(root, f"{PHASE}/253-168-PLAN.md").decode("utf-8", "strict")
    if not re.search(r'(?m)^depends_on:\s*\["253-180"\]\s*$', plan168):
        raise ContractError("SDK copy input is not the actual amended168 plan depending on180")
    if "verify-receipt --consumer 168" not in plan168:
        raise ContractError("SDK copy input does not use the amended168 receipt consumer")
    for number in (176, 177):
        if (root / f"{PHASE}/253-{number}-SUMMARY.md").exists():
            raise ContractError(f"unexecuted {number} summary exists before SDK simulation")
    identity = sdk_identity()
    source_input_commit = git(root, "rev-parse", "HEAD").decode("ascii").strip()
    source_manifest = _git_manifest(root, source_input_commit)
    source_manifest_digest = sha256(canonical_json_bytes(source_manifest))
    _assert_sdk_source_binding(root, source_input_commit, source_manifest, require_current=True)

    with tempfile.TemporaryDirectory(prefix="sigra-253-sdk-copy-") as temp:
        project = Path(temp) / "project"
        project.mkdir()
        shutil.copytree(planning, project / ".planning", symlinks=False)
        phase_dir = project / PHASE
        copied_manifest = _filesystem_manifest(project)
        copied_manifest_expected = [{"path": row["path"], "bytes": row["bytes"], "sha256": row["sha256"]}
                                   for row in source_manifest]
        if copied_manifest != copied_manifest_expected:
            raise ContractError("temporary SDK copy inputs differ from the committed source manifest")
        original_summaries = {path.name: path.read_bytes() for path in phase_dir.glob("253-*-SUMMARY.md")}
        for number in (176, 177):
            if (phase_dir / f"253-{number}-SUMMARY.md").exists():
                raise ContractError(f"SDK copy input unexpectedly contains {number} summary")
        subprocess.run(["git", "-C", str(project), "init", "-q"], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(project), "config", "user.name", "SDK Fixture"], check=True)
        subprocess.run(["git", "-C", str(project), "config", "user.email", "sdk-fixture@example.test"], check=True)
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "committed SDK copy inputs"], check=True)
        copy_input_commit = git(project, "rev-parse", "HEAD").decode().strip()
        for number in (175, 178):
            summary = phase_dir / f"253-{number}-SUMMARY.md"
            if not summary.is_file() or not re.search(r"(?m)^status:\s*halted$", summary.read_text(encoding="utf-8")):
                raise ContractError(f"SDK copy must retain halted{number} summary bytes")
        for number in (179, 180, 181):
            summary = phase_dir / f"253-{number}-SUMMARY.md"
            if summary.exists():
                if not re.search(r"(?m)^status: complete$", summary.read_text(encoding="utf-8")):
                    raise ContractError(f"SDK copy refuses non-complete existing {number} summary")
            else:
                sdk_write_summary(project, number, "complete", "Temporary SDK readiness fixture; not project evidence.")
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "temporary 178-180 SDK readiness"], check=True)
        readiness, readiness_raw, readiness_init_meta = sdk_query(project, "init.execute-phase")
        index, index_raw, readiness_index_meta = sdk_query(project, "phase-plan-index")
        readiness_rows = validate_sdk_index_rows(index.get("plans"), readiness, "readiness")
        if readiness_rows["253-175"]["halted"] is not True or readiness_rows["253-178"]["halted"] is not True:
            raise ContractError("installed SDK copy does not retain halted175 and halted178")

        # Simulate ordinary168–172 completion plus the exact original71+176/177 disposition set.
        for number in disposition_ids:
            if number in HISTORICAL_HALT_IDS:
                raise ContractError(f"disposition list overlaps halted historical plan {number}")
            sdk_write_summary(project, number, "complete", "Temporary disposition from the exact73-target contract.")
        for number in (168, 169, 170, 171, 172):
            sdk_write_summary(project, number, "complete", "Temporary ordinary completion fixture; not project evidence.")
        for number in (*range(168, 173), 176, 177, 179, 180, 181):
            summary = phase_dir / f"253-{number:02d}-SUMMARY.md"
            if not summary.is_file() or not re.search(r"(?m)^status: complete$", summary.read_text(encoding="utf-8")):
                raise ContractError(f"SDK simulation summary must be complete for {number}")
        for name, raw in original_summaries.items():
            if (phase_dir / name).read_bytes() != raw:
                raise ContractError(f"SDK fixture overwrote an existing summary: {name}")
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "temporary 168-172 and73 disposition simulation"], check=True)
        simulation_commit = git(project, "rev-parse", "HEAD").decode().strip()
        final_init, final_init_raw, post_init_meta = sdk_query(project, "init.execute-phase")
        final_index, final_index_raw, post_index_meta = sdk_query(project, "phase-plan-index")
        final_rows_by_id = validate_sdk_index_rows(final_index.get("plans"), final_init, "final")
        final_rows = list(final_rows_by_id.values())
        incomplete = [row for row in final_rows if row.get("has_summary") is not True]
        halted = [row for row in final_rows if row.get("halted") is True]
        blocked = []
        for row in final_rows:
            summary = phase_dir / f"{row['id']}-SUMMARY.md"
            if summary.is_file() and re.search(r"(?m)^status:\s*blocked\s*$", summary.read_text(encoding="utf-8")):
                blocked.append(row["id"])
        halted_ids = sorted(row["id"] for row in halted)
        if len(incomplete) != 0 or halted_ids != sorted(f"253-{n:02d}" for n in HISTORICAL_HALT_IDS) or blocked:
            raise ContractError(f"installed SDK post-chain accounting differs: incomplete={len(incomplete)}, halted={halted_ids}, blocked={blocked}")
        for name, raw in original_summaries.items():
            if (phase_dir / name).read_bytes() != raw:
                raise ContractError(f"SDK fixture changed original summary bytes: {name}")
        if any(not (phase_dir / f"253-{n:02d}-SUMMARY.md").is_file() for n in (176, 177)):
            raise ContractError("SDK simulation omitted one of the explicitly retired176/177 dispositions")
        query_reports = {
            "readiness_init": {"arguments": ["init.execute-phase", "253"], **readiness_init_meta, "stdout": readiness_raw.decode("utf-8", "strict"), "stdout_sha256": sha256(readiness_raw)},
            "readiness_index": {"arguments": ["phase-plan-index", "253"], **readiness_index_meta, "stdout": index_raw.decode("utf-8", "strict"), "stdout_sha256": sha256(index_raw)},
            "post_init": {"arguments": ["init.execute-phase", "253"], **post_init_meta, "stdout": final_init_raw.decode("utf-8", "strict"), "stdout_sha256": sha256(final_init_raw)},
            "post_index": {"arguments": ["phase-plan-index", "253"], **post_index_meta, "stdout": final_index_raw.decode("utf-8", "strict"), "stdout_sha256": sha256(final_index_raw)},
        }
        report = {
            "status": "passed", "temporary_copy": True, "sdk_identity": identity,
            "source_input_commit": source_input_commit,
            "source_input_manifest": source_manifest,
            "source_input_manifest_sha256": source_manifest_digest,
            "source_manifest_exclusions": {"project_input": list(SDK_MANIFEST_EXCLUSIONS),
                                            "simulation_summaries": [f"{PHASE}/253-{n}-SUMMARY.md"
                                                                      for n in (168, 169, 170, 171, 172, 176, 177, 179, 180, 181)]},
            "sdk_copy_project_dir": str(project),
            "copy_input_commit": copy_input_commit, "source_copy_commit": simulation_commit,
            "simulation_commit": simulation_commit,
            "readiness_168_runnable": True, "readiness_175_halted": True,
            "pre_simulation_init_sha256": sha256(readiness_raw),
            "pre_simulation_index_sha256": sha256(index_raw),
            "post_chain_incomplete": len(incomplete), "post_chain_halted": len(halted),
            "post_chain_halted_ids": halted_ids, "post_chain_blocked_summaries": blocked,
            "post_chain_init_sha256": sha256(final_init_raw),
            "post_chain_index_sha256": sha256(final_index_raw),
            "preserved_summary_sha256": {name: sha256(raw) for name, raw in original_summaries.items()},
            "disposition_ids": [f"253-{number:02d}" for number in disposition_ids],
            "sdk_queries": query_reports,
        }
        validate_sdk_copy_report_data(root, report, verify_temporary_repo=True)
        return report

def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def validate_contract_limits(original: str, current: str, rel: str, root: Path) -> None:
    number = int(re.search(r"253-(168|169|170|171|172)-PLAN\.md$", rel).group(1))
    if current != expected_plan_amendment(original, number, root):
        raise ContractError(f"request/retry/time/page/size contract limits changed outside the exact amendment in {rel}")


def validate_scoped_plan_diff(original: str, current: str, rel: str, root: Path) -> None:
    number = int(re.search(r"253-(168|169|170|171|172)-PLAN\.md$", rel).group(1))
    expected = expected_plan_amendment(original, number, root)
    if current != expected:
        raise ContractError(f"unapproved plan instruction diff in {rel}: bytes do not equal the finite original-derived amendment")


def validate_sdk_copy_report_data(root: Path, report: object,
                                  verify_temporary_repo: bool = False) -> dict:
    if not isinstance(report, dict):
        raise ContractError("SDK-copy report root must be an object")
    if report.get("status") != "passed" or report.get("temporary_copy") is not True:
        raise ContractError("SDK-copy external report is not a passing labeled temporary copy")
    identity = sdk_identity()
    if report.get("sdk_identity") != identity:
        raise ContractError("SDK-copy report installed Node/GSD identity differs from actual files")
    project_dir = report.get("sdk_copy_project_dir")
    if not isinstance(project_dir, str) or not Path(project_dir).is_absolute():
        raise ContractError("SDK-copy report project directory is missing or not absolute")
    source_commit = report.get("source_input_commit")
    manifest = report.get("source_input_manifest")
    expected_manifest = _assert_sdk_source_binding(root, source_commit, manifest)
    manifest_hash = sha256(canonical_json_bytes(expected_manifest))
    if report.get("source_input_manifest_sha256") != manifest_hash:
        raise ContractError("SDK-copy source manifest digest differs from committed bytes")
    expected_exclusions = {"project_input": list(SDK_MANIFEST_EXCLUSIONS),
                           "simulation_summaries": [f"{PHASE}/253-{n}-SUMMARY.md"
                                                     for n in (168, 169, 170, 171, 172, 176, 177, 179, 180, 181)]}
    if report.get("source_manifest_exclusions") != expected_exclusions:
        raise ContractError("SDK-copy source manifest exclusions differ from the finite contract")

    queries = report.get("sdk_queries")
    query_names = {"readiness_init", "readiness_index", "post_init", "post_index"}
    if not isinstance(queries, dict) or set(queries) != query_names:
        raise ContractError("SDK-copy report lacks exactly four actual installed-SDK query outputs")
    parsed, raw_outputs = {}, {}
    command_by_name = {"readiness_init": "init.execute-phase",
                       "readiness_index": "phase-plan-index",
                       "post_init": "init.execute-phase",
                       "post_index": "phase-plan-index"}
    logical_args = {name: [command, "253"] for name, command in command_by_name.items()}
    node, sdk = identity["node"], identity["path"]
    for name in sorted(query_names):
        row = queries[name]
        if not isinstance(row, dict) or not isinstance(row.get("stdout"), str):
            raise ContractError(f"SDK-copy actual {name} output is missing")
        expected_argv = [node, sdk, "query", command_by_name[name], "253",
                         "--project-dir", project_dir, "--raw"]
        if row.get("arguments") != logical_args[name] or row.get("argv") != expected_argv:
            raise ContractError(f"SDK-copy actual {name} query arguments differ from the installed SDK command")
        if row.get("returncode") != 0:
            raise ContractError(f"SDK-copy actual {name} query did not exit successfully")
        try:
            raw = row["stdout"].encode("utf-8", "strict")
        except UnicodeEncodeError as error:
            raise ContractError(f"SDK-copy actual {name} stdout contains invalid UTF-8 text: {error}") from error
        if sha256(raw) != row.get("stdout_sha256"):
            raise ContractError(f"SDK-copy actual {name} raw stdout hash differs")
        try:
            parsed_row = json.loads(raw.decode("utf-8", "strict"))
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise ContractError(f"SDK-copy actual {name} stdout is not strict UTF-8 JSON: {error}") from error
        if not isinstance(parsed_row, dict):
            raise ContractError(f"SDK-copy actual {name} stdout root must be an object")
        parsed[name] = parsed_row
        raw_outputs[name] = raw

    readiness_rows = validate_sdk_index_rows(parsed["readiness_index"].get("plans"),
                                             parsed["readiness_init"], "readiness")
    final_rows = validate_sdk_index_rows(parsed["post_index"].get("plans"),
                                         parsed["post_init"], "final")
    expected_halted = sorted(f"253-{n:02d}" for n in HISTORICAL_HALT_IDS)
    halted_ids = sorted(plan_id for plan_id, row in final_rows.items() if row["halted"])
    blocked_summaries = report.get("post_chain_blocked_summaries")
    if blocked_summaries != []:
        raise ContractError("SDK-copy report records blocked summary statuses")
    # Reopen every existing summary from the committed input manifest. The only
    # synthetic summaries are the exact route/disposition set, each constrained
    # to complete status by run_sdk_copy.
    source_summary_paths = {row["path"] for row in expected_manifest
                            if re.fullmatch(rf"{re.escape(PHASE)}/253-[0-9]+-SUMMARY\.md", row["path"])}
    for rel in sorted(source_summary_paths):
        original = git(root, "show", f"{source_commit}:{rel}").decode("utf-8", "strict")
        if re.search(r"(?m)^status:\s*blocked\s*$", original):
            raise ContractError(f"SDK-copy committed source contains a blocked summary status: {rel}")
    simulated = expected_exclusions["simulation_summaries"]
    if any(rel in source_summary_paths for rel in simulated[:7]):
        raise ContractError("SDK-copy route must synthesize absent168-172 and176/177 summaries")
    for number in (179, 180, 181):
        rel = f"{PHASE}/253-{number}-SUMMARY.md"
        if rel in source_summary_paths:
            original = git(root, "show", f"{source_commit}:{rel}").decode("utf-8", "strict")
            if not re.search(r"(?m)^status:\s*complete$", original):
                raise ContractError(f"SDK-copy source contains a non-complete route summary: {rel}")
    if report.get("readiness_168_runnable") is not True or not readiness_rows["253-168"]["has_summary"] is False:
        raise ContractError("SDK-copy report readiness168 summary/runnable facts disagree with parsed SDK output")
    if report.get("readiness_175_halted") is not True or not readiness_rows["253-175"]["halted"] or not readiness_rows["253-178"]["halted"]:
        raise ContractError("SDK-copy report does not preserve halted175 and halted178 in parsed readiness output")
    if report.get("post_chain_incomplete") != parsed["post_init"].get("incomplete_count") or report.get("post_chain_incomplete") != 0:
        raise ContractError("SDK-copy report final incomplete count differs from parsed SDK output")
    if report.get("post_chain_halted") != len(halted_ids) or halted_ids != expected_halted:
        raise ContractError("SDK-copy report final halted count/IDs differ from parsed SDK output")
    if report.get("post_chain_halted_ids") != halted_ids:
        raise ContractError("SDK-copy report final halted IDs differ from parsed SDK output")
    redundant_hashes = {
        "pre_simulation_init_sha256": "readiness_init",
        "pre_simulation_index_sha256": "readiness_index",
        "post_chain_init_sha256": "post_init",
        "post_chain_index_sha256": "post_index",
    }
    for field, query_name in redundant_hashes.items():
        if report.get(field) != sha256(raw_outputs[query_name]):
            raise ContractError(f"SDK-copy report redundant {field} differs from raw query bytes")
    expected_targets = [row["plan"] for row in read_json(root, R12_CONTRACT)["responsibilities"]]
    expected_targets.extend(f"253-{n:02d}" for n in NEVER_RAN_IDS + (176, 177))
    if report.get("disposition_ids") != expected_targets:
        raise ContractError("SDK-copy report does not use the exact73 disposition targets")
    if report.get("copy_input_commit") is None or not re.fullmatch(r"[0-9a-f]{40}", str(report.get("copy_input_commit"))):
        raise ContractError("SDK-copy report lacks its temporary copy input commit identity")
    copy_commit = report["copy_input_commit"]
    simulation_commit = report.get("simulation_commit")
    source_copy_commit = report.get("source_copy_commit")
    if (not isinstance(simulation_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", simulation_commit) or
            not isinstance(source_copy_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", source_copy_commit) or
            simulation_commit != source_copy_commit or simulation_commit == copy_commit):
        raise ContractError("SDK-copy source/simulation commit identities are malformed or inconsistent")
    if verify_temporary_repo:
        temporary_project = Path(project_dir)
        if not temporary_project.is_dir():
            raise ContractError("SDK-copy temporary project disappeared before producer validation")
        for commit in (copy_commit, simulation_commit):
            git(temporary_project, "cat-file", "-e", f"{commit}^{{commit}}")
        ancestry = subprocess.run(["git", "-C", str(temporary_project), "merge-base", "--is-ancestor",
                                   copy_commit, simulation_commit], capture_output=True, check=False)
        if ancestry.returncode:
            raise ContractError("SDK-copy simulation commit does not descend from its copy-input commit")
    original_summaries = report.get("preserved_summary_sha256")
    if not isinstance(original_summaries, dict):
        raise ContractError("SDK-copy report lacks preserved existing summary hashes")
    source_summaries = {Path(row["path"]).name: row["sha256"] for row in expected_manifest
                        if row["path"].startswith(PHASE + "/253-") and
                        row["path"].endswith("-SUMMARY.md")}
    if original_summaries != source_summaries:
        raise ContractError("SDK-copy report did not preserve every existing summary byte hash")
    return report


def validate_sdk_copy_report(root: Path, evidence: dict) -> dict:
    report_path = evidence.get("report_path")
    report_hash = evidence.get("report_sha256")
    if not isinstance(report_path, str) or not Path(report_path).is_absolute():
        raise ContractError("SDK-copy evidence must point to an absolute external report")
    path = Path(report_path).resolve()
    if path == root.resolve() or root.resolve() in path.parents:
        raise ContractError("SDK-copy report must remain outside the project checkout")
    raw = read_bytes(path.parent, path.name)
    if sha256(raw) != report_hash:
        raise ContractError("SDK-copy external report hash differs")
    try:
        report = json.loads(raw)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ContractError(f"SDK-copy external report is invalid JSON: {error}") from error
    return validate_sdk_copy_report_data(root, report)


def validate_bridge(root: Path, stage: str, record_path: str, sdk: bool = False) -> dict:
    root = root.resolve()
    record = read_json(root, record_path)
    if record.get("schema") != BRIDGE_SCHEMA:
        raise ContractError("bridge record schema invalid")
    if stage not in ("entry", "complete"):
        raise ContractError("bridge stage must be entry or complete")
    if record.get("stage") != stage and not (stage == "entry" and record.get("stage") == "complete"):
        raise ContractError("bridge record stage does not satisfy requested stage")
    originals = record.get("originals")
    original_plan_ids = (168, 169, 170, 171, 172, 176, 177)
    if not isinstance(originals, dict) or set(originals) != {f"{PHASE}/253-{n}-PLAN.md" for n in original_plan_ids}:
        raise ContractError("bridge must bind exactly the original168–172/176/177 plans")
    ref = record.get("preservation_ref")
    if ref != ORIGINALS_180:
        raise ContractError("bridge preservation ref is not the scoped180 durable ref")
    source_commit = record.get("source_commit")
    if not re.fullmatch(r"[0-9a-f]{40}", str(source_commit)):
        raise ContractError("bridge source commit invalid")
    source_paths = set()
    rows = git(root, "ls-tree", "-rz", "-r", source_commit, "--", PHASE, ".planning/phases/252-measure-current-ci")
    for row in rows.split(b"\0"):
        if row:
            source_paths.add(row.split(b"\t", 1)[1].decode("utf-8", "strict"))
    protected = record.get("protected_source_bindings")
    if not isinstance(protected, dict) or set(protected) != source_paths:
        raise ContractError("bridge must bind every original Phase253/252 path from its source commit")
    all_plan_paths = {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)}
    entry_plan_paths = {f"{PHASE}/253-{n}-PLAN.md" for n in (168, 169)}
    allowed_plan_changes = all_plan_paths if stage == "complete" else entry_plan_paths
    amended = record.get("amended_sha256")
    if not isinstance(amended, dict) or set(amended) != allowed_plan_changes:
        raise ContractError(f"{stage} bridge must scope exactly {len(allowed_plan_changes)} amended plans")
    for rel in sorted(source_paths):
        source_bytes = git(root, "show", f"{source_commit}:{rel}")
        if sha256(source_bytes) != protected[rel]:
            raise ContractError(f"bridge protected-source hash differs at source: {rel}")
        current = root / rel
        if not current.exists():
            raise ContractError(f"bridge protected source path is missing: {rel}")
        current_hash = sha256(read_source_bytes(root, rel))
        if rel in allowed_plan_changes:
            if current_hash != amended.get(rel):
                raise ContractError(f"bridge amendment hash differs: {rel}")
            original_text = git(root, "show", f"{ref}:{rel}").decode("utf-8", "strict")
            current_text = read_source_bytes(root, rel).decode("utf-8", "strict")
            if rel == f"{PHASE}/253-168-PLAN.md":
                validate_168_receipt_placement(current_text)
            if rel == f"{PHASE}/253-169-PLAN.md":
                validate_169_executable_contract(current_text, root)
                validate_169_owner_contract(current_text, original_text, root)
            validate_contract_limits(original_text, current_text, rel, root)
            validate_scoped_plan_diff(original_text, current_text, rel, root)
        elif current_hash != protected[rel]:
            raise ContractError(f"unapproved protected file changed during bridge: {rel}")
    for rel, pin in originals.items():
        if not isinstance(pin, dict) or set(pin) != {"blob", "sha256", "bytes"}:
            raise ContractError(f"original binding malformed: {rel}")
        original = git(root, "show", f"{ref}:{rel}")
        if len(original) != pin["bytes"] or sha256(original) != pin["sha256"]:
            raise ContractError(f"durable original readback differs: {rel}")
        blob = git(root, "hash-object", "--stdin", input_bytes=original).decode().strip()
        if blob != pin["blob"]:
            raise ContractError(f"durable original blob differs: {rel}")
        if git(root, "show", f"{source_commit}:{rel}") != original:
            raise ContractError(f"durable original does not match the receipt source: {rel}")
        current = read_bytes(root, rel)
        if rel in allowed_plan_changes and sha256(current) != amended.get(rel):
            raise ContractError(f"current amendment hash differs: {rel}")
    p168 = read_bytes(root, f"{PHASE}/253-168-PLAN.md").decode()
    p169 = read_bytes(root, f"{PHASE}/253-169-PLAN.md").decode()
    p170 = read_bytes(root, f"{PHASE}/253-170-PLAN.md").decode()
    p171 = read_bytes(root, f"{PHASE}/253-171-PLAN.md").decode()
    p172 = read_bytes(root, f"{PHASE}/253-172-PLAN.md").decode()
    original_files = {rel: git(root, "show", f"{ref}:{rel}").decode("utf-8", "strict") for rel in originals}
    unchanged_plan_ids = (170, 171, 176, 177) if stage == "entry" else (176, 177)
    for number in unchanged_plan_ids:
        rel = f"{PHASE}/253-{number}-PLAN.md"
        if read_bytes(root, rel) != original_files[rel].encode("utf-8"):
            raise ContractError(f"unapproved original plan changed: {rel}")
    validate_169_executable_contract(p169, root)
    if 'depends_on: ["253-180"]' not in p168 or "verify-receipt --consumer 168" not in p168:
        raise ContractError("168 does not consume179 after180")
    if "253-174-RECOVERY-RECEIPT.json" in p168 or "253-176-RECOVERY-RECEIPT.json" in p168:
        raise ContractError("168 still depends on a failed or retired receipt")
    if "253-174-RECOVERY-SUCCESSOR.py" in p168 or "--consumer 174" in p168:
        raise ContractError("168 still invokes the failed174 verifier path")
    if re.search(r"(?i)(?:unstarted|targets)\s*[:=]?\s*73\b|\b73\s+(?:unstarted|targets)", p169) is None:
        raise ContractError("169 does not document exactly73 disposition targets")
    if "253-174-RECOVERY-RECEIPT.json" in p169 or "253-176-RECOVERY-RECEIPT.json" in p169:
        raise ContractError("169 still references a failed or retired receipt")
    for required in ("253-180", "253-179", "24", "73", "253-175", "verify-receipt",
                     "253-175-PLAN.md", "253-175-SUMMARY.md", "253-175-REPAIR-REVIEW.json",
                     "253-175-EXECUTION-RECORD.json"):
        if required not in p169:
            raise ContractError(f"169 is missing required bridge/pin field {required}")
    if stage == "complete":
        for rel, current in ((f"{PHASE}/253-170-PLAN.md", p170), (f"{PHASE}/253-171-PLAN.md", p171)):
            old = git(root, "show", f"{ref}:{rel}").decode("utf-8")
            old_bodies = re.findall(r"<automated>(.*?)</automated>", old, re.S)
            new_bodies = re.findall(r"<automated>(.*?)</automated>", current, re.S)
            if old_bodies != new_bodies:
                raise ContractError(f"hosted command bodies changed in {rel}")
            old_tasks = re.findall(r"<task\b.*?</task>", old, re.S)
            new_tasks = re.findall(r"<task\b.*?</task>", current, re.S)
            if old_tasks != new_tasks:
                raise ContractError(f"approval/operator/checkpoint task contract changed in {rel}")
        old172 = git(root, "show", f"{ref}:{PHASE}/253-172-PLAN.md").decode("utf-8")
        completion_links = re.findall(r"(?m)^\s*-\s+([a-z0-9_]+)\s*=\s*([^;\n]+)", old172)
        current_links = re.findall(r"(?m)^\s*-\s+([a-z0-9_]+)\s*=\s*([^;\n]+)", p172)
        if len(completion_links) != 8 or current_links != completion_links:
            raise ContractError("172's eight hosted/native completion links changed")
        if "verify-receipt --consumer 168" not in p172 or "253-174-RECOVERY-RECEIPT.json" in p172:
            raise ContractError("172 does not use the179 local verifier contract")
        if "253-174-RECOVERY-SUCCESSOR.py" in p172:
            raise ContractError("172 retains a stale174 verifier")
        if "verify-receipt --consumer 168" not in p172:
            raise ContractError("172 does not verify the179 receipt before bundle consumers")
    if record.get("dispositions_for") not in ([], None):
        raise ContractError("bridge record may not disposition historical halted or recovery plans")
    sdk_copy = None
    if stage == "complete":
        evidence = record.get("sdk_copy")
        if not isinstance(evidence, dict):
            raise ContractError("complete bridge requires externally retained installed-SDK query evidence")
        if sdk:
            sdk_copy = run_sdk_copy(root, record, record_path)
        else:
            sdk_copy = validate_sdk_copy_report(root, evidence)
    return {"status": "verified", "stage": stage, "plans": 5,
            **({"sdk_copy": sdk_copy} if sdk_copy is not None else {})}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    sub = parser.add_subparsers(dest="command", required=True)
    prep = sub.add_parser("prepare")
    prep.add_argument("--attempt-dir", type=Path, required=True)
    ent = sub.add_parser("enter")
    ent.add_argument("--attempt-dir", type=Path, required=True)
    wr = sub.add_parser("write-receipt")
    wr.add_argument("--attempt-dir", type=Path, required=True)
    ver = sub.add_parser("verify-receipt")
    ver.add_argument("--consumer", choices=("168",))
    bridge = sub.add_parser("verify-bridge")
    bridge.add_argument("--stage", choices=("entry", "complete"), required=True)
    bridge.add_argument("--record", required=True)
    bridge.add_argument("--sdk", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        if args.command == "prepare":
            result = prepare(root, args.attempt_dir)
            print(json.dumps(result, sort_keys=True))
        elif args.command == "enter":
            enter(root, args.attempt_dir)
            print("179 attempt marker created; launch acceptance.sh once in the authorized root shell")
        elif args.command == "write-receipt":
            result = write_receipt(root, args.attempt_dir)
            print(json.dumps({"status": result["status"], "receipt": RECEIPT_179}, sort_keys=True))
        elif args.command == "verify-receipt":
            result = verify_receipt(root, args.consumer)
            print("253-179 successor receipt verified; 167/173/174/175 remain halted; CIREL-01 partial_not_reproduced; CIREL-02 unaccepted; full verification not_started")
            print(json.dumps(result, sort_keys=True))
        else:
            result = validate_bridge(root, args.stage, args.record, args.sdk)
            print(json.dumps(result, sort_keys=True))
        return 0
    except (ContractError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"successor contract refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
