# Phase 141: Seed Data Layer - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Populate `test/example/priv/repo/seeds.exs` so an evaluator running `mix setup` in
`test/example/` gets a fully-populated demo database covering all six auth-state personas
(admin, alice, bob, carol, dave, frank), idempotent on re-run, with the example app's
security posture matching what Sigra ships to production.

**In scope:** the `Example.Demo.Personas` + `Example.Demo.Seeds` modules, the populated
`seeds.exs` with a `Mix.env() == :test` raise-guard, the `dev.exs` Argon2 cost override,
the six persona rows + supporting rows (orgs, memberships, pending invitation, MFA
credentials, passkey display row, EnterpriseConnection, audit events), and the **one new
schema** required to make Carol's OAuth state honest (`Example.Accounts.UserIdentity` +
migration).

**Out of scope:** the `/demo/credentials` LiveView (Phase 142), Playwright spec +
screenshots (Phase 143), README/guide (Phase 144), and any new API-token persistence/admin
surface (deferred — see D-09).
</domain>

<decisions>
## Implementation Decisions

All product/security decisions for this milestone are pre-locked in
`.planning/research/SUMMARY.md` ("Conflict Resolutions" + "Key Findings"). The decisions
below are the phase-specific implementation facts confirmed against live source, plus the
two roadmap-altering forks resolved during this discussion.

### Personas & Seeding Strategy
- **D-01:** Six hand-curated, role-descriptive personas — no Faker dep. Fixed emails in the
  reserved `@demo.sigra.dev` domain. Seed *through* `Example.Accounts.register_user/1`
  (creates an **unconfirmed** user; fires audit events), then patch state-only fields
  (`confirmed_at`, `locked_at`, `failed_login_attempts`, `deleted_at`,
  `scheduled_deletion_at`, and Dave's `hashed_password` clear) via direct `Repo.update!`.
  The context API does not expose these.
- **D-02:** Idempotency via natural keys + `on_conflict:` on every insert. Users keyed on
  email; association rows (MFA credential, passkey, org membership, invitation,
  EnterpriseConnection) use `on_conflict: :nothing` keyed on their existing unique indexes.
  **No hard-coded UUIDs** — let Postgres generate PKs; fetch generated IDs after upsert for
  cross-references. Success gate: run `seeds.exs` twice → no errors, no duplicates.

### Security Posture (non-negotiable)
- **D-03:** `Mix.env() == :test` raise-guard at the top of `seeds.exs` — must raise
  immediately with a clear message before touching any DB. The `test` mix alias already
  never calls `seeds.exs` (confirmed `mix.exs:85`); do not change that. Two-layer defense.
- **D-04:** Real Argon2id hashing at the **dev** cost override `t_cost: 2, m_cost: 12`,
  added to `test/example/config/dev.exs` (currently has **no** argon2 override). Do NOT use
  the test-env `t_cost: 1, m_cost: 8`. Do NOT copy this override into any non-dev config.
  Seeded passwords must satisfy `Sigra.PasswordPolicy.validate/1` (e.g. `DemoAdmin1!`
  format) and be documented as public-by-design.
- **D-05:** Deterministic demo-only TOTP secret as a module attribute in
  `Example.Demo.Personas`, derived `:crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |>
  binary_part(0, 20)`, labeled exactly `# Demo-only — intentionally deterministic. Never
  use in production.` Stored via the example app's passthrough `Encrypted.Binary` Cloak
  type (raw binary, no real encryption — already documented as not-production in source).

### Confirmed Schema Insert Shapes (research flags resolved against source)
- **D-06:** **TOTP (admin, bob):** direct insert via
  `Example.Accounts.UserMFACredential.create_changeset/2` — `type: "totp"`,
  `encrypted_secret: <deterministic 20-byte secret from D-05>`, `enabled_at: <fixed ts>`,
  `on_conflict: :nothing` on `[user_id, type]`. Do **not** use `Sigra.Testing.setup_totp/2`
  — it is available in dev but mints a `NimbleTOTP.secret()` random secret, breaking
  determinism and the committed cheat-sheet.
- **D-07:** **Admin passkey (display-only):** insert via `UserPasskey.create_changeset/2`
  (`user_id`, `credential_id` fabricated-unique binary, `public_key` fabricated binary,
  optional `nickname`/`device_hint`), `on_conflict: :nothing` on `credential_id`. The
  changeset has **zero Wax/WebAuthn validation** — a fabricated COSE key inserts cleanly.
  Comment the row "display-only; will not authenticate" (SUMMARY pitfall #6).
- **D-08:** **EnterpriseConnection (Acme Corp SSO):** insert via
  `EnterpriseConnection.changeset/2` with `status: :active` (enum is
  `[:draft, :validation_failed, :active, :disabled]` — the `configured`/`pending` strings in
  SUMMARY.md are WRONG), `display_name: "Acme Corp SSO"`, and a **required** nested
  `oidc_settings` embed (`cast_embed required: true`) carrying well-formed fabricated
  `issuer` / `client_id` / `encrypted_client_secret` / `client_authentication_method`. A
  flat insert without the embed raises. Unique on `display_name`.
- **D-09:** **Carol's OAuth identity — DECISION (fork resolved):** Add a minimal
  `Example.Accounts.UserIdentity` schema + migration to the example app, then seed Carol's
  GitHub identity row. The library admin (`Sigra.Admin.Users.Detail` →
  `Sigra.Admin.Live.UserShowLive`) already renders linked identities and auto-detects the
  schema via `optional_schema(accounts_module, :UserIdentity)`; without the schema it shows
  *"Linked identities are not available for this app."* Adding the schema makes Carol's
  OAuth state genuinely observable in admin detail, honoring SC#3 / SEED-02 / SEED-03. The
  identity row shape must match what `Detail.list_identities/3` queries (`provider`,
  `provider_uid`/`provider_email`, FK to user; order by `provider, inserted_at`).
- **D-10:** **Admin API-token row — DECISION (fork resolved): DEFER.** The library admin
  user-detail has **no** API-token surface, and the example app's
  `Accounts.create_api_token/3` (`accounts.ex:719`) is a non-persisting stub with no
  `api_tokens` table. Seeding cannot make a token "observable in the admin UI." Do NOT build
  an api_tokens schema/admin surface in this phase. The `sigra_sk_` prefix will be surfaced
  illustratively on the `/demo/credentials` page (Phase 142). **SC#3 is amended:** drop the
  "admin ... API token (observable in admin UI)" claim; admin's distinguishing features
  remain TOTP MFA + multi-org + passkey display row + rich audit trail.

### Supporting Data
- **D-11:** **Audit log:** ≥15 rows, ≥6 distinct `action` values, on table `audit_events`,
  inserted via `AuditEvent.changeset/3` (delegates to `Sigra.Audit.Changeset` — action regex
  + reserved-prefix validation). Reuse real in-tree action strings (e.g.
  `auth.login.success`, `auth.login.failure`, `mfa.enroll.success`, `session.create`,
  `session.revoke_all`, `admin.impersonation.start`, `admin.impersonation.stop`,
  `mfa.disable`, `mfa.regenerate_backup_codes`). Spread `occurred_at` over a deterministic
  past-30-days window. Tie primarily to the admin persona.
- **D-12:** **Orgs & memberships:** Acme Corp (admin=owner, alice=member, carol=member) +
  Beta Labs (admin=member, bob=owner). One pending invitation row to
  `invited@demo.sigra.dev`. Idempotent via existing unique indexes
  (`organizations[:slug]`, `organization_memberships[:user_id, :organization_id]`,
  `organization_invitations[:organization_id, :email]`).

### Claude's Discretion
- Module layout: `Example.Demo.Personas` (pure data, single source of truth) +
  `Example.Demo.Seeds` (idempotent upsert orchestrator) per SUMMARY architecture; exact
  function decomposition, helper naming, and internal struct shape are implementation
  detail (below the methodology escalation threshold).
- Exact audit-event timestamp distribution and which non-admin personas get incidental
  audit rows.
- `UserIdentity` schema field set beyond what `Detail.list_identities/3` requires — keep
  minimal and idiomatic.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/research/SUMMARY.md` — **binding** conflict resolutions + persona roster +
  pitfalls (the source of truth for all product/security decisions this milestone)
- `.planning/ROADMAP.md` — Phase 141 goal + Success Criteria (note SC#3 amended per D-10)
- `.planning/REQUIREMENTS.md` — SEED-01..06 acceptance criteria
- `test/example/priv/repo/seeds.exs` — the empty target file
- `test/example/mix.exs` — `setup`/`ecto.setup` aliases (already wired), `:sigra` path dep
- `test/example/config/dev.exs` — needs the Argon2 cost override (D-04)
- `test/example/lib/example/accounts.ex` — `register_user/1` (@98), stub
  `create_api_token/3` (@719)
- `test/example/lib/example/accounts/user.ex` — lifecycle fields, `confirm_changeset`,
  `deletion_changeset`
- `test/example/lib/example/accounts/user_mfa_credential.ex` — TOTP direct-insert shape (D-06)
- `test/example/lib/example/accounts/user_passkey.ex` — no-Wax changeset (D-07)
- `test/example/lib/example/accounts/enterprise_connection.ex` +
  `enterprise_connection_oidc_settings.ex` — required embed + status enum (D-08)
- `test/example/lib/example/accounts/audit_event.ex` — `action` field, `audit_events` table (D-11)
- `lib/sigra/admin/users/detail.ex` — `list_identities/3` shape Carol's row must match (D-09)
- `lib/sigra/admin/live/user_show_live.ex` — admin detail render (confirms no API-token
  surface; "identities not available" fallback at :163)
- `lib/sigra/testing.ex` — `setup_totp/2` (@254) — random secret; do NOT use for seeds (D-06)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Example.Accounts.register_user/1` (`accounts.ex:98`) — primary user-creation path; fires
  audit events. All personas register through it, then get state-patched.
- `User` schema already has every lifecycle field needed (`confirmed_at`,
  `failed_login_attempts`, `locked_at`, `deleted_at`, `scheduled_deletion_at`) with
  `confirm_changeset/1` and `deletion_changeset/2`.
- `Encrypted.Binary` passthrough Cloak type — used for TOTP secret + passkey public_key +
  OIDC client secret; stores raw binary (documented as not-production).
- Existing unique indexes provide all `on_conflict:` keys (users email, mfa `[user_id,type]`,
  passkey `credential_id`, org slug, membership `[user_id,org_id]`, invitation `[org_id,email]`).
- `mix setup` → `ecto.setup` → `run priv/repo/seeds.exs` already wired; no alias change.

### Established Patterns
- Library-owned admin UI: `/admin/users`, `/admin/users/:id` resolve to
  `Sigra.Admin.Live.UsersIndexLive` / `UserShowLive` (router.ex:251-255). What renders is
  governed by the **library**, capability-gated on which optional schemas the example app
  provides (`Detail.helpers/1` resolves `identity_schema`, `mfa_schema`, `passkey_schema`,
  `membership_schema` via `optional_schema/2`). Seeding a row only shows up if the library
  has a surface AND the app has the schema.
- `@demo.sigra.dev` (seeded) vs `@example.test` (golden-path) email-domain segregation is an
  enforced code-review invariant.

### Integration Points
- New `Example.Accounts.UserIdentity` schema (D-09) plugs into the existing library admin
  detail via `optional_schema` auto-detection — no library change required, just the schema +
  migration + a seeded row.
- `dev.exs` Argon2 override (D-04) affects only the dev seed path; isolated from test
  (`t_cost: 1, m_cost: 8` stays in test.exs) and prod.
</code_context>

<specifics>
## Specific Ideas

- Persona roster is fixed per SUMMARY.md table: admin / alice / bob / carol / dave / frank,
  all `@demo.sigra.dev`. "Eve" (unconfirmed) handled via README guidance in Phase 144, not a
  seeded row.
- EnterpriseConnection status atom is `:active` (NOT `configured`) — a concrete correction to
  SUMMARY.md's guess, confirmed against `enterprise_connection.ex`.
</specifics>

<deferred>
## Deferred Ideas

- **Admin API-token persistence + admin surface** (D-10) — no table, no admin surface today;
  building both is its own feature/phase. This phase only surfaces the `sigra_sk_` prefix on
  the Phase 142 cheat-sheet. SC#3 amended accordingly.
- In-app persona banner overlay — SUMMARY "Defer"; follow-on.
- Playwright seeds-smoke spec — Phase 143.
- Backup-code seeding (`UserBackupCode`) — optional; not required by any SEED criterion.

### Reviewed Todos (not folded)
- `2026-05-28-phase-135-review-deferred-findings.md` (Threadline demo polish) — coincidental
  keyword match ("demo"); not seed-data work.
- `2026-05-29-deprecation-since-vs-removal-version-axis.md` — deprecation versioning; unrelated.
- `2026-05-29-phase-138-doctor-info-findings.md` — Doctor Info findings; unrelated.
</deferred>
