defmodule Sigra.AuthOrgSelectionTest do
  @moduledoc """
  Phase 14 Plan 03 Task 1 — Login-time organization selector integration.

  Covers the 0/1/2+ selector behavior wired into `Sigra.Auth.create_session/4`
  via `config.organizations_module`, including the fail-open contract on
  selector raises (T-14-13). These tests exercise the full `create_session`
  code path through the Mox-backed SessionStore and a host-style
  `TestOrganizations` wrapper that exposes `__sigra_org_config__/0`.
  """
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Auth

  setup :verify_on_exit!

  # Minimal user schema mirroring Sigra.AuthTest conventions.
  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :integer, autogenerate: false}
    embedded_schema do
      field :email, :string
    end
  end

  # Host Organizations wrapper — mimics what `use Sigra.Organizations`
  # produces. Returns a pluggable config map via __sigra_org_config__/0
  # so the library-side create_session wiring can reach the selector
  # without the test booting a real Repo.
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
      field :user_id, :integer
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

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestOrganizations do
    @config %{
      repo: Sigra.MockRepo,
      schemas: %{
        organization: Sigra.AuthOrgSelectionTest.TestOrg,
        membership: Sigra.AuthOrgSelectionTest.TestMembership,
        invitation: Sigra.AuthOrgSelectionTest.TestInvitation,
        user: Sigra.AuthOrgSelectionTest.TestUser,
        scope: Sigra.AuthOrgSelectionTest.TestScope
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

  # A second Organizations module whose __sigra_org_config__/0 raises,
  # used to prove the fail-open contract (T-14-13).
  defmodule BoomOrganizations do
    def __sigra_org_config__, do: raise("boom")
  end

  @config %Sigra.Config{
    repo: Sigra.MockRepo,
    user_schema: TestUser,
    session: [
      store: Sigra.MockSessionStore,
      idle_timeout: 1_800,
      absolute_timeout: 86_400,
      activity_update_threshold: 300,
      remember_me_max_age: 5_184_000,
      session_schema: TestUser
    ]
  }

  defp build_session(overrides \\ %{}) do
    base = %Sigra.Session{
      id: 1,
      user_id: 1,
      hashed_token: "hashed-token-1",
      type: :standard,
      active_organization_id: nil,
      last_active_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now()
    }

    struct(base, overrides)
  end

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

  describe "Sigra.Config struct" do
    test "carries a nullable :scope_module field that round-trips via new!/1" do
      config = Sigra.Config.new!(repo: Sigra.MockRepo, user_schema: TestUser)
      assert config.scope_module == nil

      config_with_scope =
        Sigra.Config.new!(
          repo: Sigra.MockRepo,
          user_schema: TestUser,
          scope_module: FakeApp.Accounts.Scope
        )

      assert config_with_scope.scope_module == FakeApp.Accounts.Scope
    end

    test "carries a nullable :organizations_module field that round-trips via new!/1" do
      config = Sigra.Config.new!(repo: Sigra.MockRepo, user_schema: TestUser)
      assert config.organizations_module == nil

      config_with_orgs =
        Sigra.Config.new!(
          repo: Sigra.MockRepo,
          user_schema: TestUser,
          organizations_module: __MODULE__.TestOrganizations
        )

      assert config_with_orgs.organizations_module == __MODULE__.TestOrganizations
    end
  end

  describe "create_session/4 — selector NOT wired (legacy installs)" do
    test "zero orgs config returns session unchanged (no update_active_organization call)" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)

      # verify_on_exit! asserts that update_active_organization is NEVER called.
      user = %TestUser{id: 1}
      assert {:ok, ^session} = Auth.create_session(@config, user, %{type: :standard})
    end
  end

  describe "create_session/4 — 0/1/2+ selector wired via organizations_module (ORG-SCOPE-06)" do
    @config_with_orgs %{@config | organizations_module: __MODULE__.TestOrganizations}

    test "0 orgs: session.active_organization_id stays nil, login succeeds" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)

      # list_organizations_for_user/2 is called by select_active_organization/3.
      # Zero orgs → selector returns {:none, :zero_orgs} → no update call.
      Sigra.MockRepo
      |> expect(:all, fn _query -> [] end)

      user = %TestUser{id: 1}
      assert {:ok, result} = Auth.create_session(@config_with_orgs, user, %{type: :standard})
      assert result.active_organization_id == nil
    end

    test "1 org: writes active_organization_id atomically via SessionStore.update_active_organization/3" do
      session = build_session()
      org = build_org()
      updated = %{session | active_organization_id: org.id}

      # Membership returned by list_organizations_for_user/2 join
      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)
      |> expect(:update_active_organization, fn ^session, org_id, _opts ->
        assert org_id == org.id
        {:ok, updated}
      end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> [org] end)

      user = %TestUser{id: 1}
      assert {:ok, result} = Auth.create_session(@config_with_orgs, user, %{type: :standard})
      assert result.active_organization_id == org.id
    end

    test "2+ orgs with no resume pointer: active_organization_id stays nil (picker on next request)" do
      session = build_session()
      org_a = build_org(%{slug: "alpha"})
      org_b = build_org(%{slug: "beta"})

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> [org_a, org_b] end)

      user = %TestUser{id: 1}
      assert {:ok, result} = Auth.create_session(@config_with_orgs, user, %{type: :standard})
      assert result.active_organization_id == nil
    end

    test "2+ orgs with matching resume pointer: resumes that org" do
      session = build_session()
      org_a = build_org(%{slug: "alpha"})
      org_b = build_org(%{slug: "beta"})
      updated = %{session | active_organization_id: org_b.id}

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)
      |> expect(:update_active_organization, fn ^session, org_id, _opts ->
        assert org_id == org_b.id
        {:ok, updated}
      end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> [org_a, org_b] end)

      user = %TestUser{id: 1}

      assert {:ok, result} =
               Auth.create_session(@config_with_orgs, user, %{type: :standard},
                 previous_active_organization_id: org_b.id
               )

      assert result.active_organization_id == org_b.id
    end

    test "2+ orgs with forged/unknown resume pointer: falls back to nil (not resumed)" do
      session = build_session()
      org_a = build_org(%{slug: "alpha"})
      org_b = build_org(%{slug: "beta"})

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> [org_a, org_b] end)

      user = %TestUser{id: 1}
      forged_id = Ecto.UUID.generate()

      assert {:ok, result} =
               Auth.create_session(@config_with_orgs, user, %{type: :standard},
                 previous_active_organization_id: forged_id
               )

      assert result.active_organization_id == nil
    end
  end

  describe "create_session/4 — fail-open on selector raise (T-14-13)" do
    @boom_config %{@config | organizations_module: __MODULE__.BoomOrganizations}

    test "selector raise does NOT fail login; active_organization_id stays nil" do
      session = build_session()

      Sigra.MockSessionStore
      |> expect(:create, fn 1, _metadata, _opts -> {:ok, session} end)

      user = %TestUser{id: 1}
      assert {:ok, result} = Auth.create_session(@boom_config, user, %{type: :standard})
      assert result.active_organization_id == nil
    end
  end
end
