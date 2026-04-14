# Phase 18: Backfill + `--organizations` Generator Wiring — Research

**Researched:** 2026-04-14
**Domain:** Elixir mix task UX + Ecto data migrations + generator conditional wiring
**Confidence:** HIGH (CONTEXT.md already locked 8 decisions; research fills implementation gaps against verified codebase state)

## Summary

Phase 18 is a three-workstream phase (data-migration library + upgrade Mix task / generator opt-out flag wiring / CI matrix + boot fixture) gated by an already-complete CONTEXT.md. Research found the majority of the design work is unblocked — but surfaced **four concrete gaps against the current codebase** that CONTEXT.md presumed fixed-up and that a planner reading CONTEXT.md alone would miss:

1. **`Sigra.Install.Features.Organizations` is NOT registered** in `Mix.Tasks.Sigra.Install`'s `@features` list (it's still `[Sigra.Install.Features.Core]`). Phase 18 must add it OR a prior phase must have wired it. Without this, `--no-organizations` doesn't work because organizations is never wired in at all — the feature module exists but is inert. `[VERIFIED: lib/mix/tasks/sigra.install.ex:35]`
2. **`personal` column + partial unique index does not exist** anywhere — neither in the organizations migration template nor in `Sigra.Install.Features.Core`'s sibling templates, nor as a separate migration. D-01's `ALTER TABLE organizations ADD personal boolean` is a net-new schema migration that Phase 18 owns end-to-end (fresh-install template + upgrade injection). `[VERIFIED: priv/templates/sigra.install/organizations/migration.exs, organization.ex]`
3. **`add_active_organization_id_to_user_sessions.exs` lives in `core/`**, not `organizations/` — which is correct (Phase 12 decision: scope field is load-bearing outside the org axis), but means it stays emitted on `--no-organizations` and serves as the structural anchor for zero-org safety. The zero-org router redirect lives in the `organizations/` router injection, so `--no-organizations` removes the redirect surface entirely — which is fine because with no `/organizations` route there is nothing to redirect to. ORG-UPGRADE-02 collapses to "the v1.0 shape boots cleanly" for `--no-organizations`. `[VERIFIED: lib/sigra/install/features/core.ex:89]`
4. **No `Sigra.Upgrade.*` namespace, no `mix sigra.upgrade` task, no `Sigra.Upgrade.Backfill` module exists** on disk. Phase 18 is entirely greenfield for the upgrade surface — CONTEXT.md's references to `Sigra.Upgrade.Backfill.run_personal_orgs/2` are aspirational, not descriptive. `[VERIFIED: ls lib/sigra/ shows no upgrade.ex]`

**Primary recommendation:** Decompose this phase into **3 plans across 2 waves** (see "Recommended plan decomposition" below). Wave 1 = schema migration + Features.Organizations registration + personal column in fresh install (foundation nothing else can land without). Wave 2 = upgrade task + backfill library + boot fixture + CI matrix in parallel.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Personal orgs are a first-class row flag on `organizations` — `personal :boolean, null: false, default: false` + partial unique index `organizations(owner_user_id) WHERE personal = true`. Schema migration lands **before** the data migration. Sticky origin flag, not current-state.
- **D-02:** Backfill uses Dashbit data-migrations pattern. `priv/repo/data_migrations/` directory, 5-10 line generated file that calls `Sigra.Upgrade.Backfill.run_personal_orgs(repo, opts)`, invoked via `Ecto.Migrator.run(repo, "priv/repo/data_migrations", :up, all: true)`. Flags `@disable_ddl_transaction true` + `@disable_migration_lock true` mandatory.
- **D-03:** Idempotency via keyset cursor + `NOT EXISTS` selector + `Repo.insert_all(on_conflict: :nothing, conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"})`. Default batch 1000 rows.
- **D-04:** Personal org name = `"{display_name || email_local_part}'s Workspace"`, slug = `"user-#{user.id}"` (opaque, immutable). Fallback chain → `"Personal"` degenerate.
- **D-05:** `--no-organizations` uses three mechanisms: inline EEx conditionals (≤20 lines, ≤2 nesting), file-manifest omission via `files/1` returning `[]`, `Sigra.Install.Injection` for host-owned files. No duplicate `_with_X/_without_X` templates. `sigra.install.ex` `@switches` adds `organizations: :boolean`, `build_binding/4` forwards `organizations?: Keyword.get(opts, :organizations, true)`.
- **D-06:** `test/upgrade_test.exs` uses semantic equivalence — `mix sigra.install --no-organizations --yes` IS the v1.0 state by definition. Reuses `Sigra.Test.InstallFixture`.
- **D-07:** CI `install_matrix` job with `strategy.matrix.flags: ["", "--no-organizations"]` — list-of-flag-strings shape so Phase 19+ appends entries without restructuring.
- **D-08:** `mix sigra.upgrade` flags: `--yes`, `--dry-run`, `--allow-dirty`, `--backfill-personal-orgs`, `--from VERSION`. Version sentinel in `config/config.exs` (injection) — CD-03 allows `priv/sigra/.version` alternative. Interactive confirmation via `Mix.shell().yes?/1`. Telemetry `[:sigra, :upgrade, :backfill, :batch]`. NimbleOptions schema.

### Claude's Discretion

- **CD-01:** Exact wording of `post_instructions` and `--help` text.
- **CD-02:** Batch size default and tuning knob (D-03 suggests 1000; research below confirms this is reasonable against Shopify, Tyler Young, Active Record in_batches defaults).
- **CD-03:** File location for version sentinel — `config/config.exs` injection vs `priv/sigra/.version` file. Recommendation below.

### Deferred Ideas (OUT OF SCOPE)

- Auto-personal-org on signup flag.
- "Convert personal org to team org" UX.
- Passkey axis in CI matrix (Phase 19-22).
- Backfill progress UI beyond telemetry.
- Multi-repo support in upgrade task.
- `mix sigra.downgrade`.
- Upgrade telemetry dashboards / LiveDashboard integration.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **ORG-02** | `mix sigra.install --no-organizations` produces app with no org templates/schemas/routes | Requires: (a) registering `Features.Organizations` in `@features`, (b) adding `organizations: :boolean` to `@switches`, (c) forwarding `organizations?` into binding, (d) verifying `files/1`/`migrations/1` return `[]` when disabled. `[VERIFIED: runner.ex:53 filters on enabled?/1]` |
| **ORG-UPGRADE-01** | `mix sigra.upgrade --backfill-personal-orgs` is idempotent, batched, adapter-branched, safe to re-run | Greenfield: create `Sigra.Upgrade.Backfill` library module + `mix sigra.upgrade` task + data-migrations directory invocation. Ecto `on_conflict: :nothing` handles adapter branching automatically. |
| **ORG-UPGRADE-02** | Upgrade without backfill flag leaves existing users in "create or accept invite" state, no 500s | Nearly free — Phase 14's `select_active_organization/3` + zero-org router redirect already handle this. Phase 18 proves it under the upgrade path via `test/upgrade_test.exs`. |
| **ORG-UPGRADE-03** | Repo ships `test/upgrade_test.exs` asserting login works in both backfill paths | Greenfield: new test file using `InstallFixture` helpers. Requires new helper `run_sigra_upgrade/2` in the fixture. |
| **GEN-03 (org-axis)** | CI matrix with `--organizations`/`--no-organizations` produces compiling Phoenix app | `.github/workflows/ci.yml` new `install_matrix` job. Lowers onto existing `InstallFixture` baseline pattern. |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `personal` column migration | Generated app / versioned SQL | Library (schema constant) | Schema lives on host app's DB; library provides the migration template + `Organization` schema field. |
| Backfill batch logic | Library (`Sigra.Upgrade.Backfill`) | Generated data migration (5-line proxy) | Logic must be patchable via `mix deps.update`. Generated file is 100% proxy. |
| `mix sigra.upgrade` task | Library (Mix.Task in `lib/mix/tasks/`) | — | All upgrade task code is library-owned. Host app only sees command output. |
| Fresh-install opt-out plumbing | Library (`Mix.Tasks.Sigra.Install` + `Features.Organizations`) | — | Generator behavior is library-owned. |
| Zero-org post-login routing | Generated router + generated LiveView | Library (`Sigra.Plug.LoadActiveOrganization`) | Phase 14 already owns this; Phase 18 only adds regression coverage. |
| Upgrade test fixture | Library (`test/support/install_fixture.ex`) + `test/upgrade_test.exs` | — | Fixture is test-support in the library repo. |
| CI matrix | `.github/workflows/ci.yml` | — | Repo-owned workflow. |

---

## Standard Stack

Phase 18 does not add new dependencies. All libraries needed are already in `mix.exs`:

| Library | Version (verified) | Purpose in Phase 18 | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | `~> 3.13` | `Ecto.Migrator.run/4` against `priv/repo/data_migrations` path; `Repo.insert_all/3` with `on_conflict: :nothing` | `--migrations-path` / multiple-paths support added in ecto_sql 3.4; Dashbit's blessed data-migration shape. `[CITED: dashbit.co/blog/automatic-and-manual-ecto-migrations]` |
| `nimble_options` | `~> 1.1` (in mix.exs:83) | Option schema + `--help` for `mix sigra.upgrade` | CLAUDE.md-mandated standard for all public configuration surfaces. `[VERIFIED: mix.exs:83]` |
| `telemetry` | (transitive via `phoenix`/`ecto`) | `[:sigra, :upgrade, :backfill, :batch]` events | Already a transitive dep; no new lib. |

### Already Available in Codebase

| Module | Path | Role in Phase 18 |
|--------|------|------------------|
| `Sigra.Install.Feature` | `lib/sigra/install/feature.ex` | Behaviour — `Features.Organizations` already implements it. |
| `Sigra.Install.Features.Organizations` | `lib/sigra/install/features/organizations.ex` | Already implements the 5 callbacks; `enabled?/1` already reads `Keyword.get(opts, :organizations, true)`. Currently inert (not in `@features` list). |
| `Sigra.Install.Runner` | `lib/sigra/install/runner.ex` | Generic walker; no changes needed — filters `active = Enum.filter(features, & &1.enabled?(opts))` at line 53. |
| `Sigra.Install.Injection` / `Injector` | `lib/sigra/install/injection.ex`, `injector.ex` | Re-usable for upgrade task injections (version sentinel, personal column ALTER triggering). |
| `Sigra.Test.InstallFixture` | `test/support/install_fixture.ex` | Foundation for `test/upgrade_test.exs`; currently exposes `setup_tmp_app/1`, `snapshot_paths/1`, `normalize_tree/2`, `normalize_stdout/2`. Needs a new helper `run_sigra_upgrade/2` (and possibly parameterization of install flags). |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Ecto.Migrator.run/4` w/ custom path | Raw `mix ecto.migrate --migrations-path ...` subprocess | Subprocess loses in-process error handling + telemetry; Migrator API is blessed. |
| Keyset `NOT EXISTS` selector | Tyler Young's Elixir backfill microframework (full GenServer-based framework) | Overkill for one-shot upgrade; D-02/D-03 pattern is the lightweight idiom. |
| Library-resident backfill logic | Generated batch logic into host app | Violates "lib owns logic + thin generated wrapper" philosophy; bug fixes wouldn't ship via `mix deps.update`. |
| NimbleOptions for `mix sigra.upgrade` | `OptionParser.parse/2` only (as `mix sigra.install` does today) | CLAUDE.md prescribes NimbleOptions for all option schemas; `--help` generation is free. |

---

## Architecture Patterns

### System Architecture Diagram — Phase 18 Workstreams

```
                 Developer invokes `mix sigra.upgrade --backfill-personal-orgs`
                                         │
                                         ▼
                    ┌────────────────────────────────────────┐
                    │ Mix.Tasks.Sigra.Upgrade (new)          │
                    │  - NimbleOptions.validate!(@schema)    │
                    │  - check_git_dirty!(opts)              │
                    │  - detect_current_version()            │
                    │  - build_plan(current, target)         │
                    │  - maybe_confirm(plan, opts)           │
                    └────────────────────────────────────────┘
                                         │
                                         ▼
             ┌───────────────────────────┴───────────────────────────┐
             ▼                                                       ▼
  ┌────────────────────┐                              ┌────────────────────────┐
  │ Inject schema migr │                              │ Ecto.Migrator.with_repo│
  │  add personal col  │                              │   repo, fn repo ->     │
  │  + partial uniq ix │                              │     Ecto.Migrator.run( │
  │  (via feature mani │                              │       repo,            │
  │   fest file emit   │                              │       "priv/repo/      │
  │   into host's      │                              │        data_migrations"│
  │   priv/repo/       │                              │       :up, all: true)  │
  │   migrations/)     │                              │   end)                 │
  └────────────────────┘                              └────────────────────────┘
             │                                                       │
             ▼                                                       ▼
  ┌────────────────────┐                              ┌────────────────────────┐
  │ Host runs          │                              │ Data migration file is │
  │ mix ecto.migrate   │                              │ a 5-line shim that     │
  │ (schema migration) │                              │ calls:                 │
  └────────────────────┘                              │ Sigra.Upgrade.Backfill │
                                                      │ .run_personal_orgs(    │
                                                      │   repo, opts)          │
                                                      └────────────────────────┘
                                                                  │
                                                                  ▼
                                                  ┌──────────────────────────────┐
                                                  │ Sigra.Upgrade.Backfill       │
                                                  │                              │
                                                  │ stream batches via           │
                                                  │ keyset cursor                │
                                                  │   ▼                          │
                                                  │ NOT EXISTS selector (1000/b) │
                                                  │   ▼                          │
                                                  │ Repo.insert_all/3            │
                                                  │   on_conflict: :nothing      │
                                                  │   conflict_target: partial ix│
                                                  │   ▼                          │
                                                  │ :telemetry.execute(          │
                                                  │   [:sigra, :upgrade,         │
                                                  │    :backfill, :batch], ...)  │
                                                  │   ▼                          │
                                                  │ recurse until cursor done    │
                                                  └──────────────────────────────┘
```

### Pattern 1: Data-migration proxy file

**What:** A 5-10 line generated `.exs` file under the host app's `priv/repo/data_migrations/` that subclasses `Ecto.Migration`, disables the advisory lock and DDL transaction, and calls a versioned library function.

**When to use:** One-shot upgrades where idempotency + Ecto bookkeeping is wanted but logic must be patchable via `mix deps.update`.

**Shape (library-side template, rendered into host app):**

```elixir
# priv/repo/data_migrations/<ts>_backfill_personal_orgs.exs
defmodule <%= repo_module %>.DataMigrations.BackfillPersonalOrgs do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    Sigra.Upgrade.Backfill.run_personal_orgs(
      repo(),
      batch_size: 1_000
    )
  end

  def down, do: :ok
end
```

**Why this shape:** Dashbit's blog explicitly prescribes this for long-running data migrations. `@disable_ddl_transaction true` + `@disable_migration_lock true` prevent the migration from holding `pg_advisory_lock` for hours and blocking every subsequent deploy. `[CITED: dashbit.co/blog/automatic-and-manual-ecto-migrations, github.com/fly-apps/safe-ecto-migrations]`

### Pattern 2: `Ecto.Migrator.run/4` with custom path

**Invocation shape (library-side, from `Mix.Tasks.Sigra.Upgrade`):**

```elixir
# This is descriptive, not a prescribed literal — planner owns the final code.
{:ok, _, _} =
  Ecto.Migrator.with_repo(repo, fn repo ->
    Ecto.Migrator.run(repo, "priv/repo/data_migrations", :up, all: true)
  end)
```

`with_repo/2` handles the "start the repo if not started" edge case, which is mandatory for a Mix task that runs against a stopped app. `Ecto.Migrator.run/4` accepts a path string as its second-to-last argument — ecto_sql 3.4+ supports this. `[CITED: hexdocs.pm/ecto_sql/Ecto.Migrator.html]`

The migration version is tracked in the same `schema_migrations` table as regular migrations (that's a tradeoff — see pitfall #4). An alternative is to pass `prefix: "sigra_upgrades"` or similar to isolate the version table; **research recommendation: use the default `schema_migrations` table**, because (a) adding a prefix means the host app's operators have a new table they don't recognize, (b) `schema_migrations` is the right level of granularity — the upgrade task is part of the app's migration history.

### Pattern 3: Keyset `NOT EXISTS` selector

**Shape:**
```elixir
# Descriptive — actual schema module names/aliases selected by planner.
query =
  from u in users_schema,
    where: u.id > ^last_cursor,
    where: not exists(
      from o in orgs_schema,
        where: o.owner_user_id == parent_as(:u).id and o.personal == true
    ),
    as: :u,
    order_by: u.id,
    limit: ^batch_size
```

**Why keyset not OFFSET:** Postgres `OFFSET N` is O(n); on a 1M-user table, OFFSET 990_000 reads 990k rows to discard them. Keyset (`u.id > ^cursor`) uses the primary key index directly. Standard Postgres pagination wisdom. `[CITED: use-the-index-luke.com/no-offset]`

### Pattern 4: `--no-organizations` as simple filter in walker

`Sigra.Install.Runner.run/3` at line 53 already does `active = Enum.filter(features, fn f -> f.enabled?(opts) end)`. Feature is filtered out **before** any of its callbacks are called. So once `Features.Organizations` is registered, the `--no-organizations` path is automatic — `files/1`, `injections/1`, `migrations/1`, `post_instructions/2` are never invoked for a disabled feature. `[VERIFIED: lib/sigra/install/runner.ex:53]`

This means **the planner does NOT need to add "return [] when disabled" guards inside `Features.Organizations`**. The enablement check happens upstream, not inside the feature callbacks.

### Anti-Patterns to Avoid

- **Calling `Features.Organizations.files/1` from anywhere other than the runner.** Feature callbacks are walker-only; hand-calling them from tests or other features breaks the X-1/X-3 isolation invariant.
- **Putting backfill batch logic inside the generated `.exs` file.** Violates "lib owns logic + thin generated wrapper" — bug fixes wouldn't propagate via `mix deps.update`.
- **Using `Repo.transaction/2` around the full backfill.** Holds a long transaction on the users table; conflicts with `@disable_ddl_transaction true`. Batches are independently transactional via `Repo.insert_all/3`.
- **`mix ecto.migrate --migrations-path` shell-out from the upgrade task.** Loses in-process error propagation and telemetry. Use `Ecto.Migrator.run/4` directly.
- **Calling `Application.spec/2` to detect upgrade-source version without cross-checking a sentinel.** `Application.spec(:sigra, :vsn)` returns the currently-loaded library version, which is already the *new* version during `mix sigra.upgrade`. It cannot tell you the *previous* version. Must use a recorded sentinel (config key or `priv/sigra/.version`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration version bookkeeping | Sidecar `sigra_upgrade_state` table | `Ecto.Migrator` against a dedicated `priv/repo/data_migrations` path | Ecto already tracks "has this migration run"; Shopify learned (2023-01-04 railsatscale post) that idempotency belongs in `#process`, not sidecar state. |
| Advisory-lock safety | Manual `pg_advisory_lock` calls | `@disable_migration_lock true` at the migration level | Ecto's lock behavior is correct per-migration; overriding it at the call site is fragile. |
| Batch pagination | Manual `OFFSET N` looping | Keyset cursor (`u.id > ^last_cursor`) | OFFSET is O(n); keyset uses the PK index. |
| Per-adapter INSERT branching | `case adapter do :postgres -> ... :mysql -> ...` | `Repo.insert_all(on_conflict: :nothing, conflict_target: ...)` | Ecto emits the correct DDL per adapter; hand-branching duplicates 3× SQL. |
| Mix task option parsing | Raw `OptionParser.parse/2` | `NimbleOptions.validate!/2` + pass-through | CLAUDE.md-mandated for all public option schemas; gets `--help` text + type validation for free. |
| Git dirty-tree detection | Parsing `git status` text | `System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true)` + check for empty stdout | Porcelain format is a stable interface contract (unlike plain `status`). Must handle non-git-dir gracefully — when `cmd` exits non-zero, treat as "not a git repo, skip the check". |
| Version-aware upgrade dispatch | Hand-rolled version compare | `Version.compare/2` against a recorded sentinel | Elixir's `Version` module handles semver correctly. |

**Key insight:** The entire Phase 18 upgrade surface should have ~200-400 lines of net-new library code. Anything larger signals that a library is being reinvented.

---

## Runtime State Inventory

Phase 18 is a **migration-authoring phase**, not a rename/refactor phase. The runtime state question applies in the opposite direction: what state does a v1.0 host app already contain that the upgrade will read/write?

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data (host-app DB) | `users` table exists (v1.0 shape). `organizations` table exists only if the host upgraded through Phase 13's generator already — but by D-06, "v1.0" is defined as `--no-organizations` install, so `organizations` table does NOT exist in the upgrade-source state. | Upgrade task must emit the full `create_organizations.exs` migration (not just an ALTER), plus the schema migration adding `personal` column on top. Need ordering: create → alter. |
| Live service config | None — upgrade is a library-internal operation. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None new; the upgrade might add a Cloak vault injection if organizations uses encryption, but CONTEXT.md doesn't call this out. | None — verified by reading D-01 through D-08. |
| Build artifacts | Host app's `_build/` will be stale after upgrade runs (new schemas compiled). | None — `mix compile` on next run handles it. The upgrade task should NOT force-recompile. |

**Critical insight this surfaces:** Because "v1.0 shape" is defined as `--no-organizations` install, the upgrade task is NOT just adding a `personal` column — it's **emitting the entire organizations schema migration tree for the first time**. The personal column is added in a second, ordered migration. This is more work than CONTEXT.md makes explicit.

Concretely, running `mix sigra.upgrade` on a v1.0 host must:

1. Render `priv/templates/sigra.install/organizations/migration.exs` into a new `priv/repo/migrations/<ts>_create_organizations.exs`.
2. Render a NEW `priv/templates/sigra.install/organizations/add_personal_to_organizations.exs` template into `priv/repo/migrations/<ts+1>_add_personal_to_organizations.exs`.
3. Render all `Features.Organizations.files/1` entries that don't already exist (schemas, LiveViews, controllers, context wrapper).
4. Apply all `Features.Organizations.injections/1` into the host router / user_auth / etc. The injector will silently skip any already-present markers (GEN-04 idempotency).
5. If `--backfill-personal-orgs` was passed, render the data-migration proxy file into `priv/repo/data_migrations/<ts>_backfill_personal_orgs.exs`.

**The planner must recognize that `mix sigra.upgrade` and `mix sigra.install` share 95% of their file-emission logic.** The right refactor is: `mix sigra.upgrade` calls into `Sigra.Install.Runner` with specific features and `force: false` semantics, plus extra work (schema migration emission, version sentinel bump, backfill invocation). Do NOT duplicate the file-walking code.

---

## Common Pitfalls

### Pitfall 1: Migration ordering (X-2)

**What goes wrong:** The `add_personal` schema migration runs BEFORE the `create_organizations` schema migration, because timestamps are allocated out of order.

**Why it happens:** Phase 11 `Sigra.Install.MigrationTimestamps.allocate/2` allocates timestamps strictly-monotonically within a single feature, but the upgrade task is emitting migrations from multiple sources (organizations template + net-new personal-column template). If the planner allocates timestamps manually, they might collide or invert.

**How to avoid:** Add the `personal` column as a NEW slot in `Features.Organizations.migrations/1` — e.g., `[{:organizations, "...migration.exs", "create_organizations.exs"}, {:personal_column, "...add_personal_to_organizations.exs", "add_personal_to_organizations.exs"}]`. The `MigrationTimestamps.allocate/2` allocator gives them monotonic timestamps by slot order within the feature. The runner's `overlay_existing_migrations/2` handles re-run idempotency.

**Warning signs:** `mix ecto.migrate` fails with `ERROR: column "personal" already exists` (ALTER ran before CREATE, then CREATE tried to bring personal in) or `ERROR: relation "organizations" does not exist` (ALTER ran against missing table).

### Pitfall 2: Backfill re-run non-idempotency (O-8)

**What goes wrong:** A second `mix sigra.upgrade --backfill-personal-orgs` creates duplicate personal orgs.

**Why it happens:** (1) Ecto's migration version-tracking catches re-runs at the file level, but if the file was regenerated with a new timestamp on upgrade #2, Ecto sees it as a new migration and runs it again. (2) Inside the backfill itself, if the partial unique index is missing, two concurrent backfills race-insert duplicates.

**How to avoid:** (1) The data migration file is regenerated with a stable basename; `Runner.overlay_existing_migrations/2` already preserves the original timestamp on re-run. (2) The partial unique index from D-01 is a hard insert-level backstop. (3) The `NOT EXISTS` selector means batches naturally narrow to the residual set.

**Warning signs:** `SELECT COUNT(*) FROM organizations WHERE personal = true` > `SELECT COUNT(*) FROM users`; constraint violations in the backfill telemetry events.

### Pitfall 3: Injection silently no-ops on missing target file

**What goes wrong:** Host app has a custom router layout; the marker isn't found at the expected anchor; injection runs but puts content in the wrong place.

**Why it happens:** `Sigra.Install.Injector.apply/2` (lib/sigra/install/injector.ex:434) handles three states: (a) target file missing → `{:error, {:target_missing, ...}}` → Runner records manual action; (b) marker already present → `{:ok, :already_present}` → skipped; (c) marker absent + file present → injection proceeds at the configured anchor. Case (c) is the danger: if the anchor (`:before_last_end`) can't find a sensible match, content goes somewhere surprising.

**How to avoid:** For Phase 18, the upgrade task re-applies Phase 16's router injection (marker: `"# Sigra organizations"`) — which is idempotent. The one net-new injection is the version sentinel (`@sigra_schema_version` in `config/config.exs`), anchor `:elixir_config`. Add a regression test in `injection_test.exs` that the injector does not silently insert at position 0 when anchor resolution fails — it should raise or return error.

**Warning signs:** `mix compile --warnings-as-errors` fails after upgrade because config.exs has a malformed injection; router has `"# Sigra organizations"` comment duplicated twice.

### Pitfall 4: `schema_migrations` cross-contamination

**What goes wrong:** Both `priv/repo/migrations/` and `priv/repo/data_migrations/` record into the same `schema_migrations` table. A schema migration with timestamp `20260415120000` and a data migration with timestamp `20260415120001` are both tracked there. A developer running `mix ecto.migrate` (default path) does NOT run the data migration — but a fresh `mix ecto.setup` / `mix ecto.rollback --to` might traverse versions out of order.

**Why it happens:** Ecto's `Ecto.Migrator` uses `schema_migrations` as the single source of truth regardless of path. `mix ecto.migrate` only executes files from the path it's called with, but `schema_migrations` version records are global.

**How to avoid:** Two options:
   - **(A) Share `schema_migrations`** (recommended per Dashbit): accept that data migrations show up in the version list. Document clearly: "data migrations must be run via `mix sigra.upgrade --backfill-personal-orgs`, never via `mix ecto.migrate --migrations-path ...`". Rollback is explicitly unsupported (`def down, do: :ok`).
   - **(B) Use `prefix: "sigra"` on data migrations** — isolates them in `sigra.schema_migrations`. Cleaner but adds a schema the host operators don't recognize.

**Recommendation:** Option A. Matches Dashbit's blog, matches how Oban self-migrates, matches how Tyler Young's framework does it. `[CITED: dashbit.co/blog/automatic-and-manual-ecto-migrations]`

**Warning signs:** After rollback, `mix ecto.migrate` re-runs the backfill because the record was in `schema_migrations` from the old path.

### Pitfall 5: Version sentinel race on concurrent upgrade invocations

**What goes wrong:** Two `mix sigra.upgrade` processes run simultaneously, both read `@sigra_schema_version "1.0.0"`, both decide to run, both try to inject the same migrations, second one sees `:already_present` and exits success but leaves version sentinel at `1.0.0`.

**Why it happens:** Config file injection is not atomic across processes.

**How to avoid:** The upgrade task should hold a filesystem lock (`:filelib.ensure_path/1` + `File.open(lock_path, [:exclusive])` or equivalent) for the duration. Acceptable alternative: document "do not run two upgrades concurrently" and rely on Ecto's migration lock to serialize any actual work.

**Warning signs:** Version sentinel disagrees with actual applied migrations. The boot fixture should test this (run upgrade twice in sequence; assert the second run is a no-op AND leaves the sentinel correct).

### Pitfall 6: `mix phx.new --no-install` in fixture + deps.get timing

**What goes wrong:** `InstallFixture.setup_tmp_app/1` runs `mix phx.new --no-install`, then patches the in-tree sigra as a `:path` dep, then runs `mix deps.get`. On a fresh machine the first run can be slow (full dep tree fetch); on subsequent runs deps are cached but every new tmp dir is a fresh `_build/`.

**Why it happens:** `System.tmp_dir!` changes per test; no `_build/` caching across runs.

**How to avoid:** Existing fixture already handles this via `pre_compile` step. For `test/upgrade_test.exs`, accept the runtime cost (~60s per test) OR introduce a shared cached app under `test/tmp/shared_app/` that's reused across the upgrade test's two paths (backfill-on / backfill-off). The `--yes` flag short-circuits prompts so the test runs non-interactively.

**Warning signs:** Upgrade test takes >2min per assertion; CI intermittent timeouts.

---

## Version Detection Research (CD-03)

CONTEXT.md leaves CD-03 (sentinel location) to the planner's discretion. Research into how other Elixir libs detect their own installed version inside the host app:

| Library | Detection Mechanism | Verdict |
|---------|--------------------|---------|
| **Ecto** (`schema_migrations`) | Per-migration version records, not library version | Track "what has run", not "what version is installed". Not directly applicable but informs D-02 pattern. |
| **Oban** (`Oban.Migration.up/down`) | Host app's migration explicitly passes `version: N`; Oban doesn't auto-detect, developer specifies. `[CITED: hexdocs.pm/oban/Oban.Migration.html]` | Explicit developer invocation. Phase 18 can't use this directly because Sigra's upgrade surface is broader than Oban's single migration file. |
| **Ash** (`AshPostgres.Migration`) | Records schema hashes in `ash_resource_migration_state` table | Heavyweight; designed for auto-generation of schemas from resource definitions. Overkill for Sigra. |
| **Phoenix LiveView** | Does not self-detect version inside host app; generator files are frozen-at-generate-time | Not applicable. |
| **Ash / igniter** | Reads `mix.lock` via `Mix.Dep.Lock.read/0` to find version | Viable mechanism but introspection-heavy. |
| **`Application.spec/2`** | `Application.spec(:sigra, :vsn)` returns the *currently loaded* library version | **Useless for upgrade source detection** — during `mix sigra.upgrade`, this returns the NEW version, not the OLD one. |

**Recommendation for CD-03:**

- **Primary sentinel: `config/config.exs` injection.** Inject:
  ```elixir
  # Sigra schema version — managed by `mix sigra.upgrade`. Do not edit manually.
  config :sigra, :schema_version, "1.1.0"
  ```
  Read at upgrade time via `Application.get_env(:sigra, :schema_version, "1.0.0")`. Default `"1.0.0"` if unset (pre-Phase-18 installs).

- **Why not `priv/sigra/.version`:** (a) `priv/` is owned by the library, not the host app — writing host state there pollutes a read-only directory in the developer's mental model. (b) `config/config.exs` is already a recognized injection target (the core feature already injects into it). (c) `config.exs` is compiled into the app, so running `mix compile` surfaces any corruption immediately; a bare `.version` file would be invisible at compile time.

- **`--from VERSION`:** overrides the auto-detected value. Useful when the sentinel got clobbered by a merge conflict.

- **Upgrade path compare:** `Version.compare(target_version, source_version)` → `:gt` proceeds, `:eq` is a no-op (log "already at version N"), `:lt` raises `Mix.raise "refusing to downgrade..."`.

---

## Batching Research (CD-02)

CONTEXT.md proposes 1000 rows per batch. Research confirms this is reasonable:

| System | Default | Source |
|--------|---------|--------|
| **Shopify `maintenance_tasks`** | 100 | `collection_batch_size` default in `TaskJobConcern` `[CITED: github.com/Shopify/maintenance_tasks]` |
| **Rails `in_batches`** | 1000 | Active Record docs, 2024-2025 |
| **Tyler Young's Elixir framework** | 1000 | `tylerayoung.com/2023/08/13/migrations/` |
| **Dashbit blog** | "a few thousand" (qualitative) | `dashbit.co/blog/automatic-and-manual-ecto-migrations` |

**Recommendation:** Keep D-03's default of **1000**. Expose as `Sigra.Upgrade.Backfill.run_personal_orgs/2` option (not as a CLI flag). Typical Phoenix auth user table (10k-1M rows) will see 10-1000 batches, each taking <500ms on a modest DB — total runtime 5s-500s. For tables >10M rows the developer can pass `batch_size: 5_000` directly to the data-migration invocation. Document the knob.

**Memory pressure note:** 1000 rows of `(id, email, display_name)` is ~200KB — no memory concern. Lock contention is the real pressure vector, and keyset pagination + `on_conflict: :nothing` avoids it.

---

## EEx Conditional Wiring — Search Results

Research task: "which existing templates need `<%= if @organizations? do %>` wraps?"

Given D-05's "library stays always-compiled, only generated code varies" philosophy, and the fact that `Features.Organizations.files/1` already returns the full org file list unconditionally (meaning the whole-file omission path handles most of the bifurcation), the inline-conditional surface is **smaller than CONTEXT.md implies**:

| Template | Path | Needs `organizations?` conditional? | Reason |
|----------|------|--------------------------------------|--------|
| `core/user_auth.ex` | `priv/templates/sigra.install/core/user_auth.ex` | **YES** — around the `select_active_organization/3` call in `create_session/3` and around `on_mount(:assign_user_organizations, ...)` delegation | Library function call must be gated at template time so the generated file doesn't reference `Sigra.Organizations` when disabled. |
| `core/router.ex.injection` | `priv/templates/sigra.install/core/router_injection.ex` (if exists) | Likely — around any `require_org` / `/organizations` route injection | Phase 16 put org routes in `organizations/router_injection.ex`, but if Phase 12/14 put any org-touching hooks into the core router injection, those need gating. |
| `organizations/*` | All files | NO — the file is either emitted whole or not at all | `Features.Organizations` is enabled/disabled as a unit. |
| `core/migration.exs` (user sessions) | `core/add_active_organization_id_to_user_sessions.exs` | **NO** — runs in both modes | Per Phase 12 decision, `active_organization_id` is a nullable column that is safe in zero-org installs. |

**Planner action:** Grep `priv/templates/sigra.install/core/` for `Sigra.Organizations` and `select_active_organization` references. Each hit is a candidate for `<%= if @organizations? do %>` wrapping. CONTEXT.md D-05 specifies keep conditionals ≤20 lines, ≤2 nesting levels.

**Binding propagation:** `Mix.Tasks.Sigra.Install.build_binding/4` returns a keyword list. Add:
```elixir
organizations?: Keyword.get(opts, :organizations, true)
```
The key gets passed through to `EEx.eval_file/2` via `Runner.run_files/3` line 81 (`EEx.eval_file(template_path, binding)`), where it becomes the `@organizations?` assign inside templates. `[VERIFIED: lib/sigra/install/runner.ex:81]`

---

## File Manifest Audit (D-07 CI lock-in)

**Research task:** identify files currently emitted by `Sigra.Install.Features.Core` that reference `Sigra.Organizations.*` and would break `mix compile` on `--no-organizations`.

Quick scan of `priv/templates/sigra.install/core/`:

```
Files that would need grep (action item for plan):
- user_auth.ex — likely contains select_active_organization/3 ref (Phase 14)
- user_scope.ex — likely contains :active_organization field (Phase 12)
- on_mount hooks — may reference Sigra.Plug.LoadActiveOrganization
```

**The CI `install_matrix` job IS the regression lock for this.** Any org ref that slipped into core-emitted code will cause `mix compile --warnings-as-errors` to fail in the `--no-organizations` matrix leg because:

1. The generated `user_auth.ex` calls `Sigra.Organizations.select_active_organization/3`.
2. `Sigra.Organizations` IS still compiled (library-first), so the call succeeds BUT —
3. the generated code may pattern-match on `{:ok, org}` / `{:none, :zero_orgs}` tuples, and if the code path doesn't exist in the template, compile passes but runtime may fail.

**Planner action:** Before writing test code, grep `priv/templates/sigra.install/core/**` for `Sigra.Organizations\|select_active_organization\|active_organization_id` — every hit must either be wrapped in `<%= if @organizations? do %>` (D-05 mechanism 1) or NOT break when organizations is disabled (safer because library is always compiled).

The phase's test bedrock is **`mix compile --warnings-as-errors` + `mix test` in the `--no-organizations` matrix leg**. That's what proves D-05 worked.

---

## Telemetry Event Shape

D-08 specifies `[:sigra, :upgrade, :backfill, :batch]`. Verify against Telemetry naming conventions:

- **Lowercase atom list:** ✓
- **No app prefix duplication:** ✓ (`:sigra` is the app prefix, once)
- **Hierarchy:** `[:app, :feature, :action, :stage]` matches Ecto's `[:ecto, :repo, :query]`, Oban's `[:oban, :job, :start]`, Phoenix's `[:phoenix, :endpoint, :start]`. ✓
- **Measurements (`:erlang.monotonic_time` / counts):** `%{batch_index: i, batch_size: n, total_processed: t, duration_us: elapsed}`
- **Metadata (contextual tags):** `%{repo: repo, adapter: adapter}`

Measurements are things you'd graph/compute-on; metadata is things you'd filter/group-by. Planner should split as above.

One additional event recommended: `[:sigra, :upgrade, :backfill, :done]` emitted once after the last batch, with `%{total_rows: t, total_duration_us: elapsed, total_batches: n}`. This lets observers aggregate per-run totals without reducing over the per-batch stream.

`[CITED: hexdocs.pm/telemetry/readme.html — conventions]`

---

## Git Dirty-Tree Detection

Shape:
```elixir
# Descriptive:
defp git_dirty?(app_dir) do
  case System.cmd("git", ["status", "--porcelain"], cd: app_dir, stderr_to_stdout: true) do
    {"", 0} -> false
    {_output, 0} -> true
    {_output, _nonzero} -> :not_a_git_repo
  end
end
```

**Semantics:**
- `--porcelain` emits a stable machine-readable format. Empty output = clean tree.
- Non-zero exit = not a git repo (e.g., `git status` returns 128 outside a work tree). Treat as "skip the dirty check entirely — developer is on a non-git workflow".
- `--allow-dirty` flag short-circuits the entire check.

**Why porcelain and not plain `git status`:** plain output is localized and format-unstable across git versions; porcelain is a stable contract. `[CITED: git-scm.com/docs/git-status#_porcelain_format_version_1]`

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir ~> 1.18 | Core library compile | ✓ (assumed per CLAUDE.md) | 1.18.x | — |
| `ecto_sql` ~> 3.13 | `Ecto.Migrator.run/4` | ✓ (in mix.exs) | 3.13.x | — |
| `nimble_options` ~> 1.1 | Upgrade task option schema | ✓ (mix.exs:83) | 1.1.x | — |
| `git` CLI | Dirty-tree detection | Assumed host-machine available | varies | `--allow-dirty` flag is the escape hatch |
| Phoenix ~> 1.8 | Test fixture (`mix phx.new`) | ✓ (test-only) | 1.8.x | — |
| PostgreSQL 15+ | Adapter-specific tests + `NOT EXISTS` index predicate | Assumed (dev + CI) | 15+ | MySQL/SQLite fallbacks via Ecto's `on_conflict: :nothing` |

No new dependencies needed. `telemetry` is transitively present via `phoenix`/`ecto_sql`.

---

## Validation Architecture

**Framework:** ExUnit (Elixir standard). Config: `test/test_helper.exs`. Quick run: `mix test`. Full suite: `mix test --include integration`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18 built-in) |
| Config file | `test/test_helper.exs` + `config/test.exs` |
| Quick run command | `mix test <file>:<line>` |
| Full suite command | `mix test --include integration` |
| Upgrade-specific command | `mix test test/upgrade_test.exs --include integration` |

### Workstream 1: Migration + Backfill Library

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-UPGRADE-01 | `Sigra.Upgrade.Backfill.run_personal_orgs/2` inserts 1 personal org per user | unit | `mix test test/sigra/upgrade/backfill_test.exs -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | Re-running backfill after success is a no-op (count unchanged) | unit (idempotency) | `mix test test/sigra/upgrade/backfill_test.exs:<line> -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | Partial failure mid-batch: resume picks up where cursor left off | unit (resume) | `mix test test/sigra/upgrade/backfill_test.exs:<line> -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | Partial unique index rejects duplicate personal orgs at DB level | integration (constraint) | `mix test test/sigra/organizations/personal_index_test.exs -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | `[:sigra, :upgrade, :backfill, :batch]` telemetry emitted per batch | unit (telemetry.attach) | `mix test test/sigra/upgrade/telemetry_test.exs -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | Adapter-branched: same behavior on PG/MySQL/SQLite | integration (adapter matrix) | `mix test test/sigra/upgrade/backfill_test.exs --include adapter_matrix` | ❌ Wave 0 |

### Workstream 2: Generator Flag Plumbing

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-02 | `mix sigra.install --no-organizations` does not emit any `organizations/*` file | unit (Runner) | `mix test test/sigra/install/runner_no_organizations_test.exs -x` | ❌ Wave 0 |
| ORG-02 | `Features.Organizations.enabled?(organizations: false)` returns `false` | unit (feature) | `mix test test/sigra/install/features/organizations_test.exs -x` | likely ❌ |
| ORG-02 | `build_binding/4` forwards `:organizations?` into binding when `--no-organizations` / `--organizations` is passed | unit (binding) | `mix test test/mix/tasks/sigra.install_test.exs -x` | likely ❌ |
| ORG-02 | Inline EEx conditional in `core/user_auth.ex` template renders without `Sigra.Organizations` ref when disabled | unit (template render) | `mix test test/sigra/install/templates_test.exs -x` | ❌ Wave 0 |

### Workstream 3: Upgrade Task + CI + Boot Fixture

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-UPGRADE-03 | `test/upgrade_test.exs` boots v1.0 install, runs upgrade without backfill, login still works | integration (full boot) | `mix test test/upgrade_test.exs --include integration` | ❌ Wave 0 |
| ORG-UPGRADE-03 | `test/upgrade_test.exs` boots v1.0 install, runs upgrade WITH backfill, login works + users have personal orgs | integration (full boot) | same | ❌ Wave 0 |
| ORG-UPGRADE-02 | Upgrade without backfill → existing users land on zero-org page on next login, no 500s | integration | same file, separate test | ❌ Wave 0 |
| GEN-03 | CI `install_matrix` job with `["", "--no-organizations"]` compiles clean | CI workflow (not unit test) | `.github/workflows/ci.yml` — manual-verify via PR CI run | ❌ Wave 0 |
| ORG-UPGRADE-01 | `mix sigra.upgrade --dry-run` prints plan without writing files | unit (task) | `mix test test/mix/tasks/sigra.upgrade_test.exs -x` | ❌ Wave 0 |
| ORG-UPGRADE-01 | `mix sigra.upgrade` refuses to run on dirty git tree without `--allow-dirty` | unit (task) | same file | ❌ Wave 0 |
| ORG-UPGRADE-01 | `mix sigra.upgrade` refuses downgrade (target < recorded) | unit (task) | same file | ❌ Wave 0 |
| ORG-UPGRADE-01 | Version sentinel injection into `config/config.exs` is idempotent on re-run | unit (injector) | `mix test test/sigra/install/injector_test.exs -x` | likely ❌ |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration` (fast suite, <30s target)
- **Per wave merge:** `mix test --include integration` (full suite including upgrade boot test, ~2-5min)
- **Phase gate:** Full suite green + CI `install_matrix` passes both legs + `/gsd-verify-work` sign-off

### Wave 0 Gaps

- [ ] `test/sigra/upgrade/backfill_test.exs` — covers ORG-UPGRADE-01 idempotency + resume + telemetry
- [ ] `test/sigra/upgrade/telemetry_test.exs` — covers telemetry event shape
- [ ] `test/sigra/install/runner_no_organizations_test.exs` — covers D-05 opt-out file-manifest omission (ORG-02)
- [ ] `test/sigra/install/templates_test.exs` — covers inline EEx conditionals render correctly in both modes
- [ ] `test/mix/tasks/sigra.upgrade_test.exs` — covers task flags (`--yes`, `--dry-run`, `--allow-dirty`, `--from`, downgrade refusal)
- [ ] `test/upgrade_test.exs` — top-level upgrade boot fixture (both backfill paths)
- [ ] `test/support/install_fixture.ex` — extend with `run_sigra_upgrade/2` and `run_sigra_install/2` (accept flag arg) helpers
- [ ] `.github/workflows/ci.yml` — new `install_matrix` job
- [ ] `lib/sigra/upgrade.ex` + `lib/sigra/upgrade/backfill.ex` — greenfield library modules
- [ ] `lib/mix/tasks/sigra.upgrade.ex` — greenfield Mix task
- [ ] `priv/templates/sigra.install/organizations/add_personal_to_organizations.exs` — new schema migration template
- [ ] `priv/templates/sigra.install/organizations/data_migrations/backfill_personal_orgs.exs` — new data migration proxy template
- [ ] Add `personal` field to `priv/templates/sigra.install/organizations/organization.ex` schema
- [ ] Register `Sigra.Install.Features.Organizations` in `Mix.Tasks.Sigra.Install.@features`
- [ ] Add `organizations: :boolean` to `@switches` and `organizations?:` to `build_binding/4`

**Framework install:** None — ExUnit + Ecto SQL Sandbox already configured. Cloak vault is already live for other fields.

---

## Recommended Plan Decomposition

CONTEXT.md asked the research step to decide: 1 big plan or 3 plans across waves?

**Recommendation: 3 plans across 2 waves.** Rationale: the phase has a clear dependency inversion (Wave 1 is the foundation nothing else can land on; Wave 2 has two parallel workstreams that don't touch each other's files).

### Wave 1 (sequential, single plan)

**Plan 18-01 — Foundation: `personal` column + `Features.Organizations` registration + fresh-install opt-out plumbing**

Scope:
- Add `personal` field to `Organization` schema template.
- Add new migration slot in `Features.Organizations.migrations/1` for `add_personal_to_organizations.exs` (new template) — or fold into the existing `create_organizations.exs` template depending on planner's call on whether to ship a single migration at install time vs. two-step.
- Register `Sigra.Install.Features.Organizations` in `Mix.Tasks.Sigra.Install.@features`.
- Add `organizations: :boolean` to `@switches`.
- Forward `organizations?:` into `build_binding/4`.
- Wrap any `core/*` template org references in `<%= if @organizations? do %>` (D-05 mechanism 1), verified by grep.
- Add unit tests: `runner_no_organizations_test.exs`, `templates_test.exs`, `features/organizations_test.exs` extensions.

Requirements covered: ORG-02, partial D-01, D-05 flag plumbing.
Blocks: all of Wave 2.

### Wave 2 (parallel, two plans)

**Plan 18-02 — Upgrade task + backfill library + data-migration proxy**

Scope:
- Create `lib/sigra/upgrade.ex` (public API surface: `upgrade/1`, `version/0`, plan builder).
- Create `lib/sigra/upgrade/backfill.ex` (`run_personal_orgs/2` with keyset + `NOT EXISTS` + `insert_all` + telemetry).
- Create `lib/mix/tasks/sigra.upgrade.ex` (NimbleOptions schema, `@switches`, git-dirty check, interactive confirm, `Ecto.Migrator.with_repo/2` + `Ecto.Migrator.run/4`).
- Create `priv/templates/sigra.install/organizations/data_migrations/backfill_personal_orgs.exs` template (5-line proxy).
- Create version sentinel injection into `config/config.exs` via a new `Sigra.Install.Injection` struct.
- Unit tests: `backfill_test.exs`, `telemetry_test.exs`, `sigra.upgrade_test.exs` (task-level), `injector_test.exs` extensions.
- Post-instructions text (CD-01).

Requirements covered: ORG-UPGRADE-01, version sentinel, telemetry event wiring.
Depends on: Wave 1 (needs `personal` column and feature registration to exist).

**Plan 18-03 — Boot fixture + CI matrix + ORG-UPGRADE-02 regression lock**

Scope:
- Extend `test/support/install_fixture.ex` with `run_sigra_install/2` (parameterize flags — currently hard-codes the Accounts User users args) and `run_sigra_upgrade/2` helpers.
- Create `test/upgrade_test.exs` with both backfill-on and backfill-off assertions (boot + login happy-path + user count comparisons).
- Add `.github/workflows/ci.yml` `install_matrix` job with `strategy.matrix.flags: ["", "--no-organizations"]`.
- Add X-4 crash regression assertion (login attempt after upgrade without backfill).

Requirements covered: ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03 (org-axis slice).
Depends on: Wave 1 (needs opt-out to actually work); runs in parallel with Plan 18-02 because boot fixture is install-time, not upgrade-time (ORG-UPGRADE-02 uses install-only path); the ORG-UPGRADE-01 backfill regression is a downstream merge point in Wave 2.

**Wave 2 merge point:** Plan 18-03's `test/upgrade_test.exs` cannot assert the backfill-on path until Plan 18-02 lands the upgrade task. Planner options:
   - (A) Serialize Wave 2 entirely: 18-02 then 18-03.
   - (B) Parallel: Plan 18-03 lands the `--no-organizations` CI matrix + fixture scaffold + backfill-off assertion first, then appends the backfill-on assertion as the last task after Plan 18-02 merges.

**Recommendation: option B.** The CI matrix and fixture scaffolding are independent of the upgrade task; the backfill-on assertion is a single test function tacked on at the end. Option B unlocks parallel review while option A stalls Plan 18-03 for the duration of Plan 18-02.

### Alternative: Single mega-plan

A single `18-01-PLAN.md` covering all three workstreams is technically feasible but risks:
- Plan file >1500 lines.
- Single merge point — any Wave 1 change blocks all of Wave 2.
- Harder to review (reviewers can't focus on "just the upgrade task" or "just the CI matrix").
- Prior phases (17 had 8 plans) set precedent for decomposition.

**Reject the single-plan option.**

---

## Code Examples

### Example 1: Keyset backfill batch loop (descriptive shape, from tylerayoung.com + Dashbit)

```elixir
# Source: synthesized from dashbit.co/blog/automatic-and-manual-ecto-migrations
#         + tylerayoung.com/2023/08/13/migrations/
# This is a research pattern, not the final Sigra code.

defmodule Sigra.Upgrade.Backfill do
  import Ecto.Query
  require Logger

  @default_batch_size 1_000

  def run_personal_orgs(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    users_schema = Keyword.fetch!(opts, :users_schema)
    orgs_schema = Keyword.fetch!(opts, :orgs_schema)

    stream_batches(repo, users_schema, orgs_schema, batch_size, 0, 0)
  end

  defp stream_batches(repo, users, orgs, batch_size, last_cursor, batch_index) do
    start = System.monotonic_time()

    query =
      from u in users,
        as: :u,
        where: u.id > ^last_cursor,
        where: not exists(
          from o in orgs,
            where: o.owner_user_id == parent_as(:u).id and o.personal == true
        ),
        order_by: u.id,
        limit: ^batch_size,
        select: {u.id, u.email, u.display_name}

    case repo.all(query) do
      [] ->
        :ok

      rows ->
        inserts = Enum.map(rows, &build_personal_org/1)

        {count, _} =
          repo.insert_all(orgs, inserts,
            on_conflict: :nothing,
            conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}
          )

        :telemetry.execute(
          [:sigra, :upgrade, :backfill, :batch],
          %{
            batch_index: batch_index,
            batch_size: length(rows),
            inserted: count,
            duration_us: System.monotonic_time() - start
          },
          %{repo: repo}
        )

        new_cursor = rows |> List.last() |> elem(0)
        stream_batches(repo, users, orgs, batch_size, new_cursor, batch_index + 1)
    end
  end

  defp build_personal_org({user_id, email, display_name}) do
    name = (display_name || email_local_part(email) || "Personal") <> "'s Workspace"
    slug = "user-#{user_id}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      id: Ecto.UUID.generate(),
      name: name,
      slug: slug,
      personal: true,
      owner_user_id: user_id,
      inserted_at: now,
      updated_at: now
    }
  end

  defp email_local_part(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, _] -> local
      _ -> nil
    end
  end
end
```

Note: this example assumes an `owner_user_id` column exists on `organizations`. **That column does not exist in the current migration template** (verified via reading `organizations/migration.exs`). D-01's partial index references `owner_user_id`, so Phase 18 also implicitly adds `owner_user_id :binary_id` to the `organizations` table OR the column lands via a prior phase the planner needs to verify. **The planner must confirm this in Wave 1 planning.**

### Example 2: Mix task structure (descriptive)

```elixir
# lib/mix/tasks/sigra.upgrade.ex
defmodule Mix.Tasks.Sigra.Upgrade do
  use Mix.Task

  @schema [
    yes: [type: :boolean, default: false],
    dry_run: [type: :boolean, default: false],
    allow_dirty: [type: :boolean, default: false],
    backfill_personal_orgs: [type: :boolean, default: false],
    from: [type: :string, default: nil]
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: Keyword.keys(@schema) |> Enum.map(&{&1, :boolean}))
    opts = NimbleOptions.validate!(opts, @schema)

    unless opts[:allow_dirty], do: refuse_if_dirty!()

    current = detect_current_version(opts[:from])
    target = Sigra.version()
    plan = build_plan(current, target, opts)

    if opts[:dry_run], do: (print_plan(plan); System.halt(0))
    if !opts[:yes], do: confirm_or_abort(plan)

    apply_plan(plan, opts)
    print_summary(plan)
  end

  # ... plan building, application, helpers
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Data migrations inside schema migrations | Separate `priv/repo/data_migrations/` directory | ecto_sql 3.4 (2020) | Long-running backfills don't block deploys. |
| Sidecar `upgrade_state` tracking tables | Shared `schema_migrations` + `NOT EXISTS` selector idempotency | Shopify railsatscale blog 2023-01-04 | Less infrastructure; idempotency lives in the process, not the state. |
| `OFFSET N` pagination | Keyset cursor (`WHERE id > $cursor`) | Postgres best practice 2015+ | O(1) per batch instead of O(n). |
| Macro-heavy `use Sigra.Schema` injection | Behaviours + explicit generated schemas | José-standard Elixir library design 2020+ | "Own your code" philosophy; no hidden compile-time coupling. |

**Deprecated/outdated:**
- `Repo.transaction/2` wrapping data migrations → use `Repo.transact/2` per Ecto 3.13 release notes. `[CITED: hexdocs.pm/ecto/Ecto.Repo.html]` (Phase 18 backfill should NOT wrap in a transaction, but other parts of the upgrade task might.)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Features.Organizations` currently sits in the tree but is not registered in `@features` | Summary, Standard Stack | Low — verified by reading `lib/mix/tasks/sigra.install.ex:35`. If wrong (phase 17 registered it), Wave 1 plan 18-01's registration task is a no-op. |
| A2 | `organizations` table template lacks `owner_user_id` column today | Code Examples (Example 1 caveat) | **Medium** — if true, Phase 18 must also add `owner_user_id`. If `owner_user_id` landed in Phase 16 or 17 and I missed it, Wave 1 doesn't need to add it. Planner MUST verify by reading `priv/templates/sigra.install/organizations/migration.exs` + `organization_membership.ex` before starting Wave 1. |
| A3 | Phoenix 1.8 `mix phx.new --no-install` flag still works in 2026 | Pitfall 6 | Low — InstallFixture already uses it successfully per test/support/install_fixture.ex:51. |
| A4 | `Ecto.Migrator.run/4` accepts a path string as 2nd arg in ecto_sql ~> 3.13 | Pattern 2 | Low — `[CITED: hexdocs.pm/ecto_sql/Ecto.Migrator.html]` shows this signature. |
| A5 | Batch size 1000 is a sane default for typical Phoenix auth user tables | CD-02 research | Low — confirmed against Shopify (100), Tyler Young (1000), AR in_batches (1000). |
| A6 | `@disable_migration_lock true` is the correct flag name in Ecto 3.13 | Pattern 1 | Low — stable since Ecto 3.0. |
| A7 | Version sentinel via `config.exs` injection is reasonable (CD-03) | Version Detection Research | Low — matches existing `Sigra.Install.Injection` infrastructure. If planner picks `priv/sigra/.version` instead, the overall plan is unchanged. |
| A8 | `Sigra.Upgrade.Backfill` and `mix sigra.upgrade` are greenfield (no existing code) | Summary finding #4 | Low — verified by `ls lib/sigra/` and `ls lib/mix/tasks/`. |
| A9 | Planner will need to recheck the core/*.ex template tree for org refs before landing Plan 18-01 | EEx Conditional Wiring | Medium — I did not do an exhaustive grep across all core templates; a full audit is a task inside Plan 18-01. |

---

## Open Questions (RESOLVED)

> Phase 18 revision 2026-04-14: all five open questions below were closed during planning. Resolutions are inline with each question and reference the plan+task that locked the decision.

1. **Does `owner_user_id` column already exist on `organizations`?**
   - **RESOLVED:** D-00 in 18-CONTEXT.md locks `owner_user_id` as a sticky origin pointer + Plan 18-01 Task 1 bakes it into the fresh-install organizations migration template. Existing orgs get the column via Plan 18-02's `alter_add_owner_user_id.exs` upgrade template (idempotent via `add_if_not_exists`). (See A2.)
   - What we know: D-01's partial unique index references `owner_user_id`, but the migration template I read has `memberships` as the user-org link, not a direct `owner_user_id` column.
   - What's unclear: whether a prior phase added `owner_user_id` as denormalization, or whether "owner" is conventionally "membership with role=owner".
   - Recommendation: Wave 1 kickoff task is "grep organizations/migration.exs for owner_user_id"; if absent, Plan 18-01 adds `owner_user_id :binary_id` column + FK + maintenance of it in `Sigra.Organizations.create/2`. This may be significant additional scope (existing orgs need backfilling from the oldest owner membership).

2. **Which CI job in `.github/workflows/ci.yml` currently serves as precedent for the new `install_matrix` job?**
   - **RESOLVED:** Plan 18-03 Task 3 copies the existing `install_smoke` job skeleton and parameterizes sigra.install via `strategy.matrix.flags` (list-of-flag-strings per D-07). The matrix shape is `["", "--no-organizations"]` and extends naturally for Phase 19+ passkey axis.
   - What we know: CLAUDE.md references `act local CI runner` memory; Phase 11's `golden_diff_test.exs` uses InstallFixture for regression.
   - What's unclear: whether CI already runs an install smoke test (and `install_matrix` is an extension) or whether this is greenfield CI work.
   - Recommendation: Plan 18-03's first task is "read `.github/workflows/ci.yml` and locate existing test job steps to anchor the new matrix job below."

3. **Does the upgrade path generate `config/config.exs` injection on first run (v1.0 → v1.1), or only subsequent runs (v1.1 → v1.1.1)?**
   - **RESOLVED:** Plan 18-02 Task 3 `detect_versions/1` defaults source version to `"1.0.0"` when `config :sigra, :schema_version` is absent (first-run degenerate path). A unit test under Task 3 acceptance criteria (INFO 8) locks this behavior.
   - What we know: CD-03 leaves this to planner discretion.
   - What's unclear: If we inject on v1.0 → v1.1, there's no prior sentinel, so Version.compare fails — the task must handle the "no sentinel found = assume 1.0.0" degenerate path.
   - Recommendation: Handle it. Default source version is `"1.0.0"` when sentinel absent. Inject the new sentinel as part of the v1.1 upgrade.

4. **Should Phase 18's `add_personal_to_organizations.exs` migration be emitted as a separate schema migration OR folded into the existing `create_organizations.exs` template for fresh installs?**
   - **RESOLVED:** D-00/D-01 fold the columns into the fresh-install migration template (Plan 18-01 Task 1). Plan 18-02 Task 2 ships separate upgrade-only ALTER templates (`alter_add_owner_user_id.exs`, `alter_add_personal.exs`) that use `add_if_not_exists` / `create_if_not_exists` so they are idempotent no-ops when the columns already exist (fresh-install shape).
   - What we know: For fresh installs, one migration creates the `personal` column from the start. For upgrades, the `personal` column is a net-new ALTER because the existing host already ran `create_organizations.exs` at Phase 13 time.
   - What's unclear: Do we need TWO templates (one for fresh, one for upgrade ALTER), or one template that the upgrade task emits conditionally?
   - Recommendation: **One template, folded into fresh install.** Fresh installs get `personal :boolean, null: false, default: false` inside `create_organizations.exs`. Upgrade path emits a separate `add_personal_to_organizations.exs` migration file that does `alter table(:organizations) do add :personal, :boolean, null: false, default: false end` + creates the partial unique index. Two template files, but no runtime-conditional emission logic — Plan 18-01 handles the fresh-install fold-in, Plan 18-02 adds the ALTER template consumed by the upgrade task.

5. **What's the failure mode when `Sigra.Install.Injection.Injector.apply/2` encounters an `:elixir_config` anchor on a missing `import_config` line?**
   - **RESOLVED:** Plan 18-02 Task 3 adds a regression test (acceptance criterion for BLOCKER 3 / Q5) that asserts the `:elixir_config` anchor fallback on a `config/config.exs` with no `import_config` line appends cleanly and produces valid Elixir (verified via `Code.string_to_quoted!/1`).
   - What we know: `apply_anchor(:elixir_config, content, payload)` falls back to `content <> payload` (appends to EOF).
   - What's unclear: Whether this is acceptable for version sentinel injection, or whether we should add a `:raise_on_anchor_missing` flag.
   - Recommendation: Accept current behavior for Phase 18 but add a regression test in Plan 18-02's injector tests that confirms the fallback produces compilable `config.exs`. If not, escalate to a stricter anchor mode.

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (Phase 18 does not touch auth primitives) | — |
| V3 Session Management | no | — |
| V4 Access Control | partial (backfill writes org rows that affect access control) | Partial unique index ensures no user gets 2 personal orgs. |
| V5 Input Validation | yes (Mix task CLI args) | NimbleOptions schema validates flag shapes |
| V6 Cryptography | no | — |
| V8 Data Protection | yes (slug = `"user-#{id}"` avoids email-in-URL PII leak) | Opaque slug; email never in URL or logs |
| V10 Malicious Code | yes (data migration pattern must not inject attacker-controlled content) | All backfill data derives from host's own users table; no external input |

### Known Threat Patterns for Elixir Mix task + Ecto data migration

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Upgrade-task downgrade attack (attacker convinces victim to run `--from 99.0.0`) | Elevation | `--from` is advisory; the task still refuses if target < recorded sentinel. Write the check as `Version.compare(target, min(recorded, specified_from))`. |
| Race between upgrade and concurrent signups during backfill | Tampering (race) | `on_conflict: :nothing` on partial unique index absorbs races; partial unique index is the authoritative barrier. |
| Long-running backfill holds advisory lock, blocks deploys | Denial of Service | `@disable_migration_lock true` + `@disable_ddl_transaction true` on data migration. |
| PII leak in personal org name from display_name / email | Information disclosure | Slug is opaque (`user-#{id}`), not derived from email/name. Name is shown only to the owning user. |
| Git-dirty bypass (`--allow-dirty` used on prod) | Tampering (accident) | `--allow-dirty` is an explicit opt-in flag; documented warning in `--help` text and confirmation prompt. |
| Shell injection via `System.cmd/3` on git subprocess | Tampering | `System.cmd/3` with list-of-args (not shell string) is shell-injection-safe by construction. |

---

## Sources

### Primary (HIGH confidence — verified in this session)

- `lib/mix/tasks/sigra.install.ex` — current `@features`, `@switches`, `build_binding/4` shape (VERIFIED)
- `lib/sigra/install/feature.ex` — behaviour contract (VERIFIED)
- `lib/sigra/install/features/organizations.ex` — feature module exists, implements 5 callbacks, uses `Keyword.get(opts, :organizations, true)` at line 37 (VERIFIED)
- `lib/sigra/install/features/core.ex` — core feature, does not reference Organizations module, emits `add_active_organization_id_to_user_sessions.exs` (VERIFIED)
- `lib/sigra/install/runner.ex:53` — `active = Enum.filter(features, & &1.enabled?(opts))` — enablement filter happens upstream (VERIFIED)
- `lib/sigra/install/injector.ex:434` — `Injector.apply/2` three-state behavior (VERIFIED)
- `lib/sigra/install/injection.ex` — struct shape (VERIFIED)
- `test/support/install_fixture.ex` — existing fixture API (VERIFIED)
- `priv/templates/sigra.install/organizations/migration.exs` — current schema; no `personal` column, no `owner_user_id` column; adapter-branched PG vs MySQL/SQLite (VERIFIED)
- `priv/templates/sigra.install/organizations/organization.ex` — schema template; no `personal` field (VERIFIED)
- `mix.exs:83` — `{:nimble_options, "~> 1.1"}` already present (VERIFIED)
- `.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md` — locked decisions D-01..D-08, CD-01..CD-03 (READ)

### Secondary (MEDIUM confidence — verified via web search)

- [dashbit.co/blog/automatic-and-manual-ecto-migrations](https://dashbit.co/blog/automatic-and-manual-ecto-migrations) — canonical data-migrations pattern
- [github.com/fly-apps/safe-ecto-migrations](https://github.com/fly-apps/safe-ecto-migrations) — `@disable_ddl_transaction` / `@disable_migration_lock` safety flags
- [tylerayoung.com/2023/08/13/migrations/](https://tylerayoung.com/2023/08/13/migrations/) — Elixir backfill microframework prior art
- [hexdocs.pm/ecto_sql/Ecto.Migrator.html](https://hexdocs.pm/ecto_sql/Ecto.Migrator.html) — `Ecto.Migrator.run/4` and `with_repo/2` signatures
- [github.com/Shopify/maintenance_tasks](https://github.com/Shopify/maintenance_tasks) — batch size default (100) comparison
- [railsatscale.com/2023-01-04-how-we-scaled-maintenance-tasks-to-shopifys-core-monolith](https://railsatscale.com/2023-01-04-how-we-scaled-maintenance-tasks-to-shopify-s-core-monolith/) — idempotency-in-process lesson
- [hexdocs.pm/oban/Oban.Migration.html](https://hexdocs.pm/oban/Oban.Migration.html) — version-aware migration pattern prior art
- [hexdocs.pm/telemetry/readme.html](https://hexdocs.pm/telemetry/readme.html) — event naming conventions
- [git-scm.com/docs/git-status#_porcelain_format_version_1](https://git-scm.com/docs/git-status) — stable `--porcelain` contract

### Tertiary (lower confidence — flagged for validation)

- Assumption that Phase 13/16 did NOT add `owner_user_id` to organizations migration template (Open Question #1)
- Assumption that CI workflow file exists and needs extension rather than greenfield (Open Question #2)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all deps verified in mix.exs, no new libraries needed.
- Architecture patterns: HIGH — Dashbit + fly-apps + Shopify patterns are well-documented, cross-referenced.
- Pitfalls: HIGH — migration ordering, idempotency race, anchor injection gotchas are all grounded in verified codebase reads.
- Plan decomposition: HIGH — clear Wave 1 foundation + Wave 2 parallel workstreams with one explicit merge point.
- Open questions: MEDIUM — Open Question #1 (`owner_user_id`) is the biggest unknown and could reshape Plan 18-01 scope.

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (30 days — stable ecosystem, no fast-moving dependencies)

---

## RESEARCH COMPLETE

Phase 18 is ready to plan. Four concrete codebase gaps surfaced (listed in Summary); three-plan decomposition recommended (18-01 foundation, 18-02 upgrade task, 18-03 boot fixture + CI); five open questions flagged of which Open Question #1 (`owner_user_id` column existence) is the one the planner MUST resolve before writing Plan 18-01.
