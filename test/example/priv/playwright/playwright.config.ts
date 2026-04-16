import { defineConfig, devices } from '@playwright/test';

// Phase 10.1.1 Plan 07: full-lifecycle golden-path browser smoke for test/example.
// DB state is shared across the spec, so we run serially (workers: 1, fullyParallel: false).
// retries: 1 in CI is the ONLY concession to timing flake — D-15 forbids masking real
// flake with continue-on-error or higher retry counts.

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
  },
  timeout: 60_000,
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    headless: true,
    // Longpoll transport makes each LiveView action slower; widen the
    // default action (click/fill) and navigation ceilings accordingly.
    actionTimeout: 15_000,
    navigationTimeout: 15_000,
  },
  projects: [
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
