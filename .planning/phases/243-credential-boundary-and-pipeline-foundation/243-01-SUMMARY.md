---
phase: 243-credential-boundary-and-pipeline-foundation
plan: 01
subsystem: auth
tags: [plug, personal-access-token, scope, authorization, mox]
requires: []
provides:
  - "Explicit PAT Plug that loads the live user into the host Scope"
  - "Bounded verifier-derived credential facts in conn.private[:sigra_auth]"
  - "Fail-closed scope authorization for verified PAT and JWT facts"
affects: [243-02, 243-03, 243-04, API-01]
tech-stack:
  added: []
  patterns:
    - "Credential metadata stays separate from identity Scope state"
    - "Scoped authorization reads only server-produced private facts"
key-files:
  created:
    - lib/sigra/plug/credential_auth.ex
    - lib/sigra/plug/fetch_api_token.ex
    - test/sigra/plug/fetch_api_token_test.exs
  modified:
    - lib/sigra/plug/require_scopes.ex
    - test/sigra/plug/require_scopes_test.exs
key-decisions:
  - "PAT verification is explicit and uses APIToken.verify/2 as the only verifier."
  - "Authorization scopes are trusted only when supplied by verified PAT or JWT private facts."
patterns-established:
  - "CredentialAuth builds struct Scopes canonically and preserves legacy new/1 compatibility."
  - "Fetch plugs assign nil on authentication failure; route gates own error responses."
requirements-completed: [API-01]
coverage:
  - id: D1
    description: "Explicit PAT authentication produces a live-user Scope, bounded facts, and fail-closed scope enforcement."
    requirement: API-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/require_scopes_test.exs --trace"
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-08-12
status: complete
---

# Phase 243 Plan 01: PAT Pipeline and Trusted Scope Boundary Summary

**Explicit PAT authentication now verifies one credential, reloads the current user into the host Scope, and authorizes scopes only from bounded private verifier facts.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-12T19:33:00Z
- **Completed:** 2026-08-12T19:36:20Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments

- Added `FetchAPIToken`, an explicit PAT pipeline that accepts only one trimmed Bearer header and calls `Sigra.APIToken.verify/2`.
- Added `CredentialAuth` to reload the live user, construct a canonical host Scope, and record an exact credential-facts allowlist without raw credentials.
- Reworked `RequireScopes` to fail closed unless trusted PAT/JWT facts contain server-selected list scopes, preserving all/any/wildcard and error-handler behavior.

## Task Commits

1. **Task 1: Trace one PAT through verifier, live user, normal Scope, and bounded credential facts** - `2a838e15` (RED), `43fa6195` (GREEN)
2. **Task 2: Enforce scopes solely from trusted credential facts** - `816aed04` (RED), `75d29a73` (GREEN)

## Files Created/Modified

- `lib/sigra/plug/credential_auth.ex` - private identity-to-Scope and credential-facts seam.
- `lib/sigra/plug/fetch_api_token.ex` - public explicit PAT Plug.
- `lib/sigra/plug/require_scopes.ex` - trusted private-facts enforcement.
- `test/sigra/plug/fetch_api_token_test.exs` - end-to-end Mox PAT tracer contract.
- `test/sigra/plug/require_scopes_test.exs` - fail-closed trusted scope matrix.

## Decisions Made

- PAT paths call only `Sigra.APIToken.verify/2`, then resolve the current user with the configured Repo.
- `conn.private[:sigra_auth]` holds the exact bounded facts map; identity Scope fields never grant route scopes.
- Only `:personal_access_token` and `:jwt` facts with list-valued scopes may satisfy `RequireScopes`.

## TDD Gate Compliance

- RED commits `2a838e15` and `816aed04` recorded behavior failures before production implementation.
- GREEN commits `43fa6195` and `75d29a73` made both deterministic contract suites pass.

## Verification

`MIX_ENV=test mix test test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/require_scopes_test.exs --trace` passed: 8 tests, 0 failures.

The test helper emitted its documented PostgreSQL connection-refused noise, but these focused Mox/Plug contracts completed successfully without database access.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

`state.advance-plan` could not parse the pre-existing `Plan: —` placeholder in `STATE.md`; the state was normalized to Plan 02 of 05 after the SDK had already recorded the summary-derived progress and metrics.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The PAT pipeline and trusted scope boundary are ready for the JWT/app-session explicit-pipeline work in Plan 243-02.

## Self-Check: PASSED

Verified all five changed production/test files exist and all four RED/GREEN commits are present in git history.
