// Starea aplicației în memorie + salvare automată.
import * as store from './store.js';
import { todayISO } from './dates.js';
import { fixeazaCatalog } from './model.js';

// Preferințe de afișare ale acestei tablete (nu fac parte din date / backup)
function pref(key, fallback) {
  try { const v = localStorage.getItem(key); return v === null ? fallback : JSON.parse(v); } catch { return fallback; }
}
export function savePref(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* rămâne doar pentru sesiunea curentă */ }
}

export const state = {
  controls: [],
  now: new Date(),
  // Stare de interfață (nu se salvează)
  ui: {
    backTo: '#/panou',
    objSearch: '',
    objTip: 'ALL',
    histSearch: '',
    histFilter: 'ALL',
    calYear: new Date().getFullYear(),
    calMonth: new Date().getMonth(),
    calSelected: todayISO(),
    expanded: new Set(),      // construcții deschise
    collapsed: new Set(),     // construcții închise explicit
    nerFilter: 'ALL',
    nerQuery: '',             // căutarea din tabul de nereguli
    constrPick: '',           // neregula al cărei meniu de construcții e deschis
    showAllNer: false,        // arată și neregulile de instalații nebifate DA la dotări
    obsOpen: new Set(),       // câmpuri de observații goale deschise acum („<idControl>|<cale>”)
    toolsOpen: false,         // meniul „⋯” (restrânge / extinde) deschis
    todoOpen: false,          // lista completă „Ce mai aveți de făcut” deschisă
    ghidQuery: '',            // căutarea din Ghidul aplicației
    gpsBusy: '',              // id-ul construcției pentru care se caută poziția
    catCollapsed: new Set(pref('agenda-cats-collapsed', [])),    // categorii de nereguli restrânse
    rowCollapsed: new Set(pref('agenda-rows-collapsed', [])),    // rânduri de nereguli restrânse: „<idControl>|<cheie>”
  },
  meta: { lastBackup: null, sarbatoriVerificate: [] },   // anii pentru care lista sărbătorilor legale a fost verificată
};

// Data de azi se citește mereu direct din ceasul tabletei (nu dintr-o copie), ca să nu rămână în urmă nicio clipă.
export const today = () => todayISO(new Date());

// v1.14: ascunderea observațiilor a fost înlocuită de „+ Obs.”; preferințele ei vechi se șterg
try { localStorage.removeItem('agenda-obs-hidden'); localStorage.removeItem('agenda-obs-override'); } catch { /* stocare indisponibilă */ }

export function getControl(id) {
  return state.controls.find((c) => c.id === id);
}

const pending = new Map();
let timer = null;
const listeners = new Set();

export function onSaveState(fn) { listeners.add(fn); }
function emit(s) { listeners.forEach((fn) => fn(s)); }

// Marchează un control ca modificat și programează salvarea.
// `now`: salvează imediat (atingeri, selecții, date); textul tastat se salvează după o scurtă pauză.
export function touch(c, now = false) {
  c.updatedAt = new Date().toISOString();
  fixeazaCatalog(c);   // încheierea fixează lista de nereguli, redeschiderea o eliberează
  pending.set(c.id, c);
  emit('saving');
  clearTimeout(timer);
  if (now) { flush(); checkpoint(c); } else { timer = setTimeout(flush, 350); scheduleCheckpoint(c); }
}

// ───────── Anulează / Refă (pe control, în sesiunea curentă) ─────────
// Se păstrează instantanee ale controlului. Un pas = o atingere, sau un text tastat până la o pauză / până
// la următoarea atingere. Nu se salvează între sesiuni.
const LIMITA_PASI = 80;
const hist = new Map();   // idControl → { base, undo: [], redo: [] }
const histListeners = new Set();
let histTimer = null;
const snap = (c) => JSON.stringify(c, (k, v) => (k === 'updatedAt' ? undefined : v));

export function onHistory(fn) { histListeners.add(fn); }
const emitHist = (c) => histListeners.forEach((fn) => fn(c));

// Punctul de plecare: controlul așa cum e la deschidere (înainte de prima modificare)
export function historyStart(c) {
  if (!hist.has(c.id)) hist.set(c.id, { base: snap(c), undo: [], redo: [] });
}

// Închide pasul curent: dacă s-a schimbat ceva de la ultimul pas, starea anterioară intră în „Anulează”.
export function checkpoint(c) {
  clearTimeout(histTimer);
  const h = hist.get(c.id);
  if (!h) return;
  const cur = snap(c);
  if (cur === h.base) return;
  h.undo.push(h.base);
  if (h.undo.length > LIMITA_PASI) h.undo.shift();
  h.redo = [];
  h.base = cur;
  emitHist(c);
}
function scheduleCheckpoint(c) {
  clearTimeout(histTimer);
  histTimer = setTimeout(() => checkpoint(c), 1000);
}

export function historyState(id) {
  const h = hist.get(id);
  return { undo: h ? h.undo.length : 0, redo: h ? h.redo.length : 0 };
}

function restore(c, json) {
  const data = JSON.parse(json);
  for (const k of Object.keys(c)) if (!(k in data)) delete c[k];
  Object.assign(c, data);
}

// Revine un pas înapoi (undo) sau înainte (redo). Returnează true dacă s-a schimbat ceva.
export function historyMove(c, dir) {
  checkpoint(c);   // textul tastat până acum devine un pas separat
  const h = hist.get(c.id);
  if (!h) return false;
  const from = dir === 'undo' ? h.undo : h.redo;
  const to = dir === 'undo' ? h.redo : h.undo;
  if (!from.length) return false;
  to.push(h.base);
  h.base = from.pop();
  restore(c, h.base);
  c.updatedAt = new Date().toISOString();
  pending.set(c.id, c);
  flush();
  emitHist(c);
  return true;
}

export async function flush() {
  clearTimeout(timer);
  if (!pending.size) return;
  const list = [...pending.values()];
  pending.clear();
  try {
    for (const c of list) await store.saveControl(c);
    emit('saved');
  } catch (e) {
    console.error(e);
    for (const c of list) pending.set(c.id, c);
    emit('error');
  }
}

export async function addControl(c) {
  state.controls.push(c);
  await store.saveControl(c);
}

export async function removeControl(id) {
  state.controls = state.controls.filter((c) => c.id !== id);
  pending.delete(id);
  await store.deleteControl(id);
}
