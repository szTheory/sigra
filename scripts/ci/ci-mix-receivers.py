#!/usr/bin/env python3
"""Run and verify the native Mix CI receiver commands."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parents[2]
RECORDER = ROOT / "scripts/ci/ci-command-record.py"
SCAFFOLD = {
    "Sigra.Install.Features.PasskeysJsTest": "test/sigra/install/features/passkeys_js_test.exs",
    "Sigra.Install.GeneratorPasskeysOptOutTest": "test/sigra/install/generator_passkeys_opt_out_test.exs",
    "Sigra.Install.GoldenDiffTest": "test/sigra/install/golden_diff_test.exs",
    "Sigra.Install.IdempotencyTest": "test/sigra/install/idempotency_test.exs",
    "Sigra.Install.VaultPromotionTest": "test/sigra/install/vault_promotion_test.exs",
    "Sigra.UpgradeIntegrationTest": "test/upgrade_test.exs",
}


def validate_native_report(value: dict) -> tuple[bool, list[str]]:
    """Check that each expected receiver ran and retained useful test identities."""
    return False, ["native_report_validation_not_implemented"]


def record_leg(name: str, argv: list[str]) -> int:
    output_value = os.environ.get("SIGRA_CI_RECEIVER_OUTPUT")
    temporary = None
    if not output_value:
        temporary = tempfile.TemporaryDirectory(prefix="sigra-ci-receiver-")
        output_value = temporary.name
    output = pathlib.Path(output_value).resolve()
    invocation_dir = output / "legs" / name
    timing = invocation_dir / "exunit.json"
    invocation_dir.mkdir(parents=True, exist_ok=False)

    env = os.environ.copy()
    env.update({
        "MIX_ENV": "test",
        "SIGRA_CI_REQUIRED": "1",
        "SIGRA_EXUNIT_TIMING_JSON": str(timing),
        "SIGRA_EXUNIT_TIMING_INVOCATION": name,
    })
    if name == "dep-off":
        env["SIGRA_EXUNIT_TIMING_THREADLINE_GUARD_JSON"] = str(invocation_dir / "threadline_guard.json")

    command = [sys.executable, str(RECORDER), "--cwd", str(ROOT), "--output-root",
               str(output / "commands"), "--invocation", name, "--", *argv]
    result = subprocess.run(command, cwd=ROOT, env=env, check=False)
    if temporary is not None:
        temporary.cleanup()
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    leg = sub.add_parser("leg")
    leg.add_argument("name", choices=("ordinary", "scaffold", "dep-off"))
    leg.add_argument("argv", nargs=argparse.REMAINDER)
    native = sub.add_parser("native")
    native.add_argument("--output", required=True)
    args = parser.parse_args()

    if args.mode == "leg":
        argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
        if not argv:
            parser.error("leg requires a native command after --")
        return record_leg(args.name, argv)

    output = pathlib.Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    env = os.environ.copy()
    env.update({"MIX_ENV": "test", "SIGRA_CI_RECEIVER_OUTPUT": str(output)})
    command = [sys.executable, str(RECORDER), "--cwd", str(ROOT), "--output-root",
               str(output / "commands"), "--invocation", "mix-ci", "--", "mix", "ci"]
    result = subprocess.run(command, cwd=ROOT, env=env, check=False)
    record_path = output / "commands" / "mix-ci" / "record.json"
    payload = {
        "schema_version": "sigra.ci-mix-receivers/v1",
        "command": ["mix", "ci"],
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "record": str(record_path.relative_to(output)),
        "receiver_order": ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"],
        "native_exit_code": result.returncode,
    }
    errors = ["native_mix_ci_failed"] if result.returncode else []
    if not result.returncode:
        errors.extend(validate_native_report(payload))
    payload["errors"] = errors
    (output / "MIX-RECEIVERS.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps(payload, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
