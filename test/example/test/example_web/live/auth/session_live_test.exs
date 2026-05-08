defmodule ExampleWeb.Auth.SessionLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Example.Accounts
  alias Example.Accounts.AuditEvent
  alias Example.Accounts.UserSession
  alias Example.Repo

  describe "Phase 108 preserve-current session flow" do
    test "keeps the current session, revokes sibling sessions, and stays on the page", %{
      conn: conn
    } do
      user = user_fixture(%{email: "session-live@example.com"})
      sibling = session_fixture(user, %{ip: "10.20.30.40"})

      conn = log_in_user(conn, user)
      current_token = Plug.Conn.get_session(conn, :user_token)

      {:ok, view, html} = live(conn, "/users/sessions")

      assert html =~ "This device"
      assert html =~ "Log out of other devices"
      assert html =~ "Recent security activity"
      assert html =~ "Signed in"
      assert html =~ sibling.ip

      html = render_click(view, :revoke_others, %{})

      assert html =~ "Logged out of 1 other session."
      assert html =~ "Signed out of other devices"
      assert html =~ "This device"
      refute html =~ sibling.ip
      refute html =~ "session.revoke_others"
      assert Repo.get(UserSession, sibling.id) == nil
      assert Accounts.current_session_hashed_token(current_token)
    end

    test "shows a truthful no-op message when no sibling sessions exist", %{conn: conn} do
      user = user_fixture(%{email: "session-live-single@example.com"})
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, "/users/sessions")

      assert html =~ "This device"
      refute html =~ "Log out of other devices"

      html = render_click(view, :revoke_others, %{})

      assert html =~ "No other sessions were active."
      assert html =~ "This device"
    end

    test "fails closed when the current session can no longer be proven", %{conn: conn} do
      user = user_fixture(%{email: "session-live-fail@example.com"})
      sibling = session_fixture(user, %{ip: "10.99.0.2"})
      conn = log_in_user(conn, user)
      current_token = Plug.Conn.get_session(conn, :user_token)

      {:ok, view, _html} = live(conn, "/users/sessions")

      :ok = Accounts.delete_user_session_token(current_token)

      html = render_click(view, :revoke_others, %{})

      assert html =~ "verify the current session. No other sessions were revoked."
      assert Repo.get(UserSession, sibling.id)
    end

    test "renders suspicious-login activity with normalized labels and bounded metadata", %{
      conn: conn
    } do
      user = user_fixture(%{email: "session-live-suspicious@example.com"})
      conn = log_in_user(conn, user)
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      Repo.insert!(%AuditEvent{
        action: "security.suspicious_login",
        actor_id: user.id,
        actor_type: "user",
        target_id: user.id,
        target_type: "user",
        effective_user_id: user.id,
        outcome: "failure",
        ip_address: "9.9.9.9",
        metadata: %{"geo_city" => "Berlin", "geo_country_code" => "DE"},
        occurred_at: now,
        inserted_at: now
      })

      {:ok, _view, html} = live(conn, "/users/sessions")

      assert html =~ "Recent security activity"
      assert html =~ "Suspicious sign-in attempt"
      assert html =~ "Failed"
      assert html =~ "9.9.9.9"
      assert html =~ "Berlin, DE"
      refute html =~ "security.suspicious_login"
    end
  end
end
