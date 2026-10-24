#!/usr/bin/env python3
"""Finished-archive security contracts for ci-diagnostic-bundle.py."""

import hashlib
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
                    "trace_unavailable_reason": None, **extra}
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

    def test_passing_trace_requires_synthetic_registered_provenance_and_missing_context_is_explicit(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "invocation"
            root.mkdir()
            manifest, _ = self.make_manifest(root, [("trace.zip", b"trace", "trace")],
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
