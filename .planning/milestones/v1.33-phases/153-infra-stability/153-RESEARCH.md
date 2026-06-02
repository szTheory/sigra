# Phase 153: Infrastructure Stability & CI Hardening - Research

**Researched:** 2026-06-02
**Status:** Ready for planning
**Requirement:** INFRA-01

## Research Question

What do we need to know to plan Phase 153 well: stabilize the DB connection sandbox and resolve CI connection leaks so test execution is deterministic and cleanup is reliable?

## Executive Summary

The library test suite has a shared live Postgres repo module, `Sigra.Test.PostgresRepo`, but individual test modules currently start that repo independently with a normal Ecto pool. Several modules also perform per-test DDL, `TRUNCATE`, or storage lifecycle work directly against live Postgres. That combination creates avoidable ownership ambiguity, pool churn, and global database mutation while `mix test` may run files concurrently.

The fix should centralize the live DB harness:

- Configure `Sigra.Test.PostgresRepo` with `pool: Ecto.Adapters.SQL.Sandbox`, env-driven connection settings, explicit `ownership_timeout`, and conservative pool sizing.
- Start the repo once from `test/test_helper.exs` and set `Ecto.Adapters.SQL.Sandbox.mode(Sigra.Test.PostgresRepo, :manual)`.
- Add a shared case helper, likely `Sigra.Test.PostgresCase`, that starts one sandbox owner per test using `start_owner!(PostgresRepo, shared: not tags[:async])`, stops it in `on_exit`, and returns `repo` plus `sandbox_owner` in test context.
- Migrate live-DB library tests off `start_supervised!({PostgresRepo, PostgresRepo.default_config()})`.
- Move stable DDL to `setup_all` where possible, then use sandbox transaction rollback as the primary row cleanup mechanism. Keep tests `async: false` during this stabilization pass unless they are proven non-overlapping.
- Treat `Sigra.Audit.QueryIndexTest` separately because it currently creates/drops a scratch database through `storage_up/storage_down`; it should not mutate global config for the shared repo or reuse the shared repo module while dropping storage.

## Primary Technical References

- `Ecto.Adapters.SQL.Sandbox` v3.14.0 docs: sandbox repos should use `pool: Ecto.Adapters.SQL.Sandbox`; manual mode requires explicit checkouts; `start_owner!/2` starts an owner process and should be stopped with `stop_owner/1`; `shared: true` prevents concurrent tests; `ownership_timeout` controls owner timeout. Source: https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html
- `Phoenix.Ecto.SQL.Sandbox` v4.7.0 docs: relevant only for external browser/client transactional testing. Phase 153 should preserve current real seeded dev-server Playwright proof and not introduce Phoenix external-client sandbox machinery. Source: https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html

## Current Code Findings

### Library DB Harness

- `test/support/postgres_test_repo.ex` defines `Sigra.Test.PostgresRepo` with a normal pool and `pool_size: 2`.
- Its module docs still say tests must call `start_link/0` or `start_supervised!/1` themselves.
- `test/test_helper.exs` starts ExUnit and Mox mocks only; it does not start `PostgresRepo` or set sandbox mode.
- CI `library_tests` and `library_tests_dep_off` provide the `sigra_test` Postgres database, so library DB tests are expected to run in default `mix test`.

### Repeated Per-Module Repo Starts

The following live-DB library tests start `PostgresRepo` independently and should move to a shared case helper:

- `test/sigra/api_token_audit_atomic_test.exs`
- `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs`
- `test/sigra/mfa_audit_atomicity_test.exs`
- `test/sigra/auth/register_audit_atomicity_test.exs`
- `test/sigra/account_audit_atomicity_test.exs`
- `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs`
- `test/sigra/oauth/oauth_ceremony_audit_test.exs`
- `test/sigra/oauth/oauth_audit_atomicity_test.exs`
- `test/sigra/audit/audit_assertions_test.exs`
- `test/sigra/audit/forwarders/threadline_test.exs`
- `test/sigra/jwt_refresh_audit_cofate_test.exs`
- `test/sigra/audit_multi_step_test.exs`

Other library tests bind `@repo Sigra.Test.PostgresRepo` and perform DDL/cleanup without visible per-test sandbox ownership:

- `test/sigra/admin/users_query_test.exs`
- `test/sigra/admin/users_actions_test.exs`
- `test/sigra/admin/audit/query_test.exs`

### DDL And Cleanup Patterns

Existing tests use:

- `CREATE TABLE IF NOT EXISTS` in setup/setup_all.
- `DROP TABLE IF EXISTS ... CASCADE`.
- `TRUNCATE TABLE ... RESTART IDENTITY CASCADE`.
- Constraint add/drop mutations inside setup.
- Query planner setup in `Sigra.Audit.QueryIndexTest` using `storage_down`, `storage_up`, `Application.put_env(:sigra, repo, config)`, and `repo.start_link()`.

Plan implication: DDL can remain explicit and idempotent, preferably in `setup_all`, but row cleanup should be transaction rollback from sandbox owners. Tests that need constraint mutation should make that mutation deterministic and restore/drop it, or keep such tests synchronous and isolated.

### Example App Sandbox

The example app already uses the expected Phoenix shape:

- `test/example/config/test.exs` configures `Example.Repo` with `pool: Ecto.Adapters.SQL.Sandbox`.
- `test/example/test/test_helper.exs` calls `Ecto.Adapters.SQL.Sandbox.mode(Example.Repo, :manual)`.
- `Example.DataCase.setup_sandbox/1` calls `start_owner!(Example.Repo, shared: not tags[:async])` and stops the owner in `on_exit`.
- `ExampleWeb.ConnCase` delegates to `Example.DataCase.setup_sandbox/1`.

Plan implication: do not rewrite the example app harness. If needed, only make targeted improvements such as returning `sandbox_owner` from `setup_sandbox/1` for explicit allowances in spawned-process tests.

## Planning Recommendations

### 1. Build A Shared Library Postgres Case

Create a test support module such as `test/support/postgres_case.ex`.

Expected behavior:

- `use ExUnit.CaseTemplate`
- aliases or imports `Sigra.Test.PostgresRepo`
- setup starts `Ecto.Adapters.SQL.Sandbox.start_owner!(Sigra.Test.PostgresRepo, shared: not tags[:async])`
- setup registers `on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)`
- setup returns `{:ok, repo: Sigra.Test.PostgresRepo, sandbox_owner: owner}`
- using block imports `Ecto.Query` where current tests expect it, but avoid over-importing unrelated helpers.

### 2. Start The Repo Once In `test/test_helper.exs`

After `ExUnit.start()` and mock setup ordering is confirmed safe:

- Start `Sigra.Test.PostgresRepo` once if `Postgrex` is loaded.
- Use `Sigra.Test.PostgresRepo.default_config()`.
- Set sandbox mode to manual with `Ecto.Adapters.SQL.Sandbox.mode(Sigra.Test.PostgresRepo, :manual)`.

The repo module is conditionally defined only if `Code.ensure_loaded?(Postgrex)` succeeds, so the helper must preserve that optional boundary.

### 3. Configure Sandbox Pool In `PostgresRepo`

Update `default_config/0` to include:

- `pool: Ecto.Adapters.SQL.Sandbox`
- `ownership_timeout: ...` explicit CI-suitable integer, for example `120_000` or higher only if current tests need it
- `pool_size` sized modestly; do not mask ownership bugs with broad pool expansion
- existing env-driven host/user/password/database and `log: false`

Update module docs to say the repo is started by `test/test_helper.exs` and live-DB tests should use `Sigra.Test.PostgresCase`.

### 4. Migrate Live-DB Tests

Replace each direct `start_supervised!({PostgresRepo, PostgresRepo.default_config()})` setup with `use Sigra.Test.PostgresCase, async: false` or an equivalent explicit setup callback.

For tests that currently do DDL in `setup`, move stable table creation to `setup_all` where possible. Keep per-test row setup inside the sandbox transaction. Avoid `TRUNCATE` where rollback covers inserted rows.

Keep all migrated live-DB tests `async: false` in this phase unless a test has:

- unique table names,
- no global DDL mutation during tests,
- no shared mode need,
- explicit `Sandbox.allow/3` for child DB processes.

### 5. Isolate `QueryIndexTest`

`Sigra.Audit.QueryIndexTest` is the highest-risk special case:

- It uses `storage_down/storage_up` on a scratch DB.
- It mutates application env for `Sigra.Test.PostgresRepo`.
- It calls `repo.start_link()` directly.

Preferred planning path:

- Stop using the shared `Sigra.Test.PostgresRepo` module for this storage-destructive scratch DB.
- Introduce a separately named scratch repo module or test-local repo module whose config points to `sigra_audit_query_index_scratch`.
- Keep `storage_up/storage_down` confined to that scratch repo.
- Ensure the scratch repo process is stopped before `storage_down` in `on_exit`.

Fallback if a separate repo is too invasive:

- Keep `QueryIndexTest` synchronous and storage-isolated.
- Ensure it does not alter the shared repo config used by other library tests.
- Explicitly stop repo before dropping scratch storage.

### 6. Cross-Process Tests

Where tests spawn tasks, telemetry forwarders, LiveView-like processes, or background workers that query through the repo:

- Prefer `start_supervised!/1` for processes so ExUnit stops them before the owner exits.
- Use `Ecto.Adapters.SQL.Sandbox.allow(repo, sandbox_owner_or_parent, child_pid)` for explicit child processes when tests become async.
- For this stabilization phase, keep such tests `async: false` and use `shared: true` via `start_owner!(..., shared: not tags[:async])`.
- Ensure telemetry handlers are detached and any synchronous dispatch assertions are complete before the sandbox owner stops.

## Verification Strategy

Minimum proof for the plan:

1. Source assertions:
   - `test/support/postgres_test_repo.ex` contains `pool: Ecto.Adapters.SQL.Sandbox`.
   - `test/test_helper.exs` starts `Sigra.Test.PostgresRepo` once and sets `Sandbox.mode(..., :manual)`.
   - `test/support/postgres_case.ex` exists and calls both `start_owner!` and `stop_owner`.
   - No migrated live-DB tests call `start_supervised!({PostgresRepo, PostgresRepo.default_config()})`.
   - `Sigra.Audit.QueryIndexTest` no longer mutates shared `Sigra.Test.PostgresRepo` config for scratch storage.
2. Targeted commands:
   - `MIX_ENV=test mix test test/sigra/audit_multi_step_test.exs test/sigra/api_token_audit_atomic_test.exs test/sigra/audit/query_index_test.exs`
   - `MIX_ENV=test mix test test/sigra/admin/users_query_test.exs test/sigra/admin/users_actions_test.exs test/sigra/admin/audit/query_test.exs`
   - `MIX_ENV=test mix test`
3. CI parity commands or jobs:
   - library tests lane: `mix test`
   - dep-off lane equivalent: compile without Threadline, then `mix test`
   - example unit smoke, Playwright smoke, generated admin smoke remain green without adding transactional browser sandboxing.

## Risks And Mitigations

- **DDL in sandbox transactions can hold locks or leak schema mutations.** Mitigate by keeping stable DDL in `setup_all`, using unique table names, and only relying on rollback for row data.
- **Shared mode disables async concurrency.** Accept for Phase 153; later async conversion should be a separate targeted optimization.
- **Owner exit errors can persist if spawned processes outlive tests.** Mitigate with `start_supervised!/1`, synchronous dispatch, explicit task awaits, and `on_exit` cleanup before owner stop.
- **`ownership_timeout` can hide slow or stuck tests if set too high.** Use an explicit but bounded value and fix ownership/lifecycle first.
- **Scratch DB storage tests can race shared repo tests.** Keep storage-destructive tests on a distinct repo module and distinct database.

## Non-Goals

- Do not introduce a broad Elixir/OTP/Postgres CI matrix.
- Do not redesign Playwright/browser tests around `Phoenix.Ecto.SQL.Sandbox`.
- Do not change Sigra public APIs, generated host contracts, auth behavior, release docs, or product scope.
- Do not solve test speed or async conversion beyond what is required to make DB cleanup deterministic.

## RESEARCH COMPLETE

