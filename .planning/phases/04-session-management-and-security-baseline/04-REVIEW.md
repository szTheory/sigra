---
phase: 04-session-management-and-security-baseline
reviewed: 2026-04-07T12:00:00Z
depth: standard
files_reviewed: 29
files_reviewed_list:
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - lib/sigra/email_templates.ex
  - lib/sigra/error.ex
  - lib/sigra/lockout.ex
  - lib/sigra/plug/fetch_session.ex
  - lib/sigra/plug/rate_limit.ex
  - lib/sigra/plug/require_sudo.ex
  - lib/sigra/rate_limiters/hammer.ex
  - lib/sigra/session.ex
  - lib/sigra/session_store.ex
  - lib/sigra/session_stores/ecto.ex
  - lib/sigra/suspicious_login.ex
  - lib/sigra/telemetry.ex
  - lib/sigra/testing.ex
  - lib/sigra/ua_parser.ex
  - lib/sigra/geo_ip.ex
  - lib/sigra/workers/token_cleanup.ex
  - lib/mix/tasks/sigra.install.ex
  - priv/templates/sigra.install/auth.ex
  - priv/templates/sigra.install/emails.ex
  - priv/templates/sigra.install/session_live.ex
  - priv/templates/sigra.install/sudo_controller.ex
  - priv/templates/sigra.install/sudo_html.ex
  - priv/templates/sigra.install/user_auth.ex
  - priv/templates/sigra.install/user_session.ex
  - priv/templates/sigra.install/migration.exs
  - priv/templates/sigra.install/auth_fixtures.ex
  - priv/templates/sigra.install/conn_case_helpers.ex
findings:
  critical: 3
  warning: 7
  info: 4
  total: 14
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-07T12:00:00Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** issues_found

## Summary

Reviewed the complete Phase 04 session management and security baseline implementation. The overall architecture is solid: database-backed sessions, HMAC-protected tokens, SHA-256 hashed storage, idle/absolute timeouts, sudo mode, suspicious login detection, and account lockout. The behaviour-based abstractions (SessionStore, RateLimiter, GeoIP) are well-designed for testability.

However, there are three critical security issues: an open redirect vulnerability in the sudo controller, an XSS risk in email templates from unescaped user-controlled data, and an insecure random number generator used for confirmation codes. There are also several warnings around race conditions, missing validation, and a broken template binding.

## Critical Issues

### CR-01: Open Redirect in Sudo Controller via `return_to` parameter

**File:** `priv/templates/sigra.install/sudo_controller.ex:23-33`
**Issue:** The `return_to` parameter from user input is used directly in `redirect(to: return_to)` without validation. An attacker can craft a URL like `/users/sudo?return_to=https://evil.com` to redirect users to a malicious site after sudo confirmation. This is OWASP A01:2021 (Broken Access Control).
**Fix:**
```elixir
  def create(conn, %{"sudo" => %{"password" => password, "return_to" => return_to}}) do
    user = conn.assigns.current_scope.user

    case Sigra.Crypto.verify_password(password, user.hashed_password) do
      true ->
        session = conn.private[:sigra_session]
        <%= context_module %>.confirm_sudo(session.hashed_token)

        # Validate return_to is a local path (not an external URL)
        safe_return_to =
          if return_to && String.starts_with?(return_to, "/") && !String.starts_with?(return_to, "//") do
            return_to
          else
            ~p"/"
          end

        conn
        |> put_flash(:info, "Password confirmed.")
        |> redirect(to: safe_return_to)

      false ->
        conn
        |> put_flash(:error, "Incorrect password. Please try again.")
        |> render(:new, return_to: return_to)
    end
  end
```

### CR-02: Insecure PRNG for Confirmation Codes

**File:** `lib/sigra/auth.ex:310`
**Issue:** `:rand.uniform/1` uses the default PRNG algorithm which is not cryptographically secure. A 6-digit confirmation code generated with a predictable PRNG can be guessed if the attacker knows the seed state. This is security-sensitive because confirmation codes are an authentication factor.
**Fix:**
```elixir
    # Generate 6-digit code (100000-999999) using crypto-safe random
    code =
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()
      |> rem(900_000)
      |> Kernel.+(100_000)
      |> Integer.to_string()
```

### CR-03: XSS via Unescaped IP Address in Email Templates

**File:** `priv/templates/sigra.install/emails.ex:153-189`
**Issue:** The `suspicious_login_email/2` function interpolates `details.ip`, `details.geo_city`, `details.geo_country_code`, and `details.device` directly into HTML without escaping. While IP addresses are typically safe, the `device` field comes from the User-Agent header which is fully attacker-controlled. A malicious User-Agent containing `<script>` tags or HTML entities would be rendered in the email. Email clients vary in their HTML sanitization, and some (especially webmail) may execute injected content.
**Fix:**
```elixir
  def suspicious_login_email(user, details) do
    ip = details |> Map.get(:ip, "Unknown") |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    geo_city = Map.get(details, :geo_city)
    geo_country = Map.get(details, :geo_country_code)
    location = if geo_city, do: "#{Phoenix.HTML.html_escape(geo_city) |> Phoenix.HTML.safe_to_string()}, #{Phoenix.HTML.html_escape(geo_country) |> Phoenix.HTML.safe_to_string()}", else: "Unknown"
    device = details |> Map.get(:device, "Unknown device") |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    # ... rest unchanged
  end
```

## Warnings

### WR-01: Race Condition in Lockout Increment

**File:** `lib/sigra/lockout.ex:85-99`
**Issue:** `increment!/3` reads `user.failed_login_attempts`, adds 1, and writes back. Under concurrent requests (e.g., credential stuffing), two requests could both read `failed_login_attempts: 4`, both compute `5`, and both write `5` -- meaning the counter only increments by 1 instead of 2. This could allow more attempts than the threshold intends.
**Fix:** Use an atomic `UPDATE ... SET failed_login_attempts = failed_login_attempts + 1` query instead of read-modify-write:
```elixir
  def increment!(repo, user, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    import Ecto.Query

    {1, [updated]} =
      from(u in user.__struct__,
        where: u.id == ^user.id,
        select: u
      )
      |> repo.update_all(inc: [failed_login_attempts: 1])

    # Set locked_at if threshold reached
    if updated.failed_login_attempts >= threshold && is_nil(updated.locked_at) do
      updated
      |> Ecto.Changeset.change(%{locked_at: DateTime.utc_now()})
      |> repo.update!()
    else
      updated
    end
  end
```

### WR-02: Unbound `reset_password_url` in Email Template

**File:** `priv/templates/sigra.install/emails.ex:163`
**Issue:** The template references `<%= reset_password_url %>` but this binding is never set in `lib/mix/tasks/sigra.install.ex`. The `binding` list on lines 83-98 of `sigra.install.ex` does not include `:reset_password_url`. This will cause a compile error in the generated `Emails` module when `suspicious_login_email/2` or `lockout_notification_email/2` is called.
**Fix:** Add `reset_password_url` to the binding in `lib/mix/tasks/sigra.install.ex`:
```elixir
    binding = [
      # ... existing bindings ...
      reset_password_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/reset-password"
    ]
```

### WR-03: Generated Auth Template References Wrong Module Name

**File:** `priv/templates/sigra.install/auth.ex:456`
**Issue:** `sigra_config/0` references `Sigra.SessionStore.Ecto` but the actual module is `Sigra.SessionStores.Ecto` (plural). This will cause a runtime error when any session management function is called.
**Fix:**
```elixir
      session: [
        store: Sigra.SessionStores.Ecto,
        session_schema: <%= context_module %>.UserSession
      ],
```

### WR-04: FetchSession Plug Does Not Invalidate Expired Sessions

**File:** `lib/sigra/plug/fetch_session.ex:107-120`
**Issue:** When `session_valid?/2` returns `false` (idle or absolute timeout exceeded), the plug returns `:skip` and assigns `current_scope: nil`, but it does not delete the expired session from the database. This means expired sessions accumulate in the `user_sessions` table and are listed in the session management UI until the cleanup worker runs. More importantly, a user viewing their sessions page may see "active" sessions that are actually expired, which is confusing.
**Fix:** Delete the session from the store when validation fails:
```elixir
  defp fetch_and_validate_session(token, session_store, session_config, opts) do
    case session_store.fetch(token, opts) do
      {:ok, session} ->
        if session_valid?(session, session_config) do
          {:ok, session}
        else
          # Clean up expired session eagerly
          session_store.delete(session.hashed_token, opts)
          :skip
        end

      {:error, _reason} ->
        :skip
    end
  end
```

### WR-05: `revoke_current` Event Revokes All Sessions Instead of Current

**File:** `priv/templates/sigra.install/session_live.ex:109-114`
**Issue:** The `"revoke_current"` event handler calls `Auth.revoke_all_sessions(user, except_token: nil)` which revokes ALL sessions (passing `except_token: nil` is equivalent to not passing it). The intent appears to be revoking only the current session, not all sessions. The `"revoke_all"` handler already handles revoking all sessions.
**Fix:**
```elixir
  def handle_event("revoke_current", %{"token" => encoded_token}, socket) do
    hashed_token = Base.url_decode64!(encoded_token)
    Auth.revoke_session(hashed_token)

    {:noreply, redirect(socket, to: ~p"/users/log_in")}
  end
```

### WR-06: `generate_user_session_token` Does Not Accept `type` Option

**File:** `priv/templates/sigra.install/conn_case_helpers.ex:54`
**Issue:** The `ConnCaseHelpers` template calls `generate_user_session_token(user, type: type)` with a `type:` keyword option, but the generated `generate_user_session_token/1` function in `auth.ex` template (line 231) only accepts a single argument (`user`) with no options. This will cause a `FunctionClauseError` when tests use `log_in_user/3` with a non-default `:type`.
**Fix:** Update the generated `generate_user_session_token` in `priv/templates/sigra.install/auth.ex` to accept options:
```elixir
  def generate_user_session_token(%<%= schema_alias %>{} = user, opts \\ []) do
    {token, user_token} = UserToken.build_session_token(user, opts)
    Repo.insert!(user_token)
    token
  end
```

## Info

### IN-01: Dual Telemetry Events in `register/3`

**File:** `lib/sigra/auth.ex:50-67`
**Issue:** The `register/3` function wraps the operation in `Telemetry.span/3` (which emits `:start` and `:stop` events) and also manually emits a `[:sigra, :auth, :register, :stop]` event on success (line 56). This results in duplicate `:stop` events for successful registrations. The manual event is redundant.
**Fix:** Remove the manual `Telemetry.event` call on line 56, as the span already emits the stop event.

### IN-02: Bare Rescue in Hammer Rate Limiter

**File:** `lib/sigra/rate_limiters/hammer.ex:34`
**Issue:** The `rescue _` clause catches all exceptions including unexpected ones (e.g., `ArgumentError` from a misconfigured module name). While the fail-open behavior is documented and intentional, a bare rescue makes it harder to diagnose configuration errors. Consider rescuing specific exceptions or logging the exception details.
**Fix:**
```elixir
    rescue
      e ->
        Logger.warning("[Sigra] Hammer rate limiter unavailable (#{inspect(e.__struct__)}), failing open")
        {:allow, 0}
```

### IN-03: `Sigra.Config` Schema Duplicated in Module Attribute and Moduledoc

**File:** `lib/sigra/config.ex:18-371` and `lib/sigra/config.ex:374-729`
**Issue:** The NimbleOptions schema is defined twice: once inline in the `@moduledoc` for documentation generation and once in `@schema` for runtime validation. While this works, any change to option defaults or types must be made in both places. Consider generating the moduledoc from the `@schema` attribute.
**Fix:** Move the `@schema` definition above the `@moduledoc` and reference it:
```elixir
  @schema [ ... ]  # single source of truth

  @moduledoc """
  ...
  #{NimbleOptions.docs(@schema)}
  """
```

### IN-04: TokenCleanup Worker Uses Wrong Queue

**File:** `lib/sigra/workers/token_cleanup.ex:21`
**Issue:** The `TokenCleanup` worker is assigned to `queue: :sigra_mailer`. Token cleanup is not email delivery -- it should use a dedicated queue or a general-purpose queue to avoid conflicting with email delivery concurrency limits.
**Fix:**
```elixir
  use Oban.Worker,
    queue: :sigra_maintenance,
    max_attempts: 1
```

---

_Reviewed: 2026-04-07T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
