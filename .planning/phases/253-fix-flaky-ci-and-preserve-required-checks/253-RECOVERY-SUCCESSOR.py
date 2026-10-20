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
REVIEW_173 = f"{PHASE}/253-173-RECOVERY-REVIEW.json"
REVIEW_175 = f"{PHASE}/253-175-REPAIR-REVIEW.json"
RECEIPT_176 = f"{PHASE}/253-176-RECOVERY-RECEIPT.json"
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
    transformed = transformed.replace("253-174", "253-176")

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
    if log173.splitlines()[-1] != "VERIFY-EXIT 1":
        raise ContractError("173's original failure sentinel changed")
    if (root / f"{PHASE}/253-173-RECOVERY-RECEIPT.json").exists() or (root / f"{PHASE}/253-174-RECOVERY-RECEIPT.json").exists():
        raise ContractError("old 173/174 success receipt must remain absent")
    return {"review173_sha256": sha256(raw_review173), "findings": len(review173["findings"]),
            "historical_sha256": HISTORICAL_SHA256,
            "174_log_sha256": sha256(log174), "174_status": "halted", "174_exit": 1,
            "173_status": "halted", "173_exit": 1, "167_status": "halted"}


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
    summary175 = read_bytes(root, f"{PHASE}/253-175-SUMMARY.md").decode("utf-8")
    if not re.search(r"^status: complete$", summary175, re.M):
        raise ContractError("175 must be complete before preparation")
    review175 = read_json(root, REVIEW_175)
    if review175.get("schema") != REVIEW_SCHEMA or review175.get("status") != "reviewed_for_new_acceptance":
        raise ContractError("175 repair review schema/status is invalid")
    if review175.get("unresolved_implementation_findings") != []:
        raise ContractError("175 repair review has unresolved findings")
    if review175.get("scope") != {"product_changes": ["scripts/ci/ci-git-publication.test.py"],
                                   "github_requests": 0, "native_browser_launches": 0}:
        raise ContractError("175 review product scope differs from the one test repair")
    reviewed_files = review175.get("source_files")
    required_reviewed_files = {"scripts/ci/ci-git-publication.test.py", PLAN_175,
                               f"{PHASE}/253-RECOVERY-SUCCESSOR.py",
                               f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
                               "scripts/ci/ci-git-publication.py", "scripts/ci/ci-gate-canary-dryrun.py"}
    if not isinstance(reviewed_files, dict) or set(reviewed_files) != required_reviewed_files:
        raise ContractError("175 review does not bind the exact changed/tooling source files")
    for rel, digest in reviewed_files.items():
        if sha256(read_bytes(root, rel)) != digest:
            raise ContractError(f"175 review source hash differs: {rel}")
    commits = review175.get("source_commits")
    if not isinstance(commits, dict) or set(commits) == set():
        raise ContractError("175 review lacks source commit identities")
    if set(commits) != required_reviewed_files:
        raise ContractError("175 review commit identities do not cover exactly the source files")
    for rel in required_reviewed_files:
        commit = commits.get(rel)
        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ContractError(f"175 review commit identity missing: {rel}")
        if git(root, "show", f"{commit}:{rel}") != read_bytes(root, rel):
            raise ContractError(f"175 review commit does not contain exact source bytes: {rel}")
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
    if any((root / f"{PHASE}/253-176-{name}").exists() for name in
           ("PERMISSION-PREFLIGHT.json", "REGRESSION.log", "RECOVERY-RECEIPT.json", "SUMMARY.md")):
        raise ContractError("176 attempt artifacts already exist")
    source174 = read_bytes(root, PLAN_174)
    body174 = command_body(source174, PLAN_174)
    generated, transformations = expected_acceptance_body(body174)
    source176 = read_bytes(root, PLAN_176)
    body176 = command_body(source176, PLAN_176)
    body176_hash = sha256(body176.encode("utf-8"))
    bindings = original_bindings(root)
    shared = {rel: sha256(read_bytes(root, rel)) for rel in SHARED}
    prepared = {
        "schema": "sigra.phase253.successor-prepared/v1",
        "source_commit": bindings["source_commit"],
        "plan174_body_sha256": sha256(body174.encode("utf-8")),
        "plan176_body_sha256": body176_hash,
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
    if launch.get("block_sha256") != prepared.get("plan176_body_sha256"):
        raise ContractError("root launch did not bind the exact176 automated body")
    if not isinstance(launch.get("tool_call_id"), str) or not launch["tool_call_id"].strip() or not launch.get("session_id"):
        raise ContractError("actual tool call/session identity is missing")
    if launch.get("generated_script_sha256") != prepared.get("generated_script_sha256"):
        raise ContractError("launch record generated-script hash differs")
    if preflight.get("generated_script_sha256") != prepared.get("generated_script_sha256"):
        raise ContractError("preflight generated script hash differs")
    if preflight.get("plan_command_sha256") != prepared.get("plan176_body_sha256"):
        raise ContractError("preflight exact plan-command hash differs")
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
    log = read_bytes(attempt_dir, "253-176-REGRESSION.log")
    preflight = read_json(attempt_dir, "253-176-PERMISSION-PREFLIGHT.json")
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
        "recovery_plan": "253-176",
        "repair_plan": "253-175",
        "bridge_plan": "253-177",
        "attempt_count": 1,
        "next_plan": "253-177",
        "source_commit": source,
        "plan_command_sha256": prepared["plan176_body_sha256"],
        "generated_script_sha256": prepared["generated_script_sha256"],
        "historical": history,
        "historical_sha256": {rel: row["sha256"] for rel, row in prepared["source_bindings"].items()},
        "shared_sha256": prepared["shared_sha256"],
        "review": {"path": REVIEW_173, "sha256": REVIEW_173_SHA256},
        "repair_review": {"path": REVIEW_175, "sha256": sha256(read_bytes(root, REVIEW_175))},
        "permission_preflight": {"path": f"{PHASE}/253-176-PERMISSION-PREFLIGHT.json", "sha256": sha256(read_bytes(attempt_dir, "253-176-PERMISSION-PREFLIGHT.json"))},
        "regression_log": {"path": f"{PHASE}/253-176-REGRESSION.log", "sha256": sha256(log)},
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
    target = root / RECEIPT_176
    if target.exists():
        raise ContractError("176 receipt already exists")
    target.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return receipt


def verify_receipt(root: Path, consumer: str | None = None) -> dict:
    root = root.resolve()
    receipt = read_json(root, RECEIPT_176)
    if receipt.get("schema") != SUCCESSOR_SCHEMA or receipt.get("status") != "verified_local_success":
        raise ContractError("176 successor receipt schema/status invalid")
    for rel, field in ((REVIEW_173, "review"), (REVIEW_175, "repair_review"),
                       (f"{PHASE}/253-176-PERMISSION-PREFLIGHT.json", "permission_preflight"),
                       (f"{PHASE}/253-176-REGRESSION.log", "regression_log")):
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
    repair_review = read_json(root, REVIEW_175)
    if repair_review.get("schema") != REVIEW_SCHEMA or repair_review.get("status") != "reviewed_for_new_acceptance":
        raise ContractError("175 repair review schema/status is invalid")
    if repair_review.get("unresolved_implementation_findings") != []:
        raise ContractError("175 repair review has unresolved implementation findings")
    if repair_review.get("scope") != {"product_changes": ["scripts/ci/ci-git-publication.test.py"],
                                      "github_requests": 0, "native_browser_launches": 0}:
        raise ContractError("175 repair review product scope is invalid")
    reviewed_files = repair_review.get("source_files")
    reviewed_commits = repair_review.get("source_commits")
    required_review_files = {"scripts/ci/ci-git-publication.test.py", PLAN_175,
                             f"{PHASE}/253-RECOVERY-SUCCESSOR.py",
                             f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
                             "scripts/ci/ci-git-publication.py", "scripts/ci/ci-gate-canary-dryrun.py"}
    if not isinstance(reviewed_files, dict) or set(reviewed_files) != required_review_files:
        raise ContractError("175 repair review does not bind the exact reviewed source set")
    if not isinstance(reviewed_commits, dict) or set(reviewed_commits) != required_review_files:
        raise ContractError("175 repair review does not bind each reviewed commit")
    for rel in required_review_files:
        if sha256(read_bytes(root, rel)) != reviewed_files[rel]:
            raise ContractError(f"175 review source hash mismatch: {rel}")
        commit = reviewed_commits[rel]
        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ContractError(f"175 review commit identity is invalid: {rel}")
        if git(root, "show", f"{commit}:{rel}") != read_bytes(root, rel):
            raise ContractError(f"175 review commit does not contain reviewed bytes: {rel}")
    parsed = parse_log(bound_file(root, receipt["regression_log"], "regression log"))
    preflight = read_json(root, receipt["permission_preflight"]["path"])
    body174 = command_body(read_bytes(root, PLAN_174), PLAN_174)
    generated, _ = expected_acceptance_body(body174)
    body176 = command_body(read_bytes(root, PLAN_176), PLAN_176)
    if sha256(body176.encode()) != receipt.get("plan_command_sha256"):
        raise ContractError("receipt plan command hash is not the exact176 first body")
    if sha256(generated.encode()) != receipt.get("generated_script_sha256"):
        raise ContractError("receipt generated script hash is not the reviewed174 transformation")
    prepared = {"source_commit": receipt.get("source_commit"),
                "plan176_body_sha256": receipt.get("plan_command_sha256"),
                "generated_script_sha256": receipt.get("generated_script_sha256"),
                "shared_sha256": receipt.get("shared_sha256", {}),
                "source_bindings": {rel: {"sha256": value} for rel, value in receipt.get("historical_sha256", {}).items()}}
    validate_preflight(root, preflight, parsed, prepared, root)
    validate_probe_object(root, preflight["probe"])
    if receipt.get("recovery_plan") != "253-176" or receipt.get("repair_plan") != "253-175" or receipt.get("bridge_plan") != "253-177":
        raise ContractError("receipt plan lineage is incorrect")
    if receipt.get("attempt_count") != 1 or receipt.get("next_plan") != "253-177":
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
        bridge_rel = f"{PHASE}/253-177-BRIDGE-RECORD.json"
        bridge_file = root / bridge_rel
        if changed_originals and not bridge_file.exists():
            raise ContractError("168 consumer requires the177 durable bridge record after plan amendments")
        if bridge_file.exists():
            bridge_record = read_json(root, bridge_rel)
            if bridge_record.get("source_commit") != source:
                raise ContractError("177 bridge source commit differs from the176 receipt")
            validate_bridge(root, bridge_record.get("stage"), bridge_rel)
            allowed = ({f"{PHASE}/253-{n}-PLAN.md" for n in (168, 169)}
                       if bridge_record.get("stage") == "entry"
                       else {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)})
            if set(bridge_record.get("amended_sha256", {})) != allowed:
                raise ContractError("177 bridge does not scope exactly the active-stage plan amendments")
    if clean_status(root):
        raise ContractError("receipt verification requires a clean committed tree")
    return {"status": "verified", "source_commit": source, "count": parsed["count"]}


def sdk_query(project: Path, command: str, phase: str = "253") -> tuple[dict, bytes]:
    sdk = Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs"
    node = Path.home() / ".asdf/installs/nodejs/20.18.1/bin/node"
    if not sdk.is_file() or not node.is_file():
        raise ContractError("installed GSD SDK or pinned Node runtime is unavailable")
    result = subprocess.run([str(node), str(sdk), "query", command, phase,
                             "--project-dir", str(project), "--raw"],
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
    return value, result.stdout


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


HISTORICAL_HALT_IDS = (2, 7, 9, 12, 16, 27, 40, 51, 63, 73, 84, 92, 97,
                       104, 113, 122, 134, 143, 146, 155, 167, 173, 174)
NEVER_RAN_IDS = (144, 145, *range(147, 155), *range(156, 164))


def run_sdk_copy(root: Path, record: dict, record_path: str) -> dict:
    """Run the installed GSD queries against a separately committed planning copy."""
    planning = root / ".planning"
    if not planning.is_dir():
        raise ContractError("SDK copy requires a complete .planning tree")
    r12_raw = read_bytes(root, R12_CONTRACT)
    if sha256(r12_raw) != R12_CONTRACT_SHA256:
        raise ContractError("the R12 disposition source bytes differ from their frozen pin")
    r12 = json.loads(r12_raw)
    if len(r12.get("responsibilities", [])) != 53:
        raise ContractError("frozen R12 contract does not contain exactly53 original targets")
    try:
        disposition_ids = tuple(int(row["plan"].removeprefix("253-"))
                                for row in r12["responsibilities"]) + NEVER_RAN_IDS
    except (KeyError, TypeError, ValueError) as error:
        raise ContractError(f"frozen R12 target list is malformed: {error}") from error
    if len(disposition_ids) != 71 or len(set(disposition_ids)) != 71:
        raise ContractError("the exact R12 plus18-target disposition fixture is not71 unique plans")
    with tempfile.TemporaryDirectory(prefix="sigra-253-sdk-copy-") as temp:
        project = Path(temp) / "project"
        project.mkdir()
        shutil.copytree(planning, project / ".planning", symlinks=False)
        phase_dir = project / PHASE
        original_summaries = {p.name: p.read_bytes() for p in phase_dir.glob("253-*-SUMMARY.md")}
        for number in (175, 176, 177):
            sdk_write_summary(project, number, "complete", "Temporary readiness fixture; not project evidence.")
        plan168 = phase_dir / "253-168-PLAN.md"
        plan168_text = plan168.read_text(encoding="utf-8")
        if not re.search(r'(?m)^depends_on:\s*\["253-177"\]\s*$', plan168_text):
            raise ContractError("SDK copy input is not the actual amended168 plan depending on177")
        if "verify-receipt --consumer 168" not in plan168_text:
            raise ContractError("SDK copy input does not use the amended168 receipt consumer")
        # First committed snapshot proves the next active plan is runnable and174 stays halted.
        subprocess.run(["git", "-C", str(project), "init", "-q"], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(project), "config", "user.name", "SDK Fixture"], check=True)
        subprocess.run(["git", "-C", str(project), "config", "user.email", "sdk-fixture@example.test"], check=True)
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "simulated completed 175-177"], check=True)
        readiness, readiness_raw = sdk_query(project, "init.execute-phase")
        index, index_raw = sdk_query(project, "phase-plan-index")
        plans = {str(row.get("id")): row for row in index.get("plans", []) if isinstance(row, dict)}
        row168 = plans.get("253-168")
        row174 = plans.get("253-174")
        if not isinstance(row168, dict) or row168.get("halted") is not False or row168.get("blocked_by") != []:
            raise ContractError("real SDK copy does not show168 runnable after completed177")
        if not isinstance(row174, dict) or row174.get("halted") is not True:
            raise ContractError("real SDK copy does not retain174 halted")
        init_runnable = readiness.get("runnable_plans")
        if not isinstance(init_runnable, list) or "253-168-PLAN.md" not in init_runnable:
            raise ContractError("init.execute-phase does not select168 as runnable after177")

        # Apply only the explicitly listed71 dispositions and ordinary168-172 summaries.
        # Preserve the literal historical halted set, now including174.
        for number in disposition_ids:
            if number in HISTORICAL_HALT_IDS:
                raise ContractError(f"disposition list overlaps halted historical plan {number}")
            sdk_write_summary(project, number, "complete", "Simulated disposition from the same71-target contract.")
        for number in (168, 169, 170, 171, 172):
            sdk_write_summary(project, number, "complete", "Temporary ordinary completion fixture; not project evidence.")
        sdk_write_summary(project, 174, "halted", "Retained literal historical halt fixture.")
        for name, raw in original_summaries.items():
            if (phase_dir / name).read_bytes() != raw:
                raise ContractError(f"SDK fixture overwrote an existing summary: {name}")
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "simulated 169-172 and71 dispositions"], check=True)
        final_init, final_init_raw = sdk_query(project, "init.execute-phase")
        final_index, final_index_raw = sdk_query(project, "phase-plan-index")
        final_rows = [row for row in final_index.get("plans", []) if isinstance(row, dict)]
        incomplete = [row for row in final_rows if row.get("has_summary") is not True]
        halted = [row for row in final_rows if row.get("halted") is True]
        blocked_summaries = []
        for row in final_rows:
            if row.get("has_summary"):
                rel = phase_dir / f"{row['id']}-SUMMARY.md"
                if rel.is_file() and re.search(r"(?m)^status:\s*blocked\s*$", rel.read_text(encoding="utf-8")):
                    blocked_summaries.append(row["id"])
        if len(incomplete) != 0 or len(halted) != 23 or blocked_summaries:
            raise ContractError(f"real SDK copy final accounting differs: incomplete={len(incomplete)}, "
                                f"halted={len(halted)}, blocked={blocked_summaries}")
        if final_init.get("incomplete_count") != 0 or final_init.get("incomplete_plans") != []:
            raise ContractError("init.execute-phase disagrees with zero incomplete plans")
        if len(HISTORICAL_HALT_IDS) != 23:
            raise ContractError("historical halted fixture does not contain exactly23 IDs")
        final_plan_rows = {str(row.get("id")): row for row in final_rows}
        if set(row["id"] for row in halted) != {f"253-{number:02d}" for number in HISTORICAL_HALT_IDS}:
            raise ContractError("SDK copy halted IDs differ from the exact23-plan set")
        return {
            "status": "passed",
            "sdk": str(Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs"),
            "sdk_sha256": sha256((Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs").read_bytes()),
            "node": str(Path.home() / ".asdf/installs/nodejs/20.18.1/bin/node"),
            "source_copy_commit": git(project, "rev-parse", "HEAD").decode().strip(),
            "source_snapshot_sha256": sha256(canonical_json_bytes({p.relative_to(project).as_posix(): sha256(p.read_bytes())
                                      for p in sorted((project / ".planning").rglob("*")) if p.is_file()})),
            "readiness_168_runnable": True,
            "readiness_174_halted": True,
            "pre_simulation_init_sha256": sha256(readiness_raw),
            "pre_simulation_index_sha256": sha256(index_raw),
            "post_chain_incomplete": 0,
            "post_chain_halted": 23,
            "post_chain_halted_ids": sorted(row["id"] for row in halted),
            "post_chain_blocked_summaries": [],
            "post_chain_init_sha256": sha256(final_init_raw),
            "post_chain_index_sha256": sha256(final_index_raw),
            "preserved_summary_sha256": {name: sha256(raw) for name, raw in original_summaries.items()},
            "disposition_ids": [f"253-{number:02d}" for number in disposition_ids],
            "temporary_copy": True,
        }


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def validate_contract_limits(original: str, current: str, rel: str) -> None:
    """Keep request, retry, time, paging and size constraints byte-identical."""
    pattern = re.compile(r"(?i)(?:cap|ceiling|limit|budget|request|retry|target|at most|no more than|maximum|page|attempt|deadline|margin|bytes)")
    if rel == f"{PHASE}/253-168-PLAN.md":
        # The sole executable replacement in the first body is the old nested
        # 174 receipt command becoming the shared 168 consumer command.
        nested = re.compile(r"python3 -c 'import os,pathlib,re,subprocess; p=pathlib\.Path\(\"[^\"]*253-174-PLAN\.md\"\);.*?\|\| exit \$\?; ?")
        consumer = re.compile(r"python3 \.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR\.py verify-receipt --consumer 168 \|\| exit \$\?; ?")
        original = nested.sub("<RECEIPT-CONSUMER> ", original, count=1)
        current = consumer.sub("<RECEIPT-CONSUMER> ", current, count=1)
        current = current.replace("253-176-RECOVERY-RECEIPT.json", "253-174-RECOVERY-RECEIPT.json")
        current = current.replace("\nverify-receipt --consumer 168\n", "\n")
    if rel in {f"{PHASE}/253-169-PLAN.md", f"{PHASE}/253-172-PLAN.md"}:
        current = current.replace("Twenty-three halted", "Twenty-two halted").replace("23 halted", "22 halted")
    old_rows = [line.strip() for line in original.splitlines() if pattern.search(line)]
    new_rows = [line.strip() for line in current.splitlines() if pattern.search(line)]
    if old_rows != new_rows:
        raise ContractError(f"request/retry/time/page/size contract lines changed in {rel}")


def validate_scoped_plan_diff(original: str, current: str, rel: str) -> None:
    """Reject edits outside the explicit recovery-routing sections of each PLAN."""
    number = int(re.search(r"253-(168|169|170|171|172)-PLAN\.md$", rel).group(1))
    allowed = {
        168: re.compile(r"(?i)(?:wave:|depends_on:|253-(?:167|168|169|173|174|175|176|177)|halted|receipt|recovery|acceptance|review|verify-receipt)"),
        169: re.compile(r"(?i)(?:wave:|depends_on:|253-(?:167|168|169|173|174|175|176|177)|halted|receipt|recovery|acceptance|review|owner|disposition|partition|never-ran|target|pin|complete)"),
        170: re.compile(r"(?i)(?:wave:|253-(?:168|169|170|171|172|174|175|176|177)|halted|receipt|recovery|preserv|summary)"),
        171: re.compile(r"(?i)(?:wave:|253-(?:168|169|170|171|172|174|175|176|177)|halted|receipt|recovery|preserv|summary)"),
        172: re.compile(r"(?i)(?:wave:|depends_on:|253-(?:167|168|169|170|171|172|173|174|175|176|177)|halted|receipt|recovery|owner|disposition|partition|target|pin|complete|verify-receipt)"),
    }[number]
    for line in difflib.unified_diff(original.splitlines(), current.splitlines(), lineterm=""):
        if line.startswith(("---", "+++", "@@")):
            continue
        if line.startswith(("-", "+")) and line[1:].strip() and not allowed.search(line[1:]):
            raise ContractError(f"unapproved plan instruction diff in {rel}: {line[:180]}")


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
    if not isinstance(originals, dict) or set(originals) != {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)}:
        raise ContractError("bridge must bind the original168–172 plans")
    ref = record.get("preservation_ref")
    if ref != "refs/gsd/phase253-successor-177-plan-originals":
        raise ContractError("bridge preservation ref is not the scoped durable ref")
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
            validate_contract_limits(git(root, "show", f"{ref}:{rel}").decode("utf-8"),
                                     read_source_bytes(root, rel).decode("utf-8"), rel)
            validate_scoped_plan_diff(git(root, "show", f"{ref}:{rel}").decode("utf-8"),
                                      read_source_bytes(root, rel).decode("utf-8"), rel)
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
    if "depends_on: [\"253-177\"]" not in p168 or "verify-receipt --consumer 168" not in p168:
        raise ContractError("168 does not consume176 after177")
    if "253-174-RECOVERY-RECEIPT.json" in p168 or "verify-receipt" not in p168:
        raise ContractError("168 still depends on the failed174 receipt")
    if "253-174-RECOVERY-SUCCESSOR.py" in p168 or "--consumer 174" in p168:
        raise ContractError("168 still invokes the failed174 verifier path")
    if re.search(r"(?i)(?:halted|halts)\s*[:=]?\s*22\b|\b22\s+(?:halted|halts)\b", p169):
        raise ContractError("169 retains the stale22-halt accounting")
    if re.search(r"(?i)(?:halted|halts)\s*[:=]?\s*23\b|\b23\s+(?:halted|halts)\b", p169) is None:
        raise ContractError("169 does not assert all23 halted plans")
    if re.search(r"(?i)(?:unstarted|targets)\s*[:=]?\s*71\b|\b71\s+(?:unstarted|targets)", p169) is None:
        raise ContractError("169 does not retain the same71 disposition targets")
    if "253-174-RECOVERY-RECEIPT.json" in p169 or "owner 253-174" in p169:
        raise ContractError("169 still assigns recovery ownership to the failed174 result")
    for required in ("253-177", "253-176", "23", "71", "253-174", "verify-receipt",
                     "253-174-PLAN.md", "253-174-SUMMARY.md", "253-174-REGRESSION.log",
                     "253-174-PERMISSION-PREFLIGHT.json", "253-174-EXECUTION-RECORD.json"):
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
            raise ContractError("172 does not use the176 local verifier contract")
        if "253-174-RECOVERY-SUCCESSOR.py" in p172 or re.search(r"(?i)halted\s*[:=]?\s*22\b", p172):
            raise ContractError("172 retains a stale174 verifier or22-halt pin")
    if record.get("dispositions_for") not in ([], None):
        raise ContractError("bridge record may not disposition historical halted or recovery plans")
    if stage == "complete":
        evidence = record.get("sdk_copy")
        if not isinstance(evidence, dict) or evidence.get("status") != "passed":
            raise ContractError("complete bridge requires installed SDK copy evidence")
        required_claims = {"readiness_168_runnable": True, "readiness_174_halted": True,
                           "post_chain_incomplete": 0, "post_chain_halted": 23,
                           "post_chain_blocked_summaries": [], "temporary_copy": True}
        for key, expected in required_claims.items():
            if evidence.get(key) != expected:
                raise ContractError(f"stored SDK-copy claim {key} differs")
        if not re.fullmatch(r"[0-9a-f]{40}", str(evidence.get("source_copy_commit"))):
            raise ContractError("SDK-copy committed source identity is missing")
        for key in ("sdk_sha256", "source_snapshot_sha256", "pre_simulation_init_sha256",
                    "pre_simulation_index_sha256", "post_chain_init_sha256", "post_chain_index_sha256"):
            if not re.fullmatch(r"[0-9a-f]{64}", str(evidence.get(key))):
                raise ContractError(f"SDK-copy evidence lacks a valid {key}")
        if evidence.get("disposition_ids") != [f"253-{n:02d}" for n in
                tuple(int(row["plan"].removeprefix("253-")) for row in read_json(root, R12_CONTRACT)["responsibilities"]) + NEVER_RAN_IDS]:
            raise ContractError("SDK-copy evidence does not use the same frozen71 targets")
        if sdk:
            actual = run_sdk_copy(root, record, record_path)
            for key, expected in required_claims.items():
                if actual.get(key) != expected:
                    raise ContractError(f"installed SDK rerun failed {key}")
            if actual.get("post_chain_halted_ids") != sorted(
                    f"253-{n:02d}" for n in HISTORICAL_HALT_IDS):
                raise ContractError("installed SDK rerun halted IDs differ from exact23-plan set")
    return {"status": "verified", "stage": stage, "plans": 5}


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
            print("176 attempt marker created; launch acceptance.sh once in the authorized root shell")
        elif args.command == "write-receipt":
            result = write_receipt(root, args.attempt_dir)
            print(json.dumps({"status": result["status"], "receipt": RECEIPT_176}, sort_keys=True))
        elif args.command == "verify-receipt":
            result = verify_receipt(root, args.consumer)
            print("253-176 successor receipt verified; 167/173/174 remain halted; CIREL-01 partial_not_reproduced; CIREL-02 unaccepted; full verification not_started")
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
