// Verificarea încrucișată a EDITORULUI: aplicația web originală (js/app.js, js/editor.js, js/state.js) rulează
// într-un DOM simulat; pe controale aleatoare se apasă butoanele editorului, se scrie în câmpuri, se caută, se schimbă
// taburile, se anulează / refac pași. După fiecare pas se înregistrează: controlul, ecranul (ca șir de „jetoane”),
// mesajele, confirmările, istoricul Anulează / Refă. Testul Swift EditorWebTests reia aceiași pași și cere același rezultat.
// Rulare: node ios/Diferential/editor.mjs [cazuri.json] [editor.json] [sămânță]
process.env.TZ = 'Europe/Bucharest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ACUM = new Date('2026-10-15T09:00:00+03:00').getTime();
const DateReal = Date;
globalThis.Date = class extends DateReal {
  constructor(...a) { super(...(a.length ? a : [ACUM])); }
  static now() { return ACUM; }
};
// alt punct de plecare decât genereaza.mjs (7): identificatorii noi nu repetă pe cei din date
let samantaUid = 1000003 + (Number(process.argv[4] || 20260927) % 1000000);
Math.random = () => { samantaUid = (samantaUid * 1103515245 + 12345) % 2147483648; return samantaUid / 2147483648; };

// ───────── DOM simulat ─────────
// Cronometrele nu pornesc niciodată: pașii „pauză” (checkpoint) sunt expliciți, ca în testul Swift.
globalThis.setTimeout = () => 0;
globalThis.clearTimeout = () => {};
globalThis.setInterval = () => 0;
globalThis.clearInterval = () => {};
globalThis.requestAnimationFrame = () => 0;
globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };
globalThis.CSS = { escape: (s) => s };
console.warn = () => {};
console.error = () => {};

function element(id = '') {
  const clase = new Set();
  return {
    id, dataset: {}, style: { setProperty() {} }, hidden: false, value: '',
    className: '', _html: '',
    get innerHTML() { return this._html; },
    set innerHTML(v) { this._html = v; },
    classList: {
      add: (...c) => c.forEach((x) => clase.add(x)),
      remove: (...c) => c.forEach((x) => clase.delete(x)),
      toggle: (c, f) => { if (f ?? !clase.has(c)) clase.add(c); else clase.delete(c); },
      contains: (c) => clase.has(c),
    },
    querySelector: () => null, querySelectorAll: () => [], addEventListener() {}, removeEventListener() {},
    insertAdjacentHTML() {}, replaceWith() {}, remove() {}, focus() {}, select() {}, scrollIntoView() {}, closest: () => null,
    setAttribute() {}, removeAttribute() {}, getAttribute: () => null, matches: () => false,
    offsetHeight: 0, offsetWidth: 0, offsetLeft: 0, scrollWidth: 0, clientWidth: 0, parentElement: null,
  };
}

// mesajele (toast): textul, nivelul, eticheta acțiunii; acțiunea se poate apăsa ca pas separat
let mesaje = [];
let actiuneMesaj = null;
const toastEl = element('toast');
Object.defineProperty(toastEl, 'innerHTML', {
  get() { return this._html; },
  set(v) {
    this._html = v;
    const text = dec((v.match(/<span>([\s\S]*?)<\/span>/) || [])[1] || '');
    const nivel = (this.className.match(/toast-(\w+)/) || [])[1] || '';
    const eticheta = (v.match(/<button class="toast-btn">([\s\S]*?)<\/button>/) || [])[1];
    mesaje.push(eticheta ? { text, nivel, actiune: dec(eticheta) } : { text, nivel });
    actiuneMesaj = null;
  },
});
toastEl.querySelector = (sel) => (sel === '.toast-btn' ? Object.assign(element(), { addEventListener: (t, fn) => { actiuneMesaj = fn; } }) : null);

// ferestrele modale: se înregistrează conținutul; răspunsul (confirmă / renunță) îl alege pasul
let raspuns = true;
let clicuriModal = [];
let modale = [];
const modalRoot = element('modal-root');
Object.defineProperty(modalRoot, 'innerHTML', {
  get() { return this._html; },
  set(v) { this._html = v; if (v) modale.push(v); },
});
let modalCurent = null;
modalRoot.querySelector = (sel) => {
  if (sel !== '.modal') return null;
  const m = element();
  const el = new Map();
  m.el = (s) => {
    if (!el.has(s)) {
      const b = element();
      b.l = {};
      b.addEventListener = (t, fn) => { b.l[t] = fn; if (t === 'click' && s === '#close-anyway' && raspuns) clicuriModal.push(fn); };
      el.set(s, b);
    }
    return el.get(s);
  };
  m.querySelector = m.el;
  modalCurent = m;
  m.querySelectorAll = (s) => (s === '[data-r]' ? ['0', '1'].map((r) => {
    const b = element();
    b.dataset = { r };
    b.addEventListener = (t, fn) => { if (t === 'click' && (r === '1') === raspuns) clicuriModal.push(fn); };
    return b;
  }) : []);
  return m;
};

const elemente = new Map([['toast', toastEl], ['modal-root', modalRoot]]);
const ascultatori = {};
let E; let S; let c = null; let tab = 'obiectiv';
globalThis.document = {
  getElementById: (id) => { if (!elemente.has(id)) elemente.set(id, element(id)); return elemente.get(id); },
  // „Restrânge categoriile”: butoanele de categorie din corpul tabului curent
  querySelectorAll: (sel) => {
    if (sel === '#ed-body [data-act="cat-toggle"]' && c) {
      return [...E.tabHTML(c, tab).matchAll(/data-act="cat-toggle" data-cat="([^"]+)"/g)].map((m) => ({ dataset: { cat: m[1] } }));
    }
    return [];
  },
  querySelector: () => null,
  createElement: () => element(),
  addEventListener: (t, f) => { (ascultatori[t] ||= []).push(f); },
  documentElement: element('html'),
  body: element('body'),
  activeElement: null,
  visibilityState: 'visible',
};
const ascultatoriFereastra = {};
globalThis.window = {
  addEventListener: (t, f) => { ascultatoriFereastra[t] = f; },
  scrollY: 0, scrollTo() {}, print() {},
  matchMedia: () => ({ matches: false }),
  getComputedStyle: () => ({ display: 'block' }),
};
let gpsUrmator = null;
Object.defineProperty(globalThis, 'navigator', {
  configurable: true, writable: true,
  value: {
    clipboard: { writeText: async () => {} },
    geolocation: { getCurrentPosition: (ok) => ok({ coords: { latitude: gpsUrmator.lat, longitude: gpsUrmator.lon, accuracy: gpsUrmator.acc } }) },
  },
});
globalThis.location = { hash: '#/panou', protocol: 'https:', replace(h) { this.hash = h; }, reload() {} };
globalThis.history = { length: 1, back() {} };

const asteapta = () => new Promise((r) => setImmediate(r));

await import('../../js/app.js');
for (let i = 0; i < 5; i++) await asteapta();
S = await import('../../js/state.js');
E = await import('../../js/editor.js');
const D = await import('../../js/dates.js');

// ───────── ecranul, ca șir de jetoane ─────────
// Pastilele, câmpurile (valoare, indiciu), butoanele (apăsat „+”, dezactivat „!”), clasele de stare, textul.
// EditorWebTests produce același șir din modelul Swift.
const STARE = /^(is-[\w-]+|warn|done|open|closed|over|cur|past|none|exact|t-[\w-]+|fb-\w+|dl-\w+|q-\w+|st-\w+|pv-\w+)$/;
const atribut = (a, n) => { const m = a.match(new RegExp(`\\s${n}="([^"]*)"`)); return m ? m[1] : null; };
function dec(s) {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
}
function tipPastila(cls) {
  const l = cls.split(/\s+/);
  return l.find((x) => x.startsWith('fs-')) || (l.find((x) => x.startsWith('pill-')) || 'pill-?').slice(5);
}
export function jetoane(html) {
  let s = html.replace(/<svg[\s\S]*?<\/svg>/g, '').replace(/<datalist[\s\S]*?<\/datalist>/g, '');
  s = s.replace(/<span class="pill ([^"]+)"([^>]*)>([\s\S]*?)<\/span>/g, (m, cls, a, t) => (/\shidden\b/.test(a) ? ' ' : ` ⟦${tipPastila(cls)}|${t.trim()}⟧ `));
  s = s.replace(/<input\b([^>]*)>/g, (m, a) => ` ⟦in|${atribut(a, 'value') ?? ''}|${atribut(a, 'placeholder') ?? ''}⟧ `);
  s = s.replace(/<textarea\b([^>]*)>([\s\S]*?)<\/textarea>/g, (m, a, v) => ` ⟦ta|${v}|${atribut(a, 'placeholder') ?? ''}⟧ `);
  s = s.replace(/<(\w+)\b([^>]*)>/g, (m, t, a) => {
    const cls = (atribut(a, 'class') || '').split(/\s+/).filter(Boolean);
    const st = cls.filter((x) => STARE.test(x)).map((x) => `.${x}`).join('');
    if (t === 'button' || t === 'a') return ` ⟦b${cls.includes('on') ? '+' : ''}${/\sdisabled\b/.test(a) ? '!' : ''}${st}⟧ `;
    if (cls.includes('cat-group')) return ` ⟦g:${cls.find((x) => x.startsWith('cat-') && x !== 'cat-group') || ''}${st}⟧ `;
    return st ? ` ⟦${st}⟧ ` : ' ';
  });
  s = dec(s.replace(/<[^>]+>/g, ' '));
  return s.split(/\s+/).filter(Boolean).join(' ').replace(/\s+([.,;:])/g, '$1');
}

// ───────── generarea pașilor ─────────
const cazuri = JSON.parse(fs.readFileSync(process.argv[2] || path.join(os.homedir(), 'Library/Caches/AgendaKit-diferential/cazuri.json'), 'utf8'));
const iesire = process.argv[3] || path.join(os.homedir(), 'Library/Caches/AgendaKit-diferential/editor.json');
let s = Number(process.argv[4] || 20260927) >>> 0;
const rnd = () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const alege = (l) => l[Math.floor(rnd() * l.length)];
const sansa = (p) => rnd() < p;
const intre = (a, b) => a + Math.floor(rnd() * (b - a + 1));

const OBS = ['', '', 'hol etaj 1', 'P6 nr. 3\nhol', '  corp B  ', 'Lipsă aviz; se va reface', 'stingătoare expirate'];
const SUME = ['', '2.500', '1500,5', '3000 lei', 'abc', '500', '12.345,67'];
const COORD = ['44.426800, 26.102500', '44°25′36″ N 26°6′9″ E', 'abc', '44,4268 26,1025', '', '91 10'];
const REGIM = ['P', 'P+1', 'S+P+2E', '', 'D+P', 'P+M', 'S+P', 'parter'];
const TEXTE = ['', 'Corp B', 'Ion Pop', '0722 123 456', 'a@b.ro', '1978', '250,5', 'Beton armat', 'Lemn', 'Școala nr. 3'];
const ETICHETE = ['Căi de evacuare blocate', 'Depozitare butelii în subsol', '', 'Ușă blocată'];
const LOCATII = ['Subsol corp A', 'Demisol', '', 'Sala 3'];
const CAUTARI = ['', 'd', 'G1', 'A1', 'hidr', 'stingatoare', 'hol', 'evacuare', 'lfd', 'instruire', 'xyz', 'plan', 'adapost'];
const EXCLUSE = new Set(['backup-export', 'control-delete', 'pv-text', 'scroll-top', 'modal-close']);

// butoanele, legăturile și câmpurile de pe ecran (din HTML-ul curent)
function candidati(html) {
  const cl = [];
  for (const m of html.matchAll(/<(button|a)\b([^>]*)>/g)) {
    const a = m[2];
    if (/\sdisabled\b/.test(a)) continue;
    const act = atribut(a, 'data-act');
    if (act) {
      if (EXCLUSE.has(act)) continue;
      const d = {};
      for (const x of a.matchAll(/\sdata-([\w-]+)="([^"]*)"/g)) if (x[1] !== 'act') d[x[1].replace(/-(\w)/g, (_, l) => l.toUpperCase())] = dec(x[2]);
      cl.push({ t: 'click', act, d });
    } else {
      const h = atribut(a, 'href');
      if (h && h.startsWith(`#/control/${c.id}/`)) cl.push({ t: 'nav', hash: dec(h) });
    }
  }
  const campuri = [];
  for (const m of html.matchAll(/<(input|textarea)\b([^>]*)>/g)) {
    const a = m[2];
    const bind = atribut(a, 'data-bind');
    const verif = atribut(a, 'data-verif');
    if (atribut(a, 'id') === 'ner-search') { campuri.push({ t: 'cautare' }); continue; }
    if (bind) campuri.push({ t: 'input', bind: dec(bind), tip: atribut(a, 'type') || m[1], rerender: a.includes('data-rerender'), grav: atribut(a, 'data-grav'), obs: a.includes('data-obs') });
    else if (verif) campuri.push({ t: 'verif', verif: dec(verif) });
  }
  return { cl, campuri };
}

function valoarePentru(bind, tip) {
  if (tip === 'date') return sansa(0.12) ? '' : D.addDays(c.dataInceput || '2026-10-15', intre(-30, 60));
  if (/regimInaltime$/.test(bind)) return alege(REGIM);
  if (/\.obs$/.test(bind)) return alege(OBS);
  if (/amenda\.suma$/.test(bind)) return alege(SUME);
  if (/\.locatie$/.test(bind)) return alege(LOCATII);
  if (/\.label$/.test(bind)) return alege(ETICHETE);
  return alege(TEXTE);
}

const fara = (x) => JSON.stringify(x, (k, v) => (k === 'updatedAt' ? undefined : v));
const rutaDin = (h) => { const p = h.replace(/^#\/?/, '').split('/').map(decodeURIComponent); return { tab: p[2] || 'obiectiv', focus: p[3] || '' }; };

async function schimbaRuta() {
  for (let i = 0; i < 4 && location.hash !== rutaCurenta; i++) {
    rutaCurenta = location.hash;
    ascultatoriFereastra.hashchange();
    await asteapta();
  }
  ({ tab } = rutaDin(location.hash));
}
let rutaCurenta = '';

async function click(act, d) {
  const html = E.viewControl(c, tab);
  const btn = {
    dataset: { act, ...d }, disabled: false,
    closest: (sel) => (sel === '.no-clear' ? (d.path === 'tip' ? {} : null)
      : sel === '.constr.open' ? (html.includes(`<article class="constr open" id="constr-${d.id}">`) ? {} : null) : null),
  };
  const p = Promise.all((ascultatori.click || []).map((f) => f({ target: { closest: (sel) => (sel === '[data-act]' ? btn : null) } })));
  for (let i = 0; i < 6; i++) {
    await asteapta();
    const l = clicuriModal; clicuriModal = [];
    for (const f of l) f();
  }
  await p;
}

async function eveniment(tip, tinta) {
  await Promise.all((ascultatori[tip] || []).map((f) => f({ target: tinta })));
  await asteapta();
}

const secvente = [];
const NR = Number(process.env.NR_SECVENTE || 60);
const PASI = Number(process.env.NR_PASI || 40);
const alese = cazuri.controls.filter((_, i) => i % Math.max(1, Math.floor(cazuri.controls.length / NR)) === 0).slice(0, NR);

for (const [si, ales] of alese.entries()) {
  S.state.controls = JSON.parse(JSON.stringify(cazuri.controls));
  c = S.state.controls.find((x) => x.id === ales.id);
  Object.assign(S.state.ui, {
    expanded: new Set(), collapsed: new Set(), nerFilter: 'ALL', nerQuery: '', constrPick: '', showAllNer: false,
    obsOpen: new Set(), toolsOpen: false, todoOpen: false, gpsBusy: '', catCollapsed: new Set(), rowCollapsed: new Set(), focusStrong: false,
  });
  const tab0 = alege(E.tabsFor(c).map((t) => t.key));
  location.hash = `#/control/${c.id}/${tab0}`;
  await schimbaRuta();
  let anterior = fara(c);
  const pasi = [{ pas: { t: 'start', tab: tab0 }, c: JSON.parse(anterior), tab, focus: rutaDin(location.hash).focus, tok: jetoane(E.viewControl(c, tab) + E.editToolsHTML(c)), ist: Object.values(S.historyState(c.id)) }];
  let ultimMesajCuActiune = false;

  for (let k = 0; k < PASI; k++) {
    mesaje = []; modale = []; raspuns = sansa(0.75);
    const html = E.viewControl(c, tab) + E.editToolsHTML(c);
    const { cl, campuri } = candidati(html);
    const r = rnd();
    let pas;
    if (ultimMesajCuActiune && actiuneMesaj && r < 0.15) pas = { t: 'mesaj' };
    else if (r < 0.2 && campuri.length) pas = { ...alege(campuri) };
    else if (r < 0.24) pas = { t: 'pauza' };
    else if (r < 0.27) pas = { t: 'pv' };
    else {
      // întâi tipul acțiunii, apoi butonul: fiecare acțiune de pe ecran e exersată la fel de des
      const tipuri = [...new Set(cl.map((x) => (x.t === 'click' ? x.act : x.t)))];
      const tip = alege(tipuri);
      pas = alege(cl.filter((x) => (x.t === 'click' ? x.act : x.t) === tip));
    }
    if (!pas) continue;

    const centrale = () => c.constructii.flatMap((x) => x.dotari?.centrala?.ct || []).map((x) => x.id);
    const inainte = { constr: new Set(c.constructii.map((x) => x.id)), chei: new Set(c.nereguli.map((x) => x.key)),
      intreb: new Set((c.deIntrebat || []).map((x) => x.id)), ct: new Set(centrale()) };
    if (pas.t === 'click') {
      if (pas.act === 'gps-get') { gpsUrmator = { lat: 44 + rnd() * 4, lon: 21 + rnd() * 8, acc: intre(3, 300) }; pas.gps = gpsUrmator; }
      pas.raspuns = raspuns;
      if (pas.act === 'gps-manual') pas.coord = alege(COORD);
      await click(pas.act, pas.d);
      // „Introduceți coordonatele”: textul scris, apoi „Salvează” (nerecunoscut: fereastra rămâne, cu mesajul)
      if (pas.act === 'gps-manual' && modalCurent) {
        modalCurent.el('#gps-man').value = pas.coord;
        modalCurent.el('#gps-man-ok').l.click();
        await asteapta();
        modale = [];
      }
    } else if (pas.t === 'nav') {
      location.hash = pas.hash;
    } else if (pas.t === 'input') {
      const valoare = valoarePentru(pas.bind, pas.tip);
      pas.valoare = valoare;
      const tinta = Object.assign(element(), { dataset: { bind: pas.bind, ...(pas.rerender ? { rerender: '1' } : {}), ...(pas.grav !== null ? { grav: pas.grav } : {}), ...(pas.obs ? { obs: '1' } : {}) }, value: valoare, tagName: pas.obs ? 'TEXTAREA' : 'INPUT', scrollHeight: 0 });
      await eveniment('input', tinta);
      if (pas.rerender || pas.grav !== null) { pas.change = true; await eveniment('change', tinta); }
      if (pas.obs && sansa(0.6)) { pas.focusout = true; await eveniment('focusout', tinta); }
    } else if (pas.t === 'verif') {
      pas.valoare = sansa(0.15) ? '' : D.addDays(c.dataInceput, -intre(0, 900));
      await eveniment('change', Object.assign(element(), { dataset: { verif: pas.verif }, value: pas.valoare }));
    } else if (pas.t === 'cautare') {
      pas.q = alege(CAUTARI);
      await eveniment('input', Object.assign(element('ner-search'), { dataset: { sec: tab === 'acte' ? 'acte' : { nereguli: 'ner', planuri: 'plan', pc: 'pc' }[tab] }, value: pas.q }));
    } else if (pas.t === 'pauza') {
      S.checkpoint(c);
    } else if (pas.t === 'pv') {
      // Text PV → „Marchează-le trecute în PV”
      await click('pv-text', {});
      modalCurent.el('[data-pv="mark"]').l.click();
      await asteapta();
      modale = [];
    } else if (pas.t === 'mesaj') {
      const f = actiuneMesaj; actiuneMesaj = null; f();
      await asteapta();
    }
    await schimbaRuta();
    c = S.state.controls.find((x) => x.id === ales.id);

    const acum = fara(c);
    const rec = { pas, tab, focus: rutaDin(location.hash).focus, tok: jetoane(E.viewControl(c, tab) + E.editToolsHTML(c)), ist: Object.values(S.historyState(c.id)) };
    if (acum !== anterior) { rec.c = JSON.parse(acum); anterior = acum; }
    if (pas.t === 'click' && ['constr-inc', 'ner-add', 'adp-count', 'intreb-add', 'ct-count', 'centrala'].includes(pas.act)) {
      const nou = c.constructii.find((x) => !inainte.constr.has(x.id))?.id || c.nereguli.find((x) => !inainte.chei.has(x.key))?.key.replace(/^(k|adp)/, '')
        || (c.deIntrebat || []).find((x) => !inainte.intreb.has(x.id))?.id.replace(/^q/, '')
        || centrale().find((x) => !inainte.ct.has(x))?.replace(/^ct/, '');
      if (nou) rec.uid = nou;
    }
    if (mesaje.length) rec.mesaje = mesaje;
    if (modale.length) rec.modale = modale.map(jetoane);
    ultimMesajCuActiune = mesaje.some((m) => m.actiune);
    pasi.push(rec);
  }
  secvente.push({ id: ales.id, pasi });
  process.stdout.write(`\r${si + 1}/${alese.length}`);
}

// ───────── fereastra „Control nou”: obiectivele găsite și butonul, pentru mai multe denumiri scrise ─────────
S.state.controls = JSON.parse(JSON.stringify(cazuri.controls));
modale = [];
await click('new-control', {});
const controlNou = [];
for (const q of ['', 'scoala', 'Școala', 'ȘUȘANI', 'spital', 'xyz', '  hotel aurora  ', 'Hotel Aurora', 'a', 'gradinita nr. 2', 'Biserica Sf. Ilie', '   ', 'depozit']) {
  const nume = modalCurent.el('#nc-name');
  nume.value = q;
  nume.l.input();
  controlNou.push({ q, html: jetoane(modalCurent.el('#nc-existing').innerHTML), buton: modalCurent.el('#nc-create span').textContent });
}

fs.mkdirSync(path.dirname(iesire), { recursive: true });
fs.writeFileSync(iesire, JSON.stringify({ acum: new DateReal(ACUM).toISOString(), secvente, controlNou }));
const nrPasi = secvente.reduce((a, x) => a + x.pasi.length, 0);
console.log(`\nScris: ${iesire} (${secvente.length} secvențe, ${nrPasi} pași, ${fs.statSync(iesire).size} octeți)`);
process.exit(0);
