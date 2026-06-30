import { statSync } from 'node:fs';
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page, type TestInfo } from '@playwright/test';
import { captureAdminCheckpoint } from '../helpers/adminArtifacts';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 31 Plan 2: curated admin checkpoint spec.
//
// Per D-04, D-19, D-20, D-25, D-26, D-27, D-28, D-29, and D-30 this spec
// captures the eight required reviewer pages as explicit screenshots so the
// Playwright HTML report becomes asynchronously reviewable on green runs
// without widening the behavior suite across every viewport/theme:
//
//   1. Global overview                                 (/admin)
//   2. Org overview                                    (/admin/organizations/:slug)
//   3. Global user index                               (/admin/users)
//   4. User detail                                     (/admin/users/:id)
//   5. Organization-scoped admin page                  (/admin/organizations/:slug/users)
//   6. Active impersonation banner on a non-admin
//      page (the impersonated user's org members view) (/organizations/:slug/members)
//   7. Per-user audit                                  (/admin/users/:id/audit)
//   8. Audit explorer                                  (/admin/audit?...)
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
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
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

/**
 * Capture a curated admin checkpoint AND assert the artifact was actually
 * written to disk and is non-empty. The assertion turns D-19/D-20 from an
 * implicit promise ("we call the helper") into an explicit contract
 * ("the reviewer artifact exists for every shipped checkpoint page"),
 * catching regressions in the helper, project partitioning, or Playwright
 * output plumbing before they ship as silently-missing attachments.
 */
async function captureAndVerify(
  page: Page,
  testInfo: TestInfo,
  name: string,
): Promise<void> {
  // Use viewport-only capture (fullPage: false) to avoid the 32767px hard limit
  // imposed by Playwright/Chrome on full-page screenshots. The global-user-index
  // checkpoint navigates to the unfiltered /admin/users list (100+ users), which
  // can exceed this limit on mobile. Viewport-only is sufficient for human review
  // artifacts — assertCheckpointScreenshot handles the baseline comparison
  // separately and also uses fullPage: false.
  const filePath = await captureAdminCheckpoint(page, testInfo, { name, fullPage: false });
  const stats = statSync(filePath);
  expect(
    stats.isFile(),
    `Expected curated checkpoint ${name} to land at ${filePath}`,
  ).toBe(true);
  expect(
    stats.size,
    `Expected curated checkpoint ${name} to be a non-empty PNG`,
  ).toBeGreaterThan(0);
}

/** Phase 35: axe a11y gate paired with each curated checkpoint capture. */
async function assertNoAxeViolations(page: Page, label: string) {
  // Scope to the full WCAG 2.1/2.2 AA tag set (EN 301 549 legal floor) so the
  // gate is literally defensible against modern accessibility standards (D-07).
  // The axe `best_practice` tag-group is intentionally excluded (D-09): rules
  // like `region` (full-page landmark wrapping) would fail on the admin shell's
  // `<header>` layout, which is intentional Phoenix/LiveView structure rather
  // than a shipped WCAG regression signal for this lane.
  //
  // D-08: `target-size` (wcag22aa/2.5.8) is suppressed because the admin
  // filter form uses intentionally dense sg-select and sg-bottom-nav controls
  // whose compact sizing is accepted by the admin-design-contract.md.
  // All other WCAG 2.2 AA rules remain active — this is a single-rule carve-out,
  // not a wholesale 2.2 tag drop.
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .disableRules(['target-size'])
    .analyze();
  const detail =
    violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}

/**
 * Phase 35: committed `toHaveScreenshot` baselines (5 checkpoints × 3 projects).
 * Snapshots live under `admin-checkpoints.spec.ts-snapshots/` (Playwright default).
 */
async function assertCheckpointScreenshot(page: Page, testInfo: TestInfo, slug: string) {
  await assertNoAxeViolations(page, `axe:${slug}`);
  // Name excludes project — Playwright appends project + platform to the file path.
  // Viewport-only: full-page captures vary in height run-to-run (audit rows,
  // LiveView hydration) and break baselines across CI vs local.
  const dark = testInfo.project.name.includes('dark');
  const mobile = testInfo.project.name.includes('mobile');
  // Baselines were captured on macOS desktop WebKit/Chromium; GitHub-hosted
  // Linux runners differ in font rasterization and sub-pixel layout. Keep
  // defaults locally; widen only where CI needs parity with frozen PNGs.
  const ci = process.env.CI === 'true';
  await expect(page).toHaveScreenshot(`${slug}.png`, {
    fullPage: false,
    maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
  });
}

test.describe('Phase 31 admin checkpoint inventory (D-28)', () => {
  test('captures curated admin review pages across desktop/mobile/dark', async ({
    page,
  }, testInfo) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
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

    // --- Checkpoint: Global overview (/admin) --------------------------------
    // Phase 157 LAND-01..04: front-door archetype with deferred load.
    // D-06 HARD REQUIREMENT: wait for loaded data (sg-metric__number visible),
    // not just .phx-connected — connected? gate defers queries to connected mount,
    // creating a brief window where .phx-connected is set but skeleton is still shown.
    // Note: admin overview uses summary_chip (.sg-metric__number), not metric_link.
    await page.goto('/admin');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-metric__number').first()).toBeVisible();
    await expect(page.locator('.sg-notice').first()).toBeVisible();
    await captureAndVerify(page, testInfo, 'global-overview');
    await assertCheckpointScreenshot(page, testInfo, 'global-overview');

    // --- Checkpoint: Org overview (/admin/organizations/:slug) ---------------
    // Phase 157 LAND-01..04: same front-door archetype, org scope.
    // Org route: redesigned OrganizationLive (not the "org landing stub" referenced
    // in CP3 comment — that was before Phase 157 created this baseline).
    await page.goto(`/admin/organizations/${orgSlug}`);
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-notice').first()).toBeVisible();
    await captureAndVerify(page, testInfo, 'org-overview');
    await assertCheckpointScreenshot(page, testInfo, 'org-overview');

    // --- Checkpoint 1: Global user index (/admin/users) --------------------
    // D-28: "global user index" — proves admin shell chrome, Global scope
    // label, dense list layout, and action visibility on the primary admin
    // entry page.
    //
    // INDEX-03 / D-08: Navigate to the unfiltered list so the multi-page
    // pagination <nav> is the captured state. A ?q= filter that resolves to a
    // single user would produce the single-page all_results_label instead of
    // the <nav> and fail to prove list-scale pagination (D-08).
    // The targetEmail row appears on page 1 (just registered, sorted DESC).
    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText('Global');
    await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
    // D-08: multi-page pagination <nav> must render (list-scale proof).
    // The nav uses class sg-cluster--between (no aria-label attribute); the prev/next
    // links inside it carry their own aria-labels.
    await expect(page.getByRole('link', { name: 'Next page' })).toBeVisible();
    await captureAndVerify(page, testInfo, 'global-user-index');
    await assertCheckpointScreenshot(page, testInfo, 'global-user-index');

    // --- Checkpoint 2: User detail (/admin/users/:id) ----------------------
    // D-28: "user detail" — proves identity bar, bounded session preview with
    // Manage sessions link-out, and Start impersonation visible. Revoke
    // session controls moved to UserSessionsLive (Plan 02 D-04); the detail
    // page is now a calm read-only identity surface with link-outs.
    await openUserDetail(page, targetEmail);
    await expect(page.getByText('Global user operations')).toBeVisible();
    await expect(
      page.getByRole('link', { name: 'Manage sessions' }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: 'Start impersonation' }),
    ).toBeVisible();
    await captureAndVerify(page, testInfo, 'user-detail');
    await assertCheckpointScreenshot(page, testInfo, 'user-detail');

    // --- Checkpoint: User sessions (/admin/users/:id/sessions) -------------
    // Phase 200 Plan 01: per-user session management surface with APG confirm
    // dialog (Revoke all sessions). Revoke flow moved here from user detail
    // (D-04). This checkpoint proves the sessions page renders with the
    // destructive Revoke all sessions control visible and correctly scoped.
    const userDetailUrl = new URL(page.url());
    const userIdMatch = userDetailUrl.pathname.match(/\/admin\/users\/([^/]+)/);
    const userId = userIdMatch ? userIdMatch[1] : '';
    await page.goto(`/admin/users/${userId}/sessions`);
    await waitForLiveViewReady(page);
    await expect(
      page.getByRole('button', { name: 'Revoke all sessions' }),
    ).toBeVisible();
    await captureAndVerify(page, testInfo, 'user-sessions');
    await assertCheckpointScreenshot(page, testInfo, 'user-sessions');

    // --- Checkpoint 3: Organization-scoped admin page ----------------------
    // D-28: "organization-scoped admin page" — proves the scope chrome
    // swaps from Global to the org name and the scoped admin list renders.
    // Use /admin/organizations/:slug/users so reviewers see a dense
    // data-rich org-scoped layout rather than the org landing stub.
    await page.goto(`/admin/organizations/${orgSlug}/users`);
    await waitForLiveViewReady(page);
    await expect(page.locator('header').first()).toContainText('Admin');
    await expect(page.locator('header').first()).toContainText(orgName);
    await captureAndVerify(page, testInfo, 'org-scoped-admin');
    await assertCheckpointScreenshot(page, testInfo, 'org-scoped-admin');

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
    await captureAndVerify(page, testInfo, 'impersonation-banner');
    await assertCheckpointScreenshot(page, testInfo, 'impersonation-banner');

    // Stop impersonation before the audit checkpoint so the audit page
    // renders from the admin session (not the impersonated user) and
    // reflects the banner-free admin chrome reviewers expect on the
    // explorer.
    await page.getByRole('button', { name: 'End impersonation' }).click();
    await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
    await waitForLiveViewReady(page);

    // --- Checkpoint 6: Per-user audit (/admin/users/:id/audit) -------------
    // Phase 158 GATE-01: per-user audit surface with mobile card layout
    // (AUDX-01) and loaded-row wait (D-06 HARD REQUIREMENT).
    // Navigate using the detailPath captured above — same targetEmail user
    // who has admin.impersonation rows from the impersonation START/STOP
    // above, so zero new seed is needed.
    const userAuditPath = detailPath.replace(/\?.*$/, '') + '/audit';
    await page.goto(userAuditPath);
    await waitForLiveViewReady(page);
    // Self-justifying capture (Phase 158): the screenshot is a by-product of
    // asserted-correct, tone-mapped DOM — not something a human must bless.
    // Shared lib-owned chrome present on every project:
    await expect(page.getByText('Global audit explorer')).toBeVisible(); // scope_ribbon/1
    // D-06 HARD-FAIL + tone proof: assert a VISIBLE loaded impersonation row
    // carrying data-tone="info" (the exact tone the ExUnit golden pins), in the
    // project-appropriate layout — NOT just .phx-connected. This user was
    // impersonated immediately above, so admin.impersonation.* rows exist.
    const isMobileProject = testInfo.project.name.includes('mobile');
    if (isMobileProject) {
      const mobileResults = page.locator('[data-testid="admin-audit-user-mobile-results"]');
      await expect(mobileResults).toBeVisible();
      await expect(
        page.locator('[data-testid="admin-audit-user-desktop-results"]'),
      ).toBeHidden();
      await expect(
        mobileResults.locator('article[data-tone="info"]').first(),
      ).toBeVisible();
    } else {
      const desktopResults = page.locator('[data-testid="admin-audit-user-desktop-results"]');
      await expect(desktopResults).toBeVisible();
      await expect(
        page.locator('[data-testid="admin-audit-user-mobile-results"]'),
      ).toBeHidden();
      await expect(
        desktopResults.locator('tbody tr[data-tone="info"]').first(),
      ).toBeVisible();
    }
    await captureAndVerify(page, testInfo, 'user-audit');
    await assertCheckpointScreenshot(page, testInfo, 'user-audit');

    // --- Checkpoint 8: Audit explorer (/admin/audit) -----------------------
    // D-28: "audit explorer" — proves filter/export usability and
    // impersonation attribution on the primary investigation surface.
    await page.goto('/admin/audit?action_prefix=admin.impersonation');
    await waitForLiveViewReady(page);
    await expect(page.getByRole('heading', { name: 'Audit' })).toBeVisible();
    await expect(page.getByText('Global audit explorer')).toBeVisible(); // scope_ribbon/1
    // Self-justifying capture (Phase 158 AUDX-02 / D-05): encode the intended
    // delta — the all-viewport quick-filter chip row — as positive assertions on
    // the chips' real name/value, so the new baseline reflects asserted-correct DOM.
    const failuresChip = page.locator(
      'label.sg-filter-chip:has(input[name="outcome"][value="failure"])',
    );
    await expect(failuresChip).toBeVisible();
    await expect(failuresChip).toContainText('Failures');
    const impersonationChip = page.locator(
      'label.sg-filter-chip:has(input[name="action_prefix"][value="admin.impersonation"])',
    );
    await expect(impersonationChip).toBeVisible();
    await expect(impersonationChip).toContainText('Impersonation');
    // This view was opened with ?action_prefix=admin.impersonation, so it is checked.
    await expect(impersonationChip.locator('input')).toBeChecked();
    await expect(page.getByRole('link', { name: 'Export CSV' })).toBeVisible();
    // Per-project layout: the dual-layout swap is the other half of the intended delta.
    const isMobileExplorer = testInfo.project.name.includes('mobile');
    if (isMobileExplorer) {
      await expect(page.locator('[data-testid="admin-audit-mobile-results"]')).toBeVisible();
      await expect(page.locator('[data-testid="admin-audit-desktop-results"]')).toBeHidden();
    } else {
      await expect(page.locator('[data-testid="admin-audit-desktop-results"]')).toBeVisible();
      await expect(page.locator('[data-testid="admin-audit-mobile-results"]')).toBeHidden();
    }
    await captureAndVerify(page, testInfo, 'audit-explorer');
    await assertCheckpointScreenshot(page, testInfo, 'audit-explorer');
  });
});
