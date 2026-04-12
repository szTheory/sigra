defmodule Sigra.Scope.HydrationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Scope.Hydration
  alias Sigra.Session

  # Inline test schemas mirror the pattern from Sigra.Organizations.ContextTest.
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

  defp build_session(active_organization_id) do
    %Session{
      id: 1,
      user_id: Ecto.UUID.generate(),
      hashed_token: :crypto.hash(:sha256, "test"),
      type: :standard,
      active_organization_id: active_organization_id
    }
  end

  defp build_scope(user) do
    %TestScope{user: user, active_organization: nil, membership: nil, impersonating_from: nil}
  end

  describe "hydrate/3" do
    test "returns scope unchanged when session.active_organization_id is nil" do
      user = build_user()
      scope = build_scope(user)
      session = build_session(nil)

      # No Repo calls expected — the nil clause short-circuits.
      assert {:ok, returned} = Hydration.hydrate(scope, @test_config, session)
      assert returned == scope
      assert returned.active_organization == nil
      assert returned.membership == nil
    end

    test "returns populated scope on valid session + live membership" do
      user = build_user()
      org = build_org()
      membership = build_membership(%{organization_id: org.id, user_id: user.id, role: :admin})
      session = build_session(org.id)
      scope = build_scope(user)

      Sigra.MockRepo
      # fetch_organization/2 calls repo.one/1
      |> expect(:one, fn _query -> org end)
      # get_membership/3 calls repo.one/1
      |> expect(:one, fn _query -> membership end)

      assert {:ok, hydrated} = Hydration.hydrate(scope, @test_config, session)
      assert hydrated.active_organization.id == org.id
      assert hydrated.membership.id == membership.id
      assert hydrated.user == user
      # Contract: scope.active_organization.id == session.active_organization_id
      assert hydrated.active_organization.id == session.active_organization_id
    end

    test "returns {:error, :not_a_member} when user was removed from the org" do
      user = build_user()
      org = build_org()
      session = build_session(org.id)
      scope = build_scope(user)

      Sigra.MockRepo
      # Org fetch succeeds
      |> expect(:one, fn _query -> org end)
      # Membership lookup returns nil (user was removed)
      |> expect(:one, fn _query -> nil end)

      assert {:error, :not_a_member} = Hydration.hydrate(scope, @test_config, session)
    end

    test "returns {:error, :org_not_found} when the org was deleted" do
      user = build_user()
      session = build_session(Ecto.UUID.generate())
      scope = build_scope(user)

      Sigra.MockRepo
      # fetch_organization returns nil (soft-deleted or hard-gone)
      |> expect(:one, fn _query -> nil end)

      assert {:error, :org_not_found} = Hydration.hydrate(scope, @test_config, session)
    end

    test "never raises on any of the error inputs" do
      # Exercises all three non-happy paths and asserts no exception escapes.
      user = build_user()
      session_stale = build_session(Ecto.UUID.generate())
      scope = build_scope(user)

      # Case A: org missing
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      assert_no_raise(fn ->
        assert {:error, :org_not_found} = Hydration.hydrate(scope, @test_config, session_stale)
      end)

      # Case B: org present but membership missing
      org = build_org()
      session_revoked = build_session(org.id)

      Sigra.MockRepo
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> nil end)

      assert_no_raise(fn ->
        assert {:error, :not_a_member} =
                 Hydration.hydrate(scope, @test_config, session_revoked)
      end)
    end

    test "is pure — two calls yield structurally-equal scopes (happy path)" do
      user = build_user()
      org = build_org()
      membership = build_membership(%{organization_id: org.id, user_id: user.id})
      session = build_session(org.id)
      scope = build_scope(user)

      Sigra.MockRepo
      # First call: 2 reads
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)
      # Second call: 2 reads
      |> expect(:one, fn _query -> org end)
      |> expect(:one, fn _query -> membership end)

      assert {:ok, first} = Hydration.hydrate(scope, @test_config, session)
      assert {:ok, second} = Hydration.hydrate(scope, @test_config, session)

      assert first == second
      assert first.active_organization.id == second.active_organization.id
      assert first.membership.id == second.membership.id
    end

    test "is pure — nil org_id path makes zero Repo calls" do
      user = build_user()
      scope = build_scope(user)
      session = build_session(nil)

      # No expect/3 calls at all — verify_on_exit! will fail if the hydrator
      # invokes the repo for the nil-pointer case.
      assert {:ok, ^scope} = Hydration.hydrate(scope, @test_config, session)
    end
  end

  # Small helper so the "never raises" test reads well.
  defp assert_no_raise(fun) do
    try do
      fun.()
    rescue
      e -> flunk("hydrate/3 raised #{inspect(e)} — must be fail-closed, not raise")
    end
  end
end
