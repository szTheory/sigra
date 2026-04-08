defmodule Sigra.Plug.RequireMFAEnrolledTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireMFAEnrolled

  @moduletag :phase6

  describe "init/1" do
    test "returns opts unchanged" do
      opts = RequireMFAEnrolled.init(mfa_check_fn: &Function.identity/1)
      assert is_list(opts)
    end
  end

  describe "call/2 with MFA-enrolled user" do
    test "passes through when mfa_check_fn returns true" do
      opts = RequireMFAEnrolled.init(mfa_check_fn: fn _user -> true end)

      conn =
        conn(:get, "/admin")
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> RequireMFAEnrolled.call(opts)

      refute conn.halted
    end
  end

  describe "call/2 with unenrolled user" do
    test "redirects to enrollment_path and halts" do
      opts =
        RequireMFAEnrolled.init(
          mfa_check_fn: fn _user -> false end,
          enrollment_path: "/users/settings"
        )

      conn =
        conn(:get, "/admin")
        |> init_test_session(%{})
        |> fetch_flash()
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> RequireMFAEnrolled.call(opts)

      assert conn.halted
      assert Plug.Conn.get_resp_header(conn, "location") == ["/users/settings"]
      assert conn.status == 302
    end

    test "uses default enrollment_path of /users/settings" do
      opts = RequireMFAEnrolled.init(mfa_check_fn: fn _user -> false end)

      conn =
        conn(:get, "/admin")
        |> init_test_session(%{})
        |> fetch_flash()
        |> Plug.Conn.assign(:current_scope, %{id: 1})
        |> RequireMFAEnrolled.call(opts)

      assert conn.halted
      assert Plug.Conn.get_resp_header(conn, "location") == ["/users/settings"]
    end
  end

  describe "call/2 with no user" do
    test "redirects when current_scope is nil" do
      opts =
        RequireMFAEnrolled.init(
          mfa_check_fn: fn _user -> true end,
          enrollment_path: "/users/settings"
        )

      conn =
        conn(:get, "/admin")
        |> init_test_session(%{})
        |> fetch_flash()
        |> RequireMFAEnrolled.call(opts)

      assert conn.halted
      assert Plug.Conn.get_resp_header(conn, "location") == ["/users/settings"]
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(RequireMFAEnrolled)
      assert function_exported?(RequireMFAEnrolled, :init, 1)
      assert function_exported?(RequireMFAEnrolled, :call, 2)
    end
  end

  # Helper to initialize flash
  defp fetch_flash(conn) do
    conn
    |> Phoenix.Controller.fetch_flash()
  end
end
