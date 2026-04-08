---
phase: 05-oauth-and-social-login
audited: 2026-04-08
asvs_level: 1
threats_total: 20
threats_closed: 20
threats_open: 0
status: SECURED
---

# Phase 5 Security Audit: OAuth and Social Login

## Threat Verification

### Closed (20/20)

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-05-01 | Spoofing | mitigate | All strategy wrappers (Google, GitHub, Apple, Facebook, Generic) normalize UID to string via `normalize_user/1` returning `"sub"` key. See `lib/sigra/oauth/strategies/google.ex:55`, `github.ex:56`, `apple.ex:57`, `facebook.ex:59`, `generic.ex:62`. Identity lookup in `lib/sigra/oauth/callback.ex:75` uses `(provider, provider_uid)`, never email alone. |
| T-05-02 | Tampering | mitigate | NimbleOptions validates entire `oauth:` config section in `lib/sigra/config.ex:761-797`. Types enforced: `:boolean` for enabled/trust_provider_email, `{:in, [...]}` for session_type/link_confirmation, `:keyword_list` for providers. Invalid types rejected at `Config.new!/1` call time. |
| T-05-03 | Information Disclosure | mitigate | `safe_message/1` clauses for all 7 OAuth error codes in `lib/sigra/error.ex:125-149`. All return generic strings. `OAuthError.message/1` includes internal details (`lib/sigra/error.ex:65-66`) but is only used in server logs, never in user-facing flash messages. Controller template uses `Sigra.Error.safe_message/1` for all error flashes. |
| T-05-04 | Elevation of Privilege | mitigate | `ensure_assent!/0` calls `Code.ensure_loaded?(Assent)` in all 5 strategy wrappers: `google.ex:74`, `github.ex:76`, `apple.ex:76`, `facebook.ex:80`, `generic.ex:82`. Raises descriptive error with install instructions if Assent not loaded. Called at entry points `authorize_url/1` and `callback/3`. |
| T-05-05 | Spoofing | mitigate | `lib/sigra/oauth/strategies/facebook.ex:66` forces `"email_verified" => false` in `normalize_user/1` regardless of provider response. Downstream `lib/sigra/oauth/callback.ex:162` checks `user_info["email_verified"] == true` -- Facebook users get `confirmed_at: nil`, triggering confirmation flow. |
| T-05-06 | Spoofing | mitigate | HMAC-signed state generated via `Sigra.Token.generate/4` with purpose `"sigra-oauth-state"` and 900s (15-min) TTL at `lib/sigra/oauth.ex:304-310`. Verification at `lib/sigra/oauth.ex:313-329` uses `Plug.Crypto.secure_compare/2` for timing-safe comparison before `Token.verify/4`. Returns `state_mismatch` error on failure. |
| T-05-07 | Spoofing | mitigate | `lib/sigra/oauth/callback.ex:88-93` returns `{:link_confirmation_required, ...}` when email matches existing user but no identity exists. Never auto-links. Config default `link_confirmation: :required` at `lib/sigra/config.ex:787`. |
| T-05-08 | Spoofing | mitigate | `lib/sigra/oauth/callback.ex:107-118` checks if provider_uid maps to identity's user but email matches a different user. Returns `{:error, %OAuthError{error_code: :email_mismatch}}` with Logger.error for audit trail. User sees generic "Could not complete sign in." via safe_message. |
| T-05-09 | Tampering | mitigate | Identity lookup at `lib/sigra/oauth/callback.ex:75` uses `repo.get_by(identity_schema, provider: provider_str, provider_uid: provider_uid)` -- always by (provider, provider_uid), never email. Generated schema template at `priv/templates/sigra.gen.oauth/user_identity.ex:55-56` enforces `unique_constraint([:user_id, :provider])` and `unique_constraint([:provider, :provider_uid])`. |
| T-05-10 | Denial of Service | accept | Accepted for v1. Token refresh is currently stubbed (`lib/sigra/oauth.ex:369` logs warning). First-refresh-wins pattern will be implemented when full refresh is added. Risk is low: worst case is a redundant refresh call, not data loss. |
| T-05-11 | Information Disclosure | mitigate | `lib/sigra/oauth/callback.ex:57-58` logs detailed error at `:error` level. `lib/sigra/oauth.ex:112` logs callback failures with `Logger.error`. Controller template (`priv/templates/sigra.gen.oauth/oauth_controller.ex:100-108`) uses `Sigra.Error.safe_message/1` for all user-facing flash messages. |
| T-05-13 | Spoofing | mitigate | Facebook strategy forces `email_verified: false` at `lib/sigra/oauth/strategies/facebook.ex:66`. Callback processor at `lib/sigra/oauth/callback.ex:162` checks `user_info["email_verified"] == true` -- evaluates false for Facebook, so `confirmed_at` is set to `nil`, which triggers the standard email confirmation flow. |
| T-05-14 | Denial of Service | mitigate | `lib/sigra/oauth/callback.ex:174-175` wraps user+identity creation in `Ecto.Multi`. Database unique constraints on email (from user schema) and `(provider, provider_uid)` (from identity schema at `priv/templates/sigra.gen.oauth/user_identity.ex:56`) catch concurrent registration races. Transaction rolls back on constraint violation. |
| T-05-15 | Spoofing | mitigate | Same mechanism as T-05-06. HMAC-signed state parameter generated at `lib/sigra/oauth.ex:304-310`, verified at `lib/sigra/oauth.ex:313-329` with 15-min TTL. Controller template stores state in session at `priv/templates/sigra.gen.oauth/oauth_controller.ex:30-31` and clears at `oauth_controller.ex:65-67`. |
| T-05-16 | Tampering | mitigate | Controller template stores OAuth session params with `sigra_oauth_*` prefix (`priv/templates/sigra.gen.oauth/oauth_controller.ex:30-32`): `:sigra_oauth_state`, `:sigra_oauth_code_verifier`, `:sigra_oauth_return_to`. Cleared immediately after use at `oauth_controller.ex:65-67`. |
| T-05-17 | Information Disclosure | mitigate | Controller template uses `Sigra.Error.safe_message(:oauth_state_mismatch)` and `Sigra.Error.safe_message(:oauth_no_email)` for error flashes (`priv/templates/sigra.gen.oauth/oauth_controller.ex:100-108`). Catch-all error at line 110-114 returns generic message. No internal error details in flash. |
| T-05-18 | Tampering | mitigate | UserIdentity schema template uses `Encrypted.Binary` type (cloak_ecto) for `encrypted_access_token` and `encrypted_refresh_token` at `priv/templates/sigra.gen.oauth/user_identity.ex:18-19`. Vault template at `priv/templates/sigra.gen.oauth/vault.ex:23-29` configures AES-256-GCM with 12-byte IV. Key rotation supported via Cloak.Vault behaviour. |
| T-05-19 | Denial of Service | mitigate | Vault template at `priv/templates/sigra.gen.oauth/vault.ex:35-38` uses `System.fetch_env!/1` which raises `System.EnvError` at application startup if CLOAK_KEY is missing. Generator prints key generation instructions at `lib/mix/tasks/sigra.gen.oauth.ex:353-358`. |
| T-05-12 | Elevation of Privilege | mitigate | `require_sudo/2` in `lib/sigra/oauth.ex` checks `session.sudo_at` freshness against `config.session[:sudo_timeout]`. Both `link_provider/4` and `unlink_provider/4` call `require_sudo/2` via `with :ok <- require_sudo(config, opts)` before delegating to `do_link_provider/3` and `do_unlink_provider/3`. Returns `{:error, :sudo_required}` when sudo is stale or missing. Tests in `test/sigra/oauth/oauth_test.exs` verify both the happy path (sudo active) and rejection (no sudo). |
| T-05-20 | Elevation of Privilege | accept | Accepted. Generated routes at `lib/mix/tasks/sigra.gen.oauth.ex:236-244` follow standard Phoenix scope pattern (`scope "/auth"` with `pipe_through [:browser]`). No privilege escalation vector beyond standard Phoenix route handling. |

### Open (0/20)

No open threats.

### Resolved: T-05-12 (2026-04-08)

**Fix:** Added `require_sudo/2` private helper to `Sigra.OAuth` that checks `session.sudo_at` freshness against the configured `sudo_timeout`. Both `link_provider/4` and `unlink_provider/4` now accept `opts[:session]` and return `{:error, :sudo_required}` when sudo mode is not active. Commit: `802b2da`. 651 tests pass including 2 new sudo enforcement tests.

### Unregistered Flags

None. No `## Threat Flags` section found in any SUMMARY.md file.

### Accepted Risks Log

| Threat ID | Category | Risk Description | Rationale |
|-----------|----------|------------------|-----------|
| T-05-10 | Denial of Service | Token refresh race condition -- concurrent refresh attempts may cause redundant API calls | First-refresh-wins pattern is acceptable for v1. Token refresh is currently stubbed. Worst case is an extra API call, not data corruption or loss. |
| T-05-20 | Elevation of Privilege | Generated routes follow standard Phoenix patterns | No special privilege escalation surface beyond normal Phoenix routing. Standard `pipe_through [:browser]` pipeline applies. |
