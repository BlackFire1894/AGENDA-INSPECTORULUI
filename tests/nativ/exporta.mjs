// Exportă, din codul aplicației web, tot ce aplicația nativă (Swift) trebuie să reproducă 1 la 1:
//   docs/nativ/date/     — datele comune pe care aplicația nativă le citește ca atare (catalogul, ghidul, stilurile fișei)
//   docs/nativ/vectori/  — cazuri de test: intrare → rezultatul exact al aplicației web (termene, texte, cifre, notificări)
// Rulare: `npm run nativ` (scrie fișierele) · `node tests/nativ/exporta.mjs --verifica` (le compară; folosit de `npm test`).
// Rezultatul e determinist: ceas fix, fus orar Europe/Bucharest, identificatori generați dintr-o sămânță fixă.
process.env.TZ = 'Europe/Bucharest';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ACUM = new Date('2026-10-15T09:00:00+03:00').getTime();   // joi, 15.10.2026, 09:00 (ora României)
const AZI = '2026-10-15';
const DateReal = Date;
globalThis.Date = class extends DateReal {
  constructor(...a) { super(...(a.length ? a : [ACUM])); }
  static now() { return ACUM; }
};
let samanta = 42;
Math.random = () => { samanta = (samanta * 1103515245 + 12345) % 2147483648; return samanta / 2147483648; };

const radacina = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const M = await import('../../js/model.js');
const D = await import('../../js/dates.js');
const A = await import('../../js/activitati.js');
const { buildDemo, buildDemoActivitati } = await import('../../js/demo.js');
const { fisaMarkup, FISA_CSS, fisaFileName } = await import('../../js/fisa.js');
const { MANUAL } = await import('../../js/help.js');
const { APP_VERSION } = await import('../../js/version.js');
const { stareNativa, cifreZi } = await import('./referinta.mjs');

const zileDe = (de, pana) => { const out = []; for (let d = de; d <= pana; d = D.addDays(d, 1)) out.push(d); return out; };
const scurt = (st) => Object.fromEntries(Object.entries(st).filter(([, v]) => v !== undefined));

// ───────── date comune ─────────
function catalog() {
  return {
    versiuneAplicatieWeb: APP_VERSION,
    schema: M.SCHEMA_VERSION,
    termene: { TERMEN_PLATA: D.TERMEN_PLATA, PRAG_ROSU: D.PRAG_ROSU, TERMEN_ANAF: D.TERMEN_ANAF, TERMEN_ASI: D.TERMEN_ASI, TERMEN_PIERDERE_ASI: D.TERMEN_PIERDERE_ASI, TERMEN_INCARCARE: D.TERMEN_INCARCARE },
    luni: D.MONTHS, luniScurt: D.MONTHS_SHORT, zileSaptamana: D.WEEKDAYS, zileScurt: D.WEEKDAYS_SHORT,
    tipObiectiv: M.TIP_OBIECTIV, dotari: M.DOTARI, centralaTipuri: M.CENTRALA_TIPURI, acte: M.ACTE,
    categorii: M.CATEGORII, sectiuni: M.SECTIUNI,
    sablon: M.SABLON,                       // toate rândurile de nereguli / rubrici, în ordine (cu din / retrasDin / letter / req …)
    lipsaDotari: M.LIPSA_DOTARI, autoNU: M.AUTO_NU, grfNiveluri: M.GRF_NIVELURI,
    structuri: M.STRUCTURI, materialePereti: M.MATERIALE_PERETI, lipsaIncarcare: M.LIPSA_INCARCARE,
    tipuriActivitate: A.TIPURI_ACTIVITATE, stariActivitate: A.STARI_ACTIVITATE,
  };
}
function sarbatori() {
  const out = {};
  for (let an = 2024; an <= 2040; an++) out[an] = Object.fromEntries([...D.sarbatoriLegale(an)].sort(([a], [b]) => a.localeCompare(b)));
  return { pasteOrtodox: Object.fromEntries(Array.from({ length: 17 }, (_, i) => [2024 + i, D.pasteOrtodox(2024 + i)])), sarbatori: out };
}

// ───────── cazuri de test ─────────
function vectoriDate() {
  const zile = zileDe('2024-01-01', '2030-12-31');
  return {
    fmt: zileDe('2026-01-01', '2026-12-31').filter((_, i) => i % 11 === 0).map((d) => ({ iso: d, fmtDate: D.fmtDate(d), fmtDateLong: D.fmtDateLong(d), fmtDateMedium: D.fmtDateMedium(d) })),
    plural: [0, 1, 2, 5, 19, 20, 21, 101, 120].map((n) => ({ n, zile: D.zile(n) })),
    nelucratoare: zile.map((d) => [d, D.zinelucratoare(d)]).filter(([, m]) => m).map(([d, motiv]) => ({ d, motiv })),
    addWorkingDays: zileDe('2026-11-20', '2027-01-10').map((d) => ({ d, n: 3, rezultat: D.addWorkingDays(d, 3) })),
    workingDaysBetween: zileDe('2026-12-20', '2027-01-05').map((d) => ({ de: d, pana: '2027-01-08', rezultat: D.workingDaysBetween(d, '2027-01-08') })),
    nextWorkingDay: zileDe('2026-12-20', '2027-01-10').map((d) => ({ d, rezultat: D.nextWorkingDay(d) })),
    parseDateQuery: ['12.09.2026', '09.2026', '2026', '1.2.2026', '31.02.2026', 'școala', '', '2026-10-15', '10.2026 x'].map((q) => ({ q, rezultat: D.parseDateQuery(q, new Date(ACUM)) ?? null })),
  };
}

function controlCuAmenda(dataInchiderii, dataAmenzii = '') {
  const c = M.newControl({ tip: 'OPEC', denumire: 'Test', start: dataInchiderii });
  c.dataIncheiere = dataInchiderii;
  const n = c.nereguli.find((x) => x.key === 'd');
  n.status = 'nok'; n.amenda = { ...n.amenda, aplicata: true, data: dataAmenzii, suma: '1.000' };
  return [c, n];
}
function vectoriTermene() {
  const amenzi = [];
  for (const [inc, apl] of [['2026-10-01', ''], ['2026-11-20', ''], ['2026-12-10', '2026-12-11'], ['2026-12-17', '']]) {
    const [c, n] = controlCuAmenda(inc, apl);
    for (let k = -2; k <= 50; k++) amenzi.push({ dataIncheiere: inc, dataAplicarii: apl, azi: D.addDays(apl || inc, k), rezultat: scurt(M.fineStatus(c, n, D.addDays(apl || inc, k))) });
  }
  { const [c, n] = controlCuAmenda('2026-10-01'); n.amenda.achitata = true; n.amenda.dataAchitare = '2026-10-10'; amenzi.push({ dataIncheiere: '2026-10-01', achitata: '2026-10-10', azi: '2026-10-12', rezultat: scurt(M.fineStatus(c, n, '2026-10-12')) }); }
  { const c = M.newControl({ tip: 'OPEC', start: '2026-10-01' }); const n = c.nereguli.find((x) => x.key === 'd'); n.status = 'nok'; n.amenda = { ...n.amenda, aplicata: true }; amenzi.push({ neincheiat: true, azi: '2026-10-12', rezultat: scurt(M.fineStatus(c, n, '2026-10-12')) }); }

  const asi = [];
  for (const [inc, cfg] of [['2026-09-01', {}], ['2026-10-02', {}], ['2026-09-01', { asiPrezentat: true, asiDataPrezentare: '2026-10-20' }], ['2026-06-10', { asiPierdere: true, asiDataPierdere: '2026-09-10' }]]) {
    const c = M.newControl({ tip: 'OPEC', start: inc }); c.dataIncheiere = inc;
    const a = c.nereguli.find((x) => x.key === 'a'); Object.assign(a, { status: 'nok', asiTermen: true }, cfg);
    for (let k = 0; k <= 100; k += (k >= 84 && k <= 97 ? 1 : 7)) asi.push({ dataIncheiere: inc, cfg, azi: D.addDays(inc, k), rezultat: M.asiDeadline(c, D.addDays(inc, k)) && scurt(M.asiDeadline(c, D.addDays(inc, k))) });
  }
  { const c = M.newControl({ tip: 'OPEC', start: '2026-10-01' }); const a = c.nereguli.find((x) => x.key === 'a'); Object.assign(a, { status: 'nok', asiTermen: true }); asi.push({ neincheiat: true, azi: '2026-10-05', rezultat: M.asiDeadline(c, '2026-10-05') }); }

  const incarcare = [];
  for (const inc of ['2026-10-01', '2026-11-26', '2026-11-27', '2026-12-23', '2026-12-31']) {
    for (const flags of [{}, { aplicatie: true }, { aplicatie: true, document: true }]) {
      const c = M.newControl({ tip: 'OPEC', start: inc }); c.dataIncheiere = inc; Object.assign(c.incarcare, flags);
      for (let k = 0; k <= 9; k++) incarcare.push({ dataIncheiere: inc, bife: flags, azi: D.addDays(inc, k), rezultat: M.incarcareStatus(c, D.addDays(inc, k)) });
    }
  }
  return { amenzi, asi, incarcare };
}

function vectoriSume() {
  return ['2500', '2.500', '2 500', '1.500,50', '1500,5', '12.345.678', '2.5', '3000 lei', '', 'abc', '0', '1.000.000,99', ' 750 '].map((v) => ({ text: v, parseSuma: M.parseSuma(v) ?? null, lei: M.parseSuma(v) != null ? A.lei(M.parseSuma(v)) : null }));
}

// Setul demonstrativ al aplicației (ca în Setări → Date demonstrative), cu tot ce afișează aplicația despre el
function vectoriDemo() {
  const controls = buildDemo(AZI).map(M.normalizeControl);
  const activitati = buildDemoActivitati(AZI, controls).map(A.normalizeActivitate);
  const meta = { lastBackup: null, sarbatoriVerificate: [] };
  const rand = (c, n) => ({
    key: n.key, sec: M.secOf(n), litera: M.neregulaLetter(c, n), eticheta: M.neregulaLabel(n), constatare: M.constatareLabel(n),
    categorie: M.neregulaCat(n), aplicabil: M.isApplicable(c, n), status: n.status, grav: M.isGrav(n),
    veche: (({ veche, auto, manual }) => ({ veche, auto: auto?.id ?? null, manual }))(M.vecheInfo(controls, c, n)),
    constructii: M.constructiiOf(c, n).map((k) => k.id),
    amenda: n.status === 'nok' && n.amenda?.aplicata ? scurt(M.fineStatus(c, n, AZI)) : null,
  });
  const perControl = controls.map((c) => ({
    id: c.id,
    controlStats: (({ fines, asi, incarcare, ...rest }) => ({ ...rest, fines: fines.map((f) => ({ key: f.n.key, ...scurt(f.st) })), asi: asi && scurt(asi), incarcare }))(M.controlStats(c, AZI)),
    secStats: Object.fromEntries(M.sectiuniActive(c).map((s) => [s, (({ fines, ...r }) => ({ ...r, fines: fines.length }))(M.secStats(c, s, AZI))])),
    todoList: M.todoList(c),
    pvText: M.pvText(c, controls),
    pvTextNetrecute: M.pvText(c, controls, { doarNetrecute: true, cuActe: false }),
    sigilii: M.sigiliiControl(c), adaposturi: M.adaposturiStats(c),
    randuri: M.activeNereguli(c).map((n) => rand(c, n)),
    fisaHtml: fisaMarkup(c, controls, new Date(ACUM)), fisaFisier: fisaFileName(c),
  }));
  const cautari = ['școala', 'scoala', 'nord', '12.10.2026', '10.2026', '2026', 'popescu', 'valea'].map((q) => ({ q, controale: controls.filter((c) => M.matchControl(c, q)).map((c) => c.id) }));
  const r = A.raportLunar(controls, activitati, 2026, 9, AZI);
  return {
    azi: AZI, controls, activitati,
    obiective: M.objectives(controls).map((o) => ({ id: o.id, denumire: o.denumire, tip: o.tip, controale: o.controls.map((c) => c.id), ultim: o.last.id })),
    perControl, cautari,
    panou: {
      cifre: cifreZi(controls, activitati, AZI),
      amenzi: M.allFines(controls, AZI).map((f) => ({ control: f.c.id, key: f.n.key, ...scurt(f.st) })),
      asi: M.allAsi(controls, AZI).map((x) => ({ control: x.c.id, ...scurt(x.a) })),
      deConfirmat: A.deConfirmat(activitati, AZI).map((a) => a.id),
    },
    raportOctombrie: { ...r, controale: r.controale.map((c) => c.id), amenzi: r.amenzi.map((x) => ({ control: x.c.id, key: x.n.key, data: x.data, suma: x.suma })), efectuate: r.efectuate.map((a) => a.id), planificate: r.planificate.map((a) => a.id), anulate: r.anulate.map((a) => a.id), zile: r.zile.map(([d, x]) => [d, { controale: x.controale.map((c) => c.id), activitati: x.activitati.map((a) => a.id) }]) },
    raportOctombrieHtml: A.raportMarkup(r, controls, new Date(ACUM)),
    nativ: stareNativa(controls, activitati, meta, AZI, new Date(ACUM)),   // widgeturi (cifre pe 21 de zile) + notificări
    backup: { app: 'agenda-inspectorului', schema: M.SCHEMA_VERSION, exportedAt: new Date(ACUM).toISOString(), controls, activitati },
  };
}

// Compatibilitatea cu datele vechi: un control dintr-o versiune veche → cum îl completează aplicația
function vectoriNormalizare() {
  const vechi = [
    { id: 'v1', objectiveId: 'o1', tip: 'OPEC', denumire: 'Control din v1.2', dataInceput: '2025-03-10', dataIncheiere: '2025-03-11', schema: 1,
      constructii: [{ id: 'k1', denumire: 'Corp A' }], acte: { ctpsi: { status: 'ok', obs: '' } },
      nereguli: [{ key: 'd', status: 'nok', constructieId: 'k1', amenda: { aplicata: true, serie: 'DB', numar: '0012345', suma: '500' } }] },
    { id: 'v2', objectiveId: 'o2', tip: 'LOCALITATE', denumire: 'Comuna din v1.8', dataInceput: '2026-02-02', dataIncheiere: '', schema: 7,
      gps: { lat: 45.1, lng: 25.2, acc: 12 }, nereguli: [{ key: 'k77', custom: true, label: 'Rând adăugat', status: 'nok' }] },
  ];
  return vechi.map((c) => ({ intrare: c, rezultat: M.normalizeControl(JSON.parse(JSON.stringify(c))) }));
}

export function genereaza() {
  const json = (o) => `${JSON.stringify(o, null, 1)}\n`;
  return {
    'docs/nativ/date/catalog.json': json(catalog()),
    'docs/nativ/date/sarbatori.json': json(sarbatori()),
    'docs/nativ/date/ghid.json': json({ versiuneAplicatieWeb: APP_VERSION, capitole: MANUAL }),
    'docs/nativ/date/stiluri-fisa.css': `${FISA_CSS.trim()}\n${A.RAPORT_CSS.trim()}\n`,
    'docs/nativ/vectori/date.json': json(vectoriDate()),
    'docs/nativ/vectori/termene.json': json(vectoriTermene()),
    'docs/nativ/vectori/sume.json': json(vectoriSume()),
    'docs/nativ/vectori/demo.json': json(vectoriDemo()),
    'docs/nativ/vectori/normalizare.json': json(vectoriNormalizare()),
  };
}

const fisiere = genereaza();
if (process.argv.includes('--verifica')) {
  const vechi = Object.entries(fisiere).filter(([f, c]) => !fs.existsSync(path.join(radacina, f)) || fs.readFileSync(path.join(radacina, f), 'utf8') !== c).map(([f]) => f);
  if (vechi.length) { console.error(`Neactualizate (rulați npm run nativ): ${vechi.join(', ')}`); process.exit(1); }
  console.log('Datele pentru aplicația nativă sunt la zi.');
} else {
  for (const [f, c] of Object.entries(fisiere)) { fs.mkdirSync(path.dirname(path.join(radacina, f)), { recursive: true }); fs.writeFileSync(path.join(radacina, f), c); }
  console.log(`Scrise: ${Object.keys(fisiere).length} fișiere în docs/nativ/`);
}
