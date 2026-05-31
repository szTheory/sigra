import { test, expect, type Page, type TestInfo } from '@playwright/test';
// otplib: imported for future TOTP challenge integration. The example app
// currently uses MFA as step-up auth (not login challenge per golden-path.spec.ts:141),
// so authenticator.generate(DEMO_TOTP_B32) is not called at runtime. Retained
// for documentation and quick activation if mfa.check_fn is added to sigra_config().
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { authenticator } from 'otplib';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';

// Phase 143 Plan 2: evaluator-facing demo showcase spec.
//
// Exercises the six seeded demo personas using structural assertions
// (data-testid and email-based locators — never display-name text) and
// captures four committed PNG baselines for evaluator-facing screenshots.
//
// Runs exclusively in the `demo-showcase-chromium` project partition;
// excluded from `chromium` and `mobile` via testIgnore in playwright.config.ts.
//
// PW-01: structural persona assertions in isolated partition.
// PW-02: four committed PNG baselines under tests/demo-showcase.spec.ts-snapshots/.

// Demo-only deterministic secret — matches Personas.demo_totp_secret/0
const DEMO_TOTP_B32 = 'CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW';
const DEMO_ADMIN_EMAIL = 'admin@demo.sigra.dev';
const DEMO_ADMIN_PASSWORD = 'DemoAdmin1!SecurePass';
const DEMO_ALICE_EMAIL = 'alice@demo.sigra.dev';
const DEMO_ALICE_PASSWORD = 'AliceDemoPass1!';
const EVALUATOR_FLOW_MAX_MS = 10 * 60 * 1000;
const DEMO_EMAILS = [
  'admin@demo.sigra.dev',
  'alice@demo.sigra.dev',
  'bob@demo.sigra.dev',
  'carol@demo.sigra.dev',
  'dave@demo.sigra.dev',
  'frank@demo.sigra.dev',
];
const DEMO_LOCALS = ['admin', 'alice', 'bob', 'carol', 'dave', 'frank'];

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

/**
 * CI-aware screenshot baseline comparison for the demo showcase lane.
 * No axe assertions — this lane is PW-02 evaluator screenshots, not a11y gate.
 * Tolerances mirror the admin-checkpoints pattern (D-08):
 *   - CI: maxDiffPixels 200_000 / maxDiffPixelRatio 0.22
 *   - Local: maxDiffPixels 30_000 / maxDiffPixelRatio 0.06
 */
async function assertDemoScreenshot(
  page: Page,
  _testInfo: TestInfo,
  slug: string,
) {
  const ci = process.env.CI === 'true';
  await expect(page).toHaveScreenshot(`${slug}.png`, {
    fullPage: false,
    maxDiffPixels: ci ? 200_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : 0.06,
  });
}

/**
 * Log in as the demo admin persona.
 *
 * The example app's sigra_config() does not set mfa.check_fn, so the login
 * flow creates a :standard session (not :mfa_pending), regardless of the
 * user's TOTP enrollment state. The admin lands directly at "/" on successful
 * login — no MFA challenge redirect.
 *
 * The DEMO_TOTP_B32 constant is declared above for documentation purposes
 * (it is the correct base32 encoding of Personas.demo_totp_secret/0) and
 * is available if a future change adds mfa.check_fn to the example app's
 * sigra_config, at which point the loginDemoAdmin function would need to
 * complete the TOTP challenge by clicking button[phx-click="show_totp"]
 * and filling #mfa_totp_code with authenticator.generate(DEMO_TOTP_B32).
 *
 * Reference: golden-path.spec.ts:141 — "the example app uses MFA as step-up
 * auth (sudo mode), not as a login challenge."
 *
 * Sequence:
 *   1. Navigate to /users/log_in — a plain controller page (not a LiveView)
 *   2. Fill #login_form (password form) — multiple forms exist on the page
 *   3. Submit — redirects to "/" with :standard session
 *   4. Wait for redirect away from /users/log_in
 */
async function loginDemoUser(page: Page, email: string, password: string) {
  // /users/log_in is a plain controller page (not a LiveView) — do NOT call
  // waitForLiveViewReady here. Fill the form directly and submit.
  await page.goto('/users/log_in');
  // The login page has multiple forms (passkey, magic link, password).
  // Scope fills to #login_form to target the password form specifically.
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  // No MFA challenge — example app creates a :standard session without check_fn.
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}

async function loginDemoAdmin(page: Page) {
  await loginDemoUser(page, DEMO_ADMIN_EMAIL, DEMO_ADMIN_PASSWORD);
}

test.describe('demo-showcase', () => {
  test('documented evaluator path reaches authenticated flow within ten minutes', async ({
    page,
  }) => {
    const startedAt = Date.now();

    await page.goto('/demo/credentials');
    await waitForLiveViewReady(page);

    await expect(
      page.locator('[data-testid="demo-persona-row-alice"]'),
    ).toBeVisible();
    await expect(page.getByText(DEMO_ALICE_EMAIL)).toBeVisible();

    await loginDemoUser(page, DEMO_ALICE_EMAIL, DEMO_ALICE_PASSWORD);

    await page.goto('/users/sessions');
    await waitForLiveViewReady(page);
    await expect(
      page.getByText(/active|just now|current/i).first(),
    ).toBeVisible();

    const elapsedMs = Date.now() - startedAt;
    expect(
      elapsedMs,
      'documented evaluator path should reach an authenticated auth surface within 10 minutes',
    ).toBeLessThanOrEqual(EVALUATOR_FLOW_MAX_MS);
  });

  test('demo personas structural assertions and evaluator screenshots', async ({
    page,
  }, testInfo) => {
    // ──────────────────────────────────────────────────────────────────
    // Step 1: /demo/credentials — assert all 6 persona rows by data-testid
    // ──────────────────────────────────────────────────────────────────
    await page.goto('/demo/credentials');
    await waitForLiveViewReady(page);

    for (const local of DEMO_LOCALS) {
      await expect(
        page.locator(`[data-testid="demo-persona-row-${local}"]`),
      ).toBeVisible();
    }

    await assertDemoScreenshot(page, testInfo, 'demo-credentials');

    // ──────────────────────────────────────────────────────────────────
    // Step 2: Login as demo admin (standard session — no MFA challenge)
    // ──────────────────────────────────────────────────────────────────
    await loginDemoAdmin(page);

    // ──────────────────────────────────────────────────────────────────
    // Step 3: /admin/users?q=demo.sigra.dev — assert all 6 demo emails
    // ──────────────────────────────────────────────────────────────────
    await page.goto('/admin/users?q=demo.sigra.dev');
    await waitForLiveViewReady(page);

    for (const email of DEMO_EMAILS) {
      await expect(adminUsersEmailLocator(page, email)).toBeVisible();
    }

    await assertDemoScreenshot(page, testInfo, 'admin-user-list');

    // ──────────────────────────────────────────────────────────────────
    // Step 4: /admin/users/{admin-id} — assert MFA + passkey row
    // ──────────────────────────────────────────────────────────────────
    await page.goto(
      `/admin/users?q=${encodeURIComponent(DEMO_ADMIN_EMAIL)}`,
    );
    await waitForLiveViewReady(page);
    await page.getByRole('link', { name: 'Open user' }).first().click();
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    await waitForLiveViewReady(page);

    await expect(page.getByText('MFA: Enabled')).toBeVisible();
    await expect(page.getByText('1 passkey')).toBeVisible();

    await assertDemoScreenshot(page, testInfo, 'admin-user-detail');

    // ──────────────────────────────────────────────────────────────────
    // Step 5: /admin/audit — assert non-empty audit event rows
    // ──────────────────────────────────────────────────────────────────
    await page.goto('/admin/audit');
    await waitForLiveViewReady(page);

    // Audit table renders rows in <table class="table w-full"> <tbody> <tr>
    const auditRowCount = await page.locator('table tbody tr').count();
    expect(auditRowCount, 'Expected audit log to have at least one row').toBeGreaterThan(0);

    await assertDemoScreenshot(page, testInfo, 'audit-explorer');
  });
});
