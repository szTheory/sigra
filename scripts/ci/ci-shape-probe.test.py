#!/usr/bin/env python3
"""253-126: the read-only shape-probe driver, rehearsed through the real 253-125 transport. No network.

Every test runs the driver as a child process against a scratch Git copy of the driver, the transport and the committed
source-pointer files, under the live-policy shim: the allocation is mode live, so every transport policy branch runs, and
only the layer below it (sockets, DNS, TLS trust) is redirected to local TLS fakes for api.github.com, the results-receiver
log host and a blob host. A refusal test proves "before any request" by an empty shim connect log, an empty fake-server
journal and no record file, after the unmodified binding passed in the same test (the positive control).
"""
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
import subprocess
import tempfile
import threading
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
DRIVER_REL = "scripts/ci/ci-shape-probe.py"
TRANSPORT_REL = "scripts/ci/ci-hosted-transport.py"
SHIM_SOURCE = ROOT / "scripts/ci/ci-live-policy-shim.py"
PHASE_REL = ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks"
BASELINE_REL = ".planning/phases/252-measure-current-ci/252-BASELINE.json"
R10_LEDGER_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-HTTP-LEDGER-R10.json"
R10_ALLOCATION_REL = f"{PHASE_REL}/253-LOAD-RECOVERY-CANARY-ALLOCATION-R10.json"
DUMMY_TOKEN = "dummy-not-a-credential-253-126"
API = "api.github.com"
RESULTS_RECEIVER = "results-receiver.actions.githubusercontent.com"
BLOB = "productionresultssa16.blob.core.windows.net"
UNTRUSTED = "evil.example.com"
SHIM_HOSTS = (API, RESULTS_RECEIVER, BLOB, UNTRUSTED)
CANCELLED_RUN, FAILED_JOB, LOG_RUN = 38141825287, 117183276622, 38963239851
CATEGORY_LIMITS = {"preflight": 1, "cancelled_shape": 3, "job_log_shape": 1, "failure_logs": 3}
LIST_FIELDS = ("schema_version", "repository", "window_id", "max_requests", "max_elapsed_seconds", "max_response_bytes",
               "max_pages", "max_hops", "category_limits", "download_hosts", "source_pointers", "driver_commit", "requests")
# The no-HTTP-client rule, the same pattern as the plan's grep: an import of http, http.client, urllib, urllib.request,
# socket or ssl in "import X" or "from X import Y" form (which covers "from http import client").
NO_HTTP_IMPORT = re.compile(r"^[ \t]*(import|from)[ \t]+(http|http\.client|urllib|urllib\.request|socket|ssl)([ \t.,]|$)",
                            re.M)
GIT_ENV = {"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1", "GIT_AUTHOR_NAME": "t",
           "GIT_AUTHOR_EMAIL": "t@example.invalid", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid"}


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SHIM = load_module(SHIM_SOURCE, "ci_live_policy_shim_for_shape_probe_test")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# -- the scratch repository: the driver under test, the transport and the committed source-pointer files ---------------
_SCRATCH = {}


def _git(root, *args):
    env = dict(os.environ, **GIT_ENV)
    return subprocess.run(["git", "-C", str(root), *args], env=env, text=True, capture_output=True, check=True).stdout.strip()


def setUpModule():  # noqa: N802
    tmp = tempfile.TemporaryDirectory(prefix="sigra-253-126-repo-")
    root = pathlib.Path(tmp.name)
    for rel in (TRANSPORT_REL, BASELINE_REL, R10_LEDGER_REL, R10_ALLOCATION_REL):
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / rel, root / rel)
    # An absent driver (the RED run) becomes an empty file, so every test runs and fails on its own assertion.
    driver = (ROOT / DRIVER_REL).read_bytes() if (ROOT / DRIVER_REL).exists() else b""
    _git(root, "init", "-q")
    # An older driver revision first, so "driver_commit with the driver changed since" is a real ancestor.
    (root / DRIVER_REL).write_bytes(driver + b"\n# 253-126 test: an older driver revision\n")
    _git(root, "add", "-A")
    _git(root, "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-q", "-m", "older driver")
    old = _git(root, "rev-parse", "HEAD")
    (root / DRIVER_REL).write_bytes(driver)
    _git(root, "add", "-A")
    _git(root, "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-q", "-m", "driver")
    head = _git(root, "rev-parse", "HEAD")
    orphan = _git(root, "commit-tree", "HEAD^{tree}", "-m", "orphan, never an ancestor of HEAD")
    _SCRATCH.update(tmp=tmp, root=root, head=head, old=old, orphan=orphan)


def tearDownModule():  # noqa: N802
    _SCRATCH["tmp"].cleanup()


def pointer(rel, **locator):
    return dict({"path": rel, "sha256": sha256((ROOT / rel).read_bytes())}, **locator)


def request_list():
    hosts = json.loads((ROOT / R10_ALLOCATION_REL).read_text())["download_hosts"] + [RESULTS_RECEIVER]
    return {
        "schema_version": "sigra.phase253.shape-probe-requests/v1", "repository": "szTheory/sigra",
        "window_id": "253-126-rehearsal-window", "max_requests": 8, "max_elapsed_seconds": 600,
        "max_response_bytes": 4194304, "max_pages": 2, "max_hops": 2, "category_limits": dict(CATEGORY_LIMITS),
        "download_hosts": hosts,
        "source_pointers": [pointer(BASELINE_REL, pointer="/failure_analysis/families/5/run"),
                            pointer(R10_LEDGER_REL, sequence=45), pointer(R10_LEDGER_REL, sequence=47),
                            pointer(R10_ALLOCATION_REL, pointer="/download_hosts")],
        "driver_commit": _SCRATCH["head"],
        "requests": [
            {"id": "rate", "route_id": "rate_limit", "method": "GET", "category": "preflight", "params": {}, "query": {},
             "mode": "one"},
            {"id": "cancelled-run", "route_id": "run", "method": "GET", "category": "cancelled_shape",
             "params": {"run_id": CANCELLED_RUN}, "query": {}, "mode": "one"},
            {"id": "cancelled-jobs", "route_id": "run_jobs", "method": "GET", "category": "cancelled_shape",
             "params": {"run_id": CANCELLED_RUN}, "query": {"per_page": 100}, "mode": "pages"},
            {"id": "job-log-redirect", "route_id": "job_logs", "method": "GET", "category": "job_log_shape",
             "params": {"job_id": FAILED_JOB}, "query": {}, "mode": "one"},
            {"id": "run-log-chain", "route_id": "run_logs", "method": "GET", "category": "failure_logs",
             "params": {"run_id": LOG_RUN}, "query": {}, "mode": "follow"},
        ],
    }


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")
    return path


def bind(directory, doc, approval_edit=None, allocation_edit=None):
    """Write a request list, an approval bound to its sha256, and a live allocation built from it."""
    requests = write_json(directory / "requests.json", doc)
    digest = sha256(requests.read_bytes())
    approval = {"schema_version": "sigra.phase253.shape-probe-approval/v1", "decision": "approve",
                "decided_by": "253-126 test", "decision_text": "approve", "note": "", "section": "shape_probe",
                "section_sha256": digest, "requests_path": str(requests), "authorizes": ["the five GETs"],
                "excludes": ["any write"], "recorded_at": "2026-10-16T00:00:00Z"}
    if approval_edit:
        approval_edit(approval)
    approval_path = write_json(directory / "approval.json", approval)
    allocation = {"schema_version": "sigra.phase253.http-allocation/v1", "allocation_kind": "canary", "mode": "live",
                  "repository": doc.get("repository"), "window_id": doc.get("window_id"), "source_sha256": digest,
                  "max_requests": doc.get("max_requests"), "max_elapsed_seconds": doc.get("max_elapsed_seconds"),
                  "max_response_bytes": doc.get("max_response_bytes"), "max_pages": doc.get("max_pages"),
                  "max_hops": doc.get("max_hops"), "category_limits": copy.deepcopy(doc.get("category_limits")),
                  "bound_documents": [{"path": str(requests), "sha256": digest},
                                      {"path": str(approval_path), "sha256": sha256(approval_path.read_bytes())}],
                  "download_hosts": list(doc.get("download_hosts") or [])}
    if allocation_edit:
        allocation_edit(allocation)
    allocation_path = write_json(directory / "allocation.json", allocation)
    return {"requests": requests, "approval": approval_path, "allocation": allocation_path}


def log_zip():
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, text in (("0_producer (admin_behavior).txt", "2026-10-16T20:35:00Z ##[group]Run tests\nok\n"),
                           ("producer (admin_behavior)/1_Set up job.txt", "2026-10-16T20:35:01Z Runner ready\n")):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, text)
    return buffer.getvalue()


class FakeHandler(http.server.BaseHTTPRequestHandler):
    """Answers by Host header and journals every request it actually received."""
    protocol_version = "HTTP/1.1"

    def _answer(self):
        host = (self.headers.get("Host") or "").split(":", 1)[0].lower()
        route = self.path.split("?", 1)[0]
        status, headers, payload = self.server.routes.get(
            (host, self.path), self.server.routes.get((host, route), (404, [], b'{"message":"Not Found"}')))
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
        self.server.journal.append({"method": self.command, "host": host, "path": self.path, "status": status,
                                    "authorization": self.headers.get("Authorization")})

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = _answer  # noqa: N815

    def log_message(self, *_args):
        pass


class ShimCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.class_tmp = tempfile.TemporaryDirectory(prefix="sigra-253-126-tls-")
        cls.cert, key = SHIM.make_tls_identity(pathlib.Path(cls.class_tmp.name), (
            API, "*.actions.githubusercontent.com", "*.blob.core.windows.net", UNTRUSTED))
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FakeHandler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cls.cert, key)
        cls.server.socket = context.wrap_socket(cls.server.socket, server_side=True)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
        cls.class_tmp.cleanup()

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="sigra-253-126-")
        self.addCleanup(tmp.cleanup)
        self.tmp = pathlib.Path(tmp.name)
        self.root = _SCRATCH["root"]
        self.server.routes = {}
        self.server.journal = []
        self.connect_log = self.tmp / "connect.jsonl"
        self.refusal_log = SHIM.refusal_log_for(self.connect_log)
        self.shim_env = SHIM.prepare(self.tmp / "site", {host: self.server.server_address[1] for host in SHIM_HOSTS},
                                     self.cert, self.connect_log)
        self.records = {"ledger": self.tmp / "ledger.json", "evidence": self.tmp / "evidence.json",
                        "bodies": self.tmp / "bodies.json"}

    def env(self):
        env = {key: value for key, value in os.environ.items()
               if key not in {"GH_TOKEN", "GITHUB_TOKEN", "PYTHONPATH"} and not key.startswith("SIGRA_")}
        env.update(self.shim_env)
        env["GH_TOKEN"] = DUMMY_TOKEN
        return env

    def driver(self, *args):
        return subprocess.run(["python3", str(self.root / DRIVER_REL), *map(str, args)], cwd=self.root, env=self.env(),
                              text=True, capture_output=True, timeout=120)

    def check_only(self, paths):
        return self.driver("--check-only", "--requests", paths["requests"], "--allocation", paths["allocation"],
                           "--approval", paths["approval"])

    def run_probe(self, paths):
        return self.driver("--run", "--requests", paths["requests"], "--allocation", paths["allocation"],
                           "--approval", paths["approval"], "--ledger", self.records["ledger"],
                           "--evidence", self.records["evidence"], "--bodies", self.records["bodies"])

    def connects(self):
        return [(row["host"], row["port"]) for row in SHIM.read_log(self.connect_log)]

    def assert_no_socket(self):
        self.assertEqual(SHIM.read_log(self.connect_log), [])
        self.assertEqual(SHIM.read_log(self.refusal_log), [])
        self.assertEqual(self.server.journal, [])

    def assert_refused(self, result, field):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(f"ci-shape-probe: REFUSED: {field}:", result.stderr)
        self.assert_no_socket()
        for path in self.records.values():
            self.assertFalse(path.exists(), f"{path.name} was written by a refused run")
            self.assertFalse(pathlib.Path(str(path) + ".lock").exists())


class ProbeRefusalTests(ShimCase):
    """Every refusal happens before any socket; the unmodified binding passes first in every test."""

    def setUp(self):
        super().setUp()
        self.doc = request_list()
        self.paths = bind(self.tmp, self.doc)
        listed = self.driver("--check-requests", self.paths["requests"])
        self.assertEqual(listed.returncode, 0, listed.stderr)
        bound = self.check_only(self.paths)
        self.assertEqual(bound.returncode, 0, bound.stderr)
        self.assertIn("check-only OK", bound.stdout)
        self.assert_no_socket()

    def rebind(self, doc=None, approval_edit=None, allocation_edit=None):
        directory = pathlib.Path(tempfile.mkdtemp(dir=self.tmp))
        return bind(directory, doc if doc is not None else copy.deepcopy(self.doc), approval_edit, allocation_edit)

    def assert_run_refused(self, paths, field):
        self.assert_refused(self.run_probe(paths), field)

    def test_live_probe_refuses_a_post_method_before_any_socket(self):
        doc = copy.deepcopy(self.doc)
        doc["requests"][0]["method"] = "POST"
        self.assert_run_refused(self.rebind(doc), "list.requests[0].method")

    def test_live_probe_refuses_every_write_ref_pr_and_unlisted_route_before_any_socket(self):
        transport = load_module(ROOT / TRANSPORT_REL, "ci_hosted_transport_for_shape_probe_test")
        for route in ("dispatch", "cancel_run", "create_ref", "get_ref", "pr_create", "artifact_zip"):
            with self.subTest(route=route):
                doc = copy.deepcopy(self.doc)
                doc["requests"][1].update(route_id=route, method=transport.ROUTES[route][0])
                self.assert_run_refused(self.rebind(doc), "list.requests[1].route_id")

    def test_live_probe_refuses_follow_on_job_logs_before_any_socket(self):
        doc = copy.deepcopy(self.doc)
        doc["requests"][3]["mode"] = "follow"
        self.assert_run_refused(self.rebind(doc), "list.requests[3].mode")

    def test_live_probe_refuses_a_scoped_ref_in_a_parameter_query_or_id_before_any_socket(self):
        edits = {
            "parameter": lambda item: item["params"].update(branch="gsd/253-replan-r10-candidate"),
            "query": lambda item: item["query"].update(ref="gsd/253-replan-r9-fixture"),
            "id": lambda item: item.update(id="read-253-replan-r8"),
        }
        for name, edit in edits.items():
            with self.subTest(where=name):
                doc = copy.deepcopy(self.doc)
                edit(doc["requests"][2])
                result = self.run_probe(self.rebind(doc))
                self.assert_refused(result, "list.requests[2]")
                self.assertIn("253-replan", result.stderr)

    def test_live_probe_refuses_a_requests_file_edited_after_approval_before_any_socket(self):
        paths = self.rebind()
        paths["requests"].write_text(paths["requests"].read_text() + " ")
        self.assert_run_refused(paths, "approval.section_sha256")

    def test_live_probe_refuses_a_rejected_approval_before_any_socket(self):
        self.assert_run_refused(self.rebind(approval_edit=lambda item: item.update(decision="reject")),
                                "approval.decision")

    def test_live_probe_refuses_a_hermetic_test_allocation_before_any_socket(self):
        self.assert_run_refused(self.rebind(allocation_edit=lambda item: item.update(mode="hermetic-test")),
                                "allocation.mode")

    def test_live_probe_refuses_a_production_allocation_before_any_socket(self):
        self.assert_run_refused(self.rebind(allocation_edit=lambda item: item.update(allocation_kind="production")),
                                "allocation.allocation_kind")

    def test_live_probe_refuses_category_limits_that_differ_from_the_request_list_before_any_socket(self):
        limits = dict(CATEGORY_LIMITS, failure_logs=2, preflight=2)
        self.assert_run_refused(self.rebind(allocation_edit=lambda item: item.update(category_limits=limits)),
                                "allocation.category_limits")

    def test_live_probe_refuses_bound_documents_without_the_approval_before_any_socket(self):
        self.assert_run_refused(
            self.rebind(allocation_edit=lambda item: item.update(bound_documents=item["bound_documents"][:1])),
            "allocation.bound_documents")

    def test_live_probe_refuses_records_that_already_exist_before_any_socket(self):
        self.records["evidence"].write_text("{}\n")
        result = self.run_probe(self.rebind())
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("ci-shape-probe: REFUSED: evidence:", result.stderr)
        self.assert_no_socket()
        self.assertFalse(self.records["ledger"].exists())

    def test_check_only_refuses_an_allocation_without_results_receiver(self):
        def drop(item):
            item["download_hosts"] = [host for host in item["download_hosts"] if host != RESULTS_RECEIVER]
        paths = self.rebind(allocation_edit=drop)
        hosts = json.loads(paths["allocation"].read_text())["download_hosts"]
        self.assertEqual(hosts, json.loads((ROOT / R10_ALLOCATION_REL).read_text())["download_hosts"])
        self.assert_refused(self.check_only(paths), "allocation.download_hosts")
        self.assert_run_refused(paths, "allocation.download_hosts")
        # Control: the transport alone accepts this pre-R11 42-host allocation, so only the driver's exact list refuses it.
        request = write_json(self.tmp / "rate.json", {"route_id": "rate_limit", "method": "GET", "category": "preflight",
                                                      "params": {}, "query": {}})
        transport = subprocess.run(["python3", str(self.root / TRANSPORT_REL), "--check-only", "--allocation",
                                    str(paths["allocation"]), "--ledger", str(self.tmp / "none.json"), "--request",
                                    str(request), "--output", os.devnull], cwd=self.root, env=self.env(), text=True,
                                   capture_output=True, timeout=60)
        self.assertEqual(transport.returncode, 0, transport.stderr)
        self.assert_no_socket()

    def test_check_only_refuses_each_allocation_field_that_differs_from_the_request_list(self):
        def hosts(change):
            return lambda item: item.update(download_hosts=change(list(item["download_hosts"])))
        cases = {
            "window_id": ("window_id", lambda item: item.update(window_id="253-126-another-window")),
            "max_requests": ("max_requests", lambda item: item.update(max_requests=9)),
            "max_elapsed_seconds": ("max_elapsed_seconds", lambda item: item.update(max_elapsed_seconds=599)),
            "max_response_bytes": ("max_response_bytes", lambda item: item.update(max_response_bytes=2097152)),
            "max_pages": ("max_pages", lambda item: item.update(max_pages=1)),
            "max_hops": ("max_hops", lambda item: item.update(max_hops=1)),
            "category_limits": ("category_limits", lambda item: item.update(
                category_limits=dict(CATEGORY_LIMITS, job_log_shape=2, cancelled_shape=2))),
            "repository": ("repository", lambda item: item.update(repository="szTheory/sigra-fork")),
            "download_hosts without results-receiver": ("download_hosts", hosts(
                lambda value: [host for host in value if host != RESULTS_RECEIVER])),
            "download_hosts with an extra trusted blob host": ("download_hosts", hosts(
                lambda value: value + ["productionresultssa41.blob.core.windows.net"])),
            "download_hosts reordered": ("download_hosts", hosts(lambda value: [value[1], value[0]] + value[2:])),
        }
        for name, (field, edit) in cases.items():
            with self.subTest(field=name):
                for path in self.records.values():
                    path.unlink(missing_ok=True)
                paths = self.rebind(allocation_edit=edit)
                self.assertNotEqual(json.loads(paths["allocation"].read_text()),
                                    json.loads(self.paths["allocation"].read_text()))
                self.assert_refused(self.check_only(paths), f"allocation.{field}")
                self.assert_run_refused(paths, f"allocation.{field}")

    def test_check_requests_refuses_each_missing_or_altered_field(self):
        cases = {f"without {field}": (f"list.{field}", lambda doc, field=field: doc.pop(field)) for field in LIST_FIELDS}
        cases.update({
            "an unknown field": ("list.extra_field", lambda doc: doc.update(extra_field=True)),
            "a source pointer sha256 altered": ("list.source_pointers[0].sha256", lambda doc: doc["source_pointers"][0].update(
                sha256="0" * 64)),
            "driver_commit not an ancestor": ("list.driver_commit", lambda doc: doc.update(driver_commit=_SCRATCH["orphan"])),
            "driver_commit with the driver changed since": ("list.driver_commit", lambda doc: doc.update(
                driver_commit=_SCRATCH["old"])),
        })
        self.assertEqual(len(cases), len(LIST_FIELDS) + 4)
        for name, (field, edit) in cases.items():
            with self.subTest(case=name):
                doc = copy.deepcopy(self.doc)
                edit(doc)
                requests = write_json(self.tmp / "mutated-requests.json", doc)
                self.assert_refused(self.driver("--check-requests", requests), field)

    def test_the_driver_imports_no_http_client_of_its_own(self):
        driver = (ROOT / DRIVER_REL).read_text()
        self.assertEqual(NO_HTTP_IMPORT.findall(driver), [])
        # Positive control: the SAME pattern finds the transport's own HTTP client imports.
        self.assertTrue(NO_HTTP_IMPORT.search((ROOT / TRANSPORT_REL).read_text()))
        self.assertTrue(NO_HTTP_IMPORT.search("from http import client\n"))
        for name in ("request_one", "fetch_pages", "follow_download", "_scrub_text"):
            self.assertIn(f"transport.{name}", driver)


class ProbeRehearsalTests(ShimCase):
    """The approved five GETs, end to end through the real transport under a live allocation."""

    def setUp(self):
        super().setUp()
        self.doc = request_list()
        self.paths = bind(self.tmp, self.doc)
        ledger47 = [row for row in json.loads((ROOT / R10_LEDGER_REL).read_text())["transactions"] if row["sequence"] == 47]
        self.assertEqual(len(ledger47), 1)
        self.seq47 = ledger47[0]
        location = self.seq47["scrubbed_headers"]["location"]
        self.assertEqual((location["host"], location["port"], location["has_query"]), (RESULTS_RECEIVER, None, True))
        self.log_path = location["path"]
        baseline = json.loads((ROOT / BASELINE_REL).read_text())
        run = baseline["failure_analysis"]["families"][5]["run"]
        self.assertEqual((run["id"], run["conclusion"]), (CANCELLED_RUN, "cancelled"))
        seq45 = next(row for row in json.loads((ROOT / R10_LEDGER_REL).read_text())["transactions"] if row["sequence"] == 45)
        jobs = json.loads(base64.b64decode(seq45["response_body_base64"]))
        for job in jobs["jobs"]:
            job.update(run_id=CANCELLED_RUN, conclusion="cancelled")
        json_headers = [("Content-Type", "application/json; charset=utf-8"), ("X-RateLimit-Resource", "core"),
                        ("X-RateLimit-Remaining", "4990")]
        repo = "/repos/szTheory/sigra/actions"
        self.server.routes = {
            (API, "/rate_limit"): (200, json_headers, b'{"resources":{"core":{"limit":5000,"remaining":4990}}}'),
            (API, f"{repo}/runs/{CANCELLED_RUN}"): (200, json_headers, json.dumps(run).encode()),
            (API, f"{repo}/runs/{CANCELLED_RUN}/jobs"): (200, json_headers, json.dumps(jobs).encode()),
            (API, f"{repo}/jobs/{FAILED_JOB}/logs"): (302, [
                ("Content-Type", "text/html;charset=utf-8"),
                ("Location", f"https://{BLOB}/actions-results/job-logs.txt?sig=job-synthetic-253-126")], b""),
            (API, f"{repo}/runs/{LOG_RUN}/logs"): (302, [
                ("Content-Type", "text/html;charset=utf-8"),
                ("Location", f"https://{RESULTS_RECEIVER}{self.log_path}?sig=synthetic-253-126&se=2026-10-16")], b""),
            (RESULTS_RECEIVER, self.log_path): (200, [("Content-Type", "application/zip")], log_zip()),
        }

    def records_text(self):
        return "".join(path.read_text() for path in self.records.values() if path.exists())

    def load(self, name):
        return json.loads(self.records[name].read_text())

    def assert_token_only_on_api(self):
        for row in self.server.journal:
            self.assertEqual(row["method"], "GET")
            self.assertEqual(row["authorization"], f"Bearer {DUMMY_TOKEN}" if row["host"] == API else None, row)
        self.assertNotIn(DUMMY_TOKEN, self.records_text())
        self.assertNotIn("synthetic-253-126", self.records_text())

    def assert_common(self, evidence, ledger):
        self.assertEqual(evidence["schema_version"], "sigra.phase253.shape-probe-evidence/v1")
        self.assertEqual(evidence["window_id"], "253-126-rehearsal-window")
        self.assertEqual(evidence["requests_sha256"], sha256(self.paths["requests"].read_bytes()))
        self.assertEqual(evidence["approval_sha256"], sha256(self.paths["approval"].read_bytes()))
        self.assertEqual(evidence["allocation_sha256"], sha256(self.paths["allocation"].read_bytes()))
        self.assertEqual(evidence["driver_commit"], _SCRATCH["head"])
        self.assertIsInstance(evidence["window_wall_start_epoch"], int)
        self.assertLessEqual(evidence["window_wall_start_epoch"], evidence["ended_epoch"])
        self.assertEqual(evidence["request_count"], len(ledger["transactions"]))
        self.assertEqual(evidence["transport_ledger"], ledger)
        self.assertTrue(all(row["method"] == "GET" for row in ledger["transactions"]))
        self.assertTrue(all(row["host"] == API or row["route_id"] == "run_logs" for row in ledger["transactions"]))
        self.assertFalse(pathlib.Path(str(self.records["ledger"]) + ".lock").exists())
        self.assertEqual(SHIM.read_log(self.refusal_log), [])

    def test_live_probe_records_the_seq47_chain_to_results_receiver(self):
        result = self.run_probe(self.paths)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        evidence, ledger, bodies = self.load("evidence"), self.load("ledger"), self.load("bodies")
        self.assertEqual(evidence["status"], "complete")
        self.assertIsNone(evidence["stop"])
        self.assert_common(evidence, ledger)
        self.assertEqual([(row["route_id"], row["hop_ordinal"] or 0, row["host"], row["actual_status"])
                          for row in ledger["transactions"]],
                         [("rate_limit", 0, API, 200), ("run", 0, API, 200), ("run_jobs", 0, API, 200),
                          ("job_logs", 0, API, 302), ("run_logs", 0, API, 302), ("run_logs", 1, RESULTS_RECEIVER, 200)])
        self.assertEqual(self.connects(), [(API, 443)] * 5 + [(RESULTS_RECEIVER, 443)])
        self.assert_token_only_on_api()
        self.assertEqual([item["id"] for item in evidence["results"]],
                         ["rate", "cancelled-run", "cancelled-jobs", "job-log-redirect", "run-log-chain"])
        by_id = {item["id"]: item for item in evidence["results"]}
        # job_logs: hop 0 only; its Location is recorded and no second socket is opened.
        job = by_id["job-log-redirect"]["observed"]["hops"]
        self.assertEqual(len(job), 1)
        self.assertEqual((job[0]["hop_ordinal"], job[0]["status"], job[0]["location"]["host"], job[0]["location"]["has_query"]),
                         (0, 302, BLOB, True))
        self.assertNotIn((BLOB, 443), self.connects())
        chain = by_id["run-log-chain"]["observed"]["hops"]
        self.assertEqual([(hop["hop_ordinal"], hop["host"], hop["status"]) for hop in chain],
                         [(0, API, 302), (1, RESULTS_RECEIVER, 200)])
        self.assertEqual(chain[0]["location"], {"host": RESULTS_RECEIVER, "path_pattern": "/rest/runs/{uuid}/logs",
                                                "has_query": True, "port": None})
        self.assertEqual(chain[0]["content_type"], "text/html;charset=utf-8")
        self.assertEqual(chain[0]["path_pattern"], "/repos/szTheory/sigra/actions/runs/{n}/logs")
        self.assertEqual(chain[1]["path_pattern"], "/rest/runs/{uuid}/logs")
        self.assertIn("location", chain[0]["safe_header_names"])
        self.assertEqual(len(by_id["run-log-chain"]["receipts"]), 2)
        entry = next(item for item in bodies["entries"] if item["id"] == "run-log-chain")
        self.assertEqual(bodies["schema_version"], "sigra.phase253.shape-probe-bodies/v1")
        self.assertEqual((entry["hop_ordinal"], entry["bytes"], entry["sha256"]), (1, len(log_zip()), sha256(log_zip())))
        self.assertEqual(entry["magic_hex"], log_zip()[:8].hex())
        with zipfile.ZipFile(io.BytesIO(log_zip())) as archive:
            expected = [{"name": info.filename, "size": info.file_size, "compressed_size": info.compress_size,
                         "crc": info.CRC} for info in archive.infolist()]
        self.assertEqual(entry["zip_members"], expected)
        self.assertEqual(entry["token_scan"], "clean")
        self.assertEqual(base64.b64decode(entry["full_base64"]), log_zip())
        self.assertEqual([item["name"] for item in entry["head_sample_base64"]], [item["name"] for item in expected])
        json_entries = [item for item in bodies["entries"] if item["id"] in {"rate", "cancelled-run", "cancelled-jobs"}]
        self.assertEqual(len(json_entries), 3)
        for item in json_entries:
            self.assertEqual(set(item) - {"id", "hop_ordinal", "page_ordinal", "kind"}, {"sha256", "bytes"})

    def test_live_probe_records_a_results_receiver_to_blob_chain(self):
        self.server.routes[(RESULTS_RECEIVER, self.log_path)] = (
            302, [("Location", f"https://{BLOB}/actions-results/logs.zip?sig=hop-two-synthetic-253-126")], b"")
        self.server.routes[(BLOB, "/actions-results/logs.zip")] = (200, [("Content-Type", "application/zip")], log_zip())
        result = self.run_probe(self.paths)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        evidence, ledger = self.load("evidence"), self.load("ledger")
        self.assert_common(evidence, ledger)
        rows = [row for row in ledger["transactions"] if row["route_id"] == "run_logs"]
        self.assertEqual([(row["hop_ordinal"], row["host"], row["actual_status"]) for row in rows],
                         [(0, API, 302), (1, RESULTS_RECEIVER, 302), (2, BLOB, 200)])
        chain = next(item for item in evidence["results"] if item["id"] == "run-log-chain")["observed"]["hops"]
        self.assertEqual([(hop["host"], hop["status"]) for hop in chain], [(API, 302), (RESULTS_RECEIVER, 302), (BLOB, 200)])
        self.assertEqual(chain[1]["location"]["host"], BLOB)
        self.assertEqual(self.connects(), [(API, 443)] * 5 + [(RESULTS_RECEIVER, 443), (BLOB, 443)])
        self.assert_token_only_on_api()
        entry = next(item for item in self.load("bodies")["entries"] if item["id"] == "run-log-chain")
        self.assertEqual((entry["hop_ordinal"], entry["sha256"]), (2, sha256(log_zip())))

    def test_live_probe_halts_on_an_untrusted_hop_and_keeps_partial_records(self):
        self.server.routes[(RESULTS_RECEIVER, self.log_path)] = (302, [("Location", f"https://{UNTRUSTED}/logs.zip")], b"")
        result = self.run_probe(self.paths)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        evidence, ledger, bodies = self.load("evidence"), self.load("ledger"), self.load("bodies")
        self.assert_common(evidence, ledger)
        self.assertEqual(evidence["status"], "halted")
        self.assertEqual((evidence["stop"]["code"], evidence["stop"]["request_id"]), ("redirect_rejected", "run-log-chain"))
        self.assertEqual(ledger["terminal_stop"]["code"], "redirect_rejected")
        self.assertEqual([item["id"] for item in evidence["results"]],
                         ["rate", "cancelled-run", "cancelled-jobs", "job-log-redirect", "run-log-chain"])
        self.assertEqual([item["status"] for item in evidence["results"]], ["complete"] * 4 + ["halted"])
        chain = evidence["results"][-1]["observed"]["hops"]
        self.assertEqual([(hop["host"], hop["status"]) for hop in chain], [(API, 302), (RESULTS_RECEIVER, 302)])
        self.assertEqual(chain[1]["location"]["host"], UNTRUSTED)
        self.assertEqual(len(ledger["transactions"]), 6)
        self.assertNotIn((UNTRUSTED, 443), self.connects())
        self.assertEqual(self.connects(), [(API, 443)] * 5 + [(RESULTS_RECEIVER, 443)])
        self.assertEqual({item["id"] for item in bodies["entries"]},
                         {"rate", "cancelled-run", "cancelled-jobs", "job-log-redirect"})
        self.assert_token_only_on_api()

    def test_live_probe_large_body_keeps_only_digest_and_head_sample(self):
        large = b"2026-10-16T20:35:00Z log line without secrets\n" * 6522
        large = large[:300000]
        self.assertEqual(len(large), 300000)
        self.server.routes[(RESULTS_RECEIVER, self.log_path)] = (200, [("Content-Type", "text/plain")], large)
        result = self.run_probe(self.paths)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        entry = next(item for item in self.load("bodies")["entries"] if item["id"] == "run-log-chain")
        self.assertEqual((entry["bytes"], entry["sha256"], entry["zip_members"]), (300000, sha256(large), None))
        self.assertEqual(entry["token_scan"], "clean")
        self.assertIsNone(entry["full_base64"])
        self.assertEqual(base64.b64decode(entry["head_sample_base64"]), large[:2048])
        self.assertNotIn(base64.b64encode(large[:6000]).decode(), self.records["bodies"].read_text())
        self.assert_token_only_on_api()


if __name__ == "__main__":
    unittest.main(verbosity=2)
