---
phase: 243-credential-boundary-and-pipeline-foundation
plan: 03
subsystem: auth
tags: [plug, browser-session, scope, credential-boundary, mox]
requires:
  - "CredentialAuth canonical Scope builder and bounded legacy adapter from 243-01"
provides:
  - "Browser session authentication reloads the configured live user before assigning Scope"
  - "Generated struct and existing non-struct new/1 Scope modules remain compatible"
  - "Deleted browser-session users fail closed without credential facts"
affects: [243-04, API-01]
tech-stack:
  added: []
  patterns:
    - "Browser identity uses CredentialAuth.build_scope/2 without credential metadata"
    - "Scope modules are detected through their generated __struct__/0 contract before legacy fallback"
key-files:
  created: []
  modified:
    - lib/sigra/plug/fetch_session.ex
    - lib/sigra/plug/credential_auth.ex
    - test/sigra/plug/fetch_session_test.exs
key-decisions:
  - "FetchSession reloads config.user_schema by session user_id only after session validation succeeds."
  - "Browser sessions retain sigra_session private state but never write sigra_auth credential facts."
  - "Generated Scope structs use Sigra.Scope.build/3; only non-struct modules fall back to new/1."
requirements-completed: [API-01]
coverage:
  - id: D1
    description: "Browser sessions construct a normal Scope from a freshly loaded current user across generated and legacy host Scope forms."
    requirement: API-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/plug/fetch_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/require_scopes_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deleted browser-session users remain unauthenticated and receive no scoped credential facts."
    requirement: API-01
    verification:
      - kind: unit
        ref: "test/sigra/plug/fetch_session_test.exs#assigns nil without authenticated private state when the session user was deleted"
        status: pass
    human_judgment: false
metrics:
  duration: 4min
  completed: 2026-08-12
  tasks: 1
  files: 3
status: complete
---

# Phase 243 Plan 03: Browser Session Scope Compatibility Summary

**Browser sessions now reload the live user into canonical generated Scopes while retaining bounded legacy `new/1` compatibility and rejecting deleted users.**

## Accomplishments

- Updated `FetchSession` to resolve `config.user_schema` through the configured Repo before scope construction.
- Preserved normal session lifecycle behavior while preventing missing users from receiving Scope, session-private state, or credential facts.
- Added deterministic coverage for generated struct Scope construction, legacy Scope construction with the exact loaded user, and the deleted-user boundary.

## Task Commits

1. **Task 1: Load full browser-session users through the compatibility adapter** — `b3cfd35d` (RED), `aabc263a` (GREEN)

## Files Created/Modified

- `lib/sigra/plug/fetch_session.ex` — reloads live users and builds identity-only browser Scope state.
- `lib/sigra/plug/credential_auth.ex` — reliably recognizes generated struct Scope modules before its bounded legacy fallback.
- `test/sigra/plug/fetch_session_test.exs` — verifies full-user, generated/legacy, deleted-user, lifecycle, cookie, and private-state behavior.

## Decisions Made

- Browser session validation precedes the one live-user Repo lookup; activity and private session state are installed only for a live user.
- `sigra_auth` remains absent from every browser-session outcome, so browser identity cannot imply delegated scope authority.

## TDD Gate Compliance

- RED commit `b3cfd35d` added failing generated-struct, legacy full-user, and deleted-user contracts.
- GREEN commit `aabc263a` reloads users and passes the focused compatibility suite.

## Verification

`MIX_ENV=test mix test test/sigra/plug/fetch_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/require_scopes_test.exs --trace` passed: 25 tests, 0 failures.

Focused test startup emitted the documented local PostgreSQL connection-refused noise; all selected Mox/Plug contracts passed without database access.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Compatibility Bug] Detect generated Scope structs without assuming they are already loaded**
- **Found during:** Task 1 GREEN
- **Issue:** The adapter classified an unloaded generated-like struct Scope as legacy, bypassing canonical `Sigra.Scope.build/3` construction.
- **Fix:** Detect struct modules by invoking the generated `__struct__/0` contract and rescue only a missing function for the existing legacy `new/1` path.
- **Files modified:** `lib/sigra/plug/credential_auth.ex`, `test/sigra/plug/fetch_session_test.exs`
- **Verification:** Generated and legacy Scope tests pass in the focused suite.
- **Commit:** `aabc263a`

**Total deviations:** 1 auto-fixed (Rule 1 compatibility bug). **Impact:** Required to preserve the locked generated-struct/legacy-module compatibility boundary; no scope expansion.

## Known Stubs

None.

## Self-Check: PASSED

Verified all three modified source/test files exist and both TDD commits are present in git history.
