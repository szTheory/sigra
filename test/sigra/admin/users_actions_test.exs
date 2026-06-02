defmodule Sigra.Admin.UsersActionsTest do
  use Sigra.Test.PostgresCase, async: false

  alias Ecto.Adapters.SQL
  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Actions
  alias Sigra.Admin.Users.Detail

  @repo Sigra.Test.PostgresRepo

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_action_users" do
      field :email, :string
      field :display_name, :string
      field :confirmed_at, :utc_datetime
      field :locked_at, :utc_datetime
      field :deleted_at, :utc_datetime
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule Organization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_action_organizations" do
      field :name, :string
      field :slug, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule OrganizationMembership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_action_organization_memberships" do
      field :role, :string
      belongs_to :organization, Organization, type: :binary_id
      belongs_to :user, User, type: :binary_id
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule UserSession do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_action_user_sessions" do
      field :user_id, :binary_id
      field :hashed_token, :binary
      field :type, :string
      field :ip, :string
      field :user_agent, :string
      field :last_active_at, :utc_datetime_usec
      field :active_organization_id, :binary_id
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end

  defmodule AuditEvent do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "admin_action_audit_events" do
      field :occurred_at, :utc_datetime_usec
      field :action, :string
      field :outcome, :string
      field :actor_id, :binary_id
      field :actor_type, :string
      field :target_id, :binary_id
      field :target_type, :string
      field :organization_id, :binary_id
      field :effective_user_id, :binary_id
      field :ip_address, :string
      field :user_agent, :string
      field :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    def changeset(event, attrs, opts \\ []) do
      Sigra.Audit.Changeset.changeset(event, attrs, opts)
    end
  end

  setup_all do
    Sigra.Test.PostgresCase.checkout_repo!(fn repo ->
      ddl = [
        """
        CREATE TABLE IF NOT EXISTS admin_action_users (
          id uuid PRIMARY KEY,
          email text NOT NULL,
          display_name text,
          confirmed_at timestamp,
          locked_at timestamp,
          deleted_at timestamp,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_action_organizations (
          id uuid PRIMARY KEY,
          name text NOT NULL,
          slug text NOT NULL,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_action_organization_memberships (
          id uuid PRIMARY KEY,
          user_id uuid NOT NULL,
          organization_id uuid NOT NULL,
          role text NOT NULL,
          inserted_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_action_user_sessions (
          id uuid PRIMARY KEY,
          user_id uuid NOT NULL,
          hashed_token bytea NOT NULL,
          type text NOT NULL,
          ip text,
          user_agent text,
          last_active_at timestamp,
          active_organization_id uuid,
          inserted_at timestamp NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS admin_action_audit_events (
          id uuid PRIMARY KEY,
          occurred_at timestamp,
          action text NOT NULL,
          outcome text,
          actor_id uuid,
          actor_type text,
          target_id uuid,
          target_type text,
          organization_id uuid,
          effective_user_id uuid,
          ip_address text,
          user_agent text,
          metadata jsonb,
          inserted_at timestamp NOT NULL
        )
        """
      ]

      Enum.each(ddl, &SQL.query!(repo, &1, []))
    end)

    :ok
  end

  setup do
    org = insert_org(%{id: Ecto.UUID.generate(), slug: "acme", name: "Acme Ops"})
    target_user = insert_user("target@example.com")
    other_user = insert_user("other@example.com")
    insert_membership(target_user.id, org.id)

    config =
      Sigra.Config.new!(
        repo: @repo,
        user_schema: User,
        session: [store: Sigra.SessionStores.Ecto, session_schema: UserSession],
        audit: [audit_schema: AuditEvent]
      )
      |> Map.merge(%{
        membership_schema: OrganizationMembership,
        organization_schema: Organization
      })

    %{
      config: config,
      org: org,
      target_user: target_user,
      other_user: other_user,
      global_scope: global_scope(),
      org_scope: org_scope(org),
      outside_scope: org_scope(%{org | id: Ecto.UUID.generate(), slug: "beta", name: "Beta Ops"})
    }
  end

  describe "Phase 28 action contracts" do
    test "revoke_session records the acting admin separately from the target user", %{
      config: config,
      target_user: user,
      global_scope: global_scope,
      outside_scope: outside_scope
    } do
      session = insert_session(user.id, %{ip: "10.0.0.8"})

      assert :ok = Actions.revoke_session(config, global_scope, user.id, session.hashed_token)
      refute @repo.get_by(UserSession, hashed_token: session.hashed_token)

      audit = @repo.get_by(AuditEvent, action: "session.delete")
      assert audit
      assert audit.target_id == user.id
      assert audit.actor_id == global_scope.scope.user.id
      assert audit.effective_user_id == user.id

      assert_raise Authorizer.UnauthorizedError, fn ->
        Actions.revoke_session(config, outside_scope, user.id, random_hashed_token())
      end
    end

    test "revoke_all_sessions preserves actor, target, and effective user attribution", %{
      config: config,
      target_user: user,
      org_scope: org_scope
    } do
      _first = insert_session(user.id, %{ip: "10.0.0.9"})
      _second = insert_session(user.id, %{ip: "10.0.0.10"})

      assert {2, nil} = Actions.revoke_all_sessions(config, org_scope, user.id)
      assert [] == @repo.all(UserSession)

      audit = @repo.get_by(AuditEvent, action: "session.revoke_all")
      assert audit
      assert audit.target_id == user.id
      assert audit.actor_id == org_scope.scope.user.id
      assert audit.effective_user_id == user.id
      assert audit.metadata["count"] == 2
    end

    test "audit preview contracts keep revoke semantics and target identity details visible", %{
      config: config,
      target_user: user,
      global_scope: global_scope
    } do
      session = insert_session(user.id)
      :ok = Actions.revoke_session(config, global_scope, user.id, session.hashed_token)
      {_count, nil} = Actions.revoke_all_sessions(config, global_scope, user.id)

      preview = Detail.recent_audit_preview(config, global_scope, user.id)

      assert Enum.any?(preview, &(&1.action == "session.delete"))
      assert Enum.any?(preview, &(&1.action == "session.revoke_all"))
      assert Enum.all?(preview, &(&1.action in ["session.delete", "session.revoke_all"]))
    end
  end

  defp insert_user(email) do
    now = DateTime.utc_now()
    confirmed_at = DateTime.truncate(now, :second)

    @repo.insert!(%User{
      id: Ecto.UUID.generate(),
      email: email,
      display_name: String.split(email, "@") |> hd(),
      confirmed_at: confirmed_at,
      inserted_at: now,
      updated_at: now
    })
  end

  defp insert_org(attrs) do
    now = DateTime.utc_now()
    @repo.insert!(struct!(Organization, Map.merge(%{inserted_at: now, updated_at: now}, attrs)))
  end

  defp insert_membership(user_id, org_id) do
    now = DateTime.utc_now()

    @repo.insert!(%OrganizationMembership{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      organization_id: org_id,
      role: "member",
      inserted_at: now,
      updated_at: now
    })
  end

  defp insert_session(user_id, attrs \\ %{}) do
    now = DateTime.utc_now()

    @repo.insert!(%UserSession{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      hashed_token: Map.get(attrs, :hashed_token, random_hashed_token()),
      type: "standard",
      ip: Map.get(attrs, :ip, "127.0.0.1"),
      user_agent: "ExUnit",
      last_active_at: now,
      active_organization_id: Map.get(attrs, :active_organization_id),
      inserted_at: now
    })
  end

  defp global_scope do
    %Scope{
      mode: :global,
      scope: %{user: %{id: Ecto.UUID.generate()}},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp org_scope(org) do
    %Scope{
      mode: :organization,
      scope: %{user: %{id: Ecto.UUID.generate()}},
      organization: org,
      organization_id: org.id,
      organization_slug: org.slug,
      platform_admin?: false,
      admin_org_ids: [org.id]
    }
  end

  defp random_hashed_token, do: :crypto.hash(:sha256, Ecto.UUID.generate())
end
