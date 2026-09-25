// Ecranele de listă: Panou, Obiective, Obiectiv (istoric), Calendar, Istoric, Setări.
import { state, today } from './state.js';
import {
  fmtDate, fmtDateLong, MONTHS, MONTHS_SHORT, WEEKDAYS_SHORT, addDays, diffDays,
  toISO, zile, parseDateQuery, ucfirst, sarbatoriLegale,
} from './dates.js';
import {
  objectives, allFines, allAsi, isIncheiat, byStartDesc, controlStats, matchControl, fold,
  neregulaLetter, fineStatus, asiDeadline, controlRange, activeNereguli, tabOfNeregula,
  constructiiNume, secOf, amendaSerieNr, vecheInfo, constatareLabel, isApplicable, fmtCoord, googleMapsUrl, appleMapsUrl,
  incarcareStatus, LIPSA_INCARCARE,
  parseSuma, isGrav, sigiliiControl, sigiliiText,
} from './model.js';
import { icon, esc, pill, finePill, tipBadge, empty } from './ui.js';
import { APP_VERSION } from './version.js';
import { MANUAL } from './help.js';
import { FISA_CSS } from './fisa.js';
import {
  activitatiInZi, deConfirmat, titluActivitate, tipLabel, cand, STARI_ACTIVITATE, raportLunar, raportMarkup, RAPORT_CSS,
  ziLibera, eticheteLibera,
} from './activitati.js';


export const FONT_SIZES = [
  { key: 'mic', label: 'Mic', px: 15, hint: 'mai mult conținut pe ecran' },
  { key: 'mediu', label: 'Mediu', px: 16.5, hint: 'echilibrat' },
  { key: 'mare', label: 'Mare', px: 18, hint: 'implicit' },
];

export function currentFont() {
  const f = document.documentElement.dataset.font;
  return f === 'mic' || f === 'mediu' ? f : 'mare';
}

// aceleași denumiri ca pastilele din Panou (fineStatus)
const LEVEL_LABEL = { blue: 'În curs', yellow: 'Termen 15 zile expirat', red: 'Trimite la ANAF', green: 'Achitată' };

export function money(v) {
  const n = parseSuma(v);
  if (n === null) return '';
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

// Nereguli grave (șablon G sau rânduri adăugate marcate grave) care nu sunt conforme
const graveCount = (c) => c.nereguli.filter((n) => isGrav(n) && n.status !== 'ok' && isApplicable(c, n)).length;

// Filtrele din Istoric și Obiective, după informațiile de pe rândul controlului; active împreună = toate îndeplinite.
// ultim: în Obiective se verifică doar ultimul control (starea actuală); celelalte, la oricare control.
const FILTRE = [
  { key: 'am-blue', label: 'Amendă în curs', ic: 'fine', lv: 'blue', test: (c, st) => st.fines.some((f) => f.st.level === 'blue') },
  { key: 'am-yellow', label: 'Termen 15 zile expirat', ic: 'fine', lv: 'yellow', test: (c, st) => st.fines.some((f) => f.st.level === 'yellow') },
  { key: 'am-red', label: 'Trimite la ANAF', ic: 'fine', lv: 'red', test: (c, st) => st.fines.some((f) => f.st.level === 'red') },
  { key: 'am-green', label: 'Amendă achitată', ic: 'fine', lv: 'green', test: (c, st) => st.fines.some((f) => f.st.level === 'green') },
  { key: 'asi', label: 'ASI în curs', ic: 'hourglass', lv: 'red', test: (c, st) => !!st.asi && !st.asi.resolved && !st.asi.pending },
  { key: 'inc', label: 'De încărcat', ic: 'upload', lv: 'warn', test: (c, st) => !!st.incarcare && !st.incarcare.gata },
  { key: 'pv', label: 'Netrecute în PV', ic: 'pv', lv: 'warn', test: (c, st) => st.netrecute > 0 },
  { key: 'grave', label: 'Nereguli grave', ic: 'alert', lv: 'red', ultim: true, test: (c) => graveCount(c) > 0 },
  { key: 'sigiliu', label: 'Sigiliu aplicat', ic: 'lock', lv: 'red', ultim: true, test: (c) => !!sigiliiControl(c) },
];
const FILTRU = Object.fromEntries(FILTRE.map((f) => [f.key, f]));
export const controlPotrivit = (c, keys, t) => { const st = controlStats(c, t); return keys.every((k) => FILTRU[k].test(c, st)); };
export const obiectivPotrivit = (o, keys, t) => keys.every((k) => (FILTRU[k].ultim ? [o.last] : o.controls).some((c) => FILTRU[k].test(c, controlStats(c, t))));

// Rândul de filtre: fiecare cu numărul rezultatelor dacă l-ați adăuga (sau, activ, câte sunt acum)
function filtreHTML(lista, activeSet, numara) {
  const active = [...activeSet].filter((k) => FILTRU[k]);
  const btns = FILTRE.map((f) => {
    const on = active.includes(f.key);
    const n = numara(on ? active : [...active, f.key]);
    return `<button class="flt-btn flt-${f.lv} ${on ? 'on' : ''}" data-act="flt-toggle" data-list="${lista}" data-val="${f.key}" aria-pressed="${on}" ${!n && !on ? 'disabled' : ''}>
      ${icon(on ? 'check' : f.ic)}<span>${f.label}</span><b>${n}</b></button>`;
  }).join('');
  return `<div class="flt-row" id="flt-${lista}">${btns}${active.length ? `<button class="flt-btn flt-clear" data-act="flt-clear" data-list="${lista}">${icon('x')}<span>Șterge filtrele</span></button>` : ''}</div>`;
}

export function controlRow(c, { showName = true } = {}) {
  const st = controlStats(c, today());
  const [y, m, d] = c.dataInceput.split('-');
  const chips = [statusPill(c)];
  if (st.constatate) chips.push(pill('neutral', `${st.constatate} ${st.constatate === 1 ? 'neregulă' : 'nereguli'}`));
  if (st.netrecute) chips.push(pill('warn', `${st.netrecute} ${st.netrecute === 1 ? 'netrecută' : 'netrecute'} în PV`, 'pv'));
  const grave = graveCount(c);
  if (grave) chips.unshift(pill('red', `${grave} ${grave === 1 ? 'neregulă gravă' : 'nereguli grave'}`, 'alert'));
  const sig = sigiliiControl(c);
  if (sig) chips.splice(grave ? 1 : 0, 0, pill('red', sigiliiText(sig), 'lock'));
  const vechi = activeNereguli(c).filter((n) => vecheInfo(state.controls, c, n).veche).length;
  if (vechi) chips.push(`<span class="pill pill-veche">${icon('history')}${vechi} ${vechi === 1 ? 'neregulă veche' : 'nereguli vechi'}</span>`);
  const byLevel = {};
  st.fines.forEach((f) => { byLevel[f.st.level] = (byLevel[f.st.level] || 0) + 1; });
  for (const lv of ['red', 'yellow', 'blue', 'green']) {
    if (byLevel[lv]) chips.push(finePill(lv, `${byLevel[lv]} ${byLevel[lv] === 1 ? 'amendă' : 'amenzi'} · ${lv === 'green' && byLevel[lv] > 1 ? 'Achitate' : LEVEL_LABEL[lv]}`));
  }
  if (st.asi && !st.asi.resolved) {
    const z = st.asi.daysLeft;
    const cand = z > 0 ? (z === 1 ? 'mai este 1 zi' : `mai sunt ${zile(z)}`) : z === 0 ? (st.asi.faza ? 'ultima zi azi' : 'expiră azi') : `depășit cu ${zile(-z)}`;
    chips.push(pill('red', st.asi.pending ? 'ASI 90 de zile: neînceput' : st.asi.faza === 'pierdere' ? `ASI, constatarea pierderii valabilității: ${cand}` : `ASI: ${cand}`, 'hourglass'));
  }
  // după încheiere: încărcat în aplicație / document încărcat
  const inc = st.incarcare;
  if (inc?.gata) chips.push(pill('green', 'Încărcat în aplicație · document încărcat', 'upload'));
  else if (inc) {
    inc.lipsa.forEach((k) => chips.push(pill(inc.level, ucfirst(LIPSA_INCARCARE[k]), 'upload')));
    chips.push(pill(inc.level, inc.daysLeft < 0 ? `Încărcare: termen depășit cu ${zile(-inc.daysLeft)}` : inc.daysLeft === 0 ? 'Încărcare: ultima zi azi' : `Încărcare: ${inc.daysLeft === 1 ? '1 zi lucrătoare' : `${inc.daysLeft} zile lucrătoare`}`, 'hourglass'));
  }
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
  if (!value) return 'Scrieți numele obiectivului sau o dată: 12.09.2026, 09.2026 sau 2026.';
  if (!dq) return `Caut după nume: „${esc(value)}”`;
  if (dq.kind === 'day') return `Controale care includ ziua de ${fmtDateLong(dq.iso)}`;
  if (dq.kind === 'month') return `Controale din ${MONTHS[dq.month - 1]} ${dq.year}`;
  return `Controale din anul ${dq.year}`;
}

// ───────────────────────── PANOU ─────────────────────────

export function viewDashboard() {
  const t = today();
  const cs = state.controls;
  const now = new Date();
  // Antet: data și ora pe un rând. Ghidul și Backup rapid apar aici doar pe vertical (pe orizontal sunt în bara laterală).
  const head = `<header class="dash-head">
    <div class="eyebrow">${icon('clock')} Data și ora tabletei</div>
    <div class="dash-actions">
      <a class="btn btn-ghost guide-btn" href="#/ghid">${icon('book')} Ghidul aplicației</a>
      ${cs.length ? `<button class="btn btn-ghost backup-quick ${backupIsStale() ? 'stale' : ''}" data-act="backup-export">${icon('download')}<span><b>Backup rapid</b><small>${esc(backupAgeText())}</small></span></button>` : ''}
    </div>
    <h1 class="dash-date"><span>${esc(ucfirst(fmtDateLong(t)))}</span><span class="dash-time" data-clock>${pad(now.getHours())}:${pad(now.getMinutes())}</span></h1>
  </header>`;

  if (!cs.length) {
    return `${head}<div class="welcome card">
      <div class="welcome-art">${icon('shield')}</div>
      <h2>Bun venit în Agenda inspectorului</h2>
      <p>Toate datele rămân pe această tabletă. Începeți cu un control nou sau încercați aplicația pe date demonstrative. Tot ce face aplicația e explicat în <b>Ghidul aplicației</b>.</p>
      <div class="row-gap">
        <button class="btn btn-primary btn-xl" data-act="new-control">${icon('plus')} Control nou</button>
        <button class="btn btn-ghost btn-xl" data-act="demo-load">Încarcă date demonstrative</button>
        <a class="btn btn-ghost btn-xl" href="#/ghid">${icon('book')} Ghidul aplicației</a>
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
  const asiPending = asi.length - asiActive.length;
  const netrecute = [];
  cs.forEach((c) => activeNereguli(c).forEach((n) => { if (n.status === 'nok' && !n.inPV) netrecute.push({ c, n }); }));
  const nearestAsi = asiActive[0]?.a.daysLeft;
  // de încărcat (după încheiere): cele cu termenul depășit sau azi, primele
  const deInc = cs.map((c) => ({ c, s: incarcareStatus(c, t) })).filter((x) => x.s && !x.s.gata).sort((x, y) => x.s.daysLeft - y.s.daysLeft);
  const incRosii = deInc.filter((x) => x.s.level === 'red').length;


  const kpis = `<section class="kpis">
    <button class="kpi kpi-fines" data-act="scroll" data-target="sec-fines">
      <span class="kpi-top"><span class="kpi-ic">${icon('fine')}</span><span class="kpi-num">${active.length}</span></span>
      <span class="kpi-label">Amenzi active</span>
      ${active.length ? `<span class="kpi-bar">${['red', 'yellow', 'blue'].map((l) => `<span class="seg seg-${l}" style="flex:${cnt[l]}"></span>`).join('')}</span>` : ''}
      <span class="kpi-legend">${[
        ['red', cnt.red, 'de trimis la ANAF'],
        ['yellow', cnt.yellow, 'cu termen de plată expirat'],
        ['blue', cnt.blue, 'în curs'],
      ].filter(([, n]) => n).map(([l, n, t]) => `<span><i class="dot dot-${l}"></i><b>${n}</b> ${t}</span>`).join('')}</span>
      <span class="kpi-foot">${cnt.green ? `+ ${cnt.green} ${cnt.green === 1 ? 'achitată' : 'achitate'} (nu intră în total)` : active.length ? '' : 'nicio amendă activă'}</span>
    </button>
    <button class="kpi kpi-open" data-act="scroll" data-target="sec-open">
      <span class="kpi-top"><span class="kpi-ic">${icon('clock')}</span><span class="kpi-num">${open.length}</span></span>
      <span class="kpi-label">Controale neîncheiate</span>
      <span class="kpi-foot">${open.length ? `cel mai vechi: ${fmtDate(open[open.length - 1].dataInceput)}` : 'toate sunt încheiate'}</span>
    </button>
    <button class="kpi kpi-asi" data-act="scroll" data-target="sec-asi">
      <span class="kpi-top"><span class="kpi-ic">${icon('hourglass')}</span><span class="kpi-num">${asiActive.length}</span></span>
      <span class="kpi-label">Termene ASI 90 zile</span>
      <span class="kpi-foot">${nearestAsi !== undefined ? (nearestAsi >= 0 ? `cel mai apropiat: ${nearestAsi === 0 ? 'expiră azi' : zile(nearestAsi)}` : `unul depășit cu ${zile(-nearestAsi)}`) : 'niciun termen activ'}${asiPending ? `<br>+ ${asiPending} ${asiPending === 1 ? 'neînceput' : 'neîncepute'} (control neîncheiat)` : ''}</span>
    </button>
    <button class="kpi kpi-inc" data-act="scroll" data-target="sec-inc">
      <span class="kpi-top"><span class="kpi-ic">${icon('upload')}</span><span class="kpi-num">${deInc.length}</span></span>
      <span class="kpi-label">De încărcat</span>
      <span class="kpi-foot">${deInc.length ? (incRosii ? `${incRosii} cu ultima zi azi sau termen depășit` : 'în aplicație și document, în 3 zile lucrătoare') : 'toate controalele încheiate sunt încărcate'}</span>
    </button>
    <button class="kpi kpi-pv" data-act="scroll" data-target="sec-pv">
      <span class="kpi-top"><span class="kpi-ic">${icon('pv')}</span><span class="kpi-num">${netrecute.length}</span></span>
      <span class="kpi-label">Netrecute în PV</span>
      <span class="kpi-foot">${netrecute.length ? 'de completat în procesul-verbal' : 'toate sunt trecute'}</span>
    </button>
  </section>`;

  const fineItem = ({ c, n, st }) => `<a class="item item-${st.level}" href="#/control/${c.id}/${tabOfNeregula(n)}/${encodeURIComponent(n.key)}">
      <span class="item-main">
        <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
        <span class="item-sub">${esc(neregulaLetter(c, n))}. ${esc(constatareLabel(n))}${c.constructii.length > 1 && secOf(n) === 'ner' ? ` · ${esc(constructiiNume(c, n))}` : ''}</span>
        ${amendaSerieNr(n.amenda) ? `<span class="item-sub">Amenda ${esc(amendaSerieNr(n.amenda))}</span>` : ''}
        <span class="item-msg">${esc(st.msg)}</span>
        ${st.nelucr ? `<span class="item-warn">⚠ ${esc(st.nelucr)}</span>` : ''}
        ${vecheInfo(state.controls, c, n).veche ? `<span class="item-veche">${icon('history')} Neregulă veche</span>` : ''}
      </span>
      <span class="item-side">
        ${finePill(st.level, st.label)}
        ${n.amenda.suma ? `<span class="amount">${esc(money(n.amenda.suma))}</span>` : ''}
      </span>
    </a>`;

  const secFines = `<section class="card dash-sec k-fines" id="sec-fines">
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

  const secAsi = `<section class="card dash-sec k-asi" id="sec-asi">
    <h2 class="sec-title">${icon('hourglass')} Termene ASI – 90 de zile</h2>
    ${asi.length ? `<div class="items">${asi.map(({ c, a }) => `<a class="item item-red" href="#/control/${c.id}/nereguli/a">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          ${a.faza === 'pierdere' ? `<span class="item-sub"><b>Constatarea pierderii valabilității</b> (5 zile după cele 90)</span>` : ''}
          <span class="item-msg">${esc(a.msg)}</span>
          ${a.nelucr ? `<span class="item-warn">⚠ ${esc(a.nelucr)}</span>` : ''}
        </span>
        <span class="item-side">${a.pending ? pill('neutral', 'neînceput') : countdown(a.daysLeft)}</span>
      </a>`).join('')}</div>` : '<p class="muted pad">Niciun termen ASI activ.</p>'}
  </section>`;

  const secInc = `<section class="card dash-sec k-inc" id="sec-inc">
    <h2 class="sec-title">${icon('upload')} De încărcat în aplicație</h2>
    ${deInc.length ? `<div class="items">${deInc.map(({ c, s: x }) => `<a class="item item-${x.level === 'red' ? 'red' : 'warn'}" href="#/control/${c.id}/obiectiv/sec-incarcare">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-sub">încheiat ${esc(fmtDateLong(c.dataIncheiere))}</span>
          <span class="chips">${x.lipsa.map((k) => pill(x.level, ucfirst(LIPSA_INCARCARE[k]), 'upload')).join('')}</span>
          <span class="item-msg">${esc(x.msg)}</span>
        </span>
        <span class="item-side">${countdown(x.daysLeft, { lucr: true })}</span>
      </a>`).join('')}</div>` : '<p class="muted pad">Toate controalele încheiate sunt încărcate în aplicație, cu documentul.</p>'}
  </section>`;

  const secOpen = `<section class="card dash-sec k-open" id="sec-open">
    <h2 class="sec-title">${icon('clock')} Controale neîncheiate</h2>
    ${open.length ? `<div class="items">${open.map((c) => {
      const days = diffDays(c.dataInceput, t);
      return `<a class="item item-open" href="#/control/${c.id}/obiectiv">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-sub">${days < 0 ? 'începe' : 'început'} ${esc(fmtDateLong(c.dataInceput))}</span>
          <span class="item-msg">Lipsește data încheierii</span>
        </span>
        <span class="item-side">${(() => { const sig = sigiliiControl(c); return sig ? pill('red', sigiliiText(sig), 'lock') : ''; })()}${pill('open', days < 0 ? `începe peste ${zile(-days)}` : days === 0 ? 'început azi' : days === 1 ? 'început ieri' : `de ${zile(days)}`, 'clock')}</span>
      </a>`;
    }).join('')}</div>` : '<p class="muted pad">Toate controalele sunt încheiate.</p>'}
  </section>`;

  const secPv = `<section class="card dash-sec k-pv" id="sec-pv">
    <h2 class="sec-title">${icon('pv')} Nereguli netrecute în procesul-verbal</h2>
    ${netrecute.length ? `<div class="items">${netrecute.map(({ c, n }) => `<a class="item item-warn" href="#/control/${c.id}/${tabOfNeregula(n)}/${encodeURIComponent(n.key)}">
        <span class="item-main">
          <span class="item-title">${esc(c.denumire || 'Obiectiv fără denumire')}</span>
          <span class="item-sub">${esc(neregulaLetter(c, n))}. ${esc(constatareLabel(n))}</span>
          ${vecheInfo(state.controls, c, n).veche ? `<span class="item-veche">${icon('history')} Neregulă veche</span>` : ''}
        </span>
        <span class="item-side">${pill('warn', 'Netrecut')}</span>
      </a>`).join('')}</div>` : '<p class="muted pad">Toate neregulile constatate sunt trecute în PV.</p>'}
  </section>`;

  const conf = deConfirmat(state.activitati, t);
  const secConf = conf.length ? `<section class="card act-conf" id="sec-act-conf">
    <h2 class="sec-title">${icon('calendar')} Activități de confirmat (${conf.length})</h2>
    <p class="muted">Ziua lor a trecut și sunt încă planificate: marcați-le efectuate, reprogramați-le sau anulați-le. Raportul lunar numără doar activitățile efectuate.</p>
    <div class="act-list">${conf.map((a) => actItem(a, { confirmare: true })).join('')}</div>
  </section>` : '';
  return `${head}${sarbatoriReminder(t)}${secConf}${kpis}<div class="dash-grid">${secFines}${secAsi}${secInc}${secOpen}${secPv}</div>`;
}

// Vechimea ultimului backup (aceeași funcție de backup e disponibilă din Panou, control, bara laterală și Setări)
export function backupAgeDays() {
  const last = state.meta.lastBackup;
  return last ? diffDays(last.slice(0, 10), today()) : null;
}
export function backupIsStale() {
  const d = backupAgeDays();
  return state.controls.length > 0 && (d === null || d >= 7);
}
export function backupAgeText() {
  const d = backupAgeDays();
  if (d === null) return 'niciun backup încă';
  if (d === 0) return `ultimul: azi, ${state.meta.lastBackup.slice(11, 16)}`;
  if (d === 1) return 'ultimul: ieri';
  return `ultimul: acum ${zile(d)}`;
}

const pad = (n) => String(n).padStart(2, '0');

// ───────── Planul lunar: o activitate (Calendar, Panou) ─────────
const PILL_STARE = { planificat: 'open', efectuat: 'green', anulat: 'neutral' };
function actItem(a, { confirmare = false } = {}) {
  const ob = a.objectiveId && objectives(state.controls).find((o) => o.id === a.objectiveId);
  const btn = (act, val, txt, ic, cls = '') => `<button class="chip-btn ${cls}" data-act="${act}" data-id="${a.id}" ${val ? `data-val="${val}"` : ''}>${ic ? icon(ic) : ''}${txt}</button>`;
  return `<div class="act-item act-${a.tip} st-${a.stare}">
    <button class="act-main" data-act="act-edit" data-id="${a.id}">
      <span class="act-tip">${esc(tipLabel(a))}</span>
      <b>${esc(String(a.descriere || '').trim() || tipLabel(a))}</b>
      <small>${esc(cand(a))}${ob ? ` · ${esc(ob.denumire || '')}` : ''}</small>
    </button>
    <span class="act-side">
      ${pill(PILL_STARE[a.stare], STARI_ACTIVITATE[a.stare], a.stare === 'efectuat' ? 'check' : a.stare === 'planificat' ? 'clock' : '')}
      ${a.stare === 'planificat' ? `<span class="act-btns">${btn('act-stare', 'efectuat', 'Efectuată', 'check', 'ok')}${confirmare ? btn('act-reprog', '', 'Reprogramează', 'calendar') : ''}${btn('act-stare', 'anulat', 'Anulată', 'x')}</span>` : ''}
    </span>
  </div>`;
}

// ───────── Sărbătorile legale: verificare anuală ─────────
// Aplicația le calculează singură (date fixe + Paștele ortodox), dar legea se poate schimba (ex. 6–7 ianuarie, din 2024).
// Din 1 decembrie (și în ianuarie, dacă n-a fost confirmată) Panoul cere verificarea listei pentru anul respectiv.
function anSarbatoriDeVerificat(t) {
  const y = +t.slice(0, 4), m = +t.slice(5, 7);
  const an = m === 12 ? y + 1 : m === 1 ? y : null;
  return an && !(state.meta.sarbatoriVerificate || []).includes(an) ? an : null;
}
function listaSarbatori(an) {
  return `<ul class="hol-list">${[...sarbatoriLegale(an)].sort(([a], [b]) => a.localeCompare(b)).map(([d, nume]) => `<li><b>${esc(fmtDateLong(d))}</b> — ${esc(nume)}</li>`).join('')}</ul>`;
}
function sarbatoriReminder(t) {
  const an = anSarbatoriDeVerificat(t);
  if (!an) return '';
  return `<section class="card hol-rem">
    <h2 class="sec-title">${icon('calendar')} Sărbătorile legale pentru ${an}: verificați lista</h2>
    <p>Termenele (plată, ANAF, ASI, încărcare) țin cont de zilele nelucrătoare. Aplicația calculează singură sărbătorile legale pentru ${an}, după art. 139 din Codul muncii. Verificați dacă legea s-a schimbat față de lista de mai jos; dacă da, cereți actualizarea aplicației.</p>
    <details><summary>Lista pentru ${an} (${sarbatoriLegale(an).size} zile)</summary>${listaSarbatori(an)}</details>
    <div class="row-gap"><button class="btn btn-primary btn-lg" data-act="sarbatori-ok" data-an="${an}">${icon('check')} Am verificat lista pentru ${an}</button></div>
  </section>`;
}

// Numărătoarea unui termen, scrisă în clar (zile rămase / ultima zi / peste termen)
function countdown(days, { lucr = false } = {}) {
  const n = Math.abs(days);
  const u = `${n === 1 ? 'zi' : 'zile'}${lucr && days > 0 ? ' lucrătoare' : ''}`;
  return `<span class="countdown ${days <= 0 ? 'over' : ''}"><b>${n}</b><small>${days < 0 ? `${u} peste termen` : days === 0 ? 'ultima zi: azi' : `${u} rămase`}</small></span>`;
}

// ───────────────────────── OBIECTIVE ─────────────────────────

export function viewObjectives() {
  const u = state.ui;
  return `<header class="page-head">
      <div><div class="eyebrow">${icon('building')} Lista obiectivelor controlate</div><h1>Obiective</h1></div>
      <div class="row-gap"><button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button></div>
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
  const baza = objectives(state.controls)
    .filter((o) => u.objTip === 'ALL' || o.tip === u.objTip)
    .map((o) => ({ o, hits: o.controls.filter((c) => matchControl(c, q)) }))
    .filter((x) => x.hits.length || (!parseDateQuery(q) && fold(x.o.denumire).includes(fold(q))));
  const flt = [...u.objFlt].filter((k) => FILTRU[k]);
  const list = baza.filter((x) => obiectivPotrivit(x.o, flt, t));
  const filtre = state.controls.length ? filtreHTML('obj', u.objFlt, (keys) => baza.filter((x) => obiectivPotrivit(x.o, keys, t)).length) : '';
  if (!state.controls.length) {
    return empty('building', 'Niciun obiectiv încă', 'Obiectivele apar aici după primul control.', `<button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button>`);
  }
  if (!list.length) return filtre + empty('search', 'Niciun rezultat', flt.length ? 'Niciun obiectiv nu îndeplinește toate filtrele alese.' : 'Încercați alt nume sau altă dată.');
  return `${filtre}<p class="count">${list.length} ${list.length === 1 ? 'obiectiv' : 'obiective'}${flt.length ? ` · filtre: ${flt.map((k) => FILTRU[k].label).join(' + ')}` : ''}</p>
  <div class="obj-list">${list.map(({ o, hits }) => {
    const open = o.controls.filter((c) => !isIncheiat(c)).length;
    const deInc = o.controls.filter((c) => { const x = incarcareStatus(c, t); return x && !x.gata; }).length;
    const sigUlt = sigiliiControl(o.last);
    // aceleași informații pe care le folosesc filtrele, ca motivul potrivirii să se vadă pe card
    const sts = o.controls.map((c) => controlStats(c, t));
    const peNivel = (lv) => sts.reduce((k, st) => k + st.fines.filter((f) => f.st.level === lv).length, 0);
    const achitate = u.objFlt.has('am-green') ? peNivel('green') : 0;
    const asi = sts.filter((st) => FILTRU.asi.test(null, st)).length;
    const netrec = sts.reduce((k, st) => k + st.netrecute, 0);
    const graveUlt = graveCount(o.last);
    const dateHit = parseDateQuery(q) && hits[0];
    const init = (o.denumire || '?').trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
    return `<a class="obj-card" href="#/obiectiv/${o.id}">
      <span class="avatar ${o.tip === 'LOCALITATE' ? 'av-loc' : 'av-opec'}">${esc(init)}</span>
      <span class="obj-main">
        <span class="obj-title">${esc(o.denumire || 'Obiectiv fără denumire')}</span>
        <span class="obj-sub">${tipBadge(o.tip)}${o.localitate ? `<span>${icon('pin')} ${esc(o.localitate)}</span>` : ''}${o.administrator ? `<span>${esc(o.administrator)}</span>` : ''}${o.telefon ? `<span>· ${esc(o.telefon)}</span>` : ''}</span>
        <span class="chips">
          ${pill('neutral', `${o.controls.length} ${o.controls.length === 1 ? 'control' : 'controale'}`, 'history')}
          ${pill('neutral', `ultimul: ${fmtDate(o.last.dataInceput)}`, 'calendar')}
          ${dateHit ? pill('accent', `găsit: ${rangeText(dateHit)}`, 'search') : ''}
          ${graveUlt ? pill('red', `La ultimul control: ${graveUlt} ${graveUlt === 1 ? 'neregulă gravă' : 'nereguli grave'}`, 'alert') : ''}
          ${sigUlt ? pill('red', `La ultimul control: ${sigiliiText(sigUlt).replace(/^S/, 's')}`, 'lock') : ''}
          ${open ? pill('open', `${open} în desfășurare`, 'clock') : ''}
          ${deInc ? pill('warn', `${deInc} ${deInc === 1 ? 'control neîncărcat' : 'controale neîncărcate'}`, 'upload') : ''}
          ${asi ? pill('red', asi === 1 ? 'ASI în curs' : `ASI în curs la ${asi} controale`, 'hourglass') : ''}
          ${netrec ? pill('warn', `${netrec} ${netrec === 1 ? 'netrecută' : 'netrecute'} în PV`, 'pv') : ''}
          ${['red', 'yellow', 'blue'].map((lv) => { const k = peNivel(lv); return k ? finePill(lv, `${k} ${k === 1 ? 'amendă' : 'amenzi'} · ${LEVEL_LABEL[lv]}`) : ''; }).join('')}
          ${achitate ? finePill('green', `${achitate} ${achitate === 1 ? 'amendă achitată' : 'amenzi achitate'}`) : ''}
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
  const nActive = fines.filter((f) => f.st.level !== 'green').length;
  return `<header class="page-head">
      <div class="head-with-back">
        <a class="icon-btn big" href="#/obiective" aria-label="Înapoi">${icon('back')}</a>
        <div><div class="eyebrow">${tipBadge(o.tip)}</div><h1>${esc(o.denumire || 'Obiectiv fără denumire')}</h1></div>
      </div>
      <div class="row-gap"><button class="btn btn-primary btn-lg" data-act="new-control" data-oid="${o.id}">${icon('plus')} Control nou pe acest obiectiv</button></div>
    </header>
    <section class="card info-grid">
      <div><span class="lbl">Administrator</span><span class="val">${esc(o.administrator || '—')}</span></div>
      <div><span class="lbl">Telefon</span><span class="val">${o.telefon ? `<a href="tel:${esc(o.telefon.replace(/\s/g, ''))}">${icon('phone')} ${esc(o.telefon)}</a>` : '—'}</span></div>
      <div><span class="lbl">Email</span><span class="val">${o.email ? `<a href="mailto:${esc(o.email)}">${icon('mail')} ${esc(o.email)}</a>` : '—'}</span></div>
      <div><span class="lbl">Adresă</span><span class="val">${esc([o.adresa, o.localitate].filter(Boolean).join(', ') || '—')}</span></div>
      <div><span class="lbl">Construcții</span><span class="val">${o.last.constructii.length}</span></div>
      <div class="wide"><span class="lbl">Coordonate GPS pe construcții</span><span class="val gps-list">${o.last.constructii.map((k, i) => {
        const nume = k.denumire || `Construcția ${i + 1}`;
        return `<span>${esc(nume)}: ${k.gps ? `<a href="${esc(googleMapsUrl(k.gps))}" target="_blank" rel="noopener">${icon('pin')} ${esc(fmtCoord(k.gps))}</a> · <a class="small-link" href="${esc(appleMapsUrl(k.gps, `${o.denumire} – ${nume}`))}" target="_blank" rel="noopener">Hărți Apple</a>` : '<span class="muted">necompletate</span>'}</span>`;
      }).join('')}</span></div>
    </section>
    <section class="stat-row">
      <div class="stat"><b>${o.controls.length}</b><span>${o.controls.length === 1 ? 'control' : 'controale'}</span></div>
      <div class="stat"><b>${totalNer}</b><span>${totalNer === 1 ? 'neregulă constatată' : 'nereguli constatate'}</span></div>
      <div class="stat"><b>${fines.length}</b><span>${fines.length === 1 ? 'amendă aplicată' : 'amenzi aplicate'}</span></div>
      <div class="stat"><b>${nActive}</b><span>${nActive === 1 ? 'amendă activă' : 'amenzi active'}</span></div>
    </section>
    <h2 class="list-title">${icon('history')} Istoricul controalelor</h2>
    <div class="timeline">${o.controls.map((c) => `<div class="tl-item">${controlRow(c, { showName: false })}</div>`).join('')}</div>`;
}

// ───────────────────────── ISTORIC ─────────────────────────

export function viewHistory() {
  const u = state.ui;
  return `<header class="page-head">
      <div><div class="eyebrow">${icon('history')} Toate controalele, pe toate obiectivele</div><h1>Istoric controale</h1></div>
      <div class="row-gap"><button class="btn btn-primary btn-lg" data-act="new-control">${icon('plus')} Control nou</button></div>
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
  const t = today();
  const baza = state.controls
    .filter((c) => u.histFilter === 'ALL' || (u.histFilter === 'OPEN' ? !isIncheiat(c) : isIncheiat(c)))
    .filter((c) => matchControl(c, u.histSearch));
  const flt = [...u.histFlt].filter((k) => FILTRU[k]);
  const list = baza.filter((c) => controlPotrivit(c, flt, t)).sort(byStartDesc);
  const filtre = filtreHTML('hist', u.histFlt, (keys) => baza.filter((c) => controlPotrivit(c, keys, t)).length);
  if (!list.length) return filtre + empty('search', 'Niciun rezultat', flt.length ? 'Niciun control nu îndeplinește toate filtrele alese.' : 'Încercați alt nume, altă dată sau alt filtru.');
  const groups = new Map();
  for (const c of list) {
    const k = c.dataInceput.slice(0, 7);
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(c);
  }
  let html = `${filtre}<p class="count">${list.length} ${list.length === 1 ? 'control' : 'controale'}${flt.length ? ` · filtre: ${flt.map((k) => FILTRU[k].label).join(' + ')}` : ''}</p>`;
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
    for (const n of activeNereguli(c)) {
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
    if (a?.termenPierdere && a.termenPierdere >= from && a.termenPierdere <= to) {
      get(a.termenPierdere).deadlines.push({ kind: 'asi2', level: 'red', c, text: 'Termen ASI – constatarea pierderii valabilității' });
    }
    const inc = incarcareStatus(c, t);
    if (inc && !inc.gata && inc.termen >= from && inc.termen <= to) {
      get(inc.termen).deadlines.push({ kind: 'inc', level: 'warn', c, text: 'Termen încărcare în aplicație și document', to: 'obiectiv/sec-incarcare' });
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
    let [s, e] = controlRange(c);
    if (!isIncheiat(c) && t > s) e = t;   // la fel ca în grilă: controlul neîncheiat continuă până azi
    return s <= toISO(new Date(y, m, daysInMonth)) && e >= toISO(first);
  }).length;
  const pre = `${y}-${pad(m + 1)}`;
  const actLuna = state.activitati.filter((a) => a.stare !== 'anulat' && a.data.slice(0, 7) <= pre && (a.dataSfarsit || a.data).slice(0, 7) >= pre).length;

  let cells = '';
  for (let i = 0; i < weeks * 7; i++) {
    const d = addDays(gridStart, i);
    const inMonth = +d.slice(5, 7) === m + 1;
    const ev = data.get(d) || { controls: [], deadlines: [] };
    const acts = activitatiInZi(state.activitati, d).filter((a) => a.stare !== 'anulat');
    const lib = ziLibera(d, t);
    const toate = [...(lib ? [`<span class="cal-ev ev-liber ${lib.sarbatoare ? 'ev-sarb' : ''} st-${lib.stare}">${lib.stare === 'efectuat' ? '✓ ' : ''}${esc(lib.eticheta)}</span>`] : []),
      ...ev.controls.map((c) => `<span class="cal-ev ${isIncheiat(c) ? 'ev-done' : 'ev-open'}">${esc(c.denumire || 'Fără denumire')}</span>`),
      ...acts.map((a) => `<span class="cal-ev ev-act act-${a.tip} st-${a.stare}">${a.stare === 'efectuat' ? '✓ ' : ''}${esc(titluActivitate(a))}</span>`)];
    const shown = toate.slice(0, 3);
    const more = toate.length - shown.length;
    cells += `<button class="cal-cell ${inMonth ? '' : 'out'} ${lib ? 'is-liber' : ''} ${d === t ? 'is-today' : ''} ${d === u.calSelected ? 'is-sel' : ''}" data-act="cal-day" data-date="${d}">
      <span class="cal-num">${+d.slice(8)}</span>
      <span class="cal-evs">${shown.join('')}${more > 0 ? `<span class="cal-more">+${more}</span>` : ''}</span>
      ${ev.deadlines.length ? `<span class="cal-dls">${ev.deadlines.slice(0, 4).map((x) => `<i class="dot dot-${x.level}"></i>`).join('')}</span>` : ''}
    </button>`;
  }

  const sel = u.calSelected;
  const selData = calendarData(sel, sel).get(sel) || { controls: [], deadlines: [] };
  const panel = `<aside class="card day-panel">
    <div class="day-head">
      <div><div class="eyebrow">${sel === t ? 'Astăzi' : 'Ziua selectată'}</div><h2>${esc(ucfirst(fmtDateLong(sel)))}</h2></div>
    </div>
    ${(() => { const z = ziLibera(sel, t); return z ? `<div class="liber-note ${z.sarbatoare ? 'ev-sarb' : ''}"><b>${esc(eticheteLibera(z))}</b>${pill(PILL_STARE[z.stare], STARI_ACTIVITATE[z.stare], z.stare === 'efectuat' ? 'check' : 'clock')}</div>` : ''; })()}
    ${selData.controls.length ? `<div class="ctl-list">${selData.controls.map((c) => controlRow(c)).join('')}</div>` : '<p class="muted pad">Niciun control în această zi.</p>'}
    ${selData.deadlines.length ? `<h3 class="mini-title">Termene</h3><div class="items">${selData.deadlines.map((x) => `<a class="item item-${x.level}" href="#/control/${x.c.id}/${x.to || `${x.n ? tabOfNeregula(x.n) : 'nereguli'}/${encodeURIComponent(x.n ? x.n.key : 'a')}`}">
        <span class="item-main"><span class="item-title">${esc(x.text)}</span><span class="item-sub">${esc(x.c.denumire)}${x.n ? ` · ${esc(neregulaLetter(x.c, x.n))}. ${esc(constatareLabel(x.n))}` : ''}</span></span>
      </a>`).join('')}</div>` : ''}
    ${(() => { const al = activitatiInZi(state.activitati, sel); return al.length ? `<h3 class="mini-title">Activități</h3><div class="act-list">${al.map((a) => actItem(a)).join('')}</div>` : '<p class="muted pad">Nicio activitate în această zi.</p>'; })()}
    <button class="btn btn-primary btn-lg btn-block" data-act="new-control" data-date="${sel}">${icon('plus')} Control nou în această zi</button>
    <button class="btn btn-ghost btn-lg btn-block" data-act="act-new" data-date="${sel}">${icon('plus')} Activitate nouă în această zi</button>
  </aside>`;

  return `<header class="page-head">
      <div><div class="eyebrow">${icon('calendar')} ${monthCount} ${monthCount === 1 ? 'control' : 'controale'} și ${actLuna} ${actLuna === 1 ? 'activitate' : 'activități'} în această lună</div><h1 class="cap">${MONTHS[m]} ${y}</h1></div>
      <div class="row-gap cal-nav">
        <div class="stepper cal-step" aria-label="Anul">
          <button class="step-btn" data-act="cal-year-prev" aria-label="Anul anterior">${icon('chevL')}</button>
          <span class="step-val"><b>${y}</b><small>anul</small></span>
          <button class="step-btn" data-act="cal-year-next" aria-label="Anul următor">${icon('chevR')}</button>
        </div>
        <div class="stepper cal-step" aria-label="Luna">
          <button class="step-btn" data-act="cal-prev" aria-label="Luna anterioară">${icon('chevL')}</button>
          <span class="step-val"><b class="cap">${MONTHS_SHORT[m]}</b><small>luna</small></span>
          <button class="step-btn" data-act="cal-next" aria-label="Luna următoare">${icon('chevR')}</button>
        </div>
        <button class="btn btn-ghost btn-lg" data-act="cal-today">Azi</button>
        <a class="btn btn-primary btn-lg" href="#/luna/${pre}">${icon('list')} Plan lunar</a>
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
          <span><i class="dot dot-warn"></i>termen încărcare</span>
          <span><i class="sw sw-act"></i>activitate (culoarea tipului)</span>
          <span><i class="sw sw-liber"></i>zi liberă „Liber”: weekend / sărbătoare legală (✓ = efectuată)</span>
        </div>
      </div>
      ${panel}
    </div>`;
}

// ───────────────────────── PLAN LUNAR (raport) ─────────────────────────
export function viewLuna(id) {
  const [an, lu] = id.split('-').map(Number);
  const luna = lu - 1;
  const r = raportLunar(state.controls, state.activitati, an, luna, today());
  const nav = (d) => { const x = new Date(an, luna + d, 1); return `${x.getFullYear()}-${pad(x.getMonth() + 1)}`; };
  return `<div class="fisa-page">
    <header class="page-head fisa-actions">
      <div class="head-with-back">
        <a class="icon-btn big" href="#/calendar" aria-label="Înapoi la calendar">${icon('back')}</a>
        <div><div class="eyebrow">${icon('calendar')} Tot ce s-a planificat și efectuat în lună</div><h1>Plan lunar</h1></div>
      </div>
      <div class="row-gap">
        <div class="stepper cal-step" aria-label="Luna">
          <a class="step-btn" href="#/luna/${nav(-1)}" aria-label="Luna anterioară">${icon('chevL')}</a>
          <span class="step-val"><b class="cap">${MONTHS_SHORT[luna]}</b><small>${an}</small></span>
          <a class="step-btn" href="#/luna/${nav(1)}" aria-label="Luna următoare">${icon('chevR')}</a>
        </div>
        <button class="btn btn-primary btn-lg" data-act="raport-print">${icon('download')} Tipărește / PDF</button>
        <button class="btn btn-ghost btn-lg" data-act="raport-share" data-an="${an}" data-luna="${luna}">${icon('upload')} Partajează fișierul</button>
      </div>
    </header>
    <p class="muted fisa-hint">Pentru PDF: <b>Tipărește / PDF</b> → în fereastra de tipărire, butonul Partajare → <b>Salvează în Fișiere</b>. Dacă tipărirea nu pornește, folosiți <b>Partajează fișierul</b>.</p>
    <style>${FISA_CSS}${RAPORT_CSS}</style>
    <article class="fisa-doc card">${raportMarkup(r, state.controls)}</article>
  </div>`;
}

// ───────────────────────── SETĂRI ─────────────────────────

const THEMES = [
  { key: 'auto', label: 'Automat', hint: 'ca iPad-ul', ic: 'contrast' },
  { key: 'light', label: 'Luminoasă', hint: 'mereu', ic: 'sun' },
  { key: 'dark', label: 'Întunecată', hint: 'mereu', ic: 'moon' },
];
const currentTheme = () => document.documentElement.dataset.theme || 'auto';

export function viewSettings(persisted) {
  const last = state.meta.lastBackup;
  const demo = state.controls.filter((c) => c.demo).length;
  return `<header class="page-head"><div><div class="eyebrow">${icon('settings')} Date, backup și informații</div><h1>Setări</h1></div>
    <div class="row-gap"><a class="btn btn-primary btn-lg" href="#/ghid">${icon('book')} Ghidul aplicației</a></div></header>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('settings')} Mărimea textului</h2>
    <p>Se aplică imediat în toată aplicația: text, butoane, spațieri și iconițe se ajustează împreună.</p>
    <div class="font-opts" role="radiogroup" aria-label="Mărimea textului">
      ${FONT_SIZES.map((f) => `<button class="font-opt ${currentFont() === f.key ? 'on' : ''}" data-act="font-size" data-val="${f.key}" role="radio" aria-checked="${currentFont() === f.key}">
        <span class="aa" style="font-size:${f.px + 8}px">Aa</span><span>${f.label}</span><small>${f.hint}</small>
      </button>`).join('')}
    </div>
  </section>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('moon')} Tema</h2>
    <p><b>Automat</b> urmează iPad-ul (Setări → Afișaj și luminozitate): luminoasă ziua, întunecată seara, dacă așa e setat. Sau alegeți una fixă.</p>
    <div class="font-opts" role="radiogroup" aria-label="Tema">
      ${THEMES.map((t) => `<button class="font-opt theme-opt ${currentTheme() === t.key ? 'on' : ''}" data-act="theme" data-val="${t.key}" role="radio" aria-checked="${currentTheme() === t.key}">
        <span class="aa">${icon(t.ic)}</span><span>${t.label}</span><small>${t.hint}</small>
      </button>`).join('')}
    </div>
  </section>
  <section class="card set-sec">
    <h2 class="sec-title">${icon('download')} Backup</h2>
    <p>Butonul <b>Backup rapid</b> din Panou, din bara laterală și din fiecare control face exact același export ca butonul de aici. Datele sunt salvate <b>doar pe această tabletă</b>. Exportă periodic un fișier de backup și salvează-l în <b>Fișiere → iCloud Drive</b> (sau alt loc sigur).</p>
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
        <span class="rule-row"><i class="dot dot-red"></i> din ziua 40: „Mai aveți 5 zile până să o trimiteți la ANAF” (termen: ziua 45)</span>
        <span class="rule-row"><i class="dot dot-green"></i> achitată, cu dovadă primită</span></li>
      <li><b>ASI:</b> 90 de zile de la data încheierii controlului; dacă documentația nu a fost prezentată, încă 5 zile calendaristice pentru constatarea pierderii valabilității.</li>
      <li><b>Încărcarea</b> în aplicația ISU și a documentului: 3 zile lucrătoare de la data încheierii.</li>
      <li>Termenele care cad într-o zi nelucrătoare (weekend sau sărbătoare legală) <b>nu se mută automat</b>; aplicația vă avertizează și vă recomandă următoarea zi lucrătoare; verificați prelungirea.</li>
    </ul>
  </section>
  <section class="card set-sec" id="sarbatori">
    <h2 class="sec-title">${icon('calendar')} Sărbători legale</h2>
    <p>Calculate automat (datele fixe și Paștele ortodox), după art. 139 din Codul muncii. Dacă legea se schimbă, aplicația trebuie actualizată; în decembrie, Panoul vă cere să verificați lista pentru anul următor.</p>
    ${[+today().slice(0, 4), +today().slice(0, 4) + 1].map((an) => `<details><summary>${an} — ${sarbatoriLegale(an).size} zile${(state.meta.sarbatoriVerificate || []).includes(an) ? ' · verificată' : ''}</summary>${listaSarbatori(an)}
      ${(state.meta.sarbatoriVerificate || []).includes(an) ? '' : `<button class="btn btn-ghost" data-act="sarbatori-ok" data-an="${an}">${icon('check')} Am verificat lista pentru ${an}</button>`}</details>`).join('')}
  </section>
  <section class="card set-sec danger-zone">
    <h2 class="sec-title">${icon('trash')} Zonă periculoasă</h2>
    <p>Șterge definitiv toate controalele de pe această tabletă. Faceți întâi un backup.</p>
    <button class="btn btn-danger btn-lg" data-act="wipe">Șterge toate datele</button>
  </section>
  <p class="muted center">Agenda inspectorului · v${APP_VERSION} · funcționează offline</p>`;
}

// ───────────────────────── GHIDUL APLICAȚIEI ─────────────────────────
// Manualul: cuprins, căutare în text, capitole cu butoanele desenate ca în aplicație.
export function viewGhid() {
  const q = fold(state.ui.ghidQuery || '').trim();
  const bloc = (b) => (b.p ? `<p>${b.p}</p>`
    : b.h ? `<h3 class="m-sub">${b.h}</h3>`
      : b.ol ? `<ol class="m-steps">${b.ol.map((x) => `<li>${x}</li>`).join('')}</ol>`
        : b.ul ? `<ul>${b.ul.map((x) => `<li>${x}</li>`).join('')}</ul>`
          : b.note ? `<p class="m-note">${icon('info')}<span>${b.note}</span></p>`
            : b.btns ? `<dl class="m-btns">${b.btns.map(([btn, t]) => `<div><dt>${btn}</dt><dd>${t}</dd></div>`).join('')}</dl>` : '');
  const text = (cap) => fold(`${cap.title} ${cap.blocks.map((b) => [b.p, b.h, b.note, ...(b.ul || []), ...(b.ol || []), ...(b.btns || []).flat()].join(' ')).join(' ')}`.replace(/<[^>]+>/g, ' '));
  const caps = MANUAL.filter((cap) => !q || q.split(/\s+/).every((w) => text(cap).includes(w)));
  return `<header class="page-head">
      <div><div class="eyebrow">${icon('book')} Manualul aplicației · v${esc(APP_VERSION)}</div><h1>Ghidul aplicației</h1></div>
      <div class="row-gap"><button class="btn btn-ghost btn-lg" data-act="ghid-back">${icon('back')} Înapoi</button></div>
    </header>
    <div class="searchbar">
      ${icon('search')}
      <input type="search" data-search="ghid" value="${esc(state.ui.ghidQuery || '')}" placeholder="Caută în ghid (ex. sigiliu, amendă, GPS, verificări)" autocomplete="off" enterkeyhint="search">
      ${state.ui.ghidQuery ? '<button class="icon-btn" data-act="search-clear" data-key="ghid" aria-label="Șterge căutarea">' + icon('x') + '</button>' : ''}
    </div>
    <nav class="m-toc card" aria-label="Cuprins">
      ${MANUAL.map((cap) => `<a href="#/ghid/${cap.id}" class="m-toc-item ${caps.includes(cap) ? '' : 'is-off'}">${icon(cap.ic)}<span>${esc(cap.title)}</span></a>`).join('')}
    </nav>
    <div id="ghid-list">${caps.map((cap) => `<section class="card m-cap" id="ghid-${cap.id}">
      <h2 class="sec-title">${icon(cap.ic)} ${esc(cap.title)}</h2>
      ${cap.blocks.map(bloc).join('')}
    </section>`).join('') || empty('search', 'Nimic găsit în ghid', 'Încercați alt cuvânt.')}</div>`;
}
