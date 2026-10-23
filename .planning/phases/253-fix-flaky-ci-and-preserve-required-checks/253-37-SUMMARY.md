---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "37"
subsystem: testing
tags: [ci-reliability, load-recovery, sanitation, database-cleanup]
requires:
  - phase: 253
    provides: CR-DARK-FIRST native control receipts and the quiet-drop gap
provides:
  - validateSanitizedCommandLog (exact safe redaction marker accepted, credentials/headers/keys rejected)
  - captureOwnedDatabaseAbsence and verifyDatabaseAbsenceReceipt (independent pg_database zero-row proof)
affects: [253 native recovery plans]
actuals:
  tokens: 9500
  tasks: 2
  commits: 2
plan_head_before: 796951df4907dcb3f5925031dc16494f86c1c920
plan_head_after: 5db451e2b707ca6f433f0998223726b0e9c002e0
tech-stack:
  added: []
  patterns: ["injected spawn double for hermetic psql tests", "hash-bound zero-count query log as cleanup receipt"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "Query is piped on stdin so psql variable interpolation (:'target') applies; -c would not interpolate."
  - "Absence receipt is required for every control attempt, not only quiet drops, so the old CR-DARK-FIRST receipt stays rejected."
  - "Absence query timeout is bounded by the command deadline; the 15000 ms cleanup reserve is not enlarged."
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "Exact [REDACTED seeded demo credentials] marker accepted at the native receipt boundary; plaintext rows, altered markers, signing keys and auth/cookie headers rejected"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#control receipt accepts the exact safe seeded-credentials redaction marker"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#sanitized-log validation rejects plaintext credentials, near-match markers, keys and auth headers"
        status: pass
    human_judgment: false
  - id: D2
    description: "Zero-byte quiet drop log proves cleanup only with a digest-bound independent zero-row owned-database query; forged/failed/wrong-name/null receipts rejected"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#database absence verification rejects failed, forged, wrong-name, present-row and null receipts"
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 37: Sanitized-log and database-absence validation Summary

**The native control verifier now accepts only the exact seeded-credentials redaction line and treats a quiet `mix ecto.drop` as cleanup only when a digest-bound psql catalog query proves zero rows for the exact owned database.**

## Task Commits

1. Task 1: sanitized seeded-credentials log validation - `410f4437b` (feat)
2. Task 2: independent exact database-absence query for quiet drop - `5db451e2b` (feat)

## Accomplishments

- `validateSanitizedCommandLog(text)` exported and used by `verifyNativeControlAttempt`; the header plus exact marker line passes; extra rows, altered case/whitespace/CRLF marker, orphan marker, unredacted `secret_key_base`, Set-Cookie/Cookie/Authorization headers fail.
- `captureOwnedDatabaseAbsence` runs one bounded psql (`-X`, `ON_ERROR_STOP=1`, `-A -t`, maintenance DB `postgres`, parameterized `datname = :'target'`) with the password only in the environment; refuses names outside `sigra_253_control_`.
- `verifyDatabaseAbsenceReceipt` binds database, argv, query digest, connection identity, exit/signal/timeout, monotonic window, stdout count 0 and log SHA-256; empty drop log requires the real empty digest, drop exit 0 and a passing receipt.
- Both native control runners capture the receipt inside the existing command deadline and cleanup reserve; failures halt and are charged.
- No real native/Playwright/GitHub work performed. One read-only psql catalog probe on a local Postgres confirmed the query shape (count 0).

## Deviations from Plan

None - plan executed as written. The receipt is required for every control attempt (not only quiet drops), which is stricter than the minimum and keeps old CR-DARK-FIRST rejected.

## Issues Encountered

Five pre-existing tests in `ci-registration-recovery.test.mjs` fail (revision CLI freeze, retry, saved-receipt shell, usage counters, stale-source) because `.planning/config.json` carries an unrelated uncommitted operator edit that no longer matches its authorized SHA-256/blob (`assertDirtyConfigPreserved`). They fail identically at the pre-plan HEAD (verified in a detached worktree). Out of scope; config.json must not be touched. All 37 other tests, including 7 new ones, pass.

## Known Stubs

None.

## Next Phase Readiness

Future authorized native runs will produce the actual absence receipt. Full Phase253 verification stays not_started until root runs `$gsd-execute-phase 253`.

## Self-Check: PASSED
