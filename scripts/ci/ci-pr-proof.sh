#!/usr/bin/env bash
# Phase 253 plan 42: finite real PR collector for the normal and docs-only actual pull requests.
#
#   ci-pr-proof.sh --prepare --publication RECEIPT --manifest MANIFEST --output FREEZE [--repo-root DIR] [--poll-interval SECONDS]
#                  [--budget-document PATH] [--bound-document PATH ...] [--main-record MAIN-FETCH-R12]  (required for the r12 head)
#   ci-pr-proof.sh --check-only --freeze FREEZE [--allocation ALLOCATION]
#   ci-pr-proof.sh --main-preflight --freeze PR-FREEZE --current-main SHA --output FILE [--repo-root DIR]
#                  (step 0, r12 freezes: exit 0 only for status clean; the file is exclusive-create; never fetches)
#   ci-pr-proof.sh --family normal|docs-only --freeze FREEZE --allocation ALLOCATION --evidence OUT --requests LEDGER [--repo-root DIR]
#                  --revision-freeze CANARY-FREEZE --action-approval FILE   (committed docs_and_prs section approval, required)
#                  [--main-preflight FILE]   (normal family on an r12 freeze: required, the clean step-0 preflight)
#                  [--docs-publication-receipt OUT]   (docs-only: exclusive-create receipt derived from the ledger rows)
#   ci-pr-proof.sh --verify EVIDENCE [--docs-evidence EVIDENCE] [--server-journal JSON] [--docs-server-journal JSON]
#
# Every GitHub transaction goes through scripts/ci/ci-hosted-transport.py (predebited, typed, repository
# scoped, no implicit retry/redirect). --prepare, --check-only and --main-preflight perform no network I/O. --verify
# never trusts collector output: it hands the retained bytes to scripts/ci/ci-hosted-gate-verify.py.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export SIGRA_PR_PROOF_ROOT="$ROOT"
export PYTHONDONTWRITEBYTECODE=1

if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit $(( $# == 0 ))
fi

exec python3 - "$@" <<'PYEOF'
import argparse
import base64
import hashlib
import importlib.util
import json
import os
import re
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
# 253-102/253-111/253-119/253-130/253-137/253-166: the normal head is the candidate ref the canary freeze selected, one of
# exactly these seven names (ci-git-publication.py REF_PAIRS); the docs-only refs never vary.
NORMAL_HEADS = ("gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-r9-candidate", "gsd/253-replan-r10-candidate", "gsd/253-replan-r11-candidate", "gsd/253-replan-r12-candidate", "gsd/253-replan-r13-candidate")
# 253-138/253-166: the r12 and r13 normal heads are prepared only against the recorded fresh main (--main-record).
MAIN_RECORD_HEADS = {"gsd/253-replan-r12-candidate": "r12", "gsd/253-replan-r13-candidate": "r13"}
FAMILY_REFS = {"normal": (NORMAL_HEADS, "main"),
               "docs-only": ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base")}
TERMINAL_POLLS = {"normal": 15, "docs-only": 12}
# 253-139: the offline step-0 preflight. GitHub runs pull_request CI on the test merge of the head into the CURRENT base,
# so a main that moved since the freeze is accepted only if the frozen main is its ancestor and the head merges cleanly.
PREFLIGHT_SCHEMA = "sigra.phase253.pr-main-preflight/r12"
PREFLIGHT_KEYS = ("schema", "freeze_sha256", "head_sha", "frozen_main", "current_main", "moved", "ancestor", "merge_preflight",
                  "status")
PREFLIGHT_MODE = object()  # --main-preflight given without a value selects the step-0 mode
SHA40 = re.compile(r"[0-9a-f]{40}")
DOCS_RECEIPT_SCHEMA = "sigra.phase253.pr-docs-publication-receipt/r12"
DOCS_NOT_APPLICABLE = {"status": "not_applicable",
                       "reason": "the docs-only base is the scoped ref gsd/253-replan-docs-base created in the same window"}


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


def frozen_refs(family, spec):
    """(head_ref, base_ref) of a frozen family; the normal head must be one of the known candidate names."""
    head_ref, base_ref = (spec or {}).get("head_ref"), (spec or {}).get("base_ref")
    if family == "normal":
        valid = isinstance(head_ref, str) and head_ref in NORMAL_HEADS and base_ref == FAMILY_REFS["normal"][1]
    else:
        valid = (head_ref, base_ref) == FAMILY_REFS[family]
    if not valid:
        raise SystemExit(f"ci-pr-proof: {family} refs are not the exact proof refs")
    return head_ref, base_ref


def exclusive_write(path, data):
    """Create path or fail: an existing file is never replaced (O_CREAT | O_EXCL)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def bound_document(path):
    full = Path(path) if Path(path).is_absolute() else ROOT / path
    return {"path": path, "sha256": sha256(full.read_bytes())}


# ------------------------------------------------------------------------------------------ prepare
def main_freshness_proof(publisher, repo, record, manifest, head_sha):
    """253-138: the PR base is the recorded fresh main. The publication's server parent must be the record's
    fetched_main_sha, its manifest must carry main_freshness over these exact record bytes, and the normal head must merge
    cleanly into that main (publisher.merge_preflight, the one merge test). Every refusal precedes any write or request."""
    def refuse(rule):
        raise SystemExit(f"ci-pr-proof: {rule}; network_requests 0")
    try:
        rel, raw, value = publisher.load_main_record(repo, record)
    except publisher.PublicationError as error:
        refuse(str(error))
    fetched = value["fetched_main_sha"]
    if manifest["server_parent_sha"] != fetched:
        refuse(f"server parent is not the recorded fresh main: server parent {manifest['server_parent_sha']}, "
               f"recorded fresh main {fetched}")
    fresh = manifest.get("main_freshness")
    if not isinstance(fresh, dict):
        refuse("the publication manifest has no main_freshness (prepare the publication with --main-record)")
    if fresh.get("record_sha256") != sha256(raw):
        refuse("the manifest main_freshness record_sha256 differs from the main-fetch record")
    try:
        preflight = publisher.merge_preflight(repo, head_sha, fetched)
    except publisher.PublicationError as error:
        refuse(str(error))
    if not preflight["clean"]:
        refuse("the normal head does not merge cleanly into the recorded fresh main: " + ", ".join(preflight["conflicts"]))
    bind_path = rel if repo.resolve() == ROOT.resolve() else str(repo / rel)
    return {"fetched_main_sha": fetched, "main_record_sha256": sha256(raw), "preflight": preflight,
            "binding": bound_document(bind_path)}


def prepare(args):
    publisher = load(PUBLICATION, "ci_git_publication")
    verifier = load(VERIFY, "ci_hosted_gate_verify")
    repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
    receipt_path, manifest_path = Path(args.publication), Path(args.manifest)
    try:
        publisher.verify_publication(receipt_path, bool(args.require_live_origin))
        manifest = publisher.validate_manifest(json.loads(manifest_path.read_text()))
    except (publisher.PublicationError, OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"ci-pr-proof: publication proof rejected: {error}")
    receipt = read_json(receipt_path)
    if (manifest["status"] != "ready-local-proposal" or receipt.get("manifest_sha256") != sha256(manifest_path.read_bytes())
            or receipt.get("candidate_sha") != manifest["candidate_helper_commit"]):
        raise SystemExit("ci-pr-proof: publication receipt does not bind the ready manifest and candidate")
    parent, candidate = manifest["server_parent_sha"], manifest["candidate_helper_commit"]
    docs_base, docs_head = manifest["docs_base_commit"], manifest["docs_head_commit"]
    candidate_ref = receipt.get("candidate_ref")
    normal_head = candidate_ref.removeprefix("refs/heads/") if isinstance(candidate_ref, str) and candidate_ref.startswith("refs/heads/") else None
    if normal_head not in NORMAL_HEADS:
        raise SystemExit("ci-pr-proof: the publication receipt's candidate_ref is not one of the known candidate refs")
    if manifest.get("docs_head_path") != DOCS_PATH:
        raise SystemExit("ci-pr-proof: manifest documentation path is not the exact proof file")
    if normal_head in MAIN_RECORD_HEADS and not args.main_record:
        raise SystemExit(f"ci-pr-proof: the {MAIN_RECORD_HEADS[normal_head]} normal head requires --main-record; network_requests 0")
    fresh = main_freshness_proof(publisher, repo, args.main_record, manifest, candidate) if args.main_record else None

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
        "normal": {"head_ref": normal_head, "base_ref": "main", "head_sha": candidate,
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
    if fresh:
        freeze["source"].update({"fetched_main_sha": fresh["fetched_main_sha"], "main_record_sha256": fresh["main_record_sha256"]})
        freeze["mergeability_preflight"] = fresh["preflight"]
        freeze["bound_documents"].append(fresh["binding"])
    freeze["freeze_sha256"] = sha256(canonical({key: value for key, value in freeze.items() if key != "freeze_sha256"}))
    atomic_write(args.output, (json.dumps(freeze, indent=2, sort_keys=True) + "\n").encode())
    print(json.dumps({"status": "freeze_prepared", "freeze_sha256": freeze["freeze_sha256"], "network_requests": 0}))


# ---------------------------------------------------------------------------------------- check only
def check_freeze(freeze_path, allocation_path=None, quiet=False):
    transport = load(TRANSPORT, "ci_hosted_transport")
    raw = Path(freeze_path).read_bytes()
    freeze = json.loads(raw)
    if freeze.get("schema_version") != FREEZE_SCHEMA or freeze.get("repository") != REPO:
        raise SystemExit("ci-pr-proof: freeze schema or repository mismatch")
    stated = freeze.get("freeze_sha256")
    if stated != sha256(canonical({key: value for key, value in freeze.items() if key != "freeze_sha256"})):
        raise SystemExit("ci-pr-proof: freeze digest differs from its content")
    for family in ("normal", "docs-only"):
        frozen_refs(family, freeze.get(family))
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
    if not quiet:
        print(json.dumps(result, sort_keys=True))
    return freeze


# --------------------------------------------------------------------------------- step-0 main preflight
def commit_present(repo, sha):
    return subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{sha}^{{commit}}"], capture_output=True).returncode == 0


def is_ancestor(repo, ancestor, descendant):
    result = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", ancestor, descendant], capture_output=True)
    if result.returncode not in (0, 1):
        raise SystemExit(f"ci-pr-proof: git merge-base failed: {result.stderr.decode('utf-8', 'replace').strip()}; network_requests 0")
    return result.returncode == 0


def preflight_document(publisher, repo, freeze, current_main):
    """The step-0 preflight of the frozen normal head against current_main: ancestry of the frozen main, then the one
    merge test (publisher.merge_preflight). rewritten wins over conflicted; only clean is accepted downstream."""
    frozen, head = freeze["source"]["fetched_main_sha"], freeze["normal"]["head_sha"]
    ancestor = is_ancestor(repo, frozen, current_main)
    try:
        merge = publisher.merge_preflight(repo, head, current_main)
    except publisher.PublicationError as error:
        merge = {"head": head, "base": current_main, "exit": None, "clean": False, "conflicts": [], "error": str(error)}
    status = "rewritten" if not ancestor else ("clean" if merge["clean"] else "conflicted")
    return {"schema": PREFLIGHT_SCHEMA, "freeze_sha256": freeze["freeze_sha256"], "head_sha": head, "frozen_main": frozen,
            "current_main": current_main, "moved": current_main != frozen, "ancestor": ancestor, "merge_preflight": merge,
            "status": status}


def main_preflight(args):
    """253-139 step 0: offline. 253-144's runner does the approved fetch and passes the fetched SHA in as --current-main."""
    def refuse(rule):
        raise SystemExit(f"ci-pr-proof: main preflight refused: {rule}; network_requests 0")
    current = args.current_main
    if not isinstance(current, str) or not SHA40.fullmatch(current):
        refuse("--current-main must be a full lowercase 40-hex commit SHA")
    if Path(args.output).exists():
        refuse(f"{args.output} already exists; the preflight file is exclusive-create")
    freeze = check_freeze(args.freeze, quiet=True)
    if not SHA40.fullmatch(str((freeze.get("source") or {}).get("fetched_main_sha"))):
        refuse("the freeze is not an r12 PR freeze (no source.fetched_main_sha)")
    repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
    if not commit_present(repo, current):
        refuse(f"current main {current} is not a commit in the local object store (fetch it first; this mode never fetches)")
    document = preflight_document(load(PUBLICATION, "ci_git_publication"), repo, freeze, current)
    try:
        exclusive_write(args.output, (json.dumps(document, indent=2, sort_keys=True) + "\n").encode())
    except FileExistsError:
        refuse(f"{args.output} already exists; the preflight file is exclusive-create")
    print(json.dumps({"status": document["status"], "moved": document["moved"], "current_main": current,
                      "conflicts": document["merge_preflight"].get("conflicts"), "output": str(args.output),
                      "network_requests": 0}, sort_keys=True))
    return 0 if document["status"] == "clean" else 1


def required_base_preflight(args, freeze):
    """The base_preflight the evidence records, checked before any write or request. An r12 normal family needs a clean
    step-0 preflight for this exact freeze and head, re-derived here; docs-only records not_applicable (its base is a
    scoped ref created in the same window); a pre-r12 freeze records nothing and takes no preflight."""
    def refuse(rule):
        raise SystemExit(f"ci-pr-proof: main preflight refused: {rule}; network_requests 0")
    given = args.main_preflight
    r12 = bool((freeze.get("source") or {}).get("fetched_main_sha"))
    if given is not None and args.family != "normal":
        refuse("--main-preflight applies to the normal family only")
    if not r12:
        if given is not None:
            refuse("--main-preflight applies only to an r12 PR freeze (one carrying source.fetched_main_sha)")
        return None
    if args.family != "normal":
        return dict(DOCS_NOT_APPLICABLE)
    if given is None:
        refuse("the r12 normal family requires --main-preflight FILE (the clean step-0 preflight)")
    try:
        raw = Path(given).read_bytes()
        document = json.loads(raw)
    except (OSError, ValueError) as error:
        refuse(f"the main preflight file is unreadable: {error}")
    if not isinstance(document, dict) or document.get("schema") != PREFLIGHT_SCHEMA or set(document) != set(PREFLIGHT_KEYS):
        refuse(f"the main preflight schema or field set is not {PREFLIGHT_SCHEMA}")
    if document["freeze_sha256"] != freeze.get("freeze_sha256"):
        refuse("the main preflight was made for another PR freeze")
    if document["head_sha"] != freeze["normal"]["head_sha"]:
        refuse("the main preflight names another normal head")
    if document["frozen_main"] != freeze["source"]["fetched_main_sha"]:
        refuse("the main preflight names another frozen main")
    if document["status"] != "clean":
        refuse(f"the step-0 main preflight is not clean (status {document['status']}; conflicts "
               f"{(document.get('merge_preflight') or {}).get('conflicts')})")
    current = document["current_main"]
    repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
    if not isinstance(current, str) or not SHA40.fullmatch(current) or not commit_present(repo, current):
        refuse(f"the preflight current main {current!r} is not a commit in the local object store")
    recomputed = preflight_document(load(PUBLICATION, "ci_git_publication"), repo, freeze, current)
    if recomputed != document:
        refuse(f"the main preflight differs from the recomputed preflight (status {recomputed['status']}, conflicts "
               f"{recomputed['merge_preflight'].get('conflicts')})")
    return {**document, "sha256": sha256(raw)}


# ---------------------------------------------------------------------------------- section approval
def approved_section(args):
    """The committed docs_and_prs approval gates every live mode; nothing is written or requested before it passes."""
    if not (args.revision_freeze and args.action_approval):
        raise SystemExit("ci-pr-proof: approval refused: live collection needs --revision-freeze and a committed docs_and_prs "
                         "section --action-approval")
    publisher = load(PUBLICATION, "ci_git_publication")
    repo = Path(args.repo_root).resolve() if args.repo_root else ROOT
    try:
        freeze, _ = publisher.load_freeze(Path(args.revision_freeze))
        record = publisher.check_section_approval(args.action_approval, freeze, "docs_and_prs", repo)
        # The same full policy gate the canary applies: frozen source, expired reruns, native_target, bounds, categories.
        publisher.check_revision_freeze(Path(args.revision_freeze), repo)
    except Exception as error:  # noqa: BLE001 - every malformed-freeze failure is the same uniform pre-request refusal
        raise SystemExit(f"ci-pr-proof: approval refused: {type(error).__name__}: {error}")
    return freeze["outward_actions"]["docs_and_prs"], record, (freeze.get("identity") or {}).get("candidate_ref")


# --------------------------------------------------------------------------------------- collection
class Collector:
    def __init__(self, args, section, action_approval, base_preflight=None):
        self.section = section
        self.base_preflight = base_preflight
        self.docs_receipt_path = Path(args.docs_publication_receipt) if args.docs_publication_receipt else None
        self.action_approval = action_approval
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
        self.check_section()

    def actions(self, kind):
        return [item for item in self.section.get("actions", []) if item.get("action") == kind]

    def check_section(self):
        """The approved docs_and_prs section must list exactly the objects and draft PR this family would create."""
        head_ref, base_ref = frozen_refs(self.family, self.spec)
        creates = [item for item in self.actions("pr_create") if item.get("family") == self.family]
        if (len(creates) != 1 or creates[0].get("head") != head_ref or creates[0].get("base") != base_ref
                or creates[0].get("draft") is not True):
            raise SystemExit(f"ci-pr-proof: the {self.family} PR create differs from the approved docs_and_prs section")
        if self.family == "docs-only":
            docs = self.actions("publish_docs_objects")
            refs = {("refs/heads/" + FAMILY_REFS["docs-only"][1], self.spec["base_sha"]),
                    ("refs/heads/" + FAMILY_REFS["docs-only"][0], self.spec["head_sha"])}
            if (len(docs) != 1 or docs[0].get("docs_base_commit") != self.spec["base_sha"]
                    or docs[0].get("docs_head_commit") != self.spec["head_sha"]
                    or {(item.get("ref"), item.get("sha")) for item in docs[0].get("refs", [])} != refs):
                raise SystemExit("ci-pr-proof: the docs object publication differs from the approved docs_and_prs section")

    def require_listed_pr(self, body):
        for item in self.actions("pr_create"):
            if (item.get("family") == self.family and item.get("head") == body.get("head")
                    and item.get("base") == body.get("base") and item.get("draft") is True and body.get("draft") is True):
                return
        raise Stop("pr_create is outside the approved docs_and_prs section")

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
        try:
            return status, (json.loads(data) if data else None)
        except (ValueError, UnicodeDecodeError) as error:
            raise Stop(f"{args[1]} returned malformed JSON ({type(error).__name__}); charged response remains in the ledger") from error

    def preflight(self):
        if any(tx.get("family") == "shared" for tx in self.ledger()["transactions"]):
            return
        self.jcall("one", "rate_limit", "preflight", family="shared")
        self.jcall("pages", "rules_main", "preflight", query={"per_page": 100}, family="shared")
        self.jcall("one", "branch_protection", "preflight", family="shared", expect=(200, 404))
        self.jcall("one", "workflow", "preflight", params={"workflow_id": WORKFLOW_ID}, family="shared")

    def docs_publication_state(self):
        """Return (count, complete): complete only when the ledger holds exactly the frozen two-stage publication."""
        rows = [tx for tx in self.ledger()["transactions"] if tx.get("category") == "docs_publication"]
        if not rows:
            return 0, False
        publisher = load(PUBLICATION, "ci_git_publication")
        routes = sorted(tx.get("route_id") for tx in rows)
        expected_routes = sorted(list(publisher.DOCS_STAGE_ROUTES) * 2)
        created = set()
        for tx in rows:
            if tx.get("route_id") == "create_ref" and tx.get("state") == "complete" and tx.get("actual_status") == 201:
                try:
                    body = json.loads(base64.b64decode(tx.get("response_body_base64") or ""))
                    created.add((body.get("ref"), (body.get("object") or {}).get("sha")))
                except (ValueError, TypeError):
                    pass
        wanted = {("refs/heads/" + FAMILY_REFS["docs-only"][1], self.spec["base_sha"]),
                  ("refs/heads/" + FAMILY_REFS["docs-only"][0], self.spec["head_sha"])}
        complete = (len(rows) == publisher.DOCS_PUBLICATION_LIMIT and routes == expected_routes
                    and all(tx.get("state") == "complete" for tx in rows) and created == wanted)
        return len(rows), complete

    def publish_docs(self):
        done, complete = self.docs_publication_state()
        if complete:
            self.notes.append("docs objects were already published under the shared docs_publication category")
            return
        if done:
            raise Stop("docs publication is present in the shared ledger but is not the complete frozen two-stage publication")
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
            if not any(item.get("ref") == "refs/heads/" + ref and item.get("sha") == commit
                       for entry in self.actions("publish_docs_objects") for item in entry.get("refs", [])):
                raise Stop(f"{label}: ref creation is outside the approved docs_and_prs section")
            probe_status, _ = self.jcall("one", "get_ref", "docs_publication", params={"branch": ref}, expect=(404,))
            self.jcall("one", "create_ref", "docs_publication", "POST", body={"ref": "refs/heads/" + ref, "sha": commit}, expect=(201,))
            _, ref_readback = self.jcall("one", "get_ref", "docs_publication", params={"branch": ref})
            if ref_readback.get("object", {}).get("sha") != commit:
                raise Stop(f"{label}: scoped ref readback differs")

    def docs_publication_receipt(self):
        """253-139: the docs publication receipt, built only from the shared ledger's docs_publication rows (route,
        sequence, status, the created tree/commit/ref object and the readbacks), never from collector variables."""
        ledger = self.ledger()
        rows, refs, commits = [], [], []
        for tx in [tx for tx in ledger["transactions"] if tx.get("category") == "docs_publication"]:
            try:
                body = json.loads(base64.b64decode(tx.get("response_body_base64") or ""))
            except (ValueError, TypeError):
                body = None
            body = body if isinstance(body, dict) else {}
            route, status = tx.get("route_id"), tx.get("actual_status")
            created = readback = None
            if route in ("git_create_tree", "git_create_commit"):
                created = body.get("sha")
                if route == "git_create_commit":
                    commits.append(created)
            elif route == "create_ref":
                created = (body.get("object") or {}).get("sha")
                refs.append({"ref": body.get("ref"), "sha": created})
            elif route in ("git_get_commit", "git_get_blob"):
                readback = body.get("sha")
            elif route == "get_ref" and status == 200:
                readback = (body.get("object") or {}).get("sha")
            rows.append({"sequence": tx.get("sequence"), "route_id": route, "method": tx.get("method"), "actual_status": status,
                         "created_sha": created, "readback_sha": readback})
        _, complete = self.docs_publication_state()
        return {"schema": DOCS_RECEIPT_SCHEMA, "freeze_sha256": self.freeze.get("freeze_sha256"),
                "docs_base_commit": commits[0] if commits else None, "docs_head_commit": commits[1] if len(commits) > 1 else None,
                "rows": rows, "refs": refs, "ledger_window_id": ledger.get("window_id"), "complete": complete}

    def write_docs_receipt(self):
        exclusive_write(self.docs_receipt_path,
                        (json.dumps(self.docs_publication_receipt(), indent=2, sort_keys=True) + "\n").encode())

    def sleep(self):
        time.sleep(max(0, int(self.freeze["poll"]["interval_seconds"])))

    def collect(self):
        head_ref, base_ref = frozen_refs(self.family, self.spec)
        head_sha = self.spec["head_sha"]
        self.preflight()
        if self.family == "docs-only":
            try:
                self.publish_docs()
            finally:
                # Written on the publishing, the already-published and the partial path, before any Stop propagates.
                if self.docs_receipt_path is not None:
                    self.write_docs_receipt()
        title = f"Phase 253 {self.family} CI proof (draft, do not merge)"
        create_body = {"title": title, "head": head_ref, "base": base_ref, "body": "Draft proof pull request; never merged.", "draft": True}
        self.require_listed_pr(create_body)
        _, created = self.jcall("one", "pr_create", "pr_create", "POST", body=create_body, expect=(201,))
        number = created["number"]
        expected_base = (self.base_preflight or {}).get("current_main")
        if expected_base is not None and (created.get("base") or {}).get("sha") != expected_base:
            raise Stop(f"main moved between the step-0 preflight and PR creation: the created PR base is "
                       f"{(created.get('base') or {}).get('sha')}, the preflight current_main is {expected_base}")
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
            raise Stop(self.no_run_verdict(number))
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

    def no_run_verdict(self, number):
        """253-139: both discovery attempts found no run. One diagnostic PR read (pr_identity, this failure path only) names
        GitHub's own reason instead of the generic stop; the success path's pr_identity use is unchanged."""
        _, pr = self.jcall("one", "pr_read", "pr_identity", params={"pull_number": number})
        mergeable, state = (pr or {}).get("mergeable"), (pr or {}).get("mergeable_state")
        if mergeable is False:
            return (f"pull request #{number} has merge conflicts with its base (mergeable false, mergeable_state {state}); "
                    "GitHub creates no pull_request run for it")
        if mergeable is None:
            return (f"pull request #{number} mergeability is still unknown (mergeable null, mergeable_state {state}); "
                    "GitHub has not created a pull_request run for it")
        return f"no pull_request run although pull request #{number} is mergeable (mergeable_state {state})"

    def write(self, stop=None, started=False):
        evidence = {"schema_version": EVIDENCE_SCHEMA, "repository": REPO, "family": self.family,
                    "action_approval": self.action_approval,
                    "synthetic": self.allocation.get("mode") == "hermetic-test", "freeze": self.freeze,
                    "allocation_base64": base64.b64encode(self.allocation_raw).decode("ascii"),
                    "transport_ledger": self.ledger(), "server_journal": None, "downloads": self.downloads,
                    "collection": {"complete": not started and stop is None and len(self.downloads) == 5, "stop": stop,
                                   "notes": self.notes + (["collection started; no request has completed yet"] if started else [])}}
        if self.base_preflight is not None:
            evidence["base_preflight"] = self.base_preflight
        atomic_write(self.evidence_path, (json.dumps(evidence, sort_keys=True) + "\n").encode())
        return evidence


def run_family(args):
    section, action_approval, revision_candidate_ref = approved_section(args)
    # Every live family run binds the PR freeze's normal head to the candidate ref the approved canary freeze selected.
    try:
        normal_head = (read_json(args.freeze).get("normal") or {}).get("head_ref")
    except (OSError, ValueError, AttributeError) as error:
        raise SystemExit(f"ci-pr-proof: the PR freeze is unreadable: {error}")
    if normal_head not in NORMAL_HEADS or revision_candidate_ref != "refs/heads/" + normal_head:
        raise SystemExit("ci-pr-proof: the PR freeze normal head ref differs from the revision freeze candidate_ref "
                         f"({normal_head!r} vs {revision_candidate_ref!r})")
    if Path(args.evidence).exists():
        raise SystemExit(f"ci-pr-proof: {args.evidence} already exists; refusing to overwrite the recorded window and downloads "
                         "(continue the shared ledger with a new --evidence path; the earlier file stays as the record)")
    if args.docs_publication_receipt is not None:
        if args.family != "docs-only":
            raise SystemExit("ci-pr-proof: --docs-publication-receipt applies to the docs-only family only; network_requests 0")
        if Path(args.docs_publication_receipt).exists():
            raise SystemExit(f"ci-pr-proof: {args.docs_publication_receipt} already exists; the docs publication receipt is "
                             "exclusive-create; network_requests 0")
    base_preflight = required_base_preflight(args, check_freeze(args.freeze, quiet=True))
    collector = Collector(args, section, action_approval, base_preflight)
    stop = None
    # Record the approval and the wall-clock window start before the first transaction can leave the process.
    action_approval["window_wall_start_epoch"] = int(time.time())
    collector.write(started=True)
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
    parser.add_argument("--require-live-origin", action="store_true",
                        help="--prepare only: refuse a hermetic or legacy local-fixture publication receipt (live acceptance)")
    parser.add_argument("--revision-freeze", help="the canary revision freeze carrying the enumerated outward_actions")
    parser.add_argument("--action-approval", help="committed approval bound to the docs_and_prs section digest")
    parser.add_argument("--docs-evidence")
    parser.add_argument("--server-journal")
    parser.add_argument("--docs-server-journal")
    parser.add_argument("--bound-document", action="append")
    parser.add_argument("--budget-document", help="path of the frozen budget document (default: the Phase253 load-recovery budgets)")
    parser.add_argument("--poll-interval", type=int, default=60)
    parser.add_argument("--main-record", help="--prepare only: the sigra.phase253.main-fetch/r12 record the PR base is checked "
                        "against (required for the r12 normal head)")
    parser.add_argument("--main-preflight", nargs="?", const=PREFLIGHT_MODE,
                        help="alone: the offline step-0 mode; with FILE and --family normal: the clean preflight (r12 required)")
    parser.add_argument("--current-main", help="--main-preflight mode: the freshly fetched main SHA (present locally)")
    parser.add_argument("--docs-publication-receipt", help="--family docs-only: write (exclusive-create) the docs publication "
                        "receipt derived from the ledger's docs_publication rows")
    args = parser.parse_args()
    preflight_mode = args.main_preflight is PREFLIGHT_MODE
    modes = [bool(args.prepare), bool(args.check_only), bool(args.verify), bool(args.family), preflight_mode and not args.family]
    if sum(modes) != 1:
        parser.error("choose exactly one of --prepare, --check-only, --main-preflight, --family or --verify")
    if preflight_mode and args.family:
        parser.error("--family takes --main-preflight FILE (the step-0 preflight file)")
    if args.main_preflight is not None and not (preflight_mode or args.family):
        parser.error("--main-preflight FILE is used with --family only")
    if preflight_mode:
        if not (args.freeze and args.current_main and args.output):
            parser.error("--main-preflight requires --freeze, --current-main and --output")
        return main_preflight(args)
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
