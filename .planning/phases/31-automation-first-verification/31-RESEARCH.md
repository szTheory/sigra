# Phase 31: Automation-First Verification - Research

**Researched:** 2026-04-16
**Domain:** Admin verification architecture on the existing ExUnit + Playwright + CI harness
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Browser coverage boundary
- **D-01:** Browser verification uses a layered contract model, not a giant
  end-to-end matrix. Playwright should prove a small set of canonical operator
  journeys where real browser semantics matter, while ExUnit and Phoenix test
  helpers continue to own most correctness and failure-path coverage.
- **D-02:** The example app is the primary browser test bed for deep admin flow
  coverage. It already provides the richest deterministic fixtures and should
  remain the place where Sigra proves user-operations, impersonation, and audit
  journeys end to end in a browser.
- **D-03:** Generated-host browser coverage is intentionally shallow and parity-
  focused. It should prove installer/template/runtime parity for the shipped
  seams, not duplicate the example app's full browser journey suite.
- **D-04:** The canonical browser contract set for Phase 31 is:
  1) user search/filter -> open user -> revoke session -> scope remains visible;
  2) global detail -> organization-scoped pivot -> organization scope remains
  explicit; 3) stale sudo redirect, then fresh sudo -> start impersonation ->
  persistent banner on a non-admin page -> stop -> return to admin context;
  4) audit filtering -> impersonation semantics visible -> CSV export ->
  scoped per-user/org path keeps filter semantics aligned.
- **D-05:** Generated-host browser smoke should cover: shell render on desktop
  and mobile, visible scope labels, admin navigation presence, allowed
  organization access, denied global admin response, and not-found out-of-scope
  organization response. Keep generated-host flows narrow and deterministic.
- **D-06:** Do not move broad negative-case matrices into Playwright. Denied
  impersonation attempts, blocked sensitive mutations, malformed params,
  scope-safe export rules, audit attribution, and authorization permutations
  should remain primarily outside the browser.

### Non-browser verification boundary
- **D-07:** Correctness for security-sensitive library behavior stays
  ExUnit-owned. Authorization, scope narrowing, impersonation state
  transitions, timeout handling, audit attribution, and export filtering rules
  should be asserted primarily in in-process tests under `test/sigra/**/*.exs`
  and the example app's controller/LiveView tests.
- **D-08:** Booted-app smoke is intentionally thin and targeted. Use shell/curl
  or similar process-external requests only for wiring/runtime seams that
  in-process ExUnit cannot prove: server boot, route availability, session/cookie
  continuity across real HTTP, generated-host installation/runtime wiring, and
  a few admin-critical denial/success responses.
- **D-09:** Phase 31 adopts a layered model:
  ExUnit owns correctness, targeted booted-app smoke owns runtime/wiring
  confidence, and browser coverage owns operator UX. Do not let shell smoke
  become a second full functional suite.
- **D-10:** Generated-host parity must remain explicit. For admin verification,
  Sigra should verify both the example app and a freshly generated host app:
  the example app remains the rich deterministic test bed, while generated-host
  smoke proves installer/template parity for the shipped seams.
- **D-11:** Generated-host smoke should stay narrow. It should cover install,
  compile, boot, deterministic admin policy/data seeding, and a minimal set of
  admin route checks or focused acceptance flows. It should not duplicate the
  example app's broad ExUnit matrix.
- **D-12:** Non-browser verification should fail on policy and contract
  regressions, not on presentation details. Assertions belong on HTTP status,
  redirect target, audit side effects, CSV schema/filtering, and scope denial
  semantics rather than page copy or layout.
- **D-13:** Direct-path coverage must include negative cases, not only happy
  paths. Explicitly keep denied/out-of-scope/impersonation-blocked/export-scope
  scenarios in ExUnit and targeted HTTP smoke so Phase 31 does not create false
  confidence from browser-only success flows.

### What belongs where
- **D-14:** `test/sigra/**/*.exs` owns library contracts: admin authorizer
  decisions, impersonation start/stop/timeout semantics, dual-actor audit field
  assembly, export query normalization, scope-safe query behavior, and
  impersonation-forbidden mutation guards.
- **D-15:** `test/example/test/**/*_test.exs` owns example host integration:
  controller and LiveView route behavior, redirects, scoped resource loading,
  CSV response shape, return-to handling, and browserless end-to-end flows that
  can run through `Phoenix.ConnTest` and `Phoenix.LiveViewTest`.
- **D-16:** `scripts/ci/*.sh` smoke owns process-external checks only:
  fresh-install compile/migrate, generated-host boot, example-host boot, and a
  few real HTTP requests that prove runtime wiring for admin-critical routes.
- **D-17:** Generated-host smoke must cover the seams Sigra actually ships:
  installer output, generated policy/layout/router/template wiring, and at
  least one deterministic admin journey proving the generated app is not merely
  compilable but operable.
- **D-18:** Do not add shell/curl coverage for detailed LiveView interaction
  flows, complex filtering matrices, pagination behavior, or broad authorization
  permutations already better covered in ExUnit. Those belong in ExUnit or
  Playwright, not bash.

### Artifact policy
- **D-19:** Dedicated admin verification Playwright jobs must upload reviewer-
  usable artifacts on every run, not only on failure. Phase 31 should make
  green runs reviewable, not just debuggable.
- **D-20:** Passing runs retain a lightweight artifact set:
  Playwright HTML report plus explicit curated screenshots for the selected
  desktop/mobile/dark admin checkpoints. Do not retain full trace or full video
  bundles for every passing run.
- **D-21:** Failing runs retain the richer diagnostic bundle:
  Playwright HTML report plus `test-results/` with retained traces, failure
  screenshots, and retained videos where enabled.
- **D-22:** Artifact publication should stay scoped to the dedicated admin
  verification jobs for the example app and generated host. Do not widen this
  policy to every unrelated browser or smoke job in the repository.
- **D-23:** Retention stays intentionally short-lived:
  7 days for PR/push verification artifacts and 14 days for main/nightly/release
  admin verification artifacts.
- **D-24:** Keep `trace: 'on-first-retry'`. Add `screenshot: 'only-on-failure'`
  globally for failure evidence, and use retained video sparingly, ideally on
  failure-oriented admin verification jobs rather than blanket always-on video.
- **D-25:** Reviewer-facing visual checkpoints on passing runs should come from
  explicit test-authored screenshots, not from retaining whole-run raw
  Playwright output directories indiscriminately.

### Mobile and dark-mode gate shape
- **D-26:** Mobile and dark mode are gated through a dedicated checkpoint layer,
  not by rerunning the entire functional suite across every viewport/theme
  combination.
- **D-27:** Keep one main behavioral browser suite for workflow truth, then add
  a compact checkpoint spec that captures retained artifacts for selected admin
  pages in `chromium`, `mobile`, and `dark-chromium`.
- **D-28:** The required checkpoint pages are:
  global user index, user detail, organization-scoped admin page, active
  impersonation state on a non-admin or org-scoped page, and audit explorer.
  These pages collectively prove shell chrome, dense data layout, action
  visibility, scope context, banner persistence, and filter/export usability.
- **D-29:** Dark mode should be invoked primarily through a dedicated Playwright
  project using `colorScheme: 'dark'`. Do not make the artifact gate depend on
  a UI theme toggle interaction.
- **D-30:** Do not adopt a full visual-baseline regime for the admin milestone.
  Use targeted screenshots and assertions as reviewer artifacts, while keeping
  correctness gates grounded in Playwright behavior, ExUnit, and direct-path
  tests.

### Claude's Discretion
- Exact file/module names for any new Playwright checkpoint specs or CI jobs
- Exact split between controller tests and lower-level library tests, as long as
  policy correctness remains library-owned
- Exact screenshot filenames and artifact folder layout, provided the retained
  outputs stay predictable and scoped
- Exact script names and CI job partitioning for the targeted HTTP/admin smoke
- Whether the thin runtime smoke uses `curl` alone or a small Elixir/Req helper,
  provided it stays process-external and minimal

### Deferred Ideas (OUT OF SCOPE)
None stated in `31-CONTEXT.md`. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VFY-01 | Sigra ships automated browser/system coverage for critical admin flows, including user search/detail, session revocation, impersonation start/stop, and audit filtering/export. [VERIFIED: .planning/REQUIREMENTS.md] | Canonical example-app browser suite on `chromium`; direct-path ExUnit at library + example tiers; thin generated-host runtime smoke. |
| VFY-02 | The admin milestone produces review artifacts that make UX progress easy to inspect asynchronously, including Playwright HTML reports plus screenshots, traces, and retained video where useful. [VERIFIED: .planning/REQUIREMENTS.md] | Always-upload HTML report + explicit checkpoint screenshots on green; upload `test-results/` diagnostics on failure; keep failure video selective. |
| VFY-03 | Automated verification covers both browser and direct-path behavior so authorization, scope, impersonation, and export rules are proven outside the browser happy path. [VERIFIED: .planning/REQUIREMENTS.md] | Preserve library and example ExUnit ownership for negative/security cases; add only targeted process-external checks for boot/session/route seams. |
| VFY-04 | Automated review coverage includes mobile and dark-mode checkpoints for the admin UI so responsive and low-light usability regressions are visible in CI artifacts. [VERIFIED: .planning/REQUIREMENTS.md] | Add compact checkpoint spec and `dark-chromium` project; do not rerun the full behavior suite across every viewport/theme combination. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Reuse the existing Phoenix/Ecto/LiveView stack; do not introduce a second frontend or testing stack. [VERIFIED: CLAUDE.md]
- Keep dependencies minimal and prefer the repo's existing patterns and helpers. [VERIFIED: CLAUDE.md]
- Testing must stay comprehensive around happy path, main error cases, and boundary conditions, with flat AAA-style specs. [VERIFIED: CLAUDE.md]
- Local `mix test` depends on Postgres at `localhost:5432` with `postgres`/`postgres`. [VERIFIED: CLAUDE.md]
- Work should stay inside the GSD workflow and phase artifacts. [VERIFIED: CLAUDE.md]

## Summary

Sigra already has the right verification skeleton for this phase: library-owned ExUnit for security semantics, example-app ExUnit for Phoenix integration, a thin example HTTP smoke job, a real example Playwright job, and a generated-host admin acceptance harness. The phase should strengthen that skeleton instead of replacing it. The current gaps are scope, not tooling: admin browser coverage currently runs as part of a broader Playwright smoke job, mobile coverage duplicates full behavior flows, dark-mode coverage is absent, and green runs do not publish reviewer-usable artifacts. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: test/example/priv/playwright/playwright.config.ts] [VERIFIED: test/example/priv/playwright/tests/admin-user-operations.spec.ts] [VERIFIED: test/example/priv/playwright/tests/impersonation.spec.ts] [VERIFIED: test/example/priv/playwright/tests/admin-audit.spec.ts]

The implementation-ready shape is a layered contract model. Keep behavior truth in a narrow example-app `chromium` admin suite; keep security and negative cases in ExUnit; keep generated-host coverage intentionally small and parity-oriented; add a dedicated checkpoint spec for curated screenshots in `chromium`, `mobile`, and `dark-chromium`; and publish two artifact classes in CI: lightweight review artifacts on green, richer diagnostics on failure. That approach satisfies the phase decisions without adding a second runner, without ballooning runtime, and without recreating the same assertions in browser, ExUnit, and bash. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] [CITED: https://playwright.dev/docs/test-projects] [CITED: https://playwright.dev/docs/next/test-use-options] [CITED: https://playwright.dev/docs/test-reporters]

**Primary recommendation:** Split admin verification into four owned slices: Playwright harness partitioning, example-app admin behavior plus checkpoints, direct-path verification plus thin runtime smoke, and CI artifact publication. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin browser workflow truth | Browser / Client | Frontend Server (SSR) | Real browser semantics matter for LiveView interaction, navigation, downloads, and viewport/theme rendering; the example app already hosts those flows. [VERIFIED: test/example/priv/playwright/tests/admin-user-operations.spec.ts] [VERIFIED: test/example/priv/playwright/tests/impersonation.spec.ts] [VERIFIED: test/example/priv/playwright/tests/admin-audit.spec.ts] |
| Authorization, impersonation, export policy correctness | API / Backend | Database / Storage | The rules are library-owned and already asserted in ExUnit around authorizer, impersonation state, and export semantics. [VERIFIED: test/sigra/admin/authorizer_test.exs] [VERIFIED: test/sigra/impersonation_test.exs] [VERIFIED: test/sigra/plug/forbid_during_impersonation_test.exs] |
| Example-host route and LiveView integration | Frontend Server (SSR) | API / Backend | Redirects, scoped route loading, `return_to`, and LiveView rendering belong in controller/LiveView tests, not the browser as primary truth. [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs] [VERIFIED: test/example/test/example_web/live/admin_user_show_live_test.exs] [VERIFIED: test/example/test/example_web/controllers/admin/audit_export_controller_test.exs] |
| Boot/runtime seam verification | Frontend Server (SSR) | Browser / Client | Real HTTP is only needed to prove app boot, route reachability, cookie continuity, and generated-host wiring. [VERIFIED: scripts/ci/http-smoke.sh] [VERIFIED: scripts/ci/admin-acceptance-smoke.sh] |
| Reviewer artifact publication | CDN / Static | Browser / Client | Playwright emits static report folders and test output artifacts, while GitHub Actions stores them as downloadable review evidence. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [VERIFIED: .github/workflows/ci.yml] [CITED: https://playwright.dev/docs/test-reporters] [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data?azure-portal=true] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@playwright/test` | `1.59.1` (npm modified 2026-04-16) [VERIFIED: npm registry] | Browser admin workflow coverage, HTML report, screenshots, traces, optional video | Already pinned in the repo lockfile and used by all browser smoke. Extend it; do not add Cypress/WebdriverIO. [VERIFIED: test/example/priv/playwright/package-lock.json] [VERIFIED: npm registry] |
| ExUnit | Bundled with Elixir 1.18+ in repo toolchain [VERIFIED: mix.exs] | Library contract tests and example integration tests | The repo already uses ExUnit as the main correctness engine for admin policy, impersonation, and audit/export behavior. [VERIFIED: test/sigra/admin/authorizer_test.exs] [VERIFIED: test/sigra/impersonation_test.exs] [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs] |
| Phoenix ConnTest / LiveViewTest | Phoenix `1.8.5`, LiveView `1.1.28` in lockfiles [VERIFIED: mix.lock] | Direct-path controller and LiveView verification | These tests already cover admin redirects, scoped loading, `return_to`, and CSV controller behavior more deterministically than browser duplication. [VERIFIED: test/example/test/example_web/live/admin_user_show_live_test.exs] [VERIFIED: test/example/test/example_web/controllers/admin/audit_export_controller_test.exs] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `actions/upload-artifact` | pinned SHA for `v4.4.3` in CI [VERIFIED: .github/workflows/ci.yml] | Publish HTML reports and diagnostics | Use for per-job artifact bundles with explicit names and retention; `retention-days` is supported and artifact names are immutable per upload in v4+. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data?azure-portal=true] [CITED: https://github.com/actions/upload-artifact] |
| Bash + `curl` | `curl 8.7.1` locally [VERIFIED: local command] | Process-external boot and route canaries | Use only for real HTTP seam checks such as boot, session continuity, and a few admin-critical status/redirect checks. [VERIFIED: scripts/ci/http-smoke.sh] [VERIFIED: scripts/ci/admin-acceptance-smoke.sh] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing Playwright workspace | A second E2E runner | Reject. It would duplicate harness setup and violate the repo's current testing shape. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] |
| Targeted checkpoint screenshots | Full visual snapshot baseline regime | Reject for v1.2. The context explicitly prefers curated checkpoints over snapshot-everything maintenance. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] |
| Thin runtime smoke | Broad curl/bash functional suite | Reject. The phase boundary keeps negative-case matrices in ExUnit and rich workflows in Playwright. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] |

**Installation:**
```bash
cd test/example/priv/playwright
npm ci
```

**Version verification:** `npm view @playwright/test version time.modified --json` returned `1.59.1` with registry modification time `2026-04-16T23:42:29.089Z`. [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram

```text
Developer / CI
  |
  +--> mix test ------------------------------> test/sigra/**/*.exs
  |                                             |
  |                                             +--> library policy truth
  |
  +--> cd test/example && mix test ----------> controller + LiveView tests
  |                                             |
  |                                             +--> route, redirect, CSV, return_to truth
  |
  +--> boot app + curl script ----------------> scripts/ci/*smoke.sh
  |                                             |
  |                                             +--> runtime / boot / cookie seam truth
  |
  +--> npx playwright test -------------------> behavior suite (chromium)
  |                                             |
  |                                             +--> operator workflow truth
  |
  +--> npx playwright test -------------------> checkpoint suite (chromium/mobile/dark)
                                                |
                                                +--> curated screenshots + HTML report
                                                |
                                                +--> upload-artifact
                                                      |
                                                      +--> green review bundle
                                                      +--> failure diagnostics bundle
```

### Recommended Project Structure

```text
test/
├── sigra/                          # library-owned policy and runtime contracts
├── example/test/example_web/       # controller, LiveView, and integration contracts
└── example/priv/playwright/
    ├── playwright.config.ts        # project split, artifact policy, reporter config
    ├── helpers/                    # shared screenshot / login / fixture helpers
    └── tests/
        ├── admin-*.spec.ts         # canonical admin behavior flows
        └── admin-checkpoints.spec.ts

scripts/ci/
├── http-smoke.sh                   # example-app generic boot smoke
├── admin-http-smoke.sh             # new focused admin seam smoke
└── admin-acceptance-smoke.sh       # generated-host install/boot/parity smoke

.github/workflows/
└── ci.yml                          # dedicated admin artifact jobs
```

### Pattern 1: Split behavioral truth from visual checkpoints
**What:** Keep one admin behavior suite on `chromium`, then run a separate checkpoint spec on `chromium`, `mobile`, and `dark-chromium`. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [CITED: https://playwright.dev/docs/test-projects] [CITED: https://playwright.dev/docs/emulation]

**When to use:** When the same pages need both functional proof and reviewer-facing screenshots, but rerunning the full behavior suite across every viewport/theme would duplicate runtime and assertions. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

**Example:**
```ts
// Source: https://playwright.dev/docs/test-projects
// Source: https://playwright.dev/docs/emulation
export default defineConfig({
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', testMatch: /admin-checkpoints\.spec\.ts/, use: { ...devices['iPhone 13'] } },
    {
      name: 'dark-chromium',
      testMatch: /admin-checkpoints\.spec\.ts/,
      use: { ...devices['Desktop Chrome'], colorScheme: 'dark' },
    },
  ],
});
```

### Pattern 2: Attach curated screenshots to the HTML report
**What:** Save named screenshots through `testInfo.outputPath(...)` and attach them so the HTML report is reviewer-usable even on green runs. [CITED: https://playwright.dev/docs/api/class-testinfo] [CITED: https://playwright.dev/docs/test-reporters]

**When to use:** For canonical review pages where the artifact itself is part of the deliverable. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

**Example:**
```ts
// Source: https://playwright.dev/docs/api/class-testinfo
test('admin checkpoint', async ({ page }, testInfo) => {
  await page.goto('/admin/users');
  const path = testInfo.outputPath('admin-users-desktop.png');
  await page.screenshot({ path, fullPage: true });
  await testInfo.attach('admin-users-desktop', { path, contentType: 'image/png' });
});
```

### Pattern 3: Keep generated-host smoke deterministic and narrow
**What:** Continue using `admin-acceptance-smoke.sh` to scaffold, install, seed deterministic admin fixtures, boot the generated host, then run only the shipped admin seam checks. [VERIFIED: scripts/ci/admin-acceptance-smoke.sh] [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts]

**When to use:** To prove installer/template/runtime parity for the generated host without cloning the example-app browser matrix. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

### Anti-Patterns to Avoid

- **Full-matrix browser duplication:** Today the existing admin files already expand to 14 test instances because all admin specs run on both `mobile` and `chromium`; adding dark mode to that same behavior set would grow the matrix again. [VERIFIED: local command]
- **Failure-only artifact publication:** Current CI uploads Playwright artifacts only on failure for both example and generated-host jobs, so green runs are not asynchronously reviewable. [VERIFIED: .github/workflows/ci.yml]
- **Generated-host suite creep:** `admin-generated.spec.ts` should stay about shell/scoping/denial parity; detailed filtering and mutation matrices belong elsewhere. [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser artifact plumbing | Custom report bundler | Playwright HTML reporter + `testInfo.attach` + `actions/upload-artifact` | The built-in reporter already writes `playwright-report`, supports attachments, and CI artifact upload already exists. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [CITED: https://playwright.dev/docs/test-reporters] [CITED: https://playwright.dev/docs/api/class-testinfo] |
| Dark-mode verification | UI-toggle automation just to enter dark mode | A dedicated Playwright project with `colorScheme: 'dark'` | Dark-mode artifact gating is cheaper and more deterministic through project config. [CITED: https://playwright.dev/docs/emulation] |
| Generated-host auth client | Full custom HTTP test framework | `curl` cookie jar or a tiny helper inside a focused smoke script | The process-external layer only needs a few real HTTP seam checks. [VERIFIED: scripts/ci/http-smoke.sh] [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] |
| Artifact storage rules | Manual zip and retention logic | `actions/upload-artifact` with explicit artifact names and `retention-days` | GitHub already handles storage and per-artifact retention. [CITED: https://docs.github.com/en/actions/tutorials/store-and-share-data?azure-portal=true] [CITED: https://github.com/actions/upload-artifact] |

**Key insight:** The hard part in this phase is ownership discipline, not missing tooling. Sigra already has the right tools; Phase 31 should tighten boundaries so each layer proves one thing well. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Expanding every admin behavior spec to every viewport/theme
**What goes wrong:** Runtime climbs quickly while the same security and workflow assertions get re-executed three times. [VERIFIED: local command]
**Why it happens:** Playwright projects run all matched tests by default, and the current config already applies `mobile` and `chromium` to every admin spec. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [CITED: https://playwright.dev/docs/test-projects]
**How to avoid:** Restrict the behavior suite to `chromium` and target `mobile` plus `dark-chromium` only at the checkpoint spec. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]
**Warning signs:** `npx playwright test --list` shows the same admin workflow multiplied across projects instead of only the checkpoint spec. [VERIFIED: local command]

### Pitfall 2: Letting Playwright become the primary security oracle
**What goes wrong:** Browser-only happy paths hide denied, malformed, and edge-case regressions. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]
**Why it happens:** Browser tests are attractive but they are slower and less precise for policy permutations than ExUnit and Phoenix test helpers. [VERIFIED: test/sigra/admin/authorizer_test.exs] [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs]
**How to avoid:** Keep negative admin policy, impersonation-forbidden mutations, export scoping, and timeout semantics in `test/sigra` and example controller/LiveView tests. [VERIFIED: test/sigra/plug/forbid_during_impersonation_test.exs] [VERIFIED: test/example/test/example_web/impersonation_blocked_ops_test.exs] [VERIFIED: test/example/test/example_web/controllers/admin/audit_export_controller_test.exs]
**Warning signs:** New Playwright tests start asserting 403/404/error permutations already covered by ExUnit files.

### Pitfall 3: Publishing only HTML reports without curated green artifacts
**What goes wrong:** Reviewers must browse the raw report after every run, and green runs still lack obvious mobile/dark snapshots. [VERIFIED: .github/workflows/ci.yml]
**Why it happens:** The current jobs upload only on failure and only the report folder. [VERIFIED: .github/workflows/ci.yml]
**How to avoid:** Always upload `playwright-report/` plus a stable `artifacts/admin-checkpoints/` directory for green runs; upload `test-results/` only on failure. [CITED: https://playwright.dev/docs/test-reporters] [CITED: https://playwright.dev/docs/next/test-use-options]
**Warning signs:** Successful PR runs have no downloadable screenshots.

### Pitfall 4: Reusing artifact names carelessly after CI split
**What goes wrong:** `upload-artifact` v4+ treats artifacts as immutable and duplicate names across uploads can fail. [CITED: https://github.com/actions/upload-artifact]
**Why it happens:** Splitting example and generated-host jobs into multiple uploads tempts copy-paste artifact names.
**How to avoid:** Give each upload a distinct name by scope and purpose, e.g. `admin-example-report`, `admin-example-diagnostics`, `admin-generated-report`, `admin-generated-diagnostics`. [CITED: https://github.com/actions/upload-artifact]
**Warning signs:** Artifact upload steps fail after adding a second upload step or matrix dimension.

## Code Examples

Verified patterns from official sources and repo usage:

### Admin-specific artifact config
```ts
// Source: https://playwright.dev/docs/next/test-use-options
// Source: https://playwright.dev/docs/test-reporters
export default defineConfig({
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
});
```

### CI artifact upload with short retention
```yaml
# Source: https://docs.github.com/en/actions/tutorials/store-and-share-data?azure-portal=true
# Source: https://github.com/actions/upload-artifact
- name: Upload admin report
  uses: actions/upload-artifact@v4
  with:
    name: admin-example-report
    path: |
      test/example/priv/playwright/playwright-report/
      test/example/priv/playwright/artifacts/admin-checkpoints/
    retention-days: 7
    if-no-files-found: error
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One Playwright smoke job uploading artifacts only on failure | Admin-specific jobs that always publish review artifacts and upload extra diagnostics only on failure | Recommended for Phase 31; current workflow is still failure-only today. [VERIFIED: .github/workflows/ci.yml] | Green runs become asynchronously reviewable. |
| Re-run the same workflow specs across every viewport/theme | One truth suite plus a compact checkpoint layer using Playwright projects | Supported in current Playwright docs. [CITED: https://playwright.dev/docs/test-projects] [CITED: https://playwright.dev/docs/emulation] | Keeps runtime bounded while still exposing mobile and dark regressions. |
| Raw output directories as the only evidence | Explicit attachments and named screenshots in the HTML report | Supported by `testInfo.attach`. [CITED: https://playwright.dev/docs/api/class-testinfo] | Reviewer artifacts become predictable and easier to scan. |

**Deprecated/outdated:**
- Uploading only failure reports for admin verification is no longer sufficient for this milestone's review-artifact goal. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

All substantive claims in this research were verified against repo files, local commands, or official docs in this session. No user confirmation gates were introduced.

## Open Questions

1. **Should the generated-host job publish dark-mode screenshots too, or only desktop/mobile shell parity?**
   - What we know: The context requires generated-host browser coverage to stay narrow and parity-focused. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]
   - What's unclear: Whether the generated host needs dark-mode reviewer evidence or whether example-app dark checkpoints are sufficient.
   - Recommendation: Default to example-app dark checkpoints only; add generated-host dark screenshots only if the shipped templates diverge materially by theme.

2. **Should admin runtime smoke stay pure bash/curl or use a tiny Elixir helper for authenticated requests?**
   - What we know: The discretion area explicitly allows either, provided the layer stays process-external and minimal. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md]
   - What's unclear: Which approach yields the lowest maintenance for authenticated admin export checks.
   - Recommendation: Prefer bash + curl cookie jar first; move to a small helper only if login/export session handling becomes awkward.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Playwright workspace and `npm ci` | ✓ [VERIFIED: local command] | `v22.14.0` [VERIFIED: local command] | — |
| npm | Playwright dependency install | ✓ [VERIFIED: local command] | `11.1.0` [VERIFIED: local command] | — |
| Elixir / Mix | ExUnit and Phoenix tasks | ✓ [VERIFIED: local command] | Elixir repo requires `~> 1.18`; local runtime is present. [VERIFIED: mix.exs] [VERIFIED: local command] | — |
| PostgreSQL | `mix test`, example app DB, smoke scripts | ✓ [VERIFIED: local command] | `pg_isready` reports `accepting connections`. [VERIFIED: local command] | GitHub Actions service already provisions Postgres in CI. [VERIFIED: .github/workflows/ci.yml] |
| `curl` | HTTP smoke scripts | ✓ [VERIFIED: local command] | `8.7.1` [VERIFIED: local command] | — |
| Playwright CLI | Browser suite execution | ✓ via workspace [VERIFIED: local command] | `1.59.1` [VERIFIED: local command] | `npx playwright ...` from `test/example/priv/playwright` |

**Missing dependencies with no fallback:**
- None. [VERIFIED: local command]

**Missing dependencies with fallback:**
- None. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix ConnTest/LiveViewTest + Playwright `1.59.1` [VERIFIED: mix.lock] [VERIFIED: npm registry] |
| Config file | `test/example/priv/playwright/playwright.config.ts` for browser tests; ExUnit uses Mix project config. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [VERIFIED: mix.exs] |
| Quick run command | `MIX_ENV=test mix test test/sigra/admin/authorizer_test.exs test/sigra/impersonation_test.exs test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1` [VERIFIED: local command] |
| Full suite command | CI workflow jobs in `.github/workflows/ci.yml` plus focused admin Playwright commands from this phase. [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VFY-01 | Library-owned admin authorization and impersonation rules | unit | `MIX_ENV=test mix test test/sigra/admin/authorizer_test.exs test/sigra/impersonation_test.exs test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1` | ✅ [VERIFIED: local command] |
| VFY-01 | Example-host redirect, restore, blocked-op, CSV, and user-detail integration | integration | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/controllers/impersonation_controller_test.exs test/example_web/controllers/admin/audit_export_controller_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1` | ✅ [VERIFIED: local command] |
| VFY-01 | Canonical admin browser journeys on example app | browser | `cd test/example/priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts --project=chromium` | ✅ [VERIFIED: test/example/priv/playwright/tests/admin-user-operations.spec.ts] [VERIFIED: test/example/priv/playwright/tests/impersonation.spec.ts] [VERIFIED: test/example/priv/playwright/tests/admin-audit.spec.ts] |
| VFY-02 | Review artifacts on green and diagnostics on failure | CI artifact | workflow step in `.github/workflows/ci.yml` | ❌ Wave 0 |
| VFY-03 | Process-external generated-host admin seam checks | smoke | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh` | ✅ [VERIFIED: scripts/ci/admin-acceptance-smoke.sh] |
| VFY-04 | Mobile and dark-mode curated checkpoints | browser artifact | `cd test/example/priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-checkpoints.spec.ts --project=chromium --project=mobile --project=dark-chromium` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run the focused ExUnit commands that match the changed layer. [VERIFIED: local command]
- **Per wave merge:** Run example admin Playwright behavior plus checkpoint spec. [VERIFIED: test/example/priv/playwright/tests/admin-user-operations.spec.ts] [VERIFIED: test/example/priv/playwright/tests/impersonation.spec.ts] [VERIFIED: test/example/priv/playwright/tests/admin-audit.spec.ts]
- **Phase gate:** CI green with library, example direct-path, example admin browser, generated-host admin browser, and artifact uploads present. [VERIFIED: .planning/ROADMAP.md]

### Wave 0 Gaps

- [ ] `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — curated desktop/mobile/dark screenshots for the five required admin pages.
- [ ] `test/example/priv/playwright/helpers/admin-artifacts.ts` (or equivalent) — shared naming/attachment helper so screenshot output is predictable.
- [ ] `test/example/priv/playwright/playwright.config.ts` — add `dark-chromium`, checkpoint project scoping, `screenshot`, and selective `video` policy.
- [ ] `.github/workflows/ci.yml` — dedicated always-upload artifact steps for green runs and separate failure diagnostics upload.
- [ ] `scripts/ci/admin-http-smoke.sh` (or equivalent focused extension) — thin authenticated admin route/export seam checks without browser duplication.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Reuse existing Sigra login/session flows; do not create test-only auth backdoors in the verification harness. [VERIFIED: scripts/ci/admin-acceptance-smoke.sh] [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] |
| V3 Session Management | yes | Preserve real session rotation, sudo confirmation, impersonation restore, and cookie continuity through existing Sigra session primitives. [VERIFIED: test/sigra/impersonation_test.exs] [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs] |
| V4 Access Control | yes | Keep admin scope, out-of-scope org denial, and impersonation-forbidden mutations asserted primarily in library/example ExUnit. [VERIFIED: test/sigra/admin/authorizer_test.exs] [VERIFIED: test/example/test/example_web/impersonation_blocked_ops_test.exs] |
| V5 Input Validation | yes | Reuse normalized query-param handling for audit and export routes; verify malformed or out-of-scope params outside the browser. [VERIFIED: test/example/test/example_web/controllers/admin/audit_export_controller_test.exs] |
| V6 Cryptography | no new phase-owned crypto | Continue using Sigra's existing HMAC/session/token primitives; Phase 31 should not introduce new crypto logic. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Broken admin scope enforcement hidden by happy-path browser tests | Elevation of Privilege | Keep out-of-scope org and forbidden global cases in library/example ExUnit and thin HTTP smoke. [VERIFIED: test/sigra/admin/authorizer_test.exs] [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] |
| Session restore regressions around impersonation | Spoofing / Elevation of Privilege | Assert restore token handling in controller tests and timeout behavior in library tests. [VERIFIED: test/sigra/impersonation_test.exs] [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs] |
| Export scope leakage | Information Disclosure | Keep CSV scope and filter semantics covered in controller tests and a minimal real-HTTP export canary. [VERIFIED: test/example/test/example_web/controllers/admin/audit_export_controller_test.exs] |
| Artifact leakage of unnecessary raw test output on success | Information Disclosure | Upload only curated screenshots + report on green; keep `test-results/` for failure diagnostics. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] [CITED: https://playwright.dev/docs/next/test-use-options] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/31-automation-first-verification/31-CONTEXT.md` - phase boundary, ownership rules, artifact policy, and mobile/dark-mode decisions.
- `.github/workflows/ci.yml` - current CI job layout, current artifact uploads, and current admin/browser split.
- `test/example/priv/playwright/playwright.config.ts` - current Playwright project shape, reporter config, and trace policy.
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` - existing admin user-operation browser flow.
- `test/example/priv/playwright/tests/impersonation.spec.ts` - existing impersonation browser flow.
- `test/example/priv/playwright/tests/admin-audit.spec.ts` - existing audit filter/export browser flow.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` - current generated-host parity smoke.
- `scripts/ci/http-smoke.sh` - current example-app process-external smoke boundary.
- `scripts/ci/admin-acceptance-smoke.sh` - current generated-host install/seed/boot/browser harness.
- `test/sigra/admin/authorizer_test.exs` - library-owned admin scope truth.
- `test/sigra/impersonation_test.exs` - library-owned impersonation truth.
- `test/sigra/plug/forbid_during_impersonation_test.exs` - library-owned impersonation mutation guard truth.
- `test/example/test/example_web/controllers/impersonation_controller_test.exs` - example-host controller truth for impersonation.
- `test/example/test/example_web/controllers/admin/audit_export_controller_test.exs` - example-host controller truth for scoped exports.
- `test/example/test/example_web/live/admin_user_show_live_test.exs` - example-host LiveView truth for user detail and audit handoff.
- `https://playwright.dev/docs/next/test-use-options` - screenshot / trace / video options and output location.
- `https://playwright.dev/docs/videos` - `retain-on-failure` and `on-first-retry` video behavior.
- `https://playwright.dev/docs/test-projects` - project scoping, `testMatch`, and dependency model.
- `https://playwright.dev/docs/emulation` - `colorScheme: 'dark'` support.
- `https://playwright.dev/docs/test-reporters` - HTML reporter output folder and attachment behavior.
- `https://playwright.dev/docs/api/class-testinfo` - `outputPath` and `attach`.
- `https://docs.github.com/en/actions/tutorials/store-and-share-data?azure-portal=true` - workflow artifact upload and `retention-days`.
- `https://github.com/actions/upload-artifact` - artifact immutability, `if-no-files-found`, and retention inputs.

### Secondary (MEDIUM confidence)

- `npm view @playwright/test version time.modified --json` - current registry version and update time. [VERIFIED: npm registry]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - The phase reuses existing repo tooling, and the only version-sensitive external recommendation (`@playwright/test`) was checked against the npm registry. [VERIFIED: npm registry]
- Architecture: HIGH - The ownership boundaries come directly from `31-CONTEXT.md` and current repo harness layout. [VERIFIED: .planning/phases/31-automation-first-verification/31-CONTEXT.md] [VERIFIED: .github/workflows/ci.yml]
- Pitfalls: HIGH - The main risks are directly visible in the current config, current workflow, and current project expansion. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: local command]

**Research date:** 2026-04-16
**Valid until:** 2026-05-16
