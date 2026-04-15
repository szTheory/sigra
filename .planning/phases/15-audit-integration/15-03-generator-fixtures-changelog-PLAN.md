---
phase: 15-audit-integration
plan: 03
type: execute
wave: 3
depends_on:
  - 15-01
  - 15-02
files_modified:
  - lib/sigra/install/features/core.ex
  - test/fixtures/install_golden/tree/
  - test/example/
  - test/support/audit_test_event.ex
  - CHANGELOG.md
  - test/sigra/audit/query_index_test.exs
autonomous: true
requirements:
  - AUD-01
  - AUD-03

must_haves:
  truths:
    - "Fresh mix sigra.install emits the new alter_audit_events_add_org_columns migration alongside the frozen create migration"
    - "test/fixtures/install_golden/tree/ matches the regenerated install output byte-for-byte"
    - "test/example/ reflects the new schema + migration state"
    - "CHANGELOG.md documents the session.create ordering fix and the unknown-filter-key ArgumentError as intentional breaking changes"
    - "Postgres EXPLAIN test proves the (organization_id, inserted_at) composite index is hit for Query.build/2 with :organization_id filter"
  artifacts:
    - path: "lib/sigra/install/features/core.ex"
      provides: "Generator manifest emits the new alter migration file"
      contains: "alter_audit_events_add_org_columns"
    - path: "test/fixtures/install_golden/tree/"
      provides: "Golden install output with new migration + updated schema"
    - path: "CHANGELOG.md"
      provides: "Entries for the two intentional breaking changes"
      contains: "session.create"
  key_links:
    - from: "lib/sigra/install/features/core.ex"
      to: "priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs"
      via: "files/1 callback emits the migration alongside create_audit_events.exs"
      pattern: "alter_audit_events_add_org_columns"
    - from: "test/sigra/audit/query_index_test.exs"
      to: "(organization_id, inserted_at) composite index"
      via: "EXPLAIN SELECT assertion"
      pattern: "Index Scan using audit_events_organization_id_inserted_at_index"
---

<objective>
Wire the new ALTER migration through the generator, regenerate golden fixtures and the example app, update the test audit schema, document the two intentional breaking changes in CHANGELOG, and un-skip the Postgres EXPLAIN index-hit test so the `(organization_id, inserted_at)` composite is proven to be used.

Purpose: Plans 15-01 and 15-02 landed the library changes but did not update the install path. Host apps running `mix sigra.install` on a fresh project must receive the new migration + updated schema, and host apps upgrading must have the new migration emitted as a standalone file. The golden fixture + example app regeneration proves the install path is byte-consistent, and the CHANGELOG entries document the two behavior changes (session.create reorder, unknown-filter-key raise) that would otherwise surprise v1.0 users.

Output: Updated generator manifest, regenerated install golden tree, regenerated example app, CHANGELOG entries, and a live Postgres index-hit test.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/15-audit-integration/15-CONTEXT.md
@.planning/phases/15-audit-integration/15-RESEARCH.md
@.planning/phases/15-audit-integration/15-VALIDATION.md
@.planning/phases/15-audit-integration/15-01-SUMMARY.md
@.planning/phases/15-audit-integration/15-02-SUMMARY.md

@lib/sigra/install/features/core.ex
@priv/templates/sigra.install/core/create_audit_events.exs
@priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs
@priv/templates/sigra.install/core/audit_event.ex
@CHANGELOG.md

<interfaces>
<!-- From Plan 15-01: the alter migration template -->
<!-- From Plan 15-02: the session.create reorder and the unknown-filter-key raise -->
<!-- From Phase 13: on_delete: :nilify_all contract for organization_id FK -->

Generator manifest pattern (from Phase 11):
  `Sigra.Install.Features.Core` implements `Sigra.Install.Feature` with:
  - `enabled?/1` → always true
  - `files/1` → list of template files to emit (relative paths under priv/templates/sigra.install/core/)
  - `injections/1` → list of %Injection{} structs
  - `migrations/1` → ordered migration template files with strict timestamps

This plan adds one entry to `files/1` or `migrations/1` for the new alter migration.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Wire alter migration through generator + test audit schema parity + regenerate golden + example</name>
  <files>
    lib/sigra/install/features/core.ex,
    test/support/audit_test_event.ex,
    test/fixtures/install_golden/tree/,
    test/example/
  </files>
  <read_first>
    - lib/sigra/install/features/core.ex (full file — locate files/1 or migrations/1 callback where create_audit_events.exs is registered)
    - priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs (from 15-01)
    - priv/templates/sigra.install/core/create_audit_events.exs (existing, FROZEN reference — do NOT modify)
    - test/support/audit_test_event.ex (verify 15-01 Wave 0 already added the two fields — defensive check)
    - test/fixtures/install_golden/ README or test/sigra/install/golden_diff_test.exs (understand regen harness)
    - .planning/phases/15-audit-integration/15-CONTEXT.md D-09, D-10, D-14
    - .planning/phases/15-audit-integration/15-RESEARCH.md (manual runbook for install_golden + example regen)
  </read_first>
  <action>
    **1. Update `lib/sigra/install/features/core.ex`** to register the new alter migration.

    Locate the callback where `create_audit_events.exs` is registered (grep: `grep -n "create_audit_events" lib/sigra/install/features/core.ex`). Add the new alter migration AFTER it in the migration list, with a strictly-later timestamp (GEN-07 contract from Phase 11):

    ```elixir
    # In migrations/1 (or files/1, whichever owns audit migrations):
    [
      # ... existing ...
      %{
        template: "core/create_audit_events.exs",
        timestamp_offset: existing_offset,
        target: "priv/repo/migrations/{{timestamp}}_create_audit_events.exs"
      },
      %{
        template: "core/alter_audit_events_add_org_columns.exs",
        timestamp_offset: existing_offset + 1,  # strictly after create
        target: "priv/repo/migrations/{{timestamp}}_alter_audit_events_add_org_columns.exs"
      }
      # ... existing ...
    ]
    ```

    The exact struct shape depends on the Phase 11 feature manifest — use the shape already used by `create_audit_events.exs`. The binding passed to EEx must include `adapter` so the template's `<%= if @adapter == :postgres do %>` branching works (confirmed by 15-RESEARCH.md).

    **2. Verify `test/support/audit_test_event.ex`** has the two new fields (added in Plan 15-01 Wave 0). If missing, add:
    ```elixir
    field :organization_id, :binary_id
    field :effective_user_id, :binary_id
    ```

    **3. Regenerate `test/fixtures/install_golden/tree/`:**

    Follow the manual runbook from 15-RESEARCH.md. Typical steps:
    ```bash
    # Remove the old golden tree (or let the regen harness overwrite)
    rm -rf test/fixtures/install_golden/tree
    # Run the generator against a throwaway target under /tmp
    MIX_ENV=test mix sigra.install.regen_golden
    # OR (if no regen mix task): manual regen
    cd /tmp && mix phx.new throwaway --no-ecto --no-html
    cd throwaway && mix sigra.install --yes
    # Copy tree back into fixture
    rsync -a --delete /tmp/throwaway/ $SIGRA_ROOT/test/fixtures/install_golden/tree/
    ```

    Whatever the exact mechanism, the resulting `test/fixtures/install_golden/tree/` MUST contain the new `alter_audit_events_add_org_columns.exs` migration file under `priv/repo/migrations/` and the updated `audit_event.ex` schema with the two new fields.

    **4. Regenerate `test/example/`:** Same approach — the example app is the second fixture that must reflect the new install output. If a regen task exists (`mix sigra.regen_example` or similar), run it. Otherwise, apply the migration + schema diff manually by:
    - Adding the new migration file under `test/example/priv/repo/migrations/`
    - Updating `test/example/lib/example/audit_event.ex` with the two new fields

    **5. Run the golden-diff test** (`mix test test/sigra/install/golden_diff_test.exs` or equivalent) and the example-app smoke test (`mix test test/example/` or the existing CI harness). Both must pass.

    **6. Confirm the Postgres alter migration is round-trippable:**
    ```bash
    MIX_ENV=test mix ecto.drop
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate
    MIX_ENV=test mix ecto.rollback --all
    MIX_ENV=test mix ecto.migrate
    ```
    Migration up → down → up must be clean.
  </action>
  <verify>
    <automated>mix test test/sigra/install/ --include golden_diff && mix compile --warnings-as-errors</automated>
  </verify>
  <done>
    Generator emits the alter migration; golden tree and example app reflect it; up/down round-trip clean on Postgres.
  </done>
  <acceptance_criteria>
    - `grep -c "alter_audit_events_add_org_columns" lib/sigra/install/features/core.ex` returns at least `1`
    - `ls test/fixtures/install_golden/tree/priv/repo/migrations/ 2>&1 | grep -c alter_audit_events_add_org_columns` returns `1`
    - `grep -c "field :organization_id, :binary_id" test/fixtures/install_golden/tree/lib/*/audit_event.ex 2>/dev/null` returns at least `1`
    - `grep -c "field :effective_user_id, :binary_id" test/fixtures/install_golden/tree/lib/*/audit_event.ex 2>/dev/null` returns at least `1`
    - `ls test/example/priv/repo/migrations/ | grep -c alter_audit_events_add_org_columns` returns `1`
    - `grep -c "field :organization_id, :binary_id" test/support/audit_test_event.ex` returns `1`
    - `mix test test/sigra/install/` exits 0
    - `MIX_ENV=test mix ecto.drop && MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate && MIX_ENV=test mix ecto.rollback --all && MIX_ENV=test mix ecto.migrate` exits 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: CHANGELOG entries + Postgres EXPLAIN index-hit test</name>
  <files>
    CHANGELOG.md,
    test/sigra/audit/query_index_test.exs
  </files>
  <read_first>
    - CHANGELOG.md (existing file, understand formatting convention)
    - test/sigra/audit/query_index_test.exs (stub created in 15-01 Wave 0)
    - .planning/phases/15-audit-integration/15-CONTEXT.md D-15 (breaking change statement), D-27 (session.create reorder)
    - lib/sigra/audit/query.ex (verify Query.build/2 signature for the test)
  </read_first>
  <action>
    **1. Add CHANGELOG entries** under a new `## [Unreleased]` or `## [v1.1.0]` section (match existing convention in the file). Two entries, under subsections:

    ```markdown
    ## [v1.1.0] - Unreleased

    ### Added
    - `Sigra.Audit.log_safe/3` accepts a scope as the second positional argument. The scope is duck-typed on `%{user, active_organization, impersonating_from}`; pass `nil` explicitly for pre-authentication or truly anonymous call sites. `log_safe/2` remains as a thin shim.
    - `Sigra.Audit.Query` supports `:organization_id`, `:effective_user_id`, and `:organization_scope` filters. `:organization_scope` accepts `{:only, org_id}` or `{:including_global, org_id}` tagged tuples.
    - `Sigra.Scope.build/3` library constructor for the host-app `%Scope{}` struct, used by login-time scope synthesis and by Sigra-aware workers.
    - `Sigra.Workers` behaviour — single `@callback perform(scope, args)` contract for Oban workers requiring tenant context. `Sigra.Workers.new/3` fails fast when required `"organization_id"` / `"actor_id"` arg keys are absent.
    - `Sigra.Testing.assert_audit_logged/2` helper wrapping `assert_audit_event/2` with a name aligned to REQ DX-02.
    - Custom Credo check `Sigra.Credo.NoLogSafe2InLib` that forbids arity-2 `Sigra.Audit.log_safe` calls in `lib/sigra/**` (with an exception for the shim definition and for `test/**`).

    ### Changed
    - **BREAKING (behavior):** `session.create` audit now fires AFTER `select_active_organization` during login, so the very first audit event of a login carries the real `organization_id`. Previously, it fired before org assignment and always had a null org. If you were relying on the old ordering (e.g. a log scraper keyed on null-org events for login detection), update your consumers to match.
    - **BREAKING (API):** `Sigra.Audit.Query.build/2` now raises `ArgumentError` on unknown filter keys instead of silently ignoring them. If your host app was passing an unknown key (e.g. `actor:` instead of `actor_id:`) the query previously returned unfiltered results — now it fails loudly. Rationale: silent-ignore on an audit query is a security-adjacent bug.

    ### Added migrations
    - New alter migration `alter_audit_events_add_org_columns.exs` adds `organization_id :binary_id` (nullable, FK `on_delete: :nilify_all`) and `effective_user_id :binary_id` (nullable) columns to `audit_events`, plus a composite index `(organization_id, inserted_at)`. On Postgres, the migration uses `@disable_ddl_transaction true` + `create index(..., concurrently: true)` for zero-downtime deploy on production audit tables. On SQLite/MySQL, a plain `change/0` migration emits the same shape non-concurrently.
    ```

    Adjust formatting to match the existing CHANGELOG.md style (headings, date format, bullet style). Do NOT remove or reorder existing entries.

    **2. Un-skip and implement `test/sigra/audit/query_index_test.exs`** (stub was created in 15-01 Wave 0).

    Remove `@tag :skip` from the test and implement the Postgres-only EXPLAIN-based assertion:

    ```elixir
    defmodule Sigra.Audit.QueryIndexTest do
      use Sigra.DataCase  # or whatever the existing Ecto test case is

      @moduletag :postgres

      setup do
        unless Sigra.Repo.__adapter__() == Ecto.Adapters.Postgres do
          {:skip, "Postgres-only: EXPLAIN plan test"}
        else
          :ok
        end
      end

      test "Query.build/2 with :organization_id hits the (organization_id, inserted_at) composite index" do
        org_id = Ecto.UUID.generate()

        query =
          Sigra.Audit.Query.build(Sigra.Test.AuditTestEvent,
            organization_id: org_id,
            order: [desc: :inserted_at],
            limit: 50
          )

        {sql, params} = Sigra.Repo.to_sql(:all, query)

        %Postgrex.Result{rows: rows} =
          Ecto.Adapters.SQL.query!(Sigra.Repo, "EXPLAIN " <> sql, params)

        plan_text = rows |> List.flatten() |> Enum.join("\n")

        assert plan_text =~ "audit_events_organization_id_inserted_at_index",
               "Expected (organization_id, inserted_at) composite index hit, got:\n#{plan_text}"
      end
    end
    ```

    If the actual schema / repo / test module names differ, adjust accordingly — the key assertion is that the EXPLAIN output substring-matches the composite index name.

    **3. Run the test** to prove the index is being used:
    ```bash
    MIX_ENV=test mix ecto.reset  # ensure the alter migration has run
    mix test test/sigra/audit/query_index_test.exs
    ```

    If the assertion fails (Postgres decides to seq-scan on an empty table), insert ~100 rows first to make the planner prefer the index, or use `SET enable_seqscan = off` before the EXPLAIN. Document whichever escape hatch you use in a comment on the test.
  </action>
  <verify>
    <automated>mix test test/sigra/audit/query_index_test.exs --include postgres</automated>
  </verify>
  <done>
    CHANGELOG.md has both breaking-change entries + the additions summary; the Postgres EXPLAIN test passes and proves the composite index is hit.
  </done>
  <acceptance_criteria>
    - `grep -c "session.create" CHANGELOG.md` returns at least `1`
    - `grep -c "ArgumentError" CHANGELOG.md` returns at least `1`
    - `grep -c "BREAKING" CHANGELOG.md` returns at least `2`
    - `grep -c "alter_audit_events_add_org_columns" CHANGELOG.md` returns at least `1`
    - `grep -c "Sigra.Workers" CHANGELOG.md` returns at least `1`
    - `grep -c "@tag :skip" test/sigra/audit/query_index_test.exs` returns `0` (un-skipped)
    - `grep -c "audit_events_organization_id_inserted_at_index" test/sigra/audit/query_index_test.exs` returns at least `1`
    - `grep -c "EXPLAIN" test/sigra/audit/query_index_test.exs` returns at least `1`
    - `mix test test/sigra/audit/query_index_test.exs --include postgres` exits 0 on Postgres
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Install path | Host apps consume generator output as-is; drift between library and generated code is a silent footgun |
| Upgrade path | v1.0 users running the new ALTER must not lose data; concurrent index creation must actually concurrent |
| Query performance | Audit-log queries scale linearly without index use; seq-scan at volume is a DoS surface |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-15-05 | Tampering | Alter migration FK declaration | mitigate | Generator emits `references(:organizations, type: :binary_id, on_delete: :nilify_all)` verbatim (per 15-01 template); golden fixture regen catches any drift. Anti-regression for Phase 13 D-17. |
| T-15-07 | Denial of Service | `Sigra.Audit.Query` at scale | mitigate | EXPLAIN-based index-hit test in `test/sigra/audit/query_index_test.exs` asserts the `(organization_id, inserted_at)` composite is actually used for `:organization_id` filter. Prevents a silent seq-scan regression in future schema changes. |
| T-15-08 | Repudiation | CHANGELOG documentation gap | accept | Breaking changes MUST be loud (rationale: silent ignores in audit systems are worse than loud failures). CHANGELOG entries cover both the `session.create` reorder and the unknown-filter-key raise so v1.0 upgraders can react. |
</threat_model>

<verification>
- `mix test` full suite green
- `mix credo --strict` exits 0 (re-check after fixture regen)
- `mix docs --warnings-as-errors` stays clean (per DX-08)
- `mix test test/sigra/install/` green (golden-diff test)
- `mix test test/sigra/audit/query_index_test.exs --include postgres` green on Postgres
- Migration round-trips: `MIX_ENV=test mix ecto.drop && mix ecto.create && mix ecto.migrate && mix ecto.rollback --all && mix ecto.migrate` exits 0
- CHANGELOG.md has two explicit BREAKING entries
</verification>

<success_criteria>
All `must_haves.truths` hold; fresh install emits the alter migration; golden fixtures + example app are regenerated and pass; CHANGELOG documents the two behavior changes; EXPLAIN test proves the composite index is used under Postgres. Phase 15 is ready for `/gsd-verify-work` and merge.
</success_criteria>

<output>
After completion, create `.planning/phases/15-audit-integration/15-03-SUMMARY.md` including: generator manifest diff, golden-fixture diff stats (files added / modified), CHANGELOG entry text, EXPLAIN test output capture, and the full-suite + credo + docs green confirmation. This is the final plan SUMMARY for Phase 15.
</output>
