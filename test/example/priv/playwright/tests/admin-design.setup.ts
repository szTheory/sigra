import { expect, test as setup, type Page } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { randomUUID } from 'node:crypto';
import { TEST_PASSWORD } from '../helpers/fixtures';

const chromiumStatePath = 'test-results/.auth/admin-design-chromium.json';
const mobileStatePath = 'test-results/.auth/admin-design-mobile.json';
const darkStatePath = 'test-results/.auth/admin-design-dark.json';

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  const fontLoaded = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  expect(fontLoaded, 'Space Grotesk must be loaded before persisting auth state').toBe(true);
}

async function registerDesignAdmin(page: Page, email: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', TEST_PASSWORD);
  await Promise.all([
    page.waitForURL((url: URL) => !url.pathname.endsWith('/users/register'), { timeout: 30_000 }),
    page.getByRole('button', { name: /Create an account/ }).click(),
  ]);
  await expect(page.getByRole('alert')).toContainText('Account created successfully!');
}

async function persistDesignAdmin(page: Page, email: string, statePath: string) {
  await registerDesignAdmin(page, email);
  await mkdir(dirname(statePath), { recursive: true });
  await page.context().storageState({ path: statePath });
}

setup('authenticate admin design chromium', async ({ page }) => {
  await persistDesignAdmin(
    page,
    `platform-admin+dg-chromium-${randomUUID()}@example.test`,
    chromiumStatePath,
  );
});

setup('authenticate admin design mobile', async ({ page }) => {
  await persistDesignAdmin(
    page,
    `platform-admin+dg-mobile-${randomUUID()}@example.test`,
    mobileStatePath,
  );
});

setup('authenticate admin design dark', async ({ page }) => {
  await persistDesignAdmin(
    page,
    `platform-admin+dg-dark-${randomUUID()}@example.test`,
    darkStatePath,
  );
});
