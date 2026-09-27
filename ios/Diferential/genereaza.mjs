// Verificarea încrucișată web ↔ Swift: generează date aleatoare (deterministe, din sămânță), le trece prin
// CODUL WEB ORIGINAL (js/model.js, js/dates.js, js/activitati.js, tests/nativ/referinta.mjs) și scrie intrările
// împreună cu rezultatele. Testul Swift DiferentialTests calculează aceleași lucruri și cere rezultate identice.
// Rulare: node ios/Diferential/genereaza.mjs [fișier ieșire] [sămânță] (implicit în ~/Library/Caches/AgendaKit-diferential/)
process.env.TZ = 'Europe/Bucharest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// ceasul fix și identificatorii deterministi, ca în tests/nativ/exporta.mjs
const ACUM = new Date('2026-10-15T09:00:00+03:00').getTime();
let ceas = ACUM;   // ecranele web citesc ziua de azi din ceas (Panoul se generează în mai multe zile)
const DateReal = Date;
globalThis.Date = class extends DateReal {
  constructor(...a) { super(...(a.length ? a : [ceas])); }
  static now() { return ceas; }
};
globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };
let samantaUid = 7;
Math.random = () => { samantaUid = (samantaUid * 1103515245 + 12345) % 2147483648; return samantaUid / 2147483648; };

const M = await import('../../js/model.js');
const D = await import('../../js/dates.js');
const A = await import('../../js/activitati.js');
const { stareNativa, cifreZi } = await import('../../tests/nativ/referinta.mjs');
const F = await import('../../js/fisa.js');

const iesire = process.argv[2] || path.join(os.homedir(), 'Library/Caches/AgendaKit-diferential/cazuri.json');
let s = Number(process.argv[3] || 20260926) >>> 0;
const rnd = () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const alege = (l) => l[Math.floor(rnd() * l.length)];
const sansa = (p) => rnd() < p;
const intre = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const zi = (de = '2024-01-01', pana = '2030-12-31') => D.addDays(de, intre(0, D.diffDays(de, pana)));
const scurt = (st) => (st ? Object.fromEntries(Object.entries(st).filter(([, v]) => v !== undefined)) : st);

const NUME = ['Școala Gimnazială nr. 5', 'Spitalul Județean', 'Primăria Comunei Șușani', 'SC Țesătura SRL', 'Căminul Cultural Brădet', '', 'Hotel Aurora', 'Grădinița nr. 2', 'Depozit Logistic Nord', 'Biserica Sf. Ilie'];
const OBS = ['', '', 'hol etaj 1', 'P6 nr. 3\nhol', '  corp B  ', 'Lipsă aviz; se va reface', 'stingătoare expirate\n\n2 bucăți'];
const SUME = ['', '2.500', '1500,5', '3000 lei', '1.000.000', 'abc', '500', ' 750 ', '2 500', '12.345,67'];
const SERII = ['', 'DB 0012345', 'db0012345', 'seria CJ nr. 45 678', '0099', 'PV 12/2026', 'AB 1'];
const REGIM = ['P', 'P+1', 'S+P+2E', 'Parter + 1 etaj', '', 'D+P', 'P+M', 'S+P'];
const ETICHETE = ['Căi de evacuare blocate', 'cai de EVACUARE blocate ', 'Depozitare butelii în subsol', '', 'Ușă blocată'];
const LOCATII = ['Subsol corp A', 'Demisol', '', 'Sala 3'];

function constructie(i) {
  const k = M.emptyConstructie(i);
  if (sansa(0.8)) k.denumire = alege(['Corp A', 'Sala de sport', 'Anexă', 'Pavilion', '']);
  k.regimInaltime = alege(REGIM);
  k.grf = alege(['', '', 'I', 'III', 'V', 'V', 'NN']);
  for (const d of M.DOTARI) {
    if (d.centrala) { k.dotari.centrala.tipuri = M.CENTRALA_TIPURI.filter(() => sansa(0.3)); continue; }
    k.dotari[d.key].v = sansa(0.45) ? '' : alege(d.opts);
    if (sansa(0.15)) k.dotari[d.key].obs = alege(OBS);
  }
  if (sansa(0.5)) k.gps = { lat: 44 + rnd() * 4, lon: 21 + rnd() * 8, acc: intre(3, 300), la: '2026-09-01T08:00:00.000Z' };
  return k;
}

function amesteca(c) {
  c.tip = alege(['OPEC', 'LOCALITATE']);
  c.denumire = alege(NUME);
  c.administrator = alege(['Ion Popescu', 'Maria Ionescu', '']);
  c.localitate = alege(['Brașov', 'Șușani', '']);
  if (!c.constructii.length || sansa(0.6)) c.constructii = Array.from({ length: intre(1, 3) }, (_, i) => constructie(i + 1));
  const ids = c.constructii.map((k) => k.id);
  for (const a of M.ACTE) c.acte[a.key].status = alege(['', '', 'ok', 'ok', 'nok', 'nec']);
  for (const n of c.nereguli) {
    n.status = alege(['', '', '', '', 'ok', 'ok', 'nok', 'nok', 'nec']);
    if (n.status !== 'nok') { if (sansa(0.1)) n.obs = alege(OBS); continue; }
    n.inPV = sansa(0.5);
    n.obs = alege(OBS);
    n.constructieIds = sansa(0.4) ? [] : sansa(0.1) ? ['inexistent'] : ids.filter(() => sansa(0.6));
    n.vecheManual = sansa(0.15);
    n.sigiliu = sansa(0.3);
    if (sansa(0.4)) {
      n.amenda = { aplicata: true, serieNr: alege(SERII), data: sansa(0.5) ? '' : D.addDays(c.dataInceput, intre(-3, 12)), suma: alege(SUME), achitata: sansa(0.2), dataAchitare: '' };
      if (n.amenda.achitata && sansa(0.7)) n.amenda.dataAchitare = D.addDays(c.dataInceput, intre(1, 40));
    }
    if (n.key === 'a') {
      n.asiTermen = sansa(0.8); n.asiPrezentat = sansa(0.2); n.asiDataPrezentare = n.asiPrezentat && sansa(0.7) ? zi() : '';
      n.asiPierdere = sansa(0.2); n.asiDataPierdere = n.asiPierdere && sansa(0.7) ? zi() : '';
    }
  }
  for (const n of c.nereguli.filter(M.isVerificare)) {
    for (const id of ids) if (sansa(0.4)) n.verificari[id] = { data: D.addDays(c.dataInceput, -intre(0, 900)), ...(sansa(0.3) ? { luni: alege([12, 24, '24', 6]) } : {}) };
  }
  for (let i = intre(0, 2); i > 0; i--) {
    c.nereguli.push({ ...M.emptyNeregula(`k${M.uid()}`, true, alege(['ner', 'plan', 'pc'])), label: alege(ETICHETE), status: alege(['', 'ok', 'nok']), grav: sansa(0.3), sigiliu: sansa(0.3), inPV: sansa(0.5), obs: alege(OBS) });
  }
  c.adapostPC = { v: alege(['', 'DA', 'DA', 'NU', 'NEC']), obs: '' };
  if (c.adapostPC.v === 'DA') {
    for (let i = intre(0, 3); i > 0; i--) c.nereguli.push({ ...M.emptyAdapost(c), locatie: alege(LOCATII), status: alege(['', 'ok', 'nok']), inPV: sansa(0.5) });
  }
  for (const dot of Object.keys(M.AUTO_NU)) if (sansa(0.6)) M.syncAutoNU(c, dot);
  if (sansa(0.7)) {
    c.dataIncheiere = D.addDays(c.dataInceput, intre(0, 3));
    c.incarcare = { aplicatie: sansa(0.5), aplicatieData: '', document: sansa(0.4), documentData: '' };
    if (sansa(0.25)) c.catalog = alege([8, 9, 10, 11]);
  } else {
    c.dataIncheiere = '';
    delete c.catalog;
  }
  M.syncAdaposturi(c);
  return c;
}

// ───────── datele ─────────
const controls = [];
for (let o = 0; o < 70; o++) {
  let c = amesteca(M.newControl({ start: zi('2024-01-01', '2030-10-01') }));
  controls.push(c);
  for (let k = intre(0, 2); k > 0; k--) {
    c = amesteca(M.controlFromPrevious(c, D.addDays(c.dataInceput, intre(20, 400))));
    controls.push(c);
  }
}
const date = controls.map((c) => M.normalizeControl(JSON.parse(JSON.stringify(c))));
const activitati = Array.from({ length: 50 }, () => A.normalizeActivitate({
  ...A.emptyActivitate(zi('2024-01-01', '2030-12-31'), '2027-06-01'),
  tip: alege(['instruire', 'sedinta', 'birou', 'informare', 'exercitiu', 'concediu', 'alta', 'necunoscut']),
  stare: alege(['planificat', 'efectuat', 'anulat', '?']), ora: alege(['', '09:00', '14:30']),
  descriere: alege(['', 'Analiza lunară', 'Vizită']), objectiveId: sansa(0.3) ? alege(date).objectiveId : '',
})).map((a) => (sansa(0.3) ? { ...a, dataSfarsit: D.addDays(a.data, intre(-2, 12)) } : a)).map(A.normalizeActivitate);

// zilele de calcul: în jurul termenelor fiecărui control (schimbările de stadiu) + aleatoare
function zileControl(c) {
  const baza = c.dataIncheiere || c.dataInceput;
  const l = [0, 1, 3, 14, 15, 16, 17, 39, 40, 44, 45, 46, 60, 89, 90, 91, 94, 95, 96, 120].map((k) => D.addDays(baza, k));
  for (const n of M.activeNereguli(c)) if (D.isISO(n.amenda?.data)) l.push(D.addDays(n.amenda.data, alege([-1, 0, 15, 16, 40, 45, 46])));
  l.push(zi());
  return [...new Set(l)];
}

const INTREBARI = ['d', 'AG', 'G1', '+1', 'A1', 'stingatoare', 'STINGĂTOARE expirate', 'hidranti interiori', 'hint', 'marcarea hidrantilor', 'asigurare', 'hol', 'foc deschis', '2', 'cadru tehnic', 'evacuare', 'etaj'];
const perControl = date.map((c) => {
  const randuri = M.activeNereguli(c);
  return {
    id: c.id,
    zile: zileControl(c).map((d) => ({
      d,
      amenzi: randuri.filter((n) => n.status === 'nok' && n.amenda?.aplicata).map((n) => ({ key: n.key, st: scurt(M.fineStatus(c, n, d)) })),
      asi: scurt(M.asiDeadline(c, d)) ?? null,
      incarcare: M.incarcareStatus(c, d),
    })),
    controlStats: (({ fines, asi, incarcare, ...rest }) => ({ ...rest, fines: fines.map((f) => ({ key: f.n.key, ...scurt(f.st) })), asi: asi ? scurt(asi) : null, incarcare }))(M.controlStats(c)),
    secStats: Object.fromEntries(M.sectiuniActive(c).map((sec) => [sec, (({ fines, ...r }) => ({ ...r, fines: fines.map((f) => ({ key: f.n.key, ...scurt(f.st) })) }))(M.secStats(c, sec))])),
    todoList: M.todoList(c),
    todoFaraInchidere: M.todoList(c, { includeClose: false }),
    pvText: M.pvText(c, date),
    pvNetrecute: M.pvText(c, date, { doarNetrecute: true, cuActe: false }),
    sigilii: M.sigiliiControl(c),
    sigiliiText: M.sigiliiControl(c) ? M.sigiliiText(M.sigiliiControl(c)) : null,
    adaposturi: M.adaposturiStats(c),
    adaposturiText: M.adaposturiStats(c) ? M.adaposturiText(M.adaposturiStats(c)) : null,
    catalogOf: M.catalogOf(c),
    randuri: c.nereguli.map((n) => ({
      key: n.key, litera: M.neregulaLetter(c, n), eticheta: M.neregulaLabel(n), constatare: M.constatareLabel(n), cat: M.neregulaCat(n),
      tab: M.tabOfNeregula(n), aplicabil: M.isApplicable(c, n), ascunsa: M.ascunsaDeDotari(c, n), grav: M.isGrav(n),
      veche: (({ veche, auto, manual }) => ({ veche, auto: auto?.id ?? null, manual }))(M.vecheInfo(date, c, n)),
      constructii: M.constructiiOf(c, n).map((k) => k.id), nume: M.constructiiNume(c, n), eligibile: M.constructiiEligibile(c, n).map((k) => k.id),
      serieNr: M.amendaSerieNr(n.amenda), suma: M.parseSuma(n.amenda?.suma) ?? null, verifText: M.verifText(c, n),
      verif: M.isVerificare(n) ? c.constructii.map((k) => (({ data, luni, expira, stare }) => ({ data, luni, expira: expira ?? null, stare }))(M.verifStare(c, n, k))) : null,
      expirate: M.verifExpirate(c, n).map((k) => k.id),
      cautari: INTREBARI.filter((q) => M.matchNeregula(c, n, q)),
    })),
    acte: M.ACTE.map((a) => INTREBARI.filter((q) => M.matchAct(c, a.key, q))),
    fisa: F.fisaMarkup(c, date, new Date(ACUM)),
    fisier: F.fisaFileName(c),
    cautare: ['scoala', 'șușani', 'popescu', c.dataInceput, c.dataInceput.slice(0, 7).split('-').reverse().join('.'), c.dataInceput.slice(0, 4), 'xyz'].filter((q) => M.matchControl(c, q)),
  };
});

const zileGlobale = [...new Set([...Array.from({ length: 30 }, () => zi()), '2026-12-01', '2026-12-31', '2027-01-01', '2027-01-15', '2026-10-15', '2025-06-01'])];
const meta = [{ lastBackup: null, sarbatoriVerificate: [] }, { lastBackup: '2026-10-05T10:00', sarbatoriVerificate: [2027] }, { lastBackup: '2024-02-01T08:30', sarbatoriVerificate: [2025, 2026] }];
const global = {
  cifre: zileGlobale.map((d) => cifreZi(date, activitati, d)),
  amenzi: zileGlobale.slice(0, 12).map((d) => ({ d, l: M.allFines(date, d).map((f) => ({ control: f.c.id, key: f.n.key, ...scurt(f.st) })) })),
  asi: zileGlobale.slice(0, 12).map((d) => ({ d, l: M.allAsi(date, d).map((x) => ({ control: x.c.id, ...scurt(x.a) })) })),
  obiective: M.objectives(date).map((o) => ({ id: o.id, controale: o.controls.map((c) => c.id), ultim: o.last.id })),
  nativ: zileGlobale.slice(0, 14).map((d, i) => ({ d, meta: meta[i % meta.length], stare: stareNativa(date, activitati, meta[i % meta.length], d, new Date(ACUM)) })),
  rapoarte: Array.from({ length: 30 }, () => {
    const an = intre(2024, 2030), luna = intre(0, 11), azi = zi();
    const r = A.raportLunar(date, activitati, an, luna, azi);
    // datele întâi: raportMarkup sortează lista amenzilor pe loc
    const rec = { an, luna, azi, r: { ...r, controale: r.controale.map((c) => c.id), amenzi: r.amenzi.map((x) => ({ control: x.c.id, key: x.n.key, data: x.data, suma: x.suma })), efectuate: r.efectuate.map((a) => a.id), planificate: r.planificate.map((a) => a.id), anulate: r.anulate.map((a) => a.id), zile: r.zile.map(([z, x]) => [z, { controale: x.controale.map((c) => c.id), activitati: x.activitati.map((a) => a.id) }]) } };
    rec.html = A.raportMarkup(r, date, new Date(ACUM));
    return rec;
  }),
  activitati: activitati.map((a) => ({ id: a.id, titlu: A.titluActivitate(a), cand: A.cand(a), zile: A.zileActivitate(a) })),
  peZile: zileGlobale.map((d) => ({ d, deConfirmat: A.deConfirmat(activitati, d).map((a) => a.id), inZi: A.activitatiInZi(activitati, d).map((a) => a.id), libera: A.ziLibera(d, '2026-10-15') })),
};

// normalizarea datelor vechi / incomplete
const vechi = Array.from({ length: 40 }, (_, i) => {
  const c = JSON.parse(JSON.stringify(alege(date)));
  delete c.createdAt; delete c.updatedAt;
  for (const k of ['administrator', 'adresa', 'localitate', 'incarcare', 'adapostPC', 'schema', 'catalog']) if (sansa(0.3)) delete c[k];
  if (sansa(0.3)) c.gps = { lat: 45, lon: 25, acc: 10 };
  c.nereguli = c.nereguli.filter(() => sansa(0.7)).map((n) => {
    const x = { ...n };
    if (sansa(0.3)) { x.constructieId = x.constructieIds[0] || ''; delete x.constructieIds; }
    if (x.amenda && sansa(0.3)) { const { serieNr, ...am } = x.amenda; x.amenda = { ...am, serie: 'DB', numar: String(1000 + i) }; }
    for (const k of ['verificari', 'grav', 'sigiliu', 'auto', 'obsAuto', 'asiPierdere']) if (sansa(0.3)) delete x[k];
    return x;
  });
  c.constructii = c.constructii.map((k) => { const x = { ...k, dotari: { ...k.dotari } }; if (sansa(0.3)) delete x.grf; if (sansa(0.3)) delete x.gps; if (sansa(0.3)) delete x.dotari.asi; return x; });
  return { intrare: c, rezultat: M.normalizeControl(JSON.parse(JSON.stringify(c))) };
});

// ───────── ecranele web (js/views.js), ca HTML: Panou, Obiective, Istoric, pagina obiectivului, rândul controlului ─────────
const V = await import('../../js/views.js');
const S = await import('../../js/state.js');
S.state.controls = date;
S.state.activitati = activitati;
S.state.meta = { lastBackup: null, sarbatoriVerificate: [] };
const Q = ['', 'scoala', 'Șușani', '2026', date[3].dataInceput.split('-').reverse().join('.'), date[5].dataInceput.slice(0, 7).split('-').reverse().join('.'), 'xyz'];
const FLT = [[], ['am-red'], ['asi', 'pv'], ['grave'], ['adapost', 'am-green'], ['inc'], ['sigiliu', 'am-yellow'], ['am-blue', 'grave', 'pv']];
const ecrane = {
  randuri: date.map((c) => ({ id: c.id, cu: V.controlRow(c), fara: V.controlRow(c, { showName: false }) })),
  obiective: [], istoric: [],
  pagini: M.objectives(date).map((o) => ({ id: o.id, html: V.viewObjective(o.id) })),
  panou: [],
};
for (const q of Q) for (const [i, flt] of FLT.entries()) {
  const tip = ['ALL', 'OPEC', 'LOCALITATE'][i % 3];
  Object.assign(S.state.ui, { objSearch: q, objTip: tip, objFlt: new Set(flt) });
  ecrane.obiective.push({ q, tip, flt, html: V.objListHTML() });
  const st = ['ALL', 'OPEN', 'DONE'][(i + Q.indexOf(q)) % 3];
  Object.assign(S.state.ui, { histSearch: q, histFilter: st, histFlt: new Set(flt) });
  ecrane.istoric.push({ q, stare: st, flt, html: V.histListHTML() });
}
for (const [i, z] of ['2026-10-15', '2024-03-04', '2025-12-10', '2026-01-08', '2027-06-30', '2028-12-24', '2029-01-02', '2030-08-15'].entries()) {
  ceas = new DateReal(`${z}T09:00:00+03:00`).getTime();
  S.state.meta = { lastBackup: null, sarbatoriVerificate: i % 2 ? [Number(z.slice(0, 4)) + 1] : [] };
  ecrane.panou.push({ azi: z, meta: S.state.meta, html: V.viewDashboard() });
}
S.state.controls = [];
ecrane.panou.push({ azi: '2026-10-15', meta: { lastBackup: null, sarbatoriVerificate: [] }, gol: true, html: V.viewDashboard() });
ceas = ACUM;

// ───────── calendarul: grila, ziua selectată (ca șir de jetoane: texte, pastile, butoane, clasele de stare) ─────────
const STARE_CAL = /^(out|is-liber|is-today|is-sel|ev-(open|done|act|liber|sarb)|st-(planificat|efectuat|anulat)|act-(instruire|sedinta|birou|informare|exercitiu|concediu|alta)|dot-\w+|item-(blue|green|yellow|red|warn|open))$/;
const atribut = (a, n) => { const m = a.match(new RegExp(`\\s${n}="([^"]*)"`)); return m ? m[1] : null; };
const dec = (x) => x.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
function jetoane(html) {
  let s = html.replace(/<svg[\s\S]*?<\/svg>/g, '');
  s = s.replace(/<span class="pill ([^"]+)"([^>]*)>([\s\S]*?)<\/span>/g, (m, cls, a, t) => {
    const l = cls.split(/\s+/);
    const tip = l.find((x) => x.startsWith('fs-')) || (l.find((x) => x.startsWith('pill-')) || 'pill-?').slice(5);
    return ` ⟦${tip}|${t.trim()}⟧ `;
  });
  s = s.replace(/<(\w+)\b([^>]*)>/g, (m, t, a) => {
    const cls = (atribut(a, 'class') || '').split(/\s+/).filter(Boolean);
    const st = cls.filter((x) => STARE_CAL.test(x)).map((x) => `.${x}`).join('');
    if (t === 'button' || t === 'a') return ` ⟦b${st}⟧ `;
    return st ? ` ⟦${st}⟧ ` : ' ';
  });
  s = dec(s.replace(/<[^>]+>/g, ' '));
  return s.split(/\s+/).filter(Boolean).join(' ').replace(/\s+([.,;:])/g, '$1');
}
S.state.controls = date;
S.state.activitati = activitati;
ecrane.calendar = [];
for (const [y, m, sel] of [[2026, 9, '2026-10-15'], [2026, 9, '2026-10-03'], [2026, 11, '2026-12-25'], [2027, 0, '2027-01-01'], [2025, 4, '2025-05-20'],
  [2028, 1, '2028-02-29'], [2030, 7, '2030-08-15'], [2024, 2, '2024-03-31'], [2029, 3, '2029-04-16'], [2026, 5, '2026-06-01']]) {
  Object.assign(S.state.ui, { calYear: y, calMonth: m, calSelected: sel });
  ecrane.calendar.push({ an: y, luna: m, sel, tok: jetoane(V.viewCalendar()) });
}
// și ziua selectată pe controale și pe activități
for (const sel of [...date.slice(0, 40).map((c) => c.dataInceput), ...activitati.slice(0, 20).map((a) => a.data)]) {
  Object.assign(S.state.ui, { calYear: +sel.slice(0, 4), calMonth: +sel.slice(5, 7) - 1, calSelected: sel });
  ecrane.calendar.push({ an: +sel.slice(0, 4), luna: +sel.slice(5, 7) - 1, sel, tok: jetoane(V.viewCalendar()) });
}

fs.mkdirSync(path.dirname(iesire), { recursive: true });
fs.writeFileSync(iesire, JSON.stringify({ acum: new Date(ACUM).toISOString(), controls: date, activitati, perControl, global, vechi, ecrane }));
console.log(`Scris: ${iesire} (${date.length} controale, ${activitati.length} activități, ${fs.statSync(iesire).size} octeți)`);
