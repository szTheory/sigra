#!/usr/bin/env python3
"""Offline dry-run gate for the Phase 253 hosted canary (253-101).

Runs the real ci-gate-canary.sh sequence (--publish-only, --scenario full-pass, --remaining-scenarios) in a temporary
clone of HEAD, through the real ci-hosted-transport.py, ci-git-publication.py and ci-hosted-gate-verify.py, against a
local HTTPS fake GitHub. Every request is sent with a hermetic-test canary allocation, so the transport refuses any
origin other than the local one; GH_TOKEN and GITHUB_TOKEN are removed and gh/curl on PATH are recorders that fail.

What the fake models (stated assumptions, not observations): the candidate commit has zero check runs and the server
parent has the five required ones from the GitHub Actions app; a dispatched run becomes listable only after a delay;
each run completes after a modeled number of polls; artifact zips and failed logs answer with one 302 hop; get_ref is
404 until create_ref; an existing ref at another sha stops create-only publication. 253-128: the failed-log chain is the one
GitHub returned to the 253-127 probe (302 to results-receiver, then its own 200 zip), read from the committed records.

The result is always synthetic: the evidence is labelled channel hermetic-https and can never become hosted proof.
Prints one JSON summary object; exits 0 only when every driver mode, the publisher and the verifier passed.

--live-policy (253-108) runs the same sequence with a LIVE canary allocation (mode live, the trusted download_hosts list,
no test fields) and no SIGRA_CANARY_TEST_* variable, so every live branch of the transport, publisher and driver runs as
it would against GitHub. Only the layer below every policy decision differs: the 253-107 live-policy shim maps
api.github.com and the trusted download hosts on port 443 to the local fake, which serves them by Host header under a
certificate for those names. GH_TOKEN is a fixed dummy inside the clone's environment only; the window id starts with
253-dryrun-live-policy-, so the verifier's dry-run guard labels every result synthetic. A recording sleep on the
recorder PATH logs each requested wait and sleeps only --sleep-scale of it.
"""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import http.server
import importlib.util
import io
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
DRIVER_REL = "scripts/ci/ci-gate-canary.sh"
FIXTURE_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml"
R7_FREEZE_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE-R7.json"
REPO = "szTheory/sigra"
WORKFLOW_ID = 259268962
APP = {"id": 15368, "slug": "github-actions", "name": "GitHub Actions"}
REQUIRED_CHECKS = ("Library tests", "Example unit smoke (ExUnit + ConnTest)", "Install smoke (fresh phx.new + sigra.install)",
                   "Example HTTP smoke (boot + curl critical routes)", "Example Playwright smoke (full lifecycle)")
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
SCENARIOS = ("full-pass", "docs-only", "actual-failure", "missing-seam", "unexpected-skip", "cancelled")
REMAINING = SCENARIOS[1:]
OUTCOMES = {"full-pass": "success", "docs-only": "success", "actual-failure": "failure", "missing-seam": "failure",
            "unexpected-skip": "failure", "cancelled": "cancelled", "verifier": "success"}
# Modeled polls to completion, counted from the first poll (3/3/2/2/2/3/3 in dispatch order).
DEFAULT_POLLS = {"full-pass": 3, "docs-only": 3, "actual-failure": 2, "missing-seam": 2, "unexpected-skip": 2,
                 "cancelled": 3, "verifier": 3}
LEGACY_REFS = {"gsd/253-replan-candidate": "ce89eb7319c20596850a0c8a0b6e5661e197c86a",
               "gsd/253-replan-fixture": "12cc2ded39301724b7234a4ee9a7a0d79609cc45"}
FIXED_DATE = "Thu, 15 Oct 2026 00:00:00 GMT"
DISPATCH_INPUTS = {"scenario", "candidate_sha", "fixture_sha", "fixture_blob", "matrix_evidence"}
REQUIRED_INPUTS = {"scenario", "candidate_sha", "fixture_sha", "fixture_blob"}
SHA40 = re.compile(r"[a-f0-9]{40}")
# 253-108 live-policy mode.
API_HOST = "api.github.com"
BLOB_HOST = "productionresultssa17.blob.core.windows.net"
PIPELINES_HOST = "pipelines.actions.githubusercontent.com"
# 253-128: GitHub's run-log redirect host (253-127 probe: hop 1 of run_logs answers 200 application/zip itself).
RESULTS_RECEIVER_HOST = "results-receiver.actions.githubusercontent.com"
LIVE_TLS_NAMES = (API_HOST, "*.blob.core.windows.net", PIPELINES_HOST, RESULTS_RECEIVER_HOST)
LIVE_TOKEN = "dryrun-live-policy-not-a-credential"
LIVE_WINDOW_PREFIX = "253-dryrun-live-policy-"
R8_ALLOCATION_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json"
SHIM_REL = "scripts/ci/ci-live-policy-shim.py"
TRANSPORT_REL = "scripts/ci/ci-hosted-transport.py"
# The two refs 253-104 created on GitHub (R8 pair); a run seeded with them must never move them.
R8_REFS = {"gsd/253-replan-r8-candidate": "7a1ba235a502c1f7b379a6109698fa59b65b6c8a",
           "gsd/253-replan-r8-fixture": "ad015ec1005b7f19d8722ce3650aa1eb777b8f44"}
# 253-119: the two refs 253-113 created on GitHub (R9 pair, FREEZE-R9's commits); a run seeded with them must never move them.
R9_REFS = {"gsd/253-replan-r9-candidate": "b9720d8e00e69e11c965ed7cf5029e3a0008783a",
           "gsd/253-replan-r9-fixture": "aa7014893b716f279b60ceb545b8aee5ca15b10c"}
# 253-117: GitHub's recorded responses, read from the committed R9 ledger at run time (the harness runs locally only):
# seq 25 the workflow_runs listing, 27 the run poll, 28 the jobs page and 29 the artifacts page of real run 38906314106.
R9_LEDGER_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R9.json"
REFERENCE_SEQUENCES = {"listing": 25, "run": 27, "jobs": 28, "artifacts": 29}
FIXTURE_TITLE = "Phase 253 Gate Canary"
WORKFLOW_PATH = ".github/workflows/ci.yml"
NESTED_RUN_OBJECTS = ("repository", "head_repository", "head_commit", "actor", "triggering_actor")
FAKE_CREATED_AT = "2026-10-15T00:00:00Z"
# 253-128: the failed-log chain and the cancelled run GitHub returned to the 253-127 read-only probe, read from the
# committed probe records at run time (and R10 ledger seq 47 for hop 0); nothing is copied into a fixture file.
PROBE_EVIDENCE_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PROBE-EVIDENCE-R11-PROBE.json"
PROBE_BODIES_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PROBE-BODIES-R11-PROBE.json"
PROBE_LEDGER_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-PROBE-HTTP-LEDGER-R11-PROBE.json"
R10_LEDGER_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json"
R10_LOG_HOP0_SEQUENCE = 47
PROBE_LOG_CHAIN_ID = "run-log-chain"
PROBE_CANCELLED_IDS = {"run": "cancelled-run", "jobs": "cancelled-jobs"}
# The recorded Location carries a signed query whose names the ledger redacts (only has_query is kept), so the fake's
# query parameter names and values are synthetic.
LOG_QUERY = "sig=dry-run-signature&se=2026-10-15"
LOG_UUID_NAMESPACE = uuid.UUID("2530128a-0000-4000-8000-000000000253")
LOG_NUMBERED_MEMBER = re.compile(r"(\d+)_(.+)\.txt")
LOG_SYSTEM_MEMBER = re.compile(r"(.+)/system\.txt")


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


TRANSPORT = load_module("ci_hosted_transport_for_dryrun", HERE / "ci-hosted-transport.py")
# 253-128: the probe driver's own path-pattern function, so the fake's paths are compared with the same instrument.
SHAPE_PROBE = load_module("ci_shape_probe_for_dryrun", HERE / "ci-shape-probe.py")
OBJECT_TESTS = load_module("ci_git_publication_tests_for_dryrun", HERE / "ci-git-publication.test.py")
ObjectServer = OBJECT_TESTS.ObjectServer
PUBLISHER = load_module("ci_git_publication_for_dryrun", HERE / "ci-git-publication.py")


class DryRunError(Exception):
    pass


def run(argv, cwd=None, env=None, data=None, check=True):
    result = subprocess.run(argv, cwd=cwd, env=env, input=data, capture_output=True)
    if check and result.returncode:
        raise DryRunError(f"{' '.join(map(str, argv[:4]))} failed: {result.stderr.decode(errors='replace').strip()[-600:]}")
    return result


def git(repo: Path, *args, data=None, check=True) -> str:
    return run(["git", "-C", str(repo), *args], data=data, check=check).stdout.decode().strip()


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def atomic_write(path: Path, data: bytes) -> None:
    temp = path.with_name(f".{path.name}.tmp")
    temp.write_bytes(data)
    os.replace(temp, path)


def zip_bytes(name: str, content: bytes) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as bundle:
        info = zipfile.ZipInfo(name, date_time=(2026, 10, 15, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        bundle.writestr(info, content)
    return buffer.getvalue()


# ------------------------------------------------------------------------------ 253-117 GitHub's recorded shapes
_REFERENCE: dict = {}


def load_reference(root: Path = ROOT) -> dict:
    """The decoded real bodies (REFERENCE_SEQUENCES) and the sha256 of the committed ledger they came from."""
    if "value" not in _REFERENCE:
        raw = (root / R9_LEDGER_REL).read_bytes()
        rows = {row.get("sequence"): row for row in json.loads(raw)["transactions"]}
        bodies = {name: json.loads(base64.b64decode(rows[sequence]["response_body_base64"]))
                  for name, sequence in REFERENCE_SEQUENCES.items()}
        _REFERENCE["value"] = {"path": R9_LEDGER_REL, "sha256": sha256_hex(raw), "sequences": dict(REFERENCE_SEQUENCES),
                               **bodies}
    return _REFERENCE["value"]


def run_title(scenario, run_id, attempt=1) -> str:
    """The fixture's run-name as GitHub renders it; GitHub returns it as both name and display_title."""
    return f"{FIXTURE_TITLE} / {scenario} / {run_id}-{attempt}"


def _ordered_like(real: dict, value: dict) -> dict:
    ordered = {key: value[key] for key in real if key in value}
    ordered.update({key: item for key, item in value.items() if key not in ordered})
    return ordered


def build_run(record: dict, status: str, conclusion, commit: dict | None = None, reference: dict | None = None,
              bare_name: bool = False) -> dict:
    """A workflow run object with GitHub's recorded key sets (R9 seq 27). Dynamic fields come from the fake's record;
    actor, triggering_actor, repository and head_repository are the committed real objects (public repository metadata).
    bare_name serves the pre-253-117 fake shape (bare workflow name, path with an @ suffix): a fault, never the default."""
    real = (reference or load_reference())["run"]
    run_id, branch = record["id"], record["head_branch"]
    api = f"https://api.github.com/repos/{REPO}"
    title = run_title(record["scenario"], run_id)
    suite = 90000000000 + run_id % 10000000000
    commit = commit or {}
    message = commit.get("message")
    if isinstance(message, str) and message.endswith("\n"):
        message = message[:-1]  # GitHub's commit JSON drops one trailing newline (as the object fake does)

    def person(item):
        item = item or {}
        return {"name": item.get("name"), "email": item.get("email")}
    head_commit = {"id": record["head_sha"], "tree_id": (commit.get("tree") or {}).get("sha"), "message": message,
                   "timestamp": (commit.get("committer") or {}).get("date"), "author": person(commit.get("author")),
                   "committer": person(commit.get("committer"))}
    value = {"id": run_id, "name": title, "node_id": f"WFR_dryrun{run_id}", "head_branch": branch,
             "head_sha": record["head_sha"], "path": WORKFLOW_PATH, "display_title": title,
             "run_number": record["run_number"], "event": "workflow_dispatch", "status": status, "conclusion": conclusion,
             "workflow_id": WORKFLOW_ID, "check_suite_id": suite, "check_suite_node_id": f"CS_dryrun{suite}",
             "url": f"{api}/actions/runs/{run_id}", "html_url": f"https://github.com/{REPO}/actions/runs/{run_id}",
             "pull_requests": [], "created_at": FAKE_CREATED_AT, "updated_at": FAKE_CREATED_AT,
             "actor": copy.deepcopy(real["actor"]), "run_attempt": 1, "referenced_workflows": [],
             "run_started_at": FAKE_CREATED_AT, "triggering_actor": copy.deepcopy(real["triggering_actor"]),
             "jobs_url": f"{api}/actions/runs/{run_id}/jobs", "logs_url": f"{api}/actions/runs/{run_id}/logs",
             "check_suite_url": f"{api}/check-suites/{suite}", "artifacts_url": f"{api}/actions/runs/{run_id}/artifacts",
             "cancel_url": f"{api}/actions/runs/{run_id}/cancel", "rerun_url": f"{api}/actions/runs/{run_id}/rerun",
             "previous_attempt_url": None, "workflow_url": f"{api}/actions/workflows/{WORKFLOW_ID}",
             "head_commit": head_commit, "repository": copy.deepcopy(real["repository"]),
             "head_repository": copy.deepcopy(real["head_repository"])}
    if bare_name:
        value["name"] = FIXTURE_TITLE
        value["path"] = f"{WORKFLOW_PATH}@refs/heads/{branch}"
    return _ordered_like(real, value)


def reference_steps(reference: dict, job_name: str) -> list:
    """The step names of the recorded real job (seq 28): producers and Browser verdict, as GitHub listed them."""
    for job in reference["jobs"]["jobs"]:
        if job["name"] == job_name or (job_name == "producer" and job["name"].startswith("producer (")):
            return [step["name"] for step in job["steps"]]
    raise KeyError(f"no recorded {job_name} job")


# No real sample of the verifier job's steps exists (it has only ever been skipped); modeled from the fixture workflow:
# its four named steps plus GitHub's own Set up / Post checkout / Complete job steps.
VERIFIER_STEPS = ("Set up job", "Checkout candidate verifier by pinned commit", "Verify immutable candidate verifier checkout",
                  "Verify retained source matrix independently", "Retain separate verifier result",
                  "Post Checkout candidate verifier by pinned commit", "Complete job")
# The skipped producer matrix job of the verifier run: GitHub shows a matrix job skipped by its job-level if once, under
# its unexpanded name (the Phase 252 bundle's install_matrix job). Never observed live for this fixture (253-118 row).
SKIPPED_PRODUCER_NAME = "producer (${{ matrix.seam }})"


def build_steps(names, conclusions: dict | None, done: bool) -> list:
    """Step objects with the recorded key set (seq 28); every step succeeds unless conclusions names it."""
    steps = []
    for number, name in enumerate(names, 1):
        conclusion = (conclusions or {}).get(name, "success") if done else None
        steps.append({"name": name, "status": "completed" if done else "queued", "conclusion": conclusion, "number": number,
                      "started_at": FAKE_CREATED_AT if done else None, "completed_at": FAKE_CREATED_AT if done else None})
    return steps


def build_job(record: dict, job_id: int, name: str, conclusion, steps: list, reference: dict | None = None) -> dict:
    """A job object with the recorded key set (seq 28): workflow_name is the run-name, as GitHub returns it."""
    real = (reference or load_reference())["jobs"]["jobs"][0]
    run_id = record["id"]
    api = f"https://api.github.com/repos/{REPO}"
    ran = conclusion not in (None, "skipped")
    runner = 1000000000 + job_id % 100000000
    value = {"id": job_id, "run_id": run_id, "workflow_name": run_title(record["scenario"], run_id),
             "head_branch": record["head_branch"], "run_url": f"{api}/actions/runs/{run_id}", "run_attempt": 1,
             "node_id": f"CR_dryrun{job_id}", "head_sha": record["head_sha"], "url": f"{api}/actions/jobs/{job_id}",
             "html_url": f"https://github.com/{REPO}/actions/runs/{run_id}/job/{job_id}",
             "status": "completed" if conclusion else "in_progress", "conclusion": conclusion,
             "created_at": FAKE_CREATED_AT, "started_at": FAKE_CREATED_AT,
             "completed_at": FAKE_CREATED_AT if conclusion else None, "name": name, "steps": steps,
             "check_run_url": f"{api}/check-runs/{job_id}", "labels": ["ubuntu-latest"],
             "runner_id": runner if ran else None, "runner_name": f"GitHub Actions {runner}" if ran else None,
             "runner_group_id": 0 if ran else None, "runner_group_name": "GitHub Actions" if ran else None}
    return _ordered_like(real, value)


def build_artifact(record: dict, artifact_id: int, name: str, size: int, digest: str, reference: dict | None = None) -> dict:
    """An artifact object with the recorded key set (seq 29), workflow_run included."""
    real = (reference or load_reference())["artifacts"]["artifacts"][0]
    repository_id = real["workflow_run"]["repository_id"]
    api = f"https://api.github.com/repos/{REPO}"
    value = {"id": artifact_id, "node_id": f"ART_dryrun{artifact_id}", "name": name, "size_in_bytes": size,
             "url": f"{api}/actions/artifacts/{artifact_id}", "archive_download_url": f"{api}/actions/artifacts/{artifact_id}/zip",
             "expired": False, "digest": "sha256:" + digest, "created_at": FAKE_CREATED_AT, "updated_at": FAKE_CREATED_AT,
             "expires_at": "2026-10-22T00:00:00Z",
             "workflow_run": _ordered_like(real["workflow_run"], {
                 "id": record["id"], "repository_id": repository_id, "head_repository_id": repository_id,
                 "head_branch": record["head_branch"], "head_sha": record["head_sha"]})}
    return _ordered_like(real, value)


def check_jobs_shape(body, run_id, record, reference: dict) -> tuple[list, int, int]:
    """Mismatches of one served jobs page against seq 28, and the number of jobs and steps checked."""
    real = reference["jobs"]
    problems = [_key_problem(f"jobs page of run {run_id}", body, real)]
    jobs_checked = steps_checked = 0
    title = run_title(record["scenario"], run_id)
    lists = {"producer": reference_steps(reference, "producer"), "Browser verdict": reference_steps(reference, "Browser verdict")}
    for job in (body.get("jobs") or []) if isinstance(body, dict) else []:
        jobs_checked += 1
        label = f"job {job.get('name') if isinstance(job, dict) else job!r} of run {run_id}"
        problems.append(_key_problem(label, job, real["jobs"][0]))
        if not isinstance(job, dict):
            continue
        if job.get("run_id") != run_id or job.get("workflow_name") != title:
            problems.append(f"{label} run_id/workflow_name {job.get('run_id')!r}/{job.get('workflow_name')!r} is not the "
                            f"run's id and run-name {title!r}")
        steps = job.get("steps") if isinstance(job.get("steps"), list) else None
        if steps is None:
            problems.append(f"{label} has no step list")
            continue
        for step in steps:
            steps_checked += 1
            problems.append(_key_problem(f"{label} step {step.get('name') if isinstance(step, dict) else step!r}", step,
                                         real["jobs"][0]["steps"][0]))
        if job.get("conclusion") == "skipped" and steps:
            problems.append(f"{label} is skipped but lists steps (GitHub lists none)")
        kind = "producer" if str(job.get("name", "")).startswith("producer (") else job.get("name")
        if job.get("conclusion") not in (None, "skipped") and kind in lists:
            names = [step.get("name") for step in steps if isinstance(step, dict)]
            if names != lists[kind]:
                problems.append(f"{label} steps {names} differ from GitHub's recorded list {lists[kind]}")
    return problems, jobs_checked, steps_checked


def check_artifacts_shape(body, run_id, reference: dict) -> tuple[list, int]:
    real = reference["artifacts"]
    problems = [_key_problem(f"artifacts page of run {run_id}", body, real)]
    checked = 0
    for artifact in (body.get("artifacts") or []) if isinstance(body, dict) else []:
        checked += 1
        label = f"artifact {artifact.get('name') if isinstance(artifact, dict) else artifact!r} of run {run_id}"
        problems.append(_key_problem(label, artifact, real["artifacts"][0]))
        if isinstance(artifact, dict):
            origin = artifact.get("workflow_run")
            problems.append(_key_problem(f"{label} workflow_run", origin, real["artifacts"][0]["workflow_run"]))
            if isinstance(origin, dict) and origin.get("id") != run_id:
                problems.append(f"{label} workflow_run.id {origin.get('id')!r} is not run {run_id}")
    return problems, checked


def _key_problem(label, value, real) -> str | None:
    if not isinstance(value, dict):
        return f"{label} is not an object"
    if set(value) != set(real):
        return f"{label} keys differ from GitHub's: missing {sorted(set(real) - set(value))}, extra {sorted(set(value) - set(real))}"
    return None


def check_run_shape(run, scenario, reference: dict) -> list:
    """Every way this served run differs from GitHub's recorded run shape (an empty list when it matches)."""
    real = reference["run"]
    label = f"run {run.get('id') if isinstance(run, dict) else None} ({scenario})"
    problem = _key_problem(label, run, real)
    if not isinstance(run, dict):
        return [problem]
    problems = [problem] if problem else []
    for key in NESTED_RUN_OBJECTS:
        problems.append(_key_problem(f"{label} {key}", run.get(key), real[key]))
    for key in ("repository", "head_repository"):
        if isinstance(run.get(key), dict):
            problems.append(_key_problem(f"{label} {key}.owner", run[key].get("owner"), real[key]["owner"]))
    title = run_title(scenario, run.get("id"), run.get("run_attempt"))
    if run.get("name") != title:
        problems.append(f"{label} name {run.get('name')!r} is not the run-name {title!r}")
    if run.get("display_title") != title:
        problems.append(f"{label} display_title {run.get('display_title')!r} is not the run-name {title!r}")
    if run.get("path") != WORKFLOW_PATH:
        problems.append(f"{label} path {run.get('path')!r} is not exactly {WORKFLOW_PATH!r}")
    return [item for item in problems if item]


# ------------------------------------------------------------------- 253-128 GitHub's recorded run-log chain (probe)
RESULTS_LOG_PATH = re.compile(r"/rest/runs/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/logs")
_LOG_REFERENCE: dict = {}


def path_pattern(path: str) -> str:
    """The 253-127 probe's path pattern ({uuid}, {hex}, {n}), computed by the probe driver's own function."""
    return SHAPE_PROBE._path_pattern(path)


class _Stream(io.RawIOBase):
    """A write-only, non-seekable sink: zipfile then streams each member with a data descriptor, as GitHub's log zip does
    (local header magic 504b030414000800 in the 253-127 bodies record)."""

    def __init__(self):
        super().__init__()
        self.data = bytearray()

    def writable(self):
        return True

    def write(self, chunk):
        self.data += chunk
        return len(chunk)


def log_archive(job_names) -> bytes:
    """The failed-log zip in GitHub's recorded member pattern: for each executed job n, `{n}_<job>.txt` and
    `<job>/system.txt` (253-127 bodies record). The text is synthetic; real log bytes are never reconstructed."""
    sink = _Stream()
    with zipfile.ZipFile(sink, "w", zipfile.ZIP_DEFLATED) as bundle:
        for index, name in enumerate(job_names):
            for member, text in ((f"{index}_{name}.txt", f"modeled job log for {name}\n"),
                                 (f"{name}/system.txt", f"modeled system log for {name}\n")):
                info = zipfile.ZipInfo(member, date_time=(2026, 10, 15, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, text.encode())
    return bytes(sink.data)


def log_member_problems(names) -> list:
    """Every way a log zip's member names differ from the recorded pattern: numbered logs 0..k-1 once each, and one
    `<job>/system.txt` for exactly the jobs the numbered logs name."""
    problems, numbered, system = [], {}, []
    for name in names if isinstance(names, list) else []:
        number, other = LOG_NUMBERED_MEMBER.fullmatch(name), LOG_SYSTEM_MEMBER.fullmatch(name)
        if number and "/" not in name:
            numbered.setdefault(int(number.group(1)), []).append(number.group(2))
        elif other:
            system.append(other.group(1))
        else:
            problems.append(f"log member {name!r} is neither {{n}}_<job>.txt nor <job>/system.txt")
    if not numbered:
        problems.append(f"log archive {names!r} has no numbered job log")
    if sorted(numbered) != list(range(len(numbered))) or any(len(jobs) != 1 for jobs in numbered.values()):
        problems.append(f"numbered job logs {sorted(numbered)} are not 0..k-1 once each")
    jobs = sorted(jobs[0] for jobs in numbered.values())
    if jobs != sorted(system) or len(set(system)) != len(system):
        problems.append(f"numbered logs name {jobs} but system.txt members name {sorted(system)}")
    return problems


def load_log_reference(root: Path = ROOT) -> dict:
    """GitHub's recorded failed-log chain: the probe evidence's run-log-chain hops, cross-checked against the probe
    ledger rows and bodies record, with hop 0 also matched against R10 ledger seq 47. Each file's sha256 is returned."""
    if "value" in _LOG_REFERENCE:
        return _LOG_REFERENCE["value"]
    raws = {rel: (root / rel).read_bytes() for rel in (PROBE_EVIDENCE_REL, PROBE_BODIES_REL, PROBE_LEDGER_REL, R10_LEDGER_REL)}
    evidence = json.loads(raws[PROBE_EVIDENCE_REL])
    result = next((item for item in evidence.get("results", []) if item.get("id") == PROBE_LOG_CHAIN_ID), None)
    if not isinstance(result, dict) or result.get("status") != "complete" or result.get("route_id") != "run_logs":
        raise DryRunError("the probe evidence has no complete run_logs run-log-chain result")
    hops = sorted(result["observed"]["hops"], key=lambda hop: hop["hop_ordinal"])
    if [hop["hop_ordinal"] for hop in hops] != list(range(len(hops))) or len(hops) < 2:
        raise DryRunError("the probe's run-log-chain hops are not a 0..n chain with a redirect")
    rows = {row.get("sequence"): row for row in json.loads(raws[PROBE_LEDGER_REL])["transactions"]}
    for hop in hops:
        row = rows.get(hop["sequence"]) or {}
        if ((row.get("route_id"), row.get("hop_ordinal"), row.get("actual_status"), row.get("host"))
                != ("run_logs", hop["hop_ordinal"], hop["status"], hop["host"])
                or sorted(row.get("scrubbed_headers") or {}) != hop["safe_header_names"]):
            raise DryRunError(f"probe evidence hop {hop['hop_ordinal']} differs from probe ledger seq {hop['sequence']}")
    final = hops[-1]
    if final["status"] != 200 or final["location"] is not None or any(hop["location"] is None for hop in hops[:-1]):
        raise DryRunError("the probe's run-log-chain does not end in a final 200 after its redirects")
    body = next((entry for entry in json.loads(raws[PROBE_BODIES_REL])["entries"]
                 if entry.get("id") == PROBE_LOG_CHAIN_ID and entry.get("hop_ordinal") == final["hop_ordinal"]), None)
    if not isinstance(body, dict) or body.get("content_type") != final["content_type"]:
        raise DryRunError("the probe bodies record has no final run-log-chain body of the recorded content type")
    names = [member["name"] for member in body.get("zip_members") or []]
    if final["content_type"] == "application/zip" and log_member_problems(names):
        raise DryRunError(f"the recorded log members do not follow the modeled pattern: {log_member_problems(names)}")
    seq47 = next((row for row in json.loads(raws[R10_LEDGER_REL])["transactions"]
                  if row.get("sequence") == R10_LOG_HOP0_SEQUENCE), {})
    first, headers = hops[0], seq47.get("scrubbed_headers") or {}
    location = headers.get("location") or {}
    if ((seq47.get("route_id"), seq47.get("hop_ordinal"), seq47.get("actual_status")) != ("run_logs", 0, first["status"])
            or headers.get("content-type") != first["content_type"]
            or headers.get("content-length") != str(first["content_length"])
            or (location.get("host"), location.get("port"), location.get("has_query"))
            != (first["location"]["host"], first["location"]["port"], first["location"]["has_query"])
            or path_pattern(str(location.get("path"))) != first["location"]["path_pattern"]):
        raise DryRunError("R10 ledger seq 47 differs from the probe's recorded run_logs hop 0")
    _LOG_REFERENCE["value"] = {
        "files": {rel: sha256_hex(raw) for rel, raw in raws.items()},
        "hops": hops,
        "final_body": {"content_type": body["content_type"], "magic_hex": body.get("magic_hex"), "member_names": names,
                       "raw_bytes": body.get("bytes"), "scrubbed_bytes": (rows.get(final["sequence"]) or {}).get("scrubbed_response_bytes")},
        "seq47": {"sequence": R10_LOG_HOP0_SEQUENCE, "status": seq47.get("actual_status"), "location_host": location.get("host")}}
    return _LOG_REFERENCE["value"]


def check_log_hop(row: dict, recorded: dict, reference: dict, live: bool, local_port) -> list:
    """Every way one served run_logs hop differs from GitHub's recorded hop of the same ordinal."""
    ordinal = row.get("hop_ordinal")
    served = urlsplit(row.get("observed_path") or "")
    label = f"run_logs hop {ordinal} ({served.path})"
    problems = []
    headers = row.get("scrubbed_headers") if isinstance(row.get("scrubbed_headers"), dict) else {}
    if row.get("actual_status") != recorded["status"]:
        problems.append(f"{label} status {row.get('actual_status')} is not GitHub's recorded {recorded['status']}")
    if sorted(headers) != recorded["safe_header_names"]:
        problems.append(f"{label} safe headers {sorted(headers)} differ from GitHub's recorded {recorded['safe_header_names']}")
    if headers.get("content-type") != recorded["content_type"]:
        problems.append(f"{label} content-type {headers.get('content-type')!r} is not GitHub's recorded {recorded['content_type']!r}")
    wanted_length = None if recorded["content_length"] is None else str(recorded["content_length"])
    if headers.get("content-length") != wanted_length:
        problems.append(f"{label} content-length {headers.get('content-length')!r} is not GitHub's recorded {wanted_length!r}")
    if path_pattern(served.path) != recorded["path_pattern"]:
        problems.append(f"{label} path pattern {path_pattern(served.path)!r} is not GitHub's recorded {recorded['path_pattern']!r}")
    if bool(served.query) != recorded["has_query"]:
        problems.append(f"{label} has_query {bool(served.query)} is not GitHub's recorded {recorded['has_query']}")
    if live and row.get("host") != recorded["host"]:
        problems.append(f"{label} host {row.get('host')!r} is not GitHub's recorded {recorded['host']!r}")
    expected, location = recorded["location"], headers.get("location")
    if expected is None and location is not None:
        problems.append(f"{label} redirects to Location host {(location or {}).get('host')!r}; GitHub's recorded hop {ordinal} is final")
    elif expected is not None and not isinstance(location, dict):
        problems.append(f"{label} has no Location; GitHub's recorded hop {ordinal} redirects to {expected['host']!r}")
    elif expected is not None:
        # Hermetic mode serves every host on the exact local origin, so the recorded host's stand-in is localhost:<port>.
        host, port = (expected["host"], expected["port"]) if live else ("localhost", local_port)
        if location.get("host") != host:
            problems.append(f"{label} Location host {location.get('host')!r} is not GitHub's recorded {expected['host']!r}"
                            + ("" if live else f" (local stand-in {host!r})"))
        if location.get("port") != port:
            problems.append(f"{label} Location port {location.get('port')!r} is not GitHub's recorded {expected['port']!r}")
        if path_pattern(str(location.get("path"))) != expected["path_pattern"]:
            problems.append(f"{label} Location path {location.get('path')!r} is not GitHub's recorded {expected['path_pattern']!r}")
        if location.get("has_query") != expected["has_query"]:
            problems.append(f"{label} Location has_query {location.get('has_query')!r} is not GitHub's recorded {expected['has_query']}")
    final = reference["final_body"]
    if ordinal == reference["hops"][-1]["hop_ordinal"]:
        if row.get("raw_magic_hex") != final["magic_hex"]:
            problems.append(f"{label} body magic {row.get('raw_magic_hex')!r} is not GitHub's recorded {final['magic_hex']!r}")
        if final["content_type"] == "application/zip":
            problems.extend(f"{label} {item}" for item in log_member_problems(row.get("zip_member_names")))
    elif recorded["content_length"] is not None and row.get("response_bytes") != recorded["content_length"]:
        problems.append(f"{label} body is {row.get('response_bytes')} bytes; GitHub's recorded hop {ordinal} is {recorded['content_length']}")
    return problems


def check_run_logs(journal: list, reference: dict, live: bool, local_port) -> tuple[list, int]:
    """Compare every run_logs hop the fake served with GitHub's recorded chain; returns (mismatches, complete chains)."""
    hops, problems = reference["hops"], []
    rows = [row for row in journal if row.get("route_id") == "run_logs"]
    for row in rows:
        ordinal = row.get("hop_ordinal")
        if type(ordinal) is not int or not 0 <= ordinal < len(hops):
            problems.append(f"run_logs hop {ordinal!r} was served; GitHub's recorded chain is hops 0..{len(hops) - 1}")
            continue
        problems.extend(check_log_hop(row, hops[ordinal], reference, live, local_port))
    starts = sum(1 for row in rows if row.get("hop_ordinal") == 0)
    finals = sum(1 for row in rows if row.get("hop_ordinal") == hops[-1]["hop_ordinal"])
    if starts != finals:
        problems.append(f"{starts} run_logs chain(s) started but {finals} reached GitHub's recorded final hop")
    return problems, min(starts, finals)


# ---------------------------------------------------------------- 253-128 GitHub's recorded cancelled run (probe)
_CANCELLED_REFERENCE: dict = {}


def cancelled_run_problems(run, reference: dict, label: str) -> list:
    """Every way a served, completed cancelled run differs from the recorded cancelled run: key sets, the terminal
    status/conclusion, and each top-level value's type (values that depend on the event, such as pull_requests, are
    compared by type only: the recorded sample is a pull_request run, the canary run is workflow_dispatch)."""
    real = reference["run"]
    problem = _key_problem(label, run, real)
    if not isinstance(run, dict):
        return [problem]
    problems = [problem] if problem else []
    for key in NESTED_RUN_OBJECTS:
        problems.append(_key_problem(f"{label} {key}", run.get(key), real[key]))
    if (run.get("status"), run.get("conclusion")) != ("completed", "cancelled"):
        problems.append(f"{label} is {run.get('status')}/{run.get('conclusion')}, not GitHub's recorded completed/cancelled")
    for key in sorted(set(run) & set(real)):
        if type(run[key]) is not type(real[key]):
            problems.append(f"{label} {key} is {type(run[key]).__name__}; GitHub's recorded cancelled run has "
                            f"{type(real[key]).__name__}")
    return [item for item in problems if item]


def cancelled_jobs_problems(page, reference: dict, label: str) -> list:
    """Every way a cancelled run's jobs page differs from the recorded one: key sets, the recorded job and step
    status/conclusion vocabulary, and the rules the recorded sample follows (a skipped job lists no steps and has no
    runner; a cancelled job with steps has exactly one cancelled step, no failed or cancelled step after it, and ends with
    a successful Complete job; at least one job is cancelled)."""
    if not isinstance(page, dict):
        return [f"{label} is not an object"]
    problems = []
    if set(page) != reference["page_keys"]:
        problems.append(f"{label} keys {sorted(page)} differ from GitHub's recorded {sorted(reference['page_keys'])}")
    jobs = page.get("jobs") if isinstance(page.get("jobs"), list) else []
    if page.get("total_count") != len(jobs):
        problems.append(f"{label} total_count {page.get('total_count')!r} is not its {len(jobs)} jobs")
    vocabulary = sorted(f"{status}/{conclusion}" for status, conclusion in reference["job_pairs"])
    step_vocabulary = sorted(f"{status}/{conclusion}" for status, conclusion in reference["step_pairs"])
    for job in jobs:
        if not isinstance(job, dict):
            problems.append(f"{label} job {job!r} is not an object")
            continue
        where = f"{label} job {job.get('name')!r}"
        if set(job) != reference["job_keys"]:
            problems.append(f"{where} keys differ from GitHub's recorded cancelled-run job keys")
        if (job.get("status"), job.get("conclusion")) not in reference["job_pairs"]:
            problems.append(f"{where} is {job.get('status')}/{job.get('conclusion')}, outside GitHub's recorded cancelled-run "
                            f"job vocabulary {vocabulary}")
        steps = job.get("steps") if isinstance(job.get("steps"), list) else None
        if steps is None:
            problems.append(f"{where} has no step list")
            continue
        for step in steps:
            if not isinstance(step, dict) or set(step) != reference["step_keys"]:
                problems.append(f"{where} step {step.get('name') if isinstance(step, dict) else step!r} keys differ from GitHub's")
            elif (step.get("status"), step.get("conclusion")) not in reference["step_pairs"]:
                problems.append(f"{where} step {step.get('name')!r} is {step.get('status')}/{step.get('conclusion')}, outside "
                                f"GitHub's recorded cancelled-run step vocabulary {step_vocabulary}")
        if job.get("conclusion") == "skipped" and (steps or job.get("runner_id") is not None):
            problems.append(f"{where} is skipped but lists steps or a runner (GitHub's recorded skipped jobs list neither)")
        if job.get("conclusion") == "cancelled" and steps:
            conclusions = [step.get("conclusion") if isinstance(step, dict) else None for step in steps]
            if conclusions.count("cancelled") != 1:
                problems.append(f"{where} has {conclusions.count('cancelled')} cancelled steps; GitHub's recorded cancelled jobs have one")
            elif {"failure", "cancelled"} & set(conclusions[conclusions.index("cancelled") + 1:]):
                problems.append(f"{where} has a failed or cancelled step after its cancelled step")
            last = steps[-1] if isinstance(steps[-1], dict) else {}
            if (last.get("name"), last.get("conclusion")) != ("Complete job", "success"):
                problems.append(f"{where} does not end with a successful Complete job step, as GitHub's recorded cancelled jobs do")
    if not any(isinstance(job, dict) and job.get("conclusion") == "cancelled" for job in jobs):
        served = sorted({str(job.get("conclusion")) for job in jobs if isinstance(job, dict)})
        problems.append(f"{label} lists no cancelled job (conclusions {served}); GitHub's recorded cancelled run lists "
                        f"{reference['cancelled_jobs']} cancelled jobs")
    return problems


def check_cancelled_shape(run, page, reference: dict) -> list:
    """The served cancelled run and its jobs page against GitHub's recorded cancelled run 38141825287."""
    label = f"cancelled run {run.get('id') if isinstance(run, dict) else None}"
    return cancelled_run_problems(run, reference, label) + cancelled_jobs_problems(page, reference, f"jobs page of {label}")


def load_cancelled_reference(root: Path = ROOT) -> dict:
    """GitHub's recorded cancelled run and jobs from the 253-127 probe (evidence results cancelled-run/cancelled-jobs,
    bodies decoded from the probe ledger and checked against their response_sha256). If the probe recorded a non-200 for
    either, the reference is unavailable and the gate reports cancelled_run_checked "unavailable"."""
    if "value" in _CANCELLED_REFERENCE:
        return _CANCELLED_REFERENCE["value"]
    raws = {rel: (root / rel).read_bytes() for rel in (PROBE_EVIDENCE_REL, PROBE_LEDGER_REL)}
    results = {item.get("id"): item for item in json.loads(raws[PROBE_EVIDENCE_REL]).get("results", [])}
    hops = {name: ((results.get(probe_id) or {}).get("observed") or {}).get("hops") or [{}]
            for name, probe_id in PROBE_CANCELLED_IDS.items()}
    statuses = {name: value[0].get("status") for name, value in hops.items()}
    sequences = {name: value[0].get("sequence") for name, value in hops.items()}
    value = {"available": False, "files": {rel: sha256_hex(raw) for rel, raw in raws.items()}, "statuses": statuses,
             "sequences": sequences}
    if all(status == 200 for status in statuses.values()):
        rows = {row.get("sequence"): row for row in json.loads(raws[PROBE_LEDGER_REL])["transactions"]}
        bodies = {}
        for name, sequence in sequences.items():
            row = rows.get(sequence) or {}
            raw = base64.b64decode(row.get("response_body_base64") or "")
            if row.get("actual_status") != 200 or sha256_hex(raw) != row.get("response_sha256"):
                raise DryRunError(f"probe ledger seq {sequence} does not hold the recorded {name} body")
            bodies[name] = json.loads(raw)
        run, page = bodies["run"], bodies["jobs"]
        jobs = page.get("jobs") or []
        steps = [step for job in jobs for step in job.get("steps") or []]
        if (run.get("status"), run.get("conclusion")) != ("completed", "cancelled") or not jobs or not steps:
            raise DryRunError("the probe's cancelled-run sample is not a completed cancelled run with jobs and steps")
        if any(set(job) != set(jobs[0]) for job in jobs) or any(set(step) != set(steps[0]) for step in steps):
            raise DryRunError("the probe's cancelled-run jobs do not share one job and one step key set")
        value.update(available=True, run=run, page_keys=set(page), job_keys=set(jobs[0]), step_keys=set(steps[0]),
                     job_pairs={(job.get("status"), job.get("conclusion")) for job in jobs},
                     step_pairs={(step.get("status"), step.get("conclusion")) for step in steps},
                     cancelled_jobs=sum(1 for job in jobs if job.get("conclusion") == "cancelled"))
        # The rules are read off the sample: the recorded run must satisfy every one of them (self-check).
        own = cancelled_run_problems(run, value, "the recorded cancelled run") + cancelled_jobs_problems(
            page, value, "the recorded cancelled run's jobs")
        if own:
            raise DryRunError(f"the recorded cancelled run does not satisfy its own rules: {own[:3]}")
    _CANCELLED_REFERENCE["value"] = value
    return value


def response_shape(journal: list, runs: dict, reference: dict, log_reference: dict | None = None, live: bool = False,
                   local_port=None, cancelled_reference: dict | None = None) -> dict:
    """Compare every run, job, step and artifact object the fake actually served (run polls, workflow_runs listings, jobs
    and artifacts pages, decoded from the server journal) with the recorded real shapes."""
    mismatches, scenarios = [], set()
    counts = {"runs_checked": 0, "jobs_checked": 0, "steps_checked": 0, "artifacts_checked": 0}
    cancelled_seen = {"run": 0, "jobs": 0}
    cancelled_ok = bool(cancelled_reference and cancelled_reference.get("available"))
    run_path = re.compile(rf"/repos/{REPO}/actions/runs/(\d+)")
    listing_path = re.compile(rf"/repos/{REPO}/actions/workflows/\d+/runs")
    page_path = re.compile(rf"/repos/{REPO}/actions/runs/(\d+)/(jobs|artifacts)")

    def check_run(run):
        record = runs.get(run.get("id")) if isinstance(run, dict) else None
        if record is None:
            mismatches.append(f"served run {run.get('id') if isinstance(run, dict) else run!r} is not one the fake dispatched")
            return
        counts["runs_checked"] += 1
        scenarios.add(record["scenario"])
        mismatches.extend(check_run_shape(run, record["scenario"], reference))
        if cancelled_ok and record["scenario"] == "cancelled" and run.get("status") == "completed":
            # 253-128: the completed cancelled run against GitHub's recorded cancelled run (253-127 probe).
            cancelled_seen["run"] += 1
            mismatches.extend(cancelled_run_problems(run, cancelled_reference, f"cancelled run {run.get('id')}"))

    for row in journal:
        if row.get("actual_status") != 200:
            continue
        path = urlsplit(row.get("observed_path") or "").path
        is_run, is_listing, is_page = run_path.fullmatch(path), listing_path.fullmatch(path), page_path.fullmatch(path)
        if not (is_run or is_listing or is_page):
            continue
        try:
            body = json.loads(base64.b64decode(row.get("response_body_base64") or ""))
        except ValueError:
            mismatches.append(f"served body for {path} is not JSON")
            continue
        if is_run:
            check_run(body)
            continue
        if is_page:
            run_id = int(is_page.group(1))
            record = runs.get(run_id)
            if record is None:
                mismatches.append(f"served {is_page.group(2)} page for run {run_id}, which the fake never dispatched")
                continue
            if is_page.group(2) == "jobs":
                problems, jobs, steps = check_jobs_shape(body, run_id, record, reference)
                counts["jobs_checked"] += jobs
                counts["steps_checked"] += steps
                if cancelled_ok and record["scenario"] == "cancelled":
                    cancelled_seen["jobs"] += 1
                    problems = problems + cancelled_jobs_problems(body, cancelled_reference, f"jobs page of cancelled run {run_id}")
            else:
                problems, artifacts = check_artifacts_shape(body, run_id, reference)
                counts["artifacts_checked"] += artifacts
            mismatches.extend(item for item in problems if item)
            continue
        problem = _key_problem("workflow_runs listing", body, reference["listing"])
        if problem:
            mismatches.append(problem)
        for run in (body.get("workflow_runs") or []) if isinstance(body, dict) else []:
            check_run(run)
    # 253-128: every run_logs hop the fake served, against GitHub's recorded chain (253-127 probe, R10 seq 47).
    log_chains = 0
    if log_reference is not None:
        log_problems, log_chains = check_run_logs(journal, log_reference, live, local_port)
        mismatches.extend(log_problems)
    unique = list(dict.fromkeys(mismatches))
    return {"reference": {"path": reference["path"], "sha256": reference["sha256"], "sequences": reference["sequences"]},
            "log_reference": (log_reference or {}).get("files"),
            "ok": not unique, **counts, "scenarios_checked": sorted(scenarios),
            "verifier_run_checked": "verifier" in scenarios, "run_logs_chains_checked": log_chains,
            "cancelled_reference": (cancelled_reference or {}).get("files"),
            "cancelled_run_checked": (None if cancelled_reference is None else "unavailable" if not cancelled_ok
                                      else cancelled_seen["run"] >= 1 and cancelled_seen["jobs"] >= 1),
            "run_logs_checked": log_chains >= 1, "mismatch_count": len(unique), "mismatches": unique[:10]}


def build_jobs_page(record: dict, faults=()) -> dict:
    """A run's jobs page as the fake serves it (moved out of the handler by 253-128, unchanged; also the job list the
    failed-log archive is built from). Fault cancelled-shape-drift: the cancelled run's cancelled job reports failure."""
    run_id = record["id"]
    jobs = []
    reference = load_reference()

    def job(name, conclusion, names=(), step_conclusions=None):
        # 253-117: GitHub's recorded job and step shapes (seq 28); a skipped job lists no steps, as GitHub's does.
        ran = conclusion not in (None, "skipped")
        steps = build_steps(names, step_conclusions, conclusion is not None) if ran or conclusion is None else []
        jobs.append(build_job(record, run_id * 10 + len(jobs), name, conclusion, steps if names else [], reference))
    scenario, done = record["scenario"], record.get("completed")
    if scenario == "verifier":
        job(SKIPPED_PRODUCER_NAME, "skipped" if done else None)
        job("Browser verdict", "skipped" if done else None)
        ok = "success" if record.get("matrix_ok") else "failure"
        job("verifier", ok if done else None, VERIFIER_STEPS, {"Verify retained source matrix independently": ok})
    else:
        producer_steps, verdict_steps = reference_steps(reference, "producer"), reference_steps(reference, "Browser verdict")
        for seam in SEAMS:
            conclusion = "success"
            if scenario == "actual-failure" and seam == "admin_behavior":
                conclusion = "failure"
            if scenario == "cancelled" and seam == "admin_behavior":
                conclusion = ("failure" if "cancelled-shape-drift" in faults else "cancelled") if done else None
            step_conclusions = {"Run the named synthetic tiny command": conclusion}
            if scenario == "missing-seam" and seam == "admin_checkpoints":
                # The fixture's upload step is if: !(missing-seam && admin_checkpoints): GitHub reports it skipped.
                step_conclusions["Upload this producer's synthetic receipt"] = "skipped"
            job(f"producer ({seam})", conclusion, producer_steps, step_conclusions)
        outcome = OUTCOMES[scenario]
        if scenario == "cancelled":
            job("Browser verdict", "skipped" if done else None)
        else:
            job("Browser verdict", outcome if done else None, verdict_steps, {"Shared browser record validator": outcome})
        job("verifier", "skipped" if done else None)
    return {"total_count": len(jobs), "jobs": jobs}


# ----------------------------------------------------------------------------------------- git-backed object store
class LazyBlobs(dict):
    """Blob map backed by the fake's object store; GitHub knows every blob reachable in the repository."""

    def __init__(self, server):
        super().__init__()
        self.server = server

    def _load(self, sha):
        if not isinstance(sha, str) or not SHA40.fullmatch(sha):
            return None
        kind = run(["git", f"--git-dir={self.server.git_dir}", "cat-file", "-t", sha], check=False)
        if kind.returncode or kind.stdout.decode().strip() != "blob":
            return None
        data = run(["git", f"--git-dir={self.server.git_dir}", "cat-file", "blob", sha]).stdout
        value = {"sha": sha, "content": base64.b64encode(data).decode(), "size": len(data)}
        dict.__setitem__(self, sha, value)
        return value

    def get(self, sha, default=None):
        return dict.get(self, sha) or self._load(sha) or default

    def __contains__(self, sha):
        return dict.__contains__(self, sha) or self._load(sha) is not None


class LazyTrees(dict):
    def __init__(self, server):
        super().__init__()
        self.server = server

    def _load(self, sha):
        if not isinstance(sha, str) or not SHA40.fullmatch(sha):
            return None
        kind = run(["git", f"--git-dir={self.server.git_dir}", "cat-file", "-t", sha], check=False)
        if kind.returncode or kind.stdout.decode().strip() != "tree":
            return None
        value = {"sha": sha, "tree": self.server.top_level(sha), "truncated": False}
        dict.__setitem__(self, sha, value)
        return value

    def get(self, sha, default=None):
        return dict.get(self, sha) or self._load(sha) or default

    def __contains__(self, sha):
        return dict.__contains__(self, sha) or self._load(sha) is not None


# ----------------------------------------------------------------------------------------------------- fake GitHub
class FakeGitHub(ObjectServer):
    """GitHub-faithful local HTTPS fake: reuses ObjectServer's Git object routes, adds the canary REST routes."""

    server_version = "GitHub.com"
    sys_version = ""

    def version_string(self):
        return "GitHub.com"

    def date_time_string(self, timestamp=None):
        return FIXED_DATE

    # -- wire and journal ----------------------------------------------------------------------------------
    def _pending(self):
        for _ in range(50):
            try:
                ledger = json.loads(Path(self.server.ledger_path).read_text())
                rows = [row for row in ledger.get("transactions", []) if row.get("state") == "pending"]
                if rows:
                    return rows[-1]
            except (OSError, ValueError):
                pass
            time.sleep(0.02)
        return None

    def _send(self, status, body=b"", content_type="application/json; charset=utf-8", extra=(), api=True,
              always_type=False, chunked=False):
        # 253-128: always_type sends Content-Type on an empty redirect (GitHub's run_logs hop 0 does); chunked omits
        # Content-Length and frames the body chunked (GitHub's results-receiver hop 1 sends no Content-Length).
        pending = self._pending()
        headers = [("Server", self.version_string()), ("Date", FIXED_DATE)]
        if body or status not in (204, 302) or always_type:
            headers.append(("Content-Type", content_type))
        if not chunked:
            headers.append(("Content-Length", str(len(body))))
        headers.append(("X-GitHub-Request-Id", f"DRYRUN:{len(self.server.journal) + 1:04d}"))
        if api:
            remaining = 4900 - len(self.server.journal)
            headers += [("X-RateLimit-Limit", "5000"), ("X-RateLimit-Remaining", str(remaining)),
                        ("X-RateLimit-Reset", "1792100000"), ("X-RateLimit-Resource", "core")]
        headers += list(extra)
        safe, scrubbed = TRANSPORT.scrub_receipt(headers, body, [], headers)
        if pending is None:
            self.server.violations.append(f"uncharged request {self.command} {self.path}")
            row = {"sequence": None}
        else:
            row = {key: pending.get(key) for key in (
                "sequence", "url", "url_sha256", "route_id", "page_ordinal", "hop_ordinal", "source_sha256", "window_id",
                "request_sha256", "request_body_base64", "dispatch_inputs", "input_key_count", "input_unicode_scalars",
                "input_utf8_bytes", "input_sha256")}
            expected_path = urlsplit(pending.get("url", "")).path
            observed = urlsplit(self.path)
            if pending.get("method") != self.command or observed.path != expected_path:
                self.server.violations.append(f"journal/ledger mismatch: {self.command} {self.path} vs {pending.get('url')}")
            body_sha = sha256_hex(self.server.last_body) if self.server.last_body else None
            if (pending.get("request_body_sha256") or None) != body_sha:
                self.server.violations.append(f"request body differs from the charged ledger row: {self.path}")
            if self.server.live and pending.get("host") != self._host():
                self.server.violations.append(f"ledger host {pending.get('host')} differs from the Host header {self._host()}")
        row.update({"method": self.command, "actual_status": status, "scrubbed_headers": safe,
                    "response_sha256": sha256_hex(scrubbed), "response_body_base64": base64.b64encode(scrubbed).decode(),
                    "response_bytes": len(body), "scrubbed_response_bytes": len(scrubbed), "state": "complete",
                    "observed_path": self.path, "raw_magic_hex": body[:8].hex()})
        if content_type == "application/zip" and body:
            # 253-128: the raw archive's member names (the journal's body is the scrubbed text, which does not unzip).
            try:
                row["zip_member_names"] = zipfile.ZipFile(io.BytesIO(body)).namelist()
            except zipfile.BadZipFile:
                row["zip_member_names"] = None
        if self.server.live:
            row["host"] = self._host()
        with self.server.lock:
            self.server.journal.append(row)
            atomic_write(Path(self.server.journal_path), json.dumps(self.server.journal).encode())
        self.send_response(status)
        for name, value in headers[2:]:
            self.send_header(name, value)
        if chunked:
            self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        if chunked:
            self.wfile.write(f"{len(body):x}\r\n".encode() + body + b"\r\n0\r\n\r\n" if body else b"0\r\n\r\n")
        elif body:
            self.wfile.write(body)

    def _reply(self, status, value):
        self._send(status, json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode())

    def _refuse(self, reason, status=422):
        self.server.violations.append(f"{reason}: {self.command} {self.path}")
        self._reply(status, {"message": "Validation Failed", "documentation_url": "https://docs.github.com/rest"})

    def _host(self):
        return (self.headers.get("Host") or "").lower()

    def _guard(self):
        """None to serve normally; otherwise the request is answered here (credential refusal or an injected error)."""
        server = self.server
        authorization = self.headers.get("Authorization")
        if server.live:
            # 253-108: requests are routed by Host header. api.github.com must carry exactly the dummy bearer token and
            # never a download path; the blob host must carry no Authorization and serve only the paths this fake issued.
            host, download = self._host(), urlsplit(self.path).path.startswith("/_downloads/")
            receiver = RESULTS_LOG_PATH.fullmatch(urlsplit(self.path).path) is not None
            if host == API_HOST:
                if authorization == f"Bearer {LIVE_TOKEN}":
                    server.authorization["api_with"] += 1
                else:
                    server.authorization["api_without"] += 1
                    server.violations.append(f"api.github.com request without the dummy bearer token: {self.command} {self.path}")
                if download or receiver:
                    return lambda: self._refuse("a download path was requested on api.github.com", 404)
            elif host == RESULTS_RECEIVER_HOST:
                # 253-128: GitHub's run-log host takes no Authorization and serves only the log paths this fake issued.
                if authorization:
                    server.authorization["results_receiver_with"] += 1
                    server.violations.append(f"Authorization reached results-receiver: {self.command} {urlsplit(self.path).path}")
                if not receiver:
                    return lambda: self._refuse("results-receiver serves only issued run-log paths", 404)
            elif host == BLOB_HOST:
                if authorization:
                    server.authorization["blob_with"] += 1
                    server.violations.append(f"Authorization reached the blob host: {self.command} {urlsplit(self.path).path}")
                if not download:
                    return lambda: self._refuse("the blob host serves only issued download paths", 404)
            else:
                return lambda: self._refuse(f"request for an unmodeled Host {host!r}", 421)
        elif authorization:
            self.server.violations.append("a credential reached the local fake")
            return lambda: self._reply(400, {"message": "dry-run fake refuses credentials"})
        key = self.command + " " + urlsplit(self.path).path
        if key in self.server.inject:
            status, payload = self.server.inject.pop(key)
            return lambda: self._send(status, payload)
        return None

    # -- request entry points ------------------------------------------------------------------------------
    def do_GET(self):  # noqa: N802
        self.server.last_body = b""
        answered = self._guard()
        if answered:
            return answered()
        parsed = urlsplit(self.path)
        path, query = parsed.path, parse_qs(parsed.query, keep_blank_values=True)
        if path.startswith("/_downloads/"):
            return self._download(path, query)
        if RESULTS_LOG_PATH.fullmatch(path):
            return self._results_receiver(path, query)
        if path.startswith(f"/repos/{REPO}/git/"):
            if query:
                return self._refuse("Git object reads take no query")
            return super().do_GET()
        handler = self._get_handler(path, query)
        if handler is None:
            return self._refuse("no GitHub GET route for this path or query", 404)
        return handler()

    def do_POST(self):  # noqa: N802
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.server.last_body = raw
        answered = self._guard()
        if answered:
            return answered()
        parsed = urlsplit(self.path)
        if parsed.query:
            return self._refuse("POST routes take no query")
        try:
            value = json.loads(raw or b"null")
        except ValueError:
            return self._refuse("POST body is not JSON", 400)
        path = parsed.path
        if path == f"/repos/{REPO}/git/trees":
            return self._create_tree(value)
        if path in (f"/repos/{REPO}/git/blobs", f"/repos/{REPO}/git/commits", f"/repos/{REPO}/git/refs"):
            self.rfile = io.BytesIO(raw)
            self.headers.replace_header("Content-Length", str(len(raw)))
            return super().do_POST()
        match = re.fullmatch(rf"/repos/{REPO}/actions/workflows/(\d+)/dispatches", path)
        if match:
            return self._dispatch(int(match.group(1)), value)
        match = re.fullmatch(rf"/repos/{REPO}/actions/runs/(\d+)/cancel", path)
        if match:
            return self._cancel(int(match.group(1)), value)
        return self._refuse("no GitHub POST route for this path", 404)

    def log_message(self, *_args):
        pass

    # -- REST routes -------------------------------------------------------------------------------------------
    def _paged(self, query, extra_keys=()):
        expected = {"per_page", "page", *extra_keys}
        if set(query) != expected or any(len(values) != 1 for values in query.values()):
            return None
        if query["per_page"] != ["100"] or query["page"] != ["1"]:
            return None
        return {key: values[0] for key, values in query.items()}

    def _get_handler(self, path, query):
        server = self.server
        if path == "/rate_limit" and not query:
            server.last_rate_at = time.monotonic()
            return lambda: self._reply(200, {"resources": {"core": {"limit": 5000, "used": 100 + len(server.journal),
                                                                    "remaining": 4900 - len(server.journal), "reset": 1792100000}},
                                             "rate": {"limit": 5000, "remaining": 4900 - len(server.journal)}})
        if path == f"/repos/{REPO}/rules/branches/main" and self._paged(query) is not None:
            return lambda: self._reply(200, server.rules)
        if path == f"/repos/{REPO}/branches/main/protection" and not query:
            return lambda: self._reply(404, {"message": "Branch not protected", "status": "404"})
        match = re.fullmatch(rf"/repos/{REPO}/commits/([a-f0-9]{{40}})/check-runs", path)
        if match and self._paged(query) is not None:
            return lambda: self._check_runs(match.group(1))
        match = re.fullmatch(rf"/repos/{REPO}/actions/workflows/(\d+)", path)
        if match and not query:
            return lambda: self._workflow(int(match.group(1)))
        match = re.fullmatch(rf"/repos/{REPO}/actions/workflows/(\d+)/runs", path)
        if match:
            fields = self._paged(query, ("event", "branch"))
            if fields is not None and fields["event"] == "workflow_dispatch":
                return lambda: self._list_runs(int(match.group(1)), fields["branch"])
            return None
        match = re.fullmatch(rf"/repos/{REPO}/actions/runs/(\d+)", path)
        if match and not query:
            return lambda: self._poll(int(match.group(1)))
        match = re.fullmatch(rf"/repos/{REPO}/actions/runs/(\d+)/jobs", path)
        if match and self._paged(query) is not None:
            return lambda: self._jobs(int(match.group(1)))
        match = re.fullmatch(rf"/repos/{REPO}/actions/runs/(\d+)/artifacts", path)
        if match and self._paged(query) is not None:
            return lambda: self._artifacts(int(match.group(1)))
        match = re.fullmatch(rf"/repos/{REPO}/actions/artifacts/(\d+)/zip", path)
        if match and not query:
            return lambda: self._redirect("artifacts", int(match.group(1)))
        match = re.fullmatch(rf"/repos/{REPO}/actions/runs/(\d+)/logs", path)
        if match and not query:
            return lambda: self._redirect("logs", int(match.group(1)))
        return None

    def _check_runs(self, sha):
        if sha != self.server.server_parent:
            return self._reply(200, {"total_count": 0, "check_runs": []})
        runs = [{"id": 70000000 + index, "name": name, "head_sha": sha, "status": "completed", "conclusion": "success",
                 "html_url": f"https://github.com/{REPO}/actions/runs/600000/job/{70000000 + index}",
                 "app": dict(APP)} for index, name in enumerate(REQUIRED_CHECKS)]
        self._reply(200, {"total_count": len(runs), "check_runs": runs})

    def _workflow(self, workflow_id):
        if workflow_id != WORKFLOW_ID:
            return self._reply(404, {"message": "Not Found"})
        self._reply(200, {"id": WORKFLOW_ID, "name": "CI", "path": ".github/workflows/ci.yml", "state": "active",
                          "html_url": f"https://github.com/{REPO}/blob/main/.github/workflows/ci.yml"})

    def _dispatch(self, workflow_id, value):
        server = self.server
        if workflow_id != WORKFLOW_ID or not isinstance(value, dict) or set(value) != {"ref", "inputs"}:
            return self._refuse("dispatch body must be exactly ref and inputs for the registered workflow")
        ref, inputs = value["ref"], value["inputs"]
        if not isinstance(ref, str) or ref not in server.refs:
            return self._refuse("dispatch ref does not exist")
        if (not isinstance(inputs, dict) or set(inputs) - DISPATCH_INPUTS or not REQUIRED_INPUTS <= set(inputs)
                or any(not isinstance(item, str) for item in inputs.values())
                or inputs["scenario"] not in (*SCENARIOS, "verifier")):
            return self._refuse("dispatch inputs are not the workflow's declared inputs")
        with server.lock:
            server.run_seq += 1
            run_id = server.run_base + server.run_seq
            server.runs[run_id] = {"id": run_id, "run_number": 500 + server.run_seq, "scenario": inputs["scenario"],
                                   "inputs": dict(inputs), "head_branch": ref, "head_sha": server.refs[ref],
                                   "visible_at": time.monotonic() + server.visibility_delay, "polls": 0,
                                   "needed": server.polls.get(inputs["scenario"], 3), "cancel_requested": False}
        self._send(204, b"")

    def _run_json(self, record):
        status, conclusion = "in_progress", None
        if record.get("completed"):
            status, conclusion = "completed", record["conclusion"]
        elif record["polls"] == 0 and not record["cancel_requested"]:
            status = "queued"
        # 253-117: GitHub's recorded run shape (name == display_title == the run-name, path exact).
        return build_run(record, status, conclusion, commit=self._commit(record["head_sha"]),
                         bare_name="run-shape-bare-name" in getattr(self.server, "faults", ()))

    def _commit(self, sha):
        """The fake's stored commit (publication created it), else the object from the fake's git store."""
        stored = self.server.commits.get(sha)
        if stored:
            return stored
        result = run(["git", f"--git-dir={self.server.git_dir}", "cat-file", "commit", sha], check=False)
        if result.returncode:
            return None
        head, _, message = result.stdout.decode(errors="replace").partition("\n\n")
        fields = dict(line.split(" ", 1) for line in head.splitlines() if " " in line)

        def ident(text):
            match = re.fullmatch(r"(.*) <(.*)> (\d+) [+-]\d{4}", text or "")
            if not match:
                return {}
            when = datetime.fromtimestamp(int(match.group(3)), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            return {"name": match.group(1), "email": match.group(2), "date": when}
        return {"sha": sha, "tree": {"sha": fields.get("tree")}, "message": message,
                "author": ident(fields.get("author")), "committer": ident(fields.get("committer"))}

    def _list_runs(self, workflow_id, branch):
        now = time.monotonic()
        runs = [self._run_json(record) for record in sorted(self.server.runs.values(), key=lambda item: -item["id"])
                if workflow_id == WORKFLOW_ID and record["head_branch"] == branch and record["visible_at"] <= now]
        self._reply(200, {"total_count": len(runs), "workflow_runs": runs})

    def _poll(self, run_id):
        record = self.server.runs.get(run_id)
        if record is None or record["visible_at"] > time.monotonic():
            return self._reply(404, {"message": "Not Found"})
        if "first_poll_delay" not in record:
            record["first_poll_delay"] = round(time.monotonic() - self.server.last_rate_at, 3)
        if not record.get("completed"):
            record["polls"] += 1
            waiting_on_cancel = record["scenario"] == "cancelled" and not record["cancel_requested"]
            if record["polls"] >= record["needed"] and not waiting_on_cancel:
                record["completed"] = True
                record["conclusion"] = self._conclusion(record)
        self._reply(200, self._run_json(record))

    def _conclusion(self, record):
        if record["scenario"] != "verifier":
            return OUTCOMES[record["scenario"]]
        verifier = self.server.verifier_module
        payload = record["inputs"].get("matrix_evidence")
        job = {"model": "verify_sources" if self.server.live else "scenario-set",
               "matrix_payload_chars": len(payload) if isinstance(payload, str) else None}
        try:
            decoded = verifier.decode_matrix_payload(payload)
            if self.server.live:
                # 253-117 (D-22): what the hosted verifier job runs, the candidate's verify_sources on the decoded compact
                # matrix. Hermetic evidence says fixture_ref_state hermetic-unverified and the compact matrix carries no
                # origin, so there the job keeps the scenario-set model.
                results, executed = verifier.verify_sources(decoded)
                job.update(result="sources_verified", executed_jobs=executed,
                           scenarios=[item.get("scenario") for item in results])
                ok = True
            else:
                ok = set(decoded.get("scenarios", {})) == set(SCENARIOS)
                job.update(result="scenario_set_complete" if ok else "scenario_set_incomplete")
        except Exception as error:  # noqa: BLE001 - the modeled verifier job simply fails
            ok = False
            job.update(result="failed", error=f"{type(error).__name__}: {error}"[:400])
        record["matrix_ok"] = ok
        self.server.verifier_job = job
        return "success" if ok else "failure"

    def _cancel(self, run_id, value):
        record = self.server.runs.get(run_id)
        if value != {}:
            return self._refuse("cancel takes no parameters")
        if record is None:
            return self._reply(404, {"message": "Not Found"})
        if record.get("completed"):
            return self._reply(409, {"message": "Cannot cancel a workflow run that is completed."})
        record["cancel_requested"] = True
        record["polls"] = 0
        self._reply(202, {})

    def _jobs(self, run_id):
        record = self.server.runs.get(run_id)
        if record is None:
            return self._reply(404, {"message": "Not Found"})
        self._reply(200, self._jobs_body(record))

    def _jobs_body(self, record):
        """The run's jobs page (253-128: also the job list the failed-log archive is built from)."""
        return build_jobs_page(record, getattr(self.server, "faults", ()))

    def _artifacts(self, run_id):
        record = self.server.runs.get(run_id)
        if record is None:
            return self._reply(404, {"message": "Not Found"})
        artifacts = []
        if record.get("completed") and record["scenario"] != "verifier":
            for seam in SEAMS:
                if record["scenario"] == "missing-seam" and seam == "admin_checkpoints":
                    continue
                if record["scenario"] == "cancelled" and seam == "admin_behavior":
                    continue
                content = json.dumps({"schema_version": "sigra.gate-canary-producer/v1", "scenario": record["scenario"],
                                      "seam": seam, "actual_event": "workflow_dispatch", "synthetic": True}).encode() + b"\n"
                artifacts.append(self._artifact(record, f"gate-canary-producer-{seam}-{run_id}-1",
                                                zip_bytes("producer.json", content)))
            if record["scenario"] != "cancelled":
                artifacts.append(self._artifact(record, f"gate-canary-{record['scenario']}-{run_id}-1",
                                                zip_bytes("canary-result.json", self._result(record))))
        self._reply(200, {"total_count": len(artifacts), "artifacts": artifacts})

    def _artifact(self, record, name, archive):
        server = self.server
        key = (record["id"], name)
        if key not in server.artifact_ids:
            server.artifact_ids[key] = 900000 + len(server.artifact_ids) + 1
        artifact_id = server.artifact_ids[key]
        server.blobs_by_artifact[artifact_id] = archive
        digest = sha256_hex(archive)
        if "artifact-digest" in getattr(server, "faults", ()) and name.startswith("gate-canary-") and "-producer-" not in name:
            digest = sha256_hex(archive + b"modeled-corruption")
        # 253-117: GitHub's recorded artifact shape (seq 29), workflow_run with its real key set.
        return build_artifact(record, artifact_id, name, len(archive), digest)

    def _result(self, record):
        scenario, inputs = record["scenario"], record["inputs"]
        passed = scenario in ("full-pass", "docs-only")
        logical = "pull_request" if scenario == "docs-only" else "workflow_dispatch"
        verdict = {"schema_version": "sigra.gate-canary-result/v1", "scenario": scenario, "run_id": str(record["id"]),
                   "run_attempt": "1", "candidate_sha": inputs["candidate_sha"], "fixture_workflow_sha": inputs["fixture_sha"],
                   "fixture_workflow_blob": inputs["fixture_blob"], "status": "passed" if passed else "rejected",
                   "synthetic": True, "actual_event": "workflow_dispatch", "logical_event": logical,
                   "classifier_result": "success" if scenario == "docs-only" else "", "docs_only": scenario == "docs-only",
                   "production_dispatch_exemption": False, "validator_exit_code": 0 if passed else 1,
                   "missing_producer_seams": ["admin_checkpoints"] if scenario == "missing-seam" else [],
                   "honest_skip_verdict": {"verdict": "PASS" if passed else "FAIL", "event": logical,
                                           "docs_only": "true" if scenario == "docs-only" else "false", "modeled": True},
                   "honest_skip_exit_code": 0 if passed else 1}
        return (json.dumps(verdict, indent=2) + "\n").encode()

    def _redirect(self, kind, identifier):
        server = self.server
        if kind == "artifacts" and identifier not in server.blobs_by_artifact:
            return self._reply(404, {"message": "Not Found"})
        if kind == "logs":
            record = server.runs.get(identifier)
            if record is None or not record.get("completed") or record.get("conclusion") != "failure":
                return self._reply(404, {"message": "Not Found"})
        if kind == "logs" and "run-logs-legacy-blob-redirect" not in getattr(server, "faults", ()):
            # 253-128: GitHub's recorded chain (253-127 probe, R10 seq 47): hop 0 is a 302 with the recorded content-type
            # and an empty body, to results-receiver /rest/runs/<uuid>/logs with a signed query (synthetic names/values).
            first = load_log_reference()["hops"][0]
            token = str(uuid.uuid5(LOG_UUID_NAMESPACE, str(identifier)))
            server.log_tokens[token] = identifier
            origin = f"https://{RESULTS_RECEIVER_HOST}" if server.live else f"https://localhost:{server.server_address[1]}"
            return self._send(first["status"], b"", content_type=first["content_type"], always_type=True,
                              extra=[("Location", f"{origin}/rest/runs/{token}/logs?{LOG_QUERY}")])
        if server.live:
            # GitHub answers with a pre-signed blob URL on port 443 (no explicit port); the transport must follow it.
            # Artifacts only; for logs this is the pre-R11 shape, served only under --fault run-logs-legacy-blob-redirect.
            location = f"https://{BLOB_HOST}/_downloads/{kind}/{identifier}?sv=2025&sig=dry-run-signature"
        else:
            location = f"https://localhost:{server.server_address[1]}/_downloads/{kind}/{identifier}?sig=dry-run-signature"
        self._send(302, b"", extra=[("Location", location)])

    def _results_receiver(self, path, query):
        """253-128: results-receiver answers hop 1 as the probe recorded: the final 200 application/zip, no Content-Length,
        a zip in the recorded member pattern (one numbered log and one system.txt per executed job)."""
        server = self.server
        hops = load_log_reference()["hops"]
        if len(hops) != 2:
            return self._refuse(f"the recorded run-log chain has {len(hops)} hops; this fake models the observed two", 404)
        if query != parse_qs(LOG_QUERY, keep_blank_values=True):
            return self._refuse("results-receiver log query is not one this fake issued", 404)
        record = server.runs.get(server.log_tokens.get(RESULTS_LOG_PATH.fullmatch(path).group(1)))
        if record is None or not record.get("completed") or record.get("conclusion") != "failure":
            return self._refuse("results-receiver log path is not one this fake issued", 404)
        final = hops[-1]
        names = [job["name"] for job in self._jobs_body(record)["jobs"] if job["conclusion"] not in (None, "skipped")]
        self._send(final["status"], log_archive(names), content_type=final["content_type"], api=False,
                   chunked=final["content_length"] is None)

    def _download(self, path, query):
        match = re.fullmatch(r"/_downloads/(artifacts|logs)/(\d+)", path)
        if not match or set(query) != ({"sv", "sig"} if self.server.live else {"sig"}):
            return self._refuse("download host path is not one this fake issued", 404)
        kind, identifier = match.group(1), int(match.group(2))
        if kind == "logs" and "run-logs-legacy-blob-redirect" not in getattr(self.server, "faults", ()):
            return self._refuse("the pre-R11 blob log path is not GitHub's recorded run-log chain", 404)
        if kind == "artifacts":
            data = self.server.blobs_by_artifact.get(identifier)
        else:
            record = self.server.runs.get(identifier, {})
            data = zip_bytes("0_producer (admin_behavior).txt",
                             f"modeled failed log for {record.get('scenario')} run {identifier}\n".encode())
        if data is None:
            return self._reply(404, {"message": "Not Found"})
        self._send(200, data, content_type="application/zip", api=False)

    # -- Git tree creation (git-index backed, top-level response like GitHub) --------------------------------
    def _create_tree(self, value):
        server = self.server
        if not isinstance(value, dict) or set(value) - {"base_tree", "tree"} or not isinstance(value.get("tree"), list):
            return self._refuse("tree body must be base_tree and tree")
        base = value.get("base_tree")
        index = Path(server.work) / f"index-{threading.get_ident()}"
        index.unlink(missing_ok=True)
        empty = Path(server.work) / "empty-work-tree"
        empty.mkdir(exist_ok=True)
        env = {**os.environ, "GIT_INDEX_FILE": str(index), "GIT_WORK_TREE": str(empty)}
        gitdir = f"--git-dir={server.git_dir}"
        try:
            if base:
                if base not in server.trees:
                    return self._reply(422, {"message": "base_tree is not a valid tree"})
                run(["git", gitdir, "read-tree", base], env=env)
            for item in value["tree"]:
                path = item["path"]
                if item.get("sha") is None and "content" not in item:
                    run(["git", gitdir, "update-index", "--force-remove", "--", path], env=env)
                    continue
                if "content" in item:
                    sha = run(["git", gitdir, "hash-object", "-w", "--stdin"], data=item["content"].encode("utf-8")).stdout.decode().strip()
                else:
                    sha = item["sha"]
                if sha not in server.blobs:
                    return self._reply(422, {"message": "tree references unknown blob"})
                run(["git", gitdir, "update-index", "--add", "--cacheinfo", f"{item['mode']},{sha},{path}"], env=env)
            tree = run(["git", gitdir, "write-tree"], env=env).stdout.decode().strip()
        finally:
            index.unlink(missing_ok=True)
        self._reply(201, {"sha": tree, "url": f"https://api.github.com/repos/{REPO}/git/trees/{tree}",
                          "tree": server.top_level(tree), "truncated": False})


class FakeServer(OBJECT_TESTS.ObjectHTTPServer):
    def handle_error(self, request, client_address):
        # A client closing its socket (keep-alive read after close) is not a fault; any other handler error is.
        error = sys.exc_info()[1]
        if not isinstance(error, (OSError, ssl.SSLError)):
            self.violations.append(f"fake handler error: {type(error).__name__}: {error}")

    def top_level(self, tree):
        rows = run(["git", f"--git-dir={self.git_dir}", "ls-tree", tree]).stdout.decode().splitlines()
        result = []
        for row in rows:
            meta, path = row.split("\t", 1)
            mode, kind, sha = meta.split()
            result.append({"path": path, "mode": mode, "type": kind, "sha": sha,
                           "url": f"https://api.github.com/repos/{REPO}/git/{kind}s/{sha}"})
        return result


def seeded_scoped_refs(args) -> dict:
    """The earlier scoped refs the run pre-seeds at their real GitHub SHAs: r8 (--seed-r8-refs), r9 (--seed-r9-refs) or both."""
    refs = {}
    if getattr(args, "seed_r8_refs", False):
        refs.update(R8_REFS)
    if getattr(args, "seed_r9_refs", False):
        refs.update(R9_REFS)
    return refs


def start_fake(work: Path, clone: Path, ledger: Path, journal: Path, server_parent: str, verifier_module,
               visibility_delay: float, polls: dict, seed_legacy: bool, live: bool = False, seed_refs: dict | None = None):
    cert, key = work / "tls-cert.pem", work / "tls-key.pem"
    # Live-policy mode: a certificate for the real hostnames, so SNI and hostname verification use them (253-108).
    names = LIVE_TLS_NAMES if live else ("localhost",)
    run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
         "-subj", "/CN=" + ("sigra-live-policy-dry-run" if live else "localhost"),
         "-addext", "subjectAltName=" + ",".join(f"DNS:{name}" for name in names), "-keyout", str(key), "-out", str(cert)])
    server = FakeServer(("127.0.0.1", 0), FakeGitHub)
    server.live = live
    server.authorization = {"api_with": 0, "api_without": 0, "blob_with": 0, "results_receiver_with": 0}
    server.log_tokens = {}
    server.work = str(work)
    server.git_dir = str(work / "fake-github.git")
    run(["git", "init", "--bare", "-q", server.git_dir])
    (Path(server.git_dir) / "objects/info/alternates").write_text(str(clone / ".git/objects") + "\n")
    server.journal, server.violations, server.lock = [], [], threading.Lock()
    server.journal_path, server.ledger_path = str(journal), str(ledger)
    server.blobs, server.trees, server.tree_entries = LazyBlobs(server), LazyTrees(server), {}
    server.commits, server.refs, server.flags, server.last_body = {}, {}, {}, b""
    server.parent_sha = server.server_parent = server_parent
    raw = run(["git", "-C", str(clone), "cat-file", "commit", server_parent]).stdout
    head, message = raw.split(b"\n\n", 1)
    lines = head.decode().splitlines()
    server.commits[server_parent] = {"sha": server_parent, "tree": {"sha": next(l.split()[1] for l in lines if l.startswith("tree "))},
                                     "parents": [{"sha": l.split()[1]} for l in lines if l.startswith("parent ")],
                                     "message": message.decode(), "author": {}, "committer": {}}
    if seed_legacy:
        server.refs.update(LEGACY_REFS)
    if seed_refs:
        server.refs.update(seed_refs)
    server.seeded = dict(server.refs)
    server.rules = [{"type": "required_status_checks", "ruleset_source_type": "Repository", "ruleset_source": REPO,
                     "ruleset_id": 4242424, "parameters": {"strict_required_status_checks_policy": False,
                                                          "do_not_enforce_on_create": False,
                                                          "required_status_checks": [{"context": name, "integration_id": APP["id"]}
                                                                                     for name in REQUIRED_CHECKS]}},
                    {"type": "deletion", "ruleset_source_type": "Repository", "ruleset_source": REPO, "ruleset_id": 4242424}]
    server.runs, server.run_seq = {}, 0
    server.run_base = 40000000000 + int.from_bytes(os.urandom(3), "big") * 100
    server.visibility_delay, server.polls = visibility_delay, polls
    server.artifact_ids, server.blobs_by_artifact = {}, {}
    server.verifier_module = verifier_module
    server.verifier_job = None
    server.inject = {}
    server.last_rate_at = time.monotonic()
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.load_cert_chain(cert, key)
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, thread, cert


# --------------------------------------------------------------------------------------------------- the dry run
def stop_line(stderr: str) -> str | None:
    """The root cause when a component reported one (transport, verifier, publisher), else the driver's last FAIL line."""
    lines = [line.strip() for line in stderr.splitlines() if line.strip()]
    causes = [line for line in lines if re.search(r"ci-hosted-transport: |hosted-gate-verify: FAIL|ci-git-publication: ", line)]
    if causes:
        return causes[0]
    wanted = [line for line in lines if "ci-gate-canary: FAIL" in line]
    return (wanted or lines or [None])[-1]


def apply_patch(clone: Path, patch: dict) -> None:
    path = clone / DRIVER_REL
    text = path.read_text()
    count = text.count(patch["old"])
    if count != 1:
        raise DryRunError(f"reintroduction patch {patch.get('name')!r} applies {count} times, not exactly once")
    path.write_text(text.replace(patch["old"], patch["new"]))


def prepare_clone(args, work: Path) -> dict:
    clone = work / "clone"
    run(["git", "clone", "-q", "--shared", "--no-checkout", str(ROOT), str(clone)])
    head = git(ROOT, "rev-parse", "HEAD")
    git(clone, "checkout", "-q", "-B", "dry-run", head)
    for key, value in (("user.name", "Phase 253 dry run"), ("user.email", "dry-run@example.invalid"), ("commit.gpgsign", "false")):
        git(clone, "config", key, value)
    changed = False
    if args.overlay_worktree:
        # Development and test aid: carry the real checkout's uncommitted scripts/ci edits into the clone (read-only use
        # of the real checkout). The summary lists every overlaid path; the default run tests HEAD exactly.
        listed = git(ROOT, "diff", "--name-only", "HEAD", "--", "scripts/ci").splitlines()
        listed += git(ROOT, "ls-files", "--others", "--exclude-standard", "--", "scripts/ci").splitlines()
        overlaid = sorted({rel for rel in listed if rel and "__pycache__" not in rel})
        for rel in overlaid:
            source, target = ROOT / rel, clone / rel
            if source.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                git(clone, "add", rel)
            else:
                git(clone, "rm", "-q", rel)
        args.overlaid = overlaid
        changed = bool(overlaid)
    if args.driver_from:
        content = run(["git", "-C", str(ROOT), "show", f"{args.driver_from}:{DRIVER_REL}"]).stdout
        (clone / DRIVER_REL).write_bytes(content)
        changed = True
    if args.driver_patch:
        apply_patch(clone, json.loads(Path(args.driver_patch).read_text()))
        changed = True
    if getattr(args, "transport_from", None):
        # 253-108: the transport under test comes from this commit (the sensitivity control on the 253-104 defect).
        content = run(["git", "-C", str(ROOT), "show", f"{args.transport_from}:{TRANSPORT_REL}"]).stdout
        (clone / TRANSPORT_REL).write_bytes(content)
        git(clone, "add", TRANSPORT_REL)
        changed = True
    if changed:
        git(clone, "add", DRIVER_REL)
        git(clone, "commit", "-qm", "dry-run: driver and helpers under test", "--allow-empty")
    phase = clone / PHASE_REL
    publisher = clone / "scripts/ci/ci-git-publication.py"
    env = scrubbed_env(work)
    if args.revision_freeze:
        freeze_rel = args.revision_freeze
        freeze_plan = json.loads((clone / freeze_rel).read_text()).get("plan")
    else:
        server_parent = args.server_parent or json.loads((ROOT / R7_FREEZE_REL).read_text())["identity"]["server_parent_sha"]
        manifest_rel = f"{PHASE_REL}/253-DRYRUN-CANARY-PUBLICATION.json"
        run(["python3", str(publisher), "--prepare", "--candidate-source", git(clone, "rev-parse", "HEAD"),
             "--server-parent", server_parent, "--repo-root", str(clone), "--output", str(clone / manifest_rel),
             "--fixture-file", FIXTURE_REL, "--workflow-path", ".github/workflows/ci.yml"], env=env)
        git(clone, "add", manifest_rel)
        git(clone, "commit", "-qm", "dry-run: synthetic publication manifest")
        freeze_rel = f"{PHASE_REL}/253-DRYRUN-CANARY-FREEZE.json"
        build = ["python3", str(publisher), "--build-freeze", "--manifest", manifest_rel, "--output", freeze_rel,
                 "--repo-root", str(clone)]
        if args.ref_pair:
            build += ["--ref-pair", args.ref_pair]
        run(build, env=env)
        git(clone, "add", freeze_rel)
        git(clone, "commit", "-qm", "dry-run: synthetic freeze")
        freeze_plan = json.loads((clone / freeze_rel).read_text()).get("plan")
    freeze_path = clone / freeze_rel
    freeze = json.loads(freeze_path.read_text())
    approval_rel = f"{PHASE_REL}/253-DRYRUN-CANARY-ACTION-APPROVAL.json"
    approval = {"schema_version": "sigra.phase253.outward-action-approval/v1", "decision": "approve", "section": "canary",
                "section_sha256": freeze["outward_actions_sha256"]["canary"], "decided_by": "dry-run-synthetic",
                "recorded_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    (clone / approval_rel).write_text(json.dumps(approval, indent=2) + "\n")
    git(clone, "add", approval_rel)
    git(clone, "commit", "-qm", "dry-run: synthetic canary approval (decided_by dry-run-synthetic)")
    return {"clone": clone, "phase": phase, "freeze_path": freeze_path, "freeze": freeze, "freeze_plan": freeze_plan,
            "approval": clone / approval_rel}


def scrubbed_env(work: Path, extra: dict | None = None) -> dict:
    bin_dir = work / "recorder-bin"
    bin_dir.mkdir(exist_ok=True)
    marker = work / "network-commands"
    for name in ("gh", "curl", "wget"):
        stub = bin_dir / name
        stub.write_text(f'#!/bin/sh\nprintf "{name} %s\\n" "$*" >> "{marker}"\nexit 97\n')
        stub.chmod(0o755)
    env = {key: value for key, value in os.environ.items()
           if key not in {"GH_TOKEN", "GITHUB_TOKEN"} and not key.startswith("SIGRA_CANARY_TEST_")}
    (work / "home").mkdir(exist_ok=True)
    (work / "tmp").mkdir(exist_ok=True)
    env.update({"PATH": f"{bin_dir}:{env['PATH']}", "HOME": str(work / "home"), "TMPDIR": str(work / "tmp"),
                "PYTHONDONTWRITEBYTECODE": "1", "GIT_TERMINAL_PROMPT": "0"})
    env.update(extra or {})
    return env


SLEEP_RECORDER = """#!/bin/sh
# 253-108 recording sleep: logs the requested duration and the category of the last charged request (so a wait is
# classified by what preceded it, not by its value), then sleeps only the scaled fraction.
last=$(jq -r '(.transactions // [])[-1].category // "none"' {ledger} 2>/dev/null) || last=none
printf '%s %s\\n' "$1" "${{last:-none}}" >> {log}
exec /bin/sleep "$(awk -v d="$1" -v s={scale} 'BEGIN {{ printf "%.3f", d * s }}')"
"""


SITECUSTOMIZE_CHAIN = '''# 253-108 runner: the shim's sitecustomize shadows the interpreter's own (Homebrew's adds its site-packages, where
# PyYAML lives), so load the next sitecustomize on sys.path first. Paths only; no network behaviour changes.
import importlib.util as _chain_util
import os as _chain_os
import sys as _chain_sys
_chain_here = _chain_os.path.dirname(_chain_os.path.abspath(__file__))
for _chain_entry in list(_chain_sys.path):
    _chain_dir = _chain_os.path.abspath(_chain_entry or ".")
    _chain_file = _chain_os.path.join(_chain_dir, "sitecustomize.py")
    if _chain_dir != _chain_here and _chain_os.path.isfile(_chain_file):
        _chain_spec = _chain_util.spec_from_file_location("_sigra_chained_sitecustomize", _chain_file)
        _chain_spec.loader.exec_module(_chain_util.module_from_spec(_chain_spec))
        break
'''


def chain_interpreter_sitecustomize(path: Path) -> None:
    """Prepend the chain to the shim's generated sitecustomize (a work-dir copy; the shim source is unchanged)."""
    path.write_text(SITECUSTOMIZE_CHAIN + path.read_text())


def install_recording_sleep(work: Path, ledger: Path, scale: float) -> Path:
    log = work / "requested-sleeps.log"
    stub = work / "recorder-bin" / "sleep"
    stub.parent.mkdir(exist_ok=True)
    quote = lambda value: "'" + str(value).replace("'", "'\\''") + "'"  # noqa: E731
    stub.write_text(SLEEP_RECORDER.format(ledger=quote(ledger), log=quote(log), scale=quote(scale)))
    stub.chmod(0o755)
    return log


def requested_sleeps(log: Path | None) -> dict:
    """Each requested wait, grouped by the request that preceded it: dispatch (discovery) or a watch read (poll)."""
    result = {"discovery": [], "poll": [], "other": []}
    if log is None or not log.exists():
        return result
    for line in log.read_text().splitlines():
        duration, _, last = line.partition(" ")
        value = float(duration)
        value = int(value) if value.is_integer() else value
        group = {"dispatch": "discovery", "pre_watch_rate": "poll", "terminal_polls": "poll"}.get(last.strip(), "other")
        result[group].append(value if group != "other" else {"seconds": value, "after": last.strip()})
    return result


def category_counts(ledger: dict) -> dict:
    counts: dict = {}
    for row in ledger.get("transactions", []):
        counts[row.get("category")] = counts.get(row.get("category"), 0) + 1
    return counts


def dry_run(args) -> dict:
    started = time.monotonic()
    # Resolved, so paths handed to the driver match its pwd -P root (macOS /var is a symlink to /private/var).
    work = Path(tempfile.mkdtemp(prefix="sigra-253-dryrun-")).resolve()
    live = bool(getattr(args, "live_policy", False))
    summary = {"status": "failed", "synthetic": True, "freeze_plan": None, "scenarios": [], "verifier": {"status": "pending"},
               "requests_by_category": {}, "requests_total": 0, "journal_requests": 0, "stop": None,
               "mode": "live-policy" if live else "hermetic", "live_hops": [],
               "authorization": {"api_with": 0, "api_without": 0, "blob_with": 0, "results_receiver_with": 0},
               "requested_sleeps": requested_sleeps(None), "shim_refusals": [], "shim_connect_hosts": [], "violations": []}
    if getattr(args, "transport_from", None):
        summary["transport_from"] = args.transport_from
    if args.driver_from:
        summary["driver_from"] = args.driver_from
    if args.driver_patch:
        summary["driver_patch"] = json.loads(Path(args.driver_patch).read_text()).get("name")
    args.overlaid = []
    server = None
    try:
        prepared = prepare_clone(args, work)
        clone, phase, freeze, freeze_path = prepared["clone"], prepared["phase"], prepared["freeze"], prepared["freeze_path"]
        summary["freeze_plan"] = prepared["freeze_plan"]
        if args.overlay_worktree:
            summary["overlaid_worktree_paths"] = args.overlaid
        evidence = phase / "253-DRYRUN-CANARY-EVIDENCE.json"
        ledger = phase / "253-DRYRUN-CANARY-REQUESTS.json"
        receipt = phase / "253-DRYRUN-CANARY-PUBLICATION-RECEIPT.json"
        journal = work / "server-journal.json"
        journal.write_text("[]")
        verifier_module = load_module("ci_hosted_gate_verify_for_dryrun_fake", clone / "scripts/ci/ci-hosted-gate-verify.py")
        polls = dict(DEFAULT_POLLS)
        for item in args.polls or []:
            name, _, count = item.partition("=")
            polls[name] = int(count)
        visibility = args.visibility_delay
        if visibility is None:
            # Live-policy: below the scaled 20-second discovery wait, so the one charged listing finds the run.
            visibility = 0.05 if live else 3.0
        server, thread, cert = start_fake(work, clone, ledger, journal, freeze["identity"]["server_parent_sha"],
                                          verifier_module, visibility, polls, args.seed_legacy_refs, live=live,
                                          seed_refs=seeded_scoped_refs(args) or None)
        server.faults = set(args.fault or [])
        for item in args.inject or []:
            key, _, status = item.rpartition("=")
            server.inject[key] = (int(status), b'{"message":"injected dry-run refusal"}')
        port = server.server_address[1]
        manifest = freeze["bound_documents"]["publication_manifest"]
        allocation = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": f"253-101-dry-run-{os.getpid()}",
                      "source_sha256": sha256_hex(freeze_path.read_bytes()), "max_requests": 117, "max_elapsed_seconds": 3600,
                      "max_response_bytes": 4 * 1024 * 1024, "max_pages": 3, "max_hops": 2, "repository": REPO,
                      "download_hosts": [], "mode": "hermetic-test", "allocation_kind": "canary",
                      "category_limits": freeze["categories"]["canary"],
                      "bound_documents": [{"path": str(freeze_path), "sha256": sha256_hex(freeze_path.read_bytes())},
                                          {"path": str(clone / manifest["path"]), "sha256": manifest["sha256"]},
                                          {"path": str(clone / FIXTURE_REL), "sha256": sha256_hex((clone / FIXTURE_REL).read_bytes())}],
                      "test_origin": f"https://localhost:{port}", "test_ca_file": str(cert)}
        sleep_log = None
        if live:
            # 253-108: the live canary allocation shape (as 253-104's), trusted hosts from ALLOCATION-R8, no test fields.
            # 253-128: plus results-receiver, GitHub's run-log host (admitted by the transport only as run_logs hop 1).
            del allocation["test_origin"], allocation["test_ca_file"]
            allocation.update({"window_id": f"{LIVE_WINDOW_PREFIX}{os.getpid()}", "max_pages": 10, "mode": "live",
                               "download_hosts": list(json.loads((ROOT / R8_ALLOCATION_REL).read_text())["download_hosts"])
                               + [RESULTS_RECEIVER_HOST]})
            shim = load_module("ci_live_policy_shim_for_dryrun", clone / SHIM_REL)
            connect_log = work / "shim-connect.log"
            refusal_log = shim.refusal_log_for(connect_log)
            shim_env = shim.prepare(work / "live-policy-shim", {API_HOST: port, BLOB_HOST: port, PIPELINES_HOST: port,
                                                                RESULTS_RECEIVER_HOST: port}, cert, connect_log)
            chain_interpreter_sitecustomize(Path(shim_env["PYTHONPATH"]) / "sitecustomize.py")
            sleep_log = install_recording_sleep(work, ledger, args.sleep_scale)
            env = scrubbed_env(work, {**shim_env, "GH_TOKEN": LIVE_TOKEN})
        allocation_path = work / ("live-policy-canary-allocation.json" if live else "hermetic-canary-allocation.json")
        allocation_path.write_text(json.dumps(allocation, indent=2) + "\n")
        summary["allocation"] = {key: allocation[key] for key in ("mode", "allocation_kind", "window_id", "download_hosts",
                                                                  "max_requests", "max_pages", "max_hops")}
        summary["allocation"]["fields"] = sorted(allocation)
        if not live:
            overrides = {"SIGRA_CANARY_TEST_POLL_SECONDS": str(0.05 if args.poll_seconds is None else args.poll_seconds),
                         "SIGRA_CANARY_TEST_SERVER_JOURNAL": str(journal),
                         "SIGRA_CANARY_TEST_DISCOVERY_WAIT_SECONDS": str(4.0 if args.discovery_wait is None else args.discovery_wait)}
            env = scrubbed_env(work, overrides)
        summary["test_overrides"] = sorted(key for key in env if key.startswith("SIGRA_CANARY_TEST_"))
        common = ["--revision-freeze", str(freeze_path), "--action-approval", str(prepared["approval"]),
                  "--http-allocation", str(allocation_path), "--requests", str(ledger), "--evidence", str(evidence),
                  "--publication-receipt", str(receipt)]
        steps = [("publish-only", ["--publish-only"]), ("full-pass", ["--scenario", "full-pass"])]
        if args.stop_after != "full-pass":
            steps.append(("remaining", ["--remaining-scenarios"]))
        invocations = []
        failed = None

        def ledger_rows():
            return json.loads(ledger.read_text()).get("transactions", []) if ledger.exists() else []

        def invoke(label, mode):
            before = len(ledger_rows())
            result = subprocess.run(["bash", str(clone / DRIVER_REL), *mode, *common], cwd=clone, env=env,
                                    capture_output=True, text=True, timeout=args.timeout)
            added = ledger_rows()[before:]
            record = {"mode": label, "exit": result.returncode, "stop": stop_line(result.stderr) if result.returncode else None,
                      "requests": len(added), "requests_by_category": category_counts({"transactions": added}),
                      "retained_preflight_reverified": "retained preflight re-verified" in result.stdout}
            if args.verbose:
                sys.stderr.write(f"--- {label} exit {result.returncode}\n{result.stdout}{result.stderr}")
            return result, record

        for label, mode in steps:
            result, record = invoke(label, mode)
            invocations.append(record)
            if result.returncode:
                failed = (label, result.returncode, stop_line(result.stderr))
                if args.reenter:
                    _, again = invoke(label + " (re-entry)", mode)
                    summary["reentry"] = again
                break
        summary["invocations"] = invocations
        ledger_value = json.loads(ledger.read_text()) if ledger.exists() else {"transactions": []}
        summary["requests_by_category"] = category_counts(ledger_value)
        routes: dict = {}
        for row in ledger_value.get("transactions", []):
            routes[row.get("route_id")] = routes.get(row.get("route_id"), 0) + 1
        summary["requests_by_route"] = routes
        summary["live_hops"] = [{"route": row.get("route_id"), "hop_ordinal": row.get("hop_ordinal"), "host": row.get("host"),
                                 "status": row.get("actual_status"), "category": row.get("category")}
                                for row in ledger_value.get("transactions", []) if (row.get("hop_ordinal") or 0) >= 1]
        summary["authorization"] = dict(server.authorization)
        summary["requested_sleeps"] = requested_sleeps(sleep_log)
        if live:
            summary["shim_refusals"] = shim.read_log(refusal_log)
            summary["shim_connect_hosts"] = sorted({entry.get("host") for entry in shim.read_log(connect_log)})
        if receipt.exists():
            receipt_value = json.loads(receipt.read_text())
            origin = receipt_value.get("origin") or {}
            summary["publication"] = {"status": receipt_value.get("status"), "origin_kind": origin.get("kind"),
                                      "origin_window_id": origin.get("window_id"),
                                      "verifier_dryrun_window": verifier_module.dryrun_window(receipt_value)}
        created = git(clone, "ls-files", "--others", "--exclude-standard", "--", PHASE_REL).splitlines()
        summary["preflight_copies"] = sorted(Path(rel).name for rel in created if "PREFLIGHT" in rel)
        summary["requests_total"] = len(ledger_value.get("transactions", []))
        summary["journal_requests"] = len(server.journal)
        summary["first_poll_delays"] = [record["first_poll_delay"] for _, record in sorted(server.runs.items())
                                        if "first_poll_delay" in record]
        evidence_value = json.loads(evidence.read_text()) if evidence.exists() else {}
        summary["evidence_status"] = evidence_value.get("status")
        summary["evidence_has_preflight"] = bool(evidence_value.get("preflight"))
        summary["evidence_diagnostics"] = evidence_value.get("diagnostics")
        if "publication" in summary:
            summary["publication"]["fixture_ref_state"] = (evidence_value.get("expected") or {}).get("fixture_ref_state")
        verify = clone / "scripts/ci/ci-hosted-gate-verify.py"
        for name in SCENARIOS:
            if name in (evidence_value.get("scenarios") or {}):
                check = subprocess.run(["python3", str(verify), "--mode", "canary", "--evidence", str(evidence), "--scenario", name],
                                       cwd=clone, env=env, capture_output=True, text=True)
                if check.returncode == 0 and json.loads(check.stdout).get("synthetic") is True:
                    summary["scenarios"].append(name)
        if failed is None and args.stop_after != "full-pass":
            matrix = subprocess.run(["python3", str(verify), "--mode", "canary", "--evidence", str(evidence), "--scenario", "matrix"],
                                    cwd=clone, env=env, capture_output=True, text=True)
            ok = matrix.returncode == 0 and json.loads(matrix.stdout).get("synthetic") is True
            summary["verifier"] = {"status": "passed" if ok else "failed",
                                   "detail": None if ok else (matrix.stderr.strip() or matrix.stdout.strip())[-400:]}
        elif failed is not None:
            summary["verifier"] = {"status": "failed" if summary["scenarios"] or evidence_value.get("scenarios") else "pending"}
        limits = freeze["categories"]["canary"]
        over = {key: value for key, value in summary["requests_by_category"].items() if value > limits.get(key, 0)}
        problems = []
        if failed is not None:
            summary["stop"] = failed[2]
            problems.append(f"{failed[0]} exited {failed[1]}")
        if over:
            problems.append(f"categories above the frozen table: {over}")
        if summary["requests_by_category"].get("infrastructure_retry"):
            problems.append("infrastructure_retry was used")
        if summary["journal_requests"] != summary["requests_total"]:
            problems.append("server journal and ledger counts differ")
        summary["violations"] = list(server.violations)
        summary["verifier_job_model"] = "verify_sources" if live else "scenario-set"
        verifier_job = dict(server.verifier_job) if server.verifier_job else None
        if verifier_job is not None:
            dispatches = [row for row in ledger_value.get("transactions", []) if row.get("route_id") == "dispatch"]
            if dispatches:
                row = dispatches[-1]
                verifier_job["dispatch"] = {key: row.get(key) for key in ("sequence", "actual_status", "input_key_count",
                                                                          "input_unicode_scalars", "input_utf8_bytes")}
            verifier_job["matrix_payload_limit"] = PUBLISHER.MATRIX_PAYLOAD_LIMIT
        summary["verifier_job"] = verifier_job
        if args.stop_after != "full-pass" and failed is None:
            wanted = "sources_verified" if live else "scenario_set_complete"
            if (verifier_job or {}).get("result") != wanted:
                problems.append(f"the modeled verifier job did not report {wanted}: {verifier_job}")
        # 253-117: every run object the fake served must have GitHub's recorded shape.
        summary["response_shape"] = shape = response_shape(server.journal, server.runs, load_reference(),
                                                           log_reference=load_log_reference(), live=live, local_port=port,
                                                           cancelled_reference=load_cancelled_reference())
        if not shape["ok"]:
            problems.append(f"response_shape: {shape['mismatch_count']} served object(s) differ from GitHub's recorded "
                            f"shape: {shape['mismatches'][:3]}")
        if shape["runs_checked"] < 1:
            problems.append("response_shape: no served run was checked")
        if args.stop_after != "full-pass" and not shape["verifier_run_checked"]:
            problems.append("response_shape: the separate verifier run was not checked")
        if args.stop_after != "full-pass" and not shape["run_logs_checked"]:
            problems.append("response_shape: no run_logs chain was served and checked against GitHub's recorded chain")
        if args.stop_after != "full-pass" and shape["cancelled_run_checked"] is not True and (
                shape["cancelled_run_checked"] != "unavailable"):
            problems.append("response_shape: the cancelled run and its jobs were not checked against GitHub's recorded ones")
        if summary["authorization"].get("results_receiver_with"):
            problems.append(f"Authorization reached results-receiver {summary['authorization']['results_receiver_with']} time(s)")
        if server.violations:
            problems.append("fake GitHub violations: " + "; ".join(server.violations[:5]))
        if summary["shim_refusals"]:
            problems.append(f"the live-policy shim refused a real network destination: {summary['shim_refusals'][:3]}")
        if summary["requested_sleeps"]["other"]:
            problems.append(f"a sleep followed an unexpected request: {summary['requested_sleeps']['other'][:3]}")
        if live and summary["test_overrides"]:
            problems.append(f"a test-only override was set in live-policy mode: {summary['test_overrides']}")
        network = work / "network-commands"
        if network.exists():
            problems.append("a network command was invoked: " + network.read_text()[:200])
        if args.seed_legacy_refs:
            changed = {name: server.refs.get(name) for name, sha in LEGACY_REFS.items() if server.refs.get(name) != sha}
            summary["seeded_refs_changed"] = bool(changed)
            if changed:
                problems.append(f"a seeded legacy ref changed: {changed}")
        if getattr(args, "seed_r8_refs", False):
            changed = {name: server.refs.get(name) for name, sha in R8_REFS.items() if server.refs.get(name) != sha}
            summary["seeded_r8_refs_changed"] = bool(changed)
            if changed:
                problems.append(f"a seeded r8 ref changed: {changed}")
        if getattr(args, "seed_r9_refs", False):
            changed = {name: server.refs.get(name) for name, sha in R9_REFS.items() if server.refs.get(name) != sha}
            summary["seeded_r9_refs_changed"] = bool(changed)
            if changed:
                problems.append(f"a seeded r9 ref changed: {changed}")
        expected = ["full-pass"] if args.stop_after == "full-pass" else list(SCENARIOS)
        if failed is None and summary["scenarios"] != expected:
            problems.append(f"verifier accepted {summary['scenarios']}, expected {expected}")
        if failed is None and args.stop_after != "full-pass" and summary["verifier"]["status"] != "passed":
            problems.append("the verifier's --mode canary --scenario matrix did not pass")
        summary["problems"] = problems
        summary["status"] = "passed" if not problems else "failed"
    except (DryRunError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        summary["stop"] = summary["stop"] or f"dry-run setup: {error}"
        summary.setdefault("problems", []).append(str(error))
    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        summary["modeled_elapsed_seconds"] = round(time.monotonic() - started, 1)
        if args.keep:
            summary["work_dir"] = str(work)
        else:
            shutil.rmtree(work, ignore_errors=True)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--stop-after", choices=("full-pass", "all"), default="all",
                        help="end after this scenario's receipt is verified (default: the whole sequence)")
    parser.add_argument("--driver-from", help="substitute the clone's ci-gate-canary.sh with this commit's blob")
    parser.add_argument("--driver-patch", help="JSON {name, old, new}: an exactly-once reintroduction patch for the driver")
    parser.add_argument("--seed-legacy-refs", action="store_true",
                        help="pre-seed the two refs 253-97 left on GitHub; they must not change")
    parser.add_argument("--seed-r8-refs", action="store_true",
                        help="pre-seed the two r8 refs 253-104 left on GitHub; they must not change")
    parser.add_argument("--seed-r9-refs", action="store_true",
                        help="pre-seed the two r9 refs 253-113 left on GitHub; they must not change (combinable with --seed-r8-refs)")
    parser.add_argument("--ref-pair", choices=sorted(PUBLISHER.REF_PAIRS),
                        help="forwarded to --build-freeze for the derived synthetic freeze: one of the publisher's REF_PAIRS "
                             f"({', '.join(sorted(PUBLISHER.REF_PAIRS))}; the publisher's default is "
                             f"{PUBLISHER.DEFAULT_REF_PAIR}); ignored with --revision-freeze")
    parser.add_argument("--revision-freeze", help="use this committed freeze (repository-relative) instead of deriving one")
    parser.add_argument("--server-parent", help="server parent for the derived synthetic freeze (default: the R7 freeze's)")
    parser.add_argument("--visibility-delay", type=float, default=None,
                        help="modeled seconds before a dispatched run is listable (default 3; 0.05 with --live-policy)")
    parser.add_argument("--discovery-wait", type=float, default=None,
                        help="hermetic-only SIGRA_CANARY_TEST_DISCOVERY_WAIT_SECONDS (default 4; live is 20)")
    parser.add_argument("--poll-seconds", type=float, default=None,
                        help="hermetic-only SIGRA_CANARY_TEST_POLL_SECONDS (default 0.05)")
    parser.add_argument("--transport-from", help="substitute the clone's ci-hosted-transport.py with this commit's blob")
    parser.add_argument("--live-policy", action="store_true",
                        help="253-108: a live canary allocation through the live-policy shim (see the module docstring)")
    parser.add_argument("--sleep-scale", type=float, default=0.01,
                        help="live-policy: fraction of each requested driver sleep actually slept (default 0.01)")
    parser.add_argument("--polls", action="append", help="SCENARIO=N modeled polls to completion (repeatable)")
    parser.add_argument("--inject", action="append", help="'METHOD /path=STATUS': answer that request once with STATUS")
    parser.add_argument("--reenter", action="store_true", help="after a failed driver mode, run it once more (halt guard check)")
    parser.add_argument("--fault", action="append",
                        choices=("artifact-digest", "run-shape-bare-name", "run-logs-legacy-blob-redirect",
                                 "cancelled-shape-drift"),
                        help="modeled server fault (artifact-digest: listed digest differs from the served bytes; "
                             "run-shape-bare-name: every run is served in the pre-253-117 shape, bare name and path@ref; "
                             "run-logs-legacy-blob-redirect: failed logs take the pre-R11 blob-host redirect; "
                             "cancelled-shape-drift: the cancelled run's cancelled job reports failure)")
    parser.add_argument("--timeout", type=int, default=900, help="seconds allowed per driver invocation")
    parser.add_argument("--overlay-worktree", action="store_true",
                        help="copy the checkout's uncommitted scripts/ci edits into the clone (test aid; recorded)")
    parser.add_argument("--keep", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--verbose", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.live_policy and (args.discovery_wait is not None or args.poll_seconds is not None):
        parser.error("--discovery-wait and --poll-seconds are hermetic-only; live-policy runs the live 20/60-second waits")
    if args.sleep_scale < 0:
        parser.error("--sleep-scale must be non-negative")
    for key in ("GH_TOKEN", "GITHUB_TOKEN"):
        os.environ.pop(key, None)
    summary = dry_run(args)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
