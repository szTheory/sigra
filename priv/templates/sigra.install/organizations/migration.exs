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
      # D-00: sticky origin owner (added Phase 18). Write-once on insert; :nilify_all so the org row survives owner account deletion.
      add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      # D-01: personal-workspace flag (added Phase 18). Sticky origin, NOT current state — a personal org stays `personal: true` even after inviting others.
      add :personal, :boolean, null: false, default: false
      # Phase 91 B2B-01: org-level MFA enforcement.
      add :enforce_mfa_for_members, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: only enforce slug uniqueness for active orgs.
    # Soft-deleted orgs release their slug for reclamation (D-09).
    create unique_index(:organizations, [:slug],
      where: "deleted_at IS NULL",
      name: :organizations_slug_active_index
    )

    # D-01 / D-03: at-most-one-personal-org-per-user. Structural invariant AND
    # insert-safety backstop for Sigra.Upgrade.Backfill (Plan 18-02). Postgres
    # partial unique index — one row per owner_user_id where personal = true.
    create unique_index(:organizations, [:owner_user_id],
      where: "personal = true",
      name: :organizations_personal_owner_uidx
    )

    # ── Organization Memberships ───────────────────────────────────────
    create table(:organization_memberships<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      # Phase 92 / Plan 92-02: nullable host-owned role storage.
      # The library no longer ships a canonical role taxonomy; the
      # generated wrapper passes `roles:` / `owner_role:` /
      # `invitation_admin_roles:` to `use Sigra.Organizations`.
      add :role, :string
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
      # Phase 92 / B2B-02 (CR-03 fix): nullable host-owned role storage,
      # mirroring the memberships column above. The library no longer
      # ships a canonical role taxonomy and therefore cannot bake a
      # `default: "member"` opinion into the schema. Application-level
      # enforcement of the configured `:roles` universe lives in
      # `Sigra.Organizations.Invitations.create/2`.
      add :role, :string
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :invited_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :accepted_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :revoked_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: prevent duplicate pending invites per org+email (D-12).
    create unique_index(:organization_invitations, [:organization_id, :email],
      where: "accepted_at IS NULL AND revoked_at IS NULL",
      name: :organization_invitations_pending_index
    )

    create unique_index(:organization_invitations, [:hashed_token])

    # ── Organization Slug Aliases ──────────────────────────────────────
    # Tracks previous slugs for 7 days after a slug change so the
    # `LoadOrganizationFromSlug` plug can redirect old URLs to the
    # canonical slug (Phase 16 D-13). Old-slug uniqueness is enforced
    # only while `expires_at > now()` so expired aliases can be
    # reclaimed by another organization.
    create table(:organization_slug_aliases<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :old_slug, :citext, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:organization_slug_aliases, [:organization_id])
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
      name: :organization_slug_aliases_old_slug_idx
    )
  end

  def down do
    drop table(:organization_slug_aliases)
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
      # D-00: sticky origin owner (added Phase 18). Write-once on insert; :nilify_all so the org row survives owner account deletion.
      add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      # D-01: personal-workspace flag (added Phase 18). Sticky origin, NOT current state — a personal org stays `personal: true` even after inviting others.
      add :personal, :boolean, null: false, default: false
      # Phase 91 B2B-01: org-level MFA enforcement.
      add :enforce_mfa_for_members, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    # MySQL/SQLite: no partial index support. Application-level handles
    # soft-delete slug reclamation.
    create unique_index(:organizations, [:slug])

    # D-01: MySQL/SQLite lack partial unique indexes. Application-level guard
    # in Sigra.Organizations enforces at-most-one-personal-org-per-user;
    # this composite index provides a best-effort structural hint.
    create unique_index(:organizations, [:owner_user_id, :personal],
      name: :organizations_personal_owner_uidx
    )

    # ── Organization Memberships ───────────────────────────────────────
    create table(:organization_memberships<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      # Phase 92 / Plan 92-02: nullable host-owned role storage.
      # See the postgres branch above for full rationale.
      add :role, :string
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
      # Phase 92 / B2B-02 (CR-03 fix): nullable host-owned role storage.
      # See the postgres branch above for full rationale.
      add :role, :string
      add :hashed_token, :binary
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :invited_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :accepted_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :revoked_by_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # MySQL/SQLite: no partial index. Composite unique index as fallback.
    create unique_index(:organization_invitations, [:organization_id, :email, :accepted_at, :revoked_at])
    create unique_index(:organization_invitations, [:hashed_token])

    # ── Organization Slug Aliases ──────────────────────────────────────
    # Tracks previous slugs for 7 days after a slug change (Phase 16 D-13).
    # MySQL/SQLite: no partial-index support — enforce uniqueness on
    # `old_slug` alone. Application-level cleanup removes expired rows
    # before the old_slug becomes reclaimable.
    create table(:organization_slug_aliases<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :organization_id, references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :old_slug, :string, null: false, size: 63
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:organization_slug_aliases, [:organization_id])
    # Phase 17 Plan 08: rename to match the postgres branch (Option A).
    # MySQL/SQLite already used a plain unique_index under the legacy
    # `old_slug_active_idx` name — this rename only harmonizes the two
    # adapter branches and introduces no behavior change.
    create unique_index(:organization_slug_aliases, [:old_slug],
      name: :organization_slug_aliases_old_slug_idx
    )
  end

  def down do
    drop table(:organization_slug_aliases)
    drop table(:organization_invitations)
    drop table(:organization_memberships)
    drop table(:organizations)
  end
<% end %>
end
