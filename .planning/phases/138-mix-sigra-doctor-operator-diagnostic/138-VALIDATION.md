---
phase: 138
slug: mix-sigra-doctor-operator-diagnostic
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
validated: 2026-05-29
reconstructed: true
reconstruction_source: [138-01-SUMMARY.md, 138-02-SUMMARY.md, 138-VERIFICATION.md]
---

# Phase 138 — Validation Strategy

> Per-phase validation contract, reconstructed at milestone close from delivered
> artifacts (State B: VERIFICATION.md + SUMMARY files present, no pre-execution
> VALIDATION.md was filed). Both requirements are COVERED by green automated tests;
> no gaps, no auditor spawn required.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 / OTP 28, per `.tool-versions`) |
| **Config file** | none custom — standard `mix test`; `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | doctor unit + task files ~0.1s (no DB needed); full suite minutes (needs live Postgres @ localhost:5432) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/doctor_test.exs` (+ task test file for Plan 02)
- **After every plan wave:** Run full `mix test` + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~0.1 seconds (doctor files run without DB via the injection seam)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| doctor-pure-module | 138-01 | 1 | DR-01 | T-138-01 | Nine-feature matrix; all four DR-01 states (`:missing`/`:available`/`:loaded_active`/`:configured_but_missing`) reachable; every row has a non-empty hint; no secret values in hints | unit | `mix test test/sigra/doctor_test.exs` | ✅ | ✅ green |
| doctor-hard-fail | 138-01 | 1 | DR-02 | T-138-04 | Four D-09 hard-fail conditions (async forwarder w/o Oban, async email w/o Oban, encryption stub + passkeys/user_schema, forwarder module not loaded) each yield `verdict: :fail`; dep-off all-false → `:ok` | unit | `mix test test/sigra/doctor_test.exs` (tests 5/6/7/8 + dep-off invariant test 9) | ✅ | ✅ green |
| doctor-mix-task | 138-02 | 2 | DR-01 | T-138-03 | ANSI matrix renders all nine feature names via `Mix.shell().info/1`; `--quiet` omits hints but never the error gate; no `IO.puts`/`System.halt` | integration (CaptureIO) | `mix test test/sigra/mix/tasks/doctor_task_test.exs` | ✅ | ✅ green |
| doctor-exit-gate | 138-02 | 2 | DR-02 | T-138-04 / T-138-05 | `exit({:shutdown, 1})` fires only on `:fail` verdict, after the full report prints; unknown flag raises `Mix.Error`; clean/dep-off exits 0 | integration (CaptureIO) | `mix test test/sigra/mix/tasks/doctor_task_test.exs` (test 6 misconfig exit, test 7 report-before-exit, test 5 bad flag) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements — ExUnit present, no framework install needed.
- [x] `test/sigra/doctor_test.exs` — 22 unit tests via the injection seam (D-04); no `CaptureIO`/`Mix.Task.run`/`System.cmd`. Covers all four DR-01 states, all four D-09 DR-02 hard-fail conditions, the dep-off `:ok` invariant, and the every-row-has-a-hint assertion. **Created in 138-01 (RED `e356245` → GREEN `4c69dcf`).**
- [x] `test/sigra/mix/tasks/doctor_task_test.exs` — 8 CaptureIO integration tests: dep-off smoke (green), nine feature names in output, shortdoc visible, `--quiet`, bad-flag raise, `exit({:shutdown, 1})` on misconfig, full report before exit, no `System.halt`. **Created in 138-02 (RED `3cfb606` → GREEN `87b7c51`).**

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ANSI color rendering / TTY auto-degradation | DR-01 (cosmetic) | Visual-only; the `Mix.shell()` abstraction handles non-TTY/CI degradation and is not phase-critical | Run `mix sigra.doctor` in a color terminal vs. piped to a file; confirm colors degrade to plain text when non-TTY |

*All goal-critical behaviors have automated verification. The single manual entry is cosmetic ANSI rendering, explicitly non-critical-path per 138-VERIFICATION.md.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — existing ExUnit infra sufficient)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (doctor files ran in 0.1s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-29 — reconstructed at milestone close; 30/30 doctor-specific tests green (`mix test test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs` → 30 tests, 0 failures, 0.1s), both DR-01/DR-02 COVERED, 0 gaps.

---

## Validation Audit 2026-05-29

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

State-B reconstruction (no pre-execution VALIDATION.md existed). Cross-referenced the 2 requirements (DR-01, DR-02) against delivered tests: both COVERED by green automated suites. No MISSING/PARTIAL classifications, so no `gsd-nyquist-auditor` spawn was needed.

**Test run (this audit):**
- `mix test test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs` → 30 tests, 0 failures (0.1s, no DB — injection seam + CaptureIO)

**Tech-debt note (non-blocking, does not affect Nyquist compliance):** Phase-138 Info findings IN-01/IN-02/IN-03 (doc-only `:quiet` inaccuracy in `run/1`; `bcrypt_configured?/1` hardcoded `false`; test-8 CWD-relative source grep) remain tracked in `.planning/todos/pending/2026-05-29-phase-138-doctor-info-findings.md`. None alter requirement coverage.
