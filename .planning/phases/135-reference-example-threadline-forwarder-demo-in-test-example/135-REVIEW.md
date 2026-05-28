---
phase: 135-reference-example-threadline-forwarder-demo-in-test-example
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - test/example/AGENTS.md
  - test/example/config/config.exs
  - test/example/lib/example/accounts.ex
  - test/example/mix.exs
  - test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs
  - test/example/priv/repo/migrations/20260528152138_threadline_semantics_schema.exs
  - test/example/priv/repo/migrations/20260528152139_threadline_governance_schema.exs
  - test/example/test/example_web/threadline_forwarder_test.exs
findings:
  critical: 2
  warning: 3
  info: 1
  total: 6
status: remediated
remediation:
  fixed: [CR-02, WR-02]
  deferred: [CR-01, WR-01, WR-03, IN-01]
  retest: "mix test threadline_forwarder_test.exs --include example_app → 1 test, 0 failures"
---

# Phase 135: Code Review Report

**Reviewed:** 2026-05-28
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the Threadline audit-forwarder reference demo added to `test/example/`. The forwarder config wiring in `config.exs` and `accounts.ex` is internally consistent. The `mix.exs` dep declaration is correct in scope. The three generated migrations are committed verbatim from Threadline's own generators.

Two blockers were found: a forward-reference column in the generated trigger DDL that will cause the trigger to error at runtime on a fresh migration run, and a global telemetry mutation in an `async: true` test that creates a cross-test race condition and a permanent state leak. Three warnings address a fragile assertion type, a missing handler re-attach on teardown, and an undeclared `threadline` dep scope in AGENTS.md.

---

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Migration 1 trigger references `actor_ref` column that does not exist until migration 2

**File:** `test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs:36`

**Issue:** Migration `20260528152137` creates the `audit_transactions` table with columns `(id, txid, occurred_at, source, meta)` — no `actor_ref` column. In the same migration, the `threadline_capture_changes()` trigger function is defined with a body that executes:

```sql
INSERT INTO audit_transactions (id, txid, occurred_at, actor_ref)
VALUES (gen_random_uuid(), v_txid, clock_timestamp(),
        NULLIF(current_setting('threadline.actor_ref', true), '')::jsonb)
ON CONFLICT (txid) DO NOTHING;
```

The `actor_ref` column is only added by migration `20260528152138` via `ALTER TABLE audit_transactions ADD COLUMN IF NOT EXISTS actor_ref jsonb`. PostgreSQL's `CREATE OR REPLACE FUNCTION` stores the function body as text and defers column resolution to execution time. When the trigger fires (after migration 1 but before migration 2 runs, or in any scenario where the trigger is invoked against the pre-migration-2 schema), it will raise `ERROR: column "actor_ref" of relation "audit_transactions" does not exist`.

In a fresh `mix test` run the `ecto.migrate --quiet` alias runs all three migrations in timestamp order before any test code touches the DB, so the column exists by the time a trigger fires. However, if the trigger is ever invoked during migration 1's own `up/0` (unlikely here, but conceivable in some test-isolation teardown or partial migration rollback scenario), it fails. More concretely, a `mix ecto.rollback` to revision `20260528152137` (migration 2 down runs first, dropping the column) leaves the trigger function pointing at a column that no longer exists — any subsequent table write that fires the trigger will crash. The `down/0` in migration 1 drops the function, so a *complete* rollback of both migrations is safe, but a rollback to exactly the state of migration 1 is broken.

This is a generated-file issue but it breaks the demo's `mix ecto.rollback` story.

**Fix:** Reorder the `actor_ref` column addition into migration 1 (before the trigger function), or split the trigger CREATE into migration 2 after the `ALTER TABLE` so the column exists when the function is registered. The minimal fix in migration 1:

```sql
-- Add actor_ref to the CREATE TABLE before defining the trigger function:
CREATE TABLE IF NOT EXISTS audit_transactions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  txid        bigint      NOT NULL UNIQUE,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_ref   jsonb,         -- <- add here
  source      text,
  meta        jsonb
)
```

Then remove the `ADD COLUMN IF NOT EXISTS actor_ref` line from migration 2 (or keep it as a no-op guard). Since these are committed as-is from Threadline's generator, the cleaner fix is a note in AGENTS.md that `mix ecto.rollback` to the exact state of migration 1 is unsupported for this demo.

---

### CR-02: `async: true` test mutates global telemetry handler state — race condition and permanent leak

**File:** `test/example/test/example_web/threadline_forwarder_test.exs:13,36-48`

**Issue:** The test module is declared `async: true` (line 13), meaning ExUnit may run it concurrently with other test modules. The `setup` block unconditionally calls:

```elixir
:telemetry.detach({Sigra.Audit.Forwarders.Threadline, :default})   # line 36
```

This removes the `:default` handler from the global telemetry registry for the entire VM. Any other test running concurrently that triggers a Sigra audit event will find no Threadline handler attached (or, worse, will attach its own handler that collides). This is a textbook async-unsafe global side effect.

Additionally, `on_exit` only detaches the `:test` handler:

```elixir
on_exit(fn -> :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test}) end)
```

It never re-attaches `:default`. If more than one test in the suite runs this setup block (e.g., if the test file is run multiple times in the same Mix session, or future test cases are added to the same module), each run permanently removes `:default` without restoring it. After the test suite finishes, the VM is left with no Threadline forwarder — this only matters for interactive `iex -S mix` sessions, but it is still a leak.

The comment in setup (line 32–35) correctly identifies the problem ("prevents double-projection") but the chosen mitigation — detaching in setup — is incompatible with `async: true`. Telemetry handlers are process-global; the SQL Sandbox boundary does not help here.

**Fix (two-part):**

1. Change `async: false` to make the test sequential:

```elixir
use ExampleWeb.ConnCase, async: false
```

2. Re-attach `:default` in `on_exit` to avoid the permanent leak:

```elixir
on_exit(fn ->
  :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test})

  # Restore the :default handler the Application originally attached.
  Sigra.Audit.Forwarders.Threadline.attach(
    repo: Example.Repo,
    id: :default,
    dispatch: :auto
  )
end)
```

Alternatively, if the example Application does NOT actually call `attach_forwarders/0` at boot (confirmed: `Example.Application` does not call it — only `Sigra.Application` does, and `Sigra.Application.attach_forwarders/0` reads from `config :example, :sigra_config`), then the detach of `:default` is necessary but `async: false` is still required because the `:test` handler itself is shared state.

---

## Warnings

### WR-01: Test assertion `action.actor_ref.id == user.id` assumes struct field layout that may not match

**File:** `test/example/test/example_web/threadline_forwarder_test.exs:79`

**Issue:**

```elixir
assert action.actor_ref.id == user.id
assert action.actor_ref.type == :user
```

`action.actor_ref` is a `Threadline.Semantics.ActorRef` struct loaded from the database. The field name `.id` is assumed to match the field Threadline uses for the actor identifier. If Threadline's struct field is `:actor_id`, `:user_id`, or `:ref`, this assertion raises a `KeyError` rather than producing a useful failure message. Similarly, `.type` being an atom (`:user`) assumes Threadline deserializes the `actor_ref jsonb` column back into typed atoms rather than strings. If it deserializes as `"user"`, the assertion fails even when the data is correct.

These assertions are testing Threadline's internal struct layout rather than the demo's behavior. The test would be more robust with pattern matching or an existence check:

```elixir
# Safer: assert the row exists and has the right name/status
# (Threadline struct internals are its own concern)
assert action.name == "session.create"
assert action.status == :ok
# Only assert actor_ref.id if the struct field is verified against Threadline source
```

If `.id` and `.type` are correct per Threadline 0.5/0.6 source, this is low-risk — but the test will give a confusing error if a Threadline upgrade renames those fields.

---

### WR-02: `on_exit` does not re-attach the `:default` handler — persistent VM state corruption

**File:** `test/example/test/example_web/threadline_forwarder_test.exs:48`

**Issue:** (Distinct from CR-02's race condition.) The `on_exit` callback only detaches `:test`:

```elixir
on_exit(fn -> :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test}) end)
```

`Sigra.Application.attach_forwarders/0` is called once at VM boot and attaches `:default`. The setup detaches `:default` permanently. After this test exits, the VM state is: no `:default` handler, no `:test` handler. Any subsequent code path (in the same `iex -S mix test` session) that emits Sigra telemetry events will find no Threadline forwarder. This makes the example app behave differently after the test runs vs before it runs — a violation of test isolation.

Even if `async: false` is set (fixing CR-02), the teardown must restore the `:default` handler. See the fix in CR-02 for the concrete `on_exit` addition.

---

### WR-03: `threadline` dep declared `only: [:dev, :test]` but migration files are unconditional

**File:** `test/example/mix.exs:70`

**Issue:**

```elixir
{:threadline, "~> 0.5", only: [:dev, :test]}
```

The three Threadline migration files in `priv/repo/migrations/` are unconditional — they run in all environments including `:prod`. A host app that copies this pattern and runs `mix ecto.migrate` in production will succeed (migrations are plain SQL via `execute/1` and do not require the `threadline` library to be compiled). However, if any production code path (not in the migrations themselves) references `Threadline.*` modules, compilation in `:prod` will fail because the dep is excluded.

In this example app the only production reference to Threadline is via `Sigra.Audit.Forwarders.Threadline` in `sigra_config/0` — that module lives in Sigra (library code), not in `threadline`. So the dep scope is technically correct for this app. But AGENTS.md documents the dep as `only: [:dev, :test]` (line 199), and an adopter copying the pattern without reading the nuance may put Threadline-specific code in production paths that won't compile.

The AGENTS.md documentation should clarify when `only: [:dev, :test]` is safe vs when `:prod` is needed.

---

## Info

### IN-01: `config.exs` and `accounts.ex` duplicate the full forwarder config block verbatim

**File:** `test/example/config/config.exs:53-64`, `test/example/lib/example/accounts.ex:608-621`

**Issue:** The forwarder keyword list is copy-pasted identically into both places. If a future adopter changes one block (e.g., adds an `endpoint:` key or changes `dispatch: :auto`) and not the other, the application-boot path (via `Sigra.Application.attach_forwarders/0` which reads `config :example, :sigra_config`) and the runtime path (via `sigra_config/0` which returns a `Sigra.Config` struct built from the hardcoded list) will diverge silently.

The duplication is intentional for the demo (shows both config surfaces). AGENTS.md at line 202 explains both touchpoints. This is low-risk for a reference app but adopters should be warned in a comment that keeping both in sync is a maintenance burden and that the `sigra_config/0` struct is the authoritative runtime config for most operations.

This is an info-level documentation gap, not a bug.

---

## Remediation (orchestrator, 2026-05-28)

Verified each finding against the code before acting. Fixed the verified bug in
our own code; deferred external/plan-mandated findings to a tracked todo.

**Fixed:**

- **CR-02 + WR-02** — `threadline_forwarder_test.exs`. Changed `async: true` →
  `async: false` (the test mutates VM-global `:telemetry` handlers) and added a
  `:default` re-attach to `on_exit` via `Sigra.Application.attach_forwarders/0`
  (idempotent detach-then-attach; restores boot state exactly). Corrected the
  stale moduledoc that claimed the app never attaches forwarders. Re-ran the
  integration test: `1 test, 0 failures`.

**Deferred (tracked):**

- **CR-01** — The forward-referenced `actor_ref` column lives in Threadline's
  **generated** capture migration, committed **verbatim** per a locked plan
  decision (`135-CONTEXT.md`: "committed verbatim"). The demo's happy path uses
  the Semantics `record_action/2` API, not the capture trigger, and never does a
  partial `ecto.rollback` to migration 1 — so the demo is unaffected (test
  passes). Editing generated DDL would defeat the "show adopters exactly what
  Threadline emits" goal. This is an upstream Threadline concern; tracked.
- **WR-01** — `actor_ref.id`/`.type` assertions are **intentionally strong**:
  Success Criterion #1 requires asserting the actor shape (`actor_ref.id ==
  user.id`, `actor_ref.type == :user`). The fields are correct against Threadline
  0.6 (test passes). The reviewer's "weaken to existence check" suggestion is
  declined; the brittleness-on-upgrade risk is tracked, not fixed.
- **WR-03** — `only: [:dev, :test]` dep scope is **plan-mandated** (must_have
  artifact). Correct for this app (the only prod Threadline reference is
  `Sigra.Audit.Forwarders.Threadline`, which is Sigra library code). The
  suggested AGENTS.md "when is :prod needed" clarification is tracked as a doc nit.
- **IN-01** — The duplicated forwarder block across `config.exs` and
  `accounts.ex` is **by design** (the plan requires mirroring in both surfaces to
  demonstrate them). Doc-comment clarification tracked as a nit.

---

_Reviewed: 2026-05-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
