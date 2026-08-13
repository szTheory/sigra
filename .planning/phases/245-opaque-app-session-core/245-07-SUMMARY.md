---
phase: 245-opaque-app-session-core
plan: 07
subsystem: auth
tags: [ecto, postgres, account-deletion, opaque-tokens, transaction, revocation]
requires:
  - phase: 245-opaque-app-session-core
    provides: Transaction-composable opaque app-session family and token revocation.
provides:
  - Account-deletion scheduling revokes configured app-session credentials in its existing transaction.
  - PostgreSQL proof for deletion rollback co-fate, user isolation, and finalization safety.
affects: [246-first-party-app-session-install-and-issuance, account-deletion]
tech-stack:
  added: []
  patterns: [transaction-composed security-event revocation, configured-schema compatibility]
key-files:
  created: [test/sigra/app_session_account_deletion_test.exs]
  modified: [lib/sigra/account/deletion.ex, test/sigra/account/deletion_test.exs]
key-decisions:
  - "Deletion scheduling appends the schema-agnostic app-session revoke Multi before its hook and transaction commit."
  - "Hosts without both configured app-session schemas retain the existing deletion and worker lifecycle."
patterns-established:
  - "Security-event credential invalidation shares the initiating lifecycle Multi, rather than running after commit."
requirements-completed: [APP-05]
coverage:
  - id: D1
    description: "Deletion scheduling atomically deactivates users, cleans ordinary tokens, and revokes app access and refresh credentials without affecting another user."
    requirement: APP-05
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_account_deletion_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "A later deletion hook failure rolls back account state, ordinary token cleanup, and app-session terminal fields; finalization strategies cannot restore the credential."
    requirement: APP-05
    verification:
      - kind: integration
        ref: "test/sigra/app_session_account_deletion_test.exs#deletion rollback and finalization tests"
        status: pass
    human_judgment: false
metrics:
  duration: 5min
  completed: 2026-08-13
  tasks: 1
  files: 3
status: complete
---

# Phase 245 Plan 07: Transactional Account-Deletion Revocation Summary

**Account-deletion scheduling now invalidates configured opaque app sessions in the same Ecto transaction as immediate deactivation, token cleanup, and lifecycle hooks.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-13T00:57:50Z
- **Completed:** 2026-08-13T01:02:50Z
- **Tasks:** 1/1
- **Files modified:** 3

## Accomplishments

- Composed the existing all-app-session revocation Multi into deletion scheduling before hooks and transaction commit.
- Added PostgreSQL proofs for next-auth access/refresh denial, rollback co-fate, cross-user isolation, and soft/anonymize/hard-delete finalization.
- Retained browser-session post-commit behavior and existing no-app-session scheduling/worker compatibility.

## Task Commits

1. **Task 1: Revoke app sessions inside account-deletion scheduling** — `8b7f6d50` (RED), `10997447` (GREEN)

## Files Created/Modified

- `lib/sigra/account/deletion.ex` — appends configured app-session lifecycle revocation to the scheduling Multi.
- `test/sigra/app_session_account_deletion_test.exs` — real PostgreSQL transaction, rollback, isolation, and finalization coverage.
- `test/sigra/account/deletion_test.exs` — verifies the composed Multi and schema-absent compatibility.

## Decisions Made

- App-session revocation is performed before the deletion hook within the same outer transaction; hook failure rolls it back.
- Only hosts with both app-session schemas activate the new Multi step, preserving existing hosts unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved microsecond timestamps for app-session-compatible account schemas**
- **Found during:** Task 1 PostgreSQL verification
- **Issue:** Schedule timestamps truncated to seconds cannot be stored by representative `:utc_datetime_usec` user schemas.
- **Fix:** Retained `DateTime.utc_now/0` microsecond precision through deletion scheduling.
- **Files modified:** `lib/sigra/account/deletion.ex`
- **Verification:** Focused PostgreSQL account-deletion suite passes.
- **Committed in:** `10997447`

**Total deviations:** 1 auto-fixed Rule 1 bug. No scope expansion.

## Known Stubs

None.

## Threat Flags

None — this change narrows deletion-time authentication authority and introduces no new endpoint, trust boundary, or data exposure surface.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_account_deletion_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --trace` — passed, 40 tests.
- `MIX_ENV=test mix format --check-formatted lib/sigra/account/deletion.ex test/sigra/app_session_account_deletion_test.exs test/sigra/account/deletion_test.exs` — passed.
- `git diff --check` — passed.

## Self-Check: PASSED

- All three planned implementation and test files exist.
- TDD commits `8b7f6d50` and `10997447` exist in git history.
