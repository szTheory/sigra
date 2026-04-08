defmodule Sigra.Plug.RequireScopesTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireScopes

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      body =
        case type do
          :insufficient_scope ->
            required = Keyword.get(opts, :required_scopes, [])
            provided = Keyword.get(opts, :provided_scopes, [])
            "insufficient_scope:required=#{inspect(required)},provided=#{inspect(provided)}"

          other ->
            "#{other}"
        end

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, body)
    end
  end

  describe "init/1" do
    test "returns opts with scopes and error_handler" do
      opts = RequireScopes.init(scopes: ["profile:read"], error_handler: TestErrorHandler)
      assert opts[:scopes] == ["profile:read"]
      assert opts[:error_handler] == TestErrorHandler
    end

    test "raises when scopes is empty" do
      assert_raise ArgumentError, ~r/non-empty list/, fn ->
        RequireScopes.init(scopes: [], error_handler: TestErrorHandler)
      end
    end

    test "raises when scopes is missing" do
      assert_raise KeyError, fn ->
        RequireScopes.init(error_handler: TestErrorHandler)
      end
    end

    test "raises when error_handler is missing" do
      assert_raise KeyError, fn ->
        RequireScopes.init(scopes: ["profile:read"])
      end
    end
  end

  describe "call/2 - session auth bypass" do
    test "passes conn through when auth_method is :session" do
      opts = RequireScopes.init(scopes: ["profile:read"], error_handler: TestErrorHandler)

      scope = %{auth_method: :session, token_scopes: []}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 - scope enforcement" do
    test "passes when token has all required scopes (AND mode)" do
      opts = RequireScopes.init(scopes: ["profile:read", "sessions:read"], error_handler: TestErrorHandler)

      scope = %{auth_method: :api_token, token_scopes: ["profile:read", "sessions:read", "mfa:read"]}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end

    test "passes when token has any required scope (OR mode)" do
      opts = RequireScopes.init(scopes: ["profile:read", "sessions:read"], error_handler: TestErrorHandler, match: :any)

      scope = %{auth_method: :api_token, token_scopes: ["profile:read"]}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end

    test "passes when token has wildcard * scope" do
      opts = RequireScopes.init(scopes: ["profile:read"], error_handler: TestErrorHandler)

      scope = %{auth_method: :api_token, token_scopes: ["*"]}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      refute conn.halted
    end

    test "calls error_handler with :insufficient_scope when scopes missing" do
      opts = RequireScopes.init(scopes: ["sessions:write"], error_handler: TestErrorHandler)

      scope = %{auth_method: :api_token, token_scopes: ["profile:read"]}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body =~ "insufficient_scope"
      assert conn.resp_body =~ "sessions:write"
      assert conn.resp_body =~ "profile:read"
    end

    test "includes required_scopes and provided_scopes in opts" do
      opts = RequireScopes.init(scopes: ["sessions:write"], error_handler: TestErrorHandler)

      scope = %{auth_method: :api_token, token_scopes: ["profile:read"]}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.assign(:current_scope, scope)
        |> RequireScopes.call(opts)

      assert conn.resp_body =~ ~s(required=["sessions:write"])
      assert conn.resp_body =~ ~s(provided=["profile:read"])
    end
  end

  describe "call/2 - unauthenticated" do
    test "calls error_handler with :unauthenticated when no current_scope" do
      opts = RequireScopes.init(scopes: ["profile:read"], error_handler: TestErrorHandler)

      conn =
        conn(:get, "/api/resource")
        |> RequireScopes.call(opts)

      assert conn.halted
      assert conn.resp_body == "unauthenticated"
    end
  end
end
