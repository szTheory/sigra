<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.AlterAuditEventsAddOrgColumns do
  use Ecto.Migration

<%= if adapter == :postgres do %>
  @disable_ddl_transaction true
  @disable_migration_lock true
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []

  def up do
    alter table(:audit_events, @prefix_opts) do
      add :organization_id, references(:organizations, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :nilify_all))
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at], Keyword.merge(@prefix_opts, concurrently: true))
  end

  def down do
    drop index(:audit_events, [:organization_id, :inserted_at], @prefix_opts)

    alter table(:audit_events, @prefix_opts) do
      remove :effective_user_id
      remove :organization_id
    end
  end
<% else %>
  def change do
    alter table(:audit_events) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at])
  end
<% end %>
end
