import { expect, test } from '@playwright/test';

const email = 'alice@demo.tasklane.test';
const password = 'AliceDemoPass1!';

const mediaCache = 'tasklane-learning-twin-media-v1';

async function logIn(page: import('@playwright/test').Page) {
  await page.goto('/users/log_in');
  await page.locator('#login_form').getByLabel('Email').fill(email);
  await page.locator('#login_form').getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Log in' }).click();
}

async function markerState(page: import('@playwright/test').Page) {
  return page.evaluate(async () => {
    const db = await new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open('tasklane-learning-twin');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const records = await new Promise<Array<{ key: string; value: { partition: string; url: string } }>>((resolve, reject) => {
      const request = db.transaction('media_markers').objectStore('media_markers').openCursor();
      const entries: Array<{ key: string; value: { partition: string; url: string } }> = [];
      request.onsuccess = () => {
        const cursor = request.result;
        if (!cursor) return resolve(entries);
        entries.push({ key: String(cursor.key), value: cursor.value });
        cursor.continue();
      };
      request.onerror = () => reject(request.error);
    });
    db.close();
    return records;
  });
}

async function storageState(page: import('@playwright/test').Page) {
  return page.evaluate(async () => {
    const cache = await caches.open('tasklane-learning-twin-media-v1');
    return { cached: (await cache.keys()).map((request) => new URL(request.url).pathname), markers: await markerState() };

    async function markerState() {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const records = await new Promise<Array<{ key: string; value: { partition: string; url: string } }>>((resolve, reject) => {
        const request = db.transaction('media_markers').objectStore('media_markers').openCursor();
        const entries: Array<{ key: string; value: { partition: string; url: string } }> = [];
        request.onsuccess = () => {
          const cursor = request.result;
          if (!cursor) return resolve(entries);
          entries.push({ key: String(cursor.key), value: cursor.value });
          cursor.continue();
        };
        request.onerror = () => reject(request.error);
      });
      db.close();
      return records;
    }
  });
}

async function prepareLesson(page: import('@playwright/test').Page) {
  await logIn(page);
  await page.goto('/app/lesson');
  await expect(page.getByRole('button', { name: 'Make available offline' })).toBeEnabled();
}

test.describe('media integrity', () => {
  test('promotes two exact media responses marker-last and exposes the accessible available state', async ({ page }) => {
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();

    await expect(page.getByTestId('twin-offline-panel')).toHaveAttribute('aria-busy', 'true');
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Checking lesson media…');
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Available offline');
    await expect(page.getByRole('button', { name: 'Record practice' })).toBeFocused();

    const stored = await storageState(page);
    expect(stored.cached).toEqual(expect.arrayContaining(['/app/lesson/media/image/v1', '/app/lesson/media/audio/v1']));
    expect(stored.markers).toHaveLength(2);
    expect(new Set(stored.markers.map(({ key }) => key))).toHaveSize(2);
  });

  for (const [name, route] of [
    ['short response', async (response: import('@playwright/test').APIResponse) => (await response.body()).subarray(0, 8)],
    ['same-size corrupt response', async (response: import('@playwright/test').APIResponse) => {
      const bytes = await response.body();
      const changed = Uint8Array.from(bytes);
      changed[0] ^= 1;
      return changed;
    }],
  ] as const) {
    test(`rejects a ${name} without a ready marker`, async ({ page, request }) => {
      const response = await request.get('/app/lesson/media/audio/v1');
      const body = await route(response);
      await page.route('**/app/lesson/media/audio/v1', (intercept) => intercept.fulfill({ status: 200, contentType: 'audio/mpeg', body }));

      await prepareLesson(page);
      await page.getByRole('button', { name: 'Make available offline' }).click();
      await expect(page.getByTestId('twin-offline-status')).toHaveText('Lesson media could not be prepared. Connect to the internet and try again.');
      await expect(page.getByRole('button', { name: 'Try again' })).toBeFocused();

      const stored = await storageState(page);
      expect(stored.markers).toHaveLength(0);
      expect(stored.cached).not.toContain('/app/lesson/media/audio/v1');
    });
  }

  test('rejects an interrupted body and the one-shot worker cache-write failure without markers', async ({ page }) => {
    await page.route('**/app/lesson/media/audio/v1', (intercept) => intercept.abort('failed'));
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeFocused();
    expect((await storageState(page)).markers).toHaveLength(0);

    await page.unroute('**/app/lesson/media/audio/v1');
    const forced = page.evaluate(async () => {
      const registration = await navigator.serviceWorker.ready;
      return await new Promise<string>((resolve) => {
        const channel = new MessageChannel();
        channel.port1.onmessage = (event) => resolve(event.data.type);
        registration.active?.postMessage({ type: 'force-cache-put-failure' }, [channel.port2]);
      });
    });
    await expect.poll(() => forced).toBe('cache-write-failed');
    await page.getByRole('button', { name: 'Try again' }).click();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeFocused();
    expect((await storageState(page)).markers).toHaveLength(0);

    await page.getByRole('button', { name: 'Try again' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Available offline');
    expect((await storageState(page)).markers).toHaveLength(2);
  });

  test('keeps an orphaned cache response unavailable on activation', async ({ page, request }) => {
    const media = await request.get('/app/lesson/media/audio/v1');
    await prepareLesson(page);
    await page.evaluate(async (body) => {
      const cache = await caches.open('tasklane-learning-twin-media-v1');
      await cache.put('/app/lesson/media/audio/v1', new Response(Uint8Array.from(body), { headers: { 'content-type': 'audio/mpeg' } }));
    }, Array.from(await media.body()));

    await page.context().setOffline(true);
    await page.goto('/app/lesson');
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/unavailable/i);
    await expect(page.getByTestId('twin-lesson')).toBeHidden();
    await page.context().setOffline(false);
  });
});

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
