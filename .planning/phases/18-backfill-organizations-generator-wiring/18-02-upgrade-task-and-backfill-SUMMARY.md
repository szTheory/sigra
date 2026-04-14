---
phase: 18-backfill-organizations-generator-wiring
plan: 02
subsystem: upgrade
tags: [upgrade, migration, backfill, nimble_options, telemetry, phase-18]
requires:
  - phase-11 Sigra.Install.Injection + Sigra.Install.Injector.apply/2
  - phase-18 plan 01 fresh-install shape (owner_user_id + personal columns)
provides:
  - Sigra.Upgrade.Backfill library with keyset-paginated run_personal_orgs/2 + per-batch telemetry + NimbleOptions schema
  - Sigra.Upgrade orchestrator (git dirty check, version detect, downgrade refusal, plan build, EEx template walker, version sentinel injection, three-section stdout summary)
  - Mix.Tasks.Sigra.Upgrade entry point with NimbleOptions-validated flags (--yes, --dry-run, --allow-dirty, --backfill-personal-orgs, --from VERSION)
  - priv/templates/sigra.upgrade/data_migration.exs — Dashbit-style 10-line shim delegating to library backfill
  - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs — ALTER for existing v1.0 orgs + earliest-owner backfill via UPDATE..FROM
  - priv/templates/sigra.upgrade/alter_add_personal.exs — ALTER for personal boolean + partial unique index
  - BLOCKER 1 zero-org detection: organizations_table_present?/0 scans priv/repo/migrations/ for create table(:organizations
  - insert_all/3 callback added to Sigra.MockRepo.Behaviour
affects:
  - Upgrade codepath from v1.0 to v1.1 (ORG-UPGRADE-01)
  - Host apps with and without the organizations feature (zero-org installs correctly skip ALTERs)
  - Phase 18 plan 03 (CI matrix can now exercise mix sigra.upgrade against both install variants)
tech-stack:
  added:
    - ":telemetry event namespace [:sigra, :upgrade, :backfill, :batch | :done]"
  patterns:
    - "Dashbit data migration pattern (priv/repo/data_migrations/ separation + @disable_ddl_transaction + @disable_migration_lock)"
    - "Keyset cursor pagination (u.id > ^last_cursor, NOT offset) per Ecto + Shopify maintenance_tasks prior art"
    - "Library-resident batching with a 10-line host-side shim so fixes ship via mix deps.update"
    - "EEx.eval_file/2 walker for upgrade templates, byte-compatible with Sigra.Install.Runner"
    - "NimbleOptions schema at both the Mix task CLI boundary and the library function boundary (defence-in-depth validation)"
key-files:
  created:
    - lib/sigra/upgrade.ex
    - lib/sigra/upgrade/backfill.ex
    - lib/mix/tasks/sigra.upgrade.ex
    - priv/templates/sigra.upgrade/data_migration.exs
    - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs
    - priv/templates/sigra.upgrade/alter_add_personal.exs
    - test/sigra/upgrade_test.exs
    - test/sigra/upgrade/backfill_test.exs
  modified:
    - test/support/mock_repo_behaviour.ex
decisions:
  - "Default source schema version is \"0.0.0\" (not plan's \"1.0.0\") — Sigra's current vsn is 0.1.0 so a \"1.0.0\" literal would trip the downgrade refusal on every run. Pre-v1 libs start schema versioning at 0."
  - "repo_module binding in upgrade_binding/0 uses inspect(repo_module), matching Mix.Tasks.Sigra.Install.build_binding/4 precedent verbatim. A bare module atom would interpolate as \"Elixir.MyApp.Repo\" via to_string/1; inspect/1 produces the canonical bare \"MyApp.Repo\"."
  - "Backfill tests use the Mox-based Sigra.MockRepo pattern (hermetic, no live DB) rather than a real Postgres connection — consistent with the rest of the Sigra unit test suite."
  - "personal_exists_subquery/1 helper built as a separate query expression instead of inlining a second `from o in ^orgs_schema` inside the main query — Ecto's pin operator can't target query sources inside subquery expressions, so the subquery must be built separately and passed by reference."
metrics:
  duration: "~45 minutes"
  completed: 2026-04-14
  tasks_completed: 4
  files_created: 8
  files_modified: 1
---

# Phase 18 Plan 02: Upgrade Task and Backfill Summary

Shipped `mix sigra.upgrade`: a NimbleOptions-validated Mix task that delegates to a Sigra.Upgrade orchestrator (git dirty check, version detect, downgrade refusal, plan, interactive confirm, EEx template walker, three-section stdout summary, version sentinel injection) which in turn composes with a library-resident Sigra.Upgrade.Backfill (keyset-paginated NOT EXISTS selector, Repo.insert_all with on_conflict: :nothing on the partial unique index, per-batch telemetry, NimbleOptions-validated schemas) — plus three Dashbit-pattern upgrade templates under priv/templates/sigra.upgrade/ (a 10-line data_migration shim delegating to the library, and two idempotent ALTER migrations for owner_user_id + personal).

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Sigra.Upgrade.Backfill library + 11 unit tests | `8f4cf00` | `lib/sigra/upgrade/backfill.ex`, `test/sigra/upgrade/backfill_test.exs`, `test/support/mock_repo_behaviour.ex` |
| 2 | Three upgrade-only migration templates (data_migration shim + two ALTERs) | `848e881` | `priv/templates/sigra.upgrade/data_migration.exs`, `.../alter_add_owner_user_id.exs`, `.../alter_add_personal.exs` |
| 3 | Sigra.Upgrade orchestrator + 14 regression tests | `38556ce` | `lib/sigra/upgrade.ex`, `test/sigra/upgrade_test.exs` |
| 4 | Mix.Tasks.Sigra.Upgrade with NimbleOptions schema | `8a3daab` | `lib/mix/tasks/sigra.upgrade.ex` |

## What Shipped

### 1. `Sigra.Upgrade.Backfill` (Task 1)

New module `lib/sigra/upgrade/backfill.ex`. Public surface:

```elixir
@spec run_personal_orgs(module(), keyword()) :: {:ok, non_neg_integer()}
def run_personal_orgs(repo, opts \\ [])
```

NimbleOptions schema requires `:users_schema` and `:orgs_schema` (atoms), with `:batch_size` defaulting to 1_000 (per Phase 18 CD-02).

**Query shape (build_query/4):** First batch uses a cursor-less query; subsequent batches add `where: u.id > ^last_cursor`. Both versions wrap a separately-built `personal_exists_subquery/1` inside `not exists(...)`. Rationale: Ecto's `^` pin operator can't target the source module inside an inline subquery (`from o in ^orgs_schema` is a compile error outside macro context), so the subquery must be constructed as a separate query value and passed by reference.

```elixir
defp personal_exists_subquery(orgs_schema) do
  from o in orgs_schema,
    where: o.owner_user_id == parent_as(:u).id and o.personal == true,
    select: 1
end
```

**Insert shape:** `Repo.insert_all/3` with `on_conflict: :nothing, conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}` — matches Phase 18 D-01's partial unique index predicate exactly so a race with concurrent signups collapses silently.

**Naming fallback chain (D-04):** `display_name` (if non-blank string) → email local-part (before `@`) → literal `"Personal"`. Slug is always `"user-#{user.id}"` — opaque, immutable, PII-safe.

**Telemetry:** per-batch `[:sigra, :upgrade, :backfill, :batch]` with `%{batch_index, batch_size, inserted, total_processed}`, and a terminal `[:sigra, :upgrade, :backfill, :done]` with `%{total_processed, batches}`.

**11 AAA tests** (all async: false) cover:

1. Happy path: 3 users → 3 rows with `personal: true`, correct owner_user_id, correct slug format, correct on_conflict opts
2. Idempotent no-op when residual set is empty
3. Skip existing: residual selector returns only 1 user of 3
4. `display_name` workspace name override
5. Email local-part fallback
6. `"Personal"` fallback when neither field present
7. 2500-user multi-batch telemetry (3 batches: 1000, 1000, 500)
8. `:done` event emits once at end with correct totals
9. Keyset cursor advances (second query has extra `where` clause)
10. Missing `:users_schema` raises NimbleOptions error
11. Missing `:orgs_schema` raises NimbleOptions error

**MockRepo behaviour extended:** Added `@callback insert_all/3` to `Sigra.MockRepo.Behaviour` (Rule 3 — required to stub the backfill's insert path under the existing hermetic test pattern).

### 2. Three upgrade templates (Task 2)

- **`data_migration.exs`** — 10-line Dashbit shim with `@disable_ddl_transaction true` + `@disable_migration_lock true` flags, a single `up/0` that calls `Sigra.Upgrade.Backfill.run_personal_orgs/2` with host schema modules, and `def down, do: :ok`. All batching/telemetry/SQL lives in the library so fixes ship via `mix deps.update`.

- **`alter_add_owner_user_id.exs`** — ALTER with `add_if_not_exists :owner_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)` followed by an `execute/2` call that runs `UPDATE organizations o SET owner_user_id = (SELECT m.user_id FROM organization_memberships m WHERE m.organization_id = o.id AND m.role = 'owner' ORDER BY m.inserted_at ASC LIMIT 1) WHERE owner_user_id IS NULL`. `down/0` uses `remove_if_exists`. Binary-id awareness via `<%= if binary_id do %>` EEx guard.

- **`alter_add_personal.exs`** — ALTER with `add_if_not_exists :personal, :boolean, null: false, default: false` + `create_if_not_exists unique_index(:organizations, [:owner_user_id], where: "personal = true", name: :organizations_personal_owner_uidx)`. `down/0` drops the index first, then removes the column.

All three templates use EEx `<%= repo_module %>` (bare render — see Task 3 decision note) and are byte-compatible with the install walker's binding shape.

### 3. `Sigra.Upgrade` orchestrator (Task 3)

`lib/sigra/upgrade.ex` — the guts of `mix sigra.upgrade`. Public API is just `run/1` but several helpers are `@doc false` and reachable from the Mix.Tasks layer and from the regression tests.

**Pipeline (run/1):**

```elixir
with :ok <- check_git_dirty(opts),
     {:ok, source, target} <- detect_versions(opts),
     :ok <- ensure_upgrade_direction(source, target),
     plan <- build_plan(opts, source, target),
     :ok <- maybe_confirm(plan, opts) do
  apply_plan(plan, opts)
end
```

**Git dirty check:** `System.cmd("git", ["status", "--porcelain"])` — empty output = clean (allow), non-empty output = `Mix.raise("Refusing to run...")` with the dirty file list echoed, non-zero exit status = not a git repo (allow). `--allow-dirty` short-circuits the check entirely.

**Version detection:** source from `--from VERSION` → then `Application.get_env(:sigra, :schema_version, "0.0.0")`; target from `:application.get_key(:sigra, :vsn)`. `ensure_upgrade_direction/2` uses `Version.compare/2` and raises on `:lt`, short-circuits on `:eq`.

**BLOCKER 1 zero-org detection (`organizations_table_present?/0`):** Pre-Ecto-connect scan of `priv/repo/migrations/` for any file whose body contains the literal substring `create table(:organizations`. Returns `false` when the directory doesn't exist or no match is found — which makes `migrations_to_emit/1` return `[]` on `--no-organizations` v1.0 installs (Phase 18 D-06 test fixture depends on this).

**Migrations emitted:**

| Condition | Migrations |
|---|---|
| No organizations table | `[]` (even with `--backfill-personal-orgs`) |
| Organizations table present, no backfill flag | 2 ALTERs (`alter_add_owner_user_id`, `alter_add_personal`) |
| Organizations table present + `--backfill-personal-orgs` | 2 ALTERs + 1 data migration shim |

**Version sentinel injection:** returns a `%Sigra.Install.Injection{}` with `target: "config/config.exs"`, `marker: "config :sigra, :schema_version"`, `anchor: :elixir_config` — delegating to the existing `Sigra.Install.Injector.apply/2` from Phase 11. The marker ensures re-runs are idempotent no-ops.

**Template walker (write_migration/2):** Splits destination by template name — `data_migration.exs` lands in `priv/repo/data_migrations/`, the two ALTERs land in `priv/repo/migrations/`. Both get a UTC timestamp prefix via `Calendar.strftime/2`. `EEx.eval_file/2` renders with the minimal upgrade binding.

**Upgrade binding (`upgrade_binding/0`):** Matches `Mix.Tasks.Sigra.Install.build_binding/4` by using `inspect(repo_module)` for the repo atom — `inspect/1` on a module atom renders as the bare `MyApp.Repo` identifier, which is what EEx `<%= repo_module %>` must produce. (Using a bare atom directly would go through `to_string/1` and produce `"Elixir.MyApp.Repo"`.) See deviations section below.

**Apply injection (`apply_injection/1`):** Extracted out of `apply_plan/2` to satisfy Credo's max depth 2 — handles `{:ok, _}`, `{:error, {:target_missing, path}}` (logs and continues so upgrades on apps without a `config/config.exs` don't hard-fail), and raises on any other injection error.

**14 regression tests** in `test/sigra/upgrade_test.exs` cover:

- BLOCKER 1: `organizations_table_present?/0` on empty dir, missing dir, and a seeded `create table(:organizations` migration file
- BLOCKER 1: `migrations_to_emit/1` returns `[]` in zero-org case (even with backfill flag), 2 ALTERs when present without backfill, 3 items with backfill flag
- INFO 8: `detect_versions/1` default source when `:schema_version` sentinel is deleted from env; target from `:sigra` app vsn; `--from` override
- Git dirty check: dirty tree raises, `--allow-dirty` bypasses, clean tree passes (using a real throwaway `git init` inside System.tmp_dir)
- BLOCKER 3 / WARNING 7: `build_plan/3` yields a `config :sigra, :schema_version` injection whose content is valid Elixir (`Code.string_to_quoted!/1` round-trip)

### 4. `Mix.Tasks.Sigra.Upgrade` (Task 4)

`lib/mix/tasks/sigra.upgrade.ex` — thin shell: parses args via `OptionParser`, validates with `NimbleOptions.validate!/2`, delegates to `Sigra.Upgrade.run/1`. No business logic at the task boundary. Schema covers `:yes`, `:dry_run`, `:allow_dirty`, `:backfill_personal_orgs`, `:from`. `mix help sigra.upgrade` was verified to render the full moduledoc.

## Verification

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | PASS |
| `mix test test/sigra/upgrade/backfill_test.exs` | 11 tests, 0 failures |
| `mix test test/sigra/upgrade_test.exs` | 14 tests, 0 failures |
| `mix test test/sigra/upgrade_test.exs test/sigra/upgrade/backfill_test.exs` | 25 tests, 0 failures |
| `mix format --check-formatted` (touched files) | PASS |
| `mix credo --strict lib/sigra/upgrade.ex` | PASS (after apply_injection/1 extraction) |
| `mix credo --strict lib/sigra/upgrade/backfill.ex` | PASS |
| `mix credo --strict lib/mix/tasks/sigra.upgrade.ex` | PASS |
| `mix help sigra.upgrade` | Discovers task, prints moduledoc |
| Task 1 grep: `def run_personal_orgs(repo, opts`, `not exists`, `parent_as(:u)`, `u.id > \^last_cursor`, `on_conflict: :nothing`, `:unsafe_fragment`, `[:sigra, :upgrade, :backfill, :batch]`, `NimbleOptions.validate!` | all ≥ 1 |
| Task 1 grep: `OFFSET\|offset:` in backfill.ex | 0 (keyset only) |
| Task 2 grep: `@disable_ddl_transaction true`, `@disable_migration_lock true`, `Sigra.Upgrade.Backfill.run_personal_orgs`, `on_delete: :nilify_all`, `UPDATE organizations`, `organizations_personal_owner_uidx`, `where: "personal = true"` | all ≥ 1 |
| Task 3 grep: `defmodule Sigra.Upgrade do`, `def run(opts)`, `check_git_dirty`, `git.*status.*porcelain`, `Version.compare`, `Refusing to downgrade`, `config :sigra, :schema_version`, `Mix.shell().yes?`, `priv/repo/data_migrations`, `Applied:`, `Pending:`, `Next steps:` | all ≥ 1 |
| Task 4 grep: `defmodule Mix.Tasks.Sigra.Upgrade do`, `use Mix.Task`, `@shortdoc`, `NimbleOptions.validate!`, `Sigra.Upgrade.run`, `backfill_personal_orgs`, `allow_dirty` | all ≥ 1 |

## Deviations from Plan

### Rule 1 (Auto-fixed bug) — Plan's `"1.0.0"` default source version is incompatible with current library version

**Found during:** Task 3 test authoring.

**Issue:** `18-CONTEXT.md` D-08 specifies `source = Keyword.get(opts, :from) || Application.get_env(:sigra, :schema_version, "1.0.0")`. Sigra's actual library version (from `mix.exs @version`) is `"0.1.0"`. `Version.compare("0.1.0", "1.0.0")` returns `:lt`, so `ensure_upgrade_direction/2` would raise `"Refusing to downgrade"` on every single run in the current repo — no test of the orchestrator could pass, and any user running `mix sigra.upgrade` would hit the downgrade refusal as the first thing.

**Fix:** Changed the default to `"0.0.0"`. Pre-v1 libraries logically start their schema versioning at `0.0.0`; the sentinel gets written to `"0.1.0"` after the first upgrade run, so subsequent runs pick up the real version from `config/config.exs`. The plan's intent — "refuse downgrades, allow re-runs, short-circuit on `:eq`" — holds identically.

**Files modified:** `lib/sigra/upgrade.ex` (`@default_source_version "0.0.0"`).

**Commit:** `38556ce`.

**Test coverage:** `test/sigra/upgrade_test.exs` → `"defaults source to a pre-1.0 version when the sentinel config key is absent"` now asserts `target >= source` (not a specific literal) — stable across future version bumps.

### Rule 1 (Auto-fixed bug) — Plan's `repo_module: repo` bare-atom binding produces wrong EEx output

**Found during:** Task 3 binding construction.

**Issue:** Plan 18-02 Task 3's `upgrade_binding/0` action says *"`repo_module` binding uses a bare module atom (e.g. `MyApp.Repo`); do NOT wrap in `inspect/1`"*. This is wrong. When EEx evaluates `<%= repo_module %>` against a binding `[repo_module: MyApp.Repo]` (a bare atom), Elixir's EEx injects a `to_string/1` call around the value. `to_string/1` on a module atom returns `"Elixir.MyApp.Repo"` (with the `Elixir.` prefix, via atom-to-string conversion). The generated migration would therefore have `defmodule Elixir.MyApp.Repo.Migrations.AddOwnerUserIdToOrganizations do` — a compile error in the host app.

The actual existing precedent, `lib/mix/tasks/sigra.install.ex:109`, uses `repo_module: inspect(repo_module)`. `inspect/1` on a module atom returns the canonical `"MyApp.Repo"` string (no `Elixir.` prefix). That's what every install template interpolates successfully today.

**Fix:** Used `inspect(repo_module)` to match install precedent verbatim. The plan's Task 3 acceptance criterion `"the generated file contains the bare substring 'defmodule MyApp.Repo.Migrations.AddOwnerUserIdToOrganizations do'"` is satisfied by `inspect/1`, not by a bare atom.

**Files modified:** `lib/sigra/upgrade.ex` (`upgrade_binding/0`).

**Commit:** `38556ce`.

### Rule 1 (Auto-fixed compile error) — Ecto subquery `from o in ^orgs_schema` is a compile error

**Found during:** Task 1 first compile.

**Issue:** Plan 18-02 Task 1's `build_query/4` action uses inline `from o in ^orgs_schema` inside a `not exists(...)` clause. Ecto's `^` pin operator is only valid inside matches or inside custom macros where the underlying macro has opted into it; it cannot target the source module of a subquery expression compiled as part of the parent `from`. The compiler errors with `"misplaced operator ^orgs_schema"`.

**Fix:** Built the exists-clause subquery as a separate top-level query via a `personal_exists_subquery/1` helper and passed it by reference:

```elixir
exists_query = personal_exists_subquery(orgs_schema)
from u in users_schema,
  as: :u,
  where: not exists(exists_query),
  ...
```

The semantics are identical — Ecto emits the same SQL — but the pin operator issue is sidestepped because `orgs_schema` is only resolved inside the helper's own `from` where it's a first-class source.

**Files modified:** `lib/sigra/upgrade/backfill.ex`.

**Commit:** `8f4cf00`.

### Rule 3 (Auto-fixed blocking issue) — `Sigra.MockRepo.Behaviour` missing `insert_all/3` callback

**Found during:** Task 1 test authoring.

**Issue:** `Sigra.Upgrade.Backfill.run_personal_orgs/2` calls `repo.insert_all/3`, but `Sigra.MockRepo.Behaviour` (the hermetic-test mock shared across the Sigra suite) didn't declare that callback. Without it, Mox can't stub the call, and the backfill tests couldn't run without a live Postgres connection — which would have violated the test suite's hermetic-by-default invariant.

**Fix:** Added `@callback insert_all/3` to `test/support/mock_repo_behaviour.ex` with the standard Ecto.Repo signature.

**Files modified:** `test/support/mock_repo_behaviour.ex`.

**Commit:** `8f4cf00`.

### Rule 1 (Credo refactor) — `apply_plan/2` exceeded max nesting depth

**Found during:** Task 3 `mix credo --strict` run.

**Issue:** The inlined `Enum.each(plan.injections, fn injection -> case ... end)` block made `apply_plan/2` exceed Credo's "function body nested too deep (max depth is 2, was 3)" check.

**Fix:** Extracted the per-injection logic into a separate `apply_injection/1` private function. Semantics unchanged; nesting depth now 2.

**Files modified:** `lib/sigra/upgrade.ex`.

**Commit:** `38556ce`.

## Scope-boundary deferrals

**Pre-existing formatting drift across the repository (unrelated files).** `mix format --check-formatted` at the repo root flags a substantial set of pre-existing unformatted files (lib/sigra/audit/changeset.ex, lib/sigra/oauth/strategies/apple.ex, lib/sigra/workers/account_deletion.ex, multiple controllers and test files generated or hand-edited before Plan 18-02). None of these were touched by this plan. Per the SCOPE BOUNDARY rule, they are not in scope for this plan. Scoped check `mix format --check-formatted` over only this plan's touched `.ex` files passes.

**Full `mix test` run.** Not executed because Plan 18-01's SUMMARY already documents the 5 pre-existing Phase 16/17 install template failures (DEF-18-01 / DEF-18-02) that Plan 18-02 cannot fix. The tests this plan owns (`test/sigra/upgrade/backfill_test.exs`, `test/sigra/upgrade_test.exs`) all pass — 25 tests, 0 failures.

## Known Stubs

None. Plan 18-02 does not introduce any stub data, placeholder UI, or disconnected components. `files_to_emit/1` returns `[]` intentionally — the plan only emits injections + migrations, never template files — and the upcoming Plan 18-03 test fixture exercises the orchestrator end-to-end.

## Dependencies Satisfied

- **ORG-UPGRADE-01** — Developers upgrading from v1.0 to v1.1 can run `mix sigra.upgrade --backfill-personal-orgs --yes` idempotently. The backfill library is keyset-paginated, on-conflict-safe against the partial unique index, telemetry-instrumented, and strictly opt-in via the CLI flag.

## Next Steps

- **Plan 18-03** can proceed. The CI matrix leg `mix sigra.upgrade --yes --allow-dirty` over a `mix sigra.install --no-organizations` tmp app is now structurally valid: `organizations_table_present?/0` detects the missing table and emits zero ALTERs; only the version sentinel injection is applied. The org-enabled leg exercises the full pipeline (2 ALTERs + optional backfill shim).
- A follow-up plan should land a broader `mix format` pass across the pre-existing unformatted files flagged above — outside Plan 18-02's scope.

## Self-Check: PASSED

All 8 created files and 1 modified file exist on disk. All 4 per-task commits exist in git history and are reachable from HEAD:

- `8f4cf00` — Task 1 (Backfill library)
- `848e881` — Task 2 (Three templates)
- `38556ce` — Task 3 (Upgrade orchestrator)
- `8a3daab` — Task 4 (Mix task)

25 tests pass across `test/sigra/upgrade/backfill_test.exs` (11) and `test/sigra/upgrade_test.exs` (14). `mix compile --warnings-as-errors` clean. Scoped `mix format --check-formatted` clean over all touched files. `mix credo --strict` clean on all three created library modules. `mix help sigra.upgrade` discovers the task and prints its moduledoc.
