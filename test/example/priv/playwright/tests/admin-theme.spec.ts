import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function logInAsPlatformAdmin(page: Page) {
  const email = `platform-admin+theme-${Date.now()}@example.test`;
  await registerUser(page, email, TEST_PASSWORD);
}

async function shellTheme(page: Page) {
  return page.locator('.sg-admin-shell').evaluate((el) => ({
    theme: el.getAttribute('data-theme'),
    preference: el.getAttribute('data-theme-preference'),
    colorScheme: getComputedStyle(el).colorScheme,
    background: getComputedStyle(el).backgroundColor,
    coreStroke: getComputedStyle(el.querySelector('.sg-brand-mark__core') as Element).stroke,
  }));
}

test.describe('admin theme switch', () => {
  test('persists Light, Dark, and System without global DaisyUI theme state', async ({ page }) => {
    await logInAsPlatformAdmin(page);
    await page.goto('/admin');
    await waitForLiveViewReady(page);

    const switcher = page.getByRole('radiogroup', { name: 'Theme' });
    await expect(switcher).toBeVisible();
    await expect(page.getByRole('radio', { name: 'System' })).toHaveAttribute('aria-checked', 'true');

    await page.getByRole('radio', { name: 'Dark' }).click();
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'dark');
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme-preference', 'dark');
    await expect(page.getByRole('radio', { name: 'Dark' })).toHaveAttribute('aria-checked', 'true');
    await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', 'dark');
    await expect(page.locator('html')).not.toHaveAttribute('data-theme', /.+/);
    expect(await page.evaluate(() => localStorage.getItem('sigra.admin.theme'))).toBe('dark');
    const dark = await shellTheme(page);
    expect(dark.colorScheme).toContain('dark');
    expect(dark.coreStroke).toBe('rgb(244, 241, 235)');

    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'dark');
    expect((await shellTheme(page)).colorScheme).toContain('dark');

    await page.getByRole('radio', { name: 'Light' }).click();
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'light');
    await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', 'light');
    expect(await page.evaluate(() => localStorage.getItem('sigra.admin.theme'))).toBe('light');
    const light = await shellTheme(page);
    expect(light.colorScheme).toContain('light');
    expect(light.coreStroke).toBe('rgb(154, 52, 18)');

    await page.getByRole('radio', { name: 'System' }).click();
    await expect(page.locator('.sg-admin-shell')).not.toHaveAttribute('data-theme', /.+/);
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme-preference', 'system');
    await expect(page.locator('html')).not.toHaveAttribute('data-sg-admin-theme', /.+/);
    expect(await page.evaluate(() => localStorage.getItem('sigra.admin.theme'))).toBeNull();

    const { violations } = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();
    expect(violations).toHaveLength(0);
  });

  test('keyboard navigation uses radiogroup semantics', async ({ page }) => {
    await logInAsPlatformAdmin(page);
    await page.goto('/admin');
    await waitForLiveViewReady(page);

    const system = page.getByRole('radio', { name: 'System' });
    await system.focus();
    await page.keyboard.press('ArrowLeft');
    await expect(page.getByRole('radio', { name: 'Dark' })).toBeFocused();
    await expect(page.getByRole('radio', { name: 'Dark' })).toHaveAttribute('aria-checked', 'true');
    await page.keyboard.press('Home');
    await expect(page.getByRole('radio', { name: 'Light' })).toBeFocused();
    await expect(page.getByRole('radio', { name: 'Light' })).toHaveAttribute('aria-checked', 'true');
    await page.keyboard.press('End');
    await expect(page.getByRole('radio', { name: 'System' })).toBeFocused();
    await expect(page.getByRole('radio', { name: 'System' })).toHaveAttribute('aria-checked', 'true');
  });
});
