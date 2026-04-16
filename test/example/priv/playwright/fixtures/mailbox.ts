// Helper to scrape the Swoosh dev mailbox (Plug.Swoosh.MailboxPreview) for the
// most-recent confirmation link.
//
// Swoosh's MailboxPreview renders a two-pane UI: a list of emails on the left,
// and the selected email body inside an <iframe id="html-mail"> on the right.
// We use Playwright's frameLocator targeting that exact ID to reach into the
// iframe and pull the first /users/confirm/ link out of the rendered email.
//
// The ID selector matters: Phoenix Live Reload injects a hidden iframe at
// `/phoenix/live_reload/frame` in MIX_ENV=dev, so a bare `iframe` selector
// resolves to 2 elements and fails strict-mode. Matching `iframe#html-mail`
// is unambiguous regardless of live reload state.
//
// If a future Swoosh release changes the rendering to inline HTML (no iframe),
// swap frameLocator for page.locator(...) directly.

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

  // Swoosh renders the email body in `iframe#html-mail`. Phoenix LiveReload
  // also injects a hidden iframe in dev — use the exact ID to disambiguate.
  const href = await page
    .frameLocator('iframe#html-mail')
    .locator('a[href*="/users/confirm/"]')
    .first()
    .getAttribute('href');

  if (!href) {
    throw new Error(`No confirmation link found in email for ${recipient}`);
  }

  const normalized = new URL(href, page.url());
  normalized.protocol = new URL(page.url()).protocol;
  normalized.host = new URL(page.url()).host;

  return normalized.toString();
}
