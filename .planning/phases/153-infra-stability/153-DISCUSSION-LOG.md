# Phase 153: Infrastructure Stability & CI Hardening - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-01T21:02:12-04:00
**Phase:** 153-infra-stability
**Mode:** assumptions with subagent-backed deepening
**Areas analyzed:** Library Postgres test harness, example-app SQL Sandbox, browser/dev-server proof, CI proof strategy, ecosystem lessons

## Assumptions Presented

### Initial Assumptions
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Scope stays infra-only; no public API, generated-host contract, or product-surface change. | High | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` |
| Primary library risk is shared live `Sigra.Test.PostgresRepo` usage, not the Phoenix example app's generated SQL Sandbox pattern. | Likely | `test/support/postgres_test_repo.ex`, `test/test_helper.exs`, `test/sigra/**/*PostgresRepo*` |
| Example app should preserve `start_owner!/stop_owner` `DataCase` and `ConnCase` patterns, adding explicit allowances only at cross-process seams. | Likely | `test/example/test/support/data_case.ex`, `test/example/test/support/conn_case.ex`, Threadline/example tests |
| CI proof should reuse existing gates and add targeted leak/cleanup verification, not a broad new matrix. | Likely | `.github/workflows/ci.yml`, Phase 151 context |

## User Direction

The user requested deeper consideration of all assumptions with subagents, including:

- pros, cons, and tradeoffs for each approach
- examples for each approach
- idiomatic Elixir, Plug, Ecto, and Phoenix posture for this kind of library/app
- lessons from popular successful libraries/apps in other ecosystems
- developer ergonomics and user-friendliness
- coherence with Sigra's goals, architecture, and project vision
- applicable information from the `prompts/` research corpus

## Subagent Research

### Library Postgres Test Harness
| Recommendation | Confidence | Evidence |
|----------------|------------|----------|
| Convert `Sigra.Test.PostgresRepo` to a sandbox-backed repo started once for the suite. | High | `test/support/postgres_test_repo.ex`, `test/test_helper.exs`, live `PostgresRepo` test modules |
| Add a shared `Sigra.Test.PostgresCase` using `start_owner!(..., shared: not tags[:async])`. | High | Ecto SQL Sandbox docs, Phoenix/Ecto case-template idioms |
| Replace per-test `DROP` / `CREATE` / `TRUNCATE` cleanup with transaction rollback where practical. | High | Current live DB tests create/truncate shared tables; Ecto SQL Sandbox provides transactional isolation |
| Treat pool-size increases and serialization as fallback mitigations, not primary architecture. | High | `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`, Ecto pool/queue guidance |

### Example App SQL Sandbox
| Recommendation | Confidence | Evidence |
|----------------|------------|----------|
| Preserve Phoenix-generated SQL Sandbox setup in `Example.DataCase` and `ExampleWeb.ConnCase`. | High | `test/example/test/support/data_case.ex`, `test/example/test/support/conn_case.ex` |
| Keep `async: false` for tests mutating VM-global state or intentionally exercising cross-process DB locking. | High | Tests using telemetry handlers, `Application.put_env/3`, `:persistent_term`, and concurrent lock paths |
| Use explicit `Sandbox.allow/3` only for known spawned DB-using processes. | High | Ecto SQL Sandbox docs and existing last-owner test pattern |
| Keep Playwright as seeded dev-server proof rather than transactional browser sandbox proof for this phase. | Medium-high | `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |

### CI And Prompt Synthesis
| Recommendation | Confidence | Evidence |
|----------------|------------|----------|
| Reuse existing CI gates as proof and add targeted leak/cleanup verification. | High | `.github/workflows/ci.yml`, `docs/uat-ci-coverage.md`, Phase 146/151 context |
| Keep deterministic single-version CI posture unless a specific compatibility risk requires matrix expansion. | High | Phase 151 context, `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` |
| Keep the work maintenance-first and stability-focused. | High | `.planning/research/SUMMARY.md`, `.planning/PROJECT.md` |

## Alternatives Considered

### Current Per-Test Repo Start + Manual Cleanup
- **Pros:** Simple locally; self-contained test files.
- **Cons:** Repeated named repo starts, shared physical tables, destructive DDL, truncation races, poor leak diagnostics.
- **Tradeoff:** Lowest migration cost, highest CI flake risk.
- **Decision:** Rejected as the primary pattern.

### Single Global Transaction
- **Pros:** Simple ownership model.
- **Cons:** Test state can leak between cases; long transactions increase lock/timeout risk; one stuck test can poison the lane.
- **Tradeoff:** Fewer moving parts but weaker isolation.
- **Decision:** Rejected.

### Sandbox Per Test With Shared Mode For Sync Tests
- **Pros:** Idiomatic Ecto/Phoenix, rollback cleanup, clear ownership, future async path via allowances.
- **Cons:** Requires migrating live DB tests and organizing DDL.
- **Tradeoff:** Moderate migration cost for durable determinism.
- **Decision:** Accepted.

### Physical DB Or Schema Per Module
- **Pros:** Strong isolation for destructive storage tests.
- **Cons:** Slow, more CI complexity, lifecycle still tricky.
- **Tradeoff:** Useful exception, not default.
- **Decision:** Deferred to rare true storage-level tests.

### Force All Example Tests `async: false`
- **Pros:** Can reduce ownership mistakes.
- **Cons:** Slows feedback and hides global-state coupling; does not help Playwright/dev-server lanes.
- **Tradeoff:** Stability by serialization, worse signal.
- **Decision:** Rejected except where global state or cross-process behavior requires it.

### Phoenix.Ecto.SQL.Sandbox For Playwright Now
- **Pros:** Official transactional browser-test mechanism for external clients.
- **Cons:** Requires endpoint plug, sandbox route/metadata, socket/LiveView connect-info/on_mount allowance, and Playwright fixture changes.
- **Tradeoff:** Excellent for transactional browser tests; excessive for current seeded dev-app proof.
- **Decision:** Deferred.

### Raise Pool Size Or Serialize CI
- **Pros:** Fast mitigation.
- **Cons:** Masks leaks and ownership bugs; may reappear under CI pressure.
- **Tradeoff:** Useful as temporary relief only.
- **Decision:** Rejected as the primary fix.

## Corrections Made

No user corrections. The user approved the expanded recommendation set with "1" / Yes, proceed.

## External Research

- Ecto SQL Sandbox docs confirm SQL Sandbox is the pool for concurrent transactional tests, `mode(:manual)` enables explicit checkout/ownership, `start_owner!/2` should be stopped in `on_exit`, allowances support async collaborating processes, shared mode supports broad collaborating processes but prevents concurrency, and `ownership_timeout` exists to catch or tune long ownership.
  Source: https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html
- Phoenix.Ecto SQL Sandbox docs confirm browser/external-client transactional tests are possible through `Phoenix.Ecto.SQL.Sandbox`, metadata headers, endpoint plug wiring, and explicit LiveView/channel allowance hooks.
  Source: https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html

## Final Decisions Captured

Final decisions are recorded in `.planning/phases/153-infra-stability/153-CONTEXT.md`.
