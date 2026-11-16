// test-only: copy-independent locator for the password login submit button.
import type { Page } from "@playwright/test";

/**
 * CSS selector for the password login form's submit button, independent of the
 * button's visible text so copy changes cannot break browser tests.
 *
 * `#login_form` holds exactly one submit-capable button: the example host
 * button has no `type` attribute (it defaults to submit) and the generated
 * `sigra_auth_button` defaults `type` to "submit". The passkey control is
 * `type="button"` and lives in a different form, so excluding `type="button"`
 * keeps the selector unambiguous (Playwright strict mode throws on multiple
 * matches).
 *
 * Exported as a string constant because one spec hands a selector string to a
 * probe function rather than a locator.
 */
export const LOGIN_SUBMIT_SELECTOR = '#login_form button:not([type="button"])';

/** Locator for the password login submit button; see LOGIN_SUBMIT_SELECTOR. */
export function loginSubmit(page: Page) {
  return page.locator(LOGIN_SUBMIT_SELECTOR);
}
