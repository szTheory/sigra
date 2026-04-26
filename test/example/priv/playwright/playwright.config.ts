import { defineConfig, devices } from '@playwright/test';

// Phase 10.1.1 Plan 07: full-lifecycle golden-path browser smoke for test/example.
// Phase 31 Plan 1: partition admin verification across a single behavior-truth lane
// (desktop chromium), a compact checkpoint lane (chromium / mobile / dark-chromium)
// scoped to `tests/admin-checkpoints.spec.ts`, and a generated-host parity lane
// scoped to `tests/admin-generated.spec.ts`. The checkpoint spec itself is
// authored in a later plan; this config reserves the partitioning surface so
// the checkpoint file slots into a pre-scoped, reviewer-artifact-friendly lane.
//
// DB state is shared across specs, so we run serially (workers: 1, fullyParallel: false).
// retries: 1 in CI is the ONLY concession to timing flake — D-15 forbids masking real
// flake with continue-on-error or higher retry counts.
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
  /(admin-user-operations|admin-audit|impersonation)\.spec\.ts/;
const ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/;
const ADMIN_GENERATED_SPEC = /admin-generated\.spec\.ts/;
// Virtual WebAuthn authenticator uses Chrome DevTools Protocol — Chromium only
// (Playwright mobile preset is WebKit).
const WEBAUTHN_CDP_SPECS =
  /passkeys-hooks\.spec\.ts|passkey-options\.spec\.ts|passkey-login\.spec\.ts/;
// Phase 86 D-86-03: email visual regression lane (9 templates × 2 engines × 2 themes = 36 baselines)
// Each project is scoped to exactly one engine+theme combination. The spec
// encodes engine and theme in every snapshot name so no project-name suffix is needed.
const EMAIL_VISUAL_SPEC = /email-visual\.spec\.ts/;

// GitHub Pages publish job sets SIGRA_PLAYWRIGHT_PAGES_PUBLISH=1 so reviewer
// videos are retained on green runs (default CI keeps video on failure only).
const pagesPublish = process.env.SIGRA_PLAYWRIGHT_PAGES_PUBLISH === '1';
const checkpointVideo = pagesPublish ? 'on' : 'retain-on-failure';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
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
      testIgnore: [ADMIN_CHECKPOINTS_SPEC, ADMIN_GENERATED_SPEC, EMAIL_VISUAL_SPEC],
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
        ADMIN_GENERATED_SPEC,
        EMAIL_VISUAL_SPEC,
        WEBAUTHN_CDP_SPECS,
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

    // Phase 86 D-86-03: email visual regression lane.
    //
    // 9 templates × 2 engines × 2 themes = 36 committed baselines.
    // Viewport: 640×1200 (matches the email card width in base_layout/1).
    // Diff tolerance: maxDiffPixels 50 per D-86-03 and D-86-11.
    //
    // Each project covers exactly one engine+theme combination. The spec
    // includes engine and theme in the snapshot arg so the committed PNG names
    // are `{template}__{engine}__{theme}.png` — no project-name suffix needed.
    //
    // snapshotPathTemplate at the project level routes baselines to the
    // canonical `__snapshots__/email-visual.spec.ts/` directory instead of the
    // default `tests/email-visual.spec.ts-snapshots/` path used by other specs.
    //
    // Baselines are generated once with `--update-snapshots` and then committed.
    // Normal CI runs compare against committed PNGs and fail on drift.
    // To update: `MIX_ENV=test mix sigra.email.snapshot` then
    // `npx playwright test tests/email-visual.spec.ts --update-snapshots`.
    // Document the reason for the change in the commit message.
    {
      name: 'email-visual-chromium-light',
      testMatch: EMAIL_VISUAL_SPEC,
      // Route baselines to the canonical __snapshots__/email-visual.spec.ts/ path.
      // {arg}{ext} only — no {-projectName} suffix because the arg already encodes
      // engine and theme (e.g. `lockout-notification__chromium__light.png`).
      expect: {
        toHaveScreenshot: {
          pathTemplate: '__snapshots__/email-visual.spec.ts/{arg}{ext}',
          maxDiffPixels: 50,
        },
      },
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 640, height: 1200 },
        colorScheme: 'light',
      },
    },
    {
      name: 'email-visual-chromium-dark',
      testMatch: EMAIL_VISUAL_SPEC,
      expect: {
        toHaveScreenshot: {
          pathTemplate: '__snapshots__/email-visual.spec.ts/{arg}{ext}',
          maxDiffPixels: 50,
        },
      },
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 640, height: 1200 },
        colorScheme: 'dark',
      },
    },
    {
      name: 'email-visual-webkit-light',
      testMatch: EMAIL_VISUAL_SPEC,
      expect: {
        toHaveScreenshot: {
          pathTemplate: '__snapshots__/email-visual.spec.ts/{arg}{ext}',
          maxDiffPixels: 50,
        },
      },
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 640, height: 1200 },
        colorScheme: 'light',
      },
    },
    {
      name: 'email-visual-webkit-dark',
      testMatch: EMAIL_VISUAL_SPEC,
      expect: {
        toHaveScreenshot: {
          pathTemplate: '__snapshots__/email-visual.spec.ts/{arg}{ext}',
          maxDiffPixels: 50,
        },
      },
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 640, height: 1200 },
        colorScheme: 'dark',
      },
    },
  ],
});
