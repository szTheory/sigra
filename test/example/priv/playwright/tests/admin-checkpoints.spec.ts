import { test, expect, type Page } from '@playwright/test';
import { captureAdminCheckpoint } from '../helpers/adminArtifacts';

// Phase 31 Plan 2: curated admin checkpoint spec.
//
// Per D-04, D-19, D-20, D-25, D-26, D-27, D-28, D-29, and D-30 this spec
// captures the five required reviewer pages as explicit screenshots so the
// Playwright HTML report becomes asynchronously reviewable on green runs
// without widening the behavior suite across every viewport/theme:
//
//   1. Global user index                               (/admin/users)
//   2. User detail                                     (/admin/users/:id)
//   3. Organization-scoped admin page                  (/admin/organizations/:slug)
//   4. Active impersonation banner on a non-admin
//      page (the impersonated user's org members view) (/organizations/:slug/members)
//   5. Audit explorer                                  (/admin/audit?...)
//
// This spec runs in exactly three partitioned projects configured by
// `playwright.config.ts` (D-27, D-29):
//
//   * admin-checkpoints-chromium — desktop reviewer artifacts
//   * admin-checkpoints-mobile   — mobile reviewer artifacts (iPhone 13 device)
//   * admin-checkpoints-dark     — dark-mode reviewer artifacts
//
// Per D-25 and D-30 we attach explicit screenshots through
// `captureAdminCheckpoint(...)` — we do NOT adopt a full visual-baseline
// regime and we do NOT retain whole-run raw Playwright output
// indiscriminately. Per D-06 this spec does NOT assert denial /
// forbidden / malformed-param / authorization-permutation paths; those
// remain in ExUnit and targeted HTTP smoke.
//
// LiveView + longpoll means each navigation is relatively slow; we keep the
// spec to a single test per project so fixtures are seeded once and the five
// pages are captured in one authenticated journey.

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
  await expect(
    page.locator('#admin-users-mobile-results').getByText(targetEmail).first(),
  ).toBeVisible();
  await page.getByRole('link', { name: 'Open user' }).first().click();
  await waitForLiveViewReady(page);
  await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
}

async function confirmSudo(page: Page, password: string) {
  await expect(page).toHaveURL(/\/users\/sudo\?/);
  await page.fill('input[name="sudo[password]"]', password);
  await page.getByRole('button', { name: 'Confirm password' }).click();
}

test.describe('Phase 31 admin checkpoint inventory (D-28)', () => {
  test('captures curated admin review pages across desktop/mobile/dark', async ({
    page,
  }, testInfo) => {
    const suffix = Date.now();
    const password = 'CorrectHorseBatteryStaple123!';
    const targetEmail = `checkpoint-target-${suffix}@example.test`;
    // Example.SigraAdminPolicy grants platform-admin to users whose email
    // starts with the `platform-admin+` prefix — match that convention so
    // the admin routes below render for this session.
    const adminEmail = `platform-admin+checkpoint-${suffix}@example.test`;
    const orgName = `Checkpoint Org ${suffix}`;
    const orgSlug = `checkpoint-org-${suffix}`;

    // --- Seed reviewer fixtures -------------------------------------------
    // 1. Target user who will own an organization and later be impersonated.
    await registerUser(page, targetEmail, password);
    await createOrganization(page, orgName, orgSlug);

    // 2. Fresh admin session (so the admin header / scope chrome reflects
    //    the platform admin, not the target).
    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    // --- Checkpoint 1: Global user index (/admin/users) --------------------
    // D-28: "global user index" — proves admin shell chrome, Global scope
    // label, dense list layout, and action visibility on the primary admin
    // entry page.
    await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText('Global');
    await expect(
      page.locator('#admin-users-mobile-results').getByText(targetEmail).first(),
    ).toBeVisible();
    await captureAdminCheckpoint(page, testInfo, {
      name: 'global-user-index',
    });

    // --- Checkpoint 2: User detail (/admin/users/:id) ----------------------
    // D-28: "user detail" — proves action context (revoke / start
    // impersonation) and the pivot link for org-scoped views are visible
    // on the same page reviewers inspect for support actions.
    await openUserDetail(page, targetEmail);
    await expect(page.getByText('Global user operations')).toBeVisible();
    await expect(
      page.getByRole('button', { name: 'Revoke session' }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: 'Start impersonation' }),
    ).toBeVisible();
    await captureAdminCheckpoint(page, testInfo, {
      name: 'user-detail',
    });

    // --- Checkpoint 3: Organization-scoped admin page ----------------------
    // D-28: "organization-scoped admin page" — proves the scope chrome
    // swaps from Global to the org name and the scoped admin list renders.
    // Use /admin/organizations/:slug/users so reviewers see a dense
    // data-rich org-scoped layout rather than the org landing stub.
    await page.goto(`/admin/organizations/${orgSlug}/users`);
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText(orgName);
    await captureAdminCheckpoint(page, testInfo, {
      name: 'org-scoped-admin',
    });

    // --- Impersonate so the banner checkpoint has real state to render ----
    await openUserDetail(page, targetEmail);
    const detailUrl = new URL(page.url());
    const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
    await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
    await confirmSudo(page, password);
    await waitForLiveViewReady(page);
    await page.getByRole('button', { name: 'Start impersonation' }).click();
    await expect(page).toHaveURL('/');

    // --- Checkpoint 4: Active impersonation banner on a non-admin page ----
    // D-28: "active impersonation state on a non-admin or org-scoped page"
    // — proves the impersonation banner persists as the admin navigates
    // outside /admin (here, into an organization members page the
    // impersonated user owns).
    await page.goto(`/organizations/${orgSlug}/members`);
    await waitForLiveViewReady(page);
    const banner = page.locator('section').filter({ hasText: 'Impersonating' }).first();
    await expect(banner).toContainText(`Impersonating ${targetEmail}`);
    await expect(banner).toContainText(`Signed in as ${adminEmail}`);
    await expect(
      banner.getByRole('button', { name: 'End impersonation' }),
    ).toBeVisible();
    await captureAdminCheckpoint(page, testInfo, {
      name: 'impersonation-banner',
    });

    // Stop impersonation before the audit checkpoint so the audit page
    // renders from the admin session (not the impersonated user) and
    // reflects the banner-free admin chrome reviewers expect on the
    // explorer.
    await page.getByRole('button', { name: 'End impersonation' }).click();
    await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
    await waitForLiveViewReady(page);

    // --- Checkpoint 5: Audit explorer (/admin/audit) -----------------------
    // D-28: "audit explorer" — proves filter/export usability and
    // impersonation attribution on the primary investigation surface.
    await page.goto('/admin/audit?action_prefix=admin.impersonation');
    await waitForLiveViewReady(page);
    await expect(page.getByRole('heading', { name: 'Audit' })).toBeVisible();
    await expect(page.getByText('Impersonation').first()).toBeVisible();
    await expect(page.getByRole('link', { name: 'Export CSV' })).toBeVisible();
    await captureAdminCheckpoint(page, testInfo, {
      name: 'audit-explorer',
    });
  });
});
