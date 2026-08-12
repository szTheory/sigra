import { expect, test } from '@playwright/test';

const DEMO_ALICE_EMAIL = 'alice@demo.tasklane.test';
const DEMO_ALICE_PASSWORD = 'AliceDemoPass1!';

test('hosted Crosswake local return preserves the real cookie jar and clears correlation material', async ({
  page,
}) => {
  await page.goto('/users/log_in');

  const passwordForm = page.locator('#login_form');
  await passwordForm.getByLabel('Email').fill(DEMO_ALICE_EMAIL);
  await passwordForm.getByLabel('Password').fill(DEMO_ALICE_PASSWORD);
  await passwordForm.getByRole('button', { name: 'Log in' }).click();
  await expect(page).not.toHaveURL(/\/users\/log_in/);

  const sessionCookie = (await page.context().cookies()).find((cookie) => cookie.name === '_example_key');
  expect(sessionCookie).toBeDefined();
  expect(sessionCookie?.httpOnly).toBe(true);
  expect(sessionCookie?.sameSite).toBe('Lax');
  // The proof runner deliberately uses MIX_ENV=test over loopback HTTP.
  expect(sessionCookie?.secure).toBe(false);

  const returnRequest = page.waitForRequest((request) => {
    const url = new URL(request.url());
    return request.method() === 'GET' && url.pathname === '/crosswake/return';
  });
  const appRequest = page.waitForRequest((request) => {
    const url = new URL(request.url());
    return (
      request.method() === 'GET' &&
      request.resourceType() === 'document' &&
      url.pathname === '/app'
    );
  });

  await expect(page.getByRole('button', { name: 'Continue to Crosswake' })).toBeVisible();
  await page.getByRole('button', { name: 'Continue to Crosswake' }).click();

  const returnUrl = new URL((await returnRequest).url());
  const appNavigation = await appRequest;
  expect(appNavigation.headers()['referer']).toBeUndefined();

  expect([...returnUrl.searchParams.keys()].sort()).toEqual(['continuation', 'state']);

  const sentinels = ['continuation', 'state'].map((key) => {
    const value = returnUrl.searchParams.get(key);
    if (!value) throw new Error(`missing ${key} from local return`);
    return value;
  });

  await expect(page).toHaveURL(/\/app$/);
  await expect(page.locator('[data-testid="app-account-home"]')).toBeVisible();
  await expect(page.getByRole('heading', { name: /welcome back/i })).toBeVisible();

  const finalUrl = page.url();
  const finalContent = await page.locator('body').textContent();

  expect(returnUrl.toString()).not.toContain('pkce_verifier');
  expect(finalUrl).not.toContain('pkce_verifier');

  for (const sentinel of [
    ...sentinels,
    'return_ref',
    'authority',
    'route',
    'destination',
    'binding',
    'pkce_verifier',
    'token',
    'database identifier',
  ]) {
    expect(finalUrl).not.toContain(sentinel);
    expect(finalContent?.toLowerCase()).not.toContain(sentinel.toLowerCase());
  }
});
