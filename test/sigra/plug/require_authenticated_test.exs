defmodule Sigra.Plug.RequireAuthenticatedTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireAuthenticated

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, _opts) do
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(401, "#{type}")
    end
  end

  @default_opts [error_handler: TestErrorHandler]

  describe "init/1" do
    test "returns opts with error_handler" do
      opts = RequireAuthenticated.init(@default_opts)
      assert opts[:error_handler] == TestErrorHandler
    end
  end

  describe "call/2" do
    test "passes conn through when current_scope is present" do
      opts = RequireAuthenticated.init(@default_opts)

      conn =
        conn(:get, "/protected")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> RequireAuthenticated.call(opts)

      refute conn.halted
    end

    test "halts conn when current_scope is nil" do
      opts = RequireAuthenticated.init(@default_opts)

      conn =
        conn(:get, "/protected")
        |> RequireAuthenticated.call(opts)

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "unauthenticated"
    end

    test "calls error_handler.auth_error with :unauthenticated" do
      opts = RequireAuthenticated.init(@default_opts)

      conn =
        conn(:get, "/protected")
        |> RequireAuthenticated.call(opts)

      assert conn.resp_body == "unauthenticated"
    end
  end
end
