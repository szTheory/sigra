---
phase: 246-hosted-and-direct-login-ceremonies
plan: 03
subsystem: auth
tags: [hosted-login, postgres, concurrency, audit, pkce]
requires:
  - phase: 246-hosted-and-direct-login-ceremonies
    provides: Locked S256 hosted-code exchange and app-session issuance
provides:
  - Barrier-controlled PostgreSQL proof that a hosted code issues one session exactly once
  - Audit/persistence rollback proof with bounded hosted-exchange audit evidence
affects: [246-04, hosted-login]
tech-stack:
  added: []
  patterns: [Sandbox ready/go barrier, real FOR UPDATE race proof, same-transaction audit co-fate]
key-files:
  created: [test/sigra/app_login/concurrency_test.exs, test/sigra/app_login_audit_cofate_test.exs]
  modified: []
key-decisions:
  - "Hosted-code concurrency proof asserts the result multiset and persisted state, never a winner identity."
  - "Hosted exchange audit records only action, attempt ID, profile ID, and family ID in the issuance transaction."
requirements-completed: [APP-02]
coverage:
  - id: D1
    description: Two concurrent hosted-code exchanges serialize to one committed app session and one bounded invalid-code result.
    requirement: APP-02
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: Optional hosted-exchange audit co-fates with credential persistence, while fault, expiry, and replay paths reveal no credential.
    requirement: APP-02
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_audit_cofate_test.exs test/sigra/app_login/concurrency_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 13min
  completed: 2026-08-13
  tasks: 2
  files: 2
status: complete
---

# Phase 246 Plan 03: Hosted Exchange Concurrency and Co-Fate Summary

**Hosted login now has deterministic PostgreSQL proof of exactly-once code exchange and rollback-safe bounded audit evidence.**

## Performance

- **Duration:** 13 min
- **Completed:** 2026-08-13T02:08:17Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Added two real Sandbox-allowed callers behind a ready/go barrier that race the same hosted code through `Sigra.AppLogin.exchange_hosted/5`; it proves one issuance, one uniform rejection, one consumed attempt, one family, and one access/refresh pair.
- Added audit-on/off lifecycle parity coverage that verifies exact bounded audit metadata and excludes raw credential material from returned fault outcomes.
- Added deterministic audit and app-session persistence constraint fault coverage; after cleanup, the unchanged hosted code successfully exchanges, proving the failed transaction left no consumed code or credential rows.
- Pinned expiry and replay to the same `:invalid_code` terminal result without another session issuance.

## Task Commits

1. **Task 1: Serialize two real hosted-code exchanges** — `0dd52ad4` (test)
2. **Task 2: Prove hosted audit and persistence faults roll back together** — `26ba1c71` (test)

## Files Created/Modified

- `test/sigra/app_login/concurrency_test.exs` — creates the exact hosted/session PostgreSQL schema fixtures and barrier-released exchange race proof.
- `test/sigra/app_login_audit_cofate_test.exs` — verifies bounded audit metadata, disabled-audit parity, fault rollback/recovery, expiry, and replay.

## Decisions Made

- Tests assert only observable public-facade results and stored rows; the exchange winner is intentionally unspecified.
- Constraint faults use temporary named PostgreSQL constraints with `try/after` cleanup, preserving deterministic isolation and proving a retry of the same code after cleanup.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Test setup] Completed the paired static profile configuration required by the hosted exchange test config.**
- **Found during:** Task 1 RED verification.
- **Issue:** The initial proof omitted the required challenge schema and static profile registry, so config validation stopped before the public exchange could run.
- **Fix:** Added the paired challenge schema and a finite static `ios-primary` profile to the test config.
- **Files modified:** `test/sigra/app_login/concurrency_test.exs`
- **Verification:** Focused concurrency suite passed.
- **Commit:** `0dd52ad4`

2. **[Rule 1 - Test isolation] Scoped co-fate assertions to each family and captured lifecycle baselines across fault cases.**
- **Found during:** Task 2 RED verification.
- **Issue:** Sequential mode cases shared the test transaction, causing global row-count assertions to include a preceding successful mode case.
- **Fix:** Asserted family-scoped token counts and compared each failed fault case with its pre-fault lifecycle baseline.
- **Files modified:** `test/sigra/app_login_audit_cofate_test.exs`
- **Verification:** Combined co-fate and concurrency suites passed.
- **Commit:** `26ba1c71`

**Total deviations:** 2 auto-fixed Rule 1 test fixes. Production exchange code already satisfied the locked transactional contract, so no speculative refactor was introduced.

## Known Stubs

None.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_audit_cofate_test.exs test/sigra/app_login/concurrency_test.exs --trace` — passed, 4 tests / 0 failures.
- `mix format --check-formatted lib/sigra/app_login.ex lib/sigra/app_login/attempt.ex test/sigra/app_login_audit_cofate_test.exs test/sigra/app_login/concurrency_test.exs` — passed.
- `git diff --check` — passed.
- `rg -n "\\b(Process\\.sleep|:timer\\.sleep)\\b" lib/sigra/app_login.ex lib/sigra/app_login/attempt.ex test/sigra/app_login_audit_cofate_test.exs test/sigra/app_login/concurrency_test.exs` — no matches.

## Next Phase Readiness

Phase 246 can expand hosted and direct ceremony surfaces with a deterministic proof that hosted bearer-code exchange is atomic under concurrent callers and persistence faults.

## Self-Check: PASSED

- `test/sigra/app_login/concurrency_test.exs` and `test/sigra/app_login_audit_cofate_test.exs` exist.
- Task commits `0dd52ad4` and `26ba1c71` exist in git history.
