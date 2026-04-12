defmodule <%= repo_module %>.Migrations.CreateOrganizations do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  def up do
    # ── Organizations ──────────────────────────────────────────────────
    create table(:organizations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :name, :string, null: false, size: 255
      add :slug, :citext, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: only enforce slug uniqueness for active orgs.
    # Soft-deleted orgs release their slug for reclamation (D-09).
    create unique_index(:organizations, [:slug],
      where: "deleted_at IS NULL",
      name: :organizations_slug_active_index
    )

    # ── Organization Memberships ───────────────────────────────────────
    create table(:organization_memberships<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :role, :string, null: false, default: "member"
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_memberships, [:user_id, :organization_id])
    create index(:organization_memberships, [:organization_id])

    # ── Organization Invitations ───────────────────────────────────────
    create table(:organization_invitations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :citext, null: false
      add :role, :string, null: false, default: "member"
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :invited_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :accepted_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: prevent duplicate pending invites per org+email (D-12).
    create unique_index(:organization_invitations, [:organization_id, :email],
      where: "accepted_at IS NULL AND revoked_at IS NULL",
      name: :organization_invitations_pending_index
    )

    create index(:organization_invitations, [:hashed_token])
  end

  def down do
    drop table(:organization_invitations)
    drop table(:organization_memberships)
    drop table(:organizations)
  end
<% else %>
  def up do
    # ── Organizations ──────────────────────────────────────────────────
    create table(:organizations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :name, :string, null: false, size: 255
      add :slug, :string, null: false, size: 63
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # MySQL/SQLite: no partial index support. Application-level handles
    # soft-delete slug reclamation.
    create unique_index(:organizations, [:slug])

    # ── Organization Memberships ───────────────────────────────────────
    create table(:organization_memberships<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :role, :string, null: false, default: "member"
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_memberships, [:user_id, :organization_id])
    create index(:organization_memberships, [:organization_id])

    # ── Organization Invitations ───────────────────────────────────────
    create table(:organization_invitations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :string, null: false, size: 160
      add :role, :string, null: false, default: "member"
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :invited_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :accepted_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # MySQL/SQLite: no partial index. Composite unique index as fallback.
    create unique_index(:organization_invitations, [:organization_id, :email, :accepted_at, :revoked_at])
    create index(:organization_invitations, [:hashed_token])
  end

  def down do
    drop table(:organization_invitations)
    drop table(:organization_memberships)
    drop table(:organizations)
  end
<% end %>
end
