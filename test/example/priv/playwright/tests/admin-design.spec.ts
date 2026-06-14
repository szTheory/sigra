import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page, type TestInfo } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 185 (AUDIT-INFRA): admin-design board-snapshot spec.
//
// Captures every Sigra.Admin.Components board from the design gallery
// (/admin/_design) as an element-scoped PNG baseline (board-level, not
// full-page). Axe WCAG A/AA is asserted green for every board before
// the snapshot is taken.
//
// Runs in three partitioned projects (admin-design-chromium, -mobile, -dark)
// so regressions surface per project without replaying the full behavior suite.

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

/** Phase 35: axe a11y gate paired with each board snapshot. */
async function assertNoAxeViolations(page: Page, label: string) {
  // Scope to WCAG A/AA tags so best-practice rules like `region` (full-page
  // landmark wrapping) do not fail on the admin shell's `<header>` layout,
  // which is intentional Phoenix/LiveView structure rather than a shipped
  // WCAG regression signal for this lane.
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const detail =
    violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}

/**
 * Element-scoped board screenshot helper.
 * Captures the board element (#boardId) rather than the full page so each
 * board's PNG baseline is independent and stable across admin shell changes.
 */
async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);
  const dark = testInfo.project.name.includes('dark');
  const mobile = testInfo.project.name.includes('mobile');
  const ci = process.env.CI === 'true';
  const locator = page.locator(`#${boardId}`);
  await expect(locator).toHaveScreenshot(`${boardId}.png`, {
    maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
  });
}

const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',       // designated canary (D-10)
  'board-field_help', 'board-skeleton', 'board-audit_row',
];
const GROUP_BOARDS = ['board-mg-1', 'board-mg-2', 'board-mg-3', 'board-mg-4', 'board-mg-5'];

test.describe('Design gallery board snapshots', () => {
  // Each Playwright test runs in an isolated browser context, so the admin
  // session must be established inside the test's own context (mirrors
  // admin-checkpoints.spec.ts, which calls registerUser per test). Registering
  // once in beforeAll on a separate page does NOT authenticate the test pages.
  // The gallery renders static literal assigns only, so the unique per-test
  // email never appears in any board screenshot — captures stay deterministic.
  test.beforeEach(async ({ page }, testInfo) => {
    const suffix = `${Date.now()}-${testInfo.project.name}-${testInfo.title}`.replace(
      /[^a-z0-9]+/gi,
      '-',
    );
    const adminEmail = `platform-admin+design-${suffix}@example.test`;
    await registerUser(page, adminEmail, TEST_PASSWORD);
    await page.goto('/admin/_design');
    await waitForLiveViewReady(page);
  });

  for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS]) {
    test(`board: ${boardId}`, async ({ page }, testInfo) => {
      await assertBoardScreenshot(page, testInfo, boardId);
    });
  }
});
