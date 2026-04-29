defmodule Sigra.Plug.RequireOrgMfaTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias Sigra.Plug.RequireOrgMfa

  defmodule TestScope do
    defstruct [:user, :active_organization]
  end

  defmodule TestUser do
    defstruct [:id]
  end

  defmodule TestOrg do
    defstruct [:id, :slug, :enforce_mfa_for_members]
  end

  defmodule FakeErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      Process.put(:require_org_mfa_call, {type, opts})

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(302, "redirect")
    end
  end

  defmodule BombErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(_conn, type, _opts) do
      raise "BombErrorHandler should not be called; got #{inspect(type)}"
    end
  end

  setup do
    Process.delete(:require_org_mfa_call)
    :ok
  end

  defp scope(attrs \\ %{}) do
    Map.merge(
      %TestScope{
        user: %TestUser{id: "u1"},
        active_organization: %TestOrg{id: "o1", slug: "acme", enforce_mfa_for_members: false}
      },
      attrs
    )
  end

  describe "init/1" do
    test "raises when :error_handler is missing" do
      assert_raise KeyError, fn ->
        RequireOrgMfa.init(mfa_check_fn: fn _ -> true end)
      end
    end

    test "raises when :mfa_check_fn is missing" do
      assert_raise KeyError, fn ->
        RequireOrgMfa.init(error_handler: FakeErrorHandler)
      end
    end

    test "returns validated opts" do
      opts = RequireOrgMfa.init(error_handler: FakeErrorHandler, mfa_check_fn: fn _ -> true end)
      assert opts[:error_handler] == FakeErrorHandler
      assert is_function(opts[:mfa_check_fn], 1)
      assert opts[:enrollment_path] == "/users/settings/mfa"
    end
  end

  describe "call/2" do
    test "passes through when scope is nil" do
      conn = conn(:get, "/organizations/acme/members") |> assign(:current_scope, nil)

      result =
        RequireOrgMfa.call(
          conn,
          RequireOrgMfa.init(error_handler: BombErrorHandler, mfa_check_fn: fn _ -> false end)
        )

      refute result.halted
    end

    test "passes through when policy is disabled" do
      conn = conn(:get, "/organizations/acme/members") |> assign(:current_scope, scope())

      result =
        RequireOrgMfa.call(
          conn,
          RequireOrgMfa.init(error_handler: BombErrorHandler, mfa_check_fn: fn _ -> false end)
        )

      refute result.halted
    end

    test "passes through when member already has MFA" do
      active_org = %TestOrg{id: "o1", slug: "acme", enforce_mfa_for_members: true}

      conn =
        conn(:get, "/organizations/acme/members")
        |> assign(:current_scope, scope(%{active_organization: active_org}))

      result =
        RequireOrgMfa.call(
          conn,
          RequireOrgMfa.init(error_handler: BombErrorHandler, mfa_check_fn: fn _ -> true end)
        )

      refute result.halted
    end

    test "halts and stores return_to when policy is enabled and member has no MFA" do
      active_org = %TestOrg{id: "o1", slug: "acme", enforce_mfa_for_members: true}

      conn =
        conn(:get, "/organizations/acme/members?tab=all")
        |> init_test_session(%{})
        |> assign(:current_scope, scope(%{active_organization: active_org}))

      result =
        RequireOrgMfa.call(
          conn,
          RequireOrgMfa.init(error_handler: FakeErrorHandler, mfa_check_fn: fn _ -> false end)
        )

      assert result.halted
      assert get_session(result, :user_return_to) == "/organizations/acme/members?tab=all"
      assert {:org_mfa_required, [enrollment_path: "/users/settings/mfa"]} =
               Process.get(:require_org_mfa_call)
    end

    test "invalid current path falls back to org dashboard" do
      active_org = %TestOrg{id: "o1", slug: "acme", enforce_mfa_for_members: true}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:request_path, "//evil.example")
        |> Map.put(:query_string, "")
        |> assign(:current_scope, scope(%{active_organization: active_org}))

      result =
        RequireOrgMfa.call(
          conn,
          RequireOrgMfa.init(error_handler: FakeErrorHandler, mfa_check_fn: fn _ -> false end)
        )

      assert get_session(result, :user_return_to) == "/organizations/acme"
    end
  end
end
