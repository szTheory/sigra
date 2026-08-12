---
phase: 243-credential-boundary-and-pipeline-foundation
plan: 02
subsystem: auth
tags: [plug, jwt, app-session, credential-boundary, mox]
requires:
  - "Explicit PAT and CredentialAuth normal-Scope seam from 243-01"
provides:
  - "Explicit JWT Plug that reloads a live user and projects bounded facts"
  - "Fail-closed public FetchAppSession Plug foundation"
affects: [243-03, 243-04, API-01]
tech-stack:
  added: []
  patterns:
    - "Each host-selected credential Plug invokes only its named verifier"
    - "Unimplemented app-session selection preserves a nil Scope and no credential facts"
key-files:
  created:
    - lib/sigra/plug/fetch_jwt.ex
    - lib/sigra/plug/fetch_app_session.ex
    - test/sigra/plug/fetch_jwt_test.exs
    - test/sigra/plug/fetch_app_session_test.exs
  modified: []
key-decisions:
  - "FetchJWT calls only Sigra.JWT.verify_access/2 and reloads its string subject through the configured Repo."
  - "JWT facts are the exact CredentialAuth allowlist, with list-validated verified scopes and empty assurance."
  - "FetchAppSession is intentionally inert and fail closed until Phase 245 supplies its verifier and storage contract."
metrics:
  duration: 8min
  completed: 2026-08-12
  tasks: 2
  files: 4
status: complete
---

# Phase 243 Plan 02: Explicit JWT and Fail-Closed App Session Summary

**Explicit JWT authentication now uses the normal-Scope boundary, while the public app-session seam authenticates nothing until its Phase 245 verifier exists.**

## Accomplishments

- Added `FetchJWT`, which accepts exactly one Bearer JWT, invokes only `Sigra.JWT.verify_access/2`, reloads the configured host user, and writes bounded verifier-derived facts through `CredentialAuth`.
- Added `FetchAppSession` as a public, options-compatible Plug that returns an existing Scope unchanged and otherwise assigns nil with no credential state.
- Added focused Mox/Plug contracts for string JWT subjects, deleted users, metadata and raw-token absence, Scope skips, and app-session fail-closed behavior.

## Task Commits

1. **Task 1: Add explicit JWT authentication on the proven normal-Scope seam** — `588c82d2` (RED), `d140656a` (GREEN)
2. **Task 2: Publish FetchAppSession as a fail-closed Plug foundation** — `edfad6f9` (RED), `e31d59b6` (GREEN)

## Verification

- `MIX_ENV=test mix test test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_api_token_test.exs --trace` — passed, 6 tests / 0 failures.
- `MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_jwt_test.exs --trace` — passed, 6 tests / 0 failures.
- `MIX_ENV=test mix test test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/require_scopes_test.exs --trace` — passed, 14 tests / 0 failures.

Focused test startup emitted the documented local PostgreSQL connection-refused noise; all selected Mox/Plug contracts executed and passed without database access. The full `mix ci` phase gate was not run because the required local PostgreSQL service is unavailable, per the phase validation contract.

## TDD Gate Compliance

- RED commits `588c82d2` and `edfad6f9` captured the missing public Plug contracts before production code existed.
- GREEN commits `d140656a` and `e31d59b6` made each task's focused contract suite pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Bug] Use a raw Cookie request header in the app-session negative test**
- **Found during:** Task 2 RED
- **Issue:** `Plug.Conn.put_req_cookie/3` is not a public Plug API, so the initial test could not reach the intended missing-module failure.
- **Fix:** Replaced it with a `cookie` request header, preserving the no-parsing/fail-closed assertion.
- **Files modified:** `test/sigra/plug/fetch_app_session_test.exs`
- **Verification:** RED test then failed only because `FetchAppSession` did not yet exist; GREEN suite passed.
- **Commit:** `edfad6f9`

**Total deviations:** 1 auto-fixed (Rule 1 test bug). **Impact:** No production-scope change.

## Known Stubs

None. `FetchAppSession` is deliberately fail closed by the phase contract and does not prevent Plan 02's boundary goal from being achieved.

## Self-Check: PASSED

All four planned source/test files exist, and all four RED/GREEN commits are present in git history.
