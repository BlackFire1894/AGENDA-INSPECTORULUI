// Persistență locală: IndexedDB (cu localStorage ca rezervă). Datele nu părăsesc tableta.
const DB_NAME = 'agenda-inspectorului';
const DB_VERSION = 1;
const LS_KEY = 'agenda-inspectorului:v1';

let dbp = null;

function openDB() {
  if (dbp) return dbp;
  dbp = new Promise((resolve, reject) => {
    if (!('indexedDB' in window)) return reject(new Error('IndexedDB indisponibil'));
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('controls')) db.createObjectStore('controls', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('meta')) db.createObjectStore('meta');
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbp;
}

function tx(store, mode, fn) {
  return openDB().then((db) => new Promise((resolve, reject) => {
    const t = db.transaction(store, mode);
    const s = t.objectStore(store);
    const r = fn(s);
    t.oncomplete = () => resolve(r && 'result' in r ? r.result : undefined);
    t.onerror = () => reject(t.error);
    t.onabort = () => reject(t.error);
  }));
}

let useLS = false;
function lsRead() {
  try { return JSON.parse(localStorage.getItem(LS_KEY)) || { controls: {}, meta: {} }; } catch { return { controls: {}, meta: {} }; }
}
function lsWrite(d) {
  try { localStorage.setItem(LS_KEY, JSON.stringify(d)); } catch (e) { console.error(e); throw e; }
}

export async function init() {
  try {
    await openDB();
  } catch (e) {
    console.warn('Folosesc localStorage:', e);
    useLS = true;
  }
  // Cere stocare persistentă (Safari o acordă aplicațiilor instalate pe ecranul principal).
  try {
    if (navigator.storage?.persist) return await navigator.storage.persist();
  } catch { /* ignorat */ }
  return false;
}

export async function isPersisted() {
  try { return !!(await navigator.storage?.persisted?.()); } catch { return false; }
}

export async function loadAll() {
  if (useLS) return Object.values(lsRead().controls);
  return tx('controls', 'readonly', (s) => s.getAll());
}

export async function saveControl(c) {
  if (useLS) { const d = lsRead(); d.controls[c.id] = c; lsWrite(d); return; }
  await tx('controls', 'readwrite', (s) => s.put(c));
}

export async function deleteControl(id) {
  if (useLS) { const d = lsRead(); delete d.controls[id]; lsWrite(d); return; }
  await tx('controls', 'readwrite', (s) => s.delete(id));
}

export async function replaceAll(list) {
  if (useLS) { const d = lsRead(); d.controls = Object.fromEntries(list.map((c) => [c.id, c])); lsWrite(d); return; }
  await tx('controls', 'readwrite', (s) => { s.clear(); for (const c of list) s.put(c); });
}

export async function getMeta(key) {
  if (useLS) return lsRead().meta[key];
  return tx('meta', 'readonly', (s) => s.get(key));
}

export async function setMeta(key, value) {
  if (useLS) { const d = lsRead(); d.meta[key] = value; lsWrite(d); return; }
  await tx('meta', 'readwrite', (s) => s.put(value, key));
}
