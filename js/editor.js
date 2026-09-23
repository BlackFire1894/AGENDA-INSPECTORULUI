// Editorul unui control: 3 taburi — Obiectiv, Acte & evidențe, Nereguli.
import { state, today } from './state.js';
import { fmtDate, fmtDateLong, isISO } from './dates.js';
import {
  TIP_OBIECTIV, DOTARI, CENTRALA_TIPURI, ACTE, STRUCTURI, MATERIALE_PERETI, SECTIUNI, CATEGORII,
  controlStats, secStats, fineStatus, fineDate, asiDeadline, isIncheiat, neregulaLabel, neregulaLetter,
  neregulaCat, secOf, isApplicable, isLocalitate, constructieOf, amendaSerieNr, vecheInfo, constatareAnterioara, todoList,
} from './model.js';
import { icon, esc, pill, tipBadge, helpBtn } from './ui.js';

// Toate taburile posibile; „planuri” și „pc” apar doar la controalele de tip Localitate.
export const TABS = [
  { key: 'obiectiv', label: 'Obiectiv', ic: 'building' },
  { key: 'acte', label: 'Acte & evidențe', ic: 'doc' },
  { key: 'planuri', label: 'Planuri și SVSU', ic: 'list', sec: 'plan' },
  { key: 'pc', label: 'Protecție civilă', ic: 'shield', sec: 'pc' },
  { key: 'nereguli', label: 'Nereguli', ic: 'alert', sec: 'ner' },
];

export function tabsFor(c) {
  return TABS.filter((t) => !t.sec || !SECTIUNI[t.sec].onlyLocalitate || isLocalitate(c));
}

export function viewControl(c, tab) {
  curControlId = c.id;
  return `<div class="editor">
    <header class="ed-head" id="ed-head">${edHeadHTML(c)}</header>
    <div id="ed-todo">${todoHTML(c)}</div>
    <nav class="ed-tabs" id="ed-tabs" style="--tabs:${tabsFor(c).length}">${edTabsHTML(c, tab)}</nav>
    <div id="ed-body" class="ed-body">${tabHTML(c, tab)}</div>
  </div>`;
}

export function edHeadHTML(c) {
  return `<a class="icon-btn big" href="${esc(state.ui.backTo)}" aria-label="Înapoi">${icon('back')}</a>
    <div class="ed-title">
      <div class="ed-meta">${tipBadge(c.tip)}${isIncheiat(c) ? pill('done', 'Încheiat', 'check') : pill('open', 'În desfășurare', 'clock')}</div>
      <h1 data-live="denumire">${esc(c.denumire || 'Obiectiv fără denumire')}</h1>
      <div class="ed-dates">${icon('calendar')} ${esc(fmtDate(c.dataInceput))}${isIncheiat(c) ? ` – ${esc(fmtDate(c.dataIncheiere))}` : ' – în desfășurare'}
        <span class="save-ind" id="save-ind">${icon('check')}<span>Salvat</span></span></div>
    </div>
    <div class="ed-actions">
      <button class="btn btn-ghost" data-act="pv-text">${icon('pv')} Text PV</button>
      <a class="btn btn-ghost" href="#/fisa/${c.id}">${icon('download')} Fișa PDF</a>
      <a class="btn btn-ghost" href="#/obiectiv/${c.objectiveId}">${icon('history')} Istoric</a>
      <button class="btn btn-ghost" data-act="backup-export" title="Backup rapid al tuturor controalelor">${icon('upload')} Backup</button>
      ${helpBtn('ctrl')}
      <button class="icon-btn big danger" data-act="control-delete" aria-label="Șterge controlul">${icon('trash')}</button>
    </div>`;
}

// „Ce mai ai de făcut”: pasul următor, cu acces direct; lista completă se deschide la cerere.
export function todoHTML(c) {
  const items = todoList(c);
  if (!items.length) {
    return `<div class="todo todo-done">${icon('check')}<span><b>Totul e completat.</b> Puteți genera Text PV sau Fișa PDF.</span></div>`;
  }
  const open = state.ui.todoOpen;
  const btn = (x) => `<button class="todo-item t-${x.level}" data-act="todo-go" data-tab="${x.tab}" data-focus="${esc(x.focus || '')}">
      ${icon(x.level === 'warn' ? 'alert' : 'chevR')}<span>${esc(x.text)}</span></button>`;
  return `<div class="todo ${open ? 'open' : ''}">
    <div class="todo-head">
      <span class="todo-title">${icon('list')} Ce mai ai de făcut <b>${items.length}</b></span>
      ${open ? '' : btn(items[0])}
      ${items.length > 1 || open ? `<button class="todo-more" data-act="todo-toggle">${open ? 'Ascunde lista' : `Toate (${items.length})`}</button>` : ''}
    </div>
    ${open ? `<div class="todo-list">${items.map(btn).join('')}</div>` : ''}
  </div>`;
}

export function edTabsHTML(c, tab) {
  const st = controlStats(c, today());
  const tabs = tabsFor(c);
  const badge = (t) => {
    if (t.key === 'obiectiv') return [`${c.constructii.length} ${tabs.length >= 5 ? 'constr.' : c.constructii.length === 1 ? 'construcție' : 'construcții'}`, false];
    if (t.key === 'acte') return [tabs.length < 5 || !st.acteNok ? `${st.acteDone}/${st.acteTotal}${st.acteNok ? ` · ${st.acteNok} lipsă` : ''}` : `${st.acteNok} lipsă`, st.acteNok > 0];
    const s2 = secStats(c, t.sec, today());
    // Cu 5 taburi, textul e scurt ca să încapă; culoarea portocalie semnalează nereguli netrecute în PV.
    if (s2.constatate) return [`${s2.constatate} ${nokWord(t.sec, s2.constatate)}${s2.netrecute && tabs.length < 5 ? ` · ${s2.netrecute} netrecute` : ''}`, s2.netrecute > 0];
    return [`${s2.checked}/${s2.total} verificate`, false];
  };
  return tabs.map((t, i) => {
    const [txt, warn] = badge(t);
    return `<a class="ed-tab ${t.key === tab ? 'on' : ''}" href="#/control/${c.id}/${t.key}">
      <span class="tab-num">${i + 1}</span>
      <span class="tab-txt"><b>${t.label}</b><small class="${warn ? 'warn' : ''}">${esc(txt)}</small></span>
    </a>`;
  }).join('');
}

export function tabHTML(c, tab) {
  curControlId = c.id;
  const t = tabsFor(c).find((x) => x.key === tab);
  if (!t || t.key === 'obiectiv') return tabObiectiv(c);
  if (t.key === 'acte') return tabActe(c);
  return tabSectiune(c, t.sec);
}

// ───────── helpers pentru câmpuri ─────────

// Observații: câmp pe mai multe rânduri (Enter = rând nou) care crește doar în jos.
// Fiecare câmp se poate ascunde / afișa individual; butonul general „Ascunde / Arată observațiile” le setează pe toate.
// Ascuns: cele completate au indicatorul „Observații scrise”, cele goale „+ Observații”.
let curControlId = '';
export const obsKey = (path) => `${curControlId}|${path}`;
export function obsIsHidden(path) {
  const o = state.ui.obsOverride.get(obsKey(path));
  return o === undefined ? state.ui.obsHidden : o;
}

function obsField(path, value, cls = 'row-obs') {
  if (obsIsHidden(path)) {
    return value
      ? `<button type="button" class="obs-add has-obs" data-act="obs-show" data-path="${path}" title="${esc(value.slice(0, 120))}">${icon('doc')} Observații scrise</button>`
      : `<button type="button" class="obs-add" data-act="obs-show" data-path="${path}">${icon('plus')} Observații</button>`;
  }
  return `<div class="obs-wrap">
    <textarea class="obs ${cls}" data-bind="${path}" rows="1" placeholder="Observații" autocomplete="off" enterkeyhint="enter">${esc(value)}</textarea>
    <button type="button" class="obs-hide" data-act="obs-hide" data-path="${path}" aria-label="Ascunde aceste observații" title="Ascunde">${icon('chevD', 'up')}</button>
  </div>`;
}

// Construcția în care s-a făcut constatarea (implicit prima construcție)
function constrSelect(c, n, path) {
  const cur = constructieOf(c, n);
  if (!cur) return '';
  return `<label class="constr-sel">
    ${icon('building')}<span class="constr-sel-lbl">Construcția</span>
    <select data-bind="${path}.constructieId" data-rerender="1" aria-label="Construcția în care s-a făcut constatarea">
      ${c.constructii.map((k, i) => `<option value="${k.id}" ${k.id === cur.id ? 'selected' : ''}>${i + 1}. ${esc(k.denumire || `Construcția ${i + 1}`)}</option>`).join('')}
    </select>
  </label>`;
}

function field(label, path, value, { type = 'text', ph = '', list = '', mode = '', unit = '', wide = false, live = '' } = {}) {
  return `<label class="field ${wide ? 'wide' : ''}">
    <span class="lbl">${esc(label)}</span>
    <span class="inp-wrap">
      <input type="${type}" data-bind="${path}" value="${esc(value)}" placeholder="${esc(ph)}" ${list ? `list="${list}"` : ''} ${mode ? `inputmode="${mode}"` : ''} ${live ? `data-live-src="${live}"` : ''} autocomplete="off">
      ${unit ? `<span class="unit">${esc(unit)}</span>` : ''}
    </span>
  </label>`;
}

function segBtns(path, value, opts, cls = '') {
  return `<div class="segmented ${cls}">${opts.map((o) => {
    const [k, l] = Array.isArray(o) ? o : [o, o];
    return `<button type="button" class="${value === k ? 'on' : ''} v-${esc(k)}" ${k === 'NEC' ? 'title="Nu este cazul" aria-label="Nu este cazul"' : ''} data-act="set" data-path="${path}" data-val="${esc(k)}" data-toggle="1">${esc(l)}</button>`;
  }).join('')}</div>`;
}

function toggle(path, on, label, { level = 'accent', ic = 'check', offLabel = '' } = {}) {
  return `<button type="button" class="toggle ${on ? `on t-${level}` : ''}" data-act="flag" data-path="${path}" aria-pressed="${on}">
    <span class="tg-box">${on ? icon(ic) : ''}</span><span>${esc(on || !offLabel ? label : offLabel)}</span>
  </button>`;
}

// ───────── TAB 1: OBIECTIV ─────────

function tabObiectiv(c) {
  const endBlock = isIncheiat(c)
    ? `<div class="field">
        <span class="lbl">Data încheierii controlului</span>
        <span class="inp-wrap"><input type="date" data-bind="dataIncheiere" data-rerender="1" value="${esc(c.dataIncheiere)}"></span>
        <span class="field-actions">
          <button class="chip-btn" data-act="end-today">Azi</button>
          <button class="chip-btn danger" data-act="reopen">Redeschide</button>
        </span>
        ${c.dataIncheiere < c.dataInceput ? `<span class="field-err">${icon('alert')} Data încheierii este înaintea datei de începere.</span>` : ''}
      </div>`
    : `<div class="field">
        <span class="lbl">Data încheierii controlului</span>
        <div class="end-empty">
          <span>${icon('clock')} Control în desfășurare</span>
          <button class="btn btn-success btn-lg" data-act="close-control">${icon('check')} Încheie controlul</button>
        </div>
        <span class="hint">Se completează implicit cu data începerii; o poți modifica după.</span>
      </div>`;

  return `
  <section class="card form-card" id="sec-date">
    <h2 class="sec-title">${icon('building')} Date obiectiv</h2>
    <div class="field wide">
      <span class="lbl">Tip obiectiv</span>
      ${segBtns('tip', c.tip, TIP_OBIECTIV.map((t) => [t.key, t.label]), 'seg-lg no-clear')}
    </div>
    <div class="form-grid">
      ${field('Denumire obiectiv', 'denumire', c.denumire, { ph: 'ex: Școala Gimnazială nr. 1', wide: true, live: 'denumire' })}
      ${field('Administrator obiectiv', 'administrator', c.administrator, { ph: 'Nume și prenume' })}
      <label class="field">
        <span class="lbl">Telefon</span>
        <span class="inp-wrap"><input type="tel" data-bind="telefon" value="${esc(c.telefon)}" placeholder="07xx xxx xxx" inputmode="tel" autocomplete="off">
        ${c.telefon ? `<a class="inp-action" href="tel:${esc(c.telefon.replace(/\s/g, ''))}" aria-label="Sună">${icon('phone')}</a>` : ''}</span>
      </label>
      <label class="field wide">
        <span class="lbl">Email</span>
        <span class="inp-wrap"><input type="email" data-bind="email" value="${esc(c.email)}" placeholder="nume@exemplu.ro" inputmode="email" autocomplete="off" autocapitalize="off">
        ${c.email ? `<a class="inp-action" href="mailto:${esc(c.email)}" aria-label="Trimite email">${icon('mail')}</a>` : ''}</span>
      </label>
    </div>
  </section>

  <section class="card form-card" id="sec-perioada">
    <h2 class="sec-title">${icon('calendar')} Perioada controlului</h2>
    <div class="form-grid">
      <div class="field">
        <span class="lbl">Data începerii controlului</span>
        <span class="inp-wrap"><input type="date" data-bind="dataInceput" data-rerender="1" value="${esc(c.dataInceput)}"></span>
        <span class="field-actions"><button class="chip-btn" data-act="start-today">Azi</button></span>
      </div>
      ${endBlock}
    </div>
  </section>

  <section class="card form-card">
    <div class="sec-title-row">
      <h2 class="sec-title">${icon('layers')} Construcții</h2>
      <div class="stepper" aria-label="Număr construcții">
        <button class="step-btn" data-act="constr-dec" aria-label="Mai puține">−</button>
        <span class="step-val"><b>${c.constructii.length}</b><small>${c.constructii.length === 1 ? 'construcție' : 'construcții'}</small></span>
        <button class="step-btn" data-act="constr-inc" aria-label="Mai multe">+</button>
      </div>
    </div>
    <div class="constr-list">${c.constructii.map((k, i) => constructieHTML(c, k, i)).join('')}</div>
  </section>
  <datalist id="dl-structura">${STRUCTURI.map((s) => `<option value="${esc(s)}">`).join('')}</datalist>
  <datalist id="dl-pereti">${MATERIALE_PERETI.map((s) => `<option value="${esc(s)}">`).join('')}</datalist>`;
}

function isOpen(c, k, i) {
  const u = state.ui;
  if (u.collapsed.has(k.id)) return false;
  if (u.expanded.has(k.id)) return true;
  return c.constructii.length === 1 || i === 0;
}

function dotariSummary(k) {
  let da = 0, nec = 0, set = 0;
  for (const d of DOTARI) {
    const v = k.dotari[d.key];
    if (d.centrala) { if (v.tipuri.length || v.nuAre) set++; continue; }
    if (v.v) set++;
    if (v.v === 'DA') da++;
    if (v.v === 'NEC') nec++;
  }
  return { da, nec, set, total: DOTARI.length };
}

function constructieHTML(c, k, i) {
  const open = isOpen(c, k, i);
  const p = `constructii.#${k.id}`;
  const s = dotariSummary(k);
  return `<article class="constr ${open ? 'open' : ''}">
    <div class="constr-head">
      <span class="constr-num">${i + 1}</span>
      <input class="constr-name" data-bind="${p}.denumire" value="${esc(k.denumire)}" placeholder="Denumirea construcției ${i + 1}" autocomplete="off">
      <span class="constr-sum">${s.set}/${s.total} dotări${k.suprafata ? ` · ${esc(k.suprafata)} m²` : ''}${k.regimInaltime ? ` · ${esc(k.regimInaltime)}` : ''}</span>
      <button class="icon-btn" data-act="constr-toggle" data-id="${k.id}" aria-label="${open ? 'Restrânge' : 'Extinde'}">${icon('chevD', open ? 'rot' : '')}</button>
    </div>
    ${open ? `<div class="constr-body">
      <div class="form-grid g3">
        ${field('Suprafață desfășurată', `${p}.suprafata`, k.suprafata, { mode: 'decimal', unit: 'm²', ph: '0' })}
        ${field('Regim de înălțime', `${p}.regimInaltime`, k.regimInaltime, { ph: 'ex: S+P+2E' })}
        ${field('Nr. angajați', `${p}.nrAngajati`, k.nrAngajati, { mode: 'numeric', ph: '0' })}
        ${field('Structura de rezistență', `${p}.structura`, k.structura, { list: 'dl-structura', ph: 'Alege sau scrie' })}
        ${field('Material pereți', `${p}.materialPereti`, k.materialPereti, { list: 'dl-pereti', ph: 'Alege sau scrie' })}
      </div>
      <div class="mini-row"><h3 class="mini-title">Dotări și instalații <small>NEC = nu este cazul</small></h3>${i === 0 || state.ui.obsHidden ? obsToggleBtn() : ''}</div>
      <div class="dotari">${DOTARI.map((d) => dotareRow(p, k, d)).join('')}</div>
      ${c.constructii.length > 1 ? `<div class="constr-foot"><button class="btn btn-ghost danger" data-act="constr-del" data-id="${k.id}">${icon('trash')} Șterge construcția</button></div>` : ''}
    </div>` : ''}
  </article>`;
}

function dotareRow(p, k, d) {
  const v = k.dotari[d.key];
  const path = `${p}.dotari.${d.key}`;
  if (d.centrala) {
    return `<div class="dot-row">
      <span class="dot-label">${esc(d.label)}</span>
      <div class="chips-sel">
        ${CENTRALA_TIPURI.map((t) => `<button type="button" class="chip-sel ${v.tipuri.includes(t) ? 'on' : ''}" data-act="centrala" data-path="${path}" data-val="${t}">${t}</button>`).join('')}
        <button type="button" class="chip-sel ${v.nuAre ? 'on off-kind' : ''}" data-act="centrala" data-path="${path}" data-val="NU_ARE">NU ARE</button>
      </div>
      ${obsField(`${path}.obs`, v.obs, 'dot-obs')}
    </div>`;
  }
  return `<div class="dot-row">
    <span class="dot-label">${esc(d.label)}</span>
    ${segBtns(`${path}.v`, v.v, d.opts, 'seg-dnn')}
    ${obsField(`${path}.obs`, v.obs, 'dot-obs')}
  </div>`;
}

// ───────── TAB 2: ACTE ─────────

function tabActe(c) {
  const st = controlStats(c, today());
  const ok = ACTE.filter((a) => c.acte[a.key].status === 'ok').length;
  return `<section class="card">
    <div class="sec-title-row">
      <h2 class="sec-title">${icon('doc')} Acte de autoritate și evidențe</h2>
      <div class="tool-btns">${obsToggleBtn()}${restBtn(st.acteTotal - st.acteDone, 'acte', 'Restul prezentate')}</div>
      <div class="progress-txt"><b>${st.acteDone}</b>/${st.acteTotal} verificate · <span class="t-green">${ok} prezentate</span> · <span class="t-red">${st.acteNok} lipsă</span></div>
    </div>
    <div class="progress"><span class="p-ok" style="width:${(ok / st.acteTotal) * 100}%"></span><span class="p-nok" style="width:${(st.acteNok / st.acteTotal) * 100}%"></span></div>
    <div class="check-list">${ACTE.map((a, i) => {
      const v = c.acte[a.key];
      const path = `acte.${a.key}`;
      return `<div class="check-row ${v.status ? `is-${v.status}` : ''}" id="act-${a.key}">
        <span class="row-idx">${i + 1}</span>
        <div class="row-main">
          <span class="row-label">${esc(a.label)}</span>
          ${obsField(`${path}.obs`, v.obs)}
        </div>
        ${okNok(path, v.status, 'Prezentat', 'Lipsă')}
      </div>`;
    }).join('')}</div>
  </section>`;
}

function okNok(path, status, okLabel, nokLabel) {
  return `<div class="oknok">
    <button type="button" class="ok-btn ${status === 'ok' ? 'on' : ''}" data-act="set" data-path="${path}.status" data-val="ok" data-toggle="1" aria-pressed="${status === 'ok'}">${icon('check')}<span>${okLabel}</span></button>
    <button type="button" class="nok-btn ${status === 'nok' ? 'on' : ''}" data-act="set" data-path="${path}.status" data-val="nok" data-toggle="1" aria-pressed="${status === 'nok'}">${icon('x')}<span>${nokLabel}</span></button>
  </div>`;
}

// ───────── TABURI DE CONSTATĂRI: Nereguli, Planuri și SVSU, Protecție civilă ─────────

// „1 constatată / 2 constatate”, „1 neconformă / 2 neconforme”
const nokWord = (sec, n) => (sec === 'ner' ? (n === 1 ? 'constatată' : 'constatate') : (n === 1 ? 'neconformă' : 'neconforme'));

const SEC_UI = {
  ner: { ic: 'alert', title: 'Nereguli constatate', addTitle: 'Nereguli suplimentare', nokWord: 'constatate', empty: 'Adaugă nereguli care nu se află în lista standard.' },
  plan: { ic: 'list', title: 'Planuri și SVSU', addTitle: 'Rubrici suplimentare', nokWord: 'neconforme', empty: 'Adaugă rubrici care nu se află în lista standard.' },
  pc: { ic: 'shield', title: 'Protecție civilă', addTitle: 'Rubrici suplimentare', nokWord: 'neconforme', empty: 'Adaugă rubrici care nu se află în lista standard.' },
};

function tabSectiune(c, sec) {
  const ui = SEC_UI[sec];
  const st = secStats(c, sec, today());
  const f = state.ui.nerFilter;
  const showAll = state.ui.showAllNer;
  const rows = c.nereguli.filter((n) => secOf(n) === sec);
  const tmpl = rows.filter((n) => !n.custom && (showAll || isApplicable(c, n)));
  const custom = rows.filter((n) => n.custom);
  const show = (n) => f === 'ALL' || (f === 'NOK' ? n.status === 'nok' : !n.status);
  const inPV = st.constatate - st.netrecute;
  const anyFineOrAsi = st.fines.length || (sec === 'ner' && asiDeadline(c, today()));

  // grupare pe categorii, în ordinea din listă
  const groups = [];
  for (const n of tmpl) {
    const cat = neregulaCat(n);
    let g = groups.find((x) => x.cat === cat);
    if (!g) { g = { cat, rows: [] }; groups.push(g); }
    g.rows.push(n);
  }
  let body = groups.map((g) => {
    const vis = g.rows.filter(show);
    const adapost = sec === 'pc' && g.cat === 'pcdotare' && (f === 'ALL' || (f === 'TODO' && !c.adapostPC.v)) ? adapostRow(c) : '';
    if (!vis.length && !adapost) return '';
    const nok = g.rows.filter((n) => n.status === 'nok').length;
    const closed = state.ui.catCollapsed.has(g.cat);
    const nRows = vis.length + (adapost ? 1 : 0);
    return `<div class="cat-group cat-${g.cat} ${closed ? 'closed' : ''}">
      <button type="button" class="cat-title" data-act="cat-toggle" data-cat="${g.cat}" aria-expanded="${!closed}">
        ${icon('chevD', closed ? '' : 'rot')}<span class="cat-name">${esc(CATEGORII[g.cat])}</span>
        <span class="cat-meta">${nRows} ${nRows === 1 ? 'rând' : 'rânduri'}</span>
        ${nok ? `<span class="cat-count">${nok} ${nokWord(sec, nok)}</span>` : ''}
      </button>
      ${closed ? '' : `<div class="check-list">${vis.map((n) => neregulaRow(c, n)).join('')}${adapost}</div>`}
    </div>`;
  }).join('');
  if (!body) body = '<p class="muted pad">Nimic de afișat pentru acest filtru.</p>';

  const hiddenNote = sec === 'ner' && st.hidden > 0
    ? `<div class="banner banner-info">${icon('info')}<span>${showAll
      ? `Se văd toate neregulile, inclusiv cele ${st.hidden} pentru instalații care nu sunt bifate DA la dotări.`
      : `<b>${st.hidden} nereguli de instalații sunt ascunse</b>: instalațiile respective nu sunt bifate DA la dotări (tabul Obiectiv).`}</span>
      <button class="btn btn-ghost" data-act="toggle-all-ner">${showAll ? 'Ascunde-le' : 'Arată toate'}</button></div>`
    : '';

  return `<section class="ner-summary">
      <div class="sum-box"><b>${st.checked}<small>/${st.total}</small></b><span>verificate</span></div>
      <div class="sum-box s-red"><b>${st.constatate}</b><span>${ui.nokWord}</span></div>
      <div class="sum-box ${st.netrecute ? 's-warn' : 's-green'}"><b>${inPV}<small>/${st.constatate}</small></b><span>trecute în PV</span></div>
      <div class="sum-box s-blue"><b>${st.fines.length}</b><span>amenzi</span></div>
    </section>
    ${!isIncheiat(c) && anyFineOrAsi ? `<div class="banner banner-info">${icon('info')}<span>Termenele amenzilor${sec === 'ner' ? ' și ASI' : ''} pornesc după ce completezi <b>data încheierii</b> în tabul Obiectiv.</span></div>` : ''}
    ${hiddenNote}
    <div class="toolbar">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['NOK', `${ui.nokWord[0].toUpperCase()}${ui.nokWord.slice(1)} (${st.constatate})`], ['TODO', `Neverificate (${st.total - st.checked})`]].map(([k, l]) => `<button class="${f === k ? 'on' : ''}" data-act="ner-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
      <div class="tool-btns">
        ${(() => { const all = groups.length && groups.every((g) => state.ui.catCollapsed.has(g.cat)); return `<button class="btn btn-ghost" data-act="cats-all" data-val="${all ? 'open' : 'close'}">${icon(all ? 'chevD' : 'list')} ${all ? 'Extinde categoriile' : 'Restrânge categoriile'}</button>`; })()}
        ${obsToggleBtn()}
        ${restBtn(st.total - st.checked - (sec === 'pc' && !c.adapostPC.v ? 1 : 0), sec, sec === 'ner' ? 'Restul conform' : 'Restul conforme')}
      </div>
    </div>
    <section class="card">
      <h2 class="sec-title">${icon(ui.ic)} ${ui.title}</h2>
      ${body}
    </section>
    <section class="card">
      <div class="sec-title-row">
        <h2 class="sec-title">${icon('plus')} ${ui.addTitle}</h2>
        <button class="btn btn-primary" data-act="ner-add" data-sec="${sec}">${icon('plus')} Adaugă rând</button>
      </div>
      <div class="cat-group cat-custom"><div class="check-list">${custom.filter(show).map((n) => neregulaRow(c, n)).join('') || `<p class="muted pad">${ui.empty}</p>`}</div></div>
    </section>`;
}

// Adăpost de protecție civilă: DA / NU / NEC + observații
// „Restul conform”: bifează în bloc rândurile vizibile încă neverificate (cu confirmare și „Anulează”)
function restBtn(n, sec, label) {
  if (n <= 0) return '';
  return `<button class="btn btn-ghost btn-rest" data-act="rest-ok" data-sec="${sec}">${icon('check')} ${label} (${n})</button>`;
}

export function obsToggleBtn() {
  const h = state.ui.obsHidden;
  return `<button class="btn btn-ghost ${h ? 'is-on' : ''}" data-act="obs-toggle" aria-pressed="${h}">${icon('doc')} ${h ? 'Arată observațiile' : 'Ascunde observațiile'}</button>`;
}

function adapostRow(c) {
  const v = c.adapostPC;
  return `<div class="check-row adapost-row" id="ner-adapostPC">
    <span class="row-idx letter">2</span>
    <div class="row-main">
      <span class="row-label">Adăpost de protecție civilă <small class="muted">NEC = nu este cazul</small></span>
      ${obsField('adapostPC.obs', v.obs)}
    </div>
    <div class="row-side">${segBtns('adapostPC.v', v.v, ['DA', 'NU', 'NEC'], 'seg-dnn seg-adapost')}</div>
  </div>`;
}

function neregulaRow(c, n) {
  const path = `nereguli.@${n.key}`;
  const letter = neregulaLetter(c, n);
  const sec = SECTIUNI[secOf(n)];
  const labelHTML = n.custom
    ? `<input class="row-label-input" data-bind="${path}.label" value="${esc(n.label)}" placeholder="Descrie ${secOf(n) === 'ner' ? 'neregula' : 'rubrica'}…" autocomplete="off">`
    : `<span class="row-label">${esc(neregulaLabel(n))}</span>`;
  const chips = [];
  if (n.status === 'nok') {
    chips.push(n.inPV ? pill('green', 'Trecut în PV', 'pv') : pill('warn', 'Netrecut în PV', 'pv'));
    if (n.amenda.aplicata) { const fs = fineStatus(c, n, today()); chips.push(pill(fs.level, `Amendă · ${fs.label}`, 'fine')); }
  }
  const vi = vecheInfo(state.controls, c, n);
  if (vi.veche) chips.unshift(`<span class="pill pill-veche">${icon('history')}Neregulă veche</span>`);
  else if (n.status !== 'nok' && vi.auto) chips.push(pill('neutral', `Constatată la controlul din ${fmtDate(vi.auto.dataInceput)}`, 'history'));
  if (!n.custom && !isApplicable(c, { ...n, status: '' })) chips.push(pill('neutral', 'Instalație nebifată DA la dotări', 'info'));
  return `<div class="check-row ner-row ${n.status ? `is-${n.status}` : ''} ${vi.veche ? 'is-veche' : ''}" id="ner-${esc(n.key)}">
    <span class="row-idx letter">${esc(letter)}</span>
    <div class="row-main">
      ${labelHTML}
      ${chips.length ? `<span class="chips">${chips.join('')}</span>` : ''}
      ${n.sec === 'ner' || !n.sec ? constrSelect(c, n, path) : ''}
      ${obsField(`${path}.obs`, n.obs)}
    </div>
    <div class="row-side">
      ${okNok(path, n.status, sec.ok, sec.nok)}
      ${n.custom ? `<button class="icon-btn danger" data-act="ner-del" data-key="${esc(n.key)}" aria-label="Șterge rândul">${icon('trash')}</button>` : ''}
    </div>
    ${n.status === 'nok' ? neregulaDetail(c, n, path) : ''}
  </div>`;
}

function neregulaDetail(c, n, path) {
  const a = n.amenda;
  let asi = '';
  if (n.key === 'a' && !n.custom && secOf(n) === 'ner') {
    const d = asiDeadline(c, today());
    asi = `<div class="detail-block">
      <div class="detail-toggles">
        ${toggle(`${path}.asiTermen`, n.asiTermen, 'Termen de prezentare 90 de zile', { level: 'red', ic: 'hourglass' })}
        ${n.asiTermen ? toggle(`${path}.asiPrezentat`, n.asiPrezentat, 'Documentație prezentată', { level: 'green' }) : ''}
      </div>
      ${n.asiTermen && d ? `<div class="deadline ${d.resolved ? 'dl-green' : 'dl-red'}">
        ${icon(d.resolved ? 'check' : 'hourglass')}
        <div><b>${d.resolved ? 'Rezolvat' : d.pending ? 'Termen neînceput' : `Termen: ${esc(fmtDateLong(d.deadline))}`}</b><span>${esc(d.msg)}</span>${d.nelucr ? `<span class="nelucr-inline">⚠ ${esc(d.nelucr)}</span>` : ''}</div>
        ${!d.pending && !d.resolved ? `<span class="countdown big ${d.daysLeft < 0 ? 'over' : ''}"><b>${Math.abs(d.daysLeft)}</b><small>${d.daysLeft < 0 ? 'zile depășit' : d.daysLeft === 1 ? 'zi' : 'zile'}</small></span>` : ''}
      </div>` : ''}
      ${n.asiTermen && n.asiPrezentat ? `<div class="form-grid g3"><label class="field"><span class="lbl">Data prezentării</span><span class="inp-wrap"><input type="date" data-bind="${path}.asiDataPrezentare" data-rerender="1" value="${esc(n.asiDataPrezentare)}"></span></label></div>` : ''}
    </div>`;
  }
  let fine = '';
  if (a.aplicata) {
    const fs = fineStatus(c, n, today());
    const fd = fineDate(c, n);
    fine = `<div class="fine-box fb-${fs.level}">
      <div class="fine-status">
        <span class="fine-dot"></span>
        <div><b>${esc(fs.label)}${amendaSerieNr(a) ? ` · ${esc(amendaSerieNr(a))}` : ''}</b><span>${esc(fs.msg)}</span></div>
      </div>
      <div class="form-grid g3">
        ${field('Seria amenzii', `${path}.amenda.serie`, a.serie, { ph: 'ex: AB' })}
        ${field('Nr. amenzii', `${path}.amenda.numar`, a.numar, { mode: 'numeric', ph: 'ex: 0012345' })}
        <label class="field">
          <span class="lbl">Data aplicării</span>
          <span class="inp-wrap"><input type="date" data-bind="${path}.amenda.data" data-rerender="1" value="${esc(a.data)}"></span>
          <span class="hint">${a.data ? `<button class="link-btn" data-act="fine-date-default" data-key="${esc(n.key)}">Folosește data încheierii</button>` : `Implicit: data încheierii${fd ? ` (${fmtDate(fd)})` : ' — necompletată'}`}</span>
        </label>
        ${field('Sumă', `${path}.amenda.suma`, a.suma, { mode: 'decimal', unit: 'lei', ph: '0' })}
        <div class="field">
          <span class="lbl">Plată</span>
          ${toggle(`${path}.amenda.achitata`, a.achitata, 'Achitată – dovadă primită', { level: 'green' })}
        </div>
        ${a.achitata ? `<label class="field"><span class="lbl">Data dovezii de plată</span><span class="inp-wrap"><input type="date" data-bind="${path}.amenda.dataAchitare" data-rerender="1" value="${esc(a.dataAchitare)}"></span></label>` : ''}
      </div>
      ${fs.plataPana && !a.achitata ? `<div class="fine-timeline">
        <span class="${fs.level === 'blue' ? 'cur' : 'past'}"><i class="dot dot-blue"></i>Plată până la <b>${fmtDate(fs.plataPana)}</b>${fs.plataNelucr ? ` <em class="nelucr">(${esc(fs.plataNelucr)})</em>` : ''}</span>
        <span class="${fs.level === 'red' ? 'cur' : ''}"><i class="dot dot-red"></i>ANAF până la <b>${fmtDate(fs.anafPana)}</b>${fs.anafNelucr ? ` <em class="nelucr">(${esc(fs.anafNelucr)})</em>` : ''}</span>
      </div>` : ''}
      ${fs.nelucr && !a.achitata ? `<div class="nelucr-warn">${icon('alert')}<span>${esc(fs.nelucr)}</span></div>` : ''}
    </div>`;
  }
  const vi = vecheInfo(state.controls, c, n);
  const veche = vi.auto
    ? `<div class="veche-note">${icon('history')}<span><b>Neregulă veche</b> — constatată și la controlul din ${esc(fmtDate(vi.auto.dataInceput))} (din istoric)</span></div>`
    : toggle(`${path}.vecheManual`, n.vecheManual, 'Neregulă veche', { level: 'veche', ic: 'history' });
  return `<div class="ner-detail">
    <div class="detail-toggles">
      ${toggle(`${path}.inPV`, n.inPV, 'Trecut în procesul-verbal', { level: 'green', ic: 'pv', offLabel: 'Netrecut în procesul-verbal' })}
      ${toggle(`${path}.amenda.aplicata`, a.aplicata, 'Sancționat cu amendă', { level: 'blue', ic: 'fine' })}
      ${veche}
    </div>
    ${asi}${fine}
  </div>`;
}
