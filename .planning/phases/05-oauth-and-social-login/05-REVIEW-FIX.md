---
phase: 05-oauth-and-social-login
fixed_at: 2026-04-08T15:00:00Z
review_path: .planning/phases/05-oauth-and-social-login/05-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-04-08T15:00:00Z
**Source review:** .planning/phases/05-oauth-and-social-login/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: Atom exhaustion via user-controlled provider parameter

**Files modified:** `priv/templates/sigra.gen.oauth/oauth_controller.ex`
**Commit:** 8d9f1f8
**Applied fix:** Added `validate_provider/2` private function that checks the provider string against configured OAuth providers (via `Sigra.Config.oauth_providers/1`) before any atom conversion. Both `request/2` and `callback/2` actions now validate the provider first, returning a flash error and redirect for unknown providers instead of crashing with `ArgumentError`. The `String.to_existing_atom` call only executes after allowlist validation confirms the atom exists.

### CR-02: Mixed config access pattern causes crash on struct configs

**Files modified:** `lib/sigra/oauth.ex`
**Commit:** 1e15aa8
**Applied fix:** Replaced `get_in(config, [:oauth, :providers])` with `Keyword.get(config.oauth, :providers, [])` in `get_provider_config/2`. This uses dot-access for the `oauth` field (works on both structs and maps) and `Keyword.get` on the resulting keyword list, avoiding the `Access` protocol issue with structs.

### WR-01: OAuth state verification uses string comparison instead of constant-time comparison

**Files modified:** `lib/sigra/oauth.ex`
**Commit:** e563d5a
**Applied fix:** Replaced `state != stored_state` with `not Plug.Crypto.secure_compare(state, stored_state || "")` in `verify_state/3`. The `|| ""` fallback handles nil stored_state safely. This prevents timing side-channel leakage on the state comparison, consistent with the security posture of HMAC-signed state tokens.

### WR-02: `String.to_existing_atom` on provider strings in settings templates

**Files modified:** `priv/templates/sigra.gen.oauth/oauth_settings_live.ex`, `priv/templates/sigra.gen.oauth/oauth_settings.html.heex`, `priv/templates/sigra.gen.oauth/oauth_html.ex`
**Commit:** 8c751db
**Applied fix:** Added `safe_provider_atom/1` to `OAuthHTML` module (public, for use in HEEx templates) and as a private function in the LiveView module. The helper wraps `String.to_existing_atom` in a rescue clause, returning `:unknown` for unrecognized provider strings instead of crashing. All `String.to_existing_atom(identity.provider)` calls in both templates replaced with the safe variant.

### WR-03: `unlink_provider/4` does not send notification email as documented

**Files modified:** `lib/sigra/oauth.ex`
**Commit:** 40c1ee9
**Applied fix:** Updated `@doc` for both `link_provider/4` and `unlink_provider/4` to clarify that the caller (controller/LiveView) is responsible for sending notification emails, matching the pattern used elsewhere in Sigra where the context module emits telemetry and the controller handles email delivery.

### WR-04: Dead code path in `detect_context_name/2`

**Files modified:** `lib/mix/tasks/sigra.gen.oauth.ex`
**Commit:** 77f61b5
**Applied fix:** Removed the dead `if Code.ensure_loaded?(accounts)` branch where both sides returned `"Accounts"`. The `nil` case now directly returns `"Accounts"`. Also prefixed the unused `base` parameter with underscore to prevent compiler warnings.

### WR-05: `get_tokens/2` returns encrypted token values as "access_token"

**Files modified:** `lib/sigra/oauth.ex`
**Commit:** fa53680
**Applied fix:** Added documentation in the `@doc` explaining the naming convention: identity struct fields are named `encrypted_*` for the DB column, but Cloak transparently decrypts when loaded through Ecto, so the values are plaintext. Added inline comment at the return site. Updated the example to use `"plaintext_token"` to reduce confusion.

---

_Fixed: 2026-04-08T15:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
