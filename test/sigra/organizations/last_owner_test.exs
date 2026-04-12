defmodule Sigra.Organizations.LastOwnerTest do
  @moduledoc """
  Unit tests for last-owner guard error normalization and role demotion logic.

  For real database integration tests with FOR UPDATE lock behavior, see
  test/example/test/example/organizations/last_owner_test.exs which uses
  the example app's real database.
  """
  use ExUnit.Case, async: true

  import Mox

  # Reuse inline schemas from context_test
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

  setup :verify_on_exit!

  @config %{
    repo: Sigra.MockRepo,
    schemas: %{
      organization: TestOrg,
      membership: TestMembership,
      invitation: TestInvitation,
      user: TestUser,
      scope: nil
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

  defp scope do
    %{user: %TestUser{id: Ecto.UUID.generate(), email: "test@example.com"}}
  end

  describe "remove_member last-owner guard" do
    test "returns {:error, :last_owner} when guard fires" do
      membership = build_membership()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:error, :guard_last_owner, :last_owner, %{}}
      end)

      assert {:error, :last_owner} =
               Sigra.Organizations.remove_member(@config, scope(), membership)
    end

    test "succeeds when guard passes" do
      membership = build_membership()
      deleted_membership = membership

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{guard_last_owner: :safe, membership: deleted_membership}}
      end)

      assert {:ok, _} =
               Sigra.Organizations.remove_member(@config, scope(), membership)
    end
  end

  describe "change_role last-owner guard" do
    test "demoting last owner from :owner to :admin returns {:error, :last_owner}" do
      membership = build_membership(%{role: :owner})

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:error, :guard_last_owner, :last_owner, %{}}
      end)

      assert {:error, :last_owner} =
               Sigra.Organizations.change_role(@config, scope(), membership, :admin)
    end

    test "changing non-owner role does not trigger guard" do
      membership = build_membership(%{role: :admin})
      updated = %{membership | role: :member}

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{membership: updated}}
      end)

      assert {:ok, result} =
               Sigra.Organizations.change_role(@config, scope(), membership, :member)

      assert result.role == :member
    end

    test "promoting member to owner does not trigger guard" do
      membership = build_membership(%{role: :member})
      updated = %{membership | role: :owner}

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{membership: updated}}
      end)

      assert {:ok, result} =
               Sigra.Organizations.change_role(@config, scope(), membership, :owner)

      assert result.role == :owner
    end
  end
end
