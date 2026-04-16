import { test, expect } from "@playwright/test";

test.describe("passkey-primary login fallback smoke", () => {
  test("keeps identifier, password, and magic-link fallback visible on the real login page", async ({
    page,
  }) => {
    await page.goto("/users/log_in");

    const runtimeState = await page.evaluate(() => {
      const runtime = (window as typeof window & {
        SigraPasskeyRuntime?: {
          PasskeyRegister?: unknown;
          PasskeyAuthenticate?: unknown;
          attachPasskeyLogin?: unknown;
        };
        liveSocket?: {
          hooks?: Record<string, unknown>;
        };
      }).SigraPasskeyRuntime;
      const liveSocket = (window as typeof window & {
        liveSocket?: {
          hooks?: Record<string, unknown>;
        };
      }).liveSocket;

      return {
        hasRuntime: Boolean(runtime),
        registerMountedType:
          typeof (runtime?.PasskeyRegister as { mounted?: unknown } | undefined)
            ?.mounted,
        authenticateMountedType:
          typeof (
            runtime?.PasskeyAuthenticate as { mounted?: unknown } | undefined
          )?.mounted,
        attachType: typeof runtime?.attachPasskeyLogin,
        hasRegisterHook: Boolean(liveSocket?.hooks?.PasskeyRegister),
        hasAuthenticateHook: Boolean(liveSocket?.hooks?.PasskeyAuthenticate),
      };
    });

    await expect(page.locator("#passkey_login_form")).toBeVisible();
    await expect(
      page.locator('input[autocomplete="username webauthn"]'),
    ).toBeVisible();
    await expect(page.locator("#passkey_login_button")).toBeVisible();
    await expect(page.getByText("Continue with passkey")).toBeVisible();
    await expect(page.getByText("Use password instead")).toBeVisible();
    await expect(page.getByText("Email me a magic link")).toBeVisible();
    expect(runtimeState).toEqual({
      hasRuntime: true,
      registerMountedType: "function",
      authenticateMountedType: "function",
      attachType: "function",
      hasRegisterHook: true,
      hasAuthenticateHook: true,
    });
  });

  test("clicking passkey login requests real options path without leaking browser errors", async ({
    page,
  }) => {
    await page.goto("/users/log_in");

    const runtimeState = await page.evaluate(() => {
      const runtime = (window as typeof window & {
        SigraPasskeyRuntime?: {
          PasskeyAuthenticate?: unknown;
          attachPasskeyLogin?: unknown;
        };
        liveSocket?: {
          hooks?: Record<string, unknown>;
        };
      }).SigraPasskeyRuntime;
      const liveSocket = (window as typeof window & {
        liveSocket?: {
          hooks?: Record<string, unknown>;
        };
      }).liveSocket;

      return {
        authenticateMountedType:
          typeof (
            runtime?.PasskeyAuthenticate as { mounted?: unknown } | undefined
          )?.mounted,
        attachType: typeof runtime?.attachPasskeyLogin,
        hasAuthenticateHook: Boolean(liveSocket?.hooks?.PasskeyAuthenticate),
      };
    });

    expect(runtimeState).toEqual({
      authenticateMountedType: "function",
      attachType: "function",
      hasAuthenticateHook: true,
    });

    await page
      .locator('input[autocomplete="username webauthn"]')
      .fill("passkey@example.com");

    const optionsResponsePromise = page.waitForResponse(
      (response) =>
        response.url().includes("/users/log_in/passkey/options") &&
        response.request().method() === "POST" &&
        response.request().postData()?.includes("passkey@example.com") === true,
    );

    await page.locator("#passkey_login_button").click();

    const optionsResponse = await optionsResponsePromise;
    expect(optionsResponse.status()).toBe(200);
    expect(optionsResponse.request().method()).toBe("POST");
    expect(optionsResponse.request().postData()).toContain("passkey@example.com");

    const optionsBody = await optionsResponse.json();
    expect(optionsBody.options.challenge).toBeTruthy();
    expect(optionsBody.options.rpId).toBe("localhost");

    await expect(
      page.locator('input[autocomplete="username webauthn"]'),
    ).toBeVisible();
    await expect(page.locator("#passkey_login_button")).toBeVisible();
    await expect(page.getByText("Use password instead")).toBeVisible();
    await expect(page.getByText("Email me a magic link")).toBeVisible();
    await expect(page.getByText(/AbortError|NotAllowedError/)).toHaveCount(0);
  });
});
