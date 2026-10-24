#!/usr/bin/env python3
"""Hermetic acquisition/installation boundaries; no apt, sudo, or network."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("os_deps", Path(__file__).with_name("ci-playwright-os-deps.py"))
deps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deps)

SOURCE = """# Existing Ubuntu archive
Types: deb
URIs: mirror+file:/etc/apt/apt-mirrors.txt
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
"""
MIRRORS = "http://azure.archive.ubuntu.com/ubuntu/\tpriority:1\nhttps://archive.ubuntu.com/ubuntu/\tpriority:2\n"
MIRRORLISTS = {"mirror+file:/etc/apt/apt-mirrors.txt": MIRRORS,
               "mirror+file:/etc/apt/apt-security-mirrors.txt": MIRRORS}
PLAN = 'sudo -- sh -c "apt-get update&& apt-get install -y --no-install-recommends libflite1 libasound2t64 fonts-liberation"\n'


class OsDependencies(unittest.TestCase):
    def test_public_cli_command_is_data_and_exact_packages_are_retained(self):
        self.assertEqual(deps.packages_from_dry_run(PLAN), ["libflite1", "libasound2t64", "fonts-liberation"])
        self.assertEqual(deps.packages_from_dry_run(PLAN.replace("sudo -- ", "")),
                         ["libflite1", "libasound2t64", "fonts-liberation"])

    def test_unknown_shell_forms_and_injections_fail_closed(self):
        for value in [PLAN + "notice\n", PLAN.replace("&&", ";"),
                      PLAN.replace("libflite1", "libflite1; touch /tmp/injected"),
                      PLAN.replace("libflite1", "$(whoami)"),
                      PLAN.replace("libflite1", "--allow-unauthenticated"),
                      PLAN.replace("libflite1", "libflite1 libflite1"),
                      PLAN.replace("apt-get update", "echo apt-get update"),
                      PLAN.replace("sudo -- sh", "sudo sh"),
                      PLAN.replace("libflite1", "libflite1 #comment")]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                deps.packages_from_dry_run(value)

    def test_sources_change_only_uri_and_keep_signature_and_suite_fields(self):
        first = deps.ubuntu_sources(SOURCE, MIRRORLISTS)
        self.assertIn("URIs: https://archive.ubuntu.com/ubuntu/", first)
        self.assertIn("URIs: https://security.ubuntu.com/ubuntu/", first)
        original_other = [line for line in SOURCE.splitlines() if not line.startswith("URIs:")]
        for output in [first]:
            self.assertEqual(original_other, [line for line in output.splitlines() if not line.startswith("URIs:")])
            self.assertNotIn("Trusted:", output)

    def test_standard_security_mirrorlist_is_validated_and_resolved(self):
        source = SOURCE.replace("http://security.ubuntu.com/ubuntu/",
                                "mirror+file:/etc/apt/apt-security-mirrors.txt")
        self.assertEqual(deps.ubuntu_sources(source, MIRRORLISTS), deps.ubuntu_sources(SOURCE, MIRRORLISTS))
        with self.assertRaisesRegex(ValueError, "mirrorlist"):
            deps.ubuntu_sources(source, {"mirror+file:/etc/apt/apt-mirrors.txt": MIRRORS})

    def test_unrecognized_sources_and_security_overrides_are_rejected(self):
        for source, mirrors in [(SOURCE.replace("noble-updates", "jammy-updates"), MIRRORS),
                                (SOURCE.replace("Signed-By:", "Trusted:"), MIRRORS),
                                (SOURCE + "Trusted: yes\n", MIRRORS),
                                (SOURCE.replace("http://security.ubuntu.com/ubuntu/", "https://evil.example/ubuntu/"), MIRRORS),
                                (SOURCE, "https://evil.example/ubuntu/\n"),
                                (SOURCE.replace("http://security.ubuntu.com/ubuntu/", "https://user:pass@security.ubuntu.com/ubuntu/"), MIRRORS),
                                (SOURCE.replace("http://security.ubuntu.com/ubuntu/", "https://security.ubuntu.com/ubuntu/?override=1"), MIRRORS)]:
            with self.subTest(source=source), self.assertRaises(ValueError):
                deps.ubuntu_sources(source, {key: mirrors for key in MIRRORLISTS})

    def fixture(self, folder):
        root = Path(folder)/"system"
        (root/"etc/apt/sources.list.d").mkdir(parents=True)
        (root/"etc/os-release").write_text('ID=ubuntu\nVERSION_ID="24.04"\n')
        (root/"etc/apt/sources.list.d/ubuntu.sources").write_text(SOURCE)
        (root/"etc/apt/apt-mirrors.txt").write_text(MIRRORS)
        key = root/deps.KEYRING.lstrip("/"); key.parent.mkdir(parents=True); key.write_bytes(b"retained-keyring")
        playwright = Path(folder)/"playwright"
        (playwright/"node_modules/playwright").mkdir(parents=True)
        (playwright/"node_modules/playwright/cli.js").write_text("// public CLI fixture\n")
        return root, playwright

    def scenario(self, outcomes):
        with tempfile.TemporaryDirectory() as folder:
            root, playwright = self.fixture(folder)
            calls = []
            def runner(argv, log):
                calls.append(argv)
                if "--dry-run" in argv:
                    log.write_text(PLAN)
                    return 0
                code, output = outcomes.pop(0)
                self.assertFalse(any("Dl-Limit" in arg or "Verify-Peer" in arg for arg in argv))
                for key in ["Dir::State::lists=", "Dir::Cache::archives=", "Dir::Etc::sourceparts="]:
                    self.assertTrue(any(arg.startswith(key) for arg in argv))
                self.assertIn("/usr/bin/apt-get", argv)
                self.assertIn("Acquire::Retries=0", argv)
                self.assertIn("APT::Update::Error-Mode=any", argv)
                log.write_text(output)
                return code
            report = Path(folder)/"result.json"
            with patch.object(deps.platform, "system", return_value="Linux"), \
                 patch.object(deps.platform, "machine", return_value="x86_64"), \
                 patch.object(deps.shutil, "which", return_value="/usr/bin/node"), \
                 patch.object(deps.os, "geteuid", return_value=1001):
                code = deps.install(playwright, ["chromium", "webkit"], report, system_root=root, runner=runner)
            self.assertEqual((root/"etc/apt/sources.list.d/ubuntu.sources").read_text(), SOURCE)
            self.assertEqual((root/"etc/apt/apt-mirrors.txt").read_text(), MIRRORS)
            return code, json.loads(report.read_text()), calls

    def test_success_acquires_before_install_and_install_has_no_kill_timer(self):
        code, report, calls = self.scenario([(0, "updated"), (0, "downloaded"), (0, "configured")])
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "passed")
        self.assertEqual([x["phase"] for x in report["phases"]], ["package-plan", "update", "download", "install"])
        self.assertIn("timeout", calls[1]); self.assertIn("timeout", calls[2])
        self.assertIn("--download-only", calls[2]); self.assertIn("--no-download", calls[3])
        self.assertNotIn("timeout", calls[3]); self.assertNotIn("--foreground", sum(calls, []))
        self.assertEqual(calls[3][-3:], ["libflite1", "libasound2t64", "fonts-liberation"])

    def test_one_acquisition_retry_then_success_does_not_repeat_install(self):
        code, report, calls = self.scenario([(0, "updated"), (124, "slow acquisition"),
                                            (0, "updated fallback"), (0, "downloaded"), (0, "configured")])
        self.assertEqual(code, 0)
        self.assertEqual(report["successful_acquisition_attempt"], 2)
        self.assertEqual(sum("--no-download" in argv for argv in calls), 1)
        self.assertEqual([x["exit_code"] for x in report["phases"]], [0, 0, 124, 0, 0, 0])

    def test_exhausted_acquisition_keeps_last_exit_and_never_starts_dpkg(self):
        code, report, calls = self.scenario([(124, "slow index"), (137, "stalled fallback")])
        self.assertEqual(code, 137)
        self.assertEqual(report["status"], "failed")
        self.assertFalse(any("--no-download" in argv for argv in calls))
        self.assertEqual([x["exit_code"] for x in report["phases"]], [0, 124, 137])

    def test_security_error_and_install_error_never_retry(self):
        code, report, calls = self.scenario([(100, "GPG error: repository is not signed")])
        self.assertEqual(code, 100); self.assertEqual(len(calls), 2)
        code, report, calls = self.scenario([(0, "updated"), (0, "downloaded"), (100, "dpkg failure")])
        self.assertEqual(code, 100); self.assertEqual(len(calls), 4)
        self.assertFalse(report["package_configuration_retried"])

    def test_network_errors_retry_but_unknown_errors_do_not(self):
        self.assertTrue(deps.transient_acquisition(100, "Temporary failure resolving archive.ubuntu.com"))
        self.assertTrue(deps.transient_acquisition(100, "503 Service Unavailable"))
        self.assertFalse(deps.transient_acquisition(100, "Unable to locate package libflite1"))
        self.assertFalse(deps.transient_acquisition(124, "Certificate verification failed"))


if __name__ == "__main__":
    unittest.main()
