---
phase: 15-audit-integration
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs
  - priv/templates/sigra.install/core/audit_event.ex
  - lib/sigra/audit.ex
  - lib/sigra/audit/changeset.ex
  - lib/sigra/audit/query.ex
  - lib/sigra/scope.ex
  - lib/sigra/auth.ex
  - lib/sigra/mfa.ex
  - lib/sigra/account.ex
  - lib/sigra/oauth.ex
  - lib/sigra/api_token.ex
  - lib/sigra/lockout.ex
  - lib/sigra/suspicious_login.ex
  - lib/sigra/plug/load_active_organization.ex
  - test/support/audit_test_event.ex
  - test/sigra/audit/log_safe_scope_test.exs
  - test/sigra/audit/query_filters_test.exs
  - test/sigra/audit/query_index_test.exs
  - test/sigra/scope/build_test.exs
  - test/sigra/testing/assert_audit_logged_test.exs
autonomous: true
requirements:
  - AUD-01
  - AUD-02
  - AUD-03
  - AUD-05

must_haves:
  truths:
    - "Fresh v1.1 installs get real indexed organization_id + effective_user_id columns on audit_events via a standalone ALTER migration"
    - "Every audit emission in lib/sigra/** goes through a single public entry point Sigra.Audit.log_safe/3 with scope as the second positional argument"
    - "Sigra.Audit.Query rejects unknown filter keys with ArgumentError instead of silently ignoring typos"
    - "Sigra.Scope.build/3 exists as the library-side constructor used by both login-time scope synthesis and worker reference implementation"
    - "Every existing log_safe/2 call site in lib/sigra/** has been mechanically rewritten to log_safe(action, nil, opts)"
  artifacts:
    - path: "priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs"
      provides: "ALTER migration template adding organization_id + effective_user_id + composite index"
      contains: "alter table(:audit_events)"
    - path: "lib/sigra/audit.ex"
      provides: "log_safe/3 public API + log_safe/2 shim + private scope_fields/1"
      contains: "def log_safe(action, scope, opts)"
    - path: "lib/sigra/audit/changeset.ex"
      provides: "@cast_fields extended with :organization_id + :effective_user_id"
      contains: ":organization_id"
    - path: "lib/sigra/audit/query.ex"
      provides: ":organization_id, :effective_user_id, :organization_scope filters + unknown-key raise"
      contains: "raise ArgumentError"
    - path: "lib/sigra/scope.ex"
      provides: "Sigra.Scope.build/3 library constructor"
      contains: "def build(scope_module"
    - path: "priv/templates/sigra.install/core/audit_event.ex"
      provides: "Schema template with two new field declarations"
      contains: "field :organization_id"
  key_links:
    - from: "lib/sigra/audit.ex"
      to: "lib/sigra/audit/changeset.ex"
      via: "build_attrs/4 -> changeset_opts/2 -> @cast_fields"
      pattern: "build_attrs"
    - from: "lib/sigra/**"
      to: "Sigra.Audit.log_safe/3"
      via: "mechanical sweep replacing /2 with /3 form"
      pattern: "Audit\\.log_safe\\([^,]+, nil,"
---

<objective>
Lay the schema, helper, and query foundation for Phase 15 and mechanically rewrite every existing audit call site in lib/sigra/** to the new 3-arity form.

Purpose: This is the pure-mechanical, trivially-reviewable foundation plan locked by D-25. It creates the ALTER migration, adds the two new columns to the audit changeset + schema template, introduces Sigra.Audit.log_safe/3 with private scope_fields/1, adds the three new query filters with strict whitelist validation, creates Sigra.Scope.build/3, and performs the 79-site find-and-replace sweep. No semantic enrichment happens here — Plan 15-02 replaces the placeholder `nil` scopes with real ones.

Output: ALTER migration template, updated schema/changeset, new log_safe/3 API, extended Query, new Sigra.Scope module, all 79 existing call sites migrated to /3 with nil scope placeholder, and the Wave 0 test scaffold for `assert_audit_logged/2` (used by Plan 15-02 Task 3).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@.planning/phases/15-audit-integration/15-CONTEXT.md
@.planning/phases/15-audit-integration/15-RESEARCH.md
@.planning/phases/15-audit-integration/15-VALIDATION.md
@.planning/phases/13-organizations-schemas-context/13-CONTEXT.md
@.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md

@lib/sigra/audit.ex
@lib/sigra/audit/changeset.ex
@lib/sigra/audit/query.ex
@lib/sigra/scope/hydration.ex
@priv/templates/sigra.install/core/audit_event.ex
@priv/templates/sigra.install/core/create_audit_events.exs

<interfaces>
<!-- These are the key contracts Plan 15-01 establishes. Executors for 15-02/15-03 read against these. -->

Sigra.Audit public API after 15-01:

```elixir
# New primary API (scope as 2nd positional arg per D-01)
@spec log_safe(action :: String.t(), scope :: term() | nil, opts :: keyword()) :: :ok
def log_safe(action, scope, opts)

# Shim kept for backwards compatibility (D-02)
@spec log_safe(action :: String.t(), opts :: keyword()) :: :ok
def log_safe(action, opts), do: log_safe(action, nil, opts)

# Private duck-typed helper (D-03..D-06) — NOT public per D-05
# Returns keyword list that is prepended to opts (caller wins on conflict per D-06)
defp scope_fields(nil), do: [organization_id: nil, effective_user_id: nil, actor_id: nil]
defp scope_fields(%{user: user, active_organization: org}) do
  [
    organization_id: org && org.id,
    effective_user_id: user && user.id,  # D-04: v1.2 one-line diff point
    actor_id: user && user.id
  ]
end
```

Sigra.Scope module (NEW — lib/sigra/scope.ex):

```elixir
defmodule Sigra.Scope do
  @moduledoc "Library-side scope constructors. Host Scope struct is generated into the app."

  @spec build(scope_module :: module(), user :: struct() | nil, opts :: keyword()) :: struct()
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

Sigra.Audit.Query new filter contract (D-15):
- `:organization_id` — strict equality; nil means IS NULL
- `:effective_user_id` — strict equality; nil means IS NULL
- `:organization_scope` — `{:only, org_id}` or `{:including_global, org_id}`
- Unknown filter keys raise ArgumentError (breaking change vs v1.0 silent-ignore)

Audit schema cast_fields after 15-01:
Existing list gains `:organization_id, :effective_user_id` (top-level, NOT nested in :metadata per D-07).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 0 (Wave 0): Test scaffolds + test audit schema extension + assert_audit_logged test stub</name>
  <files>
    test/support/audit_test_event.ex,
    test/sigra/audit/log_safe_scope_test.exs,
    test/sigra/audit/query_filters_test.exs,
    test/sigra/audit/query_index_test.exs,
    test/sigra/scope/build_test.exs,
    test/sigra/testing/assert_audit_logged_test.exs
  </files>
  <read_first>
    - test/support/audit_test_event.ex (existing test schema)
    - .planning/phases/15-audit-integration/15-VALIDATION.md (Wave 0 Requirements section, lines 52-67)
    - .planning/phases/15-audit-integration/15-CONTEXT.md (D-01..D-07, D-15, D-23, D-31)
    - .planning/phases/15-audit-integration/15-02-semantic-workers-credo-PLAN.md frontmatter `deviations` field (explains the D-31 signature refinement — `(map, keyword)` not `(repo, fields)`)
    - lib/sigra/audit/changeset.ex (existing @cast_fields shape)
    - lib/sigra/testing.ex lines 1100-1200 (existing `assert_audit_event/2` at line 1150 — the shape the new `assert_audit_logged/2` will wrap)
  </read_first>
  <action>
    1. Edit `test/support/audit_test_event.ex`: add `field :organization_id, :binary_id` and `field :effective_user_id, :binary_id` to the schema block. Do not change anything else.

    2. Create `test/sigra/audit/log_safe_scope_test.exs` with 4 failing test stubs (use `@tag :skip` so suite stays green until 15-01 implements):
       - `test "log_safe/3 with nil scope writes nil organization_id + nil effective_user_id"`
       - `test "log_safe/3 with full scope writes organization_id from scope.active_organization.id and effective_user_id from scope.user.id"`
       - `test "log_safe/3 duck-types scope on %{user, active_organization, impersonating_from} keys (no Sigra.Scope struct match)"`
       - `test "log_safe/3 caller-supplied :organization_id in opts wins over scope-derived value (D-06 caller-wins merge)"`
       Each test should call `Sigra.Audit.log_safe("test.event", scope, repo: TestRepo, audit_schema: AuditTestEvent, metadata: %{})` and use a direct `TestRepo.one(from a in AuditTestEvent, order_by: [desc: a.inserted_at], limit: 1)` read to assert the row.

    3. Create `test/sigra/audit/query_filters_test.exs` with 5 failing stubs (`@tag :skip`):
       - `test "build/2 filters by :organization_id equality"`
       - `test "build/2 filters by :organization_id nil => IS NULL"`
       - `test "build/2 filters by :effective_user_id equality and nil"`
       - `test "build/2 :organization_scope {:only, org_id} filters strict"`
       - `test "build/2 :organization_scope {:including_global, org_id} returns rows with matching org_id OR NULL org_id"`
       - `test "build/2 raises ArgumentError on unknown filter key (breaking change per D-15)"` — assert `assert_raise ArgumentError, fn -> Sigra.Audit.Query.build(AuditTestEvent, actor: "wrong") end`

    4. Create `test/sigra/audit/query_index_test.exs` — Postgres-only (use `@moduletag :postgres` and skip on other adapters via `@moduletag :skip` initially). Stub: `test "EXPLAIN shows (organization_id, inserted_at) index hit"`. Body: run `SELECT * FROM EXPLAIN SELECT ... WHERE organization_id = $1 ORDER BY inserted_at DESC LIMIT 50` and assert output contains "Index Scan using audit_events_organization_id_inserted_at_index".

    5. Create `test/sigra/scope/build_test.exs` with 3 stubs (`@tag :skip`):
       - `test "Sigra.Scope.build/3 with minimal opts returns struct with user set and others nil"`
       - `test "Sigra.Scope.build/3 propagates :active_organization and :membership from opts"`
       - `test "Sigra.Scope.build/3 always sets :impersonating_from to nil in v1.1"`
       Use a test fixture scope module (define inline: `defmodule BuildTest.Scope do defstruct [:user, :active_organization, :membership, :impersonating_from] end`).

    6. Create `test/sigra/testing/assert_audit_logged_test.exs` as a Wave 0 test stub for the helper introduced in Plan 15-02 Task 3. Use `@tag :skip` on each test so the suite stays green until 15-02 implements `Sigra.Testing.assert_audit_logged/2`. The stub file MUST establish the four test shapes that Plan 15-02's acceptance criteria grep for — the executor for 15-02 un-skips these tests, not recreates them:

       ```elixir
       defmodule Sigra.Testing.AssertAuditLoggedTest do
         use ExUnit.Case, async: true

         # This file is a Wave 0 stub created by Plan 15-01 Task 0 for
         # consumption by Plan 15-02 Task 3 (adds `assert_audit_logged/2` to
         # `lib/sigra/testing.ex` as a thin alias for `assert_audit_event/2`).
         #
         # All tests are @tag :skip until 15-02 implements the helper.
         #
         # Signature note (see Plan 15-02 `deviations` field):
         # `assert_audit_logged(expected :: map(), opts :: keyword())`
         # NOT `assert_audit_logged(repo, fields)` — the D-31 CONTEXT signature
         # was refined during planning after surveying the existing
         # `assert_audit_event/2` at lib/sigra/testing.ex:1150.

         @tag :skip
         test "assert_audit_logged/2 passes when latest row matches given map fields" do
           # 15-02 executor: insert a row via AuditTestEvent then call:
           #   assert assert_audit_logged(%{action: "test.event"}, repo: TestRepo, audit_schema: AuditTestEvent) == true
           flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
         end

         @tag :skip
         test "assert_audit_logged/2 fails with a clear ExUnit.AssertionError when a field does not match" do
           # 15-02 executor: assert_raise ExUnit.AssertionError, ~r/Expected action/, fn -> ... end
           flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
         end

         @tag :skip
         test "assert_audit_logged/2 raises FunctionClauseError when first arg is not a map" do
           # 15-02 executor: assert_raise FunctionClauseError, fn ->
           #   assert_audit_logged([action: "test.event"], repo: TestRepo, audit_schema: AuditTestEvent)
           # end
           flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
         end

         @tag :skip
         test "assert_audit_logged/2 raises KeyError when opts is missing :audit_schema" do
           # 15-02 executor: assert_raise KeyError, fn ->
           #   assert_audit_logged(%{action: "test.event"}, repo: TestRepo)
           # end
           flunk("Wave 0 stub — implemented in Plan 15-02 Task 3")
         end
       end
       ```

       The four test names and the `FunctionClauseError` / `KeyError` assertions are load-bearing — Plan 15-02 Task 3 acceptance criteria grep for these literal strings in the file.
  </action>
  <verify>
    <automated>mix test test/sigra/audit/log_safe_scope_test.exs test/sigra/audit/query_filters_test.exs test/sigra/audit/query_index_test.exs test/sigra/scope/build_test.exs test/sigra/testing/assert_audit_logged_test.exs --include skip 2>&1 | grep -E "Excluded|Skipped"; mix compile 2>&1 | grep -c "error" | grep -q "^0$"</automated>
  </verify>
  <done>
    All 6 files exist and compile; all tests tagged @tag :skip so suite is green; test/support/audit_test_event.ex has the two new fields; the `assert_audit_logged` stub file is in place for Plan 15-02 Task 3 to un-skip and implement against.
  </done>
  <acceptance_criteria>
    - `test -f test/sigra/audit/log_safe_scope_test.exs` succeeds
    - `test -f test/sigra/audit/query_filters_test.exs` succeeds
    - `test -f test/sigra/audit/query_index_test.exs` succeeds
    - `test -f test/sigra/scope/build_test.exs` succeeds
    - `test -f test/sigra/testing/assert_audit_logged_test.exs` succeeds
    - `grep -c "field :organization_id, :binary_id" test/support/audit_test_event.ex` returns `1`
    - `grep -c "field :effective_user_id, :binary_id" test/support/audit_test_event.ex` returns `1`
    - `grep -c "@tag :skip" test/sigra/audit/log_safe_scope_test.exs` returns at least `4`
    - `grep -c "@tag :skip" test/sigra/testing/assert_audit_logged_test.exs` returns at least `4`
    - `grep -c "FunctionClauseError" test/sigra/testing/assert_audit_logged_test.exs` returns at least `1`
    - `grep -c "KeyError" test/sigra/testing/assert_audit_logged_test.exs` returns at least `1`
    - `mix compile --warnings-as-errors` exits 0
    - `mix test test/sigra/audit/log_safe_scope_test.exs` exits 0 (skipped tests do not fail the suite)
    - `mix test test/sigra/testing/assert_audit_logged_test.exs` exits 0 (skipped tests do not fail the suite)
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 1: ALTER migration template + schema template + changeset @cast_fields + Sigra.Scope.build/3 + log_safe/3 core + Query extension</name>
  <files>
    priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs,
    priv/templates/sigra.install/core/audit_event.ex,
    lib/sigra/audit/changeset.ex,
    lib/sigra/audit.ex,
    lib/sigra/audit/query.ex,
    lib/sigra/scope.ex
  </files>
  <read_first>
    - priv/templates/sigra.install/core/create_audit_events.exs (FROZEN — do not modify; read to mirror style)
    - priv/templates/sigra.install/core/audit_event.ex (existing schema template)
    - lib/sigra/audit.ex full file
    - lib/sigra/audit/changeset.ex full file
    - lib/sigra/audit/query.ex full file
    - lib/sigra/scope/hydration.ex (sibling module style reference)
    - .planning/phases/15-audit-integration/15-CONTEXT.md (D-01 through D-17, D-23)
    - .planning/phases/13-organizations-schemas-context/13-CONTEXT.md D-17 (on_delete: :nilify_all contract)
  </read_first>
  <behavior>
    - log_safe/3 with nil scope writes explicit nil organization_id + nil effective_user_id to the cast fields (not absent keys)
    - log_safe/3 with a scope having user + active_organization writes both ids
    - log_safe/3 duck-types — does NOT pattern-match on %Sigra.Scope{} (Scope is host-generated)
    - log_safe/2 delegates to log_safe/3 with nil scope (shim stays per D-02)
    - Caller-supplied :organization_id in opts wins over scope-derived value
    - scope_fields/1 stays PRIVATE (no defp -> def promotion, no public facade per D-05)
    - Query.build/2 accepts :organization_id, :effective_user_id, :organization_scope as new filter keys
    - Query.build/2 raises ArgumentError on any filter key not in the explicit whitelist (D-15 breaking change)
    - Sigra.Scope.build/3 returns a struct of the given scope_module with user, active_organization, membership set from opts and impersonating_from always nil in v1.1
  </behavior>
  <action>
    **1. Create `priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs`** as an EEx template. The generator binding provides `adapter` (:postgres | :mysql | :sqlite) per RESEARCH.md. Use adapter branching at the EEx level:

    ```elixir
    defmodule <%= inspect(@repo) %>.Migrations.AlterAuditEventsAddOrgColumns do
      use Ecto.Migration

    <%= if @adapter == :postgres do %>
      @disable_ddl_transaction true
      @disable_migration_lock true

      def up do
        alter table(:audit_events) do
          add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
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
    <% else %>
      def change do
        alter table(:audit_events) do
          add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
          add :effective_user_id, :binary_id
        end

        create index(:audit_events, [:organization_id, :inserted_at])
      end
    <% end %>
    end
    ```

    The FK explicitly sets `type: :binary_id` (D-13). Index is composite `(organization_id, inserted_at)` parallel to existing `(actor_id, inserted_at)` (D-11). No `effective_user_id` index in v1.1 (D-12).

    **2. Update `priv/templates/sigra.install/core/audit_event.ex`**: add two fields unconditionally (D-14) inside the schema block, next to existing `target_id`/`actor_id` fields:

    ```elixir
    field :organization_id, :binary_id
    field :effective_user_id, :binary_id
    ```

    No EEx conditional — ships in all installs regardless of `--organizations` (D-14).

    **3. Update `lib/sigra/audit/changeset.ex`** `@cast_fields` (currently at approx line 30) to append the two new atoms: `:organization_id, :effective_user_id`. Leave all other fields untouched.

    **4. Create `lib/sigra/scope.ex`**:

    ```elixir
    defmodule Sigra.Scope do
      @moduledoc """
      Library-side scope helpers. The `%Scope{}` struct itself is generated
      into the host app — this module only provides constructors that work
      via `struct/2` reflection on the host's module.

      Used by:
      - Login-time scope synthesis in `Sigra.Auth` (D-27 in 15-CONTEXT.md)
      - Worker reference implementation `Sigra.Workers.AccountDeletion` (D-21, D-22)

      **Worker scopes are audit-only.** Host apps MUST NOT pass a worker-reconstructed
      scope to authorization functions — the minimal skeleton does not carry a real
      request context.
      """

      @spec build(scope_module :: module(), user :: struct() | nil, opts :: keyword()) :: struct()
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

    **5. Update `lib/sigra/audit.ex`**:

    a. Add new public `log_safe/3`:
    ```elixir
    @doc """
    Library-internal safe audit emission with optional scope.

    `scope` is the second positional argument — mirrors Phoenix 1.8 scopes
    idiom. Pass `nil` explicitly for pre-authentication or truly anonymous sites.

    Scope is duck-typed on `%{user, active_organization, impersonating_from}` —
    it does NOT pattern-match on `%Sigra.Scope{}` because that struct is generated
    into the host app, not defined in the library.

    `effective_user_id` is the authenticated principal (or v1.2 impersonation
    target); `target_id` is the subject of the event. They diverge for
    anonymous-actor events (failed login, magic link request) and for admin
    actions on other users (v1.2).
    """
    def log_safe(action, scope, opts) when is_binary(action) and is_list(opts) do
      scope_opts = scope_fields(scope)
      merged = Keyword.merge(scope_opts, opts)  # caller wins (D-06)
      __log_internal__(action, merged, safe: true)
    end
    ```

    b. Keep `log_safe/2` as shim (D-02):
    ```elixir
    def log_safe(action, opts) when is_binary(action) and is_list(opts) do
      log_safe(action, nil, opts)
    end
    ```

    c. Add private `scope_fields/1` (D-03, D-04, D-05). Must stay `defp`:
    ```elixir
    defp scope_fields(nil) do
      [organization_id: nil, effective_user_id: nil, actor_id: nil]
    end

    defp scope_fields(%{user: user} = scope) do
      org = Map.get(scope, :active_organization)
      # D-04: v1.2 impersonation diff is a single conditional added on this line.
      [
        organization_id: org && org.id,
        effective_user_id: user && user.id,
        actor_id: user && user.id
      ]
    end
    ```

    d. Update `build_attrs/4` (approx line 384) to pick up the two new keys from opts and pass them through to the changeset. Add an inline comment: `# Top-level columns (D-07) — not nested in :metadata`.

    **6. Update `lib/sigra/audit/query.ex`**:

    a. Add `@allowed_filters` module attribute listing every supported key:
    ```elixir
    @allowed_filters [
      :action, :actor_id, :target_id, :inserted_after, :inserted_before,
      :limit, :order, :organization_id, :effective_user_id, :organization_scope
    ]
    ```
    (Include every existing key — grep the current reduce body to enumerate.)

    b. Replace the existing catch-all `defp apply_filter(query, _), do: query` (around line 43) with:
    ```elixir
    defp apply_filter(_query, {key, _value}) do
      raise ArgumentError,
            "Sigra.Audit.Query: unknown filter key #{inspect(key)}. " <>
              "Allowed keys: #{inspect(@allowed_filters)}"
    end
    ```

    c. Add three new `apply_filter/2` clauses BEFORE the raising catch-all:
    ```elixir
    defp apply_filter(query, {:organization_id, nil}),
      do: from(q in query, where: is_nil(q.organization_id))

    defp apply_filter(query, {:organization_id, id}),
      do: from(q in query, where: q.organization_id == ^id)

    defp apply_filter(query, {:effective_user_id, nil}),
      do: from(q in query, where: is_nil(q.effective_user_id))

    defp apply_filter(query, {:effective_user_id, id}),
      do: from(q in query, where: q.effective_user_id == ^id)

    defp apply_filter(query, {:organization_scope, {:only, org_id}}),
      do: from(q in query, where: q.organization_id == ^org_id)

    # TODO(v1.2): Postgres may not use the (organization_id, inserted_at) composite
    # index for the IS NULL branch. Revisit with partial index on
    # WHERE organization_id IS NULL or a UNION ALL rewrite.
    defp apply_filter(query, {:organization_scope, {:including_global, org_id}}),
      do: from(q in query, where: q.organization_id == ^org_id or is_nil(q.organization_id))
    ```

    d. Also wire the top-level `build/2` to validate filter keys up front (belt + suspenders) — at the head of `build/2`, add:
    ```elixir
    Enum.each(filters, fn {k, _} ->
      unless k in @allowed_filters do
        raise ArgumentError,
              "Sigra.Audit.Query: unknown filter key #{inspect(k)}. " <>
                "Allowed keys: #{inspect(@allowed_filters)}"
      end
    end)
    ```

    **7. Un-skip the Wave 0 tests** (remove `@tag :skip` from the 4 files created in Task 0 that cover functionality implemented in this task) and run them — they must pass. **Do NOT un-skip `test/sigra/testing/assert_audit_logged_test.exs`** — that file is implemented by Plan 15-02 Task 3, not this task.
  </action>
  <verify>
    <automated>mix test test/sigra/audit/log_safe_scope_test.exs test/sigra/audit/query_filters_test.exs test/sigra/scope/build_test.exs && mix compile --warnings-as-errors</automated>
  </verify>
  <done>
    All named files exist / are updated; `log_safe/3` is the sole public API path; `log_safe/2` is a shim; `scope_fields/1` is private; Query rejects unknown filter keys; Sigra.Scope.build/3 exists; all Wave 0 unit tests (except the 15-02-owned `assert_audit_logged_test.exs`) pass.
  </done>
  <acceptance_criteria>
    - `test -f priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` succeeds
    - `grep -c "references(:organizations, type: :binary_id, on_delete: :nilify_all)" priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` returns at least `1`
    - `grep -c "@disable_ddl_transaction true" priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` returns `1`
    - `grep -c "concurrently: true" priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` returns `1`
    - `grep -c "def up" priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` returns `1`
    - `grep -c "def down" priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs` returns `1`
    - `grep -c "field :organization_id, :binary_id" priv/templates/sigra.install/core/audit_event.ex` returns `1`
    - `grep -c "field :effective_user_id, :binary_id" priv/templates/sigra.install/core/audit_event.ex` returns `1`
    - `grep -c ":organization_id" lib/sigra/audit/changeset.ex` returns at least `1`
    - `grep -c ":effective_user_id" lib/sigra/audit/changeset.ex` returns at least `1`
    - `grep -c "def log_safe(action, scope, opts)" lib/sigra/audit.ex` returns `1`
    - `grep -c "def log_safe(action, opts)" lib/sigra/audit.ex` returns `1` (shim)
    - `grep -c "defp scope_fields" lib/sigra/audit.ex` returns at least `2` (nil + non-nil clause)
    - `grep -c "def scope_fields" lib/sigra/audit.ex` returns `0` (stays private per D-05)
    - `test -f lib/sigra/scope.ex` succeeds
    - `grep -c "def build(scope_module" lib/sigra/scope.ex` returns `1`
    - `grep -c "impersonating_from: nil" lib/sigra/scope.ex` returns `1`
    - `grep -c "raise ArgumentError" lib/sigra/audit/query.ex` returns at least `1`
    - `grep -c "organization_scope" lib/sigra/audit/query.ex` returns at least `2`
    - `grep -c "including_global" lib/sigra/audit/query.ex` returns at least `1`
    - `grep -c "TODO(v1.2)" lib/sigra/audit/query.ex` returns at least `1`
    - `mix compile --warnings-as-errors` exits 0
    - `mix test test/sigra/audit/log_safe_scope_test.exs` exits 0 (no skips remaining for implemented cases)
    - `mix test test/sigra/audit/query_filters_test.exs` exits 0
    - `mix test test/sigra/scope/build_test.exs` exits 0
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Mechanical 79-site sweep — log_safe(x, y) → log_safe(x, nil, y) across lib/sigra/**</name>
  <files>
    lib/sigra/auth.ex,
    lib/sigra/mfa.ex,
    lib/sigra/account.ex,
    lib/sigra/oauth.ex,
    lib/sigra/api_token.ex,
    lib/sigra/lockout.ex,
    lib/sigra/suspicious_login.ex,
    lib/sigra/plug/load_active_organization.ex
  </files>
  <read_first>
    - .planning/phases/15-audit-integration/15-CONTEXT.md (D-25 mechanical sweep policy; Call Sites section listing 79 sites and per-file counts)
    - lib/sigra/audit.ex (to confirm log_safe/3 signature is live from Task 1)
    - Each of the 8 target files, top-to-bottom (you must see every call site you rewrite)
  </read_first>
  <action>
    Rewrite every `Sigra.Audit.log_safe(action, opts)` and aliased `Audit.log_safe(action, opts)` call to `Sigra.Audit.log_safe(action, nil, opts)` / `Audit.log_safe(action, nil, opts)`. This is a PURELY MECHANICAL find-and-replace — DO NOT enrich any site with a real scope. Plan 15-02 handles the semantic enrichment pass.

    **Per-file expected call site counts (from CONTEXT.md):**

    | File | log_safe/2 sites to rewrite |
    |------|------------------------------|
    | lib/sigra/auth.ex | 24 |
    | lib/sigra/mfa.ex | 20 |
    | lib/sigra/account.ex | 17 |
    | lib/sigra/oauth.ex | 8 |
    | lib/sigra/api_token.ex | 7 |
    | lib/sigra/lockout.ex | 1 |
    | lib/sigra/suspicious_login.ex | 1 |
    | lib/sigra/plug/load_active_organization.ex | 1 |
    | **TOTAL** | **79** |

    Both call forms exist in the codebase (confirmed by RESEARCH.md):
    - Fully qualified: `Sigra.Audit.log_safe(...)`
    - Aliased: `Audit.log_safe(...)` (module aliases `Sigra.Audit, as: Audit`)

    **Method:** For each file, read it top-to-bottom. For each `log_safe(` call, insert `nil, ` as the second positional argument. Do NOT change the action string. Do NOT change the opts keyword list. Multi-line calls (where the opts span several lines) get `nil,` inserted on the same line as the action:

    Before:
    ```elixir
    Sigra.Audit.log_safe("auth.login.success",
      repo: repo,
      audit_schema: audit_schema,
      metadata: %{user_id: user.id, ip: ip}
    )
    ```

    After:
    ```elixir
    Sigra.Audit.log_safe("auth.login.success", nil,
      repo: repo,
      audit_schema: audit_schema,
      metadata: %{user_id: user.id, ip: ip}
    )
    ```

    **Do NOT touch:**
    - `Sigra.Audit.log/2` calls (raising variant — out of scope per D-08)
    - `Sigra.Audit.log_multi/3` and `log_multi_safe/3` calls (out of scope per D-08)
    - The `log_safe/2` shim definition itself inside `lib/sigra/audit.ex` (added in Task 1)
    - Any test file under `test/**`
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors && mix test --stale</automated>
  </verify>
  <done>
    All 79 call sites migrated to 3-arity form with nil placeholder; compile clean; existing test suite still green (no semantic change yet).
  </done>
  <acceptance_criteria>
    - `grep -c "Audit\\.log_safe(" lib/sigra/auth.ex` returns `24`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/auth.ex` returns `24`
    - `grep -c "Audit\\.log_safe(" lib/sigra/mfa.ex` returns `20`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/mfa.ex` returns `20`
    - `grep -c "Audit\\.log_safe(" lib/sigra/account.ex` returns `17`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/account.ex` returns `17`
    - `grep -c "Audit\\.log_safe(" lib/sigra/oauth.ex` returns `8`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/oauth.ex` returns `8`
    - `grep -c "Audit\\.log_safe(" lib/sigra/api_token.ex` returns `7`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/api_token.ex` returns `7`
    - `grep -c "Audit\\.log_safe(" lib/sigra/lockout.ex` returns `1`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/lockout.ex` returns `1`
    - `grep -c "Audit\\.log_safe(" lib/sigra/suspicious_login.ex` returns `1`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/suspicious_login.ex` returns `1`
    - `grep -c "Audit\\.log_safe(" lib/sigra/plug/load_active_organization.ex` returns `1`
    - `grep -c "Audit\\.log_safe([^,]*, nil," lib/sigra/plug/load_active_organization.ex` returns `1`
    - Total: `grep -rhEo "Audit\\.log_safe\\([^,]*, (nil|scope)," lib/sigra/ --include="*.ex" | wc -l` returns `79` after this task (all nil in 15-01; some become `scope` in 15-02)
    - `mix compile --warnings-as-errors` exits 0
    - `mix test --stale` exits 0
  </acceptance_criteria>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Audit write path | Untrusted action strings and caller-opts flow into the audit changeset — merge direction and column placement matter |
| Query filter surface | Host-app callers pass filter keywords; typos must not silently return unfiltered results |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-15-01 | Repudiation | `Sigra.Audit.log_safe/3` + `scope_fields/1` | mitigate | `effective_user_id` shipped as real column in v1.1 (equal to `actor_id`); private `scope_fields/1` is the single v1.2 one-line extension point so impersonation audits cannot accidentally attribute actions to the target user (addresses O-7). |
| T-15-03 | Information Disclosure | `Sigra.Audit.Query.build/2` | mitigate | Existing silent catch-all clause replaced with explicit `@allowed_filters` whitelist that raises `ArgumentError` on unknown keys — audit-table typos (`actor:` for `actor_id:`) can no longer return unfiltered result sets. Breaking change CHANGELOG'd in Plan 15-03. |
| T-15-05 | Tampering | Alter migration FK declaration | mitigate | FK declared as `references(:organizations, type: :binary_id, on_delete: :nilify_all)` — Phase 13 D-17 anti-regression. Cascade-delete of an org cannot wipe historical audit rows (addresses O-10). |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` green
- `mix test` green (all existing suites + new Wave 0 tests)
- `grep -rhEo "Audit\\.log_safe\\([^,]*, (nil|scope)," lib/sigra/ --include="*.ex" | wc -l` returns `79`
- No `log_safe/2` call remains in `lib/sigra/**` except the shim definition in `lib/sigra/audit.ex`
- Sigra.Audit.Query raises ArgumentError on unknown filter keys
- Migration template compiles as ERB/EEx (verified by generator test or manual `EEx.eval_file/2` dry run)
</verification>

<success_criteria>
All three truths in `must_haves.truths` hold; every artifact listed in `must_haves.artifacts` exists with the stated contents; the 79 log_safe call sites are mechanically uniform and still type-check; Wave 0 test files from 15-VALIDATION.md exist (plus the `assert_audit_logged_test.exs` stub for Plan 15-02) and the unit-level ones pass. The codebase is now ready for semantic enrichment (Plan 15-02).
</success_criteria>

<output>
After completion, create `.planning/phases/15-audit-integration/15-01-SUMMARY.md` following the workflow summary template, including: files touched, per-file sweep counts, the log_safe/3 signature, the @allowed_filters list, a note that every site now carries `nil` scope pending semantic enrichment in 15-02, and a note that `test/sigra/testing/assert_audit_logged_test.exs` is a Wave 0 stub owned by Plan 15-02 Task 3.
</output>
