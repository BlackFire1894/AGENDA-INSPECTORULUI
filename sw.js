// Service worker: aplicația pornește instant și funcționează offline.
// Fiecare versiune are propriul cache. Când VERSION se schimbă, iPad-ul descarcă versiunea nouă
// în fundal, iar aplicația afișează „Versiune nouă disponibilă — Actualizează”.
// IMPORTANT: VERSION trebuie să fie identic cu APP_VERSION din js/version.js.
const VERSION = '1.14.0';
const CACHE = `agenda-${VERSION}`;
const ASSETS = [
  './', './index.html', './manifest.webmanifest', './css/app.css',
  './js/app.js', './js/state.js', './js/store.js', './js/model.js', './js/dates.js',
  './js/views.js', './js/editor.js', './js/ui.js', './js/demo.js', './js/version.js', './js/fisa.js', './js/help.js',
  './icons/icon.svg', './icons/apple-touch-icon.png', './icons/icon-192.png', './icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  // cache: 'reload' ocolește cache-ul HTTP, ca să luăm sigur fișierele noi
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS.map((u) => new Request(u, { cache: 'reload' })))));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k.startsWith('agenda-') && k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

// Utilizatorul a apăsat „Actualizează”
self.addEventListener('message', (e) => {
  if (e.data?.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const key = req.mode === 'navigate' ? './index.html' : req;
    const cached = await cache.match(key, { ignoreSearch: true });
    if (cached) return cached;
    try {
      const res = await fetch(req);
      if (res.ok) cache.put(key, res.clone());
      return res;
    } catch {
      return cached || Response.error();
    }
  })());
});
