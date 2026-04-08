---
phase: 05-oauth-and-social-login
plan: 02
subsystem: auth
tags: [oauth, orchestrator, callback, hmac-state, account-linking, telemetry, testing]

# Dependency graph
requires:
  - phase: 05-oauth-and-social-login
    plan: 01
    provides: Identity struct, OAuthError, Config oauth section, Strategies.resolve/2, strategy wrappers
provides:
  - Sigra.OAuth orchestrator with authorize_url/3, handle_callback/4, get_tokens/2, link_provider/4, unlink_provider/4
  - Sigra.OAuth.Callback with process_callback/4 handling 5 account scenarios
  - Auth module OAuth extensions (register_oauth, login_oauth, link_provider, unlink_provider)
  - 7 OAuth telemetry events with oauth_events/0 accessor
  - Testing helpers (mock_oauth_callback, create_identity, oauth_user_fixture)
affects: [05-03, 05-04, 05-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [HMAC-signed OAuth state via Sigra.Token, Ecto.Multi for race-safe registration, maybe_put for nil-safe field updates]

key-files:
  created:
    - lib/sigra/oauth.ex
    - lib/sigra/oauth/callback.ex
    - test/sigra/oauth/oauth_test.exs
    - test/sigra/oauth/callback_test.exs
    - test/sigra/oauth/auth_integration_test.exs
    - test/support/oauth_helpers.ex
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/telemetry.ex
    - lib/sigra/testing.ex

key-decisions:
  - "HMAC state uses Sigra.Token.generate with purpose sigra-oauth-state and 15-min TTL"
  - "Callback processor uses Ecto.Multi for race-safe user+identity registration"
  - "Auth module delegates to OAuth modules rather than duplicating logic"
  - "Mock strategy pattern: tests use :strategy key in provider config to bypass real Assent HTTP calls"

patterns-established:
  - "OAuth orchestrator pattern: authorize_url generates HMAC state, handle_callback verifies then delegates"
  - "Account routing in Callback: identity lookup first, then email match, then new registration"
  - "maybe_put helper for nil-safe identity field updates (Apple nil-name on re-auth)"
  - "Mock repo per scenario: ExistingIdentity, EmailMismatch, EmailMatch, NewUser in test/support"

requirements-completed: [OAUTH-04, OAUTH-05, OAUTH-06, OAUTH-07, OAUTH-08]

# Metrics
duration: 24min
completed: 2026-04-08
---

# Phase 5 Plan 2: OAuth Orchestrator and Auth Integration Summary

**OAuth orchestrator with HMAC-signed state, callback processor handling 5 account scenarios (register/login/link-confirm/no-email/UID-conflict), Auth module extensions, 7 telemetry events, and 3 testing helpers**

## Performance

- **Duration:** 24 min
- **Started:** 2026-04-08T14:05:36Z
- **Completed:** 2026-04-08T14:29:33Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Sigra.OAuth orchestrator with authorize_url/3 that generates HMAC-signed state (sigra-oauth-state purpose, 15-min TTL) replacing Assent's default state, preserving PKCE code_verifier in session params
- Sigra.OAuth.Callback.process_callback/4 routes to correct action for all 5 scenarios: existing identity login with field update, new user registration via Ecto.Multi, email-match link confirmation, no-email error, UID/email cross-account conflict block
- get_tokens/2 returns current tokens or detects expiry; refresh stub logs warning (full refresh requires Assent HTTP client integration in Plan 03)
- link_provider/4 checks for existing identity, creates new identity record with telemetry event
- unlink_provider/4 enforces D-03 (last provider block when no password) via Ecto.Query count
- Auth module extended with register_oauth/4, login_oauth/4, link_provider/4, unlink_provider/4 as clean delegation layer
- 7 OAuth telemetry events added to catalog with oauth_events/0 accessor function
- 3 Testing helpers: mock_oauth_callback/1, create_identity/1, oauth_user_fixture/1
- Apple nil-name handling via maybe_put helper (only updates non-nil fields on re-auth)
- D-42: auto-confirm email when trust_provider_email config is true and provider reports email_verified
- D-48: session metadata includes auth_method: :oauth and provider atom

## Task Commits

1. **Task 1: OAuth orchestrator and Callback processor** - `9b692c9` (feat)
2. **Task 2: Auth OAuth extensions, Telemetry events, Testing helpers** - `f8f0ded` (feat)

## Files Created/Modified

- `lib/sigra/oauth.ex` - OAuth orchestrator: authorize_url, handle_callback, get_tokens, link_provider, unlink_provider
- `lib/sigra/oauth/callback.ex` - Callback processor: process_callback with 5 account routing scenarios
- `lib/sigra/auth.ex` - Added register_oauth, login_oauth, link_provider, unlink_provider delegations
- `lib/sigra/telemetry.ex` - Added 7 OAuth events to catalog, @oauth_events attribute, oauth_events/0 function
- `lib/sigra/testing.ex` - Added mock_oauth_callback/1, create_identity/1, oauth_user_fixture/1
- `test/sigra/oauth/oauth_test.exs` - 17 tests for OAuth orchestrator (authorize_url, handle_callback, link/unlink, get_tokens)
- `test/sigra/oauth/callback_test.exs` - 11 tests for Callback processor (all 5 scenarios + Apple nil-name)
- `test/sigra/oauth/auth_integration_test.exs` - 17 tests for Auth delegation, telemetry firing, testing helpers
- `test/support/oauth_helpers.ex` - Shared mock schemas, mock repos (MockRepo + 4 scenario-specific CallbackRepos)

## Decisions Made

- HMAC state compares stored session value against URL param before Token.verify, providing double-check against CSRF
- Mock strategy pattern using :strategy config key lets tests bypass Assent's HTTP calls entirely (tests run without network)
- Auth module delegates rather than re-implementing, keeping OAuth logic centralized in Sigra.OAuth modules
- Token refresh is stubbed with a warning log -- full refresh requires Assent HTTP integration which belongs in the controller layer (Plan 03)

## Deviations from Plan

None -- plan executed exactly as written.

## Threat Mitigations Applied

| Threat ID | Mitigation | Verified |
|-----------|-----------|----------|
| T-05-06 | HMAC-signed state with 15-min TTL, state_mismatch error on invalid | Yes - 3 tests |
| T-05-07 | Email-match linking returns link_confirmation_required, never auto-links | Yes - 1 test |
| T-05-08 | UID/email cross-account returns email_mismatch error with :error log | Yes - 1 test |
| T-05-09 | Identity lookup by (provider, provider_uid) only, never email alone | Yes - code review |
| T-05-11 | Generic user-facing messages via OAuthError, detailed Logger.error | Yes - code review |
| T-05-13 | Facebook email_verified=false flows through to unconfirmed registration | Yes - 1 test |
| T-05-14 | Ecto.Multi wraps user+identity insert for race condition safety | Yes - 3 tests |

## Self-Check: PASSED

- All 9 files verified present on disk
- Both commits (9b692c9, f8f0ded) verified in git log
- All acceptance criteria patterns found in source files
- 76 tests pass with 0 failures
- mix compile --warnings-as-errors succeeds
