import type { Page } from '@playwright/test';

/**
 * Locates the user row/card on `/admin/users` for either responsive layout.
 * Desktop and mobile markup both live in the DOM; `.or()` on the raw email
 * text matches **two** nodes and trips Playwright strict mode. Targeting a
 * single `tr` or `article` under the results panes yields one visible match
 * because Tailwind hides the inactive layout.
 */
export function adminUsersEmailLocator(page: Page, email: string) {
  // Both desktop and mobile result nodes can exist in the DOM; Tailwind only
  // shows one layout. Without `visible: true`, `.first()` can resolve to a
  // hidden desktop row on WebKit mobile and break `toBeVisible`.
  return page
    .locator(
      '#admin-users-desktop-results tbody tr, #admin-users-mobile-results article',
    )
    .filter({ hasText: email })
    .filter({ visible: true })
    .first();
}
