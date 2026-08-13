---
phase: 245-opaque-app-session-core
plan: 05
subsystem: auth
tags: [ecto, postgres, opaque-tokens, revocation, audit, security-events]
requires:
  - phase: 245-opaque-app-session-core
    provides: Dedicated opaque app-session family/token rows, synchronous access checks, and locked refresh lifecycle.
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: Optional audit Multi and post-commit telemetry conventions.
provides:
  - Owner-bound one-family and user-wide opaque app-session revocation APIs.
  - Transaction-composable all-session revoke Multi builder for later security events.
  - Stable Sigra.Auth delegates for host and generated callers.
affects: [246-first-party-app-session-install-and-issuance, password-reset, sign-out-all, account-deletion]
tech-stack:
  added: []
  patterns: [owner-bound locked family lookup, family-and-token revocation Multi, post-commit revoke audit telemetry]
key-files:
  created: []
  modified: [lib/sigra/app_session.ex, lib/sigra/auth.ex, test/sigra/app_session_test.exs]
key-decisions:
  - "Family selectors are bound to the trusted user ID in a locked active-family lookup, normalizing foreign, absent, and terminal selectors to not found."
  - "append_revoke_all_multi/4 performs only lifecycle mutation so security-event callers can compose their existing audit in the same outer transaction."
  - "Standalone device and all-app revokes append bounded session.app_* audit rows and emit telemetry only after commit."
patterns-established:
  - "Revocation updates both the family and every still-unrevoked typed token row before the next authentication or refresh attempt."
requirements-completed: [APP-05]
coverage:
  - id: D1
    description: Owner-safe single-family revocation normalizes foreign and terminal selectors, audits only the owned mutation, and immediately denies access and refresh.
    requirement: APP-05
    verification:
      - kind: integration
        ref: "test/sigra/app_session_test.exs#owner-bound family revoke immediately denies its access and refresh without leaking foreign selectors"
        status: pass
    human_judgment: false
  - id: D2
    description: All-app revocation is user-scoped, audit-atomic, transaction-composable, and denies each affected credential on its next use.
    requirement: APP-05
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 4min
  completed: 2026-08-12
  tasks: 1
  files: 3
status: complete
---

# Phase 245 Plan 05: Owner-Safe App-Session Revocation Summary

**Owner-constrained device and all-app opaque-session revocation now atomically invalidates family credentials, commits bounded audit evidence, and exposes reusable security-event composition.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-12T20:50:45-04:00
- **Completed:** 2026-08-12T20:53:53-04:00
- **Tasks:** 1/1
- **Files modified:** 3

## Accomplishments

- Added `revoke_family_for_user/3` and `revoke_all_for_user/2`, which revoke family and typed token rows together.
- Added `append_revoke_all_multi/4` for caller-owned security-event transactions without a standalone transaction or duplicate audit.
- Added `Sigra.Auth` delegates and PostgreSQL proof for cross-account isolation, audit co-fate, rollback, and immediate access/refresh denial.

## Task Commits

1. **Task 1: Revoke one owned family or every family with durable next-auth denial** — `15751f41` (RED), `8e1a030d` (GREEN)

## Files Created/Modified

- `lib/sigra/app_session.ex` — owner-bound single/all revocation, atomic audit composition, and reusable Multi builder.
- `lib/sigra/auth.ex` — thin app-session revocation facade delegates.
- `test/sigra/app_session_test.exs` — PostgreSQL proofs for isolation, idempotency, audit rollback, and composable revocation.

## Decisions Made

- Foreign, missing, and already-revoked device selectors all return `{:error, :not_found}` and create no audit row.
- The reusable all-session builder mutates only lifecycle state; callers such as password reset retain ownership of their security-event audit entry.
- Standalone all-session revocation records the active-family count, including zero-count idempotent requests, in its bounded audit metadata.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized audit constraint exceptions at the public revoke boundary**
- **Found during:** Task 1 audit rollback proof
- **Issue:** An audit check-constraint violation escaped `Ecto.Multi`, despite the transaction rolling back family/token mutation.
- **Fix:** Return `{:error, :app_session_revoke_aborted}` after rollback for both one-family and all-family revoke paths.
- **Files modified:** `lib/sigra/app_session.ex`
- **Verification:** Audit-constraint rollback proof passes with the family and all tokens still usable.
- **Committed in:** `8e1a030d`

**Total deviations:** 1 auto-fixed Rule 1 bug.

## Issues Encountered

- The repository-wide `MIX_ENV=test mix test` run has unrelated historical planning/evidence and generator-contract failures. Details are recorded in `deferred-items.md`; the focused lifecycle, audit, and concurrency suite passes.

## Known Stubs

None.

## User Setup Required

None — `tmp/db.env` supplied the PostgreSQL connection used for deterministic integration proof.

## Next Phase Readiness

Phase 246 and the pending password-reset, sign-out-all, and deletion plans can call the stable facade or compose `append_revoke_all_multi/4` into their existing transactions.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` — passed, 10 tests.
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs --trace` — passed, 15 tests.
- `MIX_ENV=test mix format --check-formatted lib/sigra/app_session.ex lib/sigra/auth.ex test/sigra/app_session_test.exs` — passed.
- `git diff --check` — passed.

## Self-Check: PASSED

- All three planned implementation/test files exist.
- TDD RED commit `15751f41` precedes GREEN commit `8e1a030d` in git history.
