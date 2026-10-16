#!/usr/bin/env python3
"""Hermetic wire-level contracts for the Phase 253 hosted transport."""

import http.server
import base64
import hashlib
import json
import os
import pathlib
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/ci/ci-gate-canary.sh"
TRANSPORT_SOURCE = ROOT / "scripts/ci/ci-hosted-transport.py"


class JournalHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):  # noqa: N802
        ledger = json.loads(pathlib.Path(self.server.ledger_path).read_text())
        pending = ledger["transactions"][-1]
        status, response_headers, payload = self.server.responses.pop(0) if self.server.responses else (
            self.server.status, [("Content-Type", "application/json")], b'{"ready":true}')
        self.send_response(status)
        for name, value in response_headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("X-GitHub-Request-Id", "local-fixture")
        self.end_headers()
        self.wfile.write(payload)
        observed_headers = {name.lower(): value for name, value in response_headers}
        observed_headers["x-github-request-id"] = "local-fixture"
        observed_headers["date"] = self.date_time_string()
        observed_headers["content-length"] = str(len(payload))
        self.server.journal.append({"path": self.path, "charged": pending["state"] == "pending",
                                    "authorization": self.headers.get("Authorization"), "method": "GET",
                                    "status": status, "headers": observed_headers,
                                    "body_sha256": hashlib.sha256(payload).hexdigest(), "body": base64.b64encode(payload).decode()})

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        request_body = self.rfile.read(length)
        ledger = json.loads(pathlib.Path(self.server.ledger_path).read_text())
        pending = ledger["transactions"][-1]
        payload = b'{"created":true}'
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("X-GitHub-Request-Id", "local-object-fixture")
        self.end_headers()
        self.wfile.write(payload)
        self.server.journal.append({"path": self.path, "charged": pending["state"] == "pending",
                                    "authorization": self.headers.get("Authorization"), "method": "POST", "status": 201,
                                    "request_body_sha256": hashlib.sha256(request_body).hexdigest(),
                                    "request_body_bytes": len(request_body)})

    def date_time_string(self, timestamp=None):
        return "Tue, 13 Oct 2026 00:00:00 GMT"

    def log_message(self, *_args):
        pass


class HostedTransportWireTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-transport-")
        self.addCleanup(self.tmp.cleanup)
        self.tmp_path = pathlib.Path(self.tmp.name)
        self.cert = self.tmp_path / "server.pem"
        self.key = self.tmp_path / "server-key.pem"
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
             "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
             "-keyout", str(self.key), "-out", str(self.cert)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.ledger = self.tmp_path / "ledger.json"
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), JournalHandler)
        self.server.ledger_path = self.ledger
        self.server.status = 202
        self.server.journal = []
        self.server.responses = []
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.cert, self.key)
        self.server.socket = context.wrap_socket(self.server.socket, server_side=True)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.thread.join)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

        self.allocation_path = self.tmp_path / "allocation.json"
        self.request_path = self.tmp_path / "request.json"
        self.output_path = self.tmp_path / "response.json"
        self.body_path = self.tmp_path / "response.body"
        host, port = self.server.server_address
        allocation = {
            "schema_version": "sigra.phase253.http-allocation/v1",
            "window_id": "test-window",
            "source_sha256": "a" * 64,
            "max_requests": 4,
            "max_elapsed_seconds": 60,
            "max_response_bytes": 4096,
            "max_pages": 2,
            "max_hops": 2,
            "repository": "szTheory/sigra",
            "download_hosts": [],
            "mode": "hermetic-test",
            "test_origin": f"https://localhost:{port}",
            "test_ca_file": str(self.cert),
        }
        self.allocation_path.write_text(json.dumps(allocation))
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "test_probe", "page_ordinal": 1}))

    def run_runner(self):
        env = dict(os.environ)
        env.pop("GH_TOKEN", None)
        env.pop("GITHUB_TOKEN", None)
        return subprocess.run(
            ["bash", str(RUNNER), "--transport-probe", "--allocation", str(self.allocation_path),
             "--ledger", str(self.ledger), "--request", str(self.request_path),
             "--output", str(self.output_path), "--body-output", str(self.body_path)],
            cwd=ROOT, env=env, text=True, capture_output=True, timeout=10,
        )

    def test_shell_startup_charges_before_one_real_https_response(self):
        result = self.run_runner()
        self.assertEqual(result.returncode, 0, result.stderr)
        ledger = json.loads(self.ledger.read_text())
        receipt = json.loads(self.output_path.read_text())
        self.assertEqual(ledger["schema_version"], "sigra.phase253.http-ledger/v2")
        self.assertEqual(len(ledger["transactions"]), 1)
        self.assertTrue(self.server.journal[0]["charged"])
        self.assertEqual(self.server.journal[0]["path"], "/probe")
        self.assertEqual(receipt["actual_status"], 202)
        self.assertEqual(ledger["transactions"][0]["actual_status"], 202)
        self.assertEqual(receipt["scrubbed_headers"]["content-type"], "application/json")
        self.assertEqual(receipt["response_sha256"], __import__("hashlib").sha256(b'{"ready":true}').hexdigest())
        self.assertEqual(self.body_path.read_bytes(), b'{"ready":true}')

    def test_git_object_post_records_body_facts_without_retaining_source_content(self):
        source_text = "UTF-8 source with newline Δ\n"
        self.request_path.write_text(json.dumps({"method": "POST", "route_id": "git_create_blob",
                                                 "body": {"encoding": "utf-8", "content": source_text}}))
        result = self.run_runner()
        self.assertEqual(result.returncode, 0, result.stderr)
        ledger = json.loads(self.ledger.read_text())
        transaction = ledger["transactions"][0]
        observed = self.server.journal[0]
        request_body = json.dumps({"encoding": "utf-8", "content": source_text}, ensure_ascii=False,
                                  separators=(",", ":")).encode()
        self.assertTrue(observed["charged"])
        self.assertEqual(observed["path"], "/repos/szTheory/sigra/git/blobs")
        self.assertEqual(transaction["request_body_sha256"], hashlib.sha256(request_body).hexdigest())
        self.assertEqual(transaction["request_body_bytes"], len(request_body))
        self.assertEqual(observed["request_body_sha256"], transaction["request_body_sha256"])
        self.assertIsNone(transaction["request_body_base64"])
        self.assertNotIn(source_text, json.dumps(ledger))
        self.assertIsNone(observed["authorization"])

    def test_actual_http_200_and_404_reconcile_to_independent_v2_verdict(self):
        for status in (200, 404):
            with self.subTest(status=status):
                self.ledger.unlink(missing_ok=True)
                self.output_path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.server.status = status
                self.server.responses = [(status, [("Content-Type", "application/json")], b'{"wire":true}')]
                result = self.run_runner()
                self.assertEqual(result.returncode, 0, result.stderr)
                ledger = json.loads(self.ledger.read_text())
                receipt = json.loads(self.output_path.read_text())
                observed = self.server.journal[0]
                self.assertEqual(receipt["actual_status"], status)
                self.assertEqual(observed["status"], status)
                transaction = ledger["transactions"][0]
                journal = {key: transaction[key] for key in (
                    "sequence", "url", "url_sha256", "route_id", "page_ordinal", "hop_ordinal", "source_sha256", "window_id")}
                journal.update(method=observed["method"], actual_status=observed["status"],
                               scrubbed_headers=observed["headers"], response_sha256=observed["body_sha256"],
                               response_body_base64=observed["body"], response_bytes=len(base64.b64decode(observed["body"])),
                               scrubbed_response_bytes=len(base64.b64decode(observed["body"])),
                               state="complete", request_sha256=transaction["request_sha256"], request_body_base64=None,
                               dispatch_inputs=None, input_key_count=None, input_unicode_scalars=None,
                               input_utf8_bytes=None, input_sha256=None)
                evidence = {"schema_version": "sigra.phase253.hosted-replan-evidence/v2", "repository": "szTheory/sigra",
                            "origin": {"kind": "measured-v2", "channel": "hermetic-https",
                                       "window_id": ledger["window_id"], "source_sha256": ledger["source_sha256"]},
                            "budget": {"request_count": 1, "max_requests": 4},
                            "transport_ledger": ledger, "transport_receipts": [receipt], "server_journal": [journal]}
                path = self.tmp_path / "independent-evidence.json"
                path.write_text(json.dumps(evidence))
                verdict = subprocess.run(["python3", str(ROOT / "scripts/ci/ci-hosted-gate-verify.py"),
                                          "--mode", "transport", "--evidence", str(path)],
                                         cwd=ROOT, text=True, capture_output=True, timeout=10)
                self.assertEqual(verdict.returncode, 0, verdict.stderr)
                self.assertIn('"status": "transport_verified"', verdict.stdout)

    def test_native_statuses_are_retained_without_inference(self):
        for status in (204, 404, 500):
            with self.subTest(status=status):
                self.ledger.unlink(missing_ok=True)
                self.output_path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.server.responses = [(status, [("Content-Type", "application/json")], b'{"status":"wire"}')]
                result = self.run_runner()
                self.assertEqual(result.returncode, 0, result.stderr)
                receipt = json.loads(self.output_path.read_text())
                ledger = json.loads(self.ledger.read_text())
                self.assertEqual(receipt["actual_status"], status)
                self.assertEqual(ledger["transactions"][0]["actual_status"], status)

    def test_connection_failure_still_spends_a_pending_sequence(self):
        held = socket.socket()
        held.bind(("127.0.0.1", 0))
        port = held.getsockname()[1]
        held.close()
        allocation = json.loads(self.allocation_path.read_text())
        allocation["test_origin"] = f"https://localhost:{port}"
        self.allocation_path.write_text(json.dumps(allocation))
        result = self.run_runner()
        self.assertNotEqual(result.returncode, 0)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), 1)
        self.assertIsNone(ledger["transactions"][0]["actual_status"])
        self.assertEqual(ledger["transactions"][0]["state"], "failed")
        self.assertEqual(self.server.journal, [])

    def test_declined_budget_never_reaches_the_https_server(self):
        allocation = json.loads(self.allocation_path.read_text())
        allocation["max_requests"] = 0
        self.allocation_path.write_text(json.dumps(allocation))
        result = self.run_runner()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.server.journal, [])
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(ledger["terminal_stop"]["code"], "request_budget_exhausted")

    def test_redirects_are_individually_charged_and_signed_query_is_not_retained(self):
        port = self.server.server_address[1]
        signed = f"https://localhost:{port}/download?sig=fixture-secret"
        self.server.responses = [
            (302, [("Location", signed)], b""),
            (200, [("Content-Type", "application/octet-stream")], b"archive-bytes"),
        ]
        result = subprocess.run(
            ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--follow-download",
             "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
             "--request", str(self.request_path), "--output", str(self.output_path),
             "--body-output", str(self.body_path)],
            cwd=ROOT, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        ledger_text = self.ledger.read_text()
        receipt_text = self.output_path.read_text()
        self.assertEqual(len(self.server.journal), 2)
        self.assertTrue(all(item["charged"] for item in self.server.journal))
        self.assertEqual([item["path"] for item in self.server.journal], ["/probe", "/download?sig=fixture-secret"])
        self.assertNotIn("fixture-secret", ledger_text + receipt_text)
        ledger = json.loads(ledger_text)
        self.assertEqual([item["actual_status"] for item in ledger["transactions"]], [302, 200])
        self.assertEqual([item["hop_ordinal"] for item in ledger["transactions"]], [0, 1])
        self.assertEqual(ledger["transactions"][0]["scrubbed_headers"]["location"]["has_query"], True)
        self.assertEqual(self.body_path.read_bytes(), b"archive-bytes")
        self.assertTrue(all(item["authorization"] is None for item in self.server.journal))

    def test_all_redirect_statuses_are_measured_without_automatic_follow(self):
        port = self.server.server_address[1]
        for status in (301, 302, 307, 308):
            with self.subTest(status=status):
                self.ledger.unlink(missing_ok=True)
                self.output_path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.server.responses = [
                    (status, [("Location", f"https://localhost:{port}/download?signature=private")], b""),
                    (200, [("Content-Type", "application/octet-stream")], b"archive"),
                ]
                result = subprocess.run(
                    ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--follow-download",
                     "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
                     "--request", str(self.request_path), "--output", str(self.output_path),
                     "--body-output", str(self.body_path)],
                    cwd=ROOT, text=True, capture_output=True, timeout=10,
                    env={**os.environ, "GH_TOKEN": "ghp_testtoken-not-forwarded"},
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                ledger = json.loads(self.ledger.read_text())
                self.assertEqual([row["actual_status"] for row in ledger["transactions"]], [status, 200])
                self.assertTrue(all(row["charged"] for row in self.server.journal))
                self.assertTrue(all(row["authorization"] is None for row in self.server.journal))
                self.assertNotIn("signature=private", self.ledger.read_text() + self.output_path.read_text())

    def test_redirect_budget_exhaustion_charges_only_the_frozen_hops(self):
        port = self.server.server_address[1]
        allocation = json.loads(self.allocation_path.read_text())
        allocation["max_hops"] = 1
        self.allocation_path.write_text(json.dumps(allocation))
        self.server.responses = [
            (302, [("Location", f"https://localhost:{port}/download?one=secret")], b""),
            (307, [("Location", f"https://localhost:{port}/third?two=secret")], b""),
        ]
        result = subprocess.run(
            ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--follow-download",
             "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
             "--request", str(self.request_path), "--output", str(self.output_path)],
            cwd=ROOT, text=True, capture_output=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.server.journal), 2)
        self.assertTrue(all(row["charged"] for row in self.server.journal))
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual([row["actual_status"] for row in ledger["transactions"]], [302, 307])
        self.assertEqual(ledger["terminal_stop"]["code"], "redirect_budget_exhausted")
        self.assertNotIn("secret", self.ledger.read_text() + self.output_path.read_text())

    def test_unapproved_redirect_is_stopped_before_a_second_socket_request(self):
        self.server.responses = [(302, [("Location", "https://attacker.example/download?sig=secret")], b"")]
        result = subprocess.run(
            ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--follow-download",
             "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
             "--request", str(self.request_path), "--output", str(self.output_path)],
            cwd=ROOT, text=True, capture_output=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.server.journal), 1)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(ledger["terminal_stop"]["code"], "redirect_rejected")

    def test_pages_are_explicit_charged_requests_and_cycles_stop_at_the_frozen_limit(self):
        port = self.server.server_address[1]
        self.server.responses = [
            (200, [("Content-Type", "application/json"),
                   ("Link", f'<https://localhost:{port}/page/2>; rel="next"')], b'{"page":1}'),
            (200, [("Content-Type", "application/json"),
                   ("Link", f'<https://localhost:{port}/page/3>; rel="next"')], b'{"page":2}'),
        ]
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "test_page", "page_ordinal": 1}))
        result = subprocess.run(
            ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--fetch-pages",
             "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
             "--request", str(self.request_path), "--output", str(self.output_path)],
            cwd=ROOT, text=True, capture_output=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.server.journal), 2)
        self.assertTrue(all(item["charged"] for item in self.server.journal))
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual([item["page_ordinal"] for item in ledger["transactions"]], [1, 2])
        self.assertIsNotNone(ledger["terminal_stop"], result.stderr)
        self.assertEqual(ledger["terminal_stop"]["code"], "page_budget_or_cycle", result.stderr)

    def test_live_allocation_rejects_hermetic_test_origin_before_socket_use(self):
        allocation = json.loads(self.allocation_path.read_text())
        allocation["mode"] = "live"
        self.allocation_path.write_text(json.dumps(allocation))
        result = self.run_runner()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.server.journal, [])
        self.assertFalse(self.ledger.exists())

    def test_two_page_response_charges_both_wire_requests(self):
        port = self.server.server_address[1]
        self.server.responses = [
            (200, [("Content-Type", "application/json"),
                   ("Link", f'<https://localhost:{port}/page/2>; rel="next"')], b'{"page":1}'),
            (200, [("Content-Type", "application/json")], b'{"page":2}'),
        ]
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "test_page", "page_ordinal": 1}))
        result = subprocess.run(
            ["python3", str(ROOT / "scripts/ci/ci-hosted-transport.py"), "--fetch-pages",
             "--allocation", str(self.allocation_path), "--ledger", str(self.ledger),
             "--request", str(self.request_path), "--output", str(self.output_path),
             "--body-output", str(self.body_path)],
            cwd=ROOT, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), 2)
        self.assertEqual([row["page_ordinal"] for row in ledger["transactions"]], [1, 2])
        self.assertTrue(all(row["charged"] for row in self.server.journal))
        self.assertEqual(json.loads(self.body_path.read_text()), [{"page": 1}, {"page": 2}])

    def test_concurrent_requests_cannot_overspend_the_last_slot(self):
        allocation = json.loads(self.allocation_path.read_text())
        allocation["max_requests"] = 1
        self.allocation_path.write_text(json.dumps(allocation))
        command = ["bash", str(RUNNER), "--transport-probe", "--allocation", str(self.allocation_path),
                   "--ledger", str(self.ledger), "--request", str(self.request_path),
                   "--output", str(self.output_path)]
        first = subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second = subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        first.communicate(timeout=10)
        second.communicate(timeout=10)
        self.assertEqual(sorted([first.returncode, second.returncode]), [0, 1])
        self.assertEqual(len(self.server.journal), 1)
        self.assertEqual(len(json.loads(self.ledger.read_text())["transactions"]), 1)

    def test_rate_and_auth_hard_stops_prevent_a_later_network_request(self):
        for status in (401, 403, 429):
            with self.subTest(status=status):
                self.ledger.unlink(missing_ok=True)
                self.output_path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.server.responses = [(status, [("Retry-After", "60")], b"denied")]
                first = self.run_runner()
                self.assertNotEqual(first.returncode, 0)
                second = self.run_runner()
                self.assertNotEqual(second.returncode, 0)
                self.assertEqual(len(self.server.journal), 1)
                ledger = json.loads(self.ledger.read_text())
                self.assertEqual(ledger["transactions"][0]["actual_status"], status)
                self.assertIsNotNone(ledger["terminal_stop"])

    def test_exact_core_threshold_is_terminal(self):
        self.server.responses = [(200, [("X-RateLimit-Resource", "core"),
                                       ("X-RateLimit-Remaining", "250"),
                                       ("X-RateLimit-Reset", "1791909900")], b"{}")]
        result = self.run_runner()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.server.journal), 1)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(ledger["transactions"][0]["actual_status"], 200)
        self.assertEqual(ledger["terminal_stop"]["code"], "core_budget_stop")


PRODUCTION_CATEGORY_LIMITS = {
    "preflight": 8, "docs_publication": 14, "pr_create": 2, "pr_identity": 8, "run_discovery": 4,
    "pre_watch_rate": 2, "terminal_polls": 27, "attempt_jobs": 4, "native_checks": 4,
    "artifact_metadata": 4, "artifact_downloads": 20, "failure_logs": 2, "infrastructure_rerun": 21,
}


def load_transport():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_hosted_transport_under_test", ROOT / "scripts/ci/ci-hosted-transport.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TypedAllocationWireTests(unittest.TestCase):
    """Actual local-HTTPS wire contracts for canary/production allocation kinds and category predebits."""

    def setUp(self):
        self.transport = load_transport()
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-typed-allocation-")
        self.addCleanup(self.tmp.cleanup)
        self.tmp_path = pathlib.Path(self.tmp.name)
        cert, key = self.tmp_path / "server.pem", self.tmp_path / "server-key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost",
                        "-addext", "subjectAltName=DNS:localhost", "-keyout", str(key), "-out", str(cert)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.ledger = self.tmp_path / "ledger.json"
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), JournalHandler)
        self.server.ledger_path = self.ledger
        self.server.status = 200
        self.server.journal = []
        self.server.responses = []
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        self.server.socket = context.wrap_socket(self.server.socket, server_side=True)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.cert = cert
        self.port = self.server.server_address[1]
        self.allocation_path = self.tmp_path / "allocation.json"
        self.request_path = self.tmp_path / "request.json"
        self.output_path = self.tmp_path / "receipt.json"

    def allocation(self, kind="canary", max_requests=117, **extra):
        value = {"schema_version": "sigra.phase253.http-allocation/v1", "window_id": "typed-window",
                 "source_sha256": "a" * 64, "max_requests": max_requests, "max_elapsed_seconds": 3600,
                 "max_response_bytes": 4096, "max_pages": 2, "max_hops": 2, "repository": "szTheory/sigra",
                 "download_hosts": [], "mode": "hermetic-test", "test_origin": f"https://localhost:{self.port}",
                 "test_ca_file": str(self.cert)}
        if kind is not None:
            value["allocation_kind"] = kind
        value.update(extra)
        return value

    def write_allocation(self, value):
        self.allocation_path.write_text(json.dumps(value))

    def probe(self, **fields):
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "test_probe", **fields}))
        return self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)

    def test_kind_ceilings_are_separate_and_unknown_or_oversized_allocations_fail_before_io(self):
        validate = self.transport._validate_allocation
        validate(self.allocation(kind="canary", max_requests=117))
        validate(self.allocation(kind=None, max_requests=100))  # legacy allocations remain canary-kind
        validate(self.allocation(kind="production", max_requests=120, category_limits=PRODUCTION_CATEGORY_LIMITS))
        for broken in (
            self.allocation(kind="canary", max_requests=120),
            self.allocation(kind=None, max_requests=120),
            self.allocation(kind="production", max_requests=121, category_limits=PRODUCTION_CATEGORY_LIMITS),
            self.allocation(kind="production", max_requests=117, category_limits=PRODUCTION_CATEGORY_LIMITS),
            self.allocation(kind="Production", max_requests=120, category_limits=PRODUCTION_CATEGORY_LIMITS),
            self.allocation(kind="unknown", max_requests=10),
            self.allocation(kind="production", max_requests=120),
            self.allocation(kind="production", max_requests=120, category_limits={**PRODUCTION_CATEGORY_LIMITS, "preflight": 9}),
            self.allocation(kind="production", max_requests=120, category_limits={**PRODUCTION_CATEGORY_LIMITS, "extra": 1}),
            self.allocation(kind="canary", max_requests=117, category_limits={"a": 118}),
            self.allocation(kind="canary", max_requests=117, bound_documents=[{"path": "x", "sha256": "z"}]),
            self.allocation(kind="canary", max_requests=117, bound_documents="x"),
        ):
            with self.subTest(allocation=broken):
                with self.assertRaises(self.transport.TransportError):
                    validate(broken)

    def test_canary_wire_boundary_charges_exactly_117_then_stops_without_a_118th_socket_request(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=117))
        for _ in range(117):
            self.probe()
        self.assertEqual(len(self.server.journal), 117)
        with self.assertRaises(self.transport.TransportError) as caught:
            self.probe()
        self.assertEqual(caught.exception.code, "request_budget_exhausted")
        self.assertEqual(len(self.server.journal), 117)
        self.assertTrue(all(row["charged"] for row in self.server.journal))
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), 117)
        self.assertEqual(ledger["terminal_stop"]["code"], "request_budget_exhausted")

    def test_production_wire_boundary_charges_exactly_120_with_every_frozen_category(self):
        self.write_allocation(self.allocation(kind="production", max_requests=120, category_limits=PRODUCTION_CATEGORY_LIMITS))
        for category, limit in PRODUCTION_CATEGORY_LIMITS.items():
            for _ in range(limit):
                self.probe(category=category, family="shared")
        self.assertEqual(len(self.server.journal), 120)
        ledger = json.loads(self.ledger.read_text())
        counts = {}
        for row in ledger["transactions"]:
            counts[row["category"]] = counts.get(row["category"], 0) + 1
        self.assertEqual(counts, PRODUCTION_CATEGORY_LIMITS)
        with self.assertRaises(self.transport.TransportError) as caught:
            self.probe(category="preflight", family="shared")
        self.assertEqual(caught.exception.code, "request_budget_exhausted")
        self.assertEqual(len(self.server.journal), 120)

    def test_category_predebit_stops_before_the_wire_and_never_resets_via_parent_or_family(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=10, category_limits={"alpha": 1, "beta": 2}))
        self.probe(category="alpha", family="normal")
        with self.assertRaises(self.transport.TransportError) as caught:
            self.probe(category="alpha", family="docs-only")  # a different family never resets the category
        self.assertEqual(caught.exception.code, "category_budget_exhausted")
        self.assertEqual(len(self.server.journal), 1)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(ledger["terminal_stop"]["code"], "category_budget_exhausted")
        with self.assertRaises(self.transport.TransportError) as stopped:
            self.probe(category="beta", family="normal")  # terminal stop also blocks unrelated categories
        self.assertEqual(stopped.exception.code, "terminal_stop")
        self.assertEqual(len(self.server.journal), 1)

    def test_missing_or_unknown_category_is_rejected_when_limits_are_frozen(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=10, category_limits={"alpha": 1}))
        for fields in ({}, {"category": "nope"}, {"category": 3}):
            with self.subTest(fields=fields):
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.probe(**fields)
                self.assertEqual(caught.exception.code, "category_rejected")
        self.assertEqual(self.server.journal, [])

    def test_changed_limits_or_window_cannot_continue_an_existing_ledger(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=10, category_limits={"alpha": 1}))
        self.probe(category="alpha")
        for changed in (self.allocation(kind="canary", max_requests=10, category_limits={"alpha": 5}),
                        self.allocation(kind="canary", max_requests=10, category_limits={"alpha": 1}, window_id="fresh-window"),
                        self.allocation(kind="canary", max_requests=11, category_limits={"alpha": 1})):
            with self.subTest(changed=changed):
                self.write_allocation(changed)
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.probe(category="alpha")
                self.assertEqual(caught.exception.code, "ledger_identity_mismatch")
        self.assertEqual(len(self.server.journal), 1)

    def test_bound_document_digests_are_checked_before_any_network_io(self):
        document = self.tmp_path / "bound.txt"
        document.write_text("frozen")
        digest = hashlib.sha256(b"frozen").hexdigest()
        self.write_allocation(self.allocation(kind="canary", max_requests=5, bound_documents=[{"path": str(document), "sha256": digest}]))
        self.probe()
        document.write_text("changed")
        self.ledger.unlink()
        with self.assertRaises(self.transport.TransportError) as caught:
            self.probe()
        self.assertEqual(caught.exception.code, "bound_document_mismatch")
        self.assertEqual(len(self.server.journal), 1)
        self.write_allocation(self.allocation(kind="canary", max_requests=5, bound_documents=[{"path": str(self.tmp_path / "missing"), "sha256": digest}]))
        with self.assertRaises(self.transport.TransportError) as missing:
            self.probe()
        self.assertEqual(missing.exception.code, "bound_document_mismatch")

    def route(self, route_id, method="GET", **fields):
        request = {"route_id": route_id, "method": method, **fields}
        allocation = self.allocation(kind="production", max_requests=120, category_limits=PRODUCTION_CATEGORY_LIMITS)
        return self.transport._route(request, allocation)

    def test_pr_collector_routes_build_only_typed_repository_scoped_paths(self):
        sha, other = "a" * 40, "b" * 40
        self.assertEqual(self.route("pr_read", params={"pull_number": 7})[3], "/repos/szTheory/sigra/pulls/7")
        self.assertEqual(self.route("compare", params={"base_sha": sha, "head_sha": other}, query={"per_page": 100, "page": 1})[3],
                         f"/repos/szTheory/sigra/compare/{sha}...{other}?per_page=100&page=1")
        self.assertEqual(self.route("attempt_jobs", params={"run_id": 9, "attempt": 2}, query={"per_page": 100, "page": 1})[3],
                         "/repos/szTheory/sigra/actions/runs/9/attempts/2/jobs?per_page=100&page=1")
        self.assertEqual(self.route("repo_contents", params={"content_path": ".github/workflows/ci.yml"}, query={"ref": sha})[3],
                         f"/repos/szTheory/sigra/contents/.github/workflows/ci.yml?ref={sha}")
        self.assertEqual(self.route("workflow_runs", params={"workflow_id": 5}, query={"event": "pull_request", "head_sha": sha, "per_page": 100})[3],
                         f"/repos/szTheory/sigra/actions/workflows/5/runs?event=pull_request&head_sha={sha}&per_page=100")
        body = {"title": "Phase 253 proof", "head": "gsd/253-replan-candidate", "base": "main", "body": "draft", "draft": True}
        host, port, payload, path = self.route("pr_create", method="POST", body=body)
        self.assertEqual((path, host), ("/repos/szTheory/sigra/pulls", "localhost"))
        self.assertEqual(json.loads(payload)["draft"], True)

    def test_pr_collector_routes_reject_unsafe_parameters_bodies_and_queries(self):
        sha = "a" * 40
        bad_body = {"title": "t", "head": "gsd/253-replan-candidate", "base": "main", "body": "b", "draft": True}
        rejections = [
            ("pr_read", "GET", {"params": {"pull_number": 0}}),
            ("pr_read", "GET", {"params": {"pull_number": "7"}}),
            ("compare", "GET", {"params": {"base_sha": "main", "head_sha": sha}}),
            ("compare", "GET", {"params": {"base_sha": sha.upper(), "head_sha": sha}}),
            ("attempt_jobs", "GET", {"params": {"run_id": 9, "attempt": 0}}),
            ("repo_contents", "GET", {"params": {"content_path": "../secrets"}, "query": {"ref": sha}}),
            ("repo_contents", "GET", {"params": {"content_path": ".github/workflows/other.yml"}, "query": {"ref": sha}}),
            ("repo_contents", "GET", {"params": {"content_path": ".github/workflows/ci.yml"}, "query": {"ref": "main"}}),
            ("workflow_runs", "GET", {"params": {"workflow_id": 5}, "query": {"event": "push"}}),
            ("workflow_runs", "GET", {"params": {"workflow_id": 5}, "query": {"head_sha": "short"}}),
            ("pr_create", "POST", {"body": {**bad_body, "draft": False}}),
            ("pr_create", "POST", {"body": {**bad_body, "base": "release"}}),
            ("pr_create", "POST", {"body": {**bad_body, "head": "attacker:branch"}}),
            ("pr_create", "POST", {"body": {**bad_body, "extra": 1}}),
            ("pr_create", "POST", {"body": {**bad_body, "maintainer_can_modify": True}}),
            ("pr_read", "POST", {"params": {"pull_number": 7}, "body": {}}),
        ]
        for route_id, method, fields in rejections:
            with self.subTest(route=route_id, fields=fields):
                with self.assertRaises(self.transport.TransportError):
                    self.route(route_id, method=method, **fields)

    def test_253_102_pr_heads_are_exactly_the_two_candidates_and_the_docs_head(self):
        self.assertEqual(self.transport.PR_HEAD_REFS,
                         {"gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-r9-candidate",
                          "gsd/253-replan-docs-head"})
        self.assertEqual(self.transport.PR_BASE_REFS, {"main", "gsd/253-replan-docs-base"})
        body = {"title": "Phase 253 proof", "head": "gsd/253-replan-r8-candidate", "base": "main", "body": "draft", "draft": True}
        self.assertEqual(self.route("pr_create", method="POST", body=body)[3], "/repos/szTheory/sigra/pulls")
        for head in ("gsd/253-replan-r8-fixture", "gsd/253-replan-fixture", "gsd/253-replan-r10-candidate",
                     "gsd/253-replan-r8-candidate-x", "refs/heads/gsd/253-replan-r8-candidate"):
            with self.subTest(head=head):
                with self.assertRaises(self.transport.TransportError):
                    self.route("pr_create", method="POST", body={**body, "head": head})

    def test_253_102_create_ref_accepts_both_r8_names_under_the_unchanged_namespace_rule(self):
        allocation = self.allocation(kind="canary", max_requests=117)
        for ref in ("refs/heads/gsd/253-replan-r8-candidate", "refs/heads/gsd/253-replan-r8-fixture"):
            with self.subTest(ref=ref):
                request = {"route_id": "create_ref", "method": "POST", "body": {"ref": ref, "sha": "a" * 40}}
                self.assertEqual(self.transport._route(request, allocation)[3], "/repos/szTheory/sigra/git/refs")
        source = TRANSPORT_SOURCE.read_text()
        self.assertIn('r"refs/heads/gsd/253-replan-[a-z0-9][a-z0-9-]{0,100}", ref)', source)

    def test_253_111_pr_create_accepts_the_r9_candidate_and_refuses_the_r9_fixture_and_a_fourth_name(self):
        body = {"title": "Phase 253 proof", "head": "gsd/253-replan-r9-candidate", "base": "main", "body": "draft", "draft": True}
        self.assertEqual(self.route("pr_create", method="POST", body=body)[3], "/repos/szTheory/sigra/pulls")
        for head in ("gsd/253-replan-r9-fixture", "gsd/253-replan-r10-candidate", "gsd/253-replan-r9-candidate-x",
                     "refs/heads/gsd/253-replan-r9-candidate", "szTheory:gsd/253-replan-r9-candidate"):
            with self.subTest(head=head):
                with self.assertRaises(self.transport.TransportError):
                    self.route("pr_create", method="POST", body={**body, "head": head})
        for base in ("gsd/253-replan-r9-candidate", "gsd/253-replan-r8-candidate", "release"):
            with self.subTest(base=base):
                with self.assertRaises(self.transport.TransportError):
                    self.route("pr_create", method="POST", body={**body, "base": base})

    def test_253_111_create_ref_accepts_both_r9_names_under_the_unchanged_namespace_rule(self):
        allocation = self.allocation(kind="canary", max_requests=117)
        for ref in ("refs/heads/gsd/253-replan-r9-candidate", "refs/heads/gsd/253-replan-r9-fixture"):
            with self.subTest(ref=ref):
                request = {"route_id": "create_ref", "method": "POST", "body": {"ref": ref, "sha": "a" * 40}}
                self.assertEqual(self.transport._route(request, allocation)[3], "/repos/szTheory/sigra/git/refs")
        self.assertEqual(self.transport.PR_BASE_REFS, {"main", "gsd/253-replan-docs-base"})
        source = TRANSPORT_SOURCE.read_text()
        self.assertEqual(source.count('r"refs/heads/gsd/253-replan-[a-z0-9][a-z0-9-]{0,100}", ref)'), 1)

    def test_legacy_canary_hermetic_allocation_still_rejects_pr_collector_routes(self):
        request = {"route_id": "pr_read", "method": "GET", "params": {"pull_number": 7}}
        with self.assertRaises(self.transport.TransportError):
            self.transport._route(request, self.allocation(kind="canary", max_requests=10))

    # -- 253-101: hermetic canary routing (offline dry-run of the whole canary) ---------------------------
    def canary_requests(self):
        sha = "a" * 40
        return [
            ("rate_limit", {"method": "GET"}),
            ("rules_main", {"method": "GET", "query": {"per_page": 100, "page": 1}}),
            ("branch_protection", {"method": "GET"}),
            ("check_runs", {"method": "GET", "params": {"commit_sha": sha}, "query": {"per_page": 100, "page": 1}}),
            ("workflow", {"method": "GET", "params": {"workflow_id": 259268962}}),
            ("workflow_runs", {"method": "GET", "params": {"workflow_id": 259268962},
                               "query": {"event": "workflow_dispatch", "branch": "gsd/253-replan-fixture", "per_page": 100}}),
            ("run", {"method": "GET", "params": {"run_id": 9}}),
            ("run_jobs", {"method": "GET", "params": {"run_id": 9}, "query": {"per_page": 100}}),
            ("run_artifacts", {"method": "GET", "params": {"run_id": 9}, "query": {"per_page": 100}}),
            ("dispatch", {"method": "POST", "params": {"workflow_id": 259268962},
                          "body": {"ref": "gsd/253-replan-fixture", "inputs": {"scenario": "full-pass"}}}),
            ("cancel_run", {"method": "POST", "params": {"run_id": 9}, "body": {}}),
            ("get_ref", {"method": "GET", "params": {"branch": "gsd/253-replan-fixture"}}),
            ("create_ref", {"method": "POST", "body": {"ref": "refs/heads/gsd/253-replan-fixture", "sha": sha}}),
            ("git_get_commit", {"method": "GET", "params": {"sha": sha}}),
            ("artifact_zip", {"method": "GET", "params": {"artifact_id": 5}}),
            ("run_logs", {"method": "GET", "params": {"run_id": 9}}),
        ]

    def test_hermetic_canary_allocation_routes_every_canary_route_to_its_local_origin(self):
        allocation = self.allocation(kind="canary", max_requests=117)
        for route_id, fields in self.canary_requests():
            with self.subTest(route=route_id):
                host, port, _, path = self.transport._route({"route_id": route_id, **fields}, allocation)
                self.assertEqual((host, port), ("localhost", self.port))
                self.assertTrue(path == "/rate_limit" or path.startswith("/repos/szTheory/sigra/"), path)

    def test_hermetic_canary_non_git_routes_are_answered_by_the_local_https_server_without_credentials(self):
        limits = {"preflight": 2, "cancellation": 1}
        self.write_allocation(self.allocation(kind="canary", max_requests=117, category_limits=limits))
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "rate_limit", "category": "preflight"}))
        receipt, _, _, _ = self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)
        self.assertEqual(receipt["actual_status"], 200)
        self.request_path.write_text(json.dumps({"method": "POST", "route_id": "cancel_run", "category": "cancellation",
                                                 "params": {"run_id": 9}, "body": {}}))
        self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)
        self.assertEqual([row["path"] for row in self.server.journal], ["/rate_limit", "/repos/szTheory/sigra/actions/runs/9/cancel"])
        self.assertTrue(all(row["charged"] and row["authorization"] is None for row in self.server.journal))
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual({row["host"] for row in ledger["transactions"]}, {"localhost"})
        self.assertTrue(all(row["url"].startswith("https://localhost/") for row in ledger["transactions"]))

    def test_hermetic_canary_allocation_naming_a_non_local_origin_is_refused(self):
        for origin in ("https://api.github.com:443", "https://example.com:4443", f"http://localhost:{self.port}",
                       "https://localhost", f"https://user@localhost:{self.port}"):
            with self.subTest(origin=origin):
                allocation = self.allocation(kind="canary", max_requests=117, test_origin=origin)
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.transport._route({"route_id": "rate_limit", "method": "GET"}, allocation)
                self.assertEqual(caught.exception.code, "test_origin_rejected")

    def test_live_canary_allocation_still_sends_every_canary_route_only_to_api_github_com(self):
        live = self.allocation(kind="canary", max_requests=117, mode="live")
        live.pop("test_origin"), live.pop("test_ca_file")
        self.transport._validate_allocation(live)
        for route_id, fields in self.canary_requests():
            with self.subTest(route=route_id):
                host, port, _, _ = self.transport._route({"route_id": route_id, **fields}, live)
                self.assertEqual((host, port), ("api.github.com", 443))
        for extra in ({"test_origin": f"https://localhost:{self.port}"}, {"test_ca_file": str(self.cert)}):
            with self.subTest(extra=extra):
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.transport._validate_allocation({**live, **extra})
                self.assertIn(caught.exception.code, {"allocation_field_rejected", "test_origin_rejected"})

    def test_hermetic_canary_routing_keeps_the_category_predebit_and_the_117_cap(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=117, category_limits={"preflight": 1, "dispatch": 1}))
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "rate_limit", "category": "preflight"}))
        self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)
        with self.assertRaises(self.transport.TransportError) as caught:
            self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)
        self.assertEqual(caught.exception.code, "category_budget_exhausted")
        self.assertEqual(len(self.server.journal), 1)
        with self.assertRaises(self.transport.TransportError) as capped:
            self.transport._validate_allocation(self.allocation(kind="canary", max_requests=118))
        self.assertEqual(capped.exception.code, "allocation_limit_invalid")

    def test_a_dispatch_receipt_and_ledger_row_carry_the_exact_transmitted_input_metrics(self):
        self.write_allocation(self.allocation(kind="canary", max_requests=117, category_limits={"dispatch": 1}))
        inputs = {"scenario": "full-pass", "candidate_sha": "a" * 40, "fixture_sha": "b" * 40, "fixture_blob": "c" * 40}
        self.request_path.write_text(json.dumps({"method": "POST", "route_id": "dispatch", "category": "dispatch",
                                                 "params": {"workflow_id": 259268962},
                                                 "body": {"ref": "gsd/253-replan-fixture", "inputs": inputs}}))
        receipt, _, _, _ = self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path)
        canonical = self.transport.serialize_dispatch_inputs(inputs)
        row = json.loads(self.ledger.read_text())["transactions"][0]
        for record in (receipt, row):
            self.assertEqual(record["dispatch_inputs"], inputs)
            self.assertEqual(record["input_key_count"], 4)
            self.assertEqual(record["input_utf8_bytes"], len(canonical))
            self.assertEqual(record["input_sha256"], hashlib.sha256(canonical).hexdigest())
        self.assertEqual(self.server.journal[0]["path"], "/repos/szTheory/sigra/actions/workflows/259268962/dispatches")

    def test_a_kindless_legacy_hermetic_allocation_still_needs_a_live_allocation_for_non_git_routes(self):
        with self.assertRaises(self.transport.TransportError) as caught:
            self.transport._route({"route_id": "rate_limit", "method": "GET"}, self.allocation(kind=None, max_requests=10))
        self.assertEqual(caught.exception.code, "live_allocation_required")


# -- 253-107: LIVE-mode approved redirect through the live-policy shim ----------------------------------
SHIM_SOURCE = ROOT / "scripts/ci/ci-live-policy-shim.py"
R8_ALLOCATION = ROOT / ".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ALLOCATION-R8.json"
DUMMY_TOKEN = "dummy-not-a-credential-253-107"
BLOB_HOST = "productionresultssa17.blob.core.windows.net"
ARTIFACT_PATH = "/repos/szTheory/sigra/actions/artifacts/11999138572/zip"
BLOB_LOCATION = f"https://{BLOB_HOST}/x/artifact.zip?sv=2025&sig=redacted"
# Every name the local server answers for; only the trusted ones are ever expected on the wire.
SHIM_HOSTS = ("api.github.com", BLOB_HOST, "productionresultssa41.blob.core.windows.net",
              "pipelines.actions.githubusercontent.com", "evil.example.com",
              "productionresultssa17.blob.core.windows.net.evil.example")


def load_shim():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ci_live_policy_shim_under_test", SHIM_SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def small_zip() -> bytes:
    import io
    import zipfile
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("canary-result.json", '{"scenario":"full-pass"}\n')
    return buffer.getvalue()


class LiveHostHandler(http.server.BaseHTTPRequestHandler):
    """Answers by Host header, like the real hosts would; journals every request it actually received."""
    protocol_version = "HTTP/1.1"

    def do_GET(self):  # noqa: N802
        host = (self.headers.get("Host") or "").split(":", 1)[0].lower()
        route_path = self.path.split("?", 1)[0]
        status, response_headers, payload = self.server.routes.get(
            (host, self.path), self.server.routes.get((host, route_path), (404, [], b'{"message":"Not Found"}')))
        self.send_response(status)
        for name, value in response_headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
        self.server.journal.append({"host": host, "path": self.path, "status": status,
                                    "authorization": self.headers.get("Authorization"), "accept": self.headers.get("Accept")})

    def log_message(self, *_args):
        pass


class LivePolicyRedirectTests(unittest.TestCase):
    """The allocation mode is ``live``: every policy branch of the transport runs; only sockets/TLS are local."""

    def setUp(self):
        self.shim = load_shim()
        self.transport = load_transport()
        self.tmp = tempfile.TemporaryDirectory(prefix="sigra-253-live-policy-")
        self.addCleanup(self.tmp.cleanup)
        self.tmp_path = pathlib.Path(self.tmp.name)
        self.cert, key = self.shim.make_tls_identity(self.tmp_path / "tls", (
            "api.github.com", "*.blob.core.windows.net", "pipelines.actions.githubusercontent.com",
            "evil.example.com", "productionresultssa17.blob.core.windows.net.evil.example"))
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), LiveHostHandler)
        self.server.journal = []
        self.server.sni = []
        self.server.routes = {
            ("api.github.com", ARTIFACT_PATH): (302, [("Location", BLOB_LOCATION)], b""),
            (BLOB_HOST, "/x/artifact.zip"): (200, [("Content-Type", "application/zip")], small_zip()),
        }
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.cert, key)
        context.sni_callback = lambda _sock, name, _ctx: self.server.sni.append(name)
        self.server.socket = context.wrap_socket(self.server.socket, server_side=True)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.port = self.server.server_address[1]
        self.connect_log = self.tmp_path / "connect.jsonl"
        self.refusal_log = self.shim.refusal_log_for(self.connect_log)
        self.shim_env = self.shim.prepare(self.tmp_path / "site", {host: self.port for host in SHIM_HOSTS},
                                          self.cert, self.connect_log)
        bound = self.tmp_path / "bound.txt"
        bound.write_text("253-107 live-policy test binding\n")
        allocation = json.loads(R8_ALLOCATION.read_text())
        allocation["window_id"] = "253-107-live-redirect-test"
        allocation["bound_documents"] = [{"path": str(bound), "sha256": hashlib.sha256(bound.read_bytes()).hexdigest()}]
        self.allocation = allocation
        self.allocation_path = self.tmp_path / "allocation.json"
        self.ledger = self.tmp_path / "ledger.json"
        self.request_path = self.tmp_path / "request.json"
        self.output_path = self.tmp_path / "receipt.json"
        self.body_path = self.tmp_path / "artifact.zip"
        self.write_allocation()
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads",
                                                 "params": {"artifact_id": 11999138572}}))

    def write_allocation(self):
        self.allocation_path.write_text(json.dumps(self.allocation))

    def child_env(self):
        env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN", "PYTHONPATH"}}
        env.update(self.shim_env)
        env["GH_TOKEN"] = DUMMY_TOKEN
        return env

    def follow(self):
        return subprocess.run(
            ["python3", str(TRANSPORT_SOURCE), "--follow-download", "--allocation", str(self.allocation_path),
             "--ledger", str(self.ledger), "--request", str(self.request_path), "--output", str(self.output_path),
             "--body-output", str(self.body_path)],
            cwd=ROOT, env=self.child_env(), text=True, capture_output=True, timeout=30)

    def connects(self):
        return [(row["host"], row["port"]) for row in self.shim.read_log(self.connect_log)]

    def test_live_allocation_is_really_live(self):
        self.assertEqual(self.allocation["mode"], "live")
        self.assertFalse({"test_origin", "test_ca_file"} & set(self.allocation))
        self.transport._validate_allocation(self.allocation)
        self.assertEqual(self.transport._route(json.loads(self.request_path.read_text()), self.allocation)[:2],
                         ("api.github.com", 443))

    def test_shim_refuses_an_unmapped_destination_positive_control(self):
        probe = ("import socket, sys\n"
                 "try:\n"
                 "    socket.create_connection(('example.invalid', 443), timeout=2)\n"
                 "except OSError as exc:\n"
                 "    print(exc); sys.exit(7)\n"
                 "sys.exit(0)\n")
        result = subprocess.run(["python3", "-c", probe], cwd=self.tmp_path, env=self.child_env(),
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertIn("live-policy shim refused real network destination example.invalid:443", result.stdout)
        refusals = self.shim.read_log(self.refusal_log)
        self.assertEqual([(row["event"], row["host"], row["port"]) for row in refusals],
                         [("refused_connect", "example.invalid", 443)])
        self.assertEqual(self.connects(), [])
        # Without the variable the shim is inert even with the sitecustomize on PYTHONPATH.
        inert = {key: value for key, value in self.child_env().items() if key != self.shim.ENV_VAR}
        check = subprocess.run(["python3", "-c", "import socket, ssl; print(socket.create_connection.__module__)"],
                               cwd=self.tmp_path, env=inert, text=True, capture_output=True, timeout=15)
        self.assertEqual(check.stdout.strip(), "socket", check.stderr)

    def test_live_artifact_zip_follows_the_approved_redirect_to_the_trusted_blob_host(self):
        result = self.follow()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.body_path.read_bytes(), small_zip())
        ledger = json.loads(self.ledger.read_text())
        rows = ledger["transactions"]
        self.assertEqual(len(rows), 2)
        self.assertIsNone(ledger["terminal_stop"])
        self.assertEqual([row["state"] for row in rows], ["complete", "complete"])
        self.assertEqual(len({row["request_group"] for row in rows}), 1)
        self.assertIsNotNone(rows[0]["request_group"])
        self.assertEqual([row["hop_ordinal"] for row in rows], [0, 1])
        self.assertEqual([row["host"] for row in rows], ["api.github.com", BLOB_HOST])
        self.assertEqual([row["actual_status"] for row in rows], [302, 200])
        self.assertEqual([row["category"] for row in rows], ["artifact_downloads", "artifact_downloads"])
        self.assertEqual(rows[1]["url"], f"https://{BLOB_HOST}/x/artifact.zip?[REDACTED]")
        self.assertNotIn("sig=redacted", self.ledger.read_text() + self.output_path.read_text())
        self.assertEqual(self.connects(), [("api.github.com", 443), (BLOB_HOST, 443)])
        self.assertEqual([(row["host"], row["authorization"]) for row in self.server.journal],
                         [("api.github.com", f"Bearer {DUMMY_TOKEN}"), (BLOB_HOST, None)])
        self.assertEqual(self.server.sni, ["api.github.com", BLOB_HOST])
        self.assertEqual(self.shim.read_log(self.refusal_log), [])

    # -- negative matrix: every refused destination fails closed in the transport, never in the shim ------
    def assert_refused_after_hop_zero(self, location, expected_code):
        self.server.routes[("api.github.com", ARTIFACT_PATH)] = (302, [("Location", location)], b"")
        result = self.follow()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(f"ci-hosted-transport: {expected_code}:", result.stderr)
        self.assertEqual(self.connects(), [("api.github.com", 443)])
        self.assertEqual([row["host"] for row in self.server.journal], ["api.github.com"])
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual(len(ledger["transactions"]), 1)  # exactly the charged hop 0
        self.assertEqual(ledger["transactions"][0]["hop_ordinal"], 0)
        self.assertEqual(ledger["transactions"][0]["host"], "api.github.com")
        self.assertEqual(ledger["transactions"][0]["actual_status"], 302)
        self.assertEqual(ledger["terminal_stop"]["code"], expected_code)
        self.assertEqual(self.shim.read_log(self.refusal_log), [])
        # Only hop 0's empty 302 body may have been written; never a downloaded archive.
        self.assertEqual(self.body_path.read_bytes() if self.body_path.exists() else b"", b"")

    def test_live_redirect_to_an_untrusted_host_is_refused_before_its_socket(self):
        self.assert_refused_after_hop_zero("https://evil.example.com/a.zip", "redirect_rejected")

    def test_live_redirect_to_a_lookalike_host_is_refused_before_its_socket(self):
        self.assert_refused_after_hop_zero(f"https://{BLOB_HOST}.evil.example/a.zip", "redirect_rejected")

    def test_live_redirect_over_http_is_refused_before_its_socket(self):
        self.assert_refused_after_hop_zero(f"http://{BLOB_HOST}/a.zip", "malformed_location")

    def test_live_redirect_to_port_8443_is_refused_before_its_socket(self):
        self.assert_refused_after_hop_zero(f"https://{BLOB_HOST}:8443/a.zip", "redirect_rejected")

    def test_live_redirect_to_a_policy_trusted_host_absent_from_download_hosts_is_refused(self):
        self.assertNotIn("productionresultssa41.blob.core.windows.net", self.allocation["download_hosts"])
        self.assert_refused_after_hop_zero("https://productionresultssa41.blob.core.windows.net/a.zip", "redirect_rejected")

    def test_live_redirect_with_userinfo_or_fragment_is_refused_before_its_socket(self):
        for location in (f"https://user@{BLOB_HOST}/a.zip", f"https://{BLOB_HOST}/a.zip#frag"):
            with self.subTest(location=location):
                for path in (self.ledger, self.output_path, self.connect_log):
                    path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.assert_refused_after_hop_zero(location, "malformed_location")

    def test_live_redirect_to_api_github_com_is_refused_because_it_is_never_a_download_host(self):
        self.assert_refused_after_hop_zero(f"https://api.github.com{ARTIFACT_PATH}?again=1", "redirect_rejected")

    def direct(self, request, destination):
        self.request_path.write_text(json.dumps(request))
        os.environ["GH_TOKEN"] = DUMMY_TOKEN
        try:
            with self.shim.patched({host: self.port for host in SHIM_HOSTS}, self.cert, self.connect_log):
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.transport.request_one(self.allocation_path, self.ledger, self.request_path, self.output_path,
                                               None, destination)
        finally:
            os.environ.pop("GH_TOKEN", None)
        return caught.exception.code

    def test_direct_destination_calls_outside_the_live_hop_rule_are_refused_before_the_predebit(self):
        # Seed the ledger with one charged, complete request so "count unchanged" is a real observation.
        self.server.routes[("api.github.com", ARTIFACT_PATH)] = (200, [("Content-Type", "application/zip")], small_zip())
        self.assertEqual(self.follow().returncode, 0)
        self.assertEqual(len(json.loads(self.ledger.read_text())["transactions"]), 1)
        self.connect_log.unlink()
        self.server.journal.clear()
        artifact = {"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads",
                    "params": {"artifact_id": 11999138572}}
        run = {"method": "GET", "route_id": "run", "category": "artifact_downloads", "params": {"run_id": 38791286863}}
        blob = (BLOB_HOST, 443, "/x")
        cases = [
            ("non-API host at hop 0", dict(artifact, hop_ordinal=0), blob),
            ("non-API host with hop absent", artifact, blob),
            ("trusted destination on a non-download route", dict(run, hop_ordinal=1), blob),
            ("api.github.com is not a hop >= 1 destination", dict(artifact, hop_ordinal=1), ("api.github.com", 443, ARTIFACT_PATH)),
            ("policy-trusted host absent from download_hosts", dict(artifact, hop_ordinal=1),
             ("productionresultssa41.blob.core.windows.net", 443, "/x")),
            ("untrusted host at hop 1", dict(artifact, hop_ordinal=1), ("evil.example.com", 443, "/x")),
            ("trusted host on port 8443", dict(artifact, hop_ordinal=1), (BLOB_HOST, 8443, "/x")),
            ("hop beyond max_hops", dict(artifact, hop_ordinal=3), blob),
            ("boolean hop ordinal", dict(artifact, hop_ordinal=True), blob),
        ]
        for name, request, destination in cases:
            with self.subTest(case=name):
                self.assertEqual(self.direct(request, destination), "origin_rejected")
                self.assertEqual(len(json.loads(self.ledger.read_text())["transactions"]), 1)
                self.assertIsNone(json.loads(self.ledger.read_text())["terminal_stop"])
        self.assertEqual(self.shim.read_log(self.connect_log), [])
        self.assertEqual(self.server.journal, [])
        self.assertEqual(self.shim.read_log(self.refusal_log), [])

    def test_direct_destination_call_on_a_fresh_window_leaves_no_ledger(self):
        request = {"method": "GET", "route_id": "artifact_zip", "category": "artifact_downloads",
                   "params": {"artifact_id": 11999138572}, "hop_ordinal": 0}
        self.assertEqual(self.direct(request, (BLOB_HOST, 443, "/x")), "origin_rejected")
        self.assertFalse(self.ledger.exists())
        self.assertEqual(self.shim.read_log(self.connect_log), [])

    # -- positive controls in the same suite ---------------------------------------------------------------
    def test_run_logs_follow_to_pipelines_host_without_authorization(self):
        logs_path = "/repos/szTheory/sigra/actions/runs/38791286863/logs"
        self.server.routes[("api.github.com", logs_path)] = (
            302, [("Location", "https://pipelines.actions.githubusercontent.com/logs/run.zip?sig=private")], b"")
        self.server.routes[("pipelines.actions.githubusercontent.com", "/logs/run.zip")] = (
            200, [("Content-Type", "application/zip")], small_zip())
        self.request_path.write_text(json.dumps({"method": "GET", "route_id": "run_logs", "category": "failure_logs",
                                                 "params": {"run_id": 38791286863}}))
        result = self.follow()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.body_path.read_bytes(), small_zip())
        self.assertEqual(self.connects(), [("api.github.com", 443), ("pipelines.actions.githubusercontent.com", 443)])
        self.assertEqual([(row["host"], row["authorization"]) for row in self.server.journal],
                         [("api.github.com", f"Bearer {DUMMY_TOKEN}"), ("pipelines.actions.githubusercontent.com", None)])
        rows = json.loads(self.ledger.read_text())["transactions"]
        self.assertEqual([(row["hop_ordinal"], row["category"]) for row in rows], [(0, "failure_logs"), (1, "failure_logs")])
        self.assertNotIn("sig=private", self.ledger.read_text() + self.output_path.read_text())
        self.assertEqual(self.shim.read_log(self.refusal_log), [])

    def test_live_max_hops_one_with_two_redirects_stops_with_redirect_budget_exhausted(self):
        self.allocation["max_hops"] = 1
        self.write_allocation()
        self.server.routes[(BLOB_HOST, "/x/artifact.zip")] = (
            302, [("Location", "https://productionresultssa18.blob.core.windows.net/y.zip?sig=two")], b"")
        result = self.follow()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("redirect_budget_exhausted", result.stderr)
        ledger = json.loads(self.ledger.read_text())
        self.assertEqual([(row["host"], row["actual_status"]) for row in ledger["transactions"]],
                         [("api.github.com", 302), (BLOB_HOST, 302)])
        self.assertEqual(ledger["terminal_stop"]["code"], "redirect_budget_exhausted")
        self.assertEqual(self.connects(), [("api.github.com", 443), (BLOB_HOST, 443)])
        self.assertEqual(self.shim.read_log(self.refusal_log), [])

    # -- 253-110: live-side gaps the hermetic-vs-live audit found ------------------------------------------
    def test_live_accept_header_is_github_json_on_api_github_com_and_plain_json_on_the_download_host(self):
        self.assertEqual(self.follow().returncode, 0)
        self.assertEqual([(row["host"], row["accept"]) for row in self.server.journal],
                         [("api.github.com", "application/vnd.github+json"), (BLOB_HOST, "application/json")])

    RUNS_QUERY = {"event": "workflow_dispatch", "per_page": 100}

    def runs_request(self):
        return {"method": "GET", "route_id": "workflow_runs", "category": "run_discovery",
                "params": {"workflow_id": 259268962}, "query": dict(self.RUNS_QUERY)}

    def runs_path(self, page):
        request = dict(self.runs_request(), query={**self.RUNS_QUERY, "page": page})
        return self.transport._route(request, self.allocation)[3]

    def fetch_pages(self, request):
        self.request_path.write_text(json.dumps(request))
        return subprocess.run(
            ["python3", str(TRANSPORT_SOURCE), "--fetch-pages", "--allocation", str(self.allocation_path),
             "--ledger", str(self.ledger), "--request", str(self.request_path), "--output", str(self.output_path),
             "--body-output", str(self.body_path)],
            cwd=ROOT, env=self.child_env(), text=True, capture_output=True, timeout=30)

    def serve_runs(self, link):
        first = json.dumps({"total_count": 2, "workflow_runs": [{"id": 1}]}).encode()
        second = json.dumps({"total_count": 2, "workflow_runs": [{"id": 2}]}).encode()
        headers = [("Content-Type", "application/json")]
        self.server.routes[("api.github.com", self.runs_path(1))] = (200, headers + ([("Link", link)] if link else []), first)
        self.server.routes[("api.github.com", self.runs_path(2))] = (200, headers, second)

    def test_live_pagination_follows_an_api_github_com_next_link_as_a_second_charged_api_request(self):
        self.serve_runs(f'<https://api.github.com{self.runs_path(2)}>; rel="next", '
                        f'<https://api.github.com{self.runs_path(2)}>; rel="last"')
        result = self.fetch_pages(self.runs_request())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([run["id"] for run in json.loads(self.body_path.read_text())["workflow_runs"]], [1, 2])
        rows = json.loads(self.ledger.read_text())["transactions"]
        self.assertEqual([(row["host"], row["page_ordinal"], row["category"]) for row in rows],
                         [("api.github.com", 1, "run_discovery"), ("api.github.com", 2, "run_discovery")])
        self.assertEqual([(row["host"], row["path"], row["authorization"]) for row in self.server.journal],
                         [("api.github.com", self.runs_path(page), f"Bearer {DUMMY_TOKEN}") for page in (1, 2)])
        self.assertEqual(self.connects(), [("api.github.com", 443), ("api.github.com", 443)])
        self.assertEqual(self.shim.read_log(self.refusal_log), [])

    def test_live_pagination_refuses_every_link_off_api_github_com_or_off_the_route_before_a_second_request(self):
        page2 = self.runs_path(2)
        path_only, query = page2.split("?", 1)
        links = {
            "foreign host": f"https://evil.example.com{page2}",
            "blob host": f"https://{BLOB_HOST}{page2}",
            "the hermetic local origin": f"https://localhost:{self.port}{page2}",
            "http": f"http://api.github.com{page2}",
            "port 8443": f"https://api.github.com:8443{page2}",
            "userinfo": f"https://user@api.github.com{page2}",
            "fragment": f"https://api.github.com{page2}#frag",
            "a different route": f"https://api.github.com/repos/szTheory/sigra/actions/runs?{query}",
            "an unapproved query key": f"https://api.github.com{page2}&status=completed",
            "a page that does not advance by one": f"https://api.github.com{path_only}?{query.replace('page=2', 'page=3')}",
        }
        # Userinfo and fragments are already refused by the response-header scrubber, before _next_page_url runs.
        earlier = {"userinfo": "malformed_location", "fragment": "malformed_location"}
        for label, target in links.items():
            code = earlier.get(label, "pagination_destination_rejected")
            with self.subTest(link=label):
                for path in (self.ledger, self.output_path, self.body_path, self.connect_log):
                    path.unlink(missing_ok=True)
                self.server.journal.clear()
                self.serve_runs(f'<{target}>; rel="next"')
                result = self.fetch_pages(self.runs_request())
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(f"ci-hosted-transport: {code}:", result.stderr)
                ledger = json.loads(self.ledger.read_text())
                self.assertEqual([(row["host"], row["page_ordinal"]) for row in ledger["transactions"]], [("api.github.com", 1)])
                self.assertEqual(ledger["terminal_stop"]["code"], code)
                self.assertEqual([row["path"] for row in self.server.journal], [self.runs_path(1)], "no second request")
                self.assertEqual(self.connects(), [("api.github.com", 443)])
                self.assertEqual(self.shim.read_log(self.refusal_log), [])

    def test_live_full_first_rules_page_is_followed_by_one_charged_second_rules_page_on_api_github_com(self):
        request = {"method": "GET", "route_id": "rules_main", "category": "preflight", "query": {"per_page": 100}}
        path = lambda page: self.transport._route(dict(request, query={"per_page": 100, "page": page}), self.allocation)[3]
        headers = [("Content-Type", "application/json")]
        self.server.routes[("api.github.com", path(1))] = (200, headers, json.dumps([{"type": "rule", "n": n} for n in range(100)]).encode())
        self.server.routes[("api.github.com", path(2))] = (200, headers, json.dumps([{"type": "rule", "n": 100}]).encode())
        result = self.fetch_pages(request)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(self.body_path.read_text())), 101)
        rows = json.loads(self.ledger.read_text())["transactions"]
        self.assertEqual([(row["host"], row["page_ordinal"], row["category"]) for row in rows],
                         [("api.github.com", 1, "preflight"), ("api.github.com", 2, "preflight")])
        self.assertEqual([row["path"] for row in self.server.journal], [path(1), path(2)])
        self.assertEqual(self.connects(), [("api.github.com", 443), ("api.github.com", 443)])


class LivePolicyAllocationTests(unittest.TestCase):
    """253-110: the live side of _validate_allocation and _route's test-only routes, offline (no socket at all)."""

    def setUp(self):
        self.transport = load_transport()
        self.live = json.loads(R8_ALLOCATION.read_text())
        self.assertEqual(self.live["mode"], "live")
        self.transport._validate_allocation(self.live)

    def refused(self, allocation):
        with self.assertRaises(self.transport.TransportError) as caught:
            self.transport._validate_allocation(allocation)
        return caught.exception.code

    def test_live_download_hosts_must_be_a_unique_list_of_trusted_hosts_only(self):
        trusted = self.live["download_hosts"]
        self.assertIn("pipelines.actions.githubusercontent.com", trusted)
        cases = {
            "missing": {key: value for key, value in self.live.items() if key != "download_hosts"},
            "not a list": dict(self.live, download_hosts="productionresultssa17.blob.core.windows.net"),
            "duplicated": dict(self.live, download_hosts=trusted + [trusted[0]]),
            "untrusted": dict(self.live, download_hosts=trusted + ["evil.example.com"]),
            "lookalike": dict(self.live, download_hosts=["productionresultssa17.blob.core.windows.net.evil.example"]),
            "api.github.com": dict(self.live, download_hosts=["api.github.com"]),
            "uppercase blob": dict(self.live, download_hosts=["PRODUCTIONRESULTSSA17.blob.core.windows.net"]),
        }
        for label, allocation in cases.items():
            with self.subTest(case=label):
                self.assertEqual(self.refused(allocation), "download_host_allocation")
        for accepted in ([], ["pipelines.actions.githubusercontent.com"], ["productionresultssa0.blob.core.windows.net"]):
            with self.subTest(accepted=accepted):
                self.transport._validate_allocation(dict(self.live, download_hosts=accepted))

    def test_live_canary_max_requests_is_one_through_117_while_hermetic_may_be_zero(self):
        base = {key: value for key, value in self.live.items() if key != "category_limits"}
        for value in (1, 117):
            self.transport._validate_allocation(dict(base, max_requests=value))
        for value in (0, 118, True):
            with self.subTest(max_requests=value):
                self.assertEqual(self.refused(dict(base, max_requests=value)), "allocation_limit_invalid")
        hermetic = dict(base, mode="hermetic-test", max_requests=0, test_origin="https://localhost:4555", test_ca_file="/dev/null")
        self.transport._validate_allocation(hermetic)  # contrast: the hermetic minimum is zero

    def test_live_unknown_allocation_mode_is_refused(self):
        for mode in ("hermetic", "LIVE", None):
            with self.subTest(mode=mode):
                self.assertEqual(self.refused(dict(self.live, mode=mode)), "allocation_mode")

    def test_live_allocation_refuses_every_test_only_route(self):
        for request in ({"route_id": "test_probe", "method": "GET"}, {"route_id": "test_page", "method": "GET", "page_ordinal": 1}):
            with self.subTest(route=request["route_id"]):
                with self.assertRaises(self.transport.TransportError) as caught:
                    self.transport._route(request, self.live)
                self.assertEqual(caught.exception.code, "test_origin_rejected")
        hermetic = dict(self.live, mode="hermetic-test", test_origin="https://localhost:4555", test_ca_file="/dev/null")
        self.assertEqual(self.transport._route({"route_id": "test_probe", "method": "GET"}, hermetic)[:2], ("localhost", 4555))


if __name__ == "__main__":
    unittest.main(verbosity=2)
