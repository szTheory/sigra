# Login and Logout

Sigra uses database-backed session tokens (not stateful JWTs for sessions). A login creates a session row, writes a reference to the Phoenix session cookie, and optionally sets a long-lived remember-me cookie. Logout clears the cookies and records an explicit owner-initiated `auth.logout` audit event so the recent security activity surface can distinguish "you signed out" from generic session revocation. This guide covers the flow, remember-me, session renewal, revoking other sessions, and logout-everywhere.

## What Sigra gives you

- **`MyAppWeb.UserAuth.log_in_user/3`** — creates a session token, renews the session ID (defeats session fixation), sets the remember-me cookie when requested, and redirects.
- **`MyAppWeb.UserAuth.log_out_user/1`** — deletes the token from the database, renews the session, clears the remember-me cookie, and redirects.
- **`MyAppWeb.UserAuth.fetch_current_scope/2`** — plug that reads the session/remember-me cookie on every request and assigns `:current_scope` to the conn.
- **`MyApp.Accounts.get_user_by_email_and_password/2`** — enumeration-safe lookup; returns `nil` for both wrong password and unknown email.
- **`MyApp.Accounts.delete_user_session_token/1`** — deletes a single session token.
- **`MyApp.Accounts.log_out_user_session_token/3`** — logs out the current session with truthful voluntary-logout audit semantics.
- **`MyApp.Accounts.revoke_other_sessions/2`** — revokes sibling sessions while keeping the current device signed in.
- **`MyApp.Accounts.delete_all_user_session_tokens/1`** — the "log out everywhere" primitive.
- **Recent security activity on `/users/sessions`** — shows recent sign-ins, suspicious-login outcomes, and session changes sourced from Sigra-owned persisted truth. It does not claim timeout-expiry history.

## Happy path

The generated `SessionController.create/2` (or its LiveView equivalent) calls:

    def create(conn, %{"user" => %{"email" => email, "password" => password} = params}) do
      case Accounts.get_user_by_email_and_password(email, password) do
        %User{} = user ->
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, params)

        nil ->
          conn
          |> put_flash(:error, "Invalid email or password")
          |> redirect(to: ~p"/users/log-in")
      end
    end

`log_in_user/3` does four things:

1. Generates a 32-byte random token, stores its SHA-256 hash in `users_tokens` with `context: "session"`.
2. Calls `Plug.Conn.configure_session(renew: true)` to rotate the Phoenix session ID.
3. Writes the raw token to the Phoenix session under `:user_token`.
4. If `params["user"]["remember_me"] == "true"`, sets the signed remember-me cookie with the same token.

## Remember-me

The remember-me cookie is **signed** (not encrypted) by Phoenix and contains the same token that's in the Phoenix session. Sigra reads it in `fetch_current_scope/2` on the next visit:

    defp ensure_user_token(conn) do
      if token = get_session(conn, :user_token) do
        {token, conn}
      else
        conn = fetch_cookies(conn, signed: [@remember_me_cookie])

        if token = conn.cookies[@remember_me_cookie] do
          {token, put_session(conn, :user_token, token)}
        else
          {nil, conn}
        end
      end
    end

If the Phoenix session cookie expires (browser close), the remember-me cookie rehydrates it. The session token itself is a DB row, so you can invalidate it server-side at any time.

### Configuration

    # config/config.exs
    config :my_app, MyApp.Auth.Config,
      session_ttl: 5_184_000  # 60 days in seconds (default)

Remember-me cookie options — `:max_age`, `:same_site`, `:http_only`, `:secure`, `:sign` — live in `lib/my_app_web/user_auth.ex`. In production the `:secure` flag is automatically enabled and the `:domain` is read from `Sigra.Config.cookie_domain` at runtime (see [Subdomain Authentication](subdomain-auth.html)).

## Session renewal

`UserAuth.log_in_user/3` always calls `renew_session/1` before writing the new token. This prevents session-fixation attacks where an attacker sets a known session ID on the victim, waits for them to authenticate, then uses that same ID.

You should also call `renew_session/1` after any privilege change — for example, after confirming sudo mode or completing MFA:

    conn
    |> UserAuth.renew_session()
    |> put_session(:user_token, new_token)

## Logout

The generator adds a `DELETE /users/log-out` route to the authenticated pipeline. It dispatches to:

    def log_out_user(conn) do
      user_token = get_session(conn, :user_token)
      current_user = conn.assigns.current_scope.user
      user_token && Accounts.log_out_user_session_token(user_token, current_user)

      conn
      |> renew_session()
      |> delete_resp_cookie(@remember_me_cookie)
      |> redirect(to: ~p"/")
    end

Three things happen:

1. The DB row is deleted through a logout-specific helper that records `auth.logout` instead of falling back to a generic session-revoke label.
2. The Phoenix session ID is rotated.
3. The remember-me cookie is cleared.

## Revoke other sessions

For an account-security page that should keep the current device signed in, call the preserve-current primitive instead of the destructive revoke-all flow:

    def delete_other_sessions(conn, _params) do
      user = conn.assigns.current_scope.user
      current_token = get_session(conn, :user_token)
      current_hashed_token = Accounts.current_session_hashed_token(current_token)

      case Accounts.revoke_other_sessions(user, current_hashed_token) do
        {:ok, 0} ->
          conn |> put_flash(:info, "No other sessions were active.") |> redirect(to: ~p"/users/sessions")

        {:ok, count} ->
          conn |> put_flash(:info, "Logged out of #{count} other sessions.") |> redirect(to: ~p"/users/sessions")

        {:error, :current_session_not_found} ->
          conn |> put_flash(:error, "Couldn't verify the current session.") |> redirect(to: ~p"/users/sessions")
      end
    end

`Sigra.Auth.revoke_other_sessions/3` validates that the supplied current session actually belongs to the user before revoking anything. If that proof fails, Sigra revokes nothing and returns `{:error, :current_session_not_found}`.

The generated `/users/sessions` page refreshes both the active-session list and the recent security activity feed after a preserve-current revoke, so users immediately see a `Signed out of other devices` activity row beside the remaining current session truth.

## Log out everywhere

For a "log out of all devices" button (common on account security pages), call:

    def delete_all_sessions(conn, _params) do
      user = conn.assigns.current_scope.user
      Accounts.delete_all_user_session_tokens(user)

      conn
      |> UserAuth.log_out_user()
      |> put_flash(:info, "Logged out of all devices.")
    end

`delete_all_user_session_tokens/1` issues a single `delete_all` against `users_tokens` for that user, context `"session"`. Every session — on every device, including the current one — is invalidated.

## Protecting routes

In `lib/my_app_web/router.ex`:

    pipeline :require_authenticated_user do
      plug :fetch_session
      plug :fetch_current_scope
      plug :require_authenticated_user
    end

    scope "/", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :authenticated,
        on_mount: [{MyAppWeb.UserAuth, :require_authenticated}] do
        live "/dashboard", DashboardLive
      end
    end

`require_authenticated_user/2` redirects unauthenticated requests to `/users/log-in` and stores the original path in the session so the user lands back where they started after login.

## Testing

    setup do
      %{user: user, conn: conn} = Sigra.Testing.authenticated_fixture()
      %{user: user, conn: conn}
    end

    test "shows dashboard when logged in", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")
      assert html_response(conn, 200) =~ "Dashboard"
    end

    test "log-out clears the session", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end

## Related

- [Getting Started](getting-started.html) — the end-to-end walkthrough.
- [Password Reset](password-reset.html) — password reset invalidates all sessions.
- [Subdomain Authentication](subdomain-auth.html) — sharing cookies across subdomains.
- [MFA](mfa.html) — adding a second factor to the login flow.
- `Sigra.Auth` — `create_session/4`, `delete_session/3`, `revoke_other_sessions/3`, `delete_all_sessions/3`.
