# Phase 18: Backfill + `--organizations` Generator Wiring — Pattern Map

**Mapped:** 2026-04-14
**Files analyzed:** 16 (2 templates modified, 6 net-new templates, 3 library modules new, 2 library modules modified, 1 Mix task new, 1 test fixture modified, 1 net-new test, 1 CI workflow modified)
**Analogs found:** 14 / 16 (2 files are net-new surfaces with no direct analog; covered by "No analog found" section)

## Orientation

Phase 18 is a **greenfield upgrade surface** built on top of the **existing Phase 11 feature manifest walker**. 95 % of the Mix task logic and binding plumbing for `mix sigra.upgrade` is a direct mirror of `mix sigra.install`; the net-new library surface is ~200–400 LOC of backfill code. Every template file already has a sibling in `priv/templates/sigra.install/organizations/` whose EEx shape + binary_id handling + adapter branching pattern should be copied literally.

## File Classification

### Wave 1 — Plan 18-01 (Foundation: schema + flag plumbing)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/organizations/migration.exs` (MODIFY) | EEx migration template | CRUD / schema migration | Self (add to existing file) | exact (same file) |
| `priv/templates/sigra.install/organizations/organization.ex` (MODIFY) | EEx schema template | CRUD / schema field | Self (add field to existing schema) | exact (same file) |
| `lib/mix/tasks/sigra.install.ex` (MODIFY) | Mix task dispatcher | request-response | Self (add switch + binding key) | exact (same file) |
| `lib/sigra/install/features/organizations.ex` (MODIFY) | Feature behaviour impl | manifest | Self + `Sigra.Install.Features.Core` | exact (same shape) |
| `lib/sigra/organizations.ex` (MODIFY — `create_organization/3`) | Context module | CRUD | Self (existing function, add `owner_user_id` set) | exact (same function) |
| Generated `Accounts.Auth` context EEx template (if any call-site to `select_active_organization/3` from generated code exists) | EEx controller/context template | request-response | `deps/phoenix/priv/templates/phx.gen.auth/auth.ex` line 165 (`<%= if live? do %>` inline conditional) | role-match (prior art) |

### Wave 2 — Plan 18-02 (Upgrade task + backfill library)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/sigra.upgrade.ex` (NEW) | Mix task dispatcher | request-response | `lib/mix/tasks/sigra.install.ex` | exact (walker caller shape) |
| `lib/sigra/upgrade.ex` (NEW) | Upgrade orchestrator API | batch + transform | `lib/sigra/install/runner.ex` | role-match (walker over features) |
| `lib/sigra/upgrade/backfill.ex` (NEW — `run_personal_orgs/2`) | Library service | batch / keyset pagination | `lib/sigra/organizations.ex` `list_organizations_with_roles_for_user/2` (Ecto query idiom) + no existing batching analog | partial (net-new batching pattern) |
| `priv/templates/sigra.upgrade/data_migration.exs` (NEW) | EEx migration-shim template | batch invocation | `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` (simplest Ecto.Migration template) | role-match |
| `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` (NEW) | EEx ALTER migration template | schema migration | `priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` | exact (ALTER-shape sibling) |
| `priv/templates/sigra.upgrade/alter_add_personal.exs` (NEW) | EEx ALTER migration template | schema migration | Same as above | exact |
| Version sentinel injection in `config/config.exs` | Host-owned file injection | config | `Sigra.Install.Features.Core.config_injection/4` (line 469) | exact |

### Wave 2 — Plan 18-03 (Boot fixture + CI matrix)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/support/install_fixture.ex` (MODIFY — add `run_sigra_install/2`, `run_sigra_upgrade/2`) | Test support | file-I/O + subprocess | Self (`setup_tmp_app/1`) | exact (same file) |
| `test/upgrade_test.exs` (NEW) | Integration test | file-I/O + subprocess | `test/sigra/install/golden_diff_test.exs` | role-match (tmp-app fixture test) |
| `.github/workflows/ci.yml` (MODIFY — add `install_matrix` job) | CI config | event-driven | `install_smoke` job (lines 104–149 of the same file) | exact |

---

## Pattern Assignments

### `priv/templates/sigra.install/organizations/migration.exs` (MODIFY — add `owner_user_id` + `personal` + partial unique index)

**Analog:** Self (lines 3–99 already contain the `create table(:organizations ...)` Postgres branch).

**Pattern to follow — add into the Postgres branch's `create table(:organizations ...)` block, mirroring the existing `add :name`, `add :slug` lines:**

```eex
create table(:organizations<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :name, :string, null: false, size: 255
      add :slug, :citext, null: false
      add :deleted_at, :utc_datetime
      # D-00: sticky origin owner (added Phase 18). Write-once; :nilify_all on user delete.
      add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      # D-01: personal-workspace flag (added Phase 18). Sticky origin, not current state.
      add :personal, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end
```

**Partial unique index — mirror the existing `organizations_slug_active_index` shape at lines 17–20:**

```eex
# D-01: at-most-one-personal-org-per-user (doubles as D-03 insert-safety backstop).
create unique_index(:organizations, [:owner_user_id],
  where: "personal = true",
  name: :organizations_personal_owner_uidx
)
```

**MySQL/SQLite branch:** mirror the existing non-partial-index fallback at line 114. `personal` column is always emitted; partial unique index falls back to a composite `(owner_user_id, personal)` unique index or app-level enforcement per Phase 12 precedent.

---

### `priv/templates/sigra.install/organizations/organization.ex` (MODIFY — add `belongs_to :owner` + `personal` field)

**Analog:** Self (lines 18–27).

**Pattern to follow — add field + belongs_to to the `schema "organizations"` block:**

```eex
  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :deleted_at, :utc_datetime
    field :personal, :boolean, default: false

    belongs_to :owner, <%= context_module %>.<%= schema_alias %>, foreign_key: :owner_user_id

    has_many :memberships, <%= context_module %>.OrganizationMembership
    has_many :invitations, <%= context_module %>.OrganizationInvitation

    timestamps(type: :utc_datetime)
  end
```

**Changeset note:** `owner_user_id` is write-once and NOT exposed via `cast/3` — `create_organization/3` writes it explicitly via `put_change/3`, never via user attrs. `personal` is similarly NOT exposed via cast in the generated changeset (library sets it, not host code).

---

### `lib/mix/tasks/sigra.install.ex` (MODIFY — register `Features.Organizations`, add `organizations: :boolean` switch, forward `organizations?` in binding)

**Analog:** Self. Three surgical edits against the existing file (lib/mix/tasks/sigra.install.ex lines 35, 37–44, 88–118).

**Edit 1 — `@features` list (line 35):**

```elixir
@features [Sigra.Install.Features.Core, Sigra.Install.Features.Organizations]
```

**Edit 2 — `@switches` (lines 37–44) — add `organizations: :boolean`:**

```elixir
@switches [
  live: :boolean,
  binary_id: :boolean,
  table: :string,
  api: :boolean,
  jwt: :boolean,
  organizations: :boolean,
  yes: :boolean
]
```

**Edit 3 — `build_binding/4` binding kw list (lines 96–117) — add `organizations?`:**

```elixir
organizations?: Keyword.get(opts, :organizations, true),
```

The binding key flows through `Runner.run_files/3` line 81 (`EEx.eval_file(template_path, binding)`) and becomes `@organizations?` inside any `.eex` template. `Features.Organizations.enabled?/1` already reads `Keyword.get(opts, :organizations, true)` at line 37 — no changes needed there; the feature is filtered out before `files/1`/`migrations/1`/`injections/1` are ever called (see `Runner.run/3` line 53).

---

### `lib/sigra/install/features/organizations.ex` (MODIFY — verify `migrations/1` includes both new slots)

**Analog:** Self (line 111). Current shape is `[{:organizations, ..., "create_organizations.exs"}]`.

**Pattern to follow — extend with the two new upgrade-side ALTER slots (for the upgrade codepath only; fresh-install bakes `owner_user_id`/`personal` into `migration.exs` directly):**

```elixir
@impl true
def migrations(_binding) do
  [
    {:organizations, "organizations/migration.exs", "create_organizations.exs"}
    # Note: alter_add_owner_user_id / alter_add_personal are upgrade-only slots
    # emitted by mix sigra.upgrade, NOT by mix sigra.install. Fresh installs
    # get owner_user_id + personal via the create_organizations migration
    # template directly.
  ]
end
```

The upgrade task emits alters through a parallel list in `Sigra.Upgrade` (see Wave 2 pattern).

---

### `lib/sigra/organizations.ex` `create_organization/3` (MODIFY — set `owner_user_id`)

**Analog:** Self (line 370 `create_organization/3`). Current shape uses `Multi.insert` → `Multi.insert(:membership, ...)`.

**Pattern to follow — set `owner_user_id` on the org changeset before insert:**

```elixir
def create_organization(config, scope, attrs) do
  org_schema = config.schemas.organization
  membership_schema = config.schemas.membership

  changeset =
    org_schema
    |> build_org_changeset(attrs, config)
    |> Ecto.Changeset.put_change(:owner_user_id, scope.user.id)
  # ... existing Multi.new() pipeline unchanged
```

`put_change/2` (not `cast/3`) — keeps `owner_user_id` structurally unreachable from user attrs; changeset audit invariants stay intact.

---

### `lib/mix/tasks/sigra.upgrade.ex` (NEW)

**Analog:** `lib/mix/tasks/sigra.install.ex` — copy the module skeleton, swap walker target.

**Imports pattern (copy verbatim from analog lines 31–33):**

```elixir
defmodule Mix.Tasks.Sigra.Upgrade do
  @moduledoc """..."""
  @shortdoc "Upgrades a Sigra-installed app to the current library version"

  use Mix.Task

  alias Sigra.Upgrade
```

**Switch list (NimbleOptions-validated, per CLAUDE.md stack):** unlike `sigra.install` which uses raw `OptionParser`, this task uses `NimbleOptions` — see `lib/sigra/organizations.ex` lines 38–200 for the schema-definition idiom and line 222 (`NimbleOptions.validate!(opts, @org_config_schema)`) for the validation call site.

```elixir
@options_schema [
  yes: [type: :boolean, default: false, doc: "Skip interactive prompts (required for CI)."],
  dry_run: [type: :boolean, default: false, doc: "Print plan without writing."],
  allow_dirty: [type: :boolean, default: false, doc: "Bypass dirty-git-tree refusal."],
  backfill_personal_orgs: [type: :boolean, default: false, doc: "Generate personal-org backfill data migration."],
  from: [type: {:or, [:string, nil]}, default: nil, doc: "Override auto-detected source version."]
]
```

**Run/1 skeleton — mirror `sigra.install.ex` lines 47–68 but delegate to `Sigra.Upgrade`:**

```elixir
@impl true
def run(args) do
  {opts, _parsed, _} = OptionParser.parse(args, switches: switches_from_schema(@options_schema))
  opts = NimbleOptions.validate!(opts, @options_schema)

  Sigra.Upgrade.run(opts)
end
```

**Interactive confirmation pattern (from CONTEXT.md D-08):** `Mix.shell().yes?(prompt) || System.halt(0)`.

---

### `lib/sigra/upgrade.ex` (NEW — task orchestrator API)

**Analog:** `lib/sigra/install/runner.ex` — the walker shape. But `Upgrade.run/1` does MORE than Runner: dirty-git check, version detection, plan computation, optional backfill dispatch, three-section stdout summary.

**Core walker pattern (from `Runner.run/3` lines 52–69):**

```elixir
# NEW: Sigra.Upgrade.run/1 reuses Sigra.Install.Runner for the file-emission
# subset. This avoids duplicating run_files/run_injections/run_post_instructions.
def run(opts) do
  with :ok <- check_git_dirty(opts),
       {:ok, source, target} <- detect_versions(opts),
       :ok <- ensure_upgrade_direction(source, target),
       plan <- build_plan(opts, source, target),
       :ok <- maybe_confirm(plan, opts) do
    apply_plan(plan, opts)
  end
end
```

**Git dirty-tree check idiom (from RESEARCH.md "Don't Hand-Roll" table):**

```elixir
defp check_git_dirty(%{allow_dirty: true}), do: :ok
defp check_git_dirty(_opts) do
  case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
    {"", 0} -> :ok
    {_dirty, 0} -> Mix.raise("Refusing to run on dirty working tree. Pass --allow-dirty to override.")
    {_, _} -> :ok  # not a git repo — skip check
  end
end
```

**Version detection (CD-03 decision — sentinel in `config/config.exs`):**

```elixir
defp detect_versions(opts) do
  source = opts[:from] || Application.get_env(:sigra, :schema_version, "1.0.0")
  target = Application.spec(:sigra, :vsn) |> to_string()
  {:ok, source, target}
end

defp ensure_upgrade_direction(source, target) do
  case Version.compare(target, source) do
    :gt -> :ok
    :eq -> {:halt, :already_at_target}
    :lt -> Mix.raise("Refusing to downgrade from #{source} to #{target}")
  end
end
```

**Three-section stdout output** — `Mix.shell().info/1` once per section, matching `Runner.run_post_instructions/3` at line 120 (one `info` call per logical chunk).

---

### `lib/sigra/upgrade/backfill.ex` (NEW — `run_personal_orgs/2`)

**Analog:** No existing batching code in the library. Closest Ecto-query shape is `lib/sigra/organizations.ex` (import `Ecto.Query`, `from u in schema, ...`).

**Imports pattern — mirror `lib/sigra/organizations.ex` lines 32–36:**

```elixir
defmodule Sigra.Upgrade.Backfill do
  @moduledoc """
  Library-resident backfill logic for `mix sigra.upgrade --backfill-personal-orgs`.

  Thin proxy target for the data-migration shim generated into the host
  app's `priv/repo/data_migrations/`. All batching, logging, telemetry,
  and SQL logic lives here so fixes ship via `mix deps.update`.
  """

  import Ecto.Query
```

**Core pattern — keyset `NOT EXISTS` selector + `Repo.insert_all/3` + telemetry (from RESEARCH.md Pattern 3 lines 216–229):**

```elixir
def run_personal_orgs(repo, opts \\ []) do
  batch_size = Keyword.get(opts, :batch_size, 1_000)
  config = resolve_config(opts)
  users_schema = config.schemas.user
  orgs_schema = config.schemas.organization

  do_batch(repo, users_schema, orgs_schema, batch_size, 0, 0)
end

defp do_batch(repo, users_schema, orgs_schema, batch_size, last_cursor, batch_index) do
  query =
    from u in users_schema,
      as: :u,
      where: u.id > ^last_cursor,
      where: not exists(
        from o in ^orgs_schema,
          where: o.owner_user_id == parent_as(:u).id and o.personal == true
      ),
      order_by: u.id,
      limit: ^batch_size

  case repo.all(query) do
    [] ->
      :ok

    users ->
      rows = Enum.map(users, &build_personal_org_row/1)

      {inserted, _} =
        repo.insert_all(orgs_schema, rows,
          on_conflict: :nothing,
          conflict_target: {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}
        )

      :telemetry.execute(
        [:sigra, :upgrade, :backfill, :batch],
        %{batch_index: batch_index, batch_size: length(users), inserted: inserted},
        %{}
      )

      next_cursor = users |> List.last() |> Map.fetch!(:id)
      do_batch(repo, users_schema, orgs_schema, batch_size, next_cursor, batch_index + 1)
  end
end
```

**Name + slug generation (D-04):**

```elixir
defp build_personal_org_row(user) do
  now = DateTime.utc_now() |> DateTime.truncate(:second)
  display =
    cond do
      user.display_name not in [nil, ""] -> user.display_name
      is_binary(user.email) and String.contains?(user.email, "@") ->
        user.email |> String.split("@") |> List.first()
      true -> "Personal"
    end

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
```

---

### `priv/templates/sigra.upgrade/data_migration.exs` (NEW — 5-line shim)

**Analog:** `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` (simplest Ecto.Migration template in the tree).

**Full template content (copy-shape; Dashbit data-migration pattern with concurrent-safety flags per RESEARCH.md Pattern 1 lines 178–194):**

```eex
defmodule <%= repo_module %>.DataMigrations.BackfillPersonalOrgs do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    Sigra.Upgrade.Backfill.run_personal_orgs(repo(), batch_size: 1_000)
  end

  def down, do: :ok
end
```

---

### `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs` + `alter_add_personal.exs` (NEW)

**Analog:** `priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` — the canonical ALTER template in the tree (already used by `Features.Core` migration slot `:audit_events_org_columns` at `features/core.ex` line 93).

**Pattern to follow — standard `alter table/2 do ... end` with `binary_id`-aware references:**

```eex
defmodule <%= repo_module %>.Migrations.AddOwnerUserIdToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
    end

    # Backfill origin owner from earliest :owner membership (small N — no batching).
    execute("""
    UPDATE organizations o SET owner_user_id = (
      SELECT m.user_id FROM organization_memberships m
      WHERE m.organization_id = o.id AND m.role = 'owner'
      ORDER BY m.inserted_at ASC LIMIT 1
    ) WHERE owner_user_id IS NULL
    """, "")
  end
end
```

`add_personal` migration is the same shape without the UPDATE (default `false`).

---

### Version sentinel injection (new `Sigra.Install.Injection`) in `config/config.exs`

**Analog:** `lib/sigra/install/features/core.ex` line 469 `config_injection/4`.

**Full pattern (copy shape verbatim — same `target`, same `anchor: :elixir_config`, new `marker`):**

```elixir
defp version_sentinel_injection do
  target_version = Application.spec(:sigra, :vsn) |> to_string()

  content = """

  # Sigra schema version — managed by `mix sigra.upgrade`. Do not edit manually.
  config :sigra, :schema_version, "#{target_version}"
  """

  %Sigra.Install.Injection{
    target: Path.join(["config", "config.exs"]),
    marker: "config :sigra, :schema_version",
    anchor: :elixir_config,
    content: content
  }
end
```

Upgrade-time: injection is idempotent via marker match. To BUMP the version on an existing sentinel, the planner needs a second "rewrite matched line" operation — see `lib/sigra/install/injector.ex` for the anchor handlers. Simplest path: extend Injector with a `:replace_marker_line` mode OR do a direct `File.read!/File.write!` rewrite inside `Sigra.Upgrade` (skip the injector for the bump-in-place case).

---

### `test/support/install_fixture.ex` (MODIFY — add `run_sigra_install/2`, `run_sigra_upgrade/2`)

**Analog:** Self (`setup_tmp_app/1` lines 40–107).

**Pattern to follow — factor the `mix sigra.install` subprocess block (lines 88–99) into a standalone function, then add a parallel `run_sigra_upgrade/2`:**

```elixir
@doc "Run `mix sigra.install` in an already-prepared tmp app with the given flags."
def run_sigra_install(app_dir, flags) when is_list(flags) do
  args = ["sigra.install", "Accounts", "User", "users"] ++ flags ++ ["--yes"]

  {out, status} =
    System.cmd("mix", args,
      cd: app_dir,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0, do: raise("mix sigra.install #{inspect(flags)} failed:\n#{out}")
  {:ok, out}
end

@doc "Run `mix sigra.upgrade` in a tmp app. Mirror of run_sigra_install/2."
def run_sigra_upgrade(app_dir, flags) when is_list(flags) do
  args = ["sigra.upgrade"] ++ flags ++ ["--yes"]

  {out, status} =
    System.cmd("mix", args,
      cd: app_dir,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0, do: raise("mix sigra.upgrade #{inspect(flags)} failed:\n#{out}")
  {:ok, out}
end
```

**`setup_tmp_app/1` refactor:** replace its inline install block (lines 88–99) with a call to the new `run_sigra_install/2` so the existing golden-diff test keeps working byte-identically.

---

### `test/upgrade_test.exs` (NEW)

**Analog:** `test/sigra/install/golden_diff_test.exs` lines 1–50 (tmp-app-fixture-based integration test shape).

**Imports + setup pattern (copy verbatim):**

```elixir
defmodule Sigra.UpgradeTest do
  @moduledoc """
  Phase 18 D-06: semantic-equivalence upgrade regression test.
  `mix sigra.install --no-organizations` is the v1.0 state by definition.
  """
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :upgrade
  @moduletag timeout: 300_000
```

**Core test pattern — two-path upgrade flow, mirrors CONTEXT.md D-06 steps 1–6:**

```elixir
describe "mix sigra.upgrade" do
  test "backfill-off: login still works, users land on zero-org page" do
    {:ok, %{app_dir: app_dir}} = InstallFixture.setup_tmp_app(app_name: "upgrade_no_backfill")
    # setup_tmp_app now runs sigra.install with the default install flags;
    # we need --no-organizations for v1.0-shape, so use the lower-level helpers:
    {:ok, _} = InstallFixture.run_sigra_install(app_dir, ["--no-organizations"])
    seed_users!(app_dir, 5)
    migrate!(app_dir)

    {:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])

    assert upgrade_out =~ "Applied"
    # assert compile + ecto.migrate succeed; no users have personal orgs yet.
  end

  test "backfill-on: every user gets a personal org; rerun is no-op" do
    # Parallel flow with --backfill-personal-orgs
  end
end
```

---

### `.github/workflows/ci.yml` (MODIFY — add `install_matrix` job)

**Analog:** `install_smoke` job (lines 104–149 of the same file).

**Pattern to follow — copy the `install_smoke` job skeleton verbatim, add `strategy.matrix.flags`, replace the final `run:` with a matrix-parameterized install invocation:**

```yaml
install_matrix:
  name: Install matrix (flag combinations)
  runs-on: ubuntu-latest
  strategy:
    fail-fast: false
    matrix:
      flags:
        - ""
        - "--no-organizations"
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      ports: ['5432:5432']
      options: >-
        --health-cmd pg_isready --health-interval 10s
        --health-timeout 5s --health-retries 5
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4.3.1
    - uses: erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93  # v1.24.0
      with:
        version-file: .tool-versions
        version-type: strict
    - name: Install Hex + Rebar
      run: |
        mix local.hex --force
        mix local.rebar --force
    - name: Install phx_new archive
      run: mix archive.install --force hex phx_new
    - name: Fetch Sigra library deps
      run: mix deps.get
    - name: Scaffold fresh Phoenix app
      run: mix phx.new tmp_app --no-assets --no-mailer --no-install
    - name: Patch in-tree sigra as path dep
      run: |
        # mirror InstallFixture.patch_mix_exs_with_path_dep! shape
        ...
    - name: Run sigra.install with matrix flags
      working-directory: tmp_app
      run: mix sigra.install Accounts User users ${{ matrix.flags }} --yes
    - name: Compile + migrate + test
      working-directory: tmp_app
      env:
        PGUSER: postgres
        PGPASSWORD: postgres
        PGHOST: localhost
      run: |
        mix deps.get
        mix compile --warnings-as-errors
        mix ecto.create && mix ecto.migrate
        mix test
```

**Matrix shape is a list-of-flag-strings** (D-07) — Phase 19+ appends `"--no-passkeys"`, `"--no-organizations --no-passkeys"` without restructuring.

---

## Shared Patterns

### Pattern A: Feature manifest gating (file-level + binding-level)

**Source:** `lib/sigra/install/features/organizations.ex` (`enabled?/1` at line 37) + `lib/sigra/install/runner.ex` line 53 (`Enum.filter(features, fn f -> f.enabled?(opts) end)`).

**Apply to:** All generator-flag bifurcation decisions. The feature-enablement check happens upstream in the runner — **feature callbacks do NOT need internal `if enabled?` guards**. This is critical for D-05 mechanism 2 (whole-file omission).

### Pattern B: `<%= if flag do %> ... <% end %>` inline EEx conditional

**Source:** `deps/phoenix/priv/templates/phx.gen.auth/auth.ex` line 165.

```eex
<%= if live? do %>defp put_token_in_session(conn, token) do
  conn
  |> put_session(:<%= schema.singular %>_token, token)
  |> put_session(:live_socket_id, <%= schema.singular %>_session_topic(token))
end
<% end %>
```

**Apply to:** D-05 mechanism 1 — small gated blocks (≤20 lines, ≤2 nesting levels) within otherwise-shared `core/` templates. Binding key `organizations?` is propagated via `build_binding/4` in `sigra.install.ex`.

**IMPORTANT research finding:** A grep of `priv/templates/sigra.install/core/` for `Sigra.Organizations`, `select_active_organization`, and `active_organization_id` returned only a docstring hit in `organization_invitation_email.ex` (line 31). The `select_active_organization/3` call lives in `lib/sigra/auth.ex` line 1126 — **library-side, always compiled**. This means the **inline EEx conditional surface is near-empty** under the current codebase state: whole-file omission via `Features.Organizations.files/1 = []` already carries ~100% of the bifurcation. Plan 18-01 should verify this with a fresh grep and ONLY add inline conditionals if a new call-site is introduced in `core/` templates. This is the **"library is always compiled"** invariant from CONTEXT.md's "no library forking" coherence check.

### Pattern C: `NimbleOptions.validate!/2` schema-driven option surfaces

**Source:** `lib/sigra/organizations.ex` lines 38–200 (schema definition) + line 222 (validation call).

```elixir
@schema [
  batch_size: [type: :pos_integer, default: 1_000, doc: "..."],
  yes: [type: :boolean, default: false, doc: "..."]
]

def run(opts) do
  validated = NimbleOptions.validate!(opts, @schema)
  ...
end
```

**Apply to:** `Mix.Tasks.Sigra.Upgrade` options, `Sigra.Upgrade.Backfill.run_personal_orgs/2` options. Free `--help` text and validation errors at parse time. CLAUDE.md stack-mandated.

### Pattern D: `%Sigra.Install.Injection{}` with marker idempotency

**Source:** `lib/sigra/install/features/core.ex` line 485 (`config_injection/4`).

```elixir
%Injection{
  target: Path.join(["config", "config.exs"]),
  marker: "# Sigra authentication",
  anchor: :elixir_config,
  content: content
}
```

**Apply to:** Version sentinel injection (Plan 18-02). Marker-based idempotency via `Sigra.Install.Injector.apply/2` gives GEN-04 re-run safety for free. Anchors: `:before_last_end`, `:elixir_config`, `:after_use_block`, `:at_top` (see `lib/sigra/install/injection.ex` line 32).

### Pattern E: Subprocess-in-tmp-app test fixture

**Source:** `test/support/install_fixture.ex` `setup_tmp_app/1` lines 40–107.

- `System.tmp_dir!() <> "/sigra_xxx_<unique_int>"` for isolation
- `mix phx.new --no-assets --no-mailer --no-install`
- Patch mix.exs with `{:sigra, path: sigra_repo_root, override: true}`
- `mix deps.get` + `mix compile` (pre-warm)
- `mix sigra.install ... --yes` (capture stdout)
- Helper raises with full stdout on non-zero status

**Apply to:** `test/upgrade_test.exs` (Plan 18-03) and the new `run_sigra_install/2` / `run_sigra_upgrade/2` helpers.

---

## No Analog Found

These net-new surfaces have no close match in the codebase (planner should lean on RESEARCH.md and external references):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/sigra/upgrade/backfill.ex` batching loop | service | batch / keyset pagination | No existing batching code in `lib/`. Pattern source: RESEARCH.md Pattern 3 (keyset `NOT EXISTS`), Dashbit blog on data migrations, Tyler Young's Elixir backfill microframework, Shopify `maintenance_tasks` (cited in research). |
| `Ecto.Migrator.with_repo/2` + `Ecto.Migrator.run/4` against `priv/repo/data_migrations` | migration orchestrator | batch invocation | No existing usage of the custom-path `Ecto.Migrator.run/4` form in the codebase. Pattern source: RESEARCH.md Pattern 2, `hexdocs.pm/ecto_sql/Ecto.Migrator.html`, Dashbit blog. |

For both files the planner should:
1. Follow RESEARCH.md's concrete code snippets literally (they're descriptive but very close to the final shape).
2. Place these in the new `lib/sigra/upgrade/` subtree (mirroring `lib/sigra/install/`).
3. Add property-style tests mimicking `test/sigra/install/idempotency_test.exs` to prove the "re-run is no-op" contract from D-03.

---

## Key Integration Nuances (flagged for planner)

1. **`Features.Organizations` is NOT currently in `@features`** (`lib/mix/tasks/sigra.install.ex` line 35 still reads `[Sigra.Install.Features.Core]`). Plan 18-01 MUST add it. Without this edit, the `--no-organizations` flag is inert because the organizations feature is never wired in at all (RESEARCH.md gap #1).

2. **No `Sigra.Upgrade.*` namespace exists on disk.** RESEARCH.md gap #4: `Sigra.Upgrade.Backfill.run_personal_orgs/2` is aspirational in CONTEXT.md. Plan 18-02 creates the entire namespace.

3. **`select_active_organization/3` lives in `lib/sigra/auth.ex` line 1126** — library-side, always compiled, never in templates. This MATERIALLY reduces the inline-EEx conditional surface that CONTEXT.md D-05 implies. Planner should verify with a fresh `grep -r "Sigra\.Organizations" priv/templates/sigra.install/core/` before writing any `<%= if @organizations? do %>` wrappers.

4. **`Runner.run/3` filters features at line 53 before any callback invocation.** Feature modules do NOT need internal enabled-checks in `files/1`/`migrations/1`/`injections/1`. This is a clean contract — don't violate it.

5. **`Features.Organizations.migrations/1` at line 111 currently returns a single slot** (`:organizations`). The upgrade-side alter migrations (owner_user_id, personal) should NOT be added to this list — they're upgrade-only and the fresh-install `migration.exs` template already bakes those columns in per Plan 18-01. Emitting them through the feature manifest would cause duplicate ALTER attempts on fresh installs.

6. **Refactoring `setup_tmp_app/1` for the new test fixture must preserve byte-identity with `golden_diff_test.exs`.** The default-flags path (no `--no-organizations`) must produce the exact same stdout + tree as before or the golden fixture test will fail. Safest: add new helpers (`run_sigra_install/2`, `run_sigra_upgrade/2`) WITHOUT editing `setup_tmp_app/1`'s existing inline install block (the copy-paste cost is minimal).

## Metadata

**Analog search scope:** `lib/mix/tasks/`, `lib/sigra/install/`, `lib/sigra/organizations.ex`, `lib/sigra/auth.ex`, `priv/templates/sigra.install/`, `test/support/`, `test/sigra/install/`, `.github/workflows/`, `deps/phoenix/priv/templates/phx.gen.auth/`
**Files scanned (analog candidates):** ~40
**Pattern extraction date:** 2026-04-14
