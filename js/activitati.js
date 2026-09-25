// Activitățile din planul lunar (altele decât controalele): instruiri, ședințe, birou, concediu etc.
// Se păstrează pe tabletă (meta „activitati”), intră în backup; raportul lunar le adună alături de controale.
import { fmtDate, fmtDateLong, isISO, todayISO, addDays, MONTHS, sarbatoriLegale, zinelucratoare, ucfirst } from './dates.js';
import { activeNereguli, fineDate, isIncheiat, controlStats, uid, byStartDesc, objectives, parseSuma } from './model.js';
import { esc } from './ui.js';

export const TIPURI_ACTIVITATE = [
  { key: 'instruire', label: 'Instruire / pregătire' },
  { key: 'sedinta', label: 'Ședință' },
  { key: 'birou', label: 'Activitate de birou' },
  { key: 'informare', label: 'Informare publică' },
  { key: 'exercitiu', label: 'Exercițiu / aplicație' },
  { key: 'concediu', label: 'Concediu / liber' },
  { key: 'alta', label: 'Altă activitate' },
];
const TIP = Object.fromEntries(TIPURI_ACTIVITATE.map((t) => [t.key, t]));
export const STARI_ACTIVITATE = { planificat: 'Planificată', efectuat: 'Efectuată', anulat: 'Anulată' };

// Activitate nouă: implicit efectuată dacă ziua a trecut, altfel planificată
export function emptyActivitate(data = todayISO(), today = todayISO()) {
  const acum = new Date().toISOString();
  return {
    id: uid(), tip: 'instruire', data, dataSfarsit: '', ora: '', descriere: '',
    stare: data < today ? 'efectuat' : 'planificat', obs: '', objectiveId: '', createdAt: acum, updatedAt: acum,
  };
}

export function normalizeActivitate(a) {
  const out = { ...emptyActivitate(a?.data || todayISO()), ...a };
  if (!TIP[out.tip]) out.tip = 'alta';
  if (!STARI_ACTIVITATE[out.stare]) out.stare = 'planificat';
  if (!isISO(out.dataSfarsit) || out.dataSfarsit <= out.data) out.dataSfarsit = '';
  return out;
}

export const sfarsitActivitate = (a) => a.dataSfarsit || a.data;
export const zileActivitate = (a) => {
  let n = 1;
  for (let d = a.data; d < sfarsitActivitate(a); d = addDays(d, 1)) n++;
  return n;
};
export const tipLabel = (a) => TIP[a.tip]?.label || 'Altă activitate';
// Titlul afișat: „Ședință: analiza lunară”; la „Altă activitate”, doar descrierea
export function titluActivitate(a) {
  const d = String(a.descriere || '').trim();
  if (a.tip === 'alta') return d || 'Altă activitate';
  return d ? `${tipLabel(a)}: ${d}` : tipLabel(a);
}
export function cand(a) {
  const per = a.dataSfarsit ? `${fmtDate(a.data)} – ${fmtDate(a.dataSfarsit)} (${zileActivitate(a)} zile)` : fmtDate(a.data);
  return a.ora ? `${per}, ora ${a.ora}` : per;
}

// Activitățile dintr-o zi (cele pe mai multe zile apar în fiecare zi)
export const activitatiInZi = (list, d) => list.filter((a) => a.data <= d && sfarsitActivitate(a) >= d)
  .sort((x, y) => (x.ora || '99').localeCompare(y.ora || '99') || x.createdAt.localeCompare(y.createdAt));

// Planificate a căror (ultimă) zi a trecut: de confirmat (efectuată / reprogramată / anulată)
export const deConfirmat = (list, today = todayISO()) => list
  .filter((a) => a.stare === 'planificat' && sfarsitActivitate(a) < today)
  .sort((x, y) => x.data.localeCompare(y.data));

// Zilele libere (weekend + sărbători legale) apar implicit în plan, fără introducere manuală:
// efectuate până azi inclusiv, planificate după. null pentru zilele lucrătoare.
// În celula calendarului: numele scurte, ca să încapă întregi (numele complet apare la ziua selectată și în raport)
const SARB_SCURT = {
  'Sfântul Ioan Botezătorul': 'Sf. Ioan', 'a doua zi de Paște': 'Paște (ziua 2)', 'a doua zi de Rusalii': 'Rusalii (ziua 2)',
  'Adormirea Maicii Domnului': 'Sf. Maria', 'Sfântul Andrei': 'Sf. Andrei', 'a doua zi de Crăciun': 'Crăciun (ziua 2)',
};
const scurt = (nume) => nume.split(' / ').map((x) => SARB_SCURT[x] || x).join(' / ');
export function ziLibera(d, today = todayISO()) {
  const motiv = zinelucratoare(d);
  if (!motiv) return null;
  const sarbatoare = sarbatoriLegale(+d.slice(0, 4)).get(d) || '';
  return { d, motiv, sarbatoare, eticheta: sarbatoare ? ucfirst(scurt(sarbatoare)) : 'Liber', stare: d <= today ? 'efectuat' : 'planificat' };
}
export const eticheteLibera = (z) => (z.sarbatoare ? `Sărbătoare legală: ${ucfirst(z.sarbatoare)}` : `Zi liberă (${z.motiv})`);

const suma = (v) => parseSuma(v) ?? 0;
export const lei = (n) => `${n.toLocaleString('ro-RO', { maximumFractionDigits: 2 })} lei`;

// Raportul lunii: controalele începute în lună, amenzile aplicate în lună (după data aplicării),
// activitățile din lună, pe tipuri și pe stări; lista zi cu zi.
export function raportLunar(controls, activitati, an, luna, today = todayISO()) {
  const pre = `${an}-${String(luna + 1).padStart(2, '0')}`;
  const inLuna = (d) => isISO(d) && d.slice(0, 7) === pre;
  const ctl = controls.filter((c) => inLuna(c.dataInceput)).sort((a, b) => -byStartDesc(a, b));
  const constatate = ctl.reduce((s, c) => s + controlStats(c, today).constatate, 0);
  const amenzi = [];
  let faraData = 0;
  for (const c of controls) {
    for (const n of activeNereguli(c)) {
      if (n.status !== 'nok' || !n.amenda?.aplicata) continue;
      const d = fineDate(c, n);
      if (inLuna(d)) amenzi.push({ c, n, data: d, suma: suma(n.amenda.suma) });
      else if (!d && inLuna(c.dataInceput)) faraData++;
    }
  }
  const act = activitati.filter((a) => a.data.slice(0, 7) <= pre && sfarsitActivitate(a).slice(0, 7) >= pre);
  const peTipuri = TIPURI_ACTIVITATE.map((t) => {
    const ef = act.filter((a) => a.tip === t.key && a.stare === 'efectuat');
    return { ...t, n: ef.length, zile: ef.reduce((s, a) => s + zileInLuna(a, pre), 0) };
  }).filter((t) => t.n);
  const zile = new Map();
  const zi = (d) => { if (!zile.has(d)) zile.set(d, { controale: [], activitati: [] }); return zile.get(d); };
  ctl.forEach((c) => zi(c.dataInceput).controale.push(c));
  act.forEach((a) => zi(a.data.slice(0, 7) === pre ? a.data : `${pre}-01`).activitati.push(a));
  const libere = [];
  const zileLuna = new Date(an, luna + 1, 0).getDate();
  for (let k = 1; k <= zileLuna; k++) {
    const z = ziLibera(`${pre}-${String(k).padStart(2, '0')}`, today);
    if (!z) continue;
    // lucrată = în ziua liberă a început un control sau s-a efectuat o activitate (alta decât concediul)
    z.lucrata = ctl.some((c) => c.dataInceput === z.d)
      || act.some((a) => a.stare === 'efectuat' && a.tip !== 'concediu' && a.data <= z.d && sfarsitActivitate(a) >= z.d);
    libere.push(z);
  }
  return {
    an, luna, titlu: `${MONTHS[luna][0].toUpperCase()}${MONTHS[luna].slice(1)} ${an}`,
    controale: ctl, incheiate: ctl.filter(isIncheiat).length, constatate,
    amenzi, sumaAmenzi: amenzi.reduce((s, x) => s + x.suma, 0), amenziFaraData: faraData,
    efectuate: act.filter((a) => a.stare === 'efectuat'), planificate: act.filter((a) => a.stare === 'planificat'),
    anulate: act.filter((a) => a.stare === 'anulat'), peTipuri,
    libere, zileLuna, lucratoare: zileLuna - libere.length,
    zile: [...zile.entries()].sort(([a], [b]) => a.localeCompare(b)),
  };
}
function zileInLuna(a, pre) {
  let n = 0;
  for (let d = a.data; d <= sfarsitActivitate(a); d = addDays(d, 1)) if (d.slice(0, 7) === pre) n++;
  return n;
}

// Raportul, în același stil ca Fișa controlului (tipărire / PDF / partajare)
export function raportMarkup(r, controls, now = new Date()) {
  const obNume = new Map(objectives(controls).map((o) => [o.id, o.denumire]));
  const h = [];
  h.push(`<header class="f-head">
    <div class="f-kicker">Plan lunar · raport de activitate</div>
    <h1>${esc(r.titlu)}</h1>
    <div class="f-meta"><span><b>Generat:</b> ${esc(fmtDateLong(todayISO(now)))}</span></div>
    <div class="f-sum f-sum-6">
      <div><b>${r.controale.length}</b><span>${r.controale.length === 1 ? 'control început' : 'controale începute'} (${r.incheiate} ${r.incheiate === 1 ? 'încheiat' : 'încheiate'})</span></div>
      <div><b>${r.constatate}</b><span>${r.constatate === 1 ? 'neregulă constatată' : 'nereguli constatate'}</span></div>
      <div><b>${r.amenzi.length}</b><span>${r.amenzi.length === 1 ? 'amendă aplicată' : 'amenzi aplicate'}${r.amenzi.length ? ` · ${esc(lei(r.sumaAmenzi))}` : ''}</span></div>
      <div><b>${r.efectuate.length}</b><span>${r.efectuate.length === 1 ? 'activitate efectuată' : 'activități efectuate'}</span></div>
      <div><b>${r.planificate.length}</b><span>${r.planificate.length === 1 ? 'activitate planificată' : 'activități planificate'} (neconfirmate)</span></div>
      <div><b>${r.libere.length}</b><span>${r.libere.length === 1 ? 'zi liberă' : 'zile libere'} (${r.lucratoare} lucrătoare)</span></div>
    </div>
  </header>`);
  if (r.peTipuri.length) {
    h.push(`<section><h2>Activități efectuate, pe tipuri</h2><table class="f-table"><thead><tr><th>Tip</th><th>Activități</th><th>Zile</th></tr></thead><tbody>
      ${r.peTipuri.map((t) => `<tr><td>${esc(t.label)}</td><td>${t.n}</td><td>${t.zile}</td></tr>`).join('')}</tbody></table></section>`);
  }
  if (r.libere.length) {
    const sarb = r.libere.filter((z) => z.sarbatoare);
    const ef = r.libere.filter((z) => z.stare === 'efectuat').length;
    const lucrate = r.libere.filter((z) => z.lucrata);
    h.push(`<section><h2>Zile libere</h2><table class="f-table"><thead><tr><th></th><th>Zile</th></tr></thead><tbody>
      <tr><td>Weekend (fără sărbătorile căzute în weekend)</td><td>${r.libere.length - sarb.length}</td></tr>
      <tr><td>Sărbători legale${sarb.length ? `: ${esc(sarb.map((z) => `${z.sarbatoare} (${fmtDate(z.d)})`).join(', '))}` : ''}</td><td>${sarb.length}</td></tr>
      <tr><td>Efectuate (până azi)</td><td>${ef}</td></tr>
      <tr><td>Planificate</td><td>${r.libere.length - ef}</td></tr>
      <tr><td><b>Zile lucrătoare în lună</b></td><td><b>${r.lucratoare}</b></td></tr></tbody></table>
      ${lucrate.length ? `<p>Zile libere în care s-a lucrat (control început sau activitate efectuată): ${esc(lucrate.map((z) => fmtDate(z.d)).join(', '))}.</p>` : ''}</section>`);
  }
  h.push('<section><h2>Zi cu zi</h2>');
  if (!r.zile.length) h.push('<p>Niciun control și nicio activitate în această lună.</p>');
  for (const [d, x] of r.zile) {
    h.push(`<h3>${esc(fmtDateLong(d))}</h3><ul class="f-list">`);
    for (const c of x.controale) {
      const st = controlStats(c, todayISO(now));
      h.push(`<li><b>Control: ${esc(c.denumire || 'Obiectiv fără denumire')}</b> — ${isIncheiat(c) ? `încheiat ${esc(fmtDate(c.dataIncheiere))}` : 'în desfășurare'}; ${st.constatate} ${st.constatate === 1 ? 'neregulă constatată' : 'nereguli constatate'}${st.fines.length ? `; ${st.fines.length} ${st.fines.length === 1 ? 'amendă' : 'amenzi'}` : ''}</li>`);
    }
    for (const a of x.activitati) {
      const ob = a.objectiveId && obNume.get(a.objectiveId);
      h.push(`<li><b>${esc(titluActivitate(a))}</b> — ${esc(cand(a))}${ob ? ` · ${esc(ob)}` : ''} · <i>${esc(STARI_ACTIVITATE[a.stare])}</i>${a.obs?.trim() ? `<br>${esc(a.obs.trim())}` : ''}</li>`);
    }
    h.push('</ul>');
  }
  h.push('</section>');
  if (r.amenzi.length || r.amenziFaraData) {
    h.push(`<section><h2>Amenzi aplicate în lună</h2>${r.amenzi.length ? `<table class="f-table"><thead><tr><th>Data</th><th>Obiectiv</th><th>Seria și nr.</th><th>Suma</th></tr></thead><tbody>
      ${r.amenzi.sort((a, b) => a.data.localeCompare(b.data)).map((x) => `<tr><td>${esc(fmtDate(x.data))}</td><td>${esc(x.c.denumire || '')}</td><td>${esc(x.n.amenda.serieNr || '—')}</td><td>${x.suma ? esc(lei(x.suma)) : '—'}</td></tr>`).join('')}</tbody></table>` : ''}
      ${r.amenziFaraData ? `<p>+ ${r.amenziFaraData} ${r.amenziFaraData === 1 ? 'amendă' : 'amenzi'} din controale neîncheiate, fără data aplicării (nu sunt numărate mai sus).</p>` : ''}</section>`);
  }
  if (r.anulate.length) h.push(`<section><h2>Activități anulate</h2><ul class="f-list">${r.anulate.map((a) => `<li>${esc(titluActivitate(a))} — ${esc(cand(a))}</li>`).join('')}</ul></section>`);
  return h.join('');
}

export const RAPORT_CSS = `
.fisa-doc .f-list { margin: 0 0 6pt; padding-left: 14pt; }
.fisa-doc .f-list li { margin: 2pt 0; }
.fisa-doc .f-sum.f-sum-6 { grid-template-columns: repeat(3, 1fr) !important; }
`;

export function raportDocument(r, controls, fisaCss) {
  return `<!doctype html><html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Plan lunar – ${esc(r.titlu)}</title>
<style>@page { size: A4; margin: 14mm; } body { margin: 0; padding: 16px; } ${fisaCss} ${RAPORT_CSS}</style></head>
<body><div class="fisa-doc">${raportMarkup(r, controls)}</div></body></html>`;
}
export const raportFileName = (r) => `Plan-lunar-${r.an}-${String(r.luna + 1).padStart(2, '0')}.html`;
