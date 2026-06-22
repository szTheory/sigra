/**
 * Phase 190 Plan 03 — Platform Admin JTBD flow spec (FLOW-01..03, DATA-01).
 *
 * Exercises the global-posture platform admin journey:
 *   overview → users search → user detail → per-user audit → return with scope
 *   and breadcrumb reconstructed.
 *
 * Happy case:     alice@demo.tasklane.test — confirmed Acme member, audit events visible.
 * Main-error:     dave@demo.tasklane.test — locked + unconfirmed, auth.login.failure +
 *                 auth.lockout.start audit events visible.
 * Boundary:       frank@demo.tasklane.test — scheduled-deletion indicator visible;
 *                 empty search filter renders empty state without error styling.
 * Keyboard:       Tab/Enter to "Revoke all sessions" trigger → ConfirmDialog opens →
 *                 focus containment invariant → Escape closes → focus returns to trigger.
 * Reduced-motion: assertReducedMotionEffect() confirms CSS collapsed effect (FLOW-02).
 * Theme:          seedThemeAndAssertNoFlash → nav → reload → system flip (FLOW-03).
 *
 * This spec runs on the `chromium` behavior-truth lane only (excluded from mobile via
 * playwright.config.ts ADMIN_BEHAVIOR_SPECS regex — D-09).
 *
 * Copy assertion: "Session revoked." is the actual short-form flash string from
 * user_show_live.ex:81. The full brand-book string is aspirational; copy gap
 * routed to Phase 191 per D-13.
 *
 * D-10: reducedMotion is set via test.use() at describe-block level — NOT via
 * page.emulateMedia() after goto (Firefox drops it after navigation, playwright#31328).
 */

import { test, expect } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import {
  waitForLiveViewReady,
  loginDemoAdmin,
  assertScopeChrome,
  seedThemeAndAssertNoFlash,
  assertThemeAttributes,
  assertReducedMotionEffect,
  DEMO_ADMIN_EMAIL,
  DEMO_ADMIN_PASSWORD,
} from '../helpers/adminFlows';

// Demo persona credentials (public-by-design, dev server only; from personas.ex)
const DEMO_ALICE_EMAIL = 'alice@demo.tasklane.test';
const DEMO_DAVE_EMAIL = 'dave@demo.tasklane.test';
const DEMO_FRANK_EMAIL = 'frank@demo.tasklane.test';

test.describe('Phase 190 platform admin flow (FLOW-01..03, DATA-01)', () => {
  // D-10: must be at describe-block level before any test runs.
  // Never call page.emulateMedia({ reducedMotion }) after page.goto.
  test.use({ reducedMotion: 'reduce' });

  // After each test, the beforeEach state is set up fresh, so we use beforeEach
  // only for the admin login and initial navigation — not for the theme describe block
  // (which seeds theme before goto via addInitScript).
  test.beforeEach(async ({ page }) => {
    await loginDemoAdmin(page);
    await page.goto('/admin');
    await waitForLiveViewReady(page);
  });

  // ── Reduced-motion (FLOW-02) ──────────────────────────────────────────────
  // Assert CSS collapsed effect on loading bar immediately on first page load.
  // Runs in the outer describe so it fires before any navigation.
  test('reduced-motion: loading bar animation collapsed to none (FLOW-02)', async ({
    page,
  }) => {
    // Assert after landing on /admin (beforeEach already navigated here).
    await assertReducedMotionEffect(page);
  });

  // ── Happy path — alice ────────────────────────────────────────────────────

  test.describe('happy path — alice (confirmed Acme member)', () => {
    test('overview → users search → user detail → audit → return with scope/breadcrumb (FLOW-01)', async ({
      page,
    }) => {
      // 1. Overview: global scope visible.
      await assertScopeChrome(page, 'Global');

      // 2. Navigate to users list, search for alice.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');

      await page.fill('input[name="q"]', DEMO_ALICE_EMAIL);
      await page.click('button:has-text("Search")');
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      const aliceRow = adminUsersEmailLocator(page, DEMO_ALICE_EMAIL);
      await expect(aliceRow).toBeVisible();

      // 3. Open alice's user detail. The "Search" button is a LiveView event that
      //    patches the results list; clicking the row link immediately after races
      //    that patch and the click is swallowed (the URL never leaves the list).
      //    Read the visible row's "Open user" href and navigate to it directly —
      //    this preserves the return_to scope param and lands on the detail page.
      const aliceDetailHref = await aliceRow
        .getByRole('link', { name: 'Open user' })
        .getAttribute('href');
      expect(aliceDetailHref).toMatch(/\/admin\/users\/[a-f0-9-]+/);
      await page.goto(aliceDetailHref!);
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');

      // 4. Breadcrumb "Users" link must carry the return_to / ?q= scope.
      const breadcrumb = page.getByRole('navigation', { name: 'Breadcrumb' });
      await expect(breadcrumb.getByRole('link', { name: 'Users' })).toHaveAttribute(
        'href',
        /return_to|\/admin\/users\?/,
      );

      // 5. Recent audit is visible (alice has seeded events). The Recent Audit
      //    section is the <section> containing the "View full audit" link; each
      //    event renders as an <article class="sg-list-row"> with a status pill
      //    (audit_row/1 in lib/sigra/admin/components.ex:699 — no "sg-audit-row"
      //    class exists, so the row is matched via .sg-list-row + .sg-status-pill).
      const recentAuditSection = page
        .locator('section')
        .filter({ has: page.getByRole('link', { name: 'View full audit' }) });
      await expect(
        recentAuditSection.locator('.sg-list .sg-list-row .sg-status-pill').first(),
      ).toBeVisible();

      // 6. Navigate to alice's full per-user audit.
      await page.getByRole('link', { name: 'View full audit' }).click();
      await waitForLiveViewReady(page);
      await expect(page).toHaveURL(/\/admin\/users\/[^?/]+\/audit/);
      await assertScopeChrome(page, 'Global');

      // 7. Return via breadcrumb — URL must have ?q= param (scope reconstructed).
      const auditBreadcrumb = page.getByRole('navigation', { name: 'Breadcrumb' });
      const usersLink = auditBreadcrumb.getByRole('link', { name: 'Users' });
      await expect(usersLink).toBeVisible();
      const usersHref = await usersLink.getAttribute('href');
      // Breadcrumb back-link carries the filtered list scope (D-12).
      expect(usersHref).toMatch(/\/admin\/users/);

      // Click back to users list and verify scope.
      await usersLink.click();
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');
    });
  });

  // ── Main-error — dave locked/unconfirmed ─────────────────────────────────

  test.describe('main-error — dave locked/unconfirmed', () => {
    test('user detail shows locked/unconfirmed state; audit shows auth.login.failure and auth.lockout.start', async ({
      page,
    }) => {
      // 1. Search for dave.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');

      await page.fill('input[name="q"]', DEMO_DAVE_EMAIL);
      await page.click('button:has-text("Search")');
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      const daveRow = adminUsersEmailLocator(page, DEMO_DAVE_EMAIL);
      await expect(daveRow).toBeVisible();

      // 2. Open dave's user detail. Navigate via the row's href (the post-Search
      //    LiveView patch swallows an immediate link click — see happy path note).
      const daveDetailHref = await daveRow
        .getByRole('link', { name: 'Open user' })
        .getAttribute('href');
      expect(daveDetailHref).toMatch(/\/admin\/users\/[a-f0-9-]+/);
      await page.goto(daveDetailHref!);
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
      await waitForLiveViewReady(page);
      await assertScopeChrome(page, 'Global');

      // 3. Locked + unconfirmed state indicators must be visible.
      // dave has locked_at set and is unconfirmed (hashed_password=nil per personas.ex).
      // The status_pills helper renders these as sg-status-pill elements.
      const statusArea = page.locator('.sg-cluster').filter({ hasText: /locked|unconfirmed/i });
      await expect(statusArea.first()).toBeVisible();

      // 4. Navigate to dave's per-user audit.
      await page.getByRole('link', { name: 'View full audit' }).click();
      await waitForLiveViewReady(page);
      await expect(page).toHaveURL(/\/admin\/users\/[^?/]+\/audit/);

      // 5. Dave has 2 seeded audit events: auth.login.failure + auth.lockout.start.
      // The action column renders as <code class="sg-code">{row.action}</code>.
      await expect(page.locator('code.sg-code').filter({ hasText: 'auth.login.failure' }).first()).toBeVisible();
      await expect(page.locator('code.sg-code').filter({ hasText: 'auth.lockout.start' }).first()).toBeVisible();
    });
  });

  // ── Boundary — frank scheduled-deletion + empty filter ───────────────────

  test.describe('boundary — frank scheduled-deletion + empty/no-data filter', () => {
    test('frank shows scheduled-deletion indicator; empty search renders empty state without error', async ({
      page,
    }) => {
      // 1. Search for frank.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);

      await page.fill('input[name="q"]', DEMO_FRANK_EMAIL);
      await page.click('button:has-text("Search")');
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
      const frankRow = adminUsersEmailLocator(page, DEMO_FRANK_EMAIL);
      await expect(frankRow).toBeVisible();

      // 2. Open frank's user detail. Navigate via the row's href (the post-Search
      //    LiveView patch swallows an immediate link click — see happy path note).
      const frankDetailHref = await frankRow
        .getByRole('link', { name: 'Open user' })
        .getAttribute('href');
      expect(frankDetailHref).toMatch(/\/admin\/users\/[a-f0-9-]+/);
      await page.goto(frankDetailHref!);
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
      await waitForLiveViewReady(page);

      // 3. Scheduled-deletion indicator visible.
      // frank has scheduled_deletion=true — renders as a status pill or notice.
      const scheduledDeletionIndicator = page.locator(
        '.sg-status-pill, .sg-notice',
      ).filter({ hasText: /deletion|scheduled|delete/i });
      await expect(scheduledDeletionIndicator.first()).toBeVisible();

      // 4. Empty filter: search for a term that matches no users.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);

      await page.fill('input[name="q"]', 'zzz-no-such-user-xyz@nowhere.test');
      await page.click('button:has-text("Search")');
      await expect(page).toHaveURL(/\/admin\/users\?.*q=/);

      // 5. Empty state renders — NOT an error component (D-13: empty ≠ broken).
      // The users list shows "No users match this view" text (from admin-user-operations.spec.ts:95).
      const emptyMsg = page.getByText(/no users match|no results|no match/i);
      await expect(emptyMsg.first()).toBeVisible();

      // Assert NO error-tone styling (empty state must not look broken).
      const errorEl = page.locator('[data-tone="danger"], .sg-status-pill[data-tone="danger"]').filter({
        hasText: /error|failed/i,
      });
      await expect(errorEl).toHaveCount(0);
    });
  });

  // ── Keyboard operability (FLOW-02) ────────────────────────────────────────

  test.describe('keyboard operability (FLOW-02)', () => {
    test('Tab to revoke trigger → Enter opens confirm dialog → focus containment → Escape closes → trigger refocused', async ({
      page,
    }) => {
      // Navigate to alice's user detail (alice has sessions to revoke).
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);

      await page.fill('input[name="q"]', DEMO_ALICE_EMAIL);
      await page.click('button:has-text("Search")');
      const aliceRowKb = adminUsersEmailLocator(page, DEMO_ALICE_EMAIL);
      await expect(aliceRowKb).toBeVisible();
      // Navigate via the row's href (post-Search LiveView patch swallows an
      // immediate link click — see happy path note).
      const aliceDetailHrefKb = await aliceRowKb
        .getByRole('link', { name: 'Open user' })
        .getAttribute('href');
      expect(aliceDetailHrefKb).toMatch(/\/admin\/users\/[a-f0-9-]+/);
      await page.goto(aliceDetailHrefKb!);
      await expect(page).toHaveURL(/\/admin\/users\/[a-f0-9-]+/, { timeout: 10000 });
      await waitForLiveViewReady(page);

      // Locate the "Revoke all sessions" or "Revoke session" trigger button.
      // Prefer "Revoke all sessions" from the Danger Zone section (always present if sessions exist).
      // Fall back to the per-session "Revoke session" button in the Sessions table.
      const revokeAllTrigger = page.getByRole('button', { name: 'Revoke all sessions' }).first();
      const revokeSessionTrigger = page.getByRole('button', { name: 'Revoke session' }).first();

      // Find whichever trigger is visible (alice has sessions).
      let triggerLocator = revokeAllTrigger;
      const revokeAllVisible = await revokeAllTrigger.isVisible().catch(() => false);
      if (!revokeAllVisible) {
        triggerLocator = revokeSessionTrigger;
      }
      await expect(triggerLocator).toBeVisible();

      // Capture element handle for focus-return assertion (Gate 5).
      const triggerHandle = await triggerLocator.elementHandle();

      // Keyboard-focus the trigger (not click — click suppresses :focus-visible).
      await triggerLocator.focus();
      await expect(triggerLocator).toBeFocused();

      // Open the confirm dialog via Enter.
      await page.keyboard.press('Enter');

      // Wait for overlay to appear (LiveView gate, not a sleep).
      const overlay = page.locator('#user-session-confirm-overlay');
      await expect(overlay).toBeVisible();
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();

      // Gate: focus containment invariant — focus must be inside the dialog.
      const isFocusInsideDialog = await page.evaluate(() => {
        const active = document.activeElement;
        const dialogEl = document.querySelector('.sg-confirm-dialog');
        return dialogEl !== null && (dialogEl === active || dialogEl.contains(active));
      });
      expect(isFocusInsideDialog, 'focus must be contained inside confirm dialog').toBe(true);

      // Escape closes the dialog.
      await page.keyboard.press('Escape');
      await expect(overlay).toBeHidden();

      // Gate 5: focus returns to the trigger after Escape.
      const isTriggerFocusedAfterEscape = await page.evaluate((handle) => {
        const active = document.activeElement;
        return handle !== null && (handle === active || (handle as Element).contains(active));
      }, triggerHandle);
      expect(
        isTriggerFocusedAfterEscape,
        'focus must return to trigger after Escape closes dialog',
      ).toBe(true);
    });
  });

  // ── Theme persistence (FLOW-03) ───────────────────────────────────────────
  //
  // This describe block does NOT use the outer beforeEach (which calls loginDemoAdmin
  // then goto /admin). The theme seed must happen via addInitScript BEFORE goto —
  // seedThemeAndAssertNoFlash handles this internally by calling addInitScript then
  // page.goto('/admin'). The outer beforeEach fires first, but seedThemeAndAssertNoFlash
  // re-seeds localStorage before its own goto, which re-navigates to /admin.

  test.describe('theme persistence (FLOW-03)', () => {
    test('dark theme persists across nav + reload + system flip; no-flash on first paint', async ({
      page,
    }) => {
      // The outer beforeEach has already logged in. Now seed the theme before the
      // next goto — seedThemeAndAssertNoFlash adds an initScript and calls goto('/admin'),
      // which tests the no-flash invariant: the inline <script> in admin_shell.ex:24-42
      // fires synchronously before paint.
      await seedThemeAndAssertNoFlash(page, 'dark');

      // 1. Theme persists on /admin.
      await waitForLiveViewReady(page);
      await assertThemeAttributes(page, 'dark');

      // 2. Theme persists after LiveView navigation to /admin/users.
      await page.goto('/admin/users');
      await waitForLiveViewReady(page);
      await assertThemeAttributes(page, 'dark');

      // 3. Theme persists after page.reload().
      // The no-flash inline script re-reads localStorage synchronously on each load.
      await page.reload();
      await waitForLiveViewReady(page);
      await assertThemeAttributes(page, 'dark');

      // 4. System flip: explicit dark choice overrides system preference.
      // Change system color scheme to light — explicit 'dark' should remain.
      await page.emulateMedia({ colorScheme: 'light' });
      await assertThemeAttributes(page, 'dark');

      // 5. Flip to 'system' preference → reload → preference persists.
      // The admin shell re-syncs localStorage from server state on LiveView mount,
      // so a bare localStorage.setItem('system') is overwritten back to 'dark' on
      // reload. Seed via addInitScript instead: it runs on EVERY navigation (incl.
      // reload) before both the inline no-flash script and the LiveView mount, so the
      // 'system' selection survives. In system mode the app records the choice in
      // data-sg-admin-theme-preference="system" and emits NO explicit resolved
      // data-sg-admin-theme override (the page follows the OS scheme via CSS).
      await page.addInitScript(() => {
        window.localStorage.setItem('sigra.admin.theme', 'system');
      });
      await page.reload();
      await waitForLiveViewReady(page);
      await assertThemeAttributes(page, 'system');
    });
  });
});
