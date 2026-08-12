---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 02
subsystem: auth
tags: [personal-access-token, postgres, ecto, authorization, tdd]
requires:
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: "Independent PAT generator contract from Plan 01"
provides:
  - "Owner-constrained PAT self-service revocation with non-disclosing terminal outcomes"
  - "Library-side PAT scope validation for empty, duplicate, malformed, and unregistered scope selections"
affects: [244-03, PAT-02]
tech-stack:
  added: []
  patterns:
    - "Self-management mutations select the active record by both resource ID and authenticated owner before entering the audit transaction"
    - "Scope selection validation permits an explicitly allowed empty set while retaining registry checks for non-empty sets"
key-files:
  created: []
  modified:
    - lib/sigra/api_token.ex
    - lib/sigra/auth.ex
    - test/sigra/api_token_test.exs
key-decisions:
  - "Keep the generic administrative revoke API while exposing a distinct owner-required self-management facade."
  - "Treat empty PAT scopes as an explicitly permitted subset and reject repeated scope values before persistence."
requirements-completed: [PAT-02]
coverage:
  - id: D1
    description: "Owner-constrained PAT revoke returns the same not-found result for foreign, absent, and already-revoked rows without mutating the terminal row."
    requirement: PAT-02
    verification:
      - kind: integration
        ref: "test/sigra/api_token_test.exs#owner-constrained revoke leaves foreign and terminal rows untouched"
        status: pass
    human_judgment: false
  - id: D2
    description: "PAT creation accepts empty and configured singleton scopes and rejects malformed, duplicate, and unregistered selections at the library boundary."
    requirement: PAT-02
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/api_token_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 6min
  completed: 2026-08-12
  tasks: 1
  files: 3
status: complete
---

# Phase 244 Plan 02: PAT and Advanced JWT Truth Repair Summary

**PAT self-management now revokes only active tokens belonging to the authenticated owner, while creation validates allowed scope selections inside the library.**

## Performance

- **Duration:** 6 min
- **Completed:** 2026-08-12T22:03:51Z
- **Tasks:** 1/1
- **Files modified:** 3

## Accomplishments

- Added `Sigra.APIToken.revoke_for_user/3` and an owner-required `Sigra.Auth` facade that query token ID, owner ID, and active state together.
- Preserved the existing transactional revoke/audit path and normalized foreign, missing, and already-revoked self-service calls to `{:error, :not_found}` without additional mutation.
- Added library-bound empty/single/invalid scope contracts and a Postgres-backed ownership proof.

## Task Commits

1. **Task 1: Revoke one PAT through an owner-constrained public API** - `82e3dc4a` (RED), `541d6a34` (GREEN)

## Files Created/Modified

- `lib/sigra/api_token.ex` - owner-constrained active-token query, shared revoke transaction, and scope-selection validation.
- `lib/sigra/auth.ex` - owner-required PAT self-management facade.
- `test/sigra/api_token_test.exs` - deterministic ownership/scope contracts plus live-Postgres terminal-state coverage.

## Decisions Made

- Retained ID-only `revoke/2` as the explicit generic administrative capability; browser self-management must use the owner-required facade.
- Empty scopes are a valid configured subset; non-empty selections remain validated through `ScopeRegistry` before any persistence action.

## TDD Gate Compliance

- RED commit `82e3dc4a` captured five expected failures for the owner facade, bounded revocation outcome, empty scope, and duplicate scope contracts.
- GREEN commit `541d6a34` made the focused suite pass with 29 tests and 0 failures, including the live PostgreSQL query proof.

## Verification

`source tmp/db.env && MIX_ENV=test mix test test/sigra/api_token_test.exs --trace` passed after formatting: 29 tests, 0 failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Database query correctness] Replaced `get_by` nil comparison with an explicit active-token query**
- **Found during:** Task 1 GREEN verification
- **Issue:** Ecto rejects `revoked_at: nil` in `Repo.get_by/2`; the intended active-state predicate must use `is_nil/1`.
- **Fix:** Queried the schema with token ID, owner ID, and `is_nil(token.revoked_at)` before reusing the existing transactional revoke path.
- **Files modified:** `lib/sigra/api_token.ex`, `test/sigra/api_token_test.exs`
- **Verification:** Live PostgreSQL ownership/terminal-state test passed.
- **Committed in:** `541d6a34`

**Total deviations:** 1 auto-fixed (Rule 1 database query correctness). No scope expansion.

## Known Stubs

None.

## Threat Flags

None. The change tightens an existing persistence boundary and introduces no endpoint, file-access path, or new trust boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 03 can route generated browser PAT management to the owner-required facade; PAT-02 library boundary and real-query proof are complete.

## Self-Check: PASSED

Verified all three planned source/test files exist and both RED/GREEN commits are present in git history.
