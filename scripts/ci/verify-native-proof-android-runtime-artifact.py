#!/usr/bin/env python3
"""Independently verify a downloaded Phase 248 Android runtime evidence bundle."""

import hashlib
import json
import pathlib
import re
import sys


def fail(message: str) -> None:
    raise SystemExit(f"Android runtime artifact verification failed: {message}")


if len(sys.argv) != 4:
    fail("usage: verify-native-proof-android-runtime-artifact.py ARTIFACT_DIR IMPLEMENTATION_SHA LOCK")

root = pathlib.Path(sys.argv[1])
expected_sha = sys.argv[2]
lock_path = pathlib.Path(sys.argv[3])
if not re.fullmatch(r"[a-f0-9]{40}", expected_sha):
    fail("expected implementation SHA is not exact")

expected_names = {
    "248-ANDROID-EVIDENCE.json",
    "app-debug.apk",
    "app-debug-androidTest.apk",
    "diagnostics.txt",
    "artifact.sha256",
}
actual_names = {item.name for item in root.iterdir()} if root.is_dir() else set()
if actual_names != expected_names or any(not (root / name).is_file() for name in expected_names):
    fail("bundle allowlist mismatch")

digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
hashed_names = sorted(expected_names - {"artifact.sha256"})
expected_manifest = "".join(sorted(f"{digest(root / name)}  {name}\n" for name in hashed_names))
if (root / "artifact.sha256").read_text() != expected_manifest:
    fail("exact-byte manifest mismatch")

receipt_path = root / "248-ANDROID-EVIDENCE.json"
receipt = json.loads(receipt_path.read_text())
lock = json.loads(lock_path.read_text())
if receipt.get("schema_version") != "native-proof-receipt/1":
    fail("receipt schema mismatch")
if receipt.get("implementation_sha") != expected_sha:
    fail("receipt source SHA mismatch")
if receipt.get("target_class") != "android_emulator":
    fail("receipt target class mismatch")
target = receipt.get("target_identity")
expected_target = {
    "platform": "android",
    "avd_device": lock["avd_device"],
    "api": "36",
    "abi": lock["abi"],
    "emulated": True,
}
if target != expected_target:
    fail("receipt target identity mismatch")
hashes = receipt.get("artifact_hashes", {})
expected_hashes = {
    "app_apk_sha256": digest(root / "app-debug.apk"),
    "test_apk_sha256": digest(root / "app-debug-androidTest.apk"),
    "diagnostics_sha256": digest(root / "diagnostics.txt"),
}
if hashes != expected_hashes:
    fail("receipt payload hash mismatch")
for name in ("248-ANDROID-EVIDENCE.json", "diagnostics.txt"):
    text = (root / name).read_text(errors="replace")
    if re.search(r"access[_ -]?token|refresh[_ -]?token|authorization[_ -]?code|code_verifier|password|Bearer\s", text, re.I):
        fail(f"secret marker retained in {name}")

print("Android runtime artifact verification: PASS")
