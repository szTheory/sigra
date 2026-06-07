defmodule <%= repo_module %>.Migrations.AddPersonalToOrganizations do
  @moduledoc """
  Phase 18 D-01: add `personal` column + partial unique index
  enforcing at-most-one-personal-org-per-user.

  Runs AFTER `AddOwnerUserIdToOrganizations` — the partial unique
  index references `owner_user_id`, so the column must exist first.

  Uses `add_if_not_exists` / `create_if_not_exists` so a re-run on a
  schema that already has the column is a safe no-op.
  """

  use Ecto.Migration

  def up do
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      execute(
        """
        DO $$
        BEGIN
          IF to_regclass('organizations') IS NOT NULL THEN
            IF NOT EXISTS (
              SELECT 1 FROM information_schema.columns
              WHERE table_schema = current_schema()
                AND table_name = 'organizations'
                AND column_name = 'personal'
            ) THEN
              ALTER TABLE organizations
                ADD COLUMN personal boolean NOT NULL DEFAULT false;
            END IF;
          END IF;
        END$$;
        """,
        ""
      )

      execute(
        """
        DO $$
        BEGIN
          IF to_regclass('organizations') IS NOT NULL THEN
            EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS organizations_personal_owner_uidx
              ON organizations (owner_user_id)
              WHERE personal = true';
          END IF;
        END$$;
        """,
        "DROP INDEX IF EXISTS organizations_personal_owner_uidx"
      )
    else
      alter table(:organizations) do
        add_if_not_exists :personal, :boolean, null: false, default: false
      end

      create_if_not_exists unique_index(:organizations, [:owner_user_id],
                             where: "personal = true",
                             name: :organizations_personal_owner_uidx
                           )
    end
  end

  def down do
    if repo().__adapter__() == Ecto.Adapters.Postgres do
      execute(
        "DROP INDEX IF EXISTS organizations_personal_owner_uidx",
        """
        DO $$
        BEGIN
          IF to_regclass('organizations') IS NOT NULL THEN
            EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS organizations_personal_owner_uidx
              ON organizations (owner_user_id)
              WHERE personal = true';
          END IF;
        END$$;
        """
      )
    else
      drop_if_exists index(:organizations, [:owner_user_id],
                       name: :organizations_personal_owner_uidx
                     )
    end

    if repo().__adapter__() == Ecto.Adapters.Postgres do
      execute(
        """
        DO $$
        BEGIN
          IF to_regclass('organizations') IS NOT NULL
             AND EXISTS (
               SELECT 1 FROM information_schema.columns
               WHERE table_schema = current_schema()
                 AND table_name = 'organizations'
                 AND column_name = 'personal'
             ) THEN
            ALTER TABLE organizations
              DROP COLUMN personal;
          END IF;
        END$$;
        """,
        ""
      )
    else
      alter table(:organizations) do
        remove_if_exists :personal, :boolean
      end
    end
  end
end
