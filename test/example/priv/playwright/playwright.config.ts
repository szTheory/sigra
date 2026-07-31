import { defineConfig, devices } from '@playwright/test';

// Phase 10.1.1 Plan 07: full-lifecycle golden-path browser smoke for test/example.
// Phase 31 Plan 1: partition admin verification across a single behavior-truth lane
// (desktop chromium), a compact checkpoint lane (chromium / mobile / dark-chromium)
// scoped to `tests/admin-checkpoints.spec.ts`, and a generated-host parity lane
// scoped to `tests/admin-generated.spec.ts`. The checkpoint spec itself is
// authored in a later plan; this config reserves the partitioning surface so
// the checkpoint file slots into a pre-scoped, reviewer-artifact-friendly lane.
//
// Each Playwright invocation remains internally serial (workers: 1,
// fullyParallel: false) because tests inside that invocation share its runner-local
// example database. Phase 232 isolates independent seam invocations in separate CI
// matrix jobs, so this per-invocation setting is no longer a global correctness lock.
// Retries stay at zero everywhere; CI shard commands repeat --retries=0 explicitly so
// observed isolation evidence cannot be masked by a recovered attempt.
//
// D-01..D-05, D-26..D-30: admin behavior truth stays on `chromium` only; mobile
// and dark-mode coverage comes from the dedicated checkpoint projects rather
// than rerunning the full admin behavior suite across every viewport and theme.
//
// D-20, D-21, D-24: traces remain `on-first-retry`, screenshots are captured
// only on failure globally, and retained video is enabled selectively on the
// failure-oriented admin checkpoint and generated-host projects where reviewer
// and debugging value is highest.

const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow-).*\.spec\.ts/;
const ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/;
const ADMIN_DESIGN_SPEC = /admin-design\.spec\.ts/;
const ADMIN_GENERATED_SPEC = /admin-generated\.spec\.ts/;
// Phase 189 Plan 03: dedicated modal-interaction spec (PAGE-03 APG gates).
// Runs on the main `chromium` behavior lane (NOT excluded from it).
// Excluded from `mobile` (admin behavior stays on chromium per D-01..D-05).
const ADMIN_MODAL_SPEC = /admin-modal-interaction\.spec\.ts/;
// Virtual WebAuthn authenticator uses Chrome DevTools Protocol — Chromium only
// (Playwright mobile preset is WebKit).
const WEBAUTHN_CDP_SPECS =
  /passkeys-hooks\.spec\.ts|passkey-options\.spec\.ts|passkey-login\.spec\.ts/;
// Evaluator-facing demo showcase spec — runs in its own partition so it does
// not interfere with the behavior-truth lanes (chromium, mobile).
const DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/;
// Phase 216 Plan 06: admin eval harness (render matrix + probes + bundles).
// Three projects: admin-eval (Desktop Chrome DPR1, hard-gate), admin-eval-mobile
// (iPhone 13, warn-only), admin-eval-dark (colorScheme:'dark', warn-only).
// D-15: geometry probes hard-gate only in admin-eval (chromium DPR1).
const ADMIN_EVAL_SPEC = /admin-eval\.spec\.ts/;

// GitHub Pages publish job sets SIGRA_PLAYWRIGHT_PAGES_PUBLISH=1 so reviewer
// videos are retained on green runs (default CI keeps video on failure only).
const pagesPublish = process.env.SIGRA_PLAYWRIGHT_PAGES_PUBLISH === '1';
const checkpointVideo = pagesPublish ? 'on' : 'retain-on-failure';

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  // The example app boots in MIX_ENV=dev which falls back to :longpoll
  // transport when the WebSocket handshake can't complete (common in
  // headless-chromium + Node.js Playwright runners). Every LiveView event
  // then costs a full HTTP round-trip — a single phx-change+phx-submit
  // dance can approach the default 5s expect ceiling. Raise the per-
  // assertion ceiling globally rather than sprinkling { timeout: N }
  // overrides through every spec.
  expect: {
    timeout: 15_000,
    // Baselines under `*-snapshots/` omit Playwright’s default OS suffix (`-linux`,
    // `-darwin`). Use `pathTemplate` (not `snapshotPathTemplate`) — see TestConfig
    // `expect.toHaveScreenshot` in @playwright/test types.
    toHaveScreenshot: {
      pathTemplate:
        '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}',
    },
  },
  timeout: 60_000,
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    // D-24: screenshot-on-failure globally so any failing run has a frame of
    // evidence without retaining output from every passing run.
    screenshot: 'only-on-failure',
    headless: true,
    // Longpoll transport makes each LiveView action slower; widen the
    // default action (click/fill) and navigation ceilings accordingly.
    actionTimeout: 15_000,
    navigationTimeout: 15_000,
  },
  projects: [
    // Main behavior truth lane: desktop chromium runs the full example-app
    // behavior suite (including admin user-operations, impersonation, and
    // admin-audit) but excludes the dedicated checkpoint and generated-host
    // specs so those stay scoped to their partitioned projects.
    {
      name: 'chromium',
      testIgnore: [ADMIN_CHECKPOINTS_SPEC, ADMIN_DESIGN_SPEC, ADMIN_GENERATED_SPEC, DEMO_SHOWCASE_SPEC, ADMIN_EVAL_SPEC],
      use: { ...devices['Desktop Chrome'] },
    },
    // Mobile coverage for non-admin flows (golden-path, organizations,
    // passkey-*). The admin behavior specs are intentionally excluded so
    // mobile does not silently rerun the same admin workflow assertions —
    // mobile admin coverage is owned by the dedicated checkpoint project.
    {
      name: 'mobile',
      testIgnore: [
        ADMIN_BEHAVIOR_SPECS,
        ADMIN_CHECKPOINTS_SPEC,
        ADMIN_DESIGN_SPEC,
        ADMIN_GENERATED_SPEC,
        WEBAUTHN_CDP_SPECS,
        DEMO_SHOWCASE_SPEC,
        ADMIN_MODAL_SPEC,
        ADMIN_EVAL_SPEC,
      ],
      use: { ...devices['iPhone 13'] },
    },
    // Admin checkpoint lane (chromium desktop): reviewer-facing curated
    // screenshots for the canonical admin pages. Retained video is enabled
    // on failure so diagnostic evidence is available when a checkpoint
    // regression appears, without retaining video for the many passing
    // behavior-truth runs.
    {
      name: 'admin-checkpoints-chromium',
      testMatch: ADMIN_CHECKPOINTS_SPEC,
      use: {
        ...devices['Desktop Chrome'],
        video: checkpointVideo,
      },
    },
    // Admin checkpoint lane (mobile): reviewer-facing mobile checkpoints
    // for the same canonical admin pages. Mobile regressions surface here
    // instead of in a duplicated behavior suite.
    {
      name: 'admin-checkpoints-mobile',
      testMatch: ADMIN_CHECKPOINTS_SPEC,
      use: {
        ...devices['iPhone 13'],
        video: checkpointVideo,
      },
    },
    // Admin checkpoint lane (dark theme): dark-mode reviewer artifacts come
    // from a dedicated Playwright project using `colorScheme: 'dark'` rather
    // than a UI theme toggle — per D-29 the artifact gate must not depend on
    // an interactive theme toggle.
    {
      name: 'admin-checkpoints-dark',
      testMatch: ADMIN_CHECKPOINTS_SPEC,
      use: {
        ...devices['Desktop Chrome'],
        colorScheme: 'dark',
        video: checkpointVideo,
      },
    },
    // Generated-host parity lane: proves installer/template/runtime parity
    // for the shipped admin seams without replaying the example app's full
    // admin browser matrix. Retained video on failure gives clear evidence
    // when generated-host parity regresses.
    {
      name: 'admin-generated',
      testMatch: ADMIN_GENERATED_SPEC,
      use: {
        ...devices['Desktop Chrome'],
        video: checkpointVideo,
      },
    },
    // Evaluator-facing demo showcase lane: exercises seeded personas and
    // captures four committed PNG baselines for evaluator-facing screenshots.
    // Excluded from chromium and mobile via testIgnore (D-03).
    {
      name: 'demo-showcase-chromium',
      testMatch: DEMO_SHOWCASE_SPEC,
      use: { ...devices['Desktop Chrome'] },
    },
    // Admin design gallery lane (chromium desktop): element-scoped board PNG
    // baselines for all 13 Sigra.Admin.Components + MG-1..MG-5 group boards.
    // Runs against /admin/_design (dev-only route). Excluded from chromium and
    // mobile via testIgnore so design lane stays partitioned.
    {
      name: 'admin-design-setup-chromium',
      testMatch: /admin-design\.setup\.ts/,
      grep: /authenticate admin design chromium/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'admin-design-chromium',
      testMatch: ADMIN_DESIGN_SPEC,
      dependencies: ['admin-design-setup-chromium'],
      use: {
        ...devices['Desktop Chrome'],
        video: checkpointVideo,
        storageState: 'test-results/.auth/admin-design-chromium.json',
      },
    },
    // Admin design gallery lane (mobile): mobile-viewport board baselines.
    {
      name: 'admin-design-setup-mobile',
      testMatch: /admin-design\.setup\.ts/,
      grep: /authenticate admin design mobile/,
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'admin-design-mobile',
      testMatch: ADMIN_DESIGN_SPEC,
      dependencies: ['admin-design-setup-mobile'],
      use: {
        ...devices['iPhone 13'],
        video: checkpointVideo,
        storageState: 'test-results/.auth/admin-design-mobile.json',
      },
    },
    // Admin design gallery lane (dark theme): dark-mode board baselines using
    // `colorScheme: 'dark'` rather than an interactive toggle (per D-29 pattern).
    {
      name: 'admin-design-setup-dark',
      testMatch: /admin-design\.setup\.ts/,
      grep: /authenticate admin design dark/,
      use: {
        ...devices['Desktop Chrome'],
        colorScheme: 'dark',
      },
    },
    {
      name: 'admin-design-dark',
      testMatch: ADMIN_DESIGN_SPEC,
      dependencies: ['admin-design-setup-dark'],
      use: {
        ...devices['Desktop Chrome'],
        colorScheme: 'dark',
        video: checkpointVideo,
        storageState: 'test-results/.auth/admin-design-dark.json',
      },
    },
    // Admin eval lane (Desktop Chrome DPR1): render matrix + probes + bundle writes.
    // This is the HARD-GATE geometry project (D-15): gate-severity probe findings
    // fail the test. Geometry probes run at capture via page.evaluate (D-11).
    {
      name: 'admin-eval',
      testMatch: ADMIN_EVAL_SPEC,
      use: { ...devices['Desktop Chrome'] },
    },
    // Admin eval lane (mobile): iPhone 13 render + probe capture, warn-only (D-15).
    // Geometry probes collect findings but do not fail (mobile metrics vary by OS).
    {
      name: 'admin-eval-mobile',
      testMatch: ADMIN_EVAL_SPEC,
      use: { ...devices['iPhone 13'] },
    },
    // Admin eval lane (dark theme): dark-mode render + probe capture, warn-only (D-15).
    // Geometry/color probes collect findings but do not fail in dark-mode runs.
    {
      name: 'admin-eval-dark',
      testMatch: ADMIN_EVAL_SPEC,
      use: {
        ...devices['Desktop Chrome'],
        colorScheme: 'dark',
      },
    },
  ],
});
