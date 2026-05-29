---
phase: 138-mix-sigra-doctor-operator-diagnostic
verified: 2026-05-29T16:13:55Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification: false
---

# Phase 138: `mix sigra.doctor` Operator Diagnostic — Verification Report

**Phase Goal:** An adopter can run one command and see, per feature, which optional dependencies are loaded/available/configured-but-missing/missing, with actionable next steps, and the command fails loudly when a configured feature is wired wrong.
**Verified:** 2026-05-29T16:13:55Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `mix sigra.doctor` prints a per-feature optional-dependency matrix with a clear state per row (loaded / available / configured-but-missing / missing) | VERIFIED | `lib/mix/tasks/sigra.doctor.ex` `print_row/2` renders all four state labels as ANSI IO-data via `Mix.shell().info/1`. `lib/sigra/doctor.ex` produces all four states: `{:missing, ...}` (line 395), `{:available, ...}` (line 391), `{:loaded_active, ...}` (line 381), `{:configured_but_missing, ...}` (lines 378/384/388). All nine D-05 features are present in `feature_definitions/0` (lines 222–356). Task test 2 (`test "output includes all nine feature names"`) exercises output breadth. |
| 2 | Each row carries an actionable remediation hint (what to add to deps or config to resolve it) | VERIFIED | Every feature definition in `feature_definitions/0` carries four distinct, non-empty hint strings (`hint_missing`, `hint_available`, `hint_active`, `hint_broken`), each containing specific dep version strings or config key names. `diagnose/1` populates `:hint` on every row; doctor_test.exs test 11 (`"every row has a non-empty hint string"`) asserts `String.length(row.hint) > 0` for all 9 rows. |
| 3 | `mix sigra.doctor` validates boot-time wiring for configured features (e.g. audit forwarder, async email/audit workers, encryption vault) | VERIFIED | `Sigra.Doctor` implements four D-09 hard-fail conditions: async forwarder without supervised Oban (`audit_forwarding_hard_fail?/4`, line 498), async email without supervised Oban (`async_email_hard_fail?/4`, line 493), encryption stub with passkeys+user_schema active (`encryption_hard_fail?/4`, line 525), and forwarder module not loaded (via `module_loaded?` fn in `audit_forwarding_hard_fail?/4`, line 509). Tests 5/6/7/8 in doctor_test.exs each assert `result.verdict == :fail` for their respective D-09 condition. |
| 4 | `mix sigra.doctor` exits non-zero when a configured feature is misconfigured, so it is usable as a CI/pre-deploy gate | VERIFIED | `lib/mix/tasks/sigra.doctor.ex` line 125: `exit({:shutdown, 1})` fires only when `result.verdict == :fail`. No `System.halt` anywhere (grep returns nothing). Task test 6 (`"misconfig opts produce exit({:shutdown, 1})"`) asserts `catch_exit(...) == {:shutdown, 1}`. Test 7 confirms stdout is non-empty before exit fires, proving full matrix prints first. |

**Score: 4/4 truths verified**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/doctor.ex` | Pure library module: `diagnose/1` + `run/1`, nine-feature matrix, injection seam | VERIFIED | File exists, 543 lines. Exports `diagnose/1` (line 108) and `run/1` (line 143), both with `@spec` annotations. No IO calls, no Mix.Task dependency, no `System.halt`. One `Code.ensure_loaded?` call (line 194) — the one narrow D-06 exception for dynamic forwarder module atoms. |
| `test/sigra/doctor_test.exs` | Unit tests via injection seam; no CaptureIO/subprocess | VERIFIED | File exists, 434 lines. 22 test cases. Zero matches for `CaptureIO`, `Mix.Task.run`, or `System.cmd` (grep confirmed). All 13 plan-specified behavior tests present plus additional regression tests from code review fixes (WR-01 through WR-06). |
| `lib/mix/tasks/sigra.doctor.ex` | Thin shell: ANSI output, `--quiet` flag, `exit({:shutdown, 1})` gate | VERIFIED | File exists, 194 lines. `use Mix.Task` (line 51). `Mix.Task.run("app.start")` (line 76). `Sigra.Doctor.run/1` delegation (line 78). Exactly 1 `exit({:shutdown, 1})` call (line 125). Zero `System.halt`, `IO.puts`, `IO.inspect`, `IO.write` calls. `run_with_opts/1` test seam (line 87) forwards injection opts through to `Sigra.Doctor.run/1`. |
| `test/sigra/mix/tasks/doctor_task_test.exs` | CaptureIO integration tests: green on dep-off, non-zero on misconfig | VERIFIED | File exists, 163 lines. 8 test cases using `capture_io`. Tests cover: smoke (dep-off output), nine-feature names in output, shortdoc visibility, `--quiet` flag, bad-flag error, `exit({:shutdown, 1})` on misconfig, full report before exit, no System.halt. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/sigra/doctor.ex` | `lib/sigra/optional_deps.ex` | Calls `Sigra.OptionalDeps.*_available?/0` and `encryption_active?/1` directly | WIRED | Lines 169–178: all nine availability predicates called via `Sigra.OptionalDeps.*`. No re-implementation of `Code.ensure_loaded?` for dep availability (D-06 SOT honored). |
| `lib/sigra/doctor.ex` | `lib/sigra/audit/forwarders.ex` | Calls `Sigra.Audit.Forwarders.oban_running?([])` | WIRED | Line 187: `Sigra.Audit.Forwarders.oban_running?([])` called in production path when `oban_running` override is absent. |
| `lib/mix/tasks/sigra.doctor.ex` | `lib/sigra/doctor.ex` | Calls `Sigra.Doctor.run/1` after parsing flags and running `app.start` | WIRED | Lines 76–78: `Mix.Task.run("app.start")` then `Sigra.Doctor.run(validated)`. The `run_with_opts/1` seam also routes through `Sigra.Doctor.run(opts)` (line 88). |
| `lib/mix/tasks/sigra.doctor.ex` | `exit({:shutdown, 1})` | Called when `Sigra.Doctor.run/1` returns `verdict: :fail` | WIRED | Line 125: inside the `:fail` branch of `case result.verdict`. Exactly one occurrence; not reachable on `:ok` verdict. |

---

### Data-Flow Trace (Level 4)

Not applicable: both production-path modules are pure diagnostic read-only logic with no dynamic data rendering from external sources. `Sigra.Doctor` reads from `Application.get_env` (two-hop config) and `Sigra.OptionalDeps` predicates; the Mix task reads from `Sigra.Doctor.run/1` structured return. No DB queries, no network, no state to trace for hollowness.

---

### Behavioral Spot-Checks

| Behavior | Verification Method | Result | Status |
|----------|--------------------|---------| ------ |
| `diagnose/1` returns nine rows with all four state values reachable | Code path trace: `evaluate_feature/5` cond branches at lines 375–395 | All four `{:state, hint}` tuples found at lines 378, 381, 384/388, 391, 395 | PASS |
| `diagnose/1` returns `:ok` verdict when no D-09 hard-fail fires | `has_hard_fail` accumulator in `build_matrix/3`; test 9 (dep-off invariant) | `Enum.reduce` with `fail_acc or is_hard_fail` — false stays false when all `hard_fail?` fns return false | PASS |
| `diagnose/1` returns `:fail` verdict when any D-09 fires | `hard_fail_fn` returns `true` → `is_hard_fail = true` → `verdict = :fail` | Confirmed by test cases 5/6/7/8, each asserting `result.verdict == :fail` | PASS |
| Mix task exits 1 on misconfig, 0 on clean | `format_and_exit/2` control flow; `exit({:shutdown, 1})` placement | `:ok` path has no `exit/1` call; `:fail` path hits `exit({:shutdown, 1})` at line 125 after full output | PASS |
| `--quiet` suppresses hints but not error gate | `quiet` boolean threaded to `print_row/2`; `format_and_exit/2` always calls `Mix.shell().error` on `:fail` | `quiet` only used in `print_row/2` to omit hint text on `:missing`/`:available` rows; `:fail` branch is not gated on `quiet` | PASS |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DR-01 | 138-01, 138-02 | `mix sigra.doctor` reports per-feature optional-dep matrix (loaded / available / configured-but-missing / missing) with actionable remediation hints | SATISFIED | Nine-feature matrix with four states and non-empty hints per row, rendered via `print_row/2` in ANSI IO-data form. All four states are code-reachable and tested. |
| DR-02 | 138-02 | `mix sigra.doctor` validates boot-time wiring and exits non-zero when configured feature is misconfigured | SATISFIED | Four D-09 hard-fail conditions implemented and tested; `exit({:shutdown, 1})` fires on `:fail` verdict; dep-off installs produce `:ok` verdict and exit 0. |

---

### Anti-Patterns Found

| File | Pattern | Severity | Disposition |
|------|---------|----------|-------------|
| `lib/sigra/doctor.ex` IN-01 | `run/1` docstring claims `:quiet` "omits hints from returned rows" — but `run/1` delegates to `diagnose/1` which never reads `:quiet`; hint suppression is only in the Mix task | Info | Tracked todo: `.planning/todos/pending/2026-05-29-phase-138-doctor-info-findings.md`; deferred to Phase 140. Doc-only inaccuracy, no behavior impact. |
| `lib/sigra/doctor.ex` IN-02 | `bcrypt_configured?/1` is hardcoded `false`, making `:password_migration` a two-state feature. `hint_active`/`hint_broken` strings are dead code. | Info | Tracked todo same file; deferred to Phase 140. Intentional per inline comment; no correctness impact. |
| `test/sigra/mix/tasks/doctor_task_test.exs` IN-03 | Test 8 reads source file via CWD-relative path (`File.read!("lib/mix/tasks/sigra.doctor.ex")`) and greps for "System.halt" — brittle (would match comments; CWD-coupled) | Info | Tracked todo same file; deferred to Phase 140. Test 6 already provides behavioral coverage of the same property. |

No BLOCKER or WARNING anti-patterns. No `TBD`, `FIXME`, or `XXX` markers in either production file. The three Info findings are formally tracked in `.planning/todos/pending/2026-05-29-phase-138-doctor-info-findings.md` with resolution target Phase 140.

---

### Code Review Alignment

The phase underwent a standard code review (138-REVIEW.md, 2026-05-29) that found 1 Critical + 6 Warnings + 3 Info findings. All 7 Critical/Warning findings were fixed in commit `6c936a9`:

- **CR-01**: `encryption_hard_fail?` now mirrors `verify_vault!/1` exactly (passkeys + user_schema guard; phantom `:store_tokens` key removed).
- **WR-01**: `passkeys_enabled?/1` default aligned to `Sigra.Application` (`true` when `:passkeys` key absent).
- **WR-02**: `oauth_configured?` now honors `enabled: false` master switch.
- **WR-03**: `totp_configured?` now checks `mfa[:enabled]` sub-key.
- **WR-04**: `audit_forwarding_hard_fail?` multi-clause pattern guards against malformed forwarder entries.
- **WR-05**: All `configured?` predicates route through `sub/2` helper, defending against unvalidated `Application.get_env` raw input.
- **WR-06**: `:module_loaded?` injection key added, making D-09 #4 forwarder-not-loaded branch fully unit-testable via injection seam.

The test suite grew from 13 (plan-01 spec) to 22 (doctor_test.exs) + 8 (task test) = 30 total doctor-specific tests after the review fixes. The 3 Info findings are deferred to Phase 140 with tracked todo.

---

### Human Verification Required

None. All behavioral properties are verified programmatically via the injection seam design (D-04) and CaptureIO integration tests. ANSI color rendering and TTY auto-degradation behavior are covered by the `Mix.shell()` abstraction and are not critical path for the phase goal.

---

## Gaps Summary

No gaps. All four ROADMAP success criteria are verified against the actual codebase. The phase goal — "An adopter can run one command and see, per feature, which optional dependencies are loaded/available/configured-but-missing/missing, with actionable next steps, and the command fails loudly when a configured feature is wired wrong" — is fully achieved:

- The command (`mix sigra.doctor`) exists and is registered with Mix.
- All nine features have rows with all four states reachable and hints populated.
- Four D-09 hard-fail conditions are implemented, tested, and properly exit with code 1.
- Dep-off installs remain green (exit 0) per the CI-gate-green invariant.

---

_Verified: 2026-05-29T16:13:55Z_
_Verifier: Claude (gsd-verifier)_
