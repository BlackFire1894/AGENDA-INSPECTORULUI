// Fișa controlului: rezumat complet, tipăribil (PDF din dialogul de tipărire) sau partajabil ca fișier.
import { fmtDate, fmtDateLong, todayISO, isISO } from './dates.js';
import {
  DOTARI, ACTE, SECTIUNI, CATEGORII, sectiuniActive, secOf, neregulaLetter, neregulaCat,
  constructiiNume, amendaSerieNr, fineStatus, asiDeadline, vecheInfo, isIncheiat, controlStats, isLocalitate, constatareLabel,
  sablon, isGrav, isApplicable, fmtCoord, isVerificare, verifStare, constructiiEligibile, grfText, grfVPesteParter, googleMapsUrl,
} from './model.js';
import { esc } from './ui.js';

const STATUS = { ok: 'Conform', nok: 'Neconform', nec: 'NEC (nu este cazul)' };

function money(v) {
  const n = Number(String(v).replace(',', '.'));
  return v && !Number.isNaN(n) ? `${n.toLocaleString('ro-RO', { maximumFractionDigits: 2 })} lei` : '';
}

const obs = (t) => (t && t.trim() ? esc(t.trim()).replace(/\n/g, '<br>') : '');

export function fisaMarkup(c, controls, now = new Date()) {
  const today = todayISO(now);
  const st = controlStats(c, today);
  const multe = c.constructii.length > 1;
  const perioada = isIncheiat(c)
    ? (c.dataIncheiere === c.dataInceput ? fmtDate(c.dataInceput) : `${fmtDate(c.dataInceput)} – ${fmtDate(c.dataIncheiere)}`)
    : `din ${fmtDate(c.dataInceput)} (în desfășurare)`;
  const vechi = c.nereguli.filter((n) => sectiuniActive(c).includes(secOf(n)) && vecheInfo(controls, c, n).veche).length;

  const h = [];
  h.push(`<header class="f-head">
    <div class="f-kicker">Fișa controlului</div>
    <h1>${esc(c.denumire || 'Obiectiv fără denumire')}</h1>
    <div class="f-meta">
      <span><b>Tip:</b> ${c.tip === 'LOCALITATE' ? 'Localitate' : 'OPEC / Instituție'}</span>
      <span><b>Perioada:</b> ${esc(perioada)}</span>
      ${c.administrator ? `<span><b>Administrator:</b> ${esc(c.administrator)}</span>` : ''}
      ${c.telefon ? `<span><b>Telefon:</b> ${esc(c.telefon)}</span>` : ''}
      ${c.email ? `<span><b>Email:</b> ${esc(c.email)}</span>` : ''}
      ${c.adresa || c.localitate ? `<span><b>Adresă:</b> ${esc([c.adresa, c.localitate].filter(Boolean).join(', '))}</span>` : ''}
    </div>
    <div class="f-sum">
      <div><b>${st.constatate}</b><span>nereguli / neconformități</span></div>
      <div><b>${st.netrecute}</b><span>netrecute în PV</span></div>
      <div><b>${st.fines.length}</b><span>amenzi</span></div>
      <div><b>${vechi}</b><span>nereguli vechi</span></div>
      <div><b>${st.acteNok}</b><span>acte lipsă</span></div>
    </div>
  </header>`);

  // Construcții
  h.push(`<section><h2>Construcții (${c.constructii.length})</h2>`);
  c.constructii.forEach((k, i) => {
    const by = { DA: [], NU: [], NEC: [] };
    for (const d of DOTARI) {
      if (d.centrala) continue;
      const v = k.dotari[d.key]?.v;
      if (by[v]) by[v].push(d.label);
    }
    const ct = k.dotari.centrala;
    const centrala = ct?.nuAre ? 'nu are' : (ct?.tipuri || []).join(', ');
    h.push(`<div class="f-constr">
      <h3>${i + 1}. ${esc(k.denumire || `Construcția ${i + 1}`)}</h3>
      <table class="f-kv"><tr>
        <td><b>Suprafață desf.</b><br>${k.suprafata ? `${esc(k.suprafata)} m²` : '—'}</td>
        <td><b>Regim înălțime</b><br>${esc(k.regimInaltime) || '—'}</td>
        <td><b>GRF / NSI</b><br>${esc(grfText(k.grf)) || '—'}${grfVPesteParter(k) ? '<br><b>neregulă gravă</b>' : ''}</td>
        <td><b>Nr. angajați</b><br>${esc(k.nrAngajati) || '—'}</td>
        <td><b>Anul construirii</b><br>${esc(k.anConstruire) || '—'}</td>
        <td><b>Structură</b><br>${esc(k.structura) || '—'}</td>
        <td><b>Pereți</b><br>${esc(k.materialPereti) || '—'}</td>
      </tr></table>
      <p class="f-dot"><b>Coordonate GPS:</b> ${k.gps ? `<a href="${esc(googleMapsUrl(k.gps))}">${esc(fmtCoord(k.gps))}</a> (± ${Math.round(k.gps.acc)} m)` : 'necompletate'}</p>
      ${['asi', 'aviz'].filter((d) => k.dotari[d]?.v === 'DA' && k.dotari[d].nr?.trim()).map((d) => `<p class="f-dot"><b>${d === 'asi' ? 'Nr. autorizație (ASI)' : 'Nr. aviz'}:</b> ${esc(k.dotari[d].nr)}</p>`).join('')}
      <p class="f-dot"><b>DA:</b> ${esc(by.DA.join(', ')) || '—'}${centrala ? ` · <b>Centrală termică:</b> ${esc(centrala)}` : ''}</p>
      <p class="f-dot"><b>NU:</b> ${esc(by.NU.join(', ')) || '—'} · <b>NEC:</b> ${esc(by.NEC.join(', ')) || '—'}</p>
      ${DOTARI.filter((d) => k.dotari[d.key]?.obs?.trim()).map((d) => `<p class="f-dot f-small"><b>${esc(d.label)}:</b> ${obs(k.dotari[d.key].obs)}</p>`).join('')}
    </div>`);
  });
  h.push('</section>');

  // Acte
  h.push(`<section><h2>Acte de autoritate și evidențe</h2><table class="f-table">
    <thead><tr><th>#</th><th>Act / evidență</th><th>Situație</th><th>Observații</th></tr></thead><tbody>
    ${ACTE.map((a, i) => { const v = c.acte[a.key] || {}; return `<tr class="${v.status === 'nok' ? 'f-nok' : ''}">
      <td>${i + 1}</td><td>${esc(a.label)}</td><td>${v.status === 'ok' ? 'Prezentat' : v.status === 'nok' ? 'Lipsă' : '—'}</td><td>${obs(v.obs)}</td></tr>`; }).join('')}
  </tbody></table></section>`);

  // Secțiuni de constatări
  for (const sec of sectiuniActive(c)) {
    const rows = c.nereguli.filter((n) => secOf(n) === sec);
    // nereguli grave (NU la dotări) apar mereu, chiar neverificate, ca să nu se piardă
    const gravNeverif = (n) => !n.status && sablon(n.key)?.grav && isApplicable(c, n);
    const verif = rows.filter((n) => n.status || gravNeverif(n));
    const neverif = rows.filter((n) => !n.status && isApplicable(c, n)).length - rows.filter(gravNeverif).length;
    h.push(`<section><h2>${esc(SECTIUNI[sec].label)}</h2>`);
    if (!verif.length) {
      h.push('<p class="f-small">Nicio rubrică verificată.</p>');
    } else {
      h.push(`<table class="f-table"><thead><tr><th>Nr.</th><th>${sec === 'ner' ? 'Neregulă' : 'Rubrică'}</th>${sec === 'ner' && multe ? '<th>Construcția</th>' : ''}<th>Situație</th><th>PV</th><th>Observații / sancțiune</th></tr></thead><tbody>`);
      for (const n of verif) {
        const vi = vecheInfo(controls, c, n);
        const det = [];
        if (obs(n.obs)) det.push(obs(n.obs));
        if (isVerificare(n) && n.status !== 'nec') {
          const vs = constructiiEligibile(c, n).map((k) => {
            const s = verifStare(c, n, k);
            return `${multe ? `${esc(k.denumire)}: ` : ''}${s.stare === 'lipsa' ? 'fără dată' : `${fmtDate(s.data)} (${s.luni} luni)${s.stare === 'expirata' ? ` — <b>expirată din ${fmtDate(s.expira)}</b>` : ''}`}`;
          });
          if (vs.length) det.push(`<b>Ultima verificare:</b> ${vs.join('; ')}`);
        }
        if (n.custom && n.grav) det.push('<b>Neregulă gravă</b>');
        if (n.status === 'nok' && isGrav(n) && n.sigiliu) det.push('<b>Sigiliu aplicat</b>');
        if (vi.veche) det.push(`<b>Neregulă veche</b>${vi.auto ? ` (și la controlul din ${fmtDate(vi.auto.dataInceput)})` : ''}`);
        if (n.status === 'nok' && n.amenda?.aplicata) {
          const fs = fineStatus(c, n, today);
          det.push(`<b>Amendă</b>${amendaSerieNr(n.amenda) ? ` ${esc(amendaSerieNr(n.amenda))}` : ''}${money(n.amenda.suma) ? `, ${money(n.amenda.suma)}` : ''} — ${esc(fs.label)}`);
        }
        if (sec === 'ner' && n.key === 'a' && !n.custom) {
          const d = asiDeadline(c, today);
          if (d) det.push(`<b>ASI 90 zile:</b> ${esc(d.msg)}`);
        }
        h.push(`<tr class="${n.status === 'nok' || gravNeverif(n) ? 'f-nok' : ''}">
          <td>${esc(neregulaLetter(c, n))}</td>
          <td>${esc(constatareLabel(n))}${n.custom ? '' : `<div class="f-cat">${esc(CATEGORII[neregulaCat(n)] || '')}</div>`}</td>
          ${sec === 'ner' && multe ? `<td>${esc(constructiiNume(c, n) || '—')}</td>` : ''}
          <td>${n.status === 'nok' ? (sec === 'ner' ? 'Constatat' : 'Neconform') : STATUS[n.status] || '<b>Neverificată — gravă</b>'}</td>
          <td>${n.status === 'nok' ? (n.inPV ? 'Trecut' : '<b>Netrecut</b>') : ''}</td>
          <td>${det.join('<br>')}</td>
        </tr>`);
      }
      h.push('</tbody></table>');
    }
    if (neverif) h.push(`<p class="f-small">${neverif} ${neverif === 1 ? 'rubrică neverificată' : 'rubrici neverificate'} (nu apar în tabel).</p>`);
    if (sec === 'pc' && isLocalitate(c)) {
      const a = c.adapostPC || {};
      h.push(`<p><b>Adăpost de protecție civilă:</b> ${esc(a.v || '—')}${a.v === 'NEC' ? ' (nu este cazul)' : ''}${obs(a.obs) ? ` — ${obs(a.obs)}` : ''}</p>`);
    }
    h.push('</section>');
  }

  h.push(`<footer class="f-foot">Generat la ${esc(fmtDateLong(today))}, ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')} · Agenda inspectorului</footer>`);
  return h.join('\n');
}

// Stiluri pentru fișă: folosite și în aplicație, și în fișierul partajat. Mereu pe fond alb, ca pe hârtie.
export const FISA_CSS = `
.fisa-doc { background: #fff; color: #111; font: 10.5pt/1.4 -apple-system, "Helvetica Neue", Arial, sans-serif; }
.fisa-doc h1 { font-size: 18pt; margin: 2pt 0 6pt; }
.fisa-doc h2 { font-size: 12.5pt; margin: 14pt 0 6pt; padding-bottom: 3pt; border-bottom: 1.5pt solid #16213a; }
.fisa-doc h3 { font-size: 11pt; margin: 8pt 0 4pt; }
.fisa-doc p { margin: 3pt 0; }
.f-kicker { text-transform: uppercase; letter-spacing: .08em; font-size: 8.5pt; font-weight: 700; color: #5a3de0; }
.f-meta { display: flex; flex-wrap: wrap; gap: 3pt 14pt; font-size: 10pt; }
.f-sum { display: grid; grid-template-columns: repeat(5, 1fr); gap: 6pt; margin-top: 10pt; }
.f-sum div { border: 1pt solid #c9cfdc; border-radius: 5pt; padding: 5pt 7pt; }
.f-sum b { display: block; font-size: 15pt; }
.f-sum span { font-size: 8.5pt; color: #444; }
.f-table, .f-kv { width: 100%; border-collapse: collapse; }
.f-table th, .f-table td, .f-kv td { border: 0.75pt solid #c9cfdc; padding: 3pt 5pt; text-align: left; vertical-align: top; }
.f-table th { background: #eef0f5; font-size: 9pt; }
.f-table tr, .f-constr { break-inside: avoid; page-break-inside: avoid; }
.f-nok td { background: #fde7e5; }
.f-cat { font-size: 8pt; color: #666; }
.f-dot { font-size: 9.5pt; }
.f-small { font-size: 9pt; color: #444; }
.f-foot { margin-top: 16pt; padding-top: 6pt; border-top: 0.75pt solid #c9cfdc; font-size: 8.5pt; color: #666; }
.fisa-doc * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
`;

// Document HTML complet, pentru partajare / salvare în Fișiere
export function fisaDocument(c, controls) {
  return `<!doctype html><html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fișa controlului – ${esc(c.denumire || '')}</title>
<style>@page { size: A4; margin: 14mm; } body { margin: 0; padding: 16px; } ${FISA_CSS}</style></head>
<body><div class="fisa-doc">${fisaMarkup(c, controls)}</div></body></html>`;
}

export function fisaFileName(c) {
  const slug = (c.denumire || 'control').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
  return `Fisa-control-${slug}-${isISO(c.dataInceput) ? c.dataInceput : todayISO()}.html`;
}
