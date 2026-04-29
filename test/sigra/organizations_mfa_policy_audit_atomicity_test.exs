defmodule Sigra.OrganizationsMfaPolicyAuditAtomicityTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule VerifyFailureTelemetryHandler do
    @moduledoc false
    def handle_event(event, measurements, metadata, parent) do
      send(parent, {:telemetry, event, measurements, metadata})
    end
  end

  defmodule Org do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :enforce_mfa_for_members, :boolean, default: false
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Membership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_memberships" do
      field :role, :string
      field :organization_id, :binary_id
      field :user_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Invitation do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organization_invitations" do
      field :email, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Scope do
    defstruct [:user, :active_organization, :membership]
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for table <- ["organization_memberships", "organization_invitations", "organizations", "audit_events", "users"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{table} CASCADE", [])
    end

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE users (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE organizations (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        name text,
        slug text,
        enforce_mfa_for_members boolean NOT NULL DEFAULT false,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE organization_memberships (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        role text,
        organization_id uuid NOT NULL,
        user_id uuid NOT NULL,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE organization_invitations (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        email text,
        inserted_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      repo,
      """
      CREATE TABLE audit_events (
        id uuid PRIMARY KEY,
        occurred_at timestamp NOT NULL DEFAULT now(),
        action varchar(255) NOT NULL,
        outcome varchar(32) NOT NULL DEFAULT 'success',
        actor_id uuid,
        actor_type varchar(64) NOT NULL DEFAULT 'user',
        target_id uuid,
        target_type varchar(64),
        ip_address varchar(64),
        user_agent varchar(512),
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        organization_id uuid,
        effective_user_id uuid,
        inserted_at timestamp NOT NULL DEFAULT now()
      )
      """,
      []
    )

    %{repo: repo}
  end

  defp cfg(repo, audit? \\ true) do
    %{
      repo: repo,
      schemas: %{
        organization: Org,
        membership: Membership,
        invitation: Invitation,
        user: User,
        scope: Scope
      },
      roles: [:owner, :admin, :member],
      owner_role: :owner,
      audit_schema: if(audit?, do: AuditTestEvent, else: nil),
      hooks: []
    }
  end

  defp scope(user, org) do
    %Scope{
      user: user,
      active_organization: org,
      membership: %Membership{role: "owner", organization_id: org.id, user_id: user.id}
    }
  end

  defp count_where(repo, table, where) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT count(*)::bigint FROM #{table} WHERE #{where}", [])

    n
  end

  test "happy path writes org flag and one audit row", %{repo: repo} do
    user = repo.insert!(%User{email: "owner@example.com"})
    org = repo.insert!(%Org{name: "Acme", slug: "acme"})

    assert {:ok, updated} =
             Sigra.Organizations.set_mfa_policy(
               cfg(repo),
               scope(user, org),
               org,
               true,
               mfa_check_fn: fn _ -> true end
             )

    assert updated.enforce_mfa_for_members
    assert repo.reload!(org).enforce_mfa_for_members
    assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 1
  end

  test "audit off succeeds without audit row", %{repo: repo} do
    user = repo.insert!(%User{email: "owner@example.com"})
    org = repo.insert!(%Org{name: "Acme", slug: "acme"})

    assert {:ok, updated} =
             Sigra.Organizations.set_mfa_policy(
               cfg(repo, false),
               scope(user, org),
               org,
               true,
               mfa_check_fn: fn _ -> true end
             )

    assert updated.enforce_mfa_for_members
    assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0
  end

  test "fault injection rolls back org write and returns :mfa_policy_aborted", %{repo: repo} do
    user = repo.insert!(%User{email: "owner@example.com"})
    org = repo.insert!(%Org{name: "Acme", slug: "acme"})
    telemetry_id = "mfa-policy-#{System.unique_integer([:positive])}"

    Ecto.Adapters.SQL.query!(
      repo,
      """
      ALTER TABLE audit_events
      ADD CONSTRAINT mfa_policy_change_guard CHECK (action <> 'organization.mfa_policy_change')
      """,
      []
    )

    :telemetry.attach(
      telemetry_id,
      [:sigra, :audit, :log_safe_error],
      &VerifyFailureTelemetryHandler.handle_event/4,
      self()
    )

    try do
      assert {:error, :mfa_policy_aborted} =
               Sigra.Organizations.set_mfa_policy(
                 cfg(repo),
                 scope(user, org),
                 org,
                 true,
                 mfa_check_fn: fn _ -> true end
               )

      assert repo.reload!(org).enforce_mfa_for_members == false
      assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0

      assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                      %{action: "organization.mfa_policy_change", reason: :constraint_violation}}
    after
      :telemetry.detach(telemetry_id)

      Ecto.Adapters.SQL.query!(
        repo,
        "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_policy_change_guard",
        []
      )
    end
  end

  test "no-op returns existing org and writes no audit row", %{repo: repo} do
    user = repo.insert!(%User{email: "owner@example.com"})
    org = repo.insert!(%Org{name: "Acme", slug: "acme", enforce_mfa_for_members: true})

    assert {:ok, same_org} =
             Sigra.Organizations.set_mfa_policy(
               cfg(repo),
               scope(user, org),
               org,
               true,
               mfa_check_fn: fn _ -> true end
             )

    assert same_org.id == org.id
    assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0
  end

  test "admin pre-flight returns :admin_must_enroll_first and writes no audit row", %{repo: repo} do
    user = repo.insert!(%User{email: "owner@example.com"})
    org = repo.insert!(%Org{name: "Acme", slug: "acme"})

    assert {:error, :admin_must_enroll_first} =
             Sigra.Organizations.set_mfa_policy(
               cfg(repo),
               scope(user, org),
               org,
               true,
               mfa_check_fn: fn _ -> false end
             )

    assert repo.reload!(org).enforce_mfa_for_members == false
    assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0
  end
end
