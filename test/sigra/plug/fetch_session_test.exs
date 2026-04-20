defmodule Sigra.Plug.FetchSessionTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Mox

  alias Sigra.Plug.FetchSession

  setup :verify_on_exit!

  defmodule MockScopeModule do
    def new(user), do: %{user_id: user.id}
  end

  @default_config %Sigra.Config{
    repo: Sigra.MockRepo,
    user_schema: :unused,
    session: [
      store: Sigra.MockSessionStore,
      idle_timeout: 1_800,
      absolute_timeout: 86_400,
      activity_update_threshold: 300,
      remember_me_max_age: 5_184_000
    ]
  }

  @default_opts [
    config: @default_config,
    scope_module: MockScopeModule
  ]

  defp build_session(overrides \\ %{}) do
    now = DateTime.utc_now()

    defaults = %Sigra.Session{
      id: 1,
      user_id: 1,
      hashed_token: "hashed-token",
      type: :standard,
      last_active_at: now,
      inserted_at: now,
      sudo_at: nil
    }

    struct(defaults, overrides)
  end

  defp build_user do
    %{id: 1, email: "user@example.com"}
  end

  describe "init/1" do
    test "sets default cookie options including http_only, same_site, and secure" do
      opts = FetchSession.init(@default_opts)
      cookie_opts = opts[:cookie_opts]
      assert cookie_opts[:http_only] == true
      assert cookie_opts[:same_site] == "Lax"
      assert cookie_opts[:secure] == true
    end

    test "allows overriding cookie options" do
      opts = FetchSession.init(@default_opts ++ [cookie_opts: [secure: false]])
      assert opts[:cookie_opts][:secure] == false
    end
  end

  describe "call/2 — session fetch and scope assignment" do
    test "reads session token from Plug session and fetches via SessionStore" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:fetch, fn "valid-hashed-token", _opts -> {:ok, session} end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "valid-hashed-token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end

    test "assigns current_scope when session found and valid" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "some-token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end

    test "assigns nil when no token in session" do
      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end

    test "assigns nil when session store returns error" do
      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:error, :not_found} end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "bad-token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "call/2 — idle timeout" do
    test "does NOT assign current_scope when idle timeout exceeded" do
      # Session was last active 35 minutes ago (> 30 min default)
      stale_time = DateTime.add(DateTime.utc_now(), -2100, :second)
      session = build_session(%{last_active_at: stale_time})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)
      |> expect(:delete, fn _token, _opts -> :ok end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "call/2 — absolute timeout" do
    test "does NOT assign current_scope when absolute timeout exceeded" do
      # Session was created 25 hours ago (> 24h default)
      old_time = DateTime.add(DateTime.utc_now(), -90_000, :second)
      session = build_session(%{inserted_at: old_time, last_active_at: DateTime.utc_now()})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)
      |> expect(:delete, fn _token, _opts -> :ok end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "call/2 — remember-me sessions" do
    test "remember-me sessions skip idle timeout check" do
      # Last active 35 min ago would fail idle check for standard sessions
      stale_time = DateTime.add(DateTime.utc_now(), -2100, :second)
      session = build_session(%{type: :remember_me, last_active_at: stale_time})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)
      |> expect(:update_activity, fn _token, _meta, _opts -> :ok end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end

    test "remember-me sessions use remember_me_max_age as absolute timeout" do
      # Session created 61 days ago (> 60 day remember_me_max_age)
      old_time = DateTime.add(DateTime.utc_now(), -5_270_400, :second)
      session = build_session(%{type: :remember_me, inserted_at: old_time})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)
      |> expect(:delete, fn _token, _opts -> :ok end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "call/2 — activity update throttling" do
    test "calls update_activity when activity_update_threshold exceeded" do
      # Last active 6 minutes ago (> 5 min threshold)
      stale_time = DateTime.add(DateTime.utc_now(), -360, :second)
      session = build_session(%{last_active_at: stale_time})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)
      |> expect(:update_activity, fn _token, _meta, _opts -> :ok end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end

    test "does NOT call update_activity when threshold not yet reached" do
      # Last active 2 minutes ago (< 5 min threshold)
      recent_time = DateTime.add(DateTime.utc_now(), -120, :second)
      session = build_session(%{last_active_at: recent_time})

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)

      # No update_activity expectation — Mox will fail if called

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end
  end

  describe "call/2 — remember-me cookie rehydration" do
    test "rehydrates session from remember-me cookie when session cookie absent" do
      session = build_session(%{type: :remember_me})

      Sigra.MockSessionStore
      |> expect(:fetch, fn "remember-hashed-token", _opts -> {:ok, session} end)

      # Use a config with a remember_me_cookie name
      opts = FetchSession.init(@default_opts ++ [remember_me_cookie: "_test_remember_me"])

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> put_req_cookie("_test_remember_me", "remember-hashed-token")
        |> Plug.Conn.fetch_cookies()
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end
  end

  describe "call/2 — conn.private session storage" do
    test "assigns :sigra_session to conn.private for downstream access" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:fetch, fn _token, _opts -> {:ok, session} end)

      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "token"})
        |> FetchSession.call(opts)

      assert conn.private[:sigra_session] == session
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(FetchSession)
      assert function_exported?(FetchSession, :init, 1)
      assert function_exported?(FetchSession, :call, 2)
    end
  end
end
