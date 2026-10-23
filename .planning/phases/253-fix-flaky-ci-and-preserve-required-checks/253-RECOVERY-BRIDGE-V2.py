#!/usr/bin/env python3
"""Versioned, read-only bridge consumer. Does not launch acceptance or hosted CI.

The179-tested helper remains immutable. Versioned function copies below retain
its evidence/source/limit checks while correcting only bridge counts, real
proof owners, consumer paths and the disposable SDK simulation of halted183.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

PHASE = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
LEGACY_SHA256 = "041dcbea95d1b5b18e8699d71f984c59c2039466a10e5eb10daa8a3fdcd9d36d"
LEGACY_PATH = Path(__file__).with_name("253-RECOVERY-SUCCESSOR.py")
if hashlib.sha256(LEGACY_PATH.read_bytes()).hexdigest() != LEGACY_SHA256:
    raise RuntimeError("179-pinned legacy helper changed; v2 refuses to load")
_spec = importlib.util.spec_from_file_location("phase253_immutable_successor", LEGACY_PATH)
legacy = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(legacy)
ContractError = legacy.ContractError
EXPECTED_173_FINDINGS = legacy.EXPECTED_173_FINDINGS
EXPECTED_PLAN_IDS = legacy.EXPECTED_PLAN_IDS
NEVER_RAN_IDS = legacy.NEVER_RAN_IDS
PHASE = legacy.PHASE
PLAN_174 = legacy.PLAN_174
PLAN_179 = legacy.PLAN_179
R12_CONTRACT = legacy.R12_CONTRACT
R12_CONTRACT_SHA256 = legacy.R12_CONTRACT_SHA256
RECEIPT_179 = legacy.RECEIPT_179
REVIEW_173 = legacy.REVIEW_173
REVIEW_173_SHA256 = legacy.REVIEW_173_SHA256
SHARED = legacy.SHARED
SUCCESSOR_SCHEMA = legacy.SUCCESSOR_SCHEMA
_replace_exactly_once = legacy._replace_exactly_once
acceptance_prerequisite = legacy.acceptance_prerequisite
bound_file = legacy.bound_file
check_historical_inputs = legacy.check_historical_inputs
clean_status = legacy.clean_status
command_body = legacy.command_body
expected_acceptance_body = legacy.expected_acceptance_body
git = legacy.git
parse_log = legacy.parse_log
read_bytes = legacy.read_bytes
read_json = legacy.read_json
read_source_bytes = legacy.read_source_bytes
sdk_identity = legacy.sdk_identity
sdk_query = legacy.sdk_query
sdk_write_summary = legacy.sdk_write_summary
sha256 = legacy.sha256
validate_preflight = legacy.validate_preflight
validate_probe_object = legacy.validate_probe_object

BRIDGE_180 = f"{PHASE}/253-180-BRIDGE-V2-RECORD.json"
BRIDGE_SCHEMA = "sigra.phase253.successor-bridge/v2"
ORIGINALS_180 = "refs/gsd/phase253-successor-180-v2-plan-originals"
SDK_MANIFEST_EXCLUSIONS = (BRIDGE_180,)
HISTORICAL_HALT_IDS = (*legacy.HISTORICAL_HALT_IDS, 183)
ACTIVE_HALT_COUNT = 28
ACTIVE_REPAIR_ID = 179

def verify_receipt(root: Path, consumer: str | None = None) -> dict:
    root = root.resolve()
    receipt = read_json(root, RECEIPT_179)
    if receipt.get("schema") != SUCCESSOR_SCHEMA or receipt.get("status") != "verified_local_success":
        raise ContractError("179 successor receipt schema/status invalid")
    repair_task, repair_record = acceptance_prerequisite(root, consumer)
    for rel, field in ((REVIEW_173, "review"), (repair_record, "repair_review"),
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
    if receipt.get("recovery_plan") != "253-179" or receipt.get("repair_plan") != repair_task or receipt.get("bridge_plan") != "253-180":
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
    if not isinstance(rows, list) or len(rows) != 183:
        raise ContractError("SDK index must contain exactly183 raw plan rows")
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
    if len(set(ids)) != 183:
        raise ContractError("SDK index contains duplicate plan IDs")
    if set(ids) != set(EXPECTED_PLAN_IDS):
        raise ContractError("SDK index plan IDs differ from the exact 253-01 through253-183 universe")
    if type(init.get("plan_count")) is not int or init["plan_count"] != 183:
        raise ContractError("SDK init plan_count differs from the exact183-row index")
    by_id = {row["id"]: row for row in rows}
    halted = sorted(plan_id for plan_id, row in by_id.items() if row["halted"] is True)
    expected_halted = sorted(f"253-{number:02d}" for number in HISTORICAL_HALT_IDS)
    if halted != expected_halted:
        raise ContractError("SDK index halted plan IDs differ from the exact28 halted set")
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

def expected_169_script(root: Path) -> str:
    r12 = read_json(root, R12_CONTRACT)
    if sha256(read_bytes(root, R12_CONTRACT)) != R12_CONTRACT_SHA256:
        raise ContractError("169 exact target source differs from frozen R12 bytes")
    target_ids = [row["plan"] for row in r12["responsibilities"]]
    target_ids.extend(f"253-{number:02d}" for number in NEVER_RAN_IDS + (176, 177))
    halt_ids = [f"253-{number:02d}" for number in HISTORICAL_HALT_IDS]
    plan_ids = [f"253-{number:02d}" for number in range(1, 184)]
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
        'if(c.responsibilities.length!==73||c.plan_pins.length!==183||c.halted_plans.length!==28||'
        'c.application.bundle_requires_final_summary_of!=="253-172"||'
        'c.application.accepted_only_predicate!=="scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"||'
        'JSON.stringify(sort(targets))!==JSON.stringify(sort(EXPECTED_TARGET_IDS))||'
        'JSON.stringify(sort(halts))!==JSON.stringify(sort(EXPECTED_HALT_IDS))||'
        'JSON.stringify(sort(pins))!==JSON.stringify(sort(EXPECTED_PLAN_IDS))||'
        '!t.includes("pagination_destination_rejected")||!t.includes("ci-gate-canary-flow.test.py")||'
        '!t.includes("TransportSensitivityTests")) process.exit(1)'
    )

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
    expected_plans = [f"253-{number:02d}" for number in range(1, 184)]
    for name, expected, reason in (
        ("EXPECTED_TARGET_IDS", expected_targets, "exact73 target set"),
        ("EXPECTED_HALT_IDS", expected_halts, "exact28 halt set"),
        ("EXPECTED_PLAN_IDS", expected_plans, "exact183 plan-pin set"),
    ):
        match = re.search(rf"const {name}=(\[.*?\]);", script, re.S)
        if not match:
            raise ContractError(f"169 executable {reason} comparison is missing")
        try:
            actual = json.loads(match.group(1))
        except json.JSONDecodeError as error:
            raise ContractError(f"169 executable {reason} is not a JSON array") from error
        if actual != expected:
            label = {"exact73 target set": "73 target set", "exact28 halt set": "28 halt set",
                     "exact183 plan-pin set": "183-plan-pin set"}[reason]
            raise ContractError(f"169 executable {label} differs from the authoritative source")
        actual_rows = {"EXPECTED_TARGET_IDS": "targets", "EXPECTED_HALT_IDS": "halts",
                       "EXPECTED_PLAN_IDS": "pins"}[name]
        if f"JSON.stringify(sort({actual_rows}))!==JSON.stringify(sort({name}))" not in script:
            raise ContractError(f"169 executable {reason} is not compared with actual rows")
    if not all(needle in script for needle in (
        "c.responsibilities.length!==73", "c.plan_pins.length!==183", "c.halted_plans.length!==28")):
        raise ContractError("169 executable reconciliation assertion has a stale count")
    if script != expected_script:
        raise ContractError("169 executable reconciliation assertion contains an unapproved executable or comment change")

def validate_168_receipt_placement(plan: str) -> None:
    bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
    prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
              "253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168 || exit $?;")
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
                  "253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168 || exit $?; ")
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
        repair_id, halt_count = ACTIVE_REPAIR_ID, ACTIVE_HALT_COUNT
        current = _replace_exactly_once(original, "wave: 3", "wave: 5", "169 wave")
        for old, new, label in (
            ("22 halted", f"{halt_count} halted", "169 halt count"), ("22) and", f"{halt_count}) and", "169 halt predicate"),
            ("23 halted", f"{halt_count} halted", "169 prior halt count"), ("23) and", f"{halt_count}) and", "169 prior halt predicate"),
            ("71 unstarted", "73 unstarted", "169 target count"), ("71-target", "73-target", "169 target label"),
            ("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json", "169 receipt path"),
            ("253-174", "253-179", "169 recovery identity"),
            ("149 -> 174", "149 -> 179", "149 owner"), ("158 -> 174", "158 -> 179", "158 owner"),
            ("167 -> 174", "167 -> 179", "167 proof owner"), ("173 -> 174", "173 -> 179", "173 proof owner"),
            ("154 -> 169 and 172;", "154 -> 169 and 172, 176 -> 179, 177 -> 180;", "new responsibility rows"),
            ("154 -> 169, 172 (all completion links plus load_target_disposition);",
             "154 -> 169, 172 (all completion links plus load_target_disposition), 176 -> 179, 177 -> 180;", "new proof rows"),
            ("173 -> 179.", "173 -> 179; 174 -> [179, 180]; 175 -> [179, 180]; 178 -> [179, 180]; 181 -> [179, 180]; 182 -> [179, 180]; 183 -> [179, 180].", "failed attempt owners"),
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
        current = _replace_exactly_once(current, scripts[0], old_script, "169 executable assertion")
        return current_169_instructions(current)
    if number in (170, 171):
        old_wave, new_wave = ((4, 6) if number == 170 else (5, 7))
        return _replace_exactly_once(original, f"wave: {old_wave}", f"wave: {new_wave}", f"{number} wave")
    if number == 172:
        halt_count = ACTIVE_HALT_COUNT
        current = _replace_exactly_once(original, "wave: 6", "wave: 8", "172 wave")
        current = _replace_exactly_once(current,
            "<automated>N=\"$HOME/.asdf/installs/nodejs/20.18.1/bin/node\";",
            "<automated>python3 .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer 168 && N=\"$HOME/.asdf/installs/nodejs/20.18.1/bin/node\";",
            "172 receipt verifier preamble")
        for old, new, label in (
            ("Twenty-two halted", "Twenty-eight halted", "172 halt prose"),
            ("22 halted", f"{halt_count} halted", "172 halt count"),
            ("71 targets", "73 targets", "172 target count"),
            ("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json", "172 receipt"),
            ("253-174-RECOVERY-SUCCESSOR.py", "253-RECOVERY-BRIDGE-V2.py", "172 verifier"),
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
        forbidden = sorted({f"253-{n:02d}-SUMMARY.md" for n in
                            (*HISTORICAL_HALT_IDS, *(number for number in range(168, 184) if number not in (176, 177)))})
        new_script = (
            'const b=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
            'const paths=(b.entries||[]).map(e=>e.path||e.disposition_path||""); '
            f'const EXPECTED={json.dumps([f"{n}-SUMMARY.md" for n in targets],separators=(",",":"))}; '
            f'const FORBIDDEN={json.dumps(forbidden,separators=(",",":"))}; '
            'const sort=(xs)=>[...xs].sort(); '
            'if(paths.length!==73||new Set(paths).size!==73||'
            'JSON.stringify(sort(paths))!==JSON.stringify(sort(EXPECTED))||'
            'paths.some(path=>FORBIDDEN.includes(path))) process.exit(1)'
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
        for number in (175, 178, 181, 182, 183):
            summary = phase_dir / f"253-{number}-SUMMARY.md"
            if not summary.is_file() or not re.search(r"(?m)^status:\s*halted$", summary.read_text(encoding="utf-8")):
                raise ContractError(f"SDK copy must retain halted{number} summary bytes")
        for number in (179, 180):
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
        if any(readiness_rows[f"253-{number}"]["halted"] is not True for number in (175, 178, 181, 182, 183)):
            raise ContractError("installed SDK copy does not retain halted175/178/181/182/183")

        # Simulate ordinary168–172/179/180 completion plus the exact original71+176/177 disposition set.
        for number in disposition_ids:
            if number in HISTORICAL_HALT_IDS:
                raise ContractError(f"disposition list overlaps halted historical plan {number}")
            sdk_write_summary(project, number, "complete", "Temporary disposition from the exact73-target contract.")
        for number in (168, 169, 170, 171, 172):
            sdk_write_summary(project, number, "complete", "Temporary ordinary completion fixture; not project evidence.")
        for number in (179, 180):
            sdk_write_summary(project, number, "complete", "Temporary repair-route completion fixture; not project evidence.")
        for number in (*range(168, 173), 176, 177, 179, 180):
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
                                                                      for n in (168, 169, 170, 171, 172, 176, 177, 179, 180)]},
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
                                                     for n in (168, 169, 170, 171, 172, 176, 177, 179, 180)]}
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
    for number in (179, 180):
        rel = f"{PHASE}/253-{number}-SUMMARY.md"
        if rel in source_summary_paths:
            original = git(root, "show", f"{source_commit}:{rel}").decode("utf-8", "strict")
            if not re.search(r"(?m)^status:\s*complete$", original):
                raise ContractError(f"SDK-copy source contains a non-complete route summary: {rel}")
    if report.get("readiness_168_runnable") is not True or not readiness_rows["253-168"]["has_summary"] is False:
        raise ContractError("SDK-copy report readiness168 summary/runnable facts disagree with parsed SDK output")
    if report.get("readiness_175_halted") is not True or any(
            not readiness_rows[f"253-{number}"]["halted"] for number in (175, 178, 181, 182, 183)):
        raise ContractError("SDK-copy report does not preserve halted175/178/181/182/183 in parsed readiness output")
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
    for required in ("253-180", "253-179", "28", "73", "253-175", "253-181", "253-182", "verify-receipt",
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

def current_169_instructions(text: str) -> str:
    """Make all operative partition/proof instructions agree with the v2 checks.

    This operates only on an external rendering of the original pinned169 plan.
    It does not change its acceptance deadline, hosted commands or frozen limits.
    """
    domain = "01-167 plus 173-178 and 181-183"
    halt_ids = "/".join(f"{n:02d}" for n in HISTORICAL_HALT_IDS)
    text = text.replace("01-167 plus 173", domain)
    text = text.replace("01-174", "01-183").replace("01 through 253-179", "01 through 253-183")
    text = text.replace("all 174 PLANs", "all 183 PLANs").replace("174 PLAN pins", "183 PLAN pins")
    text = text.replace("PLAN pins cover 01-183", "PLAN pins cover 01-183")
    text = re.sub(r"the contract keeps twenty-two halted records literal:.*?173\.",
                  "the contract keeps all28 halted records literal: " + halt_ids + ".", text, flags=re.I)
    text = text.replace("halted = R12 seventeen + 143 + 146 + 155 + 167 + 173 (22)",
                        "halted = the exact28 IDs " + halt_ids)
    text = text.replace("HALTED_IDS_R13 = R12 seventeen + 143 + 146 + 155 + 167 + 173 (22)",
                        "HALTED_IDS_R13 = the exact28 IDs " + halt_ids)
    text = text.replace("never-ran = 144, 145, 147..154, 156..163 (18)",
                        "never-ran = 144,145,147..154,156..163,176,177 (20)")
    text = text.replace("NEVER_RAN_IDS_R13 = 144, 145, 147..154, 156..163 (18)",
                        "NEVER_RAN_IDS_R13 = 144,145,147..154,156..163,176,177 (20)")
    text = text.replace("the eighteen never-ran", "the twenty never-ran")
    # Target counts are prose here; the sole executable contract uses exact arrays.
    text = re.sub(r"(?<![A-Za-z0-9-])71(?![A-Za-z0-9-])", "73", text)
    text = text.replace("168 partition members", "176 partition members")
    text = text.replace("164, 165, 166, 174, 168, 170, 171", "164, 165, 166, 179, 168, 170, 171")
    for old, new in (
        ("recovery owner 174", "recovery owners179/180"),
        ("completed 174", "completed 179"), ("174 complete", "179 complete"),
        ("174 is complete", "179 is complete"), ("174's", "179's"),
        ("174 Task 2", "179 Task 2"), ("174 receipt", "179 receipt"),
        ("owner 173 with 174", "owner173 with179"),
        ("149/158 to 174", "149/158 to179"), ("old 167 owner to 174", "old167 owner to179"),
        ("168 and 174 are completed proof owners", "168 and179/180 are completed proof owners"),
        ("owners move to 164-174, excluding halted 167 and 173", "owners exclude every one of the28 halted and73 unstarted plans"),
        ("twenty-two halted", "twenty-eight halted"),
    ):
        text = text.replace(old, new)
    # Replace the old continuation paragraphs rather than leave competing commands.
    text = re.sub(r"(?m)^174 continuation .*?(?=^253-179 amendment:)",
        "V2 current authority: preserve all28 historical halted SUMMARYs, including183. "
        "No halted plan is a completed repair or proof owner. The sparse domain has176 partition members: "
        "75 original completed,28 exact halted and73 original disposition targets. "
        "The targets remain original71 plus176/177; no halt is a disposition target. "
        "All183 PLANs and existing SUMMARYs are pinned; real179 and180 are ordinary proof owners. "
        "Reopen179 via253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer168. "
        "No successful181/182/183 receipt or SUMMARY is required or simulated.\n\n",
        text, flags=re.S)
    text = re.sub(r"(?m)^253-179 amendment:.*?(?=^\s*$)",
        "V2 reconciliation authority: partition " + domain + "; completed75,halted28,unstarted73. "
        "Describe174/175/178/181/182/183 as literal halts with original evidence. "
        "Use actual179/180 for their current local proof; use no halted proof owner. "
        "Pin all183 original PLANs and all existing SUMMARYs at actual producing commits. "
        "Reopen253-179-RECOVERY-RECEIPT.json with253-RECOVERY-BRIDGE-V2.py verify-receipt --consumer168. "
        "Preserve253-175-PLAN.md,253-175-SUMMARY.md,253-175-REPAIR-REVIEW.json and253-175-EXECUTION-RECORD.json, "
        "and all original181/182/183 halt evidence. "
        "Keep final owner172, original71 plus176/177 targets, all v1-R12 bytes, hosted completion links, "
        "and every request/retry/time/page/size limit unchanged.\n", text, flags=re.S)
    return text


def render_amendments(root: Path, output_dir: Path) -> dict:
    root, output_dir = root.resolve(), output_dir.resolve()
    if output_dir == root or root in output_dir.parents:
        raise ContractError("rendered plans must remain outside the checkout")
    if output_dir.exists() and any(output_dir.iterdir()):
        raise ContractError("render directory must be fresh and empty")
    receipt = read_json(root, RECEIPT_179)
    source = receipt["source_commit"]
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for number in range(168, 173):
        rel = f"{PHASE}/253-{number}-PLAN.md"
        original = git(root, "show", f"{source}:{rel}")
        if sha256(original) != receipt["historical_sha256"].get(rel):
            raise ContractError(f"179 original plan pin differs: {rel}")
        rendered = expected_plan_amendment(original.decode("utf-8", "strict"), number, root)
        target = output_dir / Path(rel).name
        target.write_text(rendered, encoding="utf-8", newline="")
        manifest[rel] = {"original_sha256": sha256(original), "amended_sha256": sha256(target.read_bytes())}
    return {"schema": "sigra.phase253.bridge-render/v2", "source_commit": source,
            "plans": manifest, "applied_to_project": False, "github_requests": 0}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    sub = parser.add_subparsers(dest="command", required=True)
    receipt = sub.add_parser("verify-receipt")
    receipt.add_argument("--consumer", choices=("168",), default="168")
    render = sub.add_parser("render-amendments")
    render.add_argument("--output-dir", type=Path, required=True)
    bridge = sub.add_parser("verify-bridge")
    bridge.add_argument("--stage", choices=("entry", "complete"), required=True)
    bridge.add_argument("--record", default=BRIDGE_180)
    bridge.add_argument("--sdk", action="store_true")
    sdk_copy = sub.add_parser("sdk-copy")
    sdk_copy.add_argument("--record", default=BRIDGE_180)
    sdk_copy.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve()
        if args.command == "verify-receipt":
            result = verify_receipt(root, args.consumer)
        elif args.command == "render-amendments":
            result = render_amendments(root, args.output_dir)
        else:
            record = read_json(root, args.record)
            receipt = read_json(root, RECEIPT_179)
            if record.get("source_commit") != receipt.get("source_commit"):
                raise ContractError("v2 bridge source differs from actual179 receipt")
            if args.command == "sdk-copy":
                output = args.output.resolve()
                if output == root or root in output.parents or output.exists():
                    raise ContractError("SDK output must be a fresh external file")
                result = validate_bridge(root, "complete", args.record, sdk=True)
                raw = (json.dumps(result["sdk_copy"], sort_keys=True, indent=2) + "\n").encode("utf-8")
                with output.open("xb") as stream:
                    stream.write(raw)
                result = {"status": "passed", "temporary_copy": True,
                          "report_path": str(output), "report_sha256": sha256(raw),
                          "post_chain_halted": result["sdk_copy"]["post_chain_halted"],
                          "post_chain_incomplete": result["sdk_copy"]["post_chain_incomplete"]}
            else:
                result = validate_bridge(root, args.stage, args.record, args.sdk)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ContractError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"v2 bridge refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
