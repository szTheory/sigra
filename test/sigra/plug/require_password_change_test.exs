defmodule Sigra.Plug.RequirePasswordChangeTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequirePasswordChange

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, _opts) do
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, "#{type}")
    end
  end

  @default_opts [error_handler: TestErrorHandler]

  describe "init/1" do
    test "returns opts unchanged" do
      opts = RequirePasswordChange.init(@default_opts)
      assert opts == @default_opts
    end
  end

  describe "call/2" do
    test "halts and calls error_handler when must_change_password is true" do
      opts = RequirePasswordChange.init(@default_opts)

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{user: %{must_change_password: true}})
        |> RequirePasswordChange.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "must_change_password"
    end

    test "passes through when must_change_password is false" do
      opts = RequirePasswordChange.init(@default_opts)

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{user: %{must_change_password: false}})
        |> RequirePasswordChange.call(opts)

      refute conn.halted
    end

    test "passes through when no current_scope assigned" do
      opts = RequirePasswordChange.init(@default_opts)

      conn =
        conn(:get, "/dashboard")
        |> RequirePasswordChange.call(opts)

      refute conn.halted
    end

    test "passes through when user struct lacks must_change_password field" do
      opts = RequirePasswordChange.init(@default_opts)

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{user: %{id: 1, email: "test@example.com"}})
        |> RequirePasswordChange.call(opts)

      refute conn.halted
    end

    test "passes through when must_change_password is nil" do
      opts = RequirePasswordChange.init(@default_opts)

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{user: %{must_change_password: nil}})
        |> RequirePasswordChange.call(opts)

      refute conn.halted
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(RequirePasswordChange)
      assert function_exported?(RequirePasswordChange, :init, 1)
      assert function_exported?(RequirePasswordChange, :call, 2)
    end
  end
end
