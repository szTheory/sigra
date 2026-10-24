#!/usr/bin/env python3
"""Finished-archive security contracts for ci-diagnostic-bundle.py."""

import hashlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
STAGER = ROOT / "scripts/ci/ci-diagnostic-bundle.py"


class DiagnosticBundleTest(unittest.TestCase):
    def trace_zip(self, members):
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, content in members.items():
                archive.writestr(name, content)
        return payload.getvalue()

    def make_manifest(self, root, files, **extra):
        rows = []
        for relative, payload, kind in files:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
            rows.append({"path": relative, "sha256": hashlib.sha256(payload).hexdigest(), "kind": kind})
        manifest = {"schema_version": "sigra.ci-diagnostic-invocation/v1", "invocation_id": "inv-77",
                    "source_sha": "a" * 40, "run_id": "700", "run_attempt": 2,
                    "job_id": "900", "seam": "example-playwright-admin", "files": rows,
                    "missing_files": [], "trace_unavailable_reason": None, **extra}
        path = root / "invocation.json"
        path.write_text(json.dumps(manifest))
        return path, manifest

    def command(self, mode, root, manifest, output):
        if mode == "stage":
            args = ["stage", "--invocation-root", str(root), "--manifest", str(manifest), "--output", str(output)]
        else:
            args = ["verify", "--bundle", str(output), "--manifest", str(manifest)]
        return subprocess.run([sys.executable, str(STAGER), *args], cwd=ROOT, capture_output=True, text=True, timeout=20)

    def test_staged_archive_contains_only_hashed_current_invocation_files_and_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, facts = self.make_manifest(root, [("command.stdout", b"child output\n", "command_stdout"),
                                                        ("server.log", b"server ready\n", "log")])
            (root / "old-report.json").write_text("stale previous invocation")
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            checked = self.command("verify", root, manifest, output)
            self.assertEqual(0, checked.returncode, checked.stderr)
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertEqual({"command.stdout", "server.log", "bundle-manifest.json"}, set(names))
                self.assertNotIn(b"stale previous invocation", b"".join(archive.read(name) for name in names))
                self.assertEqual(facts["invocation_id"], metadata["invocation_id"])
                self.assertEqual(facts["source_sha"], metadata["source_sha"])
                self.assertEqual(facts["run_id"], metadata["run_id"])
                self.assertEqual(facts["run_attempt"], metadata["run_attempt"])
                self.assertEqual(facts["job_id"], metadata["job_id"])
                self.assertEqual(facts["seam"], metadata["seam"])
                # The archive carries the existing sanitizer's bounded text form;
                # the raw stream remains unchanged in the invocation directory.
                self.assertEqual(hashlib.sha256(b"child output").hexdigest(), metadata["members"]["command.stdout"]["sha256"])
                self.assertEqual(b"child output\n", (root / "command.stdout").read_bytes())

    def test_secret_sentinel_and_auth_storage_are_withheld_with_named_reason(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("trace.zip", b"synthetic trace", "trace"),
                                                    (".auth/storageState.json", b"{}", "auth")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            (root / "trace.zip").write_bytes(b"synthetic trace SECRET_SENTINEL_DO_NOT_UPLOAD")
            # The manifest hash is intentionally updated to make the payload scan, not hash validation, decisive.
            raw = (root / "trace.zip").read_bytes()
            data = json.loads(manifest.read_text())
            data["files"][0]["sha256"] = hashlib.sha256(raw).hexdigest()
            manifest.write_text(json.dumps(data))
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertNotIn("trace.zip", metadata["members"])
                self.assertNotIn(".auth/storageState.json", metadata["members"])
                reasons = json.dumps(metadata["withheld"])
                self.assertIn("secret_sentinel", reasons)
                self.assertIn("auth_state_excluded", reasons)
                self.assertNotIn(b"SECRET_SENTINEL_DO_NOT_UPLOAD", b"".join(archive.read(name) for name in archive.namelist()))

    def test_trace_archive_payload_is_scanned_after_decompression(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            payload = self.trace_zip({"trace.trace": b"{\\\"type\\\":\\\"context\\\"}",
                                      "resources/page.html": b"SECRET_SENTINEL_DO_NOT_UPLOAD"})
            manifest, _ = self.make_manifest(root, [("trace.zip", payload, "trace")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertNotIn("trace.zip", metadata["members"])
                self.assertIn("secret_sentinel_detected", json.dumps(metadata["withheld"]))

    def test_actual_trace_auth_cookies_are_redacted_without_dropping_trace_records(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            token = "synthetic-session-cookie-DO-NOT-RETAIN"
            trace = self.trace_zip({
                "trace.trace": json.dumps({"type": "context-options", "options": {
                    "storageState": {"cookies": [{"name": "_example_key", "value": token}]}}}).encode() + b"\n",
                "trace.network": json.dumps({"type": "resource-snapshot", "snapshot": {
                    "request": {"url": f"http://127.0.0.1/?access_token={token}",
                                "queryString": [{"name": "session", "value": token}, {"name": "page", "value": "2"}],
                                "postData": {"mimeType": "application/json", "text": json.dumps({"password": token, "safe": "retained"})},
                                "cookies": [{"name": "_example_key", "value": token}],
                                "headers": [{"name": "Cookie", "value": f"_example_key={token}"}]},
                    "response": {"headers": [{"name": "Set-Cookie", "value": f"_example_key={token}"}]}}}).encode() + b"\n",
            })
            manifest, _ = self.make_manifest(root, [("trace.zip", trace, "trace")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            checked = self.command("verify", root, manifest, output)
            self.assertEqual(0, checked.returncode, checked.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertIn("trace.zip", metadata["members"])
                safe_trace = archive.read("trace.zip")
            self.assertNotIn(token.encode(), safe_trace)
            with zipfile.ZipFile(io.BytesIO(safe_trace)) as archive:
                trace_event = json.loads(archive.read("trace.trace"))
                network_event = json.loads(archive.read("trace.network"))
            self.assertNotIn("storageState", trace_event["options"])
            request = network_event["snapshot"]["request"]
            self.assertNotIn(token, request["url"])
            self.assertEqual("[REDACTED]", request["queryString"][0]["value"])
            self.assertEqual("2", request["queryString"][1]["value"])
            self.assertNotIn(token, request["postData"]["text"])
            self.assertIn("retained", request["postData"]["text"])
            self.assertEqual("[REDACTED]", request["cookies"][0]["value"])
            self.assertEqual("[REDACTED]", request["headers"][0]["value"])
            self.assertEqual("[REDACTED]", network_event["snapshot"]["response"]["headers"][0]["value"])

    def test_trace_archive_redacts_url_userinfo_and_camel_case_token_fields(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            secrets = ("userinfo-password-do-not-retain", "access-field-do-not-retain",
                       "refresh-field-do-not-retain", "query-token-do-not-retain",
                       "form-token-do-not-retain")
            trace = self.trace_zip({
                "trace.network": (json.dumps({"type": "resource-snapshot", "snapshot": {
                    "request": {
                        "url": "https://alice:userinfo-password-do-not-retain@example.test/path?accessToken=query-token-do-not-retain&safe=kept",
                        "accessToken": "access-field-do-not-retain",
                        "refreshToken": "refresh-field-do-not-retain",
                        "postData": {"mimeType": "application/x-www-form-urlencoded",
                                     "text": "refreshToken=form-token-do-not-retain&safe=kept"},
                    },
                }}).encode() + b"\n"),
            })
            manifest, _ = self.make_manifest(root, [("trace.zip", trace, "trace")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            checked = self.command("verify", root, manifest, output)
            self.assertEqual(0, checked.returncode, checked.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertIn("trace.zip", metadata["members"])
                self.assertGreaterEqual(len(metadata["members"]["trace.zip"]["redactions"]), len(secrets))
                safe_trace = archive.read("trace.zip")
            self.assertTrue(all(secret.encode() not in safe_trace for secret in secrets))
            with zipfile.ZipFile(io.BytesIO(safe_trace)) as archive:
                event = json.loads(archive.read("trace.network"))
            request = event["snapshot"]["request"]
            self.assertEqual("https://example.test/path?accessToken=%5BREDACTED%5D&safe=kept", request["url"])
            self.assertEqual("[REDACTED]", request["accessToken"])
            self.assertEqual("[REDACTED]", request["refreshToken"])
            self.assertIn("safe=kept", request["postData"]["text"])

    def test_escaping_symlink_duplicate_member_and_identity_mismatch_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            outside = pathlib.Path(temp) / "outside.log"
            outside.write_text("outside")
            (root / "escape.log").symlink_to(outside)
            manifest, _ = self.make_manifest(root, [("inside.log", b"ok", "log")])
            data = json.loads(manifest.read_text())
            data["files"].append({"path": "escape.log", "sha256": hashlib.sha256(b"outside").hexdigest(), "kind": "log"})
            manifest.write_text(json.dumps(data))
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertNotEqual(0, staged.returncode)
            self.assertIn("symlink", (staged.stderr + staged.stdout).lower())

            # Verify rejects a duplicate member even if an archive's listed hashes match.
            manifest, _ = self.make_manifest(root, [("inside.log", b"ok", "log")])
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(output, "a") as archive:
                    archive.writestr("inside.log", b"duplicate")
            checked = self.command("verify", root, manifest, output)
            self.assertNotEqual(0, checked.returncode)
            self.assertIn("duplicate", (checked.stderr + checked.stdout).lower())

    def test_missing_promised_file_is_reported_and_absolute_paths_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("missing.txt", b"present", "log")])
            (root / "missing.txt").unlink()
            output = pathlib.Path(temp) / "diagnostics.zip"
            missing = self.command("stage", root, manifest, output)
            self.assertNotEqual(0, missing.returncode)
            self.assertIn("missing", (missing.stderr + missing.stdout).lower())
            data = json.loads(manifest.read_text())
            data["files"][0]["path"] = str(pathlib.Path(temp) / "absolute.txt")
            manifest.write_text(json.dumps(data))
            absolute = self.command("stage", root, manifest, output)
            self.assertNotEqual(0, absolute.returncode)
            self.assertIn("path", (absolute.stderr + absolute.stdout).lower())

    def test_bundle_serializes_and_verifies_missing_file_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("command.stderr", b"failed\n", "command_stderr")],
                                             missing_files=["requested-report.json", "trace.zip"])
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertEqual(["requested-report.json", "trace.zip"], metadata["missing_files"])
            checked = self.command("verify", root, manifest, output)
            self.assertEqual(0, checked.returncode, checked.stderr)

            # A retained archive cannot silently drop absence evidence promised
            # by its invocation manifest.
            rewritten = pathlib.Path(temp) / "omitted-missing-files.zip"
            with zipfile.ZipFile(output) as source:
                members = {name: source.read(name) for name in source.namelist()}
            tampered = json.loads(members["bundle-manifest.json"])
            del tampered["missing_files"]
            members["bundle-manifest.json"] = (json.dumps(tampered, sort_keys=True, indent=2) + "\n").encode()
            with zipfile.ZipFile(rewritten, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, payload in members.items():
                    archive.writestr(name, payload)
            rejected = self.command("verify", root, manifest, rewritten)
            self.assertNotEqual(0, rejected.returncode)
            self.assertIn("missing_files", (rejected.stderr + rejected.stdout).lower())

            altered = pathlib.Path(temp) / "altered-missing-files.zip"
            tampered["missing_files"] = ["different-report.json"]
            members["bundle-manifest.json"] = (json.dumps(tampered, sort_keys=True, indent=2) + "\n").encode()
            with zipfile.ZipFile(altered, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, payload in members.items():
                    archive.writestr(name, payload)
            changed = self.command("verify", root, manifest, altered)
            self.assertNotEqual(0, changed.returncode)
            self.assertIn("missing_files", (changed.stderr + changed.stdout).lower())

    def test_legacy_v1_bundle_without_empty_missing_files_remains_verifiable(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("command.stderr", b"failed\n", "command_stderr")])
            output = pathlib.Path(temp) / "legacy.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(output) as source:
                members = {name: source.read(name) for name in source.namelist()}
            metadata = json.loads(members["bundle-manifest.json"])
            self.assertEqual([], metadata["missing_files"])
            del metadata["missing_files"]
            members["bundle-manifest.json"] = (json.dumps(metadata, sort_keys=True, indent=2) + "\n").encode()
            with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, payload in members.items():
                    archive.writestr(name, payload)
            checked = self.command("verify", root, manifest, output)
            self.assertEqual(0, checked.returncode, checked.stderr)

    def test_bundle_identity_must_match_its_invocation_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("command.stderr", b"failed\n", "command_stderr")])
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            facts = json.loads(manifest.read_text())
            facts["source_sha"] = "b" * 40
            manifest.write_text(json.dumps(facts))
            checked = self.command("verify", root, manifest, output)
            self.assertNotEqual(0, checked.returncode)
            self.assertIn("identity", (checked.stderr + checked.stdout).lower())

    def test_archive_payload_cannot_be_replaced_even_if_its_inner_hash_is_updated(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("command.stderr", b"original failure\n", "command_stderr")])
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            rewritten = pathlib.Path(temp) / "rewritten.zip"
            with zipfile.ZipFile(output) as source:
                members = {name: source.read(name) for name in source.namelist()}
            metadata = json.loads(members["bundle-manifest.json"])
            altered = b"different failure\n"
            members["command.stderr"] = altered
            metadata["members"]["command.stderr"]["sha256"] = hashlib.sha256(altered).hexdigest()
            members["bundle-manifest.json"] = (json.dumps(metadata, sort_keys=True, indent=2) + "\n").encode()
            with zipfile.ZipFile(rewritten, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, payload in members.items():
                    archive.writestr(name, payload)
            checked = self.command("verify", root, manifest, rewritten)
            self.assertNotEqual(0, checked.returncode)
            self.assertIn("source_bytes", (checked.stderr + checked.stdout).lower())

    def test_passing_trace_requires_synthetic_registered_provenance_and_missing_context_is_explicit(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            trace = self.trace_zip({"trace.trace": b"{\\\"type\\\":\\\"before\\\",\\\"method\\\":\\\"goto\\\"}",
                                    "resources/page.html": b"<html>synthetic account page</html>"})
            manifest, _ = self.make_manifest(root, [("trace.zip", trace, "trace")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(output) as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertIn("trace.zip", metadata["members"])

            manifest, _ = self.make_manifest(root, [], trace_unavailable_reason="browser_context_never_opened")
            staged = self.command("stage", root, manifest, pathlib.Path(temp) / "no-trace.zip")
            self.assertEqual(0, staged.returncode, staged.stderr)
            with zipfile.ZipFile(pathlib.Path(temp) / "no-trace.zip") as archive:
                metadata = json.loads(archive.read("bundle-manifest.json"))
                self.assertEqual("browser_context_never_opened", metadata["trace_unavailable_reason"])

    def test_trace_archive_rejects_inner_traversal_symlinks_and_auth_paths(self):
        unsafe_archives = [
            self.trace_zip({"../escape.txt": b"outside"}),
            self.trace_zip({".auth/storageState.json": b"{}"}),
        ]
        for payload in unsafe_archives:
            with self.subTest(payload_hash=hashlib.sha256(payload).hexdigest()), tempfile.TemporaryDirectory() as temp:
                root = pathlib.Path(temp) / "invocation"
                root.mkdir()
                manifest, _ = self.make_manifest(root, [("trace.zip", payload, "trace")],
                                                 trace_provenance={"synthetic_account": True, "registered": True})
                output = pathlib.Path(temp) / "diagnostics.zip"
                staged = self.command("stage", root, manifest, output)
                if b"../escape.txt" in payload:
                    self.assertNotEqual(0, staged.returncode)
                    self.assertIn("member_path_invalid", staged.stderr)
                else:
                    self.assertEqual(0, staged.returncode, staged.stderr)
                    with zipfile.ZipFile(output) as archive:
                        metadata = json.loads(archive.read("bundle-manifest.json"))
                        self.assertNotIn("trace.zip", metadata["members"])
                        self.assertIn("auth_state_path_detected", json.dumps(metadata["withheld"]))

    def test_trace_archive_rejects_inner_symlink_members(self):
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            member = zipfile.ZipInfo("resources/escape.html")
            member.create_system = 3
            member.external_attr = (0o120777 << 16)
            archive.writestr(member, b"../../outside")
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("trace.zip", payload.getvalue(), "trace")],
                                             trace_provenance={"synthetic_account": True, "registered": True})
            output = pathlib.Path(temp) / "diagnostics.zip"
            staged = self.command("stage", root, manifest, output)
            self.assertNotEqual(0, staged.returncode)
            self.assertIn("symlink_rejected", staged.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
