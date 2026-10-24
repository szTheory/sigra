#!/usr/bin/env python3
"""Run one command and retain its native outcome and independent output streams."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile


SCHEMA = "sigra.ci-command-record/v1"
ENV_ALLOWLIST = ("CI", "MIX_ENV", "PORT", "PHX_SERVER", "PLAYWRIGHT_BROWSERS_PATH")
TOOL_COMMANDS = {
    "python3": (["python3", "--version"],),
    "git": (["git", "--version"],),
    "bash": (["bash", "--version"],),
    "mix": (["mix", "--version"],),
    "node": (["node", "--version"],),
    "npm": (["npm", "--version"],),
    "psql": (["psql", "--version"],),
}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def bounded(text: str, maximum: int = 4096) -> str:
    return text[:maximum]


def git_value(cwd: pathlib.Path, *args: str) -> str | None:
    try:
        result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode:
        return None
    return bounded(result.stdout.strip(), 8192)


def capture_identity(cwd: pathlib.Path, argv: list[str], env: dict[str, str]) -> dict:
    versions = {}
    for tool, candidates in TOOL_COMMANDS.items():
        executable = shutil.which(tool)
        version = None
        if executable:
            for candidate in candidates:
                try:
                    result = subprocess.run(candidate, cwd=cwd, capture_output=True, text=True, timeout=4, check=False)
                    if result.returncode == 0:
                        version = bounded((result.stdout or result.stderr).strip(), 512)
                        break
                except (OSError, subprocess.TimeoutExpired):
                    continue
        versions[tool] = {"path": executable, "version": version, "available": bool(executable and version)}

    seed = None
    seed_reason = "not_applicable_or_not_detected"
    for index, item in enumerate(argv):
        match = re.fullmatch(r"--seed=(\d+)", item)
        if match:
            seed = int(match.group(1))
            seed_reason = "command_argument"
            break
        if item == "--seed" and index + 1 < len(argv) and argv[index + 1].isdigit():
            seed = int(argv[index + 1])
            seed_reason = "command_argument"
            break

    status = git_value(cwd, "status", "--short", "--untracked-files=normal")
    return {
        "source_sha": git_value(cwd, "rev-parse", "HEAD"),
        "source_ref": git_value(cwd, "rev-parse", "--abbrev-ref", "HEAD"),
        "dirty_status": status if status is not None else "unavailable",
        "runtime_versions": versions,
        "configuration": {key: env[key] for key in ENV_ALLOWLIST if key in env},
        "seed": seed,
        "seed_reason": seed_reason,
    }


def parse_cleanup(path: str | None) -> list[str] | None:
    if path is None:
        return None
    value = json.loads(pathlib.Path(path).read_text())
    if not isinstance(value, list) or not value or any(not isinstance(item, str) for item in value):
        raise ValueError("cleanup_argv_file_must_be_a_nonempty_string_array")
    return value


def run_to_files(argv: list[str], cwd: pathlib.Path, stdout_path: pathlib.Path, stderr_path: pathlib.Path,
                 capture_errors: list[str], label: str) -> tuple[int | None, int | None]:
    try:
        with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
            try:
                process = subprocess.Popen(argv, cwd=cwd, stdout=stdout, stderr=stderr, close_fds=True)
            except OSError as error:
                capture_errors.append(f"{label}_start_failed:{type(error).__name__}:{error}")
                return 127, None
            returncode = process.wait()
    except OSError as error:
        capture_errors.append(f"{label}_stream_capture_failed:{type(error).__name__}:{error}")
        try:
            process = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=None, check=False)
            for path, payload in ((stdout_path, process.stdout), (stderr_path, process.stderr)):
                try:
                    path.write_bytes(payload)
                except OSError as write_error:
                    capture_errors.append(f"{label}_stream_write_failed:{path.name}:{write_error}")
            returncode = process.returncode
        except OSError as run_error:
            capture_errors.append(f"{label}_start_failed:{type(run_error).__name__}:{run_error}")
            return 127, None
    if returncode < 0:
        return None, -returncode
    return returncode, None


def render_reproduction(cwd: pathlib.Path, argv: list[str]) -> str:
    return f"cd -- {shlex.quote(str(cwd))} && {shlex.join(argv)}"


def write_json(path: pathlib.Path, value: dict, capture_errors: list[str]) -> bool:
    try:
        temporary = path.with_name(path.name + ".tmp")
        with temporary.open("x", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
        temporary.replace(path)
        return True
    except OSError as error:
        capture_errors.append(f"record_write_failed:{type(error).__name__}:{error}")
        try:
            temporary.unlink(missing_ok=True)
        except (OSError, UnboundLocalError):
            pass
        print(f"ci-command-record: unable to write diagnostics: {error}", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--invocation", required=True)
    parser.add_argument("--cleanup-argv-file")
    parser.add_argument("argv", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    invocation = args.invocation
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", invocation):
        parser.error("--invocation must be a short filesystem-safe identifier")
    if not argv or any(not isinstance(value, str) for value in argv):
        parser.error("provide original argv after --")

    cwd = pathlib.Path(args.cwd).resolve()
    output_root = pathlib.Path(args.output_root).resolve()
    invocation_root = output_root / invocation
    try:
        output_root.mkdir(parents=True, exist_ok=True)
        invocation_root.mkdir(mode=0o700)
    except FileExistsError:
        parser.error(f"invocation directory already exists: {invocation_root}")
    except OSError as error:
        print(f"ci-command-record: cannot create invocation directory: {error}", file=sys.stderr)
        return 125

    capture_errors: list[str] = []
    started = utc_now()
    identity = capture_identity(cwd, argv, dict(os.environ))
    try:
        cleanup_argv = parse_cleanup(args.cleanup_argv_file)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        cleanup_argv = None
        capture_errors.append(f"cleanup_argv_file_invalid:{type(error).__name__}:{error}")

    primary_code, primary_signal = run_to_files(argv, cwd, invocation_root / "stdout.bin",
                                                invocation_root / "stderr.bin", capture_errors, "primary")
    # Freeze the primary status before cleanup. Cleanup is supplemental and cannot
    # change which failure or signal is returned to the caller.
    primary_outcome = (primary_code, primary_signal)
    cleanup_code = None
    if cleanup_argv:
        cleanup_code, cleanup_signal = run_to_files(cleanup_argv, cwd, invocation_root / "cleanup.stdout.bin",
                                                     invocation_root / "cleanup.stderr.bin", capture_errors, "cleanup")
        if cleanup_signal is not None:
            capture_errors.append(f"cleanup_terminated_by_signal:{cleanup_signal}")

    record = {
        "schema_version": SCHEMA,
        "invocation_id": invocation,
        "command_argv": argv,
        "reproduction": render_reproduction(cwd, argv),
        "cwd": str(cwd),
        **identity,
        "primary_exit_code": primary_outcome[0],
        "primary_signal": primary_outcome[1],
        "cleanup_exit_code": cleanup_code,
        "capture_errors": capture_errors,
        "started_at": started,
        "ended_at": utc_now(),
    }
    write_ok = write_json(invocation_root / "record.json", record, capture_errors)

    if primary_outcome[1] is not None:
        sig = primary_outcome[1]
        signal.signal(sig, signal.SIG_DFL)
        os.kill(os.getpid(), sig)
        return 128 + sig
    if primary_outcome[0] not in (None, 0):
        return int(primary_outcome[0])
    if cleanup_code not in (None, 0):
        return int(cleanup_code)
    if capture_errors or not write_ok:
        return 125
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
