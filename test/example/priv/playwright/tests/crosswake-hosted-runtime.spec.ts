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

  await page.evaluate(() => {
    const csrfToken = document
      .querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
      ?.content;

    if (!csrfToken) throw new Error('missing rendered CSRF token');

    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/crosswake/start';

    const csrfInput = document.createElement('input');
    csrfInput.type = 'hidden';
    csrfInput.name = '_csrf_token';
    csrfInput.value = csrfToken;
    form.append(csrfInput);

    document.body.append(form);
    form.submit();
  });

  const returnUrl = new URL((await returnRequest).url());
  const appNavigation = await appRequest;
  expect(appNavigation.headers()['referer']).toBeUndefined();

  const sentinels = ['continuation', 'state', 'pkce_verifier'].map((key) => {
    const value = returnUrl.searchParams.get(key);
    if (!value) throw new Error(`missing ${key} from local return`);
    return value;
  });

  await expect(page).toHaveURL(/\/app$/);
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
  await expect(page.locator('[data-testid="app-account-home"]')).toBeVisible();
  await expect(page.getByRole('heading', { name: /welcome back/i })).toBeVisible();

  const finalUrl = page.url();
  const finalContent = await page.locator('body').textContent();

  for (const sentinel of [
    ...sentinels,
    'return_ref',
    'authority',
    'route',
    'destination',
    'binding',
    'token',
    'database identifier',
  ]) {
    expect(finalUrl).not.toContain(sentinel);
    expect(finalContent?.toLowerCase()).not.toContain(sentinel.toLowerCase());
  }
});
