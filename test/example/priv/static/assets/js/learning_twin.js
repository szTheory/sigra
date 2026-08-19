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
  const receiptCopy = {
    queued: 'Practice update queued — it will be checked when you reconnect.',
    accepted: 'Practice update accepted.',
    rejected: 'Practice update rejected. Review your answer and try again.',
    conflict: 'Practice update conflicts with the current lesson.'
  };
  const terminalStatuses = new Set(['accepted', 'rejected', 'conflict']);

  const currentOutbox = async (partition) => {
    const entries = await new Promise((resolve, reject) => transaction('outbox', 'readonly', (objectStore) => {
      const request = objectStore.getAll();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    }));
    return entries.filter((entry) => entry.partition === partition).sort((left, right) => left.queued_at.localeCompare(right.queued_at));
  };
  const receiptTimestamp = (entry) => entry.terminal_at || entry.queued_at;
  const renderReceipts = async (partition) => {
    const root = receipts();
    if (!root || !partition) return;
    const entries = await currentOutbox(partition);
    root.replaceChildren();
    if (!entries.length) {
      const heading = document.createElement('h3');
      heading.className = 'vt-twin__receipt-empty-title';
      heading.textContent = 'No practice updates yet';
      const body = document.createElement('p');
      body.textContent = 'Offline updates will be checked when you reconnect.';
      root.append(heading, body);
      return;
    }

    const list = document.createElement('ol');
    list.className = 'vt-twin__receipt-list';
    for (const entry of entries) {
      const state = terminalStatuses.has(entry.status) ? entry.status : 'queued';
      const row = document.createElement('li');
      row.className = `vt-twin__receipt vt-twin__receipt--${state}`;
      const pill = document.createElement('span');
      pill.className = `vt-status-pill vt-twin__receipt-pill vt-twin__receipt-pill--${state}`;
      pill.dataset.testid = 'twin-receipt-status';
      pill.textContent = state[0].toUpperCase() + state.slice(1);
      const copy = document.createElement('p');
      copy.className = 'vt-twin__receipt-copy';
      copy.textContent = receiptCopy[state];
      const timestamp = document.createElement('time');
      timestamp.className = 'vt-twin__receipt-timestamp';
      timestamp.dataset.testid = 'twin-receipt-timestamp';
      timestamp.dateTime = receiptTimestamp(entry);
      timestamp.textContent = new Date(receiptTimestamp(entry)).toLocaleString();
      row.append(pill, copy, timestamp);
      if (state === 'conflict') {
        const review = document.createElement('button');
        review.type = 'button';
        review.className = 'vt-btn vt-btn--secondary';
        review.textContent = 'Review lesson';
        review.addEventListener('click', () => lessonRoot()?.focus());
        row.append(review);
      }
      list.append(row);
    }
    root.append(list);
  };

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
    await renderReceipts(activation.partition);
  };
  const replay = async (queued) => {
    const response = await fetch('/app/lesson/replay', { method: 'POST', headers: { 'content-type': 'application/json', 'x-csrf-token': csrf() }, body: JSON.stringify({ client_mutation_id: queued.client_mutation_id, idempotency_key: queued.idempotency_key, base_checkpoint: queued.base_checkpoint, action: queued.action, answer: queued.answer }) });
    if (!response.ok) return false;
    const result = await response.json();
    if (result.client_mutation_id !== queued.client_mutation_id || !terminalStatuses.has(result.status) || !result.terminal_at) return false;
    const existing = await get('outbox', outboxKey(queued.partition, queued.idempotency_key));
    if (!existing || terminalStatuses.has(existing.status)) return true;
    await put('outbox', outboxKey(queued.partition, queued.idempotency_key), { ...existing, status: result.status, terminal_at: result.terminal_at });
    return true;
  };
  const replayQueued = async () => {
    if (!navigator.onLine || !currentTwin) return;
    const activation = await get('current_activation', 'current');
    const state = await completeGate(activation);
    if (!state || activation.partition !== currentTwin.partition) return;
    for (const queued of await currentOutbox(activation.partition)) {
      if (terminalStatuses.has(queued.status)) continue;
      await replay(queued);
      await renderReceipts(activation.partition);
    }
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
    await renderReceipts(twin.partition);
    actionButton()?.addEventListener('click', () => prepare(twin));
    document.querySelector('[data-testid="twin-practice-form"]')?.addEventListener('submit', (event) => { event.preventDefault(); queuePractice(event.currentTarget).catch(() => clearCurrent()); });
    window.addEventListener('online', () => replayQueued().catch(() => {}));
    document.querySelector('[data-testid="twin-record-practice"]')?.addEventListener('click', () => replayQueued().catch(() => {}));
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
