# Phase 153: Infrastructure Stability & CI Hardening - Context

**Gathered:** 2026-06-01 (assumptions mode, subagent-backed)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 153 stabilizes database test isolation, sandbox ownership, CI connection cleanup, and deterministic proof for INFRA-01. The phase is infra-only: it does not change Sigra public APIs, generated-host contracts, package claims, release/adoption docs, auth behavior, or product scope.
</domain>

<decisions>
## Implementation Decisions

### Library Postgres Test Harness
- **D-01:** Convert `Sigra.Test.PostgresRepo` into a SQL Sandbox-backed test repo started once for the library test suite, rather than independently started by each live-DB test module.
- **D-02:** Configure the test repo with `pool: Ecto.Adapters.SQL.Sandbox`, env-driven Postgres settings, an explicit CI-suitable `ownership_timeout`, and only modest pool-size tuning after ownership is fixed.
- **D-03:** Add a shared library DB case/helper, for example `Sigra.Test.PostgresCase`, that starts a sandbox owner per test with `Ecto.Adapters.SQL.Sandbox.start_owner!(Sigra.Test.PostgresRepo, shared: not tags[:async])`, stops it in `on_exit`, and returns the repo in test context.

### Cleanup And DDL
- **D-04:** Make transaction rollback the primary per-test cleanup mechanism for library live-DB tests. Do not rely on per-test `DROP TABLE`, `CREATE TABLE`, or `TRUNCATE` as the main isolation strategy.
- **D-05:** Keep schema/DDL setup explicit, idempotent, and preferably module-level where stable tables are needed. Test-specific data and constraint mutations should live inside the sandbox transaction where practical.
- **D-06:** Treat truly storage-destructive tests as exceptions. If a test genuinely needs physical database isolation, introduce a separately named supervised scratch repo instead of mutating global config for the shared test repo.

### Library Test Concurrency
- **D-07:** Keep existing live Postgres library tests `async: false` during the stabilization pass and run them through shared sandbox ownership. Later async conversion is allowed only for selected modules with explicit `Sandbox.allow/3` and proven non-overlap.
- **D-08:** Fix ownership and lifecycle first; do not treat broad serialization, global pool-size increases, or CI resource tuning as the primary solution.

### Query Index Test
- **D-09:** Refactor `Sigra.Audit.QueryIndexTest` away from unsupervised `repo.start_link/0`, `Application.put_env/3`, and `storage_up/storage_down` on the shared repo module. Prefer using the shared supervised sandbox repo with minimal planner fixtures; use a separate scratch repo only if storage-level isolation is unavoidable.

### Example App Sandbox Posture
- **D-10:** Preserve the existing Phoenix-generated SQL Sandbox shape in `Example.DataCase` and `ExampleWeb.ConnCase`: `mode(:manual)`, `start_owner!`, `shared: not tags[:async]`, and `stop_owner/1` in `on_exit`.
- **D-11:** Tighten only targeted example-app seams: use `Sandbox.allow/3` at explicit spawned-process boundaries, keep VM-global tests `async: false`, and optionally return `sandbox_owner` from `Example.DataCase.setup_sandbox/1` for future task/forwarder tests.
- **D-12:** Keep Threadline/example telemetry-forwarder tests synchronous and non-async, with default handler detach, test handler attach using `dispatch: :sync`, DB assertions inside the sandbox-owned connection, and handler restoration in `on_exit`.

### Browser And CI Proof
- **D-13:** Keep Playwright/dev-server lanes as real seeded dev-app proof, not transactional ExUnit Sandbox proof. Do not introduce `Phoenix.Ecto.SQL.Sandbox` for Playwright in this phase unless the browser lane is intentionally redesigned around test-mode transactional external clients.
- **D-14:** Prove the fix through existing gates: library `mix test`, dep-off library lane, example unit smoke, example Playwright smoke, generated admin smoke, and targeted leak/cleanup checks. Do not add a broad CI matrix for this phase.

### Agent Discretion

Planning agents may choose exact helper names, file organization, and the migration order across live-DB tests, provided the result preserves the decisions above, keeps the suite idiomatic for Ecto/Phoenix, and improves developer ergonomics for future DB-backed tests.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/METHODOLOGY.md`
- `.planning/phases/151-ecosystem-sync-hex-dependency-management/151-CONTEXT.md`
- `.planning/phases/152-strategic-bet-evaluation-gate/152-CONTEXT.md`
- `prompts/ecto-best-practices-deep-research.md`
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/phoenix-live-view-best-practices-deep-research.md`
- `.planning/research/LOCAL-PROMPT-SYNTHESIS.md`
- `.planning/research/SUMMARY.md`
- `.planning/research/PITFALLS.md`
- `test/support/postgres_test_repo.ex`
- `test/test_helper.exs`
- `test/example/test/test_helper.exs`
- `test/example/test/support/data_case.ex`
- `test/example/test/support/conn_case.ex`
- `test/example/config/test.exs`
- `test/example/priv/playwright/playwright.config.ts`
- `.github/workflows/ci.yml`
- `scripts/ci/install-smoke.sh`
- `scripts/ci/upgrade-smoke.sh`
- `scripts/ci/admin-acceptance-smoke.sh`
- `docs/uat-ci-coverage.md`
- `MAINTAINING.md`
- `https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html`
- `https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Test.PostgresRepo` already centralizes live Postgres connection settings for library integration tests, but currently uses a normal Ecto pool with `pool_size: 2` and no SQL Sandbox pool.
- `test/test_helper.exs` currently starts ExUnit and mocks only; it does not start the Postgres test repo or set sandbox mode.
- `Example.DataCase` and `ExampleWeb.ConnCase` already use the modern Phoenix/Ecto `start_owner!` pattern.
- CI already has the right proof surfaces: `library_tests`, `library_tests_dep_off`, `example_unit_smoke`, `example_playwright_smoke`, generated admin smoke, install smoke, and upgrade smoke.

### Established Patterns
- Sigra prefers machine-enforced proof over human-only assertions.
- Post-1.0 work defaults to stewardship and stability, not new feature expansion.
- The repo avoids broad CI matrix expansion unless a concrete compatibility or trust gap requires it.
- Existing example-browser proof intentionally runs a real seeded dev app serially rather than transactional browser tests.

### Integration Points
- Library DB harness: `test/support/postgres_test_repo.ex`, `test/test_helper.exs`, and all tests using `Sigra.Test.PostgresRepo`.
- Example app sandbox: `test/example/test/test_helper.exs`, `test/example/test/support/data_case.ex`, `test/example/test/support/conn_case.ex`, and tests that use `Example.DataCase` / `ExampleWeb.ConnCase`.
- Cross-process risk areas: tests using `Task`, LiveView processes, telemetry handlers, Threadline forwarders, `Application.put_env/3`, `:persistent_term`, Swoosh mailbox state, or background/dev-server flows.
- CI proof: `.github/workflows/ci.yml` and focused scripts under `scripts/ci/`.
</code_context>

<specifics>
## Specific Ideas

- Prefer a `Sigra.Test.PostgresCase` helper so future live-DB tests have one obvious, low-DX-friction pattern.
- Return the sandbox owner pid in test context where useful so child processes can be explicitly allowed without guessing ownership.
- Remove stale comments that claim `:postgres` tests are excluded by default when `test/test_helper.exs` does not exclude them.
- Keep table names distinct where concurrent or module-level DDL remains, but rely on sandbox rollback for row cleanup.
- If leak failures persist after sandbox migration, add diagnostics around sandbox ownership, long-running owners, and checked-out connections before increasing Postgres limits.
</specifics>

<deferred>
## Deferred Ideas

- `Phoenix.Ecto.SQL.Sandbox` for Playwright/browser acceptance tests is deferred. It is a valid future approach if Sigra intentionally moves browser tests to transactional test-mode external-client proof, but it is too much machinery for Phase 153's current seeded dev-server lanes.
- Broad Elixir/OTP/Phoenix CI matrix expansion remains deferred per Phase 151 unless a specific compatibility regression requires it.

### Reviewed Todos (not folded)

None.
</deferred>
