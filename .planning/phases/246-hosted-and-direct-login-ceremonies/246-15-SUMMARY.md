---
phase: 246-hosted-and-direct-login-ceremonies
plan: 15
subsystem: auth
tags: [elixir, ecto, postgresql, hosted-login, replay-protection]
requires:
  - phase: 246-13
    provides: hosted login ceremony and explicit approval facade
provides:
  - Signed hosted continuations with digest-only one-time approval bindings
  - Atomic hosted-code issuance and replay rejection at the PostgreSQL boundary
affects: [hosted-login, app-sessions, generated-app-sessions]
tech_stack:
  added: []
  patterns: [Ecto.Multi transaction, unique nonce digest, deterministic PostgreSQL constraint fault]
key_files:
  created: []
  modified:
    - lib/sigra/app_login.ex
    - test/support/app_login_schemas.ex
    - test/sigra/app_login_test.exs
    - test/sigra/app_login_audit_cofate_test.exs
    - priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex
    - priv/templates/sigra.install/app_sessions/app_sessions_migration.exs
decisions:
  - Hosted approval continuations carry a signed nonce whose digest is uniquely persisted with the hosted code in one transaction.
metrics:
  duration: 12m
  completed: 2026-08-13
status: complete
---

# Phase 246 Plan 15: Atomic Hosted Approval Replay Protection Summary

Hosted approval continuations now mint at most one 60-second code through a unique, digest-only approval binding committed in the same transaction as code creation.

## Tasks Completed

1. Bound signed hosted continuations to a cryptographically generated approval nonce, persisted only as a unique digest alongside the hosted code.
2. Added deterministic PostgreSQL constraint-fault proof that failed approval insertion rolls back and leaves the continuation retryable once.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_audit_cofate_test.exs --trace` — passed (11 tests).
- `mix format --check-formatted lib/sigra/app_login.ex test/support/app_login_schemas.ex test/sigra/app_login_test.exs test/sigra/app_login_audit_cofate_test.exs` — passed.
- `git diff --check` — passed.

## Decisions Made

- The approval nonce remains inside the signed continuation; public results and telemetry expose neither nonce nor digest.
- A nullable unique `approval_digest` field allows direct-MFA records to remain in the shared host schema while making each hosted approval single-use.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Normalize unexpected hosted approval persistence constraints**
   - **Found during:** Task 2
   - **Issue:** A deterministic PostgreSQL check constraint raised `Ecto.ConstraintError` instead of returning the bounded invalid-continuation response.
   - **Fix:** Rescued transactional persistence exceptions at the approval boundary and normalized them to `:invalid_continuation`.
   - **Files modified:** `lib/sigra/app_login.ex`
   - **Commit:** b548f2b2

2. **[Rule 2 - Missing critical functionality] Add generated host schema persistence for approval digests**
   - **Found during:** Task 1
   - **Issue:** The generated shared ceremony schema did not retain the approval digest or enforce its uniqueness.
   - **Fix:** Added `approval_digest` and a unique index to the generated schema and migration templates.
   - **Files modified:** `priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex`, `priv/templates/sigra.install/app_sessions/app_sessions_migration.exs`
   - **Commit:** 9ce54686

**Total deviations:** 2 auto-fixed (1 bug, 1 critical functionality). **Impact:** Required to preserve the bounded public failure contract and make the unique digest storage available to generated hosts.

## Known Stubs

None.

## Self-Check: PASSED

- Verified all six modified production, schema, template, and test files exist.
- Verified task commits `3029c838`, `9ce54686`, `00316b4d`, and `b548f2b2` exist in git history.
