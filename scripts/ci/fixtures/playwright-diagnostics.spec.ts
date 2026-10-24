import { expect, test as plainTest, type Page } from '../../../test/example/priv/playwright/node_modules/@playwright/test/index.mjs';

// Kept outside Playwright's production testDir so failure probes never become
// application coverage identities.
async function exerciseBrowserCase(page: Page) {
  await page.goto('/');
  const title = await page.title();
  const mode = process.env.SIGRA_DIAGNOSTIC_CASE;

  if (mode === 'terminate') {
    process.kill(process.ppid, 'SIGTERM');
    process.kill(process.pid, 'SIGTERM');
    return;
  }

  if (mode === 'fail') {
    expect(title, 'intentional diagnostic assertion after a real browser navigation').toBe('Sigra diagnostic mismatch');
    return;
  }

  expect(title.length).toBeGreaterThan(0);
}

plainTest('retains a default-context first failure', async ({ page }, testInfo) => {
  expect(testInfo.project.use.trace).toBe('retain-on-failure');
  await exerciseBrowserCase(page);
});

plainTest('discards a default-context pass', async ({ page }, testInfo) => {
  expect(testInfo.project.use.trace).toBe('retain-on-failure');
  await exerciseBrowserCase(page);
});
