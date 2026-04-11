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

      assert Repo.aggregate(UserSession, :count) == 1
      assert [session] = Repo.all(UserSession)
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

      # The raw_token from Sigra.SessionStores.Ecto.create/3 is
      # Base.url_encode64(raw_bytes, padding: false) — the stored
      # hashed_token is :crypto.hash(:sha256, raw_bytes). Round-trip via
      # url_decode64 + hash_token to match the canonical store's lookup.
      {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
      expected_hash = Sigra.Token.hash_token(raw_bytes)

      assert [session] = Repo.all(UserSession)
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

  describe "log_out_user/1" do
    test "deletes the user_sessions row", %{conn: conn, user: user} do
      logged_in_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      assert Repo.aggregate(UserSession, :count) == 1

      token = Plug.Conn.get_session(logged_in_conn, :user_token)

      _logged_out_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> UserAuth.log_out_user()

      assert Repo.aggregate(UserSession, :count) == 0
    end
  end
end
