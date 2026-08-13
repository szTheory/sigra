---
phase: 245-opaque-app-session-core
plan: 03
subsystem: auth
tags: [ecto, postgres, opaque-tokens, refresh-rotation, row-locking]
requires:
  - phase: 245-opaque-app-session-core
    provides: Dedicated family and typed opaque credential rows with digest-only issuance.
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: Locked refresh lifecycle and post-commit response pattern.
provides:
  - Locked opaque refresh classification and atomic credential-family rotation.
  - Committed consumed-token reuse revocation with immediate access denial.
affects: [246-first-party-app-session-install-and-issuance]
tech-stack:
  added: []
  patterns: [digest-addressed FOR UPDATE classification, indexed family revocation, post-commit raw credential response]
key-files:
  created: [lib/sigra/app_session/refresh_token.ex]
  modified: [lib/sigra/app_session.ex, test/sigra/app_session_test.exs]
key-decisions:
  - "Refresh locks the exact typed digest row before classifying rotation, expiry, or reuse."
  - "Consumed refresh reuse revokes the indexed family and all of its credential rows in the same transaction."
  - "Replacement raw credentials are generated in the transaction flow and exposed only from a successful transaction result."
patterns-established:
  - "App-session token rotation appends typed rows, consumes the presented refresh row, and supersedes active access rows without altering the family's absolute deadline."
requirements-completed: [APP-04]
coverage:
  - id: D1
    description: PostgreSQL-backed opaque refresh lifecycle covering locked rotation, bounded idle/absolute expiry, and consumed-token family revocation.
    requirement: APP-04
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 5min
  completed: 2026-08-13
  tasks: 1
  files: 3
status: complete
---

# Phase 245 Plan 03: Locked App-Session Refresh Summary

**Opaque app-session refresh now locks the presented digest row, atomically rotates its family or revokes it on reuse, and returns raw replacements only after commit.**

## Performance

- **Duration:** 5 min
- **Completed:** 2026-08-13T00:42:38Z
- **Tasks:** 1/1
- **Files modified:** 3

## Accomplishments

- Added a PostgreSQL `FOR UPDATE` digest-and-kind refresh classifier before every lifecycle branch.
- Made valid refresh rotation consume the presented refresh row, supersede active access credentials, and append a new typed pair under the unchanged family deadline.
- Made consumed refresh reuse revoke only its indexed family and deny its active access immediately after the transaction commits.

## Task Commits

1. **Task 1: Rotate or revoke one family from a locked refresh classification** - `e2156dfa` (RED), `0760767f` (GREEN)

## Files Created/Modified

- `lib/sigra/app_session/refresh_token.ex` - Locked classifier plus rotate and family-revoke `Ecto.Multi` builders.
- `lib/sigra/app_session.ex` - Public post-commit `refresh/2` orchestration.
- `test/sigra/app_session_test.exs` - PostgreSQL lifecycle proof for rotation, expiry, reuse, and family isolation.

## Decisions Made

- Typed token columns and indexed `family_id` updates replace JSON/`LIKE` lifecycle matching for app sessions.
- Expiry is normalized to `:token_expired`; malformed, wrong-kind, revoked inputs normalize to `:invalid_token` without mutation.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

None.

## User Setup Required

None - `tmp/db.env` supplied the reachable PostgreSQL test database.

## Next Phase Readiness

Phase 246 can expose this committed refresh result/error contract while owning all generated host-facing ceremony and transport artifacts.

## Verification

- `MIX_ENV=test mix format --check-formatted lib/sigra/app_session.ex lib/sigra/app_session/refresh_token.ex test/sigra/app_session_test.exs` — passed.
- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` — passed, 6 tests / 0 failures.

## Self-Check: PASSED

- All planned implementation, test, and summary files exist.
- Both TDD task commits are present in git history.
