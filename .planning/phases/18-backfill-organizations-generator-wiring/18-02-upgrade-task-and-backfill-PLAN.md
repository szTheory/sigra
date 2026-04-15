---
phase: 18-backfill-organizations-generator-wiring
plan: 02
type: execute
wave: 2
depends_on: [01]
files_modified:
  - lib/mix/tasks/sigra.upgrade.ex
  - lib/sigra/upgrade.ex
  - lib/sigra/upgrade/backfill.ex
  - priv/templates/sigra.upgrade/data_migration.exs
  - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs
  - priv/templates/sigra.upgrade/alter_add_personal.exs
  - test/sigra/upgrade/backfill_test.exs
autonomous: true
requirements: [ORG-UPGRADE-01]
tags: [upgrade, migration, backfill, nimble_options, telemetry]
must_haves:
  truths:
    - "Developer can run `mix sigra.upgrade --yes` and have the task detect source/target versions, refuse downgrades, and emit a three-section stdout summary (Applied / Pending / Next steps)"
    - "Developer can run `mix sigra.upgrade --backfill-personal-orgs --yes` and have it generate a data migration that delegates to Sigra.Upgrade.Backfill.run_personal_orgs/2"
    - "Sigra.Upgrade.Backfill.run_personal_orgs/2 uses keyset pagination (u.id > ^last_cursor), NOT exists selector, and Repo.insert_all with on_conflict: :nothing"
    - "Backfill emits [:sigra, :upgrade, :backfill, :batch] telemetry events per batch with batch_index, batch_size, total_processed measurements"
    - "Running mix sigra.upgrade on a dirty git tree is refused unless --allow-dirty is passed"
    - "Version sentinel `config :sigra, :schema_version, ...` is injected into config/config.exs on upgrade"
  artifacts:
    - path: "lib/mix/tasks/sigra.upgrade.ex"
      provides: "Mix task entry point with NimbleOptions-validated flags"
      contains: "defmodule Mix.Tasks.Sigra.Upgrade"
    - path: "lib/sigra/upgrade.ex"
      provides: "Upgrade orchestrator — git check, version detect, plan build, apply"
      contains: "defmodule Sigra.Upgrade"
    - path: "lib/sigra/upgrade/backfill.ex"
      provides: "Library-resident backfill with keyset pagination + telemetry"
      contains: "def run_personal_orgs(repo, opts"
    - path: "priv/templates/sigra.upgrade/data_migration.exs"
      provides: "Ecto.Migration shim template with concurrent-safety flags"
      contains: "@disable_migration_lock true"
    - path: "priv/templates/sigra.upgrade/alter_add_owner_user_id.exs"
      provides: "ALTER migration for owner_user_id on existing orgs + backfill from earliest owner membership"
      contains: "alter table(:organizations)"
    - path: "priv/templates/sigra.upgrade/alter_add_personal.exs"
      provides: "ALTER migration for personal boolean + partial unique index"
      contains: "organizations_personal_owner_uidx"
  key_links:
    - from: "Mix.Tasks.Sigra.Upgrade.run/1"
      to: "Sigra.Upgrade.run/1"
      via: "delegation after NimbleOptions.validate!"
      pattern: "Sigra\\.Upgrade\\.run"
    - from: "priv/templates/sigra.upgrade/data_migration.exs"
      to: "Sigra.Upgrade.Backfill.run_personal_orgs/2"
      via: "shim calls into versioned library function"
      pattern: "Sigra\\.Upgrade\\.Backfill\\.run_personal_orgs"
    - from: "Sigra.Upgrade"
      to: "config/config.exs"
      via: "Sigra.Install.Injection with marker `config :sigra, :schema_version`"
      pattern: "schema_version"
---

<objective>
Create the `mix sigra.upgrade` Mix task, the `Sigra.Upgrade` orchestrator, and the `Sigra.Upgrade.Backfill` library (keyset-paginated `NOT EXISTS` selector, `Repo.insert_all` with `on_conflict: :nothing`, per-batch telemetry). Ship three upgrade-only migration templates: a 10-line data-migration shim that delegates to the versioned library function, and two ALTER templates that add `owner_user_id` and `personal` to existing v1.0 `organizations` tables. Inject a version sentinel into `config/config.exs`.

Purpose: Closes ORG-UPGRADE-01 — developers upgrading from v1.0 to v1.1 can run `mix sigra.upgrade --backfill-personal-orgs` idempotently. Keeps all security-critical batching logic in the versioned library (fixes ship via `mix deps.update`) while the host app holds only a thin 10-line data-migration shim.

Output: Working `mix sigra.upgrade` task with NimbleOptions-validated flags, Dashbit data-migration pattern, per-batch telemetry, adapter-agnostic `on_conflict: :nothing` insert, and a unit-tested backfill library function.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-RESEARCH.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-01-foundation-schema-and-flag-PLAN.md
@lib/mix/tasks/sigra.install.ex
@lib/sigra/install/runner.ex
@lib/sigra/install/features/core.ex
@lib/sigra/install/injection.ex
@lib/sigra/install/injector.ex
@lib/sigra/organizations.ex
@priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs

<interfaces>
<!-- Key types + APIs extracted from codebase — use directly, do not re-explore -->

Sigra.Install.Injection struct (from lib/sigra/install/injection.ex):
```elixir
%Sigra.Install.Injection{
  target: String.t(),        # relative path, e.g. "config/config.exs"
  marker: String.t(),        # idempotency marker substring
  anchor: :elixir_config | :before_last_end | :after_use_block | :at_top,
  content: String.t()        # text to inject
}
```

Sigra.Install.Injector.apply/2 — marker-based idempotent writer.

NimbleOptions contract (Sigra-wide stack choice per CLAUDE.md):
```elixir
@schema [
  flag: [type: :boolean, default: false, doc: "..."],
  value: [type: :pos_integer, default: 1_000, doc: "..."]
]
opts = NimbleOptions.validate!(opts, @schema)
```

Ecto.Migrator custom-path pattern (from hexdocs.pm/ecto_sql/Ecto.Migrator.html):
```elixir
Ecto.Migrator.with_repo(repo, fn repo ->
  Ecto.Migrator.run(repo, "priv/repo/data_migrations", :up, all: true)
end)
```

Telemetry event shape (Phoenix 1.8+ idiom):
```elixir
:telemetry.execute(
  [:sigra, :upgrade, :backfill, :batch],
  %{batch_index: integer, batch_size: integer, total_processed: integer, inserted: integer},
  %{}
)
```

Ecto query keyset pagination (NOT exists subquery via parent_as/1):
```elixir
import Ecto.Query
from u in users_schema,
  as: :u,
  where: u.id > ^last_cursor,
  where: not exists(
    from o in ^orgs_schema,
      where: o.owner_user_id == parent_as(:u).id and o.personal == true
  ),
  order_by: u.id,
  limit: ^batch_size
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Sigra.Upgrade.Backfill library with keyset-paginated run_personal_orgs/2 + unit tests</name>
  <files>lib/sigra/upgrade/backfill.ex, test/sigra/upgrade/backfill_test.exs</files>
  <read_first>
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-02, D-03, D-04, CD-02
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section `lib/sigra/upgrade/backfill.ex`
    - lib/sigra/organizations.ex (import Ecto.Query idiom lines 32–36; query shapes)
    - .planning/phases/11-generator-feature-system/11-CONTEXT.md (feature manifest contract — for config resolution pattern)
  </read_first>
  <action>
Create `lib/sigra/upgrade/backfill.ex` as a new module under a new `lib/sigra/upgrade/` subtree. The full function skeleton:

```elixir
defmodule Sigra.Upgrade.Backfill do
  @moduledoc """
  Library-resident backfill logic for `mix sigra.upgrade --backfill-personal-orgs`.

  The host app's generated data migration (`priv/repo/data_migrations/*_backfill_personal_orgs.exs`)
  is a 10-line shim that calls `run_personal_orgs/2`. All batching, telemetry,
  and SQL logic lives here so fixes ship via `mix deps.update`.

  ## Idempotency guarantees

  Two independent layers (D-03):

  1. **Selector-level** — `where: not exists(...)` narrows to residual set on
     every re-run. Keyset cursor (`u.id > ^last_cursor`) avoids OFFSET's O(n)
     scan and makes crash-resume free.
  2. **Insert-level** — `on_conflict: :nothing` with `conflict_target:` the
     partial unique index catches any race with concurrent signups.

  ## Telemetry

  Emits `[:sigra, :upgrade, :backfill, :batch]` per batch with measurements:
    * `:batch_index` — zero-based counter
    * `:batch_size`  — rows returned by the selector
    * `:inserted`    — rows inserted (may be < batch_size on conflict)
    * `:total_processed` — running total across all batches
  """

  import Ecto.Query

  @options_schema [
    batch_size: [
      type: :pos_integer,
      default: 1_000,
      doc: "Rows per batch. Default 1000 (CD-02) — tune down for low-memory hosts."
    ],
    users_schema: [
      type: :atom,
      required: true,
      doc: "Ecto schema module for the users table (e.g. MyApp.Accounts.User)."
    ],
    orgs_schema: [
      type: :atom,
      required: true,
      doc: "Ecto schema module for the organizations table (e.g. MyApp.Accounts.Organization)."
    ]
  ]

  @doc """
  Backfills a personal organization for every user that does not already have one.

  Idempotent: safe to re-run. See module docs for guarantees.
  """
  def run_personal_orgs(repo, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    batch_size = opts[:batch_size]
    users_schema = opts[:users_schema]
    orgs_schema = opts[:orgs_schema]

    do_batch(repo, users_schema, orgs_schema, batch_size, nil, 0, 0)
  end

  defp do_batch(repo, users_schema, orgs_schema, batch_size, last_cursor, batch_index, total_processed) do
    query = build_query(users_schema, orgs_schema, last_cursor, batch_size)

    case repo.all(query) do
      [] ->
        :telemetry.execute(
          [:sigra, :upgrade, :backfill, :done],
          %{total_processed: total_processed, batches: batch_index},
          %{}
        )
        {:ok, total_processed}

      users ->
        rows = Enum.map(users, &build_personal_org_row/1)

        {inserted, _} =
          repo.insert_all(orgs_schema, rows,
            on_conflict: :nothing,
            conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}
          )

        new_total = total_processed + inserted

        :telemetry.execute(
          [:sigra, :upgrade, :backfill, :batch],
          %{
            batch_index: batch_index,
            batch_size: length(users),
            inserted: inserted,
            total_processed: new_total
          },
          %{}
        )

        next_cursor = users |> List.last() |> Map.fetch!(:id)
        do_batch(repo, users_schema, orgs_schema, batch_size, next_cursor, batch_index + 1, new_total)
    end
  end

  defp build_query(users_schema, orgs_schema, nil, batch_size) do
    from u in users_schema,
      as: :u,
      where: not exists(
        from o in ^orgs_schema,
          where: o.owner_user_id == parent_as(:u).id and o.personal == true
      ),
      order_by: u.id,
      limit: ^batch_size
  end

  defp build_query(users_schema, orgs_schema, last_cursor, batch_size) do
    from u in users_schema,
      as: :u,
      where: u.id > ^last_cursor,
      where: not exists(
        from o in ^orgs_schema,
          where: o.owner_user_id == parent_as(:u).id and o.personal == true
      ),
      order_by: u.id,
      limit: ^batch_size
  end

  defp build_personal_org_row(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    display = derive_display_name(user)

    %{
      id: Ecto.UUID.generate(),
      owner_user_id: user.id,
      name: "#{display}'s Workspace",
      slug: "user-#{user.id}",
      personal: true,
      inserted_at: now,
      updated_at: now
    }
  end

  defp derive_display_name(user) do
    cond do
      has_field?(user, :display_name) and is_binary(user.display_name) and user.display_name != "" ->
        user.display_name

      is_binary(Map.get(user, :email)) and String.contains?(user.email, "@") ->
        user.email |> String.split("@") |> List.first()

      true ->
        "Personal"
    end
  end

  defp has_field?(user, field) do
    Map.has_key?(user, field)
  end
end
```

**Note on the `nil` cursor clause:** Postgres cannot compare a UUID to `nil` via `>`, so the first batch uses a cursor-less query. Subsequent batches use `u.id > ^last_cursor` where the cursor is always a bound UUID.

**Adapter branching:** zero hand-written SQL. `Repo.insert_all` with `on_conflict: :nothing` emits the correct adapter-specific clause via Ecto. The `conflict_target: {:unsafe_fragment, ...}` form is required because the partial unique index predicate is non-standard.

**Create `test/sigra/upgrade/backfill_test.exs`** with these AAA-style tests (use async: false because telemetry handlers are process-global):

1. `test "creates personal orgs for users with none"` — seed 3 users with no personal orgs, call `run_personal_orgs/2`, assert 3 personal orgs exist with `personal: true`, correct `owner_user_id`, correct slug format `"user-#{id}"`.
2. `test "is idempotent on re-run"` — call twice, assert count stays at 3.
3. `test "skips users who already have a personal org"` — seed 2 users with pre-existing personal orgs + 1 without, call, assert only 1 new org inserted (total = 3).
4. `test "honors display_name in workspace name when present"` — user with `display_name: "Alice Smith"`, assert org name == `"Alice Smith's Workspace"`.
5. `test "falls back to email local-part when display_name is blank"` — user with `display_name: nil, email: "bob@example.com"`, assert name == `"bob's Workspace"`.
6. `test "emits telemetry events per batch"` — attach handler to `[:sigra, :upgrade, :backfill, :batch]`, seed 2500 users with `batch_size: 1_000`, assert 3 events received with correct `batch_index` values 0/1/2.
7. `test "uses keyset pagination across batches"` — seed >batch_size users, assert the selector never returns the same user twice (cursor test).
8. `test "raises when required schemas are missing"` — call with `batch_size: 1_000` but no `:users_schema` opt, assert NimbleOptions raises.
  </action>
  <verify>
    <automated>mix test test/sigra/upgrade/backfill_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `lib/sigra/upgrade/backfill.ex` exists
    - `grep -c "def run_personal_orgs(repo, opts" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "import Ecto.Query" lib/sigra/upgrade/backfill.ex` returns 1
    - `grep -c "not exists" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "parent_as(:u)" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "u.id > \\^last_cursor" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "on_conflict: :nothing" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c ":unsafe_fragment" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "\\[:sigra, :upgrade, :backfill, :batch\\]" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "NimbleOptions.validate!" lib/sigra/upgrade/backfill.ex` returns ≥ 1
    - `grep -c "OFFSET\\|offset:" lib/sigra/upgrade/backfill.ex` returns 0 (keyset, NOT offset)
    - `mix test test/sigra/upgrade/backfill_test.exs` exits 0
    - `mix compile --warnings-as-errors` exits 0
    - `mix format --check-formatted lib/sigra/upgrade/backfill.ex test/sigra/upgrade/backfill_test.exs` exits 0
    - `mix credo --strict lib/sigra/upgrade/backfill.ex` exits 0
  </acceptance_criteria>
  <done>Library backfill module exists with keyset pagination, `on_conflict: :nothing` insert, per-batch telemetry, NimbleOptions-validated options, and ≥8 passing AAA-style unit tests.</done>
</task>

<task type="auto">
  <name>Task 2: Create three upgrade-only migration templates (data_migration shim + two ALTERs)</name>
  <files>priv/templates/sigra.upgrade/data_migration.exs, priv/templates/sigra.upgrade/alter_add_owner_user_id.exs, priv/templates/sigra.upgrade/alter_add_personal.exs</files>
  <read_first>
    - priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs (simplest Ecto.Migration template analog)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-00, D-01, D-02
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md sections for the three new templates
  </read_first>
  <action>
Create the new `priv/templates/sigra.upgrade/` directory with three EEx templates.

**File 1: `priv/templates/sigra.upgrade/data_migration.exs`** (Dashbit data-migration shim, 10 lines):

```eex
defmodule <%= repo_module %>.DataMigrations.BackfillPersonalOrgs do
  @moduledoc """
  Generated by `mix sigra.upgrade --backfill-personal-orgs` (Phase 18).

  Thin shim — all batching/telemetry/SQL logic lives in
  `Sigra.Upgrade.Backfill.run_personal_orgs/2` and ships via `mix deps.update`.
  """

  use Ecto.Migration

  # Concurrent-safety flags (fly-apps/safe-ecto-migrations):
  # a multi-hour backfill must NOT hold pg_advisory_lock or block deploys.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    Sigra.Upgrade.Backfill.run_personal_orgs(repo(),
      batch_size: 1_000,
      users_schema: <%= context_module %>.<%= schema_alias %>,
      orgs_schema: <%= context_module %>.Organization
    )
  end

  def down, do: :ok
end
```

**File 2: `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs`** — adds the column to an existing v1.0 orgs table AND backfills from earliest-owner membership. Not wrapped in `@disable_ddl_transaction` because the row count is bounded (organizations table is typically small):

```eex
defmodule <%= repo_module %>.Migrations.AddOwnerUserIdToOrganizations do
  @moduledoc """
  Phase 18 D-00: add sticky `owner_user_id` to existing organizations.
  Backfills origin owner from earliest `:owner` membership — bounded row count,
  no batching needed.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :owner_user_id,
        references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
    end

    # Populate from the earliest :owner membership per org.
    execute("""
    UPDATE organizations o SET owner_user_id = (
      SELECT m.user_id FROM organization_memberships m
      WHERE m.organization_id = o.id AND m.role = 'owner'
      ORDER BY m.inserted_at ASC
      LIMIT 1
    ) WHERE owner_user_id IS NULL
    """, "")
  end

  def down do
    alter table(:organizations) do
      remove_if_exists :owner_user_id, references(:<%= table_name %>)
    end
  end
end
```

**File 3: `priv/templates/sigra.upgrade/alter_add_personal.exs`** — adds the `personal` boolean + partial unique index:

```eex
defmodule <%= repo_module %>.Migrations.AddPersonalToOrganizations do
  @moduledoc """
  Phase 18 D-01: add `personal` column + partial unique index enforcing
  at-most-one-personal-org-per-user. Runs AFTER AddOwnerUserIdToOrganizations.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :personal, :boolean, null: false, default: false
    end

    create_if_not_exists unique_index(:organizations, [:owner_user_id],
      where: "personal = true",
      name: :organizations_personal_owner_uidx
    )
  end

  def down do
    drop_if_exists index(:organizations, [:owner_user_id], name: :organizations_personal_owner_uidx)

    alter table(:organizations) do
      remove_if_exists :personal, :boolean
    end
  end
end
```

**Adapter note:** The postgres partial unique index predicate `where: "personal = true"` is postgres-specific. For mysql/sqlite branches in ALTER paths, the index falls back to a composite `(owner_user_id, personal)` — handled at plan-apply time in `Sigra.Upgrade`. Plan 18-02 ships the postgres-shape template only; adapter branching for ALTERs lives in the walker that emits these templates (see Task 4).
  </action>
  <verify>
    <automated>ls priv/templates/sigra.upgrade/ && grep -l "run_personal_orgs" priv/templates/sigra.upgrade/data_migration.exs</automated>
  </verify>
  <acceptance_criteria>
    - `priv/templates/sigra.upgrade/data_migration.exs` exists
    - `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` exists
    - `priv/templates/sigra.upgrade/alter_add_personal.exs` exists
    - `grep -c "@disable_ddl_transaction true" priv/templates/sigra.upgrade/data_migration.exs` returns 1
    - `grep -c "@disable_migration_lock true" priv/templates/sigra.upgrade/data_migration.exs` returns 1
    - `grep -c "Sigra.Upgrade.Backfill.run_personal_orgs" priv/templates/sigra.upgrade/data_migration.exs` returns 1
    - `grep -c "on_delete: :nilify_all" priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` returns 1
    - `grep -c "UPDATE organizations" priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` returns 1
    - `grep -c "organizations_personal_owner_uidx" priv/templates/sigra.upgrade/alter_add_personal.exs` returns 1
    - `grep -c "where: \"personal = true\"" priv/templates/sigra.upgrade/alter_add_personal.exs` returns 1
  </acceptance_criteria>
  <done>Three upgrade templates exist with correct safety flags, library delegation, and idempotency-friendly `add_if_not_exists` / `create_if_not_exists`.</done>
</task>

<task type="auto">
  <name>Task 3: Create Sigra.Upgrade orchestrator (git check, version detect, plan build, apply, sentinel injection)</name>
  <files>lib/sigra/upgrade.ex</files>
  <read_first>
    - lib/sigra/install/runner.ex (walker shape — lines 52–120)
    - lib/sigra/install/features/core.ex (line 469 `config_injection/4` — prior art for version sentinel)
    - lib/sigra/install/injection.ex
    - lib/sigra/install/injector.ex
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-02, D-08, CD-03
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section `lib/sigra/upgrade.ex`
  </read_first>
  <action>
Create `lib/sigra/upgrade.ex` as a new top-level library module. Full skeleton:

```elixir
defmodule Sigra.Upgrade do
  @moduledoc """
  Orchestrator for `mix sigra.upgrade`.

  Responsibilities:
    * Refuse dirty git working trees unless `--allow-dirty`
    * Detect source/target schema versions; refuse downgrades
    * Compute the plan (files to create, injections to apply, migrations to emit)
    * Interactive confirmation when `--yes` is not set
    * Emit the three-section stdout summary (Applied / Pending / Next steps)
    * Inject/update the version sentinel in `config/config.exs`
    * Optionally emit the personal-orgs data migration when `--backfill-personal-orgs`

  All file I/O paths go through `Sigra.Install.Injector` / EEx eval to stay
  byte-compatible with the install walker.
  """

  alias Sigra.Install.Injection
  alias Sigra.Install.Injector

  @typedoc "Validated opts from Mix.Tasks.Sigra.Upgrade (after NimbleOptions)"
  @type opts :: keyword()

  @spec run(opts()) :: :ok | {:halt, term()} | no_return()
  def run(opts) do
    with :ok <- check_git_dirty(opts),
         {:ok, source, target} <- detect_versions(opts),
         :ok <- ensure_upgrade_direction(source, target),
         plan <- build_plan(opts, source, target),
         :ok <- maybe_confirm(plan, opts) do
      apply_plan(plan, opts)
    end
  end

  # ── Git dirty tree check ──────────────────────────────────────────

  defp check_git_dirty(opts) do
    if Keyword.get(opts, :allow_dirty, false) do
      :ok
    else
      case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
        {"", 0} ->
          :ok

        {output, 0} when byte_size(output) > 0 ->
          Mix.raise("""
          Refusing to run `mix sigra.upgrade` on a dirty working tree.

          Either commit/stash your changes, or pass --allow-dirty to override.

          #{output}
          """)

        {_, _} ->
          # Not a git repo — allow (host app may not use git).
          :ok
      end
    end
  end

  # ── Version detection ────────────────────────────────────────────

  defp detect_versions(opts) do
    source = Keyword.get(opts, :from) || Application.get_env(:sigra, :schema_version, "1.0.0")
    target = :sigra |> Application.spec(:vsn) |> to_string()
    {:ok, source, target}
  end

  defp ensure_upgrade_direction(source, target) do
    case Version.compare(target, source) do
      :gt -> :ok
      :eq -> {:halt, :already_at_target}
      :lt -> Mix.raise("Refusing to downgrade Sigra from #{source} to #{target}.")
    end
  end

  # ── Plan ─────────────────────────────────────────────────────────

  defp build_plan(opts, source, target) do
    %{
      source: source,
      target: target,
      files: files_to_emit(opts),
      injections: injections_to_apply(target),
      migrations: migrations_to_emit(opts)
    }
  end

  defp files_to_emit(_opts), do: []

  defp injections_to_apply(target_version) do
    [version_sentinel_injection(target_version)]
  end

  defp migrations_to_emit(opts) do
    # BLOCKER 1 fix: organizations table may not exist in a --no-organizations
    # v1.0 install. Emit ALTER migrations ONLY when the host has an organizations
    # table. Detect by introspecting priv/repo/migrations/ for a create_organizations
    # migration file (cheap, pre-Ecto-connect, works in dry-run).
    base =
      if organizations_table_present?() do
        [
          {"alter_add_owner_user_id.exs", "add_owner_user_id_to_organizations.exs"},
          {"alter_add_personal.exs", "add_personal_to_organizations.exs"}
        ]
      else
        []
      end

    # Data migration shim only when backfill flag is passed AND orgs are enabled.
    # Backfill against a non-existent table is a hard error.
    if Keyword.get(opts, :backfill_personal_orgs, false) and organizations_table_present?() do
      base ++ [{"data_migration.exs", "backfill_personal_orgs.exs"}]
    else
      base
    end
  end

  # BLOCKER 1: zero-org detection. Checks priv/repo/migrations/ for any file
  # whose body creates the :organizations table. Cheap, pre-Ecto-connect.
  defp organizations_table_present? do
    migrations_dir = Path.join(["priv", "repo", "migrations"])

    if File.dir?(migrations_dir) do
      migrations_dir
      |> File.ls!()
      |> Enum.any?(fn filename ->
        path = Path.join(migrations_dir, filename)
        File.regular?(path) and String.contains?(File.read!(path), "create table(:organizations")
      end)
    else
      false
    end
  end

  defp version_sentinel_injection(target_version) do
    %Injection{
      target: Path.join(["config", "config.exs"]),
      marker: "config :sigra, :schema_version",
      anchor: :elixir_config,
      content: """

      # Sigra schema version — managed by `mix sigra.upgrade`. Do not edit manually.
      config :sigra, :schema_version, "#{target_version}"
      """
    }
  end

  # ── Interactive confirmation ─────────────────────────────────────

  defp maybe_confirm(_plan, opts) do
    if Keyword.get(opts, :yes, false) or Keyword.get(opts, :dry_run, false) do
      :ok
    else
      print_plan(_plan = %{files: [], migrations: [], injections: []})

      if Mix.shell().yes?("Proceed with upgrade?") do
        :ok
      else
        System.halt(0)
      end
    end
  end

  defp print_plan(plan) do
    Mix.shell().info("""
    Sigra upgrade plan:
      Files:      #{length(plan.files)}
      Migrations: #{length(plan.migrations)}
      Injections: #{length(plan.injections)}
    """)
  end

  # ── Apply ────────────────────────────────────────────────────────

  defp apply_plan(plan, opts) do
    if Keyword.get(opts, :dry_run, false) do
      Mix.shell().info("[DRY RUN] Would apply: #{inspect(plan)}")
      :ok
    else
      Enum.each(plan.injections, &Injector.apply(&1, cwd: File.cwd!()))
      emit_migrations(plan.migrations, opts)
      print_summary(plan)
      :ok
    end
  end

  defp emit_migrations(migrations, _opts) do
    # Walker that reads each upgrade template from priv/templates/sigra.upgrade/,
    # EEx.eval with the current binding, and writes into priv/repo/migrations/
    # (schema ALTERs) or priv/repo/data_migrations/ (data_migration.exs).
    #
    # For schema ALTER templates → priv/repo/migrations/
    # For data_migration.exs   → priv/repo/data_migrations/
    #
    # Use `Sigra.Install.Runner` helpers where possible; if the Runner is too
    # install-specific, inline a minimal walker here.
    Enum.each(migrations, fn {template, output_name} ->
      write_migration(template, output_name)
    end)
  end

  defp write_migration(template, output_name) do
    dest_dir =
      if template == "data_migration.exs" do
        Path.join(["priv", "repo", "data_migrations"])
      else
        Path.join(["priv", "repo", "migrations"])
      end

    File.mkdir_p!(dest_dir)
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    dest = Path.join(dest_dir, "#{timestamp}_#{output_name}")

    template_path = Path.join([:code.priv_dir(:sigra), "templates", "sigra.upgrade", template])
    binding = upgrade_binding()

    content = EEx.eval_file(template_path, binding)
    File.write!(dest, content)
    Mix.shell().info("* creating #{dest}")
  end

  defp upgrade_binding do
    # Minimal binding reusing the install binding shape. Host-app detection
    # mirrors Mix.Tasks.Sigra.Install.build_binding/4 essentials.
    base = Mix.Phoenix.base()
    otp_app = Mix.Phoenix.otp_app()
    repo = repo_module(otp_app)

    [
      # BLOCKER/WARNING 7: match install build_binding/4 precedent — bare module atom,
      # not inspect/1. Templates interpolate `<%= repo_module %>` which for a bare
      # module atom renders as `MyApp.Repo` (correct), whereas inspect/1 would render
      # as `MyApp.Repo` for simple modules but add stray quotes for quoted atoms. Match
      # install precedent exactly.
      repo_module: repo,
      context_module: inspect(Module.concat([base, "Accounts"])),
      schema_alias: "User",
      table_name: "users",
      binary_id: true
    ]
  end

  defp repo_module(otp_app) do
    case Application.get_env(otp_app, :ecto_repos, []) do
      [repo | _] -> repo
      [] -> Module.concat([Mix.Phoenix.base(), "Repo"])
    end
  end

  defp print_summary(plan) do
    Mix.shell().info("""

    Applied:
      ✓ Created #{length(plan.files)} files
      ✓ Applied #{length(plan.injections)} injections
      ✓ Generated #{length(plan.migrations)} migrations

    Pending:
      → Run: mix ecto.migrate

    Next steps:
      📖 See: https://hexdocs.pm/sigra/upgrade-v1.1.html
    """)
  end
end
```

**Notes for the executor:**
- `repo_module` binding uses a bare module atom (e.g. `MyApp.Repo`); do NOT wrap in `inspect/1`. Templates interpolate it as a bare module name via `<%= repo_module %>` — matching the `lib/mix/tasks/sigra.install.ex` `build_binding/4` precedent.
- The `upgrade_binding/0` helper is deliberately minimal; Plan 18-03's test fixture can extend it if additional fields become needed.
- Do NOT make this module depend on any file that Plan 18-01 already created — depends_on chains are wave-level, not file-level.
- `Injector.apply/2` is the existing Sigra.Install.Injector function — reuse it verbatim for the sentinel injection.
- If `Injector.apply/2` has a different signature than `apply(injection, opts)`, adapt the call but do not refactor the Injector itself.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors && grep -c "defmodule Sigra.Upgrade do" lib/sigra/upgrade.ex</automated>
  </verify>
  <acceptance_criteria>
    - `lib/sigra/upgrade.ex` exists
    - `grep -c "defmodule Sigra.Upgrade do" lib/sigra/upgrade.ex` returns 1
    - `grep -c "def run(opts)" lib/sigra/upgrade.ex` returns 1
    - `grep -c "check_git_dirty" lib/sigra/upgrade.ex` returns ≥ 2 (definition + call)
    - `grep -c "git.*status.*porcelain" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "Version.compare" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "Refusing to downgrade" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "config :sigra, :schema_version" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "Mix.shell().yes?" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "priv/repo/data_migrations" lib/sigra/upgrade.ex` returns ≥ 1
    - `grep -c "Applied:" lib/sigra/upgrade.ex` returns 1
    - `grep -c "Pending:" lib/sigra/upgrade.ex` returns 1
    - `grep -c "Next steps:" lib/sigra/upgrade.ex` returns 1
    - `mix compile --warnings-as-errors` exits 0
    - `mix format --check-formatted lib/sigra/upgrade.ex` exits 0
    - `mix credo --strict lib/sigra/upgrade.ex` exits 0
    - **BLOCKER 1 / Warning 7 regression coverage (NEW):** unit test `test "migrations_to_emit/1 returns empty list when priv/repo/migrations has no create_organizations migration"` — create a tmp dir with empty `priv/repo/migrations/`, cd there, call `Sigra.Upgrade.run/1` with a stub that captures plan, assert `plan.migrations == []`. Second assertion: same tmp with a file `priv/repo/migrations/20250101000000_create_organizations.exs` containing `create table(:organizations` → `plan.migrations` has the two ALTER entries.
    - **INFO 8 regression coverage (NEW):** unit test `test "detect_versions/1 defaults source to 1.0.0 when :schema_version config key is absent"` — call `Application.delete_env(:sigra, :schema_version)` first, then assert `Sigra.Upgrade.run/1` proceeds without raising and does NOT treat the missing sentinel as an error. Post-run, `Application.get_env(:sigra, :schema_version)` via the injected config line must match the target version (grep the generated config.exs fragment for `config :sigra, :schema_version, "1.1.0"` — use `inspect/1` of the current `:sigra` vsn as target).
    - **BLOCKER 3 / Q5 regression coverage (NEW):** unit test or integration test for `Sigra.Install.Injection` `:elixir_config` anchor fallback on a `config/config.exs` that has NO `import_config` line — assert the injection appends cleanly and the resulting file is valid Elixir (`Code.string_to_quoted!/1` on the file contents succeeds).
    - **WARNING 7 regression coverage (NEW):** after `mix sigra.upgrade` runs in a tmp app, `File.read!` of the generated `priv/repo/migrations/<timestamp>_add_owner_user_id_to_organizations.exs` file contains the bare substring `defmodule MyApp.Repo.Migrations.AddOwnerUserIdToOrganizations do` (no stray quotes around the module name — verifies `repo_module` binding uses a bare atom, not `inspect/1`).
  </acceptance_criteria>
  <done>`Sigra.Upgrade` module compiles, has all four pipeline stages (git check, version detect, plan, apply), writes a version sentinel injection + migration templates, emits ALTERs ONLY when organizations table is present, and defaults source version to `"1.0.0"` when the sentinel is absent.</done>
</task>

<task type="auto">
  <name>Task 4: Create Mix.Tasks.Sigra.Upgrade task with NimbleOptions schema + delegate to Sigra.Upgrade.run/1</name>
  <files>lib/mix/tasks/sigra.upgrade.ex</files>
  <read_first>
    - lib/mix/tasks/sigra.install.ex (full file — mirror the Mix.Task skeleton)
    - lib/sigra/upgrade.ex (the module this task delegates to — from Task 3)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-08, CD-01
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md sections `lib/mix/tasks/sigra.upgrade.ex` and Pattern C (NimbleOptions)
  </read_first>
  <action>
Create `lib/mix/tasks/sigra.upgrade.ex`:

```elixir
defmodule Mix.Tasks.Sigra.Upgrade do
  @shortdoc "Upgrades a Sigra-installed app to the current library version"

  @moduledoc """
  Upgrades a Sigra-installed app from an older version to the current version.

  ## Usage

      mix sigra.upgrade [--yes] [--dry-run] [--allow-dirty]
                        [--backfill-personal-orgs] [--from VERSION]

  ## Flags

    * `--yes` — skip interactive prompts. **Required for CI.**
    * `--dry-run` — print the plan without writing anything.
    * `--allow-dirty` — bypass the dirty-git-tree check.
    * `--backfill-personal-orgs` — generate the personal-org data migration
      (Phase 18 D-02).
    * `--from VERSION` — override auto-detected source version (from
      `config :sigra, :schema_version`). Useful for partial rollbacks.

  ## Example

      mix sigra.upgrade --backfill-personal-orgs --yes

  ## Telemetry

  Backfill emits `[:sigra, :upgrade, :backfill, :batch]` per batch.
  See `Sigra.Upgrade.Backfill` moduledoc for measurement keys.
  """

  use Mix.Task

  @options_schema [
    yes: [type: :boolean, default: false, doc: "Skip interactive prompts (required for CI)."],
    dry_run: [type: :boolean, default: false, doc: "Print plan without writing."],
    allow_dirty: [type: :boolean, default: false, doc: "Bypass dirty-git-tree refusal."],
    backfill_personal_orgs: [
      type: :boolean,
      default: false,
      doc: "Generate personal-org backfill data migration (Phase 18 D-02)."
    ],
    from: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Override auto-detected source version."
    ]
  ]

  @switches Enum.map(@options_schema, fn
    {key, spec} ->
      type =
        case spec[:type] do
          :boolean -> :boolean
          {:or, _} -> :string
          _ -> :string
        end

      {key, type}
  end)

  @impl Mix.Task
  def run(args) do
    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    validated = NimbleOptions.validate!(opts, @options_schema)
    Sigra.Upgrade.run(validated)
  end
end
```

**Flag alias note:** OptionParser converts `--backfill-personal-orgs` to `:backfill_personal_orgs` automatically (kebab → snake). No explicit alias needed.

**OptionParser type note:** NimbleOptions' `{:or, [:string, nil]}` validates the _value_; OptionParser's `:string` switches type accepts the CLI string. The conversion in `@switches` above maps NimbleOptions types to OptionParser types — simple and explicit.
  </action>
  <verify>
    <automated>mix help sigra.upgrade</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mix/tasks/sigra.upgrade.ex` exists
    - `grep -c "defmodule Mix.Tasks.Sigra.Upgrade do" lib/mix/tasks/sigra.upgrade.ex` returns 1
    - `grep -c "use Mix.Task" lib/mix/tasks/sigra.upgrade.ex` returns 1
    - `grep -c "@shortdoc" lib/mix/tasks/sigra.upgrade.ex` returns 1
    - `grep -c "NimbleOptions.validate!" lib/mix/tasks/sigra.upgrade.ex` returns 1
    - `grep -c "Sigra.Upgrade.run" lib/mix/tasks/sigra.upgrade.ex` returns 1
    - `grep -c "backfill_personal_orgs" lib/mix/tasks/sigra.upgrade.ex` returns ≥ 1
    - `grep -c "allow_dirty" lib/mix/tasks/sigra.upgrade.ex` returns ≥ 1
    - `mix compile --warnings-as-errors` exits 0
    - `mix help sigra.upgrade` succeeds and prints the module docstring (verifies the task is discoverable)
    - `mix format --check-formatted lib/mix/tasks/sigra.upgrade.ex` exits 0
    - `mix credo --strict lib/mix/tasks/sigra.upgrade.ex` exits 0
  </acceptance_criteria>
  <done>`mix sigra.upgrade` is a discoverable, NimbleOptions-validated task that delegates to `Sigra.Upgrade.run/1`.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CLI → Mix task | User-supplied flags flow through OptionParser → NimbleOptions → `Sigra.Upgrade.run/1`. |
| Host repo → backfill library | Host-app schemas (users, orgs) are passed as atoms; library executes queries with host Repo. |
| Generated data migration → library | The 10-line shim calls `Sigra.Upgrade.Backfill.run_personal_orgs/2` with options — library must validate. |
| Git working tree → upgrade task | `git status --porcelain` output determines whether to proceed. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-06 | Tampering | Host supplies malicious `:users_schema` atom | mitigate | NimbleOptions `:atom` validator + Ecto query will fail at compile time if the atom is not a schema module. No arbitrary code execution path from the options. |
| T-18-07 | Denial of Service | Long-running backfill holds pg_advisory_lock | mitigate | `@disable_ddl_transaction true` and `@disable_migration_lock true` in the generated data_migration.exs template (verified in Task 2 acceptance criteria). |
| T-18-08 | Repudiation | Upgrade applied without audit trail | accept | Sigra's audit plumbing (Phase 15) is for user-facing actions, not ops tasks. `mix sigra.upgrade` is a developer action, logged via Mix.shell stdout + git commit of the generated migrations. Host apps that require ops auditing can observe the `[:sigra, :upgrade, :backfill, :*]` telemetry events. |
| T-18-09 | Elevation of Privilege | Backfill creates orgs on behalf of users without consent | accept | Explicit opt-in via `--backfill-personal-orgs` flag. Matches Phase 16 D-08 contract (no auto-personal-org). Documented in `mix help sigra.upgrade`. |
| T-18-10 | Information Disclosure | Personal-org slug leaks user email | mitigate | Slug is `"user-#{user.id}"`, which is an opaque UUID. Email is never interpolated into the slug. Backfill test in Task 1 asserts slug format. |
| T-18-11 | Tampering | Dirty git working tree hides bad upgrade diff | mitigate | Default refusal via `git status --porcelain`; `--allow-dirty` escape hatch is explicit opt-in. |
| T-18-12 | Elevation of Privilege | Downgrade allows older code to write to newer schema | mitigate | `ensure_upgrade_direction/2` calls `Version.compare/2` and `Mix.raise`es on `:lt`. |
</threat_model>

<verification>
- `lib/sigra/upgrade/backfill.ex` exists with keyset pagination, `on_conflict: :nothing`, partial unique index conflict target, NimbleOptions validation, per-batch telemetry
- `test/sigra/upgrade/backfill_test.exs` has ≥ 8 passing AAA tests covering happy path, idempotency, skip existing, name fallback chain, telemetry emission, keyset pagination, NimbleOptions errors
- `priv/templates/sigra.upgrade/data_migration.exs` has both `@disable_ddl_transaction true` and `@disable_migration_lock true` and calls `Sigra.Upgrade.Backfill.run_personal_orgs`
- `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` + `alter_add_personal.exs` exist and use `add_if_not_exists` + `create_if_not_exists` for idempotency
- `lib/sigra/upgrade.ex` contains git dirty check, version compare, version sentinel injection with marker `config :sigra, :schema_version`, three-section summary
- `lib/mix/tasks/sigra.upgrade.ex` is discoverable via `mix help sigra.upgrade` and delegates to `Sigra.Upgrade.run/1` after NimbleOptions validation
- `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, and `mix test test/sigra/upgrade/` all pass
</verification>

<success_criteria>
1. `mix help sigra.upgrade` prints the task module docs (discovery).
2. `mix sigra.upgrade --dry-run --yes` in a tmp app prints the plan without writing (no files created under `priv/repo/*migrations*`).
3. `mix sigra.upgrade --yes` in a tmp app writes exactly 2 schema ALTER migrations + 1 config injection, then prints the three-section summary.
4. `mix sigra.upgrade --backfill-personal-orgs --yes` additionally writes a data migration shim under `priv/repo/data_migrations/`.
5. `mix test test/sigra/upgrade/backfill_test.exs` passes with ≥ 8 tests covering idempotency, telemetry, keyset, and fallback name chain.
6. Attempting `mix sigra.upgrade --yes` on a dirty git tree raises with the message starting `Refusing to run`.
</success_criteria>

## Risks & Mitigations

**Scope heads-up (WARNING 6):** This plan is scope-heavy (4 tasks, 5 created + 2 modified files). Not required to split, but executor SHOULD consider requesting a checkpoint / interrupt after Task 1 (Backfill library) for quality review before proceeding to Task 3 (Upgrade orchestrator). Tasks 1 and 3 are the two highest-complexity tasks; landing Task 1 cleanly in isolation reduces blast radius if Task 3 needs revision.

**BLOCKER 1 reconciliation:** Plan 18-03 Task 2 installs with `--no-organizations` (per D-06), so this plan's upgrade task MUST detect the missing organizations table at plan-build time and emit zero ALTER migrations in that case. See Task 3 updated `migrations_to_emit/1` + `organizations_table_present?/0` helper. The ALTER templates themselves use `add_if_not_exists` / `create_if_not_exists` so they are idempotent no-ops when re-run against a schema that already has the columns (the org-enabled upgrade path).

<output>
After completion, create `.planning/phases/18-backfill-organizations-generator-wiring/18-02-SUMMARY.md` following `$HOME/.claude/get-shit-done/templates/summary.md`.
</output>
