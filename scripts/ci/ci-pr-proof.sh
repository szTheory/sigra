#!/usr/bin/env bash
# Phase 253 plan 42: finite real PR collector for the normal and docs-only actual pull requests.
#
#   ci-pr-proof.sh --prepare --publication RECEIPT --manifest MANIFEST --output FREEZE [--repo-root DIR] [--poll-interval SECONDS]
#                  [--budget-document PATH] [--bound-document PATH ...]
#   ci-pr-proof.sh --check-only --freeze FREEZE [--allocation ALLOCATION]
#   ci-pr-proof.sh --family normal|docs-only --freeze FREEZE --allocation ALLOCATION --evidence OUT --requests LEDGER [--repo-root DIR]
#   ci-pr-proof.sh --verify EVIDENCE [--docs-evidence EVIDENCE] [--server-journal JSON] [--docs-server-journal JSON]
#
# Every GitHub transaction goes through scripts/ci/ci-hosted-transport.py (predebited, typed, repository
# scoped, no implicit retry/redirect). --prepare and --check-only perform no network I/O. --verify never
# trusts collector output: it hands the retained bytes to scripts/ci/ci-hosted-gate-verify.py.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export SIGRA_PR_PROOF_ROOT="$ROOT"
export PYTHONDONTWRITEBYTECODE=1

if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit $(( $# == 0 ))
fi

exec python3 - "$@" <<'PYEOF'
import argparse
import base64
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(os.environ["SIGRA_PR_PROOF_ROOT"])
TRANSPORT = ROOT / "scripts/ci/ci-hosted-transport.py"
VERIFY = ROOT / "scripts/ci/ci-hosted-gate-verify.py"
PUBLICATION = ROOT / "scripts/ci/ci-git-publication.py"
BUDGETS = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-BUDGETS.md"
BUDGET_NAME = "253-LOAD-RECOVERY-BUDGETS.md"
BOUND_DEFAULTS = (".github/workflows/ci.yml", "scripts/ci/ci-browser-records.mjs")
FREEZE_SCHEMA = "sigra.phase253.pr-proof-freeze/v1"
EVIDENCE_SCHEMA = "sigra.phase253.pr-proof-evidence/v1"
REPO = "szTheory/sigra"
WORKFLOW_ID = 259268962
WORKFLOW_PATH = ".github/workflows/ci.yml"
DOCS_PATH = "guides/reference/phase253-docs-only-proof.md"
CI_PATH = WORKFLOW_PATH
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
FAMILY_REFS = {"normal": ("gsd/253-replan-candidate", "main"),
               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")}
TERMINAL_POLLS = {"normal": 15, "docs-only": 12}


class Stop(Exception):
    """A preserved, honest collection stop: the evidence records it and verification rejects it."""


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def atomic_write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def git(repo, *args, data=None):
    result = subprocess.run(["git", "-C", str(repo), *args], input=data, capture_output=True)
    if result.returncode:
        raise SystemExit(f"ci-pr-proof: git {args[0]} failed: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout


def bound_document(path):
    full = Path(path) if Path(path).is_absolute() else ROOT / path
    return {"path": path, "sha256": sha256(full.read_bytes())}


# ------------------------------------------------------------------------------------------ prepare
def prepare(args):
    publisher = load(PUBLICATION, "ci_git_publication")
    verifier = load(VERIFY, "ci_hosted_gate_verify")
    repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
    receipt_path, manifest_path = Path(args.publication), Path(args.manifest)
    try:
        publisher.verify_publication(receipt_path)
        manifest = publisher.validate_manifest(json.loads(manifest_path.read_text()))
    except (publisher.PublicationError, OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"ci-pr-proof: publication proof rejected: {error}")
    receipt = read_json(receipt_path)
    if (manifest["status"] != "ready-local-proposal" or receipt.get("manifest_sha256") != sha256(manifest_path.read_bytes())
            or receipt.get("candidate_sha") != manifest["candidate_helper_commit"]):
        raise SystemExit("ci-pr-proof: publication receipt does not bind the ready manifest and candidate")
    parent, candidate = manifest["server_parent_sha"], manifest["candidate_helper_commit"]
    docs_base, docs_head = manifest["docs_base_commit"], manifest["docs_head_commit"]
    if manifest.get("docs_head_path") != DOCS_PATH:
        raise SystemExit("ci-pr-proof: manifest documentation path is not the exact proof file")

    def paths(base, head):
        return [item for item in git(repo, "diff", "--name-only", "-z", base, head).decode("utf-8", "strict").split("\0") if item]

    def blob(commit, path):
        return git(repo, "rev-parse", f"{commit}:{path}").decode().strip()

    normal_paths, docs_paths, docs_base_paths = paths(parent, candidate), paths(docs_base, docs_head), paths(candidate, docs_base)
    if not normal_paths or docs_paths != [DOCS_PATH] or docs_base_paths != [CI_PATH]:
        raise SystemExit("ci-pr-proof: local diffs are not a non-empty normal delta, a trigger-only docs base, and exactly one docs file")
    ci_entry = git(repo, "ls-tree", docs_base, CI_PATH).decode().split()
    docs_entry = git(repo, "ls-tree", docs_head, DOCS_PATH).decode().split()
    freeze = {
        "schema_version": FREEZE_SCHEMA, "repository": REPO,
        "workflow": {"id": WORKFLOW_ID, "path": WORKFLOW_PATH}, "required_names": list(verifier.REQUIRED_NAMES),
        "source": {"manifest_sha256": sha256(manifest_path.read_bytes()), "publication_receipt_sha256": sha256(receipt_path.read_bytes()),
                   "source_sha": manifest["source_sha"], "server_parent_sha": parent},
        "normal": {"head_ref": FAMILY_REFS["normal"][0], "base_ref": "main", "head_sha": candidate,
                   "workflow_blob": blob(candidate, CI_PATH), "local_diff_paths": normal_paths},
        "docs-only": {"head_ref": FAMILY_REFS["docs-only"][0], "base_ref": FAMILY_REFS["docs-only"][1],
                      "head_sha": docs_head, "base_sha": docs_base, "workflow_blob": blob(docs_base, CI_PATH),
                      "docs_blob": blob(docs_head, DOCS_PATH), "local_diff_paths": docs_paths,
                      "base_local_diff_paths": docs_base_paths,
                      "publication": {"candidate_sha": candidate, "candidate_tree": git(repo, "rev-parse", f"{candidate}^{{tree}}").decode().strip(),
                                      "docs_base_tree": git(repo, "rev-parse", f"{docs_base}^{{tree}}").decode().strip(),
                                      "docs_head_tree": git(repo, "rev-parse", f"{docs_head}^{{tree}}").decode().strip(),
                                      "ci_mode": ci_entry[0], "docs_mode": docs_entry[0],
                                      "date_utc_second": manifest["commit_metadata"]["date_utc_second"]}},
        "poll": {"interval_seconds": args.poll_interval, "discovery_attempts": 2,
                 "terminal_polls": dict(TERMINAL_POLLS)},
        "bound_documents": [bound_document(path) for path in (args.budget_document or BUDGETS, *BOUND_DEFAULTS, *(args.bound_document or []))],
    }
    freeze["freeze_sha256"] = sha256(canonical({key: value for key, value in freeze.items() if key != "freeze_sha256"}))
    atomic_write(args.output, (json.dumps(freeze, indent=2, sort_keys=True) + "\n").encode())
    print(json.dumps({"status": "freeze_prepared", "freeze_sha256": freeze["freeze_sha256"], "network_requests": 0}))


# ---------------------------------------------------------------------------------------- check only
def check_freeze(freeze_path, allocation_path=None):
    transport = load(TRANSPORT, "ci_hosted_transport")
    raw = Path(freeze_path).read_bytes()
    freeze = json.loads(raw)
    if freeze.get("schema_version") != FREEZE_SCHEMA or freeze.get("repository") != REPO:
        raise SystemExit("ci-pr-proof: freeze schema or repository mismatch")
    stated = freeze.get("freeze_sha256")
    if stated != sha256(canonical({key: value for key, value in freeze.items() if key != "freeze_sha256"})):
        raise SystemExit("ci-pr-proof: freeze digest differs from its content")
    for family in ("normal", "docs-only"):
        spec = freeze.get(family) or {}
        if (spec.get("head_ref"), spec.get("base_ref")) != FAMILY_REFS[family]:
            raise SystemExit(f"ci-pr-proof: {family} refs are not the exact proof refs")
    for item in freeze.get("bound_documents") or []:
        bound = Path(item["path"])
        if sha256((bound if bound.is_absolute() else ROOT / bound).read_bytes()) != item["sha256"]:
            raise SystemExit(f"ci-pr-proof: bound document changed since the freeze: {item['path']}")
    if not any(Path(item["path"]).name == BUDGET_NAME for item in freeze.get("bound_documents") or []):
        raise SystemExit("ci-pr-proof: the budget document binding is required")
    result = {"status": "freeze_valid", "network_requests": 0, "category_limits": transport.PRODUCTION_CATEGORY_LIMITS}
    if allocation_path:
        allocation = json.loads(Path(allocation_path).read_text())
        try:
            transport._validate_allocation(allocation)
        except transport.TransportError as error:
            raise SystemExit(f"ci-pr-proof: allocation rejected: {error}")
        if (allocation.get("allocation_kind") != "production" or allocation.get("source_sha256") != sha256(raw)
                or allocation.get("bound_documents") != freeze.get("bound_documents")
                or allocation.get("category_limits") != transport.PRODUCTION_CATEGORY_LIMITS):
            raise SystemExit("ci-pr-proof: allocation is not the production allocation bound to this exact freeze")
        result["allocation_valid"] = True
    print(json.dumps(result, sort_keys=True))
    return freeze


# --------------------------------------------------------------------------------------- collection
class Collector:
    def __init__(self, args):
        self.family = args.family
        self.freeze_raw = Path(args.freeze).read_bytes()
        self.freeze = check_freeze(args.freeze, args.allocation)
        self.allocation_path = Path(args.allocation)
        self.allocation_raw = self.allocation_path.read_bytes()
        self.allocation = json.loads(self.allocation_raw)
        self.ledger_path = Path(args.requests)
        self.evidence_path = Path(args.evidence)
        self.repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
        self.work = Path(tempfile.mkdtemp(prefix="sigra-pr-proof-"))
        self.spec = self.freeze[self.family]
        self.notes, self.downloads = [], []
        self.counter = 0

    def ledger(self):
        return read_json(self.ledger_path) if self.ledger_path.exists() else {"transactions": []}

    def call(self, mode, route_id, category, method="GET", params=None, query=None, body=None, page_ordinal=None, family=None):
        self.counter += 1
        request = {"route_id": route_id, "method": method, "category": category, "family": family or self.family}
        for key, value in (("params", params), ("query", query), ("body", body), ("page_ordinal", page_ordinal)):
            if value is not None:
                request[key] = value
        request_file, receipt_file, body_file = (self.work / f"{self.counter:03d}.{suffix}" for suffix in ("request", "receipt", "body"))
        request_file.write_text(json.dumps(request))
        flag = {"one": [], "pages": ["--fetch-pages"], "download": ["--follow-download"]}[mode]
        process = subprocess.run([sys.executable, str(TRANSPORT), *flag, "--allocation", str(self.allocation_path),
                                  "--ledger", str(self.ledger_path), "--request", str(request_file), "--output", str(receipt_file),
                                  "--body-output", str(body_file)], capture_output=True, text=True, timeout=900)
        if process.returncode:
            raise Stop(f"{route_id}: {process.stderr.strip() or 'transport stopped'}")
        data = body_file.read_bytes() if body_file.exists() else b""
        status = None
        if mode == "one":
            status = read_json(receipt_file)["actual_status"]
        elif mode == "download":
            status = read_json(receipt_file)["actual_status"]
        return status, data

    def jcall(self, *args, expect=(200,), **kwargs):
        status, data = self.call(*args, **kwargs)
        if status is not None and status not in expect:
            raise Stop(f"{args[1]} returned HTTP {status}; expected {list(expect)}")
        return status, (json.loads(data) if data else None)

    def preflight(self):
        if any(tx.get("family") == "shared" for tx in self.ledger()["transactions"]):
            return
        self.jcall("one", "rate_limit", "preflight", family="shared")
        self.jcall("pages", "rules_main", "preflight", query={"per_page": 100}, family="shared")
        self.jcall("one", "branch_protection", "preflight", family="shared", expect=(200, 404))
        self.jcall("one", "workflow", "preflight", params={"workflow_id": WORKFLOW_ID}, family="shared")

    def publish_docs(self):
        pub = self.spec["publication"]
        author = {"name": "Sigra Publication Bot", "email": "sigra-publication@users.noreply.github.com", "date": pub["date_utc_second"]}

        def text(commit, path):
            return git(self.repo, "cat-file", "blob", git(self.repo, "rev-parse", f"{commit}:{path}").decode().strip()).decode("utf-8", "strict")

        stages = [
            ("docs-base", FAMILY_REFS["docs-only"][1], self.spec["base_sha"], pub["docs_base_tree"], pub["candidate_tree"], pub["candidate_sha"],
             "Phase 253 docs probe base workflow exception\n", CI_PATH, pub["ci_mode"], self.spec["base_sha"], self.spec["workflow_blob"]),
            ("docs-head", FAMILY_REFS["docs-only"][0], self.spec["head_sha"], pub["docs_head_tree"], pub["docs_base_tree"], self.spec["base_sha"],
             "Phase 253 docs-only probe head\n", DOCS_PATH, pub["docs_mode"], self.spec["head_sha"], self.spec["docs_blob"]),
        ]
        for label, ref, commit, tree, base_tree, parent, message, path, mode, source_commit, blob_sha in stages:
            body = {"base_tree": base_tree, "tree": [{"path": path, "mode": mode, "type": "blob", "content": text(source_commit, path)}]}
            _, created_tree = self.jcall("one", "git_create_tree", "docs_publication", "POST", body=body, expect=(201,))
            if created_tree.get("sha") != tree:
                raise Stop(f"{label}: server tree differs from the frozen tree")
            commit_body = {"message": message, "tree": tree, "parents": [parent], "author": author, "committer": author}
            _, created = self.jcall("one", "git_create_commit", "docs_publication", "POST", body=commit_body, expect=(201,))
            if created.get("sha") != commit:
                raise Stop(f"{label}: server commit differs from the frozen commit")
            _, readback = self.jcall("one", "git_get_commit", "docs_publication", params={"sha": commit})
            if readback.get("sha") != commit or readback.get("tree", {}).get("sha") != tree:
                raise Stop(f"{label}: commit readback differs")
            self.jcall("one", "git_get_blob", "docs_publication", params={"sha": blob_sha})
            probe_status, _ = self.jcall("one", "get_ref", "docs_publication", params={"branch": ref}, expect=(404,))
            self.jcall("one", "create_ref", "docs_publication", "POST", body={"ref": "refs/heads/" + ref, "sha": commit}, expect=(201,))
            _, ref_readback = self.jcall("one", "get_ref", "docs_publication", params={"branch": ref})
            if ref_readback.get("object", {}).get("sha") != commit:
                raise Stop(f"{label}: scoped ref readback differs")

    def sleep(self):
        time.sleep(max(0, int(self.freeze["poll"]["interval_seconds"])))

    def collect(self):
        head_ref, base_ref = FAMILY_REFS[self.family]
        head_sha = self.spec["head_sha"]
        self.preflight()
        if self.family == "docs-only":
            self.publish_docs()
        title = f"Phase 253 {self.family} CI proof (draft, do not merge)"
        _, created = self.jcall("one", "pr_create", "pr_create", "POST",
                                body={"title": title, "head": head_ref, "base": base_ref, "body": "Draft proof pull request; never merged.", "draft": True},
                                expect=(201,))
        number = created["number"]
        run_id = None
        for attempt in range(1, int(self.freeze["poll"]["discovery_attempts"]) + 1):
            _, found = self.jcall("one", "workflow_runs", "run_discovery", params={"workflow_id": WORKFLOW_ID},
                                  query={"event": "pull_request", "head_sha": head_sha, "per_page": 100})
            matches = [run for run in found.get("workflow_runs", []) if run.get("head_sha") == head_sha and run.get("event") == "pull_request"]
            if matches:
                run_id = matches[0]["id"]
                break
            if attempt < int(self.freeze["poll"]["discovery_attempts"]):
                self.sleep()
        if run_id is None:
            raise Stop("no pull_request workflow run was discovered for the published head")
        self.jcall("one", "rate_limit", "pre_watch_rate")
        run = None
        for poll in range(1, TERMINAL_POLLS[self.family] + 1):
            _, run = self.jcall("one", "run", "terminal_polls", params={"run_id": run_id})
            if run.get("status") == "completed":
                break
            if poll < TERMINAL_POLLS[self.family]:
                self.sleep()
        if run is None or run.get("status") != "completed":
            raise Stop("the run did not reach a terminal state inside the frozen poll allocation")
        attempt = run["run_attempt"]
        _, pr = self.jcall("one", "pr_read", "pr_identity", params={"pull_number": number})
        merge_sha = pr.get("merge_commit_sha")
        base_sha = (pr.get("base") or {}).get("sha")
        if not merge_sha or not base_sha:
            raise Stop("the PR has no tested merge commit or base identity")
        self.jcall("one", "compare", "pr_identity", params={"base_sha": base_sha, "head_sha": head_sha}, query={"per_page": 100, "page": 1})
        if self.family == "docs-only":
            self.jcall("one", "compare", "pr_identity", params={"base_sha": self.spec["publication"]["candidate_sha"], "head_sha": base_sha},
                       query={"per_page": 100, "page": 1})
        paths = [WORKFLOW_PATH] + ([DOCS_PATH] if self.family == "docs-only" else [])
        for path in paths:
            self.jcall("one", "repo_contents", "pr_identity", params={"content_path": path}, query={"ref": merge_sha})
        self.jcall("pages", "attempt_jobs", "attempt_jobs", params={"run_id": run_id, "attempt": attempt}, query={"per_page": 100})
        self.jcall("one", "check_runs", "native_checks", params={"commit_sha": head_sha}, query={"per_page": 100, "page": 1}, page_ordinal=1)
        _, listing = self.jcall("pages", "run_artifacts", "artifact_metadata", params={"run_id": run_id}, query={"per_page": 100})
        wanted = [f"browser-execution-{seam}-{run_id}-{attempt}" for seam in SEAMS]
        by_name = {}
        for item in listing.get("artifacts", []):
            by_name.setdefault(item.get("name"), []).append(item)
        for name in wanted:
            found = by_name.get(name, [])
            if len(found) != 1:
                self.notes.append(f"artifact inventory for {name} has {len(found)} entries; not downloaded")
                continue
            before = len(self.ledger()["transactions"])
            _, data = self.call("download", "artifact_zip", "artifact_downloads", params={"artifact_id": found[0]["id"]})
            added = self.ledger()["transactions"][before:]
            group = added[-1].get("request_group") if added else None
            self.downloads.append({"artifact_id": found[0]["id"], "name": name, "request_group": group,
                                   "zip_base64": base64.b64encode(data).decode("ascii")})
        return run

    def write(self, stop=None):
        evidence = {"schema_version": EVIDENCE_SCHEMA, "repository": REPO, "family": self.family,
                    "synthetic": self.allocation.get("mode") == "hermetic-test", "freeze": self.freeze,
                    "allocation_base64": base64.b64encode(self.allocation_raw).decode("ascii"),
                    "transport_ledger": self.ledger(), "server_journal": None, "downloads": self.downloads,
                    "collection": {"complete": stop is None and len(self.downloads) == 5, "stop": stop, "notes": self.notes}}
        atomic_write(self.evidence_path, (json.dumps(evidence, sort_keys=True) + "\n").encode())
        return evidence


def run_family(args):
    collector = Collector(args)
    stop = None
    try:
        collector.collect()
    except Stop as error:
        stop = str(error)
    evidence = collector.write(stop)
    print(json.dumps({"status": "collected" if evidence["collection"]["complete"] else "stopped", "family": args.family,
                      "requests": len(evidence["transport_ledger"]["transactions"]), "stop": stop, "notes": collector.notes}, sort_keys=True))
    return 0 if stop is None else 1


# ------------------------------------------------------------------------------------------ verify
def verify(args):
    verifier = load(VERIFY, "ci_hosted_gate_verify")

    def load_evidence(path, journal):
        evidence = read_json(path)
        if journal:
            evidence["server_journal"] = read_json(journal)
        return evidence

    first = load_evidence(args.verify, args.server_journal)
    try:
        if args.docs_evidence:
            result = verifier.verify_pr_pair(first, load_evidence(args.docs_evidence, args.docs_server_journal))
        else:
            result = verifier.verify_pr_family(first, first.get("family"))
    except verifier.VerificationError as error:
        print(f"ci-pr-proof: verification failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


def main():
    parser = argparse.ArgumentParser(prog="ci-pr-proof.sh")
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--verify")
    parser.add_argument("--family", choices=("normal", "docs-only"))
    parser.add_argument("--publication")
    parser.add_argument("--manifest")
    parser.add_argument("--output")
    parser.add_argument("--freeze")
    parser.add_argument("--allocation")
    parser.add_argument("--evidence")
    parser.add_argument("--requests")
    parser.add_argument("--repo-root")
    parser.add_argument("--docs-evidence")
    parser.add_argument("--server-journal")
    parser.add_argument("--docs-server-journal")
    parser.add_argument("--bound-document", action="append")
    parser.add_argument("--budget-document", help="path of the frozen budget document (default: the Phase253 load-recovery budgets)")
    parser.add_argument("--poll-interval", type=int, default=60)
    args = parser.parse_args()
    modes = [bool(args.prepare), bool(args.check_only), bool(args.verify), bool(args.family)]
    if sum(modes) != 1:
        parser.error("choose exactly one of --prepare, --check-only, --family or --verify")
    if args.prepare:
        if not (args.publication and args.manifest and args.output):
            parser.error("--prepare requires --publication, --manifest and --output")
        prepare(args)
        return 0
    if args.check_only:
        if not args.freeze:
            parser.error("--check-only requires --freeze")
        check_freeze(args.freeze, args.allocation)
        return 0
    if args.verify:
        return verify(args)
    if not (args.freeze and args.allocation and args.evidence and args.requests):
        parser.error("--family requires --freeze, --allocation, --evidence and --requests")
    return run_family(args)


sys.exit(main())
PYEOF
