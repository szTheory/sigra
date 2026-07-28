import { readFile } from 'node:fs/promises';
import { test, expect, type Download, type Page } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 31 Plan 2: canonical admin audit browser contract.
//
// Per D-01, D-02, D-04 (4), D-19, D-20, and D-26 this spec owns:
//   * /admin/audit filter + visible impersonation semantics
//   * /admin/audit/export.csv global CSV download
//   * /admin/organizations/:slug/users/:id/audit filter alignment + per-user
//     scoped CSV download
//
// Per D-06 this spec does NOT absorb the malformed-param, scope-safe export,
// audit attribution, or authorization-permutation matrices; those stay in
// ExUnit (test/sigra/admin/audit/query_test.exs,
// test/example/test/example_web/controllers/admin/audit_export_controller_test.exs).
// Download contents are asserted for semantic markers only — not exact
// file bodies — per the `admin-audit` download/assert pattern documented in
// `.planning/phases/31-automation-first-verification/31-PATTERNS.md`. Per
// D-27 this spec only runs on the `chromium` behavior-truth lane; curated
// audit explorer screenshots live in `tests/admin-checkpoints.spec.ts`.

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
  await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
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

test.describe('Phase 31 admin audit browser contract (D-04 4)', () => {
  test('global investigation and org-scoped per-user export keep filter semantics aligned', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
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

    await page.goto(`/organizations/${orgSlug}/members`);
    await waitForLiveViewReady(page);
    await expect(page.getByRole('button', { name: 'End impersonation' })).toBeVisible();
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
    // Scope to the visible desktop results pane (dual-DOM: desktop+mobile both in DOM;
    // unscoped .first() can resolve to the hidden mobile variant on chromium).
    const desktopResults = page.locator('[data-testid="admin-audit-user-desktop-results"]');
    await expect(desktopResults.getByText(targetEmail).first()).toBeVisible();

    // Phase 228 (v1.46): the advanced audit filters were flattened out of the
    // collapsed "More filters" <details> disclosure into the always-visible
    // sg-filter-panel form, so the Action prefix textbox is directly interactable.
    await page.getByRole('textbox', { name: 'Action prefix' }).fill('session');
    await page.getByRole('button', { name: 'Apply filters' }).click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/action_prefix=session/);
    // The raw action code 'session.create' lives inside a closed <details> disclosure
    // ('Event codes') and is therefore hidden. Assert the visible action_label pill
    // instead: 'session.create' → action_label = 'Session Create' (presenter.ex:43-47).
    await expect(desktopResults.locator('.sg-status-pill', { hasText: 'Session Create' }).first()).toBeVisible();

    const scopedDownload = page.waitForEvent('download');
    await page.getByRole('link', { name: 'Export CSV' }).click();
    const scopedCsv = await readDownload(await scopedDownload);

    expect(scopedCsv).toContain('session.create');
    expect(scopedCsv).toContain(targetEmail);
    // Assert the actual organization_label row content (not the header),
    // so the test notices an empty CSV body where `organization_label`
    // is a fixed column header that would otherwise pass tautologically.
    expect(scopedCsv).toContain(orgName);
  });
});
