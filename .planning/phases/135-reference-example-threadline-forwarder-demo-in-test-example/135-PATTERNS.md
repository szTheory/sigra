# Phase 135: Reference Example — Threadline Forwarder Demo in `test/example/` - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 6 (1 new test, 5 modified/generated wiring files)
**Analogs found:** 6 / 6 (every file has a concrete in-repo analog; no RESEARCH.md fallback needed)

This is a pure wiring + assertion phase over **frozen** library code (`lib/sigra/audit/forwarders/threadline.ex`) and **generator output** (`mix threadline.install`). No new `lib/` code, no new `examples/` dir, no new CI job. Every analog below is a current in-repo file — the planner should pin against these excerpts, not paraphrase them.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/test/example_web/threadline_forwarder_test.exs` (NEW) | test (integration) | event-driven → request-response → CRUD-read | `test/example/test/example_web/audit_integration_test.exs` | exact (one hop downstream) |
| `test/example/lib/example/accounts.ex` — `forwarders:` in `sigra_config/0` (~607-609) | config (keyword DSL) | request-response (config read) | the existing `audit:` block in the same fn (607-609) | exact (sibling key, same fn) |
| `test/example/config/config.exs` — `forwarders:` in `:sigra_config` (~50-52) | config (app-env) | request-response (config read) | the existing `audit:` block at 50-52 | exact (mirror of accounts.ex) |
| `test/example/mix.exs` — Threadline dep (~69) | config (deps) | n/a | the existing `{:mox, "~> 1.1", only: :test}` dep (line 69) | exact (`only:` scope precedent) |
| `test/example/priv/repo/migrations/*_threadline_audit_schema.exs` + `*_threadline_semantics_schema.exs` (2 NEW, generated) | migration | batch DDL | `Threadline.{Capture,Semantics}.Migration.migration_content/0` (canonical source) + existing example migrations for sort-order context | role-match (generated body; format differs — see note) |
| `test/example/AGENTS.md` — new "Threadline audit forwarder demo" section | docs | n/a | the existing `## …` / `### …` section-header style in the same file | exact (additive section) |

## Pattern Assignments

### `test/example/test/example_web/threadline_forwarder_test.exs` (NEW — the crux deliverable)

**Analog:** `test/example/test/example_web/audit_integration_test.exs` (full file, 1-77). The new test reuses this scaffold verbatim for the setup + login-trigger + `Repo.one(from …)` assertion, then follows the row one hop downstream into `Threadline.Semantics.AuditAction`.

**Header / use / tag / setup pattern** (analog lines 15-33) — copy structurally:
```elixir
use ExampleWeb.ConnCase, async: true

import Ecto.Query

alias Example.Accounts
alias Example.Accounts.AuditEvent
alias Example.Repo

@moduletag :example_app          # D-10 — the ONLY tag; do NOT add :requires_threadline

setup do
  {:ok, user} =
    Accounts.register_user(%{
      email: "b8-#{System.unique_integer([:positive])}@example.test",
      password: "CorrectHorseBattery123!"
    })

  %{user: user}
end
```
For the new test, the `setup` ALSO attaches the forwarder the example Application never attaches (D-07/D-08). RESEARCH §"Open Questions 2" recommends `register_user` FIRST, THEN attach, so registration-time events are never forwarded. Attach shape (executor discretion, D-13; signature pinned below):
```elixir
:ok =
  Sigra.Audit.Forwarders.Threadline.attach(
    repo: Example.Repo,   # D-08 — owns the SQL Sandbox conn (see ownership note below)
    id: :test,
    dispatch: :sync,      # D-06 — deterministic inline; NOT :auto, NEVER :async
    actor_type: :user
  )
on_exit(fn -> :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test}) end)
```
The detach key MUST be `{Sigra.Audit.Forwarders.Threadline, :test}` — the handler id `attach/1` builds is `{__MODULE__, Keyword.get(opts, :id, :default)}` (see `attach/1` excerpt below), so `id: :test` ⇒ that exact tuple.

**Login-trigger + source-row query pattern** (analog lines 51-71) — copy, then extend:
```elixir
conn
|> Plug.Test.init_test_session(%{})
|> ExampleWeb.UserAuth.log_in_user(user)     # D-03 — drive the REAL auth path

row =
  Repo.one(
    from(a in AuditEvent,
      where: a.action == "session.create" and a.actor_id == ^user.id,
      order_by: [desc: a.inserted_at],
      limit: 1
    )
  )

assert row != nil
assert row.action == "session.create"
assert row.actor_id == user.id
```
The new test renames this `row` → `audit_event` (it is the join key), then adds the downstream hop:
```elixir
alias Threadline.Semantics.AuditAction

action =
  Repo.one(from a in AuditAction, where: a.correlation_id == ^audit_event.id)

assert action,            "Threadline audit_actions row did not materialize"
assert action.name == "session.create"
assert action.status == :ok
assert action.actor_ref.id == user.id     # ActorRef.new(:user, user.id)
assert action.actor_ref.type == :user
```

**Query target — `Threadline.Semantics.AuditAction` schema** (source: `deps/threadline/lib/threadline/semantics/audit_action.ex:35-53`). These are the exact fields/types the assertions hit:
```elixir
schema "audit_actions" do
  field(:name, :string)                                          # stored as STRING "session.create"
  field(:actor_ref, Threadline.Semantics.ActorRef)              # JSONB; loads as %ActorRef{type: :user, id: "..."}
  field(:status, Ecto.Enum, values: [ok: "ok", error: "error"]) # loads as :ok
  field(:correlation_id, :string)                              # == audit_event.id (the join key)
  # ... verb, category, reason, comment, request_id, job_id (all optional/nil here)
end
@required_fields ~w(name actor_ref status)a
```
- `name` is queried/asserted as the STRING `"session.create"` (the forwarder atom-izes via `String.to_atom`, Threadline stores `Atom.to_string`). Assert the string.
- `status` loads as the atom `:ok` (Ecto.Enum). Assert `== :ok`.
- `actor_ref` loads as `%Threadline.Semantics.ActorRef{type: :user, id: user.id}` — assert `.type`/`.id` via struct access (NOT map access; per AGENTS.md "never use map access syntax on structs").
- `correlation_id` is a `:string` holding the Sigra audit UUID. `audit_event.id` is `binary_id` — Ecto casts the binding in the `where:` automatically.

**Forwarder `attach/1` signature** (source: `lib/sigra/audit/forwarders/threadline.ex:82-91`) — the contract the test setup calls; do NOT edit this file:
```elixir
@impl Sigra.Audit.Forwarder
def attach(opts) do
  handler_id = {__MODULE__, Keyword.get(opts, :id, :default)}
  :telemetry.attach(handler_id, @audit_log_event, &__MODULE__.handle_event/4, opts)
end
```
Accepted opts read downstream (`call_threadline/2`, lines 238-241): `:threadline_module` (default `Threadline`), `:actor_type` (default `:user`), `:repo`. `:dispatch` is read by `resolve_dispatch_mode/1` (227-232): `:auto` collapses to `:sync` when `oban_running?/1` is false (the example's case), but D-06 pins `:sync` explicitly.

**The `:sync` mapping the assertions verify** (source: `lib/sigra/audit/forwarders/threadline.ex:248-299`) — this is the contract under test (do NOT re-implement; assert its output):
```elixir
status =
  case metadata[:outcome] do
    :success -> :ok ; "success" -> :ok
    :failure -> :error ; "failure" -> :error ; :error -> :error
    _ -> :ok
  end
# name: String.to_atom("session.create") when metadata[:action] is a binary
call_opts =
  [repo: repo, status: status, correlation_id: metadata[:id]]   # correlation_id @ line 295 = the join key
  |> add_actor_opt(actor_ref)                                   # actor_ref = ActorRef.new(:user, metadata[:actor_id])
threadline.record_action(name, call_opts)                       # @ line 299
```
`record_action/2` (source `deps/threadline/lib/threadline.ex:40-62`) requires `:repo` + `:actor`/`:actor_ref`, builds the changeset, calls `repo.insert/1`, returns `{:ok, %AuditAction{}}`.

**SQL Sandbox ownership (D-08, Pitfall 4 — why `repo: Example.Repo` is necessary AND sufficient):** `data_case.ex:38-41` does `start_owner!(Example.Repo, shared: not tags[:async])`. With `async: true` the conn is owner-pid-bound. BUT the `[:sigra, :audit, :log]` handler runs synchronously in the calling (test) process, and `log_in_user` runs in the test process, so `handle_event → call_threadline → Example.Repo.insert` all run on the owned connection. Pass `repo: Example.Repo`; keep `:sync`; introduce no spawned/async execution in the forward path.

**What MUST change vs. the analog:**
- Add the forwarder `attach/1` + `on_exit` detach in `setup` (analog has none).
- Add `alias Threadline.Semantics.AuditAction`.
- Rename the source `row` to `audit_event` and add the downstream `AuditAction` query + 4 assertions (name/status/actor_ref.id/actor_ref.type).
- Keep `async: true` and `@moduletag :example_app` exactly (D-10).
- Per RESEARCH Validation Architecture: do NOT weaken to "some row exists" — the `correlation_id == audit_event.id` join is mandatory (anti-under-sampling).

---

### `test/example/lib/example/accounts.ex` — `forwarders:` block in `sigra_config/0` (~607-609)

**Analog:** the existing `audit:` block in the SAME function (`sigra_config/0`, lines 590-622). The new `forwarders:` key slots INSIDE the existing `audit:` keyword list (EX-01 says "under the existing `audit:` keyword").

**Existing block to extend** (lines 604-609):
```elixir
# Activate Sigra's built-in audit integration. Without this wiring,
# Sigra.Audit.log_safe/2 is a silent no-op and no audit rows are
# written for session.create, auth.login.*, etc.
audit: [
  audit_schema: Example.Accounts.AuditEvent
],
```
The `forwarders:` entry becomes a second key inside that `audit:` list:
```elixir
audit: [
  audit_schema: Example.Accounts.AuditEvent,
  forwarders: [
    [
      module: Sigra.Audit.Forwarders.Threadline,
      id: :default,
      dispatch: :auto,          # see recipe-parity decision below
      repo: Example.Repo
    ]
  ]
],
```

**Recipe-parity vs. dead-config (RESEARCH Open Question 1, CONTEXT `<specifics>`):** The published recipe block (`guides/recipes/companion-libs/threadline.md:62-71`) is:
```elixir
forwarders: [
  [
    module: Sigra.Audit.Forwarders.Threadline,
    dispatch: :auto,
    id: :default,
    endpoint: System.get_env("THREADLINE_ENDPOINT"),
    api_key: System.get_env("THREADLINE_API_KEY")
  ]
]
```
RESEARCH (verified against `call_threadline/2`) confirms the forwarder reads ONLY `:repo`, `:id`, `:dispatch`, `:actor_type`, `:threadline_module` — `endpoint:`/`api_key:` are **dead config** (Threadline 0.5.0 is DB-based, not HTTP). RESEARCH recommends: keep the published `dispatch: :auto` literal in the committed config (grep fidelity) but DROP `endpoint:`/`api_key:` and ADD `repo: Example.Repo`. The deterministic `dispatch: :sync` lives ONLY in the test's `attach/1` call (D-06/D-07). The committed config is a grep/reference artifact — the vanilla `Example.Application` never calls `attach_forwarders/0`, so this block is never actually attached at example boot. Planner picks the exact shape; both D-06-compliant.

**What MUST change:** add the `forwarders:` key inside `audit:`. Do NOT touch any other key in `sigra_config/0`. Do NOT add `endpoint:`/`api_key:`.

---

### `test/example/config/config.exs` — `forwarders:` block mirrored in `:sigra_config` (~50-52)

**Analog:** the existing `audit:` block at lines 50-52 — a direct mirror of the `accounts.ex` block.

**Existing block to extend** (lines 43-52):
```elixir
config :example, :sigra_config,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  session: [
    store: Sigra.SessionStores.Ecto,
    session_schema: Example.Accounts.UserSession
  ],
  audit: [
    audit_schema: Example.Accounts.AuditEvent
  ],
```
Mirror the SAME `forwarders:` entry chosen for `accounts.ex` into this `audit:` list (D-12). `config.exs` is the surface `Sigra.Application.attach_forwarders/0` actually reads (per CONTEXT D-12), and dual placement satisfies success criterion #2 (adopter greps `test/example/` for "threadline" and finds a working reference). Keep the two blocks identical for copy-paste fidelity.

**What MUST change:** add the identical `forwarders:` key inside this `audit:` list. Keep it byte-for-byte consistent with the `accounts.ex` block.

---

### `test/example/mix.exs` — Threadline dep (~69)

**Analog:** the existing `{:mox, "~> 1.1", only: :test}` dep (line 69) — the in-file precedent for scoping a non-production dep with `only:`. Sigra's optional deps (`swoosh`, `oban`, `hammer`, `assent`, `joken`, `eqrcode`, lines 62-68) are listed plainly without scope.

**Existing deps tail to extend** (lines 62-70):
```elixir
# Sigra transitive/optional deps
{:swoosh, "~> 1.5"},
{:oban, "~> 2.17"},
{:hammer, "~> 7.3"},
{:assent, "~> 0.3"},
{:joken, "~> 2.6"},
{:eqrcode, "~> 0.2.1"},
{:mox, "~> 1.1", only: :test}
```
Add the new dep (D-09) — note `only: [:dev, :test]`, NOT `:test`-only (so the forwarder module compiles in the dev-boot smoke lanes and emits no `maybe_warn_missing_forwarder_deps` warning):
```elixir
{:threadline, "~> 0.5", only: [:dev, :test]}
```
`~> 0.5` matches the Phase 132 recipe pin and the root `mix.lock` (0.5.0). The root repo's `mix.lock:52` already pins `threadline 0.5.0`; the example's `test/example/mix.lock` must be committed updated (RESEARCH Runtime State Inventory — CI cache key hashes `test/example/mix.lock`).

**Aliases (no change needed, but load-bearing):** the `test` alias (line 84) is `["ecto.create --quiet", "ecto.migrate --quiet", "test"]` — so the two committed Threadline migrations auto-apply in CI with NO lane edit (D-02, D-11).

**What MUST change:** append the one dep line (comma on the prior `mox` line). Commit the regenerated `test/example/mix.lock`.

---

### Two migrations under `test/example/priv/repo/migrations/` (2 NEW, generated by `mix threadline.install`)

**Analog (body source):** `Threadline.Capture.Migration.migration_content/0` and `Threadline.Semantics.Migration.migration_content/0` — the canonical generated bodies. Do NOT hand-write the DDL (RESEARCH "Don't Hand-Roll"); run `mix threadline.install` (or call `migration_content/0` directly for controlled timestamps) and commit what it produces.

**Capture migration body** (`deps/threadline/lib/threadline/capture/migration.ex:17-64`) — creates `audit_transactions` + `audit_changes` + trigger fn. Module name `ThreadlineAuditSchema`:
```elixir
defmodule ThreadlineAuditSchema do
  use Ecto.Migration
  def up do
    execute """ CREATE TABLE IF NOT EXISTS audit_transactions ( id uuid PRIMARY KEY ..., txid bigint NOT NULL UNIQUE, ... ) """
    # ... indexes, audit_changes table, trigger fn ...
  end
  def down do ... end
end
```

**Semantics migration body** (`deps/threadline/lib/threadline/semantics/migration.ex:10-62`) — creates `audit_actions` (the test's query target) AND `ALTER TABLE audit_transactions ADD COLUMN …`. Module name `ThreadlineSemanticsMigration`:
```elixir
defmodule ThreadlineSemanticsMigration do
  use Ecto.Migration
  def up do
    execute(""" CREATE TABLE IF NOT EXISTS audit_actions ( id uuid PRIMARY KEY ..., name text NOT NULL, actor_ref jsonb NOT NULL, status text NOT NULL CHECK (status IN ('ok','error')), correlation_id text, ... inserted_at timestamptz NOT NULL DEFAULT now() ) """)
    # ... GIN/name/inserted_at indexes ...
    execute(""" ALTER TABLE audit_transactions ADD COLUMN IF NOT EXISTS actor_ref jsonb, ADD COLUMN IF NOT EXISTS action_id uuid REFERENCES audit_actions(id) ON DELETE SET NULL """)  # depends on capture's table (lines 48-52)
  end
  def down do ... end
end
```

**Ordering requirement (D-02):** semantics `ALTER`s a table capture creates, so capture MUST sort FIRST. Both files must be committed; the `test`/`setup` aliases apply them automatically.

**REAL EXECUTION RISK — Pitfall 2 (timestamp collision):** `mix threadline.install` writes BOTH files in a single `run/0` (`deps/threadline/lib/mix/tasks/threadline.install.ex:32,42`) using a SECOND-resolution UTC timestamp (`timestamp/0`, lines 92-95). The two files can share the SAME `YYYYMMDDHHMMSS` prefix → Ecto ordering is undefined / may raise "migration version … is duplicated". The executor MUST verify the two generated filenames have **distinct, ascending** prefixes with capture < semantics; if equal (or reversed), bump the semantics file's timestamp by +1 second. Module names (`ThreadlineAuditSchema`, `ThreadlineSemanticsMigration`) are distinct, so there is no module-name collision — only version-ordering. Fallback (RESEARCH Environment Availability): write the two files manually from `migration_content/0` with controlled ascending timestamps, pre-empting the collision entirely. Existing example migrations end at `20260526043000…`; the fresh `20260528…` files sort after them correctly — the only relative risk is the two new files vs. each other.

**FORMAT DIVERGENCE NOTE (planner must NOT "fix" it):** existing example migrations use the Phoenix convention `defmodule Example.Repo.Migrations.CreateOrganizationAuthPolicies do` + `def change do` (see `20260526043000_create_organization_auth_policies.exs:1-4`). The Threadline-generated migrations use BARE module names (`ThreadlineAuditSchema`, `ThreadlineSemanticsMigration`) + `def up`/`def down` and raw `execute "..."` DDL. This divergence is CORRECT and intentional — commit the generated bodies verbatim (RESEARCH "Don't Hand-Roll": hand-editing them to match the local convention risks drifting from the schema the `AuditAction` Ecto module expects). The mismatch is cosmetic and does not affect `ecto.migrate`.

**What MUST change:** add the two generated files; verify timestamp ordering; do NOT reformat the generated bodies.

---

### `test/example/AGENTS.md` — new "Threadline audit forwarder demo" section (D-13)

**Analog:** the existing `## …` (h2) / `### …` (h3) section-header style in the same file (e.g. `## Project guidelines` line 3, `### Phoenix v1.8 guidelines` line 8). The file is a mix of Phoenix usage-rules and project guidance; the addition is a NEW additive section, placed OUTSIDE the `<!-- usage-rules-start -->`…`<!-- usage-rules-end -->` fenced block (lines 22-190, which is generated and should not be hand-edited).

**Section content requirements (D-13, CONTEXT `<specifics>`, RESEARCH grep target):** a clearly-titled "Threadline audit forwarder demo" section that lets an adopter trace the wiring in under a minute (success criterion #2). It should point at: the dep (`mix.exs`), the config block (`accounts.ex` + `config.exs`), the test (`threadline_forwarder_test.exs`), and the two migrations. Prose voice is executor discretion (D-13).

**Voice constraint (CLAUDE.md / RESEARCH Project Constraints):** NO marketing voice — banned words: "seamlessly," "just works," "production-ready out of the box," "the recommended way." Match the file's existing terse, imperative guideline tone.

**What MUST change:** append one new h2 section (`## Threadline audit forwarder demo`) AFTER the `<!-- usage-rules-end -->` marker (or before `<!-- usage-rules-start -->` — anywhere outside the generated fence). Do NOT edit the fenced usage-rules block.

## Shared Patterns

### Example-app test scaffold (`@moduletag :example_app` + ConnCase + SQL Sandbox)
**Source:** `test/example/test/example_web/audit_integration_test.exs:15-33` ; sandbox in `test/example/test/support/data_case.ex:38-41`
**Apply to:** the new test file (the only test this phase adds).
- `use ExampleWeb.ConnCase, async: true`
- `@moduletag :example_app` — the ONLY tag (D-10). `test_helper.exs` excludes `:example_app` by default; the `example_unit_smoke` lane includes via `mix test --include example_app` (`ci.yml:267`). NEVER add `:requires_threadline` (that is the repo-root dep-off lane's concept; the example never runs in it).
- SQL Sandbox owner is `Example.Repo` with `shared: not tags[:async]` — pass `repo: Example.Repo` to `attach/1` so the inline `:sync` insert lands on the owned connection.

### Sigra config dual-surface (accounts.ex + config.exs)
**Source:** `test/example/lib/example/accounts.ex:607-609` and `test/example/config/config.exs:50-52`
**Apply to:** the `forwarders:` block (both files, identical).
The example carries Sigra config in BOTH `sigra_config/0` (struct via `Sigra.Config.new!/1`) AND `config :example, :sigra_config` (app-env keyword). `attach_forwarders/0` reads the app-env surface; EX-01 names `accounts.ex`. The block goes in BOTH, kept identical, for grep fidelity (D-12).

### Optional-dep `only:` scoping in the example's mix.exs
**Source:** `test/example/mix.exs:69` (`{:mox, "~> 1.1", only: :test}`)
**Apply to:** the new Threadline dep — but use `only: [:dev, :test]` (broader than mox's `:test`) so the forwarder module compiles in dev-boot smoke lanes (D-09).

### Migrations auto-apply via the `test`/`setup` aliases
**Source:** `test/example/mix.exs:81-84` (`test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]`)
**Apply to:** the two committed Threadline migrations — they apply automatically in CI with NO lane edit (D-02, D-11). No new CI job (success criterion #3).

### Frozen library code — read, never edit
**Source:** `lib/sigra/audit/forwarders/threadline.ex` (whole file), `lib/sigra/audit/forwarders.ex`, `lib/sigra/audit.ex`, `lib/sigra/application.ex`
**Apply to:** all of this phase. Phase 135 writes ZERO `lib/` code. The forwarder's `attach/1` (82-91) and `call_threadline/2` (238-308) are the contracts the test calls/asserts — assert their OUTPUT, do not re-implement.

## No Analog Found

None. Every file this phase touches has a concrete in-repo analog (the existing `audit:` config blocks, the analog integration test, the `mox`-scoped dep, the existing migration files for sort-order context, and the AGENTS.md section style). RESEARCH.md's recommended test skeleton is itself derived from the live analog, so the planner can pin against repo files exclusively. The only non-repo-analog source is the two migration BODIES, which come from Threadline's `migration_content/0` generators (canonical generator output, committed verbatim) — not a missing analog, a deliberate "don't hand-roll" delegation.

## Metadata

**Analog search scope:** `test/example/` (test, lib, config, priv/repo/migrations, mix.exs, AGENTS.md), `lib/sigra/audit/`, `deps/threadline/lib/`, `guides/recipes/companion-libs/`.
**Files scanned (read this session):** `audit_integration_test.exs`, `forwarders/threadline.ex`, `semantics/audit_action.ex`, `semantics/actor_ref.ex`, `accounts.ex` (590-622), `config.exs` (40-69), `mix.exs`, `threadline.md`, `capture/migration.ex`, `semantics/migration.ex`, `application.ex`, `AGENTS.md`, `threadline.install.ex`, `threadline.ex` (40-62), `data_case.ex` (30-49), `20260526043000_…exs` + migrations dir listing.
**Pattern extraction date:** 2026-05-28
