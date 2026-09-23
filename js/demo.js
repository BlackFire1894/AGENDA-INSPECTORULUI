// Date demonstrative, relative la data curentă, ca să se vadă toate stările (se pot șterge din Setări).
import { addDays } from './dates.js';
import { newControl, controlFromPrevious, emptyConstructie, uid } from './model.js';

function fill(k, o) {
  Object.assign(k, o.base || {});
  for (const [key, v] of Object.entries(o.dotari || {})) k.dotari[key].v = v;
  if (o.centrala) k.dotari.centrala.tipuri = o.centrala;
  return k;
}

function nok(c, key, extra = {}) {
  const n = c.nereguli.find((x) => x.key === key);
  n.status = 'nok';
  Object.assign(n, extra);
  if (extra.amenda) n.amenda = { aplicata: true, data: '', suma: '', achitata: false, dataAchitare: '', ...extra.amenda };
  return n;
}

function okAll(c, except = []) {
  for (const k of Object.keys(c.acte)) c.acte[k].status = except.includes(k) ? 'nok' : 'ok';
}

export function buildDemo(today) {
  const out = [];

  // 1. Școală — control vechi + control recent cu amendă în stadiul roșu
  const s1 = newControl({ tip: 'OPEC', denumire: 'Școala Gimnazială nr. 3', start: addDays(today, -400) });
  Object.assign(s1, { administrator: 'Maria Ionescu', telefon: '0721 456 789', email: 'secretariat@scoala3.ro', dataIncheiere: addDays(today, -399) });
  s1.constructii = [
    fill(emptyConstructie(1), { base: { denumire: 'Corp A – săli de clasă', suprafata: '1850', regimInaltime: 'P+2E', nrAngajati: '42', structura: 'Cadre din beton armat', materialPereti: 'Cărămidă' }, dotari: { asi: 'DA', aviz: 'DA', hidInt: 'DA', hidExt: 'NU', idsai: 'DA', exit: 'DA', desfumare: 'NEC', ilumHint: 'DA', ipt: 'DA' }, centrala: ['GAZOS'] }),
    fill(emptyConstructie(2), { base: { denumire: 'Sala de sport', suprafata: '620', regimInaltime: 'P', nrAngajati: '3', structura: 'Structură metalică', materialPereti: 'Panouri sandwich' }, dotari: { asi: 'NU', aviz: 'NU', idsai: 'NEC', exit: 'DA' } }),
  ];
  okAll(s1, ['analiza']);
  nok(s1, 'd', { inPV: true, obs: '4 stingătoare P6 expirate' });
  out.push(s1);

  const s2 = controlFromPrevious(s1, addDays(today, -42));
  s2.dataIncheiere = addDays(today, -41);
  okAll(s2, ['fise', 'stingatoare']);
  nok(s2, 'd', { inPV: true, obs: '2 stingătoare expirate, corp A', amenda: { suma: '2500', serie: 'DB', numar: '0012345' } });
  s2.nereguli.find((x) => x.key === 'j').constructieIds = [s2.constructii[1].id];
  nok(s2, 'j', { inPV: true, obs: 'Hol etaj 1' });
  out.push(s2);

  // 2. Spital — amendă galbenă + termen ASI activ
  const h = newControl({ tip: 'OPEC', denumire: 'Spitalul Orășenesc Valea Verde', start: addDays(today, -21) });
  Object.assign(h, { administrator: 'Dr. Andrei Popa', telefon: '0744 112 233', email: 'administrativ@spital-vv.ro', dataIncheiere: addDays(today, -20) });
  h.constructii = [
    fill(emptyConstructie(1), { base: { denumire: 'Pavilion central', suprafata: '6400', regimInaltime: 'S+P+4E', nrAngajati: '210', structura: 'Beton armat', materialPereti: 'BCA' }, dotari: { asi: 'NU', aviz: 'DA', hidInt: 'DA', hidExt: 'DA', sprinklere: 'NEC', idsai: 'DA', exit: 'DA', desfumare: 'DA', rezervaApa: 'DA', statiePompe: 'DA', acumulatori: 'DA', ilumHint: 'DA', ipt: 'DA' }, centrala: ['GAZOS', 'ELECTRIC'] }),
    fill(emptyConstructie(2), { base: { denumire: 'Ambulatoriu', suprafata: '1200', regimInaltime: 'P+1E', nrAngajati: '35', structura: 'Zidărie portantă', materialPereti: 'Cărămidă' }, dotari: { asi: 'DA', hidInt: 'DA', idsai: 'DA', exit: 'NU' } }),
  ];
  okAll(h, ['sezon']);
  nok(h, 'a', { inPV: true, asiTermen: true, obs: 'Pavilion central' });
  nok(h, 'l', { inPV: true, obs: 'Erori zona 3 centrală' });
  nok(h, 'q', { inPV: false, obs: 'Hidrant exterior H2 fără presiune', amenda: { suma: '5000', serie: 'DB', numar: '0012377' } });
  out.push(h);

  // 3. Primărie (Localitate) — amendă albastră, o neregulă netrecută în PV
  const p = newControl({ tip: 'LOCALITATE', denumire: 'Comuna Valea Mare', start: addDays(today, -6) });
  Object.assign(p, { administrator: 'Primar Gheorghe Stan', telefon: '0248 555 010', email: 'primaria@valeamare.ro', dataIncheiere: addDays(today, -5) });
  p.constructii[0] = fill(p.constructii[0], { base: { denumire: 'Sediu primărie', suprafata: '540', regimInaltime: 'P+1E', nrAngajati: '24', structura: 'Zidărie portantă', materialPereti: 'Cărămidă' }, dotari: { asi: 'NEC', aviz: 'NU', exit: 'DA', fotovoltaice: 'DA', ipt: 'NU' }, centrala: ['SOLID'] });
  okAll(p, ['comisie', 'contract']);
  nok(p, 'b', { inPV: true, amenda: { suma: '1500' } });
  nok(p, 'h', { inPV: false });
  const cust = { key: `k${uid()}`, custom: true, sec: 'ner', label: 'Căi de evacuare blocate cu mobilier', status: 'nok', obs: 'Hol parter', inPV: true, asiTermen: false, asiPrezentat: false, asiDataPrezentare: '', amenda: { aplicata: false, data: '', suma: '', achitata: false, dataAchitare: '' } };
  p.nereguli.push(cust);
  // Planuri și SVSU / Protecție civilă (doar la localități)
  for (const k of ['paar', 'plInundatii', 'plCutremur', 'svsuAvizat', 'svsuSef', 'svsuPlanPregatire']) p.nereguli.find((x) => x.key === k).status = 'ok';
  nok(p, 'plEvacuare', { inPV: true, obs: 'Neactualizat din 2021' });
  nok(p, 'svsuDotare', { inPV: true, obs: 'Lipsă motopompă', amenda: { suma: '3000' } });
  for (const k of ['pcAudibilitate', 'pcSireneNumar', 'pcSireneMentenanta']) p.nereguli.find((x) => x.key === k).status = 'ok';
  nok(p, 'pcSireneDefecte', { inPV: false, obs: 'Sirena S3 – sat Poiana' });
  p.adapostPC = { v: 'NU', obs: '' };
  out.push(p);

  // 4. Cămin cultural — amendă achitată
  const k = newControl({ tip: 'LOCALITATE', denumire: 'Căminul Cultural Poiana', start: addDays(today, -60) });
  Object.assign(k, { administrator: 'Ion Radu', telefon: '0766 000 111', dataIncheiere: addDays(today, -60) });
  k.constructii[0] = fill(k.constructii[0], { base: { denumire: 'Clădire cămin', suprafata: '380', regimInaltime: 'P', nrAngajati: '2', structura: 'Zidărie portantă', materialPereti: 'Cărămidă' }, dotari: { asi: 'NU', exit: 'DA' }, centrala: ['SOLID'] });
  okAll(k);
  nok(k, 'j', { inPV: true, amenda: { suma: '1000', achitata: true, dataAchitare: addDays(today, -52) } });
  out.push(k);

  // 5. Controale neîncheiate
  const g = newControl({ tip: 'OPEC', denumire: 'Grădinița cu Program Prelungit nr. 2', start: addDays(today, -2) });
  Object.assign(g, { administrator: 'Elena Dinu', telefon: '0733 222 444', email: 'gpp2@edu.ro' });
  g.constructii[0].denumire = 'Corp principal';
  out.push(g);

  const m = newControl({ tip: 'OPEC', denumire: 'Centrul Comercial Nord', start: today });
  Object.assign(m, { administrator: 'SC Nord Retail SRL', telefon: '0212 345 678' });
  m.constructii[0].denumire = 'Hală comercială';
  out.push(m);

  for (const c of out) c.demo = true;
  return out;
}
