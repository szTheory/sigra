#!/usr/bin/env python3
"""Offline-first continuation: exact artifact intake plus frozen docs-only collector."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

B = Path(__file__).resolve().parent
R = B / "runtime"
ROOT = next(p for p in B.parents if (p / ".git").exists())
sys.path.insert(0, str(R))
import execution_guard as guard


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read(path: Path):
    return json.loads(path.read_text())


def save(path: Path, value, exclusive=True):
    raw = (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    if exclusive:
        with path.open("xb") as f:
            f.write(raw); f.flush(); os.fsync(f.fileno())
    else:
        tmp = path.with_suffix(path.suffix + ".next")
        tmp.write_bytes(raw); os.replace(tmp, path)


def module(path: Path, name: str):
    # Compile the pinned source directly to avoid cache files in historical evidence directories.
    import types
    value = types.ModuleType(name)
    value.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), "exec"), value.__dict__)
    return value


def verify_manifest():
    manifest = read(B / "manifest.json")
    guard.require(manifest.get("schema") == "sigra.phase253.pr343-remaining-evidence-manifest/v2", "manifest schema is not recognized")
    guard.require(manifest.get("proposal_sha256") == digest((B / "proposal.json").read_bytes()), "manifest proposal digest differs")
    seen = set()
    for item in manifest.get("files", []):
        rel = item.get("path")
        guard.require(isinstance(rel, str) and rel not in seen and not rel.startswith("/") and ".." not in Path(rel).parts,
                      "manifest file path is malformed or duplicated")
        seen.add(rel)
        path = B / rel
        guard.require(path.is_file() and digest(path.read_bytes()) == item.get("sha256"), f"manifest file digest mismatch: {rel}")
    guard.require(seen and "run.py" in seen and "proposal.json" in seen and "pr-freeze.json" in seen,
                  "manifest omits required executable or frozen inputs")
    for item in manifest.get("upstream_sources", []):
        path = ROOT / item["path"]
        guard.require(path.is_file() and digest(path.read_bytes()) == item["sha256"], f"pinned upstream source changed: {item['path']}")
    normal = read(B / "pr-freeze.json")["normal"]
    workflow = B / "normal-workflow.yml"
    object_id = subprocess.run(["git", "hash-object", "--stdin"], input=workflow.read_bytes(), capture_output=True, check=True).stdout.decode().strip()
    guard.require(object_id == normal["workflow_blob"], "pinned normal workflow bytes differ from frozen PR343 Git blob")
    return manifest


def check_artifact_metadata(proposal, items):
    """Bind the frozen five IDs to the actual saved GitHub artifact inventory."""
    producers = [x for x in items if isinstance(x, dict) and str(x.get("name", "")).startswith("browser-execution-")]
    actual = {x.get("id"): x for x in producers}
    wanted = proposal["browser_artifacts"]
    guard.require(len(actual) == len(producers) == len(wanted) and set(actual) == {x["id"] for x in wanted}, "browser artifact metadata has missing, duplicate, or extra IDs")
    for spec in wanted:
        item = actual[spec["id"]]
        run = item.get("workflow_run") or {}
        guard.require(item.get("name") == spec["name"] and item.get("digest") == spec["digest"]
                      and item.get("size_in_bytes") == spec["size_in_bytes"] and item.get("expired") is False
                      and run.get("id") == spec["run_id"] and run.get("head_sha") == spec["head_sha"],
                      f"artifact metadata differs from the approved exact identity: {spec['id']}")


def ci_accounting(transactions):
    """Report only PR creations and run IDs present in durable response rows; absent discovery is unknown."""
    created = sum(1 for tx in transactions if tx.get("route_id") == "pr_create" and tx.get("family") == "docs-only"
                  and tx.get("state") == "complete" and tx.get("actual_status") == 201)
    discovered = set()
    for tx in transactions:
        if tx.get("family") == "docs-only" and tx.get("state") == "complete" and tx.get("actual_status") == 200:
            try:
                body = json.loads(base64.b64decode(tx.get("response_body_base64", ""), validate=True))
                items = body.get("workflow_runs", []) if tx.get("route_id") == "workflow_runs" else [body] if tx.get("route_id") == "run" else []
                discovered.update(str(x["id"]) for x in items if isinstance(x, dict) and x.get("id") is not None)
            except (ValueError, json.JSONDecodeError):
                pass
    return {"docs_pr_creation_count":created,"workflow_run_discovery_count":len(discovered),
            "workflow_run_ids_discovered":sorted(discovered),
            "ci_launch_status":"run_ids_discovered" if discovered else "unknown_after_docs_pr_creation" if created else "no_docs_pr_creation_recorded"}


def check_download_receipt(spec, archive, receipt, transactions):
    """Apply the existing PR verifier's measured-download invariants to each retained ZIP."""
    raw_sha = digest(archive)
    guard.require(receipt.get("actual_status") == 200 and receipt.get("raw_observation_sha256") == raw_sha
                  and receipt.get("response_bytes") == len(archive)
                  and raw_sha == spec["digest"].removeprefix("sha256:") and len(archive) == spec["size_in_bytes"],
                  f"artifact response bytes differ from the exact saved digest/size: {spec['id']}")
    group_id = receipt.get("request_group")
    group = [tx for tx in transactions if tx.get("request_group") == group_id and group_id]
    group.sort(key=lambda x: x.get("hop_ordinal", -1))
    guard.require(1 <= len(group) <= 3 and all(tx.get("family") == "normal" and tx.get("route_id") == "artifact_zip"
                  and tx.get("category") == "artifact_downloads" for tx in group), "artifact measured redirect hops are missing or misclassified")
    guard.require([tx.get("hop_ordinal") for tx in group] == list(range(len(group)))
                  and all(tx.get("actual_status") in (301, 302, 303, 307, 308) for tx in group[:-1])
                  and group[-1].get("actual_status") == 200, "artifact redirect chain is incomplete or did not end in HTTP 200")
    first_url = group[0].get("url", "")
    guard.require(first_url.endswith(f"/actions/artifacts/{spec['id']}/zip"), "artifact request URL differs from the frozen ID")


def offline():
    verify_manifest()
    p = read(B / "proposal.json")
    f = read(B / "pr-freeze.json")
    actions = read(B / "actions.json")
    guard.require(p["source_freeze"]["pr_freeze_sha256"] == digest((B / "pr-freeze.json").read_bytes()), "proposal no longer binds exact PR freeze")
    guard.require(p["source_freeze"]["actions_sha256"] == digest((B / "actions.json").read_bytes()), "proposal no longer binds exact paired actions")
    guard.require(actions["outward_actions_sha256"]["docs_and_prs"] == p["source_freeze"]["docs_and_prs_section_sha256"], "docs action section changed")
    guard.require(f["normal"]["head_sha"] == p["candidate_sha"] and f["normal"]["head_ref"] == p["normal_candidate_ref"], "normal candidate identity changed")
    guard.require(f["docs-only"]["head_ref"] == p["docs_only_pr"]["head_ref"] and f["docs-only"]["base_ref"] == p["docs_only_pr"]["base_ref"], "docs refs differ from freeze")
    guard.require(f["docs-only"]["head_sha"] == p["docs_only_pr"]["head_sha"] and f["docs-only"]["base_sha"] == p["docs_only_pr"]["base_sha"], "docs commits differ from freeze")
    guard.require(p["request_budget"]["max_requests"] == 120 and sum(p["request_budget"]["category_limits"].values()) == 120, "request table is not exact production allocation")
    guard.require(sum(p["request_budget"]["permitted_request_maxima"].values()) == 70, "proposal aggregate request maximum must remain 70")
    guard.require(p["request_budget"]["category_limits"] == module(R / "ci-hosted-transport.py", "offline_transport").PRODUCTION_CATEGORY_LIMITS, "request allocation differs from production transport contract")
    guard.require(len(p["browser_artifacts"]) == 5 and all(x["run_id"] == 39815188159 and x["attempt"] == 1 and x["head_sha"] == p["candidate_sha"] for x in p["browser_artifacts"]), "artifact manifest identity is incomplete")
    for path, blob in ((B / "docs-workflow.yml", f["docs-only"]["workflow_blob"]), (B / "docs-proof.md", f["docs-only"]["docs_blob"])):
        actual = subprocess.run(["git", "hash-object", "--stdin"], input=path.read_bytes(), capture_output=True, check=True).stdout.decode().strip()
        guard.require(actual == blob, f"saved docs source does not match frozen git blob: {path.name}")
    old = B.parent / "253-pr343-recovery"
    snapshot = json.loads((old / "ledger.json").read_text())
    snapshot["mode"] = "live"  # mode is recorded in the scoped attempt receipt, not the transport-ledger schema.
    result = module(old / "verify.py", "existing_pr343_verifier").verify(snapshot)
    recorded = read(old / "result.json")
    guard.require(result == recorded, "recomputed independent PR343 snapshot differs from its retained result")
    guard.require(result["run_id"] == 39815188159 and result["run_status"] == "completed" and result["conclusion"] == "success" and result["phase_verified"] is False,
                  "saved PR343 snapshot does not establish exact successful run; this snapshot is not phase acceptance")
    artifact_row = next((x for x in snapshot["transactions"] if x.get("route_id") == "run_artifacts"), None)
    guard.require(artifact_row is not None and artifact_row.get("actual_status") == 200, "saved PR343 inventory response is missing")
    inventory = json.loads(base64.b64decode(artifact_row["response_body_base64"], validate=True))
    guard.require(inventory.get("total_count") == len(inventory.get("artifacts", [])), "saved PR343 artifact inventory is truncated")
    check_artifact_metadata(p, inventory["artifacts"])
    allocation = json.loads((B / "allocation-template.json").read_text())
    allocation["source_sha256"] = digest((B / "pr-freeze.json").read_bytes())
    with tempfile.TemporaryDirectory(prefix="pr343-evidence-offline-check-") as temporary:
        allocation_path = Path(temporary) / "allocation.json"
        allocation_path.write_text(json.dumps(allocation))
        checked = subprocess.run(["bash", str(R / "ci-pr-proof.sh"), "--check-only", "--freeze", str(B / "pr-freeze.json"),
                                  "--allocation", str(allocation_path)], cwd=ROOT, capture_output=True, text=True, check=False)
        guard.require(checked.returncode == 0 and '"network_requests": 0' in checked.stdout,
                      "canonical collector freeze/allocation check failed offline")
    return {"status": "offline-ready", "proposal_sha256": digest((B / "proposal.json").read_bytes()),
            "normal_pr": {"number": 343, "run_id": 39815188159, "attempt": 1, "run_status": "completed", "conclusion": "success"},
            "artifacts_to_download": p["browser_artifacts"], "docs_pr_refs": {"base": p["docs_only_pr"]["base_ref"], "head": p["docs_only_pr"]["head_ref"]},
            "request_budget": p["request_budget"], "network_requests": 0,
            "docs_pr_creation_count": 0, "workflow_run_discoveries": 0, "ci_launch_status": "not_started_offline",
            "still_missing": ["original five browser ZIPs and execution-record.json contents", "new docs-only PR identity, exact pull_request run, terminal jobs/checks, and full transport-backed evidence"]}


def activate():
    # Verify approval and all once-only state before any filesystem or network mutation.
    proposal, _ = guard.verify_approval()
    offline()  # full frozen-input and collector preflight, still before any live request or write
    verify_manifest()
    guard.committed(B / "proposal.json")
    guard.committed(B / "manifest.json")
    guard.require(not any((B / n).exists() for n in ("run-state.json", "allocation.json", "ledger.json", "result.json", "attempt-result.json")),
                  "once-only continuation already started; inspect evidence and never restart")
    guard.require(not list(B.glob("request-*.json")), "partial request artifacts exist; inspect rather than restart")
    transport = module(R / "ci-hosted-transport.py", "remaining_transport")
    transport.preservation_preflight(B)
    state = {"status": "active", "proposal_sha256": digest((B / "proposal.json").read_bytes()), "started_epoch": int(time.time()), "closed": False}
    save(B / "run-state.json", state)
    try:
        allocation = json.loads((B / "allocation-template.json").read_text())
        allocation["source_sha256"] = digest((B / "pr-freeze.json").read_bytes())
        save(B / "allocation.json", allocation)

        def request(req):
            guard.check_request(req, read(B / "ledger.json")["transactions"] if (B / "ledger.json").exists() else [])
            n = len(read(B / "ledger.json")["transactions"]) if (B / "ledger.json").exists() else 0
            rq, receipt, body = B / f"request-{n+1}.json", B / f"request-{n+1}-receipt.json", B / f"request-{n+1}-body.json"
            save(rq, req)
            rec, _, raw, _ = transport.request_one(B / "allocation.json", B / "ledger.json", rq, receipt, body)
            guard.require(rec.get("actual_status") == 200 and not rec.get("error"), "HTTP response was not successful; this once-only window is closed without retry")
            return rec, raw

        # One rate-limit GET before the first payload. GitHub core <=250 terminates the run.
        _, raw = request({"method": "GET", "route_id": "rate_limit", "category": "preflight", "family": "shared", "params": {}})
        rate = json.loads(raw)
        guard.require(type(rate.get("resources", {}).get("core", {}).get("remaining")) is int and rate["resources"]["core"]["remaining"] > 250,
                      "GitHub core API budget is at or below 250; stop without further requests")

        verifier = module(R / "ci-hosted-gate-verify.py", "remaining_independent_verifier")
        downloads = []
        for spec in proposal["browser_artifacts"]:
            n = len(read(B / "ledger.json")["transactions"])
            req = {"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads", "family": "normal",
                   "params": {"artifact_id": spec["id"]}}
            guard.check_request(req, read(B / "ledger.json")["transactions"])
            rq, receipt, archive_path = B / f"request-{n+1}.json", B / f"request-{n+1}-receipt.json", B / f"artifact-{spec['id']}.zip"
            save(rq, req)
            rec = transport.follow_download(B / "allocation.json", B / "ledger.json", rq, receipt, archive_path)
            archive = archive_path.read_bytes()
            check_download_receipt(spec, archive, rec, read(B / "ledger.json")["transactions"])
            members = verifier.validate_producer_zip(archive)
            guard.require("execution-record.json" in members, f"artifact {spec['id']} lacks execution-record.json")
            record = json.loads(members["execution-record.json"].decode("utf-8", "strict"))
            member_names = {"execution-record.json"}
            for step in record.get("selected_steps", []) if isinstance(record, dict) else []:
                for ref in step.get("reports", []) if isinstance(step, dict) else []:
                    member_names.update((ref.get("path"), ref.get("selection_path")))
            guard.require(member_names == set(members), f"artifact {spec['id']} members differ from its execution-record inventory")
            downloads.append({"spec": spec, "archive": archive, "members": members, "receipt": rec})
        normal = proposal["existing_normal_pr"]
        merge_sha = normal["tested_merge_sha"]
        expected = {"run_id": str(normal["run_id"]), "run_attempt": str(normal["attempt"]), "source_sha": merge_sha, "event": "pull_request",
                    "workflow_ref": f"szTheory/sigra/.github/workflows/ci.yml@refs/pull/{normal['number']}/merge",
                    "workflow_sha": merge_sha, "classifier_result": "success", "docs_only": "false"}
        # This scoped copy was pinned to the frozen Git blob during offline preflight.
        workflow_bytes = (B / "normal-workflow.yml").read_bytes()
        producers = {"browser-execution-" + d["spec"]["name"].removeprefix("browser-execution-"): d["members"] for d in downloads}
        policy = verifier._run_browser_policy(workflow_bytes, producers, expected)
        save(B / "browser-policy-result.json", {"expected_identity": expected, "policy_result": policy,
             "artifacts": [{k: d["spec"][k] for k in ("id", "name", "digest", "run_id", "head_sha", "attempt")} for d in downloads]})

        # Existing canonical docs-only collector publishes the exact two frozen refs, opens one draft PR,
        # discovers and collects the docs pull_request run, and the independent verifier rejects incomplete evidence.
        command = ["bash", str(R / "ci-pr-proof.sh"), "--family", "docs-only", "--freeze", str(B / "pr-freeze.json"),
                   "--allocation", str(B / "allocation.json"), "--evidence", str(B / "docs-only-evidence.json"),
                   "--requests", str(B / "ledger.json"), "--repo-root", str(ROOT), "--revision-freeze", str(B / "proposal.json"),
                   "--action-approval", str(B / "approval.json"), "--docs-publication-receipt", str(B / "docs-publication-receipt.json")]
        proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
        save(B / "docs-collector-output.json", {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr})
        guard.require(proc.returncode == 0, "docs collector stopped; preserve its ledger and do not restart")
        verifier_result = subprocess.run([sys.executable, str(R / "ci-hosted-gate-verify.py"), "--mode", "pr", "--family", "docs-only", "--evidence", str(B / "docs-only-evidence.json")],
                                         cwd=ROOT, capture_output=True, text=True, check=False)
        save(B / "docs-verifier-output.json", {"returncode": verifier_result.returncode, "stdout": verifier_result.stdout, "stderr": verifier_result.stderr})
        guard.require(verifier_result.returncode == 0, "independent docs-only evidence verifier rejected collection")
        docs_verifier = module(R / "ci-hosted-gate-verify.py", "remaining_docs_pair_verifier")
        docs_evidence = read(B / "docs-only-evidence.json")
        captured_docs = {}
        docs_verifier.verify_pr_family(docs_evidence, "docs-only", captured_docs)
        docs_verifier.verify_docs_workflow_relation(workflow_bytes, captured_docs["workflow_bytes"])
        save(B / "workflow-relation-result.json", {"status":"passed", "normal_workflow_sha256":digest(workflow_bytes),
             "docs_workflow_sha256":digest(captured_docs["workflow_bytes"]), "relation":"exact single pull_request branch allowance"})
        state["status"] = "collected-and-independently-verified"
    except BaseException as error:
        state.update(status="halted", stop=f"{type(error).__name__}: {error}")
        raise
    finally:
        state["closed"] = True; state["closed_epoch"] = int(time.time())
        state["preserved_ledger_sha256"] = digest((B / "ledger.json").read_bytes()) if (B / "ledger.json").exists() else None
        save(B / "run-state.json", state, exclusive=False)
        ledger_value = read(B / "ledger.json") if (B / "ledger.json").exists() else {"transactions": []}
        transactions = ledger_value.get("transactions", [])
        save(B / "attempt-result.json", {"state": state, **ci_accounting(transactions),
             "ledger_sha256": state["preserved_ledger_sha256"]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="requires a fresh exact proposal approval committed at HEAD")
    args = parser.parse_args()
    try:
        if args.run:
            activate()
            print(json.dumps(read(B / "run-state.json"), sort_keys=True))
        else:
            print(json.dumps(offline(), sort_keys=True))
    except (guard.Refusal, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"STOP: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
