---
phase: 246-hosted-and-direct-login-ceremonies
plan: 01
subsystem: auth
tags: [app-session, hosted-login, ecto, postgresql, transaction]
requires:
  - phase: 245-opaque-app-session-core
    provides: Digest-only opaque app-session family issuance and authentication
provides:
  - Locked digest-addressed hosted-code exchange composed with app-session issuance
  - Reusable app-session Ecto.Multi issuer that releases raw credentials only after commit
affects: [246-02, hosted-login, direct-login]
tech-stack:
  added: []
  patterns: [locked attempt exchange, composed credential issuance Multi, post-commit credential response]
key-files:
  created: [lib/sigra/app_login.ex, lib/sigra/app_login/attempt.ex, test/sigra/app_login_test.exs, test/support/app_login_schemas.ex]
  modified: [lib/sigra/app_session.ex]
key-decisions:
  - "Hosted attempt consumption, optional audit, and Phase 245 issuance execute in one Ecto.Multi transaction."
  - "Raw access and refresh material remains only in Ecto.Multi changes until the outer transaction commits."
patterns-established:
  - "Ceremony exchanges use digest-addressed FOR UPDATE lookup, bound-field validation, consumption, and composable issuance in one transaction."
requirements-completed: [APP-02, APP-03]
coverage:
  - id: D1
    description: Hosted code exchange commits one consumed attempt and authenticatable Phase 245 session.
    requirement: APP-02
    verification:
      - kind: integration
        ref: test/sigra/app_login_test.exs#consumes one locked hosted code and issues an authenticatable app session
        status: pass
    human_judgment: false
  - id: D2
    description: Terminal bindings and persistence or audit faults return no credential and roll back the hosted attempt.
    requirement: APP-03
    verification:
      - kind: integration
        ref: test/sigra/app_login_test.exs#rollback and terminal binding cases
        status: pass
    human_judgment: false
duration: 13min
completed: 2026-08-13
status: complete
---

# Phase 246 Plan 01: Hosted Exchange Transaction Tracer Summary

**A digest-locked hosted code now atomically consumes once and issues the existing opaque app-session pair only after commit.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-08-13T01:42:49Z
- **Completed:** 2026-08-13T01:55:49Z
- **Tasks:** 1/1
- **Files modified:** 5

## Accomplishments

- Refactored `Sigra.AppSession.issue/4` around a reusable composable Ecto.Multi builder.
- Added `Sigra.AppLogin.exchange_hosted/5` with digest lookup, `FOR UPDATE`, trusted binding validation, and terminal consumption.
- Proved PostgreSQL rollback for audit and credential persistence faults without leaking a credential or consuming the code.

## Task Commits

1. **Task 1: Exchange one locked hosted code into the existing app-session family** - `7c2563f6` (test), `8d53d77d` (feat), `8280747b` (test)

## Files Created/Modified

- `lib/sigra/app_session.ex` - Exposes the composable app-session issuance Multi.
- `lib/sigra/app_login.ex` - Provides the bounded hosted exchange facade.
- `lib/sigra/app_login/attempt.ex` - Locks, validates, consumes, audits, and composes issuance for hosted attempts.
- `test/support/app_login_schemas.ex` - Defines the host-owned test attempt schema.
- `test/sigra/app_login_test.exs` - Covers committed exchange, terminal rejection, and transaction rollback.

## Decisions Made

- Hosted exchange normalizes every failed attempt path to `:invalid_code`.
- The server-stored profile, client reference, callback, and verifier digest must all match before consumption.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Bound the persisted client reference to the trusted profile before issuance.**
- **Found during:** Task 1
- **Issue:** Profile ID, callback, and verifier matching alone could allow a mismatched persisted client reference to reach issuance.
- **Fix:** Require exact server-stored `client_ref` equality before consuming the locked attempt.
- **Files modified:** `lib/sigra/app_login/attempt.ex`
- **Verification:** Focused PostgreSQL exchange suite passed.
- **Committed in:** `8d53d77d`

**Total deviations:** 1 auto-fixed (Rule 2)

## Issues Encountered

The focused PostgreSQL verification passed (14 tests). A subsequent full `MIX_ENV=test mix test` run reported 21 pre-existing/unrelated failures, including architecture-guide source drift, installer-template drift, and historical planning-contract files. These failures are outside this tracer's declared files and were not modified.

## User Setup Required

None - the focused suite uses the configured local PostgreSQL test database.

## Next Phase Readiness

Plan 246-02 can supply the validated static profile registry, PKCE primitives, and hosted start/approval flow to this exchange seam.

## Self-Check: PASSED

All five implementation/test artifacts exist and all three task commits are present in git history.
