#!/usr/bin/env python3
"""Offline package/replay contract for new repaired-control experiments."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts/ci/ci-repaired-replay.py"


class RepairedReplay(unittest.TestCase):
    def test_cli_exposes_package_replay_report_and_result_verification(self):
        result = subprocess.run([sys.executable, "-B", str(CLI), "--help"], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        for command in ("package", "replay", "report", "verify-result"):
            self.assertIn(command, result.stdout)

    def test_tied_waits_use_family_id_and_permutations_keep_the_same_order(self):
        rows = [{"family_id": "family-z", "required_result_wait_seconds": 12},
                {"family_id": "family-a", "required_result_wait_seconds": 12},
                {"family_id": "family-m", "required_result_wait_seconds": 8},
                {"family_id": "family-null", "required_result_wait_seconds": None}]
        expected = ["family-m", "family-a", "family-z", "family-null"]
        mod = module()
        self.assertEqual(expected, [row["family_id"] for row in mod.stable_family_order(rows)])
        self.assertEqual(expected, [row["family_id"] for row in mod.stable_family_order(list(reversed(rows)))])

    def test_package_refuses_missing_transitive_calculator_before_writing(self):
        mod = module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contract.json").write_text("{}")
            (root / "registrations.json").write_text("{}")
            output = root / "package.tar.gz"
            with self.assertRaisesRegex(ValueError, "comparison_kind_must_be_repaired_control_pr"):
                mod.package_inputs(root / "contract.json", root / "registrations.json", root, output)
            self.assertFalse(output.exists())

    def test_package_includes_only_contract_declared_native_coverage_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract, registrations = make_package_root(root)
            package = root.parent / (root.name + "-declared.tar.gz")
            manifest = module().package_inputs(contract, registrations, root, package)
            _, files = module().verify_package(package)
            self.assertIn("evidence/custom-map.json", files)
            self.assertIn("evidence/custom-parity.json", files)
            self.assertNotIn("scripts/ci/.comparison-test-map.json", files)
            self.assertEqual(set(path for path in files),
                             {row["path"] for row in manifest["members"]})
            (root / "evidence/custom-map.json").write_text("tampered")
            refused = root.parent / (root.name + "-bad-digest.tar.gz")
            with self.assertRaisesRegex(ValueError, "native_coverage_input_digest_mismatch:mapping_path"):
                module().package_inputs(contract, registrations, root, refused)
            self.assertFalse(refused.exists())

    def test_package_requires_strict_kind_and_rejects_unlisted_files(self):
        mod = module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract, registrations = make_package_root(root)
            contract_doc = json.loads(contract.read_text())
            contract_doc.pop("comparison_kind")
            contract_doc["experiment_kind"] = "repaired_control_pr"
            contract.write_text(json.dumps(contract_doc))
            output = root.parent / (root.name + "-legacy.tar.gz")
            with self.assertRaisesRegex(ValueError, "comparison_kind_must_be_repaired_control_pr"):
                mod.package_inputs(contract, registrations, root, output)
            self.assertFalse(output.exists())

            contract_doc.pop("experiment_kind")
            contract_doc["comparison_kind"] = "repaired_control_pr"
            contract.write_text(json.dumps(contract_doc))
            (root / "credentials.json").write_text('{"token":"do-not-package"}')
            with self.assertRaisesRegex(ValueError, "unexpected_input_file:credentials.json"):
                mod.package_inputs(contract, registrations, root, output)
            self.assertFalse(output.exists())

    def test_package_refuses_existing_or_self_including_output(self):
        mod = module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract, registrations = make_package_root(root)
            contract_doc = json.loads(contract.read_text())
            contract_doc["comparison_kind"] = "repaired_control_pr"
            contract.write_text(json.dumps(contract_doc))
            existing = root.parent / (root.name + "-existing.tar.gz")
            existing.write_bytes(b"preserve")
            with self.assertRaisesRegex(ValueError, "package_output_already_exists"):
                mod.package_inputs(contract, registrations, root, existing)
            self.assertEqual(b"preserve", existing.read_bytes())
            with self.assertRaisesRegex(ValueError, "package_output_inside_input_root"):
                mod.package_inputs(contract, registrations, root, root / "new-package.tar.gz")

    def test_package_refuses_symlinked_or_escaping_transitive_paths(self):
        mod = module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            contract, registrations = make_package_root(root)
            outside = root.parent / (root.name + "-outside.json")
            outside.write_text("{}")
            try:
                (root / "before" / "link.json").symlink_to(outside)
                with self.assertRaisesRegex(ValueError, "input_symlink_rejected"):
                    mod.package_inputs(contract, registrations, root, root.parent / (root.name + "-symlink.tar.gz"))
                (root / "before" / "link.json").unlink()
                value = json.loads(contract.read_text())
                value["replay_inputs"]["before_bundle"] = "../escape"
                contract.write_text(json.dumps(value))
                with self.assertRaisesRegex(ValueError, "unsafe_input_path"):
                    mod.package_inputs(contract, registrations, root, root.parent / (root.name + "-escape.tar.gz"))
            finally:
                outside.unlink(missing_ok=True)

    def test_archives_reject_tampered_or_unsafe_members_before_extraction(self):
        mod = module()
        for member_name, member_type in (("../escape", tarfile.REGTYPE), ("/absolute", tarfile.REGTYPE),
                                         ("payload", tarfile.SYMTYPE)):
            with self.subTest(member=member_name), tempfile.TemporaryDirectory() as tmp:
                package = Path(tmp) / "bad.tar.gz"
                with tarfile.open(package, "w:gz") as archive:
                    item = tarfile.TarInfo(member_name)
                    item.type = member_type
                    if member_type == tarfile.REGTYPE:
                        item.size = 1
                        archive.addfile(item, io.BytesIO(b"x"))
                    else:
                        item.linkname = "../../escape"
                        archive.addfile(item)
                with self.assertRaises(ValueError):
                    mod.verify_package(package)

        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / "collision.tar.gz"
            with tarfile.open(package, "w:gz") as archive:
                for _ in range(2):
                    item = tarfile.TarInfo("INPUTS.json")
                    raw = b"{}"
                    item.size = len(raw)
                    archive.addfile(item, io.BytesIO(raw))
            with self.assertRaisesRegex(ValueError, "unsafe_or_duplicate_archive_member"):
                mod.verify_package(package)

        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / "prefix-collision.tar.gz"
            members = {"a": b"file", "a/b": b"nested"}
            manifest = {"schema_version": mod.SCHEMA, "package_status": "ready",
                        "calculation_version": {},
                        "members": [{"path": name, "size": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
                                    for name, raw in members.items()]}
            with tarfile.open(package, "w:gz") as archive:
                for name, raw in (("INPUTS.json", (json.dumps(manifest) + "\n").encode()), *members.items()):
                    item = tarfile.TarInfo(name)
                    item.size = len(raw)
                    archive.addfile(item, io.BytesIO(raw))
            with self.assertRaisesRegex(ValueError, "package_path_collision"):
                mod.verify_package(package)

    def test_genuine_twenty_pair_calculation_replays_and_reports_all_observations(self):
        with tempfile.TemporaryDirectory(prefix="sigra-repaired-replay-fixture-") as tmp:
            work = Path(tmp)
            fixture = builder_module().build_repaired_fixture(work / "fixture")
            project = fixture["input_root"]
            original_hashes = {path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in project.rglob("*") if path.is_file()}
            package = work / "inputs.tar.gz"
            created = subprocess.run([sys.executable, "-B", str(CLI), "package",
                "--contract", str(fixture["contract_path"]), "--registrations", str(fixture["registrations_path"]),
                "--input-root", str(project), "--output", str(package)],
                cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(0, created.returncode, created.stderr)
            manifest, files = module().verify_package(package)
            self.assertEqual("sigra.ci-repaired-comparison-inputs/v1", manifest["schema_version"])
            self.assertEqual("repaired_control_pr", json.loads(files[manifest["contract_path"]])["comparison_kind"])
            self.assertNotIn(".git/HEAD", files)
            self.assertIn("scripts/ci/.comparison-test-map.json", files)
            self.assertIn("scripts/ci/.comparison-test-parity.json", files)
            self.assertFalse(any("__pycache__" in name for name in files))
            result_path = work / "result.json"
            replay = subprocess.run([sys.executable, "-B", str(CLI), "replay", "--package", str(package),
                                     "--output", str(result_path)], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(0, replay.returncode, replay.stderr[-5000:])
            result = json.loads(result_path.read_text())
            self.assertEqual("pass", result["status"], result.get("diagnostics"))
            self.assertEqual("pass", result["performance_verdict"])
            self.assertTrue(result["replay"]["network_disabled"])
            self.assertEqual(20, result["metrics"]["comparable_successful_pairs"])
            self.assertEqual(100, result["metrics"]["baseline_median_seconds"])
            self.assertEqual(80, result["metrics"]["candidate_median_seconds"])
            self.assertEqual(100, result["metrics"]["baseline_p95_seconds"])
            self.assertEqual(100, result["metrics"]["candidate_p95_seconds"])
            self.assertEqual(2400, result["metrics"]["baseline_runner_seconds"])
            self.assertEqual(2400, result["metrics"]["candidate_runner_seconds"])
            self.assertEqual(40, result["metrics"]["native_parity"]["origins_verified"])
            self.assertEqual("passed", result["metrics"]["native_parity"]["origin_status"])
            self.assertEqual(40, len(result["metrics"]["family_attempt_costs"]))
            self.assertEqual(original_hashes, {path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                                               for path in project.rglob("*") if path.is_file()})
            report_path = work / "report.json"
            report = subprocess.run([sys.executable, "-B", str(CLI), "report", "--package", str(package),
                "--result", str(result_path), "--output", str(report_path)], cwd=ROOT,
                capture_output=True, text=True)
            self.assertEqual(0, report.returncode, report.stderr)
            rendered = json.loads(report_path.read_text())
            self.assertEqual(40, len(rendered["family_attempt_costs"]))
            self.assertEqual(40, len(rendered["family_observations"]))
            self.assertEqual(20, rendered["sample_count"])
            self.assertIn("source_manifest_sha256", rendered["identities"])
            verified = subprocess.run([sys.executable, "-B", str(CLI), "verify-result", "--package", str(package),
                "--result", str(result_path)], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(0, verified.returncode, verified.stderr[-5000:])
            tampered = json.loads(result_path.read_text())
            tampered["replay"]["package_sha256"] = "0" * 64
            tampered_result = work / "tampered-result.json"
            tampered_result.write_text(json.dumps(tampered))
            refused = subprocess.run([sys.executable, "-B", str(CLI), "verify-result", "--package", str(package),
                "--result", str(tampered_result)], cwd=ROOT, capture_output=True, text=True)
            self.assertNotEqual(0, refused.returncode)
            self.assertIn("result_package_identity_mismatch", refused.stderr)

    def test_repaired_calculator_count_threshold_and_permutation_matrix(self):
        with tempfile.TemporaryDirectory(prefix="sigra-repaired-replay-matrix-") as tmp:
            work = Path(tmp)
            builder = builder_module()
            base_fixture = builder.build_repaired_fixture(work / "base")
            base_result = packaged_replay(self, base_fixture["input_root"], work / "base-replay")
            self.assertEqual("pass", base_result["performance_verdict"])

            for count in (0, 1, 19):
                with self.subTest(valid_pair_count=count):
                    input_root = work / f"count-{count}"
                    shutil.copytree(base_fixture["input_root"], input_root)
                    builder.set_pair_count(input_root, count)
                    result = packaged_replay(self, input_root, work / f"count-{count}-replay")
                    self.assertEqual("insufficient_data", result["performance_verdict"])
                    self.assertEqual("insufficient_data", result["status"])
                    self.assertEqual(count, result["metrics"]["comparable_successful_pairs"])
                    if count == 0:
                        self.assertIsNone(result["metrics"]["baseline_median_seconds"])
                        self.assertIsNone(result["metrics"]["candidate_p95_seconds"])

            misses = (
                ("median", {"candidate_wait_seconds": [81] * 20}),
                ("p95", {"candidate_wait_seconds": [80] * 18 + [101] * 2}),
                ("runner_cost", {"candidate_runner_cost_seconds": 121}),
            )
            for name, options in misses:
                with self.subTest(threshold_miss=name):
                    fixture = builder.build_repaired_fixture(work / f"miss-{name}", **options)
                    result = packaged_replay(self, fixture["input_root"], work / f"miss-{name}-replay")
                    self.assertEqual(20, result["metrics"]["comparable_successful_pairs"])
                    self.assertEqual("miss", result["performance_verdict"])
                    self.assertEqual("miss", result["status"])

            permuted = builder.build_repaired_fixture(work / "permuted", reverse_family_order=True)
            permuted_result = packaged_replay(self, permuted["input_root"], work / "permuted-replay")
            self.assertEqual("pass", permuted_result["performance_verdict"])
            metric_keys = ("baseline_median_seconds", "candidate_median_seconds",
                           "baseline_p95_seconds", "candidate_p95_seconds",
                           "baseline_runner_seconds", "candidate_runner_seconds",
                           "comparable_successful_pairs")
            for key in metric_keys:
                self.assertEqual(base_result["metrics"][key], permuted_result["metrics"][key], key)

    def test_tampering_with_a_transitive_helper_rejects_before_calculation(self):
        mod = module()
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / "tampered.tar.gz"
            manifest = {"schema_version": mod.SCHEMA, "package_status": "ready",
                        "calculation_version": {}, "members": [{"path": "scripts/ci/ci-run-metrics.sh",
                        "size": 8, "sha256": hashlib.sha256(b"tampered").hexdigest()}]}
            with tarfile.open(package, "w:gz") as archive:
                for name, raw in (("INPUTS.json", (json.dumps(manifest) + "\n").encode()),
                                  ("scripts/ci/ci-run-metrics.sh", b"tampered")):
                    item = tarfile.TarInfo(name)
                    item.size = len(raw)
                    archive.addfile(item, io.BytesIO(raw))
            with self.assertRaisesRegex(ValueError, "calculation_dependency_digest_mismatch"):
                mod.verify_package(package)


def module():
    spec = importlib.util.spec_from_file_location("repaired_replay", CLI)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def builder_module():
    spec = importlib.util.spec_from_file_location("repaired_fixture", ROOT / "scripts/ci/ci-repaired-fixture.py")
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def packaged_replay(test_case, input_root, output_root):
    output_root = Path(output_root)
    output_root.mkdir(parents=True, exist_ok=True)
    package = output_root / "inputs.tar.gz"
    result_path = output_root / "result.json"
    created = subprocess.run([sys.executable, "-B", str(CLI), "package",
        "--contract", str(input_root / "contract.json"),
        "--registrations", str(input_root / "registrations.json"),
        "--input-root", str(input_root), "--output", str(package)],
        cwd=ROOT, capture_output=True, text=True)
    test_case.assertEqual(0, created.returncode, created.stderr[-3000:])
    replay = subprocess.run([sys.executable, "-B", str(CLI), "replay",
        "--package", str(package), "--output", str(result_path)],
        cwd=ROOT, capture_output=True, text=True)
    test_case.assertEqual(0, replay.returncode, replay.stderr[-5000:])
    return json.loads(result_path.read_text())


def packaged_replay(test_case, input_root, output_root):
    output_root = Path(output_root)
    output_root.mkdir(parents=True, exist_ok=True)
    package = output_root / "inputs.tar.gz"
    result_path = output_root / "result.json"
    created = subprocess.run([sys.executable, "-B", str(CLI), "package",
        "--contract", str(input_root / "contract.json"),
        "--registrations", str(input_root / "registrations.json"),
        "--input-root", str(input_root), "--output", str(package)],
        cwd=ROOT, capture_output=True, text=True)
    test_case.assertEqual(0, created.returncode, created.stderr[-3000:])
    replay = subprocess.run([sys.executable, "-B", str(CLI), "replay",
        "--package", str(package), "--output", str(result_path)],
        cwd=ROOT, capture_output=True, text=True)
    test_case.assertEqual(0, replay.returncode, replay.stderr[-5000:])
    return json.loads(result_path.read_text())


def make_package_root(root):
    ci = root / "scripts/ci"
    ci.mkdir(parents=True)
    for relative in module().CALCULATION_FILES:
        (root / relative).write_text("pinned fixture helper\n")
    (root / "before").mkdir()
    (root / "after").mkdir()
    baseline = root / "baseline.bundle"
    baseline.write_bytes(b"baseline")
    source_dir = root / "sources"
    source_dir.mkdir()
    source_rows = {}
    for role in ("common", "control", "candidate"):
        archive = source_dir / (role + ".tar.gz")
        archive.write_bytes(b"baseline" if role == "control" else role.encode())
        patch = source_dir / (role + ".patch")
        patch.write_bytes((role + " patch\n").encode())
        source_rows[role] = {"archive": {"path": archive.relative_to(root).as_posix(),
                                          "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()},
                             "patch": {"path": patch.relative_to(root).as_posix(),
                                       "sha256": hashlib.sha256(patch.read_bytes()).hexdigest()},
                             "source_sha": role + "-sha"}
    source_manifest = source_dir / "SOURCES.json"
    source_manifest.write_text(json.dumps({"schema_version": "sigra.synthetic-repaired-sources/v1",
                                          "sources": source_rows}))
    method = source_dir / "METHOD.json"
    method.write_text(json.dumps({"comparison_kind": "repaired_control_pr"}))
    coverage_dir = root / "evidence"
    coverage_dir.mkdir()
    coverage_paths = {}
    for filename, path_field, digest_field in (
            ("custom-map.json", "mapping_path", "mapping_sha256"),
            ("custom-parity.json", "parity_receipt_path", "parity_receipt_sha256")):
        path = coverage_dir / filename
        path.write_text(json.dumps({"fixture": filename}))
        coverage_paths[path_field] = path.relative_to(root).as_posix()
        coverage_paths[digest_field] = hashlib.sha256(path.read_bytes()).hexdigest()
    contexts = ["Library tests", "Example unit smoke (ExUnit + ConnTest)",
                "Install smoke (fresh phx.new + sigra.install)", "Example HTTP smoke (boot + curl critical routes)",
                "Example Playwright smoke (full lifecycle)"]
    owners = ("library", "admin_behavior", "admin_checkpoints", "design_gallery",
              "non_admin_smoke", "demo_showcase")
    keys = {owner: {"deps": "expected-" + owner} for owner in owners}
    contract_doc = {"comparison_kind": "repaired_control_pr", "required_contexts": contexts,
        "required_check_apps": {context: 15368 for context in contexts},
        "cache_eligibility": {"default_branch_ref": "refs/heads/main",
            "expected_keys": {"before": keys, "after": keys}},
        "baseline_identity": {"source_bundle_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest()},
        "source_inputs": {"manifest_path": source_manifest.relative_to(root).as_posix(),
            "manifest_sha256": hashlib.sha256(source_manifest.read_bytes()).hexdigest(),
            "method_path": method.relative_to(root).as_posix(),
            "method_sha256": hashlib.sha256(method.read_bytes()).hexdigest()},
        "native_coverage_comparison": coverage_paths,
        "replay_inputs": {"before_bundle": "before", "after_bundle": "after",
                          "baseline_source_bundle": "baseline.bundle"}}
    contract = root / "contract.json"
    registrations = root / "registrations.json"
    contract.write_text(json.dumps(contract_doc))
    registrations.write_text(json.dumps({"records": []}))
    return contract, registrations


if __name__ == "__main__":
    unittest.main(verbosity=2)
