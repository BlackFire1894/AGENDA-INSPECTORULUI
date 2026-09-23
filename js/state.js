// Starea aplicației în memorie + salvare automată.
import * as store from './store.js';
import { todayISO } from './dates.js';

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
export function touch(c) {
  c.updatedAt = new Date().toISOString();
  pending.set(c.id, c);
  emit('saving');
  clearTimeout(timer);
  timer = setTimeout(flush, 350);
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
