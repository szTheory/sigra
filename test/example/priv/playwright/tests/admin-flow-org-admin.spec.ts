/**
 * Phase 190 Plan 04 — Org admin JTBD flow spec (FLOW-01..03, DATA-01).
 *
 * Persona: morgan@demo.tasklane.test — org-scoped admin for Acme Corp.
 * Morgan is NOT a platform admin, so global /admin is blocked. The example app's
 * graceful-denial UX redirects the authenticated non-admin home to /app with a
 * generic flash (the library default is a raw 403; the demo customizes it).
 *
 * Coverage:
 *   FLOW-01: tenant-bounded access — /admin/organizations/acme-corp (200 + scope chrome)
 *   FLOW-01: permission denied — /admin (redirect to /app, generic denial flash, anti-enumeration)
 *   FLOW-01: empty audit boundary — morgan has 0 audit events; sg-empty-state renders
 *   FLOW-02: keyboard operability — Tab navigation in org-scoped admin view
 *   FLOW-02: reduced-motion — assertReducedMotionEffect() confirms CSS collapsed effect
 *   FLOW-03: theme persistence — dark theme survives org-scoped journey and page.reload()
 *
 * D-03: org admin flow driven by morgan@demo.tasklane.test (tenant-bounded).
 * D-04: main-error = permission-denied (morgan hitting /admin is redirected home to
 *        /app with a generic denial flash); boundary = morgan empty audit (zero events).
 * D-09: flow spec asserts JOURNEY-LEVEL properties only — does not re-test
 *        permission internals or admin_plug guard mechanics.
 * D-10: reducedMotion set at test.use() context level; theme via data-sg-admin-theme
 *        + localStorage; no-flash via addInitScript before goto.
 * D-13: the DENIAL must be GENERIC — the flash must NOT disclose org name or a
 *        probed target's email (anti-enumeration); scoped to the denial flash.
 *
 * Runs on the `chromium` behavior-truth lane only.
 * Excluded from `mobile` via ADMIN_BEHAVIOR_SPECS regex in playwright.config.ts.
 */

import { test, expect, type Page } from '@playwright/test';
import {
  loginDemoMorgan,
  waitForLiveViewReady,
  assertScopeChrome,
  assertThemeAttributes,
  assertReducedMotionEffect,
  DEMO_MORGAN_EMAIL,
} from '../helpers/adminFlows';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ACME_ORG_SLUG = 'acme-corp';
const ACME_ORG_NAME = 'Acme Corp';

// Org-scoped admin routes for morgan.
const ORG_ADMIN_ROOT = `/admin/organizations/${ACME_ORG_SLUG}`;
const ORG_ADMIN_USERS = `/admin/organizations/${ACME_ORG_SLUG}/users`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Navigates to the org-scoped users list, finds the given email, opens that
 * user's detail page, and waits for LiveView to be ready.
 *
 * Uses adminUsersEmailLocator (visibility-scoped) to avoid clicking hidden
 * mobile duplicate "Open user" links.
 */
async function openOrgUserDetail(page: Page, email: string): Promise<void> {
  await page.goto(`${ORG_ADMIN_USERS}?q=${encodeURIComponent(email)}`);
  await waitForLiveViewReady(page);
  await expect(adminUsersEmailLocator(page, email)).toBeVisible();
  const visibleRow = adminUsersEmailLocator(page, email);
  await visibleRow.getByRole('link', { name: 'Open user' }).click();
  await expect(page).toHaveURL(
    new RegExp(`/admin/organizations/${ACME_ORG_SLUG}/users/[a-f0-9-]+`),
    { timeout: 10000 },
  );
  await waitForLiveViewReady(page);
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

test.describe('Phase 190 org admin flow (FLOW-01..03, DATA-01)', () => {
  /**
   * D-10: reducedMotion set at describe-block context level — must appear here,
   * NOT inside individual tests. Firefox drops emulateMedia() set after goto
   * (playwright#31328). All tests in this suite inherit the reduced-motion
   * media feature via test.use().
   */
  test.use({ reducedMotion: 'reduce' });

  /**
   * Standard beforeEach: log in as morgan and navigate to the org admin root.
   * The 403 and theme tests override this by NOT using beforeEach (they manage
   * their own navigation context).
   *
   * Note: The 403 main-error describe block uses a fresh browser context
   * via test.use({ storageState: undefined }) to ensure no cookie leakage from
   * beforeEach login. Theme block also manages its own navigation.
   */
  test.beforeEach(async ({ page }) => {
    await loginDemoMorgan(page);
    await page.goto(ORG_ADMIN_ROOT);
    await waitForLiveViewReady(page);
  });

  // -------------------------------------------------------------------------
  // Happy path — morgan org-scoped admin access
  // -------------------------------------------------------------------------

  test.describe('happy path — morgan org-scoped admin access', () => {
    test(
      'org admin reaches Acme Corp admin scope, views member list, navigates to user detail',
      async ({ page }) => {
        // Step 1: Assert scope chrome shows Acme Corp (org-scoped admin posture).
        await assertScopeChrome(page, ACME_ORG_NAME);

        // Step 2: Navigate to org-scoped users list — lists Acme members.
        await page.goto(ORG_ADMIN_USERS);
        await waitForLiveViewReady(page);
        await assertScopeChrome(page, ACME_ORG_NAME);

        // Step 3: Alice is an Acme member (seeded) — visible in the org-scoped list.
        await expect(
          adminUsersEmailLocator(page, 'alice@demo.tasklane.test'),
        ).toBeVisible();

        // Step 4: Reduced-motion CSS effect — assertReducedMotionEffect checks that
        // @media (prefers-reduced-motion: reduce) collapses the loading bar animation.
        // Call after first stable page load in this describe block (D-10).
        await assertReducedMotionEffect(page);

        // Step 5: Navigate to alice's user detail within the org scope.
        await openOrgUserDetail(page, 'alice@demo.tasklane.test');

        // Step 6: Scope chrome still shows Acme Corp on the user detail page.
        await assertScopeChrome(page, ACME_ORG_NAME);

        // Step 7: User detail renders alice's email (confirms we're on the right page).
        await expect(page.locator('main')).toContainText('alice@demo.tasklane.test');
      },
    );
  });

  // -------------------------------------------------------------------------
  // Main-error — permission denied (global /admin blocked)
  // -------------------------------------------------------------------------

  test.describe('main-error — permission denied (global /admin blocked)', () => {
    /**
     * This test manages its own fresh browser context to guarantee no session
     * cookie bleeds from the shared beforeEach login.
     *
     * Denial contract: the example app's `auth_error_handler` :insufficient_scope
     * branch gives an AUTHENTICATED non-admin a graceful redirect home to /app with
     * a generic flash ("principle of least surprise") rather than the library's raw
     * 403 default — morgan is still blocked from every global admin surface. The hard
     * 403 is retained for unauthenticated / non-HTML callers (a separate contract).
     *
     * D-13 threat T-190-10: the DENIAL must be GENERIC — the flash must NOT disclose
     * the org name 'Acme Corp' or a probed target's email (anti-enumeration). Morgan's
     * own /app hub legitimately shows morgan's own account, so the non-disclosure
     * guard is scoped to the denial flash, not the landing hub.
     */
    test(
      'morgan hitting /admin is redirected home (blocked) — generic denial, no org/target disclosure',
      async ({ browser }) => {
        const context = await browser.newContext();
        const page = await context.newPage();

        try {
          // Log in as morgan in the fresh context.
          await loginDemoMorgan(page);

          // Attempt to access global /admin — morgan is org-scoped only.
          await page.goto('/admin');

          // Blocked from global admin: morgan lands on their own account hub (/app),
          // NOT any admin surface (D-04: permission denied — no global /admin access).
          await expect(page).toHaveURL(/\/app\/?$/);

          // Generic denial flash — states the block without revealing which admin area.
          // Scope to the specific denial alert so co-rendered flashes can't cause a
          // strict-mode multi-match.
          const denial = page
            .getByRole('alert')
            .filter({ hasText: "You don't have access to that admin area." });
          await expect(denial).toBeVisible();

          // Anti-enumeration (T-190-10): the DENIAL must not echo the org identity
          // morgan was blocked from, nor a probed target's address. Scoped to the flash
          // (morgan's own hub legitimately shows morgan's own account — not enumeration).
          await expect(denial).not.toContainText(ACME_ORG_NAME);
          await expect(denial).not.toContainText(DEMO_MORGAN_EMAIL);
        } finally {
          await context.close();
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Boundary — org audit empty state (filtered to no-event date range)
  // -------------------------------------------------------------------------

  test.describe('boundary — org audit empty state (filtered date range)', () => {
    /**
     * Tests that the audit empty_state component renders when no events match the
     * active date filter. This is the deterministic boundary: a very narrow date
     * range in 2020 (before any seeded events) guarantees @rows == [] regardless
     * of what test runs may have created live session events for morgan.
     *
     * D-04 boundary intent: "zero audit events" — exercised via a filter that
     * definitively returns zero results, avoiding fragility from test-created
     * session events (loginDemoMorgan in beforeEach creates a session.create event
     * for morgan on each test run).
     *
     * The AuditIndexLive org-scoped route (/admin/organizations/acme-corp/audit)
     * renders <.empty_state :if={@rows == []} title="No audit events match this view">
     * when the active date filter returns no rows (audit_index_live.ex:205).
     *
     * Morgan can access this route (org-scoped admin, not platform-admin-only).
     */
    test(
      'org audit empty state renders when date filter matches no events',
      async ({ page }) => {
        // Navigate to the org-scoped audit index.
        await page.goto(`/admin/organizations/${ACME_ORG_SLUG}/audit`);
        await waitForLiveViewReady(page);

        // Assert scope chrome is still org-scoped.
        await assertScopeChrome(page, ACME_ORG_NAME);

        // Apply a date range that precedes all seeded and test-created events.
        // Seed reference timestamp is 2026-05-15; a 2020 range has zero events.
        // Field names: `from` and `to` (audit_index_live.ex:120-128).
        // Phase 202-03 (commit e664e7f1) moved the from/to date inputs inside a
        // collapsed <details><summary>More filters</summary> disclosure; expand it
        // first so the inputs are actionable (page.fill on a hidden input times out).
        await page.locator('details > summary', { hasText: 'More filters' }).click();
        await page.fill('input[name="from"]', '2020-01-01');
        await page.fill('input[name="to"]', '2020-01-02');
        await page.getByRole('button', { name: 'Apply filters' }).click();
        await waitForLiveViewReady(page);

        // Assert empty state renders (audit_index_live.ex:205 — @rows == []).
        // audit_index_live.ex uses title="No audit events match this view".
        await expect(page.locator('.sg-empty-state')).toBeVisible();
        await expect(page.locator('.sg-empty-state')).toContainText(
          'No audit events match this view',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Keyboard operability (FLOW-02)
  // -------------------------------------------------------------------------

  test.describe('keyboard operability (FLOW-02)', () => {
    /**
     * Asserts Tab navigation reaches interactive controls in the org-scoped admin
     * shell. This is a JOURNEY-LEVEL keyboard check (D-09) — the APG-level
     * ConfirmDialog keyboard gates are owned by admin-modal-interaction.spec.ts.
     *
     * Focus assertions use .toBeFocused() (web-first) after .focus() (keyboard-
     * focus, not click — click suppresses :focus-visible per WCAG).
     */
    test(
      'Tab navigation reaches interactive controls with visible focus in org-scoped view',
      async ({ page }) => {
        // Navigate to org admin root (beforeEach already logged in morgan).
        await page.goto(ORG_ADMIN_ROOT);
        await waitForLiveViewReady(page);

        // Tab from the body — first focusable element should be a skip link or nav item.
        await page.keyboard.press('Tab');

        // Assert that some element in the admin shell has focus (focus didn't get lost).
        const hasFocus = await page.evaluate(() => {
          const active = document.activeElement;
          return active !== null && active !== document.body;
        });
        expect(hasFocus, 'Tab should move focus to a visible interactive element').toBe(true);

        // Navigate to org users list and assert scope chrome is keyboard-reachable.
        await page.goto(ORG_ADMIN_USERS);
        await waitForLiveViewReady(page);

        // Scope chrome (header) text is visible — keyboard users can reach it via
        // heading-level navigation (assertScopeChrome uses getByText, confirming visibility).
        await assertScopeChrome(page, ACME_ORG_NAME);

        // The Search button is a named interactive control — confirm it is focusable.
        const searchButton = page.getByRole('button', { name: 'Search' });
        await searchButton.focus();
        await expect(searchButton).toBeFocused();
      },
    );
  });

  // -------------------------------------------------------------------------
  // Theme persistence across org-scoped journey (FLOW-03)
  // -------------------------------------------------------------------------

  test.describe('theme persistence across org-scoped journey (FLOW-03)', () => {
    /**
     * Verifies dark theme persists through the org-scoped admin journey and
     * survives page.reload().
     *
     * NOTE: This describe block does NOT use the outer beforeEach (loginDemoMorgan
     * + goto ORG_ADMIN_ROOT). Theme seeding uses addInitScript which must run
     * before any page.goto. The seedThemeAndAssertNoFlash helper:
     *   1. Calls addInitScript to write localStorage before any page load.
     *   2. Navigates to /admin.
     *   3. Asserts html[data-sg-admin-theme] = 'dark' (inline script in
     *      admin_shell.ex:24-42 applied before paint — no FOUC).
     *
     * Morgan cannot reach /admin (403) — so seedThemeAndAssertNoFlash navigates to
     * /admin which will 403 for morgan. Instead, we need to seed via addInitScript
     * and then navigate to a page morgan CAN reach (/admin/organizations/acme-corp).
     *
     * Implementation: call addInitScript manually (matching seedThemeAndAssertNoFlash
     * internals) then navigate to the org admin root that morgan is authorized for.
     */
    test(
      'dark theme persists across org-scoped admin journey and after page.reload()',
      async ({ browser }) => {
        // Use a fresh browser context to control the localStorage seed before any
        // page navigation. addInitScript must be registered before ANY page.goto;
        // the outer beforeEach has already loaded pages in the shared page context.
        const context = await browser.newContext();
        const page = await context.newPage();

        try {
          // Register the initScript before any navigation (D-10).
          // This mirrors seedThemeAndAssertNoFlash internals but targets morgan's
          // allowed org route rather than /admin (which would 403 for morgan).
          await page.addInitScript((t) => {
            window.localStorage.setItem('sigra.admin.theme', t);
          }, 'dark');

          // Log in as morgan (fresh context — no prior session).
          await loginDemoMorgan(page);

          // Navigate to org admin root — morgan is authorized here.
          await page.goto(ORG_ADMIN_ROOT);
          await waitForLiveViewReady(page);

          // Assert no-flash: inline script in admin_shell.ex:24-42 applied 'dark'
          // before paint synchronously (not async/defer).
          await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', 'dark');

          // Assert full theme attributes on the org admin page.
          await assertThemeAttributes(page, 'dark');

          // Navigate to org users list — theme persists across LiveView navigation.
          await page.goto(ORG_ADMIN_USERS);
          await waitForLiveViewReady(page);
          await assertThemeAttributes(page, 'dark');

          // Reload: the inline admin_shell.ex script re-reads localStorage on each
          // page render — dark theme must persist after reload without FOUC.
          await page.reload();
          await waitForLiveViewReady(page);
          await assertThemeAttributes(page, 'dark');
        } finally {
          await context.close();
        }
      },
    );
  });
});
