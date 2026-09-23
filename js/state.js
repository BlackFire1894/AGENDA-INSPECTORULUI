// Starea aplicației în memorie + salvare automată.
import * as store from './store.js';
import { todayISO } from './dates.js';

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
    showAllNer: false,        // arată și neregulile de instalații nebifate DA la dotări
    obsHidden: pref('agenda-obs-hidden', false),                 // setarea generală: observațiile ascunse
    // Excepții individuale față de setarea generală: „<idControl>|<cale>” → true (ascuns) / false (afișat)
    obsOverride: new Map(pref('agenda-obs-override', [])),
    todoOpen: false,          // lista completă „Ce mai ai de făcut” deschisă
    catCollapsed: new Set(pref('agenda-cats-collapsed', [])),    // categorii de nereguli restrânse
  },
  meta: { lastBackup: null },
};

export const today = () => todayISO(state.now);

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
  pending.set(c.id, c);
  emit('saving');
  clearTimeout(timer);
  if (now) flush();
  else timer = setTimeout(flush, 350);
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
