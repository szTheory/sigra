import { test, expect, type Page } from "@playwright/test";
import {
  captureAdminCheckpoint,
  captureGeneratedHostProofArtifact,
  writeBlockedPolicyProofBundle,
  writeGeneratedHostProofBundle,
} from "../helpers/adminArtifacts";
import { adminUsersEmailLocator } from "../helpers/adminUsersIndex";
import {
  buildLocalWebhookReceiverUrl,
  buildProofUserEmail,
  TEST_PASSWORD,
} from "../helpers/fixtures";

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

const adminPassword = process.env.SIGRA_ADMIN_PASSWORD ?? TEST_PASSWORD;

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
    timeout: 30_000,
  });
}

async function confirmSudo(page: Page, password: string) {
  await expect(page).toHaveURL(/\/users\/sudo\?/);
  await expect(
    page.getByRole("heading", { name: "Confirm your password" }),
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
  await page.request.post("/users/log_in", {
    form: {
      _action: "registered",
      "user[email]": email,
      "user[password]": password,
    },
  });
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page
    .locator('form:has(input[name="user[password]"])')
    .first()
    .evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
  await expect(page).not.toHaveURL(/\/users\/register/);
  await logIn(page, email, password);
}

async function clearBrowserSession(page: Page) {
  await page.context().clearCookies();
}

async function createOrganization(page: Page, name: string, slug: string) {
  await page.goto("/organizations/new");
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', name);
  await expect(page.locator("#slug-preview")).toHaveText(slug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  await waitForLiveViewReady(page);
}

async function logInOrRegister(page: Page, email: string, password: string) {
  await page.goto("/users/log_in");
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');

  if (!page.url().match(/\/users\/log_in(\?|$)/)) {
    return;
  }

  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page
    .locator('form:has(input[name="user[password]"])')
    .first()
    .evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });

  if (!page.url().match(/\/users\/register/)) {
    return;
  }

  await logIn(page, email, password);
}

async function waitForGeneratedDelivery(page: Page) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    await page.reload();
    await waitForLiveViewReady(page);

    const deliveryCards = page.locator("article").filter({ hasText: "Delivery ID:" });
    const openDelivery = page.getByRole("link", { name: "Open delivery" });

    if ((await deliveryCards.count()) > 0 && (await openDelivery.count()) > 0) {
      return openDelivery.first();
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error("Timed out waiting for generated-host webhook delivery to appear");
}

async function waitForGeneratedDeliveryCount(page: Page, expectedCount: number) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    await page.reload();
    await waitForLiveViewReady(page);

    const deliveryCards = page.locator("article").filter({ hasText: "Delivery ID:" });

    if ((await deliveryCards.count()) >= expectedCount) {
      return;
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error(`Timed out waiting for ${expectedCount} generated-host webhook deliveries`);
}

async function configureReceiverSecrets(
  page: Page,
  currentSecret: string,
  previousSecret?: string,
  mode?: "healthy" | "fail_after_verify",
) {
  const response = await page.request.post("/test/db_probe", {
    form: {
      table: "webhook_receiver_config",
      current_secret: currentSecret,
      previous_secret: previousSecret ?? "",
      mode: mode ?? "healthy",
    },
  });

  expect(response.status()).toBe(200);
}

async function fetchSubscriptionSecrets(page: Page, subscriptionId: string) {
  const response = await page.request.get("/test/db_probe", {
    params: {
      table: "webhook_subscription_secrets",
      subscription_id: subscriptionId,
    },
  });

  expect(response.status()).toBe(200);
  return response.json();
}

async function fetchWebhookProof(page: Page, deliveryId: string) {
  const proofResponse = await page.request.get("/test/db_probe", {
    params: {
      table: "webhook_proof",
      delivery_id: deliveryId,
    },
  });

  if (proofResponse.status() !== 200) {
    throw new Error(
      `Expected /test/db_probe webhook_proof to return 200, got ${proofResponse.status()}. Set EXAMPLE_DB_PROBE_ENABLED=1 when running this proof lane.`,
    );
  }

  return proofResponse.json();
}

async function drainWebhookQueue(page: Page) {
  const response = await page.request.post("/test/db_probe", {
    form: {
      table: "webhook_drain",
    },
  });

  expect(response.status()).toBe(200);
}

async function configureWebhookEndpointPolicy(
  page: Page,
  mode: "healthy" | "deny_exact_endpoint",
  endpointUrl?: string,
  detail = "blocked by deployment callback",
) {
  const response = await page.request.post("/test/db_probe", {
    form: {
      table: "webhook_endpoint_policy",
      mode,
      endpoint_url: endpointUrl ?? "",
      detail,
    },
  });

  expect(response.status()).toBe(200);
}

async function waitForDeliveryText(
  page: Page,
  text: string,
  path: string,
  maxAttempts = 20,
) {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    await page.goto(path);
    await waitForLiveViewReady(page);

    const mainText = (await page.locator("main").textContent()) ?? "";
    if (mainText.includes(text)) {
      return mainText;
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error(`Timed out waiting for ${text} at ${path}`);
}

async function openDeliveryFromFailures(page: Page, deliveryId: string) {
  const row = page.locator("article").filter({ hasText: deliveryId }).first();
  await expect(row).toContainText(deliveryId);
  await row.getByRole("link", { name: "Open delivery" }).click();
  await waitForLiveViewReady(page);
}

async function openReplayChildFromSourceDetail(page: Page) {
  const replayChildLink = page.getByRole("link", { name: "Open replay child" }).first();
  await expect(replayChildLink).toBeVisible();
  await replayChildLink.click();
  await waitForLiveViewReady(page);
}

function mapReceiverVerification(
  proof: Awaited<ReturnType<typeof fetchWebhookProof>>["receiver_verification"]["source_delivery"],
) {
  if (!proof) {
    return null;
  }

  return {
    receiverVerifiedAt: proof.verified_at,
    receiverSignatureTimestamp: proof.signature_timestamp,
    rawBodySha256: proof.raw_body_sha256,
  };
}

function extractLabeledValue(text: string, label: string): string {
  const match = text.match(new RegExp(`${label}:\\s+([^\\n]+)`));

  if (!match) {
    throw new Error(`Could not find label ${label}`);
  }

  return match[1].trim();
}

function extractSubscriptionIdFromUrl(url: string): string | null {
  const pathnameParts = new URL(url).pathname.split("/").filter(Boolean);
  const lastPart = pathnameParts[pathnameParts.length - 1];

  if (!lastPart || lastPart === "webhooks") {
    return null;
  }

  return lastPart;
}

test("generated host admin shell renders on desktop and mobile", async ({
  page,
}, testInfo) => {
  const suffix = Date.now();
  const orgAdminEmail = `org-admin+generated-${suffix}@example.test`;
  const platformAdminEmail = `platform-admin+generated-${suffix}@example.test`;
  const allowedOrgName = `Allowed Org ${suffix}`;
  const allowedOrgSlug = `allowed-org-${suffix}`;

  await registerUser(page, orgAdminEmail, adminPassword);
  await createOrganization(page, allowedOrgName, allowedOrgSlug);
  await clearBrowserSession(page);
  await registerUser(page, platformAdminEmail, adminPassword);

  // Desktop shell: Global scope label and admin sidebar navigation.
  await page.setViewportSize(DESKTOP_VIEWPORT);
  await page.goto("/admin");
  await expect(adminShellHeader(page).getByText("Admin", { exact: true })).toBeVisible();
  await expect(adminShellHeader(page)).toContainText("Global");
  await expect(page.locator('nav[aria-label="Admin navigation"]')).toBeVisible();
  await captureAdminCheckpoint(page, testInfo, { name: "shell-global-desktop" });

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
  await expect(adminShellHeader(page).getByText("Admin", { exact: true })).toBeVisible();
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toBeVisible();
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toContainText(
    "Global",
  );
  await captureAdminCheckpoint(page, testInfo, { name: "shell-global-mobile" });

  // Mobile organization scope: bottom nav stays, header reflects the org.
  await page.goto(`/admin/organizations/${allowedOrgSlug}`);
  await expect(page.locator('nav[aria-label="Admin bottom nav"]')).toBeVisible();
  await expect(adminShellHeader(page)).toContainText(allowedOrgName);
  await captureAdminCheckpoint(page, testInfo, {
    name: "allowed-org-mobile",
  });
});

test("generated host canonical proof correlates failed source history with replay recovery", async ({
  browser,
  page,
}, testInfo) => {
  const platformAdminEmail = `platform-admin+generated-${Date.now()}@example.test`;
  const proofUserEmail = buildProofUserEmail("generated-replay-proof-user");
  const description = `Generated replay proof ${Date.now()}`;

  await registerUser(page, platformAdminEmail, adminPassword);
  await page.goto("/admin/webhooks");
  await waitForLiveViewReady(page);

  const endpointUrl = buildLocalWebhookReceiverUrl(page.url());

  await page.getByRole("button", { name: "Create subscription" }).click();
  await expect(page.locator("main")).toContainText("Create webhook subscription");
  await page.fill('input[name="subscription[endpoint_url]"]', endpointUrl);
  await page.fill('input[name="subscription[description]"]', description);
  await page.getByLabel("user.created").check();
  await page.getByRole("button", { name: "Create subscription" }).last().click();
  await expect(page.locator("main")).toContainText(description);
  await expect(page.locator("main")).toContainText(endpointUrl);

  const subscriptionEntry = page.locator("tr, article").filter({ hasText: description }).first();
  const openSubscription = subscriptionEntry.getByRole("link", {
    name: "Open subscription",
  });

  let subscriptionId = extractSubscriptionIdFromUrl(page.url());

  if ((await openSubscription.count()) > 0) {
    const href = await openSubscription.getAttribute("href");
    await openSubscription.click();
    await waitForLiveViewReady(page);

    subscriptionId =
      extractSubscriptionIdFromUrl(page.url()) ||
      (href ? extractSubscriptionIdFromUrl(new URL(href, page.url()).toString()) : null);
  }

  if (!subscriptionId) {
    throw new Error(`Could not derive subscription id from ${page.url()}`);
  }

  const initialSecrets = await fetchSubscriptionSecrets(page, subscriptionId);
  await configureReceiverSecrets(page, initialSecrets.current_secret, undefined, "fail_after_verify");

  const subscriptionScreenshot = await captureGeneratedHostProofArtifact(
    page,
    testInfo,
    "subscription-detail.png",
  );

  const actorContext = await browser.newContext();
  const actorPage = await actorContext.newPage();

  try {
    await registerUser(actorPage, proofUserEmail, TEST_PASSWORD);
  } finally {
    await actorContext.close();
  }

  await drainWebhookQueue(page);
  await waitForDeliveryText(
    page,
    description,
    "/admin/webhooks/failures?delivery_state=dead_lettered",
  );

  const deadLetterRow = page.locator("article").filter({ hasText: description }).first();
  await expect(deadLetterRow).toContainText(description);
  const deadLetterText = await deadLetterRow.textContent();
  const sourceDeliveryId = extractLabeledValue(deadLetterText ?? "", "Delivery ID");
  const sourceFailureScreenshot = await captureGeneratedHostProofArtifact(
    page,
    testInfo,
    "failed-source-row.png",
  );

  await openDeliveryFromFailures(page, sourceDeliveryId);
  const sourceDetailText = await waitForDeliveryText(
    page,
    "Replay delivery",
    page.url(),
  );
  expect(sourceDetailText).toContain("Dead lettered");
  const sourceDetailScreenshot = await captureGeneratedHostProofArtifact(
    page,
    testInfo,
    "source-delivery-detail.png",
  );

  const sourceProofBeforeReplay = await fetchWebhookProof(page, sourceDeliveryId);
  expect(sourceProofBeforeReplay.lineage.source_delivery_id).toBe(sourceDeliveryId);
  expect(sourceProofBeforeReplay.receipt?.verified_at).toBeTruthy();

  await configureReceiverSecrets(page, initialSecrets.current_secret, undefined, "healthy");
  await page.getByRole("button", { name: "Replay delivery" }).click();
  await expect(page.locator("main")).toContainText("Replay this dead-lettered delivery?");
  await page.getByRole("button", { name: "Confirm replay" }).click();
  await expect(page.locator("main")).toContainText("Replay child:");

  const replayDeliveryId = extractLabeledValue(
    (await page.locator("main").textContent()) ?? "",
    "Replay child",
  );

  await drainWebhookQueue(page);
  await page.goto(`/admin/webhooks/deliveries/${sourceDeliveryId}?return_to=%2Fadmin%2Fwebhooks%2Ffailures`);
  await waitForLiveViewReady(page);
  await expect(page.locator("main")).toContainText(replayDeliveryId);
  await openReplayChildFromSourceDetail(page);

  const replayDetailText = await waitForDeliveryText(page, replayDeliveryId, page.url());
  expect(replayDetailText).toContain("Delivered");
  const replayDetailScreenshot = await captureGeneratedHostProofArtifact(
    page,
    testInfo,
    "replay-delivery-detail.png",
  );

  const sourceProof = await fetchWebhookProof(page, sourceDeliveryId);
  const replayProof = await fetchWebhookProof(page, replayDeliveryId);

  expect(sourceProof.lineage.source_delivery_id).toBe(sourceDeliveryId);
  expect(sourceProof.lineage.replay_delivery_id).toBe(replayDeliveryId);
  expect(sourceProof.lineage.root_delivery_id).toBe(sourceDeliveryId);
  expect(replayProof.lineage.source_delivery_id).toBe(sourceDeliveryId);
  expect(replayProof.lineage.replay_delivery_id).toBe(replayDeliveryId);
  expect(replayProof.lineage.root_delivery_id).toBe(sourceDeliveryId);
  expect(sourceProof.receiver_verification.source_delivery.verified_at).toBeTruthy();
  expect(replayProof.receiver_verification.replay_delivery.verified_at).toBeTruthy();

  await page.goto("/admin/webhooks/failures?delivery_state=dead_lettered");
  await waitForLiveViewReady(page);
  await expect(page.locator("main")).toContainText(sourceDeliveryId);
  await expect(page.locator("main")).toContainText(replayDeliveryId);
  await expect(page.locator("main")).toContainText("Already replayed");

  writeGeneratedHostProofBundle({
    runAt: new Date().toISOString(),
    proofUserEmail,
    endpointUrl,
    subscriptionId,
    subscriptionScreenshot,
    sourceDeliveryId,
    replayDeliveryId,
    rootDeliveryId: sourceProof.lineage.root_delivery_id,
    sourceDeliveryStatus: sourceProof.delivery_status,
    replayDeliveryStatus: replayProof.delivery_status,
    sourceFailureScreenshot,
    sourceDetailScreenshot,
    replayDetailScreenshot,
    receiverVerification: {
      sourceDelivery: mapReceiverVerification(sourceProof.receiver_verification.source_delivery),
      replayDelivery: mapReceiverVerification(replayProof.receiver_verification.replay_delivery),
    },
  });
});

test("generated host blocked-policy proof captures failures and detail truth", async ({
  browser,
  page,
}, testInfo) => {
  const platformAdminEmail = `platform-admin+generated-${Date.now()}@example.test`;
  const proofUserEmail = buildProofUserEmail("generated-policy-proof-user");
  const description = `Generated policy proof ${Date.now()}`;

  await registerUser(page, platformAdminEmail, adminPassword);
  await page.goto("/admin/webhooks");
  await waitForLiveViewReady(page);

  const endpointUrl = buildLocalWebhookReceiverUrl(page.url());

  await page.getByRole("button", { name: "Create subscription" }).click();
  await expect(page.locator("main")).toContainText("Create webhook subscription");
  await page.fill('input[name="subscription[endpoint_url]"]', endpointUrl);
  await page.fill('input[name="subscription[description]"]', description);
  await page.getByLabel("user.created").check();
  await page.getByRole("button", { name: "Create subscription" }).last().click();
  await expect(page.locator("main")).toContainText(description);
  await expect(page.locator("main")).toContainText(endpointUrl);

  await configureWebhookEndpointPolicy(
    page,
    "deny_exact_endpoint",
    endpointUrl,
    "blocked by deployment callback",
  );

  const actorContext = await browser.newContext();
  const actorPage = await actorContext.newPage();

  try {
    await registerUser(actorPage, proofUserEmail, TEST_PASSWORD);
  } finally {
    await actorContext.close();
  }

  try {
    await drainWebhookQueue(page);
    await waitForDeliveryText(
      page,
      "Blocked by local policy",
      "/admin/webhooks/failures?delivery_state=dead_lettered",
    );

    const blockedRow = page.locator("article").filter({ hasText: description }).first();
    await expect(blockedRow).toContainText(description);
    await expect(blockedRow).toContainText("Blocked by local policy");
    await expect(blockedRow).toContainText("Policy reason");
    await expect(blockedRow).toContainText("policy_denied");
    await expect(blockedRow).toContainText("blocked by deployment callback");

    const blockedRowText = await blockedRow.textContent();
    const blockedDeliveryId = extractLabeledValue(blockedRowText ?? "", "Delivery ID");
    const failuresScreenshot = await captureGeneratedHostProofArtifact(
      page,
      testInfo,
      "blocked-failures-row.png",
      "/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-policy-operator-truth",
    );

    await openDeliveryFromFailures(page, blockedDeliveryId);
    await expect(page.locator("main")).toContainText("Endpoint policy result");
    await expect(page.locator("main")).toContainText("policy_denied");
    await expect(page.locator("main")).toContainText("blocked by deployment callback");
    await expect(page.locator("main")).toContainText(
      "Sigra blocked this delivery before any outbound request was attempted.",
    );

    const detailScreenshot = await captureGeneratedHostProofArtifact(
      page,
      testInfo,
      "blocked-delivery-detail.png",
      "/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-policy-operator-truth",
    );

    const blockedProof = await fetchWebhookProof(page, blockedDeliveryId);
    expect(blockedProof.delivery_status).toBe("dead_lettered");
    expect(blockedProof.endpoint_url).toBe(endpointUrl);

    writeBlockedPolicyProofBundle({
      runAt: new Date().toISOString(),
      endpointUrl,
      blockedDeliveryId,
      deliveryStatus: blockedProof.delivery_status,
      policyReason: "policy_denied",
      policyDetail: "blocked by deployment callback",
      failuresScreenshot,
      detailScreenshot,
    });
  } finally {
    await configureWebhookEndpointPolicy(page, "healthy");
  }
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
  const suffix = Date.now();
  const orgAdminEmail = `org-admin+generated-${suffix}@example.test`;
  const allowedOrgName = `Allowed Org ${suffix}`;
  const allowedOrgSlug = `allowed-org-${suffix}`;
  const otherOrgSlug = `other-scope-${suffix}`;

  try {
    await registerUser(page, orgAdminEmail, adminPassword);
    await createOrganization(page, allowedOrgName, allowedOrgSlug);

    // Allowed organization access: org admin can reach its own org scope.
    const allowedResponse = await page.goto(`/admin/organizations/${allowedOrgSlug}`);
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

test.describe("VFY-01 generated host global users index", () => {
  test("lists users for platform admin", async ({ page }) => {
    await registerUser(page, `platform-admin+generated-${Date.now()}@example.test`, adminPassword);
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

test.describe("VFY-01 generated host audit CSV export", () => {
  test("returns CSV with stable audit header columns", async ({ page }) => {
    await registerUser(page, `platform-admin+generated-${Date.now()}@example.test`, adminPassword);
    const res = await page.request.get("/admin/audit/export.csv");
    expect(res.status()).toBe(200);
    const contentType = res.headers()["content-type"] ?? "";
    expect(contentType).toMatch(/csv/i);
    const body = await res.text();
    const firstLine =
      body
        .split(/\r?\n/)
        .find((line) => line.trim().length > 0) ?? "";
    expect(firstLine).toContain("occurred_at");
    expect(firstLine).toContain("impersonation_state");
  });
});

test.describe("VFY-01 generated host impersonation start", () => {
  test("starts impersonation after fresh sudo for seeded non-admin user", async ({
    page,
  }) => {
    const suffix = Date.now();
    const platformAdminEmail = `platform-admin+generated-${suffix}@example.test`;
    const impersonationTargetEmail = `impersonation-target-${suffix}@example.test`;

    await registerUser(page, impersonationTargetEmail, adminPassword);
    await clearBrowserSession(page);
    await registerUser(page, platformAdminEmail, adminPassword);
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
    await page.goto(
      `/users/sudo?return_to=${encodeURIComponent(detailPath)}`,
    );
    await confirmSudo(page, adminPassword);
    await expect(page).toHaveURL(
      new RegExp(`${detailUrl.pathname.replaceAll("/", "\\/")}\\?`),
    );
    await waitForLiveViewReady(page);
    await page.getByRole("button", { name: "Start impersonation" }).click();
    await expect(page).toHaveURL("/");
  });
});
