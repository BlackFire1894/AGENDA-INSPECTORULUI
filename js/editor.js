// Editorul unui control: 3 taburi — Obiectiv, Acte & evidențe, Nereguli.
import { state, today, historyState } from './state.js';
import { fmtDate, fmtDateLong, toISO } from './dates.js';
import {
  TIP_OBIECTIV, DOTARI, CENTRALA_TIPURI, ACTE, STRUCTURI, MATERIALE_PERETI, SECTIUNI, CATEGORII,
  controlStats, secStats, fineStatus, fineDate, asiDeadline, isIncheiat, neregulaLabel, neregulaLetter,
  neregulaCat, secOf, isApplicable, isLocalitate, constructiiOf, constructiiNume, matchNeregula, fold, amendaSerieNr, vecheInfo, todoList,
  LIPSA_DOTARI, isGrav, constructiiDeclansate, GRF_NIVELURI, grfVPesteParter, sablon, fmtCoord, googleMapsUrl, appleMapsUrl, gpsQuality,
  constructiiEligibile, isVerificare, verifStare, verifExpirate, ascunsaDeDotari,
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
      ${undoRedoHTML(c)}
      <button class="btn btn-ghost" data-act="pv-text">${icon('pv')} Text PV</button>
      <a class="btn btn-ghost" href="#/fisa/${c.id}">${icon('download')} Fișa PDF</a>
      <a class="btn btn-ghost" href="#/obiectiv/${c.objectiveId}">${icon('history')} Istoric</a>
      <button class="btn btn-ghost" data-act="backup-export" title="Backup rapid al tuturor controalelor">${icon('upload')} Backup</button>
      ${helpBtn('ctrl')}
      <button class="icon-btn big danger" data-act="control-delete" aria-label="Șterge controlul">${icon('trash')}</button>
    </div>`;
}

// Anulează / Refă: activate doar când există pași; se actualizează singure după fiecare modificare
export function undoRedoHTML(c) {
  const h = historyState(c.id);
  return `<span class="undo-redo" id="undo-redo">
    <button class="icon-btn big" data-act="undo" ${h.undo ? '' : 'disabled'} aria-label="Anulează ultima modificare" title="Anulează">${icon('undo')}</button>
    <button class="icon-btn big" data-act="redo" ${h.redo ? '' : 'disabled'} aria-label="Refă" title="Refă">${icon('redo')}</button>
  </span>`;
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

// Neregulile grave: construcțiile care le declanșează (NU la dotare / GRF-NSI V peste parter), actualizate singure
function constrNU(c, n) {
  const t = sablon(n.key);
  const list = constructiiDeclansate(c, t) || [];
  if (!list.length) return '';
  const cum = t.reqGrfV ? 'GRF/NSI V peste parter în' : 'NU la dotări în';
  return `<span class="constr-nu">${icon('building')} ${cum}: <b>${list.map((k) => esc(k.denumire) + (t.reqGrfV && k.regimInaltime ? ` (${esc(k.regimInaltime)})` : '')).join(', ')}</b></span>`;
}

// GRF / NSI al construcției: I–V sau „Nu e necesar”; V cu regim peste parter = neregulă gravă
export function grfBlock(c, k, p = `constructii.#${k.id}`) {
  const grav = grfVPesteParter(k);
  const opts = [...GRF_NIVELURI.map((v) => [v, v]), ['NN', 'Nu e necesar']];
  return `<div class="grf-field ${grav ? 'is-grav' : ''}" id="grf-${k.id}">
    <span class="lbl">GRF / NSI <small>grad de rezistență la foc / nivel de stabilitate la incendiu</small></span>
    <div class="chips-sel grf-opts" role="radiogroup" aria-label="GRF / NSI">
      ${opts.map(([v, l]) => `<button type="button" class="chip-sel ${k.grf === v ? 'on' : ''} ${v === 'NN' ? 'grf-nn' : ''}" data-act="set" data-toggle="1" data-path="${p}.grf" data-val="${v}" role="radio" aria-checked="${k.grf === v}">${l}</button>`).join('')}
    </div>
    ${grav ? `<div class="grav-note">${icon('alert')}<span><b>Neregulă gravă:</b> GRF/NSI V cu regim de înălțime ${esc(k.regimInaltime)} (peste parter). Apare în tabul Nereguli.</span>
      <a class="btn btn-ghost" href="#/control/${c.id}/nereguli/grav-grfV">Vezi</a></div>` : ''}
  </div>`;
}

// Data ultimei verificări, pe fiecare construcție relevantă; expirarea se calculează față de data controlului
function verifBlock(c, n) {
  const t = sablon(n.key);
  const list = constructiiEligibile(c, n);
  const exp = verifExpirate(c, n);
  const rows = list.map((k) => {
    const s = verifStare(c, n, k);
    const stare = s.stare === 'lipsa' ? '<span class="vf-st vf-lipsa">fără dată</span>'
      : s.stare === 'expirata' ? `<span class="vf-st vf-exp">${icon('alert')} expirată din ${esc(fmtDate(s.expira))}</span>`
        : `<span class="vf-st vf-ok">${icon('check')} valabilă până la ${esc(fmtDate(s.expira))}</span>`;
    return `<div class="vf-row ${s.stare === 'expirata' ? 'is-exp' : ''}">
      <span class="vf-name">${icon('building')} ${esc(k.denumire || 'Construcție')}</span>
      <span class="inp-wrap vf-date"><input type="date" data-verif="${esc(n.key)}|${k.id}|data" value="${esc(s.data)}" aria-label="Data ultimei verificări – ${esc(k.denumire)}"></span>
      ${t.verifAlegeri ? `<div class="segmented vf-luni" role="radiogroup" aria-label="Periodicitate">${t.verifAlegeri.map((l) => `<button type="button" class="${s.luni === l ? 'on' : ''}" data-act="verif-luni" data-key="${esc(n.key)}" data-id="${k.id}" data-val="${l}" role="radio" aria-checked="${s.luni === l}">${l} luni</button>`).join('')}</div>` : ''}
      ${stare}
    </div>`;
  }).join('');
  return `<div class="verif-block">
    <span class="lbl">Data ultimei verificări${t.verifAlegeri ? '' : ` · valabilă ${t.verif} luni`}</span>
    ${rows}
    ${exp.length && n.status !== 'nok' ? `<div class="vf-propune">${icon('alert')}<span>Verificare expirată: <b>${esc(exp.map((k) => k.denumire).join(', '))}</b>. Constatați neregula?</span>
      <button class="btn btn-ghost" data-act="verif-nok" data-key="${esc(n.key)}">${icon('x')} Constatat pentru ${exp.length === 1 ? 'aceasta' : `cele ${exp.length}`}</button></div>` : ''}
  </div>`;
}

// „hidranți interiori”, „centrală termică” … — instalația de care ține un rând
function instalatiaText(n) {
  const req = sablon(n.key)?.req || [];
  return req.map((r) => (DOTARI.find((d) => d.key === r)?.label || r).toLowerCase()).join(' / ');
}

// Construcțiile în care s-a făcut constatarea: meniu cu selecție multiplă (implicit prima construcție)
function constrSelect(c, n) {
  const sel = constructiiOf(c, n);
  if (!sel.length) return '';
  const multe = constructiiEligibile(c, n).length > 1 || sel.length > 1;
  const open = multe && state.ui.constrPick === n.key;
  const ids = new Set(sel.map((k) => k.id));
  // în meniu: doar construcțiile care au instalația rândului (plus cele deja alese, ca să poată fi debifate)
  const elig = new Set(constructiiEligibile(c, n).map((k) => k.id));
  const opts = c.constructii.filter((k) => elig.has(k.id) || ids.has(k.id));
  const all = opts.every((k) => ids.has(k.id));
  return `<div class="constr-sel ${open ? 'open' : ''}">
    <button type="button" class="constr-sel-btn" data-act="constr-pick" data-key="${esc(n.key)}" aria-expanded="${open}" ${multe ? '' : 'disabled'} aria-label="Construcțiile în care s-a făcut constatarea">
      ${icon('building')}<span class="constr-sel-lbl">${sel.length > 1 ? `Construcțiile (${sel.length})` : 'Construcția'}</span>
      <span class="constr-sel-val">${esc(constructiiNume(c, n))}</span>
      ${multe ? icon('chevD', open ? 'rot' : '') : ''}
    </button>
    ${open ? `<div class="constr-pick" role="group" aria-label="Alegeți una sau mai multe construcții">
      ${opts.map((k) => { const i = c.constructii.indexOf(k); return `<button type="button" class="constr-opt ${ids.has(k.id) ? 'on' : ''}" data-act="constr-opt" data-key="${esc(n.key)}" data-id="${k.id}" aria-pressed="${ids.has(k.id)}">
        <span class="cbox">${ids.has(k.id) ? icon('check') : ''}</span><span>${i + 1}. ${esc(k.denumire || `Construcția ${i + 1}`)}</span></button>`; }).join('')}
      ${opts.length < c.constructii.length ? `<p class="constr-pick-note">${icon('info')} Doar construcțiile cu ${esc(instalatiaText(n))} bifat DA în fișă.</p>` : ''}
      <div class="constr-pick-foot">
        <button type="button" class="btn btn-ghost" data-act="constr-opt-all" data-key="${esc(n.key)}" ${all ? 'disabled' : ''}>${icon('check')} Toate construcțiile</button>
        <button type="button" class="btn btn-primary" data-act="constr-pick" data-key="${esc(n.key)}">Gata</button>
      </div>
    </div>` : ''}
  </div>`;
}

function field(label, path, value, { type = 'text', ph = '', list = '', mode = '', unit = '', wide = false, live = '', grav } = {}) {
  return `<label class="field ${wide ? 'wide' : ''}">
    <span class="lbl">${esc(label)}</span>
    <span class="inp-wrap">
      <input type="${type}" data-bind="${path}" value="${esc(value)}" placeholder="${esc(ph)}" ${list ? `list="${list}"` : ''} ${mode ? `inputmode="${mode}"` : ''} ${live ? `data-live-src="${live}"` : ''} ${grav !== undefined ? `data-grav="${grav ? 1 : 0}"` : ''} autocomplete="off">
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
      ${field('Adresă', 'adresa', c.adresa, { ph: 'Strada, nr., bloc…' })}
      ${field('Localitate', 'localitate', c.localitate, { ph: 'ex: Cluj-Napoca' })}
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

// Coordonate GPS pe construcție: preluate doar la cerere (o atingere), cu precizia afișată și legături spre hărți
function gpsBlock(c, k, i) {
  const g = k.gps;
  const busy = state.ui.gpsBusy === k.id;
  const numeHarta = [c.denumire, k.denumire || `Construcția ${i + 1}`].filter(Boolean).join(' – ');
  if (!g) {
    return `<div class="gps-field" id="gps-${k.id}">
      <span class="lbl">Coordonate GPS</span>
      <div class="gps-empty">
        <span class="gps-cell is-empty">Necompletat</span>
        <button class="btn btn-primary btn-lg" data-act="gps-get" data-id="${k.id}" ${busy ? 'disabled' : ''}>${icon('locate')} ${busy ? 'Se caută semnalul…' : 'Completează coordonatele'}</button>
      </div>
      <span class="hint">Doar la cerere: poziția se citește o singură dată, când apăsați, lângă această construcție. Nu se urmărește locația.</span>
    </div>`;
  }
  const q = gpsQuality(g.acc);
  const la = g.la ? new Date(g.la) : null;
  return `<div class="gps-field" id="gps-${k.id}">
    <span class="lbl">Coordonate GPS</span>
    <div class="gps-box">
      <div class="gps-main">
        <b class="gps-coord gps-cell">${esc(fmtCoord(g))}</b>
        <span class="gps-meta"><span class="gps-q q-${q}">± ${Math.round(g.acc)} m · precizie ${q === 'buna' ? 'bună' : q === 'medie' ? 'medie' : 'slabă'}</span>${la ? ` · preluate ${esc(fmtDate(toISO(la)))}, ${String(la.getHours()).padStart(2, '0')}:${String(la.getMinutes()).padStart(2, '0')}` : ''}</span>
        ${q === 'slaba' ? `<span class="gps-warn">${icon('alert')} Precizie slabă: ieșiți în aer liber sau lângă o fereastră și apăsați „Actualizează”.</span>` : ''}
      </div>
      <div class="gps-actions">
        <a class="btn btn-ghost" href="${esc(googleMapsUrl(g))}" target="_blank" rel="noopener">${icon('pin')} Google Maps</a>
        <a class="btn btn-ghost" href="${esc(appleMapsUrl(g, numeHarta))}" target="_blank" rel="noopener">${icon('pin')} Hărți Apple</a>
        <button class="btn btn-ghost" data-act="gps-copy" data-id="${k.id}">${icon('doc')} Copiază</button>
        <button class="btn btn-ghost" data-act="gps-get" data-id="${k.id}" ${busy ? 'disabled' : ''}>${icon('history')} ${busy ? 'Se caută…' : 'Actualizează'}</button>
        <button class="icon-btn danger" data-act="gps-clear" data-id="${k.id}" aria-label="Șterge coordonatele">${icon('trash')}</button>
      </div>
    </div>
  </div>`;
}

function isOpen(c, k, i) {
  const u = state.ui;
  if (u.collapsed.has(k.id)) return false;
  if (u.expanded.has(k.id)) return true;
  return c.constructii.length === 1 || i === 0;
}

function dotariSummary(k) {
  let da = 0, nec = 0, set = 0, lipsa = 0;
  for (const d of DOTARI) {
    const v = k.dotari[d.key];
    if (d.centrala) { if (v.tipuri.length || v.nuAre) set++; continue; }
    if (v.v) set++;
    if (v.v === 'DA') da++;
    if (v.v === 'NEC') nec++;
    if (v.v === 'NU' && LIPSA_DOTARI.includes(d.key)) lipsa++;
  }
  return { da, nec, set, lipsa, total: DOTARI.length };
}

function constructieHTML(c, k, i) {
  const open = isOpen(c, k, i);
  const p = `constructii.#${k.id}`;
  const s = dotariSummary(k);
  return `<article class="constr ${open ? 'open' : ''}">
    <div class="constr-head">
      <span class="constr-num">${i + 1}</span>
      <input class="constr-name" data-bind="${p}.denumire" value="${esc(k.denumire)}" placeholder="Denumirea construcției ${i + 1}" autocomplete="off">
      ${s.lipsa ? `<span class="pill pill-red">${icon('alert')}${s.lipsa} ${s.lipsa === 1 ? 'instalație lipsă' : 'instalații lipsă'}</span>` : ''}
      <span class="pill pill-red" id="grf-pill-${k.id}" ${grfVPesteParter(k) ? '' : 'hidden'}>${icon('alert')}GRF/NSI V peste parter</span>
      <span class="constr-sum">${s.set}/${s.total} dotări${k.suprafata ? ` · ${esc(k.suprafata)} m²` : ''}${k.regimInaltime ? ` · ${esc(k.regimInaltime)}` : ''}${k.grf ? ` · ${k.grf === 'NN' ? 'GRF/NSI nu e necesar' : `GRF/NSI ${k.grf}`}` : ''}${k.gps ? ' · GPS ✓' : ''}</span>
      <button class="icon-btn" data-act="constr-toggle" data-id="${k.id}" aria-label="${open ? 'Restrânge' : 'Extinde'}">${icon('chevD', open ? 'rot' : '')}</button>
    </div>
    ${open ? `<div class="constr-body">
      <div class="form-grid g3">
        ${field('Suprafață desfășurată', `${p}.suprafata`, k.suprafata, { mode: 'decimal', unit: 'm²', ph: '0' })}
        ${field('Regim de înălțime', `${p}.regimInaltime`, k.regimInaltime, { ph: 'ex: S+P+2E', grav: grfVPesteParter(k) })}
        ${field('Nr. angajați', `${p}.nrAngajati`, k.nrAngajati, { mode: 'numeric', ph: '0' })}
        ${field('Anul construirii', `${p}.anConstruire`, k.anConstruire, { mode: 'numeric', ph: 'ex: 1978' })}
        ${field('Structura de rezistență', `${p}.structura`, k.structura, { list: 'dl-structura', ph: 'Alege sau scrie' })}
        ${field('Material pereți', `${p}.materialPereti`, k.materialPereti, { list: 'dl-pereti', ph: 'Alege sau scrie' })}
      </div>
      ${grfBlock(c, k, p)}
      ${gpsBlock(c, k, i)}
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
  const grav = v.v === 'NU' && LIPSA_DOTARI.includes(d.key);
  return `<div class="dot-row ${grav ? 'is-grav' : ''}">
    <span class="dot-label">${esc(d.label)}${grav ? `<small class="grav-note">${icon('alert')} Neregulă gravă</small>` : ''}</span>
    ${segBtns(`${path}.v`, v.v, d.opts, 'seg-dnn')}
    ${obsField(`${path}.obs`, v.obs, 'dot-obs')}
    ${d.nr && v.v === 'DA' ? `<label class="dot-nr"><span class="lbl">${esc(d.nr)}</span><span class="inp-wrap"><input data-bind="${path}.nr" value="${esc(v.nr || '')}" placeholder="ex: 1234 din 12.05.2019" autocomplete="off"></span></label>` : ''}
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

function okNok(path, status, okLabel, nokLabel, { nec = false } = {}) {
  return `<div class="oknok ${nec ? 'has-nec' : ''}">
    <button type="button" class="ok-btn ${status === 'ok' ? 'on' : ''}" data-act="set" data-path="${path}.status" data-val="ok" data-toggle="1" aria-pressed="${status === 'ok'}">${icon('check')}<span>${okLabel}</span></button>
    <button type="button" class="nok-btn ${status === 'nok' ? 'on' : ''}" data-act="set" data-path="${path}.status" data-val="nok" data-toggle="1" aria-pressed="${status === 'nok'}">${icon('x')}<span>${nokLabel}</span></button>
    ${nec ? `<button type="button" class="nec-btn ${status === 'nec' ? 'on' : ''}" data-act="set" data-path="${path}.status" data-val="nec" data-toggle="1" aria-pressed="${status === 'nec'}" aria-label="NEC – nu este cazul"><b>NEC</b><span>nu e cazul</span></button>` : ''}
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

// Rândurile unei secțiuni, grupate pe categorii, cu filtrul și căutarea aplicate
function sectionRows(c, sec) {
  const f = state.ui.nerFilter;
  const q = state.ui.nerQuery.trim();
  const showAll = state.ui.showAllNer;
  const rows = c.nereguli.filter((n) => secOf(n) === sec);
  const tmpl = rows.filter((n) => !n.custom && (isApplicable(c, n) || (showAll && ascunsaDeDotari(c, n))));
  const custom = rows.filter((n) => n.custom);
  const show = (n) => (f === 'ALL' || (f === 'NOK' ? n.status === 'nok' : !n.status)) && matchNeregula(c, n, q);
  const groups = [];
  for (const n of tmpl) {
    const cat = neregulaCat(n);
    let g = groups.find((x) => x.cat === cat);
    if (!g) { g = { cat, rows: [] }; groups.push(g); }
    g.rows.push(n);
  }
  // rânduri care s-ar potrivi, dar sunt ascunse (instalații nebifate DA la dotări)
  const ascunse = q && !showAll ? rows.filter((n) => ascunsaDeDotari(c, n) && matchNeregula(c, n, q)).length : 0;
  return { f, q, groups, custom, show, ascunse };
}

// „✓ Completat” sau „N necompletate” în bara unei categorii
function stareCat(rest) {
  return rest
    ? `<span class="cat-stare st-rest">${rest} ${rest === 1 ? 'necompletată' : 'necompletate'}</span>`
    : `<span class="cat-stare st-gata">${icon('check')} Completat</span>`;
}

// Lista de rânduri (se redesenează singură la căutare, ca bara de căutare să rămână activă)
export function nerResultsHTML(c, sec) {
  const ui = SEC_UI[sec];
  const { f, q, groups, custom, show, ascunse } = sectionRows(c, sec);
  const adapostHit = !q || (q.length >= 3 && fold('adapost de protectie civila').includes(fold(q)));
  let found = 0;
  let body = groups.map((g) => {
    const vis = g.rows.filter(show);
    const adapost = sec === 'pc' && g.cat === 'pcdotare' && adapostHit && (f === 'ALL' || (f === 'TODO' && !c.adapostPC.v)) ? adapostRow(c) : '';
    if (!vis.length && !adapost) return '';
    found += vis.length + (adapost ? 1 : 0);
    const nok = g.rows.filter((n) => n.status === 'nok').length;
    const closed = !q && state.ui.catCollapsed.has(g.cat);
    const nRows = vis.length + (adapost ? 1 : 0);
    // completat / necompletat: toată categoria, indiferent de filtru sau căutare
    const rest = g.rows.filter((n) => !n.status).length + (sec === 'pc' && g.cat === 'pcdotare' && !c.adapostPC.v ? 1 : 0);
    return `<div class="cat-group cat-${g.cat} ${closed ? 'closed' : ''}">
      <button type="button" class="cat-title" data-act="cat-toggle" data-cat="${g.cat}" aria-expanded="${!closed}" ${q ? 'disabled' : ''}>
        ${icon('chevD', closed ? '' : 'rot')}<span class="cat-name">${esc(CATEGORII[g.cat])}</span>
        <span class="cat-meta">${nRows} ${nRows === 1 ? 'rând' : 'rânduri'}</span>
        ${stareCat(rest)}
        ${nok ? `<span class="cat-count">${nok} ${nokWord(sec, nok)}</span>` : ''}
      </button>
      ${closed ? '' : `<div class="check-list">${vis.map((n) => neregulaRow(c, n)).join('')}${adapost}</div>`}
    </div>`;
  }).join('');
  const customVis = custom.filter(show);
  found += customVis.length;
  const fName = f === 'NOK' ? `„${ui.nokWord}”` : '„Neverificate”';
  if (!body) {
    body = q
      ? `<p class="muted pad">Nicio potrivire${customVis.length ? ' în listă (vezi rândurile adăugate, mai jos)' : ''}${f !== 'ALL' ? ` în filtrul ${fName}` : ''}.</p>`
      : '<p class="muted pad">Nimic de afișat pentru acest filtru.</p>';
  }
  const note = q ? `<div class="search-result ${found ? '' : 'none'}">${icon('search')}<span>${found
    ? `<b>${found}</b> ${found === 1 ? 'rând găsit' : 'rânduri găsite'} pentru „${esc(q)}”`
    : `Niciun rând pentru „${esc(q)}”`}${f !== 'ALL' ? ` · filtrul ${fName}` : ''}</span>
    ${f !== 'ALL' ? '<button class="btn btn-ghost" data-act="ner-filter" data-val="ALL">Caută în toate</button>' : ''}
    ${ascunse ? `<button class="btn btn-ghost" data-act="toggle-all-ner">+${ascunse} ${ascunse === 1 ? 'ascunsă' : 'ascunse'} · Arată toate</button>` : ''}
  </div>` : '';
  return `${note}
    <section class="card">
      <h2 class="sec-title">${icon(ui.ic)} ${ui.title}</h2>
      ${body}
    </section>
    <section class="card">
      ${(() => {
        const ck = `custom-${sec}`;
        const closed = !q && custom.length > 0 && state.ui.catCollapsed.has(ck);
        const nokC = custom.filter((n) => n.status === 'nok').length;
        return `<div class="sec-title-row">
        <button type="button" class="sec-title custom-toggle" data-act="cat-toggle" data-cat="${ck}" aria-expanded="${!closed}" ${custom.length && !q ? '' : 'disabled'}>
          ${custom.length ? icon('chevD', closed ? '' : 'rot') : icon('plus')} ${ui.addTitle}
          ${custom.length ? `<span class="cat-meta">${custom.length} ${custom.length === 1 ? 'rând' : 'rânduri'}${closed && nokC ? ` · ${nokC} ${nokWord(sec, nokC)}` : ''}</span>${stareCat(custom.filter((n) => !n.status).length)}` : ''}
        </button>
        <button class="btn btn-primary" data-act="ner-add" data-sec="${sec}">${icon('plus')} Adaugă rând</button>
      </div>
      ${closed ? '' : `<div class="cat-group cat-custom"><div class="check-list">${customVis.map((n) => neregulaRow(c, n)).join('') || `<p class="muted pad">${q && custom.length ? 'Niciun rând adăugat nu se potrivește căutării.' : ui.empty}</p>`}</div></div>`}`;
      })()}
    </section>`;
}

function tabSectiune(c, sec) {
  const ui = SEC_UI[sec];
  const st = secStats(c, sec, today());
  const { f, q, groups } = sectionRows(c, sec);
  const showAll = state.ui.showAllNer;
  const inPV = st.constatate - st.netrecute;
  const anyFineOrAsi = st.fines.length || (sec === 'ner' && asiDeadline(c, today()));

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
    <div class="searchbar ner-search">
      ${icon('search')}
      <input type="search" id="ner-search" data-sec="${sec}" value="${esc(state.ui.nerQuery)}" placeholder="Caută: literă (d, G1) sau text (ex. hidranți, gaz)" autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="search" aria-label="Caută în ${esc(ui.title.toLowerCase())}">
      <button class="icon-btn" data-act="ner-q-clear" aria-label="Șterge căutarea">${icon('x')}</button>
    </div>
    <div class="toolbar">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['NOK', `${ui.nokWord[0].toUpperCase()}${ui.nokWord.slice(1)} (${st.constatate})`], ['TODO', `Neverificate (${st.total - st.checked})`]].map(([k, l]) => `<button class="${f === k ? 'on' : ''}" data-act="ner-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
      <div class="tool-btns">
        ${(() => { const all = groups.length && groups.every((g) => state.ui.catCollapsed.has(g.cat)); return `<button class="btn btn-ghost" data-act="cats-all" data-val="${all ? 'open' : 'close'}" ${q ? 'hidden' : ''}>${icon(all ? 'chevD' : 'list')} ${all ? 'Extinde categoriile' : 'Restrânge categoriile'}</button>`; })()}
        ${obsToggleBtn()}
        ${restBtn(c.nereguli.filter((n) => secOf(n) === sec && !n.status && !sablon(n.key)?.grav && (isApplicable(c, n) || (showAll && ascunsaDeDotari(c, n)))).length, sec, sec === 'ner' ? 'Restul conform' : 'Restul conforme')}
      </div>
    </div>
    <div id="ner-results">${nerResultsHTML(c, sec)}</div>`;
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
  if (n.status === 'nok' && n.auto) chips.unshift(pill('neutral', `Din fișa obiectivului: NU la ${DOTARI.find((d) => d.key === sablon(n.key)?.autoNU)?.label || ''}`, 'building'));
  if (n.status === 'nok' && n.custom && n.grav) chips.unshift(pill('red', 'Neregulă gravă', 'alert'));
  if (n.status === 'nok' && isGrav(n) && n.sigiliu) chips.unshift(pill('red', 'Sigiliu', 'lock'));
  const vi = vecheInfo(state.controls, c, n);
  if (vi.veche) chips.unshift(`<span class="pill pill-veche">${icon('history')}Neregulă veche</span>`);
  else if (n.status !== 'nok' && vi.auto) chips.push(pill('neutral', `Constatată la controlul din ${fmtDate(vi.auto.dataInceput)}`, 'history'));
  if (!n.custom && !isApplicable(c, { ...n, status: '' })) {
    const t = sablon(n.key);
    chips.push(pill('neutral', t?.reqNU ? 'Nu mai e marcată NU la dotări' : t?.reqGrfV ? 'Nu mai e GRF/NSI V peste parter' : 'Instalație nebifată DA la dotări', 'info'));
  }
  return `<div class="check-row ner-row ${n.status ? `is-${n.status}` : ''} ${vi.veche && n.status !== 'nec' ? 'is-veche' : ''} ${n.custom && n.grav ? 'is-grav-custom' : ''}" id="ner-${esc(n.key)}">
    <span class="row-idx letter">${esc(letter)}</span>
    <div class="row-main">
      ${labelHTML}
      ${chips.length ? `<span class="chips">${chips.join('')}</span>` : ''}
      ${isVerificare(n) && n.status !== 'nec' ? verifBlock(c, n) : ''}
      ${sablon(n.key)?.grav ? constrNU(c, n) : ((n.sec === 'ner' || !n.sec) && n.status !== 'nec' ? constrSelect(c, n) : '')}
      ${obsField(`${path}.obs`, n.obs)}
    </div>
    <div class="row-side">
      ${okNok(path, n.status, sec.ok, sec.nok, { nec: !sablon(n.key)?.grav || n.custom })}
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
      ${n.custom ? toggle(`${path}.grav`, n.grav, 'Neregulă gravă', { level: 'red', ic: 'alert' }) : ''}
      ${isGrav(n) ? toggle(`${path}.sigiliu`, n.sigiliu, 'Sigiliu', { level: 'red', ic: 'lock' }) : ''}
    </div>
    ${asi}${fine}
  </div>`;
}
