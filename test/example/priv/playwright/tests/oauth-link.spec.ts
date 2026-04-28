import { expect, test } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';
import { probeIdentities, resetIssuer, setupIssuer } from '../fixtures/oauthIssuer';

const HERO_SNAPSHOT = 'oauth-link__disabled-tooltip.png';

async function waitForLiveViewReady(page: import('@playwright/test').Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function registerAndConfirm(page: import('@playwright/test').Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.locator('#registration_form_email').fill(email);
  await page.locator('#registration_form_password').fill(password);
  await expect(page.locator('#registration_form_email')).toHaveValue(email);
  await page.getByRole('button', { name: 'Create an account' }).click();
  await expect(page).toHaveURL('/');

  const confirmHref = await extractConfirmationLink(page, email);
  await page.goto(confirmHref);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);
}

async function logInWithPassword(
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

function linkedMetadataLocator(page: import('@playwright/test').Page) {
  return page.locator('.text-sm.text-gray-500').filter({ hasText: 'Linked' }).first();
}

function linkedIdentityDetailsLocator(page: import('@playwright/test').Page) {
  return page.locator('.flex.items-start.justify-between > div').first();
}

function flashGroupLocator(page: import('@playwright/test').Page) {
  return page.locator('#flash-group');
}

test.describe('GAUAT-05: OAuth linking and unlink protection', () => {
  test('linked-with-password: unlink is enabled after linking Google to a password account', async ({
    page,
  }) => {
    const stamp = Date.now();
    const email = `oauth-link-password-${stamp}@example.test`;
    const password = 'CorrectHorseBatteryStaple123!';
    const sub = `oauth-link-password-${stamp}`;

    await page.goto('/');
    await registerAndConfirm(page, email, password);
    await logInWithPassword(page, email, password);
    await setupIssuer(page, { sub, email, email_verified: true, name: 'Linked Password User' });

    try {
      await page.goto('/users/settings');
      await page.getByRole('link', { name: 'Continue with Google' }).click();
      await expect(page).toHaveURL('/');

      await page.goto('/users/settings');
      const unlinkButton = page.getByRole('button', { name: 'Unlink' });
      await expect(unlinkButton).toBeVisible();
      await expect(unlinkButton).not.toHaveAttribute('title', /.+/);

      const identities = await probeIdentities(page, email);
      expect(identities.count).toBe(1);
      expect(identities.rows[0].provider_uid).toBe(sub);
    } finally {
      await resetIssuer(page);
    }
  });

  test('oauth-only account: disabled tooltip, hero snapshot, set-password flip, unlink, and password login', async ({
    page,
  }) => {
    const stamp = Date.now();
    const email = `oauth-link-oauth-only-${stamp}@example.test`;
    const password = 'CorrectHorseBatteryStaple123!';
    const sub = `oauth-link-oauth-only-${stamp}`;

    await page.goto('/');
    await setupIssuer(page, { sub, email, email_verified: true, name: 'OAuth Only User' });

    try {
      await page.goto('/users/log_in');
      await page.getByRole('link', { name: 'Continue with Google' }).click();
      await expect(page).toHaveURL('/');

      await page.goto('/users/settings');
      const disabledUnlink = page.getByRole('button', { name: 'Unlink' });
      await expect(disabledUnlink).toBeDisabled();
      await expect(disabledUnlink).toHaveAttribute(
        'title',
        'Set a password first to keep access to your account.',
      );
      await expect(page).toHaveScreenshot(HERO_SNAPSHOT, {
        fullPage: true,
        maxDiffPixels: 1_000,
        mask: [linkedIdentityDetailsLocator(page), linkedMetadataLocator(page)],
      });

      await page.fill('input[name="user[password]"]', password);
      await page.fill('input[name="user[password_confirmation]"]', password);
      await page.click('button:has-text("Set password")');
      await expect(page).toHaveURL(/\/users\/settings/);
      await expect(flashGroupLocator(page).getByText('Password set.', { exact: true })).toBeVisible();

      const enabledUnlink = page.getByRole('button', { name: 'Unlink' });
      await expect(enabledUnlink).toBeVisible();

      page.once('dialog', (dialog) => dialog.accept());
      await enabledUnlink.click();
      await expect(flashGroupLocator(page).getByText('Provider unlinked.', { exact: true })).toBeVisible();

      const identities = await probeIdentities(page, email);
      expect(identities.count).toBe(0);

      await page.context().clearCookies();
      await logInWithPassword(page, email, password);
      await expect(page).toHaveURL('/');
    } finally {
      await resetIssuer(page);
    }
  });
});
