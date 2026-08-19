(() => {
  const DB = 'tasklane-learning-twin', MEDIA_CACHE = 'tasklane-learning-twin-media-v1';
  const stores = ['current_activation', 'media_markers', 'lesson_state', 'outbox'];
  let forceCachePutFailure = false;

  const open = () => new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    request.onupgradeneeded = () => stores.forEach((name) => request.result.objectStoreNames.contains(name) || request.result.createObjectStore(name));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  const put = async (store, key, value) => {
    const db = await open();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(store, 'readwrite');
      tx.objectStore(store).put(value, key);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  };
  const get = async (store, key) => {
    const db = await open();
    const value = await new Promise((resolve, reject) => {
      const request = db.transaction(store).objectStore(store).get(key);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    db.close();
    return value;
  };
  const remove = async (store, key) => {
    const db = await open();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(store, 'readwrite');
      tx.objectStore(store).delete(key);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  };
  const digest = async (bytes) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))).map((byte) => byte.toString(16).padStart(2, '0')).join('');
  const csrf = () => document.querySelector('meta[name="csrf-token"]')?.content;
  const panel = () => document.querySelector('[data-testid="twin-offline-panel"]');
  const action = () => document.querySelector('[data-testid="twin-offline-action"]');
  const status = (text) => { const node = document.querySelector('[data-testid="twin-offline-status"]'); if (node) node.textContent = text; };
  const setBusy = (busy) => { const node = panel(); if (node) node.setAttribute('aria-busy', String(busy)); const button = action(); if (button) button.disabled = busy; };
  const setUnavailable = () => {
    setBusy(false);
    status('Lesson media could not be prepared. Connect to the internet and try again.');
    const button = action();
    if (button) { button.textContent = 'Try again'; button.focus(); }
  };
  const markerKey = (partition, item) => `${partition}:${item.version}:${item.url}`;
  const cachePut = async (cache, item, bytes) => {
    if (forceCachePutFailure) {
      forceCachePutFailure = false;
      throw new Error('cache-write-failed');
    }
    await cache.put(item.url, new Response(bytes, { headers: { 'content-type': item.content_type } }));
  };
  const installItem = async (cache, item, partition) => {
    const key = markerKey(partition, item);
    try {
      const response = await fetch(item.url);
      if (!response.ok) throw new Error('body-read-failed');
      const bytes = await response.arrayBuffer();
      if (bytes.byteLength !== item.byte_size) throw new Error('short-response');
      if (await digest(bytes) !== item.sha256.toLowerCase()) throw new Error('digest-mismatch');
      await cachePut(cache, item, bytes);
      await put('media_markers', key, { partition, url: item.url, version: item.version, ready: true });
    } catch (error) {
      await remove('media_markers', key).catch(() => {});
      throw error;
    }
  };
  const install = async (manifest, partition) => {
    const cache = await caches.open(MEDIA_CACHE);
    for (const item of manifest) await installItem(cache, item, partition);
  };
  const activate = async (twin) => {
    await put('lesson_state', `${twin.partition}:lesson`, { partition: twin.partition, lesson: twin.lesson, media: twin.media, expires_at: twin.expires_at });
    await put('current_activation', 'current', { partition: twin.partition, expires_at: twin.expires_at });
  };
  const prepare = async (twin) => {
    setBusy(true);
    status('Checking lesson media…');
    try {
      await install(twin.media, twin.partition);
      await activate(twin);
      setBusy(false);
      status('Available offline');
      const button = action();
      if (button) { button.textContent = 'Make available offline'; button.disabled = false; button.focus(); }
    } catch (_) {
      setUnavailable();
    }
  };
  const boot = async () => {
    const response = await fetch('/app/lesson/bootstrap', { headers: { accept: 'application/json' } });
    if (!response.ok) return setUnavailable();
    const twin = await response.json();
    const button = action();
    if (button) button.addEventListener('click', () => prepare(twin));
    document.documentElement.dataset.twinRuntimeReady = 'true';
    await Promise.resolve();
  };
  const replay = async (partition) => {
    const action = { account_partition: partition, client_mutation_id: crypto.randomUUID(), idempotency_key: crypto.randomUUID(), base_checkpoint: 'market-morning-v1' };
    await put('outbox', `${partition}:${action.idempotency_key}`, action);
    const response = await fetch('/app/lesson/replay', { method: 'POST', headers: { 'content-type': 'application/json', 'x-csrf-token': csrf() }, body: JSON.stringify(action) });
    if (response.ok) { const receipt = await response.json(); document.querySelector('[data-testid="twin-replay-receipts"]').textContent = receipt.outcome; }
  };
  const offline = async () => {
    const pointer = await get('current_activation', 'current');
    if (!pointer || new Date(pointer.expires_at) <= new Date()) return;
    const state = await get('lesson_state', `${pointer.partition}:lesson`);
    if (!state || state.partition !== pointer.partition) return;
    const cache = await caches.open(MEDIA_CACHE);
    for (const item of state.media) if (!await get('media_markers', markerKey(pointer.partition, item)) || !await cache.match(item.url)) return;
    const root = document.querySelector('[data-testid="twin-lesson"]');
    root.hidden = false;
    root.innerHTML = `<h1>${state.lesson.title}</h1><p>${state.lesson.prompt}</p><p>${state.lesson.transcript}</p>`;
    status('Available offline');
  };

  navigator.serviceWorker.addEventListener('message', (event) => { if (event.data?.type === 'cache-write-failed') forceCachePutFailure = true; });
  navigator.serviceWorker.register('/learning-twin-worker.js', { scope: '/app/' }).then(() => navigator.serviceWorker.ready).catch(() => {});
  if (document.body.dataset.twinOfflineShell === undefined) boot().catch(setUnavailable); else offline().catch(() => {});
  document.querySelector('[data-testid="twin-record-practice"]')?.addEventListener('click', async () => {
    const pointer = await get('current_activation', 'current');
    if (pointer) await replay(pointer.partition);
  });
})();
