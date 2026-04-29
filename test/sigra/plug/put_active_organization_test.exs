defmodule Sigra.Plug.PutActiveOrganizationTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Test
  import Plug.Conn, only: [get_session: 2]

  alias Sigra.Plug.PutActiveOrganization
  alias Sigra.Session

  defmodule TestOrg do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :deleted_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestMembership do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_memberships" do
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :organization_id, :binary_id
      field :user_id, :binary_id
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestInvitation do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_invitations" do
      field :email, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :organization_id, :binary_id
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestUser do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
    end
  end

  defmodule TestScope do
    # Plan 92-02 reserved `:role` and `:actor_type` on the generated scope
    # struct. Plan 92-03 wires `:role` propagation through the authoritative
    # PutActiveOrganization seam.
    defstruct [:user, :active_organization, :membership, :impersonating_from, :role, :actor_type]

    # Test-local scope module that records calls to put_active_organization/3
    # so we can assert the orchestrator resolved the module via config and not
    # a hardcoded Sigra.Scope.
    #
    # NOTE: this stub deliberately does NOT update :role itself — the library
    # plug `Sigra.Plug.PutActiveOrganization` is the single authoritative
    # seam for role updates (per Plan 92-03 must-haves), so the test scope
    # module remains role-agnostic. The plug must apply the role write after
    # the scope_module call returns; tests below assert the post-condition.
    def put_active_organization(%__MODULE__{} = scope, nil, nil) do
      Process.put(:test_scope_calls, Process.get(:test_scope_calls, []) ++ [{:clear}])
      %{scope | active_organization: nil, membership: nil}
    end

    def put_active_organization(%__MODULE__{} = scope, org, membership) do
      Process.put(
        :test_scope_calls,
        Process.get(:test_scope_calls, []) ++ [{:set, org.id, membership && membership.id}]
      )

      %{scope | active_organization: org, membership: membership}
    end
  end

  # Host Organizations module — mimics `use Sigra.Organizations` plus the
  # Phase 14 __sigra_org_config__/0 accessor.
  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.Plug.PutActiveOrganizationTest.TestOrg,
        membership: Sigra.Plug.PutActiveOrganizationTest.TestMembership,
        invitation: Sigra.Plug.PutActiveOrganizationTest.TestInvitation,
        user: Sigra.Plug.PutActiveOrganizationTest.TestUser,
        scope: Sigra.Plug.PutActiveOrganizationTest.TestScope
      },
      roles: [:owner, :admin, :member],
      owner_role: :owner,
      reserved_slugs: [],
      additional_reserved_slugs: [],
      slug_format: ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
      slug_length: {3, 63},
      enforce_org_scope: [],
      audit_schema: nil,
      hooks: []
    }

    def __sigra_org_config__, do: @config
  end

  setup :verify_on_exit!

  setup do
    Process.delete(:test_scope_calls)
    :ok
  end

  defp build_user, do: %TestUser{id: Ecto.UUID.generate(), email: "u@example.com"}

  defp build_org(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestOrg{
        id: Ecto.UUID.generate(),
        name: "Acme",
        slug: "acme",
        deleted_at: nil,
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  defp build_membership(user, org, role \\ :member) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %TestMembership{
      id: Ecto.UUID.generate(),
      role: role,
      organization_id: org.id,
      user_id: user.id,
      inserted_at: now,
      updated_at: now
    }
  end

  defp build_session(active_organization_id, user_id) do
    %Session{
      id: 1,
      user_id: user_id,
      hashed_token: :crypto.hash(:sha256, "test"),
      type: :standard,
      active_organization_id: active_organization_id,
      last_active_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now()
    }
  end

  defp build_scope(user, org \\ nil, membership \\ nil) do
    %TestScope{
      user: user,
      active_organization: org,
      membership: membership,
      impersonating_from: nil,
      role: membership && membership.role,
      actor_type: nil
    }
  end

  defp build_conn(scope, session) do
    conn(:get, "/")
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.assign(:current_scope, scope)
    |> Plug.Conn.put_private(:sigra_session, session)
  end

  defp call_opts do
    [
      organizations: TestOrganizations,
      session_store: Sigra.MockSessionStore,
      scope_module: TestScope
    ]
  end

  describe "call/2 — set active organization" do
    test "writes the DB column, refreshes private[:sigra_session] + scope, returns {:ok, conn}" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org, :admin)
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      refreshed = %{session | active_organization_id: org.id}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, new_id, _opts ->
        assert new_id == org.id
        {:ok, refreshed}
      end)

      assert {:ok, updated_conn} = PutActiveOrganization.call(conn, org, call_opts())

      assert updated_conn.private[:sigra_session].active_organization_id == org.id
      assert updated_conn.assigns[:current_scope].active_organization.id == org.id
      assert updated_conn.assigns[:current_scope].membership.id == membership.id
      # Phase 92 / B2B-02 (Plan 92-03): role is set from membership.role at
      # this single authoritative seam.
      assert updated_conn.assigns[:current_scope].role == membership.role
      # TestScope.put_active_organization was invoked.
      assert [{:set, org_id, m_id}] = Process.get(:test_scope_calls)
      assert org_id == org.id
      assert m_id == membership.id
      # D-17: no session cookie write.
      assert get_session(updated_conn, :active_organization_id) == nil
    end

    test "resolves the host Scope module via opts (not hardcoded Sigra.Scope)" do
      # If the plug hardcoded Sigra.Scope, the call to TestScope.put_active_organization
      # would never happen, and Process.get(:test_scope_calls) would be empty. This
      # test is functionally identical to the happy-path but asserts explicitly on
      # the recorded call shape.
      user = build_user()
      org = build_org()
      membership = build_membership(user, org)
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, _, _ ->
        {:ok, %{session | active_organization_id: org.id}}
      end)

      assert {:ok, _} = PutActiveOrganization.call(conn, org, call_opts())

      assert length(Process.get(:test_scope_calls, [])) == 1
    end
  end

  describe "call/2 — membership verification (T-14-06)" do
    test "returns {:error, :not_a_member} when user has no membership — NO DB write" do
      user = build_user()
      org = build_org()
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      # get_membership returns nil — no membership.
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      # CRITICAL: NO expect for SessionStore.update_active_organization.
      # verify_on_exit! will fail the test if the plug tries to call it.

      assert {:error, :not_a_member} = PutActiveOrganization.call(conn, org, call_opts())

      # Scope module was never invoked either.
      assert Process.get(:test_scope_calls, []) == []
    end
  end

  describe "call/2 — clear active organization" do
    test "clears the DB column, assigns scope with nil org/membership, returns {:ok, conn}" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org)
      session = build_session(org.id, user.id)
      scope = build_scope(user, org, membership)
      conn = build_conn(scope, session)

      # Pre-condition: the scope arrived with a populated role atom (built
      # from membership.role inside build_scope/3). After clear, role MUST
      # be nil — Plan 92-03 must-have: clear-path nils out role alongside
      # membership.
      assert scope.role == membership.role

      cleared = %{session | active_organization_id: nil}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, nil, _opts -> {:ok, cleared} end)

      assert {:ok, updated_conn} = PutActiveOrganization.call(conn, nil, call_opts())

      assert updated_conn.private[:sigra_session].active_organization_id == nil
      assert updated_conn.assigns[:current_scope].active_organization == nil
      assert updated_conn.assigns[:current_scope].membership == nil
      # Phase 92 / B2B-02 (Plan 92-03): role is cleared alongside membership.
      assert is_nil(updated_conn.assigns[:current_scope].role)
      assert [{:clear}] = Process.get(:test_scope_calls)
      # D-17 / D-18: no put_session, no configure_session.
      assert get_session(updated_conn, :active_organization_id) == nil
    end
  end

  describe "Phase 92 / B2B-02 — :role propagation (Plan 92-03 Task 2)" do
    test "set path: writes scope.role from membership.role using a host-themed role atom" do
      # Plan 92-01 made the seam role-agnostic. This test proves the plug
      # accepts an atom the library has never heard of.
      user = build_user()
      org = build_org()
      membership = build_membership(user, org, :tenant_lead)
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, _, _ ->
        {:ok, %{session | active_organization_id: org.id}}
      end)

      assert {:ok, updated_conn} = PutActiveOrganization.call(conn, org, call_opts())
      assert updated_conn.assigns[:current_scope].role == :tenant_lead
    end

    test "set path: writes nil scope.role when membership.role is nil" do
      # Plan 92-02 made membership.role nullable. The seam must propagate
      # nil verbatim and not invent an opinionated default.
      user = build_user()
      org = build_org()
      membership = %{build_membership(user, org) | role: nil}
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, _, _ ->
        {:ok, %{session | active_organization_id: org.id}}
      end)

      assert {:ok, updated_conn} = PutActiveOrganization.call(conn, org, call_opts())
      assert is_nil(updated_conn.assigns[:current_scope].role)
    end

    test ":not_a_member error path does NOT write role onto the scope (T-92-08)" do
      # T-92-08: clear role when clearing membership and reuse the
      # authoritative membership check before writes. This test pins that
      # if get_membership returns nil, no role is written.
      user = build_user()
      org = build_org()
      session = build_session(nil, user.id)
      # Pre-existing scope arrives with a stale role (defense-in-depth):
      # if the plug ever leaks role through the no-membership branch it
      # would surface here.
      scope = %{build_scope(user) | role: :stale_atom}
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      assert {:error, :not_a_member} = PutActiveOrganization.call(conn, org, call_opts())
      # Scope module was not invoked, no role write happened.
      assert Process.get(:test_scope_calls, []) == []
    end

    test "actor_type stays nil under Phase 92 on both set and clear paths" do
      # Phase 92 reserves but does not populate actor_type. The plug must
      # not synthesize a value on either branch.
      user = build_user()
      org = build_org()
      membership = build_membership(user, org, :admin)
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, _, _ ->
        {:ok, %{session | active_organization_id: org.id}}
      end)

      {:ok, set_conn} = PutActiveOrganization.call(conn, org, call_opts())
      assert is_nil(set_conn.assigns[:current_scope].actor_type)

      # Clear path
      cleared_session = %{session | active_organization_id: nil}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, nil, _ -> {:ok, cleared_session} end)

      {:ok, clear_conn} = PutActiveOrganization.call(set_conn, nil, call_opts())
      assert is_nil(clear_conn.assigns[:current_scope].actor_type)
    end
  end

  describe "invariants (D-17, D-18)" do
    test "NEVER calls Plug.Conn.put_session or configure_session" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org)
      session = build_session(nil, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> membership end)

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn _, _, _ ->
        {:ok, %{session | active_organization_id: org.id}}
      end)

      {:ok, updated_conn} = PutActiveOrganization.call(conn, org, call_opts())

      # The Plug session cookie key is never touched — same value before and after.
      assert get_session(conn, :active_organization_id) == nil
      assert get_session(updated_conn, :active_organization_id) == nil
    end
  end
end
