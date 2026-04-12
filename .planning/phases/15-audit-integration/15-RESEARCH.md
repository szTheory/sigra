# Phase 15: Audit Integration - Research

**Researched:** 2026-04-12
**Domain:** Elixir/Phoenix audit logging — column extension, library API shape, mechanical sweep, behaviour contracts, custom Credo checks
**Confidence:** HIGH (every claim below was verified against the working tree or cited official docs; no claims rely on training-data alone)

## Summary

Phase 15's research job is implementation-level mechanics, not re-deciding anything. Every D-XX in CONTEXT.md is locked. This document fills in the unknowns the planner needs to chunk three plans (15-01 mechanical sweep + helper, 15-02 semantic enrichment + worker behaviour, 15-03 generator wiring) and write VALIDATION.md.

The biggest research surprise is that **`lib/sigra/workers.ex` does not yet exist** — Phase 15 creates it. Likewise, **`.credo.exs` does not exist** in the repo today — the custom check ships alongside its first config file. Both facts shape Plan 15-02's wave structure. The good news: every other dependency the phase touches (test audit schema, `Sigra.Testing` module, `Sigra.Audit.Query` reduce pattern, adapter-branched migration EEx convention, `Features.Core.migrations/1` slot list, `assert_audit_event/2` precedent) already exists with the exact shape Phase 15 needs.

The 79-site sweep number from CONTEXT.md is **exactly current** as of 2026-04-12 (verified per-file via `grep -rEn`). 67 sites use the fully-qualified `Sigra.Audit.log_safe(` form; 12 use the aliased `Audit.log_safe(` form. The mechanical edit must handle both forms.

**Primary recommendation:** Plan 15-01 ships the helper + shim + mechanical-only sweep + Credo check + alter migration in a single reviewable diff. Plan 15-02 reorders `session.create`, builds `Sigra.Workers` behaviour from zero, refactors `AccountDeletion`, and replaces `nil` placeholders with real scopes at Category 1/2/3 sites. Plan 15-03 updates the audit_event template, the install golden fixture, the example app mirror, and CHANGELOG.

## User Constraints (from CONTEXT.md)

### Locked Decisions

All 31 decisions D-01..D-31 from `15-CONTEXT.md` are locked. The planner MUST NOT re-debate any of them. Highlights the planner most needs in front of them when chunking work:

- **D-01..D-08** — `Sigra.Audit.log_safe/3` API shape: `(action, scope_or_nil, opts)`, scope-second-arg, private `scope_fields/1` duck-typer, prepended-to-opts so caller-supplied keys win. `log_safe/2` shim delegates with `nil` scope. `log_multi/3` and `log_multi_safe/3` do NOT gain a scope arg.
- **D-09..D-17** — Migration strategy: frozen `create_audit_events.exs` + new standalone `alter_audit_events_add_org_columns.exs` migration with `@disable_ddl_transaction true`, `@disable_migration_lock true`, and `create index(..., concurrently: true)` on Postgres only. Single composite index `(:organization_id, :inserted_at)`. NO `effective_user_id` index in v1.1. FK `references(:organizations, type: :binary_id, on_delete: :nilify_all)`. Schema + Changeset gain both fields unconditionally. `Sigra.Audit.Query` gains three new filters with strict whitelist validation (raises on unknown keys — breaking change). `Query.for_scope/2` deferred. `# TODO(v1.2):` comment on `:including_global` clause.
- **D-18..D-24** — `Sigra.Workers` is `@behaviour Sigra.Workers`, no `use` macro, callback `perform(scope :: term() | nil, args :: map())`, fail-fast `new/3` validator, scope-from-args via `Sigra.Scope.build/3`, `AccountDeletion` is the reference refactor, `EmailDelivery` / `AuditCleanup` / `TokenCleanup` stay untouched (document opt-out in moduledoc).
- **D-25..D-31** — Three plans 15-01/15-02/15-03 (mechanical → semantic → generator). Failed-login uses `target_id: user.id`, `effective_user_id: nil`. `session.create` audit moves to AFTER `select_active_organization/3`. Pre-auth-with-resolved-user passes `Sigra.Scope.build(scope_module, user, active_organization: nil)`. Failed-login with unknown email logs IP+UA only — no email hash. `Sigra.Credo.NoLogSafe2InLib` enforces "one idiom in lib/". `assert_audit_logged/2` lands in `Sigra.Testing` per REQ DX-02.

### Claude's Discretion

- Exact wave boundaries inside Plan 15-01 / 15-02 / 15-03.
- Exact arg key names for `AccountDeletion` (`"scope_module"` vs `"scope"` vs other) provided retry-safety holds.
- ExUnit tag choices, fixture paths, test-helper internal structure.
- Whether the Credo check lives in `lib/sigra/credo/` or a test-only path — must run in CI.

### Deferred Ideas (OUT OF SCOPE)

- `Sigra.Audit.Query.for_scope/2` convenience — v1.2.
- `effective_user_id` composite index — v1.2 (column ships, index does not).
- `log_multi/3` / `log_multi_safe/3` scope support — v1.2 if admin UI needs it.
- Partial index / UNION rewrite for `:including_global` filter — v1.2.
- `Sigra.Workers` adoption for `EmailDelivery` / `AuditCleanup` / `TokenCleanup` — v1.2.
- Cloak-encrypted audit metadata — orthogonal.
- `--no-organizations` conditional for audit columns — columns always ship in v1.1.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUD-01 | Real indexed `organization_id :binary_id` column on `audit_events` (nullable, FK `nilify_all`) | §Migration template & adapter branching, §Changeset cast |
| AUD-02 | Real `effective_user_id :binary_id` column populated identically to `actor_id` in v1.1 | §Schema additions, §`scope_fields/1` shape (D-04) |
| AUD-03 | Single assembly point helper for audit metadata (Phase 15 implements as private `scope_fields/1` per D-05; the public single-entry-point per AUD-03's spirit is `log_safe/3` itself) | §`log_safe/3` shape, §`scope_fields/1` private helper |
| AUD-04 | `Sigra.Audit.Query` `:organization_id` filter backed by indexed column + index hit-count proof | §`Query.build` reduce pattern extension, §Validation Architecture (index-use proof) |
| AUD-05 | `Sigra.Workers` behaviour: workers accept `args["organization_id"]` + `args["actor_id"]`, reconstruct minimal scope, emit audits via the same helper | §`Sigra.Workers` is greenfield, §`Sigra.Scope.build/3`, §`AccountDeletion` reference refactor |

## Project Constraints (from CLAUDE.md)

- **Phoenix 1.8 / Ecto 3.x** as blessed path. The `(scope, ...)` argument convention follows Phoenix 1.8 scopes guide [CITED].
- **PostgreSQL primary, MySQL/SQLite via conditional migrations.** Phase 15 inherits the existing adapter-branching pattern: EEx `<%= if adapter == :postgres do %>` ... `<% end %>` blocks in migration templates [VERIFIED: `priv/templates/sigra.install/core/migration.exs:3`].
- **OWASP standards throughout.** Failed-login MUST NOT record actor as the claimed identity (D-26 / NIST 800-63B §5.2.2).
- **Minimal transitive deps.** Phase 15 adds zero new deps. Optional Oban dep stays optional via `Code.ensure_loaded?(Oban.Worker)` wrapping pattern.
- **Testing:** comprehensive coverage, AAA style, flat, self-contained.
- **GSD workflow enforcement:** all edits go through a GSD command; this research is the input to `/gsd-plan-phase 15`.
- **Sigra hybrid lib+generator:** security-critical code in `lib/`, customizable code in `priv/templates/`. Phase 15 respects this — the helper, behaviour, query filters, and Credo check live in `lib/`; the migration template + audit schema field additions ship through `priv/templates/`.

## Standard Stack

Phase 15 adds **zero new dependencies**. Everything builds on what's already in `mix.exs`:

| Library | Version (verified in repo) | Purpose | Source |
|---------|---------------------------|---------|--------|
| Ecto | ~> 3.12 | Migration DSL, `@disable_ddl_transaction`, `@disable_migration_lock`, `create index(..., concurrently: true)` | [Ecto.Migration docs](https://hexdocs.pm/ecto_sql/Ecto.Migration.html) [CITED] |
| Credo | ~> 1.7 | Custom check via `Credo.Check` behaviour | [Credo "Adding Checks"](https://hexdocs.pm/credo/adding_checks.html) [CITED] |
| Oban | ~> 2.17 (optional) | `Oban.Worker` for the AccountDeletion reference refactor; behaviour itself MUST NOT reference Oban | wrapped via `Code.ensure_loaded?` per existing pattern [VERIFIED: `lib/sigra/workers/account_deletion.ex:1`] |
| Telemetry | (transitive) | Existing `[:sigra, :audit, :log]` event passes through unchanged | [VERIFIED: `lib/sigra/audit.ex:30`] |

## Architecture Patterns

### Where Code Lives

```
lib/sigra/
├── audit.ex                    # ADD: log_safe/3, scope_fields/1; SHIM: log_safe/2
├── audit/
│   ├── changeset.ex            # EDIT: @cast_fields gains :organization_id, :effective_user_id
│   └── query.ex                # EDIT: 3 new filter clauses + remove silent catch-all
├── scope/
│   ├── hydration.ex            # untouched
│   └── build.ex                # NEW: Sigra.Scope.build/3 (per D-23)
├── workers.ex                  # NEW: @behaviour Sigra.Workers, new/3, perform contract
├── workers/
│   └── account_deletion.ex     # REFACTOR: implement @behaviour Sigra.Workers
├── credo/
│   └── no_log_safe_2_in_lib.ex # NEW: custom Credo check (D-30)
├── testing.ex                  # ADD: assert_audit_logged/2 (per D-31, REQ DX-02)
└── auth.ex                     # EDIT: reorder session.create audit (line 1016) per D-27

priv/templates/sigra.install/core/
├── create_audit_events.exs                          # FROZEN — D-09
├── alter_audit_events_add_org_columns.exs           # NEW — adapter-branched
└── audit_event.ex                                   # EDIT: 2 new field declarations

test/
├── support/audit_test_event.ex                      # EDIT: 2 new field declarations
├── sigra/audit_test.exs                             # EDIT: scope_fields/3 form coverage
├── sigra/audit_security_test.exs                    # EDIT: whitelist filter raise
└── fixtures/install_golden/tree/                    # REGENERATE: new migration file
```

### `Sigra.Audit.log_safe/3` shape (target after Phase 15)

```elixir
@spec log_safe(String.t(), nil | map() | struct(), opts()) :: :ok
def log_safe(action, scope, opts)
    when is_binary(action) and is_list(opts) do
  case Keyword.get(opts, :audit_schema) do
    nil ->
      :ok

    _schema ->
      # caller-supplied keys win on conflict (D-06)
      opts = scope_fields(scope) ++ opts
      # ... existing log_safe/2 body unchanged from here ...
  end
end

# Backwards-compat shim — the ONLY remaining arity-2 form, allowed by the
# Credo check via the `lib/sigra/audit.ex` exception list.
@spec log_safe(String.t(), opts()) :: :ok
def log_safe(action, opts) when is_binary(action) and is_list(opts) do
  log_safe(action, nil, opts)
end

# v1.1 shape — duck-types on common scope field names. v1.2 impersonation
# becomes a one-line edit on the effective_user_id assignment.
defp scope_fields(nil) do
  [organization_id: nil, effective_user_id: nil, actor_id: nil]
end

defp scope_fields(%{user: user, active_organization: org} = _scope) do
  [
    organization_id: org && org.id,
    effective_user_id: user && user.id,
    actor_id: user && user.id
  ]
end

defp scope_fields(_other) do
  # defensive: any scope-shaped thing without those keys → all nils,
  # never raises (audit must never break the caller)
  [organization_id: nil, effective_user_id: nil, actor_id: nil]
end
```

**Why prepend not merge (D-06):** `scope_fields(scope) ++ opts` — `Keyword.get/2` returns the FIRST match, so caller-supplied keys win without needing `Keyword.merge`. Verified zero existing call sites pass `:organization_id` or `:effective_user_id` (those columns don't exist yet), so the merge direction is safe to lock now.

### Migration template — adapter-branched

Phase 15 follows the **exact** EEx adapter-branching convention already used by `priv/templates/sigra.install/core/migration.exs` and `core/api_token_migration.exs` and `organizations/migration.exs`. The shape is:

```eex
defmodule <%= repo_module %>.Migrations.AlterAuditEventsAddOrgColumns do
  use Ecto.Migration

<%= if adapter == :postgres do %>
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    alter table(:audit_events) do
      add :organization_id,
          references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at], concurrently: true)
  end

  def down do
    drop index(:audit_events, [:organization_id, :inserted_at])

    alter table(:audit_events) do
      remove :effective_user_id
      remove :organization_id
    end
  end
<% end %><%= if adapter == :mysql do %>
  def change do
    alter table(:audit_events) do
      add :organization_id,
          references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at])
  end
<% end %><%= if adapter == :sqlite do %>
  def change do
    alter table(:audit_events) do
      add :organization_id,
          references(:organizations<%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :nilify_all)
      add :effective_user_id, :binary_id
    end

    create index(:audit_events, [:organization_id, :inserted_at])
  end
<% end %>
end
```

**Crucial facts the planner must know:**

1. The `adapter` binding is set in `lib/mix/tasks/sigra.install.ex:113` from `detect_adapter/1` (line 127), which calls `repo_module.__adapter__()`. It is always one of `:postgres`, `:mysql`, `:sqlite`. [VERIFIED]
2. **Only the Postgres branch uses `@disable_ddl_transaction true` + `@disable_migration_lock true` + `concurrently: true`.** SQLite and MySQL use plain `create index` inside a `change/0` (which Ecto can reverse). CONTEXT.md D-10 explicitly says "Planner must verify the Sigra adapter-branching system emits non-concurrent index creation for SQLite/MySQL — PostgreSQL-only syntax otherwise." Verified: the existing branching pattern handles this naturally.
3. **No `Sigra.Adapters` Elixir module exists** — branching happens entirely in EEx at template render time via the `adapter` binding. Searching for `Sigra.Adapters` in the source returns zero hits. [VERIFIED]
4. The new migration is registered in `Features.Core.migrations/1` between `:audit_events` and... actually, AFTER `:audit_events` (since it ALTERs the table the previous slot creates):
   ```elixir
   {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"},
   {:audit_events_org_columns,
    "core/alter_audit_events_add_org_columns.exs",
    "alter_audit_events_add_org_columns.exs"}
   ```
   And mirrored into `base_files/1` with the same `migration_target/3` call pattern Phase 12 used for `:active_org_column`. [VERIFIED: `lib/sigra/install/features/core.ex:84-94` and `:140-156`]
5. Fresh installs emit one extra migration file. The Phase 11 `MigrationTimestamps.allocate/2` handles the timestamp sequence — slot order in the manifest is the only thing the planner controls.

### `Sigra.Workers` behaviour shape (greenfield — file does not exist today)

```elixir
defmodule Sigra.Workers do
  @moduledoc """
  Behaviour for org-aware Sigra workers.

  Workers implementing this behaviour reconstruct a minimal `%Scope{}` from
  args at perform time and emit audit events through `Sigra.Audit.log_safe/3`
  using that scope. This keeps web and worker call sites cohesive: both look
  like `Audit.log_safe(action, scope, opts)`.

  ## Opt-in, not retroactive

  v1.1 only refactors `Sigra.Workers.AccountDeletion` to this behaviour. The
  other v1.0 workers (`Sigra.Workers.AuditCleanup`, `TokenCleanup`,
  `EmailDelivery`) are tenant-agnostic and stay on the v1.0 `Oban.Worker`
  contract. v1.2 may revisit `EmailDelivery` when admin-sent emails need
  org context.

  ## Worker scopes are AUDIT-ONLY

  The `%Scope{}` reconstructed in `perform/2` is suitable for audit emission
  ONLY. It is a minimal id-only skeleton. Hosts MUST NOT pass worker scopes
  to authorization functions — those expect a fully-hydrated request-time
  scope from `Sigra.Scope.Hydration`.

  ## Not a `use` macro

  This module is `@behaviour Sigra.Workers` — no injected boilerplate. The
  callback contract is small enough that a `use` macro adds noise without
  saving meaningful code. Implementing modules write their own `Oban.Worker`
  use directive (wrapped in `Code.ensure_loaded?(Oban.Worker)` if Oban is
  optional in the host app).
  """

  @callback perform(scope :: term() | nil, args :: map()) ::
              :ok
              | {:ok, term()}
              | {:error, term()}
              | {:snooze, pos_integer()}

  @doc """
  Validates that `args` carries the org-aware keys before enqueue.

  Returns the args unchanged on success, raises `KeyError` on missing keys.
  Belt-and-suspenders: implementing workers also `Map.fetch!/2` at perform
  time so a hand-built job (bypassing this validator) still fails loudly.
  """
  @spec new(module(), map(), keyword()) :: map()
  def new(_worker_module, args, _opts \\ []) when is_map(args) do
    Map.fetch!(args, "organization_id")
    Map.fetch!(args, "actor_id")
    args
  end
end
```

**Crucial facts:**

- `lib/sigra/workers.ex` does **not exist today** — Phase 15 creates it. [VERIFIED via `ls`]
- The behaviour module **must compile without Oban present**. It contains zero references to `Oban.Worker`. The wrapping `if Code.ensure_loaded?(Oban.Worker) do ... end` lives only in the implementing modules (e.g., `lib/sigra/workers/account_deletion.ex:1`). [VERIFIED]
- `AccountDeletion` currently `@impl Oban.Worker` and `def perform(%Oban.Job{args: ...})`. The refactor makes the module implement BOTH `@impl Oban.Worker` AND `@impl Sigra.Workers` — Oban dispatches to the arity-1 form, which then `Sigra.Scope.build/3`s a scope and delegates to a private function with the `(scope, args)` shape that matches the Sigra.Workers contract. The single test target is the `(scope, args)` form. [VERIFIED structure: `lib/sigra/workers/account_deletion.ex:32-67`]

### `Sigra.Scope.build/3` (greenfield)

```elixir
defmodule Sigra.Scope.Build do
  # Or: lives in lib/sigra/scope/build.ex as Sigra.Scope.Build, but the
  # callable is Sigra.Scope.build/3. CD: planner picks module shape; the
  # PUBLIC NAME `Sigra.Scope.build/3` is locked by D-23.
end

# Public callable per D-23:
defmodule Sigra.Scope do
  @doc """
  Builds a minimal scope struct for the given scope module.

  Used by both login-time scope synthesis (auth.ex) and worker scope
  reconstruction (Sigra.Workers reference impl).
  """
  @spec build(module(), struct(), keyword()) :: struct()
  def build(scope_module, user, opts \\ []) do
    struct(scope_module,
      user: user,
      active_organization: Keyword.get(opts, :active_organization),
      membership: Keyword.get(opts, :membership),
      impersonating_from: nil
    )
  end
end
```

**Note:** `lib/sigra/scope/` exists today only as a directory containing `hydration.ex`. There is no `lib/sigra/scope.ex` parent module. Phase 15 either creates `lib/sigra/scope.ex` (so `Sigra.Scope.build/3` is callable as written) or names the function differently. **The planner should create `lib/sigra/scope.ex` to host `build/3` since CONTEXT.md D-23 locks the call name as `Sigra.Scope.build/3`.** [VERIFIED: only `lib/sigra/scope/hydration.ex` exists]

### `Sigra.Audit.Query` extension shape

Existing `apply_filter/2` reduce pattern at `lib/sigra/audit/query.ex:21-43`:

```elixir
def build(audit_schema, filters \\ []) do
  Enum.reduce(filters, from(e in audit_schema), &apply_filter/2)
end

defp apply_filter({:actor_id, id}, q), do: where(q, [e], e.actor_id == ^id)
# ... existing clauses ...
defp apply_filter(_other, q), do: q  # ← REMOVE this catch-all (D-15)
```

Phase 15 adds three new clauses BEFORE the catch-all and replaces the catch-all with a raise:

```elixir
defp apply_filter({:organization_id, nil}, q),
  do: where(q, [e], is_nil(e.organization_id))
defp apply_filter({:organization_id, id}, q),
  do: where(q, [e], e.organization_id == ^id)

defp apply_filter({:effective_user_id, nil}, q),
  do: where(q, [e], is_nil(e.effective_user_id))
defp apply_filter({:effective_user_id, id}, q),
  do: where(q, [e], e.effective_user_id == ^id)

defp apply_filter({:organization_scope, {:only, org_id}}, q),
  do: where(q, [e], e.organization_id == ^org_id)

# TODO(v1.2): Postgres may not use the (organization_id, inserted_at)
# composite index for `WHERE org_id = ? OR org_id IS NULL` — the IS NULL
# branch can fall off the plan. v1.2 will revisit with a partial index on
# `WHERE organization_id IS NULL` or a `UNION ALL` rewrite.
defp apply_filter({:organization_scope, {:including_global, org_id}}, q),
  do: where(q, [e], e.organization_id == ^org_id or is_nil(e.organization_id))

defp apply_filter({key, _value}, _q) do
  raise ArgumentError, """
  Sigra.Audit.Query received unknown filter key: #{inspect(key)}.

  Supported filters: :actor_id, :action, :action_prefix, :outcome, :from,
  :to, :target_id, :target_type, :organization_id, :effective_user_id,
  :organization_scope.

  This is a breaking change in Sigra v1.1: previously, unknown keys were
  silently ignored. Silent ignore on an audit query is a security-adjacent
  bug — `Audit.Query.build(schema, actor: id)` (typo for actor_id) returned
  unfiltered results. See CHANGELOG.
  """
end
```

[VERIFIED: existing query.ex shape `lib/sigra/audit/query.ex:21-43`]

### `Sigra.Credo.NoLogSafe2InLib` custom check shape

```elixir
defmodule Sigra.Credo.NoLogSafe2InLib do
  @moduledoc """
  Forbids `Sigra.Audit.log_safe/2` (arity 2) calls in `lib/sigra/**`.

  After Phase 15, every library-internal audit emission carries a scope as
  the second positional argument: `Sigra.Audit.log_safe(action, scope, opts)`.
  This check prevents drift back to the arity-2 shim form in lib/.

  Allowed locations:
    * The `log_safe/2` shim definition itself in `lib/sigra/audit.ex`
    * Any test file (test/**)

  Custom Credo check pattern via Credo.Check behaviour. See:
  https://hexdocs.pm/credo/adding_checks.html
  """
  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Sigra.Audit.log_safe/2 is the v1.0 backwards-compat shim. New library
      code must use Sigra.Audit.log_safe/3 with an explicit scope (or `nil`
      for pre-auth sites).
      """
    ]

  alias Credo.Code

  @doc false
  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    if exempt?(source_file.filename) do
      []
    else
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp exempt?(filename) do
    String.ends_with?(filename, "lib/sigra/audit.ex") or
      String.starts_with?(filename, "test/") or
      String.contains?(filename, "/test/")
  end

  # Detect: Sigra.Audit.log_safe(action, opts)
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Sigra, :Audit]}, :log_safe]}, meta, args} = ast,
         issues,
         issue_meta
       )
       when length(args) == 2 do
    {ast, [issue_for(issue_meta, meta, "Sigra.Audit.log_safe/2") | issues]}
  end

  # Detect: Audit.log_safe(action, opts) — aliased form
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Audit]}, :log_safe]}, meta, args} = ast,
         issues,
         issue_meta
       )
       when length(args) == 2 do
    {ast, [issue_for(issue_meta, meta, "Audit.log_safe/2") | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, meta, call) do
    format_issue(issue_meta,
      message: "#{call} is forbidden in lib/sigra/. Use log_safe/3 with an explicit scope.",
      line_no: meta[:line]
    )
  end
end
```

**Crucial facts:**

- `.credo.exs` does **not exist** in the repo today. Phase 15 creates it (or the planner can ship it inside Plan 15-02 alongside the check). [VERIFIED via `ls`]
- Custom checks register in `.credo.exs` via the `requires` key, then are added to the `checks: %{enabled: [...]}` list. [CITED: https://hexdocs.pm/credo/config_file.html]
- Both `Sigra.Audit.log_safe(...)` AND aliased `Audit.log_safe(...)` forms must be detected — the alias form is used in 12 of 79 sites today.
- Tests for the check use `Credo.Test.Case`. [CITED: https://hexdocs.pm/credo/testing_checks.html]

### Anti-Patterns to Avoid

- **Don't add a `use Sigra.Workers` macro.** D-18 explicitly rejects this. The behaviour is small enough that a macro hides more than it saves.
- **Don't put `scope_fields/1` behind a public `metadata_from_scope/2` name.** D-05 locks the helper as private. One public entry point is the entire point.
- **Don't pattern-match on `%Sigra.Scope{}` in the helper.** Scope is generated into the host app, not a library struct. D-03 says duck-type only.
- **Don't use `Keyword.merge/2` for the scope+opts combination.** D-06 says prepend so caller-supplied keys win on `Keyword.get/2`'s first-match semantics.
- **Don't reference `Oban.Worker` from `lib/sigra/workers.ex`.** D-18 says the behaviour compiles without Oban.
- **Don't add an `effective_user_id` index in v1.1.** D-12 explicitly defers it to v1.2.
- **Don't add a `:organizations` FK without `type: :binary_id`.** D-13 locks the explicit type.
- **Don't edit `priv/templates/sigra.install/core/create_audit_events.exs`.** D-09 freezes it.
- **Don't update `log_multi/3` or `log_multi_safe/3`.** D-08 keeps them out of scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrent index on Postgres | Inline `execute "CREATE INDEX CONCURRENTLY ..."` | `create index(..., concurrently: true)` + `@disable_ddl_transaction true` + `@disable_migration_lock true` | Ecto ships the directive; the manual `execute` form skips Ecto's sanity checks |
| AST traversal for the Credo check | `String.contains?` line scan | `Credo.Code.prewalk/2` + AST pattern match | Comment lines, multiline strings, and string interpolation will all false-positive on a text scan |
| Test for "latest audit row" | Manual `repo.all` + `Enum.sort_by` | `from(e in schema, order_by: [desc: :inserted_at], limit: 1)` | The existing `assert_audit_event/2` (lib/sigra/testing.ex:1150) already does this; copy the pattern |
| Migration timestamp ordering | Hand-pick timestamps | `Sigra.Install.MigrationTimestamps.allocate/2` (Phase 11 D-04) | Slot order in `Features.Core.migrations/1` is the only knob — timestamps are derived |
| Worker scope reconstruction | Build a separate `WorkerScope` struct type | `Sigra.Scope.build(scope_module, user, ...)` writing into the host's `Scope` struct | The duck-typer in `scope_fields/1` only reads `.id`, so the host struct works |

## Common Pitfalls

### Pitfall 1: Aliased call form missed by mechanical edit
**What goes wrong:** A regex sweep that only matches `Sigra.Audit.log_safe(` leaves the 12 aliased `Audit.log_safe(` sites untouched.
**Why it happens:** `lib/sigra/auth.ex` uses `alias Sigra.Audit` at module top and calls `Audit.log_safe(...)` 12 times.
**How to avoid:** The mechanical sweep regex must match `(?:Sigra\.)?Audit\.log_safe\(` (or two passes). The Credo check's two `traverse/3` clauses handle both forms — running Credo after the sweep validates completeness.
**Warning signs:** Plan 15-01 verification step should run Credo locally and assert zero `NoLogSafe2InLib` issues across `lib/sigra/`.

### Pitfall 2: `session.create` audit reorder breaks unrelated tests
**What goes wrong:** Moving the `session.create` audit emission AFTER `select_active_organization/3` changes the relative order of audit rows in any test that asserted multiple audit events in sequence.
**Why it happens:** `assert_audit_event/2` accepts a `:position` argument, and existing tests may pin `position: 0` for `session.create`.
**How to avoid:** Plan 15-02 verification step greps `test/sigra/auth*` for `position:` in audit assertions before reordering, then updates positions in the same commit as the reorder. CHANGELOG entry calls out the behavior change.
**Warning signs:** A test failure with `Expected action == "session.create", got "auth.login.success"` means the position needs to flip.

### Pitfall 3: Whitelist filter raise breaks v1.0 test fixtures
**What goes wrong:** Removing the silent catch-all clause in `Audit.Query.build/2` raises on any v1.0 test that passed a typo'd filter key (e.g., `actor:` instead of `actor_id:`).
**Why it happens:** `apply_filter(_other, q), do: q` — the existing escape hatch — is the line being removed (D-15).
**How to avoid:** Plan 15-01 grep for `Audit.Query.build` and `Audit.query(` call sites in `test/` BEFORE removing the catch-all. Fix any typo'd keys in the same commit.
**Warning signs:** Test failures with `Sigra.Audit.Query received unknown filter key: ...` are real bugs being surfaced — don't restore the catch-all to silence them.

### Pitfall 4: Concurrent index migration runs inside Ecto's migration lock
**What goes wrong:** `create index(..., concurrently: true)` raises on Postgres if the migration runs inside Ecto's default migration advisory lock.
**Why it happens:** Ecto wraps migrations in a transaction by default, and the migration lock holds an advisory lock. `CREATE INDEX CONCURRENTLY` requires both off.
**How to avoid:** BOTH `@disable_ddl_transaction true` AND `@disable_migration_lock true` at the top of the migration module. CONTEXT.md D-10 locks both. The `change/0` form CANNOT be used — must split into `up/0` + `down/0` because `change/0` implies a transaction. (See the migration template skeleton above — Postgres branch uses `up/0` + `down/0`; SQLite/MySQL use `change/0`.)
**Warning signs:** `(Postgrex.Error) ERROR 25001 (active_sql_transaction): CREATE INDEX CONCURRENTLY cannot run inside a transaction block`. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-transaction-callbacks]

### Pitfall 5: `effective_user_id` populated with `actor_id` makes failed-login look attributable
**What goes wrong:** The natural impulse for "populated identically to user_id in v1.1" (REQ AUD-02) is to set `effective_user_id = actor_id` everywhere — including failed-login sites where the user submitted credentials but failed authentication.
**Why it happens:** The "identically" wording in the requirement collides with D-26's "failed-login `effective_user_id` is strictly nil; the signal uses `target_id: user.id`."
**How to avoid:** D-26 wins. The `scope_fields/1` helper uses scope.user.id — and pre-auth failed-login sites pass `nil` scope, so `effective_user_id` lands as `nil`. The "identical to actor_id in v1.1" rule applies to AUTHENTICATED sites only.
**Warning signs:** A test for "failed login does not assert actor identity" should pin `actor_id: nil, effective_user_id: nil, target_id: user.id` for the resolved-email-but-wrong-password case.

### Pitfall 6: Install golden fixture diverges from generated tree
**What goes wrong:** Adding the new ALTER migration template + the audit_event.ex schema field changes triggers `Sigra.Install.GoldenDiffTest` failures because `test/fixtures/install_golden/tree/` no longer matches the generator output.
**Why it happens:** The fixture is byte-identical regression-locked. ANY template change requires fixture regeneration.
**How to avoid:** Plan 15-03 includes the fixture regeneration as an explicit task. The runbook is documented in `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md` (referenced from `test/sigra/install/golden_diff_test.exs:30`). Regeneration is **manual** — there is no `mix sigra.install.regenerate_golden` task. The task list:
  1. Run `mix sigra.install --yes` against the fixture template app.
  2. Snapshot the output tree via `Sigra.Test.InstallFixture.normalize_tree/2`.
  3. Replace files under `test/fixtures/install_golden/tree/` with the new normalized tree.
  4. Replace `test/fixtures/install_golden/STDOUT.txt` with the normalized stdout.
  5. Verify the diff is exactly: one new migration file + the audit_event.ex schema additions.
  6. Mirror the same change into `test/example/` (the example app fixture used by the smoke harness).
**Warning signs:** Plan 15-03 must NOT skip step 6. The example app and the golden fixture drift independently if you only update one.

## Code Examples

### Reading the latest audit row deterministically (existing pattern, copy verbatim)

```elixir
# Source: lib/sigra/testing.ex:1150 (existing assert_audit_event/2)
require Ecto.Query

query =
  Ecto.Query.from(e in audit_schema,
    order_by: [desc: e.inserted_at],
    limit: 1,
    offset: ^position
  )

event = repo.one(query)
```

For the new `assert_audit_logged/2` (D-31), the planner can either:
- **(A) Add a thin wrapper around `assert_audit_event/2`** that pre-fills the field set `{action, actor_id, effective_user_id, organization_id, target_id}` from a keyword input. This is the lower-LOC path and reuses verified deterministic ordering.
- **(B) Add a separate function** with its own query. Higher LOC, no benefit. Don't.

Recommendation: option A. The two helpers coexist; `assert_audit_event/2` stays for v1.0 callers, `assert_audit_logged/2` is the org-aware companion.

### Adapter-branched migration template (existing convention, lift verbatim)

```eex
<%= if adapter == :postgres do %>
  ... postgres-specific ...
<% end %><%= if adapter == :mysql do %>
  ... mysql-specific ...
<% end %><%= if adapter == :sqlite do %>
  ... sqlite-specific ...
<% end %>
```

[VERIFIED: `priv/templates/sigra.install/core/migration.exs:3-206`, `core/api_token_migration.exs:3-57`, `organizations/migration.exs:3`]

### `Features.Core.migrations/1` slot insertion (Phase 12 precedent)

```elixir
# Source: lib/sigra/install/features/core.ex:84-94 (Phase 12 added :active_org_column the same way)
def migrations(_binding) do
  [
    {:primary, "core/migration.exs", "create_sigra_auth_tables.exs"},
    {:active_org_column,
     "core/add_active_organization_id_to_user_sessions.exs",
     "add_active_organization_id_to_user_sessions.exs"},
    {:api_token, "core/api_token_migration.exs", "create_user_api_tokens.exs"},
    {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"},
    # NEW slot Phase 15:
    {:audit_events_org_columns,
     "core/alter_audit_events_add_org_columns.exs",
     "alter_audit_events_add_org_columns.exs"}
  ]
end
```

And the parallel insert into `base_files/1` (around lines 140-156):

```elixir
audit_org_columns_migration =
  {:eex, "core/alter_audit_events_add_org_columns.exs",
   migration_target(binding, :audit_events_org_columns,
     "alter_audit_events_add_org_columns.exs")}

# inserted in the base_files/1 list immediately after audit_migration:
[
  ...
  audit_migration,
  audit_org_columns_migration,
  ...
]
```

[VERIFIED: `lib/sigra/install/features/core.ex:140-223`]

## Runtime State Inventory

Phase 15 is a code-only refactor + additive migration. No string renames, no rebrand, no migration of stored data.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the new columns are nullable and v1.0 audit rows backfill cleanly to `NULL`. The reorder of `session.create` only affects NEW audit rows; existing rows are unchanged. | None |
| Live service config | None — Sigra is a library; no external services touch the audit table directly. | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None — the new Credo check is a Mix-compiled module; `mix deps.compile sigra` after install rebuilds normally. | None |

**Nothing found in any category** — verified by inspection of CONTEXT.md scope and grep across the workers / scope / audit / install paths.

## 79-Site Sweep Per-File Breakdown

Verified 2026-04-12 via `grep -rEn "(?:Sigra\.)?Audit\.log_safe\(" lib/sigra` (the regex matches both fully-qualified and aliased forms):

| File | Sites | Form | Plan 15-01 Chunk |
|------|-------|------|------------------|
| `lib/sigra/auth.ex` | 24 | mostly aliased `Audit.log_safe(` (12 sites) + 12 fully-qualified | A — auth.ex (largest, includes the D-27 reorder location) |
| `lib/sigra/mfa.ex` | 20 | fully-qualified | B — mfa.ex |
| `lib/sigra/account.ex` | 17 | fully-qualified | C — account.ex |
| `lib/sigra/oauth.ex` | 8 | fully-qualified | D — oauth.ex |
| `lib/sigra/api_token.ex` | 7 | fully-qualified | D — api_token.ex |
| `lib/sigra/lockout.ex` | 1 | fully-qualified | D |
| `lib/sigra/suspicious_login.ex` | 1 | fully-qualified | D |
| `lib/sigra/plug/load_active_organization.ex` | 1 | fully-qualified | D — already has scope context (Phase 14), good migration test |
| **TOTAL** | **79** | 67 fully-qualified + 12 aliased | |

The mechanical sweep is **`Audit.log_safe(action, opts)` → `Audit.log_safe(action, nil, opts)`** for every site in Plan 15-01. Plan 15-02 then replaces `nil` with real scopes at Category 1/2/3 sites per D-26/D-27/D-28.

[VERIFIED: counts match CONTEXT.md exactly; per-file breakdown matches the canonical refs section.]

## `session.create` reorder — exact location

[VERIFIED: `lib/sigra/auth.ex:996-1101`]

Current sequence inside `create_session/4`:

1. **Line 999:** `def create_session(config, user, metadata, opts \\ [])`
2. **Line 1003-1005:** `Telemetry.span` wraps `session_store.create/3`. Returns `{:ok, session}` or error.
3. **Lines 1008-1021:** **`Sigra.Audit.log_safe("session.create", ...)`** — ← target of D-27 reorder. Currently fires BEFORE org assignment.
4. **Line 1027:** `maybe_assign_active_organization(config, user, session, ...)` — calls `Sigra.Organizations.select_active_organization/3` internally (line 1052).
5. **Line 1037-1101:** `defp maybe_assign_active_organization/6` — the function that calls `select_active_organization/3` and writes the result via `session_store.update_active_organization/3`.

**Target relocation point:** The `Sigra.Audit.log_safe("session.create", ...)` block at lines 1008-1021 must move to AFTER the `maybe_assign_active_organization/6` call returns successfully. The `session` variable in scope at that point is the **updated** session with `active_organization_id` set, so the planner can synthesize a scope via `Sigra.Scope.build(scope_module, user, active_organization: <fetched_org>)` and pass it as the second arg to `log_safe/3`.

**Subtlety:** `maybe_assign_active_organization/6` returns `{:ok, session}` in all branches (it's fail-open per WR-04, lines 1056-1086). The audit MUST fire after the success branch unwraps. The cleanest shape is to move the audit emission INSIDE `maybe_assign_active_organization/6` at the end, right before the final `{:ok, updated_session}` return. This keeps the audit and the scope creation co-located.

The `auth.login.success` audit (a separate event from `session.create`) is emitted from a different call site higher in the auth pipeline; D-27 also flags this should fire after org assignment. Plan 15-02 should grep `auth.login.success` to find that emission point and reorder if necessary.

## Test Audit Schema Update

[VERIFIED: `test/support/audit_test_event.ex` is 24 lines, defines `Sigra.Test.AuditEvent` with `schema "audit_events"` and 10 fields]

Add two new field declarations:

```elixir
schema "audit_events" do
  # ... existing 10 fields ...
  field(:metadata, :map)
  field(:occurred_at, :utc_datetime_usec)
  field(:organization_id, :binary_id)         # NEW
  field(:effective_user_id, :binary_id)       # NEW
  timestamps(updated_at: false, type: :utc_datetime_usec)
end
```

**Files that reference this test schema** (10 verified via grep):
- `test/sigra/audit_test.exs`
- `test/sigra/audit_security_test.exs`
- `test/sigra/audit_observability_test.exs`
- `test/sigra/audit_integration_test.exs`
- `test/sigra/audit_property_test.exs`
- `test/sigra/audit_sensitive_data_test.exs`
- `test/sigra/audit/changeset_test.exs`
- `test/sigra/testing_audit_test.exs`
- `test/sigra/workers/audit_cleanup_test.exs`
- `test/support/audit_test_event.ex` (the schema itself)

The two-line addition is non-breaking (additive `field/2` declarations on a test-only schema). However, the migration template update means any test that creates the table via `Ecto.Migrator` needs the new columns present. The Phase 9 audit test suite uses an in-memory test schema, so the alter-migration only needs to be run in tests that use the install golden fixture (which already runs migrations end-to-end). Plan 15-02 verification step: `mix test test/sigra/audit*` after the schema edit must pass.

## `Sigra.Testing` module — current surface and where `assert_audit_logged/2` fits

[VERIFIED: `lib/sigra/testing.ex` is 1202 lines, defines `Sigra.Testing` with 17 public assertion helpers]

Existing assertion functions (line numbers from `grep "def assert_"`):
- `assert_password_hashed/1` (line 37, 46)
- `assert_session_created/1` (line 62)
- `assert_token_sent/2` (line 75)
- `assert_email_sent/1` (line 94)
- `assert_rate_limited/1` (line 200)
- `assert_mfa_enabled/2` (line 435)
- `assert_mfa_disabled/2` (line 468)
- `assert_token_revoked/2` (line 598)
- `assert_scope_denied/1` (line 617)
- `assert_deletion_scheduled/1` (line 777)
- `assert_deletion_cancelled/1` (line 798)
- `assert_account_deleted/3` (line 819)
- `assert_password_changed/1` (line 869)
- `assert_sessions_invalidated/3` (line 895)
- **`assert_audit_event/2` (line 1150)** — the existing v1.0 audit assertion. Already does deterministic latest-row read with `:position` offset support.

**Recommendation:** `assert_audit_logged/2` lands as a new function in `Sigra.Testing` that wraps `assert_audit_event/2` with a pre-filled field set:

```elixir
@doc """
Asserts the latest audit row matches the given org-aware fields.

Phase 15 helper for verifying the 79-site sweep. Reads the latest audit row
deterministically and asserts on `{action, actor_id, effective_user_id,
organization_id, target_id}`.

## Example

    assert_audit_logged(
      %{
        action: "auth.login.success",
        actor_id: user.id,
        effective_user_id: user.id,
        organization_id: org.id,
        target_id: nil
      },
      repo: MyApp.Repo,
      audit_schema: MyApp.AuditEvent
    )
"""
@spec assert_audit_logged(map(), keyword()) :: true
def assert_audit_logged(expected, opts) when is_map(expected) and is_list(opts) do
  assert_audit_event(expected, opts)
end
```

The thin wrapper preserves backward compatibility (existing `assert_audit_event/2` stays untouched) and gives Phase 15's 79 sweep tests a semantically named target. **The function is one line of real logic** — the value is the name, not the implementation.

REQ DX-02 also lists `assert_scope_has_org/2`, `assert_membership/3`, `assert_audit_logged_for_org/2` as Phase 23 helpers; Phase 15 ships only `assert_audit_logged/2` (the audit shape). The `_for_org/2` variant is Phase 23.

## Generator Install-Golden Fixture Update Mechanics

[VERIFIED: `test/sigra/install/golden_diff_test.exs:27-32` and `test/support/install_fixture.ex:1-141`]

**There is NO automated `mix` task for fixture regeneration.** The procedure is documented in `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md` (referenced from the GoldenDiffTest moduledoc). The mechanism:

1. **`Sigra.Test.InstallFixture.setup_tmp_app/0`** (test/support/install_fixture.ex) creates a temp Phoenix app and runs `mix sigra.install --yes` against it.
2. **`InstallFixture.normalize_tree(app_dir, baseline)`** walks the resulting tree and returns a sorted `[{normalized_path, content}, ...]` list. Migration filenames have their 14-digit timestamp prefix replaced with `TIMESTAMP_` for determinism.
3. **`InstallFixture.normalize_stdout(raw, app_dir)`** strips nondeterministic output from captured stdout.

**To regenerate after a template change:**

The test fixture cannot be auto-regenerated via a single command; it requires:
1. A small custom helper (or an inline `mix run -e ...` script) that calls `InstallFixture.setup_tmp_app/0`, then writes the normalized tree to `test/fixtures/install_golden/tree/`.
2. Manual diff review against the previous baseline.
3. Mirror the same change into `test/example/` (the example app, used by the Playwright smoke harness).

**Recommendation for Plan 15-03:** Ship a one-shot regeneration helper as a dev-only `mix sigra.regen.install_golden` task (or a small `dev/regenerate_golden.exs` script) that the planner runs once, then commits. The script is throwaway — it doesn't ship in `lib/`. This is the smallest deviation from the existing manual process and gives a single command for future fixture updates.

The Plan 15-03 fixture update task should explicitly list:
- `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_alter_audit_events_add_org_columns.exs` (NEW)
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/audit_event.ex` (MODIFIED — 2 new fields)
- `test/fixtures/install_golden/STDOUT.txt` (MODIFIED — extra "* creating priv/repo/migrations/TIMESTAMP_alter_audit_events_add_org_columns.exs" line)
- The corresponding mirror in `test/example/` (run `mix sigra.install --yes` against the example app and commit the deltas the same way)

## Oban Optional-Dep Boundary

[VERIFIED: `lib/sigra/workers/account_deletion.ex:1`]

The pattern in use today wraps the entire module in:

```elixir
if Code.ensure_loaded?(Oban.Worker) do
defmodule Sigra.Workers.AccountDeletion do
  # ... module body uses Oban.Worker ...
end
end
```

This is verified across all four existing worker modules. It means:
- When Oban is NOT a runtime dep of the host app, the worker module simply doesn't define itself. Sigra.Workers.AccountDeletion is undefined; any caller hits `UndefinedFunctionError`.
- When Oban IS present, the module compiles normally.

**`Sigra.Workers` (the new behaviour module) does NOT use this pattern.** It compiles unconditionally because it has zero references to Oban — only the implementing modules wrap themselves. This is exactly what D-18 requires:

> "lib/sigra/workers.ex has zero references to Oban and compiles without it."

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `log_safe/2` everywhere with metadata-bag scope | `log_safe/3` with explicit scope arg | Phase 15 (this phase) | Single point of metadata assembly; v1.2 impersonation becomes a one-line diff |
| Org/effective_user as JSONB metadata | Real indexed columns | Phase 15 | v1.2 per-org views are simple WHERE filters, no schema migration |
| Silent ignore of unknown filter keys | `ArgumentError` on unknown keys | Phase 15 | Breaking change — surfaces typos as failures, not silent unfiltered queries |
| `Audit.log_safe(action, scope_metadata: %{org_id: ...})` | `Audit.log_safe(action, scope, opts)` | Phase 15 | Cohesive call shape between web and worker contexts |
| Workers as one-off `Oban.Worker` modules | `@behaviour Sigra.Workers` (opt-in) | Phase 15 | Tenant-aware workers reconstruct scope explicitly; tenant-agnostic ones (AuditCleanup, etc.) opt out |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `adapter` EEx binding always evaluates to `:postgres`, `:mysql`, or `:sqlite` (not `nil` or another atom). | Migration template | A `nil` adapter would render no branch and emit an empty migration body. **Mitigation:** verified `lib/mix/tasks/sigra.install.ex:127 detect_adapter/1` returns one of those three; planner should add a fallback `<% else %>raise "unsupported adapter"<% end %>` if defensive. |
| A2 | `mix sigra.install --yes` against the install golden fixture is idempotent enough that re-running it produces a diff containing ONLY the Phase 15 changes (no incidental drift from other phases since the last fixture update). | Fixture regeneration | If incidental drift exists, Plan 15-03's diff review surfaces unrelated edits and risks accidentally committing them. **Mitigation:** Plan 15-03 verifies the diff visually before commit. |
| A3 | `Credo.Code.prewalk/2` exists in Credo 1.7.x and matches the API documented at https://hexdocs.pm/credo/adding_checks.html. The exact function name may be `Credo.Code.prewalk/3` (with accumulator) — Plan 15-02 should verify against the installed Credo version. | Credo check | Wrong API name → check fails to compile. **Mitigation:** the check is small and isolated; planner verifies via `mix help credo` or by inspecting `deps/credo/lib/credo/code.ex` after running `mix deps.get`. |

**All other claims in this research were verified via direct file reads or existing official documentation.** No assumed compliance / retention / security claims.

## Open Questions

1. **Where exactly should `auth.login.success` audit fire relative to `session.create`?**
   - What we know: D-27 says `session.create` reorders to AFTER `select_active_organization/3`. CONTEXT.md does NOT explicitly say `auth.login.success` reorders too.
   - What's unclear: Whether `auth.login.success` is currently emitted before or after `create_session/4` returns. A grep over `lib/sigra/auth.ex` for `auth.login.success` will resolve this in 30 seconds during Plan 15-02.
   - Recommendation: Plan 15-02's first action is `grep -n "auth.login.success" lib/sigra/auth.ex`. If it fires inside `create_session`'s caller (the login flow), reorder it the same way. If it already fires after, no change needed.

2. **Should `Sigra.Scope.build/3` live in `lib/sigra/scope.ex` (new file) or `lib/sigra/scope/build.ex` (matches sibling pattern with `hydration.ex`)?**
   - What we know: D-23 locks the call name `Sigra.Scope.build/3`. Today there is no `lib/sigra/scope.ex` — only `lib/sigra/scope/hydration.ex` defining `Sigra.Scope.Hydration`.
   - What's unclear: The naming convention has `Sigra.Scope.Hydration` (a child module under a non-existent parent). Adding `Sigra.Scope.build/3` requires creating `lib/sigra/scope.ex`.
   - Recommendation: Create `lib/sigra/scope.ex` defining `Sigra.Scope` with `build/3`. The parent module file can be small (just `build/3` and a moduledoc). This is the cleanest way to honor D-23's locked call name.

3. **Does the existing v1.0 `mix sigra.install --yes` golden test currently include the example app fixture, or are they separate?**
   - What we know: `test/fixtures/install_golden/` and `test/example/` both exist. The Phase 15 fixture update needs both.
   - What's unclear: Whether `test/example/` is regenerated by a separate command or by hand.
   - Recommendation: Plan 15-03 verifies via `find test/example -name "audit_event.ex"` whether the example app already has a tracked copy. If yes, update it via the same regeneration script. If no, the example app pulls from the live templates and rebuilds at smoke-test time.

## Environment Availability

Phase 15 depends only on what's already in the working tree. No new external services, runtimes, or CLI tools.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All Sigra code | ✓ (assumed — Sigra is the project) | ~> 1.18 | — |
| Ecto / Ecto.SQL | Migration template, Audit.Query | ✓ | ~> 3.12 | — |
| Credo | New custom check | ✓ (already a dev dep) | ~> 1.7 | — |
| Oban | AccountDeletion refactor (optional) | ✓ (optional dep, present in test deps) | ~> 2.17 | Skip refactor if unavailable; behaviour still ships |
| PostgreSQL | Concurrent index test path | ✓ (CI matrix runs all 3 adapters) | 15+ | MySQL/SQLite branches use plain `create index` |

**All dependencies present.** No fallback action required.

## Validation Architecture

> Phase 15 includes this section because `workflow.nyquist_validation` is not explicitly disabled in `.planning/config.json`. Treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18 stdlib) + ExUnitProperties (existing dep, used by `test/sigra/audit_property_test.exs`) |
| Config file | `test/test_helper.exs` (existing, no Wave 0 needed) |
| Quick run command | `mix test test/sigra/audit*` (covers the 8 audit test files in ~5s) |
| Full suite command | `mix test` |
| Adapter matrix | CI runs Postgres + MySQL + SQLite — the migration template's three branches all execute |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUD-01 | Alter migration adds `organization_id` indexed column | migration | `mix test test/sigra/install/golden_diff_test.exs` (fixture asserts the new file is emitted) + integration test that runs the migration on a real Postgres test DB | ✅ golden_diff_test.exs / ❌ migration integration test (Wave 0 gap) |
| AUD-01 | Index hit-count proves `(organization_id, inserted_at)` is used | integration | New: `test/sigra/audit_query_index_test.exs` — uses Postgres `EXPLAIN` to assert index scan | ❌ Wave 0 |
| AUD-02 | `effective_user_id` populated from scope.user.id on authenticated sites | unit | `mix test test/sigra/audit_test.exs::test "log_safe/3 sets effective_user_id from scope"` | ❌ Wave 0 (extend existing audit_test.exs) |
| AUD-02 | `effective_user_id` is `nil` on failed-login sites (D-26) | unit | `mix test test/sigra/auth_test.exs` — extend with assertion | ❌ Wave 0 (extend existing) |
| AUD-03 | `log_safe/3` is the single emission point — no other call shape works | static analysis | `mix credo --strict` runs the new `Sigra.Credo.NoLogSafe2InLib` check | ❌ Wave 0 (Credo check + .credo.exs) |
| AUD-04 | `Audit.Query.build(schema, organization_id: id)` filters correctly | unit | `mix test test/sigra/audit/query_test.exs` — extend | ❌ Wave 0 (file may need creation) |
| AUD-04 | `Audit.Query` raises on unknown filter keys (breaking change) | unit | `mix test test/sigra/audit/query_test.exs::test "raises on unknown filter key"` | ❌ Wave 0 |
| AUD-05 | `Sigra.Workers` behaviour `new/3` raises on missing org_id/actor_id | unit | `mix test test/sigra/workers_test.exs` | ❌ Wave 0 (file does not exist) |
| AUD-05 | `Sigra.Workers.AccountDeletion` reference impl emits audit via `log_safe/3` with reconstructed scope | integration | `mix test test/sigra/workers/account_deletion_test.exs::test "perform emits audit with org-aware scope"` | ✅ exists, must be extended |
| D-27 | `session.create` audit row carries `organization_id` (reorder fix) | integration | `mix test test/sigra/auth_test.exs::test "session.create audit fires after org assignment"` | ❌ Wave 0 |
| D-30 | Credo check fires on `log_safe/2` in `lib/sigra/foo.ex` | unit | `mix test test/sigra/credo/no_log_safe_2_in_lib_test.exs` | ❌ Wave 0 |
| D-31 | `assert_audit_logged/2` reads latest row deterministically | unit | `mix test test/sigra/testing_audit_test.exs::test "assert_audit_logged"` | ❌ Wave 0 (extend existing testing_audit_test.exs) |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/audit* test/sigra/workers* test/sigra/credo*` (~10 seconds)
- **Per wave merge:** `mix test` + `mix credo --strict` (~60 seconds locally; CI runs full matrix on 3 adapters)
- **Phase gate:** Full suite green + golden_diff_test green + Credo strict green + CHANGELOG entry merged before `/gsd-verify-work`

### Wave 0 Gaps

These are the test files / infrastructure pieces the planner must list as Wave 0 prerequisites in PLAN.md:

- [ ] `lib/sigra/credo/no_log_safe_2_in_lib.ex` — the custom check itself
- [ ] `.credo.exs` — Credo config file at project root with `requires:` registering the custom check (does not currently exist)
- [ ] `test/sigra/credo/no_log_safe_2_in_lib_test.exs` — uses `Credo.Test.Case`
- [ ] `lib/sigra/workers.ex` — behaviour module (greenfield)
- [ ] `test/sigra/workers_test.exs` — `new/3` enqueue validator tests
- [ ] `lib/sigra/scope.ex` — parent module hosting `build/3`
- [ ] `test/sigra/scope_build_test.exs` — `build/3` constructor tests
- [ ] `test/sigra/audit_query_index_test.exs` — `EXPLAIN`-based index hit-count test (Postgres-only; SQLite/MySQL skip)
- [ ] `test/sigra/audit/query_test.exs` — extended for whitelist filter raise + 3 new filters (verify file exists; if not, create)
- [ ] Extension of `test/sigra/testing_audit_test.exs` — `assert_audit_logged/2` coverage
- [ ] Extension of 8 audit test files for `log_safe/3` shape
- [ ] CHANGELOG.md entry — covers (a) `log_safe/3` API addition, (b) `session.create` reorder, (c) `Audit.Query` whitelist breaking change, (d) `Sigra.Workers` behaviour, (e) new alter migration

### Validation Dimensions

Plans for Phase 15 must cover all of these dimensions in their VALIDATION.md sections:

1. **Unit** — `log_safe/3` shape, `scope_fields/1` duck-typing, `Sigra.Scope.build/3`, `Sigra.Workers.new/3` validator, `Audit.Query` filter clauses, `assert_audit_logged/2`.
2. **Integration** — `AccountDeletion` perform path with reconstructed scope, login flow with `session.create` carrying real `organization_id`.
3. **Migration safety** — alter migration runs on Postgres (concurrent), MySQL (plain), SQLite (plain) without errors. Down migration cleanly reverses.
4. **Index-use proof** — `EXPLAIN ANALYZE` of `Audit.Query.build(schema, organization_id: id)` shows `(organization_id, inserted_at)` index scan, not seq scan. Postgres-only test; document `# TODO(v1.2):` for the `:including_global` IS NULL branch which may seq-scan (D-17).
5. **Static analysis** — `mix credo --strict` runs `Sigra.Credo.NoLogSafe2InLib` and reports zero issues across `lib/sigra/`. The check itself has unit tests via `Credo.Test.Case`.
6. **Generator parity** — `Sigra.Install.GoldenDiffTest` passes after fixture regeneration. Example app at `test/example/` mirrors the same migration + schema additions.
7. **Behavior change tracking** — CHANGELOG.md entry covers (a) `session.create` reorder, (b) `Audit.Query` unknown-key raise, (c) new `log_safe/3` arity, (d) new behaviour module, (e) new migration. Entry is verified by a test or by manual review during Plan 15-03.
8. **Test helper behavior** — `assert_audit_logged/2` handles `:position`, latest-row, and field assertions consistently with `assert_audit_event/2`.

## Security Domain

> Required because `security_enforcement` is not explicitly disabled in `.planning/config.json`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing v1.0 controls; Phase 15 only changes how the AUDIT of those events looks |
| V3 Session Management | yes | Phase 15 reorders `session.create` audit emission (D-27) — does not change session lifecycle |
| V4 Access Control | partial | `Audit.Query.build` raise on unknown filter keys (D-15) closes a typo-induced unfiltered-query class — defense-in-depth for audit retrieval, not a primary AC mechanism |
| V5 Input Validation | yes | `nimble_options` config schema validation already in place via `Sigra.Audit.Changeset`; Phase 15 adds two new fields under the same validator |
| V6 Cryptography | n/a | No new crypto in Phase 15 |
| **V7 Logging and Monitoring** | **YES — primary** | OWASP ASVS V7.1: "Log all authentication events"; V7.1.3: "MUST NOT log credentials"; D-26: failed-login does not record actor identity; D-29: unknown-email failed-login does NOT log email hash (avoids enumeration oracle on the audit table) |
| V10 Business Logic | yes | `Sigra.Workers.new/3` enqueue validator (D-20) fails fast on missing tenant context — prevents the "worker runs without tenant context" pitfall (PITFALLS O-11) |
| V14 Configuration | yes | `.credo.exs` is a new project-level config file; the custom check enforces the architectural invariant structurally |

### Known Threat Patterns for Sigra audit

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Audit misattribution under impersonation (PITFALLS O-7) | Repudiation | Real `effective_user_id` column ships in v1.1 (D-04), populated from scope.user.id; v1.2 impersonation diff is one line in `scope_fields/1` |
| Worker emits audit without tenant context (PITFALLS O-11) | Repudiation | `Sigra.Workers.new/3` raises on missing `organization_id`/`actor_id`; perform-time `Map.fetch!` belt-and-suspenders |
| Cascade wipes audit log (PITFALLS O-10) | Tampering | FK `on_delete: :nilify_all` on `audit_events.organization_id` (D-13); already mitigated in Phase 13, must not regress |
| Email enumeration via audit log (D-29) | Information Disclosure | Failed-login with unknown email logs IP+UA only — no email hash; verified server secret leak cannot expose historical claimed identities |
| Recording claimed identity as actor on failed login (NIST 800-63B §5.2.2) | Repudiation | D-26: `effective_user_id: nil`, `actor_id: nil`, `target_id: user.id` for failed-login with resolved email |
| Silent unfiltered audit query via typo'd filter key | Information Disclosure | D-15: `Audit.Query` raises `ArgumentError` on unknown filter keys (breaking change for v1.0 users) |
| `log_safe/2` regression after Phase 15 | Repudiation (long-term drift) | `Sigra.Credo.NoLogSafe2InLib` custom check enforces the invariant structurally in CI |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/15-audit-integration/15-CONTEXT.md` — 31 locked decisions, all read in full
- `.planning/REQUIREMENTS.md` AUD-01..AUD-05 — phase requirements, lines 73-77
- `.planning/ROADMAP.md` Phase 15 §lines 116-128 — phase goal and success criteria
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — Scope shape, Session field
- `lib/sigra/audit.ex` (full read) — current `log_safe/2` shape and surrounding helpers
- `lib/sigra/audit/changeset.ex` (full read) — `@cast_fields` list location
- `lib/sigra/audit/query.ex` (full read) — `apply_filter/2` reduce pattern + catch-all line
- `lib/sigra/scope/hydration.ex` (full read) — sibling module to verify directory structure
- `lib/sigra/workers/account_deletion.ex` (full read) — `Code.ensure_loaded?` wrapping pattern + arg shape
- `lib/sigra/install/features/core.ex` (full read) — `migrations/1` slot list, `base_files/1` insertion pattern
- `priv/templates/sigra.install/core/create_audit_events.exs` (full read) — frozen template, never edit
- `priv/templates/sigra.install/core/audit_event.ex` (full read) — schema template gaining 2 fields
- `priv/templates/sigra.install/organizations/migration.exs` (partial read) — adapter-branching EEx pattern reference
- `lib/sigra/auth.ex` lines 980-1101 — `create_session/4` and `maybe_assign_active_organization/6` exact location of D-27 reorder
- `lib/sigra/testing.ex` lines 1140-1201 — existing `assert_audit_event/2` to wrap
- `test/support/audit_test_event.ex` (full read) — test schema gaining 2 fields
- `test/sigra/install/golden_diff_test.exs` lines 1-100 — fixture regeneration runbook reference
- `test/support/install_fixture.ex` headers — `normalize_tree/2` API
- `lib/sigra/install/features/core.ex:140-156` — `base_files/1` migration insert pattern (Phase 12 precedent for `:active_org_column`)
- `lib/mix/tasks/sigra.install.ex:113-129` — `adapter` binding source via `detect_adapter/1`

### Secondary (MEDIUM confidence — official docs cited)

- [Credo "Adding Checks" docs](https://hexdocs.pm/credo/adding_checks.html) — custom check structure
- [Credo "Testing Custom Checks"](https://hexdocs.pm/credo/testing_checks.html) — `Credo.Test.Case`
- [Credo `.credo.exs` config](https://hexdocs.pm/credo/config_file.html) — `requires:` key for custom check registration
- [Ecto.Migration docs](https://hexdocs.pm/ecto_sql/Ecto.Migration.html) — `@disable_ddl_transaction`, `@disable_migration_lock`, `concurrently:`
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) — `(scope, ...)` argument convention
- [AppSignal: Writing a Custom Credo Check](https://blog.appsignal.com/2023/08/29/writing-a-custom-credo-check-in-elixir.html) — real-world example of `Credo.Code.prewalk` + `format_issue`
- [Optimum Credo (GitHub)](https://github.com/optimumBA/optimum_credo) — production custom-check repo for AST pattern reference

### Tertiary (LOW confidence — none for this phase)

None. Every claim above was verified via a direct file read or an official docs citation.

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — every dep is already in `mix.exs`; zero new deps added.
- **Architecture (helper, behaviour, query, migration):** HIGH — every shape is verified against existing repo files (audit.ex, changeset.ex, query.ex, account_deletion.ex, features/core.ex).
- **Mechanical sweep:** HIGH — 79 sites verified per-file via grep, both fully-qualified and aliased forms counted.
- **`session.create` reorder location:** HIGH — exact line numbers (1008-1021 for emission, 1027 for `maybe_assign_active_organization` call) verified via direct read.
- **Test audit schema:** HIGH — file exists, 24 lines, two-line additive change verified.
- **`Sigra.Testing` integration point:** HIGH — `assert_audit_event/2` exists at line 1150 with the exact deterministic-read pattern needed.
- **Generator install-golden mechanics:** HIGH — `golden_diff_test.exs` and `install_fixture.ex` read; manual regeneration runbook confirmed.
- **Oban optional-dep boundary:** HIGH — `if Code.ensure_loaded?(Oban.Worker) do` wrapping pattern verified in account_deletion.ex.
- **Credo custom check:** HIGH for the structural pattern (cited official docs); MEDIUM for the exact `Credo.Code.prewalk` arity (planner verifies against installed Credo 1.7.x in Plan 15-02).
- **`Sigra.Workers` greenfield:** HIGH — verified file does not exist via `ls`; the behaviour shape derives directly from D-18..D-24.
- **`.credo.exs` greenfield:** HIGH — verified file does not exist via `ls`.
- **Adapter branching:** HIGH — pattern verified in 4 existing template files; no separate `Sigra.Adapters` module exists.

**Research date:** 2026-04-12
**Valid until:** 2026-04-26 (14 days — Phase 15 is straightforward and no upstream surface area is moving rapidly)
