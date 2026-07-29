// KNOWN-BAD fixture for P2 (230-02). Declares the helper and the axe test so the guard's
// structural tests pass; the defect is the `{ tag: '@snapshot' }` on the axe test, which
// the PR lane's `--grep-invert '@snapshot'` then excludes -- removing the WCAG scan from
// every pull request while the gallery lane still reports green.
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page } from '@playwright/test';

async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(violations, `${label}: axe violations`).toHaveLength(0);
}

const RESPONSIVE_WIDTHS = [390, 1280];

test.describe('Design gallery board snapshots', () => {
  test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', { tag: '@snapshot' }, async ({ page }) => {
    await assertNoAxeViolations(page, 'design-gallery');
  });
});
