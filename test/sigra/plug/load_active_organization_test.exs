defmodule Sigra.Plug.LoadActiveOrganizationTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Test
  import Plug.Conn, only: [get_session: 2]

  alias Sigra.Plug.LoadActiveOrganization
  alias Sigra.Session

  # Inline schemas mirror the pattern from Sigra.Scope.HydrationTest — unit tests
  # for the pure primitives stub out the actual host schemas rather than booting
  # the full example app.
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
    # Phase 92 / B2B-02 (Plan 92-03 Task 2 cascade): mirror the generated
    # scope struct after Plan 92-02 — `:role` and `:actor_type` are
    # required for the library plug to set/clear role on the recovery
    # branches without raising KeyError on the struct update.
    defstruct [:user, :active_organization, :membership, :impersonating_from, :role, :actor_type]
  end

  # Host Organizations module — mimics what `use Sigra.Organizations` produces
  # plus the new `__sigra_org_config__/0` accessor the plug depends on.
  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.Plug.LoadActiveOrganizationTest.TestOrg,
        membership: Sigra.Plug.LoadActiveOrganizationTest.TestMembership,
        invitation: Sigra.Plug.LoadActiveOrganizationTest.TestInvitation,
        user: Sigra.Plug.LoadActiveOrganizationTest.TestUser,
        scope: Sigra.Plug.LoadActiveOrganizationTest.TestScope
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

  defp build_scope(user) do
    %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}
  end

  defp build_conn(scope, session) do
    conn(:get, "/")
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.assign(:current_scope, scope)
    |> Plug.Conn.put_private(:sigra_session, session)
  end

  defp plug_opts do
    LoadActiveOrganization.init(
      organizations: TestOrganizations,
      session_store: Sigra.MockSessionStore
    )
  end

  describe "call/2 — pass-through cases" do
    test "returns conn unchanged when current_scope is nil (unauthenticated)" do
      conn =
        conn(:get, "/")
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.assign(:current_scope, nil)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.assigns[:current_scope] == nil
      assert result.halted == false
      assert get_session(result, :active_organization_id) == nil
    end

    test "returns conn unchanged when sigra_session is missing" do
      user = build_user()
      scope = build_scope(user)

      conn =
        conn(:get, "/")
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.assign(:current_scope, scope)

      # No expect/0 — verify_on_exit! would fail if the plug called the repo.
      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.assigns[:current_scope] == scope
      assert result.halted == false
    end

    test "returns scope with nil active_organization when session pointer is nil" do
      user = build_user()
      scope = build_scope(user)
      session = build_session(nil, user.id)

      conn = build_conn(scope, session)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization == nil
      assert result.assigns[:current_scope].membership == nil
      assert get_session(result, :active_organization_id) == nil
    end
  end

  describe "call/2 — happy path" do
    test "assigns a fully hydrated scope when session points at a live membership" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org, :admin)
      session = build_session(org.id, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization.id == org.id
      assert result.assigns[:current_scope].membership.id == membership.id
      assert result.assigns[:current_scope].membership.role == :admin
      # D-03/D-17: NO session cookie mirror.
      assert get_session(result, :active_organization_id) == nil
    end
  end

  describe "call/2 — stale pointer recovery" do
    test "revoked membership triggers reset + selector re-run, reassigns to remaining org" do
      user = build_user()
      stale_org = build_org(%{name: "Stale"})
      remaining = build_org(%{name: "Remaining"})
      session = build_session(stale_org.id, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      remaining_membership = build_membership(user, remaining, :member)

      # 1. Hydration: fetch_organization returns the stale org (still exists),
      #    get_membership returns nil (user was removed).
      Sigra.MockRepo
      |> expect(:one, fn _query -> stale_org end)
      |> expect(:one, fn _query -> nil end)
      # 2. WR-03: recovery uses select_active_organization_with_membership/3,
      #    which selects `{org, membership}` tuples — no extra get_membership
      #    roundtrip is performed on the recovery path.
      |> expect(:all, fn _query -> [{remaining, remaining_membership}] end)

      # SessionStore expectations: first clear (nil), then set to remaining.id.
      cleared = %{session | active_organization_id: nil}
      refreshed = %{session | active_organization_id: remaining.id}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, nil, _opts -> {:ok, cleared} end)
      |> expect(:update_active_organization, fn ^cleared, new_id, _opts ->
        assert new_id == remaining.id
        {:ok, refreshed}
      end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization.id == remaining.id
      assert result.assigns[:current_scope].membership != nil
      assert result.private[:sigra_session].active_organization_id == remaining.id
      assert get_session(result, :active_organization_id) == nil
    end

    test "stale pointer with zero remaining orgs clears scope, does not halt" do
      user = build_user()
      stale_org = build_org()
      session = build_session(stale_org.id, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> stale_org end)
      |> expect(:one, fn _query -> nil end)
      |> expect(:all, fn _query -> [] end)

      cleared = %{session | active_organization_id: nil}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, nil, _opts -> {:ok, cleared} end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization == nil
      assert result.assigns[:current_scope].membership == nil
      assert result.private[:sigra_session].active_organization_id == nil
    end

    test "stale pointer with multiple remaining orgs leaves scope nil (picker path)" do
      user = build_user()
      stale_org = build_org()
      a = build_org(%{name: "A"})
      b = build_org(%{name: "B"})
      session = build_session(stale_org.id, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      ma = build_membership(user, a, :member)
      mb = build_membership(user, b, :member)

      Sigra.MockRepo
      |> expect(:one, fn _query -> stale_org end)
      |> expect(:one, fn _query -> nil end)
      |> expect(:all, fn _query -> [{a, ma}, {b, mb}] end)

      cleared = %{session | active_organization_id: nil}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, nil, _opts -> {:ok, cleared} end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization == nil
      assert result.assigns[:current_scope].membership == nil
      assert result.private[:sigra_session].active_organization_id == nil
    end

    test "deleted org (hydrate returns :org_not_found) triggers the same recovery path" do
      user = build_user()
      session = build_session(Ecto.UUID.generate(), user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      # fetch_organization returns nil -> :org_not_found
      |> expect(:one, fn _query -> nil end)
      # Recovery: list_organizations_for_user returns empty.
      |> expect(:all, fn _query -> [] end)

      cleared = %{session | active_organization_id: nil}

      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn ^session, nil, _opts -> {:ok, cleared} end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      assert result.halted == false
      assert result.assigns[:current_scope].active_organization == nil
    end
  end

  describe "invariants" do
    test "NEVER halts the pipeline on any code path" do
      user = build_user()
      scope = build_scope(user)

      # Pass through nil session
      conn1 = build_conn(scope, nil)
      assert LoadActiveOrganization.call(conn1, plug_opts()).halted == false

      # Pass through nil pointer
      conn2 = build_conn(scope, build_session(nil, user.id))
      assert LoadActiveOrganization.call(conn2, plug_opts()).halted == false
    end

    test "NEVER writes the Plug session cookie (no put_session anywhere)" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org)
      session = build_session(org.id, user.id)
      scope = build_scope(user)
      conn = build_conn(scope, session)

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)

      result = LoadActiveOrganization.call(conn, plug_opts())

      # Before and after: the Plug session cookie key is untouched.
      assert get_session(result, :active_organization_id) == nil
    end
  end
end
