defmodule <%= repo_module %>.Migrations.AddPersonalToOrganizations do
  @moduledoc """
  Adds the `personal` column + a partial unique index enforcing
  at-most-one-personal-org-per-user.

  Runs AFTER `AddOwnerUserIdToOrganizations` — the partial unique
  index references `owner_user_id`, so the column must exist first.

  Uses `add_if_not_exists` / `create_if_not_exists` so a re-run on a
  schema that already has the column is a safe no-op.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :personal, :boolean, null: false, default: false
    end

    create_if_not_exists unique_index(:organizations, [:owner_user_id],
                           where: "personal = true",
                           name: :organizations_personal_owner_uidx
                         )
  end

  def down do
    drop_if_exists index(:organizations, [:owner_user_id],
                     name: :organizations_personal_owner_uidx
                   )

    alter table(:organizations) do
      remove_if_exists :personal, :boolean
    end
  end
end
