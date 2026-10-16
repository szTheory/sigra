#!/usr/bin/env bash
# Phase 253 plan 42: subprocess + local-HTTPS contracts for ci-pr-proof.sh and the independent PR verifier.
#
# Everything here is SYNTHETIC: a temporary git repository, a local TLS "GitHub" with a real git-backed object
# store, and node-generated producer artifacts. No GitHub request is made and no result is live acceptance;
# evidence produced here is labeled synthetic and the verifier refuses to treat it as live.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
for tool in python3 node openssl git; do
  command -v "$tool" >/dev/null || { echo "ci-pr-proof.test: FAIL: $tool is required" >&2; exit 1; }
done
export SIGRA_TEST_ROOT="$ROOT" PYTHONDONTWRITEBYTECODE=1
unset GH_TOKEN GITHUB_TOKEN

exec python3 - <<'PYEOF'
import base64
import copy
import hashlib
import http.server
import importlib.util
import io
import json
import os
import pathlib
import re
import shutil
import ssl
import stat
import subprocess
import sys
import tempfile
import threading
import unicodedata
import unittest
import zipfile
from urllib.parse import parse_qs, urlsplit

ROOT = pathlib.Path(os.environ["SIGRA_TEST_ROOT"])
PROOF = ROOT / "scripts/ci/ci-pr-proof.sh"
SEAMS = ("non_admin_smoke", "admin_behavior", "admin_checkpoints", "design_gallery", "demo_showcase")
NAMES = ("Library tests", "Example unit smoke (ExUnit + ConnTest)", "Install smoke (fresh phx.new + sigra.install)",
         "Example HTTP smoke (boot + curl critical routes)", "Example Playwright smoke (full lifecycle)")
DOCS_PATH = "guides/reference/phase253-docs-only-proof.md"


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


pubtest = load(ROOT / "scripts/ci/ci-git-publication.test.py", "pubtest")
verifier = load(ROOT / "scripts/ci/ci-hosted-gate-verify.py", "gate_verify")
transport = load(ROOT / "scripts/ci/ci-hosted-transport.py", "transport")
sha = lambda data: hashlib.sha256(data).hexdigest()
enc = lambda data: base64.b64encode(data).decode("ascii")

GENERATOR = r"""
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const [, , repoRoot, workflowFile, identityFile, outDir, docsFlag] = process.argv;
const { bodyPolicy } = await import(pathToFileURL(join(repoRoot, 'scripts/ci/ci-browser-records.mjs')).href);
const identity = JSON.parse(readFileSync(identityFile, 'utf8'));
const workflowText = readFileSync(workflowFile, 'utf8');
const workflowHash = createHash('sha256').update(readFileSync(workflowFile)).digest('hex');
const docsOnly = docsFlag === 'docs';
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
function report(specs, projects) {
  const suites = specs.map((file, index) => ({ title: file, file, specs: [{ id: `spec-${index}`, title: `selected case ${index}`, file,
    tests: projects.filter((project) => project !== 'mobile' || !/passkeys-hooks|passkey-login|passkey-options/.test(file)).map((project) => ({
      projectId: project, projectName: project, expectedStatus: 'passed', status: 'expected',
      results: [{ retry: 0, status: 'passed', duration: 1, startTime: '2026-10-13T00:00:00Z' }] })) }] }));
  const count = suites.reduce((sum, suite) => sum + suite.specs[0].tests.length, 0);
  return { config: { projects: projects.map((name) => ({ id: name, name })) }, suites, errors: [],
    stats: { expected: count, unexpected: 0, flaky: 0, skipped: 0, startTime: '2026-10-13T00:00:00Z', duration: 10 } };
}
for (const seam of ['non_admin_smoke', 'admin_behavior', 'admin_checkpoints', 'design_gallery', 'demo_showcase']) {
  const target = join(outDir, `browser-execution-${seam}-${identity.run_id}-${identity.run_attempt}`);
  mkdirSync(target, { recursive: true });
  const record = { schema_version: 'sigra.browser-execution-record/v1', ...identity, workflow_file_sha256: workflowHash, seam, selected_steps: [] };
  for (const policy of bodyPolicy(seam, identity.event, workflowText)) {
    const outcome = docsOnly ? 'skipped' : 'success';
    const step = { id: policy.id, outcome, conclusion: outcome, reports: [] };
    if (!docsOnly) for (const invocation of policy.invocations) {
      const native = report(invocation.specs, invocation.projects);
      if (seam === 'design_gallery') {
        const setup = report(['admin-design.setup.ts'], invocation.projects.map((project) => project.replace('admin-design-', 'admin-design-setup-')));
        native.config.projects.push(...setup.config.projects);
        native.suites.push(...setup.suites);
        native.stats.expected += setup.stats.expected;
      }
      const selection = structuredClone(native);
      for (const suite of selection.suites) for (const spec of suite.specs) for (const selected of spec.tests) selected.results = [];
      writeFileSync(join(target, invocation.path), JSON.stringify(native));
      writeFileSync(join(target, invocation.selection_path), JSON.stringify(selection));
      step.reports.push({ path: invocation.path, selection_path: invocation.selection_path,
        sha256: hash(readFileSync(join(target, invocation.path))), selection_sha256: hash(readFileSync(join(target, invocation.selection_path))) });
    }
    record.selected_steps.push(step);
  }
  writeFileSync(join(target, 'execution-record.json'), JSON.stringify(record));
}
"""


def run(*args, **kwargs):
    return subprocess.run(list(map(str, args)), capture_output=True, text=True, **kwargs)


def git(repo, *args, data=None):
    return subprocess.check_output(["git", "-C", str(repo), *args], input=data)


def make_zip(members, **fields):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name, data in members:
            bundle.writestr(name, data)
    return buffer.getvalue()


class PRHandler(pubtest.ObjectServer):
    """Local HTTPS GitHub model: git object routes from the real publication server plus PR/run/artifact routes."""

    def _emit(self, status, body, extra=(), content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-GitHub-Request-Id", "local-pr-fixture")
        for name, value in extra:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)
        request_body = self.server.last_body
        self.server.journal.append({"method": self.command, "path": self.path, "status": status, "charged": self.server.ledger_pending(),
                                    "body_sha256": sha(body), "request_body_sha256": sha(request_body) if request_body else None,
                                    "request_body_bytes": len(request_body), "authorization": self.headers.get("Authorization")})

    def _reply(self, status, value):
        self._emit(status, json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode())

    def do_GET(self):  # noqa: N802
        self._first()
        self.server.last_body = b""
        model, base = self.server.model, "/repos/szTheory/sigra"
        parsed = urlsplit(self.path)
        route, query = parsed.path, parse_qs(parsed.query)
        flags = self.server.flags
        if route == "/rate_limit":
            remaining = "250" if flags.get("core_floor") else "4000"
            return self._emit(200, b'{"resources":{"core":{"limit":5000}}}', [("X-RateLimit-Resource", "core"), ("X-RateLimit-Remaining", remaining)])
        if route == base + "/rules/branches/main":
            rules = [{"type": "required_status_checks", "parameters": {"required_status_checks": [
                {"context": name, "integration_id": 15368} for name in NAMES]}}]
            return self._reply(200, rules)
        if route == base + "/branches/main/protection":
            return self._reply(404, {"message": "Branch not protected"})
        if route == f"{base}/actions/workflows/259268962":
            return self._reply(200, {"id": 259268962, "path": ".github/workflows/ci.yml", "name": "CI", "state": "active"})
        if route.startswith(base + "/pulls/"):
            pull = model["pulls"].get(int(route.rsplit("/", 1)[1]))
            if not pull:
                return self._reply(404, {"message": "Not Found"})
            view = copy.deepcopy(pull)
            view["merge_commit_sha"] = model["families"][view["number"]]["merge"]
            return self._reply(200, view)
        if route.startswith(base + "/compare/"):
            low, high = route.removeprefix(base + "/compare/").split("...")
            names = git(model["repo"], "diff", "--name-only", low, high).decode().split()
            ahead = int(git(model["repo"], "rev-list", "--count", f"{low}..{high}"))
            behind = int(git(model["repo"], "rev-list", "--count", f"{high}..{low}"))
            return self._reply(200, {"status": "ahead", "ahead_by": ahead, "behind_by": behind, "total_commits": ahead,
                                     "files": [{"filename": name, "status": "added"} for name in names]})
        if route.startswith(base + "/contents/"):
            path, ref = route.removeprefix(base + "/contents/"), query["ref"][0]
            commit = next((family["commit"] for family in model["families"].values() if family["merge"] == ref), None)
            if commit is None:
                return self._reply(404, {"message": "Not Found"})
            data = git(model["repo"], "show", f"{commit}:{path}")
            return self._reply(200, {"type": "file", "encoding": "base64", "path": path, "size": len(data),
                                     "sha": git(model["repo"], "rev-parse", f"{commit}:{path}").decode().strip(), "content": enc(data)})
        if route == f"{base}/actions/workflows/259268962/runs":
            head = query["head_sha"][0]
            family = next((f for f in model["families"].values() if f["head"] == head), None)
            model["discovery"][head] = model["discovery"].get(head, 0) + 1
            visible = family and family.get("created") and model["discovery"][head] >= 2
            runs = [family["run"](0)] if visible else []
            return self._reply(200, {"total_count": len(runs), "workflow_runs": runs})
        if route.startswith(base + "/actions/runs/"):
            tail = route.removeprefix(base + "/actions/runs/").split("/")
            family = next((f for f in model["families"].values() if str(f["run_id"]) == tail[0]), None)
            if family is None:
                return self._reply(404, {"message": "Not Found"})
            if len(tail) == 1:
                family["polls"] = family.get("polls", 0) + 1
                done = family["polls"] >= 3 and not flags.get("never_finish")
                return self._reply(200, family["run"](family["polls"] if done else 0))
            if tail[1] == "attempts":
                jobs = family["jobs"]
                return self._reply(200, {"total_count": len(jobs), "jobs": jobs})
            if tail[1] == "artifacts":
                artifacts = family["artifacts"]
                return self._reply(200, {"total_count": len(artifacts), "artifacts": artifacts})
        if route.startswith(base + "/commits/") and route.endswith("/check-runs"):
            head = route.removeprefix(base + "/commits/").split("/")[0]
            family = next((f for f in model["families"].values() if f["head"] == head), None)
            return self._reply(200, {"total_count": len(family["checks"]), "check_runs": family["checks"]}) if family else self._reply(404, {})
        if route.startswith(base + "/actions/artifacts/") and route.endswith("/zip"):
            artifact_id = route.removeprefix(base + "/actions/artifacts/").split("/")[0]
            location = f"https://localhost:{self.server.server_address[1]}/blob/{artifact_id}?sig=fixture-secret"
            return self._emit(302, b"", [("Location", location)])
        if route.startswith("/blob/"):
            return self._emit(200, model["zips"][int(route.rsplit("/", 1)[1])], content_type="application/zip")
        return super().do_GET()

    def do_POST(self):  # noqa: N802
        self._first()
        if urlsplit(self.path).path == "/repos/szTheory/sigra/pulls":
            value = self._read()
            if self.server.flags.get("refuse_pr_create"):
                return self._reply(422, {"message": "Validation Failed"})
            model = self.server.model
            number = model["numbers"].pop(0)
            head_sha = self.server.refs.get(value["head"])
            base_sha = self.server.parent_sha if value["base"] == "main" else self.server.refs.get(value["base"])
            pull = {"number": number, "state": "open", "draft": True, "merged": False, "merge_commit_sha": None,
                    "head": {"ref": value["head"], "sha": head_sha, "repo": {"full_name": "szTheory/sigra"}},
                    "base": {"ref": value["base"], "sha": base_sha, "repo": {"full_name": "szTheory/sigra"}}}
            model["pulls"][number] = pull
            model["families"][number]["created"] = True
            return self._reply(201, pull)
        return super().do_POST()


class World:
    """One complete hermetic Phase253 PR universe: temp git repo, published objects, TLS server, freeze and allocation."""

    # 253-109 hooks: LiveWorld overrides these; the hermetic defaults leave every existing universe unchanged.
    handler = PRHandler
    poll_interval = 0

    def tls_san(self):
        return "subjectAltName=DNS:localhost"

    def after_server_start(self):
        """Hook: runs once the local TLS server listens and before the publication request."""

    def adapt_allocation(self, allocation, purpose):
        """Hook: the hermetic universe uses its allocations as built."""
        return allocation

    def subprocess_env(self):
        """Hook: None inherits this process's environment (GH_TOKEN/GITHUB_TOKEN are unset by the wrapper)."""
        return None

    def __init__(self, test, flags=None, tag="world", mutate_section=None, ref_pair=None, seed_legacy_refs=False, seed_r8_refs=False,
                 seed_r9_refs=False):
        self.test = test
        self.mutate_section = mutate_section
        self.ref_pair = ref_pair  # 253-102: None publishes without a canary freeze (legacy pair); "r8"/"legacy" publish under a freeze
        self.seed_legacy_refs = seed_legacy_refs
        self.seed_r8_refs = seed_r8_refs  # 253-111: the r8 refs 253-104 left on GitHub, seeded at a foreign SHA
        self.seed_r9_refs = seed_r9_refs  # 253-119: the r9 refs 253-113 left on GitHub, seeded at a foreign SHA
        self.canary_freeze_path = None
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix=f"sigra-pr-proof-{tag}-"))
        test.addCleanup(shutil.rmtree, self.dir, True)
        self.flags = dict(flags or {})
        self.build()

    def build(self):
        d = self.dir
        self.repo = d / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.name", "Fixture")
        git(self.repo, "config", "user.email", "fixture@example.test")
        (self.repo / ".github/workflows").mkdir(parents=True)
        (self.repo / ".github/workflows/ci.yml").write_bytes((ROOT / ".github/workflows/ci.yml").read_bytes())
        (self.repo / "app.txt").write_text("base\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "parent")
        self.parent = git(self.repo, "rev-parse", "HEAD").decode().strip()
        (self.repo / "app.txt").write_text("changed Δ\n")
        (self.repo / "lib").mkdir()
        (self.repo / "lib/feature.ex").write_text("defmodule Feature do\nend\n")
        for rel in pubtest.HELPER_COPIES:
            (self.repo / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / rel).write_bytes((ROOT / rel).read_bytes())
        for rel in pubtest.OBSERVERS:
            (self.repo / rel).write_bytes((ROOT / rel).read_bytes())
        for rel in pubtest.HELPER_DUMMIES:
            (self.repo / rel).write_text(f"# placeholder for {rel}\n")
        phase = self.repo / pubtest.PHASE_REL
        phase.mkdir(parents=True, exist_ok=True)
        (phase / "253-LOAD-RECOVERY-CANARY-WORKFLOW.yml").write_text(pubtest.FIXTURE_TEXT)
        for name in ("ACCEPTANCE-EVIDENCE", "TARGET-DISPOSITION", "TARGET-DISPOSITION-APPROVAL"):
            (phase / f"253-LOAD-RECOVERY-{name}.json").write_text(json.dumps({"fixture": name}) + "\n")
        git(self.repo, "add", "app.txt", "lib", "scripts", ".planning", ".github")
        git(self.repo, "commit", "-qm", "candidate")
        self.source = git(self.repo, "rev-parse", "HEAD").decode().strip()
        self.manifest_path = d / "manifest.json"
        prepared = run("python3", ROOT / "scripts/ci/ci-git-publication.py", "--prepare", "--candidate-source", self.source,
                       "--server-parent", self.parent, "--repo-root", self.repo, "--output", self.manifest_path,
                       "--fixture-file", f"{pubtest.PHASE_REL}/253-LOAD-RECOVERY-CANARY-WORKFLOW.yml",
                       "--workflow-path", ".github/workflows/ci.yml", cwd=ROOT)
        assert prepared.returncode == 0, prepared.stderr
        self.manifest = json.loads(self.manifest_path.read_text())
        cert, key = d / "server.pem", d / "server-key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost",
                        "-addext", self.tls_san(), "-keyout", str(key), "-out", str(cert)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.cert = cert
        server = pubtest.ObjectHTTPServer(("127.0.0.1", 0), self.handler)
        server.journal, server.commits, server.trees = [], {}, {}
        server.tree_entries, server.blobs, server.refs = {}, {}, {}
        server.flags = dict(self.flags)
        server.last_body = b""
        server.model = {"pulls": {}, "families": {}, "numbers": [], "discovery": {}, "repo": self.repo, "zips": {}}
        self.test.addCleanup(server.server_close)
        pubtest.seed_server(server, self.repo, self.parent)
        server.parent_sha = self.parent
        self.ledger_path = d / "publication-ledger.json"
        server.ledger_path = str(self.ledger_path)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(cert, key)
        server.socket = tls.wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.test.addCleanup(thread.join)
        self.test.addCleanup(server.shutdown)
        self.server = server
        self.port = server.server_address[1]
        self.after_server_start()
        publish_allocation = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "publication-window",
                              "source_sha256": sha(self.manifest_path.read_bytes()), "max_requests": 24, "max_elapsed_seconds": 120,
                              "max_response_bytes": 2 * 1024 * 1024, "max_pages": 1, "max_hops": 2, "repository": "szTheory/sigra",
                              "download_hosts": [], "mode": "hermetic-test", "test_origin": f"https://localhost:{self.port}",
                              "test_ca_file": str(cert)}
        (d / "publication-allocation.json").write_text(json.dumps(publish_allocation))
        self.receipt_path = d / "publication-receipt.json"
        if self.seed_legacy_refs:
            self.seeded_refs = {"gsd/253-replan-candidate": self.parent, "gsd/253-replan-fixture": self.parent}
            server.refs.update(self.seeded_refs)
        if self.seed_r8_refs:
            self.seeded_refs = {**getattr(self, "seeded_refs", {}),
                                "gsd/253-replan-r8-candidate": self.parent, "gsd/253-replan-r8-fixture": self.parent}
            server.refs.update(self.seeded_refs)
        if self.seed_r9_refs:
            self.seeded_refs = {**getattr(self, "seeded_refs", {}),
                                "gsd/253-replan-r9-candidate": self.parent, "gsd/253-replan-r9-fixture": self.parent}
            server.refs.update(self.seeded_refs)
        freeze_args = []
        if self.ref_pair:
            # Publish under the canary revision freeze, as the canary does, so the receipt carries the freeze's ref pair.
            self.build_canary_freeze()
            canary_approval = self.write_approval("canary", "approval-canary", commit=True)
            publish_allocation.update({"allocation_kind": "canary", "max_requests": 117, "max_elapsed_seconds": 3600,
                                       "source_sha256": sha(self.canary_freeze_path.read_bytes())})
            (d / "publication-allocation.json").write_text(json.dumps(publish_allocation))
            freeze_args = ["--freeze", self.canary_freeze_path, "--action-approval", canary_approval]
        adapted = self.adapt_allocation(publish_allocation, "publication")
        if adapted is not publish_allocation:
            publish_allocation = adapted
            (d / "publication-allocation.json").write_text(json.dumps(publish_allocation))
        self.publication_allocation = publish_allocation
        published = run("python3", ROOT / "scripts/ci/ci-git-publication.py", "--publish", "--manifest", self.manifest_path,
                        "--allocation", d / "publication-allocation.json", "--ledger", self.ledger_path,
                        "--receipt", self.receipt_path, "--repo-root", self.repo, *freeze_args, cwd=ROOT, timeout=120,
                        env=self.subprocess_env())
        assert published.returncode == 0, published.stderr
        self.publication_requests = len(server.journal)
        server.journal.clear()  # the PR window is a separate allocation with its own independent journal
        self.freeze_path = d / "freeze.json"
        self.budget = d / "253-LOAD-RECOVERY-BUDGETS.md"  # fixture copy: ordinary tests never require active phase records
        self.budget.write_text("synthetic budget fixture\n")
        prepared = run("bash", PROOF, "--prepare", "--publication", self.receipt_path, "--manifest", self.manifest_path,
                       "--repo-root", self.repo, "--output", self.freeze_path, "--poll-interval", str(self.poll_interval),
                       "--budget-document", self.budget, cwd=ROOT, timeout=60)
        assert prepared.returncode == 0, prepared.stderr + prepared.stdout
        self.freeze = json.loads(self.freeze_path.read_text())
        self.build_approval(self.mutate_section)
        self.build_model()
        self.allocation_path = d / "allocation.json"
        self.allocation = self.adapt_allocation({
            "schema_version": "sigra.phase253.http-allocation/v1", "window_id": "pr-proof-window",
            "source_sha256": sha(self.freeze_path.read_bytes()), "max_requests": 120, "max_elapsed_seconds": 3600,
            "max_response_bytes": 4 * 1024 * 1024, "max_pages": 3, "max_hops": 2, "repository": "szTheory/sigra",
            "download_hosts": [], "mode": "hermetic-test", "test_origin": f"https://localhost:{self.port}", "test_ca_file": str(cert),
            "allocation_kind": "production", "category_limits": transport.PRODUCTION_CATEGORY_LIMITS,
            "bound_documents": self.freeze["bound_documents"]}, "production")
        self.allocation_path.write_text(json.dumps(self.allocation))
        self.ledger = d / "pr-ledger.json"
        self.server.ledger_path = str(self.ledger)

    def build_canary_freeze(self):
        """The real revision freeze, built by the publisher from the committed tree (with the world's ref pair, if any)."""
        manifest_rel = f"{pubtest.PHASE_REL}/253-LOAD-RECOVERY-CANARY-PUBLICATION.json"
        freeze_rel = f"{pubtest.PHASE_REL}/253-LOAD-RECOVERY-CANARY-FREEZE.json"
        (self.repo / manifest_rel).write_bytes(self.manifest_path.read_bytes())
        git(self.repo, "add", manifest_rel)
        git(self.repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: publication manifest")
        built = run("python3", ROOT / "scripts/ci/ci-git-publication.py", "--build-freeze", "--manifest", manifest_rel,
                    "--output", freeze_rel, "--repo-root", self.repo, *(["--ref-pair", self.ref_pair] if self.ref_pair else []), cwd=ROOT)
        assert built.returncode == 0, built.stderr
        self.canary_freeze_path = self.repo / freeze_rel
        git(self.repo, "add", freeze_rel)
        git(self.repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: canary freeze")
        self.digests = json.loads(self.canary_freeze_path.read_text())["outward_actions_sha256"]

    def build_approval(self, mutate_section=None):
        """The real revision freeze (built by the publisher from the committed tree) plus a committed docs_and_prs approval."""
        publisher = load(ROOT / "scripts/ci/ci-git-publication.py", "publisher")
        if self.canary_freeze_path is None:
            self.build_canary_freeze()
        freeze = json.loads(self.canary_freeze_path.read_text())
        if mutate_section:
            mutate_section(freeze["outward_actions"])
            freeze["outward_actions_sha256"] = {name: sha(publisher.canonical_bytes(value)) for name, value in freeze["outward_actions"].items()}
            self.canary_freeze_path.write_text(json.dumps(freeze, indent=2))
        self.digests = freeze["outward_actions_sha256"]
        self.approval_path = self.write_approval("docs_and_prs", name="approval-docs")
        git(self.repo, "add", ".planning")
        git(self.repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "planning: freeze and approval")

    def write_approval(self, section, name, commit=False, decision="approve", section_sha=None, tamper=False):
        path = self.repo / pubtest.PHASE_REL / f"{name}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"schema_version": "sigra.phase253.outward-action-approval/v1", "decision": decision,
                                    "section": section, "section_sha256": section_sha or self.digests[section],
                                    "decided_by": "test-operator", "recorded_at": "2026-10-14T00:00:00Z"}, indent=2) + "\n")
        if commit:
            git(self.repo, "add", str(path))
            git(self.repo, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", f"planning: {name}")
        if tamper:
            path.write_text(path.read_text() + "\n")
        return path

    def workflow(self, commit):
        return git(self.repo, "show", f"{commit}:.github/workflows/ci.yml")

    def build_model(self):
        spec = {"normal": self.freeze["normal"], "docs-only": self.freeze["docs-only"]}
        families, numbers = {}, [101, 102]
        for number, (name, run_id, merge) in zip(numbers, (("normal", 7001, "c" * 40), ("docs-only", 7002, "d" * 40))):
            head = spec[name]["head_sha"]
            docs = name == "docs-only"
            identity = {"run_id": str(run_id), "run_attempt": "1", "source_sha": merge, "event": "pull_request",
                        "workflow_ref": f"szTheory/sigra/.github/workflows/ci.yml@refs/pull/{number}/merge", "workflow_sha": merge,
                        "classifier_result": "success", "docs_only": "true" if docs else "false"}
            workflow = self.workflow(head)
            producers = self.generate(identity, workflow, docs)
            zips = {}
            artifacts = []
            for index, (directory, members) in enumerate(sorted(producers.items())):
                artifact_id = run_id * 10 + index
                zip_bytes = make_zip(sorted(members.items()))
                zips[artifact_id] = zip_bytes
                artifacts.append({"id": artifact_id, "name": directory, "size_in_bytes": len(zip_bytes), "expired": False,
                                  "digest": "sha256:" + sha(zip_bytes), "workflow_run": {"id": run_id, "head_sha": head}})
            artifacts.append({"id": run_id * 10 + 9, "name": f"example-playwright-admin_behavior-{run_id}", "size_in_bytes": 10,
                              "expired": False, "digest": "sha256:" + "0" * 64, "workflow_run": {"id": run_id, "head_sha": head}})
            job_names = [*NAMES, "Detect docs-only change", *[f"Example Playwright shard ({seam})" for seam in SEAMS]]
            if not docs:
                job_names += ["Library tests shard (1/2)", "Library tests shard (2/2)"]
            jobs = []
            for index, job_name in enumerate(job_names):
                steps = [{"name": "Detect docs-only change", "conclusion": "success"}] if job_name == "Detect docs-only change" else []
                jobs.append({"id": run_id * 100 + index, "run_id": run_id, "run_attempt": 1, "name": job_name, "status": "completed",
                             "conclusion": "success", "steps": steps})
            checks = [{"name": job["name"], "head_sha": head, "status": "completed", "conclusion": "success",
                       "app": {"id": 15368, "slug": "github-actions"},
                       "html_url": f"https://github.com/szTheory/sigra/actions/runs/{run_id}/job/{job['id']}"}
                      for job in jobs if job["name"] in NAMES]
            checks.append({"name": "Fast checks", "head_sha": head, "status": "completed", "conclusion": "success",
                           "app": {"id": 15368, "slug": "github-actions"}, "html_url": "https://github.com/szTheory/sigra/actions/runs/1/job/1"})

            def run_view(polls, run_id=run_id, head=head, head_ref=spec[name]["head_ref"], number=number):
                return {"id": run_id, "event": "pull_request", "head_sha": head, "head_branch": head_ref, "workflow_id": 259268962,
                        "path": ".github/workflows/ci.yml@refs/pull/%d/merge" % number, "run_attempt": 1,
                        "status": "completed" if polls else "in_progress", "conclusion": "success" if polls else None,
                        "repository": {"full_name": "szTheory/sigra"}, "head_repository": {"full_name": "szTheory/sigra"},
                        "pull_requests": [{"number": number}]}
            families[number] = {"name": name, "run_id": run_id, "head": head, "merge": merge, "commit": head, "run": run_view,
                                "jobs": jobs, "checks": checks, "artifacts": artifacts, "identity": identity, "docs": docs}
            self.server_zips = getattr(self, "server_zips", {})
            self.server_zips.update(zips)
        self.server.model = {"pulls": {}, "families": families, "numbers": list(numbers), "discovery": {}, "repo": self.repo,
                             "zips": self.server_zips}

    def generate(self, identity, workflow, docs):
        with tempfile.TemporaryDirectory(prefix="sigra-producers-") as tmp:
            tmp = pathlib.Path(tmp)
            (tmp / "gen.mjs").write_text(GENERATOR)
            (tmp / "workflow.yml").write_bytes(workflow)
            (tmp / "identity.json").write_text(json.dumps(identity))
            result = run("node", tmp / "gen.mjs", ROOT, tmp / "workflow.yml", tmp / "identity.json", tmp / "out", "docs" if docs else "normal")
            assert result.returncode == 0, result.stderr
            return {directory.name: {path.name: path.read_bytes() for path in directory.iterdir()} for directory in (tmp / "out").iterdir()}

    def collect(self, family, evidence_name, check=True, approval="default", revision_freeze="default", env=None, proof=PROOF):
        evidence = self.dir / evidence_name
        extra = []
        if revision_freeze == "default":
            revision_freeze = self.canary_freeze_path
        if approval == "default":
            approval = self.approval_path
        if revision_freeze is not None:
            extra += ["--revision-freeze", revision_freeze]
        if approval is not None:
            extra += ["--action-approval", approval]
        process = run("bash", proof, "--family", family, "--freeze", self.freeze_path, "--allocation", self.allocation_path,
                      "--evidence", evidence, "--requests", self.ledger, "--repo-root", self.repo, *extra, cwd=ROOT, timeout=600,
                      env=env if env is not None else self.subprocess_env())
        if check:
            assert process.returncode == 0, process.stdout + process.stderr
        return process, evidence

    def journal_file(self, name):
        path = self.dir / name
        path.write_text(json.dumps(self.server.journal))
        return path


def attach_journal(evidence_path, journal):
    value = json.loads(pathlib.Path(evidence_path).read_text())
    value["server_journal"] = journal
    return value


def retamper(evidence, route, mutate, family=None, nth=-1, category=None):
    """Change one retained API response consistently (ledger digest and independent journal) so only semantics can reject it."""
    transactions = evidence["transport_ledger"]["transactions"]
    indexes = [i for i, tx in enumerate(transactions) if tx["route_id"] == route and (family is None or tx["family"] == family)
               and (category is None or tx["category"] == category)]
    index = indexes[nth]
    tx = transactions[index]
    document = json.loads(base64.b64decode(tx["response_body_base64"]))
    replaced = mutate(document)
    document = document if replaced is None else replaced
    raw = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    tx.update(response_body_base64=enc(raw), response_sha256=sha(raw), scrubbed_response_bytes=len(raw), response_bytes=len(raw),
              raw_observation_sha256=sha(raw))
    if evidence.get("server_journal"):
        evidence["server_journal"][index]["body_sha256"] = sha(raw)
    return evidence


def swap_zip(evidence, name, archive):
    """Replace one producer ZIP and keep API digest, measured final hop and server journal consistent."""
    entry = next(d for d in evidence["downloads"] if d["name"] == name)
    entry["zip_base64"] = enc(archive)

    def mutate(document):
        for artifact in document["artifacts"]:
            if artifact["name"] == name:
                artifact["digest"] = "sha256:" + sha(archive)
                artifact["size_in_bytes"] = len(archive)
    retamper(evidence, "run_artifacts", mutate, family=evidence["family"])
    for index, tx in enumerate(evidence["transport_ledger"]["transactions"]):
        if tx.get("request_group") == entry["request_group"] and tx["actual_status"] == 200:
            tx.update(raw_observation_sha256=sha(archive), response_bytes=len(archive))
            evidence["server_journal"][index]["body_sha256"] = sha(archive)
    return evidence


# ------------------------------------------------------------------------------------------------ 253-109 live policy
# The PR families through the LIVE transport policy, offline: a live production allocation (no test fields, the
# trusted download_hosts list, a 253-dryrun-live-policy- window), the 253-107 shim mapping api.github.com and the
# trusted download hosts on 443 to the local fake, and a fake that serves both by Host header under a certificate
# for those names. Every policy decision (route, hop, host, token scope, ledger charge) runs as it would against GitHub.
dryrun = load(ROOT / "scripts/ci/ci-gate-canary-dryrun.py", "gate_dryrun_for_pr_proof")
shim_module = load(ROOT / "scripts/ci/ci-live-policy-shim.py", "live_policy_shim_for_pr_proof")
API_HOST, BLOB_HOST, PIPELINES_HOST = dryrun.API_HOST, dryrun.BLOB_HOST, dryrun.PIPELINES_HOST
LIVE_TOKEN = dryrun.LIVE_TOKEN
LIVE_WINDOW_PREFIX = dryrun.LIVE_WINDOW_PREFIX
TRUSTED_DOWNLOAD_HOSTS = list(json.loads((ROOT / dryrun.R8_ALLOCATION_REL).read_text())["download_hosts"])
SLEEP_LOG_VAR = "SIGRA_PR_PROOF_LIVE_SLEEP_LOG"
SLEEP_RECORDER = '''
# 253-109 test-only recorder, appended after the shim install: log each requested wait, then sleep the shim's scaled
# fraction. Inert unless the shim and the log variable are both set.
import os as _rec_os
if _rec_os.environ.get("SIGRA_LIVE_POLICY_SHIM") and _rec_os.environ.get("%s"):
    import json as _rec_json
    import time as _rec_time
    _rec_scaled = _rec_time.sleep

    def _rec_sleep(seconds, _scaled=_rec_scaled, _path=_rec_os.environ["%s"]):
        with open(_path, "a", encoding="utf-8") as _stream:
            _stream.write(_rec_json.dumps({"seconds": seconds, "pid": _rec_os.getpid()}) + "\\n")
        _scaled(seconds)
    _rec_time.sleep = _rec_sleep
''' % (SLEEP_LOG_VAR, SLEEP_LOG_VAR)


class LivePRHandler(PRHandler):
    """The PR fake served by Host header: api.github.com needs the dummy bearer token and never serves a download; the
    blob host gets no Authorization and serves only the pre-signed ZIP paths this fake issued in a 302."""

    def _host(self):
        return (self.headers.get("Host") or "").split(":", 1)[0].lower()

    def _emit(self, status, body, extra=(), content_type="application/json"):
        super()._emit(status, body, extra, content_type)
        self.server.journal[-1]["host"] = self._host()

    def _guard(self):
        """True when the request was refused here (an unmodeled host or a path on the wrong host)."""
        server, host = self.server, self._host()
        parsed = urlsplit(self.path)
        authorization = self.headers.get("Authorization")
        download = parsed.path.startswith("/blob/")
        refusal = None
        if host == API_HOST:
            if authorization != f"Bearer {LIVE_TOKEN}":
                server.violations.append(f"api.github.com request without the dummy bearer token: {self.command} {parsed.path}")
            if download:
                refusal = (404, "a download path was requested on api.github.com")
        elif host == BLOB_HOST:
            if authorization:
                server.violations.append(f"Authorization reached the blob host: {self.command} {parsed.path}")
            if not download or self.command != "GET" or set(parse_qs(parsed.query)) != {"sv", "sig"}:
                refusal = (404, "the blob host serves only issued download paths")
        else:
            refusal = (421, f"request for an unmodeled Host {host!r}")
        if refusal is None:
            return False
        server.violations.append(f"{refusal[1]}: {self.command} {parsed.path}")
        self.server.last_body = b""
        self._reply(refusal[0], {"message": refusal[1]})
        return True

    def do_GET(self):  # noqa: N802
        if self._guard():
            return None
        route = urlsplit(self.path).path
        base = "/repos/szTheory/sigra"
        if route.startswith(base + "/actions/artifacts/") and route.endswith("/zip"):
            self._first()
            self.server.last_body = b""
            artifact_id = route.removeprefix(base + "/actions/artifacts/").split("/")[0]
            # GitHub answers with a pre-signed blob URL on 443 (no explicit port); the transport must follow it bare.
            location = f"https://{BLOB_HOST}/blob/{artifact_id}?sv=2025-01-05&sig=fixture-secret"
            return self._emit(302, b"", [("Location", location)])
        return super().do_GET()

    def do_POST(self):  # noqa: N802
        if self._guard():
            return None
        return super().do_POST()


class LiveWorld(World):
    """The World universe on the live transport policy: live publication and production allocations, the shim
    environment (dummy GH_TOKEN, chained interpreter sitecustomize, scaled sleep) for every subprocess."""

    handler = LivePRHandler
    poll_interval = 60  # the frozen production interval; only the shim scales the actual wait

    def __init__(self, test, flags=None, tag="live", ref_pair="legacy", sleep_scale=0.001, seed_r8_refs=False, seed_r9_refs=False):
        self.sleep_scale = sleep_scale
        self.window_id = f"{LIVE_WINDOW_PREFIX}{os.getpid()}"
        super().__init__(test, flags=flags, tag=tag, ref_pair=ref_pair, seed_r8_refs=seed_r8_refs, seed_r9_refs=seed_r9_refs)

    def tls_san(self):
        return "subjectAltName=" + ",".join(f"DNS:{name}" for name in ("localhost", *dryrun.LIVE_TLS_NAMES))

    def after_server_start(self):
        d = self.dir
        self.server.violations = []
        self.connect_log = d / "shim-connect.log"
        self.sleep_log = d / "requested-sleeps.log"
        env = shim_module.prepare(d / "live-policy-shim", {API_HOST: self.port, BLOB_HOST: self.port, PIPELINES_HOST: self.port},
                                  self.cert, self.connect_log, sleep_scale=self.sleep_scale)
        site = pathlib.Path(env["PYTHONPATH"]) / "sitecustomize.py"
        dryrun.chain_interpreter_sitecustomize(site)  # the shim's sitecustomize hides Homebrew's (PyYAML) otherwise
        site.write_text(site.read_text() + SLEEP_RECORDER)
        base = {key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")}
        self.env = {**base, **env, "GH_TOKEN": LIVE_TOKEN, SLEEP_LOG_VAR: str(self.sleep_log), "PYTHONDONTWRITEBYTECODE": "1"}

    def adapt_allocation(self, allocation, purpose):
        live = {key: value for key, value in allocation.items() if key not in ("test_origin", "test_ca_file")}
        window = self.window_id if purpose == "production" else f"{LIVE_WINDOW_PREFIX}publication-{os.getpid()}"
        live.update(mode="live", download_hosts=list(TRUSTED_DOWNLOAD_HOSTS), window_id=window)
        return live

    def subprocess_env(self):
        return dict(self.env)

    def refusals(self):
        return shim_module.read_log(shim_module.refusal_log_for(self.connect_log))

    def connect_hosts(self):
        return sorted({entry["host"] for entry in shim_module.read_log(self.connect_log)})

    def sleeps(self):
        if not self.sleep_log.exists():
            return []
        return [json.loads(line)["seconds"] for line in self.sleep_log.read_text().splitlines() if line.strip()]


def run_verifier(*args):
    """The independent verifier CLI, outside the shim (it makes no request)."""
    process = run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", *args, cwd=ROOT, timeout=300)
    try:
        value = json.loads(process.stdout) if process.returncode == 0 else None
    except json.JSONDecodeError:
        value = None
    return process, value


class PRProofContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.world = World(cls.holder, tag="main")
        w = cls.world
        process, cls.normal_path = w.collect("normal", "normal.json")
        cls.normal_summary = json.loads(process.stdout.strip().splitlines()[-1])
        cls.normal_requests = len(w.server.journal)
        process, cls.docs_path = w.collect("docs-only", "docs.json")
        cls.docs_summary = json.loads(process.stdout.strip().splitlines()[-1])
        cls.journal = list(w.server.journal)
        cls.normal = attach_journal(cls.normal_path, cls.journal[:cls.normal_requests])
        cls.docs = attach_journal(cls.docs_path, cls.journal)

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    # ------------------------------------------------------------------------------ positive chain
    def test_complete_synthetic_normal_and_docs_chain_verifies_against_independent_server_receipts(self):
        for summary in (self.normal_summary, self.docs_summary):
            self.assertEqual(summary["status"], "collected", summary)
        w = self.world
        ledger = json.loads(w.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), len(self.journal))
        self.assertLessEqual(len(self.journal), 120)
        self.assertTrue(all(row["charged"] for row in self.journal), "every wire request was predebited before the socket")
        self.assertEqual([row["status"] for row in self.journal], [tx["actual_status"] for tx in ledger["transactions"]])
        self.assertTrue(all(row["authorization"] is None for row in self.journal))
        pair = verifier.verify_pr_pair(copy.deepcopy(self.normal), copy.deepcopy(self.docs))
        self.assertEqual(pair["status"], "synthetic_pr_pair_verified")
        self.assertFalse(pair["accepted_live"], "local HTTPS proof is labeled synthetic and is never live acceptance")
        self.assertEqual(pair["normal"]["merge_sha"], "c" * 40)
        self.assertNotEqual(pair["normal"]["merge_sha"], pair["normal"]["head_sha"])
        counts = {}
        for tx in ledger["transactions"]:
            counts[tx["category"]] = counts.get(tx["category"], 0) + 1
        self.assertEqual(counts["docs_publication"], 14)
        self.assertEqual(counts["artifact_downloads"], 20, "five artifacts x two hops per family are all counted")
        self.assertEqual(counts["preflight"], 4)
        self.assertEqual(counts["run_discovery"], 4)
        self.assertEqual(counts["pr_create"], 2)
        for category, count in counts.items():
            self.assertLessEqual(count, transport.PRODUCTION_CATEGORY_LIMITS[category])
        hops = [tx for tx in ledger["transactions"] if tx["route_id"] == "artifact_zip"]
        self.assertEqual(sorted({tx["hop_ordinal"] for tx in hops}), [0, 1])
        self.assertNotIn("fixture-secret", w.ledger.read_text() + self.normal_path.read_text())

    def test_cli_verify_modes_agree_with_the_python_verifier(self):
        w = self.world
        journal_normal = w.dir / "journal-normal.json"
        journal_normal.write_text(json.dumps(self.journal[:self.normal_requests]))
        journal_all = w.journal_file("journal-all.json")
        single = run("bash", PROOF, "--verify", self.normal_path, "--server-journal", journal_normal, cwd=ROOT, timeout=120)
        self.assertEqual(single.returncode, 0, single.stderr)
        self.assertEqual(json.loads(single.stdout)["status"], "synthetic_pr_family_verified")
        both = run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", "--mode", "pr", "--family", "docs-only", "--evidence",
                   self.write_attached("docs-attached.json", self.docs), cwd=ROOT, timeout=120)
        self.assertEqual(both.returncode, 0, both.stderr)
        pair = run("bash", PROOF, "--verify", self.normal_path, "--server-journal", journal_normal, "--docs-evidence", self.docs_path,
                   "--docs-server-journal", journal_all, cwd=ROOT, timeout=180)
        self.assertEqual(pair.returncode, 0, pair.stderr)
        self.assertEqual(json.loads(pair.stdout)["status"], "synthetic_pr_pair_verified")
        missing = run("bash", PROOF, "--verify", self.normal_path, cwd=ROOT, timeout=120)
        self.assertNotEqual(missing.returncode, 0, "a hermetic proof without the independent journal is never verified")

    def write_attached(self, name, evidence):
        path = self.world.dir / name
        path.write_text(json.dumps(evidence))
        return path

    # ----------------------------------------------------------------------------- helpers
    def assertRejected(self, evidence, family="normal", text=None):
        with self.assertRaises(verifier.VerificationError) as caught:
            verifier.verify_pr_family(evidence, family)
        if text:
            self.assertIn(text, str(caught.exception))

    def fresh(self, family="normal"):
        return copy.deepcopy(self.normal if family == "normal" else self.docs)

    # ------------------------------------------------------- wrong PR / merge / run / check identities
    def test_wrong_pr_head_base_draft_and_merge_identities_are_rejected(self):
        cases = {
            "head sha": lambda e: retamper(e, "pr_create", lambda d: d["head"].update(sha="e" * 40)),
            "head ref": lambda e: retamper(e, "pr_create", lambda d: d["head"].update(ref="gsd/253-replan-fixture")),
            "base ref": lambda e: retamper(e, "pr_create", lambda d: d["base"].update(ref="release")),
            "not draft": lambda e: retamper(e, "pr_create", lambda d: d.update(draft=False)),
            "merged": lambda e: retamper(e, "pr_read", lambda d: d.update(merged=True)),
            "fork head": lambda e: retamper(e, "pr_read", lambda d: d["head"]["repo"].update(full_name="attacker/sigra")),
            "merge equals head": lambda e: retamper(e, "pr_read", lambda d: d.update(merge_commit_sha=d["head"]["sha"])),
            "no merge": lambda e: retamper(e, "pr_read", lambda d: d.update(merge_commit_sha=None)),
            "different number": lambda e: retamper(e, "pr_read", lambda d: d.update(number=999)),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(mutate(self.fresh()))

    def test_wrong_run_event_source_workflow_and_conclusion_are_rejected(self):
        cases = {
            "dispatch event": lambda d: d.update(event="workflow_dispatch"),
            "other head": lambda d: d.update(head_sha="f" * 40),
            "other branch": lambda d: d.update(head_branch="main"),
            "other workflow": lambda d: d.update(workflow_id=1),
            "other path": lambda d: d.update(path=".github/workflows/other.yml@refs/heads/x"),
            "failure": lambda d: d.update(conclusion="failure"),
            "cancelled": lambda d: d.update(conclusion="cancelled"),
            "in progress": lambda d: d.update(status="in_progress"),
            "unlinked PR": lambda d: d.update(pull_requests=[]),
            "attempt zero": lambda d: d.update(run_attempt=0),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(retamper(self.fresh(), "run", mutate))

    def test_native_check_app_revision_name_and_job_bindings_are_exact(self):
        def checks(e, mutate):
            return retamper(e, "check_runs", lambda d: mutate(d["check_runs"]))
        cases = {
            "wrong head": lambda runs: runs[0].update(head_sha="a" * 40),
            "app drift": lambda runs: runs[0]["app"].update(id=999),
            "failed check": lambda runs: runs[1].update(conclusion="failure"),
            "missing check": lambda runs: runs.pop(0),
            "job mismatch": lambda runs: runs[0].update(html_url="https://github.com/szTheory/sigra/actions/runs/7001/job/1"),
            "duplicate": lambda runs: runs.append(dict(runs[0])),
            "trailing space": lambda runs: runs[0].update(name=runs[0]["name"] + " "),
            "zero width": lambda runs: runs[0].update(name=runs[0]["name"] + "\u200b"),
            "case variant": lambda runs: runs[0].update(name=runs[0]["name"].lower()),
            "fullwidth": lambda runs: runs[1].update(name=runs[1]["name"].replace("(", "\uff08")),
            "combining mark": lambda runs: runs[2].update(name=runs[2]["name"] + "\u0301"),
            "nfd lookalike": lambda runs: runs[3].update(name=unicodedata.normalize("NFD", runs[3]["name"].replace("e", "\u00e9"))),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(checks(self.fresh(), mutate))

    def test_job_inventory_classifier_and_library_owner_are_required(self):
        def jobs(e, mutate, family="normal"):
            return retamper(e, "attempt_jobs", lambda d: (mutate(d["jobs"]), d.update(total_count=len(d["jobs"])))[0], family=family)
        cases = {
            "required job failed": lambda j: j[0].update(conclusion="failure"),
            "classifier missing": lambda j: j.pop(5),
            "classifier step failed": lambda j: j[5]["steps"][0].update(conclusion="failure"),
            "duplicate required": lambda j: j.append(dict(j[0])),
            "producer shard missing": lambda j: j.pop(6),
            "wrong attempt": lambda j: j[0].update(run_attempt=2),
            "library owner missing": lambda j: [j.remove(job) for job in list(j) if job["name"].startswith("Library tests shard")],
            "empty": lambda j: j.clear(),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(jobs(self.fresh(), mutate))

    def test_producer_inventory_empty_null_single_duplicate_and_variant_sets_fail(self):
        def artifacts(e, mutate):
            return retamper(e, "run_artifacts", lambda d: (mutate(d), d.update(total_count=len(d["artifacts"])))[0])
        cases = {
            "empty": lambda d: d["artifacts"].clear(),
            "single": lambda d: d.update(artifacts=d["artifacts"][:1]),
            "duplicate": lambda d: d["artifacts"].append(dict(d["artifacts"][0])),
            "unknown run": lambda d: d["artifacts"][0].update(name=d["artifacts"][0]["name"].replace("7001", "7099")),
            "case variant": lambda d: d["artifacts"][0].update(name=d["artifacts"][0]["name"].replace("browser", "Browser")),
            "trailing space": lambda d: d["artifacts"][0].update(name=d["artifacts"][0]["name"] + " "),
            "cyrillic lookalike": lambda d: d["artifacts"][1].update(name=d["artifacts"][1]["name"].replace("a", "\u0430", 1)),
            "nfd seam": lambda d: d["artifacts"][1].update(name=unicodedata.normalize("NFD", d["artifacts"][1]["name"].replace("e", "\u00e9", 1))),
            "extra seam": lambda d: d["artifacts"].append(dict(d["artifacts"][0], id=999, name="browser-execution-extra-7001-1")),
            "expired": lambda d: d["artifacts"][0].update(expired=True),
            "other run": lambda d: d["artifacts"][0]["workflow_run"].update(id=1),
            "other head": lambda d: d["artifacts"][0]["workflow_run"].update(head_sha="a" * 40),
            "no digest": lambda d: d["artifacts"][0].update(digest=None),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(artifacts(self.fresh(), mutate))
        null_inventory = retamper(self.fresh(), "run_artifacts", lambda d: {"total_count": None, "artifacts": None})
        self.assertRejected(null_inventory)

    def test_producer_zip_bytes_digest_members_and_records_are_independently_checked(self):
        evidence = self.fresh()
        victim = next(item for item in evidence["downloads"] if "non_admin_smoke" in item["name"])
        files = verifier.validate_producer_zip(base64.b64decode(victim["zip_base64"]))
        self.assertIn("execution-record.json", files)
        digest_only = copy.deepcopy(evidence)
        next(d for d in digest_only["downloads"] if d["name"] == victim["name"])["zip_base64"] = enc(make_zip(sorted(files.items())) + b"")
        digest_only["downloads"][0]["zip_base64"] = enc(make_zip([("execution-record.json", b"{}")]))
        self.assertRejected(digest_only)
        reports = [name for name in files if name != "execution-record.json" and not name.endswith(".selection.json")]
        cases = {
            "record only": [("execution-record.json", files["execution-record.json"])],
            "missing report": [(n, d) for n, d in files.items() if n != reports[0]],
            "missing selection": [(n, d) for n, d in files.items() if n != reports[0].replace(".json", ".selection.json")],
            "unknown member": [*files.items(), ("extra.json", b"{}")],
            "empty report": [(n, b"" if n == reports[0] else d) for n, d in files.items()],
            "null report": [(n, b"null" if n == reports[0] else d) for n, d in files.items()],
            "altered report": [(n, d.replace(b"passed", b"failed") if n == reports[0] else d) for n, d in files.items()],
            "no record": [(n, d) for n, d in files.items() if n != "execution-record.json"],
        }
        for label, built in cases.items():
            with self.subTest(label):
                self.assertRejected(swap_zip(copy.deepcopy(evidence), victim["name"], make_zip(built)))
        forged_digest = copy.deepcopy(evidence)
        retamper(forged_digest, "run_artifacts", lambda d: d["artifacts"][0].update(digest="sha256:" + "1" * 64))
        self.assertRejected(forged_digest)

    def test_zip_intake_rejects_traversal_links_duplicates_nested_and_trailing_streams(self):
        import warnings
        warnings.filterwarnings("ignore", message="Duplicate name")
        validate = verifier.validate_producer_zip
        self.assertEqual(validate(make_zip([("execution-record.json", b"{}")])), {"execution-record.json": b"{}"})
        link = io.BytesIO()
        with zipfile.ZipFile(link, "w") as bundle:
            info = zipfile.ZipInfo("execution-record.json")
            info.create_system = 3
            info.external_attr = 0o120777 << 16
            bundle.writestr(info, b"target")
        duplicate = io.BytesIO()
        with zipfile.ZipFile(duplicate, "w") as bundle:
            bundle.writestr("a.json", b"1")
            bundle.writestr("a.json", b"2")
        for label, payload in {
            "traversal": make_zip([("../evil.json", b"{}")]), "absolute": make_zip([("/evil.json", b"{}")]),
            "nested": make_zip([("dir/x.json", b"{}")]), "backslash": make_zip([("dir\\x.json", b"{}")]),
            "directory": make_zip([("dir/", b"")]), "symlink": link.getvalue(), "duplicate": duplicate.getvalue(),
            "trailing": make_zip([("a.json", b"{}")]) + b"tail", "empty": b"", "truncated": make_zip([("a.json", b"{}")])[:-5],
            "oversized": b"PK" * (4 * 1024 * 1024),
        }.items():
            with self.subTest(label):
                with self.assertRaises(verifier.VerificationError):
                    validate(payload)

    def test_browser_policy_owner_rejects_wrong_record_identity_and_wrong_workflow_source(self):
        w = self.world
        evidence = self.fresh()
        family = next(f for f in w.server.model["families"].values() if f["name"] == "normal")
        control = w.generate(family["identity"], w.workflow(family["head"]), False)
        positive = copy.deepcopy(evidence)
        for name, members in control.items():
            swap_zip(positive, name, make_zip(sorted(members.items())))
        self.assertEqual(verifier.verify_pr_family(positive, "normal")["family"], "normal", "regenerated control must verify")
        for label, change in {
            "wrong source sha": {"source_sha": "9" * 40},
            "wrong run": {"run_id": "1"},
            "docs flag": {"docs_only": "true", "classifier_result": "success"},
            "wrong classifier": {"classifier_result": "failure"},
            "wrong event": {"event": "push"},
        }.items():
            with self.subTest(label):
                producers = w.generate({**family["identity"], **change}, w.workflow(family["head"]), False)
                tampered = copy.deepcopy(evidence)
                for item in list(tampered["downloads"]):
                    swap_zip(tampered, item["name"], make_zip(sorted(producers[next(n for n in producers if n.split("-")[2] == item["name"].split("-")[2])].items())))
                self.assertRejected(tampered)
        other = copy.deepcopy(evidence)
        retamper(other, "repo_contents", lambda d: d.update(content=enc(b"name: other\n"), sha=hashlib.sha1(b"blob 12\0name: other\n").hexdigest()))
        self.assertRejected(other)

    def test_normal_diff_must_include_nondoc_paths_and_docs_diff_must_be_the_one_file(self):
        self.assertRejected(retamper(self.fresh(), "compare", lambda d: d.update(files=[{"filename": "README.md"}])))
        self.assertRejected(retamper(self.fresh(), "compare", lambda d: d.update(files=[])))
        self.assertRejected(retamper(self.fresh(), "compare", lambda d: d.update(files=[{"filename": "unfrozen.ex"}])))
        self.assertRejected(retamper(self.fresh("docs"), "compare", lambda d: d["files"].append({"filename": "mix.exs"})), "docs-only")
        self.assertRejected(retamper(self.fresh("docs"), "compare", lambda d: d.update(files=[{"filename": "other.md"}])), "docs-only")
        self.assertRejected(retamper(self.fresh("docs"), "compare", lambda d: d.update(ahead_by=2)), "docs-only")
        wrong_local = self.fresh("docs")
        wrong_local["freeze"]["docs-only"]["local_diff_paths"] = [DOCS_PATH, "mix.exs"]
        wrong_local["freeze"]["freeze_sha256"] = verifier.canonical_digest({k: v for k, v in wrong_local["freeze"].items() if k != "freeze_sha256"})
        self.assertRejected(wrong_local, "docs-only")

    def test_docs_exemption_requires_the_actual_pull_request_classifier_and_docs_flag(self):
        w = self.world
        family = next(f for f in w.server.model["families"].values() if f["name"] == "docs-only")
        evidence = self.fresh("docs")
        self.assertEqual(verifier.verify_pr_family(copy.deepcopy(evidence), "docs-only")["family"], "docs-only")
        workflow = w.workflow(family["head"])
        for label, (identity_change, docs_flag) in {
            "classifier failed": ({"classifier_result": "failure"}, True),
            "dispatch event": ({"event": "workflow_dispatch"}, True),
            "docs flag false": ({"docs_only": "false"}, True),
            "full body with docs claim": ({}, False),
        }.items():
            with self.subTest(label):
                producers = w.generate({**family["identity"], **identity_change}, workflow, docs_flag)
                tampered = copy.deepcopy(evidence)
                for item in list(tampered["downloads"]):
                    source = next(n for n in producers if n.split("-")[2] == item["name"].split("-")[2])
                    swap_zip(tampered, item["name"], make_zip(sorted(producers[source].items())))
                self.assertRejected(tampered, "docs-only")
        no_classifier = retamper(self.fresh("docs"), "attempt_jobs", lambda d: (d["jobs"].pop(5), d.update(total_count=len(d["jobs"])))[0], family="docs-only")
        self.assertRejected(no_classifier, "docs-only")

    def test_docs_base_must_be_one_trigger_only_child_of_the_exact_candidate(self):
        for label, mutate in {
            "extra file": lambda e: retamper(e, "compare", lambda d: d["files"].append({"filename": "mix.exs"}), family="docs-only", nth=1),
            "two commits": lambda e: retamper(e, "compare", lambda d: d.update(ahead_by=2), family="docs-only", nth=1),
            "other file": lambda e: retamper(e, "compare", lambda d: d.update(files=[{"filename": ".github/workflows/other.yml"}]), family="docs-only", nth=1),
            "behind": lambda e: retamper(e, "compare", lambda d: d.update(behind_by=1), family="docs-only", nth=1),
            "wrong parent": lambda e: retamper(e, "git_get_commit", lambda d: d.update(parents=[{"sha": "3" * 40}]), nth=0),
            "wrong message": lambda e: retamper(e, "git_get_commit", lambda d: d.update(message="other\n"), nth=1),
            "extra parent": lambda e: retamper(e, "git_get_commit", lambda d: d["parents"].append({"sha": "4" * 40}), nth=0),
        }.items():
            with self.subTest(label):
                self.assertRejected(mutate(self.fresh("docs")), "docs-only")
        for label, mutate in {
            "base diff missing": lambda f: f["docs-only"].pop("base_local_diff_paths"),
            "base diff widened": lambda f: f["docs-only"].update(base_local_diff_paths=[".github/workflows/ci.yml", "mix.exs"]),
        }.items():
            with self.subTest(label):
                tampered = self.fresh("docs")
                mutate(tampered["freeze"])
                tampered["freeze"]["freeze_sha256"] = verifier.canonical_digest({k: v for k, v in tampered["freeze"].items() if k != "freeze_sha256"})
                self.assertRejected(tampered, "docs-only")

    def test_docs_commit_readback_tolerates_exactly_one_stripped_trailing_newline(self):
        # The shared fake server returns commit JSON the way GitHub does: one trailing newline stripped.
        for nth, frozen in ((0, "Phase 253 docs probe base workflow exception\n"), (1, "Phase 253 docs-only probe head\n")):
            with self.subTest(form="stripped", nth=nth):
                evidence = self.fresh("docs")
                transactions = evidence["transport_ledger"]["transactions"]
                readbacks = [tx for tx in transactions if tx["route_id"] == "git_get_commit"]
                self.assertEqual(json.loads(base64.b64decode(readbacks[nth]["response_body_base64"]))["message"], frozen[:-1])
                verifier.verify_pr_family(evidence, "docs-only")
            with self.subTest(form="verbatim", nth=nth):
                evidence = retamper(self.fresh("docs"), "git_get_commit", lambda d: d.update(message=frozen), nth=nth)
                verifier.verify_pr_family(evidence, "docs-only")
        for label, mutate in {
            "extra newline": lambda d: d.update(message=d["message"].rstrip("\n") + "\n\n"),
            "two characters stripped": lambda d: d.update(message=d["message"].rstrip("\n")[:-1]),
            "crlf": lambda d: d.update(message=d["message"].rstrip("\n") + "\r\n"),
            "trailing space": lambda d: d.update(message=d["message"].rstrip("\n") + " "),
            "missing": lambda d: d.pop("message"),
            "non-string": lambda d: d.update(message=5),
        }.items():
            for nth in (0, 1):
                with self.subTest(label, nth=nth):
                    self.assertRejected(retamper(self.fresh("docs"), "git_get_commit", mutate, nth=nth), "docs-only")

    def test_docs_publication_must_use_exactly_the_reserved_requests_and_frozen_objects(self):
        evidence = self.fresh("docs")
        txs = evidence["transport_ledger"]["transactions"]
        drop = next(i for i, tx in enumerate(txs) if tx["category"] == "docs_publication" and tx["route_id"] == "git_get_blob")
        short = copy.deepcopy(evidence)
        del short["transport_ledger"]["transactions"][drop]
        del short["server_journal"][drop]
        for index, tx in enumerate(short["transport_ledger"]["transactions"], 1):
            tx["sequence"] = index
        self.assertRejected(short, "docs-only")
        self.assertRejected(retamper(self.fresh("docs"), "git_create_commit", lambda d: d.update(sha="1" * 40), nth=0), "docs-only")
        self.assertRejected(retamper(self.fresh("docs"), "create_ref", lambda d: d["object"].update(sha="2" * 40), nth=1), "docs-only")

    # -------------------------------------------------------------------------- transport accounting
    def test_ledger_allocation_journal_and_origin_tampering_is_rejected(self):
        def change(mutate, family="normal"):
            evidence = self.fresh(family)
            mutate(evidence)
            return evidence
        def alloc(evidence, **fields):
            value = json.loads(base64.b64decode(evidence["allocation_base64"]))
            value.update(fields)
            evidence["allocation_base64"] = enc(json.dumps(value).encode())
        cases = {
            "uncharged request removed": lambda e: (e["transport_ledger"]["transactions"].pop(3), e["server_journal"].pop(3)),
            "journal missing": lambda e: e.update(server_journal=None),
            "journal extra": lambda e: e["server_journal"].append(dict(e["server_journal"][-1])),
            "journal status": lambda e: e["server_journal"][2].update(status=201),
            "journal body": lambda e: e["server_journal"][4].update(body_sha256="0" * 64),
            "journal path": lambda e: e["server_journal"][5].update(path="/other"),
            "journal credentials": lambda e: e["server_journal"][1].update(authorization="Bearer secret"),
            "canary allocation": lambda e: alloc(e, allocation_kind="canary", max_requests=117),
            "allocation 121": lambda e: alloc(e, max_requests=121),
            "live label": lambda e: e.update(synthetic=False),
            "category over": lambda e: e["transport_ledger"]["transactions"][0].update(category="unknown"),
            "terminal stop": lambda e: e["transport_ledger"].update(terminal_stop={"code": "http_429"}),
            "pending": lambda e: e["transport_ledger"]["transactions"][1].update(state="pending"),
            "rate limited": lambda e: e["transport_ledger"]["transactions"][1].update(actual_status=429),
            "family missing": lambda e: e["transport_ledger"]["transactions"][1].update(family=None),
            "duplicate page": lambda e: e["transport_ledger"]["transactions"][[i for i, t in enumerate(e["transport_ledger"]["transactions"]) if t["route_id"] == "run_artifacts"][0]].update(page_ordinal=2),
            "hop gap": lambda e: [t.update(hop_ordinal=t["hop_ordinal"] + 1) for t in e["transport_ledger"]["transactions"] if t["route_id"] == "artifact_zip" and t["hop_ordinal"] == 1],
            "response digest": lambda e: e["transport_ledger"]["transactions"][2].update(response_sha256="0" * 64),
            "foreign origin": lambda e: e["transport_ledger"]["transactions"][2].update(host="evil.example"),
            "freeze edited": lambda e: e["freeze"]["normal"].update(head_sha="b" * 40),
            "incomplete collection": lambda e: e["collection"].update(complete=False),
            "stopped collection": lambda e: e["collection"].update(stop="rate limited"),
        }
        for label, mutate in cases.items():
            with self.subTest(label):
                self.assertRejected(change(mutate))

    def test_every_removed_evidence_field_fails_closed_instead_of_crashing_or_passing(self):
        base = self.fresh()
        for key in list(base):
            if key in ("server_journal", "action_approval"):
                continue  # action_approval is collector-side provenance the verifier deliberately ignores (253-91)
            broken = self.fresh()
            del broken[key]
            with self.subTest(top=key):
                self.assertRejected(broken)
        for field in ("sequence", "state", "actual_status", "window_id", "source_sha256", "category", "family", "route_id", "method",
                      "url", "url_sha256", "host", "response_body_base64", "response_sha256", "scrubbed_response_bytes",
                      "raw_observation_sha256"):
            broken = self.fresh()
            del broken["transport_ledger"]["transactions"][3][field]
            with self.subTest(transaction_field=field):
                self.assertRejected(broken)
        for field in list(base["freeze"]):
            broken = self.fresh()
            del broken["freeze"][field]
            with self.subTest(freeze_field=field):
                self.assertRejected(broken)
        for field in ("artifact_id", "name", "request_group", "zip_base64"):
            broken = self.fresh()
            del broken["downloads"][0][field]
            with self.subTest(download_field=field):
                self.assertRejected(broken)
        for value in (None, 0, "", [], {}):
            for key in ("transport_ledger", "freeze", "downloads", "allocation_base64", "collection"):
                broken = self.fresh()
                broken[key] = value
                with self.subTest(value=value, key=key):
                    self.assertRejected(broken)

    def test_pair_rejects_budget_reset_prefix_divergence_and_reused_prs(self):
        reset = self.fresh("docs")
        value = json.loads(base64.b64decode(reset["allocation_base64"]))
        value["window_id"] = "second-window"
        reset["allocation_base64"] = enc(json.dumps(value).encode())
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_pr_pair(self.fresh(), reset)
        diverged = self.fresh("docs")
        diverged["transport_ledger"]["transactions"][0]["actual_status"] = 200 if diverged["transport_ledger"]["transactions"][0]["actual_status"] != 200 else 201
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_pr_pair(self.fresh(), diverged)
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_pr_pair(self.fresh(), self.fresh())

    # ---------------------------------------------------------------------------- collector contracts
    def test_check_only_makes_no_request_and_rejects_changed_bindings_and_wrong_allocations(self):
        w = self.world
        before = len(w.server.journal)
        ok = run("bash", PROOF, "--check-only", "--freeze", w.freeze_path, "--allocation", w.allocation_path, cwd=ROOT)
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertEqual(json.loads(ok.stdout)["network_requests"], 0)
        self.assertEqual(len(w.server.journal), before)
        for label, change in {
            "canary kind": {"allocation_kind": "canary", "max_requests": 117},
            "changed limits": {"category_limits": {**transport.PRODUCTION_CATEGORY_LIMITS, "preflight": 9}},
            "other source": {"source_sha256": "0" * 64},
            "other documents": {"bound_documents": []},
        }.items():
            with self.subTest(label):
                path = w.dir / "bad-allocation.json"
                path.write_text(json.dumps({**w.allocation, **change}))
                self.assertNotEqual(run("bash", PROOF, "--check-only", "--freeze", w.freeze_path, "--allocation", path, cwd=ROOT).returncode, 0)
        tampered = json.loads(w.freeze_path.read_text())
        tampered["normal"]["head_sha"] = "a" * 40
        path = w.dir / "tampered-freeze.json"
        path.write_text(json.dumps(tampered))
        self.assertNotEqual(run("bash", PROOF, "--check-only", "--freeze", path, cwd=ROOT).returncode, 0)

    def test_a_changed_or_missing_bound_document_stops_the_collector_before_any_request(self):
        w = self.world
        budget_bytes = w.budget.read_bytes()
        before = len(w.server.journal)
        try:
            w.budget.write_text("edited after freeze\n")
            changed = run("bash", PROOF, "--check-only", "--freeze", w.freeze_path, cwd=ROOT)
            self.assertNotEqual(changed.returncode, 0)
            process, _ = w.collect("normal", "never.json", check=False)
            self.assertNotEqual(process.returncode, 0)
            w.budget.unlink()
            self.assertNotEqual(run("bash", PROOF, "--check-only", "--freeze", w.freeze_path, cwd=ROOT).returncode, 0)
        finally:
            w.budget.write_bytes(budget_bytes)
        self.assertEqual(len(w.server.journal), before, "no wire request is possible after a binding drift")

    def test_prepare_rejects_missing_or_foreign_publication_proof(self):
        w = self.world
        bogus = w.dir / "bogus-receipt.json"
        bogus.write_text("{}")
        result = run("bash", PROOF, "--prepare", "--publication", bogus, "--manifest", w.manifest_path, "--repo-root", w.repo,
                     "--output", w.dir / "never.json", cwd=ROOT)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((w.dir / "never.json").exists())
        empty = run("bash", PROOF, "--prepare", "--publication", w.dir / "absent.json", "--manifest", w.manifest_path,
                    "--output", w.dir / "never.json", cwd=ROOT)
        self.assertNotEqual(empty.returncode, 0)

    # ------------------------------------------------------------------------------ completion CLI
    def test_completion_cli_keeps_synthetic_chain_open_and_never_accepts_it(self):
        w = self.world
        normal, docs = w.dir / "normal-attached.json", w.dir / "docs-attached.json"
        normal.write_text(json.dumps(self.normal))
        docs.write_text(json.dumps(self.docs))
        link = lambda path: {"path": str(path), "sha256": sha(pathlib.Path(path).read_bytes())}
        evidence = {"schema_version": "sigra.phase253.completion-evidence/v1", "repository": "szTheory/sigra",
                    "links": {"pr_normal": link(normal), "pr_docs_only": link(docs)}}
        path = w.dir / "completion.json"
        path.write_text(json.dumps(evidence))
        open_record = run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", "--mode", "completion", "--evidence", path, cwd=ROOT, timeout=180)
        self.assertEqual(open_record.returncode, 0, open_record.stderr)
        result = json.loads(open_record.stdout)
        self.assertEqual(result["status"], "open")
        self.assertEqual(result["requirements"], {"CIREL-01": "open", "CIREL-02": "open"})
        self.assertEqual(result["phase_verification"], "not_started")
        self.assertTrue(any(gap.startswith("synthetic:pr") for gap in result["gaps"]))
        strict = run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", "--mode", "completion", "--require-accepted", "--evidence", path,
                     cwd=ROOT, timeout=180)
        self.assertNotEqual(strict.returncode, 0)
        forged = dict(evidence, accepted=True, status="accepted")
        path.write_text(json.dumps(forged))
        claim = run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", "--mode", "completion", "--evidence", path, cwd=ROOT, timeout=180)
        self.assertNotEqual(claim.returncode, 0, "an embedded acceptance claim cannot override missing or synthetic links")
        stale = dict(evidence, links={"pr_normal": {"path": str(normal), "sha256": "0" * 64}})
        path.write_text(json.dumps(stale))
        self.assertNotEqual(run("python3", ROOT / "scripts/ci/ci-hosted-gate-verify.py", "--mode", "completion", "--evidence", path,
                                cwd=ROOT, timeout=180).returncode, 0)


class SectionApprovalTests(unittest.TestCase):
    """Live collector modes need the committed docs_and_prs approval and may create only the listed PRs (253-91)."""

    def refused(self, world, family, **kwargs):
        process, evidence = world.collect(family, "refused.json", check=False, **kwargs)
        self.assertNotEqual(process.returncode, 0, process.stdout)
        self.assertIn("approval", (process.stderr + process.stdout).lower())
        self.assertEqual(world.server.journal, [], "a request left the process before the approval was accepted")
        self.assertFalse(world.ledger.exists())
        self.assertFalse(evidence.exists())

    def test_every_live_family_mode_refuses_each_unapproved_or_wrongly_scoped_approval_before_any_request(self):
        world = World(self, tag="approval")
        whole = sha(load(ROOT / "scripts/ci/ci-git-publication.py", "publisher").canonical_bytes(
            json.loads(world.canary_freeze_path.read_text())["outward_actions"]))
        cases = {
            "absent": dict(approval=None),
            "canary section": dict(approval=world.write_approval("canary", "c1", commit=True)),
            "whole manifest": dict(approval=world.write_approval("docs_and_prs", "c2", commit=True, section_sha=whole)),
            "uncommitted": dict(approval=world.write_approval("docs_and_prs", "c3")),
            "modified": dict(approval=world.write_approval("docs_and_prs", "c4", commit=True, tamper=True)),
            "rejected": dict(approval=world.write_approval("docs_and_prs", "c5", commit=True, decision="reject")),
            "no freeze": dict(revision_freeze=None),
        }
        for family in ("normal", "docs-only"):
            for label, kwargs in cases.items():
                with self.subTest(family=family, case=label):
                    self.refused(world, family, **kwargs)

    def test_prepare_rejects_a_hermetic_publication_origin_when_live_acceptance_is_required(self):
        world = World(self, tag="live-origin")
        refused = run("bash", PROOF, "--prepare", "--publication", world.receipt_path, "--manifest", world.manifest_path,
                      "--repo-root", world.repo, "--output", world.dir / "live-freeze.json", "--poll-interval", "0",
                      "--budget-document", world.budget, "--require-live-origin", cwd=ROOT, timeout=60)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("live acceptance", refused.stderr)
        self.assertFalse((world.dir / "live-freeze.json").exists())

    def test_existing_evidence_is_never_overwritten_by_a_later_collection(self):
        world = World(self, tag="no-overwrite")
        _, path = world.collect("normal", "once.json")
        before, requests = path.read_bytes(), len(world.server.journal)
        again, _ = world.collect("normal", "once.json", check=False)
        self.assertNotEqual(again.returncode, 0)
        self.assertIn("already exists", again.stderr)
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(len(world.server.journal), requests)

    def test_docs_objects_in_the_ledger_are_reused_only_when_they_are_the_complete_frozen_publication(self):
        world = World(self, flags={"refuse_pr_create": True}, tag="docs-tamper")
        first, _ = world.collect("docs-only", "first.json", check=False)
        self.assertEqual(first.returncode, 1)
        ledger = json.loads(world.ledger.read_text())
        for tx in ledger["transactions"]:
            if tx["route_id"] == "create_ref":
                body = json.loads(base64.b64decode(tx["response_body_base64"]))
                body["object"]["sha"] = "f" * 40
                tx["response_body_base64"] = enc(json.dumps(body).encode())
                break
        world.ledger.write_text(json.dumps(ledger))
        published = len(world.server.journal)
        world.server.flags.pop("refuse_pr_create")
        second, path = world.collect("docs-only", "second.json", check=False)
        self.assertEqual(second.returncode, 1)
        self.assertEqual(len(world.server.journal), published, "a request left the process after the ledger failed the readback")
        self.assertIn("complete frozen two-stage", json.loads(path.read_text())["collection"]["stop"])

    def test_a_freeze_that_fails_the_full_policy_is_refused_even_with_a_matching_approval(self):
        world = World(self, tag="policy")
        freeze = json.loads(world.canary_freeze_path.read_text())
        freeze["scenarios"]["optional_infrastructure_retry"] = 1  # a rerun left available
        world.canary_freeze_path.write_text(json.dumps(freeze, indent=2))
        process, evidence = world.collect("normal", "policy.json", check=False)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn("approval refused", process.stderr)
        self.assertEqual(world.server.journal, [])
        self.assertFalse(evidence.exists())

    def test_prepare_and_check_only_stay_network_free_and_need_no_approval(self):
        world = World(self, tag="no-approval-needed")
        checked = run("bash", PROOF, "--check-only", "--freeze", world.freeze_path, "--allocation", world.allocation_path, cwd=ROOT)
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual(world.server.journal, [])

    def test_pr_create_that_differs_from_the_approved_section_is_refused_before_any_request(self):
        def other_base(sections):
            next(a for a in sections["docs_and_prs"]["actions"] if a.get("family") == "normal")["base"] = "release"
        def not_draft(sections):
            next(a for a in sections["docs_and_prs"]["actions"] if a.get("family") == "docs-only")["draft"] = False
        def other_head(sections):
            next(a for a in sections["docs_and_prs"]["actions"] if a.get("family") == "docs-only")["head"] = "gsd/253-replan-candidate"
        for label, family, mutate in (("base differs", "normal", other_base), ("not a draft", "docs-only", not_draft),
                                      ("head differs", "docs-only", other_head)):
            with self.subTest(label=label):
                world = World(self, tag="listed", mutate_section=mutate)
                process, evidence = world.collect(family, "listed.json", check=False)
                self.assertNotEqual(process.returncode, 0)
                self.assertIn("approval refused", process.stderr)
                self.assertIn("outward_actions", process.stderr)
                self.assertFalse(any(row["method"] == "POST" and row["path"].endswith("/pulls") for row in world.server.journal))
                self.assertEqual(world.server.journal, [])

    def test_the_action_approval_record_is_written_before_the_first_request(self):
        world = World(self, tag="record-first")
        evidence = world.dir / "first.json"
        seen = {}
        world.server.first_hook = lambda: seen.update(evidence=json.loads(evidence.read_text()) if evidence.exists() else None)
        process, path = world.collect("normal", "first.json")
        self.assertIsNotNone(seen["evidence"], "evidence did not exist when the first request arrived")
        record = seen["evidence"]["action_approval"]
        self.assertEqual(set(record), {"path", "sha256", "section", "section_sha256", "commit", "window_wall_start_epoch"})
        self.assertEqual(record["section"], "docs_and_prs")
        self.assertEqual(record["section_sha256"], world.digests["docs_and_prs"])
        self.assertEqual(record["commit"], git(world.repo, "rev-list", "-1", "HEAD", "--", str(world.approval_path.relative_to(world.repo))).decode().strip())
        final = json.loads(path.read_text())
        self.assertEqual(final["action_approval"], record)
        evidence_value = attach_journal(path, list(world.server.journal))
        result = verifier.verify_pr_family(evidence_value, "normal")
        self.assertIsNotNone(result, "the existing PR verifier must tolerate the extra top-level action_approval key")

    def test_docs_only_collection_reuses_docs_objects_already_published_in_the_shared_ledger(self):
        world = World(self, flags={"refuse_pr_create": True}, tag="docs-already-published")
        first, _ = world.collect("docs-only", "first.json", check=False)
        self.assertEqual(first.returncode, 1)
        published = len(world.server.journal)
        world.server.flags.pop("refuse_pr_create")
        world.server.model["numbers"][:] = [102]  # the docs-only family is PR 102 in this world; normal never ran
        second, path = world.collect("docs-only", "second.json", check=False)
        self.assertNotIn("docs publication is only partially", second.stdout)
        later = world.server.journal[published:]
        self.assertFalse(any(row["method"] == "POST" and row["path"].endswith(("/trees", "/commits", "/refs")) for row in later),
                         "docs objects already published under the docs_publication category were published again")
        counted = [tx for tx in json.loads(path.read_text())["transport_ledger"]["transactions"] if tx.get("category") == "docs_publication"]
        self.assertEqual(len(counted), 14)


class RefPairTests(unittest.TestCase):
    """253-102: the normal PR head is the freeze-selected candidate ref, one of exactly two code-pinned names."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.r8 = World(cls.holder, tag="r8", ref_pair="r8", seed_legacy_refs=True)
        cls.legacy = World(cls.holder, tag="legacy-pair", ref_pair="legacy")

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    def retarget(self, world, head_ref, name):
        """A copy of the world's PR freeze whose normal head is head_ref, re-digested, plus an allocation bound to it."""
        freeze = json.loads(world.freeze_path.read_text())
        freeze["normal"]["head_ref"] = head_ref
        freeze["freeze_sha256"] = sha(json.dumps({k: v for k, v in freeze.items() if k != "freeze_sha256"}, sort_keys=True,
                                                 ensure_ascii=False, separators=(",", ":")).encode())
        path = world.dir / f"{name}-freeze.json"
        path.write_text(json.dumps(freeze, indent=2, sort_keys=True) + "\n")
        allocation = world.dir / f"{name}-allocation.json"
        allocation.write_text(json.dumps({**world.allocation, "source_sha256": sha(path.read_bytes())}))
        return path, allocation

    def collect_with(self, world, family, freeze, allocation, name):
        evidence = world.dir / f"{name}.json"
        process = run("bash", PROOF, "--family", family, "--freeze", freeze, "--allocation", allocation, "--evidence", evidence,
                      "--requests", world.dir / f"{name}-ledger.json", "--repo-root", world.repo,
                      "--revision-freeze", world.canary_freeze_path, "--action-approval", world.approval_path, cwd=ROOT, timeout=600)
        return process, evidence

    def test_an_r8_freeze_yields_the_r8_head_and_the_normal_family_verifies_beside_seeded_legacy_refs(self):
        w = self.r8
        canary = json.loads(w.canary_freeze_path.read_text())
        self.assertEqual(canary["identity"]["candidate_ref"], "refs/heads/gsd/253-replan-r8-candidate")
        self.assertEqual(json.loads(w.receipt_path.read_text())["candidate_ref"], "refs/heads/gsd/253-replan-r8-candidate")
        self.assertEqual(w.freeze["normal"]["head_ref"], "gsd/253-replan-r8-candidate")
        self.assertEqual((w.freeze["docs-only"]["head_ref"], w.freeze["docs-only"]["base_ref"]),
                         ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base"))
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "a seeded legacy ref changed")
        self.assertEqual(w.server.refs["gsd/253-replan-r8-candidate"], w.manifest["candidate_helper_commit"])
        before = len(w.server.journal)
        _, path = w.collect("normal", "r8-normal.json")
        evidence = attach_journal(path, list(w.server.journal[before:]))
        result = verifier.verify_pr_family(copy.deepcopy(evidence), "normal")
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        created = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "pr_create"]
        self.assertEqual(len(created), 1)
        self.assertEqual(json.loads(base64.b64decode(created[0]["response_body_base64"]))["head"]["ref"], "gsd/253-replan-r8-candidate")
        for head in ("gsd/253-replan-r11-candidate", "gsd/253-replan-r8-fixture", "gsd/253-replan-candidate"):
            with self.subTest(verifier_head=head):
                tampered = copy.deepcopy(evidence)
                tampered["freeze"]["normal"]["head_ref"] = head
                tampered["freeze"]["freeze_sha256"] = sha(json.dumps({k: v for k, v in tampered["freeze"].items() if k != "freeze_sha256"},
                                                                     sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode())
                with self.assertRaises(verifier.VerificationError):
                    verifier.verify_pr_family(tampered, "normal")

    def test_a_legacy_freeze_still_yields_the_legacy_head(self):
        self.assertEqual(json.loads(self.legacy.canary_freeze_path.read_text())["identity"]["candidate_ref"],
                         "refs/heads/gsd/253-replan-candidate")
        self.assertEqual(self.legacy.freeze["normal"]["head_ref"], "gsd/253-replan-candidate")
        self.assertEqual(self.legacy.server.refs["gsd/253-replan-candidate"], self.legacy.manifest["candidate_helper_commit"])

    def test_prepare_refuses_a_receipt_naming_a_third_candidate_or_the_fixture_as_candidate(self):
        w = self.r8
        original = json.loads(w.receipt_path.read_text())
        for label, (candidate_ref, fixture_ref) in {
                "fourth candidate": ("refs/heads/gsd/253-replan-r11-candidate", "refs/heads/gsd/253-replan-r11-fixture"),
                "fixture as candidate": ("refs/heads/gsd/253-replan-r8-fixture", "refs/heads/gsd/253-replan-r8-fixture"),
                "mixed pair": ("refs/heads/gsd/253-replan-r8-candidate", "refs/heads/gsd/253-replan-fixture")}.items():
            with self.subTest(label=label):
                tampered = copy.deepcopy(original)
                tampered["candidate_ref"], tampered["fixture_ref"] = candidate_ref, fixture_ref
                for row in tampered["server_object_receipts"]:
                    if row.get("kind") == "ref":
                        row["ref"] = candidate_ref if row["variant"] == "candidate" else fixture_ref
                receipt = w.dir / "tampered-receipt.json"
                receipt.write_text(json.dumps(tampered))
                output = w.dir / "never-freeze.json"
                result = run("bash", PROOF, "--prepare", "--publication", receipt, "--manifest", w.manifest_path, "--repo-root", w.repo,
                             "--output", output, "--poll-interval", "0", "--budget-document", w.budget, cwd=ROOT, timeout=60)
                self.assertNotEqual(result.returncode, 0, label)
                self.assertFalse(output.exists())

    def test_check_only_accepts_only_the_four_candidate_names_as_the_normal_head(self):
        w = self.legacy
        for head in ("gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-r9-candidate",
                     "gsd/253-replan-r10-candidate"):
            with self.subTest(accepted=head):
                freeze, allocation = self.retarget(w, head, "known")
                checked = run("bash", PROOF, "--check-only", "--freeze", freeze, "--allocation", allocation, cwd=ROOT)
                self.assertEqual(checked.returncode, 0, checked.stderr)
        for head in ("gsd/253-replan-r11-candidate", "gsd/253-replan-fixture", "gsd/253-replan-r8-fixture", "gsd/253-replan-r9-fixture",
                     "gsd/253-replan-r10-fixture",
                     "gsd/253-replan-docs-head", "refs/heads/gsd/253-replan-candidate"):
            with self.subTest(refused=head):
                freeze, allocation = self.retarget(w, head, "unknown")
                checked = run("bash", PROOF, "--check-only", "--freeze", freeze, "--allocation", allocation, cwd=ROOT)
                self.assertNotEqual(checked.returncode, 0)
                self.assertIn("refs are not the exact proof refs", checked.stderr)

    def test_a_pr_head_that_disagrees_with_the_revision_freeze_candidate_is_refused_before_any_request(self):
        for world, head in ((self.legacy, "gsd/253-replan-r8-candidate"), (self.r8, "gsd/253-replan-candidate")):
            for family in ("normal", "docs-only"):
                with self.subTest(world=world.ref_pair, family=family):
                    freeze, allocation = self.retarget(world, head, f"disagree-{family}")
                    before = len(world.server.journal)
                    process, evidence = self.collect_with(world, family, freeze, allocation, f"disagree-{family}")
                    self.assertNotEqual(process.returncode, 0)
                    self.assertIn("revision freeze candidate_ref", process.stderr)
                    self.assertEqual(len(world.server.journal), before, "a request left the process with a disagreeing head")
                    self.assertFalse(evidence.exists())


class R9RefPairTests(unittest.TestCase):
    """253-111: an r9 freeze yields the r9 normal head beside the seeded r8 refs 253-104 left on GitHub."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.r9 = World(cls.holder, tag="r9", ref_pair="r9", seed_r8_refs=True)
        cls.r8 = World(cls.holder, tag="r8-for-r9", ref_pair="r8")

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    retarget = RefPairTests.retarget
    collect_with = RefPairTests.collect_with

    def test_an_r9_freeze_yields_the_r9_head_and_the_normal_family_verifies_beside_seeded_r8_refs(self):
        w = self.r9
        canary = json.loads(w.canary_freeze_path.read_text())
        self.assertEqual(canary["identity"]["candidate_ref"], "refs/heads/gsd/253-replan-r9-candidate")
        self.assertEqual(canary["identity"]["fixture_ref"], "refs/heads/gsd/253-replan-r9-fixture")
        self.assertEqual(json.loads(w.receipt_path.read_text())["candidate_ref"], "refs/heads/gsd/253-replan-r9-candidate")
        self.assertEqual(w.freeze["normal"]["head_ref"], "gsd/253-replan-r9-candidate")
        self.assertEqual((w.freeze["docs-only"]["head_ref"], w.freeze["docs-only"]["base_ref"]),
                         ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base"))
        self.assertEqual(set(w.seeded_refs), {"gsd/253-replan-r8-candidate", "gsd/253-replan-r8-fixture"})
        self.assertEqual(w.server.refs["gsd/253-replan-r9-candidate"], w.manifest["candidate_helper_commit"])
        before = len(w.server.journal)
        _, path = w.collect("normal", "r9-normal.json")
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "a seeded r8 ref changed")
        self.assertFalse([row for row in w.server.journal if "253-replan-r8-" in row["path"]], "the r9 PR window touched an r8 ref")
        evidence = attach_journal(path, list(w.server.journal[before:]))
        result = verifier.verify_pr_family(copy.deepcopy(evidence), "normal")
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        created = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "pr_create"]
        self.assertEqual(len(created), 1)
        self.assertEqual(json.loads(base64.b64decode(created[0]["response_body_base64"]))["head"]["ref"], "gsd/253-replan-r9-candidate")
        for head in ("gsd/253-replan-r11-candidate", "gsd/253-replan-r9-fixture", "gsd/253-replan-r8-candidate", "gsd/253-replan-candidate"):
            with self.subTest(verifier_head=head):
                tampered = copy.deepcopy(evidence)
                tampered["freeze"]["normal"]["head_ref"] = head
                tampered["freeze"]["freeze_sha256"] = sha(json.dumps({k: v for k, v in tampered["freeze"].items() if k != "freeze_sha256"},
                                                                     sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode())
                with self.assertRaises(verifier.VerificationError):
                    verifier.verify_pr_family(tampered, "normal")

    def test_an_r8_freeze_still_yields_the_r8_head(self):
        self.assertEqual(json.loads(self.r8.canary_freeze_path.read_text())["identity"]["candidate_ref"],
                         "refs/heads/gsd/253-replan-r8-candidate")
        self.assertEqual(self.r8.freeze["normal"]["head_ref"], "gsd/253-replan-r8-candidate")

    def test_prepare_refuses_an_r9_receipt_with_a_fourth_name_a_fixture_head_or_a_mixed_pair(self):
        w = self.r9
        original = json.loads(w.receipt_path.read_text())
        for label, (candidate_ref, fixture_ref) in {
                "fourth candidate": ("refs/heads/gsd/253-replan-r11-candidate", "refs/heads/gsd/253-replan-r11-fixture"),
                "fixture as candidate": ("refs/heads/gsd/253-replan-r9-fixture", "refs/heads/gsd/253-replan-r9-fixture"),
                "r9 candidate, r8 fixture": ("refs/heads/gsd/253-replan-r9-candidate", "refs/heads/gsd/253-replan-r8-fixture"),
                "r8 candidate, r9 fixture": ("refs/heads/gsd/253-replan-r8-candidate", "refs/heads/gsd/253-replan-r9-fixture")}.items():
            with self.subTest(label=label):
                tampered = copy.deepcopy(original)
                tampered["candidate_ref"], tampered["fixture_ref"] = candidate_ref, fixture_ref
                for row in tampered["server_object_receipts"]:
                    if row.get("kind") == "ref":
                        row["ref"] = candidate_ref if row["variant"] == "candidate" else fixture_ref
                receipt = w.dir / "tampered-r9-receipt.json"
                receipt.write_text(json.dumps(tampered))
                output = w.dir / "never-r9-freeze.json"
                result = run("bash", PROOF, "--prepare", "--publication", receipt, "--manifest", w.manifest_path, "--repo-root", w.repo,
                             "--output", output, "--poll-interval", "0", "--budget-document", w.budget, cwd=ROOT, timeout=60)
                self.assertNotEqual(result.returncode, 0, label)
                self.assertFalse(output.exists())

    def test_an_r9_or_r8_pr_head_disagreeing_with_the_revision_freeze_is_refused_before_any_request(self):
        for world, head in ((self.r9, "gsd/253-replan-r8-candidate"), (self.r8, "gsd/253-replan-r9-candidate")):
            for family in ("normal", "docs-only"):
                with self.subTest(world=world.ref_pair, family=family):
                    freeze, allocation = self.retarget(world, head, f"r9-disagree-{family}")
                    before = len(world.server.journal)
                    process, evidence = self.collect_with(world, family, freeze, allocation, f"r9-disagree-{family}")
                    self.assertNotEqual(process.returncode, 0)
                    self.assertIn("revision freeze candidate_ref", process.stderr)
                    self.assertEqual(len(world.server.journal), before, "a request left the process with a disagreeing head")
                    self.assertFalse(evidence.exists())


class R10RefPairTests(unittest.TestCase):
    """253-119: an r10 freeze yields the r10 normal head beside the seeded r8 and r9 refs left on GitHub."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.r10 = World(cls.holder, tag="r10", ref_pair="r10", seed_r8_refs=True, seed_r9_refs=True)
        cls.r9 = World(cls.holder, tag="r9-for-r10", ref_pair="r9")

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    retarget = RefPairTests.retarget
    collect_with = RefPairTests.collect_with

    def test_an_r10_freeze_yields_the_r10_head_and_the_normal_family_verifies_beside_seeded_r8_and_r9_refs(self):
        w = self.r10
        canary = json.loads(w.canary_freeze_path.read_text())
        self.assertEqual(canary["identity"]["candidate_ref"], "refs/heads/gsd/253-replan-r10-candidate")
        self.assertEqual(canary["identity"]["fixture_ref"], "refs/heads/gsd/253-replan-r10-fixture")
        self.assertEqual(json.loads(w.receipt_path.read_text())["candidate_ref"], "refs/heads/gsd/253-replan-r10-candidate")
        self.assertEqual(w.freeze["normal"]["head_ref"], "gsd/253-replan-r10-candidate")
        self.assertEqual((w.freeze["docs-only"]["head_ref"], w.freeze["docs-only"]["base_ref"]),
                         ("gsd/253-replan-docs-head", "gsd/253-replan-docs-base"))
        self.assertEqual(set(w.seeded_refs), {"gsd/253-replan-r8-candidate", "gsd/253-replan-r8-fixture",
                                              "gsd/253-replan-r9-candidate", "gsd/253-replan-r9-fixture"})
        self.assertEqual(w.server.refs["gsd/253-replan-r10-candidate"], w.manifest["candidate_helper_commit"])
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "the r10 publication changed a seeded r8 or r9 ref")
        before = len(w.server.journal)
        _, path = w.collect("normal", "r10-normal.json")
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "a seeded r8 or r9 ref changed")
        self.assertTrue([row for row in w.server.journal if "/pulls" in row["path"]], "positive control: the PR window made requests")
        self.assertFalse([row for row in w.server.journal if "253-replan-r8-" in row["path"] or "253-replan-r9-" in row["path"]],
                         "the r10 publication or PR window touched an r8 or r9 ref")
        evidence = attach_journal(path, list(w.server.journal[before:]))
        result = verifier.verify_pr_family(copy.deepcopy(evidence), "normal")
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        created = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "pr_create"]
        self.assertEqual(len(created), 1)
        self.assertEqual(json.loads(base64.b64decode(created[0]["response_body_base64"]))["head"]["ref"], "gsd/253-replan-r10-candidate")
        for head in ("gsd/253-replan-r11-candidate", "gsd/253-replan-r10-fixture", "gsd/253-replan-r9-candidate",
                     "gsd/253-replan-r8-candidate", "gsd/253-replan-candidate"):
            with self.subTest(verifier_head=head):
                tampered = copy.deepcopy(evidence)
                tampered["freeze"]["normal"]["head_ref"] = head
                tampered["freeze"]["freeze_sha256"] = sha(json.dumps({k: v for k, v in tampered["freeze"].items() if k != "freeze_sha256"},
                                                                     sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode())
                with self.assertRaises(verifier.VerificationError):
                    verifier.verify_pr_family(tampered, "normal")

    def test_an_r9_freeze_still_yields_the_r9_head(self):
        self.assertEqual(json.loads(self.r9.canary_freeze_path.read_text())["identity"]["candidate_ref"],
                         "refs/heads/gsd/253-replan-r9-candidate")
        self.assertEqual(self.r9.freeze["normal"]["head_ref"], "gsd/253-replan-r9-candidate")

    def test_prepare_refuses_an_r10_receipt_with_a_fifth_name_a_fixture_head_or_a_mixed_pair(self):
        w = self.r10
        original = json.loads(w.receipt_path.read_text())
        for label, (candidate_ref, fixture_ref) in {
                "fifth candidate": ("refs/heads/gsd/253-replan-r11-candidate", "refs/heads/gsd/253-replan-r11-fixture"),
                "fixture as candidate": ("refs/heads/gsd/253-replan-r10-fixture", "refs/heads/gsd/253-replan-r10-fixture"),
                "r10 candidate, r9 fixture": ("refs/heads/gsd/253-replan-r10-candidate", "refs/heads/gsd/253-replan-r9-fixture"),
                "r9 candidate, r10 fixture": ("refs/heads/gsd/253-replan-r9-candidate", "refs/heads/gsd/253-replan-r10-fixture"),
                "r10 candidate, r8 fixture": ("refs/heads/gsd/253-replan-r10-candidate", "refs/heads/gsd/253-replan-r8-fixture")}.items():
            with self.subTest(label=label):
                tampered = copy.deepcopy(original)
                tampered["candidate_ref"], tampered["fixture_ref"] = candidate_ref, fixture_ref
                for row in tampered["server_object_receipts"]:
                    if row.get("kind") == "ref":
                        row["ref"] = candidate_ref if row["variant"] == "candidate" else fixture_ref
                receipt = w.dir / "tampered-r10-receipt.json"
                receipt.write_text(json.dumps(tampered))
                output = w.dir / "never-r10-freeze.json"
                result = run("bash", PROOF, "--prepare", "--publication", receipt, "--manifest", w.manifest_path, "--repo-root", w.repo,
                             "--output", output, "--poll-interval", "0", "--budget-document", w.budget, cwd=ROOT, timeout=60)
                self.assertNotEqual(result.returncode, 0, label)
                self.assertFalse(output.exists())

    def test_an_r10_or_r9_pr_head_disagreeing_with_the_revision_freeze_is_refused_before_any_request(self):
        for world, head in ((self.r10, "gsd/253-replan-r9-candidate"), (self.r9, "gsd/253-replan-r10-candidate")):
            for family in ("normal", "docs-only"):
                with self.subTest(world=world.ref_pair, family=family):
                    freeze, allocation = self.retarget(world, head, f"r10-disagree-{family}")
                    before = len(world.server.journal)
                    process, evidence = self.collect_with(world, family, freeze, allocation, f"r10-disagree-{family}")
                    self.assertNotEqual(process.returncode, 0)
                    self.assertIn("revision freeze candidate_ref", process.stderr)
                    self.assertEqual(len(world.server.journal), before, "a request left the process with a disagreeing head")
                    self.assertFalse(evidence.exists())


class CollectorFaultTests(unittest.TestCase):
    def collected(self, flags, family="normal"):
        world = World(self, flags=flags, tag="fault")
        process, evidence = world.collect(family, "fault.json", check=False)
        return world, process, json.loads(evidence.read_text())

    def test_refused_pr_creation_preserves_the_charged_failure_and_is_never_accepted(self):
        world, process, evidence = self.collected({"refuse_pr_create": True})
        self.assertEqual(process.returncode, 1)
        self.assertIn("pr_create", evidence["collection"]["stop"])
        ledger = json.loads(world.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), len(world.server.journal))
        self.assertEqual(ledger["transactions"][-1]["actual_status"], 422)
        self.assertTrue(all(row["charged"] for row in world.server.journal))
        evidence["server_journal"] = world.server.journal
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_pr_family(evidence, "normal")

    def test_never_finishing_run_stops_at_the_frozen_poll_allocation_without_extra_requests(self):
        world, process, evidence = self.collected({"never_finish": True})
        self.assertEqual(process.returncode, 1)
        ledger = json.loads(world.ledger.read_text())
        polls = [tx for tx in ledger["transactions"] if tx["route_id"] == "run"]
        self.assertEqual(len(polls), 15, "normal terminal polls are capped at their frozen allocation")
        self.assertEqual(len(ledger["transactions"]), len(world.server.journal))
        self.assertIn("terminal state", evidence["collection"]["stop"])
        evidence["server_journal"] = world.server.journal
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_pr_family(evidence, "normal")

    def test_core_rate_floor_is_a_terminal_stop_before_any_later_request(self):
        world, process, evidence = self.collected({"core_floor": True})
        self.assertEqual(process.returncode, 1)
        self.assertEqual(len(world.server.journal), 1)
        ledger = json.loads(world.ledger.read_text())
        self.assertEqual(ledger["terminal_stop"]["code"], "core_budget_stop")
        again, _ = world.collect("normal", "second.json", check=False)
        self.assertNotEqual(again.returncode, 0)
        self.assertEqual(len(world.server.journal), 1, "a terminal ledger refuses a later collector run")


class LivePolicyPRTests(unittest.TestCase):
    """253-109: the normal (and docs-only) PR family through the LIVE transport policy, offline, zero GitHub requests."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.world = LiveWorld(cls.holder, tag="live-main")
        w = cls.world
        cls.normal_process, cls.normal_path = w.collect("normal", "live-normal.json", check=False)
        cls.normal_requests = len(w.server.journal)
        cls.normal_sleeps = list(w.sleeps())
        cls.docs_process, cls.docs_path = w.collect("docs-only", "live-docs.json", check=False)
        cls.all_sleeps = list(w.sleeps())

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    def normal_collected(self):
        process = self.normal_process
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        return json.loads(self.normal_path.read_text())

    def test_live_policy_universe_uses_live_publication_and_production_allocations_with_no_test_fields(self):
        w = self.world
        allocation = json.loads(w.allocation_path.read_text())
        self.assertEqual((allocation["mode"], allocation["allocation_kind"], allocation["max_requests"]), ("live", "production", 120))
        self.assertEqual(allocation["category_limits"], transport.PRODUCTION_CATEGORY_LIMITS)
        self.assertEqual(allocation["download_hosts"], TRUSTED_DOWNLOAD_HOSTS)
        self.assertIn(BLOB_HOST, allocation["download_hosts"])
        self.assertFalse({"test_origin", "test_ca_file"} & set(allocation), "a live allocation carries no test fields")
        self.assertTrue(allocation["window_id"].startswith("253-dryrun-live-policy-"))
        transport._validate_allocation(allocation)
        publication = json.loads((w.dir / "publication-allocation.json").read_text())
        self.assertEqual((publication["mode"], publication["allocation_kind"]), ("live", "canary"))
        self.assertFalse({"test_origin", "test_ca_file"} & set(publication))
        receipt = json.loads(w.receipt_path.read_text())
        self.assertEqual(receipt["origin"]["kind"], "actual-github", "the seed publication ran through the live origin path")
        self.assertTrue(receipt["origin"]["window_id"].startswith("253-dryrun-live-policy-"))
        self.assertTrue(verifier.dryrun_window(receipt), "the verifier's dry-run guard labels the live-policy receipt")
        publication_ledger = json.loads(w.ledger_path.read_text())
        self.assertEqual({tx["host"] for tx in publication_ledger["transactions"]}, {API_HOST})

    def test_live_policy_normal_family_collects_and_verifies_end_to_end_as_synthetic(self):
        evidence = self.normal_collected()
        self.assertEqual(json.loads(self.normal_process.stdout.strip().splitlines()[-1])["status"], "collected")
        self.assertIs(evidence["synthetic"], False, "the collector labels by allocation mode; the verifier's window guard labels it")
        self.assertIsNone(evidence["server_journal"])
        process, result = run_verifier("--mode", "pr", "--family", "normal", "--evidence", self.normal_path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        self.assertIs(result["synthetic"], True)
        self.assertIs(result["accepted_live"], False, "a 253-dryrun- window is never live acceptance")
        self.assertTrue(result["window_id"].startswith("253-dryrun-live-policy-"))
        self.assertEqual(result["merge_sha"], "c" * 40)

    def test_live_policy_normal_producer_zips_take_one_302_hop_from_api_to_the_trusted_blob_host(self):
        evidence = self.normal_collected()
        transactions = evidence["transport_ledger"]["transactions"]
        groups = {}
        for tx in transactions:
            if tx["route_id"] == "artifact_zip":
                groups.setdefault(tx["request_group"], []).append(tx)
        self.assertEqual(len(groups), 5)
        for group in groups.values():
            group.sort(key=lambda tx: tx["hop_ordinal"])
            self.assertEqual([(tx["hop_ordinal"], tx["host"], tx["actual_status"]) for tx in group],
                             [(0, API_HOST, 302), (1, BLOB_HOST, 200)])
            self.assertTrue(group[1]["url"].startswith(f"https://{BLOB_HOST}/blob/") and group[1]["url"].endswith("?[REDACTED]"))
        allowed = {API_HOST, *json.loads(self.world.allocation_path.read_text())["download_hosts"]}
        self.assertTrue(all(tx["host"] in allowed for tx in transactions))
        self.assertEqual({tx["host"] for tx in transactions if tx["route_id"] != "artifact_zip"}, {API_HOST})
        self.assertNotIn("fixture-secret", self.world.ledger.read_text() + self.normal_path.read_text())

    def test_live_policy_token_reaches_api_github_only_and_the_shim_refused_nothing(self):
        self.normal_collected()
        w = self.world
        journal = w.server.journal[:self.normal_requests]
        ledger = json.loads(w.ledger.read_text())["transactions"][:self.normal_requests]
        self.assertEqual(len(journal), len(ledger), "every charged transaction reached the fake exactly once")
        self.assertEqual([row["host"] for row in journal], [tx["host"] for tx in ledger])
        api = [row for row in journal if row["host"] == API_HOST]
        blob = [row for row in journal if row["host"] == BLOB_HOST]
        self.assertEqual(len(blob), 5)
        self.assertEqual(len(api) + len(blob), len(journal))
        self.assertTrue(all(row["authorization"] == f"Bearer {LIVE_TOKEN}" for row in api), "api.github.com needs the dummy token")
        self.assertTrue(all(row["authorization"] is None for row in blob), "the token followed the redirect to the blob host")
        self.assertEqual(w.server.violations, [])
        self.assertEqual(w.refusals(), [], "the shim refused a real network destination")
        self.assertEqual(w.connect_hosts(), sorted({API_HOST, BLOB_HOST}))

    def test_live_policy_waits_are_requested_at_the_frozen_interval_and_only_slept_scaled(self):
        self.normal_collected()
        self.assertEqual(self.world.freeze["poll"]["interval_seconds"], 60)
        # One discovery wait (the run is listable on the second listing) and two terminal-poll waits (done on poll 3).
        self.assertEqual(self.normal_sleeps, [60, 60, 60])

    # ------------------------------------------------------------------ 253-109 Task 3: docs-only, pair, completion
    def docs_collected(self):
        self.normal_collected()
        process = self.docs_process
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        return json.loads(self.docs_path.read_text())

    def test_live_policy_docs_only_family_publishes_its_objects_through_the_live_origin_and_verifies_as_synthetic(self):
        evidence = self.docs_collected()
        self.assertEqual(json.loads(self.docs_process.stdout.strip().splitlines()[-1])["status"], "collected")
        rows = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["category"] == "docs_publication"]
        self.assertEqual(len(rows), 14)
        self.assertEqual({(tx["host"], tx["family"]) for tx in rows}, {(API_HOST, "docs-only")})
        routes = [(tx["route_id"], tx["actual_status"]) for tx in rows]
        creates = [index for index, (route, _) in enumerate(routes) if route == "create_ref"]
        self.assertEqual(len(creates), 2)
        for index in creates:
            self.assertEqual(routes[index - 1], ("get_ref", 404), "every create-only ref is probed absent first")
            self.assertEqual(routes[index], ("create_ref", 201))
            self.assertEqual(routes[index + 1], ("get_ref", 200))
        publisher = load(ROOT / "scripts/ci/ci-git-publication.py", "publisher_for_live_docs")
        allocation = json.loads(self.world.allocation_path.read_text())
        origin = publisher.derive_origin(allocation, {"transactions": rows})
        self.assertEqual(origin["kind"], "actual-github", "the docs objects went through the publisher's live origin rule")
        self.assertTrue(origin["window_id"].startswith("253-dryrun-live-policy-"))
        process, result = run_verifier("--mode", "pr", "--family", "docs-only", "--evidence", self.docs_path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        self.assertIs(result["synthetic"], True)
        self.assertIs(result["accepted_live"], False)
        self.assertEqual(result["merge_sha"], "d" * 40)

    def test_live_docs_commit_readback_tolerates_exactly_one_stripped_trailing_newline(self):
        base = self.docs_collected()
        fresh = lambda: copy.deepcopy(base)
        for nth, frozen in ((0, "Phase 253 docs probe base workflow exception\n"), (1, "Phase 253 docs-only probe head\n")):
            with self.subTest(form="stripped", nth=nth):
                readbacks = [tx for tx in base["transport_ledger"]["transactions"] if tx["route_id"] == "git_get_commit"]
                self.assertEqual(json.loads(base64.b64decode(readbacks[nth]["response_body_base64"]))["message"], frozen[:-1])
                verifier.verify_pr_family(fresh(), "docs-only")
            with self.subTest(form="verbatim", nth=nth):
                verifier.verify_pr_family(retamper(fresh(), "git_get_commit", lambda d: d.update(message=frozen), nth=nth), "docs-only")
        for label, mutate in {
            "extra newline": lambda d: d.update(message=d["message"].rstrip("\n") + "\n\n"),
            "two characters stripped": lambda d: d.update(message=d["message"].rstrip("\n")[:-1]),
            "crlf": lambda d: d.update(message=d["message"].rstrip("\n") + "\r\n"),
            "trailing space": lambda d: d.update(message=d["message"].rstrip("\n") + " "),
            "missing": lambda d: d.pop("message"),
        }.items():
            for nth in (0, 1):
                with self.subTest(label, nth=nth):
                    with self.assertRaises(verifier.VerificationError):
                        verifier.verify_pr_family(retamper(fresh(), "git_get_commit", mutate, nth=nth), "docs-only")

    def test_live_policy_pair_is_one_allocation_one_append_only_window_within_120_requests(self):
        normal, docs = self.normal_collected(), self.docs_collected()
        process, result = run_verifier("--mode", "pr", "--family", "both", "--evidence", self.normal_path,
                                       "--docs-evidence", self.docs_path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "synthetic_pr_pair_verified")
        self.assertIs(result["synthetic"], True)
        self.assertIs(result["accepted_live"], False)
        self.assertEqual(normal["allocation_base64"], docs["allocation_base64"])
        self.assertEqual(normal["transport_ledger"]["window_id"], docs["transport_ledger"]["window_id"])
        self.assertTrue(normal["transport_ledger"]["window_id"].startswith("253-dryrun-live-policy-"))
        shorter, longer = normal["transport_ledger"]["transactions"], docs["transport_ledger"]["transactions"]
        self.assertEqual(longer[:len(shorter)], shorter, "the docs family appended to the same measured window")
        self.assertLessEqual(len(longer), 120)
        self.assertEqual(result["requests"], len(longer))
        hops = [tx for tx in longer if tx["route_id"] == "artifact_zip" and tx["hop_ordinal"] == 1]
        counts = {"normal": len(shorter), "docs-only": len(longer) - len(shorter), "combined": len(longer),
                  "hop1": {family: sum(1 for tx in hops if tx["family"] == family) for family in ("normal", "docs-only")},
                  "categories": {category: sum(1 for tx in longer if tx["category"] == category)
                                 for category in sorted({tx["category"] for tx in longer})}}
        print(f"253-109 live counts: {json.dumps(counts, sort_keys=True)}", file=sys.stderr)

    def test_live_policy_completion_on_the_dry_run_window_is_a_synthetic_gap_and_never_accepted(self):
        self.docs_collected()
        w = self.world
        link = lambda path: {"path": str(path), "sha256": sha(pathlib.Path(path).read_bytes())}
        evidence = {"schema_version": "sigra.phase253.completion-evidence/v1", "repository": "szTheory/sigra",
                    "links": {"pr_normal": link(self.normal_path), "pr_docs_only": link(self.docs_path)}}
        path = w.dir / "live-completion.json"
        path.write_text(json.dumps(evidence))
        process, result = run_verifier("--mode", "completion", "--evidence", path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "open")
        self.assertEqual(result["requirements"]["CIREL-02"], "open")
        self.assertEqual(result["phase_verification"], "not_started")
        for key in ("pr_normal", "pr_docs_only"):
            self.assertIn(f"synthetic:{key}:dry-run window cannot satisfy live acceptance", result["gaps"])
        strict, _ = run_verifier("--mode", "completion", "--require-accepted", "--evidence", path)
        self.assertEqual(strict.returncode, 1)
        self.assertIn("synthetic:pr_normal:dry-run window cannot satisfy live acceptance", strict.stderr)
        path.write_text(json.dumps(dict(evidence, accepted=True, status="accepted")))
        claimed, _ = run_verifier("--mode", "completion", "--evidence", path)
        self.assertEqual(claimed.returncode, 1, "an embedded acceptance claim cannot override a dry-run window")

    def test_live_policy_token_and_host_rules_hold_across_both_families(self):
        docs = self.docs_collected()
        w = self.world
        journal, ledger = w.server.journal, docs["transport_ledger"]["transactions"]
        self.assertEqual(len(journal), len(ledger))
        self.assertEqual([row["host"] for row in journal], [tx["host"] for tx in ledger])
        blob = [row for row in journal if row["host"] == BLOB_HOST]
        api = [row for row in journal if row["host"] == API_HOST]
        self.assertEqual(len(blob), 10, "five producer ZIPs per family")
        self.assertEqual(len(api) + len(blob), len(journal))
        self.assertTrue(all(row["authorization"] is None for row in blob))
        self.assertTrue(all(row["authorization"] == f"Bearer {LIVE_TOKEN}" for row in api))
        allowed = {API_HOST, *json.loads(w.allocation_path.read_text())["download_hosts"]}
        self.assertTrue(all(tx["host"] in allowed for tx in ledger))
        self.assertEqual(w.server.violations, [])
        self.assertEqual(w.refusals(), [])
        self.assertEqual(w.connect_hosts(), sorted({API_HOST, BLOB_HOST}))
        self.assertEqual(self.all_sleeps, [60] * 6, "three frozen 60-second waits per family, slept scaled")

    def test_live_required_check_failure_on_the_pr_head_is_rejected_on_the_live_check_view(self):
        world = LiveWorld(self, tag="live-check-failure")
        failing = next(check for check in world.server.model["families"][101]["checks"] if check["name"] == NAMES[1])
        failing["conclusion"] = "failure"
        process, path = world.collect("normal", "failed-check.json", check=False)
        self.assertEqual(process.returncode, 0, "the collector records the native checks; the verifier judges them")
        recorded = json.loads(path.read_text())
        checks = [tx for tx in recorded["transport_ledger"]["transactions"] if tx["route_id"] == "check_runs"]
        self.assertEqual([tx["host"] for tx in checks], [API_HOST])
        self.assertTrue(checks[0]["url"].startswith("https://api.github.com/"), "the live check view needs no URL rewrite")
        rejected, _ = run_verifier("--mode", "pr", "--family", "normal", "--evidence", path)
        self.assertEqual(rejected.returncode, 1, rejected.stdout)
        self.assertIn(NAMES[1], rejected.stderr)
        self.assertIn("hosted-gate-verify: FAIL", rejected.stderr)
        # Positive control for the zero-violation and zero-Authorization results: the guard records both kinds.
        before = len(world.server.violations)
        context = ssl.create_default_context(cafile=str(world.cert))
        for host, headers in ((BLOB_HOST, {"Authorization": "Bearer probe"}), (API_HOST, {})):
            connection = __import__("http.client").client.HTTPSConnection("localhost", world.port, context=context, timeout=10)
            path = f"/blob/{min(world.server.model['zips'])}?sv=1&sig=1" if host == BLOB_HOST else "/rate_limit"
            connection.request("GET", path, headers={"Host": host, **headers})
            connection.getresponse().read()
            connection.close()
        probes = world.server.violations[before:]
        self.assertTrue(any("Authorization reached the blob host" in item for item in probes), probes)
        self.assertTrue(any("without the dummy bearer token" in item for item in probes), probes)
        # (The fake appends a journal row after writing the response, so search rather than index the latest rows.)
        self.assertTrue(any(row.get("host") == BLOB_HOST and row["authorization"] == "Bearer probe" for row in world.server.journal),
                        "the journal records a present Authorization header")


REDIRECT_FIX_SUBJECT = "allow the live approved-redirect hop"
SUMMARY_107 = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-107-SUMMARY.md"


def redirect_fix_matches():
    """Every commit touching the transport whose message contains the redirect-fix subject (never 'the latest fix')."""
    output = subprocess.check_output(["git", "-C", str(ROOT), "log", "--format=%H", "--fixed-strings",
                                      f"--grep={REDIRECT_FIX_SUBJECT}", "--", "scripts/ci/ci-hosted-transport.py"], text=True)
    return output.split()


def proof_with_transport(test, revision):
    """A temporary copy of scripts/ci (plus the bound workflow) whose ci-hosted-transport.py is that revision's blob.

    The copied ci-pr-proof.sh resolves its ROOT from its own location, so it loads the substituted transport. Only the
    temporary directory is written; the real scripts/ci is untouched."""
    blob = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{revision}:scripts/ci/ci-hosted-transport.py"])
    copy_root = pathlib.Path(tempfile.mkdtemp(prefix="sigra-pr-proof-transport-")).resolve()
    test.addCleanup(shutil.rmtree, copy_root, True)
    shutil.copytree(ROOT / "scripts/ci", copy_root / "scripts/ci", ignore=shutil.ignore_patterns("__pycache__"))
    (copy_root / ".github/workflows").mkdir(parents=True)
    shutil.copyfile(ROOT / ".github/workflows/ci.yml", copy_root / ".github/workflows/ci.yml")
    target = copy_root / "scripts/ci/ci-hosted-transport.py"
    target.write_bytes(blob)
    test.assertEqual(target.read_bytes(), blob)
    return copy_root / "scripts/ci/ci-pr-proof.sh", sha(blob)


class LivePolicyR9PRTests(unittest.TestCase):
    """253-111: the 253-109 live-policy PR universe under an r9 freeze, beside seeded r8 refs, offline."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.world = LiveWorld(cls.holder, tag="live-r9", ref_pair="r9", seed_r8_refs=True)
        cls.normal_process, cls.normal_path = cls.world.collect("normal", "live-r9-normal.json", check=False)

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    def test_live_policy_r9_normal_family_verifies_as_synthetic_with_the_r9_head_and_r8_refs_untouched(self):
        w = self.world
        self.assertEqual(self.normal_process.returncode, 0, self.normal_process.stdout + self.normal_process.stderr)
        self.assertEqual(json.loads(w.receipt_path.read_text())["candidate_ref"], "refs/heads/gsd/253-replan-r9-candidate")
        self.assertEqual(json.loads(w.receipt_path.read_text())["origin"]["kind"], "actual-github")
        self.assertEqual(w.freeze["normal"]["head_ref"], "gsd/253-replan-r9-candidate")
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "a seeded r8 ref changed")
        process, result = run_verifier("--mode", "pr", "--family", "normal", "--evidence", self.normal_path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        self.assertIs(result["synthetic"], True)
        self.assertIs(result["accepted_live"], False)
        evidence = json.loads(self.normal_path.read_text())
        created = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "pr_create"]
        self.assertEqual(len(created), 1)
        self.assertEqual(json.loads(base64.b64decode(created[0]["response_body_base64"]))["head"]["ref"], "gsd/253-replan-r9-candidate")


class LivePolicyR10PRTests(unittest.TestCase):
    """253-119: the 253-109 live-policy PR universe under an r10 freeze, beside seeded r8 and r9 refs, offline."""

    @classmethod
    def setUpClass(cls):
        cls._cleanups = []
        cls.holder = unittest.TestCase()
        cls.holder.addCleanup = lambda fn, *a, **k: cls._cleanups.append((fn, a, k))
        cls.world = LiveWorld(cls.holder, tag="live-r10", ref_pair="r10", seed_r8_refs=True, seed_r9_refs=True)
        cls.normal_process, cls.normal_path = cls.world.collect("normal", "live-r10-normal.json", check=False)

    @classmethod
    def tearDownClass(cls):
        for fn, a, k in reversed(cls._cleanups):
            try:
                fn(*a, **k)
            except Exception:
                pass

    def test_live_policy_r10_normal_family_verifies_as_synthetic_with_the_r10_head_and_r8_r9_refs_untouched(self):
        w = self.world
        self.assertEqual(self.normal_process.returncode, 0, self.normal_process.stdout + self.normal_process.stderr)
        self.assertEqual(json.loads(w.receipt_path.read_text())["candidate_ref"], "refs/heads/gsd/253-replan-r10-candidate")
        self.assertEqual(json.loads(w.receipt_path.read_text())["origin"]["kind"], "actual-github")
        self.assertEqual(w.freeze["normal"]["head_ref"], "gsd/253-replan-r10-candidate")
        self.assertEqual(len(w.seeded_refs), 4)
        for name, value in w.seeded_refs.items():
            self.assertEqual(w.server.refs[name], value, "a seeded r8 or r9 ref changed")
        self.assertFalse([row for row in w.server.journal if "253-replan-r8-" in row["path"] or "253-replan-r9-" in row["path"]],
                         "the live-policy r10 universe touched an r8 or r9 ref")
        process, result = run_verifier("--mode", "pr", "--family", "normal", "--evidence", self.normal_path)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(result["status"], "synthetic_pr_family_verified")
        self.assertIs(result["synthetic"], True)
        self.assertIs(result["accepted_live"], False)
        evidence = json.loads(self.normal_path.read_text())
        created = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "pr_create"]
        self.assertEqual(len(created), 1)
        self.assertEqual(json.loads(base64.b64decode(created[0]["response_body_base64"]))["head"]["ref"], "gsd/253-replan-r10-candidate")


class LivePolicySensitivityTests(unittest.TestCase):
    """253-109: the live-policy PR path fails on the exact 253-104 defect and passes once it is fixed."""

    def fix_commit(self):
        matches = redirect_fix_matches()
        self.assertEqual(len(matches), 1, f"the redirect-fix subject must name exactly one commit: {matches}")
        return matches[0]

    def test_the_redirect_fix_commit_is_resolved_by_its_unique_subject_and_equals_the_253_107_record(self):
        commit = self.fix_commit()
        recorded = re.search(r"^redirect_fix_commit: ([0-9a-f]{40})$", SUMMARY_107.read_text(), re.M)
        self.assertIsNotNone(recorded)
        self.assertEqual(commit, recorded.group(1))
        subject = subprocess.check_output(["git", "-C", str(ROOT), "log", "-1", "--format=%s", commit], text=True).strip()
        self.assertIn(REDIRECT_FIX_SUBJECT, subject)

    def test_the_pre_fix_transport_stops_the_live_normal_family_at_the_first_artifact_hop_with_origin_rejected(self):
        proof, digest = proof_with_transport(self, self.fix_commit() + "^")
        world = LiveWorld(self, tag="live-pre-fix")
        process, path = world.collect("normal", "pre-fix.json", check=False, proof=proof)
        record = {"exit": process.returncode, "stop": None}
        evidence = json.loads(path.read_text()) if path.exists() else {}
        record["stop"] = (evidence.get("collection") or {}).get("stop")
        print(f"253-109 sensitivity pre-fix live: {json.dumps(record)}", file=sys.stderr)
        self.assertEqual(process.returncode, 1, "the pre-fix transport passed the live-policy family: the gate cannot see 253-104")
        self.assertIn("origin_rejected: live transport is restricted to api.github.com", record["stop"])
        self.assertTrue(record["stop"].startswith("artifact_zip:"), record["stop"])
        self.assertIs(evidence["collection"]["complete"], False)
        zips = [tx for tx in evidence["transport_ledger"]["transactions"] if tx["route_id"] == "artifact_zip"]
        self.assertEqual([(tx["hop_ordinal"], tx["host"], tx["actual_status"]) for tx in zips], [(0, API_HOST, 302)],
                         "only the first producer download's hop 0 was charged; hop 1 never left the process")
        self.assertFalse(any(row.get("host") == BLOB_HOST for row in world.server.journal), "a hop-1 request reached the blob host")
        self.assertEqual(world.connect_hosts(), [API_HOST], "a hop-1 connection was opened to the blob host")
        self.assertEqual(world.refusals(), [], "the transport refused the hop, not the shim")
        self.assertIsNotNone(digest)
        self.assertNotEqual(digest, sha(subprocess.check_output(["git", "-C", str(ROOT), "show",
                                                                 f"{self.fix_commit()}:scripts/ci/ci-hosted-transport.py"])))
        rejected, _ = run_verifier("--mode", "pr", "--family", "normal", "--evidence", path)
        self.assertEqual(rejected.returncode, 1)

    def test_the_fixed_transport_copy_completes_the_live_normal_family(self):
        proof, digest = proof_with_transport(self, self.fix_commit())
        world = LiveWorld(self, tag="live-fix")
        process, path = world.collect("normal", "fix.json", check=False, proof=proof)
        print(f"253-109 sensitivity fix live: {json.dumps({'exit': process.returncode})}", file=sys.stderr)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        hops = [tx for tx in json.loads(path.read_text())["transport_ledger"]["transactions"]
                if tx["route_id"] == "artifact_zip" and tx["hop_ordinal"] == 1]
        self.assertEqual([(tx["host"], tx["actual_status"]) for tx in hops], [(BLOB_HOST, 200)] * 5)
        self.assertEqual(world.connect_hosts(), sorted({API_HOST, BLOB_HOST}))
        verified, result = run_verifier("--mode", "pr", "--family", "normal", "--evidence", path)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        self.assertEqual(result["status"], "synthetic_pr_family_verified")

    def test_the_hermetic_universe_with_the_pre_fix_transport_is_recorded_not_gated(self):
        proof, digest = proof_with_transport(self, self.fix_commit() + "^")
        world = World(self, tag="hermetic-pre-fix")
        process, path = world.collect("normal", "hermetic-pre-fix.json", check=False, proof=proof)
        evidence = json.loads(path.read_text()) if path.exists() else {}
        record = {"exit": process.returncode, "stop": (evidence.get("collection") or {}).get("stop"),
                  "hop1_hosts": sorted({tx["host"] for tx in (evidence.get("transport_ledger") or {}).get("transactions", [])
                                        if tx["route_id"] == "artifact_zip" and tx["hop_ordinal"] == 1})}
        # Recorded, not gated: the hermetic allocation is exempt from the live origin check, so it is blind to 253-104.
        print(f"253-109 sensitivity pre-fix hermetic: {json.dumps(record)}", file=sys.stderr)
        self.assertIn(process.returncode, (0, 1))


if __name__ == "__main__":
    outcome = unittest.main(verbosity=2, exit=False).result
    if outcome.testsRun < 20:
        print(f"ci-pr-proof.test: FAIL: only {outcome.testsRun} contracts executed (zero-test guard)", file=sys.stderr)
        sys.exit(1)
    sys.exit(0 if outcome.wasSuccessful() else 1)
PYEOF
