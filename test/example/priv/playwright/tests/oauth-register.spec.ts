import { expect, test } from '@playwright/test';
import { probeIdentities, resetIssuer, setupIssuer } from '../fixtures/oauthIssuer';

test('GAUAT-04: Google OAuth registers, logs in, logs out, and re-logs without duplicating identities', async ({
  page,
}) => {
  const stamp = Date.now();
  const email = `oauth-register-${stamp}@example.test`;
  const sub = `google-register-${stamp}`;

  await page.goto('/');
  await setupIssuer(page, {
    sub,
    email,
    email_verified: true,
    name: 'OAuth Register',
  });

  try {
    await page.goto('/users/log_in');
    await expect(page.getByRole('link', { name: 'Continue with Google' })).toBeVisible();

    await page.getByRole('link', { name: 'Continue with Google' }).click();
    await expect(page).toHaveURL('/');

    const identitiesAfterRegister = await probeIdentities(page, email);
    expect(identitiesAfterRegister.count).toBe(1);
    expect(identitiesAfterRegister.rows[0]).toEqual({
      provider: 'google',
      provider_uid: sub,
    });

    await page.context().clearCookies();
    await page.goto('/users/settings');
    await expect(page).toHaveURL(/\/users\/log_in/);

    await page.getByRole('link', { name: 'Continue with Google' }).click();
    await expect(page).toHaveURL('/');

    const identitiesAfterRelogin = await probeIdentities(page, email);
    expect(identitiesAfterRelogin.count).toBe(1);
    expect(identitiesAfterRelogin.rows[0]).toEqual({
      provider: 'google',
      provider_uid: sub,
    });
  } finally {
    await resetIssuer(page);
  }
});
