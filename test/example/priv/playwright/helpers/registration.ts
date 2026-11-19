import { expect, type Page } from "@playwright/test";
import { loginSubmit } from "./loginSubmit";

export const GENERIC_REGISTRATION_RESPONSE =
  "If an account can be created for this email, check for any confirmation instructions, then sign in.";

export async function assertGenericRegistrationResponse(page: Page) {
  await expect(page).toHaveURL(/\/users\/register(?:\?.*)?$/);
  await expect(
    page.getByText(GENERIC_REGISTRATION_RESPONSE, { exact: true }),
  ).toBeVisible();
}

export async function signInManually(page: Page, email: string, password: string) {
  await page.goto("/users/log_in");
  const loginEmail = page.locator('#login_form input[name="user[email]"]');

  // Generated hosts with passkey-first sign-in keep password login inside a
  // closed disclosure. Open that path before interacting with the form.
  if (!(await loginEmail.isVisible())) {
    const passwordDisclosure = page
      .locator("details")
      .filter({ has: page.locator("#login_form") });

    if (await passwordDisclosure.count()) {
      await passwordDisclosure.locator("summary").click();
    }
  }

  await expect(loginEmail).toBeVisible();
  await loginEmail.fill(email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await loginSubmit(page).click();
  await expect(page).not.toHaveURL(/\/users\/log_in(?:\?.*)?$/);
}
