#!/usr/bin/env python3
"""Hermetic wire-level contracts for the Phase 253 hosted transport."""

import http.server
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


class JournalHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):  # noqa: N802
        ledger = json.loads(pathlib.Path(self.server.ledger_path).read_text())
        pending = ledger["transactions"][-1]
        self.server.journal.append({"path": self.path, "charged": pending["state"] == "pending",
                                    "authorization": self.headers.get("Authorization")})
        status, response_headers, payload = self.server.responses.pop(0) if self.server.responses else (
            self.server.status, [("Content-Type", "application/json")], b'{"ready":true}')
        self.send_response(status)
        for name, value in response_headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("X-GitHub-Request-Id", "local-fixture")
        self.end_headers()
        self.wfile.write(payload)

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
        self.assertEqual(self.body_path.read_bytes(), b'{"ready":true}')

    def test_declined_budget_never_reaches_the_https_server(self):
        allocation = json.loads(self.allocation_path.read_text())
        allocation["max_requests"] = 0
        self.allocation_path.write_text(json.dumps(allocation))
        result = self.run_runner()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.server.journal, [])
        self.assertFalse(self.ledger.exists())

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
        self.assertEqual(ledger["transactions"][0]["scrubbed_headers"]["location"]["has_query"], True)
        self.assertEqual(self.body_path.read_bytes(), b"archive-bytes")

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
