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
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    headless: true,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
