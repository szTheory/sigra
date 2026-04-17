import { test, expect } from "@playwright/test";
import { captureAdminCheckpoint } from "../helpers/adminArtifacts";

// Phase 31 Plan 1: generated-host admin parity smoke.
//
// Per D-03, D-05, D-17, D-20, D-21, D-24, and D-25 this spec stays narrow and
// deterministic. It proves installer/template/runtime parity for the shipped
// admin seams ONLY:
//
//   * shell render on desktop and mobile,
//   * visible scope labels (Global + organization name),
//   * admin navigation presence (desktop sidebar + mobile bottom nav),
//   * allowed organization access (200 + scope label + org-scoped admin content),
//   * denied global admin access (403 + explicit copy),
//   * not-found out-of-scope organization access (404 + explicit copy).
//
// Broader negative-case matrices, sensitive-mutation guards, filter
// permutations, and example-app workflow depth stay outside this spec — they
// are owned by `test/sigra/**`, `test/example/test/**`, and the example-app
// Playwright behavior suite (D-06, D-07, D-15, D-18).

const platformAdminEmail =
  process.env.SIGRA_PLATFORM_ADMIN_EMAIL ?? "platform-admin@example.test";
const orgAdminEmail = process.env.SIGRA_ORG_ADMIN_EMAIL ?? "org-admin@example.test";
const adminPassword =
  process.env.SIGRA_ADMIN_PASSWORD ?? "CorrectHorseBatteryStaple123!";
const allowedOrgSlug = process.env.SIGRA_ALLOWED_ORG_SLUG ?? "allowed-org";
const allowedOrgName = process.env.SIGRA_ALLOWED_ORG_NAME ?? "Allowed Org";
const otherOrgSlug = process.env.SIGRA_OTHER_ORG_SLUG ?? "other-scope";

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };

async function logIn(
  page: Parameters<typeof test>[0]["page"],
  email: string,
  password: string,
) {
  await page.goto("/users/log_in");
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
}

test("generated host admin shell renders on desktop and mobile", async ({
  page,
}, testInfo) => {
  await logIn(page, platformAdminEmail, adminPassword);

  // Desktop shell: Global scope label and admin sidebar navigation.
  await page.setViewportSize(DESKTOP_VIEWPORT);
  await page.goto("/admin");
  await expect(page.locator("header").getByText("Admin", { exact: true })).toBeVisible();
  await expect(page.locator("header")).toContainText("Global");
  await expect(page.locator('nav[aria-label="Admin navigation"]')).toBeVisible();
  await captureAdminCheckpoint(page, testInfo, { name: "shell-global-desktop" });

  // Desktop organization scope: header + main reflect the scoped org.
  await page.goto(`/admin/organizations/${allowedOrgSlug}`);
  await expect(page.locator("header")).toContainText(allowedOrgName);
  await expect(page.locator("main")).toContainText(allowedOrgName);
  await captureAdminCheckpoint(page, testInfo, {
    name: "allowed-org-desktop",
  });

  // Mobile shell: bottom navigation and Global scope still reachable.
  await page.setViewportSize(MOBILE_VIEWPORT);
  await page.goto("/admin");
  await expect(page.locator("header").getByText("Admin", { exact: true })).toBeVisible();
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toBeVisible();
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toContainText(
    "Global",
  );
  await captureAdminCheckpoint(page, testInfo, { name: "shell-global-mobile" });

  // Mobile organization scope: bottom nav stays, header reflects the org.
  await page.goto(`/admin/organizations/${allowedOrgSlug}`);
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toBeVisible();
  await expect(page.locator("header")).toContainText(allowedOrgName);
  await captureAdminCheckpoint(page, testInfo, {
    name: "allowed-org-mobile",
  });
});

test("generated host admin denial responses show explicit copy", async ({
  browser,
}) => {
  // Failure diagnostics are owned by the selective `video: retain-on-failure`
  // policy on the admin-generated project (see playwright.config.ts). This
  // spec intentionally does not attach curated screenshots for the denial
  // paths — green runs already prove shell parity, and denial responses
  // remain reviewable from HTTP status + body copy assertions plus the
  // failure-time screenshot + retained video on regressions (D-21, D-24).
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    await logIn(page, orgAdminEmail, adminPassword);

    // Allowed organization access: org admin can reach its own org scope.
    const allowedResponse = await page.goto(`/admin/organizations/${allowedOrgSlug}`);
    expect(allowedResponse?.status()).toBe(200);
    await expect(page.locator("header")).toContainText(allowedOrgName);

    // Denied global admin access: org admin is blocked at /admin with
    // explicit insufficient-scope copy (not a blank body).
    const forbiddenResponse = await page.goto("/admin");
    expect(forbiddenResponse?.status()).toBe(403);
    await expect(page.locator("body")).toContainText(
      "Access denied. You do not have access to this admin scope.",
    );
    await expect(page.locator("body")).not.toHaveText(/^\s*$/);

    // Not-found out-of-scope organization: org admin hits 404 with explicit
    // not-found copy, never a 403 that would leak org existence.
    const notFoundResponse = await page.goto(`/admin/organizations/${otherOrgSlug}`);
    expect(notFoundResponse?.status()).toBe(404);
    await expect(page.locator("body")).toContainText(
      "Not found. This organization admin scope is unavailable.",
    );
    await expect(page.locator("body")).not.toHaveText(/^\s*$/);
  } finally {
    await context.close();
  }
});
