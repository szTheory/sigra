import { expect, test as setup, type Page } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { TEST_PASSWORD } from '../helpers/fixtures';
import {
  assertGenericRegistrationResponse,
  signInManually,
} from '../helpers/registration';

const desktopStatePath = 'test-results/.auth/admin-eval-desktop.json';

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  await page.evaluate(async () => { await (document as any).fonts.ready; });
}

async function registerEvalAdmin(page: Page, email: string) {
  // Preserve the early document-ready navigation that avoids the registration-page load hang.
  await page.goto('/users/register', { waitUntil: 'domcontentloaded' });
  await waitForLiveViewReady(page);
  await page.getByRole('textbox', { name: 'Email', exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
  await expect(page.getByRole('status')).toBeVisible();
  await page.getByRole('button', { name: /Create an account/ }).click();
  await assertGenericRegistrationResponse(page);
  await signInManually(page, email, TEST_PASSWORD);
  await waitForLiveViewReady(page);
}

async function persistEvalAdmin(page: Page, email: string, statePath: string) {
  await registerEvalAdmin(page, email);
  await mkdir(dirname(statePath), { recursive: true });
  await page.context().storageState({ path: statePath });
}

// Audited before sharing auth state: the eval cases only inject/remove page-local
// DOM fixtures and write bundles under the gitignored eval/<git-sha>/ directory.
// No eval case sends a server-side account mutation after registration.
setup('authenticate admin eval desktop', async ({ page }) => {
  await persistEvalAdmin(
    page,
    `platform-admin+eval-desktop-${randomUUID()}@example.test`,
    desktopStatePath,
  );
});
