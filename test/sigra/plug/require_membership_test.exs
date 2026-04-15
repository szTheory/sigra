defmodule Sigra.Plug.RequireMembershipTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireMembership

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestOrg do
    defstruct [:id, :name]
  end

  defmodule TestMembership do
    defstruct [:id, :role]
  end

  defmodule TestUser do
    defstruct [:id]
  end

  # IN-03: Host org module with an extended role list. `init/1` should read
  # `__sigra_org_config__().roles` and accept custom atoms (`:viewer`,
  # `:billing`) that are NOT in the canonical `[:owner, :admin, :member]`.
  defmodule CustomRolesOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{},
      roles: [:owner, :admin, :member, :viewer, :billing],
      owner_role: :owner,
      audit_schema: nil,
      hooks: []
    }

    def __sigra_org_config__, do: @config
  end

  # A test error handler that records every call and responds 403 so halt/1
  # works cleanly afterwards.
  defmodule FakeErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      calls = Process.get(:fake_handler_calls, [])
      Process.put(:fake_handler_calls, calls ++ [{type, opts}])

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, to_string(type))
    end
  end

  # Second error handler: asserts that if it's ever invoked the test has
  # gone wrong (used for happy-path tests).
  defmodule BombErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(_conn, type, _opts) do
      raise "BombErrorHandler should NOT have been called; got #{inspect(type)}"
    end
  end

  setup do
    Process.delete(:fake_handler_calls)
    :ok
  end

  defp build_scope(org, membership) do
    %TestScope{
      user: %TestUser{id: "u1"},
      active_organization: org,
      membership: membership,
      impersonating_from: nil
    }
  end

  defp build_conn(scope) do
    conn(:get, "/")
    |> Plug.Conn.assign(:current_scope, scope)
  end

  describe "init/1" do
    test "raises when :error_handler is missing" do
      assert_raise KeyError, fn ->
        RequireMembership.init([])
      end
    end

    test "defaults :roles to an empty list (any membership OK — D-07)" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler)
      assert Keyword.fetch!(opts, :roles) == []
      assert Keyword.fetch!(opts, :error_handler) == FakeErrorHandler
    end

    test "accepts a valid :roles subset" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler, roles: [:owner, :admin])
      assert Keyword.fetch!(opts, :roles) == [:owner, :admin]
    end

    test "raises ArgumentError when :roles contains an unknown atom" do
      assert_raise ArgumentError, ~r/unknown atoms.*:superadmin/, fn ->
        RequireMembership.init(error_handler: FakeErrorHandler, roles: [:owner, :superadmin])
      end
    end

    test "raises ArgumentError when :roles is not a list of atoms" do
      assert_raise ArgumentError, ~r/must be a list of atoms/, fn ->
        RequireMembership.init(error_handler: FakeErrorHandler, roles: ["owner"])
      end
    end

    test "accepts host-extended roles when :organizations is passed (IN-03)" do
      opts =
        RequireMembership.init(
          error_handler: FakeErrorHandler,
          organizations: CustomRolesOrganizations,
          roles: [:viewer, :billing]
        )

      assert Keyword.fetch!(opts, :roles) == [:viewer, :billing]
    end

    test "rejects atoms absent from host org config roles (IN-03)" do
      assert_raise ArgumentError, ~r/unknown atoms.*:superadmin/, fn ->
        RequireMembership.init(
          error_handler: FakeErrorHandler,
          organizations: CustomRolesOrganizations,
          roles: [:owner, :superadmin]
        )
      end
    end

    test "without :organizations, rejects custom roles against canonical universe" do
      assert_raise ArgumentError, ~r/unknown atoms.*:viewer/, fn ->
        RequireMembership.init(error_handler: FakeErrorHandler, roles: [:viewer])
      end
    end
  end

  describe "call/2 — missing active organization" do
    test "nil scope calls :no_active_org and halts" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler)
      conn = conn(:get, "/") |> Plug.Conn.assign(:current_scope, nil)

      result = RequireMembership.call(conn, opts)

      assert result.halted == true
      assert [{:no_active_org, _opts}] = Process.get(:fake_handler_calls)
    end

    test "nil active_organization calls :no_active_org and halts" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler)
      scope = build_scope(nil, nil)
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == true
      assert [{:no_active_org, _opts}] = Process.get(:fake_handler_calls)
    end
  end

  describe "call/2 — role filtering" do
    test "passes through when :roles is [] regardless of the member's role (D-07)" do
      opts = RequireMembership.init(error_handler: BombErrorHandler, roles: [])
      scope = build_scope(%TestOrg{id: "o1"}, %TestMembership{id: "m1", role: :member})
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == false
      assert result.assigns[:current_scope] == scope
    end

    test "passes through when membership role is in the required list" do
      opts = RequireMembership.init(error_handler: BombErrorHandler, roles: [:owner, :admin])
      scope = build_scope(%TestOrg{id: "o1"}, %TestMembership{id: "m1", role: :admin})
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == false
    end

    test "halts with :insufficient_role + forwards required_roles when role is not in list" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler, roles: [:owner])
      scope = build_scope(%TestOrg{id: "o1"}, %TestMembership{id: "m1", role: :member})
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == true
      assert [{:insufficient_role, error_opts}] = Process.get(:fake_handler_calls)
      assert Keyword.fetch!(error_opts, :required_roles) == [:owner]
    end

    test "admin does NOT imply owner — hierarchical role confusion is rejected (T-14-11)" do
      opts = RequireMembership.init(error_handler: FakeErrorHandler, roles: [:owner])
      scope = build_scope(%TestOrg{id: "o1"}, %TestMembership{id: "m1", role: :admin})
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == true
      assert [{:insufficient_role, _}] = Process.get(:fake_handler_calls)
    end
  end

  describe "no DB re-query (D-21)" do
    test "plug reads scope.membership.role and never re-fetches it" do
      # The contract: if the plug consulted the DB instead of scope.membership.role,
      # it would see (for example) a :member role and halt. We set the scope
      # membership to :owner and trust that; BombErrorHandler proves the plug
      # did NOT overrule it via a phantom re-query.
      opts = RequireMembership.init(error_handler: BombErrorHandler, roles: [:owner])
      scope = build_scope(%TestOrg{id: "o1"}, %TestMembership{id: "m1", role: :owner})
      conn = build_conn(scope)

      result = RequireMembership.call(conn, opts)

      assert result.halted == false
    end
  end
end
