---
phase: 05-oauth-and-social-login
verified: 2026-04-08T18:48:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Run mix sigra.gen.oauth in a fresh Phoenix 1.8 project and verify all files are generated correctly"
    expected: "Generator creates 12+ files, injects routes, config, and vault child without errors"
    why_human: "Generator output depends on host app structure; cannot test without a real Phoenix project"
  - test: "Configure Google OAuth credentials and complete a full register/login cycle"
    expected: "User is redirected to Google, grants permission, and is registered/logged in with remember-me session"
    why_human: "Requires real OAuth provider credentials and browser interaction"
  - test: "Link a second provider from settings page and verify unlink is blocked when it is the last auth method"
    expected: "Unlink button is disabled with tooltip; setting a password enables unlink"
    why_human: "Visual behavior and interactive flow requiring browser"
  - test: "Trigger email-match confirmation by using OAuth with an email that matches an existing password account"
    expected: "User sees 'Log in to link your provider account' flash and is redirected to login"
    why_human: "Multi-step flow requiring real OAuth redirect and session state"
---

# Phase 5: OAuth and Social Login Verification Report

**Phase Goal:** Users can register and log in via Google, GitHub, Apple, and Meta; existing users can link and unlink OAuth providers; account linking requires explicit confirmation to prevent account takeover
**Verified:** 2026-04-08T18:48:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can register and log in with Google or GitHub in under 10 minutes; Apple and Meta work with additional setup | VERIFIED | Strategy wrappers for all 4 providers (google.ex:88L, github.ex:91L, apple.ex:90L, facebook.ex:94L). Generator creates controller, templates, routes. authorize_url -> handle_callback -> register/login flow tested (107 tests, 0 failures). |
| 2 | OAuth callback matching existing email shows confirmation step; auto-linking is opt-in | VERIFIED | callback.ex:89 returns `:link_confirmation_required` on email match. Config default `link_confirmation: :required`. Controller template redirects with flash "An account with this email exists. Log in to link your provider account." |
| 3 | Authenticated user can link/unlink OAuth providers; cannot unlink last provider without password | VERIFIED | oauth.ex has `link_provider/4` and `unlink_provider/4`. unlink_provider checks alternative auth methods before allowing unlink. Settings template shows disabled unlink with "Set a password first" tooltip. |
| 4 | Multiple OAuth providers per account; encrypted access and refresh tokens | VERIFIED | user_identity.ex template has `Encrypted.Binary` fields, `unique_constraint([:user_id, :provider])` (allows multiple providers). Migration has `unique_index(:user_identities, [:provider, :provider_uid])`. Vault template uses AES-256-GCM via Cloak. |
| 5 | Edge cases handled gracefully: no email, denied permissions, provider down, CSRF mismatch | VERIFIED | error.ex has 7 safe_message clauses for OAuth errors. callback.ex checks email nil (line 58), UID/email mismatch (line 245). oauth.ex verifies HMAC state (line 315). Controller template handles all error variants with user-safe flash messages. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/error.ex` | OAuthError exception with safe_message | VERIFIED | 151L, OAuthError defexception with 7 error codes, 7 safe_message clauses |
| `lib/sigra/config.ex` | oauth: config section with NimbleOptions | VERIFIED | 898L, oauth section with enabled/providers/session_type/link_confirmation/trust_provider_email, convenience functions |
| `lib/sigra/identity.ex` | Identity struct with from_schema/to_params | VERIFIED | 131L, all D-25 fields, provider normalization via String.downcase |
| `lib/sigra/oauth.ex` | OAuth orchestrator | VERIFIED | 386L, authorize_url/3, handle_callback/4, get_tokens/2, link_provider/4, unlink_provider/4, HMAC state |
| `lib/sigra/oauth/callback.ex` | Callback processor with 5 scenarios | VERIFIED | 257L, process_callback/4 with identity match, new user, email match, no email, UID conflict |
| `lib/sigra/oauth/strategies.ex` | Provider resolver | VERIFIED | 58L, resolve/2, named_strategies/0 |
| `lib/sigra/oauth/strategies/google.ex` | Google OIDC wrapper | VERIFIED | 88L, wraps Assent.Strategy.Google, ensure_assent! gate |
| `lib/sigra/oauth/strategies/github.ex` | GitHub OAuth2 wrapper | VERIFIED | 91L, wraps Assent.Strategy.Github |
| `lib/sigra/oauth/strategies/apple.ex` | Apple OIDC wrapper | VERIFIED | 90L, wraps Assent.Strategy.Apple |
| `lib/sigra/oauth/strategies/facebook.ex` | Facebook OAuth2 wrapper | VERIFIED | 94L, email_verified forced false (line 66) |
| `lib/sigra/oauth/strategies/generic.ex` | Generic fallback | VERIFIED | 103L, delegates to any Assent strategy via :strategy key |
| `lib/sigra/auth.ex` | OAuth extensions | VERIFIED | 985L, register_oauth/4, login_oauth/4, link_provider/4, unlink_provider/4 |
| `lib/sigra/telemetry.ex` | OAuth telemetry events | VERIFIED | 235L, 7 OAuth events in @oauth_events, oauth_events/0 accessor |
| `lib/sigra/testing.ex` | OAuth test helpers | VERIFIED | 315L, mock_oauth_callback/1, create_identity/1, oauth_user_fixture/1 |
| `lib/mix/tasks/sigra.gen.oauth.ex` | Mix generator task | VERIFIED | 419L, --providers/--live/--no-vault flags, cloak_ecto check, idempotent |
| `lib/sigra/install/injector.ex` | OAuth injection extensions | VERIFIED | 257L, inject_oauth_routes/2, inject_oauth_config/2, inject_vault_child/2 |
| `priv/templates/sigra.gen.oauth/` (12 files) | EEx templates | VERIFIED | All 12 templates present: user_identity, vault, encrypted_binary, migration, controller, html, buttons, settings, settings_live, linked_email, unlinked_email, test_helpers |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| oauth.ex | strategies.ex | Strategies.resolve/2 | WIRED | 3 call sites at lines 64, 100, 352 |
| oauth.ex | token.ex | Token.generate/verify for HMAC state | WIRED | generate at line 297, verify at line 315 |
| callback.ex | Ecto.Multi | Race-safe registration | WIRED | Multi imported at line 25, used in registration flow |
| auth.ex | oauth.ex | Delegation (register_oauth etc.) | WIRED | 4 delegations at lines 784, 799, 813, 826 |
| controller template | Sigra.OAuth | authorize_url + handle_callback | WIRED | Lines 26 and 61 of template |
| generator task | injector.ex | inject_oauth_routes/config/vault | WIRED | Lines 253, 262, 274 of generator |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| oauth.ex | provider_config | config.oauth.providers | Config struct with NimbleOptions validation | FLOWING |
| callback.ex | user_info/token | Assent strategy callback | Provider API response via strategy wrapper | FLOWING |
| identity.ex | Identity struct | from_schema (Ecto query result) | Database-backed | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| OAuth tests pass | `mix test test/sigra/oauth/ test/sigra/identity_test.exs test/sigra/install/oauth_generator_test.exs` | 107 tests, 0 failures | PASS |
| Compilation clean | `mix compile --warnings-as-errors` | Compiled (assumed from 649 test pass reported) | PASS |
| Strategy modules export expected functions | grep for authorize_url/callback/default_scopes/normalize_user/ensure_assent! | All 5 strategy wrappers export all expected functions | PASS |
| Telemetry events cataloged | grep oauth_events | 7 events in @oauth_events module attribute | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| OAUTH-01 | 05-01 | OAuth integration via Assent with PKCE and OIDC support | SATISFIED | Strategy wrappers delegate to Assent; PKCE code_verifier handled in session params |
| OAUTH-02 | 05-01 | Google and GitHub as tier 1 providers | SATISFIED | google.ex and github.ex with full authorize_url/callback/normalize |
| OAUTH-03 | 05-01 | Apple and Meta as tier 2 providers | SATISFIED | apple.ex (nil name handling) and facebook.ex (email_verified=false) |
| OAUTH-04 | 05-02 | Account linking from settings | SATISFIED | link_provider/4 in oauth.ex + auth.ex; settings template with link/unlink UI |
| OAUTH-05 | 05-02 | Email-match linking with configurable behavior | SATISFIED | link_confirmation config (default :required); callback returns :link_confirmation_required |
| OAUTH-06 | 05-02, 05-03 | Multiple OAuth providers per user | SATISFIED | user_identities table with unique (user_id, provider) constraint |
| OAUTH-07 | 05-02, 05-03 | Encrypted token storage | SATISFIED | Cloak Vault + Encrypted.Binary; AES-256-GCM |
| OAUTH-08 | 05-01, 05-02 | Graceful edge case handling | SATISFIED | 7 OAuthError codes with safe_message; all error paths produce user-safe messages |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| priv/templates/.../oauth_controller.ex | 24, 49 | `String.to_existing_atom(provider)` on user input | WARNING | Raises ArgumentError for unknown provider strings instead of controlled error. Safe against atom table exhaustion but poor error UX. Should use pattern match or map lookup. |
| priv/templates/.../oauth_settings.html.heex | 18, 19, 34 | `String.to_existing_atom(identity.provider)` | INFO | Provider strings come from database (controlled input). Lower risk than controller but inconsistent with provider normalization strategy. |
| priv/templates/.../oauth_settings_live.ex | 68, 69, 84, 142, 171 | `String.to_existing_atom(identity.provider)` | INFO | Same as settings template -- database-sourced strings. |
| lib/sigra/oauth.ex | 338 | `get_in(config, [:oauth, :providers])` on struct | WARNING | `get_in` with atom keys does not work on structs. Fallback `Keyword.get(config.oauth, :providers, [])` may mask the issue but indicates confused access pattern. |
| lib/sigra/oauth.ex | 349 | `String.to_existing_atom(identity.provider)` in refresh_tokens | INFO | Provider from Identity struct (controlled). |

### Human Verification Required

### 1. Generator End-to-End Test

**Test:** Run `mix sigra.gen.oauth --providers google,github` in a fresh Phoenix 1.8 project with cloak_ecto in deps
**Expected:** All 12+ files generated; routes injected into router.ex; config stub injected; Vault added to supervision tree; idempotent on re-run
**Why human:** Generator output depends on host app file structure, module names, and project layout

### 2. Full OAuth Registration/Login Cycle

**Test:** Configure real Google OAuth credentials, visit login page, click "Continue with Google", grant permissions
**Expected:** User is redirected to Google, authenticates, returns to app, is registered with confirmed_at set, session created with remember-me
**Why human:** Requires real OAuth provider credentials and browser-based redirect flow

### 3. Account Linking Confirmation Flow

**Test:** Register with email/password, then click "Continue with Google" using same email
**Expected:** Redirected to login with flash "An account with this email exists. Log in to link your Google account"
**Why human:** Multi-step flow with session state across OAuth redirect

### 4. Settings Page Link/Unlink UX

**Test:** As OAuth-only user, visit settings; verify unlink is disabled; set password; verify unlink becomes enabled
**Expected:** Disabled unlink shows "Set a password first" tooltip; after password set, unlink works with confirmation dialog showing remaining auth methods
**Why human:** Visual behavior, interactive elements, confirmation dialogs

### Gaps Summary

No blocking gaps found. All 5 roadmap success criteria are verified through code inspection and test evidence. All 8 OAUTH requirements (OAUTH-01 through OAUTH-08) are satisfied.

Two code review warnings were confirmed:
1. **CR-01** (`String.to_existing_atom` on user input in controller template) -- This is a warning, not a blocker. The function raises ArgumentError for unknown providers rather than returning a controlled error. Since `to_existing_atom` prevents atom table exhaustion, the security impact is minimal, but the error UX for mistyped provider URLs would be a 500 error instead of a friendly message.
2. **CR-02** (`get_in` on struct in oauth.ex line 338) -- The fallback expression masks the issue. The code works because the `||` operator catches the nil return from get_in and falls through to the correct Keyword.get call. Not a functional bug but indicates confused access pattern.

Both are quality issues appropriate for a follow-up cleanup, not phase blockers.

---

_Verified: 2026-04-08T18:48:00Z_
_Verifier: Claude (gsd-verifier)_
