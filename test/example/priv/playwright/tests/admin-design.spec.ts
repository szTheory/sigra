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
  await Promise.all([
    page.waitForURL((url) => !url.pathname.endsWith('/users/register'), { timeout: 30_000 }),
    page.getByRole('button', { name: /Create an account/ }).click(),
  ]);
  await expect(page.getByRole('alert')).toContainText('Account created successfully!');
}

let registrationSequence = 0;

function adminDesignEmail(testInfo: TestInfo) {
  // Example.SigraAdminPolicy requires this prefix for global admin access.
  const project = testInfo.project.name
    .replace(/^admin-design-/, '')
    .replace(/[^a-z0-9]+/gi, '')
    .slice(0, 8);
  const sequence = (++registrationSequence).toString(36);
  const timestamp = Date.now().toString(36);

  return `platform-admin+dg-${timestamp}-${project}-${sequence}-${testInfo.retry}@example.test`;
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

const RESPONSIVE_WIDTHS = [320, 375, 768, 1024, 1440] as const;

const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',       // designated canary (D-10)
  'board-notice_link', 'board-field_help', 'board-skeleton', 'board-audit_row',
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
    const adminEmail = adminDesignEmail(testInfo);
    await registerUser(page, adminEmail, TEST_PASSWORD);
    await page.goto('/admin/_design');
    await waitForLiveViewReady(page);
  });

  for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS]) {
    test(`board: ${boardId}`, async ({ page }, testInfo) => {
      await assertBoardScreenshot(page, testInfo, boardId);
    });
  }

  test('notice_link board is registered as a standalone L1 component', async () => {
    expect(COMPONENT_BOARDS).toHaveLength(13);
    expect(COMPONENT_BOARDS).toContain('board-notice');
    expect(COMPONENT_BOARDS).toContain('board-notice_link');
  });

  test('component boards do not overflow at required responsive widths', async ({ page }) => {
    for (const width of RESPONSIVE_WIDTHS) {
      await page.setViewportSize({ width, height: 900 });

      for (const boardId of COMPONENT_BOARDS) {
        const board = page.locator(`#${boardId}`);
        await expect(board, `${boardId} should exist at ${width}px`).toBeVisible();

        const fit = await board.evaluate((element) => {
          const boardRect = element.getBoundingClientRect();
          const children = Array.from(element.querySelectorAll('*'));
          const overflowingChild = children.find((child) => {
            const rect = child.getBoundingClientRect();
            return rect.left < -1 || rect.right > window.innerWidth + 1;
          });

          return {
            boardInsideViewport: boardRect.left >= -1 && boardRect.right <= window.innerWidth + 1,
            noHorizontalOverflow: element.scrollWidth <= element.clientWidth + 1,
            overflowingChild: overflowingChild
              ? `${overflowingChild.tagName.toLowerCase()}.${Array.from(overflowingChild.classList).join('.')}`
              : null,
          };
        });

        expect(
          fit,
          `${boardId} should stay inside ${width}px viewport without scrollWidth overflow`,
        ).toMatchObject({
          boardInsideViewport: true,
          noHorizontalOverflow: true,
          overflowingChild: null,
        });
      }
    }
  });

  test('metrics and help boards expose required L1 state evidence', async ({ page }) => {
    const statBoard = page.locator('#board-stat');
    await expect(statBoard.getByText('read-only KPI')).toBeVisible();
    const statRoot = statBoard.locator('.sg-metric').first();
    await expect(statRoot).not.toHaveAttribute('href', /.+/);
    await expect(statRoot).not.toHaveAttribute('tabindex', /.+/);
    await expect(statRoot).not.toHaveClass(/sg-card-hover/);
    await expect(statBoard.locator('a')).toHaveCount(0);

    const statLinkBoard = page.locator('#board-stat_link');
    for (const label of ['default', 'hover', 'focus-visible', 'active']) {
      await expect(statLinkBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(statLinkBoard.locator('.sg-metric-link')).toHaveCount(4);

    const summaryBoard = page.locator('#board-summary_chip');
    for (const label of [
      'tone: neutral',
      'tone: ok',
      'tone: warn',
      'tone: risk',
      'tone: info',
      'help closed',
      'help open',
      'focus-visible',
    ]) {
      await expect(summaryBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(summaryBoard.locator('[data-sg-metric-help-root]')).toHaveCount(3);
    await expect(summaryBoard.locator('[data-help-open="true"]')).toHaveCount(1);
    await expect(summaryBoard.locator('[role="tooltip"]')).toHaveCount(3);

    const fieldHelpBoard = page.locator('#board-field_help');
    for (const label of ['closed', 'open', 'focus-visible', 'click/tap', 'Escape close']) {
      await expect(fieldHelpBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(fieldHelpBoard.locator('[data-sg-field-help-root]')).toHaveCount(5);
    await expect(fieldHelpBoard.locator('[role="tooltip"]')).toHaveCount(5);
    await expect(
      fieldHelpBoard.locator(
        '.sg-field-help__panel a, .sg-field-help__panel button, .sg-field-help__panel [phx-click], .sg-field-help__panel [role="button"]',
      ),
    ).toHaveCount(0);
  });

  test('action boards expose required L1 state evidence and inert disabled examples', async ({
    page,
  }) => {
    const taskBoard = page.locator('#board-task_card');
    for (const label of ['default', 'hover', 'CTA focus-visible', 'CTA active', 'disabled']) {
      await expect(taskBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(taskBoard.locator('article.sg-card-hover')).toHaveCount(4);
    await expect(taskBoard.locator('article[tabindex], article[href]')).toHaveCount(0);

    for (const id of [
      'task-card-disabled-native',
      'task-card-disabled-aria',
      'task-card-disabled-class',
    ]) {
      const disabledExample = page.locator(`#${id}`);
      await expect(disabledExample).toBeVisible();
      const inert = await disabledExample.evaluate((element) => {
        const el = element as HTMLElement & { disabled?: boolean };
        return {
          pointerEvents: getComputedStyle(el).pointerEvents,
          disabled: el.disabled === true,
          tabIndex: el.tabIndex,
          href: el.getAttribute('href'),
        };
      });
      expect(inert.pointerEvents, `${id} should ignore pointer input`).toBe('none');
      expect(
        inert.disabled || inert.tabIndex < 0 || inert.href === null,
        `${id} should not be keyboard focusable`,
      ).toBeTruthy();
    }

    const chipBoard = page.locator('#board-applied_chip');
    for (const label of ['default', 'hover', 'focus-visible', 'active']) {
      await expect(chipBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(
      chipBoard.locator('.sg-applied-chip__remove[aria-label="Remove filter Role: Admin"]'),
    ).toHaveCount(4);
    await expect(chipBoard.locator('.sg-applied-chip__remove span[aria-hidden="true"]')).toHaveCount(
      4,
    );

    const pageBackBoard = page.locator('#board-page_back');
    for (const label of ['default', 'hover', 'focus-visible', 'active']) {
      await expect(pageBackBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(pageBackBoard.locator('a.sg-btn--ghost')).toHaveCount(4);
    await expect(pageBackBoard.locator('a', { hasText: 'Back to users' })).toHaveCount(4);
    await expect(pageBackBoard.locator('span[aria-hidden="true"]')).toHaveCount(4);
  });

  test('help states open and close with Escape without trapping focus', async ({ page }) => {
    const fieldHelp = page.locator('#board-field_help [data-sg-field-help-root]').first();
    const fieldTrigger = fieldHelp.locator('[data-sg-field-help-trigger]');
    const fieldPanelId = await fieldTrigger.getAttribute('aria-controls');
    if (!fieldPanelId) throw new Error('field_help trigger is missing aria-controls');
    const fieldPanel = page.locator(`#${fieldPanelId}`);

    await fieldTrigger.focus();
    await expect(fieldTrigger).toHaveAttribute('aria-expanded', 'true');
    await expect(fieldHelp).toHaveAttribute('data-help-open', 'true');
    await expect(fieldPanel).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(fieldTrigger).toHaveAttribute('aria-expanded', 'false');
    await expect(fieldHelp).not.toHaveAttribute('data-help-open', 'true');
    await expect(fieldPanel).toBeHidden();
    await expect(fieldTrigger).toBeFocused();

    const metricHelp = page.locator('#board-summary_chip [data-sg-metric-help-root]').first();
    const metricPanelId = await metricHelp.getAttribute('aria-describedby');
    if (!metricPanelId) throw new Error('summary_chip help root is missing aria-describedby');
    const metricPanel = page.locator(`#${metricPanelId}`);

    await metricHelp.focus();
    await expect(metricHelp).toHaveAttribute('data-help-open', 'true');
    await expect(metricPanel).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(metricHelp).not.toHaveAttribute('data-help-open', 'true');
    await expect(metricPanel).toBeHidden();
    await expect(metricHelp).toBeFocused();
  });
});
