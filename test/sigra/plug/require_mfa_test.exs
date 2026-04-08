defmodule Sigra.Plug.RequireMFATest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireMFA

  @moduletag :phase6

  describe "init/1" do
    test "sets default mfa_path to /users/mfa" do
      opts = RequireMFA.init([])
      assert opts[:mfa_path] == "/users/mfa"
    end

    test "accepts custom mfa_path" do
      opts = RequireMFA.init(mfa_path: "/auth/mfa")
      assert opts[:mfa_path] == "/auth/mfa"
    end
  end

  describe "call/2 with :mfa_pending session" do
    test "redirects to mfa_path and halts" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :mfa_pending
      }

      opts = RequireMFA.init([])

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      assert conn.halted
      assert Plug.Conn.get_resp_header(conn, "location") == ["/users/mfa"]
      assert conn.status == 302
    end

    test "allows access to the mfa_path itself" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :mfa_pending
      }

      opts = RequireMFA.init([])

      conn =
        conn(:get, "/users/mfa")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      refute conn.halted
    end

    test "allows access to /users/log_out for pending sessions" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :mfa_pending
      }

      opts = RequireMFA.init([])

      conn =
        conn(:post, "/users/log_out")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      refute conn.halted
    end

    test "respects custom mfa_path for allowlist" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :mfa_pending
      }

      opts = RequireMFA.init(mfa_path: "/auth/mfa")

      conn =
        conn(:get, "/auth/mfa")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 with :standard session" do
    test "passes through" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :standard
      }

      opts = RequireMFA.init([])

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 with :remember_me session" do
    test "passes through" do
      session = %Sigra.Session{
        id: 1,
        user_id: 1,
        hashed_token: "token",
        type: :remember_me
      }

      opts = RequireMFA.init([])

      conn =
        conn(:get, "/dashboard")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> Plug.Conn.put_private(:sigra_session, session)
        |> RequireMFA.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 with no session" do
    test "passes through (RequireAuthenticated handles that)" do
      opts = RequireMFA.init([])

      conn =
        conn(:get, "/dashboard")
        |> RequireMFA.call(opts)

      refute conn.halted
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(RequireMFA)
      assert function_exported?(RequireMFA, :init, 1)
      assert function_exported?(RequireMFA, :call, 2)
    end
  end
end
