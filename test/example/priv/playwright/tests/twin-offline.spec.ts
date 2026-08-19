import { expect, test } from '@playwright/test';
import { assertThemeAttributes, loginDemoAdmin } from '../helpers/adminFlows';

const email = 'alice@demo.tasklane.test';
const password = 'AliceDemoPass1!';

test.afterEach(async ({ page }) => {
  await page.context().setOffline(false);
});

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
  await expect(page.locator('html')).toHaveAttribute('data-twin-runtime-ready', 'true');
  await expect(page.getByRole('button', { name: 'Make available offline' })).toBeEnabled();
}

async function currentActivation(page: import('@playwright/test').Page) {
  return page.evaluate(async () => {
    const db = await new Promise<IDBDatabase>((resolve, reject) => {
      const request = indexedDB.open('tasklane-learning-twin');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const request = db.transaction('current_activation').objectStore('current_activation').get('current');
    const current = await new Promise((resolve, reject) => { request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    db.close();
    return current;
  });
}

async function logoutAfterActivationClears(page: import('@playwright/test').Page) {
  await page.evaluate(() => {
    const nativeSubmit = HTMLFormElement.prototype.submit;
    let intercepted: HTMLFormElement | undefined;
    (window as typeof window & { twinLogoutProof?: Record<string, unknown>; releaseTwinLogout?: () => void }).releaseTwinLogout = () => {
      HTMLFormElement.prototype.submit = nativeSubmit;
      nativeSubmit.call(intercepted!);
    };
    HTMLFormElement.prototype.submit = function() {
      if (new URL(this.action).pathname !== '/users/log_out') return nativeSubmit.call(this);
      intercepted = this;
      const fields = new FormData(this);
      const dbRequest = indexedDB.open('tasklane-learning-twin');
      dbRequest.onsuccess = () => {
        const db = dbRequest.result;
        const request = db.transaction('current_activation').objectStore('current_activation').get('current');
        request.onsuccess = () => {
          (window as typeof window & { twinLogoutProof?: Record<string, unknown> }).twinLogoutProof = {
            activation: request.result,
            method: this.method,
            deleteMethod: fields.get('_method'),
            csrf: fields.get('_csrf_token'),
          };
          db.close();
        };
      };
    };
  });
  await page.getByTestId('header-log-out').click();
  await expect.poll(() => page.evaluate(() => Boolean((window as typeof window & { twinLogoutProof?: unknown }).twinLogoutProof))).toBe(true);
  const proof = await page.evaluate(() => (window as typeof window & { twinLogoutProof: { activation: unknown; method: string; deleteMethod: string; csrf: string } }).twinLogoutProof);
  expect(proof.activation).toBeUndefined();
  expect(proof.method.toLowerCase()).toBe('post');
  expect(proof.deleteMethod).toBe('delete');
  expect(proof.csrf).toBeTruthy();
  await page.evaluate(() => (window as typeof window & { releaseTwinLogout: () => void }).releaseTwinLogout());
  await expect(page).toHaveURL(/\/$/);
}

async function logInAsBob(page: import('@playwright/test').Page) {
  await page.goto('/users/log_in');
  await page.locator('#login_form').getByLabel('Email').fill('bob@demo.tasklane.test');
  await page.locator('#login_form').getByLabel('Password').fill('BobDemoPass1!Beta');
  await page.getByRole('button', { name: 'Log in' }).click();
}

test.describe('media integrity', () => {
  test('promotes two exact media responses marker-last and exposes the accessible available state', async ({ page }) => {
    await prepareLesson(page);
    let releaseImage: () => void;
    const imageHeld = new Promise<void>((resolve) => { releaseImage = resolve; });
    await page.route('**/app/lesson/media/image/v1', async (intercept) => {
      await imageHeld;
      await intercept.continue();
    });
    await page.getByRole('button', { name: 'Make available offline' }).click();

    await expect(page.getByTestId('twin-offline-panel')).toHaveAttribute('aria-busy', 'true');
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Checking lesson media…');
    releaseImage!();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
    await expect(page.getByRole('button', { name: 'Make available offline' })).toBeFocused();

    const stored = await storageState(page);
    expect(stored.cached).toEqual(expect.arrayContaining(['/app/lesson/media/image/v1', '/app/lesson/media/audio/v1']));
    expect(stored.markers).toHaveLength(2);
    expect(new Set(stored.markers.map(({ key }) => key)).size).toBe(2);
  });

  for (const [name, route] of [
    ['short response', (bytes: Uint8Array) => bytes.subarray(0, 8)],
    ['same-size corrupt response', (bytes: Uint8Array) => {
      const changed = Uint8Array.from(bytes);
      changed[0] ^= 1;
      return changed;
    }],
  ] as const) {
    test(`rejects a ${name} without a ready marker`, async ({ page }) => {
      const mutated = route(new TextEncoder().encode('market-morning-audio-v1'));
      await page.route('**/app/lesson/media/audio/v1', (intercept) => intercept.fulfill({ status: 200, contentType: 'audio/mpeg', body: Buffer.from(mutated) }));
      await prepareLesson(page);

      await page.getByRole('button', { name: 'Make available offline' }).click();
      await expect(page.getByTestId('twin-offline-status')).toHaveText('Lesson media could not be prepared. Connect to the internet and try again.');
      await expect(page.getByRole('button', { name: 'Try again' })).toBeFocused();

      const stored = await storageState(page);
      expect(stored.markers.filter(({ value }) => value.url.endsWith('/audio/v1'))).toHaveLength(0);
      expect(stored.cached).not.toContain('/app/lesson/media/audio/v1');
    });
  }

  test('rejects an interrupted body and the one-shot worker cache-write failure without markers', async ({ page }) => {
    await page.route('**/app/lesson/media/audio/v1', (intercept) => intercept.abort('failed'));
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeFocused();
    expect((await storageState(page)).markers.filter(({ value }) => value.url.endsWith('/audio/v1'))).toHaveLength(0);

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
    expect((await storageState(page)).markers.filter(({ value }) => value.url.endsWith('/audio/v1'))).toHaveLength(0);

    await page.getByRole('button', { name: 'Try again' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
    expect((await storageState(page)).markers).toHaveLength(2);
  });

  test('keeps an orphaned cache response unavailable on activation', async ({ page }) => {
    await prepareLesson(page);
    const body = await page.evaluate(async () => Array.from(new Uint8Array(await (await fetch('/app/lesson/media/audio/v1')).arrayBuffer())));
    await page.evaluate(async (body) => {
      const cache = await caches.open('tasklane-learning-twin-media-v1');
      await cache.put('/app/lesson/media/audio/v1', new Response(Uint8Array.from(body), { headers: { 'content-type': 'audio/mpeg' } }));
    }, body);

    await page.context().setOffline(true);
    await page.goto('/app/lesson');
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Offline study has expired. Connect and sign in to continue.');
    await expect(page.locator('#twin-expired-heading')).toBeFocused();
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

  await expect(page.locator('html')).toHaveAttribute('data-twin-runtime-ready', 'true');
  await page.getByRole('button', { name: 'Make available offline' }).click();
  await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
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
  await expect(page.getByRole('heading', { name: 'Market morning' })).toBeVisible();
  await expect(page.getByRole('img', { name: /market morning/i })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Practice update', exact: true })).toBeVisible();
  await page.getByLabel('Action').selectOption('answer');
  await page.getByLabel('Your answer').fill('mango');
  await page.getByRole('button', { name: 'Save practice update' }).click();
  await expect(page.getByTestId('twin-replay-receipts')).toContainText('Practice update queued');
  await page.context().setOffline(false);
});

test.describe('lease, partition, logout, account switch, practice form, and theme', () => {
  test('expires a local lease, prevents replay, and focuses the generic recovery heading', async ({ page }) => {
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
    await page.evaluate(async () => {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const tx = db.transaction('current_activation', 'readwrite');
      tx.objectStore('current_activation').put({ partition: 'expired', expires_at: '2000-01-01T00:00:00.000Z' }, 'current');
      await new Promise<void>((resolve, reject) => { tx.oncomplete = () => resolve(); tx.onerror = () => reject(tx.error); });
      db.close();
    });
    await page.context().setOffline(true);
    await page.reload();
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Offline study has expired. Connect and sign in to continue.');
    await expect(page.locator('#twin-expired-heading')).toBeFocused();
    await expect(page.getByRole('button', { name: 'Save practice update' })).toHaveCount(0);
  });

  test('logout clears the activation before submitting DELETE, reports cleanup failure, and keeps the next account isolated', async ({ page }) => {
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await page.getByLabel('Action').selectOption('answer');
    await page.getByLabel('Your answer').fill('alice only');
    await page.context().setOffline(true);
    await page.getByRole('button', { name: 'Save practice update' }).click();
    await page.context().setOffline(false);
    await page.evaluate(() => {
      (window as typeof window & { twinOriginalIndexedDbOpen?: typeof indexedDB.open }).twinOriginalIndexedDbOpen = indexedDB.open.bind(indexedDB);
      Object.defineProperty(indexedDB, 'open', { configurable: true, value: () => { throw new Error('indexeddb unavailable'); } });
    });
    await page.getByTestId('header-log-out').click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText('Unable to clear offline study data. Please try again before logging out.');
    await expect(page).toHaveURL(/\/app\/lesson/);
    await page.evaluate(() => Object.defineProperty(indexedDB, 'open', {
      configurable: true,
      value: (window as typeof window & { twinOriginalIndexedDbOpen: typeof indexedDB.open }).twinOriginalIndexedDbOpen,
    }));
    await page.getByTestId('header-log-out').click();
    await expect(page).toHaveURL(/\/$/);
    const currentAfterLogout = await currentActivation(page);
    expect(currentAfterLogout).toBeUndefined();

    await logInAsBob(page);
    await page.goto('/app/lesson');
    await expect(page.locator('html')).toHaveAttribute('data-twin-runtime-ready', 'true');
    await expect(page.getByTestId('twin-replay-receipts')).not.toContainText('alice only');
    await expect(page.getByTestId('twin-replay-receipts')).not.toContainText('Practice update queued');
  });

  for (const [name, failBoot] of [
    ['failed bootstrap', true],
    ['rejected replay', false],
  ] as const) {
    test(`${name} still binds logout cleanup before account switching`, async ({ page }) => {
      await prepareLesson(page);
      await page.getByRole('button', { name: 'Make available offline' }).click();

      if (failBoot) {
        await page.route('**/app/lesson/bootstrap', (route) => route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ outcome: 'unavailable' }) }));
      } else {
        await page.getByLabel('Action').selectOption('answer');
        await page.getByLabel('Your answer').fill('alice queued replay');
        await page.context().setOffline(true);
        await page.getByRole('button', { name: 'Save practice update' }).click();
        await page.context().setOffline(false);
        await page.route('**/app/lesson/replay', (route) => route.abort('failed'));
      }

      await page.reload();

      if (failBoot) {
        await expect(page.getByTestId('twin-offline-status')).toHaveText('Lesson media could not be prepared. Connect to the internet and try again.');
        await page.unroute('**/app/lesson/bootstrap');
      } else {
        await expect(page.locator('html')).toHaveAttribute('data-twin-runtime-ready', 'true');
        await expect(page.getByTestId('twin-replay-receipts')).toContainText('Practice update queued');
        await page.unroute('**/app/lesson/replay');
      }

      await logoutAfterActivationClears(page);
      expect(await currentActivation(page)).toBeUndefined();
      await logInAsBob(page);
      await page.goto('/app/lesson');
      await expect(page.locator('html')).toHaveAttribute('data-twin-runtime-ready', 'true');
      await page.context().setOffline(true);
      await page.reload();
      await expect(page.getByTestId('twin-offline-status')).toHaveText('Offline study has expired. Connect and sign in to continue.');
      await expect(page.getByRole('heading', { name: 'Market morning' })).toHaveCount(0);
    });
  }

  test('practice form retains invalid input without a receipt and queues one bounded action when valid', async ({ page }) => {
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);

    await expect(page.getByRole('heading', { name: 'Practice update', exact: true })).toBeVisible();
    await page.getByLabel('Your answer').fill('mango');
    await page.getByRole('button', { name: 'Save practice update' }).click();
    await expect(page.getByText('Choose an action before saving your practice update.')).toBeVisible();
    await expect(page.getByLabel('Your answer')).toHaveValue('mango');
    await expect(page.getByTestId('twin-replay-receipts')).toHaveText(/No practice updates yet/);

    await page.getByLabel('Action').selectOption('answer');
    await page.getByLabel('Your answer').fill('界'.repeat(41));
    await page.getByRole('button', { name: 'Save practice update' }).click();
    await expect(page.getByTestId('twin-practice-error')).toHaveText('Your answer must be 120 bytes or fewer.');
    await expect(page.getByTestId('twin-replay-receipts')).toHaveText(/No practice updates yet/);

    await page.getByLabel('Your answer').fill('mango');
    await page.context().setOffline(true);
    await page.getByRole('button', { name: 'Save practice update' }).click();
    await expect(page.getByTestId('twin-replay-receipts')).toHaveText(/Practice update queued/);

    const outbox = await page.evaluate(async () => {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const entries = await new Promise<unknown[]>((resolve, reject) => {
        const request = db.transaction('outbox').objectStore('outbox').getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      db.close();
      return entries;
    });
    expect(outbox).toHaveLength(1);
    expect(outbox[0]).toMatchObject({ action: 'answer', answer: 'mango', base_checkpoint: 'market-morning-v1' });
    expect(JSON.stringify(outbox[0])).not.toMatch(/cookie|token|credential|digest/i);
  });
});

test('admin Light, Dark, and System preferences resolve through the keyboard-reachable theme control contract', async ({ page }) => {
  await loginDemoAdmin(page);
  await page.goto('/admin');
  const themes = page.getByRole('radiogroup', { name: 'Theme' });
  await expect(themes).toBeVisible();
  for (const theme of ['Light', 'Dark', 'System'] as const) {
    await expect(themes.getByRole('radio', { name: theme })).toBeVisible();
    await page.evaluate((value) => localStorage.setItem('sigra.admin.theme', value), theme.toLowerCase());
    await page.reload();
    await assertThemeAttributes(page, theme.toLowerCase() as 'light' | 'dark' | 'system');
  }
});

test('320px lesson and long-copy accessibility matrix preserve wrapping, focus, and reachable controls', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await prepareLesson(page);
  await page.evaluate(() => {
    const long = 'Localized checkpoint explanation with a deliberately unbrokenidentifierthatmustwrap '.repeat(4);
    document.querySelector('[data-testid="twin-lesson"] h1')!.textContent = long;
    document.querySelector('[data-testid="twin-lesson"] p')!.textContent = long;
    document.querySelector('[data-testid="twin-offline-status"]')!.textContent = long;
    document.querySelector('[data-testid="twin-practice-error"]')!.textContent = long;
    document.querySelector('[data-testid="twin-practice-error"]')!.removeAttribute('hidden');
  });
  const pageWidth = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }));
  expect(pageWidth.scroll).toBeLessThanOrEqual(pageWidth.client);
  for (const locator of [page.getByRole('img', { name: /market morning/i }), page.locator('audio'), page.getByRole('button', { name: 'Make available offline' }), page.getByRole('button', { name: 'Save practice update' })]) {
    await expect(locator).toBeVisible();
    const box = await locator.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.x + box!.width).toBeLessThanOrEqual(320);
  }
  await page.getByRole('button', { name: 'Save practice update' }).focus();
  await expect(page.getByRole('button', { name: 'Save practice update' })).toBeFocused();
  await expect(page.getByTestId('twin-practice-error')).toBeVisible();
});

test.describe('replay receipts', () => {
  async function queuePractice(page: import('@playwright/test').Page, answer = 'mango') {
    await prepareLesson(page);
    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
    await page.getByLabel('Action').selectOption('answer');
    await page.getByLabel('Your answer').fill(answer);
    await page.context().setOffline(true);
    await page.getByRole('button', { name: 'Save practice update' }).click();
    await expect(page.getByTestId('twin-replay-receipts').getByRole('list')).toBeVisible();
    return page.getByTestId('twin-replay-receipts');
  }

  test('renders semantic empty and queued receipt states without internal identifiers', async ({ page }) => {
    await prepareLesson(page);
    const receiptPanel = page.getByTestId('twin-replay-receipts');
    await expect(receiptPanel.getByRole('heading', { name: 'No practice updates yet' })).toBeVisible();
    await expect(receiptPanel).toContainText('Offline updates will be checked when you reconnect.');

    await page.getByRole('button', { name: 'Make available offline' }).click();
    await expect(page.getByTestId('twin-offline-status')).toHaveText(/Available offline/);
    await page.getByLabel('Action').selectOption('answer');
    await page.getByLabel('Your answer').fill('mango');
    await page.context().setOffline(true);
    await page.getByRole('button', { name: 'Save practice update' }).click();

    await expect(receiptPanel.getByRole('list')).toBeVisible();
    await expect(receiptPanel.getByRole('listitem')).toHaveCount(1);
    await expect(receiptPanel).toContainText('Practice update queued — it will be checked when you reconnect.');
    await expect(receiptPanel).not.toContainText(/client_mutation_id|partition|credential|digest/i);
    await page.context().setOffline(false);
  });

  test('reconnect accepts one queued row once and retains the first terminal timestamp on duplicate replay', async ({ page }) => {
    const receiptPanel = await queuePractice(page);
    const replay = page.waitForResponse((response) => response.url().includes('/app/lesson/replay') && response.request().method() === 'POST');
    await page.context().setOffline(false);
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await replay;
    await expect(receiptPanel.getByRole('listitem')).toHaveCount(1);
    await expect(receiptPanel).toContainText('Practice update accepted.');
    const firstTimestamp = await receiptPanel.getByTestId('twin-receipt-timestamp').textContent();

    await page.context().setOffline(false);
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await expect(receiptPanel.getByRole('listitem')).toHaveCount(1);
    await expect(receiptPanel.getByTestId('twin-receipt-timestamp')).toHaveText(firstTimestamp!);
  });

  test('an already-online reload replays the current partition once through the authenticated foreground route', async ({ page }) => {
    await queuePractice(page);
    const reopened = await page.context().newPage();
    await page.close();
    let replayCount = 0;
    await reopened.route('**/app/lesson/replay', async (route) => {
      replayCount += 1;
      await route.continue();
    });

    await reopened.context().setOffline(false);
    await reopened.goto('/app/lesson');

    const receiptPanel = reopened.getByTestId('twin-replay-receipts');
    await expect(receiptPanel).toContainText('Practice update accepted.');
    await expect(receiptPanel.getByRole('listitem')).toHaveCount(1);
    await expect.poll(() => replayCount).toBe(1);

    const outbox = await reopened.evaluate(async () => {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const request = db.transaction('outbox').objectStore('outbox').getAll();
      const entries = await new Promise<Array<{ status?: string; terminal_at?: string }>>((resolve, reject) => {
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      db.close();
      return entries;
    });
    expect(outbox).toHaveLength(1);
    expect(outbox[0]).toMatchObject({ status: 'accepted' });
    expect(outbox[0].terminal_at).toBeTruthy();
  });

  test('a rejected outcome keeps one row with distinct recovery copy', async ({ page }) => {
    const rejected = await queuePractice(page);
    await page.evaluate(async () => {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const tx = db.transaction('outbox', 'readwrite');
      const store = tx.objectStore('outbox');
      const entries = await new Promise<Array<{ [key: string]: string }>>((resolve, reject) => {
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const entry = entries.at(-1)!;
      entry.action = 'review';
      store.put(entry, `${entry.partition}:${entry.idempotency_key}`);
      await new Promise<void>((resolve, reject) => { tx.oncomplete = () => resolve(); tx.onerror = () => reject(tx.error); });
      db.close();
    });
    await page.context().setOffline(false);
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await expect(rejected).toContainText('Practice update rejected. Review your answer and try again.');
    await expect(rejected).not.toContainText('Practice update accepted.');
    await expect(rejected.getByRole('listitem')).toHaveCount(1);
  });

  test('a conflict preserves learner state and moves review focus locally', async ({ page }) => {
    const conflict = await queuePractice(page);
    await page.evaluate(async () => {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open('tasklane-learning-twin');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const tx = db.transaction('outbox', 'readwrite');
      const store = tx.objectStore('outbox');
      const entries = await new Promise<Array<{ [key: string]: string }>>((resolve, reject) => {
        const request = store.getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const entry = entries.at(-1)!;
      entry.base_checkpoint = 'stale-checkpoint';
      store.put(entry, `${entry.partition}:${entry.idempotency_key}`);
      await new Promise<void>((resolve, reject) => { tx.oncomplete = () => resolve(); tx.onerror = () => reject(tx.error); });
      db.close();
    });
    await page.context().setOffline(false);
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await expect(conflict).toContainText('Practice update conflicts with the current lesson.');
    await conflict.getByRole('button', { name: 'Review lesson' }).click();
    await expect(page.getByTestId('twin-lesson')).toBeFocused();
    await expect(page.getByLabel('Your answer')).toHaveValue('mango');
    await expect(conflict.getByRole('listitem')).toHaveCount(1);
  });
});
