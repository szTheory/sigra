defmodule Sigra.Scope.PlugLiveViewParityTest do
  @moduledoc """
  Phase 14 Plan 03 Task 3 — SC-3 plug ↔ on_mount parity test.

  Both the Plug pipeline (via `Sigra.Plug.LoadActiveOrganization`) and
  the LiveView `on_mount` path (via direct `Sigra.Scope.Hydration.hydrate/3`
  call inside the generated `UserAuth.mount_current_scope/2`) MUST feed
  the same `%Sigra.Session{}` through the same hydrator and produce
  structurally equivalent `%Scope{}` values.

  D-23 promised a single collapsed SC-3 matrix via shared `hydrate/3`.
  This test is the live enforcement of that promise: for every session
  state we care about, drive both paths through the hydrator and assert
  equal outputs (up to the stale-pointer recovery boundary, which only
  the plug path can reach — the LV path has no conn).
  """

  use ExUnit.Case, async: true

  import Mox
  import Plug.Test

  alias Sigra.Plug.LoadActiveOrganization
  alias Sigra.Scope.Hydration
  alias Sigra.Session

  # Inline test schemas — same pattern as HydrationTest / LoadActiveOrganizationTest.
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
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  @test_config %{
    repo: Sigra.MockRepo,
    schemas: %{
      organization: __MODULE__.TestOrg,
      membership: __MODULE__.TestMembership,
      invitation: __MODULE__.TestInvitation,
      user: __MODULE__.TestUser,
      scope: __MODULE__.TestScope
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

  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.Scope.PlugLiveViewParityTest.TestOrg,
        membership: Sigra.Scope.PlugLiveViewParityTest.TestMembership,
        invitation: Sigra.Scope.PlugLiveViewParityTest.TestInvitation,
        user: Sigra.Scope.PlugLiveViewParityTest.TestUser,
        scope: Sigra.Scope.PlugLiveViewParityTest.TestScope
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

  defp build_membership(user, org, role) do
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

  describe "plug ↔ on_mount parity (D-23 / SC-3)" do
    test "happy path: both paths produce structurally equal scopes for a valid session" do
      user = build_user()
      org = build_org()
      membership = build_membership(user, org, :admin)
      session = build_session(org.id, user.id)
      scope = build_scope(user)

      # ── LV on_mount path: direct Hydration.hydrate/3 call ────────────────────
      # This is exactly what the generated user_auth.ex mount_current_scope
      # helper calls after get_user_and_session_by_token returns.
      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)

      assert {:ok, lv_scope} = Hydration.hydrate(scope, @test_config, session)

      # ── Plug path: Sigra.Plug.LoadActiveOrganization.call/2 ──────────────────
      # Uses the SAME hydrator under the hood. We set independent expectations
      # so each path gets its own mock cycle.
      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)

      conn = build_conn(scope, session)
      plug_conn = LoadActiveOrganization.call(conn, plug_opts())
      plug_scope = plug_conn.assigns[:current_scope]

      # ── Parity assertion: structurally equal scopes ──────────────────────────
      assert plug_scope.user == lv_scope.user
      assert plug_scope.active_organization.id == lv_scope.active_organization.id
      assert plug_scope.membership.id == lv_scope.membership.id
      assert plug_scope.impersonating_from == lv_scope.impersonating_from
    end

    test "nil active_organization_id: both paths return the same zero-org scope" do
      user = build_user()
      session = build_session(nil, user.id)
      scope = build_scope(user)

      # Neither path should touch the Repo on the nil-pointer branch. If either
      # did, verify_on_exit! would fail (no expectations set).

      # LV path
      assert {:ok, lv_scope} = Hydration.hydrate(scope, @test_config, session)
      assert lv_scope == scope
      assert lv_scope.active_organization == nil
      assert lv_scope.membership == nil

      # Plug path
      conn = build_conn(scope, session)
      plug_conn = LoadActiveOrganization.call(conn, plug_opts())
      plug_scope = plug_conn.assigns[:current_scope]

      assert plug_scope == scope
      assert plug_scope.active_organization == nil
      assert plug_scope.membership == nil
      refute plug_conn.halted
    end

    test "stale pointer: LV path degrades gracefully, plug path recovers (boundary documented)" do
      user = build_user()
      session = build_session(Ecto.UUID.generate(), user.id)
      scope = build_scope(user)

      # ── LV path sees the stale pointer ─────────────────────────────────────
      # Hydration.hydrate/3 returns {:error, :org_not_found}. The generated
      # user_auth.ex falls back to the non-hydrated scope (no recovery on LV).
      Sigra.MockRepo
      # fetch_organization/2 returns nil → {:error, :not_found} → :org_not_found
      |> expect(:one, fn _query -> nil end)

      assert {:error, :org_not_found} = Hydration.hydrate(scope, @test_config, session)

      # ── Plug path recovers via LoadActiveOrganization ──────────────────────
      # Same stale pointer, same user, but the plug runs the recovery flow:
      # clear the pointer, re-run the selector (zero remaining orgs → nil),
      # leave the scope with active_organization: nil, never halt.
      Sigra.MockRepo
      # fetch_organization/2 returns nil again in the plug path
      |> expect(:one, fn _query -> nil end)
      # list_organizations_for_user/2 returns empty list (zero orgs)
      |> expect(:all, fn _query -> [] end)

      # SessionStore.update_active_organization/3 is called ONCE to clear the
      # stale pointer. Return the same session with active_organization_id: nil.
      Sigra.MockSessionStore
      |> expect(:update_active_organization, fn s, nil, _opts ->
        {:ok, %{s | active_organization_id: nil}}
      end)

      conn = build_conn(scope, session)
      plug_conn = LoadActiveOrganization.call(conn, plug_opts())
      plug_scope = plug_conn.assigns[:current_scope]

      # Parity at the HYDRATE CALL LAYER is preserved — both paths observed
      # the same {:error, :org_not_found} signal. The plug path then took
      # the recovery branch (boundary: conn available). The LV path can't
      # recover without a conn; next Plug request will. Contract documented
      # in CONTEXT §D-14 and Task 2's mount_current_scope comment.
      refute plug_conn.halted
      assert plug_scope.active_organization == nil
      assert plug_scope.membership == nil
    end
  end
end
