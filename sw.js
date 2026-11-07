const CACHE = 'rtcore-db-v1';
const CORE = [
  './',
  './index.html',
  './manifest.json',
  'https://fonts.googleapis.com/css2?family=Audiowide&family=JetBrains+Mono:wght@400;600;700;800;900&family=Outfit:wght@300;400;500;600;700;800;900&display=swap',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css'
];

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE).catch(err => console.warn('precache:', err))));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (!/^https?:$/.test(url.protocol)) return;

  // JSON / API → network-first con fallback cache
  if (url.pathname.endsWith('.json') || url.hostname === 'raw.githubusercontent.com' || url.hostname === 'cdn.jsdelivr.net') {
    e.respondWith(
      fetch(req)
        .then(r => { if (r.ok) { const c = r.clone(); caches.open(CACHE).then(cc => cc.put(req, c)); } return r; })
        .catch(() => caches.match(req))
    );
    return;
  }

  // Tutto il resto → cache-first
  e.respondWith(
    caches.match(req).then(cached => {
      if (cached) return cached;
      return fetch(req).then(r => {
        if (r.ok) { const c = r.clone(); caches.open(CACHE).then(cc => cc.put(req, c)); }
        return r;
      }).catch(() => cached);
    })
  );
});
