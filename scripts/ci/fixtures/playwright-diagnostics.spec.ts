import { expect } from '@playwright/test';
import { adminThemeTest } from '../../../test/example/priv/playwright/fixtures/adminTheme';

// Kept outside Playwright's production testDir so failure probes never become
// application coverage identities.
adminThemeTest('captures first diagnostic browser failure or disposes passing trace', async ({ page }) => {
  await page.goto('/');
  const title = await page.title();
  const mode = process.env.SIGRA_DIAGNOSTIC_CASE;

  if (mode === 'fail') {
    expect(title, 'intentional diagnostic assertion after a real browser navigation').toBe('Sigra diagnostic mismatch');
    return;
  }

  expect(title.length).toBeGreaterThan(0);
});
