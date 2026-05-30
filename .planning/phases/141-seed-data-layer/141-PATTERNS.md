# Phase 141: Seed Data Layer - Pattern Map

**Mapped:** 2026-05-29
**Files analyzed:** 6 (4 created, 2 modified)
**Analogs found:** 6 / 6 (4 codebase analogs, 2 canonical-ref-driven)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/lib/example/accounts/user_identity.ex` (NEW) | model (schema) | CRUD | `priv/templates/sigra.gen.oauth/user_identity.ex` (library template) + `accounts/user_mfa_credential.ex` | exact (de-templated) |
| `test/example/priv/repo/migrations/*_create_user_identities.exs` (NEW) | migration | CRUD | `priv/repo/migrations/20260415000002_create_user_passkeys.exs` + `sigra.gen.oauth/oauth_migration.exs` | exact |
| `test/example/lib/example/demo/personas.ex` (NEW) | utility (pure data) | transform | — none (no `Example.Demo.*` exists) | no analog — see "No Analog Found" |
| `test/example/lib/example/demo/seeds.ex` (NEW) | service (orchestrator) | batch / CRUD upsert | — none; built from canonical changeset refs below | no analog — see "No Analog Found" |
| `test/example/priv/repo/seeds.exs` (MODIFIED) | config / script | batch | current file (header-only comment block) | role-match |
| `test/example/config/dev.exs` (MODIFIED) | config | — | `test/example/config/test.exs:47` (argon2 override) | exact (adapt cost) |

---

## Pattern Assignments

### `test/example/lib/example/accounts/user_identity.ex` (NEW schema, CRUD)

**Primary analog:** `priv/templates/sigra.gen.oauth/user_identity.ex` (the library's own generator template — de-template the EEx tags). **Secondary analog:** `test/example/lib/example/accounts/user_mfa_credential.ex` (a concrete, non-templated example-app schema with the identical header conventions).

**MUST satisfy `Sigra.Admin.Users.Detail.list_identities/3`** (`lib/sigra/admin/users/detail.ex:120-133`). That query is the contract:
```elixir
from(identity in identity_schema,
  where: identity.user_id == ^user.id,
  order_by: [asc: identity.provider, asc: identity.inserted_at]
)
```
Required fields for the admin surface to render Carol's row: `user_id` (FK), `provider`, `inserted_at` (from `timestamps`). The admin auto-detects the schema via `optional_schema(accounts_module, :UserIdentity)` — naming the module `Example.Accounts.UserIdentity` is what wires it in (`detail.ex:274,278`). No library change needed.

**Schema header + PK conventions** — copy verbatim from `user_mfa_credential.ex:12-17` (this is the example-app convention, identical across every `accounts/*.ex` schema):
```elixir
use Ecto.Schema
import Ecto.Changeset

@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

**Schema block + changeset** — de-templated from `sigra.gen.oauth/user_identity.ex:18-61`. Use the example app's passthrough Cloak type `Example.Accounts.Encrypted.Binary` (same as `user_mfa_credential.ex:21`, `user_passkey.ex:18`). Keep it minimal per D-09 / Claude's Discretion — but the template's full field set is idiomatic and matches the OAuth callback path:
```elixir
schema "user_identities" do
  field :provider, :string
  field :provider_uid, :string
  field :encrypted_access_token, Example.Accounts.Encrypted.Binary
  field :encrypted_refresh_token, Example.Accounts.Encrypted.Binary
  field :token_expires_at, :utc_datetime
  field :provider_email, :string
  field :provider_name, :string
  field :provider_avatar_url, :string
  field :metadata, :map, default: %{}
  field :last_used_at, :utc_datetime

  belongs_to :user, Example.Accounts.User

  timestamps(type: :utc_datetime)
end

def changeset(identity, attrs) do
  identity
  |> cast(attrs, [
    :provider, :provider_uid, :encrypted_access_token, :encrypted_refresh_token,
    :token_expires_at, :provider_email, :provider_name, :provider_avatar_url,
    :metadata, :last_used_at, :user_id
  ])
  |> validate_required([:provider, :provider_uid, :user_id])
  |> update_change(:provider, &String.downcase/1)
  |> unique_constraint([:user_id, :provider])
  |> unique_constraint([:provider, :provider_uid])
  |> foreign_key_constraint(:user_id)
end
```
The changeset is named `changeset/2` (template convention), NOT `create_changeset/2`. Seed Carol's row with `provider: "github"`, a fabricated `provider_uid`, `provider_email: "carol@demo.sigra.dev"`. `on_conflict: :nothing` keyed on the `[:user_id, :provider]` unique index (D-02).

---

### `test/example/priv/repo/migrations/*_create_user_identities.exs` (NEW migration, CRUD)

**Primary analog:** `priv/repo/migrations/20260415000002_create_user_passkeys.exs` (concrete example-app migration; gives the exact `create table(..., primary_key: false)` + `add :id, :binary_id, primary_key: true` + `references(:users, type: :binary_id, on_delete: :delete_all)` style). **Field-list source:** `sigra.gen.oauth/oauth_migration.exs:4-25` (de-template).

**Module name:** `Example.Repo.Migrations.CreateUserIdentities` (matches `Example.Repo.Migrations.*` namespace in every existing migration). **Filename:** new timestamp `> 20260526043000` (latest existing migration). Use a 2026-05-29 stamp.

**DDL pattern** (combine passkey-migration binary_id style with the oauth template's field list and indexes):
```elixir
defmodule Example.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  def change do
    create table(:user_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :encrypted_access_token, :binary
      add :encrypted_refresh_token, :binary
      add :token_expires_at, :utc_datetime
      add :provider_email, :string
      add :provider_name, :string
      add :provider_avatar_url, :string
      add :metadata, :map, default: %{}
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_identities, [:user_id, :provider])
    create unique_index(:user_identities, [:provider, :provider_uid])
    create index(:user_identities, [:user_id])
  end
end
```
The `[:user_id, :provider]` unique index is the `on_conflict:` target for Carol's idempotent upsert (D-02).

---

### `test/example/lib/example/demo/personas.ex` (NEW, pure data)

**No codebase analog** — first `Example.Demo.*` module. Pure-data module: persona structs/maps + the deterministic TOTP secret module attribute. No DB, no deps on other modules (single source of truth, per Claude's Discretion + SUMMARY architecture).

**Deterministic TOTP secret (D-05)** — exact derivation and label are non-negotiable:
```elixir
# Demo-only — intentionally deterministic. Never use in production.
@demo_totp_secret :crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)
```
This raw 20-byte binary is stored directly into `UserMFACredential.encrypted_secret` (the `Encrypted.Binary` passthrough type stores raw binary; no real encryption). Used by both `admin` and `bob` personas (D-06).

**Persona roster (fixed, 6 rows)** — from SUMMARY.md table, all `@demo.sigra.dev`:
| handle | email | state to patch after register |
|--------|-------|--------------------------------|
| admin | admin@demo.sigra.dev | confirmed; TOTP; passkey display row; owner Acme + member Beta; audit trail |
| alice | alice@demo.sigra.dev | confirmed; member Acme |
| bob | bob@demo.sigra.dev | confirmed; TOTP; owner Beta |
| carol | carol@demo.sigra.dev | confirmed; UserIdentity (github) |
| dave | dave@demo.sigra.dev | `failed_login_attempts: 5`, `locked_at` set, `hashed_password` cleared |
| frank | frank@demo.sigra.dev | confirmed; `deleted_at` + `scheduled_deletion_at` set |

Passwords must satisfy `Sigra.PasswordPolicy.validate/1` — `DemoAdmin1!` format (12+ chars, mixed case, digit, symbol; pitfall #2). Public-by-design.

---

### `test/example/lib/example/demo/seeds.ex` (NEW, idempotent upsert orchestrator)

**No codebase analog.** Build from the canonical changeset refs below. Orchestration shape (D-01/D-02): for each persona, (1) register through the context API to fire audit events, (2) patch state-only fields via direct `Repo.update!`, (3) insert association rows with `on_conflict: :nothing`. No hard-coded UUIDs; fetch generated PKs after upsert for cross-references.

**User creation (D-01)** — `Example.Accounts.register_user/1` (`accounts.ex:98`). Delegates to `Sigra.Auth.register/3` with `User.registration_changeset/2` which casts `[:email, :display_name, :password]` (`user.ex:47-52`) and hashes the password. Creates an **unconfirmed** user. Returns `{:ok, %User{}}` | `{:error, :email_taken}` | `{:error, changeset}`. Idempotency: re-runs hit `{:error, :email_taken}` → fetch existing via `Accounts.get_user_by_email/1` (`accounts.ex:31`).
```elixir
{:ok, user} = Example.Accounts.register_user(%{
  email: "admin@demo.sigra.dev",
  display_name: "Demo Admin",
  password: "DemoAdmin1!"
})
```

**State-only field patches (D-01)** — the context API does NOT expose these; use `User` changesets directly + `Repo.update!`:
- Confirm: `User.confirm_changeset(user)` (`user.ex:140-143`) → sets `confirmed_at`.
- Frank's scheduled deletion + Dave's password clear: `User.deletion_changeset(user, attrs)` (`user.ex:161-171`) casts `[:deleted_at, :scheduled_deletion_at, :original_email, :pending_email, :email, :hashed_password]`. Clear Dave's password with `hashed_password: nil`.
- Dave's lockout (`failed_login_attempts: 5`, `locked_at`): no dedicated changeset — use `Ecto.Changeset.change(user, failed_login_attempts: 5, locked_at: ts)` then `Repo.update!`.

**D-06 TOTP credential (admin, bob)** — `Example.Accounts.UserMFACredential.create_changeset/2` (`user_mfa_credential.ex:32-38`), casts `[:user_id, :type, :encrypted_secret, :enabled_at]`:
```elixir
%Example.Accounts.UserMFACredential{}
|> Example.Accounts.UserMFACredential.create_changeset(%{
  user_id: user.id, type: "totp",
  encrypted_secret: @demo_totp_secret, enabled_at: ~U[...]
})
|> Repo.insert!(on_conflict: :nothing, conflict_target: [:user_id, :type])
```
Do NOT use `Sigra.Testing.setup_totp/2` (random secret — breaks determinism).

**D-07 admin passkey (display-only)** — `Example.Accounts.UserPasskey.create_changeset/2` (`user_passkey.ex:31-51`), requires `[:user_id, :credential_id, :public_key]`; zero Wax validation, so a fabricated binary inserts cleanly. `on_conflict: :nothing, conflict_target: [:credential_id]`. Comment "display-only; will not authenticate" (pitfall #6).

**D-08 EnterpriseConnection (Acme Corp SSO)** — `Example.Accounts.EnterpriseConnection.changeset/2` (`enterprise_connection.ex:26-44`). `status: :active` (enum `[:draft, :validation_failed, :active, :disabled]` — `configured`/`pending` are WRONG). The nested `oidc_settings` embed is `cast_embed(required: true)` — a flat insert raises. `EnterpriseConnectionOIDCSettings.changeset/2` (`enterprise_connection_oidc_settings.ex:15-30`) requires `[:issuer, :client_id, :encrypted_client_secret, :client_authentication_method]`; `client_authentication_method` must be `"client_secret_basic"` or `"client_secret_post"`:
```elixir
%Example.Accounts.EnterpriseConnection{}
|> Example.Accounts.EnterpriseConnection.changeset(%{
  organization_id: acme.id, status: :active, display_name: "Acme Corp SSO",
  oidc_settings: %{
    issuer: "https://sso.acme-demo.example",
    client_id: "acme-demo-client",
    encrypted_client_secret: "demo-secret-not-real",
    client_authentication_method: "client_secret_basic"
  }
})
|> Repo.insert!(on_conflict: :nothing,
     conflict_target: {:constraint, :enterprise_connections_active_display_name_index})
```
Unique on `display_name` via `enterprise_connections_active_display_name_index` (`enterprise_connection.ex:43`).

**D-11 audit events (≥15 rows, ≥6 actions)** — `Example.Accounts.AuditEvent.changeset/3` (`audit_event.ex:49-51`) delegates to `Sigra.Audit.Changeset.changeset/3`. CRITICAL: `validate_required([:action, :outcome, :occurred_at])` (`changeset.ex:71`) and **the listed D-11 actions all use reserved prefixes** (`auth.`, `mfa.`, `session.`, `admin.` is NOT reserved but `auth./mfa./session.` ARE — see `@default_reserved = ~w(auth. session. mfa. oauth. api. account. sigra.)` at `changeset.ex:26`). Reserved actions are rejected unless you pass `allow_reserved: true`:
```elixir
%Example.Accounts.AuditEvent{}
|> Example.Accounts.AuditEvent.changeset(%{
    action: "auth.login.success", outcome: "success",
    occurred_at: ts, actor_id: admin.id, effective_user_id: admin.id
  }, allow_reserved: true)
|> Repo.insert!()
```
TIE-TO-USER CONTRACT: admin detail filters a user's audit by `effective_user_id == user_id OR target_id == user_id` (`lib/sigra/admin/audit/query.ex:32`). For audit rows to appear on the admin persona's detail page, set `effective_user_id` (or `target_id`) to admin's id — `actor_id` alone is not enough. Cast fields available: `[:action, :outcome, :actor_id, :actor_type, :target_id, :target_type, :ip_address, :user_agent, :metadata, :occurred_at, :organization_id, :effective_user_id]` (`changeset.ex:30-43`). Spread `occurred_at` over a deterministic past-30-days window (`metadata`/`occurred_at` are insert-time; audit table is append-only, no `updated_at`). Audit rows have no natural unique index — guard idempotency by checking row count / clearing demo audit rows first, or by deterministic `id` stamping; prefer "insert only if `Repo.aggregate(AuditEvent, :count)` below threshold" guard since `on_conflict` has no target here.

**D-12 orgs / memberships / invitation** — Acme Corp (admin=owner, alice=member, carol=member) + Beta Labs (admin=member, bob=owner) + one pending invitation to `invited@demo.sigra.dev`:
- `Organization.changeset/2` (`organization.ex:28-38`) casts `[:name, :slug, :deleted_at]`; slug must match `~r/^[a-z][a-z0-9-]*[a-z0-9]$/` (min 3 chars). Unique on `organizations_slug_active_index`. Note: `owner_user_id` / `personal` are NOT cast (library-managed) — set owner via the membership `role: :owner`, or `put_change`/direct field if the seed needs the FK. `on_conflict: :nothing, conflict_target: ... :slug`.
- `OrganizationMembership.changeset/2` (`organization_membership.ex:18-25`) casts `[:role, :user_id, :organization_id]`; role enum `[:owner, :admin, :member]`. Unique `[:user_id, :organization_id]` → `on_conflict: :nothing, conflict_target: [:user_id, :organization_id]`.
- `OrganizationInvitation.changeset/2` (`organization_invitation.ex:25-44`) requires `[:email, :role, :expires_at, :organization_id]`. Unique `[:organization_id, :email]` via `organization_invitations_pending_index` → `on_conflict: :nothing`.

---

### `test/example/priv/repo/seeds.exs` (MODIFIED, script)

Currently header-comment-only (`seeds.exs:1-12`). Add the **D-03 raise-guard at the very top, before any DB access**, then call the orchestrator:
```elixir
if Mix.env() == :test do
  raise "seeds.exs must not run in MIX_ENV=test — it would contaminate the sandboxed CI fixture DB. Run with MIX_ENV=dev."
end

Example.Demo.Seeds.run()
```
The guard must raise BEFORE touching the DB (two-layer defense; the `test` alias at `mix.exs:85` already never calls this file — do not change that).

---

### `test/example/config/dev.exs` (MODIFIED, config)

**Analog:** `test/example/config/test.exs:46-47`:
```elixir
# Speed up password hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8
```
**Adapt for dev (D-04)** — append to `dev.exs` (which currently has NO argon2 override). Use the DEV cost `t_cost: 2, m_cost: 12` (NOT the test cost), with an explicit security comment:
```elixir
# Demo seed path uses real Argon2id at a reduced dev cost so `mix setup`
# stays fast (~20-50ms/hash). Do NOT lower further; do NOT copy to prod.
config :argon2_elixir, t_cost: 2, m_cost: 12
```
Isolated to dev; test.exs keeps `t_cost: 1, m_cost: 8`; prod untouched.

---

## Shared Patterns

### Example-app schema header (every `accounts/*.ex`)
**Source:** `user_mfa_credential.ex:12-17`, `user_passkey.ex:9-13`, `organization.ex:3-7`
**Apply to:** `user_identity.ex`
```elixir
use Ecto.Schema
import Ecto.Changeset

@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

### Idempotent upsert (D-02)
**Apply to:** every `Repo.insert!` in `seeds.ex`
- Users: register via context, dedupe on `{:error, :email_taken}` → fetch existing.
- Association rows: `Repo.insert!(changeset, on_conflict: :nothing, conflict_target: <existing unique index>)`.
- Conflict targets confirmed: users `:email`; mfa `[:user_id, :type]`; passkey `[:credential_id]`; org `:slug` (`organizations_slug_active_index`); membership `[:user_id, :organization_id]`; invitation `organization_invitations_pending_index`; identity `[:user_id, :provider]`; enterprise_connection `enterprise_connections_active_display_name_index`.
- Audit events have NO unique index → guard by count/threshold, not `on_conflict`.
- No hard-coded UUIDs; fetch generated PKs after upsert for cross-references.

### Passthrough Cloak type for binary secrets
**Source:** `Example.Accounts.Encrypted.Binary` (used in `user_mfa_credential.ex:21`, `user_passkey.ex:18`, `enterprise_connection_oidc_settings.ex:10`)
**Apply to:** `user_identity.ex` encrypted token fields; seed TOTP secret; passkey public_key; OIDC client secret. Stores RAW binary (no real encryption — documented as not-production). The deterministic 20-byte TOTP secret goes in directly.

### Reserved-prefix audit actions
**Source:** `lib/sigra/audit/changeset.ex:26,66-84`
**Apply to:** all D-11 audit inserts using `auth.*`, `session.*`, `mfa.*` actions → MUST pass `allow_reserved: true` as the 3rd changeset arg, else insert raises on the reserved-prefix validation. (`admin.*` is not reserved but passing `allow_reserved: true` uniformly is simplest.)

---

## No Analog Found

| File | Role | Data Flow | Reason / Substitute |
|------|------|-----------|---------------------|
| `lib/example/demo/personas.ex` | utility (pure data) | transform | No `Example.Demo.*` namespace exists. Pure-data module; pattern is the D-05 TOTP attr derivation + the SUMMARY persona table. No existing analog to copy structure from — keep idiomatic. |
| `lib/example/demo/seeds.ex` | service (orchestrator) | batch upsert | No existing seed orchestrator. Constructed entirely from the canonical changeset refs (D-06..D-12) listed in its Pattern Assignment above — each insert copies a concrete `*.changeset/create_changeset` from a real `accounts/*.ex` schema. |

---

## Metadata

**Analog search scope:** `test/example/lib/example/accounts/`, `test/example/priv/repo/migrations/`, `test/example/config/`, `priv/templates/sigra.gen.oauth/`, `lib/sigra/admin/` (audit query + user detail contract), `lib/sigra/audit/`.
**Files read:** user_mfa_credential.ex, user_passkey.ex, enterprise_connection.ex, enterprise_connection_oidc_settings.ex, organization.ex, organization_membership.ex, organization_invitation.ex, audit_event.ex, user.ex, accounts.ex, sigra.gen.oauth/user_identity.ex, sigra.gen.oauth/oauth_migration.exs, 20260415000002_create_user_passkeys.exs, config/test.exs, config/dev.exs, seeds.exs, lib/sigra/admin/users/detail.ex, lib/sigra/admin/audit/query.ex, lib/sigra/audit/changeset.ex.
**Pattern extraction date:** 2026-05-29
