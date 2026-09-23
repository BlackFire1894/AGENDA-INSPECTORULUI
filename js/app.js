// Punctul de intrare: rutare, evenimente, fluxuri (control nou, backup, date demo).
import * as store from './store.js';
import { state, today, getControl, touch, flush, addControl, removeControl, onSaveState, savePref } from './state.js';
import { fmtDate, fmtDateLong, toISO, parseDateQuery, isISO } from './dates.js';
import {
  newControl, controlFromPrevious, normalizeControl, emptyConstructie, emptyNeregula, objectives,
  fold, uid, SCHEMA_VERSION, TIP_OBIECTIV, allFines, isIncheiat, neregulaCat, pvText, sectiuniActive, secOf,
  todoList, isApplicable, ACTE, LIPSA_DOTARI, DOTARI, sablon, fmtCoord, gpsQuality, constructiiOf, grfVPesteParter, neregulaLetter, neregulaLabel,
} from './model.js';
import {
  viewDashboard, viewObjectives, objListHTML, viewObjective, viewHistory, histListHTML,
  viewCalendar, viewSettings, hintText, backupAgeText, backupIsStale, guideSteps,
} from './views.js';
import { viewControl, edHeadHTML, edTabsHTML, tabHTML, TABS, tabsFor, obsKey, todoHTML, nerResultsHTML, grfBlock } from './editor.js';
import { AJUTOR } from './help.js';
import { icon, esc, toast, openModal, closeModal, confirmDialog } from './ui.js';
import { buildDemo } from './demo.js';
import { APP_VERSION } from './version.js';
import { fisaMarkup, fisaDocument, fisaFileName, FISA_CSS } from './fisa.js';

const main = () => document.getElementById('main');
let persisted = false;
let lastDay = today();   // ultima zi văzută de aplicație (pentru detectarea zilei noi)
let route = { name: 'panou' };

// ───────── rutare ─────────

function parseRoute() {
  const parts = (location.hash || '#/panou').replace(/^#\/?/, '').split('/').map(decodeURIComponent);
  const [name, a, b, c] = parts;
  switch (name) {
    case 'obiective': return { name };
    case 'obiectiv': return { name, id: a };
    case 'calendar': return { name };
    case 'istoric': return { name };
    case 'setari': return { name };
    case 'fisa': return { name, id: a };
    case 'control': return { name, id: a, tab: TABS.some((t) => t.key === b) ? b : 'obiectiv', focus: c };
    default: return { name: 'panou' };
  }
}

async function render({ keepScroll = false } = {}) {
  dayChanged();
  const prev = route;
  route = parseRoute();
  if (route.name !== 'control' && route.name !== 'fisa') state.ui.backTo = location.hash || '#/panou';
  if (route.name === 'setari') persisted = await store.isPersisted();
  const y = window.scrollY;
  let html;
  switch (route.name) {
    case 'obiective': html = viewObjectives(); break;
    case 'obiectiv': html = viewObjective(route.id); break;
    case 'calendar': html = viewCalendar(); break;
    case 'istoric': html = viewHistory(); break;
    case 'setari': html = viewSettings(persisted); break;
    case 'fisa': {
      const c = getControl(route.id);
      if (!c) { location.hash = '#/panou'; return; }
      html = `<div class="fisa-page">
        <header class="page-head fisa-actions">
          <div class="head-with-back">
            <a class="icon-btn big" href="#/control/${c.id}/obiectiv" aria-label="Înapoi la control">${icon('back')}</a>
            <div><div class="eyebrow">${icon('doc')} Rezumatul complet al controlului</div><h1>Fișa controlului</h1></div>
          </div>
          <div class="row-gap">
            <button class="btn btn-primary btn-lg" data-act="fisa-print">${icon('download')} Tipărește / PDF</button>
            <button class="btn btn-ghost btn-lg" data-act="fisa-share" data-id="${c.id}">${icon('upload')} Partajează fișierul</button>
          </div>
        </header>
        <p class="muted fisa-hint">Pentru PDF: <b>Tipărește / PDF</b> → în fereastra de tipărire, butonul Partajare → <b>Salvează în Fișiere</b>. Dacă tipărirea nu pornește, folosiți <b>Partajează fișierul</b>.</p>
        <style>${FISA_CSS}</style>
        <article class="fisa-doc card">${fisaMarkup(c, state.controls)}</article>
      </div>`;
      break;
    }
    case 'control': {
      const c = getControl(route.id);
      if (!c) { location.hash = '#/panou'; return; }
      if (!tabsFor(c).some((t) => t.key === route.tab)) { location.replace(`#/control/${c.id}/obiectiv`); return; }
      if (route.focus) {
        state.ui.nerFilter = 'ALL';
        state.ui.nerQuery = '';
        const fn = c.nereguli.find((x) => x.key === route.focus);
        if (fn && state.ui.catCollapsed.delete(neregulaCat(fn))) savePref('agenda-cats-collapsed', [...state.ui.catCollapsed]);
      }
      if (prev.name !== 'control' || prev.id !== route.id) state.ui.showAllNer = false;
      if (prev.name !== 'control' || prev.id !== route.id || prev.tab !== route.tab) {
        state.ui.nerFilter = 'ALL'; state.ui.nerQuery = ''; state.ui.constrPick = '';
      }
      html = viewControl(c, route.tab);
      break;
    }
    default: html = viewDashboard();
  }
  main().innerHTML = html;
  main().dataset.view = route.name;
  autosizeAll();
  updateNav();
  const sameView = prev.name === route.name && prev.id === route.id && prev.tab === route.tab;
  if (keepScroll || sameView) window.scrollTo(0, y);
  else window.scrollTo(0, 0);
  if (route.name === 'control' && route.focus) focusNeregula(route.focus);
}

function focusNeregula(key) {
  let el = document.getElementById(`ner-${key}`) || document.getElementById(key);
  // Coordonatele unei construcții restrânse: întâi o deschidem.
  if (!el && key.startsWith('gps-')) {
    const id = key.slice(4);
    state.ui.collapsed.delete(id); state.ui.expanded.add(id);
    rerenderEditor();
    el = document.getElementById(key);
  }
  if (!el) return;
  requestAnimationFrame(() => {
    el.scrollIntoView({ block: 'center', behavior: 'smooth' });
    el.classList.add('flash');
    setTimeout(() => el.classList.remove('flash'), 1800);
  });
}

function updateNav() {
  const active = route.name === 'control' || route.name === 'fisa' ? (state.ui.backTo.match(/^#\/(\w+)/)?.[1] || 'panou') : route.name === 'obiectiv' ? 'obiective' : route.name;
  document.querySelectorAll('[data-nav]').forEach((a) => a.classList.toggle('on', a.dataset.nav === active));
  const t = today();
  const fines = allFines(state.controls, t).filter((f) => f.st.level === 'red' || f.st.level === 'yellow').length;
  const open = state.controls.filter((c) => !isIncheiat(c)).length;
  document.querySelectorAll('[data-badge="panou"]').forEach((b) => { b.textContent = fines || ''; b.hidden = !fines; });
  document.querySelectorAll('[data-badge="istoric"]').forEach((b) => { b.textContent = open || ''; b.hidden = !open; });
  document.querySelectorAll('[data-backup-age]').forEach((el) => { el.textContent = backupAgeText(); });
  document.querySelectorAll('[data-backup-btn]').forEach((el) => el.classList.toggle('stale', backupIsStale()));
}

// Re-randare parțială a editorului (păstrează poziția de scroll)
function rerenderEditor() {
  const c = getControl(route.id);
  if (!c) return;
  const y = window.scrollY;
  document.getElementById('ed-head').innerHTML = edHeadHTML(c);
  document.getElementById('ed-todo').innerHTML = todoHTML(c);
  document.getElementById('ed-tabs').innerHTML = edTabsHTML(c, route.tab);
  document.getElementById('ed-body').innerHTML = tabHTML(c, route.tab);
  autosizeAll();
  window.scrollTo(0, y);
  updateNav();
}

// Bara „Ce mai ai de făcut” se actualizează și în timpul tastării (fără a atinge câmpul în care se scrie)
let todoTimer;
function refreshTodoSoon(c) {
  clearTimeout(todoTimer);
  todoTimer = setTimeout(() => {
    const el = document.getElementById('ed-todo');
    if (el && route.name === 'control' && route.id === c.id) el.innerHTML = todoHTML(c);
  }, 250);
}

// Observațiile cresc în jos pe măsură ce se scrie (lățimea rămâne fixă)
function autosize(el) {
  el.style.height = 'auto';
  el.style.height = `${el.scrollHeight + 2}px`;
}
function autosizeAll() {
  document.querySelectorAll('textarea.obs').forEach(autosize);
}
let resizeTimer;
window.addEventListener('resize', () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(autosizeAll, 150); });

// ───────── acces la date prin „căi” ─────────
// ex: "constructii.#<id>.dotari.asi.v", "nereguli.@a.amenda.suma"

function step(cur, s) {
  if (cur == null) return undefined;
  if (s[0] === '#') return cur.find((x) => x.id === s.slice(1));
  if (s[0] === '@') return cur.find((x) => x.key === s.slice(1));
  return cur[s];
}
function resolvePath(obj, path) {
  const segs = path.split('.');
  let cur = obj;
  for (let i = 0; i < segs.length - 1; i++) cur = step(cur, segs[i]);
  return [cur, segs[segs.length - 1]];
}
const getPath = (obj, path) => { const [p, k] = resolvePath(obj, path); return p?.[k]; };
function setPath(obj, path, v) { const [p, k] = resolvePath(obj, path); if (p) p[k] = v; }

// ───────── evenimente ─────────

document.addEventListener('input', (e) => {
  const el = e.target;
  if (el.id === 'ner-search' && route.name === 'control') {
    const c = getControl(route.id);
    if (!c) return;
    state.ui.nerQuery = el.value;
    refreshNerResults(c, el.dataset.sec);
    return;
  }
  if (el.dataset.bind && route.name === 'control') {
    const c = getControl(route.id);
    if (!c) return;
    setPath(c, el.dataset.bind, el.value);
    touch(c);
    if (el.tagName === 'TEXTAREA') autosize(el);
    refreshTodoSoon(c);
    if (el.dataset.liveSrc === 'denumire') {
      const h = document.querySelector('[data-live="denumire"]');
      if (h) h.textContent = el.value || 'Obiectiv fără denumire';
    }
    return;
  }
  if (el.dataset.search) {
    const key = el.dataset.search;
    if (key === 'obj') state.ui.objSearch = el.value;
    else state.ui.histSearch = el.value;
    refreshSearch(key);
  }
});

// Doar lista se redesenează: bara de căutare rămâne activă, cu tastatura deschisă.
function refreshNerResults(c, sec) {
  const box = document.getElementById('ner-results');
  if (!box) return;
  box.innerHTML = nerResultsHTML(c, sec);
  autosizeAll();
  const tb = document.querySelector('.toolbar [data-act="cats-all"]');
  if (tb) tb.hidden = !!state.ui.nerQuery.trim();
}

function refreshSearch(key) {
  const v = key === 'obj' ? state.ui.objSearch : state.ui.histSearch;
  const list = document.getElementById(key === 'obj' ? 'obj-list' : 'hist-list');
  if (list) list.innerHTML = key === 'obj' ? objListHTML() : histListHTML();
  const hint = document.querySelector(`[data-hint="${key}"]`);
  if (hint) hint.innerHTML = hintText(v);
  const bar = document.querySelector(`[data-search="${key}"]`)?.closest('.searchbar');
  if (bar) {
    let clr = bar.querySelector('[data-act="search-clear"]');
    if (v && !clr) {
      bar.querySelector('input[type=search]').insertAdjacentHTML('afterend', `<button class="icon-btn" data-act="search-clear" data-key="${key}" aria-label="Șterge căutarea">${icon('x')}</button>`);
    } else if (!v && clr) clr.remove();
    const dq = parseDateQuery(v);
    const lbl = bar.querySelector('.date-pick span');
    if (lbl) lbl.textContent = dq?.kind === 'day' ? fmtDate(dq.iso) : 'Dată';
    const di = bar.querySelector('[data-search-date]');
    if (di && document.activeElement !== di) di.value = dq?.kind === 'day' ? dq.iso : '';
  }
}

document.addEventListener('change', async (e) => {
  const el = e.target;
  // regimul de înălțime schimbă starea „GRF/NSI V peste parter” → redesenăm doar atunci (nu la fiecare ieșire din câmp)
  if (el.dataset.grav !== undefined && route.name === 'control') {
    const c = getControl(route.id);
    const [k] = c ? resolvePath(c, el.dataset.bind) : [];   // părintele lui „regimInaltime”
    const now = grfVPesteParter(k);
    if (k && now !== (el.dataset.grav === '1')) {
      // actualizare parțială: câmpul atins după acesta își păstrează focusul (și tastatura)
      touch(c, true);
      el.dataset.grav = now ? '1' : '0';
      document.getElementById(`grf-${k.id}`)?.replaceWith(Object.assign(document.createElement('div'), { innerHTML: grfBlock(c, k) }).firstElementChild);
      const pillEl = document.getElementById(`grf-pill-${k.id}`);
      if (pillEl) pillEl.hidden = !now;
      document.getElementById('ed-todo').innerHTML = todoHTML(c);
      document.getElementById('ed-tabs').innerHTML = edTabsHTML(c, route.tab);
      if (now) gravGrfToast(c, k);
    }
    return;
  }
  if (el.dataset.bind && el.dataset.rerender && route.name === 'control') {
    const c = getControl(route.id);
    if (!c) return;
    setPath(c, el.dataset.bind, el.value);
    if (el.dataset.bind === 'dataInceput' && !isISO(el.value)) { c.dataInceput = today(); }
    touch(c, true);
    rerenderEditor();
    return;
  }
  if (el.dataset.searchDate) {
    const key = el.dataset.searchDate;
    const v = el.value ? fmtDate(el.value) : '';
    if (key === 'obj') state.ui.objSearch = v; else state.ui.histSearch = v;
    const input = document.querySelector(`[data-search="${key}"]`);
    if (input) input.value = v;
    refreshSearch(key);
    return;
  }
  if (el.matches('[data-import]')) {
    const file = el.files?.[0];
    el.value = '';
    if (file) importBackup(file);
  }
});

document.addEventListener('click', async (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act;
  const c = route.name === 'control' ? getControl(route.id) : null;

  switch (act) {
    case 'modal-close': closeModal(); return;
    case 'new-control': openNewControl({ date: el.dataset.date, oid: el.dataset.oid }); return;
    case 'scroll': document.getElementById(el.dataset.target)?.scrollIntoView({ behavior: 'smooth', block: 'start' }); return;
    case 'search-clear': {
      const key = el.dataset.key;
      if (key === 'obj') state.ui.objSearch = ''; else state.ui.histSearch = '';
      const input = document.querySelector(`[data-search="${key}"]`);
      if (input) { input.value = ''; input.focus(); }
      refreshSearch(key);
      return;
    }
    case 'obj-tip': state.ui.objTip = el.dataset.val; render({ keepScroll: true }); return;
    case 'hist-filter': state.ui.histFilter = el.dataset.val; render({ keepScroll: true }); return;
    case 'cal-prev': case 'cal-next': {
      const d = new Date(state.ui.calYear, state.ui.calMonth + (act === 'cal-next' ? 1 : -1), 1);
      state.ui.calYear = d.getFullYear(); state.ui.calMonth = d.getMonth();
      render({ keepScroll: true }); return;
    }
    case 'cal-year-prev': case 'cal-year-next': {
      state.ui.calYear += act === 'cal-year-next' ? 1 : -1;
      render({ keepScroll: true }); return;
    }
    case 'cal-today': {
      { const d = new Date(); state.ui.calYear = d.getFullYear(); state.ui.calMonth = d.getMonth(); state.ui.calSelected = today(); }
      render({ keepScroll: true }); return;
    }
    case 'cal-day': {
      const d = el.dataset.date;
      state.ui.calSelected = d;
      const [y, m] = d.split('-').map(Number);
      if (y !== state.ui.calYear || m - 1 !== state.ui.calMonth) { state.ui.calYear = y; state.ui.calMonth = m - 1; }
      render({ keepScroll: true });
      if (window.innerWidth < 1000) document.querySelector('.day-panel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    case 'backup-export': exportBackup(); return;
    case 'help': showHelp(el.dataset.key === 'ctrl' ? `ctrl-${route.tab}` : el.dataset.key); return;
    case 'guide': showGuide(); return;
    case 'fisa-print': window.print(); return;
    case 'fisa-share': shareFisa(getControl(el.dataset.id)); return;
    case 'demo-load': await loadDemo(); return;
    case 'demo-remove': await removeDemo(); return;
    case 'wipe': await wipeAll(); return;
    case 'apply-update': applyUpdate(); return;
    case 'font-size': setFontSize(el.dataset.val); return;
    case 'theme': setTheme(el.dataset.val); return;
    case 'check-update': {
      const found = await checkForUpdate();
      if (!found) toast(`Ai cea mai nouă versiune (${APP_VERSION})`);
      return;
    }
  }

  if (!c) return;
  // ─── acțiuni în editor ───
  switch (act) {
    case 'set': {
      const cur = getPath(c, el.dataset.path);
      const noClear = el.closest('.no-clear');
      const v = el.dataset.toggle && cur === el.dataset.val && !noClear ? '' : el.dataset.val;
      setPath(c, el.dataset.path, v);
      // GRF/NSI V la o construcție cu regim peste parter → avertizare: neregulă gravă
      if (el.dataset.path.endsWith('.grf') && v === 'V') {
        const [k] = resolvePath(c, el.dataset.path);   // părintele lui „grf” = construcția
        if (grfVPesteParter(k)) { touch(c, true); rerenderEditor(); gravGrfToast(c, k); return; }
      }
      // NU la o instalație necesară → avertizare: neregulă gravă, adăugată în tabul Nereguli
      const mDot = el.dataset.path.match(/\.dotari\.(\w+)\.v$/);
      if (mDot && v === 'NU' && LIPSA_DOTARI.includes(mDot[1])) {
        const d = DOTARI.find((x) => x.key === mDot[1]);
        touch(c, true); rerenderEditor();
        toast(`Neregulă gravă: lipsă ${d.label.toLowerCase()} — apare primul în tabul Nereguli`, 'warn', {
          label: 'Vezi', fn: () => { location.hash = `#/control/${c.id}/nereguli/lipsa-${mDot[1]}`; },
        });
        return;
      }
      break;
    }
    case 'flag': {
      const v = !getPath(c, el.dataset.path);
      setPath(c, el.dataset.path, v);
      // rând adăugat care nu mai e grav → nici sigiliul nu mai are temei
      if (el.dataset.path.endsWith('.grav') && !v) setPath(c, el.dataset.path.replace(/\.grav$/, '.sigiliu'), false);
      if (el.dataset.path.endsWith('.amenda.achitata') && v) {
        const [amenda] = resolvePath(c, el.dataset.path);
        if (!amenda.dataAchitare) amenda.dataAchitare = today();
      }
      if (el.dataset.path.endsWith('.asiPrezentat') && v) {
        const [n] = resolvePath(c, el.dataset.path);
        if (!n.asiDataPrezentare) n.asiDataPrezentare = today();
      }
      break;
    }
    case 'centrala': {
      const obj = getPath(c, el.dataset.path);
      if (el.dataset.val === 'NU_ARE') { obj.nuAre = !obj.nuAre; if (obj.nuAre) obj.tipuri = []; } else {
        obj.nuAre = false;
        obj.tipuri = obj.tipuri.includes(el.dataset.val) ? obj.tipuri.filter((t) => t !== el.dataset.val) : [...obj.tipuri, el.dataset.val];
      }
      break;
    }
    case 'start-today': c.dataInceput = today(); break;
    case 'end-today': c.dataIncheiere = today(); break;
    case 'reopen': c.dataIncheiere = ''; break;
    case 'constr-inc': {
      const k = emptyConstructie(c.constructii.length + 1);
      c.constructii.push(k);
      state.ui.expanded.add(k.id);
      break;
    }
    case 'constr-dec': case 'constr-del': {
      if (c.constructii.length <= 1) { toast('Obiectivul trebuie să aibă cel puțin o construcție', 'warn'); return; }
      const k = act === 'constr-del' ? c.constructii.find((x) => x.id === el.dataset.id) : c.constructii[c.constructii.length - 1];
      const ok = await confirmDialog({ title: 'Ștergi construcția?', text: `„${k.denumire || 'Construcție'}” și toate datele ei vor fi șterse din acest control.`, ok: 'Șterge', danger: true });
      if (!ok) return;
      c.constructii = c.constructii.filter((x) => x !== k);
      break;
    }
    case 'constr-toggle': {
      const id = el.dataset.id;
      const openNow = !!el.closest('.constr.open');
      if (openNow) { state.ui.collapsed.add(id); state.ui.expanded.delete(id); } else { state.ui.expanded.add(id); state.ui.collapsed.delete(id); }
      rerenderEditor();
      return;
    }
    case 'ner-filter': state.ui.nerFilter = el.dataset.val; rerenderEditor(); return;
    case 'ner-q-clear': {
      state.ui.nerQuery = '';
      rerenderEditor();
      document.getElementById('ner-search')?.focus();
      return;
    }
    case 'constr-pick': state.ui.constrPick = state.ui.constrPick === el.dataset.key ? '' : el.dataset.key; rerenderEditor(); return;
    case 'constr-opt': case 'constr-opt-all': {
      const n = c.nereguli.find((x) => x.key === el.dataset.key);
      if (!n) return;
      if (act === 'constr-opt-all') n.constructieIds = c.constructii.map((k) => k.id);
      else {
        const ids = new Set(constructiiOf(c, n).map((k) => k.id));
        if (ids.has(el.dataset.id)) {
          if (ids.size === 1) { toast('Rămâne cel puțin o construcție', 'warn'); return; }
          ids.delete(el.dataset.id);
        } else ids.add(el.dataset.id);
        n.constructieIds = c.constructii.filter((k) => ids.has(k.id)).map((k) => k.id);
      }
      touch(c, true);
      rerenderEditor();
      return;
    }
    case 'pv-text': openPvText(c); return;
    case 'todo-toggle': state.ui.todoOpen = !state.ui.todoOpen; rerenderEditor(); return;
    case 'todo-go': {
      closeModal();
      const target = `#/control/${c.id}/${el.dataset.tab}${el.dataset.focus ? `/${encodeURIComponent(el.dataset.focus)}` : ''}`;
      if (location.hash === target) { if (el.dataset.focus) focusNeregula(el.dataset.focus); } else location.hash = target;
      return;
    }
    case 'rest-ok': restConform(c, el.dataset.sec); return;
    case 'gps-get': { const k = c.constructii.find((x) => x.id === el.dataset.id); if (k) getGps(c, k); return; }
    case 'gps-copy': {
      const k = c.constructii.find((x) => x.id === el.dataset.id);
      if (!k?.gps) return;
      try { await navigator.clipboard.writeText(fmtCoord(k.gps)); toast('Coordonate copiate'); } catch { toast(fmtCoord(k.gps), 'warn'); }
      return;
    }
    case 'gps-clear': {
      const ok = await confirmDialog({ title: 'Ștergi coordonatele?', text: 'Le puteți prelua din nou oricând, cu „Completează coordonatele”.', ok: 'Șterge', danger: true });
      const k = c.constructii.find((x) => x.id === el.dataset.id);
      if (ok && k) { k.gps = null; touch(c, true); rerenderEditor(); }
      return;
    }
    case 'close-control': closeControlFlow(c); return;
    case 'obs-toggle':
      // butonul general: setează toate câmpurile și anulează excepțiile individuale
      state.ui.obsHidden = !state.ui.obsHidden;
      state.ui.obsOverride.clear();
      savePref('agenda-obs-hidden', state.ui.obsHidden);
      savePref('agenda-obs-override', []);
      rerenderEditor(); return;
    case 'obs-show': case 'obs-hide': {
      const show = act === 'obs-show';
      const key = obsKey(el.dataset.path);
      if (show === !state.ui.obsHidden) state.ui.obsOverride.delete(key); else state.ui.obsOverride.set(key, !show);
      const entries = [...state.ui.obsOverride].slice(-1000);   // limită de siguranță pentru memoria locală
      savePref('agenda-obs-override', entries);
      rerenderEditor();
      if (show) document.querySelector(`textarea[data-bind="${CSS.escape(el.dataset.path)}"]`)?.focus();
      return;
    }
    case 'cat-toggle': {
      const cat = el.dataset.cat;
      if (!state.ui.catCollapsed.delete(cat)) state.ui.catCollapsed.add(cat);
      savePref('agenda-cats-collapsed', [...state.ui.catCollapsed]);
      rerenderEditor(); return;
    }
    case 'cats-all': {
      const cats = [...document.querySelectorAll('#ed-body [data-act="cat-toggle"]')].map((b) => b.dataset.cat);
      cats.forEach((k) => (el.dataset.val === 'close' ? state.ui.catCollapsed.add(k) : state.ui.catCollapsed.delete(k)));
      savePref('agenda-cats-collapsed', [...state.ui.catCollapsed]);
      rerenderEditor(); return;
    }
    case 'toggle-all-ner': state.ui.showAllNer = !state.ui.showAllNer; rerenderEditor(); return;
    case 'ner-add': {
      const n = emptyNeregula(`k${uid()}`, true, el.dataset.sec || 'ner');
      n.status = 'nok';
      c.nereguli.push(n);
      state.ui.nerFilter = 'ALL';
      touch(c);
      rerenderEditor();
      const input = document.querySelector(`#ner-${CSS.escape(n.key)} .row-label-input`);
      input?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      input?.focus();
      return;
    }
    case 'ner-del': {
      const n = c.nereguli.find((x) => x.key === el.dataset.key);
      const ok = await confirmDialog({ title: 'Ștergi rândul?', text: `„${n.label || 'Neregulă suplimentară'}” va fi eliminată din acest control.`, ok: 'Șterge', danger: true });
      if (!ok) return;
      c.nereguli = c.nereguli.filter((x) => x !== n);
      break;
    }
    case 'fine-date-default': {
      const n = c.nereguli.find((x) => x.key === el.dataset.key);
      n.amenda.data = '';
      break;
    }
    case 'control-delete': {
      const ok = await confirmDialog({ title: 'Ștergi controlul?', text: `Controlul de la „${c.denumire || 'obiectiv fără denumire'}” din ${fmtDate(c.dataInceput)} va fi șters definitiv.`, ok: 'Șterge definitiv', danger: true });
      if (!ok) return;
      await removeControl(c.id);
      toast('Control șters');
      location.hash = state.ui.backTo || '#/panou';
      return;
    }
    default: return;
  }
  touch(c, true);
  rerenderEditor();
});

// ───────── control nou ─────────

async function startControl(c) {
  await addControl(c);
  state.ui.backTo = location.hash.startsWith('#/control') ? '#/panou' : (location.hash || '#/panou');
  closeModal();
  location.hash = `#/control/${c.id}/obiectiv`;
}

function openNewControl({ date, oid } = {}) {
  const start = date || today();
  if (oid) {
    const o = objectives(state.controls).find((x) => x.id === oid);
    if (o) { startControl(controlFromPrevious(o.last, start)); return; }
  }
  let tip = 'OPEC';
  let startDate = start;
  const m = openModal(`
    <div class="modal-head">
      <h2>${icon('plus')} Control nou</h2>
      <button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button>
    </div>
    <div class="modal-body">
      <label class="field">
        <span class="lbl">Data începerii</span>
        <span class="inp-wrap"><input type="date" id="nc-date" value="${start}"></span>
      </label>
      <label class="field">
        <span class="lbl">Denumire obiectiv</span>
        <span class="inp-wrap big-inp">${icon('search')}<input id="nc-name" placeholder="Scrie denumirea — caut și în obiectivele existente" autocomplete="off" enterkeyhint="done"></span>
      </label>
      <div id="nc-existing"></div>
      <div class="nc-new">
        <span class="lbl">Tip obiectiv nou</span>
        <div class="segmented seg-lg" id="nc-tip">${TIP_OBIECTIV.map((t) => `<button type="button" data-tip="${t.key}" class="${t.key === tip ? 'on' : ''}">${t.label}</button>`).join('')}</div>
        <button class="btn btn-primary btn-xl btn-block" id="nc-create">${icon('plus')} <span>Creează obiectiv nou</span></button>
      </div>
    </div>`, { wide: true });

  const name = m.querySelector('#nc-name');
  const existing = m.querySelector('#nc-existing');
  const createBtn = m.querySelector('#nc-create span');
  const objs = objectives(state.controls);

  const refresh = () => {
    const q = fold(name.value.trim());
    const list = (q ? objs.filter((o) => fold(o.denumire).includes(q)) : objs).slice(0, 6);
    createBtn.textContent = name.value.trim() ? `Creează obiectiv nou „${name.value.trim()}”` : 'Creează obiectiv nou';
    const exact = objs.find((o) => fold(o.denumire) === q && q);
    existing.innerHTML = list.length ? `<span class="lbl">${q ? 'Obiective existente găsite' : 'Obiective recente'} — datele se preiau din ultimul control</span>
      <div class="nc-list">${list.map((o) => `<button type="button" class="nc-obj ${exact === o ? 'exact' : ''}" data-oid="${o.id}">
        <span class="avatar sm ${o.tip === 'LOCALITATE' ? 'av-loc' : 'av-opec'}">${esc((o.denumire || '?').trim()[0]?.toUpperCase() || '?')}</span>
        <span class="nc-main"><b>${esc(o.denumire || 'Fără denumire')}</b><small>${o.controls.length} ${o.controls.length === 1 ? 'control' : 'controale'} · ultimul ${fmtDate(o.last.dataInceput)}</small></span>
        <span class="nc-go">Control nou ${icon('chevR')}</span>
      </button>`).join('')}</div>` : (q ? '<p class="muted">Niciun obiectiv existent cu acest nume — va fi creat unul nou.</p>' : '');
  };
  refresh();
  name.addEventListener('input', refresh);
  m.querySelector('#nc-date').addEventListener('change', (e) => { startDate = isISO(e.target.value) ? e.target.value : today(); });
  m.querySelector('#nc-tip').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tip]');
    if (!b) return;
    tip = b.dataset.tip;
    m.querySelectorAll('#nc-tip button').forEach((x) => x.classList.toggle('on', x === b));
  });
  existing.addEventListener('click', (e) => {
    const b = e.target.closest('[data-oid]');
    if (!b) return;
    const o = objs.find((x) => x.id === b.dataset.oid);
    startControl(controlFromPrevious(o.last, startDate));
  });
  m.querySelector('#nc-create').addEventListener('click', () => {
    startControl(newControl({ tip, denumire: name.value.trim(), start: startDate }));
  });
  setTimeout(() => name.focus(), 250);
}

function gravGrfToast(c, k) {
  toast(`Neregulă gravă: ${k.denumire || 'construcția'} are GRF/NSI V și regim ${k.regimInaltime} (peste parter)`, 'warn', {
    label: 'Vezi', fn: () => { location.hash = `#/control/${c.id}/nereguli/grav-grfV`; },
  });
}

// ───────── Coordonate GPS ─────────
// O singură atingere; se caută poziția precisă (GPS), cu limită de timp ca aplicația să nu rămână blocată.
function getGps(c, k) {
  if (!('geolocation' in navigator)) { toast('Localizarea nu este disponibilă pe acest dispozitiv', 'warn'); return; }
  if (state.ui.gpsBusy) return;
  state.ui.gpsBusy = k.id; rerenderEditor();
  const done = () => { state.ui.gpsBusy = ''; if (route.name === 'control' && route.id === c.id) rerenderEditor(); };
  navigator.geolocation.getCurrentPosition((pos) => {
    const { latitude: lat, longitude: lon, accuracy: acc } = pos.coords;
    k.gps = { lat, lon, acc, la: new Date().toISOString() };
    touch(c, true);
    done();
    const q = gpsQuality(acc);
    toast(q === 'slaba' ? `Coordonate preluate, dar precizie slabă (± ${Math.round(acc)} m)` : `Coordonate preluate (± ${Math.round(acc)} m)`, q === 'slaba' ? 'warn' : 'ok');
  }, (err) => {
    done();
    // 1 = permisiune refuzată, 2 = Localizarea iPad-ului oprită / fără poziție: ambele se rezolvă din Setări.
    if (err.code === 3) {
      toast('Nu s-a găsit semnal la timp. Ieșiți în aer liber sau lângă o fereastră și încercați din nou.', 'warn');
      return;
    }
    gpsActivatePrompt(c, k);
  }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
}

// Localizarea e oprită sau refuzată. O aplicație web nu poate deschide Setările iPad-ului și nici nu poate porni
// Localizarea singură, deci arătăm pașii exacți și un buton „Încearcă din nou”.
function gpsActivatePrompt(c, k) {
  const m = openModal(`<div class="modal-head"><h2>${icon('locate')} Activați localizarea</h2></div>
    <div class="modal-body">
      <p class="lead">Coordonatele nu pot fi completate: localizarea e oprită sau aplicația nu are permisiune. Pe iPad:</p>
      <ol class="gps-steps">
        <li><b>Setări → Confidențialitate și securitate → Localizare</b>: porniți <b>Localizare</b>.</li>
        <li>În aceeași listă, <b>Site-uri Safari</b>: alegeți <b>Cât timp folosesc aplicația</b> și porniți <b>Localizare precisă</b>.</li>
        <li><b>Setări → Aplicații → Safari → Localizare</b>: alegeți <b>Întreabă</b> sau <b>Permite</b>.</li>
        <li>Reveniți aici și apăsați <b>Încearcă din nou</b>; la întrebarea iPad-ului, alegeți <b>Permite</b>.</li>
      </ol>
      <p class="hint">Aplicația citește poziția doar când apăsați butonul; nu urmărește locația.</p>
    </div>
    <div class="modal-foot">
      <button class="btn btn-ghost btn-lg" data-act="modal-close">Renunță</button>
      <button class="btn btn-primary btn-lg" id="gps-retry">${icon('locate')} Încearcă din nou</button>
    </div>`);
  m.querySelector('#gps-retry').addEventListener('click', () => { closeModal(); getGps(c, k); });
}

// ───────── Restul conform (în bloc, cu „Anulează”) ─────────

// Marcare în bloc, cu confirmare manuală: lista exactă a rândurilor + bifa „Am verificat…”, altfel butonul
// rămâne inactiv (fără bife accidentale). Neregulile grave nu intră niciodată în bloc: se decid individual.
async function restConform(c, sec) {
  let rows, items;
  if (sec === 'acte') {
    const acte = ACTE.filter((a) => !c.acte[a.key]?.status);
    rows = acte.map((a) => c.acte[a.key]);
    items = acte.map((a) => ['', a.label]);
  } else {
    rows = c.nereguli.filter((n) => secOf(n) === sec && !n.status && !sablon(n.key)?.grav
      && (isApplicable(c, n) || state.ui.showAllNer));
    items = rows.map((n) => [neregulaLetter(c, n), neregulaLabel(n)]);
  }
  const grave = sec === 'ner' ? c.nereguli.filter((n) => !n.status && sablon(n.key)?.grav && isApplicable(c, n)).length : 0;
  if (!rows.length) { if (grave) toast('Neregulile grave rămase se marchează individual', 'warn'); return; }
  const word = sec === 'acte' ? 'Prezentat' : 'Conform';
  const what = sec === 'acte' ? (rows.length === 1 ? 'act' : 'acte') : (rows.length === 1 ? 'rând' : 'rânduri');
  const ok = await new Promise((resolve) => {
    let done = false;
    const m = openModal(`<div class="modal-head"><h2>${icon('alert')} Marchez ${rows.length} ${what} ca „${word}”?</h2></div>
      <div class="modal-body">
        <p class="lead">Verificați lista. Se schimbă doar rândurile de mai jos, încă nemarcate.</p>
        <ul class="bulk-list">${items.map(([l, t]) => `<li>${l ? `<b class="bulk-letter">${esc(l)}</b>` : icon('check')}<span>${esc(t)}</span></li>`).join('')}</ul>
        ${grave ? `<p class="bulk-grav">${icon('alert')} ${grave === 1 ? 'Neregula gravă (G) nu e inclusă' : `Cele ${grave} nereguli grave (G) nu sunt incluse`}: se marchează individual.</p>` : ''}
        <label class="bulk-confirm"><input type="checkbox" id="bulk-ok"><span>Am verificat la fața locului ${rows.length === 1 ? 'acest rând' : `toate cele ${rows.length} ${what}`} și ${rows.length === 1 ? 'este' : 'sunt'} „${word.toLowerCase()}${rows.length === 1 || sec === 'acte' ? '' : 'e'}”.</span></label>
      </div>
      <div class="modal-foot">
        <button class="btn btn-ghost btn-lg" data-r="0">Renunță</button>
        <button class="btn btn-primary btn-lg" data-r="1" disabled>${icon('check')} Marchează ${rows.length} ${what}</button>
      </div>`, { wide: true, onClose: () => { if (!done) resolve(false); } });
    const go = m.querySelector('[data-r="1"]');
    m.querySelector('#bulk-ok').addEventListener('change', (e) => { go.disabled = !e.target.checked; });
    m.querySelectorAll('[data-r]').forEach((btn) => btn.addEventListener('click', () => {
      if (btn.disabled) return;
      done = true; resolve(btn.dataset.r === '1'); closeModal();
    }));
  });
  if (!ok) return;
  rows.forEach((r) => { r.status = 'ok'; });
  touch(c, true);
  rerenderEditor();
  toast(`${rows.length} ${what} marcate „${word}”`, 'ok', {
    label: 'Anulează',
    fn: () => { rows.forEach((r) => { r.status = ''; }); touch(c, true); if (route.name === 'control' && route.id === c.id) rerenderEditor(); toast('Anulat'); },
  });
}

// ───────── Încheierea controlului: verificare a omisiunilor ─────────

function closeControlFlow(c) {
  const doClose = () => {
    c.dataIncheiere = c.dataInceput;
    touch(c, true);
    closeModal();
    rerenderEditor();
    toast(`Control încheiat la ${fmtDate(c.dataIncheiere)} — poți modifica data`);
  };
  const items = todoList(c, { includeClose: false });
  if (!items.length) { doClose(); return; }
  const m = openModal(`
    <div class="modal-head"><h2>${icon('alert')} Înainte de încheiere</h2><button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button></div>
    <div class="modal-body">
      <p class="lead">Au rămas ${items.length === 1 ? 'un lucru necompletat' : `${items.length} lucruri necompletate`}. Atingeți unul ca să mergeți direct la el, sau încheiați oricum.</p>
      <div class="todo-list">${items.map((x) => `<button class="todo-item t-${x.level}" data-act="todo-go" data-tab="${x.tab}" data-focus="${esc(x.focus || '')}">${icon(x.level === 'warn' ? 'alert' : 'chevR')}<span>${esc(x.text)}</span></button>`).join('')}</div>
    </div>
    <div class="modal-foot">
      <button class="btn btn-ghost btn-lg" data-act="modal-close">Revin să completez</button>
      <button class="btn btn-success btn-lg" id="close-anyway">${icon('check')} Încheie oricum</button>
    </div>`, { wide: true });
  m.querySelector('#close-anyway').addEventListener('click', doClose);
}

// ───────── Ghid și ajutor contextual ─────────

function showGuide() {
  openModal(`
    <div class="modal-head"><h2>${icon('info')} Cum lucrați cu aplicația</h2><button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button></div>
    <div class="modal-body">${guideSteps()}</div>
    <div class="modal-foot"><button class="btn btn-primary btn-lg" data-act="modal-close">Am înțeles</button></div>`, { wide: true });
}

function showHelp(key) {
  const h = AJUTOR[key] || AJUTOR.panou;
  openModal(`
    <div class="modal-head"><h2><span class="help-q">?</span> ${esc(h.title)}</h2><button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button></div>
    <div class="modal-body"><ul class="help-list">${h.lines.map((l) => `<li>${l}</li>`).join('')}</ul></div>
    <div class="modal-foot">
      <button class="btn btn-ghost btn-lg" data-act="guide">${icon('info')} Ghidul complet</button>
      <button class="btn btn-primary btn-lg" data-act="modal-close">Am înțeles</button>
    </div>`);
}

// ───────── Text pentru procesul-verbal ─────────

function openPvText(c) {
  const opts = { doarNetrecute: false, cuActe: true };
  const m = openModal(`
    <div class="modal-head"><h2>${icon('pv')} Text pentru procesul-verbal</h2><button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button></div>
    <div class="modal-body">
      <div class="detail-toggles">
        <button type="button" class="toggle" data-opt="doarNetrecute"><span class="tg-box"></span><span>Doar cele netrecute în PV</span></button>
        <button type="button" class="toggle on t-accent" data-opt="cuActe"><span class="tg-box">${icon('check')}</span><span>Include actele lipsă</span></button>
      </div>
      <textarea class="pv-text" readonly></textarea>
      <div class="row-gap">
        <button class="btn btn-primary btn-lg" data-pv="copy">${icon('doc')} Copiază</button>
        ${navigator.share ? `<button class="btn btn-ghost btn-lg" data-pv="share">${icon('upload')} Partajează</button>` : ''}
        <button class="btn btn-ghost btn-lg" data-pv="mark">${icon('pv')} Marchează-le trecute în PV</button>
      </div>
    </div>`, { wide: true, onClose: () => { if (route.name === 'control') rerenderEditor(); } });
  const ta = m.querySelector('.pv-text');
  let current = { text: '', count: 0 };
  const refresh = () => {
    current = pvText(c, state.controls, opts);
    ta.value = current.text;
    m.querySelector('[data-pv="mark"]').disabled = !current.count;
  };
  refresh();
  m.querySelectorAll('[data-opt]').forEach((b) => b.addEventListener('click', () => {
    const k = b.dataset.opt;
    opts[k] = !opts[k];
    b.classList.toggle('on', opts[k]); b.classList.toggle('t-accent', opts[k]);
    b.querySelector('.tg-box').innerHTML = opts[k] ? icon('check') : '';
    refresh();
  }));
  m.querySelector('[data-pv="copy"]').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(current.text); toast('Text copiat — lipiți-l în procesul-verbal'); } catch {
      ta.focus(); ta.select(); toast('Selectați textul și copiați-l manual', 'warn');
    }
  });
  m.querySelector('[data-pv="share"]')?.addEventListener('click', async () => {
    try { await navigator.share({ title: `Nereguli – ${c.denumire}`, text: current.text }); } catch { /* anulat */ }
  });
  m.querySelector('[data-pv="mark"]').addEventListener('click', () => {
    let n = 0;
    for (const x of c.nereguli) {
      if (x.status === 'nok' && !x.inPV && sectiuniActive(c).includes(secOf(x))) { x.inPV = true; n++; }
    }
    if (n) { touch(c, true); toast(`${n} ${n === 1 ? 'neregulă marcată' : 'nereguli marcate'} ca trecute în PV`); }
    refresh();
  });
}

// ───────── Fișa controlului: partajare ca fișier ─────────

async function shareFisa(c) {
  if (!c) return;
  const file = new File([fisaDocument(c, state.controls)], fisaFileName(c), { type: 'text/html' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: file.name });
    } else {
      const url = URL.createObjectURL(file);
      const a = document.createElement('a');
      a.href = url; a.download = file.name;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 4000);
    }
  } catch (e) {
    if (e.name !== 'AbortError') toast('Partajarea a eșuat', 'warn');
  }
}

// ───────── backup ─────────

function nowStamp() {
  const d = new Date();
  return `${toISO(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

async function exportBackup() {
  await flush();
  const payload = { app: 'agenda-inspectorului', schema: SCHEMA_VERSION, exportedAt: new Date().toISOString(), controls: state.controls };
  const json = JSON.stringify(payload, null, 1);
  const d = new Date();
  const name = `agenda-inspectorului-backup-${today()}_${String(d.getHours()).padStart(2, '0')}-${String(d.getMinutes()).padStart(2, '0')}.json`;
  const file = new File([json], name, { type: 'application/json' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: name });
    } else {
      const url = URL.createObjectURL(file);
      const a = document.createElement('a');
      a.href = url; a.download = name;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 4000);
    }
  } catch (e) {
    if (e.name === 'AbortError') { toast('Export anulat', 'warn'); return; }
    console.error(e);
    toast('Exportul a eșuat', 'warn');
    return;
  }
  state.meta.lastBackup = nowStamp();
  await store.setMeta('lastBackup', state.meta.lastBackup);
  toast(`Backup exportat: ${state.controls.length} controale`);
  if (route.name === 'control') rerenderEditor(); else render({ keepScroll: true });
}

async function importBackup(file) {
  let data;
  try {
    data = JSON.parse(await file.text());
  } catch {
    toast('Fișierul nu este un backup valid', 'warn');
    return;
  }
  const list = Array.isArray(data) ? data : data?.controls;
  if (!Array.isArray(list) || list.some((c) => !c || typeof c !== 'object' || !c.id || !isISO(c.dataInceput))) {
    toast('Fișierul nu este un backup al acestei aplicații', 'warn');
    return;
  }
  const incoming = list.map(normalizeControl);
  const m = openModal(`
    <div class="modal-head"><h2>${icon('upload')} Importă backup</h2><button class="icon-btn big" data-act="modal-close" aria-label="Închide">${icon('x')}</button></div>
    <div class="modal-body">
      <p class="lead">Fișierul conține <b>${incoming.length}</b> controale${data.exportedAt ? `, exportate pe ${esc(fmtDateLong(toISO(new Date(data.exportedAt))))}` : ''}. Pe tabletă sunt acum <b>${state.controls.length}</b>.</p>
      <div class="choice-list">
        <button class="choice" data-mode="merge"><b>Combină</b><span>Adaugă controalele noi; la cele existente păstrează versiunea modificată cel mai recent.</span></button>
        <button class="choice danger" data-mode="replace"><b>Înlocuiește tot</b><span>Șterge datele de pe tabletă și le pune pe cele din fișier.</span></button>
      </div>
    </div>`);
  m.querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', async () => {
    let result;
    if (b.dataset.mode === 'replace') {
      result = incoming;
    } else {
      const map = new Map(state.controls.map((c) => [c.id, c]));
      for (const c of incoming) {
        const cur = map.get(c.id);
        if (!cur || (c.updatedAt || '') > (cur.updatedAt || '')) map.set(c.id, c);
      }
      result = [...map.values()];
    }
    await flush();
    await store.replaceAll(result);
    state.controls = result;
    closeModal();
    toast(`Import reușit: ${result.length} controale`);
    render();
  }));
}

// ───────── mărimea textului (preferință a acestei tablete) ─────────

function setFontSize(size) {
  const root = document.documentElement;
  if (size === 'mare') delete root.dataset.font; else root.dataset.font = size;
  try { localStorage.setItem('agenda-font', size); } catch { /* setarea rămâne doar pentru sesiunea curentă */ }
  render({ keepScroll: true });
}

// ───────── tema (preferință a acestei tablete) ─────────

function setTheme(t) {
  const root = document.documentElement;
  if (t === 'light' || t === 'dark') root.dataset.theme = t; else delete root.dataset.theme;
  try { localStorage.setItem('agenda-theme', t); } catch { /* setarea rămâne doar pentru sesiunea curentă */ }
  render({ keepScroll: true });
}

// ───────── date demonstrative / ștergere ─────────

async function loadDemo() {
  const demo = buildDemo(today());
  for (const c of demo) await addControl(c);
  toast(`Am încărcat ${demo.length} controale demonstrative`);
  render();
}

async function removeDemo() {
  const ok = await confirmDialog({ title: 'Ștergi datele demonstrative?', text: 'Doar controalele demonstrative vor fi șterse. Datele tale rămân.', ok: 'Șterge', danger: true });
  if (!ok) return;
  for (const c of state.controls.filter((x) => x.demo)) await removeControl(c.id);
  toast('Date demonstrative șterse');
  render();
}

async function wipeAll() {
  const ok = await confirmDialog({ title: 'Ștergi TOATE datele?', text: `${state.controls.length} controale vor fi șterse definitiv de pe această tabletă. Operația nu poate fi anulată.`, ok: 'Șterge tot', danger: true });
  if (!ok) return;
  await store.replaceAll([]);
  state.controls = [];
  toast('Toate datele au fost șterse');
  location.hash = '#/panou';
  render();
}

// ───────── ceas: aplicația urmează data și ora tabletei ─────────

function tick() {
  state.now = new Date();
  const hh = String(state.now.getHours()).padStart(2, '0');
  const mm = String(state.now.getMinutes()).padStart(2, '0');
  document.querySelectorAll('[data-clock]').forEach((el) => { el.textContent = `${hh}:${mm}`; });
  document.querySelectorAll('[data-clock-date]').forEach((el) => { el.textContent = fmtDateLong(today()); });
  if (dayChanged()) {
    const typing = document.activeElement && /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName);
    if (!typing) render({ keepScroll: true });
  }
}

// Zi nouă (aplicația poate sta deschisă zile întregi): calendarul trece pe azi; termenele se recalculează la randare.
function dayChanged() {
  if (today() === lastDay) return false;
  const d = new Date();
  if (state.ui.calSelected === lastDay) { state.ui.calYear = d.getFullYear(); state.ui.calMonth = d.getMonth(); state.ui.calSelected = today(); }
  lastDay = today();
  return true;
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') flush();
  else { tick(); checkForUpdate(); }
});
window.addEventListener('pagehide', () => flush());
window.addEventListener('hashchange', () => { closeModal(); render(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeModal(); });

onSaveState((s) => {
  const el = document.getElementById('save-ind');
  if (!el) return;
  el.className = `save-ind s-${s}`;
  el.innerHTML = s === 'saving' ? `${icon('clock')}<span>Se salvează…</span>`
    : s === 'error' ? `${icon('alert')}<span>Eroare la salvare</span>` : `${icon('check')}<span>Salvat</span>`;
});

// ───────── pornire ─────────

async function boot() {
  try {
    await store.init();
    const list = await store.loadAll();
    state.controls = (list || []).map(normalizeControl);
    state.meta.lastBackup = (await store.getMeta('lastBackup')) || null;
  } catch (e) {
    console.error(e);
    toast('Nu am putut încărca datele', 'warn');
  }
  tick();
  setInterval(tick, 15000);
  render();
  registerSW();
}

// ───────── actualizări: „Versiune nouă disponibilă — Actualizează” ─────────

let swReg = null;
let updateRequested = false;

function showUpdateBar() {
  document.getElementById('toast')?.classList.remove('show');
  document.getElementById('update-bar')?.removeAttribute('hidden');
}

function watchInstalling(sw) {
  sw?.addEventListener('statechange', () => {
    if (sw.state === 'installed' && navigator.serviceWorker.controller) showUpdateBar();
  });
}

async function registerSW() {
  if (!('serviceWorker' in navigator) || location.protocol === 'file:') return;
  try {
    swReg = await navigator.serviceWorker.register('./sw.js');
  } catch (e) {
    console.warn('SW:', e);
    return;
  }
  if (!swReg) return;
  if (swReg.waiting && navigator.serviceWorker.controller) showUpdateBar();
  swReg.addEventListener('updatefound', () => watchInstalling(swReg.installing));
  // La prima instalare, controllerchange apare și fără actualizare — reîncărcăm doar la cererea utilizatorului.
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!updateRequested) return;
    updateRequested = false;
    location.reload();
  });
}

// Returnează true dacă există (sau tocmai s-a găsit) o versiune nouă.
async function checkForUpdate() {
  if (!swReg) return false;
  try { await swReg.update(); } catch { return false; }
  if (swReg.installing) {
    await new Promise((res) => {
      const sw = swReg.installing;
      sw.addEventListener('statechange', () => { if (sw.state !== 'installing') res(); });
    });
  }
  const found = !!(swReg.waiting && navigator.serviceWorker.controller);
  if (found) showUpdateBar();
  return found;
}

async function applyUpdate() {
  await flush();
  const btn = document.querySelector('[data-act="apply-update"]');
  if (btn) btn.textContent = 'Se actualizează…';
  updateRequested = true;
  if (swReg?.waiting) swReg.waiting.postMessage({ type: 'SKIP_WAITING' });
  else location.reload();
}

boot();
