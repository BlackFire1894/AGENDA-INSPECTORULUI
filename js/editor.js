// Editorul unui control: 3 taburi — Obiectiv, Acte & evidențe, Nereguli.
import { state, today } from './state.js';
import { fmtDate, fmtDateLong, isISO } from './dates.js';
import {
  TIP_OBIECTIV, DOTARI, CENTRALA_TIPURI, ACTE, STRUCTURI, MATERIALE_PERETI,
  controlStats, fineStatus, fineDate, asiDeadline, isIncheiat, neregulaLabel, neregulaLetter,
} from './model.js';
import { icon, esc, pill, tipBadge } from './ui.js';

export const TABS = [
  { key: 'obiectiv', label: 'Obiectiv', ic: 'building' },
  { key: 'acte', label: 'Acte & evidențe', ic: 'doc' },
  { key: 'nereguli', label: 'Nereguli', ic: 'alert' },
];

export function viewControl(c, tab) {
  return `<div class="editor">
    <header class="ed-head" id="ed-head">${edHeadHTML(c)}</header>
    <nav class="ed-tabs" id="ed-tabs">${edTabsHTML(c, tab)}</nav>
    <div id="ed-body" class="ed-body">${tabHTML(c, tab)}</div>
  </div>`;
}

export function edHeadHTML(c) {
  return `<a class="icon-btn big" href="${esc(state.ui.backTo)}" aria-label="Înapoi">${icon('back')}</a>
    <div class="ed-title">
      <div class="ed-meta">${tipBadge(c.tip)}${isIncheiat(c) ? pill('done', 'Încheiat', 'check') : pill('open', 'În desfășurare', 'clock')}</div>
      <h1 data-live="denumire">${esc(c.denumire || 'Obiectiv fără denumire')}</h1>
      <div class="ed-dates">${icon('calendar')} ${esc(fmtDate(c.dataInceput))}${isIncheiat(c) ? ` – ${esc(fmtDate(c.dataIncheiere))}` : ' – în desfășurare'}</div>
    </div>
    <div class="ed-actions">
      <span class="save-ind" id="save-ind">${icon('check')}<span>Salvat</span></span>
      <a class="btn btn-ghost" href="#/obiectiv/${c.objectiveId}">${icon('history')} Istoric obiectiv</a>
      <button class="icon-btn big danger" data-act="control-delete" aria-label="Șterge controlul">${icon('trash')}</button>
    </div>`;
}

export function edTabsHTML(c, tab) {
  const st = controlStats(c, today());
  const badge = {
    obiectiv: `${c.constructii.length} ${c.constructii.length === 1 ? 'construcție' : 'construcții'}`,
    acte: `${st.acteDone}/${st.acteTotal}${st.acteNok ? ` · ${st.acteNok} lipsă` : ''}`,
    nereguli: st.constatate ? `${st.constatate} constatate${st.netrecute ? ` · ${st.netrecute} netrecute` : ''}` : `${st.nereguliChecked}/${st.nereguliTotal} verificate`,
  };
  const warn = { nereguli: st.netrecute > 0, acte: st.acteNok > 0 };
  return TABS.map((t, i) => `<a class="ed-tab ${t.key === tab ? 'on' : ''}" href="#/control/${c.id}/${t.key}">
      <span class="tab-num">${i + 1}</span>
      <span class="tab-txt"><b>${t.label}</b><small class="${warn[t.key] ? 'warn' : ''}">${esc(badge[t.key])}</small></span>
    </a>`).join('');
}

export function tabHTML(c, tab) {
  if (tab === 'acte') return tabActe(c);
  if (tab === 'nereguli') return tabNereguli(c);
  return tabObiectiv(c);
}

// ───────── helpers pentru câmpuri ─────────

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
          <button class="chip-btn" data-act="end-start">= data începerii</button>
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
  <section class="card form-card">
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

  <section class="card form-card">
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
      <h3 class="mini-title">Dotări și instalații <small>NEC = nu este cazul</small></h3>
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
      <input class="dot-obs" data-bind="${path}.obs" value="${esc(v.obs)}" placeholder="Observații" autocomplete="off">
    </div>`;
  }
  return `<div class="dot-row">
    <span class="dot-label">${esc(d.label)}</span>
    ${segBtns(`${path}.v`, v.v, d.opts, 'seg-dnn')}
    <input class="dot-obs" data-bind="${path}.obs" value="${esc(v.obs)}" placeholder="Observații" autocomplete="off">
  </div>`;
}

// ───────── TAB 2: ACTE ─────────

function tabActe(c) {
  const st = controlStats(c, today());
  const ok = ACTE.filter((a) => c.acte[a.key].status === 'ok').length;
  return `<section class="card">
    <div class="sec-title-row">
      <h2 class="sec-title">${icon('doc')} Acte de autoritate și evidențe</h2>
      <div class="progress-txt"><b>${st.acteDone}</b>/${st.acteTotal} verificate · <span class="t-green">${ok} prezentate</span> · <span class="t-red">${st.acteNok} lipsă</span></div>
    </div>
    <div class="progress"><span class="p-ok" style="width:${(ok / st.acteTotal) * 100}%"></span><span class="p-nok" style="width:${(st.acteNok / st.acteTotal) * 100}%"></span></div>
    <div class="check-list">${ACTE.map((a, i) => {
      const v = c.acte[a.key];
      const path = `acte.${a.key}`;
      return `<div class="check-row ${v.status ? `is-${v.status}` : ''}">
        <span class="row-idx">${i + 1}</span>
        <div class="row-main">
          <span class="row-label">${esc(a.label)}</span>
          <input class="row-obs" data-bind="${path}.obs" value="${esc(v.obs)}" placeholder="Observații" autocomplete="off">
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

// ───────── TAB 3: NEREGULI ─────────

function tabNereguli(c) {
  const st = controlStats(c, today());
  const f = state.ui.nerFilter;
  const tmpl = c.nereguli.filter((n) => !n.custom);
  const custom = c.nereguli.filter((n) => n.custom);
  const show = (n) => f === 'ALL' || (f === 'NOK' ? n.status === 'nok' : !n.status);
  const inPV = st.constatate - st.netrecute;
  return `<section class="ner-summary">
      <div class="sum-box"><b>${st.nereguliChecked}<small>/${st.nereguliTotal}</small></b><span>verificate</span></div>
      <div class="sum-box s-red"><b>${st.constatate}</b><span>constatate</span></div>
      <div class="sum-box ${st.netrecute ? 's-warn' : 's-green'}"><b>${inPV}<small>/${st.constatate}</small></b><span>trecute în PV</span></div>
      <div class="sum-box s-blue"><b>${st.fines.length}</b><span>amenzi</span></div>
    </section>
    ${!isIncheiat(c) && (st.fines.length || st.asi) ? `<div class="banner banner-info">${icon('info')}<span>Termenele amenzilor și ASI pornesc după ce completezi <b>data încheierii</b> în tabul Obiectiv.</span></div>` : ''}
    <div class="seg-row">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['NOK', `Constatate (${st.constatate})`], ['TODO', `Neverificate (${st.nereguliTotal - st.nereguliChecked})`]].map(([k, l]) => `<button class="${f === k ? 'on' : ''}" data-act="ner-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
    </div>
    <section class="card">
      <h2 class="sec-title">${icon('alert')} Nereguli constatate</h2>
      <div class="check-list">${tmpl.filter(show).map((n) => neregulaRow(c, n)).join('') || '<p class="muted pad">Nimic de afișat pentru acest filtru.</p>'}</div>
    </section>
    <section class="card">
      <div class="sec-title-row">
        <h2 class="sec-title">${icon('plus')} Nereguli suplimentare</h2>
        <button class="btn btn-primary" data-act="ner-add">${icon('plus')} Adaugă neregulă</button>
      </div>
      <div class="check-list">${custom.filter(show).map((n) => neregulaRow(c, n)).join('') || '<p class="muted pad">Adaugă nereguli care nu se află în lista standard.</p>'}</div>
    </section>`;
}

function neregulaRow(c, n) {
  const path = `nereguli.@${n.key}`;
  const letter = neregulaLetter(c, n);
  const labelHTML = n.custom
    ? `<input class="row-label-input" data-bind="${path}.label" value="${esc(n.label)}" placeholder="Descrie neregula…" autocomplete="off">`
    : `<span class="row-label">${esc(neregulaLabel(n))}</span>`;
  const chips = [];
  if (n.status === 'nok') {
    chips.push(n.inPV ? pill('green', 'Trecut în PV', 'pv') : pill('warn', 'Netrecut în PV', 'pv'));
    if (n.amenda.aplicata) { const fs = fineStatus(c, n, today()); chips.push(pill(fs.level, `Amendă · ${fs.label}`, 'fine')); }
  }
  return `<div class="check-row ner-row ${n.status ? `is-${n.status}` : ''}" id="ner-${esc(n.key)}">
    <span class="row-idx letter">${esc(letter)}</span>
    <div class="row-main">
      ${labelHTML}
      ${chips.length ? `<span class="chips">${chips.join('')}</span>` : ''}
      <input class="row-obs" data-bind="${path}.obs" value="${esc(n.obs)}" placeholder="Observații" autocomplete="off">
    </div>
    <div class="row-side">
      ${okNok(path, n.status, 'Conform', 'Constatat')}
      ${n.custom ? `<button class="icon-btn danger" data-act="ner-del" data-key="${esc(n.key)}" aria-label="Șterge rândul">${icon('trash')}</button>` : ''}
    </div>
    ${n.status === 'nok' ? neregulaDetail(c, n, path) : ''}
  </div>`;
}

function neregulaDetail(c, n, path) {
  const a = n.amenda;
  let asi = '';
  if (n.key === 'a' && !n.custom) {
    const d = asiDeadline(c, today());
    asi = `<div class="detail-block">
      <div class="detail-toggles">
        ${toggle(`${path}.asiTermen`, n.asiTermen, 'Termen de prezentare 90 de zile', { level: 'red', ic: 'hourglass' })}
        ${n.asiTermen ? toggle(`${path}.asiPrezentat`, n.asiPrezentat, 'Documentație prezentată', { level: 'green' }) : ''}
      </div>
      ${n.asiTermen && d ? `<div class="deadline ${d.resolved ? 'dl-green' : 'dl-red'}">
        ${icon(d.resolved ? 'check' : 'hourglass')}
        <div><b>${d.resolved ? 'Rezolvat' : d.pending ? 'Termen neînceput' : `Termen: ${esc(fmtDateLong(d.deadline))}`}</b><span>${esc(d.msg)}</span></div>
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
        <div><b>${esc(fs.label)}</b><span>${esc(fs.msg)}</span></div>
      </div>
      <div class="form-grid g3">
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
        <span class="${fs.level === 'blue' ? 'cur' : 'past'}"><i class="dot dot-blue"></i>Plată până la <b>${fmtDate(fs.plataPana)}</b></span>
        <span class="${fs.level === 'red' ? 'cur' : ''}"><i class="dot dot-red"></i>ANAF până la <b>${fmtDate(fs.anafPana)}</b></span>
      </div>` : ''}
    </div>`;
  }
  return `<div class="ner-detail">
    <div class="detail-toggles">
      ${toggle(`${path}.inPV`, n.inPV, 'Trecut în procesul-verbal', { level: 'green', ic: 'pv', offLabel: 'Netrecut în procesul-verbal' })}
      ${toggle(`${path}.amenda.aplicata`, a.aplicata, 'Sancționat cu amendă', { level: 'blue', ic: 'fine' })}
    </div>
    ${asi}${fine}
  </div>`;
}
