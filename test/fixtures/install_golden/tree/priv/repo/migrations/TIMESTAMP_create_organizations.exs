
defmodule SigraInstallGoldenTmp.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  @auth_prefix "auth"
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []

  def up do
    # ── Organizations ──────────────────────────────────────────────────
    create table(:organizations, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 255
      add :slug, :citext, null: false
      add :deleted_at, :utc_datetime
      # D-00: sticky origin owner (added Phase 18). Write-once on insert; :nilify_all so the org row survives owner account deletion.
      add :owner_user_id, references(:users, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :nilify_all]))
      # D-01: personal-workspace flag (added Phase 18). Sticky origin, NOT current state — a personal org stays `personal: true` even after inviting others.
      add :personal, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: only enforce slug uniqueness for active orgs.
    # Soft-deleted orgs release their slug for reclamation (D-09).
    create unique_index(:organizations, [:slug],
             Keyword.merge(@prefix_opts,
               where: "deleted_at IS NULL",
               name: :organizations_slug_active_index
             )
           )

    # D-01 / D-03: at-most-one-personal-org-per-user. Structural invariant AND
    # insert-safety backstop for Sigra.Upgrade.Backfill (Plan 18-02). Postgres
    # partial unique index — one row per owner_user_id where personal = true.
    create unique_index(:organizations, [:owner_user_id],
             Keyword.merge(@prefix_opts,
               where: "personal = true",
               name: :organizations_personal_owner_uidx
             )
           )

    # ── Organization Memberships ───────────────────────────────────────
    create table(:organization_memberships, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :organization_id, references(:organizations, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :user_id, references(:users, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_memberships, [:user_id, :organization_id], @prefix_opts)
    create index(:organization_memberships, [:organization_id], @prefix_opts)

    # ── Organization Invitations ───────────────────────────────────────
    create table(:organization_invitations, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :role, :string, null: false, default: "member"
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :invited_by_id, references(:users, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :nilify_all]))
      add :accepted_by_id, references(:users, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :nilify_all]))
      add :revoked_by_id, references(:users, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :nilify_all]))

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: prevent duplicate pending invites per org+email (D-12).
    create unique_index(:organization_invitations, [:organization_id, :email],
             Keyword.merge(@prefix_opts,
               where: "accepted_at IS NULL AND revoked_at IS NULL",
               name: :organization_invitations_pending_index
             )
           )

    create unique_index(:organization_invitations, [:hashed_token], @prefix_opts)

    # ── Organization Slug Aliases ──────────────────────────────────────
    # Tracks previous slugs for 7 days after a slug change so the
    # `LoadOrganizationFromSlug` plug can redirect old URLs to the
    # canonical slug (Phase 16 D-13). Old-slug uniqueness is enforced
    # only while `expires_at > now()` so expired aliases can be
    # reclaimed by another organization.
    create table(:organization_slug_aliases, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, Keyword.merge(@ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :old_slug, :citext, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:organization_slug_aliases, [:organization_id], @prefix_opts)
    # IMMUTABLE-safe slug-alias uniqueness (Phase 17 Plan 08 — Phase 16 hotfix).
    # Postgres rejects `now()` inside partial index predicates because it is
    # STABLE, not IMMUTABLE — a host running `mix ecto.migrate` would see
    # `ERROR: functions in index predicate must be marked IMMUTABLE`.
    #
    # The consumer query (`Sigra.Plug.LoadOrganizationFromSlug` via
    # `Sigra.Organizations.get_active_slug_alias/2`) already filters by
    # `expires_at > ^DateTime.utc_now()` at the application layer, so the
    # index-level partial predicate was structurally redundant. A full
    # unique index enforces "at most one row per old_slug" and is the same
    # shape the example app migration already uses (see
    # test/example/priv/repo/migrations/*_create_organization_slug_aliases.exs).
    # Cleanup of expired alias rows is application-level (hard-delete).
    create unique_index(:organization_slug_aliases, [:old_slug],
             Keyword.merge(@prefix_opts, name: :organization_slug_aliases_old_slug_idx)
           )
  end

  def down do
    drop table(:organization_slug_aliases, @prefix_opts)
    drop table(:organization_invitations, @prefix_opts)
    drop table(:organization_memberships, @prefix_opts)
    drop table(:organizations, @prefix_opts)
  end

end
