---
phase: 07-api-authentication
verified: 2026-04-09T03:30:00Z
status: passed
score: 5/5
overrides_applied: 0
---

# Phase 7: API Authentication Verification Report

**Phase Goal:** API clients can authenticate via bearer tokens or personal access tokens; the same `current_scope` shape is produced for both session and bearer auth paths; headless mode works without any UI
**Verified:** 2026-04-09T03:30:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | API client can authenticate via `Authorization: Bearer <token>` header and receives the same `current_scope` as a session-authenticated browser user | VERIFIED | `FetchBearer` plug extracts bearer token, auto-detects opaque vs JWT, assigns `current_scope` with `auth_method`, `token_scopes`, `token_id` -- same shape as session auth. `APIToken.verify/2` and `JWT.verify_access/2` both wired in `fetch_bearer.ex:97,109`. 15 FetchBearer tests pass. |
| 2 | User can create an API key with a human-readable prefix (`myapp_live_<random>`); the raw key is shown exactly once at creation and is never retrievable again; it is stored as a SHA-256 hash | VERIFIED | `APIToken.create/3` builds `raw_key = prefix <> raw_random` (line 82), stores `Token.hash_token(raw_key)` as SHA-256 (line 83). Prefix defaults to `{otp_app}_sk_` (line 365). Raw key returned only from `create/3`; `verify/2` returns token struct without raw key. 66 APIToken tests pass. |
| 3 | Personal access tokens can be scoped and given an expiration; they appear in a listing; any token can be revoked individually | VERIFIED | `create/3` accepts `scopes` (validated via `ScopeRegistry`) and `expires_at`. `list_active/3` provides cursor-based pagination. `revoke/2` sets `revoked_at`. `revoke_all/2` bulk revokes. `can?/2` checks AND/OR scope logic. All functions present with real DB queries in `api_token.ex`. |
| 4 | JWT support works for stateless API use cases where instant revocation is not required; it is opt-in, not the default | VERIFIED | `config.ex` has `jwt: [enabled: [default: false]]` (line 487). `JWT.generate_tokens/3` and `verify_access/2` both call `Signer.ensure_joken!()` guarding Joken availability. `RefreshToken` implements family-based reuse detection. Joken is `optional: true` in `mix.exs:47`. 25 JWT tests pass. |
| 5 | All auth logic works in headless mode with no LiveView or HTML components present | VERIFIED | Core library modules (`api_token.ex`, `jwt.ex`, `fetch_bearer.ex`, `require_scopes.ex`) have zero LiveView dependencies. Install task supports `--no-live` (line 18). Generator produces JSON controllers (`APITokenController`, `TokenController`) that work without LiveView. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/api_token.ex` | API token CRUD | VERIFIED | 431 lines, create/verify/revoke/revoke_all/list_active/can?/list_scopes all implemented |
| `lib/sigra/api_token/scope_registry.ex` | Scope validation and registry | VERIFIED | 119 lines, 8 built-in scopes, valid_format?/validate_scopes/all_scopes |
| `lib/sigra/plug/require_scopes.ex` | Route-level scope enforcement | VERIFIED | 112 lines, session bypass, AND/OR mode, wildcard support |
| `lib/sigra/ecto/types/string_list.ex` | MySQL/SQLite string list type | VERIFIED | 58 lines, use Ecto.Type, cast/dump/load |
| `lib/sigra/jwt.ex` | JWT public API | VERIFIED | 269 lines, generate_tokens/verify_access/refresh/revoke_refresh |
| `lib/sigra/jwt/claims_builder.ex` | Custom claims behaviour | VERIFIED | 22 lines, @callback extra_claims |
| `lib/sigra/jwt/signer.ex` | Key derivation and signer creation | VERIFIED | 73 lines, HS256/RS256/ES256, ensure_joken! guard |
| `lib/sigra/jwt/refresh_token.ex` | Refresh rotation with reuse detection | VERIFIED | 244 lines, create/rotate/revoke/revoke_family |
| `lib/sigra/plug/fetch_bearer.ex` | Auto-detect opaque vs JWT bearer tokens | VERIFIED | 130 lines, prefix check first, eyJ check, assigns current_scope |
| `lib/sigra/auth.ex` | API token and JWT delegation | VERIFIED | Extended with create_api_token, revoke_api_token, list_api_tokens, generate_jwt_tokens, refresh_jwt |
| `lib/sigra/testing.ex` | API token and JWT test helpers | VERIFIED | Extended with create_api_token, put_bearer_token, generate_jwt, expired_jwt, assert_token_revoked |
| `lib/sigra/workers/token_cleanup.ex` | Cleanup revoked API tokens and refresh tokens | VERIFIED | cleanup_revoked_api_tokens/1, api_refresh context with 30-day TTL |
| `lib/sigra/email_templates.ex` | API token creation email callback | VERIFIED | @callback api_token_created_email/2 |
| `priv/templates/sigra.install/api_token_migration.exs` | Migration template | VERIFIED | create table(:user_api_tokens), token_epoch on users, adapter-conditional |
| `priv/templates/sigra.install/user_api_token.ex` | Schema template | VERIFIED | schema "user_api_tokens", StringList for non-Postgres |
| `priv/templates/sigra.install/api_token_controller.ex` | JSON API controller | VERIFIED | index/create/delete/delete_all, delegates to Auth |
| `priv/templates/sigra.install/token_controller.ex` | JWT auth endpoints | VERIFIED | create/refresh/mfa/revoke, MFA flow support |
| `priv/templates/sigra.install/api_token_created_email.ex` | Email notification template | VERIFIED | api_token_created_email function |
| `priv/templates/sigra.install/auth_api_token.ex` | Auth context delegation | VERIFIED | create_api_token, revoke, list delegation functions |
| `lib/mix/tasks/sigra.install.ex` | --api and --jwt flag support | VERIFIED | --api generates opaque tokens, --jwt adds JWT endpoints |
| `lib/sigra/install/injector.ex` | API route injection | VERIFIED | API pipeline and JWT route injection |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `api_token.ex` | `token.ex` | `Token.generate_hashed_token/0` and `Token.hash_token/1` | WIRED | Lines 81, 83, 128 |
| `require_scopes.ex` | `error_handler.ex` | `error_handler.auth_error(:insufficient_scope)` | WIRED | Line 90 |
| `api_token.ex` | `scope_registry.ex` | `ScopeRegistry.validate_scopes` | WIRED | Line 34 (alias), used in create |
| `jwt.ex` | `signer.ex` | `Signer.create_signer/ensure_joken!` | WIRED | Lines 69, 119 |
| `refresh_token.ex` | `token.ex` | `Token.generate_hashed_token` | WIRED | Used in create/rotate |
| `fetch_bearer.ex` | `api_token.ex` | `Sigra.APIToken.verify` | WIRED | Line 109 |
| `fetch_bearer.ex` | `jwt.ex` | `Sigra.JWT.verify_access` | WIRED | Line 97 |
| `auth.ex` | `api_token.ex` | `APIToken.create/revoke/list_active` delegation | WIRED | Lines 1077-1113 |
| `api_token_controller.ex` | `auth.ex` | `Auth.create_api_token` | WIRED | Template contains `Auth.create_api_token` |
| `token_controller.ex` | `auth.ex` | `Auth.generate_jwt_tokens/refresh_jwt` | WIRED | Template contains `Auth.generate_jwt` |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | No TODOs, FIXMEs, placeholders, or stubs in any phase 7 files |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Phase 7 tests pass | `mix test` (phase files) | 178 tests, 0 failures | PASS |
| Full suite no regressions | `mix test --seed 0` | 995 tests, 0 failures | PASS |
| Joken optional dep resolves | `grep joken mix.exs` | `{:joken, "~> 2.6", optional: true}` | PASS |
| JWT defaults to disabled | `grep "enabled.*default: false" config.ex` | Found at jwt config section | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| API-01 | 07-01, 07-03 | Bearer token authentication via Authorization header | SATISFIED | FetchBearer plug extracts and verifies bearer tokens |
| API-02 | 07-01 | API key format with human-readable prefix | SATISFIED | `{otp_app}_sk_` prefix, configurable, eyJ collision prevention |
| API-03 | 07-01 | API keys stored as SHA-256 hashes, shown only once | SATISFIED | `Token.hash_token` stores SHA-256; raw_key returned only from create |
| API-04 | 07-01 | Personal access tokens with scopes and expiration | SATISFIED | ScopeRegistry validation, configurable expiration, require_expiry/max_ttl options |
| API-05 | 07-02 | JWT support for stateless API use cases | SATISFIED | Joken optional dep, JWT.generate_tokens/verify_access, ClaimsBuilder, RefreshToken |
| API-06 | 07-03 | Dual-mode auth plug (session first, falls back to bearer) | SATISFIED | FetchBearer skips if current_scope assigned (session), otherwise processes bearer |
| API-07 | 07-01, 07-03, 07-04 | Token lifecycle: expiry, last-used, revocation, listing | SATISFIED | list_active with pagination, last_used_at tracking, revoke/revoke_all, cleanup worker |

### Human Verification Required

None -- all truths verified programmatically through code inspection and test execution.

### Gaps Summary

No gaps found. All 5 roadmap success criteria verified. All 7 API requirements (API-01 through API-07) satisfied. 995 tests pass with zero failures. No anti-patterns, TODOs, or stubs in phase 7 code.

---

_Verified: 2026-04-09T03:30:00Z_
_Verifier: Claude (gsd-verifier)_
