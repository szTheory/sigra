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
                         {"gsd/253-replan-candidate", "gsd/253-replan-r8-candidate", "gsd/253-replan-docs-head"})
        self.assertEqual(self.transport.PR_BASE_REFS, {"main", "gsd/253-replan-docs-base"})
        body = {"title": "Phase 253 proof", "head": "gsd/253-replan-r8-candidate", "base": "main", "body": "draft", "draft": True}
        self.assertEqual(self.route("pr_create", method="POST", body=body)[3], "/repos/szTheory/sigra/pulls")
        for head in ("gsd/253-replan-r8-fixture", "gsd/253-replan-fixture", "gsd/253-replan-r9-candidate",
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
