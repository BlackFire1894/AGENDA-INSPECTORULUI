// Ecranele de listă: Panou, Obiective, Obiectiv (istoric), Calendar, Istoric, Setări.
import { state, today } from './state.js';
import {
  fmtDate, fmtDateLong, fmtDateMedium, MONTHS, MONTHS_SHORT, WEEKDAYS_SHORT, addDays, diffDays,
  toISO, zile, parseDateQuery, isISO, ucfirst,
} from './dates.js';
import {
  objectives, allFines, allAsi, isIncheiat, byStartDesc, controlStats, matchControl, fold,
  neregulaLabel, neregulaLetter, fineStatus, asiDeadline, controlRange,
} from './model.js';
import { icon, esc, pill, tipBadge, empty } from './ui.js';
import { APP_VERSION } from './version.js';

const LEVEL_LABEL = { blue: 'În curs', yellow: 'Termen expirat', red: 'ANAF', green: 'Achitată' };

export function money(v) {
  const n = Number(String(v).replace(',', '.'));
  if (!v || Number.isNaN(n)) return '';
  return `${n.toLocaleString('ro-RO', { maximumFractionDigits: 2 })} lei`;
}

function rangeText(c) {
  if (!isIncheiat(c)) return `din ${fmtDate(c.dataInceput)} · în desfășurare`;
  if (c.dataIncheiere === c.dataInceput) return fmtDate(c.dataInceput);
  return `${fmtDate(c.dataInceput)} – ${fmtDate(c.dataIncheiere)}`;
}

function statusPill(c) {
  return isIncheiat(c) ? pill('done', 'Încheiat', 'check') : pill('open', 'În desfășurare', 'clock');
}

export function controlRow(c, { showName = true } = {}) {
  const st = controlStats(c, today());
  const [y, m, d] = c.dataInceput.split('-');
  const chips = [statusPill(c)];
  if (st.constatate) chips.push(pill('neutral', `${st.constatate} ${st.constatate === 1 ? 'neregulă' : 'nereguli'}`));
  if (st.netrecute) chips.push(pill('warn', `${st.netrecute} netrecute în PV`, 'pv'));
  const byLevel = {};
  st.fines.forEach((f) => { byLevel[f.st.level] = (byLevel[f.st.level] || 0) + 1; });
  for (const lv of ['red', 'yellow', 'blue', 'green']) {
    if (byLevel[lv]) chips.push(pill(lv, `${byLevel[lv]} ${byLevel[lv] === 1 ? 'amendă' : 'amenzi'} · ${LEVEL_LABEL[lv]}`, 'fine'));
  }
  if (st.asi && !st.asi.resolved) chips.push(pill('red', st.asi.pending ? 'ASI 90 zile' : `ASI: ${st.asi.daysLeft} zile`, 'hourglass'));
  return `<a class="ctl-row" href="#/control/${c.id}/obiectiv">
    <span class="date-block ${isIncheiat(c) ? '' : 'is-open'}"><b>${+d}</b><span>${MONTHS_SHORT[+m - 1]}</span><small>${y}</small></span>
    <span class="ctl-main">
      ${showName ? `<span class="ctl-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>` : ''}
      <span class="ctl-sub">${showName ? tipBadge(c.tip) : ''}<span>${esc(rangeText(c))}</span>${c.administrator && showName ? `<span>· ${esc(c.administrator)}</span>` : ''}</span>
      <span class="chips">${chips.join('')}</span>
    </span>
    ${icon('chevR', 'row-chev')}
  </a>`;
}

function searchBar(key, value, placeholder) {
  const dq = parseDateQuery(value);
  return `<div class="searchbar">
    ${icon('search')}
    <input type="search" data-search="${key}" value="${esc(value)}" placeholder="${esc(placeholder)}" autocomplete="off" enterkeyhint="search">
    ${value ? `<button class="icon-btn" data-act="search-clear" data-key="${key}" aria-label="Șterge căutarea">${icon('x')}</button>` : ''}
    <label class="date-pick" aria-label="Caută după dată">
      ${icon('calendar')}<span>${dq?.kind === 'day' ? fmtDate(dq.iso) : 'Dată'}</span>
      <input type="date" data-search-date="${key}" value="${dq?.kind === 'day' ? dq.iso : ''}">
    </label>
  </div>
  <p class="search-hint" data-hint="${key}">${hintText(value)}</p>`;
}

export function hintText(value) {
  const dq = parseDateQuery(value);
  if (!value) return 'Scrie numele obiectivului sau o dată: 12.09.2026, 09.2026 sau 2026.';
  if (!dq) return `Caut după nume: „${esc(value)}”`;
  if (dq.kind === 'day') return `Controale care includ ziua de ${fmtDateLong(dq.iso)}`;
  if (dq.kind === 'month') return `Controale din ${MONTHS[dq.month - 1]} ${dq.year}`;
  return `Controale din anul ${dq.year}`;
}

// ───────────────────────── PANOU ─────────────────────────

export function viewDashboard() {
  const t = today();
  const cs = state.controls;
  const now = state.now;
  const head = `<header class="page-head dash-head">
    <div>
      <div class="eyebrow">${icon('clock')} Data și ora tabletei</div>
      <h1 class="dash-date">${esc(ucfirst(fmtDateLong(t)))}</h1>
    </div>
    <div class="big-clock" data-clock>${pad(now.getHours())}:${pad(now.getMinutes())}</div>
  </header>`;

  if (!cs.length) {
    return `${head}<div class="welcome card">
      <div class="welcome-art">${icon('shield')}</div>
      <h2>Bun venit în Agenda inspectorului</h2>
      <p>Începe primul control. Toate datele rămân pe această tabletă; fă periodic un backup din Setări.</p>
      <div class="row-gap">
        <button class="btn btn-primary btn-xl" data-act="new-control">${icon('plus')} Control nou</button>
        <button class="btn btn-ghost btn-xl" data-act="demo-load">Încarcă date demonstrative</button>
      </div>
    </div>`;
  }

  const fines = allFines(cs, t);
  const active = fines.filter((f) => f.st.level !== 'green');
  const paid = fines.filter((f) => f.st.level === 'green');
  const cnt = { blue: 0, yellow: 0, red: 0, green: 0 };
  fines.forEach((f) => { cnt[f.st.level]++; });
  const open = cs.filter((c) => !isIncheiat(c)).sort(byStartDesc);
  const asi = allAsi(cs, t);
  const asiActive = asi.filter((x) => !x.a.pending);
  const netrecute = [];
  cs.forEach((c) => c.nereguli.forEach((n) => { if (n.status === 'nok' && !n.inPV) netrecute.push({ c, n }); }));
  const nearestAsi = asiActive[0]?.a.daysLeft;

  const backupWarn = backupReminder();

  const kpis = `<section class="kpis">
    <button class="kpi kpi-fines" data-act="scroll" data-target="sec-fines">
      <span class="kpi-ic">${icon('fine')}</span>
      <span class="kpi-num">${active.length}</span>
      <span class="kpi-label">Amenzi active</span>
      <span class="kpi-bar">${['red', 'yellow', 'blue', 'green'].map((l) => `<span class="seg seg-${l}" style="flex:${cnt[l] || 0}"></span>`).join('')}</span>
      <span class="kpi-legend">
        <span><i class="dot dot-red"></i>${cnt.red}</span><span><i class="dot dot-yellow"></i>${cnt.yellow}</span>
        <span><i class="dot dot-blue"></i>${cnt.blue}</span><span><i class="dot dot-green"></i>${cnt.green}</span>
      </span>
    </button>
    <button class="kpi kpi-open" data-act="scroll" data-target="sec-open">
      <span class="kpi-ic">${icon('clock')}</span>
      <span class="kpi-num">${open.length}</span>
      <span class="kpi-label">Controale neîncheiate</span>
      <span class="kpi-foot">${open.length ? `cel mai vechi: ${fmtDate(open[open.length - 1].dataInceput)}` : 'toate sunt încheiate'}</span>
    </button>
    <button class="kpi kpi-asi" data-act="scroll" data-target="sec-asi">
      <span class="kpi-ic">${icon('hourglass')}</span>
      <span class="kpi-num">${asiActive.length}</span>
      <span class="kpi-label">Termene ASI 90 zile</span>
      <span class="kpi-foot">${nearestAsi !== undefined ? (nearestAsi >= 0 ? `cel mai apropiat: ${zile(nearestAsi)}` : `depășit cu ${zile(-nearestAsi)}`) : 'niciun termen activ'}</span>
    </button>
    <button class="kpi kpi-pv" data-act="scroll" data-target="sec-pv">
      <span class="kpi-ic">${icon('pv')}</span>
      <span class="kpi-num">${netrecute.length}</span>
      <span class="kpi-label">Netrecute în PV</span>
      <span class="kpi-foot">${netrecute.length ? 'de completat în procesul-verbal' : 'toate sunt trecute'}</span>
    </button>
  </section>`;

  const fineItem = ({ c, n, st }) => `<a class="item item-${st.level}" href="#/control/${c.id}/nereguli/${encodeURIComponent(n.key)}">
      <span class="item-main">
        <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
        <span class="item-sub">${esc(neregulaLetter(c, n))}. ${esc(neregulaLabel(n))}</span>
        <span class="item-msg">${esc(st.msg)}</span>
      </span>
      <span class="item-side">
        ${pill(st.level, st.label)}
        ${n.amenda.suma ? `<span class="amount">${esc(money(n.amenda.suma))}</span>` : ''}
      </span>
    </a>`;

  const secFines = `<section class="card dash-sec" id="sec-fines">
    <h2 class="sec-title">${icon('fine')} Amenzi</h2>
    <div class="legend">
      <span><i class="dot dot-blue"></i>în curs (≤ 15 zile)</span>
      <span><i class="dot dot-yellow"></i>termen de 15 zile expirat</span>
      <span><i class="dot dot-red"></i>+25 zile: trimite la ANAF</span>
      <span><i class="dot dot-green"></i>achitată cu dovadă</span>
    </div>
    ${active.length ? `<div class="items">${active.map(fineItem).join('')}</div>` : '<p class="muted pad">Nicio amendă activă.</p>'}
    ${paid.length ? `<details class="paid"><summary>Achitate (${paid.length})</summary><div class="items">${paid.map(fineItem).join('')}</div></details>` : ''}
  </section>`;

  const secAsi = `<section class="card dash-sec" id="sec-asi">
    <h2 class="sec-title">${icon('hourglass')} Termene ASI – 90 de zile</h2>
    ${asi.length ? `<div class="items">${asi.map(({ c, a }) => `<a class="item item-red" href="#/control/${c.id}/nereguli/a">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-msg">${esc(a.msg)}</span>
        </span>
        <span class="item-side">${a.pending ? pill('neutral', 'neînceput') : `<span class="countdown ${a.daysLeft < 0 ? 'over' : ''}"><b>${Math.abs(a.daysLeft)}</b><small>${a.daysLeft < 0 ? 'zile depășit' : a.daysLeft === 1 ? 'zi' : 'zile'}</small></span>`}</span>
      </a>`).join('')}</div>` : '<p class="muted pad">Niciun termen ASI activ.</p>'}
  </section>`;

  const secOpen = `<section class="card dash-sec" id="sec-open">
    <h2 class="sec-title">${icon('clock')} Controale neîncheiate</h2>
    ${open.length ? `<div class="items">${open.map((c) => {
      const days = diffDays(c.dataInceput, t);
      return `<a class="item item-open" href="#/control/${c.id}/obiectiv">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-sub">început ${esc(fmtDateLong(c.dataInceput))}</span>
          <span class="item-msg">Lipsește data încheierii</span>
        </span>
        <span class="item-side"><span class="countdown"><b>${Math.max(days, 0)}</b><small>${days === 1 ? 'zi' : 'zile'}</small></span></span>
      </a>`;
    }).join('')}</div>` : '<p class="muted pad">Toate controalele sunt încheiate.</p>'}
  </section>`;

  const secPv = `<section class="card dash-sec" id="sec-pv">
    <h2 class="sec-title">${icon('pv')} Nereguli netrecute în procesul-verbal</h2>
    ${netrecute.length ? `<div class="items">${netrecute.map(({ c, n }) => `<a class="item item-warn" href="#/control/${c.id}/nereguli/${encodeURIComponent(n.key)}">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-sub">${esc(neregulaLetter(c, n))}. ${esc(neregulaLabel(n))}</span>
        </span>
        <span class="item-side">${pill('warn', 'Netrecut')}</span>
      </a>`).join('')}</div>` : '<p class="muted pad">Toate neregulile constatate sunt trecute în PV.</p>'}
  </section>`;

  return `${head}${backupWarn}${kpis}<div class="dash-grid">${secFines}${secAsi}${secOpen}${secPv}</div>`;
}

function backupReminder() {
  if (!state.controls.length) return '';
  const last = state.meta.lastBackup;
  const days = last ? diffDays(last.slice(0, 10), today()) : null;
  if (days !== null && days < 7) return '';
  return `<a class="banner" href="#/setari">${icon('alert')}<span><b>${last ? `Ultimul backup acum ${zile(days)}.` : 'Nu ai făcut încă niciun backup.'}</b> Datele sunt doar pe această tabletă — exportă un backup în Fișiere / iCloud Drive.</span>${icon('chevR')}</a>`;
}

const pad = (n) => String(n).padStart(2, '0');

// ───────────────────────── OBIECTIVE ─────────────────────────

export function viewObjectives() {
  const u = state.ui;
  return `<header class="page-head">
      <div><div class="eyebrow">${icon('building')} Lista obiectivelor controlate</div><h1>Obiective</h1></div>
      <button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button>
    </header>
    ${searchBar('obj', u.objSearch, 'Caută obiectiv după nume sau dată…')}
    <div class="seg-row">
      <div class="segmented" role="tablist">
        ${[['ALL', 'Toate'], ['OPEC', 'OPEC / Instituție'], ['LOCALITATE', 'Localitate']].map(([k, l]) => `<button class="${u.objTip === k ? 'on' : ''}" data-act="obj-tip" data-val="${k}">${l}</button>`).join('')}
      </div>
    </div>
    <div id="obj-list">${objListHTML()}</div>`;
}

export function objListHTML() {
  const u = state.ui;
  const q = u.objSearch;
  const t = today();
  const list = objectives(state.controls)
    .filter((o) => u.objTip === 'ALL' || o.tip === u.objTip)
    .map((o) => ({ o, hits: o.controls.filter((c) => matchControl(c, q)) }))
    .filter((x) => x.hits.length || (!parseDateQuery(q) && fold(x.o.denumire).includes(fold(q))));
  if (!state.controls.length) {
    return empty('building', 'Niciun obiectiv încă', 'Obiectivele apar aici după primul control.', `<button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button>`);
  }
  if (!list.length) return empty('search', 'Niciun rezultat', 'Încearcă alt nume sau altă dată.');
  return `<p class="count">${list.length} ${list.length === 1 ? 'obiectiv' : 'obiective'}</p>
  <div class="obj-list">${list.map(({ o, hits }) => {
    const fines = allFines(o.controls, t).filter((f) => f.st.level !== 'green');
    const worst = fines[0]?.st.level;
    const open = o.controls.filter((c) => !isIncheiat(c)).length;
    const dateHit = parseDateQuery(q) && hits[0];
    const init = (o.denumire || '?').trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
    return `<a class="obj-card" href="#/obiectiv/${o.id}">
      <span class="avatar ${o.tip === 'LOCALITATE' ? 'av-loc' : 'av-opec'}">${esc(init)}</span>
      <span class="obj-main">
        <span class="obj-title">${esc(o.denumire || 'Obiectiv fără denumire')}</span>
        <span class="obj-sub">${tipBadge(o.tip)}${o.administrator ? `<span>${esc(o.administrator)}</span>` : ''}${o.telefon ? `<span>· ${esc(o.telefon)}</span>` : ''}</span>
        <span class="chips">
          ${pill('neutral', `${o.controls.length} ${o.controls.length === 1 ? 'control' : 'controale'}`, 'history')}
          ${pill('neutral', `ultimul: ${fmtDate(o.last.dataInceput)}`, 'calendar')}
          ${dateHit ? pill('accent', `găsit: ${rangeText(dateHit)}`, 'search') : ''}
          ${open ? pill('open', `${open} în desfășurare`, 'clock') : ''}
          ${fines.length ? pill(worst, `${fines.length} ${fines.length === 1 ? 'amendă activă' : 'amenzi active'}`, 'fine') : ''}
        </span>
      </span>
      ${icon('chevR', 'row-chev')}
    </a>`;
  }).join('')}</div>`;
}

export function viewObjective(oid) {
  const o = objectives(state.controls).find((x) => x.id === oid);
  if (!o) return empty('building', 'Obiectiv inexistent', 'Este posibil să fi fost șters.', '<a class="btn btn-ghost btn-lg" href="#/obiective">Înapoi la obiective</a>');
  const t = today();
  const fines = allFines(o.controls, t);
  const totalNer = o.controls.reduce((s, c) => s + controlStats(c, t).constatate, 0);
  return `<header class="page-head">
      <div class="head-with-back">
        <a class="icon-btn big" href="#/obiective" aria-label="Înapoi">${icon('back')}</a>
        <div><div class="eyebrow">${tipBadge(o.tip)}</div><h1>${esc(o.denumire || 'Obiectiv fără denumire')}</h1></div>
      </div>
      <button class="btn btn-primary btn-lg" data-act="new-control" data-oid="${o.id}">${icon('plus')} Control nou pe acest obiectiv</button>
    </header>
    <section class="card info-grid">
      <div><span class="lbl">Administrator</span><span class="val">${esc(o.administrator || '—')}</span></div>
      <div><span class="lbl">Telefon</span><span class="val">${o.telefon ? `<a href="tel:${esc(o.telefon.replace(/\s/g, ''))}">${icon('phone')} ${esc(o.telefon)}</a>` : '—'}</span></div>
      <div><span class="lbl">Email</span><span class="val">${o.email ? `<a href="mailto:${esc(o.email)}">${icon('mail')} ${esc(o.email)}</a>` : '—'}</span></div>
      <div><span class="lbl">Construcții</span><span class="val">${o.last.constructii.length}</span></div>
    </section>
    <section class="stat-row">
      <div class="stat"><b>${o.controls.length}</b><span>controale</span></div>
      <div class="stat"><b>${totalNer}</b><span>nereguli constatate</span></div>
      <div class="stat"><b>${fines.length}</b><span>amenzi aplicate</span></div>
      <div class="stat"><b>${fines.filter((f) => f.st.level !== 'green').length}</b><span>amenzi active</span></div>
    </section>
    <h2 class="list-title">${icon('history')} Istoricul controalelor</h2>
    <div class="timeline">${o.controls.map((c) => `<div class="tl-item">${controlRow(c, { showName: false })}</div>`).join('')}</div>`;
}

// ───────────────────────── ISTORIC ─────────────────────────

export function viewHistory() {
  const u = state.ui;
  return `<header class="page-head">
      <div><div class="eyebrow">${icon('history')} Toate controalele, pe toate obiectivele</div><h1>Istoric controale</h1></div>
      <button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button>
    </header>
    ${searchBar('hist', u.histSearch, 'Caută după obiectiv, administrator sau dată…')}
    <div class="seg-row">
      <div class="segmented">
        ${[['ALL', 'Toate'], ['OPEN', 'În desfășurare'], ['DONE', 'Încheiate']].map(([k, l]) => `<button class="${u.histFilter === k ? 'on' : ''}" data-act="hist-filter" data-val="${k}">${l}</button>`).join('')}
      </div>
    </div>
    <div id="hist-list">${histListHTML()}</div>`;
}

export function histListHTML() {
  const u = state.ui;
  if (!state.controls.length) {
    return empty('history', 'Niciun control încă', 'Istoricul se completează automat pe măsură ce lucrezi.', `<button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button>`);
  }
  const list = state.controls
    .filter((c) => u.histFilter === 'ALL' || (u.histFilter === 'OPEN' ? !isIncheiat(c) : isIncheiat(c)))
    .filter((c) => matchControl(c, u.histSearch))
    .sort(byStartDesc);
  if (!list.length) return empty('search', 'Niciun rezultat', 'Încearcă alt nume, altă dată sau alt filtru.');
  const groups = new Map();
  for (const c of list) {
    const k = c.dataInceput.slice(0, 7);
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(c);
  }
  let html = `<p class="count">${list.length} ${list.length === 1 ? 'control' : 'controale'}</p>`;
  for (const [k, cs] of groups) {
    const [y, m] = k.split('-');
    html += `<h3 class="group-title">${MONTHS[+m - 1]} ${y} <span>${cs.length}</span></h3><div class="ctl-list">${cs.map((c) => controlRow(c)).join('')}</div>`;
  }
  return html;
}

// ───────────────────────── CALENDAR ─────────────────────────

function calendarData(from, to) {
  const t = today();
  const map = new Map();
  const get = (d) => { if (!map.has(d)) map.set(d, { controls: [], deadlines: [] }); return map.get(d); };
  for (const c of state.controls) {
    let [s, e] = controlRange(c);
    if (!isIncheiat(c) && t > s) e = t; // controlul neîncheiat apare până azi
    if (e < from || s > to) { /* în afara lunii */ } else {
      let d = s < from ? from : s;
      const end = e > to ? to : e;
      let guard = 0;
      while (d <= end && guard++ < 62) { get(d).controls.push(c); d = addDays(d, 1); }
    }
    for (const n of c.nereguli) {
      if (n.status !== 'nok' || !n.amenda?.aplicata) continue;
      const st = fineStatus(c, n, t);
      if (st.level === 'green' || !st.plataPana) continue;
      if (st.plataPana >= from && st.plataPana <= to) get(st.plataPana).deadlines.push({ kind: 'plata', level: 'blue', c, n, text: 'Termen plată amendă (15 zile)' });
      if (st.anafPana >= from && st.anafPana <= to) get(st.anafPana).deadlines.push({ kind: 'anaf', level: 'red', c, n, text: 'Termen trimitere la ANAF' });
    }
    const a = asiDeadline(c, t);
    if (a && a.deadline && !a.resolved && a.deadline >= from && a.deadline <= to) {
      get(a.deadline).deadlines.push({ kind: 'asi', level: 'red', c, text: 'Termen ASI – 90 de zile' });
    }
  }
  return map;
}

export function viewCalendar() {
  const u = state.ui;
  const y = u.calYear, m = u.calMonth;
  const first = new Date(y, m, 1);
  const offset = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const weeks = Math.ceil((offset + daysInMonth) / 7);
  const gridStart = toISO(new Date(y, m, 1 - offset));
  const gridEnd = addDays(gridStart, weeks * 7 - 1);
  const data = calendarData(gridStart, gridEnd);
  const t = today();
  const monthCount = state.controls.filter((c) => {
    const [s, e] = controlRange(c);
    return s <= toISO(new Date(y, m, daysInMonth)) && e >= toISO(first);
  }).length;

  let cells = '';
  for (let i = 0; i < weeks * 7; i++) {
    const d = addDays(gridStart, i);
    const inMonth = +d.slice(5, 7) === m + 1;
    const ev = data.get(d) || { controls: [], deadlines: [] };
    const shown = ev.controls.slice(0, 3);
    const more = ev.controls.length - shown.length;
    cells += `<button class="cal-cell ${inMonth ? '' : 'out'} ${d === t ? 'is-today' : ''} ${d === u.calSelected ? 'is-sel' : ''}" data-act="cal-day" data-date="${d}">
      <span class="cal-num">${+d.slice(8)}</span>
      <span class="cal-evs">${shown.map((c) => `<span class="cal-ev ${isIncheiat(c) ? 'ev-done' : 'ev-open'}">${esc(c.denumire || 'Fără denumire')}</span>`).join('')}${more > 0 ? `<span class="cal-more">+${more}</span>` : ''}</span>
      ${ev.deadlines.length ? `<span class="cal-dls">${ev.deadlines.slice(0, 4).map((x) => `<i class="dot dot-${x.level}"></i>`).join('')}</span>` : ''}
    </button>`;
  }

  const sel = u.calSelected;
  const selData = calendarData(sel, sel).get(sel) || { controls: [], deadlines: [] };
  const panel = `<aside class="card day-panel">
    <div class="day-head">
      <div><div class="eyebrow">${sel === t ? 'Astăzi' : 'Ziua selectată'}</div><h2>${esc(ucfirst(fmtDateLong(sel)))}</h2></div>
    </div>
    ${selData.controls.length ? `<div class="ctl-list">${selData.controls.map((c) => controlRow(c)).join('')}</div>` : '<p class="muted pad">Niciun control în această zi.</p>'}
    ${selData.deadlines.length ? `<h3 class="mini-title">Termene</h3><div class="items">${selData.deadlines.map((x) => `<a class="item item-${x.level}" href="#/control/${x.c.id}/nereguli/${encodeURIComponent(x.n ? x.n.key : 'a')}">
        <span class="item-main"><span class="item-title">${esc(x.text)}</span><span class="item-sub">${esc(x.c.denumire)}${x.n ? ` · ${esc(neregulaLetter(x.c, x.n))}. ${esc(neregulaLabel(x.n))}` : ''}</span></span>
      </a>`).join('')}</div>` : ''}
    <button class="btn btn-primary btn-lg btn-block" data-act="new-control" data-date="${sel}">${icon('plus')} Control nou în această zi</button>
  </aside>`;

  return `<header class="page-head">
      <div><div class="eyebrow">${icon('calendar')} ${monthCount} ${monthCount === 1 ? 'control' : 'controale'} în această lună</div><h1 class="cap">${MONTHS[m]} ${y}</h1></div>
      <div class="row-gap">
        <button class="icon-btn big" data-act="cal-prev" aria-label="Luna anterioară">${icon('chevL')}</button>
        <button class="btn btn-ghost btn-lg" data-act="cal-today">Azi</button>
        <button class="icon-btn big" data-act="cal-next" aria-label="Luna următoare">${icon('chevR')}</button>
      </div>
    </header>
    <div class="cal-layout">
      <div class="card cal-card">
        <div class="cal-grid cal-wd">${WEEKDAYS_SHORT.map((w) => `<span>${w}</span>`).join('')}</div>
        <div class="cal-grid">${cells}</div>
        <div class="legend cal-legend">
          <span><i class="sw sw-open"></i>control în desfășurare</span>
          <span><i class="sw sw-done"></i>control încheiat</span>
          <span><i class="dot dot-blue"></i>termen plată amendă</span>
          <span><i class="dot dot-red"></i>termen ANAF / ASI</span>
        </div>
      </div>
      ${panel}
    </div>`;
}

// ───────────────────────── SETĂRI ─────────────────────────

export function viewSettings(persisted) {
  const last = state.meta.lastBackup;
  const demo = state.controls.filter((c) => c.demo).length;
  return `<header class="page-head"><div><div class="eyebrow">${icon('settings')} Date, backup și informații</div><h1>Setări</h1></div></header>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('download')} Backup</h2>
    <p>Datele sunt salvate <b>doar pe această tabletă</b>. Exportă periodic un fișier de backup și salvează-l în <b>Fișiere → iCloud Drive</b> (sau alt loc sigur).</p>
    <div class="set-status"><span class="lbl">Ultimul backup</span><b>${last ? `${fmtDateLong(last.slice(0, 10))}, ${last.slice(11, 16)}` : 'niciodată'}</b></div>
    <div class="row-gap">
      <button class="btn btn-primary btn-lg" data-act="backup-export">${icon('download')} Exportă backup</button>
      <label class="btn btn-ghost btn-lg file-btn">${icon('upload')} Importă backup<input type="file" accept="application/json,.json" data-import></label>
    </div>
  </section>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('info')} Stocare</h2>
    <div class="set-status"><span class="lbl">Controale salvate</span><b>${state.controls.length}</b></div>
    <div class="set-status"><span class="lbl">Obiective</span><b>${objectives(state.controls).length}</b></div>
    <div class="set-status"><span class="lbl">Stocare persistentă</span><b>${persisted ? 'Da' : 'Nu (instalează aplicația pe ecranul principal)'}</b></div>
    ${demo ? `<div class="row-gap"><button class="btn btn-ghost btn-lg" data-act="demo-remove">Șterge datele demonstrative (${demo})</button></div>` : `<div class="row-gap"><button class="btn btn-ghost btn-lg" data-act="demo-load">Încarcă date demonstrative</button></div>`}
  </section>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('upload')} Actualizări</h2>
    <div class="set-status"><span class="lbl">Versiunea instalată</span><b>${APP_VERSION}</b></div>
    <p>Aplicația verifică singură la fiecare deschidere. Când există o versiune nouă, apare un mesaj cu butonul <b>Actualizează</b>.</p>
    <button class="btn btn-ghost btn-lg" data-act="check-update">${icon('history')} Verifică acum</button>
  </section>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('hourglass')} Cum se calculează termenele</h2>
    <ul class="rules">
      <li><b>Toate termenele</b> curg de la data de referință + 1 zi, după data și ora tabletei.</li>
      <li><b>Amendă:</b> data aplicării (implicit data încheierii controlului).
        <span class="rule-row"><i class="dot dot-blue"></i> zilele 1–15: în curs</span>
        <span class="rule-row"><i class="dot dot-yellow"></i> zilele 16–39: termenul de 15 zile expirat</span>
        <span class="rule-row"><i class="dot dot-red"></i> din ziua 40: „Mai ai 5 zile până să o trimiți la ANAF” (termen: ziua 45)</span>
        <span class="rule-row"><i class="dot dot-green"></i> achitată, cu dovadă primită</span></li>
      <li><b>ASI:</b> 90 de zile de la data încheierii controlului.</li>
      <li>Aplicația nu prelungește termenele care se termină în zile nelucrătoare — verifică în calculatorul de termene.</li>
    </ul>
  </section>
  <section class="card set-sec danger-zone">
    <h2 class="sec-title">${icon('trash')} Zonă periculoasă</h2>
    <p>Șterge definitiv toate controalele de pe această tabletă. Fă întâi un backup.</p>
    <button class="btn btn-danger btn-lg" data-act="wipe">Șterge toate datele</button>
  </section>
  <p class="muted center">Agenda inspectorului · v${APP_VERSION} · funcționează offline</p>`;
}
