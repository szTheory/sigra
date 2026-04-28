import { expect, test } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { authenticator } from 'otplib';
import { extractConfirmationLink } from '../fixtures/mailbox';
import { probeAuditEvent, probeBackupCodeValidity } from '../fixtures/oauthIssuer';

const evidenceDir = path.resolve(
  __dirname,
  '../../../../../.planning/uat-evidence/v1.20/mfa-backup-rotation',
);

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

async function waitForAuditEvent(
  page: import('@playwright/test').Page,
  userEmail: string,
  action: string,
) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const result = await probeAuditEvent(page, userEmail, action);
    if (result.count > 0) {
      return result;
    }

    await page.waitForTimeout(500);
  }

  throw new Error(`audit event ${action} not found for ${userEmail}`);
}

async function nextTotpCode(
  page: import('@playwright/test').Page,
  secret: string,
  previousCode: string,
) {
  for (let attempt = 0; attempt < 35; attempt += 1) {
    const currentCode = authenticator.generate(secret);

    if (currentCode !== previousCode) {
      return currentCode;
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error('timed out waiting for next TOTP code');
}

test('GAUAT-07: MFA backup-code rotation invalidates old plaintext codes and persists audit proof', async ({
  page,
}) => {
  const email = `ga-uat-07-${Date.now()}@example.test`;
  const password = 'CorrectHorseBatteryStaple123!';
  const transcript: string[] = [];

  const mark = (label: string) => {
    transcript.push(`${new Date().toISOString()} ${label}`);
  };

  mark('START register-and-confirm');
  await registerAndConfirm(page, email, password);
  await logInIfNeeded(page, email, password);

  mark('SUDO confirm-password');
  await page.goto('/users/sudo');
  await page.fill('input[name="sudo[password]"]', password);
  await page.click('button:has-text("Confirm password")');
  await expect(page).not.toHaveURL(/\/users\/sudo(\?|$)/);

  mark('MFA enroll begin');
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

  const initialCodes = await page.locator('ol li code').allInnerTexts();
  expect(initialCodes.length).toBeGreaterThanOrEqual(8);
  const preRotationCode = initialCodes[0];
  mark(`MFA enroll complete pre_rotation_code=${preRotationCode}`);

  await page.getByLabel(/i have saved these backup codes/i).check();
  await page.getByRole('button', { name: 'Done' }).click();
  await expect(page.getByRole('button', { name: /^Disable$/i }).first()).toBeVisible();

  mark('MFA rotate begin');
  await page.getByRole('button', { name: 'Regenerate codes' }).first().click();
  await expect(page.locator('#mfa_regenerate_form')).toBeVisible();

  const regenerateCode = await nextTotpCode(page, secret, enrollCode);
  await page.fill('#mfa_regenerate_form input[name="regenerate[code]"]', regenerateCode);
  await page.getByRole('button', { name: 'Regenerate codes' }).last().click();

  await expect(page.locator('#mfa_regenerate_form')).toHaveCount(0);
  await expect(
    page.getByRole('heading', { name: 'Save your backup codes' }).first(),
  ).toBeVisible();

  const rotatedCodes = await page.locator('ol li code').allInnerTexts();
  expect(rotatedCodes.length).toBeGreaterThanOrEqual(8);
  expect(rotatedCodes).not.toContain(preRotationCode);
  mark('MFA rotate complete');

  const oldCodeValidity = await probeBackupCodeValidity(page, email, preRotationCode);
  expect(oldCodeValidity.current_match).toBe(false);

  const auditEvent = await waitForAuditEvent(page, email, 'mfa.backup_codes_regenerate');
  expect(auditEvent.rows[0].outcome).toBe('success');

  await mkdir(path.join(evidenceDir, 'reports'), { recursive: true });
  await writeFile(path.join(evidenceDir, 'transcript.log'), `${transcript.join('\n')}\n`, 'utf8');
  await writeFile(
    path.join(evidenceDir, 'reports', 'old-code-validity.json'),
    JSON.stringify(
      {
        user_email: email,
        pre_rotation_code: preRotationCode,
        current_match: oldCodeValidity.current_match,
        remaining: oldCodeValidity.remaining,
        hash_prefix: oldCodeValidity.hash_prefix,
      },
      null,
      2,
    ),
    'utf8',
  );
  await writeFile(
    path.join(evidenceDir, 'reports', 'audit-event.json'),
    JSON.stringify(auditEvent, null, 2),
    'utf8',
  );
  await writeFile(
    path.join(evidenceDir, 'reports', 'ui-summary.json'),
    JSON.stringify(
      {
        pre_rotation_count: initialCodes.length,
        post_rotation_count: rotatedCodes.length,
        disable_visible_after_enrollment: true,
        regenerate_form_visible: true,
        regenerate_form_closed_after_submit: true,
        backup_codes_heading_visible_after_rotation: true,
      },
      null,
      2,
    ),
    'utf8',
  );
});
