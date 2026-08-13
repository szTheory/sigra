---
phase: 246-hosted-and-direct-login-ceremonies
plan: 05
subsystem: authentication
tags: [elixir, ecto, postgresql, direct-login, mfa, audit, concurrency]
requires:
  - phase: 246-04
    provides: direct password and digest-only MFA ceremony
provides:
  - Barrier-controlled proof that a direct MFA challenge yields one session family
  - Uniform direct-login fault and rollback evidence
  - Atomic direct-MFA audit persistence and post-commit telemetry
affects: [first-party native clients, generated direct-login host facade]
tech-stack:
  added: []
  patterns: [PostgreSQL FOR UPDATE race proof, Ecto.Multi audit co-fate, post-commit telemetry]
key-files:
  created:
    - test/sigra/app_login_direct_fault_test.exs
  modified:
    - lib/sigra/app_login.ex
    - lib/sigra/app_login/attempt.ex
    - test/sigra/app_login/concurrency_test.exs
decisions:
  - Direct MFA completion records bounded audit facts in the same transaction as challenge consumption and opaque credential issuance.
  - Direct-MFA audit telemetry is emitted only after the enclosing transaction commits.
metrics:
  duration: 18m
  tasks_completed: 2
  files_changed: 4
status: complete
---

# Phase 246 Plan 05: Direct Ceremony Hardening Summary

**Direct MFA is now proven single-use and rollback-safe under real PostgreSQL races, while every public direct-login failure remains uniform.**

## Accomplishments

- Added two-caller ready/go PostgreSQL proof for one direct-MFA challenge in audit-on and audit-off configurations: exactly one session family and access/refresh pair commit, and the loser receives the uniform denial.
- Added atomic bounded audit persistence for successful direct-MFA completion, including post-commit telemetry only.
- Added direct fault coverage for unknown/wrong/exceptional authentication, browser-only policy, malformed/expired/replayed/profile-mismatched challenges, audit failure rollback, and audit telemetry metadata exclusion.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_direct_fault_test.exs test/sigra/app_login/concurrency_test.exs --trace` — PASS (6 tests, 0 failures).
- `mix format --check-formatted lib/sigra/app_login.ex lib/sigra/app_login/attempt.ex test/sigra/app_login_direct_fault_test.exs test/sigra/app_login/concurrency_test.exs` — PASS.
- `git diff --check` — PASS.
- Direct hardening no-sleep source gate — PASS.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Make direct-MFA audit co-fate explicit**
- **Found during:** Task 1
- **Issue:** Direct MFA issued credentials without appending the configured audit event to its locked challenge-consumption transaction or emitting committed audit telemetry.
- **Fix:** Added bounded `session.app_login_direct_mfa` audit persistence to the existing `Ecto.Multi` and emitted its telemetry only after transaction success.
- **Files modified:** `lib/sigra/app_login.ex`, `lib/sigra/app_login/attempt.ex`, `test/sigra/app_login/concurrency_test.exs`, `test/sigra/app_login_direct_fault_test.exs`
- **Verification:** Audit-on race proof, audit-constraint rollback proof, and committed telemetry proof all pass.
- **Commits:** `8f631efb`, `2e0d6cc2`

**Total deviations:** 1 auto-fixed (1 missing critical security/audit behavior). **Impact:** No public API expansion; direct ceremony persistence and audit now share one atomic transaction.

## Known Stubs

None.

## Self-Check: PASSED

- All four key files exist.
- TDD RED and GREEN commits exist: `9c71bbc6`, `8f631efb`, `e76f35fa`, `2e0d6cc2`.
- Focused direct hardening suites and formatter checks pass.
