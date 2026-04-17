import type { Page } from '@playwright/test';

/**
 * Locates a user's email on `/admin/users` for either responsive layout.
 * Fresh Phoenix apps compile Tailwind responsive utilities, so the desktop
 * table (`lg:block`) and mobile cards (`lg:hidden`) are mutually exclusive at
 * runtime — union with `.or()` keeps assertions stable on both.
 */
export function adminUsersEmailLocator(page: Page, email: string) {
  return page
    .locator('#admin-users-desktop-results')
    .getByText(email)
    .first()
    .or(page.locator('#admin-users-mobile-results').getByText(email).first());
}
