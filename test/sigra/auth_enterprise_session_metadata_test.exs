defmodule Sigra.AuthEnterpriseSessionMetadataTest do
  use ExUnit.Case, async: true

  alias Sigra.Auth

  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    embedded_schema do
      field :email, :string
    end
  end

  defmodule TestOrganization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "organizations" do
      field :name, :string
      field :slug, :string
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule TestAuditEvent do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "audit_events" do
      field :action, :string
      field :outcome, :string
      field :actor_id, :binary_id
      field :actor_type, :string
      field :target_id, :binary_id
      field :target_type, :string
      field :ip_address, :string
      field :user_agent, :string
      field :metadata, :map
      field :occurred_at, :utc_datetime_usec
      field :organization_id, :binary_id
      field :effective_user_id, :binary_id
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end

  defmodule Repo do
    def get(TestOrganization, "org-acme") do
      %TestOrganization{id: "org-acme", slug: "acme", name: "Acme"}
    end

    def get(_schema, _id), do: nil

    def insert(%Ecto.Changeset{} = changeset) do
      event = Ecto.Changeset.apply_changes(changeset)
      Process.put({Sigra.AuthEnterpriseSessionMetadataTest, :last_audit_event}, event)
      {:ok, event}
    end
  end

  defmodule SessionStore do
    def create("user-1", _metadata, _opts) do
      {:ok,
       %Sigra.Session{
         id: "session-1",
         user_id: "user-1",
         hashed_token: "hashed-token",
         type: :remember_me,
         active_organization_id: nil,
         last_active_at: DateTime.utc_now(),
         inserted_at: DateTime.utc_now()
       }}
    end

    def update_active_organization(session, org_id, _opts) do
      {:ok, %{session | active_organization_id: org_id}}
    end
  end

  defmodule TestOrganizations do
    def __sigra_org_config__ do
      %{
        repo: Repo,
        schemas: %{organization: TestOrganization}
      }
    end
  end

  test "create_session logs first-session enterprise truth in audit metadata" do
    Process.delete({__MODULE__, :last_audit_event})

    config = %Sigra.Config{
      repo: Repo,
      user_schema: TestUser,
      scope_module: TestScope,
      organizations_module: TestOrganizations,
      audit: [audit_schema: TestAuditEvent],
      session: [
        store: SessionStore,
        idle_timeout: 1_800,
        absolute_timeout: 86_400,
        activity_update_threshold: 300,
        remember_me_max_age: 5_184_000,
        session_schema: TestUser
      ]
    }

    user = %TestUser{id: "user-1", email: "oauth@example.com"}

    metadata = %{
      type: :remember_me,
      active_organization_id: "org-acme",
      enterprise_connection_id: "conn-acme",
      enterprise_routing_source: :explicit_org,
      enterprise_reconciliation_outcome: :existing_membership
    }

    assert {:ok, session} = Auth.create_session(config, user, metadata)
    assert session.active_organization_id == "org-acme"

    audit_event = Process.get({__MODULE__, :last_audit_event})
    assert audit_event.action == "session.create"
    assert audit_event.organization_id == "org-acme"
    assert audit_event.metadata.active_organization_id == "org-acme"
    assert audit_event.metadata.enterprise_connection_id == "conn-acme"
    assert audit_event.metadata.enterprise_routing_source == :explicit_org
    assert audit_event.metadata.enterprise_reconciliation_outcome == :existing_membership
  end
end
