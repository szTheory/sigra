import { expect, test as plainTest, type Page } from '../../../test/example/priv/playwright/node_modules/@playwright/test/index.mjs';
import { adminThemeTest } from '../../../test/example/priv/playwright/fixtures/adminTheme';

// Kept outside Playwright's production testDir so failure probes never become
// application coverage identities.
async function exerciseBrowserCase(page: Page) {
  await page.goto('/');
  const title = await page.title();
  const mode = process.env.SIGRA_DIAGNOSTIC_CASE;

  if (mode === 'fail') {
    expect(title, 'intentional diagnostic assertion after a real browser navigation').toBe('Sigra diagnostic mismatch');
    return;
  }

  expect(title.length).toBeGreaterThan(0);
}

plainTest('retains a default-context first failure and discards a default-context pass', async ({ page }) => {
  await exerciseBrowserCase(page);
});

adminThemeTest('retains an adminTheme manual-context first failure and discards its pass', async ({ page }) => {
  await exerciseBrowserCase(page);
});
