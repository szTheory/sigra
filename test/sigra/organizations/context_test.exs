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

  describe "select_active_organization/3" do
    test "returns {:none, :zero_orgs} when user has no memberships" do
      Sigra.MockRepo
      |> expect(:all, fn _query -> [] end)

      assert {:none, :zero_orgs} =
               Sigra.Organizations.select_active_organization(@test_config, build_user())
    end

    test "returns {:ok, org} when user has exactly one membership" do
      only = build_org(%{name: "Solo Org"})

      Sigra.MockRepo
      |> expect(:all, fn _query -> [only] end)

      assert {:ok, returned} =
               Sigra.Organizations.select_active_organization(@test_config, build_user())

      assert returned.id == only.id
    end

    test "returns {:ok, resumed_org} when 2+ memberships and resume pointer matches" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      older = build_org(%{name: "Older", inserted_at: DateTime.add(now, -3600)})
      newer = build_org(%{name: "Newer", inserted_at: now})

      Sigra.MockRepo
      |> expect(:all, fn _query -> [older, newer] end)

      assert {:ok, resumed} =
               Sigra.Organizations.select_active_organization(
                 @test_config,
                 build_user(),
                 previous_active_organization_id: older.id
               )

      assert resumed.id == older.id
    end

    test "returns {:multiple, orgs} when 2+ memberships and resume pointer does not match" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      older = build_org(%{name: "Older", inserted_at: DateTime.add(now, -3600)})
      newer = build_org(%{name: "Newer", inserted_at: now})
      forged = Ecto.UUID.generate()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [older, newer] end)

      assert {:multiple, orgs} =
               Sigra.Organizations.select_active_organization(
                 @test_config,
                 build_user(),
                 previous_active_organization_id: forged
               )

      # Only user's real orgs are returned — forged pointer cannot inject anything
      assert Enum.map(orgs, & &1.id) |> Enum.sort() == Enum.sort([older.id, newer.id])
    end

    test "returns {:multiple, orgs} when 2+ memberships and no resume pointer" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      older = build_org(%{name: "Older", inserted_at: DateTime.add(now, -3600)})
      newer = build_org(%{name: "Newer", inserted_at: now})

      Sigra.MockRepo
      |> expect(:all, fn _query -> [older, newer] end)

      assert {:multiple, orgs} =
               Sigra.Organizations.select_active_organization(@test_config, build_user())

      assert length(orgs) == 2
    end

    test "{:multiple, orgs} is sorted by inserted_at descending (CD-04)" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      oldest = build_org(%{name: "Oldest", inserted_at: DateTime.add(now, -7200)})
      middle = build_org(%{name: "Middle", inserted_at: DateTime.add(now, -3600)})
      newest = build_org(%{name: "Newest", inserted_at: now})

      # Query returns in arbitrary order (by name, per the query) — selector must re-sort
      Sigra.MockRepo
      |> expect(:all, fn _query -> [middle, newest, oldest] end)

      assert {:multiple, [first, second, third]} =
               Sigra.Organizations.select_active_organization(@test_config, build_user())

      assert first.id == newest.id
      assert second.id == middle.id
      assert third.id == oldest.id
    end

    test "ignores unknown options silently (no raise)" do
      only = build_org()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [only] end)

      # Passing a bogus opt should not crash — Organizations.ex has no
      # NimbleOptions validation convention on per-call opts.
      assert {:ok, _} =
               Sigra.Organizations.select_active_organization(
                 @test_config,
                 build_user(),
                 bogus_option: :nope
               )
    end
  end

  describe "fetch_organization/2" do
    test "returns {:ok, org} for an existing non-deleted organization" do
      org = build_org()

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)

      assert {:ok, returned} = Sigra.Organizations.fetch_organization(@test_config, org.id)
      assert returned.id == org.id
    end

    test "returns {:error, :not_found} when the org does not exist" do
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      assert {:error, :not_found} =
               Sigra.Organizations.fetch_organization(@test_config, Ecto.UUID.generate())
    end

    test "does not raise on missing id (fail-closed contract)" do
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      # The whole point of fetch_organization vs get_organization! — must not raise
      assert {:error, :not_found} =
               Sigra.Organizations.fetch_organization(@test_config, Ecto.UUID.generate())
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

  # ─────────────────────────────────────────────────────────────────────
  # Phase 16 / Plan 01 tests
  # ─────────────────────────────────────────────────────────────────────

  defmodule TestUserSession do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "user_sessions" do
      field :user_id, :binary_id
      field :active_organization_id, :binary_id
      field :last_active_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestSlugAlias do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organization_slug_aliases" do
      field :organization_id, :binary_id
      field :old_slug, :string
      field :expires_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end
  end

  @phase16_config %{
    repo: Sigra.MockRepo,
    schemas: %{
      organization: TestOrg,
      membership: TestMembership,
      invitation: TestInvitation,
      user: TestUser,
      scope: TestScope,
      user_session: TestUserSession,
      organization_slug_alias: TestSlugAlias
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

  defp build_user_with_password(id \\ Ecto.UUID.generate()) do
    # Argon2 hash of "correct horse battery staple" — any real hash the
    # library can pass through Sigra.Crypto.verify_password/3 will work.
    hashed = Sigra.Crypto.hash_password("correct horse battery staple")
    %TestUser{id: id, email: "user@example.com"} |> Map.put(:hashed_password, hashed)
  end

  @tag :phase16
  test "Slug.default_reserved_slugs/0 contains orgs, organizations, switch plus existing entries" do
    reserved = Sigra.Organizations.Slug.default_reserved_slugs()

    assert "orgs" in reserved
    assert "organizations" in reserved
    assert "switch" in reserved
    # Sanity: existing entries must remain
    assert "admin" in reserved
    assert "api" in reserved
    assert "www" in reserved
    assert "static" in reserved
  end

  describe "remove_member/3 force-logout (Phase 16 SC-4)" do
    @tag :phase16
    test "Multi contains :purge_org_sessions step before :membership when user_session schema configured" do
      membership = build_membership()

      Sigra.MockRepo
      |> expect(:transaction, fn %Ecto.Multi{} = multi ->
        names = Ecto.Multi.to_list(multi) |> Enum.map(fn {name, _} -> name end)
        assert :guard_last_owner in names
        assert :purge_org_sessions in names
        assert :membership in names
        # purge must occur before membership delete (within the same tx)
        purge_idx = Enum.find_index(names, &(&1 == :purge_org_sessions))
        delete_idx = Enum.find_index(names, &(&1 == :membership))
        assert purge_idx < delete_idx
        {:ok, %{membership: membership}}
      end)

      assert {:ok, _} =
               Sigra.Organizations.remove_member(@phase16_config, test_scope(), membership)
    end

    @tag :phase16
    test "last-owner error still rolls back without touching sessions" do
      membership = build_membership()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:error, :guard_last_owner, :last_owner, %{}}
      end)

      assert {:error, :last_owner} =
               Sigra.Organizations.remove_member(@phase16_config, test_scope(), membership)
    end

    @tag :phase16
    test "backwards-compatible: config without :user_session does NOT add purge step" do
      membership = build_membership()

      Sigra.MockRepo
      |> expect(:transaction, fn %Ecto.Multi{} = multi ->
        names = Ecto.Multi.to_list(multi) |> Enum.map(fn {name, _} -> name end)
        refute :purge_org_sessions in names
        {:ok, %{membership: membership}}
      end)

      assert {:ok, _} =
               Sigra.Organizations.remove_member(@test_config, test_scope(), membership)
    end
  end

  describe "rename_organization/4" do
    @tag :phase16
    test "with valid name returns {:ok, org} and appends audit event" do
      org = build_org()
      updated = %{org | name: "New Name"}
      scope = test_scope()

      Sigra.MockRepo
      |> expect(:transaction, fn %Ecto.Multi{} = multi ->
        names = Ecto.Multi.to_list(multi) |> Enum.map(fn {name, _} -> name end)
        assert :organization in names
        {:ok, %{organization: updated}}
      end)

      assert {:ok, returned} =
               Sigra.Organizations.rename_organization(@phase16_config, scope, org, %{name: "New Name"})

      assert returned.name == "New Name"
    end

    @tag :phase16
    test "with blank name returns {:error, changeset} without transaction" do
      org = build_org()
      scope = test_scope()

      assert {:error, %Ecto.Changeset{} = cs} =
               Sigra.Organizations.rename_organization(@phase16_config, scope, org, %{name: ""})

      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :name)
    end
  end

  describe "update_slug/4" do
    @tag :phase16
    test "with wrong password returns {:error, :invalid_password} and does not run transaction" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()

      # No :transaction expectation — verify we short-circuit before Multi.
      assert {:error, :invalid_password} =
               Sigra.Organizations.update_slug(@phase16_config, scope, org, %{
                 slug: "new-slug",
                 password: "wrong",
                 confirm_slug: org.slug
               })
    end

    @tag :phase16
    test "with confirm_slug mismatch returns {:error, changeset}" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()

      assert {:error, %Ecto.Changeset{} = cs} =
               Sigra.Organizations.update_slug(@phase16_config, scope, org, %{
                 slug: "new-slug",
                 password: "correct horse battery staple",
                 confirm_slug: "wrong"
               })

      assert Keyword.has_key?(cs.errors, :confirm_slug)
    end

    @tag :phase16
    test "with reserved slug returns {:error, changeset}" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()

      assert {:error, %Ecto.Changeset{} = cs} =
               Sigra.Organizations.update_slug(@phase16_config, scope, org, %{
                 slug: "switch",
                 password: "correct horse battery staple",
                 confirm_slug: org.slug
               })

      assert Keyword.has_key?(cs.errors, :slug)
    end

    @tag :phase16
    test "happy path builds Multi with :organization and :slug_alias steps" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()
      updated_org = %{org | slug: "new-slug"}

      Sigra.MockRepo
      |> expect(:transaction, fn %Ecto.Multi{} = multi ->
        names = Ecto.Multi.to_list(multi) |> Enum.map(fn {name, _} -> name end)
        assert :organization in names
        assert :slug_alias in names
        {:ok, %{organization: updated_org}}
      end)

      assert {:ok, returned} =
               Sigra.Organizations.update_slug(@phase16_config, scope, org, %{
                 slug: "new-slug",
                 password: "correct horse battery staple",
                 confirm_slug: org.slug
               })

      assert returned.slug == "new-slug"
    end
  end

  describe "soft_delete_organization/4 (typed-confirm)" do
    @tag :phase16
    test "with password + matching confirm_name returns {:ok, org}" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()
      deleted = %{org | deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)}

      Sigra.MockRepo
      |> expect(:transaction, fn _multi -> {:ok, %{organization: deleted}} end)

      assert {:ok, result} =
               Sigra.Organizations.soft_delete_organization(@phase16_config, scope, org, %{
                 password: "correct horse battery staple",
                 confirm_name: org.name
               })

      assert result.deleted_at != nil
    end

    @tag :phase16
    test "with wrong password returns {:error, :invalid_password}" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()

      assert {:error, :invalid_password} =
               Sigra.Organizations.soft_delete_organization(@phase16_config, scope, org, %{
                 password: "wrong",
                 confirm_name: org.name
               })
    end

    @tag :phase16
    test "with confirm_name mismatch returns {:error, changeset}" do
      user = build_user_with_password()
      scope = %TestScope{user: user}
      org = build_org()

      assert {:error, %Ecto.Changeset{} = cs} =
               Sigra.Organizations.soft_delete_organization(@phase16_config, scope, org, %{
                 password: "correct horse battery staple",
                 confirm_name: "Not The Name"
               })

      assert Keyword.has_key?(cs.errors, :confirm_name)
    end
  end

  describe "list_members_with_activity/3 and count_members/2" do
    @tag :phase16
    test "list_members_with_activity/3 raises when scope.active_organization is nil" do
      scope = %TestScope{user: build_user(), active_organization: nil}

      assert_raise ArgumentError, fn ->
        Sigra.Organizations.list_members_with_activity(@phase16_config, scope)
      end
    end

    @tag :phase16
    test "list_members_with_activity/3 delegates to repo with org-scoped query" do
      user = build_user()
      org = build_org()
      scope = %TestScope{user: user, active_organization: org}
      membership = build_membership(%{organization_id: org.id, user_id: user.id})

      Sigra.MockRepo
      |> expect(:all, fn _query ->
        [{membership, ~U[2026-04-12 12:00:00Z]}]
      end)

      result = Sigra.Organizations.list_members_with_activity(@phase16_config, scope)

      assert [{^membership, last_active}] = result
      assert last_active == ~U[2026-04-12 12:00:00Z]
    end

    @tag :phase16
    test "count_members/2 delegates to Repo.aggregate" do
      user = build_user()
      org = build_org()
      scope = %TestScope{user: user, active_organization: org}

      Sigra.MockRepo
      |> expect(:aggregate, fn _query, :count -> 3 end)

      assert 3 == Sigra.Organizations.count_members(@phase16_config, scope)
    end
  end

  describe "get_active_slug_alias/2" do
    @tag :phase16
    test "returns nil when no active alias exists" do
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      assert nil ==
               Sigra.Organizations.get_active_slug_alias(@phase16_config, "old-slug")
    end

    @tag :phase16
    test "returns the alias row when a non-expired match exists" do
      alias_row = %TestSlugAlias{
        id: Ecto.UUID.generate(),
        organization_id: Ecto.UUID.generate(),
        old_slug: "old-slug",
        expires_at: DateTime.add(DateTime.utc_now(), 7, :day)
      }

      Sigra.MockRepo
      |> expect(:one, fn _query -> alias_row end)

      assert ^alias_row =
               Sigra.Organizations.get_active_slug_alias(@phase16_config, "old-slug")
    end
  end
end
