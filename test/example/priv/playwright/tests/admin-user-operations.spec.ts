import { test, expect, type Page } from '@playwright/test';

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function logInIfNeeded(page: Page, email: string, password: string) {
  await page.goto('/users/log_in');

  if (page.url().includes('/users/log_in')) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.locator('#login_form').evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.locator('form').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function createOrganization(page: Page, name: string, slug: string) {
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', name);
  await expect(page.locator('#slug-preview')).toHaveText(slug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  await waitForLiveViewReady(page);
}

async function clearBrowserSession(page: Page) {
  await page.context().clearCookies();
}

async function expectScopeChrome(page: Page, scopeLabel: string) {
  const header = page.locator('header').first();

  await expect(header.getByText('Admin', { exact: true })).toBeVisible();
  await expect(header.getByText(scopeLabel, { exact: true }).first()).toBeVisible();
}

test.describe('Phase 28 admin user operations contracts', () => {
  test('@smoke search -> filter -> open user -> revoke session keeps scope visible', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `operator-target-${suffix}@example.test`;
    const adminEmail = `platform-admin+${suffix}@example.test`;

    await registerUser(page, targetEmail, password);

    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    await expectScopeChrome(page, 'Global');

    await page.fill('input[name="q"]', targetEmail);
    await page.check('input[name="confirmed"]');
    await page.click('button:has-text("Search")');

    await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
    await expect(page).toHaveURL(/confirmed=true/);
    await expect(page.getByText('No users match this view')).toBeVisible();

    await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
    await waitForLiveViewReady(page);
    await expect(page.locator('#admin-users-mobile-results').getByText(targetEmail).first()).toBeVisible();
    await expect(page.getByRole('link', { name: 'Open user' }).first()).toBeVisible();

    await page.getByRole('link', { name: 'Open user' }).first().click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    await expect(page.getByText('Global user operations')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Back to users' })).toHaveAttribute(
      'href',
      /return_to|\/admin\/users\?/,
    );

    await expect(page.getByRole('button', { name: 'Revoke session' })).toBeVisible();
    await page.getByRole('button', { name: 'Revoke session' }).click();

    await expect(
      page.getByText(
        `Revoke this session for ${targetEmail} in Global scope? The user will need to sign in again.`,
      ),
    ).toBeVisible();

    await page.getByRole('button', { name: 'Confirm' }).click();

    await expect(page.getByText('Session revoked.')).toBeVisible();
    await expect(page.getByText('No active sessions.')).toBeVisible();
    await expectScopeChrome(page, 'Global');
  });

  test('global admins can pivot from user detail into an organization-scoped view', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `pivot-target-${suffix}@example.test`;
    const adminEmail = `platform-admin+pivot-${suffix}@example.test`;
    const orgName = `Pivot Org ${suffix}`;
    const orgSlug = `pivot-org-${suffix}`;

    await registerUser(page, targetEmail, password);
    await createOrganization(page, orgName, orgSlug);

    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
    await waitForLiveViewReady(page);
    await page.getByRole('link', { name: 'Open user' }).first().click();
    await waitForLiveViewReady(page);

    await expect(
      page.getByRole('link', {
        name: `Open organization-scoped view for ${orgName}`,
      }),
    ).toBeVisible();

    await page.getByRole('link', { name: `Open organization-scoped view for ${orgName}` }).click();
    await waitForLiveViewReady(page);

    await expect(page).toHaveURL(new RegExp(`/admin/organizations/${orgSlug}/users/`));
    await expect(page.getByText(`Organization-scoped user operations for ${orgName}`)).toBeVisible();
    await expectScopeChrome(page, orgName);
  });
});
