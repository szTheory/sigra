---
phase: 05-oauth-and-social-login
reviewed: 2026-04-08T14:30:00Z
depth: standard
files_reviewed: 37
files_reviewed_list:
  - lib/mix/tasks/sigra.gen.oauth.ex
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - lib/sigra/error.ex
  - lib/sigra/identity.ex
  - lib/sigra/install/injector.ex
  - lib/sigra/oauth.ex
  - lib/sigra/oauth/callback.ex
  - lib/sigra/oauth/strategies.ex
  - lib/sigra/oauth/strategies/apple.ex
  - lib/sigra/oauth/strategies/facebook.ex
  - lib/sigra/oauth/strategies/generic.ex
  - lib/sigra/oauth/strategies/github.ex
  - lib/sigra/oauth/strategies/google.ex
  - lib/sigra/telemetry.ex
  - lib/sigra/testing.ex
  - mix.exs
  - priv/templates/sigra.gen.oauth/encrypted_binary.ex
  - priv/templates/sigra.gen.oauth/oauth_buttons.html.heex
  - priv/templates/sigra.gen.oauth/oauth_controller.ex
  - priv/templates/sigra.gen.oauth/oauth_html.ex
  - priv/templates/sigra.gen.oauth/oauth_migration.exs
  - priv/templates/sigra.gen.oauth/oauth_settings.html.heex
  - priv/templates/sigra.gen.oauth/oauth_settings_live.ex
  - priv/templates/sigra.gen.oauth/oauth_test_helpers.ex
  - priv/templates/sigra.gen.oauth/provider_linked_email.ex
  - priv/templates/sigra.gen.oauth/provider_unlinked_email.ex
  - priv/templates/sigra.gen.oauth/user_identity.ex
  - priv/templates/sigra.gen.oauth/vault.ex
  - test/sigra/identity_test.exs
  - test/sigra/install/oauth_generator_test.exs
  - test/sigra/oauth/auth_integration_test.exs
  - test/sigra/oauth/callback_test.exs
  - test/sigra/oauth/config_test.exs
  - test/sigra/oauth/oauth_test.exs
  - test/sigra/oauth/strategies_test.exs
  - test/support/oauth_helpers.ex
findings:
  critical: 2
  warning: 5
  info: 4
  total: 11
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-08T14:30:00Z
**Depth:** standard
**Files Reviewed:** 37
**Status:** issues_found

## Summary

Phase 5 implements OAuth/social login with a solid architecture: HMAC-signed state for CSRF protection, provider-specific strategy wrappers normalizing Assent responses, Ecto.Multi for transactional user+identity creation, and proper account routing (register/login/link-confirm). The Facebook email_verified override and Apple nil-name handling are well done.

Two critical security issues were found: (1) `String.to_existing_atom` in the generated controller converts user-supplied URL params to atoms without validation, creating a potential atom exhaustion DoS vector, and (2) the `get_provider_config` helper has mixed access patterns that will crash on struct configs. Five warnings address logic bugs and missing error handling.

## Critical Issues

### CR-01: Atom exhaustion via user-controlled provider parameter

**File:** `priv/templates/sigra.gen.oauth/oauth_controller.ex:24`
**Issue:** `String.to_existing_atom(provider)` is called on the user-supplied `"provider"` URL parameter. While `to_existing_atom` does not create new atoms, if a provider atom was ever created at compile time or runtime (e.g., via config parsing), an attacker can probe for internal atoms. More importantly, when `to_existing_atom` fails (atom does not exist), it raises an `ArgumentError` that crashes the controller action with a 500 error. This should gracefully return a 404 or redirect with error. The same issue exists at line 49.
**Fix:**
```elixir
# Replace String.to_existing_atom with a safe provider resolution
defp safe_provider_atom(provider) do
  case Sigra.OAuth.Strategies.resolve(String.to_atom(provider), []) do
    {:error, :unknown_provider} -> {:error, :unknown_provider}
    _module -> {:ok, String.to_atom(provider)}
  end
end

# Or use an allowlist approach:
def request(conn, %{"provider" => provider}) do
  config = conn.assigns[:sigra_config] || raise "Sigra config not found in conn.assigns"
  configured_providers = Keyword.keys(Sigra.Config.oauth_providers(config)) |> Enum.map(&to_string/1)

  if provider in configured_providers do
    provider_atom = String.to_existing_atom(provider)
    # ... proceed
  else
    conn |> put_flash(:error, "Unknown provider.") |> redirect(to: ~p"<%= login_path %>")
  end
end
```

### CR-02: Mixed config access pattern causes crash on struct configs

**File:** `lib/sigra/oauth.ex:338`
**Issue:** `get_provider_config/2` uses `get_in(config, [:oauth, :providers])` which works on maps but fails on `%Sigra.Config{}` structs (structs do not implement `Access`). The fallback `Keyword.get(config.oauth, :providers, [])` works for both. However, `get_in` is tried first and will raise `UndefinedFunctionError` for `Sigra.Config.fetch/2` when `config` is a Config struct. This is called from `authorize_url/3` (line 64) and `handle_callback/4` (line 98).
**Fix:**
```elixir
defp get_provider_config(config, provider) do
  providers = Keyword.get(config.oauth, :providers, [])
  Keyword.get(providers, provider)
end
```

## Warnings

### WR-01: OAuth state verification uses string comparison instead of constant-time comparison

**File:** `lib/sigra/oauth.ex:312`
**Issue:** `state != stored_state` uses Elixir's default `!=` operator which does not guarantee constant-time comparison. While the subsequent HMAC verification via `Token.verify` adds defense-in-depth, the early string comparison on line 312 leaks timing information that could help an attacker determine how many characters of the state match. For CSRF tokens this is lower risk than for passwords, but it violates the security posture established elsewhere in the codebase.
**Fix:**
```elixir
# Replace the string comparison with Plug.Crypto.secure_compare
cond do
  is_nil(state) or state == "" ->
    {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}

  not Plug.Crypto.secure_compare(state, stored_state || "") ->
    {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}

  true ->
    case Token.verify(secret_key_base, @oauth_state_purpose, state, max_age: @oauth_state_max_age) do
      {:ok, _data} -> :ok
      {:error, _} -> {:error, %OAuthError{provider: nil, error_code: :state_mismatch}}
    end
end
```

### WR-02: `String.to_existing_atom` on provider strings in LiveView settings template

**File:** `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:69`
**Issue:** Multiple calls to `String.to_existing_atom(identity.provider)` in the LiveView render function. If an identity record somehow contains a provider string that was never atomized (e.g., database was manually edited, or a custom provider was removed from config), this will crash the LiveView with `ArgumentError`. The same issue appears at lines 69, 84, 142, and 171. The non-LiveView settings template at `oauth_settings.html.heex` lines 18-19 has the same problem.
**Fix:**
```elixir
# Add a safe conversion helper and use it in templates
defp safe_provider_atom(provider_str) do
  String.to_existing_atom(provider_str)
rescue
  ArgumentError -> :unknown
end
```

### WR-03: `unlink_provider/4` does not send notification email as documented

**File:** `lib/sigra/oauth.ex:210-263`
**Issue:** The @doc states "Sends notification email on success (D-07)" but the implementation only emits a telemetry event and returns. The generated `ProviderUnlinked` email template exists but is never called. Similarly, `link_provider/4` does not send the `ProviderLinked` email. The docstrings promise email delivery that does not happen.
**Fix:** Either add email delivery calls using the config's mailer, or update the docstrings to indicate that email delivery is the caller's responsibility (matching the pattern used in other Sigra modules where the controller/context handles email sending).

### WR-04: Dead code path in `detect_context_name/2`

**File:** `lib/mix/tasks/sigra.gen.oauth.ex:199-221`
**Issue:** The `detect_context_name/2` function has an if/else on line 206-210 where both branches return `"Accounts"`. The condition `Code.ensure_loaded?(accounts)` is checked but has no effect on the result.
**Fix:**
```elixir
defp detect_context_name(otp_app, base) do
  case Application.get_env(otp_app, :sigra, [])[:user_schema] do
    nil -> "Accounts"

    schema_module ->
      parts = Module.split(schema_module)
      case length(parts) do
        n when n >= 3 -> Enum.at(parts, -2)
        _ -> "Accounts"
      end
  end
end
```

### WR-05: `get_tokens/2` returns encrypted token values as "access_token"

**File:** `lib/sigra/oauth.ex:143`
**Issue:** When tokens are not expired, `get_tokens/2` returns `%{access_token: identity.encrypted_access_token}`. The field name is `encrypted_access_token` because Cloak transparently encrypts/decrypts in the Ecto schema, but here the `Identity` struct (which is not an Ecto schema) holds the raw field value. If the caller receives an `Identity` built from a raw DB query (not through the Ecto schema), this would return the encrypted binary rather than the plaintext token. The naming mismatch between `encrypted_access_token` (field name) and `access_token` (return key) is confusing and error-prone.
**Fix:** Document clearly whether `Identity.encrypted_access_token` holds the plaintext (after Cloak decryption) or the ciphertext. Consider renaming the `Identity` struct field to `access_token` to match the logical value it holds after Ecto decryption, keeping `encrypted_access_token` only for the DB column name.

## Info

### IN-01: Duplicated `ensure_assent!/0` across all strategy modules

**File:** `lib/sigra/oauth/strategies/google.ex:75`, `lib/sigra/oauth/strategies/github.ex:75`, `lib/sigra/oauth/strategies/apple.ex:75`, `lib/sigra/oauth/strategies/facebook.ex:79`, `lib/sigra/oauth/strategies/generic.ex:80`
**Issue:** The `ensure_assent!/0` function is copy-pasted identically across all five strategy modules. This is a maintenance concern -- if the error message or check logic needs to change, five files must be updated.
**Fix:** Extract to a shared module or use a `__using__` macro:
```elixir
defmodule Sigra.OAuth.Strategies.Helpers do
  def ensure_assent! do
    unless Code.ensure_loaded?(Assent) do
      raise "Assent is required for OAuth. Add {:assent, \"~> 0.3\"} to mix.exs and run: mix deps.get"
    end
    :ok
  end
end
```

### IN-02: Duplicated `build_config/1` across strategy modules

**File:** `lib/sigra/oauth/strategies/google.ex:81-87`, `lib/sigra/oauth/strategies/github.ex:84-90`, `lib/sigra/oauth/strategies/apple.ex:83-89`, `lib/sigra/oauth/strategies/facebook.ex:87-93`
**Issue:** The `build_config/1` private function is identical across Google, GitHub, Apple, and Facebook modules. Same maintenance concern as IN-01.
**Fix:** Extract to `Sigra.OAuth.Strategies.Helpers.build_config/2` taking `(provider_config, default_scopes)`.

### IN-03: `extract_assent_session/1` has redundant operation

**File:** `lib/sigra/oauth.ex:329-335`
**Issue:** `Map.to_list() |> Enum.into(%{})` is equivalent to the identity function on maps. After `Map.drop/2` the result is already a map.
**Fix:**
```elixir
defp extract_assent_session(session_params) do
  Map.drop(session_params, [:sigra_state, "sigra_state"])
end
```

### IN-04: Generated test helper passes maps where keyword lists expected

**File:** `priv/templates/sigra.gen.oauth/oauth_test_helpers.ex:35-36`
**Issue:** `create_identity(%{user_id: ..., provider: ...})` passes a map but `Sigra.Testing.create_identity/1` expects a keyword list. This will fail at runtime.
**Fix:**
```elixir
identity = create_identity(
  user_id: user.id,
  provider: to_string(provider),
  provider_uid: opts[:provider_uid] || "test_uid_#{System.unique_integer([:positive])}",
  email: opts[:email] || user.email
)
```

---

_Reviewed: 2026-04-08T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
