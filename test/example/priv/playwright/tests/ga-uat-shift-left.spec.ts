// Shift-left SEED-001 (GA UAT): browser contracts that used to be human-only.
// SEED-6: invitation signup email lock — tampered client-side email → server error.
// SEED-7: MFA backup regenerate panel + TOTP gate (flash proves handler path).

import { test, expect } from '@playwright/test';
import { authenticator } from 'otplib';
import { extractConfirmationLink } from '../fixtures/mailbox';

const baseURL = process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000';

async function waitForLiveViewReady(page: import('@playwright/test').Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function registerAndConfirm(
  page: import('@playwright/test').Page,
  email: string,
  password: string,
) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');
  await expect(page).not.toHaveURL(/\/users\/register/);
  const confirmHref = await extractConfirmationLink(page, email);
  await page.goto(confirmHref);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);
}

async function logInIfNeeded(
  page: import('@playwright/test').Page,
  email: string,
  password: string,
) {
  await page.goto('/users/log_in');
  if (page.url().includes('/users/log_in')) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }
}

async function createOrg(page: import('@playwright/test').Page, name: string, slug: string) {
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', name);
  await expect(page.locator('#slug-preview')).toHaveText(slug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  await waitForLiveViewReady(page);
}

async function sendInvite(
  page: import('@playwright/test').Page,
  inviteeEmail: string,
  orgName: string,
) {
  const modal = page.locator('#invite-member-modal');
  await page.locator('#invite-member-button').click({ force: true });
  await page.evaluate(() => {
    const d = document.getElementById('invite-member-modal');
    if (d instanceof HTMLDialogElement && !d.open) d.showModal();
  });
  await expect(modal).toHaveJSProperty('open', true);
  await modal.locator('input[name="invitation[email]"]').fill(inviteeEmail, { force: true });
  await modal.locator('button[type="submit"]').click({ force: true });
  await expect(page.getByText(`Invitation sent to ${inviteeEmail}.`)).toBeVisible();
}

async function extractInvitationLink(
  page: import('@playwright/test').Page,
  recipient: string,
) {
  let link: string | null = null;
  await expect.poll(async () => {
    const mailbox = (await page.evaluate(async () => {
      const response = await fetch('/dev/mailbox/json');
      return response.json();
    })) as {
      data: Array<{
        to: string[];
        html_body: string | null;
        text_body: string | null;
      }>;
    };

    const row = mailbox.data.find((email) => {
      const recipients = email.to.join(' ');
      const body = [email.html_body || '', email.text_body || ''].join('\n');
      return recipients.includes(recipient) && body.includes('/invitations/');
    });

    if (row) {
      const body = [row.html_body || '', row.text_body || ''].join('\n');
      const match = body.match(/https?:\/\/[^\s"'<>]*\/invitations\/[^\s"'<>]*\/accept/);
      if (match) {
        const normalized = new URL(match[0], page.url());
        normalized.protocol = new URL(page.url()).protocol;
        normalized.host = new URL(page.url()).host;
        link = normalized.toString();
      }
    }

    return link !== null;
  }, {
    message: `No invitation link for ${recipient}`,
    intervals: [250, 500, 1000],
    timeout: 30_000,
  }).toBe(true);

  if (!link) throw new Error(`No invitation link for ${recipient}`);

  return link;
}

test.describe('GA UAT shift-left (SEED-6 / SEED-7)', () => {
  test('SEED-6: invitation signup rejects tampered email with locked-address error', async ({
    page,
    browser,
  }) => {
    const suffix = Date.now();
    const ownerEmail = `ga-seed6-owner-${suffix}@example.test`;
    const ownerPassword = 'CorrectHorseBatteryStaple123!';
    const inviteeEmail = `ga-seed6-invitee-${suffix}@example.test`;
    const inviteePassword = 'CorrectHorseBatteryStaple123!';
    const orgName = `GA Seed6 Org ${suffix}`;
    const orgSlug = `ga-seed6-org-${suffix}`;

    await registerAndConfirm(page, ownerEmail, ownerPassword);
    await logInIfNeeded(page, ownerEmail, ownerPassword);
    await createOrg(page, orgName, orgSlug);
    await sendInvite(page, inviteeEmail, orgName);
    const href = await extractInvitationLink(page, inviteeEmail);

    const ctx = await browser.newContext({ baseURL });
    const p = await ctx.newPage();
    try {
      await p.goto(href);
      await waitForLiveViewReady(p);
      await expect(p.locator('#invitation-accept-signup')).toBeVisible();

      const emailInput = p.getByLabel('Email');
      await expect(emailInput).toHaveValue(inviteeEmail);
      await emailInput.evaluate((el: HTMLInputElement) => {
        el.removeAttribute('readonly');
        el.removeAttribute('disabled');
        el.value = 'attacker-different@example.test';
      });
      await p.getByLabel('Password').fill(inviteePassword);
      await p.getByRole('button', { name: `Create account & join ${orgName}` }).click();

      await expect(p.locator('#invitation-accept-signup')).toContainText(
        `This invitation is locked to ${inviteeEmail}`,
      );
    } finally {
      await ctx.close();
    }
  });

  test('SEED-7: MFA regenerate confirmation surface is reachable after enrollment', async ({
    page,
  }) => {
    const email = `ga-seed7-${Date.now()}@example.test`;
    const password = 'CorrectHorseBatteryStaple123!';

    await registerAndConfirm(page, email, password);
    await logInIfNeeded(page, email, password);

    await page.goto('/users/sudo');
    await page.fill('input[name="sudo[password]"]', password);
    await page.click('button:has-text("Confirm password")');
    await expect(page).not.toHaveURL(/\/users\/sudo(\?|$)/);

    await page.goto('/users/settings/mfa');
    await waitForLiveViewReady(page);
    const beginSelector =
      'button:has-text("Enable"), button:has-text("Begin"), button:has-text("Set up")';
    await page.locator(beginSelector).first().click();

    const secret = (
      await page.locator('[data-testid="mfa-totp-secret"]').innerText()
    ).replace(/\s+/g, '');
    expect(secret).toBeTruthy();
    const enrollCode = authenticator.generate(secret);
    await page.fill('#mfa_enroll_form input[name="enroll[code]"]', enrollCode);
    await expect(page.getByText(/save your backup codes/i).first()).toBeVisible();

    await page.goto('/users/settings/mfa');
    await waitForLiveViewReady(page);
    await expect(page.getByRole('button', { name: /^Disable$/i }).first()).toBeVisible();

    await page.getByRole('button', { name: 'Regenerate codes' }).first().click();
    await expect(page.locator('#mfa_regenerate_form')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Regenerate backup codes' })).toBeVisible();
    await expect(page.locator('#regenerate_code')).toBeVisible();

    // Full rotate+DB proof waits on `Auth.mfa_regenerate_backup_codes/2` (see MFASettingsLive TODO).
    // Here we only shift-left the human "can reach the gate" check into CI.
  });
});
