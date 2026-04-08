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
    test "reads session from conn.private[:sigra_session] and checks sudo_at" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        sudo_at: DateTime.utc_now()
      }

      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireSudo.call(opts)

      refute conn.halted
    end

    test "passes when sudo_at is within sudo_timeout (5 min default)" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        sudo_at: DateTime.add(DateTime.utc_now(), -120, :second)
      }

      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireSudo.call(opts)

      refute conn.halted
    end

    test "calls error_handler with :stale_sudo when sudo_at is expired" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        sudo_at: DateTime.add(DateTime.utc_now(), -600, :second)
      }

      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireSudo.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "stale_sudo"
    end

    test "calls error_handler with :stale_sudo when sudo_at is nil" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        sudo_at: nil
      }

      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> Plug.Conn.assign(:current_scope, %{user_id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireSudo.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "stale_sudo"
    end

    test "calls error_handler with :unauthenticated when no current_scope" do
      opts = RequireSudo.init(@default_opts)

      conn =
        conn(:get, "/admin/settings")
        |> RequireSudo.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "unauthenticated"
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
