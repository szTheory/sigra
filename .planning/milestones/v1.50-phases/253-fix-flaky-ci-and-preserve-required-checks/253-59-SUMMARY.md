---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "59"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, diagnostics, r3, playwright-reporter]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: R2 runner, sanitizeCommandLog, receipt helpers
provides:
  - env-gated per-test fsync'd JSONL Playwright reporter
  - exported preserveAttemptDiagnostics and verifyAttemptDiagnosticsR3 (for 253-60's R3 path)
affects: [253-60]
actuals:
  tokens: 12500
  tasks: 2
  commits: 2
plan_head_before: bffffe90e4c901783f4f9c833700b4a225751590
plan_head_after: c2b355482aa37366e53099215b4ca55440db8706
commits: 2
tech-stack:
  added: []
  patterns: ["fsync-per-event JSONL so a killed CLI still leaves finished-test evidence", "preserve-then-sanitize-then-hash before temp cleanup"]
key-files:
  created:
    - test/example/priv/playwright/lib/reporters/failure-jsonl.mjs
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
    - scripts/ci/ci-playwright-load.test.mjs
key-decisions:
  - "Reporter registered only when SIGRA_PLAYWRIGHT_FAILURE_JSONL is non-empty; ordinary CI reporter list stays [list, html, json?]."
  - "Preserved JSONL is sanitized twice: raw bytes, and each decoded error message, because a JSON-escaped secret field is invisible to the line-oriented sanitizer."
  - "An unterminated final JSONL fragment (kill mid-write) is recorded as truncated_tail and tolerated by the verifier only when recorded."
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "Reporter appends and fsyncs one JSONL line per onTestEnd, surviving a missing onEnd; ANSI stripped, messages capped at 8192 bytes"
    requirement: "CIREL-01"
    verification:
      - {kind: unit, ref: "scripts/ci/ci-registration-recovery.test.mjs#failure JSONL reporter appends one fsynced line per finished test without onEnd", status: pass}
      - {kind: unit, ref: "scripts/ci/ci-registration-recovery.test.mjs#failure JSONL reporter fsyncs every line and truncates oversized messages to 8192 bytes", status: pass}
    human_judgment: false
  - id: D2
    description: "preserveAttemptDiagnostics copies sanitized JSONL and error-context.md files into the raw attempt directory with sha256 receipts, exclusive create"
    requirement: "CIREL-02"
    verification:
      - {kind: unit, ref: "scripts/ci/ci-registration-recovery.test.mjs#preserveAttemptDiagnostics (4 tests)", status: pass}
    human_judgment: false
  - id: D3
    description: "verifyAttemptDiagnosticsR3 rejects launched attempts lacking, tampering or malforming per-test JSONL"
    requirement: "CIREL-02"
    verification:
      - {kind: unit, ref: "scripts/ci/ci-registration-recovery.test.mjs#verifyAttemptDiagnosticsR3 (2 tests)", status: pass}
    human_judgment: false
  - id: D4
    description: "Reporter is inert without the env var and present exactly once in production and recovery configs with it"
    requirement: "CIREL-01"
    verification:
      - {kind: unit, ref: "scripts/ci/ci-playwright-load.test.mjs#failure JSONL reporter (2 tests)", status: pass}
    human_judgment: false
duration: 25min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 59: Per-test JSONL diagnostics Summary

**Env-gated fsync-per-test Playwright JSONL reporter plus exported runner helpers that preserve, sanitize and sha256-bind the JSONL and error-context files, and a verifier that rejects launched attempts lacking them.**

## Accomplishments
- `failure-jsonl.mjs`: dependency-free reporter, one fsync'd line per `onTestEnd`, `printsToStdio() === false`.
- `playwright.config.ts`: reporter entry only when `SIGRA_PLAYWRIGHT_FAILURE_JSONL` is set; recovery config inherits it unchanged.
- `preserveAttemptDiagnostics` / `verifyAttemptDiagnosticsR3` exported from the runner, not wired into v1 or R2 paths.

## Task Commits
1. **Task 1: reporter, config entry, runner helpers** - `1bb00a16d` (feat)
2. **Task 2: loader contract for env gating** - `c2b355482` (test)

## RED / GREEN
- Task 1 RED: after adding the new tests, `ci-registration-recovery.test.mjs` reported 99 tests, 94 pass, 5 fail (all five preserve/verify tests; helpers did not exist). The three reporter tests passed immediately because the reporter module had been written before the tests (ordering deviation, noted below). GREEN: 100/100 after the helpers plus one added JSON-escaped-secret test.
- Task 2 RED: the new loader tests run against the parent commit's `playwright.config.ts` blob (via `git cat-file` into a temp tree with symlinked node_modules/tests/lib, no repo file edited): unset-variable test passed, set-variable test failed (no reporter entry). GREEN against the real config.
- Final: `ci-playwright-load.test.mjs` + `ci-registration-recovery.test.mjs` under Node 20.18.1: 116 tests, 116 pass, 0 fail, 0 skipped.

## Deviations from Plan

**1. [Process] Reporter written before its tests**
- **Found during:** Task 1
- **Issue:** The reporter module and config entry were created before the test file, so the three reporter tests have no observed failing run. The helper tests (5) and the config-gating test do have observed RED.
- **Impact:** Reporter behavior is still fully covered; no code change.

**2. [Rule 2 - Missing critical] Decoded-message sanitization**
- **Found during:** Task 1 (T-253-115)
- **Issue:** sanitizeCommandLog's `secret_key_base` pattern does not match the JSON-escaped form (`\"secret_key_base\"`) present in a JSONL line.
- **Fix:** each error message is decoded and sanitized separately before the file-level pass; test added.
- **Commit:** 1bb00a16d

**Total deviations:** 1 process note, 1 auto-added (Rule 2).

## Issues Encountered
None. Shell-default Node v26 was avoided; all tests run under Node 20.18.1.

## Known Stubs
None.

## Threat Flags
None beyond the plan's threat model (T-253-115 mitigated by sanitization and 8192-byte cap; T-253-116 by the verifier; T-253-SC no new dependency).

## Remaining gaps
- The helpers are not yet called from a native runner; 253-60 wires the R3 path.
- No Playwright CLI, browser or GitHub request was made. Full Phase253 verification stays not_started.

## Self-Check: PASSED
