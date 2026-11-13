const CACHE = 'rtcore-db-v3';
const SHELL = ['./','./index.html','./manifest.json','./assets/spdw_symbol.png','./assets/gamecube.svg','./assets/wii.svg'];

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.all(SHELL.map(path => cache.add(path).catch(error => {
      console.warn('[Rt:Core SW] Could not precache', path, error);
    })));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('rtcore-db-') && key !== CACHE).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!['http:','https:'].includes(url.protocol)) return;

  const isData = url.pathname.endsWith('.json') ||
    url.hostname === 'raw.githubusercontent.com' || url.hostname === 'cdn.jsdelivr.net';
  if (isData) {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE);
          await cache.put(request, response.clone());
        }
        return response;
      } catch (error) {
        const cached = await caches.match(request);
        if (cached) return cached;
        return new Response('Compatibility data is unavailable offline. Reconnect and retry.', {
          status:503, headers:{'Content-Type':'text/plain; charset=utf-8'}
        });
      }
    })());
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE);
          await cache.put('./index.html', response.clone());
        }
        return response;
      } catch (error) {
        return (await caches.match(request)) || (await caches.match('./index.html')) ||
          new Response('Dolphin Rt:Core is unavailable offline.', {status:503});
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && url.origin === self.location.origin) {
      const cache = await caches.open(CACHE);
      await cache.put(request,response.clone());
    }
    return response;
  })());
});
