# Password Reset

Sigra's password reset flow uses a one-time, HMAC-signed token with a 60-minute TTL. The user requests a reset, clicks an email link, sets a new password, and every one of their existing sessions is invalidated. This guide covers the full lifecycle.

## What Sigra gives you

- **`MyAppWeb.ResetPasswordLive`** — two LiveViews: one for "request a reset" and one for "enter your new password."
- **`MyApp.Accounts.deliver_user_reset_password_instructions/2`** — generates a reset token, stores its hash in `auth.user_tokens` on Postgres installs, sends the email.
- **`MyApp.Accounts.get_user_by_reset_password_token/1`** — verifies the token (HMAC, hash lookup, TTL) and returns the user.
- **`MyApp.Accounts.reset_user_password/2`** — updates the password, deletes the reset token, and invalidates every session and token for that user.
- **`Sigra.Auth.request_password_reset/3`** — library primitive. For an address with no account it returns `{:ok, :sent}`; for an account it returns the signed token and URL. The generated `deliver_user_reset_password_instructions/2` normalizes both to `{:ok, :sent}`, or returns `{:error, :rate_limited}` when the configured limiter denies the request.
- **`Sigra.Auth.reset_password/4`** — library primitive. Verifies the HMAC, looks up the token by hash, and enforces the configured reset TTL (60 minutes by default).

## Happy path

### Step 1: Request a reset

The generated `ResetPasswordLive` renders a form with one field: email. Submitting it calls:

    def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
      # The context looks the account up itself and returns {:ok, :sent} for an
      # unknown address, so the view passes the submitted email and does not branch.
      _ =
        Accounts.deliver_user_reset_password_instructions(
          email,
          &url(~p"/users/reset-password/#{&1}")
        )

      # Same flash message whether or not the email exists
      {:noreply,
       socket
       |> put_flash(:info, "If your email is in our system, you will receive reset instructions shortly.")
       |> redirect(to: ~p"/users/log_in")}
    end

The generated LiveView and controller both pass the submitted email string to the context. The context checks its configured email limiter before looking up the address, then normalizes the result before returning to the request page. The generated-host install smoke submits an existing and an unknown address and checks the same redirect and flash, plus token creation only for the existing account.

`deliver_user_reset_password_instructions/2` generates a 32-byte random token, signs its hash with HMAC using your app's `secret_key_base`, stores the row in `auth.user_tokens` with `context: "reset_password"`, and renders the email template.

**Recommendation:** render the same flash message whether the email exists or not, so the form does not tell a visitor which addresses have an account.

**Scope of this claim:** the example app compares status, redirect, flash, and page for one request; a generated-host smoke checks the same redirect and flash plus the token-count result. When configured, the email limiter checks a normalized email key before account lookup, so a denied request returns the same `:rate_limited` result for an existing or unknown address. The limiter is disabled by default. These checks do not establish timing equivalence, the production limiter's behavior, or parity of internal library results when a request is allowed.

### Step 2: Click the email link

The email body contains a URL like:

    https://myapp.com/users/reset-password/SFMyNTY.g2gDbQ...

The visible portion after `/users/reset-password/` is the HMAC-signed token. When the user clicks it, `ResetPasswordLive` (mounted for `:edit`) calls:

    def mount(%{"token" => token}, _session, socket) do
      socket = assign(socket, token: token)

      case Accounts.get_user_by_reset_password_token(token) do
        %User{} = user ->
          {:ok, assign(socket, user: user, form: to_form(Accounts.change_user_password(user)))}

        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Reset password link is invalid or it has expired.")
           |> redirect(to: ~p"/")}
      end
    end

`get_user_by_reset_password_token/1` verifies:

1. The HMAC signature (rejects tampered tokens).
2. The hash exists in `auth.user_tokens` (rejects fabricated or already-used tokens).
3. `inserted_at + configured TTL > now` (60 minutes by default; rejects expired tokens).

The signature rejects tampering, the stored hash rejects fabricated or consumed tokens, and the TTL rejects expired links. These checks do not establish timing equivalence for reset requests.

### Step 3: Enter new password

The LiveView renders the new-password form. Submitting calls:

    def handle_event("reset", %{"user" => user_params}, socket) do
      case Accounts.reset_user_password(socket.assigns.user, user_params) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password reset successfully.")
           |> redirect(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

Inside `reset_user_password/2`:

    def reset_user_password(user, attrs) do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
      |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
      |> Repo.transact()
      |> case do
        {:ok, %{user: user}} -> {:ok, user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    end

Note: `by_user_and_contexts_query(user, :all)` deletes **every** token for that user — all sessions (including the current one on other devices), all remember-me cookies, all pending confirmation tokens, all magic links. The user must log in fresh on every device.

## TTL configuration

The reset token TTL is 60 minutes by default. To change it:

    # config/config.exs
    config :my_app, :sigra_config,
      token_ttl: [reset_password: 30 * 60]  # 30 minutes, in seconds

Shorter is safer (smaller attack window) but worsens UX if the email is delayed.

## Rate limiting

Reset requests are a common enumeration vector and an email-bomb vector. Generated account helpers read the limiter and reset-request settings from `:sigra_config`:

    config :my_app, :sigra_config,
      rate_limiting: [limiter: Sigra.RateLimiters.Hammer],
      reset: [max_requests: 3, window_seconds: 60]

    config :sigra, :hammer_module, MyApp.RateLimit

The host must add the optional `:hammer` dependency, define and supervise the Hammer module, or supply its own module implementing `Sigra.RateLimiter`. `nil` (the default) disables rate limiting.

With this config, the fourth request for the same normalized email within 60 seconds is throttled before account lookup. A denied request returns `{:error, :rate_limited}` for both registered and unknown addresses, and does not enqueue a reset email. The same settings are available for magic links under `magic_link: [max_requests: 3, window_seconds: 900]`. When the limiter allows a request, internal library results and timing are not identical for registered and unknown addresses; the generated page normalizes the user-facing response. Timing equivalence is not established.

## Why all sessions are invalidated

When a password is reset, Sigra assumes the user forgot it (best case) or that an attacker had access (worst case). In both cases, every existing session must be invalidated:

- Any other device still logged in could be the attacker.
- Any lingering remember-me cookie must stop working.
- Any pending magic-link or confirmation token should be revoked.

The `delete_all` on `auth.user_tokens` handles all of this in one query.

## Testing

    test "delivers reset email" do
      user = Sigra.Testing.user_fixture()

      Accounts.deliver_user_reset_password_instructions(user.email, &"/reset/#{&1}")

      Sigra.Testing.assert_email_sent(to: user.email, subject: "Reset")
    end

    test "resets password and invalidates sessions" do
      %{user: user, conn: _conn} = Sigra.Testing.authenticated_fixture()
      {:ok, %{to_reset: token}} = Sigra.Auth.request_password_reset(Repo, user.email, user_token_schema: UserToken)

      assert {:ok, updated} = Accounts.reset_user_password(user, %{"password" => "brandnewpw1234"})
      Sigra.Testing.assert_sessions_invalidated(Repo, updated)
    end

## Related

- [Login and Logout](login-and-logout.html) — session token lifecycle.
- [Account Lifecycle](account-lifecycle.html) — change password without a reset token.
- [Audit Logging](audit-logging.html) — reset attempts are logged as `auth.password_reset_request` and `auth.password_reset.success|failure`.
- `Sigra.Auth.request_password_reset/3` and `Sigra.Auth.reset_password/4` — library primitives.
