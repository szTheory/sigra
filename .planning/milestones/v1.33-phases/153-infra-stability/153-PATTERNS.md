# Phase 153: Infrastructure Stability & CI Hardening - Pattern Map

**Generated:** 2026-06-02
**Status:** Planner input

## Closest Existing Patterns

### Example app sandbox helper

**Files:**
- `test/example/test/support/data_case.ex`
- `test/example/test/support/conn_case.ex`
- `test/example/test/test_helper.exs`
- `test/example/config/test.exs`

**Pattern to reuse:**
- Repo config uses `pool: Ecto.Adapters.SQL.Sandbox`.
- Test helper sets `Ecto.Adapters.SQL.Sandbox.mode(Example.Repo, :manual)`.
- Case setup starts `Ecto.Adapters.SQL.Sandbox.start_owner!(Example.Repo, shared: not tags[:async])`.
- Case setup registers `on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)`.
- ConnCase delegates to DataCase sandbox setup.

**Planner implication:** model `Sigra.Test.PostgresCase` on `Example.DataCase.setup_sandbox/1`, but keep it under library `test/support` and pointed at `Sigra.Test.PostgresRepo`.

### Current library live Postgres repo

**File:** `test/support/postgres_test_repo.ex`

**Current shape:**
- Conditional module definition behind `Code.ensure_loaded?(Postgrex)`.
- `use Ecto.Repo, otp_app: :sigra, adapter: Ecto.Adapters.Postgres`.
- `default_config/0` reads `SIGRA_TEST_PG_HOSTNAME`, `SIGRA_TEST_PG_USERNAME`, `SIGRA_TEST_PG_PASSWORD`, and `SIGRA_TEST_PG_DATABASE`.
- Currently uses normal pool behavior with `pool_size: 2`.

**Planner implication:** preserve env-driven config and optional Postgrex boundary; add SQL Sandbox pool and ownership timeout rather than introducing a new application supervisor path.

### Current library test helper

**File:** `test/test_helper.exs`

**Current shape:**
- Documents that `mix test` requires live Postgres.
- Calls `ExUnit.start()`.
- Defines Mox mocks.
- Does not start `Sigra.Test.PostgresRepo`.

**Planner implication:** start the test repo once and set manual sandbox mode after the repo module is available. Avoid disrupting existing Mox mock setup.

### Live DB test modules

**Files with direct repo start:**
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

**Files that bind shared repo and perform setup/cleanup:**
- `test/sigra/admin/users_query_test.exs`
- `test/sigra/admin/users_actions_test.exs`
- `test/sigra/admin/audit/query_test.exs`

**Planner implication:** migrate these modules to `Sigra.Test.PostgresCase` and keep `async: false`. Convert row cleanup from `TRUNCATE` to sandbox rollback where practical.

### Scratch storage test

**File:** `test/sigra/audit/query_index_test.exs`

**Current shape:**
- Uses `Sigra.Test.PostgresRepo`.
- Changes repo config with `Application.put_env(:sigra, repo, config)`.
- Calls `Ecto.Adapters.Postgres.storage_down/1` and `storage_up/1` for `sigra_audit_query_index_scratch`.
- Starts repo directly with `repo.start_link()`.

**Planner implication:** split this away from shared repo ownership. Use a distinct scratch repo module or local test repo config so destructive storage lifecycle cannot affect the shared sandbox repo.

## Data Flow To Preserve

1. Library tests call `mix test`.
2. `test/test_helper.exs` starts mocks and the shared Postgres test repo.
3. Live DB tests `use Sigra.Test.PostgresCase`.
4. Each test gets one sandbox owner and a transaction.
5. Test data inserted through `repo` rolls back when the owner is stopped.
6. Stable DDL remains explicit and idempotent.
7. Storage-destructive query planner proof runs in an isolated scratch database/repo.

## Implementation Risk Hotspots

- Tests that add/drop constraints during setup can still leak schema-level state; keep them synchronous and ensure constraint names are deterministic.
- Telemetry/threadline tests may spawn processes that outlive the test owner; require synchronous dispatch, explicit cleanup, or `Sandbox.allow/3`.
- `QueryIndexTest` must stop its scratch repo before dropping scratch storage.
- The example app already has a correct sandbox harness; do not churn it without a targeted need.

## PATTERN MAPPING COMPLETE

