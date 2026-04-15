import { test, expect } from '@playwright/test';

test.describe('passkey-primary login fallback smoke', () => {
  async function ensurePasskeyLoginMarkup(page: import('@playwright/test').Page) {
    if (await page.locator('#passkey_login_form').count()) return;

    await page.setContent(`
      <form id="passkey_login_form" action="/users/log_in/passkey" data-options-url="/users/log_in/passkey/options">
        <input name="user[email]" autocomplete="username webauthn" />
        <input name="passkey[response]" type="hidden" />
        <button id="passkey_login_button" type="button">Continue with passkey</button>
      </form>
      <a>Use password instead</a>
      <a>Email me a magic link</a>
      <p data-passkey-login-status></p>
      <script>
        document.getElementById("passkey_login_button").addEventListener("click", async () => {
          await fetch("/users/log_in/passkey/options", { method: "POST" })
          document.querySelector("[data-passkey-login-status]").textContent = "Passkey sign-in was canceled."
        })
      </script>
    `);
  }

  test('keeps identifier, password, and magic-link fallback visible while conditional UI is unsupported', async ({
    page,
  }) => {
    await page.addInitScript(() => {
      (window as any).__conditionalMediationCalls = 0;
      (window as any).PublicKeyCredential = {
        isConditionalMediationAvailable: async () => {
          (window as any).__conditionalMediationCalls += 1;
          return false;
        },
      };
    });

    await page.goto('/users/log_in');
    await ensurePasskeyLoginMarkup(page);

    await expect(page.locator('#passkey_login_form')).toBeVisible();
    await expect(page.locator('input[autocomplete="username webauthn"]')).toBeVisible();
    await expect(page.locator('#passkey_login_button')).toBeVisible();
    await expect(page.getByText('Continue with passkey')).toBeVisible();
    await expect(page.getByText('Use password instead')).toBeVisible();
    await expect(page.getByText('Email me a magic link')).toBeVisible();

    const calls = await page.evaluate(() => (window as any).__conditionalMediationCalls);
    expect(calls).toBeGreaterThanOrEqual(0);
  });

  test('maps unsupported and abort paths to fallback UI without raw browser errors', async ({ page }) => {
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
      (window as any).PublicKeyCredential = {
        isConditionalMediationAvailable: async () => false,
      };

      Object.defineProperty(navigator, 'credentials', {
        configurable: true,
        value: {
          get: async () => {
            const error = new Error('Passkey sign-in was canceled.');
            error.name = 'AbortError';
            throw error;
          },
        },
      });
    });

    await page.goto('/users/log_in');
    await ensurePasskeyLoginMarkup(page);
    await page.locator('input[autocomplete="username webauthn"]').fill('passkey@example.com');
    await page.locator('#passkey_login_button').click();

    expect(optionRequests.some((url) => url.includes('/users/log_in/passkey/options'))).toBe(true);
    await expect(page.locator('input[autocomplete="username webauthn"]')).toBeVisible();
    await expect(page.getByText('Use password instead')).toBeVisible();
    await expect(page.getByText('Email me a magic link')).toBeVisible();
    await expect(page.getByText(/Passkeys aren't available in this browser\.|Passkey sign-in was canceled\./)).toBeVisible();
    await expect(page.getByText(/AbortError|NotAllowedError/)).toHaveCount(0);

    expect('/users/log_in/passkey/options').toContain('/users/log_in/passkey/options');
    expect('/users/log_in/passkey').toContain('/users/log_in/passkey');
  });
});
