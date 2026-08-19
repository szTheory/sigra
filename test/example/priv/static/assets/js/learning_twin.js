(() => {
  const DB = 'tasklane-learning-twin';
  const MEDIA_CACHE = 'tasklane-learning-twin-media-v1';
  const stores = ['current_activation', 'media_markers', 'lesson_state', 'outbox'];
  let forceCachePutFailure = false;
  let currentTwin = null;

  const open = () => new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    request.onupgradeneeded = () => stores.forEach((name) => request.result.objectStoreNames.contains(name) || request.result.createObjectStore(name));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  const transaction = async (store, mode, callback) => {
    const db = await open();
    try {
      return await new Promise((resolve, reject) => {
        const tx = db.transaction(store, mode);
        const result = callback(tx.objectStore(store));
        tx.oncomplete = () => resolve(result);
        tx.onerror = () => reject(tx.error);
      });
    } finally { db.close(); }
  };
  const put = (store, key, value) => transaction(store, 'readwrite', (objectStore) => objectStore.put(value, key));
  const get = (store, key) => new Promise(async (resolve, reject) => {
    try { await transaction(store, 'readonly', (objectStore) => { const request = objectStore.get(key); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); }); } catch (error) { reject(error); }
  });
  const remove = (store, key) => transaction(store, 'readwrite', (objectStore) => objectStore.delete(key));
  const digest = async (bytes) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))).map((byte) => byte.toString(16).padStart(2, '0')).join('');
  const csrf = () => document.querySelector('meta[name="csrf-token"]')?.content;
  const panel = () => document.querySelector('[data-testid="twin-offline-panel"]');
  const actionButton = () => document.querySelector('[data-testid="twin-offline-action"]');
  const lessonRoot = () => document.querySelector('[data-testid="twin-lesson"]');
  const receipts = () => document.querySelector('[data-testid="twin-replay-receipts"]');
  const status = (text) => { const node = document.querySelector('[data-testid="twin-offline-status"]'); if (node) node.textContent = text; };
  const setBusy = (busy) => { const node = panel(); if (node) node.setAttribute('aria-busy', String(busy)); const button = actionButton(); if (button) button.disabled = busy; };
  const expiredCopy = 'Offline study has expired. Connect and sign in to continue.';
  const isLeaseValid = (activation) => Boolean(activation?.partition && activation.expires_at && new Date() < new Date(activation.expires_at));
  const markerKey = (partition, item) => `${partition}:${item.version}:${item.url}`;
  const stateKey = (partition) => `${partition}:lesson`;
  const outboxKey = (partition, idempotencyKey) => `${partition}:${idempotencyKey}`;

  const replaceWithExpiredState = () => {
    const root = lessonRoot();
    if (!root) return;
    root.hidden = false;
    root.innerHTML = `<h1 id="twin-expired-heading" tabindex="-1">${expiredCopy}</h1>`;
    root.querySelector('#twin-expired-heading')?.focus();
    status(expiredCopy);
  };
  const clearCurrent = async () => {
    await remove('current_activation', 'current');
    currentTwin = null;
    replaceWithExpiredState();
  };
  const setUnavailable = () => {
    setBusy(false);
    status('Lesson media could not be prepared. Connect to the internet and try again.');
    const button = actionButton();
    if (button) { button.textContent = 'Try again'; button.focus(); }
  };
  const cachePut = async (cache, item, bytes) => {
    if (forceCachePutFailure) { forceCachePutFailure = false; throw new Error('cache-write-failed'); }
    await cache.put(item.url, new Response(bytes, { headers: { 'content-type': item.content_type } }));
  };
  const installItem = async (cache, item, partition) => {
    try {
      const response = await fetch(item.url);
      if (!response.ok) throw new Error('body-read-failed');
      const bytes = await response.arrayBuffer();
      if (bytes.byteLength !== item.byte_size || await digest(bytes) !== item.sha256.toLowerCase()) throw new Error('media-integrity-failed');
      await cachePut(cache, item, bytes);
      await put('media_markers', markerKey(partition, item), { partition, url: item.url, version: item.version, ready: true });
    } catch (error) { await remove('media_markers', markerKey(partition, item)).catch(() => {}); throw error; }
  };
  const completeGate = async (activation) => {
    if (!isLeaseValid(activation)) return null;
    const state = await get('lesson_state', stateKey(activation.partition));
    if (!state || state.partition !== activation.partition || !isLeaseValid(state)) return null;
    const cache = await caches.open(MEDIA_CACHE);
    for (const item of state.media) if (!await get('media_markers', markerKey(activation.partition, item)) || !await cache.match(item.url)) return null;
    return state;
  };
  const activate = async (twin) => {
    if (!isLeaseValid(twin)) return clearCurrent();
    await put('lesson_state', stateKey(twin.partition), { partition: twin.partition, lesson: twin.lesson, media: twin.media, expires_at: twin.expires_at });
    await put('current_activation', 'current', { partition: twin.partition, expires_at: twin.expires_at });
  };
  const prepare = async (twin) => {
    if (!isLeaseValid(twin)) return clearCurrent();
    setBusy(true); status('Checking lesson media…');
    try {
      const cache = await caches.open(MEDIA_CACHE);
      for (const item of twin.media) await installItem(cache, item, twin.partition);
      await activate(twin);
      setBusy(false); status(`Available offline. Offline until ${new Date(twin.expires_at).toLocaleString()}.`);
      const button = actionButton(); if (button) { button.textContent = 'Make available offline'; button.disabled = false; button.focus(); }
    } catch (_) { setUnavailable(); }
  };
  const renderOffline = async () => {
    const activation = await get('current_activation', 'current');
    const state = await completeGate(activation);
    if (!state) { await clearCurrent(); return; }
    const root = lessonRoot();
    if (root) root.hidden = false;
    status(`Offline study mode — available until ${new Date(activation.expires_at).toLocaleString()}.`);
  };
  const validPractice = (form) => {
    const action = form.elements.action.value;
    const answer = form.elements.answer.value.trim();
    const error = form.querySelector('[data-testid="twin-practice-error"]');
    const message = !action ? 'Choose an action before saving your practice update.' : !answer ? 'Enter your answer before saving your practice update.' : '';
    error.hidden = !message; error.textContent = message;
    return message ? null : { action, answer };
  };
  const queuePractice = async (form) => {
    const input = validPractice(form); if (!input) return;
    const activation = await get('current_activation', 'current');
    const state = await completeGate(activation);
    if (!state) { await clearCurrent(); return; }
    const idempotencyKey = crypto.randomUUID();
    const queued = { partition: activation.partition, client_mutation_id: crypto.randomUUID(), idempotency_key: idempotencyKey, base_checkpoint: state.lesson.id, action: input.action, answer: input.answer, queued_at: new Date().toISOString() };
    await put('outbox', outboxKey(activation.partition, idempotencyKey), queued);
    if (receipts()) receipts().textContent = 'Practice update queued — it will be checked when you reconnect.';
  };
  const replay = async (partition) => {
    const response = await fetch('/app/lesson/replay', { method: 'POST', headers: { 'content-type': 'application/json', 'x-csrf-token': csrf() }, body: JSON.stringify({ account_partition: partition, client_mutation_id: crypto.randomUUID(), idempotency_key: crypto.randomUUID(), base_checkpoint: 'market-morning-v1' }) });
    if (response.ok && receipts()) receipts().textContent = (await response.json()).status;
  };
  const invalidateForAccountChange = async (twin) => {
    const activation = await get('current_activation', 'current');
    if (activation && activation.partition !== twin.partition) await clearCurrent();
  };
  const boot = async () => {
    const response = await fetch('/app/lesson/bootstrap', { headers: { accept: 'application/json' } });
    if (!response.ok) return setUnavailable();
    const twin = await response.json();
    await invalidateForAccountChange(twin);
    currentTwin = twin;
    actionButton()?.addEventListener('click', () => prepare(twin));
    document.querySelector('[data-testid="twin-practice-form"]')?.addEventListener('submit', (event) => { event.preventDefault(); queuePractice(event.currentTarget).catch(() => clearCurrent()); });
    document.querySelector('[data-testid="twin-record-practice"]')?.addEventListener('click', () => replay(twin.partition));
    document.addEventListener('click', (event) => {
      const logout = event.target.closest('[data-testid="header-log-out"]');
      if (!logout) return;
      event.preventDefault();
      clearCurrent().finally(() => { window.location.assign('/users/log_out'); });
    }, true);
    document.documentElement.dataset.twinRuntimeReady = 'true';
  };

  navigator.serviceWorker.addEventListener('message', (event) => { if (event.data?.type === 'cache-write-failed') forceCachePutFailure = true; });
  navigator.serviceWorker.register('/learning-twin-worker.js?v=3', { scope: '/app/' }).then(() => navigator.serviceWorker.ready).catch(() => {});
  if (document.body.dataset.twinOfflineShell === undefined) boot().catch(setUnavailable); else renderOffline().catch(clearCurrent);
})();
