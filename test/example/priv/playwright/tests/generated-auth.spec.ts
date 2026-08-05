import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import {
  extractConfirmationLink,
  extractMagicLink,
  extractPasswordResetLink,
} from '../fixtures/mailbox';

test.describe.configure({ mode: 'serial' });

const collisionEmail = 'oauth-collision@example.test';

async function assertAuthState(_page: Page, stateName: string) {
  throw new Error(`auth accessibility gate has not been implemented for ${stateName}`);
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

async function logOut(page: Page) {
  const logout = page.getByRole('button', { name: /log out/i });
  await expect(logout).toBeVisible();
  await logout.click();
  await expect(page).toHaveURL(/\/users\/log_in/);
  await expect(page.getByText('Logged out successfully.', { exact: true })).toBeVisible();
}

test('generated B2C email authentication journey', async ({ page }) => {
  const email = collisionEmail;
  const password = 'GeneratedAuthPassword123!';

  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'registration');
  await page.getByLabel('Email', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: /create an account/i }).click();
  await expect(page).not.toHaveURL(/\/users\/register/);
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  await assertAuthState(page, 'login after registration');

  const confirmationLink = await extractConfirmationLink(page, email);
  await page.goto(confirmationLink);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);

  await logOut(page);
  await assertAuthState(page, 'logged-out login');

  await logInWithPassword(page, email, password);
  await expect(page.getByRole('button', { name: /log out/i })).toBeVisible();
  await logOut(page);
  await assertAuthState(page, 'logged-out login');

  const magicLinkForm = page.locator('#magic_link_form');
  await assertAuthState(page, 'login magic-link request');
  await magicLinkForm.getByLabel('Email for sign-in link', { exact: true }).fill(email);
  await magicLinkForm.getByRole('button', { name: 'Email me a sign-in link' }).click();
  await expect(page.getByText(/If your email is registered/i)).toBeVisible();
  await assertAuthState(page, 'magic-link sent');

  const magicLink = await extractMagicLink(page, email);
  await page.goto(magicLink);
  await expect(page.getByRole('button', { name: /log out/i })).toBeVisible();
  await logOut(page);

  await page.goto('/users/reset-password');
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'reset request');
  await page.getByLabel('Email', { exact: true }).fill(email);
  await page.getByRole('button', { name: 'Send reset instructions' }).click();
  await expect(page).toHaveURL(/\/users\/log_in/);
  await assertAuthState(page, 'reset sent login');

  const resetLink = await extractPasswordResetLink(page, email);
  await page.goto(resetLink);
  await waitForLiveViewReady(page);
  await assertAuthState(page, 'reset token form');

  const replacementPassword = 'GeneratedAuthReplacementPassword123!';
  await page.getByLabel('New password', { exact: true }).fill(replacementPassword);
  await page.getByLabel('Confirm new password', { exact: true }).fill(replacementPassword);
  await page.getByRole('button', { name: 'Reset password' }).click();
  await expect(page).not.toHaveURL(/\/users\/reset-password/);
  await expect(page.getByRole('button', { name: /log out/i })).toBeVisible();
  await logOut(page);
  await assertAuthState(page, 'logged-out login');

  await logInWithPassword(page, email, password);
  await expect(page.getByText('Invalid email or password', { exact: true })).toBeVisible();
  await expect(page).toHaveURL(/\/users\/log_in/);
  await assertAuthState(page, 'login invalid password');

  await logInWithPassword(page, email, replacementPassword);
  await expect(page.getByRole('button', { name: /log out/i })).toBeVisible();
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
  expect(
    oidcRequests.map((requestUrl) => new URL(requestUrl).pathname).sort(),
  ).toEqual(['/oidc/.well-known/openid-configuration', '/oidc/authorize', '/oidc/token']);
});
