defmodule ExampleWeb.UserAuthTest do
  @moduledoc """
  B6 (Plan 10.1.1-03) — Locks the unification of the example app onto
  Sigra's canonical `user_sessions` store. Asserts that logging in writes
  to `user_sessions` (Sigra) and NOT to `user_tokens` with context='session'
  (legacy phx.gen.auth), and that fetch_current_scope / log_out_user round-trip
  through the canonical store.
  """
  use ExampleWeb.ConnCase, async: true

  import Ecto.Query

  alias Example.Accounts
  alias Example.Accounts.{UserSession, UserToken}
  alias Example.Repo
  alias ExampleWeb.UserAuth

  @moduletag :example_app

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "b6-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBattery123!"
      })

    %{user: user}
  end

  describe "log_in_user/3 (B6 canonical session store)" do
    test "writes a row to user_sessions (Sigra store)", %{conn: conn, user: user} do
      _conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      assert Repo.aggregate(from(s in UserSession, where: s.user_id == ^user.id), :count) == 1
      assert [session] = Repo.all(from(s in UserSession, where: s.user_id == ^user.id))
      assert session.user_id == user.id
    end

    test "does NOT write to user_tokens with context=session", %{conn: conn, user: user} do
      _conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      legacy_count =
        Repo.aggregate(from(t in UserToken, where: t.context == "session"), :count)

      assert legacy_count == 0
    end

    test "session cookie token hashes to the stored hashed_token",
         %{conn: conn, user: user} do
      logged_in_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      raw_token = Plug.Conn.get_session(logged_in_conn, :user_token)
      assert is_binary(raw_token)

      {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
      expected_hash = Sigra.Token.hash_token(raw_bytes)

      assert [session] = Repo.all(from(s in UserSession, where: s.user_id == ^user.id))
      assert session.hashed_token == expected_hash
    end

    test "fetch_current_scope assigns current_scope for a logged-in user",
         %{conn: conn, user: user} do
      logged_in_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      token = Plug.Conn.get_session(logged_in_conn, :user_token)

      new_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> UserAuth.fetch_current_scope([])

      assert new_conn.assigns.current_scope
      assert new_conn.assigns.current_scope.user.id == user.id
    end
  end

  describe "impersonation session lifecycle" do
    test "begin_impersonation preserves only the restore keys across session renewal", %{
      conn: conn,
      user: admin
    } do
      target = register_user!("target")
      admin_token = Accounts.generate_user_session_token(admin)
      impersonation_token = Accounts.generate_user_session_token(target)

      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_token: admin_token,
          user_return_to: "/users/settings",
          transient: "drop-me"
        })
        |> UserAuth.begin_impersonation(impersonation_token, admin_token,
          return_to: "/admin/users?q=restore"
        )

      assert get_session(conn, :user_token) == impersonation_token
      assert get_session(conn, :impersonator_user_token) == admin_token
      assert get_session(conn, :impersonation_return_to) == "/admin/users?q=restore"
      refute get_session(conn, :user_return_to)
      refute get_session(conn, :transient)
    end

    test "restore_impersonation rotates back to the preserved admin token and clears the restore keys",
         %{conn: conn, user: admin} do
      target = register_user!("target")
      admin_token = Accounts.generate_user_session_token(admin)
      impersonation_token = Accounts.generate_user_session_token(target)

      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: admin_token,
          impersonation_return_to: "/admin/users?q=restore",
          transient: "drop-me"
        })
        |> UserAuth.restore_impersonation()

      assert get_session(conn, :user_token) == admin_token
      refute get_session(conn, :impersonator_user_token)
      refute get_session(conn, :impersonation_return_to)
      refute get_session(conn, :transient)
    end

    test "fetch_current_scope expires timed-out impersonation sessions and restores the admin session when possible",
         %{user: admin} do
      target = register_user!("target")
      admin_token = Accounts.generate_user_session_token(admin)
      impersonation_token = expired_impersonation_token_for(target)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: admin_token,
          impersonation_return_to: "/admin/users?q=restore"
        })
        |> UserAuth.fetch_current_scope([])

      assert get_session(conn, :user_token) == admin_token
      refute get_session(conn, :impersonator_user_token)
      assert conn.assigns.current_scope.user.id == admin.id
      assert is_nil(conn.assigns.current_scope.impersonating_from)
    end

    test "fetch_current_scope fails closed when an expired impersonation session cannot restore the admin",
         %{user: admin} do
      target = register_user!("target")
      _admin_token = Accounts.generate_user_session_token(admin)
      impersonation_token = expired_impersonation_token_for(target)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{
          user_token: impersonation_token,
          impersonator_user_token: "not-a-real-token",
          impersonation_return_to: "/admin/users?q=restore"
        })
        |> UserAuth.fetch_current_scope([])

      refute get_session(conn, :user_token)
      refute get_session(conn, :impersonator_user_token)
      assert is_nil(conn.assigns.current_scope)
      assert is_nil(conn.private[:sigra_session])
    end
  end

  describe "log_out_user/1" do
    test "deletes the user_sessions row", %{conn: conn, user: user} do
      logged_in_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      assert Repo.aggregate(from(s in UserSession, where: s.user_id == ^user.id), :count) == 1

      token = Plug.Conn.get_session(logged_in_conn, :user_token)

      _logged_out_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> UserAuth.log_out_user()

      assert Repo.aggregate(from(s in UserSession, where: s.user_id == ^user.id), :count) == 0
    end
  end

  defp register_user!(prefix) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "#{prefix}-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBattery123!"
      })

    user
  end

  defp expired_impersonation_token_for(user) do
    raw_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
    expired_at = DateTime.add(DateTime.utc_now(), -3_600, :second)

    %UserSession{}
    |> Ecto.Changeset.change(%{
      user_id: user.id,
      hashed_token: Sigra.Token.hash_token(raw_bytes),
      type: "standard",
      ip: "127.0.0.1",
      user_agent: "ExUnit/1.0",
      inserted_at: expired_at,
      last_active_at: expired_at,
      sudo_at: nil
    })
    |> Repo.insert!()

    raw_token
  end
end
