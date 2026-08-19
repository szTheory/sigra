const SHELL_CACHE = 'tasklane-learning-twin-shell-v3';
const SHELL = ['/learning-twin-offline.html', '/assets/js/learning_twin.js', '/assets/css/app.css'];

self.addEventListener('message', (event) => {
  if (event.data?.type !== 'force-cache-put-failure') return;
  event.source?.postMessage({ type: 'cache-write-failed' });
  event.ports[0]?.postMessage({ type: 'cache-write-failed' });
});

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(SHELL_CACHE).then(async (cache) => {
    for (const asset of SHELL) {
      const response = await fetch(asset, { cache: 'reload' });
      if (!response.ok) throw new Error('shell install failed');
      await cache.put(asset, response);
    }
  }));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith('tasklane-learning-twin-shell-') && key !== SHELL_CACHE).map((key) => caches.delete(key)))).then(() => clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || event.request.method !== 'GET') return;
  if (event.request.mode === 'navigate' && url.pathname === '/app/lesson') {
    event.respondWith(fetch(event.request).catch(async () => (await caches.open(SHELL_CACHE)).match('/learning-twin-offline.html')));
    return;
  }
  if (SHELL.includes(decodeURIComponent(url.pathname))) event.respondWith(caches.open(SHELL_CACHE).then(async (cache) => (await cache.match(event.request, { ignoreSearch: true })) || fetch(event.request)));
});
