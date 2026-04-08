---
phase: 5
slug: oauth-and-social-login
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-08
validated: 2026-04-08
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/oauth/ test/sigra/identity_test.exs test/sigra/install/oauth_generator_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~0.1 seconds (OAuth subset) |
| **Test count** | 109 tests, 0 failures |

> **Note:** Do not use `--no-start` for OAuth tests. The `Plug.Crypto.KeyGenerator` ETS cache and `:telemetry.attach` require OTP applications to be started.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/oauth/ test/sigra/identity_test.exs test/sigra/install/oauth_generator_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** <1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | OAUTH-01 | T-05-01 / T-05-02 | Provider config validated at startup | unit | `mix test test/sigra/oauth/config_test.exs` | test/sigra/oauth/config_test.exs (14 tests) | ✅ green |
| 05-01-02 | 01 | 1 | OAUTH-02 | T-05-01 / T-05-04 / T-05-05 | Assent strategy wrappers normalize responses | unit | `mix test test/sigra/oauth/strategies_test.exs` | test/sigra/oauth/strategies_test.exs (20 tests) | ✅ green |
| 05-02-01 | 02 | 1 | OAUTH-03 | T-05-06 / T-05-15 | OAuth state HMAC-signed, verified on callback | unit | `mix test test/sigra/oauth/oauth_test.exs` | test/sigra/oauth/oauth_test.exs (21 tests) | ✅ green |
| 05-02-02 | 02 | 1 | OAUTH-04 | T-05-07 | Email-match linking requires confirmation | integration | `mix test test/sigra/oauth/callback_test.exs` | test/sigra/oauth/callback_test.exs (9 tests) | ✅ green |
| 05-03-01 | 03 | 2 | OAUTH-05 | T-05-18 | Encrypted token storage via cloak_ecto | unit | `mix test test/sigra/identity_test.exs test/sigra/install/oauth_generator_test.exs` | test/sigra/identity_test.exs (8 tests), test/sigra/install/oauth_generator_test.exs (23 tests) | ✅ green |
| 05-03-02 | 03 | 2 | OAUTH-06 | T-05-12 | Link/unlink with sudo mode enforcement | integration | `mix test test/sigra/oauth/oauth_test.exs test/sigra/oauth/auth_integration_test.exs` | test/sigra/oauth/oauth_test.exs, test/sigra/oauth/auth_integration_test.exs (14 tests) | ✅ green |
| 05-04-01 | 04 | 3 | OAUTH-07 | T-05-11 / T-05-13 | Edge cases: no email, denied perms, CSRF mismatch | unit | `mix test test/sigra/oauth/callback_test.exs test/sigra/oauth/oauth_test.exs` | test/sigra/oauth/callback_test.exs, test/sigra/oauth/oauth_test.exs | ✅ green |
| 05-04-02 | 04 | 3 | OAUTH-08 | — | Generator produces idempotent OAuth files | integration | `mix test test/sigra/install/oauth_generator_test.exs` | test/sigra/install/oauth_generator_test.exs (23 tests) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/oauth/` — directory structure for OAuth test modules
- [x] `test/support/oauth_helpers.ex` — shared fixtures for mock Assent responses
- [x] Test helpers for mocking Assent HTTP layer (mock strategy pattern via `:strategy` config key)

*All Wave 0 infrastructure is in place. Mock repos for all 5 callback scenarios are defined in `test/support/oauth_helpers.ex`.*

---

## Requirement Coverage Detail

### OAUTH-01: Provider config validated at startup
- **config_test.exs**: NimbleOptions validation for all oauth config fields (enabled, providers, session_type, link_confirmation, trust_provider_email), type validation errors, defaults, kill switch

### OAUTH-02: Assent strategy wrappers normalize responses
- **strategies_test.exs**: resolve/2 for all 4 named providers + generic fallback, default_scopes for each, normalize_user shape consistency, Facebook email_verified=false, GitHub id fallback, Apple nil name, ensure_assent! gate

### OAUTH-03: OAuth state HMAC-signed, verified on callback
- **oauth_test.exs**: HMAC state generation, state replacement in URL, Token.verify roundtrip, PKCE code_verifier passthrough, state mismatch error, missing state error, valid state callback processing

### OAUTH-04: Email-match linking requires confirmation
- **callback_test.exs**: link_confirmation_required returned when email matches existing user, provider and email in info map

### OAUTH-05: Encrypted token storage via cloak_ecto
- **identity_test.exs**: Identity struct has encrypted_access_token and encrypted_refresh_token fields, from_schema/to_params mapping
- **oauth_generator_test.exs**: Template uses Encrypted.Binary type, Vault template references Cloak.Vault/CLOAK_KEY/AES-256-GCM, migration has :binary columns for encrypted fields

### OAUTH-06: Link/unlink with sudo mode enforcement
- **oauth_test.exs**: link_provider requires sudo session, returns already_linked for existing, unlink_provider requires sudo, blocks last_provider without password, succeeds with password fallback
- **auth_integration_test.exs**: Auth.link_provider and Auth.unlink_provider delegation verified

### OAUTH-07: Edge cases (no email, denied perms, CSRF mismatch)
- **callback_test.exs**: no_email for nil and empty string, email_mismatch for UID/email cross-account conflict
- **oauth_test.exs**: state_mismatch, missing state, authorize_failed from strategy error, provider_error on unknown provider

### OAUTH-08: Generator produces idempotent OAuth files
- **oauth_generator_test.exs**: Route injection + idempotency (3 tests), config injection + idempotency (3 tests), vault child injection + idempotency (3 tests), 12 template content verifications, Mix task module existence

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| OAuth redirect flow with real provider | OAUTH-01 | Requires real provider credentials and browser interaction | Configure test Google/GitHub app, click "Sign in with Google", verify redirect and callback |
| SVG icon rendering in login form | OAUTH-02 | Visual verification of brand-compliant icons | Load login page, verify provider icons render correctly with proper sizing |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-04-08
