---
phase: 245-opaque-app-session-core
plan: 06
subsystem: auth
tags: [elixir, ecto-multi, postgres, app-sessions, security-events]
requires:
  - phase: 245-05
    provides: owner-scoped `Sigra.AppSession.append_revoke_all_multi/4`
provides:
  - Password-reset transaction revokes configured opaque app-session families before audit commit.
  - Global sign-out fails closed unless opaque app credentials are durably revoked.
  - PostgreSQL co-fate, rollback, and next-auth denial coverage for both security events.
affects: [account-deletion, generated-auth-contexts]
tech-stack:
  added: []
  patterns: [security-event lifecycle fanout via caller-owned Ecto.Multi]
key-files:
  created: [test/sigra/app_session_security_event_test.exs]
  modified: [lib/sigra/auth.ex, test/sigra/auth_test.exs]
key-decisions:
  - "Password reset receives an optional validated app_session_config and composes revoke-all before its existing audit step."
  - "Sign-out-all revokes app sessions before deleting browser sessions, so failures never report a complete sign-out."
patterns-established:
  - "Credential-family lifecycle mutations are performed in the surrounding security-event transaction when one exists."
requirements-completed: [APP-05]
coverage:
  - id: D1
    description: Password reset atomically invalidates app access and refresh credentials with its audit and token cleanup.
    requirement: APP-05
    verification:
      - kind: integration
        ref: test/sigra/app_session_security_event_test.exs#password reset revokes app credentials in its transaction
        status: pass
      - kind: integration
        ref: test/sigra/app_session_security_event_test.exs#password-reset audit rejection rolls back password reset state
        status: pass
    human_judgment: false
  - id: D2
    description: Sign-out-all revokes only the target user's app credentials regardless of browser except_token.
    requirement: APP-05
    verification:
      - kind: integration
        ref: test/sigra/app_session_security_event_test.exs#sign-out-all revokes only the target user's app credentials
        status: pass
      - kind: unit
        ref: test/sigra/auth_test.exs#returns an error when configured app-session revocation fails
        status: pass
    human_judgment: false
duration: 25min
completed: 2026-08-12
status: complete
---

# Phase 245 Plan 06: Security-Event App-Session Fanout Summary

**Password reset and global sign-out now durably revoke opaque app-session families, with PostgreSQL proof that reset rollback preserves all credential state.**

## Performance

- **Duration:** 25 min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Added a reset lifecycle seam that appends configured app-session revocation to the existing `Ecto.Multi` before audit insertion.
- Made sign-out-all fail closed before browser deletion when configured app-session revocation cannot commit; browser `except_token` remains browser-only.
- Added deterministic PostgreSQL evidence for next-auth denial, cross-user isolation, secret-free audit metadata, and rollback co-fate.

## Task Commits

1. **Task 1: Co-fate password reset with app-session invalidation** - `205eef80` (test), `4f04707e` (feat)
2. **Task 2: Fan out sign-out-all to browser and app sessions** - `4f04707e` (feat)

## Files Created/Modified

- `lib/sigra/auth.ex` - Composes reset revocation and gates browser sign-out on app-session durability.
- `test/sigra/auth_test.exs` - Covers reset Multi ordering and sign-out failure behavior.
- `test/sigra/app_session_security_event_test.exs` - Real PostgreSQL lifecycle co-fate coverage.

## Decisions Made

- Password reset takes optional `:app_session_config` rather than changing unconfigured-host behavior.
- App sessions never inherit browser `:except_token`; all target-user app families are revoked.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_security_event_test.exs test/sigra/auth_test.exs --trace` — 77 tests passed.
- Full app-session suite (including refresh, audit, concurrency, plug, security-event, and auth tests) — 96 tests passed.

## Self-Check: PASSED

- Confirmed task commits `205eef80` and `4f04707e` exist.
- Confirmed all declared implementation and test artifacts exist.

## Next Phase Readiness

Account-deletion scheduling can reuse the same transactional revoke-all builder without a post-commit gap.
