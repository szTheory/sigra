# Phase 232: Playwright Economics — Authenticate Once, Then Shard - Pattern Map

**Mapped:** 2026-07-31  
**Files analyzed:** 7 planned create/modify targets  
**Analogs found:** 6 / 7 (the composite action is a new repository primitive)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/ci.yml` | config | event-driven | same file’s `library_tests_shard` + `library_tests` | exact topology / role-match boot |
| `.github/actions/example-playwright-boot/action.yml` | config | batch | repeated boot blocks in `.github/workflows/ci.yml` | no existing reusable-action analog |
| `test/example/priv/playwright/playwright.config.ts` | config | request-response | its existing project definitions | exact |
| `test/example/priv/playwright/tests/admin-design.setup.ts` | test | request-response | `tests/admin-design.spec.ts` registration/readiness helpers | role-match |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | test | request-response | its existing `beforeEach` readiness portion | exact |
| `test/sigra/planning/phase_232_playwright_economics_test.exs` | test | transform | `phase_230_design_gallery_split_test.exs` | exact |
| `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` | config/evidence | batch | `230-EVIDENCE.md` + `scripts/ci/ci-run-metrics.sh` | role-match |

`test/example/config/dev.exs` and `test/example/lib/example/sigra_admin_policy.ex` are integration sources, not planned edits: they already supply the per-job DB/port and policy-valid-email seams. Do not add the deferred runtime schema-prefix override.

## Pattern Assignments

### `.github/workflows/ci.yml` (config, event-driven)

**Analogs:** `.github/workflows/ci.yml:497-622` (matrix + thin result job), `.github/workflows/ci.yml:1248-1600` (current Playwright service/boot/seam routing), and `.github/workflows/ci.yml:1989-2088` (duplicated app boot consumer).

**Matrix isolation and terminal aggregation pattern** (lines 497-516, 604-620):

```yaml
library_tests_shard:
  strategy:
    fail-fast: false
    matrix:
      partition: [1, 2]
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: sigra_test
      ports: ['5432:5432']

library_tests:
  name: Library tests
  needs: [library_tests_shard]
  if: always()
  steps:
    - env:
        SHARDS: ${{ needs.library_tests_shard.result }}
      run: |
        set -euo pipefail
        if [[ "$SHARDS" != "success" ]]; then
          exit 1
        fi
```

Copy this topology for an execution job such as `example_playwright_shard`, then restore the existing job id in a thin terminal job. Its display name must remain exactly `Example Playwright smoke (full lifecycle)` and `ci-gate` must continue to consume `needs.example_playwright_smoke.result` (current reference: lines 1849-1912). The aggregator must use `always()` and fail closed on the matrix result; do not keep the current in-job step-outcome loop after each seam becomes a job.

**Per-seam command/event routing pattern** (lines 1477-1531):

```yaml
- name: Run design gallery boards (chromium, mobile, dark)
  id: design_gallery
  if: ${{ !cancelled() && needs.changes.outputs.docs_only != 'true' }}
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: "http://localhost:4000"
  run: |
    npx playwright test tests/admin-design.spec.ts \
      --project=admin-design-chromium \
      --project=admin-design-mobile \
      --project=admin-design-dark \
      --grep-invert '@snapshot'
```

Preserve each current seam’s spec/project selection and the non-PR `--grep '@snapshot'` split (lines 1504-1531). Matrix commands must append `--retries=0`; no `continue-on-error` is permitted as a flake mask. Parameterize `PGDATABASE`, `PORT`, `SIGRA_EXAMPLE_URL`, and log path at the shard boundary even though runner-local `5432` may repeat across matrix runners.

**Boot behavior to move, not redesign** (lines 1305-1408):

```yaml
- name: Setup example dev DB
  working-directory: test/example
  env: { MIX_ENV: dev, PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost }
  run: mix ecto.create && mix ecto.migrate
- name: Run demo seeds
  working-directory: test/example
  run: mix run priv/repo/seeds.exs
- name: Boot example app in background
  working-directory: test/example
  run: mix phx.server > /tmp/example-playwright-server.log 2>&1 &
- name: Wait for app and warm up LiveView routes
  run: |
    for i in $(seq 1 30); do
      if curl -sf http://localhost:4000/ > /dev/null; then break; fi
      sleep 1
    done
```

Keep the readiness loop in CI; the no-sleeps rule applies to browser/admin UI tests, whereas this is a bounded process-readiness poll. Retain the warm-up route list.

---

### `.github/actions/example-playwright-boot/action.yml` (config, batch)

**Analog:** the intentionally duplicated boot preludes in `.github/workflows/ci.yml:1270-1408`, `:2010-2088`, `:2318-2390`, and `:2570-2640`.

There is no existing local action to copy. Create the smallest GitHub composite action (`runs: using: composite`) and transplant—not reimplement—the common checkout/toolchain/cache/deps/compile/migrate/seeds/npm/browser/server/readiness sequence. Keep job-scoped `services`, permissions, event guards, artifacts, and the ultimate Playwright command in workflow callers.

The action needs explicit inputs for current intentional variation: database name, port/base URL, server log path, browser set/cache behavior, and any per-job cache identity. Follow the eval lane’s compile/runtime port contract (lines 2553-2559, 2622-2635): `PORT` must agree for compile, migration/seed, boot, curl readiness, and `SIGRA_EXAMPLE_URL`.

---

### `test/example/priv/playwright/playwright.config.ts` (config, request-response)

**Analog:** `test/example/priv/playwright/playwright.config.ts:51-85,174-205`.

**Config/project syntax pattern:**

```typescript
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'admin-design-chromium',
      testMatch: ADMIN_DESIGN_SPEC,
      use: { ...devices['Desktop Chrome'], video: checkpointVideo },
    },
  ],
});
```

Add three explicit setup projects and make each existing design project depend on precisely its matching setup project plus a distinct `storageState` path under the setup project’s `outputDir`. Keep the existing viewport/theme `use` values unchanged. Do not globally remove `workers: 1`/`fullyParallel: false` merely because the workflow shards: an individual shard remains serial unless separately proven safe; each invocation’s `--retries=0` overrides the current CI default for the required proof.

---

### `test/example/priv/playwright/tests/admin-design.setup.ts` (test, request-response)

**Analog:** `test/example/priv/playwright/tests/admin-design.spec.ts:27-65`.

**Imports, deterministic registration, policy identity** (lines 1-3, 27-65):

```typescript
import { test, expect, type Page, type TestInfo } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await Promise.all([
    page.waitForURL((url) => !url.pathname.endsWith('/users/register'), { timeout: 30_000 }),
    page.getByRole('button', { name: /Create an account/ }).click(),
  ]);
  await expect(page.getByRole('alert')).toContainText('Account created successfully!');
}
```

The setup file should own this registration helper (or a narrowly extracted shared helper) and run one explicit setup test per setup project. Generate unique `platform-admin+...@example.test` values; `Example.SigraAdminPolicy.platform_admin?/1` checks that exact prefix at `test/example/lib/example/sigra_admin_policy.ex:18-26`. After the alert/redirect, call `page.context().storageState({ path })`. State files must stay ephemeral under Playwright output, never in Git or artifacts.

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (test, request-response)

**Analog:** same file’s readiness-only portion at lines 27-38 and existing `beforeEach` at lines 266-278.

**Readiness pattern to retain:**

```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
}

test.beforeEach(async ({ page }) => {
  await page.goto('/admin/_design');
  await waitForLiveViewReady(page);
});
```

Remove the per-test `registerUser()` and `TestInfo`/password/identity-only imports or helpers from this spec. Retain role selectors, stable hooks, explicit LiveView/font readiness, full-page axe, and the existing snapshot tags/event routing. Do not use sleeps or network-idle as a substitute.

---

### `test/sigra/planning/phase_232_playwright_economics_test.exs` (test, transform)

**Analog:** `test/sigra/planning/phase_230_design_gallery_split_test.exs:1-50,149-234`.

**Structural-contract pattern:**

```elixir
defmodule Sigra.Planning.Phase230DesignGallerySplitTest do
  use ExUnit.Case, async: true

  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"
  @ci_path ".github/workflows/ci.yml"

  defp extract_job(content, job_id) do
    job_ids = ~r/^  ([a-z_]+):$/m |> Regex.scan(content, capture: :all_but_first) |> List.flatten()
    idx = Enum.find_index(job_ids, &(&1 == job_id))
    assert idx, "job `#{job_id}:` not found in #{@ci_path}"
    # Regex-extract only this top-level job body.
  end
end
```

Use `File.read!` plus narrowly scoped strings/regexes; do not add a YAML/TypeScript parser for this guard. Make checks non-vacuous: enumerate the expected shard seams, assert the matrix and `fail-fast: false`, per-shard service/database/port/app inputs, every `--retries=0`, terminal exact check name, `always()` aggregator and all-shard failure path. Also assert three distinct setup/dependency/storage mappings; the design spec no longer registers in `beforeEach`; readiness persists; exactly one action owns boot prelude; and every app-booting Playwright consumer uses it. Preserve Phase 230’s ungrepped recapture guard (lines 149-184).

---

### `232-EVIDENCE.md` (evidence, batch)

**Analog:** `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` and `scripts/ci/ci-run-metrics.sh:1-120`.

Use explicit `BEFORE-PW-01`, `AFTER-PW-01`, `AFTER-SHARD-PR`, and `AFTER-SHARD-NONPR` sections with run ID, event/ref, exact commands, unmodified script output, test-count/snapshot receipt, and required-check proof. The shared measurement script uses `set -euo pipefail`, reads `gh run view ... --json jobs`, and deliberately retains failed/skipped jobs; do not hand-calculate durations or omit non-success outcomes.

## Shared Patterns

### Deterministic admin authentication and readiness

**Sources:** `test/example/priv/playwright/tests/admin-design.spec.ts:27-52`, `test/example/lib/example/sigra_admin_policy.ex:18-26`  
**Apply to:** setup test and design spec.

Register via the UI with `getByRole` plus redirect/alert assertions, store one project-specific browser context, and retain `phx-connected` plus font-ready/font-check waits before design assertions. Each email must begin `platform-admin+`.

### Runner-local isolation via established environment seams

**Source:** `test/example/config/dev.exs:4-12,20-37`  
**Apply to:** every matrix shard and boot-action caller.

```elixir
database: System.get_env("PGDATABASE", "example_dev"),
dev_endpoint_port = String.to_integer(System.get_env("PORT", "4000"))
config :example, ExampleWeb.Endpoint, http: [ip: dev_bind_ip, port: dev_endpoint_port]
```

Use these existing env seams rather than modifying production/runtime auth schema behavior.

### Required-check honesty

**Source:** `.github/workflows/ci.yml:594-622`  
**Apply to:** terminal Playwright aggregator.

The named result job is separate from the matrix, has `if: always()`, checks the matrix result exactly, and exits nonzero unless every shard succeeded. Keep `Example Playwright smoke (full lifecycle)` byte-identical.

### Coverage and recapture preservation

**Sources:** `.github/workflows/ci.yml:1477-1531`; `test/sigra/planning/phase_230_design_gallery_split_test.exs:149-215`  
**Apply to:** matrix seam routing and Phase 232 structural test.

PR design gallery retains `--grep-invert '@snapshot'`; non-PR snapshots retain `--grep '@snapshot'`; recapture stays ungrepped and uses `--update-snapshots`.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `.github/actions/example-playwright-boot/action.yml` | config | batch | No existing local composite action; derive its exact step body from the four CI boot clones. |

## Metadata

**Analog search scope:** `.github/workflows`, `.github/actions`, `test/example/priv/playwright`, `test/example/config`, `test/example/lib`, `test/sigra/planning`, `scripts/ci`, prior Phase 230 evidence.  
**Files scanned:** 10 primary files plus project/admin test contracts.  
**Pattern extraction date:** 2026-07-31
