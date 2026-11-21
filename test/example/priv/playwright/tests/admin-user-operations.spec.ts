import { test, expect, type Page } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';
import {
  assertGenericRegistrationResponse,
  signInManually,
} from '../helpers/registration';

// Phase 31 Plan 2: canonical admin user-operations browser contract.
//
// Per D-01, D-02, D-04 (1) and (2), D-19, D-20, and D-26 this spec owns:
//   * /admin/users search + filter
//   * /admin/users/:id detail -> "Manage sessions" link-out -> revoke on
//     /admin/users/:id/sessions (Phase 200 D-04; scope remains visible)
//   * global -> organization-scoped pivot (org scope remains explicit)
//
// Per D-06 this spec does NOT absorb the denied-mutation / malformed-param /
// authorization-permutation matrix; those stay in ExUnit (D-07, D-13, D-14,
// D-15). Per D-27 this spec only runs on the `chromium` behavior-truth lane;
// mobile and dark-mode coverage for the same pages lives in
// `tests/admin-checkpoints.spec.ts`.

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
  await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await assertGenericRegistrationResponse(page);
  await signInManually(page, email, password);
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
  // Org scope renders a tenant-marked chip ("Org · {name}"); global stays "Global".
  // Substring match keeps the scope label assertion robust to that prefix/glyph.
  await expect(header.getByText(scopeLabel, { exact: false }).first()).toBeVisible();
}

test.describe('Phase 31 admin user operations browser contract (D-04 1/2)', () => {
  test('@smoke search -> filter -> open user -> revoke session keeps scope visible', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
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
    await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
    await expect(page.getByRole('link', { name: 'Open user' }).first()).toBeVisible();

    await page.getByRole('link', { name: 'Open user' }).first().click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    await expect(page.getByText('Global user operations')).toBeVisible();
    // User detail uses breadcrumbs (not a "Back to users" link) for filtered-list
    // context; the "Users" crumb carries the preserved return_to. See admin-theme.spec.ts.
    const breadcrumb = page.getByRole('navigation', { name: 'Breadcrumb' });
    await expect(breadcrumb.getByRole('link', { name: 'Users' })).toHaveAttribute(
      'href',
      /return_to|\/admin\/users\?/,
    );

    // Phase 200 (D-04): the revoke flow moved off the detail page onto
    // UserSessionsLive at /admin/users/:id/sessions. The detail page is now a
    // calm read-only identity surface that links out via "Manage sessions";
    // assert the link, then drive the revoke journey on the sessions page.
    const manageSessions = page.getByRole('link', { name: 'Manage sessions' });
    await expect(manageSessions).toBeVisible();
    await manageSessions.click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^/]+\/sessions/);
    // Scope stays visible across the link-out.
    await expect(page.getByText('Global user operations')).toBeVisible();

    // Target user can show >1 active session (e.g. registration + reconnect). Revoke each:
    // strict mode forbids ambiguous `getByRole` clicks, and a single revoke must not assume
    // the list is empty afterward.
    const revokeSession = page.getByRole('button', { name: 'Revoke session' });
    const confirmPrompt = page.getByText(
      `${targetEmail} will be signed out of this browser or device immediately and must sign in again.`,
    );
    // Keep the action-specific confirmation separate from the per-row trigger.
    const confirmButton = page
      .locator('#user-session-confirm-overlay')
      .getByRole('button', { name: 'Revoke session', exact: true });

    while ((await revokeSession.count()) > 0) {
      const before = await revokeSession.count();
      await revokeSession.first().click();
      await expect(confirmPrompt).toBeVisible();
      await confirmButton.click();
      await expect(page.getByText('Session revoked.')).toBeVisible();
      await expect(revokeSession).toHaveCount(before - 1);
    }

    // Empty-state title (lib user_sessions_live.ex: `title="No active sessions"`).
    // Use exact: true to avoid substring match on the inner slot text
    // ("This user has no active sessions in the current scope.") which would
    // trip Playwright strict mode (2 elements matched).
    await expect(page.getByText('No active sessions', { exact: true })).toBeVisible();
    await expectScopeChrome(page, 'Global');
  });

  test('global admins can pivot from user detail into an organization-scoped view', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
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

test.describe('Phase 262 4a long-content support fixture', () => {
  const fixtureSuffix = Date.now().toString(36);
  const longEmail = `support-long-content-review-review-review-${fixtureSuffix}@example.test`;
  const longOrganizationName =
    `Support organization for operator teams across regions ${fixtureSuffix}`;
  const organizationSlug = longOrganizationName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
  const adminEmail = `platform-admin+support-long-content-${fixtureSuffix}@example.test`;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const setupPage = await context.newPage();

    try {
      await registerUser(setupPage, longEmail, TEST_PASSWORD);
      await createOrganization(setupPage, longOrganizationName, organizationSlug);

      await setupPage.goto('/users/settings');
      await waitForLiveViewReady(setupPage);
      setupPage.once('dialog', (dialog) => dialog.accept());
      await setupPage.getByRole('button', { name: 'Delete my account' }).click();
      await expect(
        setupPage.getByTestId('settings-delete').locator('.vt-alert'),
      ).toContainText(/Your account is scheduled for deletion on/);

      await context.clearCookies();
      await registerUser(setupPage, adminEmail, TEST_PASSWORD);
    } finally {
      await context.close();
    }
  });

  async function openSupportUser(page: Page) {
    await logInIfNeeded(page, adminEmail, TEST_PASSWORD);
    await page.goto(`/admin/users?q=${encodeURIComponent(longEmail)}`);
    await waitForLiveViewReady(page);
  }

  test('4a support long-content overflow', async ({ page }) => {
    await openSupportUser(page);

    const row = page.getByRole('row').filter({ hasText: longEmail });
    await expect(row).toHaveCount(1);
    await expect(row.getByTitle(longEmail)).toBeVisible();
    await expect(row.getByTitle(longOrganizationName)).toBeVisible();
    await expect(row.locator('[data-status="deleting"]')).toContainText('Deletion scheduled');

    const openUser = row.getByRole('link', { name: 'Open user' });
    await expect(openUser).toBeVisible();

    const rowContentFits = await row.evaluate((element) => {
      const rowBounds = element.getBoundingClientRect();
      const content = element.querySelectorAll('.sg-truncate, .sg-status-mark, .sg-btn');
      return Array.from(content).every((child) => {
        const bounds = child.getBoundingClientRect();
        return bounds.left >= rowBounds.left - 1 && bounds.right <= rowBounds.right + 1;
      });
    });
    expect(rowContentFits, 'identity, organization, status, and action stay within the row').toBe(true);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });

  test('4a support 320px/200% reflow', async ({ page }) => {
    await openSupportUser(page);
    // A 320 CSS-pixel viewport is the 200% zoom reflow target for a 640px desktop viewport.
    await page.setViewportSize({ width: 320, height: 900 });

    const results = page.getByTestId('admin-users-mobile-results');
    await expect(results).toBeVisible();
    const card = results.locator('article').filter({ hasText: longEmail });
    await expect(card).toHaveCount(1);
    await expect(card.getByTitle(longEmail)).toBeVisible();
    await expect(card.getByText('Organizations', { exact: true })).toBeVisible();
    await expect(card.getByTitle(longOrganizationName)).toBeVisible();
    await expect(card.locator('[data-status="deleting"]')).toContainText('Deletion scheduled');

    const openUser = card.getByRole('link', { name: 'Open user' });
    await expect(openUser).toBeVisible();
    const cardOverflow = await card.evaluate((element) => {
      const cardBounds = element.getBoundingClientRect();
      const content = element.querySelectorAll('.sg-truncate, .sg-status-mark, .sg-btn');
      return Array.from(content).flatMap((child) => {
        const bounds = child.getBoundingClientRect();
        if (bounds.left >= cardBounds.left - 1 && bounds.right <= cardBounds.right + 1) return [];
        return [
          {
            className: child.className,
            text: child.textContent?.trim(),
            left: bounds.left,
            right: bounds.right,
            cardLeft: cardBounds.left,
            cardRight: cardBounds.right,
          },
        ];
      });
    });
    expect(
      cardOverflow,
      'identity, organization, status, and action stay within the card: ' + JSON.stringify(cardOverflow),
    ).toEqual([]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

    await openUser.focus();
    await expect(openUser).toBeFocused();
    await page.keyboard.press('Enter');
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    await expect(
      page.getByRole('heading', { level: 1, name: longEmail, exact: true }),
    ).toBeVisible();
    await expect(page.getByText(longOrganizationName, { exact: true })).toBeVisible();
    await expect(page.locator('[data-status="deleting"]')).toContainText('Deletion scheduled');
  });
});
