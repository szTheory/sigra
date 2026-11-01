import { expect, type Page } from '../../../test/example/priv/playwright/node_modules/@playwright/test/index.mjs';
import { adminThemeTest } from '../../../test/example/priv/playwright/fixtures/adminTheme';

async function exerciseBrowserCase(page: Page) {
  await page.goto('/');
  const title = await page.title();
  if (process.env.SIGRA_DIAGNOSTIC_CASE === 'fail') {
    expect(title, 'intentional diagnostic assertion after a real browser navigation').toBe('Sigra diagnostic mismatch');
    return;
  }
  expect(title.length).toBeGreaterThan(0);
}

adminThemeTest('retains an adminTheme manual-context first failure and discards its pass', async ({ page }, testInfo) => {
  expect(testInfo.project.use.trace).toBe('retain-on-failure');
  await exerciseBrowserCase(page);
});
