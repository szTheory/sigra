---
phase: 18-backfill-organizations-generator-wiring
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/templates/sigra.install/organizations/migration.exs
  - priv/templates/sigra.install/organizations/organization.ex
  - lib/mix/tasks/sigra.install.ex
  - lib/sigra/install/features/organizations.ex
  - lib/sigra/organizations.ex
autonomous: true
requirements: [ORG-02]
tags: [organizations, generator, schema, migration]
must_haves:
  truths:
    - "mix sigra.install --no-organizations runs without error and emits zero files under a generated organizations/ subtree"
    - "mix sigra.install (default, org-enabled) generates a create_organizations migration that contains owner_user_id and personal columns plus the organizations_personal_owner_uidx partial unique index"
    - "Generated Organization schema exposes field :personal, :boolean, default: false and belongs_to :owner with foreign_key: :owner_user_id"
    - "Sigra.Install.Features.Organizations is registered in Mix.Tasks.Sigra.Install @features so --no-organizations is a real gate, not a no-op"
    - "Fresh install (no upgrade path) bakes owner_user_id + personal into the create_organizations migration directly — NOT via alter migrations"
  artifacts:
    - path: "priv/templates/sigra.install/organizations/migration.exs"
      provides: "owner_user_id + personal + partial unique index baked into fresh install"
      contains: "owner_user_id"
    - path: "priv/templates/sigra.install/organizations/organization.ex"
      provides: "personal field + owner belongs_to on schema template"
      contains: "field :personal"
    - path: "lib/mix/tasks/sigra.install.ex"
      provides: "Features.Organizations registered + organizations switch + organizations? binding"
      contains: "organizations: :boolean"
    - path: "lib/sigra/organizations.ex"
      provides: "create_organization/3 writes owner_user_id via put_change"
      contains: "put_change(:owner_user_id"
  key_links:
    - from: "lib/mix/tasks/sigra.install.ex @features"
      to: "Sigra.Install.Features.Organizations"
      via: "feature walker in Runner.run/3"
      pattern: "Sigra\\.Install\\.Features\\.Organizations"
    - from: "lib/mix/tasks/sigra.install.ex build_binding/4"
      to: "EEx templates"
      via: "@organizations? binding key"
      pattern: "organizations\\?:"
---

<objective>
Bake the personal-workspace schema shape (owner_user_id + personal column + partial unique index) directly into the fresh-install organizations migration template and schema template, register `Features.Organizations` in the install task so `--no-organizations` is a real gate, forward an `organizations?` binding to EEx templates, and make `Sigra.Organizations.create_organization/3` write `owner_user_id` on insert so fresh installs always have a sticky origin owner.

Purpose: Unlocks ORG-02 (true `--no-organizations` opt-out) and is the foundation prerequisite for Plan 18-02 (upgrade task can only ALTER columns into a v1.0 shape if the fresh-install template already knows about them and the schema is consistent).

Output: Fresh `mix sigra.install` emits the full personal-org schema; `mix sigra.install --no-organizations` emits zero org files; `Features.Organizations` is a live filter entry.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-RESEARCH.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md
@lib/mix/tasks/sigra.install.ex
@lib/sigra/install/features/organizations.ex
@lib/sigra/install/runner.ex
@lib/sigra/organizations.ex
@priv/templates/sigra.install/organizations/migration.exs
@priv/templates/sigra.install/organizations/organization.ex

<interfaces>
<!-- Extracted from lib/sigra/install/feature.ex and runner.ex — executor should use directly -->

Sigra.Install.Feature behaviour:
```elixir
@callback enabled?(opts :: keyword()) :: boolean()
@callback files(binding :: keyword()) :: [{atom(), String.t(), String.t()}]
@callback migrations(binding :: keyword()) :: [{atom(), String.t(), String.t()}]
@callback injections(binding :: keyword()) :: [Sigra.Install.Injection.t()]
@callback post_instructions(binding :: keyword(), report :: map()) :: [String.t()]
```

Sigra.Install.Features.Organizations.enabled?/1 (current, line 37):
```elixir
def enabled?(opts), do: Keyword.get(opts, :organizations, true)
```
— already correct; do NOT modify.

Sigra.Install.Runner.run/3 filters features:
```elixir
features |> Enum.filter(& &1.enabled?(opts))
```
— this is why Plan 18-01 Task 3 only needs to register the module in @features and
forward the flag through build_binding; no internal enabled-check is needed inside
the feature callbacks.

Sigra.Organizations.create_organization signature (current):
```elixir
def create_organization(config, scope, attrs)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Bake owner_user_id + personal + partial unique index into the fresh-install organizations migration template (both adapter branches)</name>
  <files>priv/templates/sigra.install/organizations/migration.exs</files>
  <read_first>
    - priv/templates/sigra.install/organizations/migration.exs (full file — both postgres and mysql/sqlite branches)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md sections D-00, D-01
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for `priv/templates/sigra.install/organizations/migration.exs`
  </read_first>
  <action>
Edit `priv/templates/sigra.install/organizations/migration.exs` in BOTH adapter branches (postgres branch starting line 3, and the `<% else %>` mysql/sqlite branch starting line 100).

**Postgres branch — inside `create table(:organizations ...)` block (after `add :deleted_at, :utc_datetime`, before `timestamps`):**

```eex
      add :deleted_at, :utc_datetime
      # D-00: sticky origin owner (added Phase 18). Write-once on insert; :nilify_all so the org row survives owner account deletion.
      add :owner_user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      # D-01: personal-workspace flag (added Phase 18). Sticky origin, NOT current state — a personal org stays `personal: true` even after inviting others.
      add :personal, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
```

**Postgres branch — immediately AFTER the existing `organizations_slug_active_index` unique_index block (after line 20 in current file), ADD:**

```eex
    # D-01 / D-03: at-most-one-personal-org-per-user. Structural invariant AND
    # insert-safety backstop for Sigra.Upgrade.Backfill (Plan 18-02). Postgres
    # partial unique index — one row per owner_user_id where personal = true.
    create unique_index(:organizations, [:owner_user_id],
      where: "personal = true",
      name: :organizations_personal_owner_uidx
    )

```

**MySQL/SQLite branch (`<% else %>` branch, ~line 100 onward) — inside the `create table(:organizations ...)` block add the same two `add` lines (owner_user_id + personal) mirroring the postgres shape.**

**MySQL/SQLite branch — AFTER `create unique_index(:organizations, [:slug])`, ADD a composite non-partial unique fallback:**

```eex
    # D-01: MySQL/SQLite lack partial unique indexes. Application-level guard
    # in Sigra.Organizations enforces at-most-one-personal-org-per-user;
    # this composite index provides a best-effort structural hint.
    create unique_index(:organizations, [:owner_user_id, :personal],
      name: :organizations_personal_owner_uidx
    )

```

Do NOT touch `organization_memberships`, `organization_invitations`, or `organization_slug_aliases` sections.
  </action>
  <verify>
    <automated>grep -c "owner_user_id" priv/templates/sigra.install/organizations/migration.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "add :owner_user_id, references" priv/templates/sigra.install/organizations/migration.exs` returns ≥ 2 (one per adapter branch)
    - `grep -c "add :personal, :boolean, null: false, default: false" priv/templates/sigra.install/organizations/migration.exs` returns ≥ 2
    - `grep -c "organizations_personal_owner_uidx" priv/templates/sigra.install/organizations/migration.exs` returns ≥ 2
    - `grep -c "where: \"personal = true\"" priv/templates/sigra.install/organizations/migration.exs` returns ≥ 1 (postgres-only)
    - `grep -c "on_delete: :nilify_all" priv/templates/sigra.install/organizations/migration.exs` returns ≥ 2 (owner_user_id lines; existing invitation `nilify_all` references push this higher — that is fine)
    - File still parses as valid EEx: `mix compile` exits 0 (templates are not compiled, but ensure no stray `<%` tokens break downstream EEx.eval)
    - `mix test test/sigra/install/ --include golden` still passes (golden diff test may need a regenerate if it snapshots the organizations migration — if it fails, update the golden fixture in the same commit with a note "Phase 18: owner_user_id + personal columns added")
  </acceptance_criteria>
  <done>Both adapter branches of `migration.exs` contain owner_user_id + personal + the `organizations_personal_owner_uidx` index; postgres gets the partial form, mysql/sqlite gets the composite fallback.</done>
</task>

<task type="auto">
  <name>Task 2: Add personal field + belongs_to :owner to the Organization schema template</name>
  <files>priv/templates/sigra.install/organizations/organization.ex</files>
  <read_first>
    - priv/templates/sigra.install/organizations/organization.ex (full file)
    - lib/sigra/organizations.ex (see how the library Organization schema is shaped, if one exists)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for organization.ex
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-00, D-01
  </read_first>
  <action>
Edit `priv/templates/sigra.install/organizations/organization.ex` to add `field :personal, :boolean, default: false` and `belongs_to :owner, ...` inside the `schema "organizations"` block.

Target shape for the schema block (adapt to existing alias / table_name EEx variables in the file):

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

**Changeset rule (MANDATORY):** Do NOT add `:personal` or `:owner_user_id` to any `cast/3` call in the changeset. These fields are set by library code (Plan 18-01 Task 4 and Plan 18-02 backfill), never by host attrs. Audit the existing `changeset/2` — if `:personal` or `:owner_user_id` appear in the cast list, remove them.

If the template uses a different existing `belongs_to` naming convention (e.g., the file already declares `has_many :users` or similar), keep this plan's `belongs_to :owner` distinct — owner is a single user pointer, not a collection.
  </action>
  <verify>
    <automated>grep -c "field :personal" priv/templates/sigra.install/organizations/organization.ex</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "field :personal, :boolean, default: false" priv/templates/sigra.install/organizations/organization.ex` returns ≥ 1
    - `grep -c "belongs_to :owner" priv/templates/sigra.install/organizations/organization.ex` returns ≥ 1
    - `grep -c "foreign_key: :owner_user_id" priv/templates/sigra.install/organizations/organization.ex` returns ≥ 1
    - `grep -n "cast(.*:personal" priv/templates/sigra.install/organizations/organization.ex` returns no matches (the field must not be in a cast list)
    - `grep -n "cast(.*:owner_user_id" priv/templates/sigra.install/organizations/organization.ex` returns no matches
  </acceptance_criteria>
  <done>Schema template has `:personal` field + `:owner` belongs_to; neither is exposed via `cast/3`.</done>
</task>

<task type="auto">
  <name>Task 3: Register Features.Organizations in @features, add --organizations switch, forward organizations? binding</name>
  <files>lib/mix/tasks/sigra.install.ex, lib/sigra/install/features/organizations.ex</files>
  <read_first>
    - lib/mix/tasks/sigra.install.ex (full file — focus on lines 35, 37–44, 45, 88–118)
    - lib/sigra/install/features/organizations.ex (full file — especially enabled?/1 at line 37 and migrations/1 at line 111)
    - lib/sigra/install/runner.ex (line 53 — feature filter)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md "Key Integration Nuances" 1, 4, 5
  </read_first>
  <action>
Three surgical edits in `lib/mix/tasks/sigra.install.ex`:

**Edit 1 — line 35 `@features`:**
```elixir
@features [Sigra.Install.Features.Core, Sigra.Install.Features.Organizations]
```

**Edit 2 — `@switches` (line 37–44), add `organizations: :boolean`:**
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

**Edit 3 — `@default_opts` (line 45), add organizations default true:**
```elixir
@default_opts [live: true, api: false, jwt: false, binary_id: true, organizations: true]
```

**Edit 4 — `build_binding/4` return kw list (between lines 96–117), add:**
```elixir
organizations?: Keyword.get(opts, :organizations, true),
```
Insert the line immediately after the `jwt:` line (~line 112) to keep related flags grouped.

**Verify `Sigra.Install.Features.Organizations.migrations/1`** (line ~111 in `lib/sigra/install/features/organizations.ex`) currently returns a list containing ONLY the `:organizations` slot pointing to `organizations/migration.exs → create_organizations.exs`. Do NOT add upgrade-only ALTER slots here — fresh installs bake owner_user_id and personal directly into the create_organizations migration (Task 1). Adding ALTER slots here would cause double-apply on fresh installs. If the current `migrations/1` list already contains only the single slot, make no edits. If additional slots exist, leave them; do NOT add new ones in this task.
  </action>
  <verify>
    <automated>grep -c "Sigra.Install.Features.Organizations" lib/mix/tasks/sigra.install.ex && grep -c "organizations: :boolean" lib/mix/tasks/sigra.install.ex && grep -c "organizations?:" lib/mix/tasks/sigra.install.ex</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "Sigra.Install.Features.Organizations" lib/mix/tasks/sigra.install.ex` returns ≥ 1
    - `grep -c "organizations: :boolean" lib/mix/tasks/sigra.install.ex` returns ≥ 1
    - `grep -c "organizations: true" lib/mix/tasks/sigra.install.ex` returns ≥ 1 (in @default_opts)
    - `grep -c "organizations?: Keyword.get(opts, :organizations, true)" lib/mix/tasks/sigra.install.ex` returns ≥ 1
    - `mix compile --warnings-as-errors` exits 0
    - `mix format --check-formatted lib/mix/tasks/sigra.install.ex` exits 0
    - `mix test test/sigra/install/` passes (confirms no regression in existing install tests)
  </acceptance_criteria>
  <done>`--no-organizations` is a real gate filtered at `Runner.run/3` line 53; `@organizations?` is available inside every EEx template binding.</done>
</task>

<task type="auto">
  <name>Task 4: Audit core templates for ungated Sigra.Organizations references + wire create_organization/3 to set owner_user_id</name>
  <files>lib/sigra/organizations.ex, priv/templates/sigra.install/core/ (audit-only; edit ONLY if a reference is found)</files>
  <read_first>
    - lib/sigra/organizations.ex (full file — especially `create_organization/3` at line ~370)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md "Key Integration Nuances" #3 (the near-empty conditional surface finding)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for `lib/sigra/organizations.ex` create_organization/3
    - lib/sigra/auth.ex line 1126 context (select_active_organization call-site lives in library, not templates)
  </read_first>
  <action>
**Step A — audit `priv/templates/sigra.install/core/` for ungated org references.**

Run a fresh grep:
```bash
grep -rn "Sigra\.Organizations\|select_active_organization\|active_organization_id" priv/templates/sigra.install/core/
```

Expected outcome (per PATTERNS.md note #3): only a docstring hit in `organization_invitation_email.ex` — docstrings are fine, no action needed.

**For EACH unexpected match** (live code referencing `Sigra.Organizations.*` in a core template), wrap the smallest enclosing block in:
```eex
<%= if @organizations? do %>
...existing call...
<% end %>
```
Keep conditionals ≤20 lines and ≤2 nesting levels per D-05 mechanism 1. If a call-site exceeds that, surface the finding in the task log and split into a helper rather than nesting deeper.

**If the grep returns ONLY docstring hits, do nothing in core/ templates — move to Step B.**

**Step B — wire `Sigra.Organizations.create_organization/3` to set `owner_user_id` via `put_change/3`.**

Locate `create_organization/3` (approximately line 370 in `lib/sigra/organizations.ex`). Before the `Ecto.Multi` pipeline inserts the organization, update the changeset to set `owner_user_id` from `scope.user.id` via `Ecto.Changeset.put_change/3`.

Exact edit shape (adapt to current local variable names — the current code uses `changeset = build_org_changeset(...)` or similar):

```elixir
def create_organization(config, scope, attrs) do
  org_schema = config.schemas.organization
  membership_schema = config.schemas.membership

  changeset =
    org_schema
    |> struct(%{})
    |> build_org_changeset(attrs, config)
    |> Ecto.Changeset.put_change(:owner_user_id, scope.user.id)

  # ... existing Ecto.Multi pipeline unchanged
end
```

**Rules:**
- Use `put_change/3`, NEVER `cast/3` — owner_user_id must be structurally unreachable from host-supplied attrs (audit invariant).
- Do NOT set `:personal` here. `:personal` stays `false` for team orgs created via this path. The library/generator code path that creates personal orgs is Plan 18-02's `Sigra.Upgrade.Backfill.run_personal_orgs/2`, which uses `Repo.insert_all` directly and bypasses this changeset.
- If `scope.user` is nil (edge case), raise with `ArgumentError, "create_organization/3 requires a scope with a loaded user"`. Do NOT silently default owner_user_id to nil — that would leave a team org with no origin owner.

**Step C — add a unit test** in `test/sigra/organizations_test.exs` (append to existing file) asserting:
1. `create_organization/3` with a valid scope produces an org with `owner_user_id == scope.user.id`.
2. `create_organization/3` with `scope.user == nil` raises `ArgumentError`.
3. The resulting org has `personal: false`.
  </action>
  <verify>
    <automated>mix test test/sigra/organizations_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `grep -rn "Sigra\\.Organizations\\|select_active_organization\\|active_organization_id" priv/templates/sigra.install/core/` returns only docstring matches OR all live matches are wrapped in `<%= if @organizations? do %>` blocks
    - `grep -c "put_change(:owner_user_id" lib/sigra/organizations.ex` returns ≥ 1
    - `grep -c "cast(.*:owner_user_id" lib/sigra/organizations.ex` returns 0 (never via cast)
    - `mix test test/sigra/organizations_test.exs` exits 0
    - New test names contain "owner_user_id" and "ArgumentError" (grep-verifiable: `grep -c "owner_user_id" test/sigra/organizations_test.exs` increases by ≥ 3 from pre-edit baseline)
    - `mix compile --warnings-as-errors` exits 0
    - `mix format --check-formatted lib/sigra/organizations.ex test/sigra/organizations_test.exs` exits 0
    - `mix credo --strict lib/sigra/organizations.ex` exits 0
  </acceptance_criteria>
  <done>Core templates are verified free of ungated org references (or minimally wrapped if found). `Sigra.Organizations.create_organization/3` writes owner_user_id via put_change, with unit tests locking the invariant.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| host app → library | Host passes `scope` (potentially with user-controlled `scope.user`) to `create_organization/3`. Library must not trust host code to pre-populate `owner_user_id`. |
| generator flag → template binding | `--organizations` flag from user CLI input flows through `build_binding/4` into EEx templates; template binding must not inject raw user strings into executable code. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-01 | Tampering | `create_organization/3` owner_user_id write | mitigate | Use `put_change/3` not `cast/3`. Changeset rejects any host-supplied `:owner_user_id` in attrs; unit test in Task 4 asserts host attrs cannot override owner_user_id. |
| T-18-02 | Elevation of Privilege | personal-org uniqueness | mitigate | Partial unique index `organizations_personal_owner_uidx` on postgres structurally enforces at-most-one-personal-org-per-user. Composite fallback on mysql/sqlite; application-level guard in library. |
| T-18-03 | Denial of Service | Migration template EEx injection via `--organizations` flag | accept | Switch is boolean (`:boolean` type in OptionParser). Non-boolean inputs are rejected at parse time. No user-controlled strings reach EEx. |
| T-18-04 | Information Disclosure | Personal org slug exposes user PII | mitigate | Plan 18-02 uses `"user-#{user.id}"` slug format (opaque, no email leak) per D-04. Plan 18-01 establishes the schema shape; slug generation is enforced in the backfill library (Plan 18-02). |
| T-18-05 | Repudiation | Org creation missing owner attribution | mitigate | owner_user_id is NOT NULL-constrained by FK presence AND validated in-library (raise if scope.user is nil). Audit events continue to carry `user_id` via existing audit plumbing. |
</threat_model>

<verification>
- Both adapter branches of `priv/templates/sigra.install/organizations/migration.exs` contain `owner_user_id` + `personal` + `organizations_personal_owner_uidx`
- `priv/templates/sigra.install/organizations/organization.ex` has `field :personal` + `belongs_to :owner` and neither is in any `cast` list
- `lib/mix/tasks/sigra.install.ex` registers `Sigra.Install.Features.Organizations` in `@features`, has `organizations: :boolean` in `@switches`, `organizations: true` in `@default_opts`, and forwards `organizations?:` in `build_binding/4`
- `lib/sigra/organizations.ex` `create_organization/3` writes `owner_user_id` via `put_change/3`; raises `ArgumentError` when `scope.user` is nil
- Audit of `priv/templates/sigra.install/core/` for `Sigra.Organizations` returns only docstring hits (or any live hits are wrapped in `<%= if @organizations? do %>`)
- `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, and `mix test` all pass
</verification>

<success_criteria>
1. `mix sigra.install Accounts User users --no-organizations --yes` in a tmp app produces ZERO files under `lib/my_app/organizations/`, `lib/my_app_web/live/organizations*`, and no `create_organizations.exs` migration (validated structurally by Plan 18-03's CI matrix).
2. `mix sigra.install Accounts User users --yes` (default) produces a `create_organizations.exs` migration that contains both `owner_user_id` and `personal` column adds plus the partial unique index (postgres) / composite fallback (mysql/sqlite).
3. `mix sigra.install --no-organizations --yes` followed by `mix compile --warnings-as-errors` succeeds with no `Sigra.Organizations.*` undefined-function warnings (library stays always-compiled; generated code has no calls into it).
4. `Sigra.Organizations.create_organization/3` unit tests assert owner_user_id is set from scope.user.id and cannot be overridden via attrs.
</success_criteria>

<output>
After completion, create `.planning/phases/18-backfill-organizations-generator-wiring/18-01-SUMMARY.md` following `$HOME/.claude/get-shit-done/templates/summary.md`.
</output>
