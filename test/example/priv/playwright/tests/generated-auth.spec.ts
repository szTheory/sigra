import { test, expect, type Page } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';

test.describe.configure({ mode: 'serial' });

const waitForLiveViewReady = async (page: Page) => {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
};

test('generated B2C email authentication journey', async ({ page }) => {
  const suffix = `${Date.now()}-${test.info().parallelIndex}`;
  const email = `generated-auth-${suffix}@example.test`;
  const password = 'GeneratedAuthPassword123!';

  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.getByLabel('Email', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: /create an account/i }).click();
  await expect(page).not.toHaveURL(/\/users\/register/);

  const confirmationLink = await extractConfirmationLink(page, email);
  await page.goto(confirmationLink);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);

});
