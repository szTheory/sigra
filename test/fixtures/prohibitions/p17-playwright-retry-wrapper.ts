// KNOWN-BAD fixture for P17 (236-03). Carries all three retry-wrapper violations at once: a
// `retries` value read from `process.env` (would recover the flake into silence and mask the
// isolation evidence a flake investigation depends on), a `page.waitForTimeout(` (papers over
// timing instead of asserting on a real readiness signal), and a `test.slow(` (widens timeouts
// to hide the same flake instead of fixing the underlying race). It is structurally valid — a
// recognisable `defineConfig({...})` with a locatable `retries:` line — so every non-vacuity
// floor passes and the RED comes from `retryWrapperIssue`, never a parse-broke message. Never
// imported or executed — read as text only.
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  retries: Number(process.env.PLAYWRIGHT_RETRIES ?? 1),
  use: {
    baseURL: 'http://localhost:4017',
    headless: true,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});

// Masking colocated in the same substitutable file, since only one artifact is swappable via
// GSD_PROHIB_SUBJECT — the guard must catch every flavor wherever it lands.
async function maskFlake(page) {
  await page.waitForTimeout(500);
  test.slow();
}
