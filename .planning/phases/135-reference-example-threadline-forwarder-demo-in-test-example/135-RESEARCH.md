# Phase 135: Reference Example — Threadline Forwarder Demo in `test/example/` - Research

**Researched:** 2026-05-28
**Domain:** Elixir/Phoenix integration test wiring (Sigra audit forwarder → Threadline 0.5.0 projection) inside the existing `test/example/` app
**Confidence:** HIGH (verification pass — CONTEXT.md is exhaustive; this research confirms it against the live tree and flags two drift items + one real execution risk)

## Summary

This is a confirmation/verification research pass over an already-exhaustive CONTEXT.md (13 locked decisions, assumptions-mode). Every load-bearing claim in CONTEXT.md was checked against the live tree (`lib/`, `deps/threadline/` @ 0.5.0, `test/example/`, `ci.yml`, the Phase 132 recipe). **The core decisions hold.** The end-to-end chain is real and queryable: `UserAuth.log_in_user/2` → `Sigra.Auth.create_session/4` → `Sigra.Audit.log_safe/2` emits `[:sigra, :audit, :log]` with metadata `%{id, action, actor_id, outcome}` (verified `lib/sigra/audit.ex:315-322`) → the attached `Sigra.Audit.Forwarders.Threadline` handler runs `:sync` inline → `Threadline.record_action/2` inserts an `audit_actions` row carrying `name="session.create"`, `actor_ref=%ActorRef{type: :user, id: user.id}`, `correlation_id=audit_event.id`, `status=:ok`.

Two minor line-number drifts were found in CONTEXT.md citations (the `threadline.ex` ranges shifted; exact lines below) — neither changes any decision. One **real execution risk** was found that CONTEXT.md does not call out: `mix threadline.install` generates BOTH migrations inside a single `run/0` invocation using a second-resolution UTC timestamp, so the two files can collide on the same `YYYYMMDDHHMMSS` prefix. If they do, Ecto's strict migration ordering will not reliably run capture-before-semantics (and may raise on a duplicated version). The planner MUST instruct the executor to verify the two generated timestamps differ and the capture file sorts first; if equal, bump the semantics file's timestamp by +1 second.

**Primary recommendation:** Proceed exactly per CONTEXT.md D-01..D-13. Pin `dispatch: :sync` on the test's `attach/1` call, pass `repo: Example.Repo`, attach in test setup with an `on_exit` `:telemetry.detach/1`. The committed config block should NOT carry HTTP-style `endpoint`/`api_key` keys (those are recipe cruft for an imagined HTTP Threadline — 0.5.0 is Ecto/DB-based and the forwarder reads only `:repo`, `:id`, `:dispatch`, `:actor_type`, `:threadline_module`). Verify/fix the two-migration timestamp ordering before relying on auto-migrate.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Test Materialization Strategy (the crux):**
- **D-01:** Test asserts a **real** `audit_actions` row inserted by Threadline's real schema/store. No Mox stub, no `threadline_module:` override, no test sink. The demo's value is a real end-to-end projection an adopter can copy.
- **D-02:** Commit the **two** `mix threadline.install` migrations into `test/example/priv/repo/migrations/` in dependency order — capture (creates `audit_transactions`) THEN semantics (ALTERs `audit_transactions` + creates `audit_actions`). Both required. The `test` alias runs `ecto.migrate --quiet`, so they apply automatically.
- **D-03:** Test triggers login through `ExampleWeb.UserAuth.log_in_user/2`, then asserts via `Example.Repo`: `Repo.one(from a in Threadline.Semantics.AuditAction, where: a.correlation_id == ^audit_event.id)` with `name == "session.create"` and actor reference carrying the user id. Sigra audit UUID → Threadline `:correlation_id` is the join key.
- **D-04:** Query the `Threadline.Semantics.AuditAction` Ecto schema directly. Threadline 0.5.0 exposes no `get_action_by_correlation_id`-style helper; the higher-level read APIs (`actor_history/2`, `timeline/2`) query the capture tables (`audit_transactions`/`audit_changes`), NOT `audit_actions`.
- **D-05:** Closest analog to copy structurally: `test/example/test/example_web/audit_integration_test.exs:55-71`. New test is one hop downstream into `audit_actions`.

**Dispatch Mode + Forwarder Attach Wiring:**
- **D-06:** Use `dispatch: :sync` (NOT `:auto`). The example supervises no Oban, so `:auto` already collapses to inline; pinning `:sync` makes intent explicit and assertion deterministic. `:async` is forbidden — raises at boot without Oban.
- **D-07:** **Attach the forwarder in the test setup**, not at app boot. `Example.Application.start/2` is a vanilla Phoenix tree that never calls `Sigra.Application.attach_forwarders/0`, so a config block alone does not auto-attach. Setup calls `Sigra.Audit.Forwarders.Threadline.attach(repo: Example.Repo, id: :test, dispatch: :sync, ...)` with `on_exit` `:telemetry.detach/1` using the same handler id.
- **D-08:** Pass `repo: Example.Repo` to `attach/1`. The `:sync` inline `record_action/2` runs in the test process, so the insert must use the repo that owns the SQL Sandbox connection — otherwise the row is invisible to the follow-up query and/or leaks past rollback.

**Dep Scope, CI Lane Reuse, Test Tagging:**
- **D-09:** Add `{:threadline, "~> 0.5", only: [:dev, :test]}` to `test/example/mix.exs` deps. `~> 0.5` matches the recipe pin. `:dev` scope (not `:test`-only) keeps the forwarder module compilable in the dev-boot smoke lanes, so the reference config emits no `maybe_warn_missing_forwarder_deps` warning at dev boot.
- **D-10:** Tag the new test `@moduletag :example_app` **only**. Do NOT add `:requires_threadline` — that tag is a library-suite concept for the repo-root dep-off lane; the example app is never part of that lane. `:example_app` is the gate (`test_helper.exs` excludes by default; lane includes via `--include example_app`).
- **D-11:** The existing `example_unit_smoke` lane runs `mix test --include example_app` (`ci.yml:267`) and executes the new test with **no new job**. Verify no other lane needs editing.
- **D-12:** Mirror the `forwarders:` block into `test/example/config/config.exs`'s `config :example, :sigra_config` too (in addition to `accounts.ex`). `config.exs` is the surface `attach_forwarders/0` actually reads; dual placement maximizes adopter-grep fidelity.
- **D-13:** Append a clearly-titled "Threadline audit forwarder demo" section to the existing `test/example/AGENTS.md` — additive, matching its existing section-header style.

### Claude's Discretion

- Exact migration filenames/timestamps for the two committed Threadline migrations (run `mix threadline.install`, commit what it generates, capture-then-semantics order). **See execution risk below — verify the two timestamps differ.**
- Whether the test attaches the forwarder in a `setup` block or inline per-test, and the exact `on_exit` detach shape — internal test structure.
- Exact `actor` mapping arg shape passed through to `record_action/2` (executor reads `lib/sigra/audit/forwarders/threadline.ex` for the `:actor` shape; test asserts the resulting `actor_ref` carries the user id).
- Prose voice of the `AGENTS.md` section and inline config-block comments.

### Deferred Ideas (OUT OF SCOPE)

- Recipe-contract test fixtures (walk `guides/recipes/companion-libs/*.md` and assert headings/pins/banner) — v1.29-future or post-v1.29.
- Threadline correlation-ID propagation (Sigra → Threadline trace correlation) — v1.30 candidate.
- `mix sigra.doctor` adopter-facing diagnostic — out of v1.29.
- A second forwarder (Datadog/Honeycomb/custom) demo — EX-01 scopes exactly one Threadline demo.
- **No new top-level `examples/` directory. No new CI jobs. No new `lib/` code.** (REQUIREMENTS.md Out-of-Scope.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EX-01 | `test/example/` extends with a working Threadline forwarder demo: `mix.exs` adds Threadline as dev/test dep; `accounts.ex` adds the `forwarders:` block under `audit:`; a new `threadline_forwarder_test.exs` asserts a Sigra audit event materializes as a Threadline row; `AGENTS.md` documents the wiring. No new top-level `examples/`. | Verified end-to-end: telemetry contract (`lib/sigra/audit.ex:315-322`), forwarder `:sync` path (`lib/sigra/audit/forwarders/threadline.ex`), `record_action/2` contract + `AuditAction` schema (`deps/threadline/`), example sandbox + `:example_app` gate + CI lane all confirmed. Threadline locked at 0.5.0 (`mix.lock:52`), matches `~> 0.5` pin. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x blessed path. (Example app is on `phoenix ~> 1.8.5`, `ecto_sql ~> 3.13`.)
- **Database:** PostgreSQL primary. `mix test` requires a live Postgres at `localhost:5432` (`postgres`/`postgres`). The new test needs the DB up (it inserts a real `audit_actions` row). One-liner container in CLAUDE.md.
- **Testing:** AAA style, flat, self-contained. Comprehensive — happy path + main error cases + boundary conditions. (The analog `audit_integration_test.exs` is the structural template; it is flat AAA.)
- **GSD Workflow Enforcement:** No direct edits outside a GSD command. (This is a planning-research artifact; edits happen in execution.)
- **No marketing voice** in suite docs (banned: "seamlessly," "just works," "production-ready out of the box," "the recommended way"). The AGENTS.md demo section must avoid these.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Login trigger | Example app (frontend/controller path via `UserAuth.log_in_user/2`) | — | The test drives the real example-app auth path; no Sigra internals are called directly to trigger the audit. |
| Audit DB row (source-of-truth) | Sigra library (`Sigra.Audit.log_safe/2`) | Example schema `Example.Accounts.AuditEvent` | Sigra owns the enforceable contract; the schema is generated/host-owned. |
| Telemetry emission `[:sigra, :audit, :log]` | Sigra library (`lib/sigra/audit.ex:315`) | — | Fires exactly once per committed audit row; the integration seam. |
| Forwarder dispatch + `record_action/2` mapping | Sigra library (`lib/sigra/audit/forwarders/threadline.ex`) | — | Frozen Phase 131 code; Phase 135 only attaches it, never edits it. |
| Threadline projection row (`audit_actions`) | Threadline 0.5.0 (`record_action/2` + `AuditAction` schema) | Example `Example.Repo` (owns the SQL Sandbox conn) | DB-resident projection; the test queries it directly. |
| Test attach/detach + assertion | Example app test (`threadline_forwarder_test.exs`) | — | The gap the test bridges — the example Application never calls `attach_forwarders/0`. |

## Standard Stack

No new libraries are introduced by Phase 135 beyond adding Threadline to the example app. Versions verified against `mix.lock` and `deps/`.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| threadline | 0.5.0 | Audit projection / queryable timeline; provides `record_action/2` + `audit_actions` schema | `[VERIFIED: mix.lock:52]` Locked at exactly 0.5.0 in root `mix.lock`; `~> 0.5` pin matches the Phase 132 recipe. DB/Ecto-based (NOT HTTP). |
| ecto_sql | ~> 3.13 | Migrations + SQL Sandbox isolation | `[VERIFIED: test/example/mix.exs:46]` Already a dep. |
| postgrex | >= 0.0.0 | Postgres driver | `[VERIFIED: test/example/mix.exs:47]` Already a dep. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| oban | ~> 2.17 | (Already a plain dep in example) | `[VERIFIED: test/example/mix.exs:64]` Present but NOT supervised — see Pitfall 1. Do not add an Oban supervisor; the demo relies on its absence so `:auto`→`:sync`. |

### Installation
Add to `test/example/mix.exs` deps (per D-09):
```elixir
{:threadline, "~> 0.5", only: [:dev, :test]},
```
Then inside `test/example/`:
```bash
mix deps.get
mix threadline.install   # generates TWO migration files (see execution risk)
# verify/fix migration timestamp ordering, then:
mix ecto.migrate
```

**Version verification:** `threadline 0.5.0` confirmed in `/Users/jon/projects/sigra/mix.lock:52` (hex, sha256 `350e5443…`). Deps: `ecto_sql ~> 3.10`, `jason ~> 1.4`, `nimble_csv ~> 1.2`, `postgrex ~> 0.17`, `telemetry ~> 1.2`; Phoenix/LiveView optional. All compatible with the example app's stack.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| threadline | Hex | already vendored @ 0.5.0 in `deps/` + `mix.lock` | — | szTheory suite (Jon's own OSS) | n/a (not slopcheck-applicable; already present, locked, and exercised by the existing library test suite) | Approved |

No new external packages are pulled by this phase — Threadline is already present in `deps/threadline/` and pinned in the root `mix.lock`. The example app merely adds it to its own `mix.exs`. slopcheck (a PyPI/npm hallucination detector) is not applicable to a vendored Hex package authored within the same OSS suite. `[VERIFIED: deps/threadline/ exists, mix.lock:52 pins 0.5.0]`

## Architecture Patterns

### System Architecture Diagram (the end-to-end projection the test proves)

```
  [test process — async: true, owns SQL Sandbox conn on Example.Repo]
        │
        │ setup: Sigra.Audit.Forwarders.Threadline.attach(
        │          repo: Example.Repo, id: :test, dispatch: :sync, actor_type: :user)
        │        → :telemetry.attach({Threadline, :test}, [:sigra,:audit,:log], handle_event/4, opts)
        ▼
  ExampleWeb.UserAuth.log_in_user(conn, user)        ← the real auth path (D-03)
        │
        ▼
  Sigra.Auth.create_session/4
        │  (writes Example.Accounts.AuditEvent row inside the committed txn — source of truth)
        ▼
  Sigra.Audit.log_safe/2 → :telemetry.execute([:sigra,:audit,:log],
        measurements, %{id: event.id, action: "session.create",
                        actor_id: user.id, outcome: "success"})   ← lib/sigra/audit.ex:315-322
        │  (synchronous, inline, in the test process)
        ▼
  Sigra.Audit.Forwarders.Threadline.handle_event/4 (try/rescue, dispatch=:sync)
        │  → call_threadline/2:
        │       name  = String.to_atom("session.create")            → "session.create" (stored)
        │       actor = ActorRef.new(:user, user.id)                 → %ActorRef{type: :user, id: user.id}
        │       status= :ok   (outcome "success" → :ok)
        │       correlation_id = event.id                            ← the join key
        ▼
  Threadline.record_action(:"session.create",
        repo: Example.Repo, status: :ok, correlation_id: event.id, actor: actor_ref)
        │  → AuditAction.changeset → Example.Repo.insert
        ▼
  audit_actions row  ──── correlation_id == audit_event.id ────►  ASSERTED by the test
        name = "session.create"   actor_ref.id = user.id   status = :ok
```

A reader can trace the primary use case top-to-bottom by following the arrows: login enters at `log_in_user`, the audit row + telemetry are produced by Sigra, the forwarder maps and inserts inline, and the test joins back on `correlation_id == audit_event.id`.

### Recommended Test Structure (mirrors the analog at `audit_integration_test.exs:55-71`)
```elixir
defmodule ExampleWeb.ThreadlineForwarderTest do
  use ExampleWeb.ConnCase, async: true
  import Ecto.Query
  alias Example.{Accounts, Repo}
  alias Example.Accounts.AuditEvent
  alias Threadline.Semantics.AuditAction

  @moduletag :example_app   # D-10 — the ONLY tag

  setup %{} do
    # D-07/D-08: attach the forwarder the example Application never attaches.
    :ok =
      Sigra.Audit.Forwarders.Threadline.attach(
        repo: Example.Repo,     # D-08 — owns the SQL Sandbox conn
        id: :test,
        dispatch: :sync,        # D-06 — deterministic inline
        actor_type: :user
      )
    on_exit(fn -> :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test}) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "tl-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBattery123!"
      })
    %{user: user}
  end

  test "login audit event materializes as a Threadline audit_actions row",
       %{conn: conn, user: user} do
    conn
    |> Plug.Test.init_test_session(%{})
    |> ExampleWeb.UserAuth.log_in_user(user)

    # Arrange→Act done; fetch the Sigra audit row to get its UUID (the join key).
    audit_event =
      Repo.one(
        from a in AuditEvent,
          where: a.action == "session.create" and a.actor_id == ^user.id,
          order_by: [desc: a.inserted_at], limit: 1
      )
    assert audit_event, "no Sigra audit row — forwarder has nothing to project"

    action =
      Repo.one(from a in AuditAction, where: a.correlation_id == ^audit_event.id)

    assert action,            "Threadline audit_actions row did not materialize"
    assert action.name == "session.create"
    assert action.status == :ok
    assert action.actor_ref.id == user.id     # ActorRef.new(:user, user.id)
    assert action.actor_ref.type == :user
  end
end
```

### Anti-Patterns to Avoid
- **Asserting only that the forwarder/`record_action` was *called* (e.g. via a Mox/stub) instead of asserting the real row.** D-01 forbids it; it under-samples (see Validation Architecture). The demo's whole value is the real projection.
- **Adding `endpoint:`/`api_key:` keys to the committed `forwarders:` block.** Threadline 0.5.0 is DB-based; `call_threadline/2` reads only `:repo`, `:id`, `:dispatch`, `:actor_type`, `:threadline_module`. Those env-var keys appear in the recipe (`threadline.md:67-68`) as aspirational HTTP cruft and would be dead config in the example. The required runtime key is `repo:`. (See Open Question 1 — recipe-parity vs. dead-config tension; D-06 specifics already license deviating from the published literal for determinism.)
- **Supervising Oban in the example to "test the async path."** Out of scope; would break D-06's `:auto`→`:sync` reasoning and add a CI job risk. The async path is covered by the library suite, not the example.
- **Tagging the test `:requires_threadline`.** That tag belongs to the repo-root dep-off lane (`ci.yml:205-219`), which never runs inside `test/example/`. D-10.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Threadline migrations | Hand-write `audit_actions`/`audit_transactions` DDL | `mix threadline.install` then commit the two generated files | The DDL is authored + versioned by Threadline; hand-rolling drifts from the schema the `AuditAction` Ecto module expects. |
| Forwarder attach/telemetry plumbing | Re-implement a telemetry handler in the test | `Sigra.Audit.Forwarders.Threadline.attach/1` | Frozen Phase 131 code with the auto-detach landmine handled; the demo's point is to exercise it. |
| Actor/correlation mapping | Manually construct `ActorRef`/`correlation_id` in the test | Let `call_threadline/2` do it; assert the result | The mapping IS the contract under test. |

**Key insight:** Phase 135 writes zero new `lib/` code and zero new DDL by hand. It is pure wiring + assertion over frozen library code and generator output.

## Runtime State Inventory

> This is an additive integration-test phase, not a rename/refactor. Included for completeness because it commits generated migrations and adds a DB-resident table.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | New `audit_actions` + `audit_transactions` + `audit_changes` tables created in the example app's test/dev DB by the two committed migrations. SQL Sandbox rolls back per-test inserts; the tables themselves persist (created at `ecto.migrate`). | Commit the two migrations; CI's `ecto.create && ecto.migrate` (or the `test` alias) creates them. None beyond that. |
| Live service config | None — example app has no external services; Threadline 0.5.0 writes to `Example.Repo`, no HTTP endpoint, no `THREADLINE_*` env vars actually read by the forwarder. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None — `THREADLINE_ENDPOINT`/`THREADLINE_API_KEY` in the recipe are NOT read by `call_threadline/2`; do not add them to the example. | None. Verified by reading `lib/sigra/audit/forwarders/threadline.ex` (no `System.get_env`, no `:endpoint`/`:api_key`). |
| Build artifacts | `test/example/mix.lock` gains a `threadline` entry; `test/example/_build` recompiles. CI cache key already hashes `test/example/mix.lock` (`ci.yml:245`), so the lane re-caches correctly. | Commit the updated `test/example/mix.lock`. |

## Common Pitfalls

### Pitfall 1: Oban is a compiled dep in the example but is NOT supervised — `:auto` still collapses to `:sync` (and WHY)
**What goes wrong:** CONTEXT.md D-06 says "the example app supervises no Oban, so `:auto` already collapses to inline." A reader might assume Oban is absent entirely and be confused that `{:oban, "~> 2.17"}` IS in `test/example/mix.exs:64` (plain, not scoped).
**Why it happens:** `oban_running?/1` = `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` (`lib/sigra/audit/forwarders.ex:99`). In the example: `Code.ensure_loaded?(Oban)` → **true** (compiled), `Process.whereis(Oban)` → **nil** (no Oban child in `Example.Application.start/2` — verified `application.ex:10-19`). So `true and false` = **false** → `:auto` resolves to `:sync`. CONTEXT.md's conclusion is correct; its phrasing ("no Oban") is imprecise. Pinning `dispatch: :sync` (D-06) sidesteps the subtlety entirely.
**How to avoid:** Pin `:sync` on the attach call. Do NOT add an Oban supervisor to fix a non-problem.
**Warning signs:** If a future change adds `{Oban, ...}` to the example's supervision tree, `:auto` would flip to `:async` and the synchronous assertion would break. The explicit `:sync` pin immunizes the test against that.

### Pitfall 2 (REAL EXECUTION RISK — not in CONTEXT.md): two-migration timestamp collision from `mix threadline.install`
**What goes wrong:** `mix threadline.install` writes BOTH migration files in a single `run/0` call (`deps/threadline/lib/mix/tasks/threadline.install.ex:27-45`), each named `#{timestamp()}_threadline_audit_schema.exs` and `#{timestamp()}_threadline_semantics_schema.exs`. `timestamp/0` is `:calendar.universal_time()` at **second** resolution (`:90-95`). Both calls can return the **same** `YYYYMMDDHHMMSS`. Ecto orders migrations by the integer version prefix; identical prefixes mean ordering is undefined (and Ecto raises "migrations can't be executed, migration version … is duplicated" if two files share the exact version).
**Why it matters here:** The semantics migration `up/0` runs `ALTER TABLE audit_transactions ADD COLUMN …` (`deps/threadline/lib/threadline/semantics/migration.ex:48-52`) against a table the capture migration creates (`deps/threadline/lib/threadline/capture/migration.ex:24-31`). Capture MUST run first. With colliding timestamps that is not guaranteed.
**How to avoid:** After `mix threadline.install`, the executor MUST verify the two generated filenames have **distinct, ascending** version prefixes with capture < semantics. If equal (or semantics < capture), rename the semantics file's timestamp to capture's + 1 second. The hardcoded module names (`ThreadlineAuditSchema`, `ThreadlineSemanticsMigration`) are distinct, so there is no module-name collision — only a version-ordering risk.
**Warning signs:** `mix ecto.migrate` errors on a duplicated version, OR a `column "actor_ref" of relation "audit_transactions" does not exist` / `relation "audit_transactions" does not exist` failure (semantics ran before capture). Existing example migrations are dated `20260410…`–`20260526…`; the freshly generated `20260528…` files sort after them correctly — the only risk is the two new files relative to each other.

### Pitfall 3: querying the wrong Threadline table
**What goes wrong:** Using `Threadline.actor_history/2` or `Threadline.timeline/2` to find the row.
**Why it happens:** Those are the discoverable public read APIs, but they query the trigger-capture tables (`audit_transactions`/`audit_changes`), NOT `audit_actions` (verified `deps/threadline/lib/threadline.ex:88-122`). `record_action/2` writes ONLY to `audit_actions`; nothing populates `audit_transactions` in this demo (no DB triggers installed on the example's tables).
**How to avoid:** Query `Threadline.Semantics.AuditAction` directly via `Example.Repo` (D-04). There is no `get_action_by_correlation_id` helper in 0.5.0 — confirmed by reading the full `threadline.ex` public surface.
**Warning signs:** Query returns `nil` even though forwarding succeeded → you queried the capture tables, not `audit_actions`.

### Pitfall 4: SQL Sandbox connection ownership on the `:sync` path
**What goes wrong:** The inline `record_action/2` insert lands on a different connection than the test's owned sandbox connection → row invisible to the follow-up query or leaks past rollback.
**Why it happens (and why it's FINE here):** `setup_sandbox` uses `shared: not tags[:async]` (`data_case.ex:39`). With `async: true` (non-shared), the connection is owner-pid-bound. BUT `:telemetry.execute([:sigra,:audit,:log], …)` runs the handler **synchronously in the calling process**, and `log_in_user` runs in the test process — so `handle_event` → `record_action` → `Example.Repo.insert` all execute in the owner process on the owned connection. Passing `repo: Example.Repo` (D-08) is the necessary-and-sufficient condition. Verified: the analog test runs `async: true` with `@moduletag :example_app` and queries the same repo successfully.
**How to avoid:** Pass `repo: Example.Repo`; keep the forwarding synchronous (`:sync`). Do not introduce any async/spawned execution in the forward path for this test.
**Warning signs:** Intermittent `nil` results or `DBConnection.OwnershipError`.

## Code Examples

### The telemetry metadata contract (the integration seam)
```elixir
# Source: lib/sigra/audit.ex:315-322 (VERIFIED)
:telemetry.execute(
  [:sigra, :audit, :log],
  measurements,
  %{
    action: event.action,     # "session.create"
    actor_id: event.actor_id, # user.id (binary_id UUID)
    outcome: event.outcome,   # "success"
    id: event.id              # audit row UUID → becomes correlation_id
  }
)
```

### The forwarder's `:sync` mapping (frozen Phase 131 code — DO NOT edit)
```elixir
# Source: lib/sigra/audit/forwarders/threadline.ex (VERIFIED, line ranges below)
# call_threadline/2 @ 238-308:
status =
  case metadata[:outcome] do
    :success -> :ok ; "success" -> :ok
    :failure -> :error ; "failure" -> :error ; :error -> :error
    _ -> :ok
  end
# name @ 273-282: String.to_atom("session.create") (string→atom, then Threadline stores Atom.to_string)
call_opts =
  [repo: repo, status: status, correlation_id: metadata[:id]]   # correlation_id @ line 295
  |> add_actor_opt(actor_ref)                                   # actor_ref via ActorRef.new(:user, actor_id)
threadline.record_action(name, call_opts)                       # @ line 299
```

### `record_action/2` contract + storage (Threadline 0.5.0)
```elixir
# Source: deps/threadline/lib/threadline.ex:40-62 (VERIFIED)
# Required: :actor (or :actor_ref) %ActorRef{}, :repo
# Stores name as a STRING: build_attrs uses Atom.to_string(name)  (threadline.ex:242)
# Returns {:ok, %AuditAction{}} | {:error, %Ecto.Changeset{}} | {:error, :missing_actor|:invalid_actor_ref|:missing_repo}

# audit_actions schema (deps/threadline/lib/threadline/semantics/audit_action.ex):
#   field :name, :string
#   field :actor_ref, Threadline.Semantics.ActorRef   # JSONB %{"type"=>"user","id"=>...}, loads as %ActorRef{}
#   field :status, Ecto.Enum, values: [ok: "ok", error: "error"]
#   field :correlation_id, :string
#   @required_fields ~w(name actor_ref status)a
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` | `Repo.transact/2` | Ecto 3.13 | Not directly used by this phase; noted per CLAUDE.md stack guidance. |
| Threadline imagined as HTTP forwarder (`endpoint`/`api_key`) | Threadline 0.5.0 is Ecto/DB-resident via `record_action/2` | Threadline 0.5.0 | The example config must use `repo:`, not HTTP env vars. The recipe's `endpoint`/`api_key` keys are not read by the forwarder. |

**Deprecated/outdated:**
- The Phase 132 recipe block (`threadline.md:62-71`) shows `dispatch: :auto` + `endpoint`/`api_key`. For the example, deviate to `dispatch: :sync` and drop the env-var keys (D-06 specifics explicitly license this; CONTEXT.md `<specifics>` permits keeping `:auto` in committed config and `:sync` only in the test's attach call — see Open Question 1).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The two `mix threadline.install` timestamps will need a manual +1s bump only *if* they collide; on most runs the same-second collision may or may not occur (depends on filesystem/clock timing within the single `run/0`). | Pitfall 2 | Low — the mitigation (verify-and-bump) is cheap and deterministic regardless; worst case the executor confirms they already differ and does nothing. |
| A2 | `Sigra.Audit.Forwarders.Threadline.attach/1` accepts `actor_type:` and `repo:` as documented in the moduledoc and read in `call_threadline/2`. | Test structure | Verified in source (`threadline.ex:48-54`, `239-241`); `[VERIFIED]`. Listed only because the exact attach keyword set is the executor's discretion (D-13). |

**Note:** All other load-bearing claims were VERIFIED against the live tree or CITED to specific files/lines. The CONTEXT.md decisions themselves are user-locked (not assumptions).

## Drift Found vs. CONTEXT.md citations (none change a decision)

| CONTEXT.md citation | Live tree reality | Severity |
|---------------------|-------------------|----------|
| `threadline.ex` `attach/1` "~99-160" | `attach/1` is at **lines 82-91**; lines 99-222 are `handle_event/4`. | Cosmetic — the executor reads the file; no decision affected. |
| `threadline.ex` "record_action/2 mapping ~238-307" | `call_threadline/2` is at **238-308**; the actual `threadline.record_action(...)` call is at **line 299**. | Cosmetic — range is essentially right. |
| `threadline.ex` "UUID→correlation_id ~294-296" | `correlation_id: metadata[:id]` is at **line 295** (inside the 290-296 `call_opts` block). | Cosmetic. |
| `forwarders.ex` `oban_running?/1` "~89-110" | `oban_running?/1` is at **89-101**; `dispatch_mode/1` at 103-110. | Cosmetic. |
| `deps/threadline` `semantics/migration.ex:48-52` ALTERs; `capture/migration.ex:24-31` creates | **Confirmed exact** — ALTER at semantics `48-52`, `CREATE TABLE audit_transactions` at capture `24-31`. | None — CONTEXT.md correct. |
| `record_action/2` "deps/threadline/lib/threadline.ex (lines 40-62, 240-253)" | `record_action/2` @ **40-62** ✓; `build_attrs/3` @ **240-253** ✓. | None — CONTEXT.md correct. |
| analog test "audit_integration_test.exs:55-71" | **Confirmed exact** — the `Repo.one`/assert block is at 55-71. | None. |
| `accounts.ex` `sigra_config/0` "~590-622" | **Confirmed** — `sigra_config/0` @ 590-622; `audit:` keyword @ 607-609. | None. |
| `config.exs` "lines 43-63" | **Confirmed** — `config :example, :sigra_config` @ 43-63; `audit:` @ 50-52. | None. |
| `mix.exs` deps "~41-71", aliases "81-86" | **Confirmed** — deps 41-71, aliases 79-87 (`test` alias @ 84). | None. |
| `ci.yml` dep-off "205-219"; `example_unit_smoke` "221-267" | **Confirmed** — dep-off 205-219; `example_unit_smoke` 221-267, `mix test --include example_app` @ 267. | None. |

## Open Questions

1. **Recipe-parity vs. dead-config in the committed `forwarders:` block.**
   - What we know: D-06 wants `dispatch: :sync` for determinism. The published recipe block shows `dispatch: :auto` + `endpoint`/`api_key` env vars. The forwarder does NOT read `endpoint`/`api_key`. CONTEXT.md `<specifics>` explicitly permits two shapes: (a) put `dispatch: :sync` in the committed config, or (b) keep the published `:auto` literal in committed config and pass `dispatch: :sync` ONLY in the test's `attach/1` call.
   - What's unclear: whether to include the env-var keys at all (they would be dead config / misleading to an adopter copying the example).
   - Recommendation: Use shape (b) for maximum recipe-grep fidelity in the committed config (`accounts.ex` + `config.exs` carry the literal recipe block, including the comment that `:auto` falls back to `:sync` without Oban), AND drop the `endpoint`/`api_key` keys (or replace them with an inline comment noting Threadline 0.5.0 is DB-based and reads `repo:` from the host's Sigra config — passed via `attach_forwarders/0`'s merge with the per-forwarder opts). The test's `attach/1` call passes `dispatch: :sync` + `repo: Example.Repo` explicitly. This keeps the committed config a faithful recipe mirror while the deterministic `:sync` + `repo:` live in the test's attach call. Planner picks; both satisfy D-06/D-12.
   - **Note for planner:** the committed config block's `forwarders:` entry needs a `repo:` (or the executor confirms `attach_forwarders/0` injects it). Since Phase 135 attaches in test (D-07), the committed config block is primarily a *grep/reference artifact* — it is never actually attached by the example's vanilla Application. So a missing `repo:` in the committed block is cosmetically fine but reduces copy-paste fidelity. Recommend including `repo: Example.Repo` (or a `# repo: comes from your sigra_config` comment) for adopter clarity.

2. **Does `register_user/2` followed by `log_in_user/2` reliably produce exactly one `session.create` audit row?**
   - What we know: the analog test (`audit_integration_test.exs`) proves `log_in_user` → `session.create` row writes (it is the locked B8 fix). `register_user` itself may or may not emit its own audit rows.
   - What's unclear: whether `register_user` emits any `[:sigra, :audit, :log]` events that would also be forwarded (creating extra `audit_actions` rows) — but those would have different `action` names and different `correlation_id`s, so the `correlation_id == audit_event.id` join (filtered to the `session.create` audit row's id) isolates the right row.
   - Recommendation: scope the join precisely to the `session.create` `AuditEvent` row's id (as in the example test above). Optionally attach the forwarder AFTER `register_user` (inside `setup`, register first then attach) so registration-time events are never forwarded — cleaner. Executor's discretion (D-13). Low risk either way because the join key isolates the row.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL @ localhost:5432 (postgres/postgres) | The test inserts a real `audit_actions` row | ✓ (CLAUDE.md documents the disposable container; CI provides `postgres:15` service) | 15 (CI) / 16-alpine (local one-liner) | None — required; without it the test fails fast (no `:postgres` tag exclusion exists). |
| threadline 0.5.0 | Forwarder target | ✓ | 0.5.0 (`mix.lock:52`, vendored in `deps/threadline/`) | None. |
| Elixir / OTP | Build + run | ✓ | Elixir 1.19.5-otp-28, Erlang 28.1 (`.tool-versions`) | None. |
| `mix threadline.install` task | Generates the two migrations | ✓ (`deps/threadline/lib/mix/tasks/threadline.install.ex`) | None — but the executor may hand-author the two files from `Threadline.Capture.Migration.migration_content/0` + `Threadline.Semantics.Migration.migration_content/0` if the task path is awkward. |

**Missing dependencies with no fallback:** None (all present).
**Missing dependencies with fallback:** `mix threadline.install` — the two migration bodies are also reachable as `Threadline.Capture.Migration.migration_content/0` and `Threadline.Semantics.Migration.migration_content/0`, so the executor can write the files manually with controlled, ascending timestamps (which also pre-empts Pitfall 2).

## Validation Architecture

> Nyquist validation is ENABLED for this phase (`workflow.nyquist_validation` not set false). This section defines what the demo test must sample to prove the end-to-end projection — not merely that the forwarder was wired.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5) + `Phoenix.ConnTest` via `ExampleWeb.ConnCase` |
| Config file | `test/example/test/test_helper.exs` (`ExUnit.start(exclude: [:example_app])`, `Ecto.Adapters.SQL.Sandbox.mode(Example.Repo, :manual)`) |
| Quick run command | `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (run inside `test/example/`) |
| Full suite command | `mix test --include example_app` (run inside `test/example/` — the `example_unit_smoke` CI lane command, `ci.yml:267`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EX-01 | A Sigra `session.create` audit event materializes as a real Threadline `audit_actions` row with the correct actor + action + join key | integration | `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (in `test/example/`) | ❌ Wave 0 — `test/example/test/example_web/threadline_forwarder_test.exs` is NEW |

### What the test MUST sample (anti-under-sampling spec)
The end-to-end behavior to sample is the **full projection chain**, joined on a real key. The single assertion bundle MUST cover:
1. **Trigger reality:** drive the real auth path `ExampleWeb.UserAuth.log_in_user/2` (not a direct `Sigra.Audit` call) — proves the demo works the way an adopter's app does.
2. **Source row exists:** a `session.create` `AuditEvent` row for `user.id` exists (gives the join key `audit_event.id`).
3. **Projection row materialized:** a `Threadline.Semantics.AuditAction` row exists where `correlation_id == audit_event.id` (the join key — Sigra audit UUID ↔ Threadline `correlation_id`).
4. **Shape correctness on the projected row:** `name == "session.create"` (string), `status == :ok`, `actor_ref.id == user.id`, `actor_ref.type == :user`.

### Sampling rate
- **Per task commit:** `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (single-file, < 5s with DB up).
- **Per wave / phase gate:** `mix test --include example_app` inside `test/example/` (the `example_unit_smoke` lane) — must stay green; plus the existing 3 `test/example/` CI jobs remain green (success criterion #3). No new CI job is added.
- **Phase gate:** full example suite green before `/gsd:verify-work`; root `mix test` and dep-off lane unaffected (the new test carries `:example_app` only, never runs in the repo-root or dep-off lanes).

### Under-sampling failure modes (what NOT to accept as "validated")
- **Asserting only that `record_action/2`/the forwarder was *called*** (e.g. a Mox stub or `:threadline_module` override capturing the call) — FORBIDDEN by D-01. It samples the wiring but not the projection; a schema mismatch or a broken `ActorRef`/`correlation_id` cast would pass falsely.
- **Asserting only that *some* `audit_actions` row exists** (no `correlation_id` join) — under-samples; cannot prove THIS login produced THIS row, and would pass even if registration-time events were the only ones forwarded.
- **Asserting `name`/`status` but not the actor or join key** — misses the "expected actor shape" half of success criterion #1.
- **Querying `Threadline.timeline/2`/`actor_history/2`** instead of `AuditAction` directly — would return `nil`/empty (wrong tables) and tempt a weakened assertion (Pitfall 3).

### Wave 0 Gaps
- [ ] `test/example/test/example_web/threadline_forwarder_test.exs` — NEW, covers EX-01 (the only test file this phase adds).
- [ ] Two committed migrations under `test/example/priv/repo/migrations/` (capture then semantics) — prerequisite DB state for the test; verify ascending timestamps (Pitfall 2).
- [ ] `{:threadline, "~> 0.5", only: [:dev, :test]}` in `test/example/mix.exs` + updated `test/example/mix.lock`.
- No new framework install needed — ExUnit + ConnCase + SQL Sandbox already present.

## Sources

### Primary (HIGH confidence — read directly this session)
- `lib/sigra/audit/forwarders/threadline.ex` — `attach/1` (82-91), `handle_event/4` (99-222), `call_threadline/2` (238-308), `correlation_id` mapping (295), `build_actor_ref/2` (312-326).
- `lib/sigra/audit/forwarders.ex` — `oban_running?/1` (89-101), `dispatch_mode/1` (103-110).
- `lib/sigra/application.ex` — `attach_forwarders/0` (123-169), `:async`-without-Oban raise (139-152).
- `lib/sigra/audit.ex` — `[:sigra, :audit, :log]` emission + metadata (315-322).
- `deps/threadline/lib/threadline.ex` — `record_action/2` (40-62), `build_attrs/3` (240-253), read APIs query capture tables (88-122).
- `deps/threadline/lib/threadline/semantics/audit_action.ex` — `audit_actions` schema (fields, required `name`/`actor_ref`/`status`).
- `deps/threadline/lib/threadline/semantics/actor_ref.ex` — `ActorRef.new/2` (35-52), JSONB serialization.
- `deps/threadline/lib/threadline/capture/migration.ex` — creates `audit_transactions` (24-31).
- `deps/threadline/lib/threadline/semantics/migration.ex` — creates `audit_actions` + ALTERs `audit_transactions` (48-52).
- `deps/threadline/lib/mix/tasks/threadline.install.ex` — two-file generation + second-resolution `timestamp/0` (27-95).
- `test/example/test/example_web/audit_integration_test.exs` — analog test (55-71), `async: true`, `@moduletag :example_app`.
- `test/example/lib/example/accounts.ex` — `sigra_config/0` (590-622), `audit:` keyword (607-609).
- `test/example/config/config.exs` — `config :example, :sigra_config` (43-63).
- `test/example/mix.exs` — deps (41-71, oban @ 64), aliases (79-87).
- `test/example/lib/example/application.ex` — no Oban child, no `attach_forwarders/0` (10-19).
- `test/example/test/test_helper.exs`, `test/support/data_case.ex` (`shared: not tags[:async]` @ 39), `conn_case.ex`.
- `test/example/lib/example/accounts/user.ex` (binary_id @ 5), `accounts/audit_event.ex` (binary_id id + actor_id).
- `.github/workflows/ci.yml` — dep-off lane (205-219), `example_unit_smoke` (221-267, `--include example_app` @ 267).
- `guides/recipes/companion-libs/threadline.md` — Phase 132 recipe block (62-71), record_action citation (74).
- `mix.lock:52` — `threadline 0.5.0` pin; `.tool-versions` — Elixir 1.19.5-otp-28 / Erlang 28.1.

### Secondary (MEDIUM)
- `.planning/REQUIREMENTS.md` (EX-01 @ 44, Out-of-Scope @ 63-73), `.planning/ROADMAP.md` (Phase 135 @ 134-146).

### Tertiary (LOW)
- None — every claim is sourced to a file read this session.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Threadline 0.5.0 locked in `mix.lock`, vendored in `deps/`, exercised by existing library tests.
- Architecture / end-to-end chain: HIGH — every hop (telemetry contract, forwarder mapping, `record_action/2`, schema, sandbox ownership) read directly.
- Pitfalls: HIGH for 1/3/4 (read from source); MEDIUM for 2 (timestamp-collision is a real code path but whether it collides on a given run is timing-dependent — the mitigation is deterministic regardless).
- CONTEXT.md decision validity: HIGH — all 13 decisions confirmed; only cosmetic line-number drift in 4 citations.

**Research date:** 2026-05-28
**Valid until:** 2026-06-27 (30 days — stable; Threadline pinned, library code frozen, example app stable). Re-verify if Threadline is bumped past 0.5.0 or `lib/sigra/audit/forwarders/threadline.ex` changes.
