defmodule Example.Organizations.LastOwnerTest do
  @moduledoc """
  Integration tests for the last-owner guard using real database transactions.

  These tests verify that the FOR UPDATE lock in guard_last_owner correctly
  serializes concurrent transactions and prevents removal/demotion of the
  sole owner.
  """
  use Example.DataCase, async: false

  alias Example.Accounts.{Organization, OrganizationMembership, OrganizationInvitation, User}

  @config %{
    repo: Example.Repo,
    schemas: %{
      organization: Organization,
      membership: OrganizationMembership,
      invitation: OrganizationInvitation,
      user: User,
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

  defp create_user(attrs \\ %{}) do
    default = %{
      email: "user-#{System.unique_integer([:positive])}@example.com",
      hashed_password: Argon2.hash_pwd_salt("ValidPassword123!")
    }

    attrs = Map.merge(default, attrs)

    %User{}
    |> Ecto.Changeset.cast(attrs, [:email, :hashed_password])
    |> Repo.insert!()
  end

  defp scope(user), do: %{user: user}

  defp create_org_with_owner(user, slug_suffix \\ nil) do
    suffix = slug_suffix || System.unique_integer([:positive])
    attrs = %{name: "Test Org #{suffix}", slug: "test-org-#{suffix}"}
    {:ok, org} = Sigra.Organizations.create_organization(@config, scope(user), attrs)
    org
  end

  defp get_membership(user, org) do
    Sigra.Organizations.get_membership(@config, user, org)
  end

  describe "remove_member on last owner" do
    test "returns {:error, :last_owner}" do
      user = create_user()
      org = create_org_with_owner(user)
      membership = get_membership(user, org)

      assert {:error, :last_owner} =
               Sigra.Organizations.remove_member(@config, scope(user), membership)
    end

    test "succeeds when 2+ owners exist" do
      user = create_user()
      org = create_org_with_owner(user)

      user2 = create_user()
      {:ok, _} = Sigra.Organizations.add_member(@config, scope(user), org, user2, :owner)

      membership = get_membership(user, org)

      assert {:ok, _} =
               Sigra.Organizations.remove_member(@config, scope(user), membership)
    end
  end

  describe "change_role demoting last owner" do
    test "returns {:error, :last_owner}" do
      user = create_user()
      org = create_org_with_owner(user)
      membership = get_membership(user, org)

      assert {:error, :last_owner} =
               Sigra.Organizations.change_role(@config, scope(user), membership, :admin)
    end

    test "succeeds when another owner exists" do
      user = create_user()
      org = create_org_with_owner(user)

      user2 = create_user()
      {:ok, _} = Sigra.Organizations.add_member(@config, scope(user), org, user2, :owner)

      membership = get_membership(user, org)

      assert {:ok, updated} =
               Sigra.Organizations.change_role(@config, scope(user), membership, :admin)

      assert updated.role == :admin
    end
  end

  describe "add_member + remove sequence" do
    test "create org (1 owner), add second owner, remove first owner succeeds" do
      user = create_user()
      org = create_org_with_owner(user)

      user2 = create_user()
      {:ok, _} = Sigra.Organizations.add_member(@config, scope(user), org, user2, :owner)

      membership1 = get_membership(user, org)
      assert {:ok, _} = Sigra.Organizations.remove_member(@config, scope(user), membership1)

      membership2 = get_membership(user2, org)
      assert membership2 != nil
      assert membership2.role == :owner
    end
  end

  describe "concurrent removal of 2 owners" do
    test "only one succeeds (FOR UPDATE serialization)" do
      user = create_user()
      org = create_org_with_owner(user)

      user2 = create_user()
      {:ok, _} = Sigra.Organizations.add_member(@config, scope(user), org, user2, :owner)

      membership1 = get_membership(user, org)
      membership2 = get_membership(user2, org)

      parent = self()

      task1 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          Sigra.Organizations.remove_member(@config, scope(user), membership1)
        end)

      task2 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          Sigra.Organizations.remove_member(@config, scope(user2), membership2)
        end)

      results = [Task.await(task1, 10_000), Task.await(task2, 10_000)]

      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, :last_owner}, &1))

      assert successes == 1, "Expected exactly 1 success, got #{successes}: #{inspect(results)}"
      assert failures == 1, "Expected exactly 1 :last_owner failure, got #{failures}: #{inspect(results)}"
    end
  end
end
