---
phase: 09-audit-logging
plan: 01
subsystem: audit
tags: [audit, generator, migration, schema, ecto]
wave: 2
requires:
  - phase-01-foundation (D-27 audit_events table reservation)
  - phase-09-05 (Wave 0 test scaffolds)
provides:
  - audit_events migration template (host-app)
  - AuditEvent Ecto schema template (host-app)
  - install-task wiring for both templates
affects:
  - lib/mix/tasks/sigra.install.ex
tech-stack:
  added: []
  patterns:
    - EEx template generation via Mix.Generator
    - Adapter-neutral Ecto migration (D-07)
    - Generated schema delegates validation to library module (D-27 hybrid split)
key-files:
  created:
    - priv/templates/sigra.install/create_audit_events.exs
    - priv/templates/sigra.install/audit_event.ex
  modified:
    - lib/mix/tasks/sigra.install.ex
decisions:
  - "Templates placed at priv/templates/sigra.install/ (flat layout) not lib/sigra/install/templates/ — matches existing project convention and the install task's find_template/1 lookup path."
  - "audit_events migration is standalone (not folded into create_sigra_auth_tables mega-migration) to keep Phase 9 additions surgical and re-runnable."
  - "audit_migration_timestamp/0 offsets by +2 seconds from main migration timestamp so audit_events sorts after create_sigra_auth_tables (+0s) and create_user_api_tokens (+1s)."
metrics:
  duration: ~15m
  tasks_completed: 2
  files_created: 2
  files_modified: 1
  completed_at: 2026-04-09T17:14:13Z
requirements:
  - AUDIT-02
---

# Phase 09 Plan 01: Generated Audit Events Migration and Schema Summary

## One-liner

Generator now emits an adapter-neutral `audit_events` migration and `AuditEvent` Ecto schema into host apps, unlocking the Phase 9 data layer for the upcoming `Sigra.Audit` module (Plan 02).

## What Shipped

### Task 1 — Migration template
- **File:** `priv/templates/sigra.install/create_audit_events.exs`
- **Commit:** `6f0f400`
- Creates `audit_events` table with all 12 D-05 fields:
  `id` (binary_id PK), `occurred_at`, `action`, `outcome`, `actor_id`, `actor_type`, `target_id`, `target_type`, `ip_address`, `user_agent`, `metadata`, `inserted_at` (no `updated_at` — append-only per D-05)
- Three D-06 indexes: `(actor_id, inserted_at)`, `(action, inserted_at)`, `(inserted_at)`
- D-07 adapter neutrality verified: no `:inet`, `:jsonb`, `:citext`, partitioning, or RLS. Ecto `:map` type handles JSONB/JSON/TEXT transparently on PostgreSQL/MySQL/SQLite.
- String column `size:` bounds set (ip 64, user_agent 512, action 255, outcome 32, actor_type/target_type 64) to stay inside MySQL row-size limits.

### Task 2 — Schema template + install-task wiring
- **Files:** `priv/templates/sigra.install/audit_event.ex`, `lib/mix/tasks/sigra.install.ex`
- **Commit:** `001e25e`
- Schema template mirrors the neighbor `user_session.ex` convention: `<%= context_module %>.AuditEvent`, `<%= if binary_id do %>` guard for `@primary_key`/`@foreign_key_type`, `use Ecto.Schema`, `import Ecto.Changeset`.
- All D-05 fields declared as `field/2` with sensible defaults (`outcome: "success"`, `actor_type: "user"`, `metadata: %{}`).
- `changeset/3` delegates to `Sigra.Audit.Changeset.changeset/3` (implemented in Plan 02 — this is the intentional cross-plan handshake described in the plan's action notes).
- `lib/mix/tasks/sigra.install.ex` now:
  - Derives an `audit_migration_path` (idempotent via `existing_audit_migration` lookup, matching the `create_sigra_auth_tables`/`create_user_api_tokens` pattern).
  - Adds `{:eex, "create_audit_events.exs", audit_migration_path}` and `{:eex, "audit_event.ex", lib/<app>/<context>/audit_event.ex}` entries to the always-generated `files` list.
  - New private `audit_migration_timestamp/0` helper offsets by +2 seconds so the audit migration sorts after the main auth migration (+0s) and api token migration (+1s).

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Migration template exists at expected path (see Deviations) | PASS |
| Contains `create table(:audit_events, primary_key: false)` | PASS |
| Contains `add :id, :binary_id, primary_key: true` | PASS |
| Contains `add :action, :string, null: false` | PASS |
| Contains `add :outcome, :string, null: false` | PASS |
| Contains `add :metadata, :map, null: false` | PASS |
| Contains `timestamps(type: :utc_datetime_usec, updated_at: false)` | PASS |
| All three D-06 indexes present | PASS |
| No PG-specific types (`inet`/`jsonb`/`citext`) | PASS |
| Schema template exists with `schema "audit_events" do` | PASS |
| Schema delegates to `Sigra.Audit.Changeset.changeset(event, attrs, opts)` | PASS |
| `grep -n audit_event lib/mix/tasks/sigra.install.ex` has matches | PASS |
| `mix compile --warnings-as-errors` exits 0 | PASS (sigra app generated cleanly) |

## Deviations from Plan

### Rule 3 — Template path correction

**Found during:** Task 1 read_first.

**Issue:** The plan specified template paths `lib/sigra/install/templates/migrations/create_audit_events.exs.eex` and `lib/sigra/install/templates/schemas/audit_event.ex.eex`. Neither the directory `lib/sigra/install/templates/` nor any existing `*.eex` files exist in this project. The project's actual template convention is a **flat** layout at `priv/templates/sigra.install/` (confirmed via `ls priv/templates/sigra.install/`: `migration.exs`, `user_token.ex`, `user_session.ex`, ~40 other templates), and the install task's `find_template/1` helper explicitly looks up templates at `Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", name]))` with a user-override path rooted at `priv/templates/sigra.install/`.

**Fix:** Placed the new templates at the real, discoverable locations:
- `priv/templates/sigra.install/create_audit_events.exs` (no `.eex` suffix — matches neighbors `migration.exs`, `api_token_migration.exs`)
- `priv/templates/sigra.install/audit_event.ex` (matches neighbors `user_token.ex`, `user_session.ex`)

**Rationale:** Following the plan's literal paths would have created orphan files that `mix sigra.install` could never load, breaking the entire purpose of the plan. Matching the project's existing convention ensures the templates are discovered by `find_template/1` on install.

**EEx variable convention alignment:** The plan's action snippet used `<%= inspect(@repo) %>` / `<%= inspect(@schema_module) %>`. The project's convention (verified in `migration.exs` and `user_token.ex`) is raw interpolation `<%= repo_module %>` / `<%= context_module %>` — the install task already passes the pre-`inspect()`'d strings in the `binding` keyword list. Used the project convention to stay consistent with neighboring templates.

**Files modified:** `priv/templates/sigra.install/create_audit_events.exs`, `priv/templates/sigra.install/audit_event.ex`

**Commits:** `6f0f400`, `001e25e`

### Rule 2 — Idempotent re-run + ordered timestamps

**Found during:** Task 2 install-task wiring.

**Issue:** The plan's action said "add the new entries" to the migration list but did not spell out duplicate prevention. Re-running `mix sigra.install` without an idempotency check would create multiple `*_create_audit_events.exs` files on each invocation, and the default `timestamp/0` collides with the existing main migration timestamp (creating `_create_audit_events.exs` and `_create_sigra_auth_tables.exs` with identical timestamps is ambiguous for Ecto ordering).

**Fix:** Applied the existing `create_sigra_auth_tables` + `create_user_api_tokens` pattern:
- `existing_audit_migration` lookup via `File.ls` + `String.contains?("create_audit_events")` for idempotency.
- New private `audit_migration_timestamp/0` offset by +2 seconds (main is +0s, api_token is +1s).

**Rationale:** Correctness requirement (Rule 2) — the generator must be re-runnable without corrupting the migration directory, and migrations must have deterministic ordering. Matches the pattern already used by every other generated migration in this file.

## Threat Model Coverage

No threats in the Plan 09-01 threat register require code-level mitigation at this stage:

- **T-9-01 (Tampering):** `accept` — documented via D-08 immutability by convention. `Sigra.Audit` will expose no update path (Plan 02). Migration template does not (and should not) apply DB-level `GRANT INSERT ONLY` — that is an optional host-app hardening.
- **T-9-02 (DoS on metadata):** `mitigate` — Plan 02 changeset will enforce the 8KB metadata cap (D-20). The schema template delegates to `Sigra.Audit.Changeset.changeset/3` so the enforcement lands when Plan 02 ships. No DB column cap is applied per the plan (allows runtime configuration of the cap).
- **T-9-04 (Repudiation):** `accept` — no delete paths from the schema; retention cleanup is explicit via Plan 02's `Sigra.Audit.cleanup/1` and the optional Oban worker.

No new threat surface introduced beyond what the `<threat_model>` block already documents.

## Known Stubs

The generated `AuditEvent` changeset delegates to `Sigra.Audit.Changeset.changeset/3`, which does not exist yet — it is introduced in Plan 09-02 (same wave). This is an **intentional cross-plan handshake** documented in the plan's action notes ("Do NOT implement `Sigra.Audit.Changeset` here — Plan 02 creates it. The generated schema will fail to compile in the host app until Plan 02 lands").

**Impact on library compilation:** None. The library itself compiles cleanly (`mix compile --warnings-as-errors` → sigra app generated) because the template is an `.ex` file under `priv/templates/` which is not compiled as part of the sigra app source — it is only evaluated via `EEx.eval_file/2` at host-app install time.

**Impact on host apps:** The generated `AuditEvent` will fail to compile until Plan 02 lands `Sigra.Audit.Changeset`. Both plans are in Wave 2 of Phase 9 and land together, so no host app should ever see this intermediate state.

## Verification

```bash
# Migration template
test -f priv/templates/sigra.install/create_audit_events.exs        # PASS
grep -q 'create table(:audit_events' ...                             # PASS
grep -q 'add :action, :string' ...                                   # PASS
grep -q 'create index(:audit_events, \[:actor_id, :inserted_at\])'   # PASS
grep -q 'updated_at: false' ...                                      # PASS
! grep -qE ':(inet|jsonb|citext)' ...                                # PASS

# Schema template
test -f priv/templates/sigra.install/audit_event.ex                  # PASS
grep -q 'schema "audit_events"' ...                                  # PASS
grep -q 'field :outcome, :string, default: "success"' ...            # PASS
grep -q 'Sigra.Audit.Changeset.changeset(event, attrs, opts)' ...    # PASS

# Install task wiring
grep -q 'audit_event' lib/mix/tasks/sigra.install.ex                 # PASS
grep -q 'create_audit_events' lib/mix/tasks/sigra.install.ex         # PASS

# Compilation
mix compile --warnings-as-errors                                     # PASS (Generated sigra app)
```

## Commits

| Task | Hash      | Summary                                             |
|------|-----------|-----------------------------------------------------|
| 1    | `6f0f400` | feat(09-01): add audit_events migration template     |
| 2    | `001e25e` | feat(09-01): add AuditEvent schema template and wire install task |

## Requirements Addressed

- **AUDIT-02** — Metadata fields queryable via schema: the 12 D-05 fields are now declared as Ecto fields on the generated `AuditEvent` schema, and the three D-06 indexes exist on the generated migration. Query surface will land in Plan 02 via `Sigra.Audit.query/1`.

## Self-Check: PASSED

- [x] `priv/templates/sigra.install/create_audit_events.exs` — FOUND
- [x] `priv/templates/sigra.install/audit_event.ex` — FOUND
- [x] `lib/mix/tasks/sigra.install.ex` — MODIFIED (audit_event, create_audit_events, audit_migration_timestamp references present)
- [x] Commit `6f0f400` — FOUND in git log
- [x] Commit `001e25e` — FOUND in git log
- [x] `mix compile --warnings-as-errors` — PASS (sigra app generated)
