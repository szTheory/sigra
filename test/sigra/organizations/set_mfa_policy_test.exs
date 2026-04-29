defmodule Sigra.Organizations.SetMfaPolicyTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Test.AuditEvent, as: AuditTestEvent

  defmodule TestOrg do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :enforce_mfa_for_members, :boolean, default: false
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
    end
  end

  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
    end
  end

  defmodule TestMfaCredential do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "user_mfa_credentials" do
      field :user_id, :binary_id
      field :enabled_at, :utc_datetime_usec
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership]
  end

  setup :verify_on_exit!

  @config %{
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
    audit_schema: AuditTestEvent,
    hooks: []
  }

  defp user, do: %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"}

  defp org(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    struct!(TestOrg, Map.merge(%{
      id: Ecto.UUID.generate(),
      name: "Acme",
      slug: "acme",
      enforce_mfa_for_members: false,
      inserted_at: now,
      updated_at: now
    }, attrs))
  end

  defp scope(user, org) do
    %TestScope{
      user: user,
      active_organization: org,
      membership: %TestMembership{role: :owner, organization_id: org.id, user_id: user.id}
    }
  end

  test "enabling without :mfa_check_fn raises" do
    current_org = org()
    current_user = user()

    assert_raise ArgumentError, ~r/requires :mfa_check_fn/, fn ->
      Sigra.Organizations.set_mfa_policy(@config, scope(current_user, current_org), current_org, true, [])
    end
  end

  test "no-op short-circuits without calling the repo" do
    current_org = org(%{enforce_mfa_for_members: true})
    current_user = user()

    assert {:ok, ^current_org} =
             Sigra.Organizations.set_mfa_policy(
               @config,
               scope(current_user, current_org),
               current_org,
               true,
               mfa_check_fn: fn _ -> true end
             )
  end

  test "enable pre-flight refuses when admin lacks MFA" do
    current_org = org()
    current_user = user()

    assert {:error, :admin_must_enroll_first} =
             Sigra.Organizations.set_mfa_policy(
               @config,
               scope(current_user, current_org),
               current_org,
               true,
               mfa_check_fn: fn _ -> false end
             )
  end

  test "happy path builds a multi and returns updated org" do
    current_org = org()
    current_user = user()
    updated_org = %{current_org | enforce_mfa_for_members: true}

    Sigra.MockRepo
    |> expect(:transact, fn %Ecto.Multi{} = multi ->
      steps = Ecto.Multi.to_list(multi) |> Enum.map(fn {name, _} -> name end)
      assert :organization in steps
      assert :audit in steps
      {:ok, %{organization: updated_org}}
    end)

    assert {:ok, %{enforce_mfa_for_members: true}} =
             Sigra.Organizations.set_mfa_policy(
               @config,
               scope(current_user, current_org),
               current_org,
               true,
               mfa_check_fn: fn _ -> true end
             )
  end

  test "count_members_without_mfa falls back to count_members when schema is nil" do
    current_org = org()
    current_user = user()

    Sigra.MockRepo
    |> expect(:aggregate, fn _query, :count -> 3 end)

    assert 3 ==
             Sigra.Organizations.count_members_without_mfa(
               @config,
               scope(current_user, current_org),
               nil
             )
  end

  test "count_members_without_mfa delegates to repo.one when schema is present" do
    current_org = org()
    current_user = user()

    Sigra.MockRepo
    |> expect(:one, fn _query -> 2 end)

    assert 2 ==
             Sigra.Organizations.count_members_without_mfa(
               @config,
               scope(current_user, current_org),
               TestMfaCredential
             )
  end
end
