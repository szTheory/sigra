import { test, expect, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { captureAdminCheckpoint } from "../helpers/adminArtifacts";
import { adminUsersEmailLocator } from "../helpers/adminUsersIndex";
import { TEST_PASSWORD } from "../helpers/fixtures";

// Generated-host admin and adopter-experience parity smoke.
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
const orgAdminEmail =
  process.env.SIGRA_ORG_ADMIN_EMAIL ?? "org-admin@example.test";
const adminPassword = process.env.SIGRA_ADMIN_PASSWORD ?? TEST_PASSWORD;
const allowedOrgSlug = process.env.SIGRA_ALLOWED_ORG_SLUG ?? "allowed-org";
const allowedOrgName = process.env.SIGRA_ALLOWED_ORG_NAME ?? "Allowed Org";
const otherOrgSlug = process.env.SIGRA_OTHER_ORG_SLUG ?? "other-scope";
const impersonationTargetEmail =
  process.env.SIGRA_IMPERSONATION_TARGET_EMAIL ??
  "impersonation-target@example.test";

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}

async function confirmSudo(page: Page, password: string) {
  await expect(page).toHaveURL(/\/users\/sudo\?/);
  // Ratified copy per installer template sudo_html.ex and example sudo_html.ex.
  // The old heading was stale; reconciled to "Re-enter your password" (Phase 208.1-02).
  await expect(
    page.getByRole("heading", { name: "Re-enter your password" }),
  ).toBeVisible();
  await page.fill('input[name="sudo[password]"]', password);
  await page.getByRole("button", { name: "Confirm password" }).click();
}

/** Admin shell chrome (avoids inner LiveView `<header>` on nested admin pages). */
function adminShellHeader(page: Page) {
  return page.locator("header").filter({ hasText: "Admin" }).first();
}

async function logIn(
  page: Parameters<typeof test>[0]["page"],
  email: string,
  password: string,
) {
  await page.goto("/users/log_in");
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
  await page.locator("details.sigra-auth-disclosure > summary").click();
  const passwordForm = page.locator("#login_form");
  await passwordForm.getByLabel("Email", { exact: true }).fill(email);
  await passwordForm.getByLabel("Password", { exact: true }).fill(password);
  await passwordForm
    .getByRole("button", { name: "Sign in with password" })
    .click();
  await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
}

test("generated auth shell communicates hierarchy and survives theme and reflow states", async ({
  page,
}, testInfo) => {
  await page.setViewportSize(DESKTOP_VIEWPORT);
  await page.goto("/users/log_in");

  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Email me a sign-in link" }),
  ).toBeVisible();

  const alternatives = page.locator("details.sigra-auth-disclosure");
  await expect(alternatives).not.toHaveAttribute("open", "");
  const alternativesSummary = alternatives.locator("summary");
  for (let index = 0; index < 4; index += 1) {
    await page.keyboard.press("Tab");
  }
  await expect(alternativesSummary).toBeFocused();
  await expect(alternativesSummary).not.toHaveCSS("box-shadow", "none");
  await page.keyboard.press("Enter");
  await expect(alternatives).toHaveAttribute("open", "");
  await expect(
    page.getByRole("button", { name: "Sign in with password" }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Work sign-in" }),
  ).toBeVisible();

  const authAssetBudget = await page.evaluate(() => {
    const entries = performance
      .getEntriesByType("resource")
      .filter((entry) => new URL(entry.name).pathname.endsWith("/sigra_auth.css")) as PerformanceResourceTiming[];

    return {
      count: entries.length,
      decodedBytes: entries.reduce((sum, entry) => sum + entry.decodedBodySize, 0),
    };
  });
  expect(authAssetBudget.count).toBe(1);
  expect(authAssetBudget.decodedBytes).toBeLessThanOrEqual(35_000);

  const authRoot = page.locator("main.sigra-auth");
  await expect(authRoot).toHaveAttribute("data-theme", "system");
  await page.emulateMedia({ reducedMotion: "reduce" });

  const themeSnapshot = async (theme: "light" | "dark" | "system") => {
    await authRoot.evaluate((element, value) => {
      element.setAttribute("data-theme", value);
    }, theme);

    return authRoot.evaluate((element) => {
      const style = getComputedStyle(element);
      return {
        background: style.getPropertyValue("--sigra-auth-bg").trim(),
        colorScheme: style.colorScheme,
      };
    });
  };

  const light = await themeSnapshot("light");
  await captureAdminCheckpoint(page, testInfo, {
    name: "auth-login-light-desktop",
    prefix: "auth",
  });
  const dark = await themeSnapshot("dark");
  expect(light.colorScheme).toBe("light");
  expect(dark.colorScheme).toBe("dark");
  expect(dark.background).not.toBe(light.background);

  await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
  const systemDark = await themeSnapshot("system");
  expect(systemDark.colorScheme).toBe("dark");
  await captureAdminCheckpoint(page, testInfo, {
    name: "auth-login-system-dark-desktop",
    prefix: "auth",
  });
  const reducedTransitionSeconds = await page
    .getByRole("button", { name: "Email me a sign-in link" })
    .evaluate((element) => parseFloat(getComputedStyle(element).transitionDuration));
  expect(reducedTransitionSeconds).toBeLessThanOrEqual(0.001);

  const { violations } = await new AxeBuilder({ page })
    .include("main.sigra-auth")
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  expect(
    violations,
    `generated auth post-disclosure axe violations: ${JSON.stringify(violations).slice(0, 2000)}`,
  ).toHaveLength(0);

  await page.setViewportSize({ width: 320, height: 800 });
  await page.locator("html").evaluate((element) => {
    element.style.fontSize = "32px";
  });
  await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();

  // GATE-02 / D-09: instrumented in place of the bare boolean assertion so
  // every run -- pass or fail -- reports what it measured. See
  // 231-02-DIAGNOSIS.md for the verdict this payload shape produced.
  // offenders is capped at 15 entries so a pathological page cannot flood
  // the job log; classList is used (not className) because className is an
  // SVGAnimatedString on SVG elements and string methods throw on it (the
  // same defect class plan 231-04 fixes in probes.ts).
  const reflowPayload = await page.evaluate(() => {
    const offenders: Array<{ tag: string; cls: string; right: number }> = [];
    for (const element of Array.from(document.querySelectorAll("*"))) {
      const rect = element.getBoundingClientRect();
      if (rect.right > window.innerWidth + 1) {
        offenders.push({
          tag: element.tagName,
          cls: Array.from(element.classList).join(" "),
          right: rect.right,
        });
        if (offenders.length >= 15) break;
      }
    }
    return {
      innerWidth: window.innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
      offenders,
    };
  });
  console.log(`gate02-reflow-instrumentation ${JSON.stringify(reflowPayload)}`);
  expect(
    reflowPayload.scrollWidth,
    `320px reflow: ${JSON.stringify(reflowPayload)}`,
  ).toBeLessThanOrEqual(reflowPayload.innerWidth);

  await captureAdminCheckpoint(page, testInfo, {
    name: "auth-login-system-dark-320-reflow",
    prefix: "auth",
  });
});

test("generated host admin shell renders on desktop and mobile", async ({
  page,
}, testInfo) => {
  await logIn(page, platformAdminEmail, adminPassword);

  // Desktop shell: Global scope label and admin sidebar navigation.
  await page.setViewportSize(DESKTOP_VIEWPORT);
  await page.goto("/admin");
  await expect(
    adminShellHeader(page).getByText("Admin", { exact: true }),
  ).toBeVisible();
  await expect(adminShellHeader(page)).toContainText("Global");
  await expect(
    page.locator('nav[aria-label="Admin navigation"]'),
  ).toBeVisible();
  await expect(
    page.locator('nav[aria-label="Admin navigation"]'),
  ).toContainText("Branding");
  // DIST-06: proves sigra_admin.css :root token block loaded
  // (the brand token is defined only in sigra_admin.css, not in default.css or app.css)
  const brandColor = await page.evaluate(
    () =>
      getComputedStyle(document.documentElement)
        .getPropertyValue("--sg-color-brand")
        .trim(),
  );
  expect(brandColor).toBe("#c2410c");
  await captureAdminCheckpoint(page, testInfo, {
    name: "shell-global-desktop",
  });

  // Auth branding customizer: generated-host route, form, and previews.
  await page
    .locator('nav[aria-label="Admin navigation"]')
    .getByText("Branding")
    .click();
  await waitForLiveViewReady(page);
  await expect(
    page.getByRole("heading", { name: "Auth forms and emails" }),
  ).toBeVisible();
  await expect(
    page.locator('[data-testid="admin-auth-branding-form"]'),
  ).toBeVisible();
  await expect(
    page.locator('[data-testid="admin-auth-preview"]'),
  ).toBeVisible();
  await expect(
    page.locator('[data-testid="admin-email-preview"]'),
  ).toBeVisible();

  // Desktop organization scope: header + main reflect the scoped org.
  await page.goto(`/admin/organizations/${allowedOrgSlug}`);
  await expect(adminShellHeader(page)).toContainText(allowedOrgName);
  await expect(page.locator("main")).toContainText(allowedOrgName);
  await captureAdminCheckpoint(page, testInfo, {
    name: "allowed-org-desktop",
  });

  // Mobile shell: bottom navigation and Global scope still reachable.
  await page.setViewportSize(MOBILE_VIEWPORT);
  await page.goto("/admin");
  await expect(
    adminShellHeader(page).getByText("Admin", { exact: true }),
  ).toBeVisible();
  await expect(
    page.locator('nav[aria-label="Admin bottom nav"]'),
  ).toBeVisible();
  await expect(
    page.locator('nav[aria-label="Admin bottom nav"]'),
  ).toContainText("Global");
  await expect(
    page.locator('nav[aria-label="Admin bottom nav"]'),
  ).toContainText("Brand");
  await captureAdminCheckpoint(page, testInfo, { name: "shell-global-mobile" });

  // Mobile organization scope: bottom nav stays, header reflects the org.
  await page.goto(`/admin/organizations/${allowedOrgSlug}`);
  await expect(
    page.locator('nav[aria-label="Admin bottom nav"]'),
  ).toBeVisible();
  await expect(adminShellHeader(page)).toContainText(allowedOrgName);
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
    const allowedResponse = await page.goto(
      `/admin/organizations/${allowedOrgSlug}`,
    );
    expect(allowedResponse?.status()).toBe(200);
    await expect(adminShellHeader(page)).toContainText(allowedOrgName);

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
    const notFoundResponse = await page.goto(
      `/admin/organizations/${otherOrgSlug}`,
    );
    expect(notFoundResponse?.status()).toBe(404);
    await expect(page.locator("body")).toContainText(
      "Not found. This organization admin scope is unavailable.",
    );
    await expect(page.locator("body")).not.toHaveText(/^\s*$/);
  } finally {
    await context.close();
  }
});

test.describe("VFY-01 generated host global users index", () => {
  test("lists users for platform admin", async ({ page }) => {
    await logIn(page, platformAdminEmail, adminPassword);
    const response = await page.goto("/admin/users");
    expect(response?.status()).toBe(200);
    await waitForLiveViewReady(page);
    await expect(
      page.getByRole("heading", { name: "Users", exact: true }),
    ).toBeVisible();
    await expect(page.getByText("Global user operations")).toBeVisible();
    await expect(page.getByRole("button", { name: "Search" })).toBeVisible();
  });
});

test.describe("OPS-01 bounded enterprise surface", () => {
  test("organization settings render stage-based enterprise guidance", async ({
    page,
  }) => {
    await logIn(page, orgAdminEmail, adminPassword);
    const response = await page.goto(
      `/organizations/${allowedOrgSlug}/settings`,
    );
    expect(response?.status()).toBe(200);
    await waitForLiveViewReady(page);
    await expect(page.locator("main")).toContainText("Allowed Org");
    await expect(page.locator("main")).toContainText("Enterprise SSO");
    await expect(page.locator("main")).toContainText("Setup");
    await expect(page.locator("main")).toContainText("Routing");
    await expect(page.locator("main")).toContainText("Reconciliation");
    await expect(page.locator("main")).toContainText("Enforcement");
    await expect(page.locator("main")).toContainText("SSO-only");
  });
});

test.describe("VFY-01 generated host audit CSV export", () => {
  test("returns CSV with stable audit header columns", async ({ page }) => {
    await logIn(page, platformAdminEmail, adminPassword);
    const res = await page.request.get("/admin/audit/export.csv");
    expect(res.status()).toBe(200);
    const contentType = res.headers()["content-type"] ?? "";
    expect(contentType).toMatch(/csv/i);
    const body = await res.text();
    const firstLine =
      body.split(/\r?\n/).find((line) => line.trim().length > 0) ?? "";
    expect(firstLine).toContain("occurred_at");
    expect(firstLine).toContain("impersonation_state");
  });
});

test("generated audit presets expose one effective filter value and visible applied state", async ({
  page,
}) => {
  await logIn(page, platformAdminEmail, adminPassword);
  await page.goto("/admin/audit");
  await waitForLiveViewReady(page);

  const presets = page.getByRole("navigation", {
    name: "Audit filter presets",
  });
  await presets.getByRole("link", { name: "Failures" }).click();
  await expect(page).toHaveURL(/(?:\?|&)outcome=failure(?:&|$)/);
  await expect(
    page.getByRole("heading", { name: "Active filters" }),
  ).toBeVisible();
  await expect(page.getByText("Outcome: Failure", { exact: true })).toBeVisible();
  await expect(page.locator('[name="outcome"]')).toHaveCount(1);
  await expect(page.locator('[name="action_prefix"]')).toHaveCount(1);
  await expect(page.locator('select[name="outcome"]')).toHaveValue("failure");

  await presets.getByRole("link", { name: "Impersonation" }).click();
  await expect(page).toHaveURL(/action_prefix=admin(?:\.|%2E)impersonation/);
  await expect(
    page.getByText("Action: admin.impersonation", { exact: true }),
  ).toBeVisible();

  const actorId = "00000000-0000-0000-0000-000000000001";
  await page.getByLabel("Actor", { exact: true }).fill(actorId);
  await page.getByRole("button", { name: "Apply filters" }).click();
  await expect(page).toHaveURL(new RegExp(`(?:\\?|&)actor=${actorId}(?:&|$)`));
  await expect(page.getByText(`Actor: ${actorId}`, { exact: true })).toBeVisible();
});

test("revoked platform admin is denied on the next authorization check", async ({
  page,
}) => {
  test.skip(
    process.env.SIGRA_EXPECT_PLATFORM_DENIED !== "1",
    "Run by the generated-host smoke after the revoke task.",
  );

  await logIn(page, platformAdminEmail, adminPassword);
  const response = await page.goto("/admin");
  expect(response?.status()).toBe(403);
  await expect(page.locator("body")).toContainText(
    "Access denied. You do not have access to this admin scope.",
  );
});

test.describe("VFY-01 generated host impersonation start", () => {
  test("starts impersonation after fresh sudo for seeded non-admin user", async ({
    page,
  }) => {
    await logIn(page, platformAdminEmail, adminPassword);
    await page.goto(
      `/admin/users?q=${encodeURIComponent(impersonationTargetEmail)}`,
    );
    await waitForLiveViewReady(page);
    await expect(
      adminUsersEmailLocator(page, impersonationTargetEmail),
    ).toBeVisible();
    await page.getByRole("link", { name: "Open user" }).first().click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    const detailUrl = new URL(page.url());
    const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
    await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
    await confirmSudo(page, adminPassword);
    await expect(page).toHaveURL(
      new RegExp(`${detailUrl.pathname.replaceAll("/", "\\/")}\\?`),
    );
    await waitForLiveViewReady(page);
    await page.getByRole("button", { name: "Start impersonation" }).click();
    await expect(page).toHaveURL("/");
  });
});
