import { test, expect } from "@playwright/test";

async function waitForLiveViewReady(page: Parameters<typeof test>[0]["page"]) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}

async function registerAndAuthenticateUser(
  page: Parameters<typeof test>[0]["page"],
  email: string,
  password: string,
) {
  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');
  await expect(page).not.toHaveURL(/\/users\/register/);

  await page.goto("/users/log_in");

  if (page.url().includes("/users/log_in")) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }
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

test("enrollment requests real passkey options from the served MFA settings page", async ({
  page,
}) => {
  const email = `passkey-options-${Date.now()}@example.test`;
  const password = "CorrectHorseBatteryStaple123!";
  const authenticator = await addVirtualAuthenticator(page);

  try {
    await registerAndAuthenticateUser(page, email, password);

    await page.goto("/users/sudo?return_to=%2Fusers%2Fsettings%2Fmfa");
    await page.fill('input[name="sudo[password]"]', password);
    await page.click('button:has-text("Confirm password")');
    await expect(page).toHaveURL(/\/users\/settings\/mfa/);
    await waitForLiveViewReady(page);

    const [optionsResponse] = await Promise.all([
      page.waitForResponse(
        (response) =>
          response.url().includes("/users/settings/mfa/passkeys/options") &&
          response.request().method() === "POST",
      ),
      page.locator("#add-passkey-button").click(),
    ]);

    expect(optionsResponse.status()).toBe(200);

    const optionsBody = await optionsResponse.json();
    expect(optionsBody.options.challenge).toBeTruthy();
    expect(optionsBody.options.rp.id).toBe("localhost");
    expect(optionsBody.options.user.id).toBeTruthy();
  } finally {
    await authenticator.close();
  }
});
