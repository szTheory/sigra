import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 189 Plan 03: dedicated ConfirmDialog modal-interaction spec.
//
// Proves PAGE-03 APG hard gates for the ConfirmDialog hook wired in Plan 01:
//   1. Open confirm dialog (click "Revoke session" trigger)
//   2. Initial focus lands on the Cancel button
//   3. Tab containment: Tab cycles within dialog, Shift+Tab wraps back
//   4. Escape closes the dialog
//   5. Focus returns to the trigger element after close
//   6. ARIA attributes: role="dialog", aria-modal="true", aria-labelledby
//   7. axe scan WHILE dialog is open (wcag2a + wcag2aa, 0 violations)
//
// Spec design per D-13: small dedicated spec, role-selector-based, sleep-free
// (no artificial delays), runs on the behavior-truth `chromium` lane.
// No screenshots (toHaveScreenshot) — interaction-only evidence.

// ─── Spec-local helpers ───────────────────────────────────────────────────────
// These mirror the checkpoints spec helpers. They are defined here because
// admin-checkpoints.spec.ts helpers are file-local and cannot be imported.

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

async function openUserDetail(page: Page, targetEmail: string) {
  await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
  await waitForLiveViewReady(page);
  await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
  await page.getByRole('link', { name: 'Open user' }).first().click();
  await waitForLiveViewReady(page);
  await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
}

/** assertNoAxeViolations — mirrors admin-checkpoints.spec.ts L114-126 */
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const detail =
    violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

test.describe('ConfirmDialog modal interaction (PAGE-03 APG gates)', () => {
  test('proves all 7 APG hard gates: initial focus, tab containment, Escape close, focus return, ARIA, axe-while-open', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
    // Target user: any regular user with an active session (registers themselves,
    // creating a session that is visible in the admin "Revoke session" row).
    const targetEmail = `modal-target-${suffix}@example.test`;
    // Admin user: platform-admin+ email grants platform-admin via Example.SigraAdminPolicy.
    const adminEmail = `platform-admin+modal-${suffix}@example.test`;

    // --- Seed: register target user (creates a visible session) ---------------
    await registerUser(page, targetEmail, password);

    // --- Seed: register and switch to admin session ---------------------------
    await clearBrowserSession(page);
    await registerUser(page, adminEmail, password);

    // --- Navigate to target user's admin detail page -------------------------
    await openUserDetail(page, targetEmail);

    // Wait for the "Revoke session" button to be visible (confirms session row loaded).
    const triggerLocator = page.getByRole('button', { name: 'Revoke session' }).first();
    await expect(triggerLocator).toBeVisible();

    // ── Gate 1: Open the confirm dialog ──────────────────────────────────────
    // Capture a handle to the trigger element for focus-return assertion (Gate 5).
    const triggerHandle = await triggerLocator.elementHandle();
    await triggerLocator.click();

    // Wait for the overlay to appear — LiveView readiness gate, NOT a sleep.
    const overlay = page.locator('#user-session-confirm-overlay');
    await expect(overlay).toBeVisible();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();

    // ── Gate 2: Initial focus is on Cancel button ─────────────────────────────
    // The ConfirmDialog hook focuses the Cancel button (first focusable) on mount.
    // Select by the stable [data-sg-confirm-cancel] contract the hook itself uses
    // (mounted()/_cancel() both querySelector it) rather than by visible label —
    // the label is action-specific copy (e.g. "Keep sessions", set in 188-04) and
    // must not couple this APG gate to microcopy.
    const cancelButton = dialog.locator('[data-sg-confirm-cancel]');
    await expect(cancelButton).toBeVisible();
    // Assert activeElement is the Cancel button (or inside the cancel button).
    const isCancelFocused = await page.evaluate(() => {
      const active = document.activeElement;
      if (!active) return false;
      // Allow: Cancel button itself, or a child of it.
      const cancel = document.querySelector('.sg-confirm-dialog button:first-of-type');
      return cancel !== null && (cancel === active || cancel.contains(active));
    });
    expect(isCancelFocused, 'Gate 2: initial focus must be on Cancel button').toBe(true);

    // ── Gate 3: Tab containment ───────────────────────────────────────────────
    // The dialog has exactly two focusable elements: Cancel (ghost) + Confirm (danger).
    const confirmButton = dialog.getByRole('button', { name: /revoke|confirm/i });
    await expect(confirmButton).toBeVisible();

    // From Cancel (first), Tab → should move to the confirm (last).
    await page.keyboard.press('Tab');
    const isConfirmFocusedAfterTab = await page.evaluate(() => {
      const active = document.activeElement;
      const confirm = document.querySelector('.sg-confirm-dialog button:last-of-type');
      return confirm !== null && (confirm === active || confirm.contains(active));
    });
    expect(isConfirmFocusedAfterTab, 'Gate 3a: Tab from Cancel must move focus to Confirm button').toBe(true);

    // From Confirm (last), Tab → should wrap to Cancel (first).
    await page.keyboard.press('Tab');
    const isCancelFocusedAfterWrap = await page.evaluate(() => {
      const active = document.activeElement;
      const cancel = document.querySelector('.sg-confirm-dialog button:first-of-type');
      return cancel !== null && (cancel === active || cancel.contains(active));
    });
    expect(isCancelFocusedAfterWrap, 'Gate 3b: Tab from last focusable must wrap to Cancel').toBe(true);

    // From Cancel (first), Shift+Tab → should wrap to Confirm (last).
    await page.keyboard.press('Shift+Tab');
    const isConfirmFocusedAfterShiftTab = await page.evaluate(() => {
      const active = document.activeElement;
      const confirm = document.querySelector('.sg-confirm-dialog button:last-of-type');
      return confirm !== null && (confirm === active || confirm.contains(active));
    });
    expect(isConfirmFocusedAfterShiftTab, 'Gate 3c: Shift+Tab from Cancel must wrap to Confirm').toBe(true);

    // Assert focus never lands on a background element (i.e. activeElement is always inside the dialog).
    const isFocusInsideDialog = await page.evaluate(() => {
      const active = document.activeElement;
      const dialogEl = document.querySelector('.sg-confirm-dialog');
      return dialogEl !== null && (dialogEl === active || dialogEl.contains(active));
    });
    expect(isFocusInsideDialog, 'Gate 3d: focus must stay inside the dialog').toBe(true);

    // ── Gate 6: ARIA attributes ────────────────────────────────────────────────
    // (Run before Escape so dialog is still open)
    // role="dialog" is asserted by getByRole('dialog') above; verify aria-modal + aria-labelledby.
    const dialogElement = page.locator('.sg-confirm-dialog[role="dialog"]');
    await expect(dialogElement).toHaveAttribute('aria-modal', 'true');
    await expect(dialogElement).toHaveAttribute('aria-labelledby', 'user-session-confirm-title');

    // The label element must be visible.
    const titleEl = page.locator('#user-session-confirm-title');
    await expect(titleEl).toBeVisible();

    // ── Gate 7: axe WHILE dialog is open ─────────────────────────────────────
    await assertNoAxeViolations(page, 'axe:confirm-dialog-open');

    // ── Gate 4: Escape closes the dialog ─────────────────────────────────────
    await page.keyboard.press('Escape');
    // Overlay should be hidden or removed after Escape.
    await expect(overlay).toBeHidden();

    // ── Gate 5: Focus returns to the trigger element after close ─────────────
    const isTriggerFocusedAfterEscape = await page.evaluate((handle) => {
      const active = document.activeElement;
      return handle !== null && (handle === active || (handle as Element).contains(active));
    }, triggerHandle);
    expect(isTriggerFocusedAfterEscape, 'Gate 5: focus must return to the Revoke session trigger after Escape').toBe(true);
  });

  // ─── Branding #restore-defaults-overlay case (D-06) ─────────────────────────
  // Proves the branding ConfirmDialog at branding_live.ex:349-378 passes the same
  // 7 APG hard gates + axe-while-open as the user-sessions case above.
  // Pitfall 4: branding dialog uses #restore-defaults-overlay / restore-defaults-title,
  // NOT #user-session-confirm-overlay / user-session-confirm-title.
  // No toHaveScreenshot — interaction-only evidence. No D-10 branding board/slug.
  test('branding #restore-defaults-overlay: proves all 7 APG hard gates + axe-while-open (D-06)', async ({
    page,
  }) => {
    const suffix = Date.now();
    const password = TEST_PASSWORD;
    // Admin user: platform-admin+ email grants platform-admin via Example.SigraAdminPolicy.
    const adminEmail = `platform-admin+branding-modal-${suffix}@example.test`;

    // --- Seed: register and sign in as platform admin -------------------------
    await registerUser(page, adminEmail, password);

    // --- Navigate to the branding workbench ----------------------------------
    await page.goto('/admin/auth-branding');
    await waitForLiveViewReady(page);

    // Wait for the "Restore config defaults" trigger to be visible.
    // This button is only shown when a saved admin profile exists (admin_profile?/1).
    // If it is not visible, the test cannot proceed — assert it is reachable for admins.
    const triggerLocator = page.getByRole('button', { name: 'Restore config defaults' });
    // The button is conditional on admin_profile?(@profile_source). If no profile exists yet,
    // save one by submitting the form once. We probe first and skip if the button is absent
    // (meaning no saved branding exists and the button is not rendered).
    // Per branding_live.ex:337-343 the button renders only when admin_profile?/1 is true.
    // We need to save a profile to make the button appear.
    const triggerVisible = await triggerLocator.isVisible();
    if (!triggerVisible) {
      // Submit the form with current defaults to create an admin profile record.
      // The "Save profile" button submits the branding form (branding_live.ex:327).
      const saveButton = page.getByRole('button', { name: 'Save profile' });
      if (await saveButton.isVisible()) {
        await saveButton.click();
        await waitForLiveViewReady(page);
      }
    }
    await expect(triggerLocator).toBeVisible();

    // ── Gate 1: Open the branding restore-defaults dialog ────────────────────
    // Capture a handle to the trigger element for focus-return assertion (Gate 5).
    const triggerHandle = await triggerLocator.elementHandle();
    await triggerLocator.click();

    // Wait for the overlay to appear — LiveView readiness gate, NOT a sleep.
    const overlay = page.locator('#restore-defaults-overlay');
    await expect(overlay).toBeVisible();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();

    // ── Gate 2: Initial focus is on Cancel button ─────────────────────────────
    // The ConfirmDialog hook focuses the Cancel button (first focusable) on mount.
    // Use the stable [data-sg-confirm-cancel] contract — same as the user-sessions case.
    const cancelButton = dialog.locator('[data-sg-confirm-cancel]');
    await expect(cancelButton).toBeVisible();
    const isCancelFocused = await page.evaluate(() => {
      const active = document.activeElement;
      if (!active) return false;
      const cancel = document.querySelector('.sg-confirm-dialog button:first-of-type');
      return cancel !== null && (cancel === active || cancel.contains(active));
    });
    expect(isCancelFocused, 'Gate 2: initial focus must be on Cancel button').toBe(true);

    // ── Gate 3: Tab containment ───────────────────────────────────────────────
    // The branding dialog has exactly two focusable elements: Cancel (ghost) + Restore defaults (danger).
    const confirmButton = dialog.getByRole('button', { name: /restore|confirm/i });
    await expect(confirmButton).toBeVisible();

    // From Cancel (first), Tab → should move to the confirm (last).
    await page.keyboard.press('Tab');
    const isConfirmFocusedAfterTab = await page.evaluate(() => {
      const active = document.activeElement;
      const confirm = document.querySelector('.sg-confirm-dialog button:last-of-type');
      return confirm !== null && (confirm === active || confirm.contains(active));
    });
    expect(isConfirmFocusedAfterTab, 'Gate 3a: Tab from Cancel must move focus to Restore defaults button').toBe(true);

    // From Confirm (last), Tab → should wrap to Cancel (first).
    await page.keyboard.press('Tab');
    const isCancelFocusedAfterWrap = await page.evaluate(() => {
      const active = document.activeElement;
      const cancel = document.querySelector('.sg-confirm-dialog button:first-of-type');
      return cancel !== null && (cancel === active || cancel.contains(active));
    });
    expect(isCancelFocusedAfterWrap, 'Gate 3b: Tab from last focusable must wrap to Cancel').toBe(true);

    // From Cancel (first), Shift+Tab → should wrap to Restore defaults (last).
    await page.keyboard.press('Shift+Tab');
    const isConfirmFocusedAfterShiftTab = await page.evaluate(() => {
      const active = document.activeElement;
      const confirm = document.querySelector('.sg-confirm-dialog button:last-of-type');
      return confirm !== null && (confirm === active || confirm.contains(active));
    });
    expect(isConfirmFocusedAfterShiftTab, 'Gate 3c: Shift+Tab from Cancel must wrap to Restore defaults button').toBe(true);

    // Assert focus never lands on a background element (i.e. activeElement is always inside the dialog).
    const isFocusInsideDialog = await page.evaluate(() => {
      const active = document.activeElement;
      const dialogEl = document.querySelector('.sg-confirm-dialog');
      return dialogEl !== null && (dialogEl === active || dialogEl.contains(active));
    });
    expect(isFocusInsideDialog, 'Gate 3d: focus must stay inside the dialog').toBe(true);

    // ── Gate 6: ARIA attributes ────────────────────────────────────────────────
    // (Run before Escape so dialog is still open)
    // Pitfall 4: assert aria-labelledby="restore-defaults-title" (NOT user-session-confirm-title).
    const dialogElement = page.locator('.sg-confirm-dialog[role="dialog"]');
    await expect(dialogElement).toHaveAttribute('aria-modal', 'true');
    await expect(dialogElement).toHaveAttribute('aria-labelledby', 'restore-defaults-title');

    // The label element must be visible.
    const titleEl = page.locator('#restore-defaults-title');
    await expect(titleEl).toBeVisible();

    // ── Gate 7: axe WHILE dialog is open ─────────────────────────────────────
    await assertNoAxeViolations(page, 'axe:branding-restore-defaults-dialog-open');

    // ── Gate 4: Escape closes the dialog ─────────────────────────────────────
    await page.keyboard.press('Escape');
    // Overlay should be hidden or removed after Escape.
    await expect(overlay).toBeHidden();

    // ── Gate 5: Focus returns to the trigger element after close ─────────────
    const isTriggerFocusedAfterEscape = await page.evaluate((handle) => {
      const active = document.activeElement;
      return handle !== null && (handle === active || (handle as Element).contains(active));
    }, triggerHandle);
    expect(isTriggerFocusedAfterEscape, 'Gate 5: focus must return to the Restore config defaults trigger after Escape').toBe(true);
  });
});
