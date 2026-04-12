defmodule Example.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def up do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 255
      add :slug, :citext, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug],
      where: "deleted_at IS NULL",
      name: :organizations_slug_active_index
    )

    create table(:organization_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_memberships, [:user_id, :organization_id])
    create index(:organization_memberships, [:organization_id])

    create table(:organization_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :role, :string, null: false, default: "member"
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :accepted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

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
end
