#!/usr/bin/env python3
"""Finite synthetic tests for the Phase 253 successor command and receipt contract."""

from __future__ import annotations

import hashlib
import base64
import importlib.util
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import unicodedata
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[3]
HELPER_PATH = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.py"
SPEC = importlib.util.spec_from_file_location("successor", HELPER_PATH)
successor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(successor)
PHASE = successor.PHASE
ORIGINAL_FROZEN_175_COMMITS = dict(successor.FROZEN_175_COMMITS)
ORIGINAL_FROZEN_178_COMMITS = dict(successor.FROZEN_178_COMMITS)


def amend_entry_plans(root, original):
    repair_id = getattr(successor, "ACTIVE_REPAIR_ID", 181)
    halt_count = getattr(successor, "ACTIVE_HALT_COUNT", 25)
    rel168 = f"{PHASE}/253-168-PLAN.md"
    (root / rel168).parent.mkdir(parents=True, exist_ok=True)
    p168 = original[rel168].decode("utf-8")
    p168 = re.sub(r"(?m)^wave: 2$", "wave: 4", p168, count=1)
    p168 = p168.replace('depends_on: ["253-174"]', 'depends_on: ["253-180"]', 1)
    nested = re.compile(
        r'python3 -c \'import os,pathlib,re,subprocess; p=pathlib\.Path\("[^"]*253-174-PLAN\.md"\);.*?\' \|\| exit \$\?; ?')
    p168, count = nested.subn("", p168, count=1)
    if count != 1:
        raise AssertionError("entry fixture could not remove the old nested verifier")
    bodies = re.findall(r"<automated>(.*?)</automated>", p168, re.S)
    if len(bodies) != 2:
        raise AssertionError("168 fixture requires exactly two original automated bodies")
    prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
              "253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 || exit $?; ")
    for body in bodies:
        p168 = p168.replace("<automated>" + body + "</automated>",
                            "<automated>" + prefix + body + "</automated>", 1)
    p168 = p168.replace("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json")
    (root / rel168).write_text(p168)

    rel169 = f"{PHASE}/253-169-PLAN.md"
    p169 = original[rel169].decode("utf-8")
    p169 = re.sub(r"(?m)^wave: 3$", "wave: 5", p169, count=1)
    p169 = p169.replace('depends_on: ["253-174"]', 'depends_on: ["253-168"]', 1)
    p169 = p169.replace("22 halted", f"{halt_count} halted").replace("22) and", f"{halt_count}) and")
    p169 = p169.replace("23 halted", f"{halt_count} halted").replace("23) and", f"{halt_count}) and")
    p169 = p169.replace("71 unstarted", "73 unstarted").replace("71-target", "73-target")
    p169 = p169.replace("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json")
    p169 = p169.replace("253-174", "253-179")
    p169 = p169.replace("253-177", "253-180")
    p169 = p169.replace("253-179 amendment to", "253-179 amendment: verify-receipt --consumer 168 is required before each contract consumer; preserve halted 253-175-PLAN.md, 253-175-SUMMARY.md, 253-175-REPAIR-REVIEW.json and 253-175-EXECUTION-RECORD.json. 253-179 amendment to", 1)
    p169 = p169.replace("149 -> 174", "149 -> 179")
    p169 = p169.replace("158 -> 174", "158 -> 179")
    p169 = p169.replace("167 -> 174", "167 -> 179")
    p169 = p169.replace("173 -> 174", "173 -> 179")
    p169 = p169.replace("154 -> 169 and 172;", "154 -> 169 and 172, 176 -> 179, 177 -> 180;")
    p169 = p169.replace("154 -> 169, 172 (all completion links plus load_target_disposition);",
                        "154 -> 169, 172 (all completion links plus load_target_disposition), 176 -> 179, 177 -> 180;")
    p169 = p169.replace("173 -> 179.", f"173 -> 179; 174 -> [{repair_id}, 179]; 175 -> [{repair_id}, 179]; 178 -> [{repair_id}, 179]." +
                        (f" 181 -> [{repair_id}, 179]; 182 -> [{repair_id}, 179]." if repair_id == 183 else ""))
    p169 = p169.replace("253-174", "253-179")
    bodies = re.findall(r"<automated>(.*?)</automated>", p169, re.S)
    if len(bodies) < 3:
        raise AssertionError("169 fixture has no third automated contract")
    old_script = re.findall(r"(?:node|\"\$N\")\s+-e\s+\'(.*?)\'", bodies[2], re.S)
    if len(old_script) != 1:
        raise AssertionError("169 fixture has no unique executable R13 assertion")
    r12 = json.loads((ROOT / successor.R12_CONTRACT).read_bytes())
    target_ids = [int(row["plan"].removeprefix("253-")) for row in r12["responsibilities"]]
    target_ids.extend(successor.NEVER_RAN_IDS + (176, 177))
    halt_ids = list(successor.HISTORICAL_HALT_IDS)
    plan_ids = list(range(1, repair_id + 1))
    new_script = (
        'const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
        'const t=JSON.stringify(c); '
        f'const EXPECTED_TARGET_IDS={json.dumps([f"253-{n:02d}" for n in target_ids], separators=(",", ":"))}; '
        f'const EXPECTED_HALT_IDS={json.dumps([f"253-{n:02d}" for n in halt_ids], separators=(",", ":"))}; '
        f'const EXPECTED_PLAN_IDS={json.dumps([f"253-{n:02d}" for n in plan_ids], separators=(",", ":"))}; '
        'const sort=(xs)=>[...xs].sort(); '
        'const targets=c.responsibilities.map(r=>r.plan); '
        'const halts=c.halted_plans.map(r=>r.plan); '
        'const pins=c.plan_pins.map(r=>r.plan); '
        f'if(c.responsibilities.length!==73||c.plan_pins.length!=={repair_id}||c.halted_plans.length!=={halt_count}||'
        'c.application.bundle_requires_final_summary_of!=="253-172"||'
        'c.application.accepted_only_predicate!=="scripts/ci/ci-hosted-gate-verify.py --mode completion --require-dispositioned"||'
        'JSON.stringify(sort(targets))!==JSON.stringify(sort(EXPECTED_TARGET_IDS))||'
        'JSON.stringify(sort(halts))!==JSON.stringify(sort(EXPECTED_HALT_IDS))||'
        'JSON.stringify(sort(pins))!==JSON.stringify(sort(EXPECTED_PLAN_IDS))||'
        '!t.includes("pagination_destination_rejected")||!t.includes("ci-gate-canary-flow.test.py")||'
        '!t.includes("TransportSensitivityTests")) process.exit(1)'
    )
    p169 = p169.replace(old_script[0], new_script, 1)
    (root / rel169).write_text(p169)


def amend_complete_plans(root, original):
    """Independent positive oracle for the five authorized future plan edits."""
    amend_entry_plans(root, original)
    for number, old_wave, new_wave in ((170, 4, 6), (171, 5, 7)):
        rel = f"{PHASE}/253-{number}-PLAN.md"
        source = original[rel].decode("utf-8")
        changed, count = re.subn(rf"(?m)^wave: {old_wave}$", f"wave: {new_wave}", source, count=1)
        if count != 1:
            raise AssertionError(f"{number} wave anchor was not unique")
        (root / rel).write_text(changed, encoding="utf-8")
    rel = f"{PHASE}/253-172-PLAN.md"
    plan = original[rel].decode("utf-8")
    plan = (plan.replace("Twenty-two halted", "Twenty-seven halted")
                .replace("22 halted", "27 halted")
                .replace("71 targets", "73 targets")
                .replace("253-174-RECOVERY-RECEIPT.json", "253-179-RECOVERY-RECEIPT.json")
                .replace("253-174-RECOVERY-SUCCESSOR.py", "253-RECOVERY-SUCCESSOR.py"))
    plan = re.sub(r"(?m)^wave: 6$", "wave: 8", plan, count=1)
    plan = plan.replace(
        '<automated>N="$HOME/.asdf/installs/nodejs/20.18.1/bin/node";',
        '<automated>python3 .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 && N="$HOME/.asdf/installs/nodejs/20.18.1/bin/node";', 1)
    r12 = json.loads((ROOT / successor.R12_CONTRACT).read_bytes())
    targets = [row["plan"] for row in r12["responsibilities"]]
    targets.extend(f"253-{n:02d}" for n in successor.NEVER_RAN_IDS + (176, 177))
    forbidden = sorted({f"253-{n:02d}-SUMMARY.md" for n in
                        (*successor.HISTORICAL_HALT_IDS, *(number for number in range(168, 184)
                                                          if number not in (176, 177)))})
    bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
    matches = list(re.finditer(r'"?\$N"?\s+-e\s+\'(const b=JSON\.parse\(require\("fs"\).*?process\.exit\(1\))\' \$P/253-LOAD-RECOVERY-SUPERSESSION-SUMMARIES-R13\.json', bodies[1], re.S))
    if len(matches) != 1:
        raise AssertionError("172 executable bundle assertion is not unique")
    code = (
        'const b=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
        'const paths=(b.entries||[]).map(e=>e.path||e.disposition_path||""); '
        f'const EXPECTED={json.dumps([f"{n}-SUMMARY.md" for n in targets],separators=(",",":"))}; '
        f'const FORBIDDEN={json.dumps(forbidden,separators=(",",":"))}; '
        'const sort=(xs)=>[...xs].sort(); '
        'if(paths.length!==73||new Set(paths).size!==73||'
        'JSON.stringify(sort(paths))!==JSON.stringify(sort(EXPECTED))||'
        'paths.some(path=>FORBIDDEN.includes(path))) process.exit(1)'
    )
    plan = plan.replace(matches[0].group(1), code, 1)
    (root / rel).write_text(plan, encoding="utf-8")


def amend_repair_183_route(root):
    """Independent temporary routing edit; the production renderer is not the oracle."""
    rel179 = f"{PHASE}/253-179-PLAN.md"
    path179 = root / rel179
    text179 = path179.read_text(encoding="utf-8")
    if 'depends_on: ["253-181"]' in text179:
        text179 = text179.replace('depends_on: ["253-181"]', 'depends_on: ["253-183"]', 1)
    else:
        text179 = text179.replace('depends_on: ["253-178"]', 'depends_on: ["253-183"]', 1)
    text179 = text179.replace("253-181-REPAIR-REVIEW.json", "253-183-REPAIR-REVIEW.json")
    path179.write_text(text179, encoding="utf-8")
    rel180 = f"{PHASE}/253-180-PLAN.md"
    path180 = root / rel180
    text180 = path180.read_text(encoding="utf-8")
    text180 = (text180.replace("181pins", "183pins").replace("25halts", "27halts")
                    .replace("[181,179]", "[183,179]"))
    path180.write_text(text180, encoding="utf-8")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def valid_log(source="a" * 40, probe=None):
    rows = []
    for name, _ in successor.SUITES:
        rows.append(f"SUITE-START {name}")
        if name == "gate-canary-shell":
            rows.append("ci-gate-canary tests passed (synthetic fixture repo; no active phase refs or ledgers)")
        else:
            rows.extend((f"Ran {79 if name == 'full-dryrun' else 3} tests in 0.001s", "", "OK"))
        rows.append(f"SUITE-PASS {name}")
    projection = {
        "status": "ready-local-proposal",
        "server_parent_sha": "09df342a82e03c3d5d40173c912b70e827f7eadc",
        "projection": {"projected_total_requests": 22, "binary_blob_requests": 10,
                       "largest_tree_body_bytes": 2096775, "max_tree_body_bytes": successor.TREE_CAP},
        "tree_requests": [{"body_bytes": 2096775}, {"body_bytes": 1024}],
        "main_freshness": {"fetched_main_sha": "09df342a82e03c3d5d40173c912b70e827f7eadc",
                           "merge_preflight": {"head": "a" * 40, "base": "b" * 40,
                                               "exit": 0, "clean": True, "conflicts": []}},
    }
    gate = {"status": "passed", "synthetic": True,
            "requests_by_category": {"preflight": 7},
            "seeded_r8_refs_changed": False, "seeded_r9_refs_changed": False,
            "seeded_r10_refs_changed": False, "seeded_r11_refs_changed": False,
            "seeded_r12_refs_changed": False, "response_shape": {"ok": True}}
    paged = {**gate, "mode": "live-policy", "stop": None,
             "paginated_reads": [{"route": "check_runs", "pages": 3, "next_link_forms": ["repositories-id"]},
                                 {"route": "run_jobs", "pages": 2, "next_link_forms": ["repositories-id"]},
                                 {"route": "run_artifacts", "pages": 2, "next_link_forms": ["repositories-id"]}]}
    rows.extend(("PROJECTION " + canonical(projection), "HERMETIC-GATE " + canonical(gate),
                 "LIVE-POLICY-GATE " + canonical(gate), "PAGED-FULL-PASS " + canonical(paged),
                 "PERMISSION-PREFLIGHT " + canonical(probe if probe is not None else valid_preflight()["probe"]),
                 "ACCEPTANCE-PID 412", "ACCEPTANCE-SOURCE " + source,
                 "FULL-DRYRUN-COUNT 79", "VERIFY-EXIT 0"))
    return ("\n".join(rows) + "\n").encode()


def valid_preflight(source="a" * 40, plan_hash="d" * 64, generated_hash="e" * 64, probe=None):
    probe = probe or {"schema": "sigra.phase253.git-permission-probe/v1", "source_commit": source,
             "shell_pid": 412, "git_common_dir": "/tmp/fixture/.git", "object_dir": "/tmp/fixture/.git/objects",
             "command": ["git", "hash-object", "-w", "--stdin"], "object_oid": "b" * 40,
             "payload_sha256": "c" * 64, "readback_sha256": "c" * 64, "payload_bytes": 12,
             "write_exit": 0, "read_exit": 0, "readback": "exact"}
    probe["source_commit"] = source
    return {"schema": "sigra.phase253.git-permission-preflight/v1", "status": "passed",
            "acceptance_status": "passed", "acceptance_exit": 0, "acceptance_source": source,
            "acceptance_pid": 412, "probe": probe, "once_only": True,
            "plan_command_sha256": plan_hash, "generated_script_sha256": generated_hash,
            "launch": {"tool": "exec_command", "sandbox_permissions": "require_escalated", "executor": "root",
                       "block_sha256": plan_hash, "tool_call_id": "call-123", "session_id": 123,
                       "generated_script_sha256": generated_hash}}


def synthetic_capture_run(project, slot, argv, native_count=None, red_errors=(), previous_slot=None, previous_hash=None):
    head = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    paths = [f"{PHASE}/253-RECOVERY-SUCCESSOR.py", f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
             f"{PHASE}/253-179-PLAN.md", f"{PHASE}/253-180-PLAN.md", f"{PHASE}/253-183-PLAN.md"]
    sources = []
    for rel in paths:
        raw = subprocess.check_output(["git", "-C", str(project), "show", f"{head}:{rel}"])
        blob = subprocess.check_output(["git", "-C", str(project), "hash-object", "--stdin"], input=raw,
                                       text=False).decode().strip()
        producer = subprocess.check_output(["git", "-C", str(project), "log", "-1", "--format=%H", "--", rel], text=True).strip()
        sources.append({"path": rel, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
                        "blob": blob, "last_producing_commit": producer})
    snapshot = {"argv": argv, "cwd": str(project.resolve()), "owner_id": "synthetic-test-fixture",
                "head": head, "sources": sources,
                "status_base64": base64.b64encode(b"").decode(),
                "inputs_sha256": "a" * 64, "wrapper_sha256": "b" * 64,
                "utc": "2026-10-20T00:00:00+00:00"}
    if native_count is None:
        stderr = b"validator records captured\n"
        exit_code = 0
    else:
        if red_errors:
            stderr_lines = []
            for item in red_errors:
                if item == "EXPECTED_25":
                    name = "test_bridge_rejects_stale_174_routes_22_halts_pins_and_hosted_link_edits"
                    failure_name = name + " (__main__.SuccessorContractTests." + name + ") (label='22-halt')"
                    assertion = '"25 halt set" does not match "169 executable reconciliation assertion has a stale count"'
                elif item == "ACTIVE_REPAIR_183_MISSING":
                    name = "test_lifecycle_183_preserves_181_182_halts_and_reuses_179_180"
                    failure_name = name + " (__main__.SuccessorContractTests." + name + ")"
                    assertion = item
                elif item == "DIRECT_RUN_REVIEW_183_MISSING":
                    name = "test_validate_review183_requires_direct_runs_and_source_commits"
                    failure_name = name + " (__main__.SuccessorContractTests." + name + ")"
                    assertion = item
                else:
                    raise AssertionError("unknown synthetic designated RED assertion")
                stderr_lines.extend(("======================================================================",
                                     "FAIL: " + failure_name, "----------------------------------------------------------------------",
                                     "Traceback (most recent call last):", f"AssertionError: {assertion}", ""))
            stderr_lines.extend(("----------------------------------------------------------------------", f"Ran {native_count} tests in 0.001s", "",
                                 f"FAILED (failures={len(red_errors)})"))
            exit_code = 1
        else:
            stderr_lines = [f"Ran {native_count} tests in 0.001s", "", "OK"]
            exit_code = 0
        stderr = ("\n".join(stderr_lines) + "\n").encode()
    record = {"slot": slot, "argv": argv, "native_exit_code": exit_code,
              "launch_guard": {"slot": slot, "argv": argv, "previous_slot": previous_slot,
                               "previous_result_sha256": previous_hash}, "signal": None, "timeout": False,
              "duration_seconds": 0.001, "before": snapshot, "after": json.loads(json.dumps(snapshot)),
              "direct_process_capture": True,
              "stdout_base64": "", "stdout_bytes": 0,
              "stdout_sha256": hashlib.sha256(b"").hexdigest(),
              "stderr_base64": base64.b64encode(stderr).decode(), "stderr_bytes": len(stderr),
              "stderr_sha256": hashlib.sha256(stderr).hexdigest(),
              "verification_exit_code": 0, "recoverable_assertion_failure": False}
    if slot == "t1-red":
        stderr = stderr.replace(b"AssertionError: EXPECTED_25", b'AssertionError: "25 halt set" does not match "169 executable reconciliation assertion has a stale count"')
    if slot == "t2-red":
        record["native_exit_code"] = 1
    if slot in ("t1-red", "t2-red"):
        record["stderr_base64"] = base64.b64encode(stderr).decode()
        record["stderr_bytes"] = len(stderr)
        record["stderr_sha256"] = hashlib.sha256(stderr).hexdigest()
    return record


def commit_capture_result(project, slot, record):
    raw = json.dumps(record, sort_keys=True).encode()
    rel = f".planning/diagnostics/phase253-execution183/synthetic/{slot}/result.json"
    path = project / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    subprocess.run(["git", "-C", str(project), "add", rel], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", f"capture original {slot} result"], check=True)
    commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    ref = f"refs/gsd/synthetic-phase253-t2/{slot}"
    subprocess.run(["git", "-C", str(project), "update-ref", ref, commit], check=True)
    blob = subprocess.check_output(["git", "-C", str(project), "hash-object", "--stdin"], input=raw).decode().strip()
    record["capture_result"] = {"base64": base64.b64encode(raw).decode(), "bytes": len(raw),
                                "sha256": hashlib.sha256(raw).hexdigest(), "path": rel,
                                "blob": blob, "commit": commit, "ref": ref}
    return record


def committed_receipt_fixture(parent):
    project = pathlib.Path(parent) / "receipt-repo"
    project.mkdir()
    shutil.copytree(ROOT / ".planning", project / ".planning")
    for rel in ("scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-git-publication.py",
                "scripts/ci/ci-gate-canary-dryrun.py"):
        target = project / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
    amend_repair_183_route(project)
    (project / f"{PHASE}/253-183-SUMMARY.md").write_text(
        "---\nphase: 253-fix-flaky-ci-and-preserve-required-checks\nplan: \"183\"\nstatus: complete\n---\n",
        encoding="utf-8")
    reviewed = {"scripts/ci/ci-git-publication.test.py", f"{PHASE}/253-183-PLAN.md",
                successor.PLAN_179, successor.PLAN_180,
                f"{PHASE}/253-RECOVERY-SUCCESSOR.py",
                f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
                "scripts/ci/ci-git-publication.py", "scripts/ci/ci-gate-canary-dryrun.py"}
    subprocess.run(["git", "-C", str(project), "init", "-q"], check=True)
    alternates = project / ".git/objects/info/alternates"
    alternates.parent.mkdir(parents=True, exist_ok=True)
    alternates.write_text(str((ROOT / ".git/objects").resolve()) + "\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(project), "config", "user.name", "Receipt Fixture"], check=True)
    subprocess.run(["git", "-C", str(project), "config", "user.email", "receipt-fixture@example.test"], check=True)
    subprocess.run(["git", "-C", str(project), "add", ".planning", "scripts"], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "receipt source files"], check=True)
    reviewed_commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    successor.FROZEN_175_COMMITS.update({rel: reviewed_commit for rel in successor.FROZEN_175_COMMITS})
    successor.FROZEN_178_COMMITS.update({rel: reviewed_commit for rel in successor.FROZEN_178_COMMITS})
    review = {"schema": successor.REVIEW_SCHEMA, "status": "reviewed_for_new_acceptance",
              "repair_plan": "253-183", "acceptance_plan": "253-179", "bridge_plan": "253-180",
              "source_files": {rel: hashlib.sha256((project / rel).read_bytes()).hexdigest() for rel in reviewed},
              "source_commits": {rel: reviewed_commit for rel in reviewed},
              "unresolved_implementation_findings": [],
              "finding_dispositions": {finding: "closed" for finding in successor.EXPECTED_178_FINDING_IDS},
              "acceptance_attempts": 0,
              "github_requests": 0, "native_browser_launches": 0,
              "requirements": {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"},
              "phase_verification_status": "not_started",
              "historical_178": {"status": "halted", "finding_ids": list(successor.EXPECTED_178_FINDING_IDS),
                                  "sha256": {rel: successor.HISTORICAL_SHA256[rel]
                                             for rel in successor.FROZEN_178_COMMITS}},
              "amended_plan_validation": {},
              "historical": {
                  "181": {"status": "halted", "sha256": successor.HISTORICAL_181_SHA256,
                          "commits": successor.FROZEN_181_COMMITS},
                  "182": {"status": "halted", "sha256": successor.HISTORICAL_182_SHA256,
                          "commits": successor.FROZEN_182_COMMITS,
                          "direct_process_capture": False,
                          "transcripts": {f"{PHASE}/253-182-TASK1-FAILED-01.log": "reconstructed",
                                          f"{PHASE}/253-182-TASK1-FAILED-02.log": "reconstructed"}}},
              "direct_runs": {},
              "scope": {"product_changes": ["scripts/ci/ci-git-publication.test.py"],
                        "product_changes_during_183": []}}
    node = pathlib.Path.home() / ".asdf/installs/nodejs/20.18.1/bin/node"
    sdk = pathlib.Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs"
    validator_output = []
    for plan_id in ("253-179", "253-180"):
        rel = f"{PHASE}/{plan_id}-PLAN.md"
        plan_raw = (project / rel).read_bytes()
        records = {}
        for key, verb, extra in (("frontmatter", "frontmatter.validate", ["--schema", "plan-gap-closure"]),
                                 ("structure", "verify.plan-structure", [])):
            argv = [str(node), str(sdk), "query", verb, rel, *extra]
            result = ({"valid": True, "schema": "plan-gap-closure"} if key == "frontmatter" else
                      {"valid": True, "errors": [], "tasks": [{"name": "first"}, {"name": "second"}]})
            stdout_raw, stderr_raw = (json.dumps(result, sort_keys=True) + "\n").encode(), b""
            record = {"argv": argv, "exit_code": 0,
                      "stdout": stdout_raw.decode("utf-8"),
                      "stdout_sha256": hashlib.sha256(stdout_raw).hexdigest(),
                      "stderr": "", "stderr_sha256": hashlib.sha256(stderr_raw).hexdigest()}
            records[key] = record
            validator_output.append({"plan_path": rel, "plan_sha256": hashlib.sha256(plan_raw).hexdigest(),
                                     "argv": argv, "exit_code": 0,
                                     "stdout": record["stdout"], "stderr": "",
                                     "stdout_sha256": record["stdout_sha256"],
                                     "stderr_sha256": record["stderr_sha256"]})
        review["amended_plan_validation"][plan_id] = {
            "plan_path": rel, "plan_sha256": hashlib.sha256(plan_raw).hexdigest(), **records}
    run_specs = {
        "t1-red": (1, ["EXPECTED_25"]), "t1-green": (3, []),
        "t2-red": (2, ["ACTIVE_REPAIR_183_MISSING", "DIRECT_RUN_REVIEW_183_MISSING"]),
        "t2-green": (6, []), "t3-full": (25, []),
    }
    previous_slot, previous_digest = None, None
    for slot, (count, failures) in run_specs.items():
        argv = successor._expected_183_test_argv(slot)
        run = synthetic_capture_run(project, slot, argv, count, failures,
                                    previous_slot=previous_slot, previous_hash=previous_digest)
        run = commit_capture_result(project, slot, run)
        review["direct_runs"][slot] = run
        previous_slot, previous_digest = slot, run["capture_result"]["sha256"]
    validator_argv = ["python3", "-B", "-c",
                      "frontmatter.validate verify.plan-structure for number in (179,180) Node 20.18.1"]
    validator_run = synthetic_capture_run(project, "t3-validators", validator_argv,
                                         previous_slot=previous_slot, previous_hash=previous_digest)
    validator_bytes = b"".join((json.dumps(row, sort_keys=True) + "\n").encode() for row in validator_output)
    validator_run["stdout_base64"] = base64.b64encode(validator_bytes).decode()
    validator_run["stdout_bytes"] = len(validator_bytes)
    validator_run["stdout_sha256"] = hashlib.sha256(validator_bytes).hexdigest()
    review["direct_runs"]["t3-validators"] = commit_capture_result(project, "t3-validators", validator_run)
    for unused_slot, predecessor in (("t1-correction", "t1-green"), ("t1-final", "t1-green"),
                                     ("t2-correction", "t2-green"), ("t2-final", "t2-green"),
                                     ("t3-recovery", "t3-full"), ("t3-full-final", "t3-full")):
        review["direct_runs"][unused_slot] = {"disposition": "not_used", "because_slot": predecessor,
                                               "result_sha256": review["direct_runs"][predecessor]["capture_result"]["sha256"]}
    (project / successor.REVIEW_183).write_text(json.dumps(review, sort_keys=True, indent=2) + "\n")
    subprocess.run(["git", "-C", str(project), "add", successor.REVIEW_183], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "commit direct-capture review fixture"], check=True)
    source = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    generated, _ = successor.expected_acceptance_body(
        successor.command_body((project / successor.PLAN_174).read_bytes(), successor.PLAN_174))
    plan_body = successor.command_body((project / successor.PLAN_179).read_bytes(), successor.PLAN_179)
    payload = b"phase253 isolated receipt probe payload\n"
    oid = subprocess.check_output(["git", "-C", str(project), "hash-object", "-w", "--stdin"], input=payload).decode().strip()
    common = pathlib.Path(subprocess.check_output(["git", "-C", str(project), "rev-parse", "--git-common-dir"], text=True).strip())
    if not common.is_absolute():
        common = (project / common).resolve()
    else:
        common = common.resolve()
    payload_hash = hashlib.sha256(payload).hexdigest()
    probe = {"schema": "sigra.phase253.git-permission-probe/v1", "source_commit": source,
             "shell_pid": 412, "git_common_dir": str(common), "object_dir": str(common / "objects"),
             "command": ["git", "hash-object", "-w", "--stdin"], "object_oid": oid,
             "payload_sha256": payload_hash, "readback_sha256": payload_hash,
             "payload_bytes": len(payload), "write_exit": 0, "read_exit": 0, "readback": "exact"}
    generated_hash = hashlib.sha256(generated.encode()).hexdigest()
    plan_hash = hashlib.sha256(plan_body.encode()).hexdigest()
    log = valid_log(source, probe)
    preflight = valid_preflight(source, plan_hash, generated_hash, probe)
    attempt = pathlib.Path(parent) / "attempt"
    attempt.mkdir()
    bindings = successor.original_bindings(project)["files"]
    prepared = {"source_commit": source, "plan179_body_sha256": plan_hash,
                "generated_script_sha256": generated_hash,
                "shared_sha256": {rel: hashlib.sha256((project / rel).read_bytes()).hexdigest()
                                  for rel in successor.SHARED},
                "source_bindings": bindings}
    (attempt / "prepared.json").write_text(json.dumps(prepared))
    (attempt / "253-179-REGRESSION.log").write_bytes(log)
    (attempt / "253-179-PERMISSION-PREFLIGHT.json").write_text(json.dumps(preflight, sort_keys=True, indent=2) + "\n")
    # Match the real plan: commit log/preflight before producing the receipt.
    for name in ("253-179-REGRESSION.log", "253-179-PERMISSION-PREFLIGHT.json"):
        shutil.copyfile(attempt / name, project / PHASE / name)
    subprocess.run(["git", "-C", str(project), "add", f"{PHASE}/253-179-REGRESSION.log",
                    f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json"], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "commit run evidence before receipt"], check=True)
    receipt = successor.expected_receipt(project, attempt)
    receipt_path = project / successor.RECEIPT_179
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
    # Attempt evidence is canonicalized only after the source-bound receipt was produced.
    (project / f"{PHASE}/253-179-REGRESSION.log").write_bytes(log)
    (project / f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json").write_text(json.dumps(preflight, sort_keys=True, indent=2) + "\n")
    subprocess.run(["git", "-C", str(project), "add", successor.RECEIPT_179,
                    f"{PHASE}/253-179-REGRESSION.log", f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json"], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "receipt and evidence"], check=True)
    return project


class SuccessorContractTests(unittest.TestCase):
    def setUp(self):
        successor.FROZEN_175_COMMITS.clear()
        successor.FROZEN_175_COMMITS.update(ORIGINAL_FROZEN_175_COMMITS)
        successor.FROZEN_178_COMMITS.clear()
        successor.FROZEN_178_COMMITS.update(ORIGINAL_FROZEN_178_COMMITS)

    def test_sdk_report_rejects_rehashed_fabricated_queries(self):
        execution = json.loads((ROOT / f"{PHASE}/253-178-EXECUTION-RECORD.json").read_bytes())
        finding = next(item for item in execution["findings"] if item["id"] == "178-REVIEW-02")
        source = pathlib.Path(finding["fabricated_report_path"])
        raw = source.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), finding["fabricated_report_sha256"])
        with tempfile.TemporaryDirectory(prefix="sigra-253-fabricated-sdk-") as temp:
            root = pathlib.Path(temp) / "project"
            (root / successor.R12_CONTRACT).parent.mkdir(parents=True)
            shutil.copy2(ROOT / successor.R12_CONTRACT, root / successor.R12_CONTRACT)
            report = pathlib.Path(temp) / "fabricated-report.json"
            report.write_bytes(raw)
            evidence = {"report_path": str(report), "report_sha256": hashlib.sha256(raw).hexdigest()}
            with self.assertRaisesRegex(successor.ContractError, "SDK-copy|query.*JSON|SDK.*output"):
                successor.validate_sdk_copy_report(root, evidence)

    def test_sdk_indexes_require_exact_unique_plan_universe(self):
        validator = getattr(successor, "validate_sdk_index_rows", None)
        self.assertTrue(callable(validator), "missing raw SDK index validator")
        expected_ids = [f"253-{number:02d}" for number in range(1, 184)]
        expected_halted = {f"253-{number:02d}" for number in successor.HISTORICAL_HALT_IDS}

        def rows(final):
            incomplete = set() if final else {"253-168"}
            result = []
            for plan in expected_ids:
                row = {"id": plan, "has_summary": plan not in incomplete,
                       "halted": plan in expected_halted, "blocked_by": [],
                       "gap_closure": plan == "253-168"}
                if row["gap_closure"]:
                    row["ready"] = plan == "253-168" and not final
                result.append(row)
            return result

        ready_rows = rows(False)
        ready_init = {"plan_count": 183, "incomplete_count": 1,
                      "incomplete_plans": ["253-168-PLAN.md"],
                      "runnable_plans": ["253-168-PLAN.md"]}
        final_rows = rows(True)
        final_init = {"plan_count": 183, "incomplete_count": 0,
                      "incomplete_plans": [], "runnable_plans": []}
        self.assertEqual(len(validator(ready_rows, ready_init, "readiness")), 183)
        self.assertEqual(len(validator(final_rows, final_init, "final")), 183)

        attacks = {
            "duplicate": lambda values: values[:-1] + [dict(values[0])],
            "missing": lambda values: values[:-1],
            "extra": lambda values: values + [{"id": "253-184", "has_summary": True,
                                                 "halted": False, "blocked_by": []}],
            "replaced": lambda values: values[:-1] + [{**values[-1], "id": "253-999"}],
            "malformed": lambda values: values[:-1] + [{**values[-1], "id": "253-0183"}],
            "non-object": lambda values: values[:-1] + ["253-183"],
        }
        for stage, base, init in (("readiness", ready_rows, ready_init), ("final", final_rows, final_init)):
            for label, mutate in attacks.items():
                with self.subTest(stage=stage, mutation=label), self.assertRaises(successor.ContractError):
                    validator(mutate(base), init, stage)
        malformed = dict(ready_rows[0]); malformed["ready"] = "true"
        with self.assertRaisesRegex(successor.ContractError, "readiness field"):
            validator([malformed, *ready_rows[1:]], ready_init, "readiness")
        wrong_halt = [dict(row) for row in ready_rows]
        wrong_halt[1]["halted"] = False
        with self.assertRaisesRegex(successor.ContractError, "halted plan IDs"):
            validator(wrong_halt, ready_init, "readiness")
        bad_runnable = dict(ready_init, runnable_plans=[])
        with self.assertRaisesRegex(successor.ContractError, "168 as runnable"):
            validator(ready_rows, bad_runnable, "readiness")
        bad_incomplete = dict(final_init, incomplete_count=1)
        with self.assertRaisesRegex(successor.ContractError, "incomplete fields"):
            validator(final_rows, bad_incomplete, "final")
        blocked168 = [dict(row) for row in ready_rows]
        blocked168[167]["blocked_by"] = ["253-178"]
        with self.assertRaisesRegex(successor.ContractError, "168 row"):
            validator(blocked168, ready_init, "readiness")
        summarized168 = [dict(row) for row in ready_rows]
        summarized168[167]["has_summary"] = True
        bad_ready_init = dict(ready_init, incomplete_count=0, incomplete_plans=[])
        with self.assertRaisesRegex(successor.ContractError, "168 row"):
            validator(summarized168, bad_ready_init, "readiness")
        blocked_final = [dict(row) for row in final_rows]
        blocked_final[175]["blocked_by"] = ["253-175"]
        self.assertEqual(len(validator(blocked_final, final_init, "final")), 183)

    def test_168_requires_receipt_before_each_automated_body(self):
        original = {
            f"{PHASE}/253-{number}-PLAN.md": (ROOT / f"{PHASE}/253-{number}-PLAN.md").read_bytes()
            for number in (168, 169, 170, 171, 172, 176, 177)
        }
        with tempfile.TemporaryDirectory(prefix="sigra-253-168-receipt-") as temp:
            root = pathlib.Path(temp)
            plan = successor.expected_plan_amendment(
                original[f"{PHASE}/253-168-PLAN.md"].decode("utf-8"), 168, root)
            bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
            self.assertEqual(len(bodies), 2)
            self.assertEqual([body.count("verify-receipt --consumer 168") for body in bodies], [1, 1])
            original_bodies = re.findall(r"<automated>(.*?)</automated>",
                original[f"{PHASE}/253-168-PLAN.md"].decode("utf-8"), re.S)
            old_check = re.compile(
                r'python3 -c \'import os,pathlib,re,subprocess; p=pathlib\.Path\("[^"]*253-174-PLAN\.md"\);.*?\' \|\| exit \$\?; ?',
                re.S)
            original_bodies[0], removed = old_check.subn("", original_bodies[0], count=1)
            self.assertEqual(removed, 1)
            prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
                      "253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 || exit $?; ")
            self.assertEqual(bodies, [prefix + body for body in original_bodies])
            for body in bodies:
                self.assertTrue(body.startswith(prefix))
                original_tail = body[len(prefix):]
                self.assertTrue(original_tail)
                script = ("receipt_spy() { printf receipt; return 7; }; "
                          "downstream_spy() { printf downstream; }; "
                          + body.replace(prefix, "receipt_spy || exit $?; ", 1)
                               .replace(original_tail, "downstream_spy", 1))
                result = subprocess.run(["bash", "-c", script], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b"receipt")
                success = subprocess.run(["bash", "-c", script.replace("return 7", "return 0")],
                                          capture_output=True)
                self.assertEqual(success.returncode, 0)
                self.assertEqual(success.stdout, b"receiptdownstream")

    def test_bridge_rejects_stale_executable_assertions_and_owners(self):
        """The prior green fixture must fail when only recovery prose is updated."""
        with tempfile.TemporaryDirectory(prefix="sigra-253-bridge-stale-executable-") as temp:
            root = pathlib.Path(temp)
            phase = root / PHASE
            phase.mkdir(parents=True)
            originals = {}
            for number in (*range(168, 173), 176, 177):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                raw = (ROOT / rel).read_bytes()
                originals[rel] = raw
                (root / rel).write_bytes(raw)
            (root / successor.R12_CONTRACT).parent.mkdir(parents=True, exist_ok=True)
            (root / successor.R12_CONTRACT).write_bytes((ROOT / successor.R12_CONTRACT).read_bytes())
            (root / successor.R12_CONTRACT).write_bytes((ROOT / successor.R12_CONTRACT).read_bytes())
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "fixture@example.test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "original plans"], check=True)
            source_commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            ref = successor.ORIGINALS_180
            subprocess.run(["git", "-C", str(root), "update-ref", ref, source_commit], check=True)
            amend_entry_plans(root, originals)
            rel169 = f"{PHASE}/253-169-PLAN.md"
            stale169 = originals[rel169].decode("utf-8")
            stale169 = re.sub(r"(?m)^wave: 3$", "wave: 5", stale169, count=1)
            stale169 = stale169.replace('depends_on: ["253-174"]', 'depends_on: ["253-168"]', 1)
            stale169 += "\n253-180\n253-179\n24 halted\n73 targets\n149 -> 179\n158 -> 179\n167 -> 179\n173 -> 179\n"
            (root / rel169).write_text(stale169)
            amended = {f"{PHASE}/253-{number}-PLAN.md": hashlib.sha256(
                (root / f"{PHASE}/253-{number}-PLAN.md").read_bytes()).hexdigest() for number in (168, 169)}
            pins = {}
            for rel, raw in originals.items():
                blob = subprocess.check_output(["git", "-C", str(root), "hash-object", "--stdin"], input=raw).decode().strip()
                pins[rel] = {"blob": blob, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
            paths = {row.split(b"\t", 1)[1].decode() for row in subprocess.check_output(
                ["git", "-C", str(root), "ls-tree", "-rz", "-r", source_commit, "--", PHASE,
                 ".planning/phases/252-measure-current-ci"]).split(b"\0") if row}
            protected = {rel: hashlib.sha256(subprocess.check_output(
                ["git", "-C", str(root), "show", f"{source_commit}:{rel}"])).hexdigest() for rel in paths}
            record = {"schema": successor.BRIDGE_SCHEMA, "stage": "entry", "source_commit": source_commit,
                      "preservation_ref": ref, "originals": pins, "amended_sha256": amended,
                      "protected_source_bindings": protected, "dispositions_for": []}
            record_path = f"{PHASE}/253-180-BRIDGE-RECORD.json"
            (root / record_path).write_text(json.dumps(record))

            # These are the false-positive executable checks from the recorded
            # report. Hashes are current and self-consistent, so only semantic
            # validation can reject them.
            p169 = (root / rel169).read_text()
            self.assertRegex(p169, r"c\.plan_pins\.length\s*!==\s*174")
            self.assertRegex(p169, r"c\.halted_plans\.length\s*!==\s*22")
            self.assertIn("149 -> 174", p169)
            self.assertIn("158 -> 174", p169)
            self.assertIn("167 -> 174", p169)
            self.assertIn("173 -> 174", p169)
            with self.assertRaisesRegex(successor.ContractError, "executable.*(180|24|73)|stale executable"):
                successor.validate_bridge(root, "entry", record_path)

    def test_full_dryrun_requires_native_output_and_matching_count(self):
        good = valid_log()
        self.assertEqual(successor.parse_log(good)["count"], 79)
        for changed in (good.replace(b"Ran 79 tests in 0.001s\n\nOK\n", b""),
                        good.replace(b"Ran 79 tests in 0.001s", b"Ran 78 tests in 0.001s")):
            with self.assertRaises(successor.ContractError):
                successor.parse_log(changed)

    def test_rehashed_168_and_169_amendments_cannot_change_request_or_budget_limits(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-contract-diff-") as temp:
            root = pathlib.Path(temp)
            original = {}
            for number in (168, 169):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                original[rel] = (ROOT / rel).read_bytes()
            (root / successor.R12_CONTRACT).parent.mkdir(parents=True, exist_ok=True)
            (root / successor.R12_CONTRACT).write_bytes((ROOT / successor.R12_CONTRACT).read_bytes())
            amend_entry_plans(root, original)
            for number in (168, 169):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                before = original[rel].decode("utf-8")
                after = (root / rel).read_text(encoding="utf-8")
                successor.validate_contract_limits(before, after, rel, root)
                lines = after.splitlines()
                if number == 168:
                    index = next(i for i, line in enumerate(lines) if ".projected_total_requests <= 22" in line)
                    lines[index] = lines[index].replace(".projected_total_requests <= 22", ".projected_total_requests <= 23", 1)
                else:
                    index = next(i for i, line in enumerate(lines) if "pages<=10" in line)
                    lines[index] = lines[index].replace("pages<=10", "pages<=11", 1)
                with self.subTest(plan=number), self.assertRaisesRegex(
                        successor.ContractError, "request/retry/time/page/size contract limits changed"):
                    successor.validate_contract_limits(before, "\n".join(lines), rel, root)
                if number == 169:
                    unapproved = after.replace('plan: "169"', 'plan: "999"', 1)
                    with self.assertRaisesRegex(successor.ContractError, "unapproved plan instruction diff"):
                        successor.validate_scoped_plan_diff(before, unapproved, rel, root)
                    empty_owner_table = after.replace("149 -> 179", "", 1)
                    with self.assertRaises(successor.ContractError):
                        successor.validate_scoped_plan_diff(before, empty_owner_table, rel, root)

            before = original[f"{PHASE}/253-168-PLAN.md"].decode("utf-8")
            after = (root / f"{PHASE}/253-168-PLAN.md").read_text(encoding="utf-8")
            composed = after.replace("Task 1", "Å", 1)
            decomposed = after.replace("Task 1", "A\u030a", 1)
            self.assertNotEqual(composed.encode("utf-8"), decomposed.encode("utf-8"))
            self.assertEqual(unicodedata.normalize("NFC", composed), unicodedata.normalize("NFC", decomposed))
            for changed in (composed, decomposed):
                with self.assertRaises(successor.ContractError):
                    successor.validate_scoped_plan_diff(before, changed, f"{PHASE}/253-168-PLAN.md", root)

    def test_prepare_transformation_matches_independent_expected_script(self):
        plan = (ROOT / successor.PLAN_174).read_bytes()
        body = successor.command_body(plan, successor.PLAN_174)
        actual, stats = successor.expected_acceptance_body(body)

        # Independent construction from the frozen command text and reviewed edits.
        expected = body.replace("253-174", "253-179")
        old = "grep -v -e '^$' -e '^scripts/ci/ci-hermetic-live-audit.test.py$'"
        new = ("grep -v -e '^$' -e '^scripts/ci/ci-hermetic-live-audit.test.py$' "
               "-e '^scripts/ci/ci-git-publication.test.py$'")
        self.assertEqual(expected.count(old), 1)
        expected = expected.replace(old, new, 1)
        for name, invocation in successor.SUITES:
            if name == "full-dryrun":
                start = f"printf 'SUITE-START {name}\\n' && "
                expected = expected.replace("{ python3 scripts/ci/ci-gate-canary-dryrun.test.py >",
                                            start + "{ python3 scripts/ci/ci-gate-canary-dryrun.test.py >", 1)
                native_count = "printf 'FULL-DRYRUN-COUNT %s\\n' \"$DRYRUN_TEST_COUNT\""
                expected = expected.replace(native_count, native_count + f" && printf 'SUITE-PASS {name}\\n'", 1)
            else:
                expected = expected.replace(invocation, successor.suite_command(name, invocation), 1)
        self.assertEqual(actual, expected)
        self.assertEqual(stats["attempt_identifier_substitutions"], body.count("253-174"))
        self.assertEqual(stats["product_allowlist_substitutions"], 1)
        self.assertEqual(stats["suite_start_markers"], 10)
        self.assertEqual(stats["suite_pass_markers"], 10)
        self.assertIn("FULL_RC=$?", actual)
        self.assertIn('test "$FULL_RC" -eq 0', actual)
        self.assertIn("test \"$DRYRUN_TEST_COUNT\" -ge 79", actual)
        self.assertEqual(actual.count("ci-git-publication.test.py"), body.count("ci-git-publication.test.py") + 1)
        syntax = subprocess.run(["bash", "-n"], input=actual, text=True, capture_output=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)

    def test_each_suite_spy_failure_keeps_exit_and_stops_later_suites_and_receipt(self):
        names = [name for name, _ in successor.SUITES if name != "full-dryrun"]
        source = successor.command_body((ROOT / successor.PLAN_174).read_bytes(), successor.PLAN_174)
        generated, _ = successor.expected_acceptance_body(source)
        for failed_index, failed_name in enumerate(names):
            with self.subTest(suite=failed_name), tempfile.TemporaryDirectory(prefix="sigra-253-suite-spy-") as temp:
                root = pathlib.Path(temp)
                trace = root / "trace"
                receipt = root / "receipt"
                commands = []
                for name in names:
                    actual_wrapper = successor.suite_command(name, dict(successor.SUITES)[name])
                    self.assertIn(f"SUITE-START {name}", generated)
                    self.assertIn(f"SUITE-PASS {name}", generated)
                    # Execute the exact generated wrapper after swapping only its
                    # production invocation for an inert failure-injection spy.
                    commands.append(actual_wrapper.replace(dict(successor.SUITES)[name], f"spy {name}", 1))
                script = "\n".join([
                    f"TRACE={str(trace)}", f"RECEIPT={str(receipt)}",
                    "spy() { printf '%s\\n' \"$1\" >> \"$TRACE\"; [ \"$1\" != \"" + failed_name + "\" ]; }",
                    " && ".join(commands) + " && touch \"$RECEIPT\"",
                ])
                run = subprocess.run(["bash", "-c", script], text=True, capture_output=True)
                self.assertNotEqual(run.returncode, 0)
                output = run.stdout
                self.assertIn(f"SUITE-START {failed_name}", output)
                self.assertNotIn(f"SUITE-PASS {failed_name}", output)
                for later in names[failed_index + 1:]:
                    self.assertNotIn(later, trace.read_text() if trace.exists() else "")
                self.assertFalse(receipt.exists())

    def test_full_dryrun_failure_does_not_print_pass_or_continue(self):
        source = successor.command_body((ROOT / successor.PLAN_174).read_bytes(), successor.PLAN_174)
        generated, _ = successor.expected_acceptance_body(source)
        self.assertIn("SUITE-START full-dryrun", generated)
        self.assertIn('FULL_RC=$?', generated)
        # This is the exact generated full-dryrun success gate with its native
        # command represented by a failing spy and its real output capture kept.
        script = ("printf 'SUITE-START full-dryrun\\n' && { spy full-dryrun > \"$2\" 2>&1; "
                  "FULL_RC=$?; cat \"$2\"; test \"$FULL_RC\" -eq 0; } && "
                  "printf 'FULL-DRYRUN-COUNT %s\\n' 79 && "
                  "printf 'SUITE-PASS full-dryrun\\n' && touch \"$1\"")
        with tempfile.TemporaryDirectory(prefix="sigra-253-full-spy-") as temp:
            receipt = pathlib.Path(temp) / "receipt"
            log = pathlib.Path(temp) / "native.log"
            run = subprocess.run(["bash", "-c", "spy() { printf 'Injected failing spy\\n'; return 17; }; " + script,
                                 "bash", str(receipt), str(log)], text=True, capture_output=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("SUITE-START full-dryrun", run.stdout)
            self.assertNotIn("SUITE-PASS full-dryrun", run.stdout)
            self.assertFalse(receipt.exists())

    def test_log_parser_accepts_only_complete_ordered_native_evidence(self):
        parsed = successor.parse_log(valid_log())
        self.assertEqual(parsed["count"], 79)
        self.assertEqual(parsed["largest_tree_body_bytes"], 2096775)
        self.assertEqual(parsed["remaining_tree_bytes"], 377)
        cases = {
            "empty": b"",
            "invalid utf8": b"\xff",
            "no final sentinel": valid_log().replace(b"VERIFY-EXIT 0\n", b""),
            "nonzero final sentinel": valid_log().replace(b"VERIFY-EXIT 0", b"VERIFY-EXIT 1"),
            "missing count": valid_log().replace(b"FULL-DRYRUN-COUNT 79\n", b""),
            "duplicate count": valid_log().replace(b"FULL-DRYRUN-COUNT 79", b"FULL-DRYRUN-COUNT 79\nFULL-DRYRUN-COUNT 79"),
            "below minimum": valid_log().replace(b"FULL-DRYRUN-COUNT 79", b"FULL-DRYRUN-COUNT 78"),
            "missing later gate": valid_log().replace(b"SUITE-PASS gate-canary-recovery\n", b""),
            "duplicate marker": valid_log().replace(b"SUITE-PASS gate-canary-recovery\n", b"SUITE-PASS gate-canary-recovery\nSUITE-PASS gate-canary-recovery\n"),
            "markers without native unittest result": valid_log().replace(b"Ran 3 tests in 0.001s\n\nOK\n", b"", 1),
            "zero tests executed": valid_log().replace(b"Ran 3 tests in 0.001s", b"Ran 0 tests in 0.001s", 1),
            "projection largest mismatch": valid_log().replace(b'"largest_tree_body_bytes":2096775', b'"largest_tree_body_bytes":1024'),
            "projection cap mismatch": valid_log().replace(b'"max_tree_body_bytes":2097152', b'"max_tree_body_bytes":2097151'),
            "projection merge failure": valid_log().replace(b'"clean":true,"conflicts":[],"exit":0', b'"clean":false,"conflicts":["mix.exs"],"exit":1'),
            "null projection object": valid_log().replace(b"PROJECTION {", b"PROJECTION null", 1),
            "nonobject paged result": valid_log().replace(b"PAGED-FULL-PASS {", b"PAGED-FULL-PASS []", 1),
            "empty required request set": valid_log().replace(b'"requests_by_category":{"preflight":7}', b'"requests_by_category":{}', 1),
            "empty tree list": valid_log().replace(b'"tree_requests":[{"body_bytes":2096775},{"body_bytes":1024}]', b'"tree_requests":[]'),
            "over cap tree": valid_log().replace(b'"body_bytes":2096775', b'"body_bytes":2097153'),
            "empty tree body": valid_log().replace(b'"body_bytes":2096775', b'"body_bytes":0'),
            "altered parent": valid_log().replace(b"09df342a82e03c3d5d40173c912b70e827f7eadc", b"f" * 40),
            "missing probe": valid_log().replace(b"PERMISSION-PREFLIGHT ", b"PERMISSION-PREFLIGHT-REMOVED "),
        }
        for label, raw in cases.items():
            with self.subTest(label=label), self.assertRaises(successor.ContractError):
                successor.parse_log(raw)

    def test_preflight_binds_root_call_plan_script_pid_probe_and_readback(self):
        log = successor.parse_log(valid_log())
        prepared = {"source_commit": "a" * 40, "plan179_body_sha256": "d" * 64,
                    "generated_script_sha256": "e" * 64}
        with tempfile.TemporaryDirectory(prefix="sigra-253-preflight-") as temp:
            root = pathlib.Path(temp)
            good = valid_preflight()
            successor.validate_preflight(root, good, log, prepared, root)
            corruptions = [
                lambda x: x.update(acceptance_pid=413),
                lambda x: x.update(acceptance_source="f" * 40),
                lambda x: x.update(acceptance_exit=1),
                lambda x: x["launch"].update(sandbox_permissions="sandboxed"),
                lambda x: x["launch"].update(block_sha256="f" * 64),
                lambda x: x["launch"].update(generated_script_sha256="f" * 64),
                lambda x: x["launch"].update(tool_call_id=""),
                lambda x: x["probe"].update(readback_sha256="f" * 64),
                lambda x: x["probe"].update(command=["git", "status"]),
                lambda x: x.update(once_only=False),
            ]
            for mutate in corruptions:
                bad = json.loads(json.dumps(good))
                mutate(bad)
                with self.subTest(corruption=mutate), self.assertRaises(successor.ContractError):
                    successor.validate_preflight(root, bad, log, prepared, root)

    def test_nested_173_review_requires_original_location_schema_and_findings(self):
        real = (ROOT / successor.REVIEW_173).read_bytes()
        with tempfile.TemporaryDirectory(prefix="sigra-253-review-fixture-") as temp:
            root = pathlib.Path(temp)
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            alternates = root / ".git/objects/info/alternates"
            alternates.parent.mkdir(parents=True, exist_ok=True)
            alternates.write_text(str((ROOT / ".git/objects").resolve()) + "\n", encoding="utf-8")
            for rel in successor.HISTORICAL_SHA256:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / rel).read_bytes())
            for rel, commit in {**successor.FROZEN_175_COMMITS, **successor.FROZEN_178_COMMITS}.items():
                self.assertEqual(successor.git(root, "show", f"{commit}:{rel}"), (root / rel).read_bytes())
            self.assertEqual(successor.check_historical_inputs(root)["findings"], 10)
            parsed = json.loads(real)
            parsed["product_changes"] = []
            del parsed["status_dispositions"]["product_changes"]
            (root / successor.REVIEW_173).write_text(json.dumps(parsed), encoding="utf-8")
            rel = f"{PHASE}/253-173-RECOVERY-REVIEW.json"
            with mock.patch.dict(successor.HISTORICAL_SHA256, {rel: hashlib.sha256((root / rel).read_bytes()).hexdigest()}), \
                    mock.patch.object(successor, "REVIEW_173_SHA256", hashlib.sha256((root / rel).read_bytes()).hexdigest()):
                with self.assertRaisesRegex(successor.ContractError, "status_dispositions.product_changes"):
                    successor.check_historical_inputs(root)

    def test_enter_is_once_only_and_rechecks_prepared_commit_and_script(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-enter-") as temp:
            root = pathlib.Path(temp) / "repo"
            attempt = pathlib.Path(temp) / "attempt"
            root.mkdir()
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "fixture@example.test"], check=True)
            (root / "input").write_text("unchanged\n")
            subprocess.run(["git", "-C", str(root), "add", "input"], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "fixture"], check=True)
            commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            attempt.mkdir()
            script = attempt / "acceptance.sh"
            script.write_text("exit 0\n")
            (attempt / "prepared.json").write_text(json.dumps({"source_commit": commit,
                "generated_script_sha256": hashlib.sha256(script.read_bytes()).hexdigest()}))
            successor.enter(root, attempt)
            with self.assertRaisesRegex(successor.ContractError, "already been entered"):
                successor.enter(root, attempt)

    def test_bridge_accepts_exact_five_plan_amendment_fixture(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-bridge-") as temp:
            root = pathlib.Path(temp)
            shutil.copytree(ROOT / ".planning", root / ".planning")
            phase = root / PHASE
            original = {}
            for number in (*range(168, 173), 176, 177):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                source = (ROOT / rel).read_bytes()
                (root / rel).write_bytes(source)
                original[rel] = source
            (root / successor.R12_CONTRACT).write_bytes((ROOT / successor.R12_CONTRACT).read_bytes())
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "fixture@example.test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "original plans"], check=True)
            source_commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            ref = successor.ORIGINALS_180
            subprocess.run(["git", "-C", str(root), "update-ref", ref, source_commit], check=True)
            # Preserve every cap/control line while applying only entry amendments.
            amend_entry_plans(root, original)
            good169 = (root / f"{PHASE}/253-169-PLAN.md").read_text()
            changed_plans = {f"{PHASE}/253-168-PLAN.md", f"{PHASE}/253-169-PLAN.md"}
            amended = {rel: hashlib.sha256((root / rel).read_bytes()).hexdigest() for rel in changed_plans}
            pins = {}
            for rel, data in original.items():
                oid = subprocess.check_output(["git", "-C", str(root), "hash-object", "--stdin"], input=data).decode().strip()
                pins[rel] = {"blob": oid, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
            source_paths = {row.split(b"\t", 1)[1].decode() for row in subprocess.check_output(
                ["git", "-C", str(root), "ls-tree", "-rz", "-r", source_commit, "--", PHASE,
                 ".planning/phases/252-measure-current-ci"]).split(b"\0") if row}
            protected = {rel: hashlib.sha256(subprocess.check_output(
                ["git", "-C", str(root), "show", f"{source_commit}:{rel}"])).hexdigest()
                         for rel in source_paths}
            record = {"schema": successor.BRIDGE_SCHEMA, "stage": "entry", "source_commit": source_commit,
                      "preservation_ref": ref, "originals": pins, "amended_sha256": amended,
                      "protected_source_bindings": protected,
                      "dispositions_for": []}
            record_path = f"{PHASE}/253-180-BRIDGE-RECORD.json"
            (root / record_path).write_text(json.dumps(record))
            self.assertEqual(successor.validate_bridge(root, "entry", record_path)["status"], "verified")
            good168 = (root / f"{PHASE}/253-168-PLAN.md").read_text()
            receipt_prefix = ("python3 -B .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/"
                              "253-RECOVERY-SUCCESSOR.py verify-receipt --consumer 168 || exit $?; ")
            receipt_attacks = (
                ("missing", lambda body: body.replace(receipt_prefix, "", 1)),
                ("late", lambda body: body.replace(receipt_prefix, "printf before; " + receipt_prefix, 1)),
                ("duplicate", lambda body: body.replace(receipt_prefix, receipt_prefix + receipt_prefix, 1)),
                ("ignored", lambda body: body.replace("|| exit $?;", ";", 1)),
            )
            good168_bodies = re.findall(r"<automated>(.*?)</automated>", good168, re.S)
            for label, mutate_body in receipt_attacks:
                for body_index in range(2):
                    bad_bodies = list(good168_bodies)
                    bad_bodies[body_index] = mutate_body(bad_bodies[body_index])
                    self.assertNotEqual(bad_bodies[body_index], good168_bodies[body_index])
                    bad168 = re.sub(r"<automated>.*?</automated>",
                                    lambda match, it=iter(bad_bodies): "<automated>" + next(it) + "</automated>",
                                    good168, count=2, flags=re.S)
                    (root / f"{PHASE}/253-168-PLAN.md").write_text(bad168)
                    bad_record = json.loads(json.dumps(record))
                    bad_record["amended_sha256"][f"{PHASE}/253-168-PLAN.md"] = hashlib.sha256(bad168.encode()).hexdigest()
                    (root / record_path).write_text(json.dumps(bad_record))
                    with self.subTest(stage="entry", label=label, body=body_index), self.assertRaisesRegex(
                            successor.ContractError, "168 receipt check must appear exactly once at the start"):
                        successor.validate_bridge(root, "entry", record_path)
                    (root / f"{PHASE}/253-168-PLAN.md").write_text(good168)
                    (root / record_path).write_text(json.dumps(record))
            executable_bodies = re.findall(r"<automated>(.*?)</automated>", good169, re.S)
            script_match = re.search(r'(?:node|"\$N")\s+-e\s+\'(.*?)\'', executable_bodies[2], re.S)
            self.assertIsNotNone(script_match)
            valid_script = script_match.group(1)
            attacks = (
                ("restored174pin", "EXPECTED_PLAN_IDS", "253-181", "253-177", "181-plan-pin set"),
                ("omitted176target", "EXPECTED_TARGET_IDS", "253-176", "253-175", "73 target set"),
                ("omitted177target", "EXPECTED_TARGET_IDS", "253-177", "253-175", "73 target set"),
                ("omitted175halt", "EXPECTED_HALT_IDS", "253-175", "253-174", "27 halt set"),
                ("omitted178halt", "EXPECTED_HALT_IDS", "253-178", "253-177", "27 halt set"),
                ("old181pinCount", "c.plan_pins.length!==183", "c.plan_pins.length!==183", "c.plan_pins.length!==181", "stale count"),
                ("old25haltCount", "c.halted_plans.length!==27", "c.halted_plans.length!==27", "c.halted_plans.length!==25", "stale count"),
                ("old71targetCount", "c.responsibilities.length!==73", "c.responsibilities.length!==73", "c.responsibilities.length!==71", "stale count"),
            )
            for label, name, needle, replacement, reason in attacks:
                with self.subTest(label=label):
                    self.assertIn(needle, valid_script)
                    mutated_script = valid_script.replace(needle, replacement, 1)
                    self.assertNotEqual(mutated_script, valid_script)
                    mutated = good169.replace(valid_script, mutated_script, 1)
                    (root / f"{PHASE}/253-169-PLAN.md").write_text(mutated)
                    bad_record = json.loads(json.dumps(record))
                    bad_record["amended_sha256"][f"{PHASE}/253-169-PLAN.md"] = hashlib.sha256(mutated.encode()).hexdigest()
                    (root / record_path).write_text(json.dumps(bad_record))
                    with self.assertRaisesRegex(successor.ContractError, reason):
                        successor.validate_bridge(root, "entry", record_path)
            owner_mutations = (("owner149", "149 -> 179", "149 -> 174"),
                               ("owner158", "158 -> 179", "158 -> 174"),
                               ("owner167", "167 -> 179", "167 -> 174"),
                               ("owner173", "173 -> 179", "173 -> 174"),
                               ("owner174", "174 -> [181, 179]", "174 -> [178, 179]"),
                               ("owner175", "175 -> [181, 179]", "175 -> [178, 179]"),
                               ("owner178", "178 -> [181, 179]", "178 -> [178, 179]"))
            for label, needle, replacement in owner_mutations:
                with self.subTest(label=label):
                    mutated = good169.replace(needle, replacement, 1)
                    self.assertNotEqual(mutated, good169)
                    (root / f"{PHASE}/253-169-PLAN.md").write_text(mutated)
                    bad_record = json.loads(json.dumps(record))
                    bad_record["amended_sha256"][f"{PHASE}/253-169-PLAN.md"] = hashlib.sha256(mutated.encode()).hexdigest()
                    (root / record_path).write_text(json.dumps(bad_record))
                    with self.assertRaisesRegex(successor.ContractError, "ownership table"):
                        successor.validate_bridge(root, "entry", record_path)
            (root / f"{PHASE}/253-169-PLAN.md").write_text(good169)
            (root / record_path).write_text(json.dumps(record))
            # A sixth altered file or unrecorded one-file edit cannot pass.
            (root / f"{PHASE}/253-168-PLAN.md").write_text("depends_on: [\"253-177\"]\nverify-receipt --consumer 168\nextra\n")
            with self.assertRaisesRegex(successor.ContractError, "amendment hash"):
                successor.validate_bridge(root, "entry", record_path)
            # Rebuild the positive fixture from the source bytes; never carry a
            # deliberately corrupted file into the complete-stage assertion.
            amend_complete_plans(root, original)
            record["stage"] = "complete"
            record["amended_sha256"] = {
                rel: hashlib.sha256((root / rel).read_bytes()).hexdigest()
                for rel in (f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173))}
            record["sdk_copy"] = {"report_path": "/tmp/fixture-sdk-report.json",
                                  "report_sha256": "0" * 64}
            (root / record_path).write_text(json.dumps(record))
            with mock.patch.object(successor, "validate_sdk_copy_report", return_value={"status": "passed"}):
                self.assertEqual(successor.validate_bridge(root, "complete", record_path)["status"], "verified")
                for label, mutate_body in receipt_attacks:
                    for body_index in range(2):
                        good168 = (root / f"{PHASE}/253-168-PLAN.md").read_text()
                        good168_bodies = re.findall(r"<automated>(.*?)</automated>", good168, re.S)
                        bad_bodies = list(good168_bodies)
                        bad_bodies[body_index] = mutate_body(bad_bodies[body_index])
                        bad168 = re.sub(r"<automated>.*?</automated>",
                                        lambda match, it=iter(bad_bodies): "<automated>" + next(it) + "</automated>",
                                        good168, count=2, flags=re.S)
                        (root / f"{PHASE}/253-168-PLAN.md").write_text(bad168)
                        bad_record = json.loads(json.dumps(record))
                        bad_record["amended_sha256"][f"{PHASE}/253-168-PLAN.md"] = hashlib.sha256(bad168.encode()).hexdigest()
                        (root / record_path).write_text(json.dumps(bad_record))
                        with self.subTest(stage="complete", label=label, body=body_index), self.assertRaisesRegex(
                                successor.ContractError, "168 receipt check must appear exactly once at the start"):
                            successor.validate_bridge(root, "complete", record_path)
                        (root / f"{PHASE}/253-168-PLAN.md").write_text(good168)
                        (root / record_path).write_text(json.dumps(record))
                # A cap edit is refused even when its changed-file hash is self-consistent.
                p170 = root / f"{PHASE}/253-170-PLAN.md"
                p170.write_bytes(p170.read_bytes().replace(b"at most 24 publication-category requests",
                                                            b"at most 25 publication-category requests", 1))
                record["amended_sha256"][f"{PHASE}/253-170-PLAN.md"] = hashlib.sha256(p170.read_bytes()).hexdigest()
                (root / record_path).write_text(json.dumps(record))
                with self.assertRaisesRegex(successor.ContractError, "request/retry/time/page/size contract limits changed"):
                    successor.validate_bridge(root, "complete", record_path)

    def _exercise_bridge_mutations(self, complete=False):
        with tempfile.TemporaryDirectory(prefix="sigra-253-bridge-mutations-") as temp:
            root = pathlib.Path(temp)
            phase = root / PHASE
            phase.mkdir(parents=True)
            originals = {}
            for number in (*range(168, 173), 176, 177):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                raw = (ROOT / rel).read_bytes()
                originals[rel] = raw
                (root / rel).write_bytes(raw)
            (root / successor.R12_CONTRACT).parent.mkdir(parents=True, exist_ok=True)
            (root / successor.R12_CONTRACT).write_bytes((ROOT / successor.R12_CONTRACT).read_bytes())
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Fixture"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "fixture@example.test"], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "original plans"], check=True)
            source = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            ref = successor.ORIGINALS_180
            subprocess.run(["git", "-C", str(root), "update-ref", ref, source], check=True)
            (amend_complete_plans if complete else amend_entry_plans)(root, originals)
            good168 = (root / f"{PHASE}/253-168-PLAN.md").read_text()
            good169 = (root / f"{PHASE}/253-169-PLAN.md").read_text()
            original172 = originals[f"{PHASE}/253-172-PLAN.md"].decode()
            good172 = (root / f"{PHASE}/253-172-PLAN.md").read_text()
            changed_plans = {f"{PHASE}/253-168-PLAN.md", f"{PHASE}/253-169-PLAN.md"}
            if complete:
                changed_plans = {f"{PHASE}/253-{n}-PLAN.md" for n in range(168, 173)}
            amended = {rel: hashlib.sha256((root / rel).read_bytes()).hexdigest() for rel in changed_plans}
            pins = {}
            for rel, raw in originals.items():
                oid = subprocess.check_output(["git", "-C", str(root), "hash-object", "--stdin"], input=raw).decode().strip()
                pins[rel] = {"blob": oid, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
            source_paths = {row.split(b"\t", 1)[1].decode() for row in subprocess.check_output(
                ["git", "-C", str(root), "ls-tree", "-rz", "-r", source, "--", PHASE,
                 ".planning/phases/252-measure-current-ci"]).split(b"\0") if row}
            protected = {rel: hashlib.sha256(subprocess.check_output(
                ["git", "-C", str(root), "show", f"{source}:{rel}"])).hexdigest() for rel in source_paths}
            record = {"schema": successor.BRIDGE_SCHEMA, "stage": "entry", "source_commit": source,
                      "preservation_ref": ref, "originals": pins, "amended_sha256": amended,
                      "protected_source_bindings": protected,
                      "dispositions_for": []}
            record_path = f"{PHASE}/253-180-BRIDGE-RECORD.json"
            stage = "complete" if complete else "entry"
            record["stage"] = stage
            if complete:
                record["sdk_copy"] = {"report_path": "/tmp/labeled-unit-spy.json", "report_sha256": "0" * 64}
            (root / record_path).write_text(json.dumps(record))
            changes = []
            if complete:
                links = re.findall(r"(?m)^- (\w+) = (.+)$", good172)
                self.assertEqual(len(links), 8)
                for label, link in links:
                    anchor = "- " + label + " = " + link
                    self.assertEqual(good172.count(anchor), 1)
                    changes.append((label, f"{PHASE}/253-172-PLAN.md", good172.replace(anchor, anchor + " changed", 1), "^" + re.escape("request/retry/time/page/size contract limits changed outside the exact amendment in " + f"{PHASE}/253-172-PLAN.md") + "$"))
                for number in (170, 171):
                    rel = f"{PHASE}/253-{number}-PLAN.md"
                    good = (root / rel).read_text()
                    for label, pattern in (("task", r"<name>"), ("command", r"<automated>"), ("approval", r"<action>")):
                        self.assertGreater(good.count(pattern), 0)
                        changes.append((f"{number}-{label}", rel, good.replace(pattern, pattern + "changed ", 1), "^" + re.escape("request/retry/time/page/size contract limits changed outside the exact amendment in " + rel) + "$"))
            else:
                bodies = re.findall(r"<automated>(.*?)</automated>", good169, re.S)
                script = re.findall(r"(?:node|\"\$N\")\s+-e\s+\'(.*?)\'", bodies[2], re.S)
                self.assertEqual(len(script), 1)
                anchor = "c.halted_plans.length!==25"
                self.assertEqual(script[0].count(anchor), 1)
                mutated = good169.replace(script[0], script[0].replace(anchor, "c.halted_plans.length!==22", 1), 1)
                changes.append(("22-halt", f"{PHASE}/253-169-PLAN.md", mutated, "^169 executable reconciliation assertion has a stale count$"))
                anchor = "253-175-EXECUTION-RECORD.json"
                self.assertEqual(good169.count(anchor), 1)
                changes.append(("pin", f"{PHASE}/253-169-PLAN.md", good169.replace(anchor, "", 1), "ownership table"))
                changes.append(("stale174", f"{PHASE}/253-168-PLAN.md", 'depends_on: ["253-180"]\n253-174-RECOVERY-RECEIPT.json\n', "168"))
            # The spy is only the report seam of complete-stage semantic unit tests.
            with mock.patch.object(successor, "validate_sdk_copy_report", return_value={"status": "passed"}) if complete else mock.patch.dict({}, {}):
                for label, rel, changed, reason in changes:
                    with self.subTest(label=label):
                        path = root / rel
                        good_bytes = path.read_bytes()
                        self.assertEqual(successor.validate_bridge(root, stage, record_path)["status"], "verified")
                        bad_bytes = changed.encode("utf-8")
                        self.assertNotEqual(bad_bytes, good_bytes)
                        self.assertNotEqual(hashlib.sha256(bad_bytes).hexdigest(), hashlib.sha256(good_bytes).hexdigest())
                        bad = json.loads(json.dumps(record))
                        bad["amended_sha256"][rel] = hashlib.sha256(bad_bytes).hexdigest()
                        try:
                            path.write_bytes(bad_bytes)
                            (root / record_path).write_text(json.dumps(bad))
                            self.assertEqual(path.read_bytes(), bad_bytes)
                            with self.assertRaisesRegex(successor.ContractError, reason):
                                successor.validate_bridge(root, stage, record_path)
                        finally:
                            path.write_bytes(good_bytes)
                            (root / record_path).write_text(json.dumps(record))
                        self.assertEqual(successor.validate_bridge(root, stage, record_path)["status"], "verified")

    def test_bridge_rejects_stale_174_routes_22_halts_pins_and_hosted_link_edits(self):
        self._exercise_bridge_mutations()

    def test_historical_25_to_22_mutation_changes_bytes_and_refuses(self):
        raw = subprocess.check_output(["git", "-C", str(ROOT), "show", "c88c3f8d96b490abe49cd2812c491fc7dd04b400:" + str(HELPER_PATH.relative_to(ROOT))])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "14b1aba3aceca988aaf201f25b8fc84995e5766cac7a36c600e46b4a087d10b5")
        import types, sys
        frozen = types.ModuleType("frozen_successor181")
        frozen.__file__ = str(HELPER_PATH)
        with mock.patch.dict(sys.modules, {frozen.__name__: frozen}):
            exec(compile(raw, str(HELPER_PATH), "exec"), frozen.__dict__)
            with mock.patch.dict(globals(), successor=frozen):
                self._exercise_bridge_mutations()

    def test_complete_bridge_rejects_hosted_link_edits_at_complete_stage(self):
        self._exercise_bridge_mutations(complete=True)

    def test_installed_sdk_copy_executes_queries_and_proves_full_route(self):
        temp = tempfile.TemporaryDirectory(prefix="sigra-253-sdk-amended-route-")
        self.addCleanup(temp.cleanup)
        project = pathlib.Path(temp.name) / "project"
        project.mkdir()
        shutil.copytree(ROOT / ".planning", project / ".planning")
        originals = {f"{PHASE}/253-{n}-PLAN.md": (ROOT / f"{PHASE}/253-{n}-PLAN.md").read_bytes()
                     for n in (*range(168, 173), 176, 177)}
        amend_complete_plans(project, originals)
        # A disposable plan copy models the future183 repair route. The actual
        # installed SDK must show168 runnable only after the completed183 fixture.
        amend_repair_183_route(project)
        plan179 = project / PHASE / "253-179-PLAN.md"
        self.assertIn('depends_on: ["253-183"]', plan179.read_text(encoding="utf-8"))
        subprocess.run(["git", "-C", str(project), "init", "-q"], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(project), "config", "user.name", "SDK Fixture"], check=True)
        subprocess.run(["git", "-C", str(project), "config", "user.email", "sdk-fixture@example.test"], check=True)
        (project / ".planning/unrelated-fixture-input.txt").write_text("source-bound\n")
        subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "committed amended SDK fixture"], check=True)
        result = successor.run_sdk_copy(project, {}, "unused")
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["readiness_168_runnable"])
        self.assertTrue(result["readiness_175_halted"])
        self.assertEqual(result["post_chain_incomplete"], 0)
        self.assertEqual(result["post_chain_halted"], 27)
        self.assertEqual(len(result["disposition_ids"]), 73)
        self.assertTrue(result["source_copy_commit"])
        self.assertEqual(set(result["sdk_queries"]), {"readiness_init", "readiness_index", "post_init", "post_index"})
        self.assertTrue(all(row["stdout_sha256"] for row in result["sdk_queries"].values()))
        self.assertTrue(result["source_input_manifest_sha256"])
        with tempfile.TemporaryDirectory(prefix="sigra-253-sdk-report-") as temp:
            report_path = pathlib.Path(temp) / "sdk-report.json"

            def persist(report):
                raw = (json.dumps(report, sort_keys=True, indent=2) + "\n").encode()
                report_path.write_bytes(raw)
                return {"report_path": str(report_path), "report_sha256": hashlib.sha256(raw).hexdigest()}

            def rewrite_query(report, name, update):
                output = report["sdk_queries"][name]
                parsed = json.loads(output["stdout"])
                update(parsed)
                output["stdout"] = json.dumps(parsed, sort_keys=True, separators=(",", ":"))
                output["stdout_sha256"] = hashlib.sha256(output["stdout"].encode("utf-8")).hexdigest()

            self.assertEqual(successor.validate_sdk_copy_report(project, persist(result))["status"], "passed")
            mutations = {
                "invalid raw JSON": lambda report: report["sdk_queries"]["readiness_init"].update(
                    stdout="not JSON", stdout_sha256=hashlib.sha256(b"not JSON").hexdigest()),
                "empty SDK output": lambda report: report["sdk_queries"]["readiness_init"].update(
                    stdout="", stdout_sha256=hashlib.sha256(b"").hexdigest()),
                "bogus query args": lambda report: report["sdk_queries"]["readiness_index"].update(
                    arguments=["bogus"], argv=["bogus"]),
                "wrong SDK identity": lambda report: report.update(sdk_identity={}),
                "self-consistent wrong source digest": lambda report: report.update(
                    source_input_manifest_sha256="f" * 64),
                "altered manifest with recomputed digest": lambda report: (
                    report["source_input_manifest"][0].update(sha256="f" * 64),
                    report.update(source_input_manifest_sha256=successor.sha256(
                        successor.canonical_json_bytes(report["source_input_manifest"]))))[-1],
                "valid JSON with unknown plan ID": lambda report: rewrite_query(
                    report, "readiness_index", lambda value: value["plans"][0].update(id="253-999")),
                "valid JSON with false runnable list": lambda report: rewrite_query(
                    report, "readiness_init", lambda value: value.update(runnable_plans=[])),
                "invalid UTF-8 stdout text": lambda report: report["sdk_queries"]["readiness_init"].update(
                    stdout="\udcff", stdout_sha256="0" * 64),
                "non-object SDK output": lambda report: report["sdk_queries"]["post_init"].update(
                    stdout="null", stdout_sha256=hashlib.sha256(b"null").hexdigest()),
                "malformed raw digest": lambda report: report["sdk_queries"]["post_index"].update(
                    stdout_sha256="g" * 64),
                "blocked summary status claim": lambda report: report.update(
                    post_chain_blocked_summaries=["253-176"]),
                "inconsistent redundant halted summary claim": lambda report: report.update(
                    post_chain_halted_ids=["253-175"]),
                "inconsistent redundant pre-query SHA": lambda report: report.update(
                    pre_simulation_init_sha256="f" * 64),
                "mismatched source-copy simulation identity": lambda report: report.update(
                    source_copy_commit="0" * 40),
            }
            expected_reasons = {
                "invalid raw JSON": "stdout is not strict UTF-8 JSON",
                "empty SDK output": "stdout is not strict UTF-8 JSON",
                "bogus query args": "query arguments differ",
                "wrong SDK identity": "identity differs",
                "self-consistent wrong source digest": "manifest digest differs",
                "altered manifest with recomputed digest": "manifest differs from Git",
                "valid JSON with unknown plan ID": "exact 253-01 through253-181 universe",
                "valid JSON with false runnable list": "168 as runnable",
                "invalid UTF-8 stdout text": "invalid UTF-8 text",
                "non-object SDK output": "stdout root must be an object",
                "malformed raw digest": "raw stdout hash differs",
                "blocked summary status claim": "blocked summary statuses",
                "inconsistent redundant halted summary claim": "halted IDs differ from parsed SDK output",
                "inconsistent redundant pre-query SHA": "redundant pre_simulation_init_sha256 differs",
                "mismatched source-copy simulation identity": "commit identities are malformed or inconsistent",
            }
            for label, mutate in mutations.items():
                bad = json.loads(json.dumps(result))
                mutate(bad)
                with self.subTest(report_mutation=label), self.assertRaisesRegex(
                        successor.ContractError, expected_reasons[label]):
                    successor.validate_sdk_copy_report(project, persist(bad))

            unrelated = project / ".planning/unrelated-fixture-input.txt"
            unrelated.write_text("different committed bytes\n")
            subprocess.run(["git", "-C", str(project), "add", str(unrelated.relative_to(project))], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "unrelated committed source mutation"], check=True)
            changed_source = json.loads(json.dumps(result))
            changed_source["source_input_commit"] = subprocess.check_output(
                ["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
            with self.assertRaisesRegex(successor.ContractError, "source manifest differs from Git"):
                successor.validate_sdk_copy_report(project, persist(changed_source))

    def test_committed_receipt_reopens_evidence_and_rejects_independent_corruptions(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-receipt-verify-") as temp:
            project = committed_receipt_fixture(temp)
            self.assertEqual(successor.verify_receipt(project)["status"], "verified")
            receipt_path = project / successor.RECEIPT_179
            log_path = project / f"{PHASE}/253-179-REGRESSION.log"
            preflight_path = project / f"{PHASE}/253-179-PERMISSION-PREFLIGHT.json"
            original_receipt = receipt_path.read_bytes()
            original_log = log_path.read_bytes()
            original_preflight = preflight_path.read_bytes()

            for non_object in (b"null\n", b"[]\n", b"\"receipt\"\n", b"{\xff}\n"):
                receipt_path.write_bytes(non_object)
                with self.assertRaises(successor.ContractError):
                    successor.verify_receipt(project)
            receipt_path.write_bytes(original_receipt)

            def commit_fixture(label):
                subprocess.run(["git", "-C", str(project), "add", "."], check=True)
                subprocess.run(["git", "-C", str(project), "commit", "-qm", label], check=True)

            def reject(label):
                with self.subTest(corruption=label):
                    commit_fixture("corruption " + label)
                    with self.assertRaises(successor.ContractError):
                        successor.verify_receipt(project)
                receipt_path.write_bytes(original_receipt)
                log_path.write_bytes(original_log)
                preflight_path.write_bytes(original_preflight)
                commit_fixture("restore " + label)

            for label, mutate in (
                    ("extra product file", lambda r: r["scope"].update(product_changes=[
                        "scripts/ci/ci-git-publication.test.py", "scripts/ci/unreviewed.py"])),
                    ("requirement overclaim", lambda r: r["requirements"].update({"CIREL-01": "accepted"})),
                    ("phase overclaim", lambda r: r.update(phase_verification_status="complete")),
                    ("old receipt plan lineage swap", lambda r: r.update(recovery_plan="253-174")),
                    ("shared source mismatch", lambda r: r["shared_sha256"].update({
                        ".planning/STATE.md": "f" * 64}))):
                receipt = json.loads(original_receipt)
                mutate(receipt)
                receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
                reject(label)

            for label, changed in (
                    ("empty log", b""),
                    ("malformed UTF-8", b"\xff"),
                    ("missing native count", original_log.replace(b"FULL-DRYRUN-COUNT 79\n", b"")),
                    ("duplicate native count", original_log.replace(
                        b"FULL-DRYRUN-COUNT 79\n", b"FULL-DRYRUN-COUNT 79\nFULL-DRYRUN-COUNT 79\n")),
                    ("count below threshold", original_log.replace(b"FULL-DRYRUN-COUNT 79", b"FULL-DRYRUN-COUNT 78")),
                    ("empty tree list", original_log.replace(
                        b'"tree_requests":[{"body_bytes":2096775},{"body_bytes":1024}]', b'"tree_requests":[]')),
                    ("serialized tree over cap", original_log.replace(b'"body_bytes":2096775', b'"body_bytes":2097153')),
                    ("missing last suite", original_log.replace(b"SUITE-PASS gate-canary-recovery\n", b""))):
                log_path.write_bytes(changed)
                receipt = json.loads(original_receipt)
                receipt["regression_log"]["sha256"] = hashlib.sha256(changed).hexdigest()
                receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
                reject(label)

            # Missing and empty launch artifacts are rejected before any success claim.
            log_path.unlink()
            receipt = json.loads(original_receipt)
            receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
            reject("missing log")
            preflight_path.write_bytes(b"")
            receipt = json.loads(original_receipt)
            receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
            reject("empty preflight")

            bad_preflight = json.loads(original_preflight)
            bad_preflight["launch"]["sandbox_permissions"] = "sandboxed"
            changed = (json.dumps(bad_preflight, sort_keys=True, indent=2) + "\n").encode()
            preflight_path.write_bytes(changed)
            receipt = json.loads(original_receipt)
            receipt["permission_preflight"]["sha256"] = hashlib.sha256(changed).hexdigest()
            receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
            reject("wrong elevated launch")

            old_receipt = project / f"{PHASE}/253-174-RECOVERY-RECEIPT.json"
            old_receipt.write_text("{}\n")
            commit_fixture("fabricated historical174 receipt")
            with self.assertRaisesRegex(successor.ContractError, "174 success receipt must remain absent"):
                successor.verify_receipt(project)

            # Consumer168 may see later committed shared planning movement because it
            # reopens the four original shared bytes at the receipt source commit.
            old_receipt.unlink()
            shared = project / ".planning/STATE.md"
            shared_bytes = shared.read_bytes()
            shared.write_bytes(shared_bytes + b"\nconsumer168 committed later state\n")
            commit_fixture("simulated root-owned shared state update")
            self.assertEqual(successor.verify_receipt(project, consumer="168")["status"], "verified")
            with self.assertRaises(successor.ContractError):
                successor.verify_receipt(project)

            # Old halted evidence is reopened independently of the new receipt/log.
            old174 = project / f"{PHASE}/253-174-REGRESSION.log"
            old174_original = old174.read_bytes()
            old174.write_bytes(old174_original + b"changed\n")
            with self.assertRaisesRegex(successor.ContractError, "original halted evidence changed"):
                successor.verify_receipt(project)

    def test_lifecycle_preserves_175_halt_and_retires_176_177(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-lifecycle-178-") as temp:
            project = committed_receipt_fixture(temp)
            self.assertEqual(successor.check_historical_inputs(project)["175_status"], "halted")
            for number in (176, 177):
                summary = project / f"{PHASE}/253-{number}-SUMMARY.md"
                summary.write_text("status: complete\n")
                with self.assertRaisesRegex(successor.ContractError, f"unexecuted {number} must not have a summary"):
                    successor.check_historical_inputs(project)
                summary.unlink()
            summary175 = project / f"{PHASE}/253-175-SUMMARY.md"
            prior175 = summary175.read_bytes()
            summary175.write_bytes(prior175.replace(b"status: halted", b"status: complete", 1))
            with self.assertRaisesRegex(successor.ContractError, "original halted evidence changed: .*253-175-SUMMARY.md"):
                successor.check_historical_inputs(project)
            summary175.write_bytes(prior175)
            self.assertEqual(successor.check_historical_inputs(project)["175_status"], "halted")

    def test_lifecycle_181_preserves_178_halt_and_reuses_179_180(self):
        # The preserved clean-input ref is the write-ahead copy for these exact
        # unexecuted instructions. Read it before testing their successor route.
        original_ref = "refs/gsd/phase253-repair181-inputs"
        original_plans = {}
        for rel in (successor.PLAN_179, successor.PLAN_180):
            original_plans[rel] = subprocess.check_output(["git", "show", f"{original_ref}:{rel}"], cwd=ROOT)
        original179 = original_plans[successor.PLAN_179].decode("utf-8")
        historical_ref = "refs/gsd/phase253-execution183-t1-first-green"
        current179 = subprocess.check_output(["git", "show", f"{historical_ref}:{successor.PLAN_179}"], cwd=ROOT).decode("utf-8")
        self.assertIn('depends_on: ["253-178"]', original179)
        self.assertIn('depends_on: ["253-181"]', current179)
        self.assertRegex(current179, r"(?m)^wave: 2$")
        self.assertNotRegex(current179, r"(?im)^.*(?:completed178|approved178|require.*178 review).*$")
        self.assertIn("253-181-REPAIR-REVIEW.json", current179)
        self.assertIn("253-178-SUMMARY.md", current179)  # Historical halt remains visible.
        self.assertEqual(
            re.findall(r"<automated>(.*?)</automated>", original179, re.S),
            re.findall(r"<automated>(.*?)</automated>", current179, re.S),
            "179 command bodies must remain byte-identical",
        )
        original180 = original_plans[successor.PLAN_180].decode("utf-8")
        current180 = subprocess.check_output(["git", "show", f"{historical_ref}:{successor.PLAN_180}"], cwd=ROOT).decode("utf-8")
        self.assertIn('depends_on: ["253-179"]', current180)
        self.assertRegex(current180, r"(?m)^wave: 3$")
        self.assertIn("181pins", current180)
        self.assertIn("25halts", current180)
        self.assertIn("73targets", current180)
        self.assertIn("[181,179]", current180)
        self.assertIn("253-178-REPAIR-REVIEW.json", current180)
        self.assertIn("never178", current180)
        self.assertNotEqual(original180, current180)

        summary178 = (ROOT / f"{PHASE}/253-178-SUMMARY.md").read_text(encoding="utf-8")
        summary175 = (ROOT / f"{PHASE}/253-175-SUMMARY.md").read_text(encoding="utf-8")
        self.assertRegex(summary178, r"(?m)^status: halted$")
        self.assertRegex(summary175, r"(?m)^status: halted$")
        for number in (176, 177, 179, 180):
            self.assertFalse((ROOT / f"{PHASE}/253-{number}-SUMMARY.md").exists())
        self.assertFalse((ROOT / successor.RECEIPT_179).exists())
        self.assertFalse((ROOT / successor.RECEIPT_178).exists())
        history = successor.check_historical_inputs(ROOT)
        self.assertEqual(history["178_status"], "halted")
        self.assertEqual(history["178_findings"], list(successor.EXPECTED_178_FINDING_IDS))

        validator = getattr(successor, "validate_review181", None)
        self.assertTrue(callable(validator), "missing source-bound validate_review181 lifecycle gate")

    def test_validate_review181_requires_real_source_commits_and_rejects_forgery(self):
        frozen_commit = "c88c3f8d96b490abe49cd2812c491fc7dd04b400"
        frozen_helper = subprocess.check_output(
            ["git", "show", f"{frozen_commit}:{PHASE}/253-RECOVERY-SUCCESSOR.py"], cwd=ROOT)
        required = {
            f"{PHASE}/253-RECOVERY-SUCCESSOR.py",
            f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
            f"{PHASE}/253-181-PLAN.md",
            f"{PHASE}/253-179-PLAN.md",
            f"{PHASE}/253-180-PLAN.md",
            "scripts/ci/ci-git-publication.test.py",
            "scripts/ci/ci-git-publication.py",
            "scripts/ci/ci-gate-canary-dryrun.py",
        }
        with tempfile.TemporaryDirectory(prefix="sigra-253-review181-") as temp:
            project = pathlib.Path(temp) / "project"
            project.mkdir()
            subprocess.run(["git", "init", "-q", str(project)], check=True)
            subprocess.run(["git", "-C", str(project), "config", "user.name", "GSD fixture"], check=True)
            subprocess.run(["git", "-C", str(project), "config", "user.email", "gsd-fixture@example.invalid"], check=True)
            alternates = project / ".git/objects/info/alternates"
            alternates.parent.mkdir(parents=True, exist_ok=True)
            alternates.write_text(str((ROOT / ".git/objects").resolve()) + "\n", encoding="utf-8")
            source_files = {}
            for rel in sorted(required):
                target = project / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                raw = (frozen_helper if rel.endswith("253-RECOVERY-SUCCESSOR.py") else
                       subprocess.check_output(["git", "show", f"{frozen_commit}:{rel}"], cwd=ROOT))
                target.write_bytes(raw)
                source_files[rel] = hashlib.sha256(raw).hexdigest()
            summary = project / f"{PHASE}/253-181-SUMMARY.md"
            summary.parent.mkdir(parents=True, exist_ok=True)
            summary.write_text("---\nstatus: complete\n---\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(project), "add", *sorted(required), summary.relative_to(project).as_posix()], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "committed review source fixture"], check=True)
            source_commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
            frozen_path = pathlib.Path(temp) / "frozen181.py"
            frozen_path.write_bytes(frozen_helper)
            frozen_spec = importlib.util.spec_from_file_location("successor181_frozen", frozen_path)
            legacy181 = importlib.util.module_from_spec(frozen_spec)
            frozen_spec.loader.exec_module(legacy181)
            base_review = {
                "schema": legacy181.REVIEW_SCHEMA,
                "status": "reviewed_for_new_acceptance",
                "repair_plan": "253-181",
                "acceptance_plan": "253-179",
                "bridge_plan": "253-180",
                "unresolved_implementation_findings": [],
                "finding_dispositions": {finding: "closed" for finding in legacy181.EXPECTED_178_FINDING_IDS},
                "acceptance_attempts": 0,
                "github_requests": 0,
                "native_browser_launches": 0,
                "requirements": {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"},
                "phase_verification_status": "not_started",
                "scope": {"product_changes": ["scripts/ci/ci-git-publication.test.py"],
                          "product_changes_during_181": []},
                "source_files": source_files,
                "source_commits": {rel: source_commit for rel in required},
                "historical_178": {
                    "status": "halted",
                    "finding_ids": list(legacy181.EXPECTED_178_FINDING_IDS),
                    "sha256": {rel: legacy181.HISTORICAL_SHA256[rel]
                               for rel in legacy181.FROZEN_178_COMMITS},
                },
                "amended_plan_validation": {"253-179": {}, "253-180": {}},
            }
            review_path = project / successor.REVIEW_181
            review_path.parent.mkdir(parents=True, exist_ok=True)
            node = pathlib.Path.home() / ".asdf/installs/nodejs/20.18.1/bin/node"
            sdk = pathlib.Path.home() / ".codex/gsd-core/bin/gsd-tools.cjs"
            validation = {}
            for plan_id in ("253-179", "253-180"):
                rel = f"{PHASE}/{plan_id}-PLAN.md"
                plan_raw = (project / rel).read_bytes()
                entries = {}
                for key, verb, extra in (("frontmatter", "frontmatter.validate", ["--schema", "plan-gap-closure"]),
                                         ("structure", "verify.plan-structure", [])):
                    argv = [str(node), str(sdk), "query", verb, rel, *extra]
                    result = subprocess.run(argv, cwd=project, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"))
                    entries[key] = {"argv": argv, "exit_code": result.returncode,
                                    "stdout": result.stdout.decode("utf-8", "strict"),
                                    "stdout_sha256": hashlib.sha256(result.stdout).hexdigest()}
                validation[plan_id] = {"plan_path": rel, "plan_sha256": hashlib.sha256(plan_raw).hexdigest(), **entries}
            base_review["amended_plan_validation"] = validation

            def write_review(value):
                review_path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")

            write_review(base_review)
            accepted = legacy181.validate_review181(project, require_summary=True)
            self.assertEqual(accepted["repair_plan"], "253-181")

            attacks = (
                ("lineage", lambda x: x.update(repair_plan="253-178"), "181 review identity or status"),
                ("findings", lambda x: x.update(finding_dispositions={}), "does not close exactly the four"),
                ("source_hash", lambda x: x["source_files"].update({next(iter(required)): "0" * 64}), "reviewed source hash differs"),
                ("source_commit", lambda x: x["source_commits"].update({next(iter(required)): "0" * 40}), "git .* failed|producing commit"),
                ("validator_argv", lambda x: x["amended_plan_validation"]["253-179"]["frontmatter"].update(argv=["fake"]), "validator argv/exit differs"),
                ("validator_stdout", lambda x: x["amended_plan_validation"]["253-179"]["frontmatter"].update(
                    stdout="not json", stdout_sha256=hashlib.sha256(b"not json").hexdigest()), "stdout is not JSON"),
                ("validator_rehashed_output", lambda x: x["amended_plan_validation"]["253-179"]["frontmatter"].update(
                    stdout="{}\n", stdout_sha256=hashlib.sha256(b"{}\n").hexdigest()), "result is not valid"),
                ("validator_plan_hash", lambda x: x["amended_plan_validation"]["253-180"].update(plan_sha256="f" * 64), "not bound to exact amended bytes"),
                ("historical", lambda x: x["historical_178"].update(status="complete"), "does not preserve the original halted 178"),
                ("external", lambda x: x.update(github_requests=1), "unauthorized external action"),
                ("attempt", lambda x: x.update(acceptance_attempts=1), "unresolved findings or records an acceptance attempt"),
            )
            for name, mutate, reason in attacks:
                with self.subTest(name=name):
                    candidate = json.loads(json.dumps(base_review))
                    mutate(candidate)
                    write_review(candidate)
                    with self.assertRaisesRegex(legacy181.ContractError, reason):
                        legacy181.validate_review181(project, require_summary=True)

    def test_consumer168_uses_entry_bridge_without_repeating_sdk_queries(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-consumer-bridge-") as temp:
            project = committed_receipt_fixture(temp)
            receipt = json.loads((project / successor.RECEIPT_179).read_bytes())
            source = receipt["source_commit"]
            ref = "refs/gsd/phase253-successor-180-plan-originals"
            subprocess.run(["git", "-C", str(project), "update-ref", ref, source], check=True)
            originals = {}
            for number in (*range(168, 173), 176, 177):
                rel = f"{PHASE}/253-{number}-PLAN.md"
                originals[rel] = subprocess.check_output(["git", "-C", str(project), "show", f"{source}:{rel}"])
            amend_entry_plans(project, originals)
            pins = {rel: {"blob": subprocess.check_output(
                        ["git", "-C", str(project), "hash-object", "--stdin"], input=raw).decode().strip(),
                        "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
                    for rel, raw in originals.items()}
            source_paths = set()
            for row in subprocess.check_output(["git", "-C", str(project), "ls-tree", "-rz", "-r", source,
                                                 "--", successor.PHASE, ".planning/phases/252-measure-current-ci"]).split(b"\0"):
                if row:
                    source_paths.add(row.split(b"\t", 1)[1].decode())
            bridge = {"schema": successor.BRIDGE_SCHEMA, "stage": "entry", "source_commit": source,
                      "preservation_ref": ref, "originals": pins,
                      "amended_sha256": {rel: hashlib.sha256((project / rel).read_bytes()).hexdigest()
                                         for rel in (f"{PHASE}/253-168-PLAN.md", f"{PHASE}/253-169-PLAN.md")},
                      "protected_source_bindings": {rel: hashlib.sha256(
                          subprocess.check_output(["git", "-C", str(project), "show", f"{source}:{rel}"])).hexdigest()
                          for rel in source_paths}, "dispositions_for": []}
            bridge_rel = f"{PHASE}/253-180-BRIDGE-RECORD.json"
            (project / bridge_rel).write_text(json.dumps(bridge, sort_keys=True, indent=2) + "\n")
            subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "simulated 177 entry bridge"], check=True)
            with mock.patch.object(successor, "run_sdk_copy", side_effect=AssertionError("consumer must not rerun SDK")):
                self.assertEqual(successor.verify_receipt(project, consumer="168")["status"], "verified")

            # Complete the remaining three exact plan paths and exercise the real SDK
            # against this committed amended copy; then consume it again without a rerun.
            amend_complete_plans(project, originals)
            bridge["stage"] = "complete"
            bridge["amended_sha256"] = {f"{PHASE}/253-{number}-PLAN.md": hashlib.sha256(
                (project / f"{PHASE}/253-{number}-PLAN.md").read_bytes()).hexdigest() for number in range(168, 173)}
            # A placeholder merely satisfies the schema precondition; --sdk below
            # performs the installed SDK calls and returns their actual outputs.
            bridge["sdk_copy"] = {"status": "not-yet-run"}
            (project / bridge_rel).write_text(json.dumps(bridge, sort_keys=True, indent=2) + "\n")
            subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "simulated 177 complete bridge"], check=True)
            verified_bridge = successor.validate_bridge(project, "complete", bridge_rel, sdk=True)
            self.assertEqual(verified_bridge["status"], "verified")
            report_path = pathlib.Path(tempfile.gettempdir()) / "sigra-phase253-178-consumer-sdk-copy-report.json"
            report_raw = (json.dumps(verified_bridge["sdk_copy"], sort_keys=True, indent=2) + "\n").encode()
            report_path.write_bytes(report_raw)
            bridge["sdk_copy"] = {"report_path": str(report_path),
                                  "report_sha256": hashlib.sha256(report_raw).hexdigest()}
            (project / bridge_rel).write_text(json.dumps(bridge, sort_keys=True, indent=2) + "\n")
            subprocess.run(["git", "-C", str(project), "add", ".planning"], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "retain actual SDK copy result"], check=True)
            with mock.patch.object(successor, "run_sdk_copy", side_effect=AssertionError("consumer must not rerun SDK")):
                self.assertEqual(successor.verify_receipt(project, consumer="168")["status"], "verified")

    def test_lifecycle_183_preserves_181_182_halts_and_reuses_179_180(self):
        validator = getattr(successor, "validate_review183", None)
        if not callable(validator):
            self.fail("ACTIVE_REPAIR_183_MISSING")
        with tempfile.TemporaryDirectory(prefix="sigra-253-lifecycle183-") as temp:
            project = committed_receipt_fixture(temp)
            review = validator(project, require_summary=True)
            self.assertEqual(review["repair_plan"], "253-183")
            self.assertEqual(review["acceptance_plan"], "253-179")
            self.assertEqual(review["bridge_plan"], "253-180")
            self.assertEqual(review["historical"]["181"]["status"], "halted")
            self.assertEqual(review["historical"]["182"]["status"], "halted")
            for number in (181, 182):
                summary = (project / f"{PHASE}/253-{number}-SUMMARY.md").read_text(encoding="utf-8")
                self.assertRegex(summary, r"(?m)^status: halted$")
            self.assertIn('depends_on: ["253-183"]', (project / successor.PLAN_179).read_text())
            self.assertIn("253-183-REPAIR-REVIEW.json", (project / successor.PLAN_179).read_text())
            amended180 = (project / successor.PLAN_180).read_text()
            for text in ("183pins", "27halts", "73targets", "[183,179]"):
                self.assertIn(text, amended180)
            self.assertFalse((project / successor.RECEIPT_179).exists())
            self.assertFalse((project / f"{PHASE}/253-179-SUMMARY.md").exists())
            self.assertTrue(callable(getattr(successor, "validate_review181", None)))

    def test_validate_review183_requires_direct_runs_and_source_commits(self):
        validator = getattr(successor, "validate_review183", None)
        if not callable(validator):
            self.fail("DIRECT_RUN_REVIEW_183_MISSING")

        review_rel = getattr(successor, "REVIEW_183", None)
        self.assertIsInstance(review_rel, str)
        self.assertTrue(review_rel.endswith("253-183-REPAIR-REVIEW.json"))
        with tempfile.TemporaryDirectory(prefix="sigra-253-review183-") as temp:
            project = committed_receipt_fixture(temp)
            review_path = project / review_rel
            original = json.loads(review_path.read_bytes())
            accepted = validator(project, require_summary=True)
            self.assertEqual(accepted["direct_runs"]["t2-red"]["native_exit_code"], 1)
            self.assertTrue(accepted["direct_runs"]["t2-red"]["direct_process_capture"])
            self.assertEqual(len(accepted["amended_plan_validation"]), 2)

            def reject(mutator, message=None):
                review = json.loads(json.dumps(original))
                mutator(review)
                review_path.write_text(json.dumps(review, sort_keys=True, indent=2) + "\n", encoding="utf-8")
                with self.assertRaises(successor.ContractError, msg=message):
                    validator(project, require_summary=True)

            reject(lambda review: review["direct_runs"].pop("t2-red"))
            reject(lambda review: review["direct_runs"]["t2-red"].update(argv=["python3", "-c", "wrong test"]))
            reject(lambda review: review["direct_runs"]["t2-red"]["capture_result"].update(base64="%%"))
            reject(lambda review: review["direct_runs"]["t2-red"]["before"]["sources"][0].update(sha256="0" * 64))
            reject(lambda review: review["direct_runs"]["t2-red"]["before"]["sources"][0].update(
                last_producing_commit=review["direct_runs"]["t2-red"]["capture_result"]["commit"]))

            def invalid_utf8(review):
                row = review["direct_runs"]["t2-red"]
                raw = b"\xff"
                row.update(stdout_base64=base64.b64encode(raw).decode(), stdout_bytes=1,
                           stdout_sha256=hashlib.sha256(raw).hexdigest())
            reject(invalid_utf8)

            def bad_capture_commit(review):
                run = review["direct_runs"]["t2-green"]
                run["capture_result"]["commit"] = "0" * 40
            reject(bad_capture_commit)

            def corrupt_validator(review):
                review["amended_plan_validation"]["253-179"]["frontmatter"]["stdout"] = "{}\n"
            reject(corrupt_validator)

            # Canonically equivalent source text with a fresh outer hash and
            # committed replacement still disagrees with the captured bytes.
            rel = f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py"
            prior = (project / rel).read_bytes()
            changed = prior + b"\n"
            (project / rel).write_bytes(changed)
            subprocess.run(["git", "-C", str(project), "add", rel], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-qm", "alternate UTF-8 source bytes"], check=True)
            replacement_commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
            replacement = json.loads(json.dumps(original))
            replacement["source_files"][rel] = hashlib.sha256(changed).hexdigest()
            replacement["source_commits"][rel] = replacement_commit
            review_path.write_text(json.dumps(replacement, sort_keys=True, indent=2) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(successor.ContractError, "final validator capture does not bind"):
                validator(project, require_summary=True)

            # Missing, empty, null, nonobject and invalid-UTF-8 review bytes
            # are independently refused before any lifecycle can be approved.
            malformed = (b"", b"null", b"[]", b"{}", b"{\xff}")
            for raw in malformed:
                with self.subTest(raw=raw):
                    review_path.write_bytes(raw)
                    with self.assertRaises(successor.ContractError):
                        validator(project, require_summary=False)
            review_path.unlink()
            with self.assertRaises(successor.ContractError):
                validator(project, require_summary=False)

        # The legacy validator remains a separate historical check; its
        # halted review cannot stand in for committed direct-run evidence.
        self.assertTrue(callable(getattr(successor, "validate_review181", None)))
        self.assertEqual(successor.REVIEW_SCHEMA,
                         "sigra.phase253.successor-repair-review/v1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
