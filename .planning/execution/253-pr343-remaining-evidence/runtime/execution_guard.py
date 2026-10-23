"""Narrow live-request guard for the exact offline-prepared continuation."""
from __future__ import annotations

import hashlib
import base64
import json
import re
import subprocess
from pathlib import Path

B = Path(__file__).resolve().parent.parent
ROOT = next(p for p in B.parents if (p / ".git").exists())
APPROVAL = B / "approval.json"
PROPOSAL = B / "proposal.json"
ALLOCATION = B / "allocation.json"
LEDGER = B / "ledger.json"


class Refusal(RuntimeError):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def response_json(tx):
    try:
        return json.loads(base64.b64decode(tx.get("response_body_base64", ""), validate=True))
    except (ValueError, TypeError, json.JSONDecodeError):
        return None


def allowed_docs_artifact(artifact_id, rows, proposal):
    """Permit only a producer advertised by the exact docs PR's completed successful run."""
    docs = read(B / "pr-freeze.json")["docs-only"]
    created = [response_json(tx) for tx in rows if tx.get("family") == "docs-only" and tx.get("route_id") == "pr_create"
               and tx.get("actual_status") == 201]
    if len(created) != 1 or not isinstance(created[0], dict):
        return False
    pr = created[0]
    number = pr.get("number")
    if type(number) is not int or pr.get("draft") is not True:
        return False
    reads = [response_json(tx) for tx in rows if tx.get("family") == "docs-only" and tx.get("route_id") == "pr_read"
             and tx.get("actual_status") == 200]
    if not any(isinstance(v, dict) and v.get("number") == number and v.get("state") == "open" and v.get("draft") is True
               and v.get("merged") is False and (v.get("head") or {}).get("ref") == docs["head_ref"]
               and (v.get("head") or {}).get("sha") == docs["head_sha"] and (v.get("base") or {}).get("ref") == docs["base_ref"]
               and (v.get("base") or {}).get("sha") == docs["base_sha"] for v in reads):
        return False
    runs = [response_json(tx) for tx in rows if tx.get("family") == "docs-only" and tx.get("route_id") == "run"
            and tx.get("actual_status") == 200]
    valid_run_ids = set()
    for run in runs:
        linked = [v for v in (run.get("pull_requests") or []) if isinstance(v, dict) and v.get("number") == number
                  and (v.get("head") or {}).get("sha") == docs["head_sha"] and (v.get("base") or {}).get("sha") == docs["base_sha"]]
        if (isinstance(run, dict) and run.get("workflow_id") == 259268962 and run.get("event") == "pull_request"
                and run.get("head_sha") == docs["head_sha"] and run.get("head_branch") == docs["head_ref"]
                and run.get("status") == "completed" and run.get("conclusion") == "success"
                and type(run.get("run_attempt")) is int and run.get("run_attempt") == 1 and len(linked) == 1):
            valid_run_ids.add(run.get("id"))
    discoveries = [response_json(tx) for tx in rows if tx.get("family") == "docs-only" and tx.get("route_id") == "workflow_runs"
                   and tx.get("actual_status") == 200]
    found_ids = {v.get("id") for page in discoveries if isinstance(page, dict) for v in (page.get("workflow_runs") or [])
                 if isinstance(v, dict) and v.get("event") == "pull_request" and v.get("head_sha") == docs["head_sha"]}
    pattern = re.compile(r"https://github\.com/szTheory/sigra/actions/runs/([1-9][0-9]*)/job/[1-9][0-9]*\Z")
    for tx in rows:
        if tx.get("family") == "shared" and tx.get("route_id") == "check_runs" and tx.get("category") == "run_discovery" and tx.get("actual_status") == 200:
            page = response_json(tx)
            if not isinstance(page, dict) or page.get("total_count") != len(page.get("check_runs") or []):
                continue
            for check in page["check_runs"]:
                match = pattern.fullmatch(check.get("details_url") or "")
                if check.get("head_sha") == docs["head_sha"] and (check.get("app") or {}).get("id") == 15368 and match:
                    found_ids.add(int(match[1]))
    listings = [tx for tx in rows if tx.get("family") == "docs-only" and tx.get("route_id") == "run_artifacts"
                and tx.get("actual_status") == 200]
    for tx in listings:
        page = response_json(tx)
        if not isinstance(page, dict) or not found_ids.intersection(valid_run_ids):
            continue
        matches = [a for a in page.get("artifacts", []) if isinstance(a, dict) and a.get("id") == artifact_id
                   and a.get("expired") is False]
        if len(matches) != 1:
            continue
        item = matches[0]
        run = item.get("workflow_run") or {}
        run_id = run.get("id")
        attempt = next((v.get("run_attempt") for v in runs if isinstance(v, dict) and v.get("id") == run_id), None)
        seams = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
        wanted_names = {f"browser-execution-{s}-{run_id}-{attempt}" for s in seams}
        if (run_id in found_ids and run_id in valid_run_ids and attempt and item.get("name") in wanted_names
                and run.get("head_sha") == docs["head_sha"] and type(item.get("size_in_bytes")) is int and item["size_in_bytes"] > 0
                and isinstance(item.get("digest"), str) and re.fullmatch(r"sha256:[a-f0-9]{64}", item["digest"])):
            expected_path = f"/repos/szTheory/sigra/actions/runs/{run_id}/artifacts"
            if expected_path in tx.get("url", ""):
                return True
    return False


def require(ok, message):
    if not ok:
        raise Refusal(message)


def committed(path: Path):
    rel = path.resolve().relative_to(ROOT).as_posix()
    listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", "--", rel], capture_output=True)
    require(listed.returncode == 0, "exact proposal approval is not tracked")
    stored = subprocess.run(["git", "-C", str(ROOT), "show", f"HEAD:{rel}"], capture_output=True)
    require(stored.returncode == 0 and stored.stdout == path.read_bytes(), "exact proposal approval differs from committed HEAD bytes")


def verify_approval():
    require(APPROVAL.is_file(), "fresh exact proposal approval is missing")
    committed(APPROVAL)
    proposal_raw = PROPOSAL.read_bytes()
    p, a = read(PROPOSAL), read(APPROVAL)
    require(a.get("schema") == "sigra.phase253.pr343-remaining-evidence-approval/v1"
            and a.get("decision") == "approve", "approval schema or decision is invalid")
    require(a.get("proposal_sha256") == sha(proposal_raw), "approval does not bind the exact proposal bytes")
    require(a.get("scope") == p["approval_required"]["scope"], "approval scope differs from proposal")
    require(isinstance(a.get("decision_text"), str) and a["decision_text"].strip(), "literal approval text is required")
    start, end = a.get("approved_at_epoch"), a.get("expires_epoch")
    require(type(start) is int and type(end) is int and start < end <= start + 86400,
            "approval expiry must be positive and no more than 24 hours")
    import time
    require(start <= int(time.time()) < end, "approval is not currently valid")
    return p, a


def check_request(req, rows):
    p, _ = verify_approval()
    limits = p["request_budget"]["category_limits"]
    maxima = p["request_budget"]["permitted_request_maxima"]
    total_ceiling = sum(maxima.values())
    require(len(rows) < p["request_budget"]["max_requests"], "total request ceiling exhausted")
    require(len(rows) < total_ceiling, "aggregate proposal request ceiling exhausted")
    require(not any(tx.get("actual_status") in (401, 403, 429) or tx.get("error") for tx in rows),
            "prior auth/rate/transport failure closed the window")
    require(req.get("method") in ("GET", "POST"), "unsupported method")
    route, family, category = req.get("route_id"), req.get("family"), req.get("category")
    require(route not in {"dispatch", "cancel_run", "rerun", "rerun_failed_jobs", "merge", "update_ref", "delete_ref"},
            "dispatch, rerun, merge, or ref mutation is forbidden")
    require(family in ("normal", "docs-only", "shared"), "request family is outside this proposal")
    require(category in limits and category in maxima, "request category is outside the frozen proposal")
    allowed_docs = {"rate_limit", "rules_main", "branch_protection", "workflow", "git_create_tree", "git_create_commit",
                    "git_get_commit", "git_get_blob", "get_ref", "create_ref", "pr_create", "pr_read", "compare",
                    "repo_contents", "workflow_runs", "run", "attempt_jobs", "check_runs", "run_artifacts", "artifact_zip"}
    if route == "artifact_zip":
        require(req.get("method") == "GET" and category == "artifact_downloads", "artifact downloads must be measured GETs")
        aid = (req.get("params") or {}).get("artifact_id")
        allowed = (family == "normal" and aid in {x["id"] for x in p["browser_artifacts"]}) or \
                  (family == "docs-only" and allowed_docs_artifact(aid, rows, p))
        require(allowed, "artifact ID/family is outside the five PR343 items or verified docs-run inventory")
    else:
        require(family in ("docs-only", "shared"), "only the frozen docs proof and shared preflight are allowed")
        require(route in allowed_docs, "route is outside the docs-only collector")
        if req.get("method") == "POST":
            require((route == "pr_create" and family == "docs-only" and category == "pr_create") or
                    (route in {"git_create_tree", "git_create_commit", "create_ref"} and family == "docs-only"
                     and category == "docs_publication"), "unapproved write route")
            if route == "pr_create":
                f = read(B / "pr-freeze.json")["docs-only"]
                body = req.get("body") or {}
                require(body == {"title":"Phase 253 docs-only CI proof (draft, do not merge)","head":f["head_ref"],
                                 "base":f["base_ref"],"body":"Draft proof pull request; never merged.","draft":True},
                        "PR creation fields differ from the frozen docs-only action")
            if route in {"git_create_tree", "git_create_commit", "create_ref"}:
                require(req.get("family") == "docs-only" and req.get("category") == "docs_publication",
                        "frozen docs publication write scope is required")
                f = read(B / "pr-freeze.json")["docs-only"]
                pub = f["publication"]
                rows_here = [x for x in rows if x.get("family") == "docs-only" and x.get("category") == "docs_publication"]
                stage, offset = divmod(len(rows_here), 7)
                require(stage < 2, "both frozen docs refs have already been published")
                base = stage == 0
                ref = f["base_ref"] if base else f["head_ref"]
                commit = f["base_sha"] if base else f["head_sha"]
                tree = pub["docs_base_tree"] if base else pub["docs_head_tree"]
                parent = pub["candidate_sha"] if base else f["base_sha"]
                path = ".github/workflows/ci.yml" if base else "guides/reference/phase253-docs-only-proof.md"
                content = (B / ("docs-workflow.yml" if base else "docs-proof.md")).read_text()
                author = {"name":"Sigra Publication Bot","email":"sigra-publication@users.noreply.github.com",
                          "date":pub["date_utc_second"]}
                body = req.get("body") or {}
                if route == "git_create_tree":
                    require(offset == 0 and body == {"base_tree": pub["candidate_tree"] if base else pub["docs_base_tree"],
                            "tree":[{"path":path,"mode":"100644","type":"blob","content":content}]},
                            "docs tree write differs from the frozen path, parent tree, or exact source bytes")
                elif route == "git_create_commit":
                    require(offset == 1 and body == {"message":"Phase 253 docs probe base workflow exception\n" if base else "Phase 253 docs-only probe head\n",
                            "tree":tree,"parents":[parent],"author":author,"committer":author},
                            "docs commit write differs from the frozen source commit fields")
                else:
                    require(offset == 5 and body == {"ref":"refs/heads/" + ref,"sha":commit},
                            "create_ref may only create the exact frozen docs ref at its frozen commit")
    counts = {}
    for tx in rows:
        counts[tx.get("category")] = counts.get(tx.get("category"), 0) + 1
    ceiling = min(limits[category], maxima[category])
    require(counts.get(category, 0) < ceiling, f"category {category} ceiling exhausted")


def authorize_request(allocation_path, ledger_path, request_path):
    p, _ = verify_approval()
    allocation = read(allocation_path)
    frozen = read(B / "pr-freeze.json")
    require(Path(allocation_path).resolve() == ALLOCATION.resolve() and Path(ledger_path).resolve() == LEDGER.resolve(),
            "request is not using the once-only scoped allocation and ledger")
    require(allocation.get("allocation_kind") == "production" and allocation.get("max_requests") == 120
            and allocation.get("window_id") == p["request_budget"]["window_id"]
            and allocation.get("category_limits") == p["request_budget"]["category_limits"]
            and allocation.get("source_sha256") == sha((B / "pr-freeze.json").read_bytes())
            and allocation.get("bound_documents") == frozen.get("bound_documents"), "allocation differs from exact proposal")
    ledger = read(ledger_path) if Path(ledger_path).exists() else {"transactions": [], "terminal_stop": None}
    require(not ledger.get("terminal_stop"), "ledger has a terminal stop; never restart")
    check_request(read(request_path), ledger.get("transactions", []))
    return True
