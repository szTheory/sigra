# Phase 232: Playwright Economics — Authenticate Once, Then Shard - Research

**Researched:** 2026-07-31
**Domain:** Playwright authentication reuse, isolated GitHub Actions matrix execution, and CI proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Authentication reuse and ordered measurement

- **D-01:** Add one explicit Playwright setup dependency for each of the three design projects.
  Each setup registers its own unique policy-valid `platform-admin+...` identity and writes a
  project-specific `storageState`; design tests consume the matching state rather than sharing
  one state file across viewport/theme projects.
- **D-02:** Remove `registerUser()` from `admin-design.spec.ts`'s per-test `beforeEach`. Retain only
  deterministic navigation plus existing LiveView and font readiness checks. Preserve role
  selectors, stable hooks, readiness signals, and the no-sleeps posture from the admin UI test
  contract.
- **D-03:** Land and observe PW-01 before any PW-02 topology change. Record the design-board job
  duration before and after with identical passing assertion and snapshot counts so the
  authentication-reuse improvement has its own receipt.

### Parallelization and state isolation

- **D-04:** Parallelize the existing independent Playwright seams as CI matrix shards. Each shard
  owns an isolated runner-local PostgreSQL service/database, example-app process, and listening
  port. Do not claim isolation by merely increasing `workers` or enabling `fullyParallel` against
  the current shared database and app.
- **D-05:** Prove correctness with a real run using more than one concurrent shard and
  `--retries=0`. Retries and `continue-on-error` remain forbidden as flake mitigation; any
  cross-spec interference must be removed rather than masked.
- **D-06:** Use separate databases—not per-shard auth schemas—for isolation. Do not add a
  production runtime auth-schema prefix override: generated schemas and migrations currently bake
  the prefix at install time, and a runtime-only override could point authentication queries at an
  unmigrated schema.

### Required context and shared boot prelude

- **D-07:** Put the shard jobs behind one terminal result aggregator whose displayed job name is
  exactly `Example Playwright smoke (full lifecycle)`. Every shard outcome must reach that
  aggregator; no seam may become advisory or disappear from the required verdict.
- **D-08:** Define the example-app boot prelude exactly once in a reusable workflow-level
  component and have every app-booting Playwright job consume it. The shared contract covers the
  applicable checkout/toolchain/cache/compile, database setup and migration, seeds, browser setup,
  app boot, and readiness behavior so individual lanes cannot drift.

### the agent's Discretion

- Exact setup-project names, state-file paths, and generated test identity suffixes, provided the
  three project states remain distinct and ephemeral.
- Exact shard count and seam-to-shard mapping after measuring the PW-01 baseline, provided the
  seams run concurrently with isolated databases/apps and all outcomes reach the required result.
- Whether the single boot definition is implemented as a composite action or another supported
  GitHub Actions reuse primitive. Research/planning should select the smallest mechanism that can
  parameterize the current jobs without changing their behavior.
- Exact evidence artifact layout and helper-script names, following the existing committed CI
  receipt patterns.

### Deferred Ideas (OUT OF SCOPE)

- A production runtime/boot-time auth-schema prefix override remains deferred. It needs an
  explicit generated-host and migration contract in a separate feature phase if ever promoted.
- The remaining automated todo matches were outside PW-01/PW-02/PW-03 and remain in their existing
  backlog/phase ownership; none were folded into Phase 232.
</user_constraints>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PW-01 | The design-board specs authenticate once per project instead of registering a fresh user before every test. | Setup-project and project-specific `storageState` pattern; preserved readiness and count receipt. |
| PW-02 | Playwright specs can run in parallel without cross-spec database interference, so `workers: 1` is no longer required for correctness. | Matrix-shard architecture with a job-local PostgreSQL service, app process, port, and `--retries=0` observed proof. |
| PW-03 | The example-app boot prelude is defined once and reused, rather than duplicated verbatim across jobs. | Local composite action recommendation plus structural test that counts one definition and all booting consumers. |

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system. [VERIFIED: AGENTS.md]
- Use Rail Accent assets from `brandbook/`. [VERIFIED: AGENTS.md]
- Support Light, Dark, and System modes. [VERIFIED: AGENTS.md]
- Keep admin UI Playwright tests deterministic: role selectors, stable hooks, explicit LiveView readiness, and no sleeps. [VERIFIED: AGENTS.md; guides/reference/admin-ui-principles.md; guides/reference/admin-design-contract.md]

## Summary

Phase 232 has a strict three-stage dependency chain: implement and measure PW-01 while the current one-job topology is intact; only then split the residual seams into isolated matrix jobs for PW-02; finally (or as the same topology change) route every app-booting lane through one shared boot component for PW-03. This is required for attributable measurements: sharding first would make the authentication saving unobservable. [VERIFIED: 232-CONTEXT.md D-03; ROADMAP.md:180-185]

The current serialization is intentional. `playwright.config.ts` declares `fullyParallel: false`, `workers: 1`, and one CI retry because all specs currently share the app and PostgreSQL instance started by `example_playwright_smoke`; the workflow serially launches admin behavior, checkpoints, design gallery, non-admin smoke, and demo showcase against `http://localhost:4000`. [VERIFIED: test/example/priv/playwright/playwright.config.ts:8-12,48-50; .github/workflows/ci.yml:1248-1600]

**Primary recommendation:** Create three ephemeral, project-specific design auth states under each setup project's `outputDir`; measure that isolated change; then replace the required job with matrix shard jobs that each own PostgreSQL/app/port and a thin, byte-name-preserving terminal aggregator, while extracting the repeated boot sequence into one local composite action. [CITED: https://playwright.dev/docs/auth; CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Register and persist a design-admin session once | Browser / Client | API / Backend | Playwright performs the UI registration and persists the browser context; the application creates the server-side user/session. [CITED: https://playwright.dev/docs/auth] |
| Keep design states independent by viewport/theme project | Browser / Client | Database / Storage | Each project consumes a distinct cookie state and distinct policy-valid user; state files are runner-ephemeral. [VERIFIED: 232-CONTEXT.md D-01; CITED: https://playwright.dev/docs/auth] |
| Prevent cross-spec interference | CI runner / service boundary | Database / Storage | A matrix leg receives its own runner-local PostgreSQL service and app process, so no concurrent seam shares mutable state. [VERIFIED: 232-CONTEXT.md D-04-D-06; test/example/config/dev.exs:3-12,32] |
| Preserve merge protection | CI orchestration | GitHub ruleset | The terminal aggregator alone owns the byte-identical required check display name and fails when any shard fails. [VERIFIED: 232-CONTEXT.md D-07; MAINTAINING.md:106-112; .github/workflows/ci.yml:604-622] |
| Prevent boot-prelude drift | CI orchestration | Runner environment | One component owns checkout/toolchains/cache/compile/DB/seeds/browser/app/readiness; consumer lanes only supply parameters and test commands. [VERIFIED: 232-CONTEXT.md D-08; .github/workflows/ci.yml:1248-1600,1989-2140,2297-2445,2547-2687] |

## Standard Stack

### Core

| Library / platform | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| `@playwright/test` | 1.59.1, lockfile-resolved | Project dependencies, `storageState`, setup projects, Chromium/WebKit execution. | The repository already uses it and its official authentication guide directly prescribes setup-project dependencies and `storageState` reuse. [VERIFIED: test/example/priv/playwright/package-lock.json:121-123; CITED: https://playwright.dev/docs/auth] |
| GitHub Actions matrix jobs | GitHub-hosted | Run isolated seams concurrently. | A matrix creates a separate job per declared value; an independent job owns its service container and background app. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations] |
| PostgreSQL service container | `postgres:15` | One disposable backing database per shard job. | The workflow already uses this runner-local service pattern, including library test partitions. [VERIFIED: .github/workflows/ci.yml:497-624,1248-1268] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Local composite action | no package | Reuse the in-job boot prelude. | Use for the duplicated setup sequence; composite actions collect workflow steps and run as one step. [CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action] |
| `scripts/ci/ci-run-metrics.sh` | repository script | Capture durable job-duration tables from `gh run view --json jobs`. | Use for the PW-01 before/after receipt and final topology receipt. [VERIFIED: scripts/ci/ci-run-metrics.sh:1-260; 230-EVIDENCE.md:17-21] |
| ExUnit planning contract tests | existing | Enforce workflow/spec structural invariants cheaply. | Add Phase 232-specific assertions alongside the Phase 230 contract-test style. [VERIFIED: test/sigra/planning/phase_230_design_gallery_split_test.exs; test/sigra/planning/phase_230_ci_timeouts_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Per-project setup states | One shared design-admin `storageState` | Rejected by D-01: sharing makes the three project identities/state files non-independent. [VERIFIED: 232-CONTEXT.md D-01] |
| Matrix jobs with one DB/app each | `workers > 1` or `fullyParallel: true` in the existing job | Rejected by D-04: the existing shared database/app remains a mutable-state collision domain. [VERIFIED: 232-CONTEXT.md D-04; playwright.config.ts:8-12] |
| Separate databases | Runtime auth-schema prefix override | Rejected by D-06: generated schemas/migrations bake the prefix, so a runtime-only query override could target an unmigrated schema. [VERIFIED: 232-CONTEXT.md D-06; todos/pending/2026-06-20-runtime-auth-prefix-override.md:15-48] |
| Local composite action | Reusable workflow | A reusable workflow can be matrix-called, but it is a complete job-level abstraction. The existing duplication is a repeated step prelude inside jobs; the composite action is the smallest supported primitive. [CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action; CITED: https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows] |

**Installation:** None. This phase uses existing pinned dependencies and GitHub Actions primitives; it must not add packages. [VERIFIED: test/example/priv/playwright/package-lock.json:121-123; 232-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
PW-01 (land and measure alone)
  admin-design-<project>-setup
    -> register unique platform-admin+... identity
    -> wait for registration redirect/alert
    -> context.storageState(project.outputDir/.auth/<project>.json)
    -> admin-design-<project> dependency consumes matching state
       -> beforeEach: goto /admin/_design -> LiveView ready -> fonts ready/check

PW-02 (only after PW-01 evidence)
  ci.yml matrix { seam, port, database, command }
    -> runner-local postgres:15 service
    -> shared boot composite receives PGDATABASE + PORT + log path
       -> checkout/toolchains/cache/compile/migrate/seeds/npm/browser/app/readiness
    -> `npx playwright test ... --retries=0` for exactly one seam
    -> shard result
  all matrix results -> terminal aggregator
    -> name: Example Playwright smoke (full lifecycle)
    -> fail unless every non-docs shard succeeds
    -> GitHub ruleset resolves the unchanged required context on a real PR
```

### Recommended Project Structure

```text
.github/
├── actions/example-playwright-boot/action.yml  # sole reusable boot prelude
└── workflows/ci.yml                             # shard matrix + terminal required aggregator
test/example/priv/playwright/
├── playwright.config.ts                         # setup projects + distinct storageState mapping
└── tests/
    ├── admin-design.setup.ts                    # three setup tests or equivalent explicit setup mapping
    └── admin-design.spec.ts                     # navigation/readiness only in beforeEach
test/sigra/planning/
└── phase_232_playwright_economics_test.exs      # structural non-vacuous contracts
.planning/phases/232-playwright-economics-authenticate-once-then-shard/
└── 232-EVIDENCE.md                              # measured run IDs and duration/count receipts
```

### Pattern 1: Project-specific setup dependency and ephemeral state

**What:** Define three explicit setup projects and wire each design project to exactly one matching `storageState` path. Put the paths under the setup project's `outputDir`, which Playwright cleans before a run, rather than a tracked state file. [CITED: https://playwright.dev/docs/auth]

**When to use:** PW-01 only. It is safe here because `admin-design.spec.ts` renders literal board assigns and D-01 requires distinct identities; do not extend the shared state to unrelated mutating specs. [VERIFIED: 232-CONTEXT.md D-01-D-02; test/example/priv/playwright/tests/admin-design.spec.ts:265-281]

**Example:**

```typescript
// Source: https://playwright.dev/docs/auth (adapted to Sigra's three design projects)
const designAuth = (project: string) =>
  path.join(test.info().project.outputDir, '.auth', `${project}.json`);

setup(`authenticate ${project}`, async ({ page }) => {
  await registerUser(page, `platform-admin+dg-${project}-${runNonce}@example.test`, TEST_PASSWORD);
  await page.context().storageState({ path: designAuth(project) });
});

{ name: 'admin-design-chromium-setup', testMatch: /admin-design\.setup\.ts/ },
{
  name: 'admin-design-chromium',
  dependencies: ['admin-design-chromium-setup'],
  use: { ...devices['Desktop Chrome'], storageState: '<matching outputDir state>' },
}
```

The actual implementation must use a stable mapping that a setup test can compute from its own project identity; it must not rely on `testInfo.retry`, which is irrelevant under the required `--retries=0` proof. [VERIFIED: 232-CONTEXT.md D-05; test/example/priv/playwright/tests/admin-design.spec.ts:55-67]

### Pattern 2: Matrix shards are process-isolation boundaries

**What:** Put independent seams in a `strategy.matrix` with `fail-fast: false`; every matrix job declares its own `postgres` service and invokes the boot composite with a unique `PGDATABASE`, `PORT`, `SIGRA_EXAMPLE_URL`, and log path. A GitHub matrix creates one job per value, so runner-local `localhost:5432` may repeat safely across legs; ports/database names must be distinct only within a runner. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations; VERIFIED: 232-CONTEXT.md D-04]

**When to use:** PW-02 after the measured PW-01 merge. Keep `fullyParallel: false`/`workers: 1` for any individual shard unless a separately isolated worker design is proven; the requirement is that the suite no longer relies on that setting for global correctness. [VERIFIED: 232-CONTEXT.md D-03-D-05]

**Recommended initial mapping:** one matrix row each for `admin_behavior`, `admin_checkpoints`, `design_gallery` (plus event-gated snapshots), `non_admin_smoke`, and `demo_showcase`. This mirrors the five existing seam IDs and retains coverage ownership. [VERIFIED: .github/workflows/ci.yml:1414-1561; phase_230_design_gallery_split_test.exs]

### Pattern 3: Thin name-preserving aggregator

**What:** Rename the execution job ID, not the required displayed check. A new aggregator job with `name: Example Playwright smoke (full lifecycle)` must `needs` the matrix execution job and, under `if: always()`, fail on any non-success result while preserving the docs-only receipt behavior. [VERIFIED: 232-CONTEXT.md D-07; .github/workflows/ci.yml:604-622,1563-1600]

**When to use:** Always after introducing a matrix. A matrix execution job's display names include matrix values, so it cannot itself preserve a stable singular branch-protection context. [VERIFIED: MAINTAINING.md:106-112; .github/workflows/ci.yml:497-622]

### Pattern 4: One boot component, parameters at the boundary

**What:** Create `.github/actions/example-playwright-boot/action.yml` as a composite action. Inputs should cover database name, app port/base URL, browser set, cache-key namespace/step output needs, log file, and whether a consumer must run the browser install. The action owns the sequence once; each calling job retains job-scoped `services`, permissions, timeout, event gates, artifact upload, and its particular Playwright command. [CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action; VERIFIED: 232-CONTEXT.md D-08]

**Anti-Patterns to Avoid**

- **One global storage state:** violates D-01 and couples viewport/theme lanes through a single session. [VERIFIED: 232-CONTEXT.md D-01]
- **`beforeAll` registration in the design spec:** it authenticates a different browser context, not each isolated test context. Use config-level `storageState`. [VERIFIED: test/example/priv/playwright/tests/admin-design.spec.ts:265-281; CITED: https://playwright.dev/docs/auth]
- **Parallel config flags over one database:** removes the serialization guard without removing the collision source. [VERIFIED: playwright.config.ts:8-12; 232-CONTEXT.md D-04]
- **A matrix job without a terminal aggregator:** its required check name changes and a missing/severed seam can be green by omission. [VERIFIED: 232-CONTEXT.md D-07; MAINTAINING.md:106-112]
- **Copying the composite prelude into recapture/eval lanes:** fails PW-03. Every job that boots the example app must call the same component, even if it passes a different port/log/browser input. [VERIFIED: 232-CONTEXT.md D-08; .github/workflows/ci.yml:1248-1600,1989-2140,2297-2445,2547-2687]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Persisting browser authentication | Cookie/header extraction or custom session serialization | Playwright `storageState` plus setup-project dependencies | It captures the supported context state and initializes isolated contexts correctly. [CITED: https://playwright.dev/docs/auth] |
| Job fan-out | Shell background processes competing on one runner | GitHub Actions matrix jobs | Each matrix value becomes a distinct job/runner boundary with its own service. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations] |
| Repeated boot sequence | YAML copy/paste or a large shell include | Local composite action | Composite actions package repeated job steps as one reusable step. [CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action] |
| Timing arithmetic | Ad-hoc parsing of timestamps in evidence prose | `scripts/ci/ci-run-metrics.sh --jobs <run-id>` and raw `gh run view --json jobs` | Existing script clamps known timestamp anomalies and does not hide failed/skipped duration records. [VERIFIED: scripts/ci/ci-run-metrics.sh:25-35; scripts/ci/ci-run-metrics.test.sh:8-16] |

**Key insight:** authentication reuse and shard isolation are different layers. `storageState` removes repeated browser setup; runner-local database/app ownership removes mutable server-state interference. Neither substitutes for the other. [CITED: https://playwright.dev/docs/auth; VERIFIED: 232-CONTEXT.md D-01-D-06]

## Common Pitfalls

### Pitfall 1: PW-01 and PW-02 are merged into one unmeasurable change
**What goes wrong:** A faster final matrix run proves neither how much registration reuse helped nor whether sharding regressed a seam.  
**How to avoid:** Commit PW-01, open/observe a real PR run with unchanged commands/counts, record the design-gallery step duration, then begin matrix work. [VERIFIED: 232-CONTEXT.md D-03; ROADMAP.md:180-185]

### Pitfall 2: Auth file leakage or stale state
**What goes wrong:** A tracked or reused state file contains cookies and can authenticate the wrong test/run.  
**How to avoid:** Write each state under the relevant project `outputDir` so Playwright clears it; never commit state files. [CITED: https://playwright.dev/docs/auth]

### Pitfall 3: A setup project creates a non-admin identity
**What goes wrong:** The user registers but `/admin/_design` fails authorization.  
**How to avoid:** Generate all three identities with the exact `platform-admin+` prefix that `Example.SigraAdminPolicy.platform_admin?/1` checks. [VERIFIED: test/example/lib/example/sigra_admin_policy.ex:18-26; 232-CONTEXT.md D-01]

### Pitfall 4: The setup project runs but the design project does not depend on it
**What goes wrong:** Ordering becomes incidental and state files may not exist before tests.  
**How to avoid:** Declare explicit `dependencies: ['<matching setup>']` on every design project and test the mapping structurally. [CITED: https://playwright.dev/docs/auth]

### Pitfall 5: `--retries=0` is not actually applied to shards
**What goes wrong:** Config-level CI retry (`retries: process.env.CI ? 1 : 0`) masks a flaky isolated run.  
**How to avoid:** Make every shard invocation pass `--retries=0`; retain traces/screenshots as diagnostics, not as retry authorization. [VERIFIED: playwright.config.ts:48-50; 232-CONTEXT.md D-05]

### Pitfall 6: A shard is excluded from the required verdict
**What goes wrong:** A matrix row can fail, skip unexpectedly, or be added later without affecting the required check.  
**How to avoid:** The aggregator must inspect the matrix result under `always()`/equivalent and fail closed; a structural contract must enumerate all intended seams and the aggregator's `needs`. [VERIFIED: 232-CONTEXT.md D-07; .github/workflows/ci.yml:1563-1600; phase_230_design_gallery_split_test.exs]

### Pitfall 7: Snapshot recapture silently becomes grepped
**What goes wrong:** Carrying PR `--grep-invert '@snapshot'` into the recapture path regenerates zero or partial baselines.  
**How to avoid:** Preserve ungrepped `--update-snapshots` invocations in `admin_design_recapture` and the local snapshot recapture gate. [VERIFIED: phase_230_design_gallery_split_test.exs; .github/workflows/ci.yml:2080-2090]

### Pitfall 8: The shared action conceals app-boot differences
**What goes wrong:** Existing jobs use different log paths, ports, artifact behavior, event guards, and browser needs; a zero-input action changes behavior accidentally.  
**How to avoid:** Parameterize only actual differences, leave job-specific artifacts/permissions/commands at call sites, and prove every consumer booted in a real run. [VERIFIED: .github/workflows/ci.yml:1248-1710,1989-2445,2547-2687]

## Code Examples

### Deterministic design setup contract

```typescript
// Source: Playwright Authentication guide, adapted to existing Sigra helpers.
import { test as setup, expect } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

setup('authenticate admin-design-chromium', async ({ page }) => {
  const state = test.info().project.outputDir + '/.auth/admin-design-chromium.json';
  await registerUser(page, makePolicyValidEmail('chromium'), TEST_PASSWORD);
  await expect(page.getByRole('alert')).toContainText('Account created successfully!');
  await page.context().storageState({ path: state });
});
```

Then the existing `admin-design.spec.ts` `beforeEach` is only:

```typescript
test.beforeEach(async ({ page }) => {
  await page.goto('/admin/_design');
  await waitForLiveViewReady(page); // retains phx-connected + fonts.ready + fonts.check
});
```

This retains the repository's explicit LiveView and font readiness rather than replacing it with sleeps or network-idle waits. [VERIFIED: test/example/priv/playwright/tests/admin-design.spec.ts:20-37,265-281; AGENTS.md]

### Retry-free shard command

```yaml
# One matrix value only; the called boot component receives its own DB/port.
- name: Run matrix seam
  working-directory: test/example/priv/playwright
  env:
    CI: 'true'
    SIGRA_EXAMPLE_URL: http://localhost:${{ matrix.port }}
  run: npx playwright test ${{ matrix.command }} --retries=0
```

The actual matrix command must preserve current project selections: Chromium-only admin behavior; three admin checkpoint projects; three design projects with `--grep-invert '@snapshot'` on PR and snapshot-only on non-PR; existing non-admin default projects; and `demo-showcase-chromium`. [VERIFIED: .github/workflows/ci.yml:1414-1561]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-test UI registration in isolated contexts | Setup-project `storageState` reuse | Playwright-supported current pattern | Removes repeated authentication while maintaining test-context isolation. [CITED: https://playwright.dev/docs/auth] |
| One serialized app/database job | Runner-isolated matrix shard jobs plus an aggregator | Phase 232 target | Allows concurrent seams without sharing mutable server state. [VERIFIED: 232-CONTEXT.md D-04-D-07] |
| Copy/pasted job boot sequences | One composite action consumed by each app-booting job | Phase 232 target | Makes drift structural rather than review-dependent. [CITED: https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A local composite action can expose all inputs needed to preserve current boot differences without a reusable workflow. | Architecture Patterns | Low: the planner can fall back to a reusable workflow only if an actual missing primitive is found during implementation. |

All other material claims were verified in the live repository or cited from current official documentation.

## Open Questions

1. **What is the optimal shard count after PW-01 measurement?**
   - What we know: five existing execution seams are already explicit, and the historical audit estimated residual enforced work at roughly 519 seconds after prelude. [VERIFIED: .github/workflows/ci.yml:1414-1561; SEED-005-CICD-AUDIT-2026-06-20.md:175-180]
   - What's unclear: current measured post-PW-01 seam duration and runner-minute cost.
   - Recommendation: initially map the five existing seams one-to-one, collect job timing, and only coalesce short seams if observed wall-clock/queue cost warrants it.

2. **Which jobs count as every app-booting Playwright consumer for PW-03?**
   - What we know: `example_playwright_smoke`, `admin_design_recapture`, `admin_checkpoint_recapture`, and `admin_eval_render` all visibly boot the example app; the final inventory must also inspect the preceding HTTP job before selecting consumers. [VERIFIED: .github/workflows/ci.yml:1159-1710,1989-2445,2547-2687]
   - What's unclear: whether PW-03's phrase “Playwright job” intentionally excludes the non-Playwright HTTP smoke.
   - Recommendation: scope the composite to every current app-booting Playwright job exactly; do not expand the phase to HTTP smoke without an explicit planning decision.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Node.js | Playwright config/listing and CI script checks | ✓ | v22.14.0 local; CI pins 20 | CI remains authoritative. [VERIFIED: local probe; .github/workflows/ci.yml:1277-1283] |
| npm | Existing Playwright project | ✓ | 11.1.0 | CI uses `npm ci`. [VERIFIED: local probe; .github/workflows/ci.yml:1323-1325] |
| GitHub CLI | Real-run evidence | ✓ | 2.95.0 | None; authenticated live access is needed for receipts. [VERIFIED: local probe; `gh run view 30390832059 --json jobs`] |
| Elixir/Mix | Planning contract tests | ✓ | OTP 28 / local Mix runtime | CI pins `.tool-versions`. [VERIFIED: local probe; .github/workflows/ci.yml:1270-1276] |
| Playwright browser binaries | Full local browser run | not checked | — | CI observed run is the phase proof mechanism. [VERIFIED: 230-VALIDATION.md:146-149] |

**Missing dependencies with no fallback:** none for planning. Real-run evidence requires repository GitHub permissions at execution time. [VERIFIED: `gh run view 30390832059 --json jobs`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit planning contracts; Playwright 1.59.1; real GitHub Actions observations. [VERIFIED: test/sigra/planning/phase_230_design_gallery_split_test.exs; package-lock.json:121-123] |
| Config file | `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |
| Quick run command | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` |
| Full structural suite | `mix test test/sigra/planning/` |
| Observed-run command | `bash scripts/ci/ci-run-metrics.sh --jobs <run-id>` plus `gh run view <run-id> --json jobs` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PW-01 | Three setup projects/dependencies/state paths are distinct; design `beforeEach` no longer calls `registerUser`; readiness remains. | static + Playwright list | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs && (cd test/example/priv/playwright && npx playwright test --list --project=admin-design-chromium)` | ❌ Wave 0 |
| PW-01 | Baseline and after run have identical design assertion/snapshot counts and measured design job/step time. | observed run | `gh run view <before> --json jobs` and `gh run view <after> --json jobs`; retain raw JSON/step counts in `232-EVIDENCE.md` | ❌ evidence |
| PW-02 | More than one matrix shard executes concurrently with separate DB/app/port and every command uses `--retries=0`. | static + observed run | planning contract; `gh run view <after-shard-run> --json jobs` | ❌ Wave 0 / evidence |
| PW-02 | Existing coverage routing is preserved: browser/project commands and non-PR snapshots execute in their correct events. | static + observed PR/non-PR runs | `mix test test/sigra/planning/ && gh run view <pr-run> --json jobs && gh run view <non-pr-run> --json jobs` | ❌ Wave 0 / evidence |
| PW-03 | Exactly one boot-prelude definition; all app-booting Playwright jobs invoke it. | static | `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` | ❌ Wave 0 |
| PW-03 | All consumers boot successfully after extraction. | observed run | `gh run view <after-shard-run> --json jobs` plus non-PR recapture/eval run | ❌ evidence |
| Required check | Required display name is byte-identical and resolves on a real PR. | static + real PR | planning contract; `gh pr checks <pr-number>` | ❌ Wave 0 / evidence |

### Measurement Protocol

1. Record a **BEFORE-PW-01** PR run ID before changing the design authentication path. Extract `Example Playwright smoke (full lifecycle)` and its `Run design gallery boards (chromium, mobile, dark)` step from `gh run view <id> --json jobs`. [VERIFIED: `gh run view 30390832059 --json jobs`; .github/workflows/ci.yml:1480-1503]
2. Land PW-01 alone, then record **AFTER-PW-01** from a real PR with the identical gallery command and the same expected count: 41 tests per design project before filtering; PR excludes the 28 tagged snapshots/project while non-snapshot/axe coverage remains. Retain list/log evidence, not only a duration. [VERIFIED: `npx playwright test --list --project=admin-design-chromium` reports 41 tests; phase_230_design_gallery_split_test.exs]
3. Only after the receipt is committed, land PW-02/PW-03 and record **AFTER-SHARD-PR** and **AFTER-SHARD-NONPR**. The PR must show >1 concurrent non-zero-duration shard jobs, success at `--retries=0`, all expected seams, and the terminal exact name. The non-PR run additionally proves snapshot and recapture/eval paths that are intentionally event-gated. [VERIFIED: 232-CONTEXT.md D-03-D-08; MAINTAINING.md:172-181]
4. Prove branch protection resolution on the phase PR via `gh pr checks <number>`; do not accept a workflow-file name match as proof. [VERIFIED: ROADMAP.md:182; 232-CONTEXT.md D-07]

### Sampling Rate

- **Per implementation commit:** `mix test test/sigra/planning/phase_232_playwright_economics_test.exs`.
- **Per wave merge:** `mix test test/sigra/planning/` and `cd test/example/priv/playwright && npx playwright test --list` for each affected project.
- **Phase gate:** all structural checks green plus the three ordered observed receipts: BEFORE/AFTER PW-01, retry-free multi-shard PR, and non-PR/real-PR required-check proof.

### Wave 0 Gaps

- [ ] `test/sigra/planning/phase_232_playwright_economics_test.exs` — verify distinct setup/dependency/state mapping, no design-spec registration, preserved readiness helper, and no `continue-on-error`/retry masking in the shard path.
- [ ] Same contract test — parse `ci.yml` job blocks non-vacuously, enumerate all matrix seams, assert isolated service/app/DB/port inputs, and assert the aggregator name is exactly `Example Playwright smoke (full lifecycle)`.
- [ ] Same contract test — locate one composite `action.yml` boot definition and assert every app-booting Playwright job uses it instead of owning duplicate boot/migrate/seed/readiness steps.
- [ ] `232-EVIDENCE.md` — durable raw run IDs, job/step duration tables, exact test-count receipts, concurrent shard timestamps, retry-zero command proof, and `gh pr checks` output.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Ephemeral, policy-valid test identities; state files outside version control. [CITED: https://playwright.dev/docs/auth; VERIFIED: sigra_admin_policy.ex:18-26] |
| V3 Session Management | yes | Project-specific `storageState`, cleaned in `outputDir`; do not log/upload state files. [CITED: https://playwright.dev/docs/auth] |
| V4 Access Control | yes | Preserve `platform-admin+` policy prefix in every setup identity. [VERIFIED: sigra_admin_policy.ex:18-26] |
| V5 Input Validation | no production-surface change | Test-only CI orchestration; existing registration UI validates inputs. [VERIFIED: Phase boundary] |
| V6 Cryptography | no new crypto | Continue existing Argon2id path; do not replace authentication with hand-rolled cookie generation. [VERIFIED: test/example/config/dev.exs:104-108] |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Committed or retained auth state impersonates a test user | Spoofing / Information disclosure | Write states under cleaned output directories, gitignore any fallback path, and exclude them from artifacts. [CITED: https://playwright.dev/docs/auth] |
| Shared database causes one shard to affect another | Tampering | One PostgreSQL service/database and app per runner shard. [VERIFIED: 232-CONTEXT.md D-04-D-06] |
| Required check becomes green while a shard is omitted | Tampering / Repudiation | Terminal aggregator fails closed over every shard and real-PR branch-protection receipt. [VERIFIED: 232-CONTEXT.md D-07] |
| Retry/continue-on-error hides nondeterminism | Repudiation | Explicit `--retries=0`, no flake masks, retain diagnostics and fix the collision. [VERIFIED: 232-CONTEXT.md D-05] |

## Sources

### Primary (HIGH confidence)

- `.github/workflows/ci.yml` — current serialized seam inventory, required job name, service/app boot, existing aggregators, recapture/eval consumers. [VERIFIED: codebase grep]
- `test/example/priv/playwright/playwright.config.ts` and `tests/admin-design.spec.ts` — current retry/worker posture, design project mapping, registration and deterministic readiness. [VERIFIED: codebase grep]
- `test/example/config/dev.exs` — existing `PGDATABASE`, `PGPORT`, and `PORT` isolation seams. [VERIFIED: codebase grep]
- `MAINTAINING.md`, `230-EVIDENCE.md`, `scripts/ci/ci-run-metrics.sh`, and a live `gh run view 30390832059 --json jobs` — required-context and measurement contracts. [VERIFIED: codebase and live CLI]

### Secondary (MEDIUM confidence)

- [Playwright Authentication](https://playwright.dev/docs/auth) — setup dependencies, `storageState`, cleanup, and server-state caveats.
- [GitHub composite actions](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action) — composite action scope.
- [GitHub reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) and [matrix jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) — matrix/reuse boundaries.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing lockfile/workflow plus current official Playwright/GitHub documentation.
- Architecture: HIGH — locked Phase 232 decisions and directly verified current CI/process seams.
- Pitfalls: HIGH — repository's prior CI evidence and static contracts document the exact failure modes.

**Research date:** 2026-07-31
**Valid until:** 2026-08-30 (recheck GitHub Actions/Playwright docs if planning starts later).
