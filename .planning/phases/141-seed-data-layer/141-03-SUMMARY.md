---
phase: 141-seed-data-layer
plan: "03"
subsystem: example-app-seed-data
tags:
  - seed-data
  - idempotent-upsert
  - personas
  - audit-events
  - mfa
  - passkey
  - enterprise-sso
  - oauth-identity
dependency_graph:
  requires:
    - "141-01 (UserIdentity schema + [:user_id, :provider] unique index for Carol upsert)"
    - "141-02 (Example.Demo.Personas module + demo_totp_secret/0 accessor)"
  provides:
    - "Example.Demo.Seeds.run/0 — idempotent upsert orchestrator for all six demo personas"
    - "Six @demo.sigra.dev users with distinct auth states (SEED-01, SEED-02, SEED-03)"
    - "Acme Corp + Beta Labs orgs, memberships, one pending invitation (D-12)"
    - "admin + bob TOTP credentials (deterministic demo secret) (D-06)"
    - "admin passkey display row (D-07)"
    - "Acme Corp SSO EnterpriseConnection status :active (D-08)"
    - "carol github UserIdentity (D-09)"
    - ">=18 audit events across >=6 distinct actions, admin-tied via effective_user_id (D-11, SEED-04)"
  affects:
    - "test/example/priv/repo/seeds.exs (plan 04) — consumes Seeds.run/0"
    - "Sigra admin UI user-detail panels — all association rows now populated"
tech_stack:
  added: []
  patterns:
    - "Check-then-insert for partial unique indexes (organizations_slug_active_index, organization_invitations_pending_index, enterprise_connections_active_display_name_index) — Ecto's {:constraint, :name} conflict_target is not supported by the Postgres adapter for partial indexes"
    - "Email-taken changeset detection: register_user/1 returns {:error, changeset} via unsafe_validate_unique before DB insert (not {:error, :email_taken}); check errors[:email] for 'taken' to detect re-run"
    - "Count-threshold guard for audit_events idempotency (no unique index)"
    - "allow_reserved: true as the 3rd arg to AuditEvent.changeset/3 for all reserved-prefix actions"
    - "effective_user_id: admin.id (not actor_id alone) to surface rows on admin detail page (query.ex:32 contract)"
key_files:
  created:
    - test/example/lib/example/demo/seeds.ex
  modified: []
decisions:
  - "check-then-insert for partial indexes: Ecto's {:constraint, :name} conflict_target (cited in PATTERNS.md) fails with FunctionClauseError in ecto_sql 3.13.5 against partial unique indexes. Used check-then-insert for org, invitation, and enterprise_connection — functionally equivalent and more readable"
  - "email-taken detection: register_user/1 returns {:error, changeset} (not {:error, :email_taken}) when unsafe_validate_unique fires before DB insert. Handled by inspecting errors[:email] for 'taken' substring — covers re-run scenario"
  - "Single atomic commit for all three tasks: all tasks write to the same file; committing incrementally would only produce partial states with no functional value. One commit captures the complete orchestrator"
  - "18 audit rows instead of exactly 15: @audit_actions list has 18 entries for coverage across all 6+ distinct action types; threshold guard checks for < 15, so insert fires if fewer than 15 admin-tied rows exist"
metrics:
  duration_seconds: 960
  completed_date: "2026-05-30"
  tasks_completed: 3
  files_created: 1
  files_modified: 0
---

# Phase 141 Plan 03: Seeds Orchestrator Summary

**One-liner:** Idempotent `Example.Demo.Seeds.run/0` orchestrator seeding all six auth-state personas, two orgs + memberships + invitation, TOTP/passkey/SSO/OAuth associations, and an 18-row audit trail tied to admin via `effective_user_id`.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Users + state patches + orgs/memberships/invitation (D-01, D-02, D-12) | af8d1d3 | test/example/lib/example/demo/seeds.ex |
| 2 | MFA + passkey + EnterpriseConnection + Carol identity (D-06, D-07, D-08, D-09) | af8d1d3 | test/example/lib/example/demo/seeds.ex |
| 3 | Audit events (D-11) — reserved-prefix + effective_user_id + count-threshold | af8d1d3 | test/example/lib/example/demo/seeds.ex |

All three tasks landed in a single atomic commit because they all write to the same new file; separate intermediate states had no functional value.

## What Was Built

### `Example.Demo.Seeds.run/0`

The complete idempotent seed orchestrator at `test/example/lib/example/demo/seeds.ex`:

**User layer (D-01):**
- Calls `Example.Accounts.register_user/1` for each persona from `Personas.all/0` — fires real Argon2id hashing and real audit events via the context API
- Re-run idempotency: handles both `{:error, :email_taken}` and the `{:error, changeset}` path (unsafe_validate_unique fires before DB insert on re-run) by fetching the existing user
- State patches via direct `Repo.update!`: `User.confirm_changeset/1` for all except dave; `Ecto.Changeset.change/2` for dave's lockout (`failed_login_attempts: 5, locked_at`); `User.deletion_changeset/2` for dave's `hashed_password: nil` clear and frank's `deleted_at + scheduled_deletion_at`

**Org layer (D-12):**
- Acme Corp (slug `acme-corp`) and Beta Labs (slug `beta-labs`) via check-then-insert against `organizations_slug_active_index` (partial index — see Deviations)
- Memberships: admin:owner Acme, alice:member Acme, carol:member Acme, admin:member Beta, bob:owner Beta; `on_conflict: :nothing` on `[:user_id, :organization_id]`
- One pending invitation (`invited@demo.sigra.dev`, role: member) in Acme Corp; check-then-insert with `is_nil/1` query guard for the partial index (`organization_invitations_pending_index`)

**Association layer (D-06, D-07, D-08, D-09):**
- TOTP: admin and bob each get a `user_mfa_credentials` row with `type: "totp"` and `encrypted_secret: Personas.demo_totp_secret()` (deterministic 20-byte SHA-256 derivation); `on_conflict: :nothing` on `[:user_id, :type]`
- Passkey: admin gets one display-only `user_passkeys` row with fabricated binary `credential_id` and `public_key`; comment "display-only; will not authenticate"; `on_conflict: :nothing` on `[:credential_id]`
- EnterpriseConnection: "Acme Corp SSO" with `status: :active`, required `oidc_settings` embed (issuer, client_id, encrypted_client_secret, client_authentication_method: "client_secret_basic"); check-then-insert by display_name
- UserIdentity: carol's github identity (`provider: "github"`, `provider_email: "carol@demo.sigra.dev"`, `provider_uid: "carol-gh-demo-uid"`); `on_conflict: :nothing` on `[:user_id, :provider]`

**Audit layer (D-11):**
- 18 audit rows across 9 distinct actions (`auth.login.success`, `auth.login.failure`, `mfa.enroll.success`, `session.create`, `session.revoke_all`, `admin.impersonation.start`, `admin.impersonation.stop`, `mfa.disable`, `mfa.regenerate_backup_codes`)
- CORRECTION 1: every insert passes `allow_reserved: true` as the 3rd arg to `AuditEvent.changeset/3` — required for `auth.*`, `session.*`, `mfa.*` reserved prefixes
- CORRECTION 2: every row sets `effective_user_id: admin.id` — required for rows to surface on admin's detail page (`query.ex:32` filters by `effective_user_id OR target_id`, not `actor_id` alone)
- `occurred_at` spread deterministically over a past-30-days window using fixed `@seed_reference_ts ~U[2026-05-15 12:00:00Z]` anchor
- Count-threshold guard: only inserts if `admin-tied audit row count < 15` — second run is a no-op

## Verification Results

All success criteria met (verified on dev DB with pre-existing data):

| Check | Result |
|-------|--------|
| 6 `@demo.sigra.dev` users with correct lifecycle states | PASS |
| dave: `failed_login_attempts=5`, `locked_at` not nil, `hashed_password` nil | PASS |
| frank: `deleted_at` not nil AND `scheduled_deletion_at` not nil | PASS |
| Acme Corp + Beta Labs exist by slug | PASS |
| admin passkey row count: 1 | PASS |
| EnterpriseConnection `status: :active` for "Acme Corp SSO" | PASS |
| carol UserIdentity `provider_email: "carol@demo.sigra.dev"` | PASS |
| audit total >= 15, distinct actions >= 6, admin_tied >= 15 | PASS (18/9/18) |
| `allow_reserved: true` present in seeds.ex | PASS |
| Second `run/0` call is a no-op (all counts identical) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `{:constraint, :name}` conflict_target not supported by ecto_sql 3.13.5 for partial indexes**

- **Found during:** Task 1 / Task 2 execution
- **Issue:** The PATTERNS.md cited `conflict_target: {:constraint, :enterprise_connections_active_display_name_index}` and implied a similar pattern for other partial indexes. In ecto_sql 3.13.5, `{:constraint, :atom}` is not a valid conflict_target for `Repo.insert!/2` — the Postgres adapter raises `FunctionClauseError` in `quote_name/1` because it only accepts atoms (column names) or binaries, not `{:constraint, atom}` tuples.
- **Fix:** Used check-then-insert pattern for organizations (by slug), invitation (via `is_nil/1` query), and EnterpriseConnection (by display_name). This is functionally equivalent — idempotent on re-run — and more readable than working around the adapter limitation.
- **Files modified:** `test/example/lib/example/demo/seeds.ex`
- **Commit:** af8d1d3

**2. [Rule 1 - Bug] `register_user/1` returns `{:error, changeset}` on re-run, not `{:error, :email_taken}`**

- **Found during:** Task 1 execution (dev DB already had demo users from prior session)
- **Issue:** `Example.Accounts.register_user/1` calls `User.registration_changeset/2` which uses `unsafe_validate_unique(:email)`. On re-run, this validation fires BEFORE the DB insert attempt, returning `{:error, changeset}` with `errors: [email: {"has already been taken", ...}]` — not `{:error, :email_taken}`. The plan assumed only `{:error, :email_taken}` needed handling.
- **Fix:** Added a clause in `upsert_user/1` that detects the email-taken changeset by checking `errors[:email]` for the "taken" substring, then fetches the existing user via `get_user_by_email/1`.
- **Files modified:** `test/example/lib/example/demo/seeds.ex`
- **Commit:** af8d1d3

**3. [Rule 1 - Bug] `Repo.get_by` rejects `nil` values for IS NULL checks**

- **Found during:** Task 1 — invitation check-then-insert
- **Issue:** `Repo.get_by(OrganizationInvitation, ..., accepted_at: nil, revoked_at: nil)` raises `ArgumentError: nil given for :accepted_at. Comparison with nil is forbidden as it is unsafe. Instead write a query with is_nil/1`.
- **Fix:** Replaced with `Repo.one(from(i in OrganizationInvitation, where: ... is_nil(i.accepted_at) and is_nil(i.revoked_at)))`.
- **Files modified:** `test/example/lib/example/demo/seeds.ex`
- **Commit:** af8d1d3

## Known Stubs

None. All association rows are correctly wired:
- TOTP rows use the real `Personas.demo_totp_secret/0` (deterministic binary)
- Passkey row is explicitly documented as "display-only; will not authenticate" — by design, not a stub
- OIDC client secret is `"demo-secret-not-real"` — documented public demo fixture, not a production secret
- All admin detail panels (TOTP, passkey, orgs, identities, audit) have real data to render

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes. This plan creates only a seed orchestrator module with no public-facing entry points.

Threat mitigations verified:
- **T-141-08 (seed against test DB):** The T-141-SC raise-guard (plan 04's `seeds.exs`) prevents test-DB contamination. The `Example.Demo.Seeds` module itself has no env guard — it is called by `seeds.exs`, which carries the guard.
- **T-141-09 (audit not tied to user):** All admin-tied audit rows set `effective_user_id: admin.id` per `query.ex:32` contract. MITIGATED.
- **T-141-10 (fabricated passkey/TOTP presented as real auth):** Passkey row comments "display-only; will not authenticate"; TOTP secret carries the "Demo-only — Never use in production" label from Personas module; OIDC secret is `"demo-secret-not-real"`. ACCEPTED (public demo data).
- **T-141-11 (non-idempotent audit inserts):** Count-threshold guard (< 15) prevents duplicate rows on re-run. MITIGATED.

## Self-Check: PASSED

- [x] `test/example/lib/example/demo/seeds.ex` exists with `defmodule Example.Demo.Seeds`
- [x] `def run` is defined
- [x] Commit `af8d1d3` exists
- [x] `allow_reserved: true` present in seeds.ex (grep returns match)
- [x] Verification run (dev DB): users=6, dave lockout/nil-pass PASS, frank deletion PASS, EC status :active, carol identity PASS, audit total=18/distinct=9/admin-tied=18
- [x] Idempotency verified: second run produces identical counts for all tables
