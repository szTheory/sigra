import { test, expect } from "@playwright/test";

test.describe("passkey-primary login fallback smoke", () => {
  test("keeps identifier, password, and magic-link fallback visible on the real login page", async ({
    page,
  }) => {
    await page.goto("/users/log_in");

    await expect(page.locator("#passkey_login_form")).toBeVisible();
    await expect(
      page.locator('input[autocomplete="username webauthn"]'),
    ).toBeVisible();
    await expect(page.locator("#passkey_login_button")).toBeVisible();
    await expect(page.getByText("Continue with passkey")).toBeVisible();
    await expect(page.getByText("Use password instead")).toBeVisible();
    await expect(page.getByText("Email me a magic link")).toBeVisible();
  });

  test("clicking passkey login requests real options path without leaking browser errors", async ({
    page,
  }) => {
    await page.addInitScript(() => {
      (window as any).SigraPasskeys = {
        authenticate: async ({
          optionsUrl,
          email,
        }: {
          optionsUrl: string;
          email: string;
        }) => {
          const csrfToken =
            document
              .querySelector("meta[name='csrf-token']")
              ?.getAttribute("content") || "";

          const response = await fetch(optionsUrl, {
            method: "POST",
            headers: {
              "content-type": "application/json",
              accept: "text/html,application/xhtml+xml",
              "x-csrf-token": csrfToken,
            },
            body: JSON.stringify({ user: { email } }),
          });

          await response.json();

          return null;
        },
      };
    });

    await page.goto("/users/log_in");
    await page
      .locator('input[autocomplete="username webauthn"]')
      .fill("passkey@example.com");

    const optionsResponsePromise = page.waitForResponse(
      (response) =>
        response.url().includes("/users/log_in/passkey/options") &&
        response.request().method() === "POST",
    );

    await page.locator("#passkey_login_button").click();

    const optionsResponse = await optionsResponsePromise;
    expect(optionsResponse.status()).toBe(200);

    const optionsBody = await optionsResponse.json();
    expect(optionsBody).toEqual({ error: "unavailable" });

    await expect(
      page.locator('input[autocomplete="username webauthn"]'),
    ).toBeVisible();
    await expect(page.getByText("Use password instead")).toBeVisible();
    await expect(page.getByText("Email me a magic link")).toBeVisible();
    await expect(page.getByText(/AbortError|NotAllowedError/)).toHaveCount(0);
  });
});
