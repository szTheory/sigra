import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Locator, type Page, type TestInfo } from '@playwright/test';
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
  // D-08: wait for the brand webfont so element heights are font-stable before
  // capture. fonts.ready alone resolves instantly if the face is never requested
  // (Pitfall 7), so we follow with a hard guard that fails loudly if the woff2
  // 404'd or --font-sans didn't apply (T-197-06).
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
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
  // Scope to the full WCAG 2.1/2.2 AA tag set (EN 301 549 legal floor) so the
  // gate is literally defensible against modern accessibility standards (D-07).
  // This helper is element-scoped (board locator, not full page), so it runs
  // against the board element rather than the whole admin shell. The axe
  // `best_practice` tag-group is intentionally excluded (D-09): rules like
  // `region` (full-page landmark wrapping) would fail on the admin shell's
  // `<header>` layout, which is intentional Phoenix/LiveView structure rather
  // than a shipped WCAG regression signal for this lane.
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
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
const GROUP_BOARDS = [
  'board-mg-1',
  'board-mg-2',
  'board-mg-3',
  'board-mg-4',
  'board-mg-5',
  'board-mg-6',
  'board-mg-7',
  'board-mg-8',
  'board-mg-9',
  'board-mg-10',
  'board-mg-11',
] as const;

const GROUP_STATE_MARKERS: Record<(typeof GROUP_BOARDS)[number], string[]> = {
  'board-mg-1': ['mg-1-populated', 'mg-1-zero', 'mg-1-loading', 'mg-1-error'],
  'board-mg-2': ['mg-2-populated', 'mg-2-zero', 'mg-2-loading', 'mg-2-error'],
  'board-mg-3': ['mg-3-populated', 'mg-3-zero-note', 'mg-3-loading-note', 'mg-3-error'],
  'board-mg-4': ['mg-4-populated', 'mg-4-zero', 'mg-4-loading', 'mg-4-error'],
  'board-mg-5': ['mg-5-populated', 'mg-5-zero', 'mg-5-loading', 'mg-5-error'],
  'board-mg-6': ['mg-6-populated', 'mg-6-zero', 'mg-6-loading', 'mg-6-error'],
  'board-mg-7': ['mg-7-populated', 'mg-7-zero', 'mg-7-loading', 'mg-7-error'],
  'board-mg-8': ['mg-8-populated', 'mg-8-zero', 'mg-8-loading', 'mg-8-error'],
  'board-mg-9': ['mg-9-populated', 'mg-9-zero', 'mg-9-loading', 'mg-9-error'],
  'board-mg-10': ['mg-10-populated', 'mg-10-zero', 'mg-10-loading', 'mg-10-error'],
  'board-mg-11': ['mg-11-populated', 'mg-11-zero', 'mg-11-loading', 'mg-11-error'],
};

const normalizeText = (value: string | null) => (value ?? '').replace(/\s+/g, ' ').trim();

async function expectTokensInBothContainers(
  desktop: Locator,
  mobile: Locator,
  tokens: string[],
  label: string,
) {
  const desktopText = normalizeText(await desktop.textContent());
  const mobileText = normalizeText(await mobile.textContent());

  for (const token of tokens) {
    expect(desktopText, `${label}: desktop should include ${token}`).toContain(token);
    expect(mobileText, `${label}: mobile should include ${token}`).toContain(token);
  }
}

async function firstTexts(root: Locator, selector: string, limit = 1) {
  return (await root.locator(selector).evaluateAll(
    (elements, max) =>
      elements
        .slice(0, max as number)
        .map((element) => element.textContent?.replace(/\s+/g, ' ').trim() ?? '')
        .filter(Boolean),
    limit,
  )) as string[];
}

async function assertUserResultEquivalence(desktop: Locator, mobile: Locator, label: string) {
  const tokens = [
    ...(await firstTexts(desktop, '.sg-strong', 1)),
    ...(await firstTexts(desktop, 'code.sg-code', 1)),
    ...(await firstTexts(desktop, '.sg-status-pill', 2)),
    ...(await firstTexts(desktop, 'td:nth-child(3) span', 2)),
    ...(await firstTexts(desktop, 'td:nth-child(4) span', 2)),
    'Open user',
  ];

  await expectTokensInBothContainers(desktop, mobile, tokens, label);
}

async function assertAuditResultEquivalence(desktop: Locator, mobile: Locator, label: string) {
  // Strict guard on the un-sliced desktop locator: the FIRST row inside the desktop
  // container must expose exactly 2 code.sg-code nodes (one event-id code + one action
  // code, both inside the Event-cell <details>).
  //
  // Fails LOUDLY on under-extraction (<2: codes left the Event <td>, became data-attrs,
  // or are hidden from the DOM rather than just visually collapsed by <details>) AND on
  // over-extraction (>2: a stray code node leaked into the first row's cell).
  //
  // Scoped to tbody tr:first-child so the same guard works for both:
  //   • gallery MG-6 (1 static row in [data-testid="mg-6-desktop-results"])
  //   • live /admin/audit and per-user audit (N rows; we assert the per-row count)
  //
  // Do NOT assert on firstTexts(…).length — that helper already .slice(0,2) and filters
  // falsy, so its return is capped at 2 and can never reveal a 3rd stray node (over-
  // extraction silently passes). The raw first-row locator count closes that gap.
  expect(
    await desktop.locator('tbody tr').first().locator('code.sg-code').count(),
    `${label}: desktop must expose exactly 2 audit codes`,
  ).toBe(2);

  const tokens = [
    ...(await firstTexts(desktop, 'code.sg-code', 2)),
    ...(await firstTexts(desktop, '.sg-status-pill', 2)),
    ...(await firstTexts(desktop, 'td:nth-child(3) span', 3)),
  ];

  await expectTokensInBothContainers(desktop, mobile, tokens, label);

  const desktopTone = await desktop.locator('tbody tr, article.sg-list-row').first().getAttribute('data-tone');
  const mobileTone = await mobile.locator('article.sg-list-row').first().getAttribute('data-tone');
  expect(mobileTone, `${label}: mobile tone should match desktop outcome tone`).toBe(desktopTone);
}

async function normalizedInnerHTML(locator: Locator) {
  return locator.evaluate((element) => {
    const clone = element.cloneNode(true) as HTMLElement;
    const comments = document.createTreeWalker(clone, NodeFilter.SHOW_COMMENT);
    const staleComments: Comment[] = [];

    while (comments.nextNode()) {
      staleComments.push(comments.currentNode as Comment);
    }

    staleComments.forEach((comment) => comment.remove());

    clone.querySelectorAll('*').forEach((node) => {
      for (const attribute of Array.from(node.attributes)) {
        if (attribute.name.startsWith('data-phx-') || attribute.name === 'data-phx-id') {
          node.removeAttribute(attribute.name);
        }
      }

      const id = node.getAttribute('id');
      if (id?.startsWith('mg-11-confirm-title-')) {
        node.setAttribute('id', 'mg-11-confirm-title');
      }

      const labelledBy = node.getAttribute('aria-labelledby');
      if (labelledBy?.startsWith('mg-11-confirm-title-')) {
        node.setAttribute('aria-labelledby', 'mg-11-confirm-title');
      }
    });

    return clone.innerHTML.replace(/\s+/g, ' ').trim();
  });
}

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

  test('component and group boards do not overflow at required responsive widths', async ({
    page,
  }) => {
    for (const width of RESPONSIVE_WIDTHS) {
      await page.setViewportSize({ width, height: 900 });

      for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS]) {
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

  test('group boards expose catalog states and right components', async ({ page }) => {
    for (const boardId of GROUP_BOARDS) {
      const board = page.locator(`#${boardId}`);
      await expect(board, `${boardId} should be visible`).toBeVisible();

      for (const marker of GROUP_STATE_MARKERS[boardId]) {
        await expect(
          page.locator(`[data-testid="${marker}"]`),
          `${boardId} should expose ${marker}`,
        ).toBeVisible();
      }
    }

    await expect(page.locator('#board-mg-1 .sg-metric')).toHaveCount(7);
    await expect(page.locator('#board-mg-2 .sg-applied-chip')).toHaveCount(6);
    await expect(page.locator('#board-mg-3 article.sg-card')).toHaveCount(2);
    await expect(page.locator('#board-mg-3')).not.toHaveClass(/(^|\s)sg-card(\s|$)/);
    await expect(page.locator('#board-mg-4 .sg-notice')).toHaveCount(3);
    await expect(page.locator('[data-testid="mg-5-desktop-results"]')).toBeAttached();
    await expect(page.locator('[data-testid="mg-5-mobile-results"]')).toBeAttached();
    await expect(page.locator('[data-testid="mg-6-desktop-results"]')).toBeAttached();
    await expect(page.locator('[data-testid="mg-6-mobile-results"]')).toBeAttached();
    await expect(page.locator('#board-mg-6 article.sg-list-row')).toHaveCount(3);
    await expect(page.locator('#board-mg-7 .sg-list-row')).toHaveCount(3);
    await expect(page.locator('#board-mg-8 .sg-list-row')).toHaveCount(3);
    await expect(page.locator('#board-mg-9 .sg-summary-facts')).toHaveCount(1);
    await expect(page.locator('#board-mg-10 .sg-detail-grid')).toHaveCount(2);
    await expect(page.locator('#board-mg-11 .sg-confirm-overlay .sg-confirm-dialog')).toHaveCount(
      2,
    );

    const nestedCards = await page.locator(GROUP_BOARDS.map((id) => `#${id}`).join(',')).evaluateAll(
      (boards) =>
        boards.flatMap((board) => {
          if (board.hasAttribute('data-sg-card-nesting-audit-only')) return [];
          const nested = board.querySelectorAll('.sg-card .sg-card:not(.sg-skeleton)');
          return Array.from(nested).map((element) => ({
            boardId: board.id,
            className: element.getAttribute('class'),
          }));
        }),
    );

    expect(nestedCards, 'group boards should not contain .sg-card .sg-card nesting').toEqual([]);
  });

  test('MG-5 and MG-6 desktop and mobile representations are content-equivalent', async ({
    page,
  }) => {
    await assertUserResultEquivalence(
      page.locator('[data-testid="mg-5-desktop-results"]'),
      page.locator('[data-testid="mg-5-mobile-results"]'),
      'gallery MG-5',
    );

    await assertAuditResultEquivalence(
      page.locator('[data-testid="mg-6-desktop-results"]'),
      page.locator('[data-testid="mg-6-mobile-results"]'),
      'gallery MG-6',
    );
    await expectTokensInBothContainers(
      page.locator('[data-testid="mg-6-populated"]'),
      page.locator('[data-testid="mg-6-populated"]'),
      ['Previous page', 'Next page', 'Export CSV'],
      'gallery MG-6 controls',
    );

    await page.goto('/admin/users');
    await waitForLiveViewReady(page);
    await assertUserResultEquivalence(
      page.locator('[data-testid="admin-users-desktop-results"]'),
      page.locator('[data-testid="admin-users-mobile-results"]'),
      'admin users',
    );

    await page.goto('/admin/audit');
    await waitForLiveViewReady(page);
    const auditDesktop = page.locator('[data-testid="admin-audit-desktop-results"]');
    if ((await auditDesktop.count()) > 0) {
      await assertAuditResultEquivalence(
        auditDesktop,
        page.locator('[data-testid="admin-audit-mobile-results"]'),
        'admin audit',
      );
      await expect(page.getByRole('link', { name: 'Previous page' })).toBeAttached();
      await expect(page.getByRole('link', { name: 'Next page' })).toBeAttached();
      await expect(page.getByRole('link', { name: 'Export CSV' })).toBeAttached();
    }

    // Filter to the seeded admin (admin@demo.tasklane.test) deterministically — the users index
    // orders by inserted_at DESC so the harness-created login user would otherwise be first-listed
    // with only ~3 audit events (insufficient to trigger pagination at page_size 25).
    await page.goto('/admin/users?q=admin%40demo.tasklane.test');
    await waitForLiveViewReady(page);
    const userDetailHref = await page
      .locator('[data-testid="admin-users-desktop-results"] a', { hasText: 'Open user' })
      .first()
      .getAttribute('href');
    if (!userDetailHref) throw new Error('admin users first Open user link is missing href');
    await page.goto(userDetailHref);
    await waitForLiveViewReady(page);
    await page.getByRole('link', { name: 'View full audit' }).click();
    await waitForLiveViewReady(page);

    const userAuditDesktop = page.locator('[data-testid="admin-audit-user-desktop-results"]');
    if ((await userAuditDesktop.count()) > 0) {
      await assertAuditResultEquivalence(
        userAuditDesktop,
        page.locator('[data-testid="admin-audit-user-mobile-results"]'),
        'admin user audit',
      );
      await expect(page.getByRole('link', { name: 'Previous page' })).toBeAttached();
      await expect(page.getByRole('link', { name: 'Next page' })).toBeAttached();
    }
  });

  test('filter form submits via real GET submission and returns filtered results', async ({ page }) => {
    // D-02 guard: the filter input must be inside a <form method="get"> so that
    // typing + clicking Search actually submits the form. This test navigates to
    // the Users index WITHOUT a pre-built ?q= query string and performs a real
    // form submission — a filter input accidentally placed outside the form would
    // cause this test to time-out waiting for filtered results, catching the D-01
    // reflow risk that the existing equivalence spec (which navigates via
    // page.goto('/admin/users?q=...')) would silently miss.
    await page.goto('/admin/users');
    await waitForLiveViewReady(page);

    // Verify we start on the unfiltered index (full user list present).
    const desktopResults = page.locator('[data-testid="admin-users-desktop-results"]');
    const mobileResults = page.locator('[data-testid="admin-users-mobile-results"]');
    await expect(desktopResults).toBeAttached();
    await expect(mobileResults).toBeAttached();

    // Type a deterministic query into the search input (placeholder: "Email, user id, or name").
    // Target the stable seeded platform admin — present in all test runs.
    const searchInput = page.getByPlaceholder('Email, user id, or name');
    await expect(searchInput, 'search input should be present').toBeAttached();
    await searchInput.fill('admin@demo.tasklane.test');

    // Click the "Search" submit button — this is the real form submission (not goto).
    // If the input is outside the <form>, clicking Search navigates with an empty ?q=
    // and no filtered results appear, failing the assertion below.
    await Promise.all([
      page.waitForURL((url) => url.searchParams.get('q') === 'admin@demo.tasklane.test', {
        timeout: 30_000,
      }),
      page.getByRole('button', { name: 'Search' }).click(),
    ]);
    await waitForLiveViewReady(page);

    // Assert the filtered result appears in both desktop and mobile containers.
    await assertUserResultEquivalence(
      desktopResults,
      mobileResults,
      'filter form submit — filtered users',
    );

    // Confirm the result row contains the queried email address in at least one container.
    const desktopText = await desktopResults.textContent();
    expect(desktopText, 'desktop results should contain the searched email').toContain(
      'admin@demo.tasklane.test',
    );
  });

  test('reused group examples render byte-coherently for equivalent data', async ({ page }) => {
    for (const pair of [
      ['mg-2-coherence-a', 'mg-2-coherence-b'],
      ['mg-6-coherence-a', 'mg-6-coherence-b'],
      ['mg-11-coherence-a', 'mg-11-coherence-b'],
    ] as const) {
      await expect(normalizedInnerHTML(page.locator(`[data-testid="${pair[0]}"]`))).resolves.toEqual(
        await normalizedInnerHTML(page.locator(`[data-testid="${pair[1]}"]`)),
      );
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

  test('content and notice boards expose required L1 state evidence', async ({ page }) => {
    const emptyBoard = page.locator('#board-empty_state');
    await expect(emptyBoard.getByText('No users found', { exact: true })).toBeVisible();
    await expect(emptyBoard.getByText('Try adjusting your filters.', { exact: true })).toBeVisible();

    const scopeBoard = page.locator('#board-scope_ribbon');
    for (const label of ['global scope', 'org scope']) {
      await expect(scopeBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(scopeBoard.locator('.sg-scope-ribbon')).toHaveCount(2);
    await expect(
      scopeBoard.locator('.sg-scope-ribbon[href], .sg-scope-ribbon[role="link"], .sg-scope-ribbon[tabindex]'),
    ).toHaveCount(0);

    const noticeBoard = page.locator('#board-notice');
    for (const label of [
      'tone: nil (neutral)',
      'tone: ok',
      'tone: warn',
      'tone: risk (with embedded notice_link)',
      'tone: info',
    ]) {
      await expect(noticeBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(noticeBoard.locator('.sg-notice')).toHaveCount(5);
    await expect(noticeBoard.locator('.sg-notice[role="alert"], .sg-notice[role="status"]')).toHaveCount(
      0,
    );
    for (const tone of ['ok', 'warn', 'risk', 'info']) {
      await expect(noticeBoard.locator(`.sg-notice[data-tone="${tone}"]`)).toHaveCount(1);
    }

    const noticeLinkBoard = page.locator('#board-notice_link');
    for (const label of ['default', 'hover', 'focus-visible', 'active']) {
      await expect(noticeLinkBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(noticeLinkBoard.locator('a.sg-notice__action')).toHaveCount(4);
    await expect(
      noticeLinkBoard.locator('a.sg-notice__action[href="/admin/users?needs_review=true"]', {
        hasText: 'Review accounts',
      }),
    ).toHaveCount(4);
  });

  test('skeleton and audit_row boards expose required L1 state evidence and reduced motion', async ({
    page,
  }) => {
    const skeletonBoard = page.locator('#board-skeleton');
    for (const label of [
      'aria-busy container',
      'line skeleton',
      'block skeleton',
      'card skeleton',
      'reduced motion static',
    ]) {
      await expect(skeletonBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(skeletonBoard.locator('[aria-busy="true"]')).toHaveCount(1);
    await expect(skeletonBoard.locator('.sg-skeleton[aria-busy]')).toHaveCount(0);
    await expect(skeletonBoard.locator('.sg-skeleton')).toHaveCount(5);

    await page.emulateMedia({ reducedMotion: 'reduce' });
    const reducedMotion = await skeletonBoard.locator('.sg-skeleton').first().evaluate((element) => {
      const after = getComputedStyle(element, '::after');
      const toMs = (duration: string) =>
        duration
          .split(',')
          .map((part) => part.trim())
          .filter(Boolean)
          .map((part) => {
            const value = Number.parseFloat(part);
            return part.endsWith('ms') ? value : value * 1000;
          });

      return {
        animationName: after.animationName,
        maxDurationMs: Math.max(...toMs(after.animationDuration)),
        iterationCounts: after.animationIterationCount.split(',').map((part) => part.trim()),
      };
    });

    expect(
      reducedMotion.animationName === 'none' || reducedMotion.maxDurationMs <= 1,
      'reduced motion should strip active skeleton shimmer movement',
    ).toBeTruthy();
    expect(reducedMotion.iterationCounts.every((count) => count === '1')).toBeTruthy();
    await page.emulateMedia({ reducedMotion: 'no-preference' });

    const auditBoard = page.locator('#board-audit_row');
    for (const label of ['success compact', 'info full with codes', 'risk failure']) {
      await expect(auditBoard.getByText(label, { exact: true })).toBeVisible();
    }
    await expect(auditBoard.locator('article.sg-list-row')).toHaveCount(3);
    await expect(auditBoard.locator('article.sg-list-row:not([data-tone])')).toHaveCount(1);
    await expect(auditBoard.locator('article.sg-list-row[data-tone="info"]')).toHaveCount(1);
    await expect(auditBoard.locator('article.sg-list-row[data-tone="risk"]')).toHaveCount(1);
    await expect(auditBoard.locator('.sg-status-pill[data-tone="info"]')).toHaveCount(2);
    await expect(auditBoard.locator('.sg-status-pill[data-tone="risk"]')).toHaveCount(1);
    await expect(auditBoard.locator('code.sg-code')).toHaveCount(2);
    await expect(auditBoard.getByText('uuid-5678', { exact: true })).toBeVisible();
    await expect(auditBoard.getByText('admin.impersonation.start', { exact: true })).toBeVisible();
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
