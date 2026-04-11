// Phase 10.1.1 Plan 07: golden-path full-lifecycle browser smoke.
//
// Exercises: register → confirm → login → sessions list → sudo → MFA enroll
// (TOTP) → logout → login → MFA challenge. This is the browser-level signal
// that catches B1 (no JS bundle), B2 (no LiveSocket), B4 (live_session
// wiring), B6 (session store unification), B7 (sudo template), B8 (audit
// schema), and B9 (form submit swallow) in one pass.
//
// TOTP alignment note: Sigra uses NimbleTOTP with its defaults (30s step,
// SHA-1, 6 digits) — see lib/sigra/mfa.ex. otplib's `authenticator` defaults
// match exactly, so no configuration is required.

import { test, expect } from '@playwright/test';
import { authenticator } from 'otplib';
import { extractConfirmationLink } from '../fixtures/mailbox';

test('full user lifecycle: register → confirm → login → sessions → sudo → MFA enroll → logout → MFA challenge', async ({
  page,
  request,
}) => {
  const email = `lifecycle-${Date.now()}@example.test`;
  const password = 'CorrectHorseBatteryStaple123!';

  // Helper: wait until LiveView has finished its channel join so phx-change
  // / phx-submit fire through the live channel rather than being queued
  // while the client is still connecting. In CI, `example_playwright_smoke`
  // runs with MIX_ENV=dev which can fall back to longpoll transport — each
  // LV event becomes a separate HTTP round-trip, and the full validate→
  // save→trigger_submit chain can exceed the default 5s expect timeout.
  const waitForLiveViewReady = async () => {
    await expect(page.locator('body.phx-connected').first()).toBeVisible({
      timeout: 15_000,
    });
  };

  // --- 1. Register ---
  await page.goto('/users/register');
  await waitForLiveViewReady();
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');
  // After successful register, the form trigger_submit reposts to
  // /users/log_in?_action=registered which logs the user in. Expect to land
  // somewhere non-register. Longpoll transport adds latency, so give this
  // a generous ceiling.
  await expect(page).not.toHaveURL(/\/users\/register/, { timeout: 15_000 });

  // --- 2. Confirm via dev mailbox ---
  const confirmHref = await extractConfirmationLink(page, email);
  await page.goto(confirmHref);
  // ConfirmationLive auto-confirms via the token in handle_params and
  // redirects away from /users/confirm/:token. We assert the redirect rather
  // than any flash text — the flash message is styled as a toast and its
  // lifecycle has shifted across Phoenix versions.
  await expect(page).not.toHaveURL(/\/users\/confirm\//, { timeout: 10_000 });

  // --- 3. Login (if not already authed) ---
  await page.goto('/users/log_in');
  // The login page is a plain controller (post plan 04). If we are already
  // logged in, the :redirect_if_user_is_authenticated scope redirects away.
  if (page.url().includes('/users/log_in')) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }

  // --- 4. Sessions list (proves B6 unification: login wrote to user_sessions) ---
  await page.goto('/users/sessions');
  await expect(
    page.getByText(/active|just now|current/i).first(),
  ).toBeVisible({ timeout: 5_000 });

  // --- 5. Sudo re-auth (proves B7 sudo template fix) ---
  await page.goto('/users/sudo');
  await page.fill('input[name="sudo[password]"]', password);
  await page.click('button:has-text("Confirm password")');
  await expect(page).not.toHaveURL(/\/users\/sudo(\?|$)/);

  // --- 6. MFA enroll (TOTP) ---
  await page.goto('/users/settings/mfa');
  const beginSelector =
    'button:has-text("Enable"), button:has-text("Begin"), button:has-text("Set up")';
  await page.locator(beginSelector).first().click();

  // Read the TOTP base32 secret from the data-testid hook (Task 1).
  const secret = (
    await page.locator('[data-testid="mfa-totp-secret"]').innerText()
  ).replace(/\s+/g, '');
  expect(secret).toBeTruthy();

  // Generate the current 6-digit code from the secret.
  const enrollCode = authenticator.generate(secret);

  await page.fill('#mfa_enroll_form input[name="enroll[code]"]', enrollCode);
  await page
    .locator(
      '#mfa_enroll_form button:has-text("Confirm"), #mfa_enroll_form button:has-text("Verify"), #mfa_enroll_form button[type="submit"]',
    )
    .first()
    .click();

  // Expect an MFA-enabled confirmation.
  await expect(
    page.getByText(/mfa.*enabled|enrolled|enabled successfully/i).first(),
  ).toBeVisible({ timeout: 5_000 });

  // --- 7. Logout ---
  // The example app exposes DELETE /users/log_out. In the browser, a "Log out"
  // button submits a form with method=delete (Phoenix's hidden-method pattern).
  // Try the visible button first; fall back to issuing a DELETE request via
  // page.request (preserves cookies).
  const logoutButton = page.getByRole('button', { name: /log out/i }).first();
  if ((await logoutButton.count()) > 0) {
    await logoutButton.click();
  } else {
    // Fallback: preserves the browser session cookie.
    await page.request.fetch('/users/log_out', { method: 'DELETE' });
  }

  // --- 8. Login again → expect MFA challenge ---
  await page.goto('/users/log_in');
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');

  // The user has TOTP enabled, so login lands on the MFA challenge page.
  await expect(page).toHaveURL(/\/users\/mfa/);

  const challengeCode = authenticator.generate(secret);
  await page.fill('input[name="mfa[code]"]', challengeCode);
  await page.locator('button[type="submit"]:visible').first().click();

  // Fully logged in — off the auth pages.
  await expect(page).not.toHaveURL(/\/users\/(log_in|mfa)/);
});
