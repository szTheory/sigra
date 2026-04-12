---
phase: 12-scope-session-foundation
plan: 04
subsystem: integration-validation
tags: [golden-fixture, example-app, round-trip-test, D-14, D-15, D-16]
dependency_graph:
  requires: [12-01, 12-02, 12-03]
  provides: [D-14-verified, D-15-verified, D-16-verified, example-app-org-scope]
  affects: [phase-14-org-plugs, phase-16-org-liveviews]
tech_stack:
  added: []
  patterns: [example-app-mirror, golden-fixture-validation, end-to-end-round-trip]
key_files:
  created:
    - test/example/priv/repo/migrations/20260410125243_add_active_organization_id_to_user_sessions.exs
    - test/example/test/example_web/smoke/session_active_org_round_trip_test.exs
  modified:
    - test/example/lib/example/accounts/scope.ex
    - test/example/lib/example/accounts/user_session.ex
decisions:
  - "Golden fixture files were already fully updated by Wave 1 agents (12-02 and 12-03) -- Task 2 was a verification-only pass"
  - "Round-trip test uses Repo.update_all for setting active_organization_id since Plan 01 does not ship a setter"
metrics:
  duration_seconds: 326
  completed: "2026-04-12T04:35:26Z"
  tasks_completed: 3
  tasks_total: 3
  tests_added: 3
  files_modified: 4
---

# Phase 12 Plan 04: Integration Validation + Example App Mirror Summary

Example app mirrored with 4-field Scope defstruct and active_organization_id schema field, golden fixture validated green, D-14 end-to-end round-trip test proves write/reload/plug-survival for active_organization_id via EctoStore.fetch/2.

## Task Results

### Task 1: Mirror template changes into test/example app + add hand-written migration
**Commit:** e197198

- Updated `test/example/lib/example/accounts/scope.ex` with 4-field defstruct (user, active_organization, membership, impersonating_from), Reserved fields moduledoc, and expanded @type t
- Added `field :active_organization_id, :binary_id` to `test/example/lib/example/accounts/user_session.ex`
- Created migration at slot 20260410125243 (confirmed open between 125242 and 125244)
- `mix compile --warnings-as-errors` exits 0 (D-16 satisfied)
- All existing example tests pass

### Task 2: Rebase the golden-diff fixture
**Commit:** N/A (no changes needed)

All golden fixture files were already updated by Wave 1 agents:
- 12-02 added `TIMESTAMP_add_active_organization_id_to_user_sessions.exs` and the STDOUT.txt line
- 12-03 updated `scope.ex` and `user_session.ex` golden fixtures

Verification: `mix test --only golden` passes (2 tests, 0 failures). Phase 11 byte-identity invariant confirmed -- `git diff --stat test/fixtures/install_golden/` shows zero changes in this worktree.

### Task 3: Add D-14 end-to-end round-trip test
**Commit:** f51e4d0

Created `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs` with 3 tests:
1. **DB round-trip**: Writes org_id via `Repo.update_all`, reloads via `EctoStore.fetch(hashed_token, repo: Example.Repo, session_schema: UserSession)`, asserts `reloaded.active_organization_id == org_id`
2. **Default-nil**: Fresh session has `active_organization_id == nil` after fetch
3. **Plug pipeline survival**: `UserAuth.log_in_user/2` works, `Plug.Conn.get_session(:user_token)` returns binary, `active_organization_id` is NOT in cookie session

All 3 tests pass. Full example suite passes with no regressions.

## Key Confirmations

| Requirement | Status | Evidence |
|-------------|--------|----------|
| D-14 (DB round-trip) | VERIFIED | Test 1 proves write/persist/reload via EctoStore.fetch/2 |
| D-14 (Plug survival) | VERIFIED | Test 3 proves login works, cookie unchanged |
| D-14 (Cookie isolation) | VERIFIED | Test 3 refutes active_organization_id in cookie session |
| D-15 (Phase 11 byte-identity) | VERIFIED | Golden test green, zero changes to Phase 11 fixture files |
| D-16 (Warnings-as-errors) | VERIFIED | mix compile --warnings-as-errors exits 0 in example app |
| ORG-SCOPE-01 | COMPLETE | Scope module compiles with all 4 fields |
| ORG-SCOPE-02 | COMPLETE | UserSession schema + migration + round-trip test all verified |

## EctoStore Signature Reference (for Phase 14)

The round-trip test uses: `EctoStore.fetch(hashed_token, repo: Example.Repo, session_schema: UserSession)` where `hashed_token` is computed via `Sigra.Token.hash_token(raw_bytes)` from the base64-decoded raw cookie token.

## FetchSession Plug Status

**NOT touched.** Per D-14 clarified, `active_organization_id` lives on the DB row only. Phase 14 will revisit cookie hydration when LoadActiveOrganization plug ships.

## Deviations from Plan

### Task 2 was verification-only (no file changes)

**Found during:** Task 2
**Issue:** Plan expected Task 2 to update golden fixture files (scope.ex, user_session.ex, STDOUT.txt, new migration file). All 4 changes were already applied by Wave 1 agents (12-02 for STDOUT.txt + migration file, 12-03 for scope.ex + user_session.ex).
**Resolution:** Ran `mix test --only golden` to confirm green, verified Phase 11 byte-identity via `git diff --stat`. No file changes or commit needed.
**Impact:** None -- the golden test passes, which is the actual requirement.

## Self-Check: PASSED
