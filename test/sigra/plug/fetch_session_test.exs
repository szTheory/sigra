defmodule Sigra.Plug.FetchSessionTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.FetchSession

  defmodule MockSessionStore do
    def fetch("valid-token", _opts), do: {:ok, %{id: 1}}
    def fetch("expired-token", _opts), do: {:error, :expired}
    def fetch(_, _opts), do: {:error, :not_found}
  end

  defmodule MockScopeModule do
    def new(user), do: %{user_id: user.id}
  end

  @default_opts [session_store: MockSessionStore, scope_module: MockScopeModule]

  describe "init/1" do
    test "returns opts unchanged" do
      opts = FetchSession.init(@default_opts)
      assert opts[:session_store] == MockSessionStore
      assert opts[:scope_module] == MockScopeModule
    end
  end

  describe "call/2" do
    test "assigns current_scope from session store when token is present" do
      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "valid-token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 1}
    end

    test "assigns current_scope as nil when no token in session" do
      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
    end

    test "assigns current_scope as nil when session store returns error" do
      opts = FetchSession.init(@default_opts)

      conn =
        conn(:get, "/")
        |> init_test_session(%{user_token: "expired-token"})
        |> FetchSession.call(opts)

      assert conn.assigns[:current_scope] == nil
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
