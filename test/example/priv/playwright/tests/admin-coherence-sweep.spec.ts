import { test, expect, type Page } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 159 Plan 4: admin coherence filmstrip spec.
//
// Behavior-only DOM assertions across all 6 admin screens — no toHaveScreenshot()
// calls in this spec. Pixel baselines are Phase 160's job.
//
// This spec verifies the Phase 159 coherence contract (D-07):
//   1. Global overview                     (/admin)            — notice visible
//   2. Org overview                        (/admin/organizations/acme-corp)    — scope_ribbon, pills
//   3. Users index                         (/admin/users)      — scope_ribbon, passkeys pill
//   4. User audit                          (/admin/users/:id/audit)            — scope_ribbon, page_back
//   5. Audit explorer                      (/admin/audit)      — scope_ribbon
//   6. Org roster                          (/admin/organizations/acme-corp/users) — scope_ribbon
//
// GATE-03: Filter chip keyboard motion check — computed transition on
// .sg-filter-chip must not contain 'transform' in Playwright's non-pointer-fine
// environment (Chromium headless does not expose a pointer:fine media feature,
// so the @media guard correctly suppresses the transition for keyboard/touch users).
//
// Seeded demo DB dependency: Screens 2 and 3 assert pills that require
// `mix run priv/repo/seeds.exs` to have been run in the dev environment.
// pat@demo.sigra.dev (passkeys), grace@demo.sigra.dev (deletion-scheduled Acme member),
// and an expired-invite row must exist in the database.
//
// This spec runs in the default chromium project — the spec file name
// admin-coherence-sweep.spec.ts does NOT match the ADMIN_CHECKPOINTS_SPEC
// regex (/admin-checkpoints\.spec\.ts/) in playwright.config.ts, so no
// playwright.config.ts changes are required.

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function clearBrowserSession(page: Page) {
  await page.context().clearCookies();
}

async function createOrganization(page: Page, name: string, slug: string) {
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', name);
  await expect(page.locator('#slug-preview')).toHaveText(slug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  await waitForLiveViewReady(page);
}

async function openUserDetail(page: Page, targetEmail: string) {
  await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
  await waitForLiveViewReady(page);
  await page.getByRole('link', { name: 'Open user' }).first().click();
  await waitForLiveViewReady(page);
  await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
}

test.describe('Phase 159 coherence sweep', () => {
  test('all 6 admin screens satisfy the coherence contract', async ({ page }) => {
    // SETUP: Register a platform admin for the journey
    const adminEmail = `platform-admin+coherence-${Date.now()}@example.test`;
    await registerUser(page, adminEmail, TEST_PASSWORD);
    await page.goto('/admin');
    await waitForLiveViewReady(page);

    // SCREEN 1 — Global overview (/admin)
    // The overview archetype surfaces a notice alarm as its primary signal.
    // scope_ribbon is NOT required on the overview archetype (it has its own scope context).
    await expect(page.locator('.sg-notice').first()).toBeVisible();

    // SCREEN 2 — Org overview (/admin/organizations/acme-corp)
    // Requires mix run priv/repo/seeds.exs — acme-corp org, grace@demo.sigra.dev member,
    // expired invite row, and deletion-scheduled user must exist in the database.
    await page.goto('/admin/organizations/acme-corp');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();
    // FIXT-01: Expired pill — seeded expired invitation for acme-corp
    // Requires mix run priv/repo/seeds.exs (expired-invite@demo.sigra.dev row)
    await expect(
      page.locator('.sg-status-pill[data-tone="risk"]').filter({ hasText: 'Expired' })
    ).toBeVisible();
    // FIXT-02: Deletion scheduled pill — grace@demo.sigra.dev is scheduled for deletion
    // Requires mix run priv/repo/seeds.exs (grace@demo.sigra.dev with deletion scheduled)
    await expect(
      page.locator('.sg-status-pill[data-tone="warn"]').filter({ hasText: 'Deletion scheduled' })
    ).toBeVisible();

    // SCREEN 3 — Users index (/admin/users)
    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();
    // FIXT-03: Passkeys pill — pat@demo.sigra.dev has a registered passkey
    // Requires mix run priv/repo/seeds.exs (pat@demo.sigra.dev must exist with passkey)
    await page.goto('/admin/users?q=pat%40demo.sigra.dev');
    await waitForLiveViewReady(page);
    await expect(
      page.locator('.sg-status-pill[data-tone="ok"]').filter({ hasText: 'Passkeys' })
    ).toBeVisible();

    // SCREEN 4 — User audit (/admin/users/:id/audit)
    // Navigate to the registered admin user's detail and then to the audit tab.
    await openUserDetail(page, adminEmail);
    // Navigate to audit tab
    await page.getByRole('link', { name: /audit/i }).first().click();
    await waitForLiveViewReady(page);
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+\/audit/);
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();
    // page_back: user-audit screen must have a Back link
    await expect(page.getByRole('link', { name: /back/i })).toBeVisible();

    // SCREEN 5 — Audit explorer (/admin/audit)
    await page.goto('/admin/audit');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();

    // SCREEN 6 — Org roster (/admin/organizations/acme-corp/users)
    await page.goto('/admin/organizations/acme-corp/users');
    await waitForLiveViewReady(page);
    await expect(page.locator('.sg-scope-ribbon')).toBeVisible();

    // GATE-03: Keyboard motion check — filter chip transition must not contain 'transform'
    // After the D-06 CSS fix, the transition is inside @media (hover: hover) and (pointer: fine).
    // Playwright's Chromium test environment does not expose a pointer:fine media feature,
    // so the transition is suppressed for keyboard and touch users as intended.
    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    const chip = page.locator('label.sg-filter-chip').first();
    await chip.focus();
    const transition = await chip.evaluate((el) => getComputedStyle(el).transition);
    // In a non-pointer:fine environment (keyboard/touch), transition should not animate transforms.
    // The scoped CSS means keyboard chip-toggle produces no transform animation (GATE-03).
    expect(transition).not.toContain('transform');
  });
});
