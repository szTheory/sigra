#!/usr/bin/env python3
"""Reject malformed Android provisioning artifact archives before commit."""

import hashlib
import io
import os
import pathlib
import re
import sys
import tarfile

EXPECTED = {
    "toolchain.lock.json",
    "gradlew",
    "gradlew.bat",
    "gradle/wrapper/gradle-wrapper.jar",
    "gradle/wrapper/gradle-wrapper.properties",
    "provisioned-files.sha256",
    "provisioned-files.mode",
}
PAYLOAD = EXPECTED - {"provisioned-files.sha256", "provisioned-files.mode"}
SHA_LINE = re.compile(r"^([a-f0-9]{64})  (.+)$")
MODE_LINE = re.compile(r"^([0-7]{3,4}) (.+)$")


def fail(message: str) -> None:
    raise SystemExit(f"NP-ANDROID-ARTIFACT: {message}")


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: ARCHIVE DESTINATION")
    archive, destination = map(pathlib.Path, sys.argv[1:])
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive, "r:") as tf:
        members = tf.getmembers()
        names = [member.name for member in members]
        if set(names) != EXPECTED or len(names) != len(EXPECTED):
            fail("archive member set is not exact")
        for member in members:
            if member.name.startswith("/") or ".." in pathlib.PurePosixPath(member.name).parts:
                fail("unsafe archive member")
            if not member.isfile() or member.issym() or member.islnk():
                fail("non-regular archive member")
        contents = {member.name: tf.extractfile(member).read() for member in members}

    sha_lines = contents["provisioned-files.sha256"].decode("utf-8").splitlines()
    mode_lines = contents["provisioned-files.mode"].decode("utf-8").splitlines()
    hashes, modes = {}, {}
    for line in sha_lines:
        match = SHA_LINE.fullmatch(line)
        if not match or match.group(2) not in PAYLOAD or match.group(2) in hashes:
            fail("invalid byte manifest")
        hashes[match.group(2)] = match.group(1)
    for line in mode_lines:
        match = MODE_LINE.fullmatch(line)
        if not match or match.group(2) not in PAYLOAD or match.group(2) in modes:
            fail("invalid mode manifest")
        modes[match.group(2)] = int(match.group(1), 8)
    if set(hashes) != PAYLOAD or set(modes) != PAYLOAD:
        fail("manifest does not cover exact payload")
    if modes["gradlew"] & 0o111 == 0:
        fail("gradlew is not executable")
    for name in PAYLOAD:
        if hashlib.sha256(contents[name]).hexdigest() != hashes[name]:
            fail(f"byte mismatch for {name}")
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents[name])
        os.chmod(target, modes[name])


if __name__ == "__main__":
    main()
