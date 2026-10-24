#!/usr/bin/env python3
"""Real-process contracts for ci-command-record.py."""

import json
import os
import pathlib
import shlex
import signal
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
RECORDER = ROOT / "scripts/ci/ci-command-record.py"


class CommandRecordTest(unittest.TestCase):
    def invoke(self, root, invocation, argv, cleanup=None, env=None):
        args = [sys.executable, str(RECORDER), "--cwd", str(ROOT), "--output-root", str(root),
                "--invocation", invocation]
        if cleanup is not None:
            cleanup_file = root / f"{invocation}-cleanup.json"
            cleanup_file.write_text(json.dumps(cleanup))
            args.extend(["--cleanup-argv-file", str(cleanup_file)])
        args.extend(["--", *argv])
        child_env = os.environ.copy()
        child_env.update(env or {})
        return subprocess.run(args, cwd=ROOT, env=child_env, capture_output=True, timeout=20)

    def test_primary_failure_survives_failing_cleanup_with_exact_streams_and_record(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = "import sys; sys.stdout.buffer.write(b'out\\x00bytes'); sys.stderr.buffer.write(b'err\\xffbytes'); sys.exit(42)"
            result = self.invoke(root, "failure-1", [sys.executable, "-c", source],
                                 [sys.executable, "-c", "raise SystemExit(7)"],
                                 {"AWS_SECRET_ACCESS_KEY": "sentinel-secret-value", "CI": "true"})
            record_path = root / "failure-1" / "record.json"
            self.assertEqual(42, result.returncode)
            self.assertTrue(record_path.is_file(), result.stderr.decode("utf-8", "replace"))
            record = json.loads(record_path.read_text())
            self.assertEqual(42, record["primary_exit_code"])
            self.assertEqual(7, record["cleanup_exit_code"])
            self.assertIsNone(record["primary_signal"])
            self.assertEqual([sys.executable, "-c", source], record["command_argv"])
            self.assertEqual(b"out\x00bytes", (record_path.parent / "stdout.bin").read_bytes())
            self.assertEqual(b"err\xffbytes", (record_path.parent / "stderr.bin").read_bytes())
            self.assertIn("cd -- ", record["reproduction"])
            self.assertEqual("true", record["configuration"]["CI"])
            self.assertNotIn("AWS_SECRET_ACCESS_KEY", json.dumps(record))
            self.assertNotIn("sentinel-secret-value", json.dumps(record))
            self.assertEqual("not_applicable_or_not_detected", record["seed_reason"])

    def test_child_signal_is_recorded_and_reemitted_to_caller(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"
            result = self.invoke(root, "signal-1", [sys.executable, "-c", source])
            record = json.loads((root / "signal-1" / "record.json").read_text())
            self.assertEqual(-signal.SIGTERM, result.returncode)
            self.assertEqual(signal.SIGTERM, record["primary_signal"])
            self.assertIsNone(record["primary_exit_code"])

    def test_missing_startup_command_has_concrete_record_and_no_seed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            result = self.invoke(root, "missing-1", [str(root / "not-installed-here")])
            record = json.loads((root / "missing-1" / "record.json").read_text())
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([str(root / "not-installed-here")], record["command_argv"])
            self.assertIsNone(record["seed"])
            self.assertIn("not_applicable_or_not_detected", record["seed_reason"])
            self.assertTrue(record["capture_errors"])

    def test_shell_safe_reproduction_keeps_metacharacters_as_argument_data(self):
        marker = pathlib.Path(tempfile.gettempdir()) / f"sigra-recorder-{os.getpid()}-should-not-exist"
        marker.unlink(missing_ok=True)
        argument = f'quote " spaces ; touch {marker} $HOME'
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = "import sys; print(sys.argv[1])"
            result = self.invoke(root, "argv-1", [sys.executable, "-c", source, argument])
            record = json.loads((root / "argv-1" / "record.json").read_text())
            self.assertEqual(0, result.returncode)
            self.assertEqual(argument + "\n", (root / "argv-1" / "stdout.bin").read_text())
            self.assertEqual(shlex.join(record["command_argv"]), record["reproduction"].split(" && ", 1)[1])
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
