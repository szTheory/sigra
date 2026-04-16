defmodule Sigra.Scope.HydrationImpersonationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Scope.Hydration
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
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  setup :verify_on_exit!

  @test_config %{
    repo: Sigra.MockRepo,
    schemas: %{
      organization: TestOrg,
      membership: TestMembership,
      invitation: TestInvitation,
      user: TestUser,
      scope: TestScope
    },
    roles: [:owner, :admin, :member],
    owner_role: :owner,
    reserved_slugs: Sigra.Organizations.Slug.default_reserved_slugs(),
    additional_reserved_slugs: [],
    slug_format: ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
    slug_length: {3, 63},
    enforce_org_scope: [],
    audit_schema: nil,
    hooks: []
  }

  defp build_user(id, email), do: %TestUser{id: id, email: email}

  defp build_org(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestOrg{
        id: Ecto.UUID.generate(),
        name: "Acme Corp",
        slug: "acme-corp",
        deleted_at: nil,
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  defp build_membership(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestMembership{
        id: Ecto.UUID.generate(),
        role: :member,
        organization_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  test "hydrate/3 keeps the effective user in scope.user and resolves the real admin into scope.impersonating_from" do
    user = build_user(Ecto.UUID.generate(), "user@example.com")
    admin = build_user(Ecto.UUID.generate(), "admin@example.com")
    org = build_org()
    membership = build_membership(%{organization_id: org.id, user_id: user.id, role: :admin})

    session = %Session{
      id: 1,
      user_id: user.id,
      hashed_token: :crypto.hash(:sha256, "test"),
      type: :standard,
      active_organization_id: org.id,
      impersonator_user_id: admin.id,
      last_active_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now()
    }

    scope = %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}

    Sigra.MockRepo
    |> expect(:one, fn _query -> org end)
    |> expect(:one, fn _query -> membership end)
    |> expect(:get, fn TestUser, id -> if id == admin.id, do: admin, else: nil end)

    assert {:ok, hydrated} = Hydration.hydrate(scope, @test_config, session)
    assert hydrated.user.id == user.id
    assert hydrated.impersonating_from.id == admin.id
    assert hydrated.active_organization.id == org.id
    assert hydrated.membership.id == membership.id
  end
end
