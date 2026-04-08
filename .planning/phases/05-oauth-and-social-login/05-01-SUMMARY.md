---
phase: 05-oauth-and-social-login
plan: 01
subsystem: auth
tags: [oauth, assent, oidc, social-login, identity, nimble-options]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: NimbleOptions config pattern, error types with safe_message/1, library struct pattern
  - phase: 04-session-management-and-security-baseline
    provides: Session struct pattern (from_schema/to_params), Code.ensure_loaded? optional dep pattern
provides:
  - Sigra.Error.OAuthError exception with 7 error codes and safe_message mappings
  - Sigra.Config oauth section with NimbleOptions validation (enabled, providers, session_type, link_confirmation, trust_provider_email)
  - Sigra.Config.oauth_enabled?/1 and oauth_providers/1 convenience functions
  - Sigra.Identity struct with from_schema/1 and to_params/1 (provider normalization)
  - Strategy wrappers for Google, GitHub, Apple, Facebook, and Generic fallback
  - Sigra.OAuth.Strategies.resolve/2 provider-to-module resolver
affects: [05-02, 05-03, 05-04, 05-05]

# Tech tracking
tech-stack:
  added: [assent ~> 0.3 (optional)]
  patterns: [strategy wrapper pattern with normalize_user/ensure_assent!, provider resolver pattern]

key-files:
  created:
    - lib/sigra/identity.ex
    - lib/sigra/oauth/strategies.ex
    - lib/sigra/oauth/strategies/google.ex
    - lib/sigra/oauth/strategies/github.ex
    - lib/sigra/oauth/strategies/apple.ex
    - lib/sigra/oauth/strategies/facebook.ex
    - lib/sigra/oauth/strategies/generic.ex
    - test/sigra/identity_test.exs
    - test/sigra/oauth/config_test.exs
    - test/sigra/oauth/strategies_test.exs
  modified:
    - lib/sigra/error.ex
    - lib/sigra/config.ex
    - mix.exs

key-decisions:
  - "Added assent as optional dep in mix.exs (required for strategy wrappers to compile in test)"
  - "Strategy wrappers expose normalize_user/1 and ensure_assent!/0 as public for testability"

patterns-established:
  - "Strategy wrapper pattern: each provider has authorize_url/callback/default_scopes/normalize_user/ensure_assent!"
  - "Provider resolver pattern: resolve/2 maps known atoms to modules, falls back to Generic with :strategy key"
  - "Facebook email_verified forced false: downstream code must honor this for email confirmation"

requirements-completed: [OAUTH-01, OAUTH-02, OAUTH-03, OAUTH-08]

# Metrics
duration: 6min
completed: 2026-04-08
---

# Phase 5 Plan 1: OAuth Foundation Types Summary

**OAuthError exception, oauth config section with NimbleOptions validation, Identity struct with provider normalization, and 5 Assent strategy wrappers (Google/GitHub/Apple/Facebook/Generic)**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-08T13:56:46Z
- **Completed:** 2026-04-08T14:03:05Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments
- OAuthError exception with 7 error codes and full safe_message/1 coverage for enumeration-safe OAuth error display
- Config oauth: section with NimbleOptions validation covering enabled kill switch, providers, session_type, link_confirmation, and trust_provider_email
- Identity struct mapping all D-25 fields with from_schema/1 and to_params/1 including lowercase provider normalization
- Five strategy wrappers normalizing Assent responses to consistent map shape with sub/email/name/picture/email_verified/raw keys
- Facebook forces email_verified=false (Pitfall 1), Apple preserves nil name on subsequent auths (Pitfall 2)
- Strategy resolver maps known providers to wrappers, unknown providers with :strategy key to Generic fallback

## Task Commits

Each task was committed atomically:

1. **Task 1: OAuthError exception, Config oauth section, Identity struct** - `45094ba` (feat)
2. **Task 2: Assent strategy wrappers for Tier 1-2 providers + Generic fallback** - `1f65a77` (feat)

_Note: TDD tasks had RED (verify fail) + GREEN (implement + pass) phases combined into single commits._

## Files Created/Modified
- `lib/sigra/error.ex` - Added OAuthError defexception and 7 safe_message/1 clauses
- `lib/sigra/config.ex` - Added oauth: NimbleOptions section, oauth_enabled?/1, oauth_providers/1
- `lib/sigra/identity.ex` - New Identity struct with from_schema/1 and to_params/1
- `lib/sigra/oauth/strategies.ex` - Provider resolver with resolve/2 and named_strategies/0
- `lib/sigra/oauth/strategies/google.ex` - Google OIDC wrapper (openid, email, profile scopes)
- `lib/sigra/oauth/strategies/github.ex` - GitHub OAuth2 wrapper (user:email scope, id fallback)
- `lib/sigra/oauth/strategies/apple.ex` - Apple OIDC wrapper (name, email scopes, nil name handling)
- `lib/sigra/oauth/strategies/facebook.ex` - Facebook OAuth2 wrapper (email_verified always false)
- `lib/sigra/oauth/strategies/generic.ex` - Generic fallback delegating to any Assent strategy
- `mix.exs` - Added assent ~> 0.3 as optional dependency
- `test/sigra/identity_test.exs` - 14 tests for Identity struct, from_schema, to_params
- `test/sigra/oauth/config_test.exs` - 11 tests for oauth config validation
- `test/sigra/oauth/strategies_test.exs` - 20 tests for resolve, normalize_user, default_scopes

## Decisions Made
- Made normalize_user/1 and ensure_assent!/0 public on each strategy wrapper for direct testability without mocking Assent HTTP calls
- Added assent ~> 0.3 as optional dep in mix.exs so strategy modules can reference Assent types at compile time; Code.ensure_loaded? gate still protects runtime usage
- Combined TDD RED+GREEN into single commits per task (tests written first, verified failing, then implementation added)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added assent as optional dependency in mix.exs**
- **Found during:** Task 2 (Strategy wrappers)
- **Issue:** Strategy wrapper modules reference Assent.Strategy.* modules which require assent in deps to compile
- **Fix:** Added `{:assent, "~> 0.3", optional: true}` to mix.exs deps
- **Files modified:** mix.exs, mix.lock
- **Verification:** `mix compile --warnings-as-errors` succeeds
- **Committed in:** 1f65a77 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for compilation. Assent was always intended as a dependency per CLAUDE.md tech stack; adding it as optional follows the established pattern for Hammer/Oban/bcrypt.

## Issues Encountered
None.

## Threat Mitigations Applied

| Threat ID | Mitigation | Verified |
|-----------|-----------|----------|
| T-05-01 | All wrappers normalize provider UID to string via normalize_user | Yes - tested |
| T-05-02 | NimbleOptions validates all oauth config types at startup | Yes - tested |
| T-05-03 | safe_message/1 returns generic strings; OAuthError details never exposed | Yes - tested |
| T-05-04 | Code.ensure_loaded?(Assent) gate on all strategy entry points | Yes - tested |
| T-05-05 | Facebook strategy forces email_verified=false | Yes - tested |

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Identity struct and strategy wrappers ready for Plan 02 (OAuth flow orchestrator)
- Config oauth: section ready for Plan 03 (OAuth controller and routes)
- OAuthError types ready for error handling in callback processing

---
*Phase: 05-oauth-and-social-login*
*Completed: 2026-04-08*
