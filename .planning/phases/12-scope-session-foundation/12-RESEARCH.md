# Phase 12: Scope + Session Foundation - Research

**Researched:** 2026-04-11
**Domain:** Mechanical data-shape extension (library struct + generator template + feature manifest + Ecto schema)
**Confidence:** HIGH — all findings verified directly against committed source code in this repo.

## Summary

Phase 12 is a narrow mechanical change, but CONTEXT.md's locked decisions contain one small-but-important misalignment with the current code shape, and two test-count assertions in `Sigra.Install.Features.CoreTest` will fail the moment the new slot lands unless updated in the same commit. This research catalogs every file that must move, the exact line ranges, and the test infrastructure that already exists so the planner can build a wave-ordered plan without surprises.

**Primary recommendation:** Sequence the changes as (1) library-struct + SessionStore + test-schema extension, gated by extended `session_test.exs` and `session_stores/ecto_test.exs`; (2) feature-manifest + new migration template + `Core` tests update + golden-diff fixture rebaseline; (3) generated templates (`scope.ex`, `user_session.ex`) + reserved-field invariant test; (4) example-app mirror updates + end-to-end round-trip test; (5) `UPGRADE-v1.2.md` doc. Waves 2 and 3 can be parallelized but both must land before Wave 4.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01 through D-16 + CD-01 through CD-04)

**D-01:** New `:active_org_column` migration slot. Standalone ALTER migration at `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs`. Phase 11 `:primary` migration template stays **byte-identical**.

**D-02:** Feature-manifest ordering — new slot lands between `:primary` and `:api_token`. `MigrationTimestamps.allocate/2` (Phase 11) handles the timestamp sequence automatically.

**D-03:** No index in Phase 12. Nullable column only, no FK. Phase 14 or 18 adds the FK reference + index.

**D-04:** First-class `:active_organization_id` field on `%Sigra.Session{}` (not a metadata map). Ordered between `:sudo_at` and `:inserted_at` in `defstruct` and `@type t`.

**D-05:** **No** dedicated `put_active_organization_id/2` setter. Callers use struct-update syntax.

**D-06:** Every `Sigra.SessionStore` implementation must round-trip the new field. No behaviour callback changes.

**D-07:** `:impersonating_from` does NOT land on `%Sigra.Session{}` in v1.2-prep. Session struct and Scope struct are distinct — v1.2 adds to Session additively.

**D-08:** Pure additive defstruct on generated `Scope`. `for_user/1` and `new/1` remain arity-1. Three new fields: `:active_organization`, `:membership`, `:impersonating_from` — all default `nil`.

**D-09:** Typespec uses `struct() | nil` for `:active_organization` and `:membership` in v1.1. Phase 13 tightens to `%<%= context_module %>.Organization{} | nil` etc.

**D-10:** `:impersonating_from` typed as `%<%= schema_alias %>{} | nil`.

**D-11:** Reserved-field enforcement = doc comment (A) + library-side invariant test (C). Two assertions: source-level grep + compile-and-introspect.

**D-12:** `UPGRADE-v1.2.md` created in Phase 12 as skeleton.

**D-13:** Phase 11 golden-diff is NOT the enforcement mechanism for the reserved field.

**D-14:** End-to-end serialization round-trip test (Success Criterion #3).

**D-15:** Golden-diff fixture gets one NEW file; Phase 11 files stay byte-identical.

**D-16:** Compile-without-warnings check (Success Criterion #1).

**CD-01:** `:active_organization_id` is the chosen name. Planner may not rename.
**CD-02:** `UPGRADE-v1.2.md` format is Claude's discretion.
**CD-03:** Test module naming is Claude's discretion (under `test/sigra/install/`).
**CD-04:** SessionStore test double extension is Claude's discretion.

### Claude's Discretion
- Exact `UPGRADE-v1.2.md` wording
- Test module/function naming for the invariant test
- Whether to extend the Ecto SessionStore test or add a separate round-trip test module

### Deferred Ideas (OUT OF SCOPE)
- `Sigra.Session.put_active_organization_id/2` setter (Phase 14+)
- `Scope.hydrate/2` / `Scope.put_active_organization/2` helper (Phase 14)
- Index on `user_sessions.active_organization_id` (Phase 14 or 18)
- `:impersonating_from` on `Sigra.Session` (v1.2)
- `Sigra.Session.put_metadata/3` — rejected (D-04 rationale)
- Removing Phase 11 golden-diff as enforcement (D-13 — keep it, just don't rely on it)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORG-SCOPE-01 | `%Scope{}` gains `:active_organization`, `:membership`, reserved `:impersonating_from` | §Mechanical Reference / Scope Template; §Integration Seams /2 |
| ORG-SCOPE-02 | `user_sessions.active_organization_id` nullable column + `%Sigra.Session{}` field | §Mechanical Reference / Session struct, Session store, Feature manifest; §Integration Seams /1,3,4 |
</phase_requirements>

## Mechanical Reference

All file paths are absolute. Line numbers are from the working tree at research time (2026-04-11).

### 1. `lib/sigra/session.ex` — Session struct + type (78 lines)

Current shape (verified lines 48-78):

```elixir
@type t :: %__MODULE__{
        id: term(),
        user_id: term(),
        token: binary() | nil,
        hashed_token: binary(),
        type: session_type(),
        ip: String.t() | nil,
        user_agent: String.t() | nil,
        parsed_ua: map() | nil,
        geo_city: String.t() | nil,
        geo_country_code: String.t() | nil,
        last_active_at: DateTime.t() | nil,
        sudo_at: DateTime.t() | nil,
        inserted_at: DateTime.t() | nil    # ← new :active_organization_id goes BEFORE this line
      }

defstruct [
  :id,
  :user_id,
  :token,
  :hashed_token,
  type: :standard,
  ip: nil,
  user_agent: nil,
  parsed_ua: nil,
  geo_city: nil,
  geo_country_code: nil,
  last_active_at: nil,
  sudo_at: nil,
  inserted_at: nil                            # ← insert :active_organization_id, nil BEFORE this line
]
```

**Note — order subtlety:** First four fields in `defstruct` are bare atoms (`:id`, `:user_id`, `:token`, `:hashed_token`), and the rest use the `key: default` form. `:active_organization_id` must use the `active_organization_id: nil` form (consistent with its neighbors) to avoid the Elixir compiler error "atoms must precede keyword pairs in defstruct".

Also update the `## Fields` doc block (lines 29-41) to add a one-line entry for `:active_organization_id`.

### 2. `lib/sigra/session_store.ex` — Behaviour (64 lines)

No callback signature changes (D-06). The behaviour already treats the Session struct as opaque — every callback returns `Sigra.Session.t()` or accepts metadata maps. The new field simply flows through.

### 3. `lib/sigra/session_stores/ecto.ex` — Ecto impl (169 lines)

**Three touch points required** for full round-trip:

1. **`create/3` (lines 22-49)** — add `active_organization_id: Map.get(metadata, :active_organization_id)` to the `attrs` map (line 29-39). Key is nullable; default nil.
2. **`to_session/1` (lines 146-168)** — add `active_organization_id: Map.get(record, :active_organization_id)` to the `%Sigra.Session{}` literal construction.
3. **Update path.** Phase 12 ships **no** dedicated update function per D-05. Callers set the field via struct-update syntax. Means `update_activity/3` and `update_sudo/3` do NOT need to change in Phase 12 — they only touch the fields they explicitly care about. Phase 14 can add `update_active_organization_id/3` (or similar) if it chooses, but it is out of scope here.

### 4. `test/support/test_user_session.ex` — Mox test schema (22 lines)

```elixir
schema "user_sessions" do
  field :user_id, :binary_id
  field :hashed_token, :binary
  field :type, :string
  field :ip, :string
  field :user_agent, :string
  field :geo_city, :string
  field :geo_country_code, :string
  field :last_active_at, :utc_datetime_usec
  field :sudo_at, :utc_datetime_usec     # ← add field :active_organization_id, :binary_id AFTER this
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

This file is critical — `Sigra.SessionStores.EctoTest` uses it as the schema module (`@opts [repo: Sigra.MockRepo, session_schema: Sigra.Test.UserSession]`, line 13 of `ecto_test.exs`). Without this field, Mox expectations that try to put `active_organization_id` on the schema struct will crash.

### 5. `lib/sigra/install/features/core.ex` — Feature manifest (744 lines)

**Current `migrations/1` (lines 85-91) — verified actual shape:**

```elixir
@impl true
def migrations(_binding) do
  [
    {:primary, "core/migration.exs", "create_sigra_auth_tables.exs"},
    {:api_token, "core/api_token_migration.exs", "create_user_api_tokens.exs"},
    {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"}
  ]
end
```

⚠️ **CONTEXT.md D-02 drift.** D-02 in CONTEXT.md shows the return as **2-tuples** (`{slot, path}`), but the actual behaviour contract (`lib/sigra/install/feature.ex` lines 55-57) and the runtime code use **3-tuples** (`{slot_key, template_path, target_basename}`). The new entry must match the 3-tuple shape. This is NOT a decision change — it's a CONTEXT.md typo. The planner should use:

```elixir
{:active_org_column,
 "core/add_active_organization_id_to_user_sessions.exs",
 "add_active_organization_id_to_user_sessions.exs"}
```

inserted between `:primary` and `:api_token`.

**Also required: `base_files/1` edit (lines 137-212).** Current code inlines migration templates directly into `files/1` so the walker emits them in monolith byte-identical order (see runner comment lines 14-17: "migration entries are inlined in `files/1` with their target already resolved from the allocated timestamp"). Two migrations are currently inlined:

- `primary_migration` at line 142-144 (position 0 in base_files)
- `audit_migration` at line 146-148 (position 22, after MFA files)

The new migration must be inlined into `base_files/1` as well. Position matters for STDOUT ordering — see §Risks / Golden-diff ordering.

### 6. `lib/sigra/install/runner.ex` — Walker (188 lines)

No changes needed. The walker:
1. Calls `MigrationTimestamps.allocate(active, base_time)` (line 55) which iterates `feature.migrations([])` and assigns `base_time + N seconds` in manifest order (`MigrationTimestamps.allocate/2` lines 30-45).
2. Threads the resolved timestamp map into each feature's binding as `:migration_timestamps`.
3. `Features.Core.migration_target/3` (lines 75-82) reads the slot's timestamp from that map and builds the target path.

Adding a new slot automatically pushes `:api_token` and `:audit_events` one second forward. Since the golden fixture normalizes all `\d{14}_` prefixes to `TIMESTAMP_`, this does NOT break byte-identity of migration contents or filenames in the fixture.

### 7. `priv/templates/sigra.install/core/scope.ex` — Generated Scope (38 lines, verified)

```eex
defmodule <%= context_module %>.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.
  ...
  """

  alias <%= context_module %>.<%= schema_alias %>

  defstruct user: nil                                   # ← REPLACE with 4-field form

  @type t :: %__MODULE__{user: %<%= schema_alias %>{} | nil}   # ← EXTEND

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%<%= schema_alias %>{} = user) do
    %__MODULE__{user: user}                             # ← unchanged (D-08 arity-1)
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope struct from a user. Used by Sigra plugs.
  """
  def new(%<%= schema_alias %>{} = user) do
    %__MODULE__{user: user}                             # ← unchanged (D-08 arity-1)
  end

  def new(nil), do: nil
end
```

EEx bindings in use: `<%= context_module %>` (line 1, 10, 15) and `<%= schema_alias %>` (line 15, 19, 24, 33). The `@moduledoc` section should gain a paragraph naming the reserved field (D-11 doc-comment enforcement A).

### 8. `priv/templates/sigra.install/core/user_session.ex` — Generated schema (35 lines, verified)

```eex
defmodule <%= context_module %>.UserSession do
  ...
  use Ecto.Schema
<%= if binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
<% end %>
  schema "user_sessions" do
    field :hashed_token, :binary
    field :type, :string, default: "standard"
    field :ip, :string
    field :user_agent, :string
    field :geo_city, :string
    field :geo_country_code, :string
    field :last_active_at, :utc_datetime_usec
    field :sudo_at, :utc_datetime_usec           # ← add field :active_organization_id, :binary_id AFTER this

    belongs_to :user, <%= context_module %>.<%= schema_alias %>

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
```

EEx bindings: `<%= context_module %>`, `<%= schema_alias %>`, `<%= if binary_id do %>`. The new field is `:binary_id` unconditionally to match Phase 18's future FK (D-03: "no index, no FK in Phase 12" — the column type is still binary_id so the Phase 18 FK reference adds cleanly).

### 9. `priv/templates/sigra.install/core/migration.exs` — **DO NOT EDIT** (300 lines)

Byte-identity invariant per D-01. Three dialect branches (postgres at line 45, mysql at line 152, sqlite at line 246) each create `:user_sessions` — none of them get the new column. The new column arrives via the sibling ALTER migration.

### 10. NEW FILE: `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs`

Minimal shape (dialect-agnostic — `alter table` with `add :col, :binary_id` works on all three Ecto SQL adapters without branching, unlike the primary migration):

```eex
defmodule <%= repo_module %>.Migrations.AddActiveOrganizationIdToUserSessions do
  use Ecto.Migration

  def change do
    alter table(:user_sessions) do
      add :active_organization_id, :binary_id
    end
  end
end
```

EEx bindings needed: only `<%= repo_module %>`. All three required bindings are in the `@binding` fixture already (see `test/sigra/install/features/core_test.exs` lines 20-41: `repo_module: "MyApp.Repo"`).

### 11. `test/fixtures/install_golden/` — Golden fixture mechanism

**Fixture layout** (verified):
- `test/fixtures/install_golden/STDOUT.txt` — normalized captured stdout, ~50 lines
- `test/fixtures/install_golden/tree/` — mirror of target app layout with migration filenames normalized to `TIMESTAMP_*`
- Migration file **contents** are byte-identical (not normalized) per D-05 of Phase 11

**Current fixture migration files:**
- `tree/priv/repo/migrations/TIMESTAMP_create_sigra_auth_tables.exs`
- `tree/priv/repo/migrations/TIMESTAMP_create_audit_events.exs`

Note: `api_token_migration.exs` is **absent** from the fixture because `Sigra.Test.InstallFixture.setup_tmp_app/0` invokes `mix sigra.install Accounts User users --yes` with no `--api` flag (verified at `test/support/install_fixture.ex` lines 87-95). Default is `live=true, api=false, jwt=false`. The `--api`-gated templates never hit the fixture, so the `:api_token` slot is inert.

**How to add a new fixture file:** The fixture is committed source. There is no auto-regeneration on test run — `GoldenDiffTest` reads the committed files and compares against a freshly generated tree (verified `golden_diff_test.exs` lines 134-145, `read_fixture_tree/0` uses `Path.wildcard` + `File.read!`). Regeneration is a manual runbook step documented in `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md` and in `golden_diff_test.exs` `flunk_with_runbook/1` at lines 112-132.

**This means Phase 12 must:**
1. Add a new committed file: `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs` with the exact rendered content.
2. Update `test/fixtures/install_golden/STDOUT.txt` to insert ONE line for the new migration creation at the correct position (see §Risks / Golden-diff ordering for exact position).
3. Verify by running `mix test test/sigra/install/golden_diff_test.exs` (tagged `:golden` + `:integration`, timeout 300s — note this shells out to `mix phx.new` and may be slow locally).

### 12. `test/example/` — Persistent generated example app

This is a separately committed Mix project under `test/example/` (not regenerated — hand-maintained). It runs in a dedicated CI job (`.github/workflows/ci.yml` line 82+). Phase 12 must mirror template changes here to keep the example compilable:

- **`test/example/lib/example/accounts/scope.ex`** (37 lines, verified) — apply the same defstruct extension, manually rendered for `context_module=Example.Accounts`, `schema_alias=User`.
- **`test/example/lib/example/accounts/user_session.ex`** (35 lines, verified) — add `field :active_organization_id, :binary_id`.
- **`test/example/priv/repo/migrations/20260410125243_add_active_organization_id_to_user_sessions.exs`** — new migration file. Timestamp must fall between the existing two migrations to mimic the installer's ordering:
  - `20260410125242_create_sigra_auth_tables.exs` (existing)
  - **NEW:** `20260410125243_add_active_organization_id_to_user_sessions.exs`
  - `20260410125244_create_audit_events.exs` (existing)
  Wait — the existing audit timestamp is `...5244`, primary is `...5242`, so `...5243` is open. However in the installer the order is `:primary → :active_org_column → :api_token → :audit_events`, which would shift `:audit_events` from `+2s` to `+3s`. For the example app's historical record, the cleanest approach is **bump `:audit_events` to `20260410125244` stays** but insert `20260410125243` (which is currently unused). Verify no existing file at that timestamp; if conflict, use `20260410125243_...`.

### 13. NEW FILE: `test/sigra/install/scope_template_invariants_test.exs` (D-11)

Pattern for compile-and-introspect (adapted from `generator_reset_test.exs` lines 165-174):

```elixir
defmodule Sigra.Install.ScopeTemplateInvariantsTest do
  use ExUnit.Case, async: true

  @template_path Path.expand(
    "../../../priv/templates/sigra.install/core/scope.ex",
    __DIR__
  )

  describe "reserved :impersonating_from field (D-11)" do
    test "source-level grep — template defstruct mentions impersonating_from: nil" do
      source = File.read!(@template_path)
      assert source =~ ~r/impersonating_from:\s*nil/,
        """
        The generated Scope template must reserve the :impersonating_from field
        for v1.2 impersonation support. See UPGRADE-v1.2.md for the contract.
        """
    end

    test "compile-and-introspect — rendered module struct has :impersonating_from key" do
      bindings = [
        context_module: "TestApp.Accounts",
        schema_alias: "User"
      ]

      # Inject a dummy User module into a fresh namespace so the template compiles
      dummy_user_source = "defmodule TestApp.Accounts.User, do: defstruct([:id])"
      Code.compile_string(dummy_user_source)

      rendered = EEx.eval_file(@template_path, assigns: [], [bindings: bindings])
      # note: the scope template uses <%= context_module %> — a plain binding, not assigns
      # so we pass [context_module: "...", schema_alias: "..."] as the second arg to eval_file

      [{mod, _bytecode}] = Code.compile_string(rendered)
      struct = mod.__struct__()

      assert :impersonating_from in Map.keys(struct),
        """
        Rendered Scope struct must contain :impersonating_from — this field is
        reserved for v1.2 impersonation. See UPGRADE-v1.2.md.
        """
    end
  end
end
```

**Pitfall to verify in plan:** the existing `scope.ex` template uses `<%= context_module %>`, which is a **direct EEx binding** (not an `@assign`). `EEx.eval_file(path, bindings)` accepts the second arg as a plain keyword list that becomes the variable binding context. The existing `generator_reset_test.exs` uses `EEx.eval_string(template, assigns: @sample_assigns)` only because the templates it tests happen to use `@assigns` — the scope template does NOT. The planner must pass `EEx.eval_file(@template_path, [context_module: "...", schema_alias: "..."])` (straight keyword list, no `assigns:` wrapper).

**Open question on Code.compile_string + dummy User:** the template emits `alias <%= context_module %>.<%= schema_alias %>` and uses `%<%= schema_alias %>{}` in pattern matches (`for_user/1`, `new/1`). Compiling the rendered source requires the referenced `TestApp.Accounts.User` module to exist at compile time. The sketch above pre-compiles it. Alternative: use `Code.compile_quoted/1` with a pre-built quoted AST, or sandbox via `Code.eval_string` with `__ENV__`. The planner should try the `Code.compile_string` path first and fall back to source-level grep only if compilation proves too fragile (in which case the second assertion becomes: "rendered source contains a valid `defstruct` with the reserved key as a substring"). The regex assertion in test #1 already covers the common case loudly.

### 14. NEW FILE: `UPGRADE-v1.2.md` at project root (D-12)

Skeleton only. Suggested three-section structure:

```markdown
# Upgrading to Sigra v1.2

## Reserved fields in v1.1

Sigra v1.1 reserves the following fields in generated code so the v1.2 upgrade
can be purely additive:

- `%<YourApp>.Accounts.Scope{impersonating_from: nil}` — populated by v1.2
  `Sigra.Plug.Impersonation`.

Do not remove these fields from your generated scope. If you do, v1.2 will
fail to compile against your generated `user_auth.ex` and associated plugs.

## v1.2 population contract

(Filled in when v1.2 ships.)

## If you need to remove a reserved field

(Filled in when v1.2 ships.)
```

The library-side invariant test (D-11) names this file in its failure messages.

### 15. `test/sigra/install/features/core_test.exs` — REQUIRES UPDATES (critical)

Two assertions WILL FAIL the instant Phase 12 code lands, and must be updated in the same commit (verified at `test/sigra/install/features/core_test.exs` lines 70-107 and 179-205):

1. **`"returns exactly 3 slot entries in canonical order"`** (line 70). Becomes 4 slots, and the pattern-match tuple must gain the new `:active_org_column` entry between `:primary` and `:api_token`.
2. **`"basenames match today's monolith targets (byte-identity contract)"`** (line 81). Add a new `Enum.any?/2` clause for `:active_org_column` with basename `"add_active_organization_id_to_user_sessions.exs"`.
3. **`"default binding (live=true, api=false, jwt=false) returns exactly 36 files"`** (line 179). Becomes **37** (one new inlined migration). The comment on line 180-181 also needs updating: `"25 base_files + 9 ui_files + 2 inlined migrations"` → `"25 base_files + 9 ui_files + 3 inlined migrations"`. *Correction:* actually becomes 26 base_files + 9 ui_files + 3 migrations = 38? Let me recount from the code: base_files at line 137-212 currently holds 25 `{:eex, ...}` tuples (I did not count exhaustively — the planner should run `mix test ...features/core_test.exs -t` once to get the exact current count, then update the number). The planner MUST verify the actual count, not trust this comment.
4. **`"--no-live returns exactly 30 files (25 base + 3 controller-mode UI + 2 inlined migrations)"`** (line 202). Same reasoning — becomes 31 (add 1 for the new inlined migration in base_files). Comment needs matching update.
5. **`"default exercise path includes the primary migration and audit events migration"`**-style assertions (line 173-176) add a new assertion: `assert "core/add_active_organization_id_to_user_sessions.exs" in sources`.

Grep `test/sigra/install/features/core_test.exs` for every occurrence of `length(Core.files(` and every hard-coded small integer (`3`, `36`, `30`) and update in lockstep. There may also be assertions in `test/sigra/install/templates_layout_test.exs` that enumerate every template under `priv/templates/sigra.install/core/` — verify.

## Integration Seams

Exactly where new code goes, ordered by wave-friendly dependency.

### Seam 1: Library struct (Wave 1 — library-only, zero generator touch)

**Files changed:**
- `lib/sigra/session.ex` — defstruct + @type + `## Fields` doc
- `lib/sigra/session_stores/ecto.ex` — `create/3` attrs map + `to_session/1`
- `test/support/test_user_session.ex` — schema field

**Tests extended:**
- `test/sigra/session_test.exs` — add `:active_organization_id` to the "struct can be created with all fields" test and any similar fixtures
- `test/sigra/session_stores/ecto_test.exs` — add an assertion in `create/3` and `fetch/2` tests proving the field round-trips through the schema and back into the Session struct. The existing test at line 56-68 builds a `%Sigra.Test.UserSession{}` literal — add `active_organization_id: <uuid>` and assert the resulting `Session` struct carries the same value.

**Downstream risk:** None inside Wave 1 if all mox expectations are updated. The walker-based tests don't exercise this path.

### Seam 2: Feature manifest + new migration template (Wave 2)

**Files changed:**
- `lib/sigra/install/features/core.ex`:
  - `migrations/1` returns 4 slots (insert between `:primary` and `:api_token`)
  - `base_files/1` inlines the new migration template — **position MATTERS for STDOUT ordering**; see §Risks. Recommended position: immediately after `primary_migration` (current line 151), before the "Core schemas + context" comment block.
- NEW: `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs`

**Tests extended:**
- `test/sigra/install/features/core_test.exs` — see §Mechanical Reference /15 above; 5 sites to update.
- `test/sigra/install/templates_layout_test.exs` — verify whether it enumerates template files; if yes, add the new file to its allow list.

### Seam 3: Generated Scope + UserSession templates (Wave 3 — parallel with Seam 2)

**Files changed:**
- `priv/templates/sigra.install/core/scope.ex` — defstruct + @type + @moduledoc reserved-field note
- `priv/templates/sigra.install/core/user_session.ex` — one new `field/2` line

**Tests created:**
- NEW: `test/sigra/install/scope_template_invariants_test.exs`

**Tests extended:**
- `test/sigra/install/generator_reset_test.exs` — if it has any `scope.ex`-specific assertions (grep required); the file currently focuses on `reset_password_*` and `user_auth.ex` per lines 23-160 so likely no changes.

### Seam 4: Golden-diff fixture rebase (Wave 4 — depends on Seams 2 + 3)

**Files changed:**
- `test/fixtures/install_golden/STDOUT.txt` — insert one `* creating priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs` line at the correct position
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex` — update committed rendered version to match new defstruct (context_module=`SigraInstallGoldenTmp.Accounts`, schema_alias=`User`)
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/user_session.ex` — add the new `field/2`
- NEW: `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_add_active_organization_id_to_user_sessions.exs` — committed expected rendered output

**Procedure:** run `mix test --only golden` once Seams 1-3 are green and let it fail with the tree/STDOUT diff. Copy the actual (normalized) tree into the fixture. Verify STDOUT.txt diff before committing — it should contain exactly ONE new line at the correct position plus zero changes anywhere else.

### Seam 5: Example app mirror (Wave 4 — parallel with Seam 4, both gated by Seams 1-3)

**Files changed:**
- `test/example/lib/example/accounts/scope.ex` — mirror new defstruct (rendered for Example.Accounts.User)
- `test/example/lib/example/accounts/user_session.ex` — add the new `field/2`
- NEW: `test/example/priv/repo/migrations/20260410125243_add_active_organization_id_to_user_sessions.exs` — hand-written migration matching template output

**Tests extended:**
- Add a new smoke test under `test/example/test/example_web/smoke/` that exercises D-14 end-to-end. See §Test Infrastructure / End-to-end round-trip for the test skeleton.

### Seam 6: Upgrade doc (Wave 5 — zero code deps, can land first or last)

- NEW: `UPGRADE-v1.2.md` at project root

## Test Infrastructure

### What exists

| Capability | Location | Reusable as-is? |
|------------|----------|-----------------|
| EEx template render in unit tests | `test/sigra/install/generator_reset_test.exs` lines 165-174 | Yes — helper pattern, copy to new test |
| EEx template read (source-level grep) | `test/sigra/install/generator_reset_test.exs` lines 185-189 | Yes |
| Full installer byte-identity snapshot | `test/sigra/install/golden_diff_test.exs` + `test/support/install_fixture.ex` | Yes — runs `mix phx.new` + `mix sigra.install`, captures + normalizes |
| Session struct unit tests | `test/sigra/session_test.exs` (line 1-40 verified) | Extend with new field |
| SessionStore Ecto round-trip via Mox | `test/sigra/session_stores/ecto_test.exs` uses `Sigra.Test.UserSession` + `Sigra.MockRepo` | Extend with new field assertions |
| Example app context-layer smoke tests | `test/example/test/example_web/smoke/register_login_logout_test.exs` | Extend with D-14 round-trip test |
| Feature manifest unit tests | `test/sigra/install/features/core_test.exs` | Extend counts + slots |
| Plug session write/read | `test/example/test/example_web/user_auth_test.exs` lines 61-103 already calls `Plug.Conn.get_session(logged_in_conn, :user_token)` | Template pattern for D-14 |

### End-to-end round-trip test (D-14)

CONTEXT.md D-14 specifies the assertion as "write `active_organization_id` onto the session via `Sigra.Session`, persist via `SessionStore`, reload, assert the value round-trips, also read via `Plug.Conn.get_session/2`." The planner should recognize that **the second half of that sentence is ambiguous** because `Plug.Conn.get_session/2` in Sigra's stack reads only the cookie-serialized map — and Sigra currently only puts `:user_token` into the cookie session (verified `lib/sigra/plug/fetch_session.ex` lines 69, 91-94). The `active_organization_id` lives on the DB row, NOT in the cookie. Phase 14 is what adds a plug that hydrates `scope.active_organization` from the DB row.

**Recommended interpretation** (flag with user if unclear during planning): the D-14 round-trip test should assert **two distinct things**, not one:

1. **DB round-trip (hard requirement, easy):** under `test/example/test/example_web/smoke/`, write `active_organization_id` via struct-update on a `%Sigra.Session{}`, persist via `Accounts` (or directly via `Sigra.SessionStores.Ecto`), reload via `SessionStore.fetch/2`, assert the value survives. Uses the real Postgres via `Example.DataCase` (async: true, SQL sandbox).
2. **Cookie session surface (soft — prove path is clean):** log in a user via the normal `SessionController` flow, assert `Plug.Conn.get_session(conn, :user_token)` returns the expected token, and assert the `conn.private[:sigra_session].active_organization_id` (from `FetchSession` plug) is `nil` on a fresh login. This proves the plug pipeline didn't crash on the new field — which is enough for Phase 12. Phase 14 extends this with actual hydration.

If the user intended the cookie session to literally carry `active_organization_id` in v1.1, that is an extra plug change that Phase 12 does NOT currently scope. Flag at plan-check.

### Validation Architecture

Nyquist enabled per `.planning/config.json` (`workflow.nyquist_validation: true`).

#### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18+ / 1.19.5 stable), plus the `test/example/` sub-project for generator smoke tests |
| Config file | `test/test_helper.exs`, `test/example/test/test_helper.exs` |
| Quick run command | `mix test test/sigra/session_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/install/features/core_test.exs test/sigra/install/scope_template_invariants_test.exs` |
| Full suite command | `mix test` then `cd test/example && mix test` |
| Golden-diff run | `mix test --only golden` (slow, 300s timeout, shells out to mix phx.new) |

#### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-SCOPE-01 | `%Scope{}` defstruct has 4 fields | unit | `mix test test/sigra/install/scope_template_invariants_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-01 | Generated Scope compiles + struct has `:impersonating_from` | unit | same | ❌ Wave 0 |
| ORG-SCOPE-01 | Golden diff reflects scope template change | integration | `mix test --only golden` | ✅ (update fixture) |
| ORG-SCOPE-01 | Compile-without-warnings in example app | integration | `cd test/example && mix compile --warnings-as-errors` | ✅ (CI already runs) |
| ORG-SCOPE-02 | `%Sigra.Session{}` has new field | unit | `mix test test/sigra/session_test.exs` | ✅ (extend) |
| ORG-SCOPE-02 | Ecto SessionStore round-trips new field | unit (Mox) | `mix test test/sigra/session_stores/ecto_test.exs` | ✅ (extend) |
| ORG-SCOPE-02 | New migration slot exists in feature manifest | unit | `mix test test/sigra/install/features/core_test.exs` | ✅ (extend) |
| ORG-SCOPE-02 | End-to-end DB round-trip | integration | `cd test/example && mix test test/example_web/smoke/session_active_org_round_trip_test.exs` | ❌ Wave 0 |
| ORG-SCOPE-02 | Golden diff reflects new migration file + updated user_session template | integration | `mix test --only golden` | ✅ (update fixture) |

#### Sampling Rate
- **Per task commit:** `mix test test/sigra/session_test.exs test/sigra/session_stores/ test/sigra/install/features/core_test.exs test/sigra/install/scope_template_invariants_test.exs` (fast, ~5-15s)
- **Per wave merge:** `mix test` (full library suite) + `mix test --only golden` (slow, manually invoked because of the phx.new shell-out)
- **Phase gate:** full library suite green + `cd test/example && mix test` green + golden-diff green + `cd test/example && mix compile --warnings-as-errors` green

#### Wave 0 Gaps
- [ ] `test/sigra/install/scope_template_invariants_test.exs` — covers ORG-SCOPE-01 reserved-field discipline
- [ ] `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs` (or similar name) — covers ORG-SCOPE-02 end-to-end
- [ ] No framework install needed — ExUnit is built in; `test/example/` Mix project already configured

No new test framework or fixture infrastructure needed — everything Phase 12 requires is already wired by Phase 10.1.1 (example app) and Phase 11 (golden-diff harness).

## Architecture Patterns

### Pattern 1: Additive slot extension (Phase 11 inheritance)

**What:** Phase 12 is the first phase to prove the Phase 11 "add a slot without touching existing slots" invariant. The `:active_org_column` slot slides in without modifying `:primary`, `:api_token`, or `:audit_events`. `MigrationTimestamps.allocate/2` automatically reorders timestamps (all shifted by +1s beyond the new slot).

**When to use:** Always, when adding a new installer-emitted migration after Phase 11.

### Pattern 2: Template invariant via source-level regex + render-and-introspect

**What:** D-11 combines two orthogonal checks: a fast regex check that catches renames and a slower compile-and-introspect check that catches structural refactoring.

**Precedent:** `generator_reset_test.exs` lines 165-174 established the EEx-eval-then-assert pattern. Phase 12 adds compilation + struct introspection on top.

### Pattern 3: Dialect-agnostic ALTER for additive columns

**What:** The `alter table ... add :col, :binary_id` DSL is identical across PostgreSQL, MySQL, and SQLite in Ecto SQL 3.13. The primary migration `migration.exs` branches on `adapter` because it uses `citext` and type-specific defaults; the ALTER migration does not.

**Source:** Ecto SQL 3.13 docs (https://hexdocs.pm/ecto_sql/Ecto.Migration.html) [VERIFIED: hexdocs], fly-apps/safe-ecto-migrations guidance [CITED: .planning/research canonical refs].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration timestamp allocation | Don't add a `now + 1.hour` helper | `Sigra.Install.MigrationTimestamps.allocate/2` | Phase 11 D-04 established it; deterministic; already handles the exact use case |
| Migration target path | Don't build path strings manually | `Sigra.Install.Features.Core.migration_target/3` | Threaded binding support; test-friendly placeholder fallback |
| Round-trip assertions for session struct | Don't add custom serialize/deserialize fn | Extend existing `to_session/1` and `attrs` map | SessionStore Ecto impl already handles Map.get pattern for every optional field |
| EEx template rendering in tests | Don't construct your own EEx harness | Copy pattern from `generator_reset_test.exs` | Already handles rescue-on-HEEx-CompileError case |

## Common Pitfalls

### Pitfall 1: defstruct atom-keyword ordering
**What goes wrong:** Adding `:active_organization_id` as a bare atom after `sudo_at: nil` triggers "atoms must precede keyword pairs in defstruct"
**Why it happens:** Elixir's `defstruct` requires all bare atoms before any keyword pairs
**How to avoid:** Use `active_organization_id: nil` (keyword form) since it follows keyword-form neighbors
**Warning signs:** Compile error at `lib/sigra/session.ex`

### Pitfall 2: Hardcoded counts in core_test
**What goes wrong:** Adding a slot or inlined migration silently breaks `assert length(...) == N` assertions
**Why it happens:** Phase 11 intentionally pinned exact counts for regression safety
**How to avoid:** Grep `core_test.exs` for every integer literal; update in the same commit
**Warning signs:** CI turns red in Wave 2 with "expected 36, got 37"

### Pitfall 3: Golden-diff STDOUT ordering
**What goes wrong:** Inlining the new migration at the wrong position in `base_files/1` produces STDOUT with the "* creating ... add_active_organization_id..." line at the wrong index, failing byte-identity
**Why it happens:** The walker prints `* creating <target>` in files-list order; STDOUT fixture is byte-checked
**How to avoid:** Insert the new migration tuple in `base_files/1` immediately AFTER `primary_migration` (current position 0) and BEFORE the "Core schemas + context" block — this puts the STDOUT line at position 1 of the fixture. Verify by running golden-diff and inspecting the diff.
**Warning signs:** Golden-diff test fails with "STDOUT diverges from fixture" showing the new line in the wrong position

### Pitfall 4: Example app timestamp collision
**What goes wrong:** Adding a `20260410125243_` file when that timestamp is already taken
**Why it happens:** The example app has two hard-coded migration timestamps (`125242` and `125244`)
**How to avoid:** `125243` is open; verify with `ls test/example/priv/repo/migrations/` before committing
**Warning signs:** Duplicate-migration-version error on `mix ecto.migrate` in the example app

### Pitfall 5: CONTEXT.md D-02 tuple shape drift
**What goes wrong:** CONTEXT.md D-02 shows `migrations/1` returning 2-tuples `{slot, path}`, but the actual `Sigra.Install.Feature` behaviour contract requires 3-tuples
**Why it happens:** CONTEXT.md was written quickly; the real shape is `{slot_key, template_path, target_basename}`
**How to avoid:** Use the 3-tuple form. This isn't a decision change — it's a typo in CONTEXT.md.
**Warning signs:** `(BadArityError)` at walker runtime, or `MigrationTimestamps.allocate/2` failing because it destructures `{slot_key, _template, _basename}` (line 36 of migration_timestamps.ex)

### Pitfall 6: EEx binding form for scope template
**What goes wrong:** Using `EEx.eval_file(path, assigns: [...])` when the template uses plain `<%= context_module %>` (not `<%= @context_module %>`)
**Why it happens:** `generator_reset_test.exs` uses the `assigns:` form because its templates use `@assigns`; the scope template does NOT
**How to avoid:** Pass a plain keyword list: `EEx.eval_file(path, [context_module: "...", schema_alias: "..."])`
**Warning signs:** `undefined function context_module/0` or `(KeyError)` at EEx eval time

### Pitfall 7: Compiling rendered Scope requires a referenced User module
**What goes wrong:** `Code.compile_string(rendered_scope)` fails because the template emits `alias TestApp.Accounts.User` and `%User{}` pattern matches against a module that doesn't exist
**Why it happens:** The template has a real compile-time dependency on the User module
**How to avoid:** Compile a dummy `TestApp.Accounts.User` struct first (`defmodule TestApp.Accounts.User, do: defstruct([:id])`); or fall back to a regex-only assertion if the compile path proves fragile across Elixir versions
**Warning signs:** `(CompileError) undefined module TestApp.Accounts.User`

## Code Examples

Verified patterns from the codebase.

### Extending the Session struct (Pattern from existing struct)

```elixir
# lib/sigra/session.ex
@type t :: %__MODULE__{
        # ... existing fields ...
        sudo_at: DateTime.t() | nil,
        active_organization_id: binary() | nil,   # NEW
        inserted_at: DateTime.t() | nil
      }

defstruct [
  :id, :user_id, :token, :hashed_token,
  type: :standard,
  ip: nil,
  user_agent: nil,
  parsed_ua: nil,
  geo_city: nil,
  geo_country_code: nil,
  last_active_at: nil,
  sudo_at: nil,
  active_organization_id: nil,   # NEW
  inserted_at: nil
]
```

### Extending Ecto SessionStore round-trip

```elixir
# lib/sigra/session_stores/ecto.ex, create/3 attrs map
attrs = %{
  user_id: user_id,
  hashed_token: hashed_token,
  type: to_string(Map.get(metadata, :type, :standard)),
  ip: Map.get(metadata, :ip),
  user_agent: Map.get(metadata, :user_agent),
  geo_city: Map.get(metadata, :geo_city),
  geo_country_code: Map.get(metadata, :geo_country_code),
  active_organization_id: Map.get(metadata, :active_organization_id),  # NEW (nullable)
  last_active_at: now,
  inserted_at: now
}

# lib/sigra/session_stores/ecto.ex, to_session/1
%Sigra.Session{
  id: record.id,
  user_id: record.user_id,
  # ... existing ...
  sudo_at: Map.get(record, :sudo_at),
  active_organization_id: Map.get(record, :active_organization_id),  # NEW
  inserted_at: Map.get(record, :inserted_at)
}
```

### Adding the feature-manifest slot (3-tuple form, NOT 2-tuple as CONTEXT.md D-02 shows)

```elixir
# lib/sigra/install/features/core.ex
@impl true
def migrations(_binding) do
  [
    {:primary, "core/migration.exs", "create_sigra_auth_tables.exs"},
    {:active_org_column, "core/add_active_organization_id_to_user_sessions.exs",
      "add_active_organization_id_to_user_sessions.exs"},
    {:api_token, "core/api_token_migration.exs", "create_user_api_tokens.exs"},
    {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"}
  ]
end
```

### Inlining into `base_files/1`

```elixir
# lib/sigra/install/features/core.ex, base_files/1
defp base_files(binding) do
  otp_app = otp_app_str(binding)
  ctx = context_underscore(binding)
  web = "#{otp_app}_web"

  primary_migration =
    {:eex, "core/migration.exs",
     migration_target(binding, :primary, "create_sigra_auth_tables.exs")}

  active_org_migration =
    {:eex, "core/add_active_organization_id_to_user_sessions.exs",
     migration_target(binding, :active_org_column,
       "add_active_organization_id_to_user_sessions.exs")}

  audit_migration =
    {:eex, "core/create_audit_events.exs",
     migration_target(binding, :audit_events, "create_audit_events.exs")}

  [
    primary_migration,
    active_org_migration,     # NEW — immediately after primary
    # ... rest of base_files unchanged ...
  ]
end
```

### Scope template invariant test skeleton

See §Mechanical Reference /13 above.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Wall-clock timestamp allocation | Slot-based `MigrationTimestamps.allocate/2` | Phase 11 D-04 | Deterministic, manifest-ordered |
| Monolithic `Mix.Tasks.Sigra.Install` | Feature behaviour + walker + `Features.Core` | Phase 11 D-01/D-03 | Phase 12 extends via additive edits |
| Scope with `defstruct user: nil` only | Phase 12: 4 fields — `user`, `active_organization`, `membership`, `impersonating_from` | Phase 12 | Matches Phoenix 1.8 scopes guide; v1.2-prep |
| Session without org pointer | Session with `:active_organization_id` | Phase 12 | v1.1 Foundations becomes org-aware |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `alter table ... add :col, :binary_id` is identical across PG/MySQL/SQLite in Ecto SQL 3.13 — no branching | Pattern 3, §10 | [ASSUMED from Ecto docs; PLANNER should verify by running `cd test/example && mix ecto.migrate` locally] If wrong, need dialect branching in the new migration template |
| A2 | `test/example/priv/repo/migrations/20260410125243_*.exs` slot is free | §Mechanical /12 | Low — `ls` confirms only `...5242` and `...5244` exist |
| A3 | `base_files/1` has exactly 25 `{:eex, ...}` tuples (derivation of "25 base_files + 9 ui + 2 migrations = 36") | §Mechanical /15 | Medium — the planner should re-count by inspection before updating the hardcoded count. If core_test has more assertions than documented, updates expand accordingly. |
| A4 | The scope template compile-and-introspect check works with `Code.compile_string` + pre-compiled dummy User | §Mechanical /13 | Medium — if compilation proves fragile, fall back to source-level regex only |
| A5 | D-14 round-trip is interpreted as (a) DB round-trip + (b) cookie session read of `:user_token` (NOT `active_organization_id` in cookie) | §Test Infrastructure | Medium — if user intended cookie to carry the org ID literally, Phase 12 scope expands |
| A6 | STDOUT fixture does not need to reorder any existing lines — just insert ONE new line after the primary migration creation line | §Risks | High — verified by reading STDOUT.txt lines 1-24, but only golden-diff run confirms |
| A7 | The example app's `DataCase` uses `Ecto.Adapters.SQL.Sandbox` with async: true, so round-trip tests can be fast unit tests | §Test Infrastructure | Low — standard Phoenix 1.8 scaffolding |

## Open Questions

1. **D-14 interpretation — does the cookie session carry `active_organization_id` in Phase 12?**
   - What we know: `FetchSession` plug currently only stores `:user_token` in the Plug cookie. The DB row is the source of truth. Phase 14 adds hydration.
   - What's unclear: whether D-14's "read via `Plug.Conn.get_session/2`" meant "prove the plug pipeline survives the new field's presence" (easy) or "actually store and retrieve the org ID via cookie" (requires new plug code, likely out of scope for Phase 12).
   - Recommendation: Default interpretation is option A (prove pipeline survives). Flag at plan-check for user confirmation before implementing option B.

2. **Reserved-field check: regex + compile, or regex only?**
   - What we know: The EEx render-and-eval pattern is proven in `generator_reset_test.exs`. Compiling a rendered Scope is one step further.
   - What's unclear: whether `Code.compile_string` + pre-compiled dummy User is stable across Elixir 1.18/1.19 patch versions.
   - Recommendation: Try both. If the compile path is fragile, keep regex-only (it still catches `git rm impersonating_from` and most refactors). Document the choice in the test's moduledoc.

3. **Where should the new migration template be inlined in `base_files/1` for STDOUT ordering?**
   - What we know: STDOUT fixture line 1 is `* creating priv/repo/migrations/TIMESTAMP_create_sigra_auth_tables.exs`. Line 24 is `* creating priv/repo/migrations/TIMESTAMP_create_audit_events.exs`.
   - What's unclear: Whether the new line should appear as line 2 (immediately after primary) or line 24 (immediately before audit_events, matching where MFA migration currently is position-wise).
   - Recommendation: Insert as line 2 (immediately after primary). Rationale: (a) matches the `migrations/1` slot order, (b) the `add_active_organization_id_*` migration is semantically related to `user_sessions` which is created in the primary migration, (c) minimizes STDOUT diff surface. The planner should verify by running golden-diff in a scratch branch.

4. **Should `Sigra.Test.UserSession` match the generated `user_session.ex` exactly, or can it be minimal?**
   - What we know: It currently is minimal (no user FK, no :belongs_to). It just needs the fields the SessionStore code references.
   - What's unclear: Whether adding `active_organization_id` is enough, or whether Phase 12 should also align it to the full schema.
   - Recommendation: Minimal is enough — just add the one field. This file is purely a test fixture for Mox.

5. **Does `test/sigra/install/templates_layout_test.exs` enumerate template files?**
   - What we know: It was listed in the test dir but not inspected in this research pass.
   - Recommendation: Planner greps it at plan-creation time; if it has a hardcoded list of template filenames, update it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All work | ✓ (assumed — existing repo) | 1.18 or 1.19 | — |
| Erlang/OTP | All work | ✓ (assumed) | 27 or 28 | — |
| PostgreSQL | `test/example/` round-trip test | ✓ (required by existing example app) | — | — |
| `mix phx.new` | Golden-diff run | ✓ (existing) | Phoenix 1.8.5 | — |

No new external dependencies. Phase 12 touches no third-party libraries.

## Project Constraints (from CLAUDE.md)

- **Phoenix 1.8+ / Ecto 3.13** — All code changes stay within this stack.
- **PostgreSQL primary** — `binary_id` column type, no PG-specific features needed for the ALTER.
- **OWASP throughout** — Phase 12 is pure data-shape; no auth logic introduced. No Argon2, token, or crypto surface touched.
- **Minimal transitive deps** — Zero new deps.
- **Comprehensive spec coverage — AAA style, flat, self-contained** — New tests in `scope_template_invariants_test.exs` and the example-app round-trip test must follow this style.
- **LiveView optional** — No LiveView work in Phase 12.
- **GSD Workflow Enforcement** — Plan must route through `/gsd-execute-phase`.

## Sources

### Primary (HIGH confidence — source files directly read in this session)
- `lib/sigra/session.ex` (78 lines) — struct shape, type, docstring
- `lib/sigra/session_store.ex` (64 lines) — behaviour callback set
- `lib/sigra/session_stores/ecto.ex` (169 lines) — `create/3`, `to_session/1`
- `lib/sigra/install/feature.ex` (65 lines) — behaviour contract (3-tuple `migrations/1`)
- `lib/sigra/install/features/core.ex` (744 lines) — manifest + base_files layout
- `lib/sigra/install/migration_timestamps.ex` (52 lines) — slot allocator
- `lib/sigra/install/runner.ex` (188 lines) — walker + overlay logic
- `lib/sigra/plug/fetch_session.ex` (174 lines) — confirms cookie stores only `:user_token`
- `priv/templates/sigra.install/core/scope.ex` (38 lines) — template to extend
- `priv/templates/sigra.install/core/user_session.ex` (35 lines) — template to extend
- `priv/templates/sigra.install/core/migration.exs` (300 lines, verified do-not-edit invariant)
- `test/sigra/session_test.exs` (first 40 lines)
- `test/sigra/session_stores/ecto_test.exs` (first 80 lines, Mox schema usage)
- `test/sigra/install/features/core_test.exs` (first ~240 lines — counts + slot assertions)
- `test/sigra/install/generator_reset_test.exs` (EEx render helper pattern, lines 165-190)
- `test/sigra/install/golden_diff_test.exs` (199 lines, fixture mechanism + runbook pointer)
- `test/support/install_fixture.ex` (287 lines, setup_tmp_app + normalize helpers)
- `test/support/test_user_session.ex` (22 lines, Mox schema)
- `test/fixtures/install_golden/STDOUT.txt` (lines 1-40 — verified migration ordering)
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex` (rendered fixture to update)
- `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_sigra_auth_tables.exs` (contents verified)
- `test/example/lib/example/accounts/user_session.ex`, `scope.ex` (verified mirror state)
- `test/example/priv/repo/migrations/` listing (`20260410125242_*`, `20260410125244_*`)
- `.planning/REQUIREMENTS.md` ORG-SCOPE-01, ORG-SCOPE-02
- `.planning/ROADMAP.md` Phase 12 entry
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — all 16 decisions
- `.planning/config.json` — nyquist_validation: true

### Secondary (MEDIUM — conceptual, from canonical references in CONTEXT.md)
- [Phoenix 1.8 scopes guide](https://hexdocs.pm/phoenix/scopes.html) [CITED: CONTEXT.md canonical refs] — defstruct + put_*/2 setter precedent
- [Oban migrations](https://hexdocs.pm/oban/installation.html) [CITED] — versioned migration pattern (Phase 12 does not use this directly but D-01 rationale cites it)
- [Dashbit: Automatic and manual Ecto migrations](https://dashbit.co/blog/automatic-and-manual-ecto-migrations) [CITED] — "never edit released migrations, layer ALTERs"
- [fly-apps/safe-ecto-migrations](https://github.com/fly-apps/safe-ecto-migrations) [CITED] — safe column addition patterns

### Tertiary (LOW — not verified this session, assumed from training + CLAUDE.md)
- Ecto SQL 3.13 dialect behavior for `alter table add :col, :binary_id` [ASSUMED; A1 in Assumptions Log]

## Metadata

**Confidence breakdown:**
- Mechanical reference (line numbers, current shapes): HIGH — every file listed was read in this session
- Integration seams: HIGH — derived directly from file reads
- Test infrastructure claims: HIGH — file paths and function signatures verified
- CONTEXT.md D-02 tuple-shape correction: HIGH — verified against behaviour contract + actual code
- D-14 interpretation: MEDIUM — flagged as open question
- Ecto SQL dialect behavior for ALTER: MEDIUM — assumed from training; flag A1

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (30 days — stable codebase, no fast-moving deps in scope)
