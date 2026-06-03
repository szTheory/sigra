defmodule Sigra.OAuth.EnterpriseReconciliationTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.OAuth.EnterpriseReconciliation

  defmodule TestOrganization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "organizations" do
      field :name, :string
      field :slug, :string
    end
  end

  defmodule TestMembership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "organization_memberships" do
      field :organization_id, :binary_id
      field :user_id, :integer
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
    end
  end

  defmodule TestInvitation do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "organization_invitations" do
      field :organization_id, :binary_id
      field :email, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :accepted_at, :utc_datetime
      field :accepted_by_id, :integer
      field :revoked_at, :utc_datetime
    end
  end

  defmodule Repo do
    def get_by(Sigra.Test.MockIdentity, clauses) do
      Enum.find(state().identities, fn identity ->
        identity.provider == clauses[:provider] and identity.provider_uid == clauses[:provider_uid]
      end)
    end

    def get_by(Sigra.Test.MockUser, clauses) do
      Enum.find(state().users, fn user -> user.email == clauses[:email] end)
    end

    def get_by(TestMembership, clauses) do
      Enum.find(state().memberships, fn membership ->
        membership.organization_id == clauses[:organization_id] and membership.user_id == clauses[:user_id]
      end)
    end

    def get_by(TestInvitation, clauses) do
      Enum.find(state().invitations, fn invitation ->
        invitation.organization_id == clauses[:organization_id] and invitation.email == clauses[:email]
      end)
    end

    def get!(Sigra.Test.MockUser, id) do
      Enum.find(state().users, fn user -> user.id == id end) || raise "user not found"
    end

    def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)

    def insert(%Ecto.Changeset{} = changeset) do
      struct = Ecto.Changeset.apply_changes(changeset)

      cond do
        match?(%Sigra.Test.MockUser{}, struct) ->
          user = %{struct | id: struct.id || next_user_id()}
          update_state(fn current -> %{current | users: [user | current.users]} end)
          {:ok, user}

        match?(%Sigra.Test.MockIdentity{}, struct) ->
          identity = %{struct | id: struct.id || next_identity_id()}
          update_state(fn current -> %{current | identities: [identity | current.identities]} end)
          {:ok, identity}

        match?(%TestMembership{}, struct) ->
          if Enum.any?(state().memberships, fn membership ->
               membership.organization_id == struct.organization_id and membership.user_id == struct.user_id
             end) do
            {:error, unique_error(struct, :user_id)}
          else
            membership = %{struct | id: struct.id || Ecto.UUID.generate()}
            update_state(fn current -> %{current | memberships: [membership | current.memberships]} end)
            {:ok, membership}
          end

        true ->
          {:ok, struct}
      end
    end

    def insert(changeset, _opts), do: insert(changeset)

    def update(%Ecto.Changeset{} = changeset) do
      struct = Ecto.Changeset.apply_changes(changeset)

      cond do
        match?(%Sigra.Test.MockIdentity{}, struct) ->
          update_state(fn current ->
            %{current | identities: replace_by_id(current.identities, struct)}
          end)

          {:ok, struct}

        match?(%TestInvitation{}, struct) ->
          update_state(fn current ->
            %{current | invitations: replace_by_id(current.invitations, struct)}
          end)

          {:ok, struct}

        true ->
          {:ok, struct}
      end
    end

    def update(changeset, _opts), do: update(changeset)

    def enterprise_users_by_email(Sigra.Test.MockUser, email) do
      Enum.filter(state().users, fn user -> user.email == email end)
    end

    def enterprise_pending_invitations(TestInvitation, org_id) do
      Enum.filter(state().invitations, fn invitation ->
        invitation.organization_id == org_id and is_nil(invitation.accepted_at) and is_nil(invitation.revoked_at)
      end)
    end

    defp replace_by_id(items, updated) do
      Enum.map(items, fn item -> if item.id == updated.id, do: updated, else: item end)
    end

    defp unique_error(struct, field) do
      struct
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(field, "has already been taken", constraint: :unique)
    end

    defp next_user_id do
      state().users
      |> Enum.map(& &1.id)
      |> Enum.max(fn -> 100 end)
      |> Kernel.+(1)
    end

    defp next_identity_id do
      state().identities
      |> Enum.map(& &1.id)
      |> Enum.max(fn -> 100 end)
      |> Kernel.+(1)
    end

    defp state, do: Sigra.OAuth.EnterpriseReconciliationTest.get_state()
    defp update_state(fun), do: Sigra.OAuth.EnterpriseReconciliationTest.update_state(fun)
  end

  setup do
    put_state(%{
      users: [],
      identities: [],
      memberships: [],
      invitations: []
    })

    :ok
  end

  test "existing identity wins first and reuses existing membership" do
    user = %Sigra.Test.MockUser{id: 42, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}

    put_state(%{
      users: [user],
      identities: [
        %Sigra.Test.MockIdentity{
          id: 7,
          user_id: 42,
          provider: "oidc",
          provider_uid: "provider_uid_123",
          metadata: %{"enterprise_connection_id" => "conn-acme"}
        }
      ],
      memberships: [
        %TestMembership{id: "member-1", organization_id: "org-acme", user_id: 42, role: :member}
      ],
      invitations: []
    })

    assert {:ok, :logged_in, resolved_user, metadata} =
             EnterpriseReconciliation.reconcile(
               build_config(),
               :oidc,
               mock_user_info(),
               mock_token(),
               enterprise_context()
             )

    assert resolved_user.id == 42
    assert metadata.enterprise_reconciliation_outcome == :existing_membership
  end

  test "auto-claim requires one verified exact email match and creates membership" do
    user = %Sigra.Test.MockUser{id: 52, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}
    put_state(%{users: [user], identities: [], memberships: [], invitations: []})

    assert {:ok, :logged_in, resolved_user, metadata} =
             EnterpriseReconciliation.reconcile(
               build_config(),
               :oidc,
               mock_user_info(),
               mock_token(),
               enterprise_context()
             )

    assert resolved_user.id == 52
    assert metadata.enterprise_reconciliation_outcome == :jit_created

    state = get_state()
    assert Enum.any?(state.identities, &(&1.user_id == 52))
    assert Enum.any?(state.memberships, &(&1.user_id == 52 and &1.organization_id == "org-acme"))
  end

  test "duplicate email matches fail closed" do
    put_state(%{
      users: [
        %Sigra.Test.MockUser{id: 1, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]},
        %Sigra.Test.MockUser{id: 2, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}
      ],
      identities: [],
      memberships: [],
      invitations: []
    })

    assert {:error, :ambiguous_email_match} =
             EnterpriseReconciliation.reconcile(
               build_config(),
               :oidc,
               mock_user_info(),
               mock_token(),
               enterprise_context()
             )
  end

  test "provider subject conflict fails closed when identity is bound to another connection" do
    put_state(%{
      users: [
        %Sigra.Test.MockUser{id: 42, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}
      ],
      identities: [
        %Sigra.Test.MockIdentity{
          id: 7,
          user_id: 42,
          provider: "oidc",
          provider_uid: "provider_uid_123",
          metadata: %{"enterprise_connection_id" => "conn-other"}
        }
      ],
      memberships: [],
      invitations: []
    })

    assert {:error, :provider_subject_conflict} =
             EnterpriseReconciliation.reconcile(
               build_config(),
               :oidc,
               mock_user_info(),
               mock_token(),
               enterprise_context()
             )
  end

  test "exact pending invite is consumed before default jit membership" do
    put_state(%{
      users: [
        %Sigra.Test.MockUser{id: 77, email: "oauth@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}
      ],
      identities: [],
      memberships: [],
      invitations: [
        %TestInvitation{
          id: "invite-1",
          organization_id: "org-acme",
          email: "oauth@example.com",
          role: :admin
        }
      ]
    })

    assert {:ok, :logged_in, resolved_user, metadata} =
             EnterpriseReconciliation.reconcile(
               build_config(),
               :oidc,
               mock_user_info(),
               mock_token(),
               enterprise_context()
             )

    assert resolved_user.id == 77
    assert metadata.enterprise_reconciliation_outcome == :invitation_consumed

    state = get_state()
    invitation = Enum.find(state.invitations, &(&1.id == "invite-1"))
    membership = Enum.find(state.memberships, &(&1.user_id == 77))

    assert invitation.accepted_by_id == 77
    assert invitation.accepted_at
    assert membership.role == :admin
  end

  def get_state do
    Process.get({__MODULE__, :state}, %{users: [], identities: [], memberships: [], invitations: []})
  end

  def update_state(fun) do
    put_state(fun.(get_state()))
  end

  defp put_state(state) do
    Process.put({__MODULE__, :state}, state)
  end

  defp enterprise_context do
    %{
      organization_id: "org-acme",
      connection_id: "conn-acme",
      routing_source: :explicit_org
    }
  end

  defp build_config do
    %{
      repo: Repo,
      user_schema: Sigra.Test.MockUser,
      identity_schema: Sigra.Test.MockIdentity,
      oauth: [session_type: :remember_me, trust_provider_email: true],
      schemas: %{
        organization: TestOrganization,
        membership: TestMembership,
        invitation: TestInvitation
      }
    }
  end
end
