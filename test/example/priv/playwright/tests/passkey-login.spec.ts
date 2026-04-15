import { test, expect } from '@playwright/test';

test.describe('passkey-primary login fallback smoke', () => {
  test('keeps identifier, password, and magic-link fallback visible on the real login page', async ({
    page,
  }) => {
    await page.goto('/users/log_in');

    await expect(page.locator('#passkey_login_form')).toBeVisible();
    await expect(page.locator('input[autocomplete="username webauthn"]')).toBeVisible();
    await expect(page.locator('#passkey_login_button')).toBeVisible();
    await expect(page.getByText('Continue with passkey')).toBeVisible();
    await expect(page.getByText('Use password instead')).toBeVisible();
    await expect(page.getByText('Email me a magic link')).toBeVisible();
  });

  test('clicking passkey login requests real options path without leaking browser errors', async ({
    page,
  }) => {
    const optionRequests: string[] = [];

    await page.route('**/users/log_in/passkey/options', async (route) => {
      optionRequests.push(route.request().url());

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          options: {
            challenge: 'Y2hhbGxlbmdl',
            rpId: 'localhost',
            timeout: 60000,
            userVerification: 'preferred',
            allowCredentials: [],
          },
        }),
      });
    });

    await page.addInitScript(() => {
      (window as any).SigraPasskeys = {
        authenticate: async ({ optionsUrl, email }: { optionsUrl: string; email: string }) => {
          await fetch(optionsUrl, {
            method: 'POST',
            headers: {
              'content-type': 'application/json',
              accept: 'application/json',
            },
            body: JSON.stringify({ user: { email } }),
          });

          return null;
        },
      };
    });

    await page.goto('/users/log_in');
    await page.locator('input[autocomplete="username webauthn"]').fill('passkey@example.com');
    await page.locator('#passkey_login_button').click();

    await expect.poll(() => optionRequests.length).toBe(1);
    expect(optionRequests[0]).toContain('/users/log_in/passkey/options');

    await expect(page.locator('input[autocomplete="username webauthn"]')).toBeVisible();
    await expect(page.getByText('Use password instead')).toBeVisible();
    await expect(page.getByText('Email me a magic link')).toBeVisible();
    await expect(page.getByText(/AbortError|NotAllowedError/)).toHaveCount(0);
  });
});
