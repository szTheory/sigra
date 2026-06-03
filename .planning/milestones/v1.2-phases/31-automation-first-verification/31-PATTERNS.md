# Phase 31: Automation-First Verification - Pattern Map

**Mapped:** 2026-04-16
**Scope:** verification patterns for Playwright, CI decomposition, shell smoke harnesses, ExUnit ownership, and recent verification-heavy plan structure

## Core Split To Preserve

| Surface | Existing owner | Pattern to copy |
|---|---|---|
| Library contracts and normalization | `test/sigra/**` | Direct-path ExUnit around runtime/query/filter seams, usually no browser or router dependency |
| Example host behavior | `test/example/test/**` | ConnCase/DataCase/LiveView tests proving generated-host wiring, route shape, scope boundaries, and copy |
| Browser-only operator journeys | `test/example/priv/playwright/tests/*.ts` | Narrow end-to-end specs for real DOM, LiveView timing, downloads, and generated-host smoke |
| Fresh-install/generated-host verification | `scripts/ci/*.sh` + dedicated CI jobs | Scaffold temp app, patch local path dep, install Sigra, compile/migrate/boot, then run one focused smoke |

Keep Phase 31 aligned with that split. Do not collapse everything into Playwright.

## Playwright Patterns

### Config and project shape

- Copy the serial, low-flake baseline from `test/example/priv/playwright/playwright.config.ts:8-44`.
- Reuse:
  - `testDir: './tests'`
  - `fullyParallel: false`
  - `workers: 1`
  - `retries: process.env.CI ? 1 : 0`
  - `reporter: [['list'], ['html', { open: 'never' }]]`
  - `trace: 'on-first-retry'`
  - two projects only: `mobile` and `chromium`
- Existing rationale is load-bearing: LiveView longpoll in CI is slow, so the suite raises global `expect`, action, and navigation timeouts instead of scattering per-assertion overrides.

### Helper organization

- Current pattern is "small local helper functions at top of spec, shared helpers only when repeated across files".
- Reuse shared fixture style from `test/example/priv/playwright/fixtures/mailbox.ts:1-52` for polling mailbox JSON and normalizing returned links.
- Reuse spec-local helpers for route-specific flows:
  - `waitForLiveViewReady` in `test/example/priv/playwright/tests/golden-path.spec.ts:24-34`
  - register/login/org helpers in `test/example/priv/playwright/tests/admin-audit.spec.ts:4-54`
  - richer journey helpers in `test/example/priv/playwright/tests/organizations.spec.ts:20-96`
- For Phase 31, factor out only helpers reused across multiple specs. Do not create a generic page-object layer.

### Spec composition

- Existing browser specs are scenario-driven and intentionally narrow:
  - one full lifecycle smoke: `golden-path.spec.ts`
  - one feature slice per high-risk seam: `organizations.spec.ts`, `passkey-login.spec.ts`, `admin-audit.spec.ts`
- Good pattern:
  - seed unique data with `Date.now()`
  - move through real URLs, not internal API shortcuts
  - assert one or two high-value invariants per step
  - leave heavy correctness to ExUnit
- Download/assert pattern to copy from `test/example/priv/playwright/tests/admin-audit.spec.ts:50-54` and `:96-127`:
  - `page.waitForEvent('download')`
  - click export link
  - read artifact contents and assert semantic markers, not exact full file bodies

### Artifact usage

- CI uploads the Playwright HTML report only on failure:
  - example host: `.github/workflows/ci.yml:500-506`
  - generated host: `.github/workflows/ci.yml:550-556`
- Config produces HTML report always, traces only on first retry: `playwright.config.ts:13-33`.
- Phase 31 should preserve that failure-only publication model. Do not add always-on artifact uploads unless the planner has a specific review need.

### Anti-patterns to avoid

- No broad retry increases beyond `1` in CI.
- No `continue-on-error` browser jobs.
- No giant multi-feature browser spec as the primary correctness gate.
- No browser-only proof for filter normalization, export schema, or auth scope rules that already have direct-path seams.

## CI Job Decomposition Patterns

### Decompose by verification seam, not by tool

Mirror `.github/workflows/ci.yml:10-556`:

1. `library_tests` for core library contracts.
2. `example_unit_smoke` for example-host ExUnit/ConnTest coverage.
3. install/generator smoke jobs for fresh `phx.new` verification.
4. focused shell harness jobs for edge install paths.
5. `example_http_smoke` for cheap boot-and-route sanity.
6. `example_playwright_smoke` for real browser flow.
7. `generated_admin_playwright_smoke` for generated-host parity.

This is the main pattern for Phase 31 planning: each job proves one boundary and can fail independently.

### Common job shape

- Repeated setup is intentional and should be copied:
  - checkout
  - `erlef/setup-beam`
  - Postgres service
  - targeted cache key for library vs example deps
  - `mix deps.get`
- Example jobs use `working-directory: test/example`; install/generator jobs stay at repo root and delegate to shell harnesses.

### Warm-up and artifact behavior

- Browser jobs warm the app before Playwright runs: `.github/workflows/ci.yml:475-493`.
- Artifact publishing is attached to the browser jobs only, and only on failure.
- Phase 31 should preserve this order: boot -> wait/warm -> run focused browser spec set -> upload report on failure.

### Anti-patterns to avoid

- Do not create one monolithic "verification" job that mixes library tests, temp-app generation, browser smoke, and generated-host smoke.
- Do not move scaffold-heavy logic into YAML when the repo already keeps it in `scripts/ci/*.sh`.

## Shell Smoke Harness Patterns

### Harness structure

Copy the baseline shell shape from:

- `scripts/ci/install-smoke.sh:1-61`
- `scripts/ci/passkeys-manual-fallback-smoke.sh:1-113`
- `scripts/ci/passkeys-opt-out-smoke.sh:16-144`
- `scripts/ci/admin-acceptance-smoke.sh:13-253`
- `scripts/ci/http-smoke.sh:12-46`

Common structure:

1. `set -euo pipefail`
2. derive repo root from `GITHUB_WORKSPACE` fallback
3. export Postgres/env defaults up front
4. create temp app/root under `/tmp`
5. scaffold fresh Phoenix app
6. patch `mix.exs` to local Sigra path dep
7. fetch deps
8. run focused install/setup path
9. assert file/config/route invariants
10. compile/migrate/boot
11. probe boot with bounded curl loop
12. cleanup background server with `trap`

### Assertion style

- Positive and negative assertion helpers are small shell functions:
  - `assert_file_exists`, `assert_match` in `passkeys-default-smoke.sh`
  - `assert_file_missing`, `assert_no_match` in `passkeys-opt-out-smoke.sh:26-44`
- Use `rg` for file-content assertions.
- Prefer explicit failure messages over silent grep exits.

### Generated-host acceptance harness

- `scripts/ci/admin-acceptance-smoke.sh` is the pattern for Phase 31 if a verification step needs a generated host plus browser proof:
  - scaffold host
  - patch deterministic policy/data
  - compile/migrate/seed
  - boot on dedicated port
  - run one focused Playwright spec against that host

### Anti-patterns to avoid

- No hidden state in the current repo checkout.
- No shell harness that depends on manually prepared apps.
- No unbounded sleeps; use bounded polling loops with log dump on timeout.

## ExUnit Ownership Boundaries

### `test/sigra/**`

- Library-owned seam tests live here.
- Pattern examples:
  - direct audit/query normalization in `test/sigra/admin/audit/query_test.exs:94-153`
  - direct support-action attribution in `test/sigra/admin/users_actions_test.exs:202-220`
  - pure API/runtime coverage with `use ExUnit.Case`
- Typical traits:
  - self-contained schemas/test repos when needed
  - explicit setup/DDL for library-only integration seams
  - no dependence on example router/layout/copy

### `test/example/test/**`

- Host/generator wiring lives here.
- Base helpers:
  - `Example.DataCase` in `test/example/test/support/data_case.ex:17-41`
  - `ExampleWeb.ConnCase` in `test/example/test/support/conn_case.ex:18-38`
  - suite gating in `test/example/test/test_helper.exs:1-2` with `exclude: [:example_app]`
- Include `@moduletag :example_app` when the example-app suites should opt into CI execution, as in `test/example/test/example_web/controllers/session_controller_test.exs:23` and `test/example/test/example_web/smoke/getting_started_flow_test.exs:17`.
- Use:
  - `DataCase` for example context/data semantics
  - `ConnCase` for controller/router/scope/copy
  - `ConnCase, async: false` for heavier LiveView/admin flows, e.g. `admin_audit_index_live_test.exs:2`

### Boundary to preserve

- If the assertion is about normalized filters, audit schema, or low-level contracts, keep it under `test/sigra`.
- If the assertion is about mounted routes, shell links, redirects, rendered copy, or generated-host behavior, keep it under `test/example/test`.

### Anti-patterns to avoid

- Do not move library seams into example-only tests.
- Do not use Playwright to cover behavior already proven cleanly by `ConnCase` or library ExUnit.

## Recent Plan Decomposition Patterns To Reuse

### Repeated structure from Phases 29 and 30

- Plans split verification-heavy work into small waves with explicit dependencies.
- Each plan has two tasks:
  1. add focused tests first
  2. implement the seam behind those tests
- The split is by seam:
  - runtime
  - controller/session wiring
  - shell/navigation
  - blocked operations
  - query normalization
  - explorer UI
  - per-user continuity
  - export

### Concrete patterns to copy

- Library/runtime first:
  - `29-01-PLAN.md:106-123`
  - `30-01-PLAN.md:102-118`
- Example route/UI verification next:
  - `29-02-PLAN.md:106-123`
  - `30-02-PLAN.md:103-120`
- Add browser verification only after direct-path seam exists:
  - `30-04-PLAN.md:110-133`
- Keep one plan focused on one verification seam, not one feature epic.

### Planner heuristics for Phase 31

- Start with the cheapest, most stable gate that proves the contract.
- Add browser or generated-host work only where direct-path verification cannot prove the seam.
- If a seam crosses library -> example host -> generated host, plan those as separate waves.

## Notable Seams To Preserve In Phase 31

- Shared filter contract between direct-path tests and browser/export flows: `test/sigra/admin/audit/query_test.exs:107-153`, `test/example/test/example_web/controllers/admin/audit_export_controller_test.exs:84-182`, `test/example/priv/playwright/tests/admin-audit.spec.ts:90-127`
- Scope-aware shell/navigation parity: `test/example/test/example_web/admin_shell_test.exs:12-65`
- URL-driven LiveView state rather than ephemeral client state: `test/example/test/example_web/live/admin_audit_index_live_test.exs:10-60`
- Fresh-install verification through shell harnesses instead of hand-maintained fixture apps: `scripts/ci/install-smoke.sh:13-61`, `scripts/ci/admin-acceptance-smoke.sh:65-253`
- Failure-only artifact publication for browser jobs: `.github/workflows/ci.yml:500-506`, `.github/workflows/ci.yml:550-556`

## Anti-Patterns To Call Out In The Plan

- A single giant verification plan covering library, example host, generated host, and browser work at once
- Browser tests used as the first or only proof of normalization logic
- CI YAML duplicating scaffold/setup logic already captured in `scripts/ci/*.sh`
- New shared Playwright abstraction before there is real duplication across specs
- Verification jobs that require human pre-seeding instead of deterministic fixture/bootstrap code

## Recommended Phase 31 Plan Shape

1. Library/direct-path verification seam first.
2. Example-host ExUnit seam second.
3. Shell harness or generated-host seam third, only if needed.
4. Playwright and artifact publication last, focused on operator-visible behavior and failure review.

That mirrors the way Phases 29 and 30 added confidence without making browser tests carry the full burden.
