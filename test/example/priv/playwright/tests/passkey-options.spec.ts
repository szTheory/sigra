import { test, expect } from "@playwright/test";

test("enrollment requests real passkey options from the served MFA settings page", async ({
  page,
}) => {
  const email = `passkey-options-${Date.now()}@example.test`;
  const password = "CorrectHorseBatteryStaple123!";

  await page.goto("/users/register");
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');

  await page.goto("/users/sudo?return_to=%2Fusers%2Fsettings%2Fmfa");
  await page.fill('input[name="sudo[password]"]', password);
  await page.click('button:has-text("Confirm password")');

  const optionsResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/users/settings/mfa/passkeys/options") &&
      response.request().method() === "POST",
  );

  await page.locator("#add-passkey-button").click();

  const optionsResponse = await optionsResponsePromise;
  expect(optionsResponse.status()).toBe(200);

  const optionsBody = await optionsResponse.json();
  expect(optionsBody.options.challenge).toBeTruthy();
  expect(optionsBody.options.rp.id).toBe("localhost");
});
