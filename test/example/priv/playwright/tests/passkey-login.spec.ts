import { test, expect } from "@playwright/test";
import { extractConfirmationLink } from "../fixtures/mailbox";

async function waitForLiveViewReady(page: Parameters<typeof test>[0]["page"]) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}

async function registerUserForPasskeyBootstrap(
  page: Parameters<typeof test>[0]["page"],
  email: string,
  password: string,
) {
  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.check('input[name="user[enroll_passkey]"]');
  await page.click('button:has-text("Create an account")');
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function confirmSignupForPasskeyBootstrap(
  page: Parameters<typeof test>[0]["page"],
  email: string,
) {
  const confirmHref = await extractConfirmationLink(page, email);
  expect(confirmHref).toContain("/users/confirm/");

  await page.context().clearCookies();
  await page.goto(confirmHref);
  await expect(page).toHaveURL(/\/users\/sudo\?return_to=/);
}

async function finishSudoForMfaSettings(
  page: Parameters<typeof test>[0]["page"],
  password: string,
) {
  if (!page.url().includes("/users/sudo")) {
    await page.goto("/users/sudo?return_to=%2Fusers%2Fsettings%2Fmfa");
  }

  await page.fill('input[name="sudo[password]"]', password);
  await page.click('button:has-text("Confirm password")');
  await expect(page).toHaveURL(/\/users\/settings\/mfa/);
  await waitForLiveViewReady(page);
}

async function addVirtualAuthenticator(
  page: Parameters<typeof test>[0]["page"],
) {
  const client = await page.context().newCDPSession(page);
  await client.send("WebAuthn.enable");

  const { authenticatorId } = await client.send("WebAuthn.addVirtualAuthenticator", {
    options: {
      protocol: "ctap2",
      transport: "internal",
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  });

  return {
    async close() {
      await client.send("WebAuthn.removeVirtualAuthenticator", {
        authenticatorId,
      });
      await client.send("WebAuthn.disable");
    },
  };
}

async function enrollPasskeyFromSettings(
  page: Parameters<typeof test>[0]["page"],
  password: string,
) {
  if (!page.url().includes("/users/settings/mfa")) {
    await finishSudoForMfaSettings(page, password);
  } else {
    await waitForLiveViewReady(page);
  }

  await expect(page.getByRole("heading", { name: "Passkeys" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Add passkey" })).toBeVisible();
  const [optionsResponse, completionResponse] = await Promise.all([
    page.waitForResponse(
      (response) =>
        response.url().includes("/users/settings/mfa/passkeys/options") &&
        response.request().method() === "POST",
    ),
    page.waitForResponse(
      (response) =>
        response.url().includes("/users/settings/mfa/passkeys") &&
        !response.url().includes("/options") &&
        response.request().method() === "POST",
    ),
    page.locator("#add-passkey-button").click(),
  ]);

  expect(optionsResponse.status()).toBe(200);
  expect(completionResponse.status()).toBe(302);

  await page.waitForURL(/\/users\/settings\/mfa/);
  await page.waitForLoadState("networkidle");
  await expect(page.locator("#passkeys")).not.toContainText("No passkeys added yet");
}

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
    const email = `passkey-login-${Date.now()}@example.test`;
    const password = "CorrectHorseBatteryStaple123!";
    const authenticator = await addVirtualAuthenticator(page);

    try {
      await registerUserForPasskeyBootstrap(page, email, password);
      await confirmSignupForPasskeyBootstrap(page, email);
      await enrollPasskeyFromSettings(page, password);

      await page.context().clearCookies();
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

      await page.locator('input[autocomplete="username webauthn"]').fill(email);

      const [optionsResponse] = await Promise.all([
        page.waitForResponse(
          (response) =>
            response.url().includes("/users/log_in/passkey/options") &&
            response.request().method() === "POST" &&
            response.request().postData()?.includes(email) === true,
        ),
        page.locator("#passkey_login_button").click(),
      ]);

      expect(optionsResponse.status()).toBe(200);
      expect(optionsResponse.request().postData()).toContain(email);

      await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
      await expect(page.getByText(/AbortError|NotAllowedError/)).toHaveCount(0);
    } finally {
      await authenticator.close();
    }
  });
});
