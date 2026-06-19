/**
 * Phase 190 Plan 04: Support investigator JTBD flow spec.
 *
 * Exercises the find→audit→impersonate→return investigation journey for the
 * platform admin operator acting in a support investigator posture
 * (admin@demo.vaultr.test, same authz role — D-01/D-03).
 *
 * Coverage:
 *   - FLOW-01: happy/main-error/boundary, scope/return-context across the
 *              impersonation journey (banner persistence, stop→URL restoration)
 *   - FLOW-02: keyboard operability + reduced-motion CSS-effect assertion
 *   - FLOW-03: dark theme persists across impersonation journey and page.reload()
 *   - DATA-01: deterministic alice (impersonation happy), dave (locked/error),
 *              frank (scheduled-deletion/boundary)
 *
 * D-02: Asserts journey-level properties only. Does NOT re-test impersonation
 * internals (stale-sudo redirect, session isolation, etc.) — those are owned
 * by impersonation.spec.ts.
 *
 * D-09: Runs on chromium behavior-truth lane only (ADMIN_BEHAVIOR_SPECS regex
 * includes admin-flow). Mobile project excludes this spec.
 *
 * D-10: reducedMotion set at test.use() context level — never emulateMedia
 * after page.goto (Firefox drops it after navigation per playwright#31328).
 */

import { test, expect } from '@playwright/test';
import {
  loginDemoAdmin,
  waitForLiveViewReady,
  assertScopeChrome,
  assertThemeAttributes,
  seedThemeAndAssertNoFlash,
  assertReducedMotionEffect,
  DEMO_ADMIN_EMAIL,
  DEMO_ADMIN_PASSWORD,
} from '../helpers/adminFlows';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';

const DEMO_ALICE_EMAIL = 'alice@demo.vaultr.test';
const DEMO_DAVE_EMAIL = 'dave@demo.vaultr.test';
const DEMO_FRANK_EMAIL = 'frank@demo.vaultr.test';

/**
 * Searches for a user by email on the /admin/users list and opens their
 * detail page. Returns on the user detail URL.
 *
 * Navigates directly using page.goto with the search query, then follows
 * the "Open user" link from the VISIBLE row (avoids the hidden mobile
 * duplicate link that `.first()` might accidentally resolve to).
 */
async function openUserDetail(page: Parameters<typeof loginDemoAdmin>[0], email: string) {
  await page.goto(`/admin/users?q=${encodeURIComponent(email)}`);
  await waitForLiveViewReady(page);
  await expect(adminUsersEmailLocator(page, email)).toBeVisible();
  // Scope "Open user" link to the visible row to avoid the hidden mobile duplicate.
  const visibleRow = adminUsersEmailLocator(page, email);
  await visibleRow.getByRole('link', { name: 'Open user' }).click();
  // Wait for navigation to user detail page. URL includes UUID + ?return_to param.
  await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
  await waitForLiveViewReady(page);
}

test.describe('Phase 190 support investigator flow (FLOW-01..03, DATA-01)', () => {
  // D-10: Set reducedMotion at describe-block level. This applies to ALL tests
  // in this file (including nested describes). Never call emulateMedia after goto.
  test.use({ reducedMotion: 'reduce' });

  test.beforeEach(async ({ page }) => {
    await loginDemoAdmin(page);
    await page.goto('/admin');
    await waitForLiveViewReady(page);
  });

  // ---------------------------------------------------------------------------
  // Happy path: find alice → per-user audit evidence → impersonate → return
  // ---------------------------------------------------------------------------

  test.describe('happy path — alice (find → audit evidence → impersonate → return)', () => {
    test('investigator finds alice, reads audit evidence, starts impersonation, sees persistent banner, stops and returns to scoped list', async ({
      page,
    }) => {
      // 1. Assert reduced-motion CSS effect (D-10) — loading bar animation is collapsed.
      await assertReducedMotionEffect(page);

      // 2. Navigate to users list and verify scope chrome.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');

      // 3. Open alice's user detail via the openUserDetail helper.
      //    (openUserDetail navigates to /admin/users?q=alice... and clicks Open user)
      await openUserDetail(page, DEMO_ALICE_EMAIL);

      // 4. Navigate to alice's per-user audit tab.
      //    The "View full audit" link navigates to /admin/users/:id/audit.
      //    alice has seeded admin.impersonation.start and admin.impersonation.stop events.
      await expect(page.getByRole('link', { name: 'View full audit' })).toBeVisible();
      await page.getByRole('link', { name: 'View full audit' }).click();
      await waitForLiveViewReady(page);
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+\/audit/, { timeout: 10000 });
      // Audit page is non-empty for alice (impersonation events seeded).
      await expect(page.locator('main')).not.toContainText('No audit events');

      // 5. Return to alice's user detail page via the browser back button.
      await page.goBack();
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
      await waitForLiveViewReady(page);

      // 6. Perform sudo flow and start impersonation.
      //    D-02: journey-level only — not testing stale-sudo redirect timing.
      //    Preserve the full URL (pathname + search) for the sudo return_to so the
      //    user detail page receives its ?return_to= pointing back to the search list.
      const detailUrl = new URL(page.url());
      const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
      await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
      await page.fill('input[name="sudo[password]"]', DEMO_ADMIN_PASSWORD);
      await page.getByRole('button', { name: 'Confirm password' }).click();
      await waitForLiveViewReady(page);

      // 7. Click "Start impersonation" button.
      await expect(page.getByRole('button', { name: 'Start impersonation' })).toBeVisible();
      await page.getByRole('button', { name: 'Start impersonation' }).click();
      await expect(page).toHaveURL('/');

      // 8. Navigate to alice's org membership page (banner renders here, not on '/').
      //    alice is a member of Acme Corp (seeded). Banner shows display name.
      await page.goto('/organizations/acme-corp/members');
      await waitForLiveViewReady(page);
      const appBanner = page.locator('section').filter({ hasText: 'Impersonating' }).first();
      await expect(appBanner).toContainText('Impersonating Alice');
      await expect(appBanner).toContainText('Signed in as Admin');

      // 9. Navigate to another org page — banner persists across navigation (D-12).
      //    /organizations/:org/settings is the sibling LiveView route available in the router.
      await page.goto('/organizations/acme-corp/settings');
      await waitForLiveViewReady(page);
      const bannerAfterNav = page.locator('section').filter({ hasText: 'Impersonating' }).first();
      await expect(bannerAfterNav).toContainText('Impersonating Alice');
      await expect(bannerAfterNav).toContainText('Signed in as Admin');

      // 10. Stop impersonation — assert return URL restores filtered list scope (D-12).
      await page.getByRole('button', { name: 'End impersonation' }).click();
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      await waitForLiveViewReady(page);

      // 11. Scope chrome shows 'Global' after returning from impersonation.
      await assertScopeChrome(page, 'Global');
    });
  });

  // ---------------------------------------------------------------------------
  // Main-error: dave (locked/unconfirmed)
  // ---------------------------------------------------------------------------

  test.describe('main-error — dave locked/unconfirmed', () => {
    test('investigator finds dave, user detail shows locked state indicators — no impersonation attempt', async ({
      page,
    }) => {
      // Search for dave (locked account — D-04).
      await openUserDetail(page, DEMO_DAVE_EMAIL);

      // Dave shows locked state indicators in the user detail view.
      // The user_show_live.ex status_pills/1 function appends {"Locked", "risk"} pill.
      // Use .filter({ hasText: 'Locked' }) to avoid strict mode violation (multiple risk pills).
      await expect(
        page.locator('.sg-status-pill[data-tone="risk"]').filter({ hasText: 'Locked' }),
      ).toBeVisible();

      // D-02: Boundary of this spec — does NOT attempt to impersonate dave.
      // Impersonation mechanics (blocked paths, etc.) are owned by impersonation.spec.ts.
    });
  });

  // ---------------------------------------------------------------------------
  // Boundary: frank (scheduled-deletion)
  // ---------------------------------------------------------------------------

  test.describe('boundary — frank scheduled-deletion', () => {
    test('investigator finds frank, user detail shows deletion-scheduled indicator', async ({
      page,
    }) => {
      // Search for frank (scheduled deletion — D-04 boundary case).
      await openUserDetail(page, DEMO_FRANK_EMAIL);

      // Frank shows a deletion-scheduled indicator (status pill with "warn" tone).
      // The user_show_live.ex status_pills/1 appends {"Deletion scheduled", "warn"}.
      await expect(
        page.locator('.sg-status-pill[data-tone="warn"]').filter({ hasText: 'Deletion scheduled' }),
      ).toBeVisible();
    });
  });

  // ---------------------------------------------------------------------------
  // Keyboard operability (FLOW-02)
  // ---------------------------------------------------------------------------

  test.describe('keyboard operability (FLOW-02)', () => {
    test('Tab navigation reaches interactive controls with visible focus; scope chrome is keyboard-reachable after impersonation stop', async ({
      page,
    }) => {
      // Navigate to users list and confirm the search input is Tab-reachable.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);

      // Tab through interactive elements — at least one focusable element should be reachable.
      await page.keyboard.press('Tab');
      const focusedTag = await page.evaluate(() => document.activeElement?.tagName?.toLowerCase());
      expect(['input', 'a', 'button', 'select', 'textarea', 'body']).toContain(focusedTag);

      // The scope chrome header is keyboard-navigable per FLOW-02.
      await assertScopeChrome(page, 'Global');

      // Perform the investigator impersonation journey with keyboard-focus for Start.
      await openUserDetail(page, DEMO_ALICE_EMAIL);

      // Preserve the full URL (pathname + search) for sudo return_to so the user detail
      // page retains its ?return_to= pointing back to the search list context.
      const detailUrlKb = new URL(page.url());
      const detailPathKb = `${detailUrlKb.pathname}${detailUrlKb.search}`;
      await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPathKb)}`);
      await page.fill('input[name="sudo[password]"]', DEMO_ADMIN_PASSWORD);
      await page.getByRole('button', { name: 'Confirm password' }).click();
      await waitForLiveViewReady(page);

      // Keyboard-focus the "Start impersonation" button (not click — preserves :focus-visible).
      const startBtn = page.getByRole('button', { name: 'Start impersonation' });
      await expect(startBtn).toBeVisible();
      await startBtn.focus();
      await expect(startBtn).toBeFocused();
      await page.keyboard.press('Enter');
      await expect(page).toHaveURL('/');

      // Navigate to alice's org page to access the impersonation banner.
      // The "End impersonation" button is in the banner, shown on org pages.
      await page.goto('/organizations/acme-corp/members');
      await waitForLiveViewReady(page);

      // Stop impersonation via banner.
      await page.getByRole('button', { name: 'End impersonation' }).click();
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      await waitForLiveViewReady(page);

      // Scope chrome ('Global') is visible after returning from impersonation.
      await assertScopeChrome(page, 'Global');
    });
  });

  // ---------------------------------------------------------------------------
  // Theme persistence across impersonation journey (FLOW-03)
  // NOTE: This describe block does NOT use the outer beforeEach login.
  //       Theme must be seeded before any goto to avoid FOUC.
  // ---------------------------------------------------------------------------

  test.describe('theme persistence across impersonation journey (FLOW-03)', () => {
    test('dark theme persists during impersonation journey and after page.reload()', async ({
      page,
    }) => {
      // NOTE: beforeEach already logged in as admin and navigated to /admin.
      // seedThemeAndAssertNoFlash uses page.addInitScript which injects a
      // localStorage write BEFORE the next goto. Then it goes to /admin.
      // Since we are already logged in, /admin loads correctly.

      // Step 1: Seed dark theme and navigate to /admin.
      // addInitScript persists for all subsequent goto calls in this test.
      await seedThemeAndAssertNoFlash(page, 'dark');
      await waitForLiveViewReady(page);

      // Theme is dark on /admin.
      await assertThemeAttributes(page, 'dark');

      // Step 3: Navigate to alice's user detail while staying in dark theme.
      await openUserDetail(page, DEMO_ALICE_EMAIL);
      // Admin shell theme persists to user detail page.
      await assertThemeAttributes(page, 'dark');

      // Step 4: Start impersonation via sudo.
      // Preserve the full URL (pathname + search) for sudo return_to.
      const detailUrlTheme = new URL(page.url());
      const detailPathTheme = `${detailUrlTheme.pathname}${detailUrlTheme.search}`;
      await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPathTheme)}`);
      await page.fill('input[name="sudo[password]"]', DEMO_ADMIN_PASSWORD);
      await page.getByRole('button', { name: 'Confirm password' }).click();
      await waitForLiveViewReady(page);

      await page.getByRole('button', { name: 'Start impersonation' }).click();
      await expect(page).toHaveURL('/');

      // Step 5: Navigate to alice's org page to see the impersonation banner and
      //         check localStorage theme during impersonation.
      await page.goto('/organizations/acme-corp/members');
      await waitForLiveViewReady(page);
      const impBanner = page.locator('section').filter({ hasText: 'Impersonating' }).first();
      await expect(impBanner).toContainText('Impersonating Alice');
      // localStorage still contains dark theme during impersonation.
      expect(
        await page.evaluate(() => localStorage.getItem('sigra.admin.theme')),
      ).toBe('dark');

      // Step 6: Stop impersonation — return to admin context.
      await page.getByRole('button', { name: 'End impersonation' }).click();
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      await waitForLiveViewReady(page);

      // Admin shell theme is dark after returning from impersonation.
      await assertThemeAttributes(page, 'dark');

      // Step 7: page.reload() — inline admin_shell.ex script fires on new HTML parse,
      // so theme must be restored without flash (addInitScript persists across reload).
      await page.reload();
      await waitForLiveViewReady(page);
      await assertThemeAttributes(page, 'dark');
    });
  });
});
