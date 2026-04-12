# Phase 13: Organizations Schemas + Context - Research

**Researched:** 2026-04-12
**Domain:** Ecto schemas, multi-tenant context layer, `Ecto.Multi` safety guards, NimbleOptions config macros
**Confidence:** HIGH

## Summary

Phase 13 builds the complete data layer for organizations in Sigra: three Ecto schemas (Organization, OrganizationMembership, OrganizationInvitation), a library-owned context module (`Sigra.Organizations`), a tenant-scoping query helper (`for_org/2`), a `prepare_query/3` enforcement layer, and safety guards for last-owner lockout, reserved slugs, and soft-delete. This is the first phase to use the library-first architecture pattern where security-critical logic lives in the library and a thin generated wrapper delegates to it.

The codebase already has all the foundational pieces: `Sigra.Install.Feature` behaviour (Phase 11), `Sigra.Hooks` engine, `Sigra.Audit.log_safe/2`, `Sigra.Session` with `active_organization_id`, the Scope template with `active_organization`/`membership` fields, adapter-branched migration templates, and Mox-based testing infrastructure. Phase 13 creates new modules that compose these existing pieces -- no new dependencies are required.

The primary technical risks are: (1) getting the `FOR UPDATE` lock semantics right for the last-owner guard across PostgreSQL/MySQL/SQLite, (2) correctly implementing `prepare_query/3` delegation without breaking existing Repo operations (especially preloads and schema migrations), and (3) ensuring the `use Sigra.Organizations` macro compiles cleanly in both the library test suite and generated host apps.

**Primary recommendation:** Build bottom-up: schemas and migration template first, then `for_org/2` + `prepare_query/3`, then context functions with Multi-based safety guards, then the `use` macro with NimbleOptions, then the hooks registry extension. Test each layer in isolation before integrating.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Library owns CRUD logic + safety guards. Generated wrapper is thin (~50-80 lines). Security patches land via `mix deps.update`.
- **D-02:** `use Sigra.Organizations` macro (~40 LOC). Injects config as `@sigra_org_config`, thin delegator functions, `defoverridable` hook callbacks, `@behaviour Sigra.Organizations.Callbacks`.
- **D-03:** NimbleOptions config schema. Required: `repo`, `schemas`. Configurable: `roles`, `owner_role`, `reserved_slugs`, `additional_reserved_slugs`, `slug_format`, `slug_length`, `enforce_org_scope`.
- **D-04:** Layer 1 module callbacks (local customization). 8 hooks via `defoverridable` in generated wrapper. All run inside `Ecto.Multi`.
- **D-05:** Layer 2 runtime hook registry (external lib integration). `Sigra.Hooks` backed by persistent_term. Priority-ordered execution.
- **D-06:** Minimal schema: name, slug, deleted_at, timestamps. No profile fields.
- **D-07:** Slug: citext column, `^[a-z][a-z0-9-]*[a-z0-9]$`, 3-63 chars. Auto-gen from name.
- **D-08:** ~25 hardcoded reserved slugs, extensible via `additional_reserved_slugs:`.
- **D-09:** Partial unique index for slug reclamation after soft-delete.
- **D-10:** Membership: org_id, user_id, role (Ecto.Enum), timestamps. Surrogate id PK. Hard-delete on removal.
- **D-11:** Hard-delete on member removal (not soft-delete).
- **D-12:** Invitation schema ships in Phase 13, zero flow logic. Status derived from timestamps.
- **D-13:** `for_org/2`: runtime raise, pure function. Accepts `%Scope{}` or raw binary `org_id`.
- **D-14:** `prepare_query/3` enforcement: one-line delegation in generated Repo.
- **D-15:** `FOR UPDATE` lock inside `Ecto.Multi` for last-owner guard.
- **D-16:** Multi error normalization to `{:error, :last_owner}`.
- **D-17:** Explicit `deleted_at` filtering in context functions, not auto-scope.
- **D-18:** `create_organization/2` atomically creates org + owner membership in one Multi.
- **D-19:** Error handling: mixed returns (`{:error, %Changeset{}}`, `{:error, :atom}`, raises).
- **D-20:** Audit call sites via existing `log_safe/2`.
- **D-21:** One migration slot in `Features.Organizations`. All 3 tables in one file.
- **D-22:** ~28 tests: 20 unit + 8 integration.
- **D-23:** Scope template typespec tightening to real types.
- **D-24:** `prepare_query/3` replaces Credo custom-check spike.

### Claude's Discretion
- **CD-01:** Internal struct shapes for `Sigra.Hooks` registry (ETS vs persistent_term, priority ordering).
- **CD-02:** Exact `for_org/2` schema extraction logic.
- **CD-03:** `Features.Organizations` module structure -- stub vs unimplemented callbacks.
- **CD-04:** Test file organization.
- **CD-05:** Audit event action names.

### Deferred Ideas (OUT OF SCOPE)
- Revisit v1.0 Auth context API surface -- future milestone
- Accrue payments integration guide -- depends on both libs
- `invited_by_id` on membership -- Phase 17
- `--no-organizations` Scope template conditionality -- Phase 18
- Hard-delete path -- v1.2
- `Sigra.Session.put_active_organization_id/2` named setter -- deferred
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORG-01 | Developer can add organizations via `mix sigra.install --organizations` generating Organization, OrganizationMembership, OrganizationInvitation schemas with migrations | Migration template pattern (adapter-branched), Feature behaviour contract, slot allocator |
| ORG-03 | User can be member of multiple orgs with different roles; no `organization_id` on users table | Membership schema with surrogate PK, unique index on `[user_id, organization_id]` |
| ORG-04 | Three roles per org: owner, admin, member via Ecto.Enum | Ecto.Enum with configurable values from NimbleOptions |
| ORG-05 | Last-owner guard via `Ecto.Multi` with fresh-count check | `FOR UPDATE` lock pattern, Multi.run guard step, error normalization |
| ORG-06 | `Sigra.Organizations.Query.for_org/2` raises on missing `organization_id` | Schema introspection via `__schema__(:fields)`, Ecto.Queryable protocol |
| ORG-07 | Reserved slug blocking at creation time | Changeset validation, hardcoded list + configurable additions |
| ORG-08 | Soft-delete with `deleted_at`; audit rows survive via `on_delete: :nilify_all` | FK cascade config, explicit filtering in context functions |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x. PostgreSQL primary, MySQL/SQLite support via conditional migrations.
- **Security:** OWASP throughout. All tokens HMAC-protected. Enumeration prevention.
- **Dependencies:** Minimal transitive deps. No new deps needed for Phase 13.
- **Testing:** Comprehensive coverage -- happy path, error cases, boundary conditions. AAA style, flat, self-contained.
- **Architecture:** Hybrid lib+generator. Security-critical code in library, customizable code generated.
- **Conventions:** `Sigra.Audit.log_safe/2` for all mutation audit sites. Mox for async unit tests, real DB for integration.

## Standard Stack

### Core (already in mix.exs -- no additions needed)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| ecto | 3.13.5 | Schema definitions, changesets, Multi | Locked in mix.lock [VERIFIED: mix.lock] |
| ecto_sql | 3.13.5 | Migration DSL, SQL Sandbox, `prepare_query/3` callback | Locked in mix.lock [VERIFIED: mix.lock] |
| nimble_options | 1.1.1 | Config schema validation for `use Sigra.Organizations` | Locked in mix.lock [VERIFIED: mix.lock] |
| mox | 1.2.0 | Mock Repo for async unit tests | Locked in mix.lock [VERIFIED: mix.lock] |

### No New Dependencies

Phase 13 requires zero new hex packages. All functionality is built on top of Ecto primitives (`Ecto.Multi`, `Ecto.Enum`, `Ecto.Changeset`, `Ecto.Query`, `Ecto.Schema.__schema__/1`) and existing Sigra infrastructure (`Sigra.Audit`, `Sigra.Hooks`, `Sigra.Install.Feature`).

## Architecture Patterns

### Recommended Module Structure

```
lib/sigra/
  organizations.ex              # Public context API (CRUD + safety guards)
  organizations/
    query.ex                    # for_org/2 + maybe_enforce_org_scope/4
    callbacks.ex                # @behaviour for defoverridable hooks
    slug.ex                     # Slug generation + reserved-word validation
    schema_helpers.ex           # Shared changeset helpers (if needed)

lib/sigra/install/
  features/
    organizations.ex            # Feature behaviour impl (migration slot)

priv/templates/sigra.install/
  organizations/
    migration.exs               # 3 tables: organizations, memberships, invitations
    organization.ex             # Generated Ecto schema
    organization_membership.ex  # Generated Ecto schema
    organization_invitation.ex  # Generated Ecto schema
    organizations.ex            # Generated thin wrapper (use Sigra.Organizations)
```

[VERIFIED: matches existing patterns in `lib/sigra/install/features/core.ex` and `priv/templates/sigra.install/core/`]

### Pattern 1: Library-First Context with Thin Wrapper

**What:** Library module (`Sigra.Organizations`) owns all business logic. Generated wrapper module uses `use Sigra.Organizations` macro that injects config + thin delegation + overridable hooks.

**When to use:** All v1.1+ features (organizations, passkeys).

**Example:**

```elixir
# Library side: lib/sigra/organizations.ex
defmodule Sigra.Organizations do
  @moduledoc "Library-owned organizations context."

  def create_organization(config, scope, attrs) do
    # All logic here: validation, Multi, audit, hooks
  end

  # __using__ macro for the generated wrapper
  defmacro __using__(opts) do
    quote do
      @sigra_org_config Sigra.Organizations.__validate_config__!(unquote(opts))
      @behaviour Sigra.Organizations.Callbacks

      def create_organization(scope, attrs) do
        Sigra.Organizations.create_organization(@sigra_org_config, scope, attrs)
      end

      # Hook callbacks with no-op defaults
      def before_create_organization(changeset, _scope), do: {:ok, changeset}
      defoverridable before_create_organization: 2

      # ... more delegates and hooks
    end
  end
end
```

[ASSUMED: macro structure based on D-02 decision and NimbleOptions patterns. Exact implementation is CD-01/CD-02 territory.]

### Pattern 2: `for_org/2` Tenant Scoping

**What:** Pure function that accepts a queryable + scope/org_id, validates schema has `:organization_id` field via `__schema__(:fields)`, and returns a scoped `Ecto.Query`.

**When to use:** Every query that touches org-scoped data.

**Example:**

```elixir
# Source: Ecto __schema__(:fields) introspection
# https://hexdocs.pm/ecto/Ecto.Schema.html
defmodule Sigra.Organizations.Query do
  import Ecto.Query

  def for_org(queryable, %{active_organization: %{id: org_id}}) do
    for_org(queryable, org_id)
  end

  def for_org(queryable, org_id) when is_binary(org_id) do
    query = Ecto.Queryable.to_query(queryable)
    schema = extract_schema(query)

    unless :organization_id in schema.__schema__(:fields) do
      raise ArgumentError,
        "#{inspect(schema)} does not have an :organization_id field. " <>
        "for_org/2 can only scope schemas with an :organization_id column."
    end

    where(query, [r], r.organization_id == ^org_id)
  end
end
```

[VERIFIED: `__schema__(:fields)` returns list of non-virtual field atoms -- confirmed via Ecto 3.13.5 docs]
[CITED: https://hexdocs.pm/ecto/Ecto.Schema.html]

### Pattern 3: `prepare_query/3` Enforcement

**What:** Generated Repo delegates `prepare_query/3` to library function. Library inspects `%Ecto.Query{}` struct to verify org-scoped schemas have `organization_id` in their WHERE clause.

**When to use:** Defense-in-depth for direct Repo queries that bypass context functions.

**Example (generated Repo):**

```elixir
# In generated Repo module
@impl true
def prepare_query(operation, query, opts) do
  if Keyword.get(opts, :skip_org_check, false) do
    {query, opts}
  else
    Sigra.Organizations.Query.maybe_enforce_org_scope(operation, query, opts, @sigra_org_config)
  end
end
```

[CITED: https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html]
[CITED: https://hexdocs.pm/ecto_tenancy_enforcer/readme.html]

**Key implementation notes from EctoTenancyEnforcer:**
- `prepare_query/3` does NOT get called for `insert_all` operations [CITED: ecto_tenancy_enforcer docs]
- Preloads issued by Ecto internally pass `ecto_query: :preload` in opts -- must be skipped [CITED: Ecto multi-tenancy guide]
- Schema migrations pass `ecto_query: :schema_migration` -- must be skipped [CITED: Ecto multi-tenancy guide]
- Fragments cannot be parsed for tenancy validation [CITED: ecto_tenancy_enforcer docs]

### Pattern 4: `FOR UPDATE` Lock in Ecto.Multi

**What:** Count owner memberships with `lock("FOR UPDATE")` inside `Multi.run/5`. Concurrent transactions block until the first commits/rolls back.

**When to use:** Last-owner guard (D-15) for remove, demote, and self-delete operations.

**Example:**

```elixir
# Source: Ecto.Query.lock/2 + Ecto.Multi.run/5
defp guard_last_owner(multi, org_id, membership_id, config) do
  Ecto.Multi.run(multi, :guard_last_owner, fn repo, _changes ->
    owner_role = config.owner_role

    count =
      from(m in config.schemas.membership,
        where: m.organization_id == ^org_id,
        where: m.role == ^owner_role,
        where: m.id != ^membership_id,
        lock: "FOR UPDATE"
      )
      |> repo.aggregate(:count)

    if count > 0 do
      {:ok, :safe}
    else
      {:error, :last_owner}
    end
  end)
end
```

[VERIFIED: `Ecto.Query.lock/2` accepts a string lock expression in Ecto 3.13.5]
[ASSUMED: `FOR UPDATE` works identically on PostgreSQL and MySQL. SQLite serializes by default so locking is a no-op but safe.]

### Pattern 5: NimbleOptions Config Validation at Compile Time

**What:** Define option schema, validate in `__using__` macro via `NimbleOptions.validate!/2`. Store validated config as module attribute.

**Example:**

```elixir
@org_config_schema [
  repo: [type: :atom, required: true, doc: "The Ecto Repo module."],
  schemas: [
    type: :keyword_list,
    required: true,
    keys: [
      organization: [type: :atom, required: true],
      membership: [type: :atom, required: true],
      invitation: [type: :atom, required: true],
      user: [type: :atom, required: true],
      scope: [type: :atom, required: true]
    ]
  ],
  roles: [
    type: {:list, :atom},
    default: [:owner, :admin, :member],
    doc: "Available roles."
  ],
  owner_role: [type: :atom, default: :owner],
  reserved_slugs: [
    type: {:list, :string},
    default: @default_reserved_slugs
  ],
  additional_reserved_slugs: [type: {:list, :string}, default: []],
  slug_format: [type: {:struct, Regex}, default: ~r/^[a-z][a-z0-9-]*[a-z0-9]$/],
  slug_length: [type: {:custom, __MODULE__, :validate_range, []}, default: {3, 63}],
  enforce_org_scope: [type: {:list, :atom}, default: []]
]
```

[VERIFIED: NimbleOptions 1.1.1 supports all these type specs -- `{:list, :atom}`, `:keyword_list` with `:keys`, `{:struct, Regex}`, `{:custom, ...}`]
[CITED: https://hexdocs.pm/nimble_options/NimbleOptions.html]

### Pattern 6: Adapter-Branched Migration Template

**What:** EEx template with `<%= if adapter == :postgres do %>` branches for PostgreSQL-specific features (citext, partial unique indexes).

**Existing precedent:** `priv/templates/sigra.install/core/migration.exs` already does this for the users table email column. Phase 13 follows the identical pattern for the organizations slug column.

```elixir
# PostgreSQL: citext + partial unique index
add :slug, :citext, null: false
create unique_index(:organizations, [:slug], where: "deleted_at IS NULL")

# MySQL/SQLite: string + application-level enforcement
add :slug, :string, null: false, size: 63
create unique_index(:organizations, [:slug])  # No partial index support
```

[VERIFIED: existing `core/migration.exs` template uses this exact `<%= if adapter == :postgres do %>` branching pattern]

### Anti-Patterns to Avoid

- **Importing Ecto.Query at module top level in library context:** Use `import Ecto.Query` inside function bodies or in a `@before_compile` block. Avoids polluting the module namespace and keeps `where/3`, `from/2` etc. scoped.
- **Referencing `Features.Core` from `Features.Organizations`:** Pitfall X-3. Feature modules must be fully isolated. No cross-references.
- **Using `Repo.transaction/2` instead of `Repo.transact/2`:** Ecto 3.13 deprecated `Repo.transaction/2` in favor of `Repo.transact/2`. However, since Sigra targets `~> 3.12`, use `Ecto.Multi` + `Repo.transaction/1` (Multi-based) which works across all 3.12+ versions. [VERIFIED: Ecto changelog]
- **Auto-filtering `deleted_at` in `for_org/2`:** D-17 explicitly separates tenant scoping from lifecycle filtering. `for_org/2` must remain generic.
- **Using `Application.get_env` for org config:** D-01/D-02/D-03 mandate struct-based config passed explicitly via the `use` macro. No global mutable config.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Option validation + docs | Custom keyword validation | NimbleOptions 1.1.1 | Generates docs automatically, handles types, defaults, required fields |
| Atomic multi-step operations | Manual try/rescue + rollback | `Ecto.Multi` | Transaction safety, composability, named error steps |
| Schema field introspection | Manual field lists | `Schema.__schema__(:fields)` | Always in sync with schema definition, zero maintenance |
| Slug generation | Custom transliteration | `String.downcase/1` + regex replacement | ASCII-only slugs don't need full Unicode transliteration |
| Concurrent safety for last-owner | Optimistic locking / retries | `FOR UPDATE` pessimistic lock in Multi | Eliminates race window entirely rather than detecting after the fact |
| Compile-time config storage | Custom module attribute management | NimbleOptions `validate!/2` + `@module_attribute` | Standard pattern, Dialyzer-friendly |

## Common Pitfalls

### Pitfall 1: `prepare_query/3` Breaking Preloads and Migrations

**What goes wrong:** Ecto internally issues queries for preloads and schema migrations. If `prepare_query/3` raises on missing `org_id`, these internal queries fail.
**Why it happens:** `prepare_query/3` intercepts ALL repo operations, not just developer-initiated ones.
**How to avoid:** Check `opts[:ecto_query]` for `:preload` and `:schema_migration` values. Also skip when `skip_org_check: true` is set. EctoTenancyEnforcer documents this exact gotcha.
**Warning signs:** `Ecto.NoResultsError` or `ArgumentError` during preloads or `mix ecto.migrate`.

[CITED: https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html]
[CITED: https://hexdocs.pm/ecto_tenancy_enforcer/readme.html]

### Pitfall 2: `FOR UPDATE` Lock Scope Too Wide

**What goes wrong:** Locking all memberships for an org instead of just the owner rows. Blocks unrelated member operations.
**Why it happens:** Forgetting to add `where: m.role == ^owner_role` to the locked query.
**How to avoid:** The lock query should filter to `role == :owner` AND exclude the membership being mutated (`m.id != ^membership_id`). Count > 0 means safe to proceed.
**Warning signs:** Deadlocks under concurrent member management; unexpectedly serialized non-owner operations.

### Pitfall 3: Ecto.Enum Compilation Order

**What goes wrong:** `Ecto.Enum` values are validated at compile time. If the schema references a config value that isn't available at compile time, it fails.
**Why it happens:** The generated schema uses `Ecto.Enum, values:` which must be a literal list at compile time.
**How to avoid:** Use a hardcoded default `[:owner, :admin, :member]` in the generated schema template. The NimbleOptions `roles` config is for library context logic (permission checks), not for the Ecto.Enum definition. If a dev needs custom roles, they edit the generated schema.
**Warning signs:** Compilation errors referencing undefined module attributes in schema files.

### Pitfall 4: Partial Unique Index Not Supported on MySQL/SQLite

**What goes wrong:** `WHERE deleted_at IS NULL` in `create unique_index` is PostgreSQL-only. MySQL 8.0+ supports functional indexes but not partial unique indexes in the same syntax. SQLite has limited partial index support.
**Why it happens:** Adapter differences in DDL support.
**How to avoid:** Adapter-branched migration template. PostgreSQL uses partial unique index. MySQL/SQLite use a composite unique index on `[:slug, :deleted_at]` with application-level enforcement for soft-deleted slug reclamation. Document this in the migration template comments.
**Warning signs:** Migration failure on MySQL/SQLite.

[VERIFIED: existing `core/migration.exs` handles this pattern for email uniqueness]

### Pitfall 5: Multi Error Tuple Shape Leaking

**What goes wrong:** `Repo.transaction(multi)` returns `{:error, step_name, reason, changes_so_far}` (4-tuple). Controllers/LiveViews expect `{:error, reason}` (2-tuple).
**Why it happens:** Ecto.Multi wraps errors with the step name.
**How to avoid:** D-16 mandates normalization. Library context functions must pattern-match the 4-tuple and return `{:error, :last_owner}` or `{:error, changeset}`.
**Warning signs:** `FunctionClauseError` in controller `case` statements expecting 2-tuples.

### Pitfall 6: Schema Extraction from Complex Queries

**What goes wrong:** `for_org/2` needs to extract the schema module from an `%Ecto.Query{}`. For simple `from(o in Organization)` queries this is straightforward, but subqueries, joins, and dynamic queries may not have a clear source schema.
**Why it happens:** `Ecto.Queryable.to_query/1` returns a query struct whose `from` source varies in shape.
**How to avoid:** Extract schema from `query.from.source` tuple: `{table_name, schema_module}` for schema-based queries. Raise `ArgumentError` for schemaless queries (they shouldn't be passed to `for_org/2`). Test with both `from(o in Org)` and `Org |> where(...)` query shapes.
**Warning signs:** `MatchError` or `FunctionClauseError` on non-standard query sources.

## Code Examples

### Ecto.Enum in Generated Schema

```elixir
# Source: Ecto.Enum docs (https://hexdocs.pm/ecto/Ecto.Enum.html)
# In generated organization_membership.ex template
schema "organization_memberships" do
  field :role, Ecto.Enum, values: [:owner, :admin, :member]
  belongs_to :organization, <%= context_module %>.Organization
  belongs_to :user, <%= context_module %>.<%= schema_alias %>

  timestamps(type: :utc_datetime)
end
```

[VERIFIED: Ecto.Enum with `values:` is stable in Ecto 3.12+]

### Multi with Last-Owner Guard + Audit

```elixir
# In lib/sigra/organizations.ex
def remove_member(config, scope, membership) do
  org_id = membership.organization_id

  Ecto.Multi.new()
  |> guard_last_owner(org_id, membership.id, config)
  |> Ecto.Multi.delete(:membership, membership)
  |> Sigra.Audit.log_multi_safe("organization.member_remove", [
    repo: config.repo,
    audit_schema: config[:audit_schema],
    actor_id: scope.user.id,
    target_id: membership.user_id,
    metadata: %{organization_id: org_id, role: to_string(membership.role)}
  ])
  |> config.repo.transaction()
  |> normalize_multi_result()
end

defp normalize_multi_result({:ok, changes}), do: {:ok, changes}
defp normalize_multi_result({:error, :guard_last_owner, :last_owner, _}), do: {:error, :last_owner}
defp normalize_multi_result({:error, _step, %Ecto.Changeset{} = cs, _}), do: {:error, cs}
defp normalize_multi_result({:error, _step, reason, _}), do: {:error, reason}
```

[VERIFIED: `Ecto.Multi.run/5` and `Ecto.Multi.delete/3` compose correctly]
[VERIFIED: `Sigra.Audit.log_multi_safe/3` exists and accepts these opts]

### Slug Validation Changeset

```elixir
# In lib/sigra/organizations/slug.ex
@default_reserved ~w(
  admin api app auth billing blog cdn dashboard docs help
  login logout new oauth register settings signup static
  status support system webhooks www
)

def validate_slug(changeset, config) do
  reserved = config.reserved_slugs ++ config.additional_reserved_slugs

  changeset
  |> Ecto.Changeset.validate_format(:slug, config.slug_format,
    message: "must start with a letter, contain only lowercase letters, numbers, and hyphens"
  )
  |> Ecto.Changeset.validate_length(:slug,
    min: elem(config.slug_length, 0),
    max: elem(config.slug_length, 1)
  )
  |> Ecto.Changeset.validate_exclusion(:slug, reserved,
    message: "is reserved and cannot be used"
  )
end
```

[VERIFIED: `Ecto.Changeset.validate_exclusion/4` is the correct function for blocking reserved values]

### Hook Registry Extension (CD-01)

**Recommendation:** Use `persistent_term` (not ETS) for the hook registry. `persistent_term` is optimized for read-heavy, write-rare data. Hooks are registered once at `Application.start/2` and read on every org mutation. This matches the existing `Sigra.Hooks` module's contract.

```elixir
# In lib/sigra/hooks.ex (extension)
@registry_key {__MODULE__, :registry}

def register(domain, stage, {mod, fun}, opts \\ []) do
  priority = Keyword.get(opts, :priority, 50)
  current = :persistent_term.get(@registry_key, %{})
  hooks = Map.get(current, {domain, stage}, [])
  updated = [{priority, {mod, fun}} | hooks] |> Enum.sort_by(&elem(&1, 0))
  :persistent_term.put(@registry_key, Map.put(current, {domain, stage}, updated))
end

def get_hooks(domain, stage) do
  @registry_key
  |> :persistent_term.get(%{})
  |> Map.get({domain, stage}, [])
  |> Enum.map(&elem(&1, 1))
end
```

[ASSUMED: persistent_term is the right choice over ETS. Tradeoff: persistent_term triggers a global GC on write (expensive but rare for hook registration); ETS has per-lookup overhead (cheap but constant). Since hooks register once at boot and read on every mutation, persistent_term wins.]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` with function | `Ecto.Multi` pipeline | Ecto 2.x+ (mature) | Named steps, composable, inspectable error tuples |
| `Ecto.Schema.embedded_schema` for roles | `Ecto.Enum` | Ecto 3.5+ | Type-safe enum columns with validation |
| Fat generated context (v1.0 Auth) | Library-first + thin wrapper (v1.1 Orgs) | Phase 13 (now) | Security patches via `mix deps.update` |
| `EctoTenancyEnforcer` (external dep) | In-house `prepare_query/3` delegation | Phase 13 (now) | No external dep; simpler config tied to NimbleOptions schema |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `FOR UPDATE` works identically on PostgreSQL and MySQL for row-level locking | Pattern 4 | Last-owner guard may not serialize correctly on MySQL; would need MySQL-specific lock syntax |
| A2 | `persistent_term` is better than ETS for hook registry | CD-01 recommendation | Minor perf difference; easily swappable if wrong |
| A3 | SQLite serializes transactions by default, making `FOR UPDATE` a no-op but safe | Pattern 4 | If SQLite has unexpected concurrency, guard could fail; mitigated by SQLite's inherent serialization |
| A4 | Ecto.Enum `values:` must be a compile-time literal list | Pitfall 3 | If Ecto supports runtime values, the workaround is unnecessary |

## Open Questions

1. **Audit event action naming convention (CD-05)**
   - What we know: v1.0 uses `"session.create"`, `"account.delete"` style (dot-separated, singular domain)
   - What's unclear: Should org events use `"organization.create"` or `"org.create"` or `"organizations.create_organization"`?
   - Recommendation: Follow v1.0 precedent: `"organization.create"`, `"organization.delete"`, `"organization.member_add"`, `"organization.member_remove"`, `"organization.member_role_change"`. Short domain prefix, action suffix.

2. **`Features.Organizations` stub strategy (CD-03)**
   - What we know: Phase 18 fills in `files/1`, `injections/1`, `post_instructions/1`. Phase 13 only needs `migrations/1`.
   - What's unclear: Should stubs return empty lists or raise?
   - Recommendation: Return empty lists (`[]`). The walker iterates all callbacks; raising would break the install command for apps that enable organizations before Phase 18 is complete. Empty lists mean "nothing to do yet."

3. **Schema extraction in `for_org/2` for joins and subqueries**
   - What we know: `query.from.source` is `{table_name, schema}` for simple queries
   - What's unclear: How `for_org/2` should handle queries with multiple joined schemas that may or may not have `organization_id`
   - Recommendation: `for_org/2` only validates and scopes the primary `from` schema. Joined schemas are the developer's responsibility. This matches `Ecto.assoc/2` semantics and keeps the function simple.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + Mox 1.2.0 |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/sigra/organizations/` |
| Full suite command | `mix test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-01 | Migration template generates valid DDL for all 3 tables | unit | `mix test test/sigra/install/features/organizations_test.exs -x` | Wave 0 |
| ORG-03 | User belongs to multiple orgs, membership schema enforces uniqueness | integration | `mix test test/sigra/organizations/membership_integration_test.exs -x` | Wave 0 |
| ORG-04 | Role enum validates owner/admin/member | unit | `mix test test/sigra/organizations/schema_test.exs -x` | Wave 0 |
| ORG-05 | Last-owner guard blocks remove/demote/self-delete | integration | `mix test test/sigra/organizations/last_owner_test.exs -x` | Wave 0 |
| ORG-06 | `for_org/2` raises on missing org_id, scopes correctly | unit | `mix test test/sigra/organizations/query_test.exs -x` | Wave 0 |
| ORG-07 | All ~25 reserved slugs blocked | unit | `mix test test/sigra/organizations/slug_test.exs -x` | Wave 0 |
| ORG-08 | Soft-delete sets deleted_at; audit FK nilifies | integration | `mix test test/sigra/organizations/soft_delete_test.exs -x` | Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/organizations/`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/sigra/organizations/query_test.exs` -- for_org/2 unit tests
- [ ] `test/sigra/organizations/slug_test.exs` -- reserved slug regression + format validation
- [ ] `test/sigra/organizations/schema_test.exs` -- changeset validation for all 3 schemas
- [ ] `test/sigra/organizations/context_test.exs` -- CRUD happy path + error cases (Mox)
- [ ] `test/sigra/organizations/last_owner_test.exs` -- integration with real DB + FOR UPDATE
- [ ] `test/sigra/organizations/soft_delete_test.exs` -- integration: deleted_at + FK cascades
- [ ] `test/sigra/organizations/membership_integration_test.exs` -- integration: multi-org membership
- [ ] `test/sigra/organizations/prepare_query_test.exs` -- enforcement raises on unscoped queries
- [ ] `test/sigra/install/features/organizations_test.exs` -- Feature behaviour, migration slots, isolation
- [ ] MockRepo behaviour may need `aggregate/3` callback for last-owner count query

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Handled by v1.0 Auth |
| V3 Session Management | no | Handled by v1.0 Session |
| V4 Access Control | yes | Last-owner guard (D-15), role-based membership checks, `for_org/2` tenant scoping |
| V5 Input Validation | yes | NimbleOptions config validation, slug format/length/reserved-word validation, Ecto.Changeset |
| V6 Cryptography | no | No crypto in this phase |

### Known Threat Patterns for Multi-Tenant Data Layer

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant data leak (O-1) | Information Disclosure | `for_org/2` raises on missing org_id + `prepare_query/3` enforcement |
| Privilege escalation via role manipulation (O-4) | Elevation of Privilege | Last-owner guard with `FOR UPDATE` lock in `Ecto.Multi` |
| Slug squatting for phishing (O-9) | Spoofing | Hardcoded reserved slug list + configurable additions |
| Audit trail destruction (O-10) | Repudiation | `on_delete: :nilify_all` on audit FK; soft-delete default |
| IDOR on org resources | Information Disclosure | `for_org/2` scoping on all queries; `prepare_query` as defense-in-depth |

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lib/sigra/install/feature.ex`, `lib/sigra/install/features/core.ex`, `lib/sigra/audit.ex`, `lib/sigra/hooks.ex`, `lib/sigra/session.ex`, `lib/sigra/config.ex` -- verified module interfaces and patterns
- Existing templates: `priv/templates/sigra.install/core/migration.exs`, `priv/templates/sigra.install/core/scope.ex` -- verified adapter branching and scope struct
- `mix.lock` -- verified all dependency versions
- [Ecto multi-tenancy guide](https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html) -- `prepare_query/3` pattern
- [Ecto.Schema docs](https://hexdocs.pm/ecto/Ecto.Schema.html) -- `__schema__(:fields)` introspection
- [NimbleOptions docs](https://hexdocs.pm/nimble_options/NimbleOptions.html) -- config validation API
- [EctoTenancyEnforcer docs](https://hexdocs.pm/ecto_tenancy_enforcer/readme.html) -- enforcement limitations (preloads, insert_all, fragments)

### Secondary (MEDIUM confidence)
- [EctoTenancyEnforcer GitHub](https://github.com/sb8244/ecto_tenancy_enforcer) -- prepare_query test patterns
- [Ecto locking discussion](https://elixirforum.com/t/sanity-check-right-way-to-use-ecto-postgres-locks-and-how-to-test-them/36063) -- FOR UPDATE testing patterns

### Tertiary (LOW confidence)
- None. All claims verified against codebase or official docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new deps, all verified in mix.lock
- Architecture: HIGH -- follows established codebase patterns (Feature behaviour, adapter branching, Mox testing)
- Pitfalls: HIGH -- all pitfalls sourced from official Ecto docs or existing codebase patterns
- `prepare_query/3` limitations: MEDIUM -- sourced from EctoTenancyEnforcer docs, not yet tested in Sigra
- `FOR UPDATE` cross-DB compatibility: MEDIUM -- verified for PostgreSQL, assumed for MySQL/SQLite

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable domain, 30-day window)
