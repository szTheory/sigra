import { readFile } from 'node:fs/promises';
import { test, expect, type Download, type Page } from '@playwright/test';

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
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}$|/organizations/${slug}/members$`));
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
  await page.fill('input[name="sudo[password]"]', password);
  await page.getByRole('button', { name: 'Confirm password' }).click();
}

async function readDownload(download: Download) {
  const path = await download.path();
  expect(path).not.toBeNull();
  return await readFile(path as string, 'utf8');
}

test.describe('Phase 30 admin audit browser contracts', () => {
  test('global investigation and org-scoped per-user export keep filter semantics aligned', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `audit-target-${suffix}@example.test`;
    const adminEmail = `platform-admin+audit-${suffix}@example.test`;
    const orgName = `Audit Org ${suffix}`;
    const orgSlug = `audit-org-${suffix}`;

    await registerUser(page, targetEmail, password);
    await createOrganization(page, orgName, orgSlug);
    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    await openUserDetail(page, targetEmail);

    const detailUrl = new URL(page.url());
    const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
    await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
    await confirmSudo(page, password);
    await waitForLiveViewReady(page);

    await page.getByRole('button', { name: 'Start impersonation' }).click();
    await expect(page).toHaveURL('/');

    await page.getByRole('button', { name: 'End impersonation' }).click();
    await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
    await waitForLiveViewReady(page);

    await page.goto('/admin/audit?action_prefix=admin.impersonation');
    await waitForLiveViewReady(page);
    await expect(page.getByRole('heading', { name: 'Audit' })).toBeVisible();
    await expect(page.getByText('Impersonation').first()).toBeVisible();
    await expect(page.getByText('acting as').first()).toBeVisible();

    const globalDownload = page.waitForEvent('download');
    await page.getByRole('link', { name: 'Export CSV' }).click();
    const globalCsv = await readDownload(await globalDownload);

    expect(globalCsv).toContain('impersonation_state');
    expect(globalCsv).toContain('admin.impersonation.start');
    expect(globalCsv).toContain(targetEmail);
    expect(globalCsv).toContain(adminEmail);

    await openUserDetail(page, targetEmail);
    await page.getByRole('link', { name: new RegExp(`Open organization-scoped view for ${orgName}`) }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(new RegExp(`/admin/organizations/${orgSlug}/users/[^/]+`));

    await page.getByRole('link', { name: 'View full audit' }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(new RegExp(`/admin/organizations/${orgSlug}/users/[^/]+/audit`));
    await expect(page.getByText(targetEmail).first()).toBeVisible();

    await page.fill('input[name="action_prefix"]', 'session');
    await page.getByRole('button', { name: 'Apply filters' }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/action_prefix=session/);
    await expect(page.getByText('session.create').first()).toBeVisible();

    const scopedDownload = page.waitForEvent('download');
    await page.getByRole('link', { name: 'Export CSV' }).click();
    const scopedCsv = await readDownload(await scopedDownload);

    expect(scopedCsv).toContain('session.create');
    expect(scopedCsv).toContain(targetEmail);
    expect(scopedCsv).toContain('organization_label');
  });
});
