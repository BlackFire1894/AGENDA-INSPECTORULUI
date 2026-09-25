// Editorul unui control: 3 taburi — Obiectiv, Acte & evidențe, Nereguli.
import { state, today, historyState } from './state.js';
import { fmtDate, fmtDateLong, toISO } from './dates.js';
import {
  TIP_OBIECTIV, DOTARI, CENTRALA_TIPURI, ACTE, STRUCTURI, MATERIALE_PERETI, SECTIUNI, CATEGORII,
  controlStats, secStats, fineStatus, fineDate, asiDeadline, isIncheiat, neregulaLabel, neregulaLetter,
  neregulaCat, secOf, isApplicable, isLocalitate, constructiiOf, constructiiNume, matchNeregula, fold, amendaSerieNr, vecheInfo, todoList,
  LIPSA_DOTARI, isGrav, constructiiDeclansate, GRF_NIVELURI, grfVPesteParter, sablon, fmtCoord, googleMapsUrl, appleMapsUrl, gpsQuality,
  constructiiEligibile, isVerificare, verifStare, verifExpirate, ascunsaDeDotari, matchAct,
} from './model.js';
import { icon, esc, pill, finePill, tipBadge } from './ui.js';

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
      <button class="icon-btn big danger" data-act="control-delete" aria-label="Șterge controlul">${icon('trash')}</button>
    </div>`;
}

// Anulează / Sus / Refă: mereu la îndemână (banda de deasupra barei de jos pe vertical, bara laterală pe orizontal),
// într-o zonă separată de conținut, ca să nu fie atinse din greșeală.
export function editToolsHTML(c) {
  const h = historyState(c.id);
  return `<button class="et-btn" data-act="undo" ${h.undo ? '' : 'disabled'} aria-label="Anulează ultima modificare">${icon('undo')}<span>Anulează</span></button>
    <button class="et-btn et-top" data-act="scroll-top" aria-label="Înapoi sus">${icon('up')}<span>Sus</span></button>
    <button class="et-btn" data-act="redo" ${h.redo ? '' : 'disabled'} aria-label="Refă">${icon('redo')}<span>Refă</span></button>`;
}

// „Ce mai aveți de făcut”: pasul următor, cu acces direct; lista completă se deschide la cerere.
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
      <span class="todo-title">${icon('list')} Ce mai aveți de făcut <b>${items.length}</b></span>
      ${open ? '' : btn(items[0])}
      ${items.length > 1 || open ? `<button class="todo-more" data-act="todo-toggle">${open ? 'Ascunde lista' : `Toate (${items.length})`}</button>` : ''}
    </div>
    ${open ? `<div class="todo-list">${items.map(btn).join('')}</div>` : ''}
  </div>`;
}

export function edTabsHTML(c, tab) {
  const st = controlStats(c, today());
  const tabs = tabsFor(c);
  // starea tabului, în cuvinte (portocaliu: acte lipsă / constatări netrecute în PV)
  const badge = (t) => {
    if (t.key === 'obiectiv') return [`${c.constructii.length} ${c.constructii.length === 1 ? 'construcție' : 'construcții'}`, false];
    if (t.key === 'acte') return [`${st.acteNok} lipsă`, st.acteNok > 0];
    const s2 = secStats(c, t.sec, today());
    if (!s2.constatate) return [`0 ${nokWord(t.sec, 0)}`, false];
    return [`${s2.constatate} ${nokWord(t.sec, s2.constatate)}${s2.netrecute ? ` · ${s2.netrecute} ${s2.netrecute === 1 ? 'netrecută' : 'netrecute'} în PV` : ''}`, s2.netrecute > 0];
  };
  // cât din tab e completat, scris lângă bară: dotările (Obiectiv), actele, rândurile verificate (secțiunile)
  const progres = (t) => {
    if (t.key === 'obiectiv') {
      const s = c.constructii.map(dotariSummary).reduce((a, x) => ({ set: a.set + x.set, total: a.total + x.total }), { set: 0, total: 0 });
      return ['Dotări', s.set, s.total];
    }
    if (t.key === 'acte') return ['Verificate', st.acteDone, st.acteTotal];
    const s2 = secStats(c, t.sec, today());
    return ['Verificate', s2.checked, s2.total];
  };
  return tabs.map((t, i) => {
    const [txt, warn] = badge(t);
    const [ce, gata, total] = progres(t);
    const pr = total ? Math.round((gata / total) * 100) : 0;
    return `<a class="ed-tab ${t.key === tab ? 'on' : ''}" href="#/control/${c.id}/${t.key}" ${t.key === tab ? 'aria-current="page"' : ''}>
      <span class="tab-num">${i + 1}</span>
      <span class="tab-txt"><b>${t.label}</b><small class="${warn ? 'warn' : ''}">${esc(txt)}</small><small class="tab-prog-txt ${gata === total && total ? 'done' : ''}">${ce} <b>${gata}/${total}</b></small></span>
      <span class="tab-prog ${gata === total && total ? 'done' : ''}" aria-hidden="true"><i style="width:${pr}%"></i></span>
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
let curControlId = '';
export const obsKey = (path) => `${curControlId}|${path}`;
// Observațiile completate se văd mereu; cele goale sunt un buton mic „+ Obs.” (se deschid la atingere).
// La un rând constatat (✗), câmpul e deschis din start — fără focus, deci fără tastatură.
function obsField(path, value, cls = 'row-obs', deschis = false) {
  if (!deschis && !String(value || '').trim() && !state.ui.obsOpen.has(obsKey(path))) {
    return `<button type="button" class="obs-add" data-act="obs-open" data-path="${path}" aria-label="Adaugă observații">${icon('plus')} Obs.</button>`;
  }
  return `<div class="obs-wrap">
    <textarea class="obs ${cls}" data-bind="${path}" data-obs="1" rows="1" placeholder="Observații" autocomplete="off" enterkeyhint="enter">${esc(value)}</textarea>
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
      : s.stare === 'expirata' ? `<span class="vf-st vf-exp">${icon('alert')} expirată — era valabilă până la ${esc(fmtDate(s.expira))}</span>`
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
        <span class="hint">Se completează implicit cu data începerii; o puteți modifica după.</span>
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
  return `<article class="constr ${open ? 'open' : ''}" id="constr-${k.id}">
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
        ${field('Structura de rezistență', `${p}.structura`, k.structura, { list: 'dl-structura', ph: 'Alegeți sau scrieți' })}
        ${field('Material pereți', `${p}.materialPereti`, k.materialPereti, { list: 'dl-pereti', ph: 'Alegeți sau scrieți' })}
      </div>
      ${grfBlock(c, k, p)}
      ${gpsBlock(c, k, i)}
      <div class="mini-row"><h3 class="mini-title">Dotări și instalații <small>NEC = nu este cazul</small></h3></div>
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

// ───────── Acte: același comportament ca la nereguli (căutare, filtru, bare cu informații, rânduri restrângibile) ─────────
const actKey = (c, key) => `${c.id}|act:${key}`;
const ACT_SEC = { ok: 'Prezentat', nok: 'Lipsă' };

function actRow(c, a, i) {
  const v = c.acte[a.key];
  const path = `acte.${a.key}`;
  const collapsed = state.ui.rowCollapsed.has(actKey(c, a.key));
  const pill0 = collapsed ? (v.status === 'ok' ? pill('green', ACT_SEC.ok, 'check') : v.status === 'nok' ? pill('red', ACT_SEC.nok, 'x')
    : v.status === 'nec' ? pill('neutral', 'NEC') : '<span class="pill pill-todo">Necompletat</span>') : '';
  const obsPill = collapsed && v.obs?.trim() ? pill('neutral', 'Are observații', 'doc') : '';
  const obsGol = !String(v.obs || '').trim() && !state.ui.obsOpen.has(obsKey(`${path}.obs`)) && v.status !== 'nok';
  const tgl = `data-act="row-toggle" data-key="act:${a.key}"`;
  return `<div class="check-row ner-row act-row ${v.status ? `is-${v.status}` : ''} ${collapsed ? 'is-collapsed' : ''}" id="act-${a.key}">
    <div class="ner-bar">
      <span class="row-idx">${i + 1}</span>
      <div class="bar-main" ${tgl}>
        <span class="row-label">${esc(a.label)}</span>
        ${pill0 || obsPill || (obsGol && !collapsed) ? `<span class="chips">${pill0}${obsPill}${obsGol && !collapsed ? obsField(`${path}.obs`, '') : ''}</span>` : ''}
      </div>
      ${collapsed ? '' : okNok(path, v.status, ACT_SEC.ok, ACT_SEC.nok, { nec: true })}
      <button type="button" class="icon-btn row-tgl" ${tgl} aria-expanded="${!collapsed}" aria-label="${collapsed ? 'Deschide' : 'Restrânge'} actul ${i + 1}">${icon('chevD', collapsed ? '' : 'rot')}</button>
    </div>
    ${collapsed || obsGol ? '' : `<div class="row-main">${obsField(`${path}.obs`, v.obs, 'row-obs', v.status === 'nok')}</div>`}
  </div>`;
}

// Lista actelor (se redesenează singură la căutare)
function acteResultsHTML(c) {
  const f = state.ui.nerFilter;
  const q = state.ui.nerQuery.trim();
  const toate = ACTE.map((a, i) => ({ a, i, v: c.acte[a.key] }));
  const vis = toate.filter(({ a, v }) => (f === 'ALL' || (f === 'NOK' ? v.status === 'nok' : !v.status)) && matchAct(c, a.key, q));
  const closed = !q && state.ui.catCollapsed.has('acte');
  const gol = toate.filter(({ v }) => !v.status);
  const lipsa = toate.filter(({ v }) => v.status === 'nok');
  const nr = (arr) => (arr.length > 8 ? `${arr.slice(0, 8).map((x) => x.i + 1).join(', ')} +${arr.length - 8}` : arr.map((x) => x.i + 1).join(', '));
  const note = q ? `<div class="search-result ${vis.length ? '' : 'none'}">${icon('search')}<span>${vis.length
    ? `<b>${vis.length}</b> ${vis.length === 1 ? 'act găsit' : 'acte găsite'} pentru „${esc(q)}”` : `Niciun act pentru „${esc(q)}”`}</span>
    ${f !== 'ALL' ? '<button class="btn btn-ghost" data-act="ner-filter" data-val="ALL">Caută în toate</button>' : ''}</div>` : '';
  return `${note}<section class="card">
    <div class="cat-group cat-acte ${closed ? 'closed' : ''}">
      <button type="button" class="cat-title" data-act="cat-toggle" data-cat="acte" aria-expanded="${!closed}" ${q ? 'disabled' : ''}>
        ${icon('chevD', closed ? '' : 'rot')}<span class="cat-name">Acte de autoritate și evidențe</span>
        <span class="cat-meta">${vis.length} ${vis.length === 1 ? 'act' : 'acte'}</span>
        <span class="cat-info">${gol.length
    ? (closed ? `<span class="cat-stare st-rest">${gol.length} ${gol.length === 1 ? 'necompletat' : 'necompletate'}: ${nr(gol)}</span>` : `<span class="cat-stare st-rest">${gol.length} necompl.</span>`)
    : `<span class="cat-stare st-gata">${icon('check')} Completat</span>`}
          ${lipsa.length ? (closed ? `<span class="cat-count">${lipsa.length} lipsă: ${nr(lipsa)}</span>` : `<span class="cat-count">${lipsa.length} lipsă</span>`) : ''}</span>
      </button>
      ${closed ? '' : `<div class="check-list">${vis.map(({ a, i }) => actRow(c, a, i)).join('') || '<p class="muted pad">Nimic de afișat pentru acest filtru.</p>'}</div>`}
    </div>
  </section>`;
}

export const listaHTML = (c, sec) => (sec === 'acte' ? acteResultsHTML(c) : nerResultsHTML(c, sec));

function tabActe(c) {
  const st = controlStats(c, today());
  const ok = ACTE.filter((a) => c.acte[a.key].status === 'ok').length;
  const f = state.ui.nerFilter;
  const gol = ACTE.filter((a) => !c.acte[a.key].status).length;
  const deschiseGata = ACTE.filter((a) => c.acte[a.key].status && !state.ui.rowCollapsed.has(actKey(c, a.key))).length;
  const vreunaInchisa = ACTE.some((a) => state.ui.rowCollapsed.has(actKey(c, a.key)));
  const nec = ACTE.filter((a) => c.acte[a.key].status === 'nec').length;
  return `<div class="sum-line">
      <span><b>${st.acteDone}</b>/${st.acteTotal} verificate</span>
      <span class="t-green"><b>${ok}</b> prezentate</span>
      ${st.acteNok ? `<span class="t-red"><b>${st.acteNok}</b> lipsă</span>` : ''}
      ${nec ? `<span><b>${nec}</b> NEC</span>` : ''}
    </div>
    ${toolsRow('acte', 'Caută: numărul actului sau text (ex. LFD, instruire)', 'Caută în acte',
    deschiseGata ? `<button class="btn btn-ghost" data-act="rows-collapse" data-sec="acte">${icon('list')} Restrânge completate (${deschiseGata})</button>`
      : vreunaInchisa ? `<button class="btn btn-ghost" data-act="rows-expand" data-sec="acte">${icon('chevD')} Deschide rândurile</button>` : '')}
    <div class="toolbar">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['NOK', `Lipsă (${st.acteNok})`], ['TODO', `Neverificate (${gol})`]].map(([k, l]) => `<button class="${f === k ? 'on' : ''}" data-act="ner-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
      ${restBtn(gol, 'acte', 'Restul prezentate')}
    </div>
    <div id="ner-results">${acteResultsHTML(c)}</div>`;
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
  ner: { ic: 'alert', title: 'Nereguli constatate', addTitle: 'Nereguli suplimentare', nokWord: 'constatate', empty: 'Adăugați nereguli care nu se află în lista standard.' },
  plan: { ic: 'list', title: 'Planuri și SVSU', addTitle: 'Rubrici suplimentare', nokWord: 'neconforme', empty: 'Adăugați rubrici care nu se află în lista standard.' },
  pc: { ic: 'shield', title: 'Protecție civilă', addTitle: 'Rubrici suplimentare', nokWord: 'neconforme', empty: 'Adăugați rubrici care nu se află în lista standard.' },
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

// Literele rândurilor, scurtat la multe: „b2, c1, e +3”
function litere(c, rows, max = 6) {
  const l = rows.map((n) => neregulaLetter(c, n));
  return l.length > max ? `${l.slice(0, max).join(', ')} +${l.length - max}` : l.join(', ');
}

// Bara unei categorii: completat / necompletat (care), constatate, amendate (care) — vizibile și restrânsă
function catInfo(c, rows, sec, { adapostGol = false, scurt = false } = {}) {
  const gol = rows.filter((n) => !n.status);
  const rest = gol.length + (adapostGol ? 1 : 0);
  const nok = rows.filter((n) => n.status === 'nok');
  const netrec = nok.filter((n) => !n.inPV);
  const amend = nok.filter((n) => n.amenda?.aplicata);
  const lit = [litere(c, gol), adapostGol ? 'adăpost' : ''].filter(Boolean).join(', ');
  const tNec = `${rest} ${rest === 1 ? 'necompletată' : 'necompletate'}`;
  const tNok = `${nok.length} ${nokWord(sec, nok.length)}`;
  const tPv = `${netrec.length} ${netrec.length === 1 ? 'netrecută' : 'netrecute'} în PV`;
  const tAm = `${amend.length} ${amend.length === 1 ? 'amendată' : 'amendate'}`;
  // categorie deschisă: cuvinte întregi, fără litere (rândurile se văd dedesubt); restrânsă: și literele rândurilor
  if (scurt) {
    return `${rest ? `<span class="cat-stare st-rest">${tNec}</span>` : `<span class="cat-stare st-gata">${icon('check')} Completat</span>`}
      ${nok.length ? `<span class="cat-count">${tNok}</span>` : ''}
      ${nok.length ? (netrec.length ? `<span class="cat-pv pv-rest">${icon('pv')} ${tPv}</span>` : `<span class="cat-pv pv-gata">${icon('pv')} toate în PV</span>`) : ''}
      ${amend.length ? `<span class="cat-amenzi">${icon('fine')} ${tAm}</span>` : ''}`;
  }
  return `${rest
    ? `<span class="cat-stare st-rest">${tNec}: ${esc(lit)}</span>`
    : `<span class="cat-stare st-gata">${icon('check')} Completat</span>`}
    ${nok.length ? `<span class="cat-count">${tNok}</span>` : ''}
    ${nok.length ? (netrec.length
    ? `<span class="cat-pv pv-rest">${icon('pv')} ${tPv}: ${esc(litere(c, netrec))}</span>`
    : `<span class="cat-pv pv-gata">${icon('pv')} toate în PV</span>`) : ''}
    ${amend.length ? `<span class="cat-amenzi">${icon('fine')} ${tAm}: ${esc(litere(c, amend))}</span>` : ''}`;
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
    const closed = !q && state.ui.catCollapsed.has(g.cat);
    const nRows = vis.length + (adapost ? 1 : 0);
    return `<div class="cat-group cat-${g.cat} ${closed ? 'closed' : ''}">
      <button type="button" class="cat-title" data-act="cat-toggle" data-cat="${g.cat}" aria-expanded="${!closed}" ${q ? 'disabled' : ''}>
        ${icon('chevD', closed ? '' : 'rot')}<span class="cat-name">${esc(CATEGORII[g.cat])}</span>
        <span class="cat-meta">${nRows} ${nRows === 1 ? 'rând' : 'rânduri'}</span>
        <span class="cat-info">${catInfo(c, g.rows, sec, { adapostGol: sec === 'pc' && g.cat === 'pcdotare' && !c.adapostPC.v, scurt: !closed })}</span>
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
      ${body}
    </section>
    <section class="card">
      ${(() => {
        const ck = `custom-${sec}`;
        const closed = !q && custom.length > 0 && state.ui.catCollapsed.has(ck);
        return `<div class="sec-title-row" id="add-${sec}">
        <button type="button" class="sec-title custom-toggle" data-act="cat-toggle" data-cat="${ck}" aria-expanded="${!closed}" ${custom.length && !q ? '' : 'disabled'}>
          ${custom.length ? icon('chevD', closed ? '' : 'rot') : icon('plus')} ${ui.addTitle}
          ${custom.length ? `<span class="cat-meta">${custom.length} ${custom.length === 1 ? 'rând' : 'rânduri'}</span><span class="cat-info">${catInfo(c, custom, sec, { scurt: !closed })}</span>` : ''}
        </button>
        <button class="btn btn-primary" data-act="ner-add" data-sec="${sec}">${icon('plus')} Adaugă rând</button>
      </div>
      ${closed ? '' : `<div class="cat-group cat-custom"><div class="check-list">${customVis.map((n) => neregulaRow(c, n)).join('') || `<p class="muted pad">${q && custom.length ? 'Niciun rând adăugat nu se potrivește căutării.' : ui.empty}</p>`}</div></div>`}`;
      })()}
    </section>`;
}

// Căutarea și, alături, meniul „⋯” cu acțiunile de afișare (restrânge / extinde)
function toolsRow(sec, ph, aria, meniu) {
  const open = state.ui.toolsOpen;
  return `<div class="tools-row">
      <div class="searchbar ner-search">
        ${icon('search')}
        <input type="search" id="ner-search" data-sec="${sec}" value="${esc(state.ui.nerQuery)}" placeholder="${esc(ph)}" autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="search" aria-label="${esc(aria)}">
        <button class="icon-btn" data-act="ner-q-clear" aria-label="Șterge căutarea">${icon('x')}</button>
      </div>
      ${meniu.trim() ? `<button class="icon-btn big tools-more ${open ? 'on' : ''}" data-act="tools-more" aria-expanded="${open}" aria-label="Opțiuni de afișare">${icon('more')}</button>` : ''}
    </div>
    ${open && meniu.trim() ? `<div class="tools-menu">${meniu}</div>` : ''}`;
}

function tabSectiune(c, sec) {
  const ui = SEC_UI[sec];
  const st = secStats(c, sec, today());
  const { f, groups } = sectionRows(c, sec);
  const showAll = state.ui.showAllNer;
  const inPV = st.constatate - st.netrecute;
  const anyFineOrAsi = st.fines.length || (sec === 'ner' && asiDeadline(c, today()));

  const rest = c.nereguli.filter((n) => secOf(n) === sec && !n.status && !sablon(n.key)?.grav && (isApplicable(c, n) || (showAll && ascunsaDeDotari(c, n)))).length;
  const allClosed = groups.length && groups.every((g) => state.ui.catCollapsed.has(g.cat));
  // Sumarul pe un rând; ascunsele (instalații nebifate DA) ca buton în același rând
  const sumar = `<div class="sum-line">
      <span><b>${st.checked}</b>/${st.total} verificate</span>
      <span class="${st.constatate ? 't-red' : ''}"><b>${st.constatate}</b> ${ui.nokWord}</span>
      ${st.constatate ? `<span class="${st.netrecute ? 't-warn' : 't-green'}"><b>${inPV}</b>/${st.constatate} în PV</span>` : ''}
      ${st.fines.length ? `<span><b>${st.fines.length}</b> ${st.fines.length === 1 ? 'amendă' : 'amenzi'}</span>` : ''}
      ${sec === 'ner' && st.hidden > 0 ? `<button class="chip-link" data-act="toggle-all-ner">${showAll
        ? `Ascunde ${st.hidden === 1 ? 'rândul' : `cele ${st.hidden} rânduri`} (instalații fără DA)`
        : `+${st.hidden} ${st.hidden === 1 ? 'rând ascuns (instalație fără DA)' : 'rânduri ascunse (instalații fără DA)'} · Arată`}</button>` : ''}
    </div>`;
  return `${sumar}
    ${!isIncheiat(c) && anyFineOrAsi ? `<p class="sec-note">${icon('info')} Termenele amenzilor${sec === 'ner' ? ' și ASI' : ''} pornesc după ce completați <b>data încheierii</b> (tabul Obiectiv).</p>` : ''}
    ${toolsRow(sec, `Caută: literă (d, G1) sau text (ex. hidranți, gaz)`, `Caută în ${ui.title.toLowerCase()}`,
    `<button class="btn btn-ghost" data-act="cats-all" data-val="${allClosed ? 'open' : 'close'}">${icon(allClosed ? 'chevD' : 'list')} ${allClosed ? 'Extinde categoriile' : 'Restrânge categoriile'}</button>${rowsBtn(c, sec)}`)}
    <div class="toolbar">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['NOK', `${ui.nokWord[0].toUpperCase()}${ui.nokWord.slice(1)} (${st.constatate})`], ['TODO', `Neverificate (${st.total - st.checked})`]].map(([k, l]) => `<button class="${f === k ? 'on' : ''}" data-act="ner-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
      ${restBtn(rest, sec, sec === 'ner' ? 'Restul conform' : 'Restul conforme')}
    </div>
    <div id="ner-results">${nerResultsHTML(c, sec)}</div>`;
}

// Adăpost de protecție civilă: DA / NU / NEC + observații
// „Restul conform”: bifează în bloc rândurile vizibile încă neverificate (cu confirmare și „Anulează”)
// „Restrânge completate (N)” sau, dacă nu mai e nimic de restrâns, „Deschide rândurile”
function rowsBtn(c, sec) {
  const rows = c.nereguli.filter((n) => secOf(n) === sec && isApplicable(c, n));
  const deschiseGata = rows.filter((n) => n.status && !rowCollapsed(c, n)).length;
  if (deschiseGata) return `<button class="btn btn-ghost" data-act="rows-collapse" data-sec="${sec}">${icon('list')} Restrânge completate (${deschiseGata})</button>`;
  if (rows.some((n) => rowCollapsed(c, n))) return `<button class="btn btn-ghost" data-act="rows-expand" data-sec="${sec}">${icon('chevD')} Deschide rândurile</button>`;
  return '';
}

function restBtn(n, sec, label) {
  if (n <= 0) return '';
  return `<button class="btn btn-ghost btn-rest" data-act="rest-ok" data-sec="${sec}">${icon('check')} ${label} (${n})</button>`;
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

export const rowKey = (c, n) => `${c.id}|${n.key}`;
const rowCollapsed = (c, n) => state.ui.rowCollapsed.has(rowKey(c, n));

// Pastilele din bara unei nereguli: aceleași mesaje și avertismente, și când rândul e restrâns
function rowPills(c, n, collapsed) {
  const sec = SECTIUNI[secOf(n)];
  const pills = [];
  if (collapsed) {
    pills.push(n.status === 'ok' ? pill('green', sec.ok, 'check')
      : n.status === 'nok' ? pill('red', sec.nok, 'x')
        : n.status === 'nec' ? pill('neutral', 'NEC') : '<span class="pill pill-todo">Necompletat</span>');
  }
  const vi = vecheInfo(state.controls, c, n);
  if (vi.veche) pills.push(`<span class="pill pill-veche">${icon('history')}Neregulă veche</span>`);
  if (n.status === 'nok' && isGrav(n) && n.sigiliu) pills.push(pill('red', 'Sigiliu', 'lock'));
  if (n.status === 'nok' && n.custom && n.grav) pills.push(pill('red', 'Neregulă gravă', 'alert'));
  if (n.status === 'nok' && n.auto) pills.push(pill('neutral', `Din fișa obiectivului: NU la ${DOTARI.find((d) => d.key === sablon(n.key)?.autoNU)?.label || ''}`, 'building'));
  if (n.status === 'nok') {
    pills.push(n.inPV ? pill('green', 'Trecut în PV', 'pv') : pill('warn', 'Netrecut în PV', 'pv'));
    if (n.amenda.aplicata) { const fs = fineStatus(c, n, today()); pills.push(finePill(fs.level, `Amendă · ${fs.label}`)); }
    if (collapsed && (c.constructii || []).length > 1 && secOf(n) === 'ner') pills.push(pill('neutral', constructiiNume(c, n), 'building'));
  }
  const exp = n.status !== 'nok' && n.status !== 'nec' ? verifExpirate(c, n) : [];
  if (exp.length) pills.push(pill('warn', `Verificare expirată: ${exp.map((k) => k.denumire).join(', ')}`, 'alert'));
  if (!vi.veche && n.status !== 'nok' && vi.auto) pills.push(pill('neutral', `Constatată la controlul din ${fmtDate(vi.auto.dataInceput)}`, 'history'));
  if (!n.custom && !isApplicable(c, { ...n, status: '' })) {
    const t = sablon(n.key);
    pills.push(pill('neutral', t?.reqNU ? 'Nu mai e marcată NU la dotări' : t?.reqGrfV ? 'Nu mai e GRF/NSI V peste parter' : 'Instalație nebifată DA la dotări', 'info'));
  }
  return pills;
}

function neregulaRow(c, n) {
  const path = `nereguli.@${n.key}`;
  const letter = neregulaLetter(c, n);
  const sec = SECTIUNI[secOf(n)];
  const collapsed = rowCollapsed(c, n);
  const vi = vecheInfo(state.controls, c, n);
  const labelHTML = n.custom
    ? `<input class="row-label-input" data-bind="${path}.label" value="${esc(n.label)}" placeholder="Descrieți ${secOf(n) === 'ner' ? 'neregula' : 'rubrica'}…" autocomplete="off">`
    : `<span class="row-label">${esc(neregulaLabel(n))}</span>`;
  const pills = rowPills(c, n, collapsed);
  const tgl = `data-act="row-toggle" data-key="${esc(n.key)}"`;
  const verif = isVerificare(n) && n.status !== 'nec' ? verifBlock(c, n) : '';
  const constr = sablon(n.key)?.grav ? constrNU(c, n) : ((n.sec === 'ner' || !n.sec) && n.status !== 'nec' ? constrSelect(c, n) : '');
  const obsGol = !String(n.obs || '').trim() && !state.ui.obsOpen.has(obsKey(`${path}.obs`)) && n.status !== 'nok';
  const faraCorp = !verif && !constr && obsGol && !n.custom && n.status !== 'nok';   // corpul ar avea doar „+ Obs.”
  if (faraCorp && !collapsed) pills.push(obsField(`${path}.obs`, ''));
  return `<div class="check-row ner-row ${n.status ? `is-${n.status}` : ''} ${vi.veche && n.status !== 'nec' ? 'is-veche' : ''} ${n.custom && n.grav ? 'is-grav-custom' : ''} ${collapsed ? 'is-collapsed' : ''}" id="ner-${esc(n.key)}">
    <div class="ner-bar">
      <span class="row-idx letter">${esc(letter)}</span>
      <div class="bar-main" ${n.custom ? '' : tgl}>
        ${labelHTML}
        ${pills.length ? `<span class="chips">${pills.join('')}</span>` : ''}
      </div>
      ${collapsed ? '' : okNok(path, n.status, sec.ok, sec.nok, { nec: !sablon(n.key)?.grav || n.custom })}
      <button type="button" class="icon-btn row-tgl" ${tgl} aria-expanded="${!collapsed}" aria-label="${collapsed ? 'Deschide' : 'Restrânge'} rândul ${esc(letter)}">${icon('chevD', collapsed ? '' : 'rot')}</button>
    </div>
    ${collapsed || faraCorp ? '' : `<div class="row-main">
      ${verif}
      ${constr}
      <div class="row-foot">${obsField(`${path}.obs`, n.obs, 'row-obs', n.status === 'nok')}${n.custom ? `<button class="icon-btn danger" data-act="ner-del" data-key="${esc(n.key)}" aria-label="Șterge rândul">${icon('trash')}</button>` : ''}</div>
    </div>
    ${n.status === 'nok' ? neregulaDetail(c, n, path) : ''}`}
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
        ${field('Seria și nr. amenzii', `${path}.amenda.serieNr`, a.serieNr, { ph: 'ex: DB 0012345' })}
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
