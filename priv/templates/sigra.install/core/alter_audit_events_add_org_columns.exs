defmodule <%= repo_module %>.Migrations.AlterAuditEventsAddOrgColumns do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    alter table(:audit_events) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at], concurrently: true)
  end

  def down do
    drop index(:audit_events, [:organization_id, :inserted_at])

    alter table(:audit_events) do
      remove :effective_user_id
      remove :organization_id
    end
  end
end
