defmodule Example.Repo.Migrations.CreateOrganizationSlugAliases do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def up do
    create table(:organization_slug_aliases, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :organization_id,
        references(
          :organizations,
          Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)
        ),
        null: false
      )

      add(:old_slug, :citext, null: false)
      add(:expires_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create(index(:organization_slug_aliases, [:organization_id], @prefix_opts))

    # Phase 16 Plan 01 D-13: the library would prefer a partial unique index
    # scoped to `expires_at > now()` but Postgres rejects `now()` in index
    # predicates (not IMMUTABLE). For the test example app we use a plain
    # unique index on `old_slug`; application-level cleanup removes expired
    # rows before the old_slug becomes reclaimable.
    create(
      unique_index(
        :organization_slug_aliases,
        [:old_slug],
        Keyword.merge(@prefix_opts, name: :organization_slug_aliases_old_slug_active_idx)
      )
    )
  end

  def down do
    drop(table(:organization_slug_aliases, @prefix_opts))
  end
end
