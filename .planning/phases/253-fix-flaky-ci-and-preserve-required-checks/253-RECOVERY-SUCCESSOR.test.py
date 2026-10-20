#!/usr/bin/env python3
"""Finite synthetic tests for the Phase 253 successor command and receipt contract."""

from __future__ import annotations

import hashlib
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


def amend_entry_plans(root, original):
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
    p169 = p169.replace("22 halted", "24 halted").replace("22) and", "24) and")
    p169 = p169.replace("23 halted", "24 halted").replace("23) and", "24) and")
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
    p169 = p169.replace("173 -> 179.", "173 -> 179; 174 -> [178, 179]; 175 -> [178, 179].")
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
    plan_ids = list(range(1, 181))
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
        'if(c.responsibilities.length!==73||c.plan_pins.length!==180||c.halted_plans.length!==24||'
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
    plan = (plan.replace("Twenty-two halted", "Twenty-four halted")
                .replace("22 halted", "24 halted")
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
    bodies = re.findall(r"<automated>(.*?)</automated>", plan, re.S)
    matches = list(re.finditer(r'"?\$N"?\s+-e\s+\'(const b=JSON\.parse\(require\("fs"\).*?process\.exit\(1\))\' \$P/253-LOAD-RECOVERY-SUPERSESSION-SUMMARIES-R13\.json', bodies[1], re.S))
    if len(matches) != 1:
        raise AssertionError("172 executable bundle assertion is not unique")
    code = (
        'const b=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); '
        'const paths=(b.entries||[]).map(e=>e.path||e.disposition_path||""); '
        f'const EXPECTED={json.dumps([f"{n}-SUMMARY.md" for n in targets],separators=(",",":"))}; '
        'const sort=(xs)=>[...xs].sort(); '
        'if(paths.length!==73||new Set(paths).size!==73||'
        'JSON.stringify(sort(paths))!==JSON.stringify(sort(EXPECTED))) process.exit(1)'
    )
    plan = plan.replace(matches[0].group(1), code, 1)
    (root / rel).write_text(plan, encoding="utf-8")


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


def committed_receipt_fixture(parent):
    project = pathlib.Path(parent) / "receipt-repo"
    project.mkdir()
    shutil.copytree(ROOT / ".planning", project / ".planning")
    for rel in ("scripts/ci/ci-git-publication.test.py", "scripts/ci/ci-git-publication.py",
                "scripts/ci/ci-gate-canary-dryrun.py"):
        target = project / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
    reviewed = {"scripts/ci/ci-git-publication.test.py", successor.PLAN_178,
                successor.PLAN_179, successor.PLAN_180,
                f"{PHASE}/253-RECOVERY-SUCCESSOR.py",
                f"{PHASE}/253-RECOVERY-SUCCESSOR.test.py",
                "scripts/ci/ci-git-publication.py", "scripts/ci/ci-gate-canary-dryrun.py"}
    (project / f"{PHASE}/253-178-SUMMARY.md").write_text(
        "---\nphase: 253-fix-flaky-ci-and-preserve-required-checks\nplan: \"178\"\nstatus: complete\n---\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(project), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(project), "config", "user.name", "Receipt Fixture"], check=True)
    subprocess.run(["git", "-C", str(project), "config", "user.email", "receipt-fixture@example.test"], check=True)
    subprocess.run(["git", "-C", str(project), "add", ".planning", "scripts"], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "receipt source files"], check=True)
    reviewed_commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    successor.FROZEN_175_COMMITS.update({rel: reviewed_commit for rel in successor.FROZEN_175_COMMITS})
    review = {"schema": successor.REVIEW_SCHEMA, "status": "reviewed_for_new_acceptance",
              "repair_plan": "253-178", "acceptance_plan": "253-179", "bridge_plan": "253-180",
              "source_files": {rel: hashlib.sha256((project / rel).read_bytes()).hexdigest() for rel in reviewed},
              "source_commits": {rel: reviewed_commit for rel in reviewed},
              "unresolved_implementation_findings": [],
              "acceptance_attempts": 0,
              "requirements": {"CIREL-01": "partial_not_reproduced", "CIREL-02": "unaccepted"},
              "phase_verification_status": "not_started",
              "scope": {"product_changes": ["scripts/ci/ci-git-publication.test.py"],
                        "product_changes_during_178": [], "github_requests": 0, "native_browser_launches": 0}}
    (project / successor.REVIEW_178).write_text(json.dumps(review, sort_keys=True, indent=2) + "\n")
    subprocess.run(["git", "-C", str(project), "add", successor.REVIEW_178], check=True)
    subprocess.run(["git", "-C", str(project), "commit", "-qm", "repair review input"], check=True)
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
            with self.assertRaisesRegex(successor.ContractError, "readiness_init.*JSON|query.*JSON|SDK.*output"):
                successor.validate_sdk_copy_report(root, evidence)

    def test_sdk_indexes_require_exact_unique_plan_universe(self):
        validator = getattr(successor, "validate_sdk_index_rows", None)
        self.assertTrue(callable(validator), "missing raw SDK index validator")
        expected_ids = [f"253-{number:02d}" for number in range(1, 182)]
        expected_halted = {f"253-{number:02d}" for number in successor.HISTORICAL_HALT_IDS}

        def rows(final):
            incomplete = set() if final else {"253-168"}
            return [{"id": plan, "has_summary": plan not in incomplete,
                     "halted": plan in expected_halted, "blocked_by": []}
                    for plan in expected_ids]

        ready_rows = rows(False)
        ready_init = {"plan_count": 181, "incomplete_count": 1,
                      "incomplete_plans": ["253-168-PLAN.md"],
                      "runnable_plans": ["253-168-PLAN.md"]}
        final_rows = rows(True)
        final_init = {"plan_count": 181, "incomplete_count": 0,
                      "incomplete_plans": [], "runnable_plans": []}
        self.assertEqual(len(validator(ready_rows, ready_init, "readiness")), 181)
        self.assertEqual(len(validator(final_rows, final_init, "final")), 181)

        attacks = {
            "duplicate": lambda values: values[:-1] + [dict(values[0])],
            "missing": lambda values: values[:-1],
            "extra": lambda values: values + [{"id": "253-182", "has_summary": True,
                                                 "halted": False, "blocked_by": []}],
            "replaced": lambda values: values[:-1] + [{**values[-1], "id": "253-999"}],
            "malformed": lambda values: values[:-1] + [{**values[-1], "id": "253-0181"}],
            "non-object": lambda values: values[:-1] + ["253-181"],
        }
        for stage, base, init in (("readiness", ready_rows, ready_init), ("final", final_rows, final_init)):
            for label, mutate in attacks.items():
                with self.subTest(stage=stage, mutation=label), self.assertRaises(successor.ContractError):
                    validator(mutate(base), init, stage)

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
            for rel, commit in successor.FROZEN_175_COMMITS.items():
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
                ("restored174pin", "EXPECTED_PLAN_IDS", "253-180", "253-177", "180-plan-pin set"),
                ("omitted176target", "EXPECTED_TARGET_IDS", "253-176", "253-175", "73 target set"),
                ("omitted177target", "EXPECTED_TARGET_IDS", "253-177", "253-175", "73 target set"),
                ("omitted175halt", "EXPECTED_HALT_IDS", "253-175", "253-174", "24 halt set"),
                ("old174pinCount", "c.plan_pins.length!==180", "c.plan_pins.length!==180", "c.plan_pins.length!==174", "stale count"),
                ("old22haltCount", "c.halted_plans.length!==24", "c.halted_plans.length!==24", "c.halted_plans.length!==22", "stale count"),
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
                               ("owner173", "173 -> 179", "173 -> 174"))
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

    def test_bridge_rejects_stale_174_routes_22_halts_pins_and_hosted_link_edits(self):
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
            amend_entry_plans(root, originals)
            good168 = (root / f"{PHASE}/253-168-PLAN.md").read_text()
            good169 = (root / f"{PHASE}/253-169-PLAN.md").read_text()
            original172 = originals[f"{PHASE}/253-172-PLAN.md"].decode()
            good172 = original172
            changed_plans = {f"{PHASE}/253-168-PLAN.md", f"{PHASE}/253-169-PLAN.md"}
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
            (root / record_path).write_text(json.dumps(record))
            self.assertEqual(successor.validate_bridge(root, "entry", record_path)["status"], "verified")
            corruptions = []
            bad = json.loads(json.dumps(record)); bad169 = good169.replace("c.halted_plans.length!==24", "c.halted_plans.length!==22", 1)
            (root / f"{PHASE}/253-169-PLAN.md").write_text(bad169)
            bad["amended_sha256"][f"{PHASE}/253-169-PLAN.md"] = hashlib.sha256(bad169.encode()).hexdigest()
            corruptions.append(("22-halt", bad, lambda: None))
            (root / f"{PHASE}/253-169-PLAN.md").write_text(good169)
            bad = json.loads(json.dumps(record)); bad169 = good169.replace("253-175-EXECUTION-RECORD.json", "")
            (root / f"{PHASE}/253-169-PLAN.md").write_text(bad169)
            bad["amended_sha256"][f"{PHASE}/253-169-PLAN.md"] = hashlib.sha256(bad169.encode()).hexdigest()
            corruptions.append(("174-pin", bad, lambda: None))
            (root / f"{PHASE}/253-169-PLAN.md").write_text(good169)
            bad = json.loads(json.dumps(record)); bad168 = 'depends_on: ["253-180"]\n253-174-RECOVERY-RECEIPT.json\n'
            (root / f"{PHASE}/253-168-PLAN.md").write_text(bad168)
            bad["amended_sha256"][f"{PHASE}/253-168-PLAN.md"] = hashlib.sha256(bad168.encode()).hexdigest()
            corruptions.append(("stale174", bad, lambda: None))
            (root / f"{PHASE}/253-168-PLAN.md").write_text(good168)
            bad = json.loads(json.dumps(record)); bad172 = good172.replace("- publication = ", "- publication = tampered-", 1)
            (root / f"{PHASE}/253-172-PLAN.md").write_text(bad172)
            bad["amended_sha256"][f"{PHASE}/253-172-PLAN.md"] = hashlib.sha256(bad172.encode()).hexdigest()
            corruptions.append(("hosted-link", bad, lambda: None))
            (root / f"{PHASE}/253-172-PLAN.md").write_text(good172)
            for label, bad_record, _ in corruptions:
                with self.subTest(label=label):
                    (root / record_path).write_text(json.dumps(bad_record))
                    with self.assertRaises(successor.ContractError):
                        successor.validate_bridge(root, "entry", record_path)

    def test_installed_sdk_copy_executes_queries_and_proves_full_route(self):
        with tempfile.TemporaryDirectory(prefix="sigra-253-sdk-amended-route-") as temp:
            project = pathlib.Path(temp) / "project"
            project.mkdir()
            shutil.copytree(ROOT / ".planning", project / ".planning")
            originals = {f"{PHASE}/253-{n}-PLAN.md": (ROOT / f"{PHASE}/253-{n}-PLAN.md").read_bytes()
                         for n in (*range(168, 173), 176, 177)}
            amend_complete_plans(project, originals)
            result = successor.run_sdk_copy(project, {}, "unused")
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["readiness_168_runnable"])
        self.assertTrue(result["readiness_175_halted"])
        self.assertEqual(result["post_chain_incomplete"], 0)
        self.assertEqual(result["post_chain_halted"], 24)
        self.assertEqual(len(result["disposition_ids"]), 73)
        self.assertTrue(result["source_copy_commit"])
        self.assertEqual(set(result["sdk_queries"]), {"readiness_init", "readiness_index", "post_init", "post_index"})
        self.assertTrue(all(row["stdout_sha256"] for row in result["sdk_queries"].values()))
        self.assertTrue(result["immutable_copy_input_sha256"])

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
