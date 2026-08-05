import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import {
  extractConfirmationLink,
  extractMagicLink,
  extractPasswordResetLink,
} from '../fixtures/mailbox';

test.describe.configure({ mode: 'serial' });

const journeyEmail = 'generated-auth-journey@example.test';

async function assertAuthState(page: Page, stateName: string) {
  const authRoot = page.locator('main.sigra-auth');
  await expect(authRoot, `${stateName}: expected one visible auth root`).toHaveCount(1);
  await expect(authRoot, `${stateName}: auth root is not visible`).toBeVisible();

  const { violations } = await new AxeBuilder({ page })
    .include('main.sigra-auth')
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();
  expect(
    violations,
    `${stateName}: scoped Axe violations: ${JSON.stringify(violations).slice(0, 2000)}`,
  ).toHaveLength(0);

  const diagnostics = await authRoot.evaluate((root) => {
    const formControlSelector = 'input:not([type="hidden"]), select, textarea, button';
    const describe = (element: Element) => {
      const id = element.getAttribute('id') ?? '';
      const label = element.textContent?.replace(/\s+/g, ' ').trim() ?? '';
      return `${element.tagName.toLowerCase()}#${id || '(no-id)'}:${label || '(no-text)'}`;
    };
    const ariaLabelledByResolves = (element: Element) => {
      const labelledBy = element.getAttribute('aria-labelledby')?.trim();
      if (!labelledBy) return false;

      return labelledBy.split(/\s+/).every((id) => root.querySelectorAll(`#${CSS.escape(id)}`).length === 1);
    };
    const hasAccessibleName = (element: Element) => {
      if (element.getAttribute('aria-label')?.trim() || ariaLabelledByResolves(element)) {
        return true;
      }

      if (element instanceof HTMLInputElement || element instanceof HTMLSelectElement || element instanceof HTMLTextAreaElement) {
        return element.labels !== null && element.labels.length > 0;
      }

      if (element instanceof HTMLButtonElement) {
        return Boolean(element.textContent?.trim() || element.getAttribute('title')?.trim());
      }

      return false;
    };
    const labels = Array.from(root.querySelectorAll('label[for]'))
      .map((label) => {
        const targetId = label.htmlFor.trim();
        const targets = targetId ? root.querySelectorAll(`#${CSS.escape(targetId)}`) : [];
        const target = targets.length === 1 ? targets[0] : null;
        return !targetId || !target?.matches(formControlSelector)
          ? `${describe(label)} -> #${targetId || '(empty)'} (${targets.length} matches)`
          : null;
      })
      .filter((diagnostic): diagnostic is string => diagnostic !== null)
      .sort();
    const unlabeledControls = Array.from(root.querySelectorAll(formControlSelector))
      .filter((control) => !hasAccessibleName(control))
      .map(describe)
      .sort();
    const ids = Array.from(root.querySelectorAll('[id]'))
      .map((element) => element.id.trim())
      .filter(Boolean);
    const duplicateIds = [...new Set(ids.filter((id) => ids.filter((candidate) => candidate === id).length > 1))].sort();

    return { labels, unlabeledControls, duplicateIds };
  });
  expect(diagnostics, `${stateName}: auth DOM invariants failed`).toEqual({
    labels: [],
    unlabeledControls: [],
    duplicateIds: [],
  });
}

const waitForLiveViewReady = async (page: Page) => {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
};

async function openPasswordForm(page: Page) {
  const disclosure = page.locator('details.sigra-auth-disclosure');
  await disclosure.locator('summary').click();
  await expect(disclosure).toHaveAttribute('open', '');
  return page.locator('#login_form');
}

async function logInWithPassword(page: Page, email: string, password: string) {
  await page.goto('/users/log_in');
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  await assertAuthState(page, 'login collapsed');
  const passwordForm = await openPasswordForm(page);
  await assertAuthState(page, 'login password disclosure');
  await passwordForm.getByLabel('Email', { exact: true }).fill(email);
  await passwordForm.getByLabel('Password', { exact: true }).fill(password);
  await passwordForm.getByRole('button', { name: 'Sign in with password' }).click();
}

async function clearBrowserSession(page: Page) {
  // The generated registration handoff does not render a logout control.
  // Clear the browser session deterministically before testing the next
  // unauthenticated auth transition; server-side logout has ConnTest coverage.
  await page.context().clearCookies();
  await page.goto('/users/log_in');
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
}

async function logOut(page: Page) {
  await page.goto('/users/settings');
  const logOutControl = page.getByRole('link', { name: 'Log out' });
  await expect(logOutControl).toHaveAttribute('href', '/users/log_out');
  await expect(logOutControl).toHaveAttribute('data-method', 'delete');
  await logOutControl.click();
  await page.goto('/users/settings');
  await expect(page).toHaveURL(/\/users\/log_in/);
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
}

test('generated B2C email authentication journey', async ({ page }) => {
  const email = journeyEmail;
  const caseVariedEmail = 'Generated-Auth-Journey@Example.Test';
  const password = 'GeneratedAuthPassword123!';

  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'registration');
  await page.getByLabel('Email', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: /create an account/i }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByText('Account created successfully!', { exact: true })).toBeVisible();

  const confirmationLink = await extractConfirmationLink(page, email);
  await clearBrowserSession(page);
  await assertAuthState(page, 'login after registration');
  await page.goto(confirmationLink);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);

  await logInWithPassword(page, email, password);
  await expect(page.getByText('Welcome back!', { exact: true })).toBeVisible();
  await logOut(page);
  await assertAuthState(page, 'logged-out login');

  const magicLinkForm = page.locator('#magic_link_form');
  await assertAuthState(page, 'login magic-link request');
  await magicLinkForm.getByLabel('Email for sign-in link', { exact: true }).fill(caseVariedEmail);
  await magicLinkForm.getByRole('button', { name: 'Email me a sign-in link' }).click();
  await expect(page.getByText(/If your email is registered/i)).toBeVisible();
  await assertAuthState(page, 'magic-link sent');

  const magicLink = await extractMagicLink(page, email);
  await page.goto(magicLink);
  await expect(page.getByText('Welcome!', { exact: true })).toBeVisible();
  await logOut(page);

  await page.goto('/users/reset-password');
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'reset request');
  await page.getByLabel('Email', { exact: true }).fill(caseVariedEmail);
  await page.getByRole('button', { name: 'Send reset instructions' }).click();
  await expect(page).toHaveURL(/\/users\/log_in/);
  await assertAuthState(page, 'reset sent login');

  const resetLink = await extractPasswordResetLink(page, email);
  await page.goto(resetLink);
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'reset token form');

  const staleResetPage = await page.context().newPage();
  await staleResetPage.goto(resetLink);
  await waitForLiveViewReady(staleResetPage);
  await assertAuthState(staleResetPage, 'stale reset token form');

  const replacementPassword = 'GeneratedAuthReplacementPassword123!';
  await page.getByLabel('New password', { exact: true }).fill(replacementPassword);
  await page.getByLabel('Confirm new password', { exact: true }).fill(replacementPassword);
  await page.getByRole('button', { name: 'Reset password' }).click();
  await expect(page).not.toHaveURL(/\/users\/reset-password/);
  await expect(page.getByText('Password reset successfully!', { exact: true })).toBeVisible();

  const staleReplacementPassword = 'GeneratedAuthStaleReplacementPassword123!';
  await staleResetPage.getByLabel('New password', { exact: true }).fill(staleReplacementPassword);
  await staleResetPage.getByLabel('Confirm new password', { exact: true }).fill(staleReplacementPassword);
  await staleResetPage.getByRole('button', { name: 'Reset password' }).click();
  await expect(staleResetPage.getByRole('heading', { name: 'Reset link expired' })).toBeVisible();
  await expect(staleResetPage.getByRole('link', { name: 'Request new reset email' })).toBeVisible();
  await assertAuthState(staleResetPage, 'stale reset token');
  await staleResetPage.close();

  await assertAuthState(page, 'logged-out login after reset');

  await logInWithPassword(page, email, password);
  await expect(page.getByText('Invalid email or password', { exact: true })).toBeVisible();
  await expect(page).toHaveURL(/\/users\/log_in/);
  await assertAuthState(page, 'login invalid password');

  await logInWithPassword(page, email, replacementPassword);
  await expect(page.getByText('Welcome back!', { exact: true })).toBeVisible();
  await logOut(page);
  await assertAuthState(page, 'logged-out login before Google collision');

  const oidcRequests: string[] = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.pathname.startsWith('/oidc/')) {
      oidcRequests.push(url.toString());
    }
  });

  const authorization = page.waitForRequest((request) =>
    request.url().includes('/oidc/authorize'),
  );
  await page.goto('/auth/google');
  const authorizationRequest = await authorization;
  const authorizationUrl = new URL(authorizationRequest.url());
  expect(authorizationUrl.hostname).toBe('127.0.0.1');
  expect(authorizationUrl.pathname).toBe('/oidc/authorize');
  expect(authorizationUrl.searchParams.get('state')).toMatch(/^.+\..+$/);
  expect(authorizationUrl.searchParams.get('code_challenge')).toMatch(
    /^[A-Za-z0-9_-]{43}$/,
  );
  expect(authorizationUrl.searchParams.get('code_challenge_method')).toBe('S256');
  expect(authorizationUrl.searchParams.has('nonce')).toBe(false);

  await expect(page).toHaveURL(/\/users\/log_in/);
  await expect(
    page.getByText(
      'An account with this email exists. Log in to link your google account.',
      { exact: true },
    ),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: /log out/i })).toHaveCount(0);
  await assertAuthState(page, 'Google collision login');
  // The browser owns only the authorization redirect; discovery and token
  // exchange are server-to-server calls and are asserted from the proof log.
  expect(
    oidcRequests.map((requestUrl) => new URL(requestUrl).pathname).sort(),
  ).toEqual(['/oidc/authorize']);
});
