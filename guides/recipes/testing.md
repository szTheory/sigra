# Testing Auth Flows

Sigra ships a rich `Sigra.Testing` helper module and a generated `AuthFixtures` module with seven named scenario fixtures covering every documented auth state. This recipe shows how to use them for fast, AAA-style tests.

## Setup

In your generated `conn_case.ex` the helpers are already imported:

    using do
      quote do
        import Sigra.Testing
        import MyApp.AuthFixtures
        import MyAppWeb.ConnCase
      end
    end

If you need them in other test files, add:

    import Sigra.Testing
    import MyApp.AuthFixtures

## Scenario fixtures

The generated `AuthFixtures` module provides seven named fixtures — one per documented auth state — plus a `scenario/2` dispatcher for parametric tests. Each fixture returns exactly the data needed for that scenario, not a uniform map.

| Scenario | Function | Returns |
|----------|----------|---------|
| Anonymous | `anonymous_fixture/0` | `%{conn: build_conn()}` |
| Authenticated | `authenticated_fixture/1` | `%{user: user, session: session, conn: logged_in_conn}` |
| MFA pending | `mfa_pending_fixture/1` | `%{user: user, session: session, totp_secret: secret}` (no conn — pre-challenge) |
| MFA complete | `mfa_complete_fixture/1` | `%{user: user, session: session, conn: logged_in_conn, totp_secret: secret}` |
| Sudo | `sudo_fixture/1` | `%{user: user, session: session, conn: logged_in_conn}` |
| Locked | `locked_fixture/1` | `%{user: user}` (no conn — locked users can't log in) |
| Unconfirmed | `unconfirmed_fixture/1` | `%{user: user}` (no conn — email not yet confirmed) |

### Use a fixture directly

    test "authenticated user sees the dashboard" do
      %{conn: conn, user: user} = authenticated_fixture()

      conn = get(conn, ~p"/dashboard")
      assert html_response(conn, 200) =~ user.email
    end

    test "locked user cannot log in" do
      %{user: user} = locked_fixture()

      conn =
        post(build_conn(), ~p"/users/log-in", %{"user" => %{"email" => user.email, "password" => "password1234"}})

      assert get_flash(conn, :error) =~ "locked"
    end

### Parametric tests via `scenario/2`

    for state <- [:anonymous, :authenticated, :locked] do
      test "GET / renders for #{state}" do
        fixture = MyApp.AuthFixtures.scenario(unquote(state))
        conn = Map.get(fixture, :conn, build_conn())

        assert get(conn, ~p"/").status == 200
      end
    end

## Assertions

`Sigra.Testing` ships targeted assertion helpers:

- **`assert_password_hashed(user)`** — confirms `user.hashed_password` starts with `"$argon2id$"`.
- **`assert_email_sent(to:, subject:)`** — checks the Swoosh test mailbox for a matching email.
- **`assert_rate_limited(conn)`** — asserts a 429 response with `Retry-After` header.
- **`assert_mfa_enabled(user, backup_code_schema:)`** — user has a confirmed TOTP secret.
- **`assert_mfa_disabled(user, backup_code_schema:)`** — inverse.
- **`assert_token_revoked(config, token_id)`** — API token's `revoked_at` is non-nil.
- **`assert_scope_denied(conn)`** — API response is 403 and halted.
- **`assert_sessions_invalidated(repo, user)`** — no session tokens remain for the user.
- **`assert_password_changed(user)`** — `hashed_password` differs from a known baseline.
- **`assert_deletion_scheduled(user)`** — `deletion_scheduled_at` is set.
- **`assert_deletion_cancelled(user)`** — inverse.
- **`assert_account_deleted(repo, user_schema, user_id)`** — the user row is gone (or anonymized).
- **`assert_audit_event(expected, opts)`** — most recent audit row matches; supports metadata subset matching.

## MFA helpers

    test "MFA challenge succeeds with generated code" do
      %{user: user} = locked_fixture()  # reuse locked_fixture for the user, then unlock
      secret = Sigra.Testing.setup_totp(user, config: MyApp.Auth.sigra_config())

      code = Sigra.Testing.generate_totp_code(secret)

      assert {:ok, _} = Sigra.MFA.verify_totp(MyApp.Auth.sigra_config(), user, code)
    end

    test "bypass MFA when you don't care about the flow" do
      %{user: user, conn: conn} = mfa_complete_fixture()
      conn = Sigra.Testing.bypass_mfa(conn)

      assert get(conn, ~p"/settings").status == 200
    end

    test "trust-this-browser cookie is honored" do
      %{user: user, conn: conn} = mfa_complete_fixture()
      conn = Sigra.Testing.trust_browser(conn, user, config: MyApp.Auth.sigra_config())

      # Next login on same conn skips MFA challenge
      assert conn.resp_cookies[Sigra.MFA.Trust.cookie_name()]
    end

## API token helpers

    test "authenticated API request" do
      %{user: user} = authenticated_fixture()
      config = MyApp.Auth.sigra_config()
      {raw, _token} = Sigra.Testing.create_api_token(config, user, name: "CI", scopes: ["read:projects"])

      conn = build_conn() |> Sigra.Testing.put_bearer_token(raw) |> get(~p"/api/projects")
      assert json_response(conn, 200)
    end

    test "revoked token returns 401" do
      %{user: user} = authenticated_fixture()
      config = MyApp.Auth.sigra_config()
      {raw, token} = Sigra.Testing.create_api_token(config, user, name: "doomed")

      Sigra.Auth.revoke_api_token(config, token.id)

      conn = build_conn() |> Sigra.Testing.put_bearer_token(raw) |> get(~p"/api/projects")
      assert conn.status == 401
    end

## OAuth helpers

    test "OAuth callback creates a new user" do
      params = Sigra.Testing.mock_oauth_callback(provider: :google, email: "new@example.com")
      conn = get(build_conn(), ~p"/auth/google/callback", params)

      assert conn.assigns.current_scope.user.email == "new@example.com"
    end

## Email helpers

    test "extract and confirm reset token" do
      user = user_fixture()

      Accounts.deliver_user_reset_password_instructions(user, fn token -> "/reset/#{token}" end)
      Sigra.Testing.assert_email_sent(to: user.email, subject: "Reset")

      # Extract the token from the most recent mail body
      url = Swoosh.Adapters.Test.Storage.all() |> List.last() |> Map.get(:html_body)
      token = Sigra.Testing.extract_reset_token(url)

      assert is_binary(token)
    end

## Audit helpers

    test "login is audited" do
      %{user: user} = authenticated_fixture()

      Sigra.Testing.assert_audit_event(%{
        action: "auth.login.success",
        actor_id: user.id
      })
    end

    test "pre-seed an audit event for query tests" do
      user = user_fixture()

      Sigra.Testing.audit_event_fixture(
        repo: Repo,
        audit_schema: MyApp.AuditEvent,
        actor_id: user.id,
        action: "auth.login.success"
      )

      events = Sigra.Audit.query(MyApp.Auth.sigra_config(), actor_id: user.id) |> Repo.all()
      assert length(events) == 1
    end

## Pitfalls

- **Scenario fixtures return different keys.** Don't pattern-match expecting a uniform map; see the table above.
- **`locked_fixture` does not set a conn.** Locked users cannot log in — if you need a conn, use `authenticated_fixture` and call `simulate_lockout/3` after.
- **`setup_totp/2` requires a config.** The user's TOTP secret is stored via the configured repo; pass `config: MyApp.Auth.sigra_config()` every time.
- **Swoosh test mailbox is per-test-process.** Use `assert_email_sent/1` inside the same test that triggered delivery. For async background workers, configure the mailer to send synchronously in test env.

## Related

- [Getting Started](getting-started.html) — the flow these tests cover.
- [Registration](registration.html), [Login and Logout](login-and-logout.html), [MFA](mfa.html), [API Authentication](api-authentication.html) — each guide has a "Testing" section.
- `Sigra.Testing` — the full helper module (see HexDocs for every function).
