// Set de date cu cazuri-limită, relativ la T = 2026-10-15 (joi). Folosește constructorii aplicației doar pentru structură.
import fs from 'node:fs';
import { newControl, emptyNeregula, uid } from '../../js/model.js';
export const T = '2026-10-15';
const day = (iso, n) => { const [y, m, d] = iso.split('-').map(Number); const x = new Date(Date.UTC(y, m - 1, d + n)); return x.toISOString().slice(0, 10); };
const nok = (c, key, extra = {}) => { const n = c.nereguli.find((x) => x.key === key); n.status = 'nok'; Object.assign(n, extra); if (extra.amenda) n.amenda = { aplicata: true, serieNr: 'DB 1', data: '', suma: '1000', achitata: false, dataAchitare: '', ...extra.amenda }; return n; };
const out = [];
// 1. Amenzi la limite: control încheiat la T-60; fiecare amendă cu data aplicării T-e
const f = newControl({ denumire: 'Amenzi limită', start: day(T, -61) }); f.dataIncheiere = day(T, -60);
const E = { d: -3, e: 0, al: 1, f: 14, aa: 15, ab: 16, ac: 39, ad: 40, ae: 44, g: 45, h: 46, i: 60 };
for (const [k, e] of Object.entries(E)) nok(f, k, { inPV: e % 2 === 0, amenda: { data: day(T, -e) } });
nok(f, 'j', { inPV: true, amenda: { data: '' } });                         // fără dată → data încheierii (e = 60)
nok(f, 'k', { inPV: true, amenda: { data: day(T, -30), achitata: true, dataAchitare: day(T, -20) } });
nok(f, 'b1', { inPV: false });                                             // constatată fără amendă
f.acte.ctpsi.status = 'nok'; f.acte.lfd.status = 'ok'; f.acte.analiza.status = 'nec';
out.push(f);
// 2. Amendă într-un control neîncheiat (termene neîncepute)
const g = newControl({ denumire: 'Deschis cu amendă', start: day(T, -2) });
nok(g, 'd', { amenda: { data: '' } }); nok(g, 'e', { inPV: true });
out.push(g);
// 3. ASI: încheiat la T-90 (expiră azi), T-20 (70 zile), T-91 (depășit 1), T-100 (depășit 10), neîncheiat, prezentat
for (const [nume, inch, prez] of [['ASI azi', -90], ['ASI 70', -20], ['ASI depășit 1', -91], ['ASI depășit 10', -100], ['ASI neînceput', null], ['ASI prezentat', -30, true]]) {
  const c = newControl({ denumire: nume, start: inch === null ? day(T, -1) : day(T, inch - 1) });
  if (inch !== null) c.dataIncheiere = day(T, inch);
  nok(c, 'a', { asiTermen: true, asiPrezentat: !!prez, asiDataPrezentare: prez ? day(T, -5) : '', inPV: true });
  out.push(c);
}
// 4. Controale neîncheiate: început azi, ieri, acum 2 zile, acum 30, programat peste 3 zile
for (const [nume, s] of [['Început azi', 0], ['Început ieri', -1], ['Început de 2 zile', -2], ['Început de 30 de zile', -30], ['Programat', 3]]) {
  out.push(newControl({ denumire: nume, start: day(T, s) }));
}
// 5. Localitate: planuri + PC, adăpost gol, câteva neconforme (unele în PV)
const l = newControl({ tip: 'LOCALITATE', denumire: 'Comuna Test', start: day(T, -10) }); l.dataIncheiere = day(T, -9);
nok(l, 'paar', { inPV: true }); nok(l, 'plEvacuare', { inPV: false, amenda: { data: '' } });
nok(l, 'pcSireneDefecte', { inPV: false }); l.nereguli.find((x) => x.key === 'pcAudibilitate').status = 'ok';
nok(l, 'd', { inPV: true });
out.push(l);
// 6. Același obiectiv, două controale: neregula d constatată în ambele (veche); rând adăugat grav
const o1 = newControl({ denumire: 'Obiectiv repetat', start: day(T, -200) }); o1.dataIncheiere = day(T, -199); nok(o1, 'd', { inPV: true });
const o2 = newControl({ denumire: 'Obiectiv repetat', objectiveId: o1.objectiveId, start: day(T, -5) }); o2.dataIncheiere = day(T, -4);
nok(o2, 'd', { inPV: false });
const cu = emptyNeregula(`k${uid()}`, true, 'ner'); Object.assign(cu, { label: 'Ușă de evacuare blocată', status: 'nok', grav: true, inPV: false }); o2.nereguli.push(cu);
o2.constructii[0].dotari.hidInt.v = 'DA'; o2.constructii[0].dotari.asi.v = 'DA'; o2.constructii[0].dotari.centrala.tipuri = ['GAZOS'];
out.push(o1, o2);
// 7. Încărcarea după încheiere (T = joi 15.10.2026): încheiat azi (3 zile lucr.), luni 12.10 (ultima zi azi), parțial, gata
for (const [nume, inch, ap, doc] of [['Încărcare 3 zile', 0, false, false], ['Încărcare azi', -3, true, false], ['Încărcare gata', -2, true, true]]) {
  const c = newControl({ denumire: nume, start: day(T, inch) }); c.dataIncheiere = day(T, inch);
  c.incarcare = { aplicatie: ap, aplicatieData: ap ? T : '', document: doc, documentData: doc ? T : '' };
  out.push(c);
}
// ASI: pierderea valabilității constatată
const ap = newControl({ denumire: 'ASI pierdere constatată', start: day(T, -101) }); ap.dataIncheiere = day(T, -100);
nok(ap, 'a', { asiTermen: true, asiPierdere: true, asiDataPierdere: day(T, -8), inPV: true }); out.push(ap);
fs.writeFileSync('date.json', JSON.stringify({ app: 'agenda-inspectorului', schema: 10, exportedAt: new Date().toISOString(), controls: out }, null, 1));
console.log('controale:', out.length);
