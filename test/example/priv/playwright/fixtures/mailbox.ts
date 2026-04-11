// Helper to scrape the Swoosh dev mailbox (Plug.Swoosh.MailboxPreview) for the
// most-recent confirmation link.
//
// Swoosh's MailboxPreview renders a two-pane UI: a list of emails on the left,
// and the selected email body inside an <iframe> on the right. We use
// Playwright's frameLocator to reach into that iframe and pull the first
// /users/confirm/ link out of the rendered email body.
//
// If a future Swoosh release changes the rendering to inline HTML (no iframe),
// swap frameLocator('iframe') for page.locator(...) directly.

import { Page, expect } from '@playwright/test';

/**
 * Open /dev/mailbox, click the most-recent email to `recipient`, and return
 * the href of the first confirmation link inside the email body iframe.
 */
export async function extractConfirmationLink(
  page: Page,
  recipient: string,
): Promise<string> {
  await page.goto('/dev/mailbox');

  // The mailbox lists emails; the recipient address appears in each row.
  const emailLink = page.getByText(recipient).first();
  await expect(emailLink).toBeVisible({ timeout: 5_000 });
  await emailLink.click();

  // Swoosh renders the email body in an iframe.
  const href = await page
    .frameLocator('iframe')
    .locator('a[href*="/users/confirm/"]')
    .first()
    .getAttribute('href');

  if (!href) {
    throw new Error(`No confirmation link found in email for ${recipient}`);
  }

  return href;
}
