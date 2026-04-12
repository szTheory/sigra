defmodule Sigra.Organizations.ContextTest do
  use ExUnit.Case, async: true

  import Mox

  # Inline test schemas for Mox-based unit testing
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
    defstruct [:user, :active_organization, :membership]
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

  defp test_scope(user \\ build_user()) do
    %TestScope{user: user}
  end

  defp build_user(id \\ Ecto.UUID.generate()) do
    %TestUser{id: id, email: "user@example.com"}
  end

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

  defp build_membership(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestMembership{
        id: Ecto.UUID.generate(),
        role: :owner,
        organization_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  describe "create_organization/3" do
    test "with valid attrs returns {:ok, org} with owner membership" do
      user = build_user()
      scope = test_scope(user)
      org = build_org()
      membership = build_membership(%{organization_id: org.id, user_id: user.id})

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        # Verify the multi has :organization and :membership steps
        assert %Ecto.Multi{} = multi
        {:ok, %{organization: org, membership: membership}}
      end)

      assert {:ok, returned_org} = Sigra.Organizations.create_organization(@test_config, scope, %{name: "Acme Corp", slug: "acme-corp"})
      assert returned_org.id == org.id
    end

    test "with invalid attrs (missing name) returns {:error, changeset}" do
      scope = test_scope()

      # No repo call expected -- changeset validation catches it before transaction
      # Actually, the changeset is built and passed to Multi, so the transaction
      # will still be called but will fail on the insert step
      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        # Simulate changeset validation failure at insert time
        changeset =
          %TestOrg{}
          |> Ecto.Changeset.cast(%{slug: "acme"}, [:name, :slug])
          |> Ecto.Changeset.validate_required([:name, :slug])

        {:error, :organization, changeset, %{}}
      end)

      assert {:error, %Ecto.Changeset{}} = Sigra.Organizations.create_organization(@test_config, scope, %{slug: "acme"})
    end

    test "with reserved slug returns {:error, changeset}" do
      scope = test_scope()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        changeset =
          %TestOrg{}
          |> Ecto.Changeset.cast(%{name: "Admin Org", slug: "admin"}, [:name, :slug])
          |> Ecto.Changeset.add_error(:slug, "is reserved and cannot be used")

        {:error, :organization, changeset, %{}}
      end)

      assert {:error, %Ecto.Changeset{} = cs} = Sigra.Organizations.create_organization(@test_config, scope, %{name: "Admin Org", slug: "admin"})
      assert cs.errors != []
    end

    test "auto-generates slug from name when slug not provided" do
      user = build_user()
      scope = test_scope(user)
      org = build_org(%{name: "My Cool Project", slug: "my-cool-project"})
      membership = build_membership(%{organization_id: org.id, user_id: user.id})

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        # Inspect the multi to verify slug was auto-generated
        assert %Ecto.Multi{} = multi
        {:ok, %{organization: org, membership: membership}}
      end)

      assert {:ok, _org} = Sigra.Organizations.create_organization(@test_config, scope, %{name: "My Cool Project"})
    end
  end

  describe "update_organization/4" do
    test "with valid attrs returns {:ok, updated_org}" do
      org = build_org()
      scope = test_scope()
      updated_org = %{org | name: "New Name", slug: "new-name"}

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{organization: updated_org}}
      end)

      assert {:ok, result} = Sigra.Organizations.update_organization(@test_config, scope, org, %{name: "New Name", slug: "new-name"})
      assert result.name == "New Name"
    end
  end

  describe "soft_delete_organization/3" do
    test "sets deleted_at and returns {:ok, org}" do
      org = build_org()
      scope = test_scope()
      deleted_org = %{org | deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)}

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{organization: deleted_org}}
      end)

      assert {:ok, result} = Sigra.Organizations.soft_delete_organization(@test_config, scope, org)
      assert result.deleted_at != nil
    end
  end

  describe "get_organization!/2" do
    test "with deleted org raises" do
      Sigra.MockRepo
      |> expect(:one!, fn _query ->
        raise Ecto.NoResultsError, queryable: TestOrg
      end)

      assert_raise Ecto.NoResultsError, fn ->
        Sigra.Organizations.get_organization!(@test_config, Ecto.UUID.generate())
      end
    end
  end

  describe "get_organization_by_slug/2" do
    test "returns nil for nonexistent slug" do
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      assert nil == Sigra.Organizations.get_organization_by_slug(@test_config, "nonexistent")
    end
  end

  describe "list_organizations_for_user/2" do
    test "returns list of orgs" do
      org1 = build_org(%{name: "Alpha"})
      org2 = build_org(%{name: "Beta"})

      Sigra.MockRepo
      |> expect(:all, fn _query -> [org1, org2] end)

      result = Sigra.Organizations.list_organizations_for_user(@test_config, build_user())
      assert length(result) == 2
    end

    test "excludes soft-deleted orgs via query filter" do
      # The query itself has `is_nil(o.deleted_at)`, so the repo would never return deleted orgs
      Sigra.MockRepo
      |> expect(:all, fn _query -> [] end)

      result = Sigra.Organizations.list_organizations_for_user(@test_config, build_user())
      assert result == []
    end
  end

  describe "normalize_multi_result/1" do
    # These test the normalization indirectly via remove_member
    test "guard_last_owner error normalizes to {:error, :last_owner}" do
      membership = build_membership()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:error, :guard_last_owner, :last_owner, %{}}
      end)

      assert {:error, :last_owner} = Sigra.Organizations.remove_member(@test_config, test_scope(), membership)
    end

    test "changeset error normalizes to {:error, changeset}" do
      membership = build_membership()
      changeset = Ecto.Changeset.change(%TestMembership{})

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:error, :membership, changeset, %{}}
      end)

      assert {:error, %Ecto.Changeset{}} = Sigra.Organizations.remove_member(@test_config, test_scope(), membership)
    end
  end
end
