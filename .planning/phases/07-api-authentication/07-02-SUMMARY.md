---
phase: 07-api-authentication
plan: 02
subsystem: auth
tags: [jwt, joken, refresh-tokens, token-rotation, reuse-detection]

requires:
  - phase: 07-01
    provides: "API token infrastructure, config extensions (jwt: section), telemetry JWT events"
provides:
  - "JWT access token generation and verification via Joken"
  - "ClaimsBuilder behaviour for custom JWT claims"
  - "Signer module with HS256 key derivation and RS256/ES256 PEM support"
  - "Refresh token rotation with family-based reuse detection"
  - "Epoch-based token invalidation on password change"
affects: [07-03, 07-04]

tech-stack:
  added: [joken ~> 2.6 (optional)]
  patterns: [family-based-refresh-rotation, epoch-check-per-request, joken-optional-guard]

key-files:
  created:
    - lib/sigra/jwt.ex
    - lib/sigra/jwt/claims_builder.ex
    - lib/sigra/jwt/signer.ex
    - lib/sigra/jwt/refresh_token.ex
    - test/sigra/jwt_test.exs
    - test/sigra/jwt/refresh_token_test.exs
    - test/sigra/jwt/signer_test.exs
    - test/support/test_user.ex
    - test/support/test_user_token.ex
  modified:
    - mix.exs
    - lib/sigra/config.ex

key-decisions:
  - "Used Joken.verify/2 (signature only) + manual exp check rather than verify_and_validate, for explicit control over expiry error reporting"
  - "Stored refresh token metadata (family_id, scopes, superseded_at) as JSON in sent_to field of user_tokens table rather than adding new columns"
  - "Added secret_key_base field to Sigra.Config struct for JWT HS256 key derivation"

patterns-established:
  - "Joken optional guard: all JWT modules call Signer.ensure_joken!() before any Joken API usage"
  - "Family-based reuse detection: superseded refresh token triggers revoke_family for entire token chain"
  - "Epoch claim: every JWT verify checks user.token_epoch against claim to catch password changes"

requirements-completed: [API-05]

duration: 10min
completed: 2026-04-08
---

# Phase 7 Plan 02: JWT Support Summary

**JWT access tokens via Joken with HMAC-SHA256 key derivation, ClaimsBuilder behaviour for custom claims, and refresh token rotation with Auth0-style family-based reuse detection**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-08T23:39:28Z
- **Completed:** 2026-04-08T23:49:57Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- JWT access token generation with standard claims (sub, iat, exp, jti, iss, scopes, epoch) and custom claims via ClaimsBuilder behaviour
- Token verification with signature check, expiry validation, and epoch-based invalidation (catches password change, account deletion)
- Refresh token rotation with family tracking -- reuse of superseded token revokes entire family (Auth0 stolen-token pattern)
- Joken added as optional dependency with runtime guard ensuring clear error message if missing

## Task Commits

Each task was committed atomically:

1. **Task 1: Joken dependency, ClaimsBuilder behaviour, Signer module** - `8c79f0c` (feat)
2. **Task 2: JWT module and RefreshToken with family-based reuse detection** - `2d00c6e` (feat)

## Files Created/Modified

- `mix.exs` - Added {:joken, "~> 2.6", optional: true}
- `lib/sigra/config.ex` - Added secret_key_base field to Config struct and NimbleOptions schema
- `lib/sigra/jwt.ex` - Public API: generate_tokens, verify_access, refresh, revoke_refresh, revoke_all_refresh
- `lib/sigra/jwt/claims_builder.ex` - Behaviour with extra_claims/1 callback for custom JWT claims
- `lib/sigra/jwt/signer.ex` - HS256 key derivation from secret_key_base, RS256/ES256 PEM loading, Joken availability guard
- `lib/sigra/jwt/refresh_token.ex` - Opaque refresh tokens with family-based rotation and reuse detection
- `test/sigra/jwt_test.exs` - 15 tests: token generation, verification, epoch check, refresh, revoke
- `test/sigra/jwt/refresh_token_test.exs` - 5 tests: create, rotate, reuse detection, family revoke, user revoke
- `test/sigra/jwt/signer_test.exs` - 5 tests: HS256, RS256, ensure_joken, key derivation
- `test/support/test_user.ex` - Minimal user struct for testing
- `test/support/test_user_token.ex` - Minimal user token Ecto schema for testing

## Decisions Made

- **Joken API usage:** Used `Joken.verify/2` for signature-only verification, then manual `exp` check. This gives explicit control over error types (`:token_expired` vs `:invalid_token`) rather than relying on Joken's built-in validation which requires a claims config module.
- **Refresh token storage:** Stored metadata (family_id, scopes, superseded_at) as JSON in the existing `sent_to` field of user_tokens table. This avoids requiring a migration to add new columns and reuses the existing token infrastructure.
- **Config extension:** Added `secret_key_base` as a top-level field on `Sigra.Config` (not nested under jwt:) since it may be used by other subsystems for token signing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Joken API usage**
- **Found during:** Task 2 (JWT module implementation)
- **Issue:** Plan suggested `Joken.encode_and_sign(%{}, signer, claims)` but correct Joken 2.6 API is `Joken.generate_and_sign(%{}, claims, signer)` and `Joken.verify/2` for signature-only verification
- **Fix:** Used correct Joken API calls verified against actual library behavior
- **Files modified:** lib/sigra/jwt.ex
- **Committed in:** 2d00c6e

**2. [Rule 1 - Bug] Fixed struct construction in rotate**
- **Found during:** Task 2 (RefreshToken implementation)
- **Issue:** `struct!(%{__struct__: config.user_schema}, %{id: ...})` failed because TestUser defstruct doesn't have all required keys
- **Fix:** Used simple `%{id: token_record.user_id}` map instead since only the id is needed for token creation
- **Files modified:** lib/sigra/jwt/refresh_token.ex
- **Committed in:** 2d00c6e

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for correct Joken API usage and runtime compatibility. No scope creep.

## Issues Encountered

None beyond the auto-fixed API issues above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- JWT infrastructure complete, ready for dual-mode auth plug (07-03)
- Bearer token path can now use either API tokens (07-01) or JWT access tokens (07-02)
- Refresh token rotation provides secure long-lived API access

## Self-Check: PASSED

All 11 files verified present. Both commits (8c79f0c, 2d00c6e) verified in git log. 25 tests passing.

---
*Phase: 07-api-authentication*
*Completed: 2026-04-08*
