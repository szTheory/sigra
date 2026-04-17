import { test, expect, type Page } from '@playwright/test';

// Phase 31 Plan 2: canonical admin impersonation browser contract.
//
// Per D-01, D-02, D-04 (3), D-19, D-20, and D-26 this spec owns:
//   * stale sudo -> password confirmation redirect
//   * fresh sudo -> start impersonation -> persistent banner on non-admin /
//     org-scoped pages -> stop -> return to admin context
//
// Per D-06 this spec does NOT absorb denied-impersonation / blocked-mutation
// matrices; those stay in ExUnit
// (test/sigra/plug/forbid_during_impersonation_test.exs and
// test/example/test/example_web/impersonation_blocked_ops_test.exs). Per D-27
// this spec only runs on the `chromium` behavior-truth lane; mobile and
// dark-mode coverage of the persistent banner lives in
// `tests/admin-checkpoints.spec.ts`.

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
  await page.locator('form').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function clearBrowserSession(page: Page) {
  await page.context().clearCookies();
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

async function openUserDetail(page: Page, targetEmail: string) {
  await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
  await waitForLiveViewReady(page);
  await expect(page.locator('#admin-users-mobile-results').getByText(targetEmail).first()).toBeVisible();
  await page.getByRole('link', { name: 'Open user' }).first().click();
  await waitForLiveViewReady(page);
  await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
}

async function confirmSudo(page: Page, password: string) {
  await expect(page).toHaveURL(/\/users\/sudo\?/);
  await expect(page.getByRole('heading', { name: 'Confirm your password' })).toBeVisible();
  await page.fill('input[name="sudo[password]"]', password);
  await page.getByRole('button', { name: 'Confirm password' }).click();
}

test.describe('Phase 31 admin impersonation browser contract (D-04 3)', () => {
  test('stale sudo redirects the impersonation start action through password confirmation', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `impersonation-target-${suffix}@example.test`;
    const adminEmail = `platform-admin+impersonation-${suffix}@example.test`;

    await registerUser(page, targetEmail, password);
    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    await openUserDetail(page, targetEmail);
    await expect(page.getByRole('button', { name: 'Start impersonation' })).toBeVisible();

    await page.getByRole('button', { name: 'Start impersonation' }).click();

    await expect(page).toHaveURL(/\/users\/sudo\?return_to=/);
    await expect(page.getByText('Please re-enter your password to continue.')).toBeVisible();
  });

  test('fresh sudo enables impersonation start, persistent banner visibility, and stop from a non-admin page', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `org-admin+impersonation-target-${suffix}@example.test`;
    const adminEmail = `platform-admin+impersonation-${suffix}@example.test`;
    const orgName = `Impersonation Org ${suffix}`;
    const orgSlug = `impersonation-org-${suffix}`;

    await registerUser(page, targetEmail, password);
    await createOrganization(page, orgName, orgSlug);
    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    await openUserDetail(page, targetEmail);
    await expect(page.getByRole('button', { name: 'Start impersonation' })).toBeVisible();

    const detailUrl = new URL(page.url());
    const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
    await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
    await confirmSudo(page, password);
    await expect(page).toHaveURL(new RegExp(`${detailUrl.pathname.replaceAll('/', '\\/')}\\?`));
    await waitForLiveViewReady(page);

    await page.getByRole('button', { name: 'Start impersonation' }).click();
    await expect(page).toHaveURL('/');

    await page.goto(`/organizations/${orgSlug}/members`);
    await waitForLiveViewReady(page);

    const appBanner = page.locator('section').filter({ hasText: 'Impersonating' }).first();
    await expect(appBanner).toContainText(`Impersonating ${targetEmail}`);
    await expect(appBanner).toContainText(`Signed in as ${adminEmail}`);
    await expect(appBanner.getByRole('button', { name: 'End impersonation' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Members (1)' })).toBeVisible();

    await page.goto(`/admin/organizations/${orgSlug}/users`);
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText(orgName);
    await expect(page.locator('section').filter({ hasText: 'Impersonating' }).first()).toContainText(targetEmail);

    await page.goto(`/organizations/${orgSlug}/members`);
    await waitForLiveViewReady(page);
    await expect(page.locator('section').filter({ hasText: 'Impersonating' }).first()).toContainText(
      adminEmail,
    );

    await page.getByRole('button', { name: 'End impersonation' }).click();
    await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText('Global');
    await expect(page.getByRole('button', { name: 'End impersonation' })).toHaveCount(0);
  });
});
