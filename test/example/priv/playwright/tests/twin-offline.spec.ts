import { expect, test } from '@playwright/test';

const email = 'alice@demo.tasklane.test';
const password = 'AliceDemoPass1!';

test('tracer: authenticated learner installs media, studies offline, and replays once', async ({ page }) => {
  await page.goto('/users/log_in');
  await page.locator('#login_form').getByLabel('Email').fill(email);
  await page.locator('#login_form').getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Log in' }).click();

  await page.goto('/app/lesson');
  await expect(page.locator('[data-testid="twin-lesson"][data-twin-ready="true"]')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Market morning' })).toBeVisible();
  await expect(page.getByRole('img', { name: /market morning/i })).toBeVisible();
  await expect(page.getByText(/transcript/i)).toBeVisible();
  await expect(page.locator('audio[autoplay]')).toHaveCount(0);

  const workerScope = await page.evaluate(async () => (await navigator.serviceWorker.ready).scope);
  expect(new URL(workerScope).pathname).toBe('/app/');
  await page.reload();
  await expect.poll(() => page.evaluate(() => navigator.serviceWorker.controller?.scriptURL ?? '')).toContain(
    '/learning-twin-worker.js',
  );

  await expect(page.getByTestId('twin-offline-status')).toHaveText(/available/i);
  const stored = await page.evaluate(async () => {
    const cache = await caches.open('tasklane-learning-twin-media-v1');
    const keys = await cache.keys();
    const db = await new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open('tasklane-learning-twin');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const names = Array.from(db.objectStoreNames);
    db.close();
    return { cached: keys.length, names };
  });
  expect(stored.cached).toBe(2);
  expect(stored.names).toEqual(expect.arrayContaining(['current_activation', 'media_markers', 'lesson_state', 'outbox']));

  await page.context().setOffline(true);
  await page.reload();
  await expect(page.getByTestId('twin-lesson')).toBeVisible();
  await page.context().setOffline(false);
  await page.reload();

  await page.getByRole('button', { name: 'Record practice' }).click();
  await expect(page.getByTestId('twin-replay-receipts')).toHaveText(/accepted/i);
});
