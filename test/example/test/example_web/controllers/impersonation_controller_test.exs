defmodule ExampleWeb.ImpersonationControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Repo
  alias Example.Accounts.UserSession

  @moduletag :example_app

  describe "start impersonation" do
    test "POST /admin/users/:id/impersonation requires sudo", %{conn: conn} do
      admin = platform_admin_fixture()
      target = user_fixture()

      conn =
        conn
        |> log_in_user(admin)
        |> post("/admin/users/#{target.id}/impersonation", %{
          "return_to" => "/admin/users?from=index"
        })

      assert redirected_to(conn) ==
               "/users/sudo?return_to=%2Fadmin%2Fusers%2F#{target.id}%2Fimpersonation%3Freturn_to%3D%252Fadmin%252Fusers%253Ffrom%253Dindex"
    end

    test "POST /admin/users/:id/impersonation rotates to the impersonated session", %{conn: conn} do
      admin = platform_admin_fixture()
      target = user_fixture()

      conn =
        conn
        |> log_in_with_sudo(admin)
        |> post("/admin/users/#{target.id}/impersonation", %{
          "return_to" => "/admin/users?q=target"
        })

      assert redirected_to(conn) == "/"

      impersonation_token = get_session(conn, :user_token)
      admin_token = get_session(conn, :impersonator_user_token)

      assert is_binary(impersonation_token)
      assert is_binary(admin_token)
      refute impersonation_token == admin_token
      assert get_session(conn, :impersonation_return_to) == "/admin/users?q=target"

      authed_conn =
        conn
        |> recycle()
        |> get("/")

      assert authed_conn.assigns.current_scope.user.id == target.id
      assert authed_conn.assigns.current_scope.impersonating_from.id == admin.id
    end

    test "POST /admin/organizations/:org/users/:id/impersonation rejects out-of-scope targets and preserves the admin session",
         %{conn: conn} do
      admin = org_admin_fixture()
      allowed_org = create_organization(%{name: "Allowed Org", slug: "allowed-org"})
      other_org = create_organization(%{name: "Other Org", slug: "other-org"})
      _membership = create_membership(admin, allowed_org, :admin)
      target = user_fixture()
      _target_membership = create_membership(target, other_org, :member)

      conn =
        conn
        |> log_in_with_sudo(admin)
        |> post("/admin/organizations/#{allowed_org.slug}/users/#{target.id}/impersonation")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "organization admin scope"
      assert conn.assigns.current_scope.user.id == admin.id
      assert is_nil(conn.assigns.current_scope.impersonating_from)
    end

    test "POST /admin/users/:id/impersonation rejects nested impersonation and leaves the original admin restorable",
         %{conn: conn} do
      admin = platform_admin_fixture()
      target = user_fixture()
      other_target = user_fixture()
      admin_token = session_token_for(admin)
      impersonation_token = impersonation_token_for(target)

      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: admin_token,
          impersonation_return_to: "/admin/users?q=restore"
        })
        |> post("/admin/users/#{other_target.id}/impersonation")

      # An authenticated-but-non-admin impersonation token hits insufficient_scope.
      # The error handler redirects authenticated users to /app (principle of least
      # surprise — avoids a raw 403 dead-end for users who have a live session).
      assert conn.status in [302, 403]

      follow_up =
        conn
        |> recycle()
        |> get("/")

      assert follow_up.assigns.current_scope.user.id == target.id
      assert follow_up.assigns.current_scope.impersonating_from.id == admin.id
      assert get_session(conn, :impersonator_user_token) == admin_token
    end
  end

  describe "stop impersonation" do
    test "DELETE /impersonation restores the preserved admin session, sanitizes return_to, and is reachable outside admin routes",
         %{conn: conn} do
      admin = platform_admin_fixture()
      target = user_fixture()
      admin_token = session_token_for(admin)
      impersonation_token = impersonation_token_for(target)

      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: admin_token,
          impersonation_return_to: "/admin/users?q=restore"
        })
        |> delete("/impersonation", %{"return_to" => "https://evil.test/phish"})

      assert redirected_to(conn) == "/admin/users?q=restore"
      assert get_session(conn, :user_token) == admin_token
      refute get_session(conn, :impersonator_user_token)
      refute get_session(conn, :impersonation_return_to)

      follow_up =
        conn
        |> recycle()
        |> get("/")

      assert follow_up.assigns.current_scope.user.id == admin.id
      assert is_nil(follow_up.assigns.current_scope.impersonating_from)
    end

    test "DELETE /impersonation when no impersonation is active is a safe no-op redirect, not a crash",
         %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> delete("/impersonation")

      # The caller was never impersonating, so the response falls back to a
      # safe public redirect target rather than raising or leaking state.
      assert conn.status in [302, 303]

      # Session token remains the user's own; no impersonator_user_token is
      # set because there was none to restore.
      refute get_session(conn, :impersonator_user_token)

      follow_up =
        conn
        |> recycle()
        |> get("/")

      assert follow_up.assigns.current_scope.user.id == user.id
      assert is_nil(follow_up.assigns.current_scope.impersonating_from)
    end
  end

  describe "direct-path negative cases (Phase 31 D-13/D-15)" do
    test "POST /admin/users/:id/impersonation without any session redirects to log in",
         %{conn: conn} do
      target = user_fixture()

      conn = post(conn, "/admin/users/#{target.id}/impersonation")

      # Unauthenticated impersonation attempts must not succeed. They should
      # redirect to log in or the sudo gate rather than ever creating a
      # session token for the target.
      assert conn.status in [302, 303]
      refute get_session(conn, :user_token)
      refute get_session(conn, :impersonator_user_token)
    end

    test "POST /admin/users/:id/impersonation as a non-admin is rejected and does not rotate sessions",
         %{conn: conn} do
      non_admin = user_fixture()
      target = user_fixture()

      original_token_conn = log_in_with_sudo(conn, non_admin)
      original_token = get_session(original_token_conn, :user_token)

      conn =
        original_token_conn
        |> post("/admin/users/#{target.id}/impersonation")

      # Authenticated non-admin users hit insufficient_scope; the error handler
      # redirects them to /app rather than returning a raw 403 dead-end.
      assert conn.status in [302, 403, 404]
      # The non-admin's existing session is untouched.
      assert get_session(conn, :user_token) == original_token
      refute get_session(conn, :impersonator_user_token)
    end

    test "POST /admin/users/:id/impersonation with explicit return_to carries the admin context forward on success",
         %{conn: conn} do
      admin = platform_admin_fixture()
      target = user_fixture()

      conn =
        conn
        |> log_in_with_sudo(admin)
        |> post("/admin/users/#{target.id}/impersonation", %{
          "return_to" => "/admin/organizations/allowed/users?q=foo"
        })

      # The saved return_to is preserved exactly so the dedicated stop flow
      # can return to the originating admin context rather than a default.
      assert get_session(conn, :impersonation_return_to) ==
               "/admin/organizations/allowed/users?q=foo"

      # The admin's original token is preserved alongside a fresh impersonation token.
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :impersonator_user_token) != nil

      refute get_session(conn, :user_token) == get_session(conn, :impersonator_user_token)
    end
  end

  defp log_in_with_sudo(conn, user) do
    conn = log_in_user(conn, user)
    token = get_session(conn, :user_token)
    {_, session} = Example.Accounts.get_user_and_session_by_token(token)

    Example.Accounts.UserSession
    |> Repo.get_by!(hashed_token: session.hashed_token)
    |> Ecto.Changeset.change(sudo_at: DateTime.utc_now())
    |> Repo.update!()

    conn
  end

  defp session_token_for(user) do
    Example.Accounts.generate_user_session_token(user)
  end

  defp impersonation_token_for(user) do
    raw_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
    now = DateTime.utc_now()

    %UserSession{}
    |> Ecto.Changeset.change(%{
      user_id: user.id,
      hashed_token: Sigra.Token.hash_token(raw_bytes),
      type: "standard",
      ip: "127.0.0.1",
      user_agent: "ExUnit/1.0",
      inserted_at: now,
      last_active_at: now,
      sudo_at: nil
    })
    |> Repo.insert!()

    raw_token
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp org_admin_fixture do
    user_fixture(%{
      email: "org-admin+#{System.unique_integer([:positive])}@example.com"
    })
  end
end
