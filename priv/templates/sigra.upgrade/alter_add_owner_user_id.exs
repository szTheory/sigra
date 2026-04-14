defmodule <%= repo_module %>.Migrations.AddOwnerUserIdToOrganizations do
  @moduledoc """
  Phase 18 D-00: add sticky `owner_user_id` to existing organizations.

  Populates the new column from the earliest `:owner` membership per
  org. Row count is bounded by `organizations` (typically small), so
  no batching is needed — a single `UPDATE ... FROM` does the work
  inside the schema migration's default DDL transaction.

  Runs BEFORE `AddPersonalToOrganizations` (the `personal` column
  migration depends on `owner_user_id` existing for the partial
  unique index predicate).
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :owner_user_id,
                        references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
    end

    # Populate from the earliest :owner membership per org.
    execute(
      """
      UPDATE organizations o SET owner_user_id = (
        SELECT m.user_id FROM organization_memberships m
        WHERE m.organization_id = o.id AND m.role = 'owner'
        ORDER BY m.inserted_at ASC
        LIMIT 1
      ) WHERE owner_user_id IS NULL
      """,
      ""
    )
  end

  def down do
    alter table(:organizations) do
      remove_if_exists :owner_user_id, references(:<%= table_name %>)
    end
  end
end
