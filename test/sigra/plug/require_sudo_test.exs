defmodule Sigra.Plug.RequireSudoTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireSudo

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
    test "returns opts with default sudo_window of 300 seconds" do
      opts = RequireSudo.init(@default_opts)
      assert opts[:sudo_window] == 300
    end

    test "accepts custom sudo_window" do
      opts = RequireSudo.init(@default_opts ++ [sudo_window: 600])
      assert opts[:sudo_window] == 600
    end
  end

  describe "call/2" do
    test "passes conn through when sudo window is fresh" do
      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.assign(:authenticated_at, DateTime.utc_now())
        |> RequireSudo.call(opts)

      refute conn.halted
    end

    test "halts conn when sudo window has expired" do
      opts = RequireSudo.init(@default_opts)

      stale_time = DateTime.add(DateTime.utc_now(), -600, :second)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.assign(:authenticated_at, stale_time)
        |> RequireSudo.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "stale_sudo"
    end

    test "halts conn when authenticated_at is missing" do
      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> RequireSudo.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "stale_sudo"
    end

    test "halts conn when current_scope is missing" do
      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> RequireSudo.call(opts)

      assert conn.halted
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(RequireSudo)
      assert function_exported?(RequireSudo, :init, 1)
      assert function_exported?(RequireSudo, :call, 2)
    end
  end
end
