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
BASELINE_OBSERVATION = {
    "source_sha": "bb97e10fdcfe4cd49253555f27e1813472f90a94",
    "source_ref": "phase-244-playwright-measurement",
    "command": ["MIX_ENV=test", "mix", "ci"],
    "exit_code": 0,
    "runtime": {"elixir": "1.19.5", "otp": "28.5"},
    "ordinary": {"tests": 2659, "failures": 0, "skipped": 12, "excluded": 22},
    "scaffold": {
        "status": "not_observed",
        "observation": "The command returned 0 without a separate scaffold ExUnit start or summary between the ordinary suite and dep-off suite.",
    },
    "threadline_guard": {"tests": 65, "failures": 0, "excluded": 2652},
    "captured_before_source_changes": True,
}
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
    errors: list[str] = []
    order = ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"]
    if value.get("leg_records") != order:
        errors.append("receiver_order_mismatch")

    ordinary = value.get("ordinary") or {}
    scaffold = value.get("scaffold") or {}
    guard = value.get("threadline_guard") or {}
    ordinary_modules = {row.get("module") for row in ordinary.get("tests", [])}
    scaffold_rows = scaffold.get("tests", [])
    scaffold_modules = {row.get("module") for row in scaffold_rows}
    guard_rows = guard.get("tests", [])
    guard_modules = {
        "Sigra.ApplicationForwardersTest", "Sigra.ConfigForwardersTest", "Sigra.OptionalDepsTest",
        "Sigra.Workers.AuditForwardTest", "Sigra.DoctorTest", "Mix.Tasks.Sigra.DoctorTest",
        "Sigra.Audit.Forwarders.NoopTest",
    }

    for name, report in (("ordinary", ordinary), ("scaffold", scaffold), ("threadline_guard", guard)):
        if not isinstance(report.get("seed"), int):
            errors.append(f"missing_seed:{name}")
        if not report.get("tests"):
            errors.append(f"no_executed_tests:{name}")
        if not isinstance(report.get("failed_test_ids"), list):
            errors.append(f"missing_failure_identity_field:{name}")
        if report.get("complete") is not True:
            errors.append(f"incomplete_receiver_report:{name}")
        if report.get("failed_count") != 0 or report.get("failed_test_ids"):
            errors.append(f"receiver_test_failures:{name}")

    for module in SCAFFOLD:
        if module in ordinary_modules:
            errors.append(f"scaffold_in_ordinary:{module}")
        if module not in scaffold_modules:
            errors.append(f"missing_scaffold:{module}")

    unexpected_scaffold = scaffold_modules.difference(SCAFFOLD)
    for module in sorted(unexpected_scaffold):
        errors.append(f"unexpected_scaffold:{module}")

    for row in guard_rows:
        if row.get("module") not in guard_modules:
            errors.append(f"non_guard_test_executed:{row.get('test_id', '<unknown>')}")

    for name in ("ordinary", "scaffold", "dep-off"):
        if not value.get("leg_command_records", {}).get(name):
            errors.append(f"missing_native_command_record:{name}")
    return not errors, errors


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
    if os.environ.get("SIGRA_CI_INJECT_FAILURE") == name:
        argv = [sys.executable, "-c", "import sys; print('injected receiver failure', file=sys.stderr); sys.exit(42)"]
    if name == "dep-off":
        env["SIGRA_EXUNIT_TIMING_THREADLINE_GUARD_JSON"] = str(invocation_dir / "threadline_guard.json")

    command = [sys.executable, str(RECORDER), "--cwd", str(ROOT), "--output-root",
               str(output / "commands"), "--invocation", name, "--", *argv]
    result = subprocess.run(command, cwd=ROOT, env=env, check=False)
    timing_report = (invocation_dir / "threadline_guard.json") if name == "dep-off" else timing
    record_path = output / "commands" / name / "record.json"
    if record_path.is_file():
        record = json.loads(record_path.read_text())
        if timing_report.is_file():
            timing_data = json.loads(timing_report.read_text())
            record["seed"] = timing_data.get("seed")
            record["seed_reason"] = "observed_exunit_suite" if isinstance(record["seed"], int) else "not_applicable"
            record["failed_test_ids"] = timing_data.get("failed_test_ids", [])
            record["test_invocation"] = timing_data.get("invocation")
        else:
            record["seed"] = None
            record["seed_reason"] = "not_applicable"
        record_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    if temporary is not None:
        temporary.cleanup()
    return result.returncode


def main() -> int:
    if sys.argv[1:2] == ["--native"]:
        native_parser = argparse.ArgumentParser(description=__doc__)
        native_parser.add_argument("--native", action="store_true")
        native_parser.add_argument("--output", required=True, help="MIX-RECEIVERS.json output file")
        native_parser.add_argument("--inject-failure", choices=("ordinary", "scaffold", "dep-off"))
        native_args = native_parser.parse_args()
        report_path = pathlib.Path(native_args.output).resolve()
        output = report_path.parent / f"native-run-{time.time_ns()}"
        args = argparse.Namespace(mode="native", output=str(output), report_output=str(report_path),
                                  inject_failure=native_args.inject_failure)
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        sub = parser.add_subparsers(dest="mode", required=True)
        leg = sub.add_parser("leg")
        leg.add_argument("name", choices=("ordinary", "scaffold", "dep-off"))
        leg.add_argument("argv", nargs=argparse.REMAINDER)
        native = sub.add_parser("native")
        native.add_argument("--output", required=True)
        native.add_argument("--report-output")
        native.add_argument("--inject-failure", choices=("ordinary", "scaffold", "dep-off"))
        args = parser.parse_args()

    if args.mode == "leg":
        argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
        if not argv:
            raise SystemExit("leg requires a native command after --")
        return record_leg(args.name, argv)

    output = pathlib.Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    env = os.environ.copy()
    env.update({"MIX_ENV": "test", "SIGRA_CI_RECEIVER_OUTPUT": str(output)})
    if args.inject_failure:
        env["SIGRA_CI_INJECT_FAILURE"] = args.inject_failure
    command = [sys.executable, str(RECORDER), "--cwd", str(ROOT), "--output-root",
               str(output / "commands"), "--invocation", "mix-ci", "--", "mix", "ci"]
    result = subprocess.run(command, cwd=ROOT, env=env, check=False)
    outer_record_path = output / "commands" / "mix-ci" / "record.json"
    reports = {}
    for name, relative in (("ordinary", "legs/ordinary/exunit.json"),
                           ("scaffold", "legs/scaffold/exunit.json"),
                           ("threadline_guard", "legs/dep-off/threadline_guard.json")):
        path = output / relative
        if path.is_file():
            reports[name] = json.loads(path.read_text())
        else:
            reports[name] = {}

    command_records = {}
    outer_record = json.loads(outer_record_path.read_text()) if outer_record_path.is_file() else None
    if outer_record is not None:
        outer_record["seed"] = None
        outer_record["seed_reason"] = "not_applicable"
        outer_record_path.write_text(json.dumps(outer_record, indent=2, sort_keys=True) + "\n")
    for name in ("ordinary", "scaffold", "dep-off"):
        leg_record_path = output / "commands" / name / "record.json"
        command_records[name] = json.loads(leg_record_path.read_text()) if leg_record_path.is_file() else None
    payload = {
        "schema_version": "sigra.ci-mix-receivers/v1",
        "command": ["mix", "ci"],
        "baseline_observation": BASELINE_OBSERVATION,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "record": str(outer_record_path.relative_to(output)),
        "receiver_order": ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"],
        "native_exit_code": result.returncode,
        **reports,
        "leg_records": ["format", "deps.get", "deps.unlock", "compile", "ordinary", "scaffold", "dep-off"],
        "leg_command_records": command_records,
    }
    errors = ["native_mix_ci_failed"] if result.returncode else []
    if not result.returncode:
        ok, validation_errors = validate_native_report(payload)
        if not ok:
            errors.extend(validation_errors)
    payload["errors"] = errors
    report_path = pathlib.Path(args.report_output).resolve() if args.report_output else output / "MIX-RECEIVERS.json"
    payload["record"] = os.path.relpath(outer_record_path, report_path.parent)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({
        "native_exit_code": payload["native_exit_code"],
        "elapsed_seconds": payload["elapsed_seconds"],
        "report": os.path.relpath(report_path, ROOT),
        "errors": errors,
        "receiver_counts": {
            name: {"tests": len(payload[name].get("tests", [])), "seed": payload[name].get("seed"),
                   "failed": payload[name].get("failed_count")}
            for name in ("ordinary", "scaffold", "threadline_guard")
        },
    }, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
