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
    # Idempotent column + FK add using a PL/pgSQL DO block.
    #
    # Why raw SQL: Ecto's `add_if_not_exists :col, references(...)` suppresses
    # the ADD COLUMN when the column exists but still emits a separate
    # ALTER TABLE ADD CONSTRAINT, which crashes with
    # `ERROR 42710 duplicate_object` on a fresh v1.1+ install where the
    # column and FK were already created by `mix sigra.install`. Postgres
    # has no `ADD CONSTRAINT IF NOT EXISTS` form, so we check
    # `information_schema.columns` and `pg_constraint` explicitly.
    execute(
      """
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'organizations' AND column_name = 'owner_user_id'
        ) THEN
          ALTER TABLE organizations
            ADD COLUMN owner_user_id <%= if binary_id do %>uuid<% else %>bigint<% end %>;
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'organizations_owner_user_id_fkey'
        ) THEN
          ALTER TABLE organizations
            ADD CONSTRAINT organizations_owner_user_id_fkey
            FOREIGN KEY (owner_user_id)
            REFERENCES <%= table_name %>(id)
            ON DELETE SET NULL;
        END IF;
      END$$;
      """,
      ""
    )

    # Populate from the earliest :owner membership per org.
    # Idempotent: WHERE owner_user_id IS NULL means a second run that
    # already populated from a prior backfill is a no-op.
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
    execute(
      """
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'organizations_owner_user_id_fkey'
        ) THEN
          ALTER TABLE organizations
            DROP CONSTRAINT organizations_owner_user_id_fkey;
        END IF;

        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'organizations' AND column_name = 'owner_user_id'
        ) THEN
          ALTER TABLE organizations
            DROP COLUMN owner_user_id;
        END IF;
      END$$;
      """,
      ""
    )
  end
end
