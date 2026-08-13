---
phase: 245-opaque-app-session-core
plan: 02
subsystem: auth
tags: [plug, scope, opaque-tokens, postgres, redaction]
requires:
  - phase: 245-opaque-app-session-core
    provides: Digest-only opaque access authentication through configured host schemas.
  - phase: 243-credential-boundary-and-pipeline-foundation
    provides: Explicit credential Plug and normal-Scope boundary patterns.
provides:
  - Explicit opaque app-session Bearer authentication into the host Scope.
  - Bounded, unscoped app-session facts kept outside Scope.
affects: [246-first-party-app-session-install-and-issuance]
tech-stack:
  added: []
  patterns: [single explicit credential verifier, live-user reload, bounded private credential facts]
key-files:
  created: []
  modified: [lib/sigra/plug/fetch_app_session.ex, lib/sigra/plug/credential_auth.ex, test/sigra/plug/fetch_app_session_test.exs]
key-decisions:
  - "FetchAppSession accepts exactly one Bearer transport and invokes only Sigra.AppSession.authenticate/2."
  - "App-session facts expose only kind, credential ID, family ID, empty scopes, method, and assurance; client references and credential material remain excluded."
patterns-established:
  - "App sessions construct the host's normal Scope from a reloaded live user while carrying no authorization scopes."
requirements-completed: [APP-04, APP-05]
coverage:
  - id: D1
    description: Explicit opaque access authentication produces normal Scope and bounded private facts.
    requirement: APP-05
    verification:
      - kind: integration
        ref: "source tmp/db.env && MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/require_scopes_test.exs --trace"
        status: pass
    human_judgment: false
  - id: D2
    description: Invalid, stale, refresh-kind, revoked, and deleted-user app-session requests fail closed without credential residue.
    requirement: APP-05
    verification:
      - kind: integration
        ref: "test/sigra/plug/fetch_app_session_test.exs"
        status: pass
    human_judgment: false
metrics:
  duration: 10min
  completed: 2026-08-13
  tasks: 1
  files: 3
status: complete
---

# Phase 245 Plan 02: Explicit App-Session Activation Summary

**Opaque app access credentials now authenticate through a single explicit Bearer pipeline, reloading the live user into normal Scope while exposing only bounded, unscoped private facts.**

## Performance

- **Duration:** 10 min
- **Completed:** 2026-08-13T00:42:33Z
- **Tasks:** 1/1
- **Files modified:** 3

## Accomplishments

- Replaced the Phase 243 fail-closed placeholder with an explicit `Sigra.AppSession.authenticate/2` request path.
- Reloaded the configured host user before constructing the normal Scope and preserved existing scopes without header parsing or database work.
- Added an app-session-only private fact projection with empty scopes, credential/family identifiers, and no credential, digest, header, or client-reference leakage.

## Task Commits

1. **Task 1: Authenticate explicit app-session requests into normal Scope** - `0f374db0` (RED), `336eab3c` (GREEN)

## Files Created/Modified

- `lib/sigra/plug/fetch_app_session.ex` - Verifies exactly one opaque Bearer access credential, reloads the live user, and fails closed.
- `lib/sigra/plug/credential_auth.ex` - Adds the bounded app-session metadata allowlist while retaining PAT/JWT projection behavior.
- `test/sigra/plug/fetch_app_session_test.exs` - Proves real PostgreSQL access, stale-state failures, scope bypass, and secret redaction.

## Decisions Made

- Kept app-session verification separate from FetchBearer, PAT, JWT, cookies, and token-shape dispatch.
- Used `scopes: []` for app sessions so `RequireScopes` retains its existing fail-closed behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added the missing CredentialAuth module alias**
- **Found during:** Task 1 GREEN verification
- **Issue:** The replacement Plug invoked the helper without its module alias, causing an undefined-function failure.
- **Fix:** Added the explicit `Sigra.Plug.CredentialAuth` alias.
- **Files modified:** `lib/sigra/plug/fetch_app_session.ex`
- **Verification:** Focused 16-test cross-pipeline suite passes.
- **Committed in:** `336eab3c`

**2. [Rule 1 - Test Bug] Modeled hard-deleted host users within the referential test schema**
- **Found during:** Task 1 RED verification
- **Issue:** The representative schema's foreign keys prevent direct user deletion while family rows exist.
- **Fix:** Removed dependent representative rows before deleting the user and asserted the presented credential fails closed.
- **Files modified:** `test/sigra/plug/fetch_app_session_test.exs`
- **Verification:** Focused PostgreSQL test passes.
- **Committed in:** `0f374db0`

**Total deviations:** 2 auto-fixed Rule 1 fixes. No scope expansion.

## Issues Encountered

None remaining.

## User Setup Required

None - `tmp/db.env` provided the required PostgreSQL connection.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/require_scopes_test.exs --trace` - 16 tests, 0 failures.
- `mix format --check-formatted lib/sigra/plug/fetch_app_session.ex lib/sigra/plug/credential_auth.ex test/sigra/plug/fetch_app_session_test.exs` - passed.
- `git diff --check` - passed.

## Known Stubs

None.

## Self-Check: PASSED

- All three planned implementation and test files exist.
- RED commit `0f374db0` and GREEN commit `336eab3c` exist in git history.
