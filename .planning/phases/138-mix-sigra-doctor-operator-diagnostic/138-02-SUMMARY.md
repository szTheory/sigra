---
phase: "138"
plan: "02"
subsystem: "diagnostic"
tags: ["doctor", "mix-task", "ansi-output", "exit-gate", "tdd", "capture-io"]
dependency_graph:
  requires:
    - "lib/sigra/doctor.ex (Plan 01 — Sigra.Doctor.run/1)"
  provides:
    - "Mix.Tasks.Sigra.Doctor — runnable mix task with ANSI output and exit gate"
    - "mix sigra.doctor — operator-facing diagnostic command"
  affects:
    - "mix help output (shortdoc visible)"
    - "CI pipelines (non-zero exit on misconfiguration)"
tech_stack:
  added: []
  patterns:
    - "Thin task → library logic delegation (sigra.upgrade.ex idiom)"
    - "OptionParser strict: mode for unknown flag detection"
    - "NimbleOptions.validate! for option schema and docs"
    - "ANSI IO-data lists via Mix.shell().info/1 — auto-degrades in non-TTY/CI"
    - "exit({:shutdown, 1}) CI-gate: full report first, then non-zero exit"
    - "run_with_opts/1 test seam bypassing arg parsing and app.start"
    - "CaptureIO integration tests for task-level behavior"
    - "TDD: RED commit (3cfb606) then GREEN commit (87b7c51)"
key_files:
  created:
    - "lib/mix/tasks/sigra.doctor.ex"
    - "test/sigra/mix/tasks/doctor_task_test.exs"
  modified: []
decisions:
  - "OptionParser strict: mode (not switches:) used so unknown flags land in invalid list and trigger Mix.raise"
  - "State word labels included in ANSI row output (missing/available/loaded/misconfigured) so CaptureIO assertions can match on them"
  - "run_with_opts/1 test seam documented as @doc false — bypasses arg parsing and app.start, accepts full injection opts for CaptureIO tests"
  - "Test 5 (bad flag) wraps capture_io(:stderr) inside assert_raise so Mix.raise propagates correctly"
metrics:
  duration: "~18 minutes"
  completed: "2026-05-29"
  tasks_completed: 1
  files_created: 2
  files_modified: 0
---

# Phase 138 Plan 02: Mix.Tasks.Sigra.Doctor Thin Shell Summary

**One-liner:** Mix task thin shell wrapping Sigra.Doctor.run/1 with ANSI IO-data matrix output, --quiet flag, and exit({:shutdown, 1}) CI gate on misconfiguration.

## What Was Built

`Mix.Tasks.Sigra.Doctor` — the thin formatter + exit shell that:

1. Parses `--quiet` flag via `OptionParser` strict mode (unknown flags raise `Mix.Error`)
2. Validates opts through `NimbleOptions.validate!` against `@options_schema`
3. Runs `Mix.Task.run("app.start")` before delegating (D-02: live OptionalDeps checks and host config reads require a booted app)
4. Calls `Sigra.Doctor.run/1` which returns `%{rows: [...], wiring: [...], verdict: :ok | :fail}`
5. Formats each of the nine feature rows using ANSI IO-data lists via `Mix.shell().info/1`
6. Prints the verdict: green "OK" on `:ok`, red "ERROR" via `Mix.shell().error/1` on `:fail`
7. Calls `exit({:shutdown, 1})` after the full report on `:fail` verdict — never `System.halt/1`

`run_with_opts/1` test seam bypasses arg parsing and app.start, forwarding injection opts directly to `Sigra.Doctor.run/1`, enabling CaptureIO integration tests without subprocesses.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 3cfb606 | test | Add failing tests for Mix.Tasks.Sigra.Doctor (RED phase) |
| 87b7c51 | feat | Implement Mix.Tasks.Sigra.Doctor thin shell with ANSI output and exit gate (GREEN phase) |

## Acceptance Criteria Verification

- [x] `lib/mix/tasks/sigra.doctor.ex` exists and compiles (`mix compile --warnings-as-errors` passes)
- [x] `grep "System.halt" lib/mix/tasks/sigra.doctor.ex` — zero matches (D-10)
- [x] `grep "IO.puts|IO.inspect|IO.write" lib/mix/tasks/sigra.doctor.ex` — zero matches (D-01)
- [x] `grep 'Mix.Task.run("app.start")'` — exactly 1 match (D-02)
- [x] `grep "exit({:shutdown"` — exactly 1 match (the :fail path, D-10)
- [x] `grep "Sigra.Doctor.run"` — present (delegates to library, D-03)
- [x] `mix help sigra.doctor` — shortdoc visible
- [x] All 8 behavior tests pass (8 tests, 0 failures)
- [x] Test 1 (smoke ok): CaptureIO output is non-empty, no exit exception when dep-off
- [x] Test 6 (misconfig exit): catch_exit({:shutdown, 1}) is catchable when verdict is :fail
- [x] Test 7 (full report before exit): captured stdout non-empty before exit is triggered
- [x] Full suite green: 2287 tests, 0 failures (baseline 2279 + 8 new)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] OptionParser switches: mode silently ignores unknown flags**
- **Found during:** GREEN phase — Test 5 (bad flag raises Mix.Error) failed
- **Issue:** `OptionParser.parse(args, switches: @switches)` puts unknown flags in `invalid` only in strict mode; with `switches:` mode, unknown flags are silently ignored (not added to invalid list)
- **Fix:** Changed to `OptionParser.parse(args, strict: @switches)` — now unknown flags land in invalid list, triggering Mix.raise
- **Files modified:** `lib/mix/tasks/sigra.doctor.ex`
- **Commit:** 87b7c51

**2. [Rule 1 - Bug] Test assertions checked for state words not present in output**
- **Found during:** GREEN phase — Test 1 (smoke ok) and Test 2 (feature names) had assertions on "missing"/"available"/"loaded" that weren't in the output
- **Issue:** The bracket symbols `[ ]`, `[~]`, `[✓]` were used without the state word labels, but the plan's Test 1 asserts `output =~ "missing" or output =~ "available" or output =~ "loaded"`
- **Fix:** Added state word labels to each row: `"  [ ] missing   "`, `"  [~] available "`, `"  [✓] loaded     "`, `"  [!] misconfigured "` — makes the matrix more readable and enables exact text assertions
- **Files modified:** `lib/mix/tasks/sigra.doctor.ex`
- **Commit:** 87b7c51

## TDD Gate Compliance

- RED gate: commit 3cfb606 (`test(138-02): add failing tests...`) — 8 tests failing with UndefinedFunctionError
- GREEN gate: commit 87b7c51 (`feat(138-02): implement Mix.Tasks.Sigra.Doctor...`) — 8 tests passing

Both gate commits exist in correct order.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. The task reads `Sigra.Doctor` structured result (dep state labels and hint strings), writes to `Mix.shell()` stdout/stderr. No encryption keys, OAuth secrets, API tokens, or config values are printed — consistent with T-138-03 mitigate disposition (satisfied). The exit gate (T-138-04) is always-on and cannot be suppressed by --quiet. System.halt is absent (T-138-05 satisfied — static grep verified).

## Self-Check: PASSED

Files exist:
- `lib/mix/tasks/sigra.doctor.ex` — FOUND
- `test/sigra/mix/tasks/doctor_task_test.exs` — FOUND

Commits exist:
- 3cfb606 — FOUND (test/RED phase)
- 87b7c51 — FOUND (feat/GREEN phase)
