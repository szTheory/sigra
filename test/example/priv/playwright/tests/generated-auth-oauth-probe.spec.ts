import { expect, test, type Page } from "@playwright/test";

const collisionEmail = "oauth-collision@example.test";
const password = "CorrectHorseBatteryStaple123!";

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", { state: "attached" });
}

async function logOut(page: Page) {
  await page.getByRole("link", { name: /log out/i }).click();
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
}

test("generated /auth/google preserves signed state and PKCE through the loopback OIDC collision path", async ({ page }) => {
  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.getByLabel("Email", { exact: true }).fill(collisionEmail);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Create an account" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByText("Account created successfully!", { exact: true })).toBeVisible();
  await logOut(page);

  const authorization = page.waitForRequest((request) => request.url().includes("/oidc/authorize"));
  await page.goto("/auth/google");
  const request = await authorization;
  const authorizationUrl = new URL(request.url());
  expect(authorizationUrl.hostname).toBe("127.0.0.1");
  expect(authorizationUrl.pathname).toBe("/oidc/authorize");
  expect(authorizationUrl.searchParams.get("state")).toMatch(/^.+\..+$/);
  expect(authorizationUrl.searchParams.get("code_challenge")).toMatch(/^[A-Za-z0-9_-]{43}$/);
  expect(authorizationUrl.searchParams.get("code_challenge_method")).toBe("S256");
  expect(authorizationUrl.searchParams.has("nonce")).toBe(false);

  await expect(page).toHaveURL(/\/users\/log_in/);
  await expect(page.getByText("An account with this email exists. Log in to link your google account.", { exact: true })).toBeVisible();
});
