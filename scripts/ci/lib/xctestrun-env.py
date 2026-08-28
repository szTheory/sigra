#!/usr/bin/env python3
"""Inject environment variables into exactly one UI-test target in an xctestrun plist."""

from __future__ import annotations

import os
import pathlib
import plistlib
import sys
import tempfile


def fail(message: str) -> None:
    raise SystemExit(f"xctestrun-env: {message}")


def target_candidates(root: dict[str, object], bundle_name: str) -> list[dict[str, object]]:
    candidates: list[dict[str, object]] = []

    configurations = root.get("TestConfigurations")
    if isinstance(configurations, list):
        for configuration in configurations:
            if not isinstance(configuration, dict):
                continue
            targets = configuration.get("TestTargets")
            if not isinstance(targets, list):
                continue
            for target in targets:
                if isinstance(target, dict) and str(target.get("TestBundlePath", "")).endswith(bundle_name):
                    candidates.append(target)

    for key, value in root.items():
        if key.startswith("__") or not isinstance(value, dict):
            continue
        if key == pathlib.Path(bundle_name).stem or str(value.get("TestBundlePath", "")).endswith(bundle_name):
            candidates.append(value)

    unique: list[dict[str, object]] = []
    seen: set[int] = set()
    for candidate in candidates:
        if id(candidate) not in seen:
            unique.append(candidate)
            seen.add(id(candidate))
    return unique


def main(argv: list[str]) -> None:
    if len(argv) < 5 or len(argv[3:]) % 2:
        fail("usage: xctestrun-env.py PATH TEST_BUNDLE KEY VALUE [KEY VALUE ...]")

    path = pathlib.Path(argv[1])
    bundle_name = argv[2]
    raw = path.read_bytes()
    root = plistlib.loads(raw)
    if not isinstance(root, dict):
        fail("root plist value must be a dictionary")

    candidates = target_candidates(root, bundle_name)
    if len(candidates) != 1:
        fail(f"expected exactly one {bundle_name} target, found {len(candidates)}")

    target = candidates[0]
    environment = target.setdefault("EnvironmentVariables", {})
    if not isinstance(environment, dict):
        fail("target EnvironmentVariables must be a dictionary")
    for index in range(3, len(argv), 2):
        key, value = argv[index : index + 2]
        if not key:
            fail("environment key cannot be empty")
        environment[key] = value

    output_format = plistlib.FMT_BINARY if raw.startswith(b"bplist") else plistlib.FMT_XML
    mode = path.stat().st_mode & 0o777
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            plistlib.dump(root, output, fmt=output_format, sort_keys=False)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    main(sys.argv)
