// Modelul de date și logica de business (fără DOM) — testabile separat.
// Structura este documentată în docs/MODEL_DATE.md (pregătită pentru portare nativă).
import {
  addDays, diffDays, isISO, todayISO, parseDateQuery, queryRange, rangesOverlap, zile,
  TERMEN_PLATA, PRAG_ROSU, TERMEN_ANAF, TERMEN_ASI, fmtDate, zinelucratoare,
} from './dates.js';

export const SCHEMA_VERSION = 4; // 2: Planuri/SVSU și PC · 3: construcția neregulii, seria/nr. amenzii, acte exerciții · 4: neregulă veche

export const TIP_OBIECTIV = [
  { key: 'OPEC', label: 'OPEC / Instituție' },
  { key: 'LOCALITATE', label: 'Localitate' },
];

const DNN = ['DA', 'NU', 'NEC']; // NEC = nu este cazul
const DN = ['DA', 'NU'];

// Dotări / instalații verificate pentru fiecare construcție
export const DOTARI = [
  { key: 'asi', label: 'ASI', opts: DNN },
  { key: 'aviz', label: 'AVIZ', opts: DNN },
  { key: 'hidInt', label: 'Hidranți interiori', opts: DNN },
  { key: 'hidExt', label: 'Hidranți exteriori', opts: DNN },
  { key: 'sprinklere', label: 'Sprinklere', opts: DNN },
  { key: 'drencere', label: 'Drencere', opts: DNN },
  { key: 'instSpeciale', label: 'Instalații speciale', opts: DNN },
  { key: 'idsai', label: 'IDSAI', opts: DNN },
  { key: 'exit', label: 'EXIT', opts: DNN },
  { key: 'desfumare', label: 'Desfumare', opts: DNN },
  { key: 'ignifugare', label: 'Ignifugare', opts: DNN },
  { key: 'rezervaApa', label: 'Rezervă de apă', opts: DNN },
  { key: 'statiePompe', label: 'Stație de pompe', opts: DNN },
  { key: 'fotovoltaice', label: 'Panouri fotovoltaice', opts: DN },
  { key: 'acumulatori', label: 'Acumulatori', opts: DN },
  { key: 'ilumHint', label: 'Iluminat Hint', opts: DN },
  { key: 'centrala', label: 'Centrală termică', centrala: true },
  { key: 'ipt', label: 'IPT', opts: DN },
];
export const CENTRALA_TIPURI = ['SOLID', 'GAZOS', 'ELECTRIC'];

export const ACTE = [
  { key: 'ctpsi', label: 'Dispoziție CTPSI / RESP' },
  { key: 'lfd', label: 'Dispoziție LFD' },
  { key: 'instruire', label: 'Dispoziție instruire' },
  { key: 'organizare', label: 'Dispoziție organizarea apărării împotriva incendiilor' },
  { key: 'comisie', label: 'Comisie PSI' },
  { key: 'sezon', label: 'Dispoziție măsuri sezon canicular / secetos / rece' },
  { key: 'controale', label: 'Controale proprii' },
  { key: 'analiza', label: 'Analiza semestrială' },
  { key: 'fise', label: 'Fișe de instruire completate corect' },
  { key: 'stingatoare', label: 'Verificare lunară a stingătoarelor' },
  { key: 'contract', label: 'Contract de transmitere temporară a unui bun imobil (art. 9 din Legea 307/2006)' },
  { key: 'exercitii', label: 'Exerciții efectuate' },
  { key: 'registreExercitii', label: 'Registrele exercițiilor sunt la zi' },
  { key: 'rapoarteExercitii', label: 'Rapoarte exerciții' },
];

// Categorii (cod de culori în interfață: bandă colorată + titlu de grup)
export const CATEGORII = {
  docs: 'Documentație și verificări',
  stingatoare: 'Stingătoare',
  electric: 'Instalații electrice și compartimentări',
  semnalizare: 'Semnalizare și iluminat',
  idsai: 'IDSAI',
  hidranti: 'Hidranți',
  desfumare: 'Desfumare',
  stingere: 'Sprinklere, drencere, instalații speciale',
  pompe: 'Stație de pompe / generator',
  planuri: 'Planuri',
  svsu: 'SVSU',
  avertizare: 'Avertizare – sirene',
  pcdotare: 'Dotare și adăpost',
  custom: 'Nereguli suplimentare',
};

// Secțiunile de constatări: fiecare are propriul tab în editor.
// „plan” și „pc” există doar la controalele de tip LOCALITATE.
export const SECTIUNI = {
  ner: { tab: 'nereguli', label: 'Nereguli', ok: 'Conform', nok: 'Constatat', onlyLocalitate: false },
  plan: { tab: 'planuri', label: 'Planuri și SVSU', ok: 'Conform', nok: 'Neconform', onlyLocalitate: true },
  pc: { tab: 'pc', label: 'Protecție civilă', ok: 'Conform', nok: 'Neconform', onlyLocalitate: true },
};

// `req`: neregula de instalație apare doar dacă cel puțin o construcție are DA la una din dotările listate
// („centrala” = are cel puțin un tip de centrală bifat).
const INST_C = ['idsai', 'hidInt', 'hidExt', 'desfumare', 'sprinklere', 'drencere', 'instSpeciale'];
export const NEREGULI = [
  { key: 'a', cat: 'docs', label: 'Nu a prezentat documentație ASI', asi: true },
  { key: 'b', cat: 'docs', label: 'Nu a prezentat / nu are verificare instalații electrice / IPT / CT' },
  { key: 'c', cat: 'docs', label: 'Nu a prezentat / nu are verificare IDSAI / Hint / Hext / Desfumare / Sprinklere / Drencere / Instalații speciale', req: INST_C },
  { key: 'd', cat: 'stingatoare', label: 'Stingătoare expirate' },
  { key: 'e', cat: 'stingatoare', label: 'Stingătoare neconforme' },
  { key: 'f', cat: 'electric', label: 'Instalații electrice exploatate incorect' },
  { key: 'g', cat: 'electric', label: 'Perete / planșeu / perete + planșeu cameră CT – 90 minute', req: ['centrala'] },
  { key: 'h', cat: 'electric', label: 'Ușă RF 15 minute cameră CT', req: ['centrala'] },
  { key: 'i', cat: 'electric', label: 'Ușă RF 60 minute cameră IDSAI', req: ['idsai'] },
  { key: 'j', cat: 'semnalizare', label: 'EXIT defect', req: ['exit'] },
  { key: 'k', cat: 'semnalizare', label: 'Iluminat Hint defect', req: ['ilumHint'] },
  { key: 'l', cat: 'idsai', label: 'Erori IDSAI', req: ['idsai'] },
  { key: 'm', cat: 'idsai', label: 'IDSAI nefuncțional', req: ['idsai'] },
  { key: 'n', cat: 'hidranti', label: 'Probleme Hint', req: ['hidInt'] },
  { key: 'o', cat: 'hidranti', label: 'Hint nefuncțional', req: ['hidInt'] },
  { key: 'p', cat: 'hidranti', label: 'Probleme Hext', req: ['hidExt'] },
  { key: 'q', cat: 'hidranti', label: 'Hext nefuncțional', req: ['hidExt'] },
  { key: 'r', cat: 'desfumare', label: 'Probleme desfumare', req: ['desfumare'] },
  { key: 's', cat: 'desfumare', label: 'Desfumare nefuncțională', req: ['desfumare'] },
  { key: 'ș', cat: 'stingere', label: 'Probleme sprinklere', req: ['sprinklere'] },
  { key: 't', cat: 'stingere', label: 'Sprinklere nefuncționale', req: ['sprinklere'] },
  { key: 'ț', cat: 'stingere', label: 'Probleme drencere', req: ['drencere'] },
  { key: 'u', cat: 'stingere', label: 'Drencere nefuncționale', req: ['drencere'] },
  { key: 'v', cat: 'stingere', label: 'Probleme instalații speciale', req: ['instSpeciale'] },
  { key: 'x', cat: 'stingere', label: 'Instalații speciale nefuncționale', req: ['instSpeciale'] },
  { key: 'y', cat: 'pompe', label: 'Probleme stație de pompe / generator', req: ['statiePompe'] },
  { key: 'z', cat: 'pompe', label: 'Stație de pompe / generator nefuncțional', req: ['statiePompe'] },
].map((n) => ({ ...n, sec: 'ner' }));

export const PLANURI = [
  { key: 'paar', cat: 'planuri', label: 'PAAR avizat', nokLabel: 'PAAR neavizat' },
  { key: 'plInundatii', cat: 'planuri', label: 'Plan inundații conform', nokLabel: 'Plan inundații neconform' },
  { key: 'plEvacuare', cat: 'planuri', label: 'Plan evacuare conform', nokLabel: 'Plan evacuare neconform' },
  { key: 'plCutremur', cat: 'planuri', label: 'Plan cutremur conform', nokLabel: 'Plan cutremur neconform' },
  { key: 'svsuAvizat', cat: 'svsu', label: 'SVSU avizat', nokLabel: 'SVSU neavizat' },
  { key: 'svsuSef', cat: 'svsu', label: 'Șef SVSU avizat', nokLabel: 'Șef SVSU neavizat' },
  { key: 'svsuDotare', cat: 'svsu', label: 'Dotare conformă', nokLabel: 'Dotare SVSU neconformă' },
  { key: 'svsuPlanPregatire', cat: 'svsu', label: 'Plan de pregătire avizat', nokLabel: 'Plan de pregătire neavizat' },
  { key: 'svsuGospodarii', cat: 'svsu', label: 'Controale gospodării', nokLabel: 'Controale gospodării neefectuate / neconforme' },
].map((n) => ({ ...n, sec: 'plan' }));

export const PROTECTIE_CIVILA = [
  { key: 'pcAudibilitate', cat: 'avertizare', label: 'Studiu de audibilitate', nokLabel: 'Lipsă studiu de audibilitate' },
  { key: 'pcSireneNumar', cat: 'avertizare', label: 'Număr suficient de sirene', nokLabel: 'Număr insuficient de sirene' },
  { key: 'pcSireneMentenanta', cat: 'avertizare', label: 'Contract mentenanță sirene', nokLabel: 'Lipsă contract mentenanță sirene' },
  { key: 'pcSireneDefecte', cat: 'avertizare', label: 'Sirene defecte' },
  { key: 'pcSireneNefunctionale', cat: 'avertizare', label: 'Sirene nefuncționale' },
  { key: 'pcDotare', cat: 'pcdotare', label: 'Dotare conformă planurilor comunei', nokLabel: 'Dotare neconformă cu planurile comunei' },
].map((n) => ({ ...n, sec: 'pc' }));

// Toate rândurile șablon, în toate secțiunile
export const SABLON = [...NEREGULI, ...PLANURI, ...PROTECTIE_CIVILA];
const SABLON_BY_KEY = new Map(SABLON.map((t) => [t.key, t]));
export const sablon = (key) => SABLON_BY_KEY.get(key);

export const STRUCTURI = ['Beton armat', 'Cadre din beton armat', 'Zidărie portantă', 'Structură metalică', 'Lemn', 'Mixtă'];
export const MATERIALE_PERETI = ['Cărămidă', 'BCA', 'Beton', 'Panouri sandwich', 'Gips-carton', 'Lemn', 'Mixt'];

export function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

export function emptyConstructie(nr = 1) {
  const dotari = {};
  for (const d of DOTARI) {
    dotari[d.key] = d.centrala ? { tipuri: [], nuAre: false, obs: '' } : { v: '', obs: '' };
  }
  return {
    id: uid(), denumire: `Construcția ${nr}`, suprafata: '', regimInaltime: '', nrAngajati: '',
    structura: '', materialPereti: '', dotari,
  };
}

// Neregulă (șablon sau custom). status: '' | 'ok' (conform) | 'nok' (constatată)
export function emptyNeregula(key, custom = false, sec = 'ner') {
  return {
    key, custom, sec, label: '', status: '', obs: '', inPV: false,
    constructieId: '',   // construcția în care s-a constatat; '' = prima construcție
    vecheManual: false,  // marcată manual ca „neregulă veche” (constatată și la controale anterioare)
    asiTermen: false, asiPrezentat: false, asiDataPrezentare: '',
    amenda: { aplicata: false, serie: '', numar: '', data: '', suma: '', achitata: false, dataAchitare: '' },
  };
}

export function newControl({ objectiveId, tip = 'OPEC', denumire = '', start } = {}) {
  const today = start || todayISO();
  const acte = {};
  for (const a of ACTE) acte[a.key] = { status: '', obs: '' };
  return {
    id: uid(),
    schema: SCHEMA_VERSION,
    objectiveId: objectiveId || uid(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    tip,
    denumire,
    administrator: '', telefon: '', email: '',
    dataInceput: today,
    dataIncheiere: '',
    constructii: [emptyConstructie(1)],
    acte,
    nereguli: SABLON.map((n) => emptyNeregula(n.key, false, n.sec)),
    adapostPC: { v: '', obs: '' },   // Adăpost de protecție civilă: DA / NU / NEC (doar LOCALITATE)
  };
}

// Control nou pe un obiectiv existent: preia datele de identificare și construcțiile
// (caracteristici + dotări) din ultimul control; actele și neregulile pornesc de la zero.
export function controlFromPrevious(prev, start) {
  const c = newControl({ objectiveId: prev.objectiveId, tip: prev.tip, denumire: prev.denumire, start });
  c.administrator = prev.administrator;
  c.telefon = prev.telefon;
  c.email = prev.email;
  c.constructii = JSON.parse(JSON.stringify(prev.constructii || [])).map((k) => ({ ...k, id: uid() }));
  if (!c.constructii.length) c.constructii = [emptyConstructie(1)];
  if (prev.adapostPC) c.adapostPC = { ...prev.adapostPC };
  return c;
}

// Completează câmpurile lipsă (date importate sau versiuni vechi).
export function normalizeControl(c) {
  const base = newControl({ objectiveId: c.objectiveId, start: c.dataInceput });
  const out = { ...base, ...c };
  out.acte = { ...base.acte, ...(c.acte || {}) };
  const byKey = new Map((c.nereguli || []).filter((n) => !n.custom).map((n) => [n.key, n]));
  const tmpl = SABLON.map((t) => ({ ...emptyNeregula(t.key, false, t.sec), ...(byKey.get(t.key) || {}), sec: t.sec }));
  const custom = (c.nereguli || []).filter((n) => n.custom).map((n) => ({ ...emptyNeregula(n.key, true), ...n, sec: n.sec || 'ner' }));
  out.nereguli = [...tmpl, ...custom].map((n) => ({ ...n, amenda: { ...emptyNeregula('').amenda, ...(n.amenda || {}) } }));
  out.constructii = (c.constructii && c.constructii.length ? c.constructii : base.constructii).map((k, i) => {
    const e = emptyConstructie(i + 1);
    return { ...e, ...k, dotari: { ...e.dotari, ...(k.dotari || {}) } };
  });
  out.adapostPC = { ...base.adapostPC, ...(c.adapostPC || {}) };
  return out;
}

export const isIncheiat = (c) => isISO(c.dataIncheiere);

// Construcția în care s-a făcut constatarea: cea aleasă sau, implicit, prima construcție.
// Dacă construcția aleasă a fost ștearsă, revine la prima.
export function constructieOf(c, n) {
  const list = c.constructii || [];
  return list.find((k) => k.id === n.constructieId) || list[0] || null;
}

// „Seria AB nr. 123456” (gol dacă nu s-a completat nimic)
export function amendaSerieNr(a) {
  const serie = String(a?.serie || '').trim();
  const numar = String(a?.numar || '').trim();
  if (!serie && !numar) return '';
  return [serie && `Seria ${serie}`, numar && `nr. ${numar}`].filter(Boolean).join(' ');
}

export function neregulaLabel(n) {
  if (n.custom) return n.label || 'Neregulă suplimentară';
  return sablon(n.key)?.label || n.label;
}

// Formularea constatării (ce se trece în PV / Panou): la rubricile formulate pozitiv („PAAR avizat”)
// se folosește forma negativă („PAAR neavizat”); la nereguli, textul lor.
export function constatareLabel(n) {
  if (n.custom) return neregulaLabel(n);
  const t = sablon(n.key);
  return (n.status === 'nok' && t?.nokLabel) || neregulaLabel(n);
}

export const neregulaCat = (n) => (n.custom ? 'custom' : sablon(n.key)?.cat || 'custom');
export const secOf = (n) => n.sec || 'ner';
export const tabOfNeregula = (n) => SECTIUNI[secOf(n)].tab;

// Numerotarea afișată: literă (a–z) la Nereguli, număr în cadrul grupului la Planuri/PC, „+n” la cele adăugate.
export function neregulaLetter(c, n) {
  if (n.custom) {
    const idx = c.nereguli.filter((x) => x.custom && secOf(x) === secOf(n)).indexOf(n);
    return `+${idx + 1}`;
  }
  const t = sablon(n.key);
  if (!t || t.sec === 'ner') return n.key;
  return String(SABLON.filter((x) => x.cat === t.cat).indexOf(t) + 1);
}

export const isLocalitate = (c) => c.tip === 'LOCALITATE';

// Secțiunile care se aplică acestui control (Planuri/PC doar la localități)
export function sectiuniActive(c) {
  return Object.keys(SECTIUNI).filter((k) => !SECTIUNI[k].onlyLocalitate || isLocalitate(c));
}

// Rândurile care contează (statistici, Panou, amenzi): cele din secțiunile active.
export function activeNereguli(c) {
  const secs = sectiuniActive(c);
  return c.nereguli.filter((n) => secs.includes(secOf(n)));
}

// Are obiectivul dotarea respectivă bifată DA în cel puțin o construcție?
export function hasDotare(c, key) {
  return (c.constructii || []).some((k) => {
    const v = k.dotari?.[key];
    if (!v) return false;
    return key === 'centrala' ? (v.tipuri || []).length > 0 : v.v === 'DA';
  });
}

// Neregulile de instalații apar doar dacă instalația există (DA la dotări).
// Un rând deja completat rămâne mereu vizibil, ca să nu „dispară” date.
export function isApplicable(c, n) {
  if (n.custom || n.status) return true;
  const req = sablon(n.key)?.req;
  return !req || req.some((k) => hasDotare(c, k));
}

// Statistici pentru o secțiune (tab)
export function secStats(c, sec, today = todayISO()) {
  const rows = c.nereguli.filter((n) => secOf(n) === sec);
  const visible = rows.filter((n) => isApplicable(c, n));
  const nok = rows.filter((n) => n.status === 'nok');
  let total = visible.length;
  let checked = visible.filter((n) => n.status).length;
  if (sec === 'pc') { total += 1; if (c.adapostPC?.v) checked += 1; }
  return {
    total, checked,
    hidden: rows.length - visible.length,
    constatate: nok.length,
    netrecute: nok.filter((n) => !n.inPV).length,
    fines: nok.filter((n) => n.amenda?.aplicata).map((n) => ({ n, st: fineStatus(c, n, today) })),
  };
}

// Data de la care curg termenele amenzii: data aplicării, implicit data încheierii.
export function fineDate(control, n) {
  if (isISO(n.amenda?.data)) return n.amenda.data;
  return isISO(control.dataIncheiere) ? control.dataIncheiere : '';
}

const maiSunt = (n) => (n === 1 ? 'Mai este 1 zi' : `Mai sunt ${zile(n)}`);

// Stadiul amenzii:
//   green  = achitată, dovadă primită
//   blue   = în curs (în termenul de 15 zile)
//   yellow = termenul de 15 zile a expirat
//   red    = au trecut 25 de zile după cele 15 inițiale → mai sunt ≤ 5 zile până la ANAF
export function fineStatus(control, n, today = todayISO()) {
  const a = n.amenda || {};
  if (a.achitata) {
    return { level: 'green', label: 'Achitată', msg: a.dataAchitare ? `Dovadă primită · ${fmtDate(a.dataAchitare)}` : 'Dovadă de plată primită' };
  }
  const d = fineDate(control, n);
  if (!d) {
    return { level: 'blue', label: 'În curs', msg: 'Termenele pornesc de la data încheierii controlului', pending: true };
  }
  const elapsed = diffDays(d, today);
  const plataPana = addDays(d, TERMEN_PLATA);
  const anafPana = addDays(d, TERMEN_ANAF);
  // Termenul NU se mută automat; doar se semnalează ziua nelucrătoare.
  const plataNelucr = zinelucratoare(plataPana);
  const anafNelucr = zinelucratoare(anafPana);
  const leftAnaf = TERMEN_ANAF - elapsed;
  if (elapsed <= TERMEN_PLATA) {
    const left = TERMEN_PLATA - Math.max(elapsed, 0);
    return {
      level: 'blue', label: 'În curs', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: left,
      nelucr: plataNelucr ? `Termenul de plată (${fmtDate(plataPana)}) cade ${plataNelucr} — verifică prelungirea` : '',
      msg: left === 0 ? 'Astăzi este ultima zi de plată' : `${maiSunt(left)} din termenul de plată (${fmtDate(plataPana)})`,
    };
  }
  if (elapsed < PRAG_ROSU) {
    const over = elapsed - TERMEN_PLATA;
    return {
      level: 'yellow', label: 'Termen 15 zile expirat', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: leftAnaf,
      nelucr: anafNelucr ? `Termenul ANAF (${fmtDate(anafPana)}) cade ${anafNelucr} — verifică prelungirea` : '',
      msg: `Termenul de plată a expirat de ${zile(over)} (${fmtDate(plataPana)})`,
    };
  }
  let msg;
  if (leftAnaf > 0) msg = `Mai ai ${zile(leftAnaf)} până să o trimiți la ANAF, consultă calculatorul de termene`;
  else if (leftAnaf === 0) msg = 'Astăzi este ultima zi pentru trimiterea la ANAF, consultă calculatorul de termene';
  else msg = `Termenul de trimitere la ANAF (${fmtDate(anafPana)}) a fost depășit cu ${zile(-leftAnaf)}`;
  return {
    level: 'red', label: 'Trimite la ANAF', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: leftAnaf, msg,
    nelucr: anafNelucr && leftAnaf >= 0 ? `Termenul ANAF (${fmtDate(anafPana)}) cade ${anafNelucr} — verifică prelungirea` : '',
  };
}

// Termenul de 90 de zile pentru prezentarea documentației ASI.
export function asiDeadline(control, today = todayISO()) {
  const n = control.nereguli.find((x) => x.key === 'a' && !x.custom);
  if (!n || n.status !== 'nok' || !n.asiTermen) return null;
  if (n.asiPrezentat) {
    return { resolved: true, msg: `Documentație prezentată${isISO(n.asiDataPrezentare) ? ' · ' + fmtDate(n.asiDataPrezentare) : ''}` };
  }
  if (!isISO(control.dataIncheiere)) {
    return { pending: true, msg: 'Termenul de 90 de zile începe după încheierea controlului' };
  }
  const deadline = addDays(control.dataIncheiere, TERMEN_ASI);
  const left = diffDays(today, deadline);
  let msg;
  if (left > 0) msg = `${maiSunt(left)} până la ${fmtDate(deadline)}`;
  else if (left === 0) msg = `Termenul expiră astăzi (${fmtDate(deadline)})`;
  else msg = `Termen depășit cu ${zile(-left)} (${fmtDate(deadline)})`;
  const nl = zinelucratoare(deadline);
  return { deadline, daysLeft: left, msg, nelucr: nl && left >= 0 ? `Termenul (${fmtDate(deadline)}) cade ${nl} — verifică prelungirea` : '' };
}

// Statistici pentru un control
export function controlStats(c, today = todayISO()) {
  const rows = activeNereguli(c);
  const nok = rows.filter((n) => n.status === 'nok');
  const acteDone = ACTE.filter((a) => c.acte[a.key]?.status).length;
  const acteNok = ACTE.filter((a) => c.acte[a.key]?.status === 'nok').length;
  const nereguliChecked = rows.filter((n) => n.status).length;
  const fines = nok.filter((n) => n.amenda?.aplicata).map((n) => ({ n, st: fineStatus(c, n, today) }));
  return {
    acteDone, acteTotal: ACTE.length, acteNok,
    nereguliChecked, nereguliTotal: rows.length,
    constatate: nok.length,
    netrecute: nok.filter((n) => !n.inPV).length,
    fines,
    asi: asiDeadline(c, today),
  };
}

// Grupare pe obiective — datele obiectivului se iau din cel mai recent control.
export function objectives(controls) {
  const map = new Map();
  for (const c of controls) {
    if (!map.has(c.objectiveId)) map.set(c.objectiveId, []);
    map.get(c.objectiveId).push(c);
  }
  const out = [];
  for (const [id, list] of map) {
    list.sort(byStartDesc);
    const last = list[0];
    out.push({
      id, controls: list, last,
      denumire: last.denumire, tip: last.tip, administrator: last.administrator,
      telefon: last.telefon, email: last.email,
    });
  }
  return out.sort((a, b) => byStartDesc(a.last, b.last));
}

export function byStartDesc(a, b) {
  return (b.dataInceput || '').localeCompare(a.dataInceput || '') || (b.createdAt || '').localeCompare(a.createdAt || '');
}

export function fold(s) {
  return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[şș]/g, 's').replace(/[ţț]/g, 't');
}

// Interval acoperit de un control (un control neîncheiat se consideră până la încheiere = start)
export function controlRange(c) {
  const s = c.dataInceput;
  const e = isISO(c.dataIncheiere) && c.dataIncheiere >= s ? c.dataIncheiere : s;
  return [s, e];
}

// Căutare după nume (fără diacritice) sau după dată (zi, lună, an)
export function matchControl(c, query) {
  const q = String(query || '').trim();
  if (!q) return true;
  const dq = parseDateQuery(q);
  if (dq) {
    const [a, b] = queryRange(dq);
    const [s, e] = controlRange(c);
    return rangesOverlap(s, e, a, b);
  }
  const hay = fold([c.denumire, c.administrator, c.telefon, c.email].join(' '));
  return fold(q).split(/\s+/).every((w) => hay.includes(w));
}

// Toate amenzile, cu stadiu, sortate după urgență
export function allFines(controls, today = todayISO()) {
  const order = { red: 0, yellow: 1, blue: 2, green: 3 };
  const out = [];
  for (const c of controls) {
    for (const n of activeNereguli(c)) {
      if (n.status === 'nok' && n.amenda?.aplicata) out.push({ c, n, st: fineStatus(c, n, today) });
    }
  }
  return out.sort((x, y) => order[x.st.level] - order[y.st.level]
    || (x.st.daysLeft ?? 999) - (y.st.daysLeft ?? 999));
}

export function allAsi(controls, today = todayISO()) {
  const out = [];
  for (const c of controls) {
    const a = asiDeadline(c, today);
    if (a && !a.resolved) out.push({ c, a });
  }
  return out.sort((x, y) => (x.a.daysLeft ?? 9999) - (y.a.daysLeft ?? 9999));
}

// ───────── Neregulă veche ─────────
// Același rând (aceeași cheie; la rândurile adăugate: același text) constatat și la un control anterior
// al aceluiași obiectiv. Întoarce cel mai recent astfel de control, sau null.
function sameRow(a, b) {
  if (a.custom || b.custom) return !!(a.custom && b.custom && fold(a.label).trim() && fold(a.label).trim() === fold(b.label).trim());
  return a.key === b.key;
}
export function controaleAnterioare(controls, c) {
  return controls
    .filter((x) => x.objectiveId === c.objectiveId && x.id !== c.id
      && ((x.dataInceput || '') < (c.dataInceput || '') || (x.dataInceput === c.dataInceput && (x.createdAt || '') < (c.createdAt || ''))))
    .sort(byStartDesc);
}
export function constatareAnterioara(controls, c, n) {
  for (const prev of controaleAnterioare(controls, c)) {
    if (prev.nereguli.some((m) => m.status === 'nok' && sameRow(m, n))) return prev;
  }
  return null;
}
// { veche, auto: control anterior | null, manual }
export function vecheInfo(controls, c, n) {
  const auto = constatareAnterioara(controls, c, n);
  const manual = !!n.vecheManual;
  return { veche: n.status === 'nok' && (!!auto || manual), auto, manual };
}

// ───────── Text pentru procesul-verbal ─────────
export function pvText(c, controls = [], { doarNetrecute = false, cuActe = true } = {}) {
  const lines = [];
  const perioada = isISO(c.dataIncheiere) && c.dataIncheiere !== c.dataInceput
    ? `${fmtDate(c.dataInceput)} – ${fmtDate(c.dataIncheiere)}` : fmtDate(c.dataInceput);
  lines.push(`Nereguli constatate – ${c.denumire || 'obiectiv fără denumire'} (control ${perioada})`);
  let nr = 0;
  const multe = (c.constructii || []).length > 1;
  for (const sec of sectiuniActive(c)) {
    const rows = c.nereguli.filter((n) => secOf(n) === sec && n.status === 'nok' && (!doarNetrecute || !n.inPV));
    if (!rows.length) continue;
    lines.push('', `${SECTIUNI[sec].label}:`);
    for (const n of rows) {
      let t = `${++nr}. ${constatareLabel(n)}`;
      const k = constructieOf(c, n);
      if (sec === 'ner' && multe && k) t += ` – construcția: ${k.denumire}`;
      if (n.obs && n.obs.trim()) t += `. ${n.obs.trim().replace(/\s*\n\s*/g, '; ')}`;
      const extra = [];
      if (vecheInfo(controls, c, n).veche) extra.push('neregulă veche');
      if (n.amenda?.aplicata) extra.push(`sancționat cu amendă${amendaSerieNr(n.amenda) ? ` ${amendaSerieNr(n.amenda)}` : ''}`);
      if (extra.length) t += ` (${extra.join('; ')})`;
      lines.push(t);
    }
  }
  if (cuActe) {
    const lipsa = ACTE.filter((a) => c.acte[a.key]?.status === 'nok');
    if (lipsa.length) {
      lines.push('', 'Acte de autoritate și evidențe lipsă:');
      lipsa.forEach((a) => {
        const obs = c.acte[a.key].obs?.trim();
        lines.push(`${++nr}. ${a.label}${obs ? `. ${obs.replace(/\s*\n\s*/g, '; ')}` : ''}`);
      });
    }
  }
  if (!nr) lines.push('', doarNetrecute ? 'Toate neregulile constatate sunt deja trecute în PV.' : 'Nu au fost constatate nereguli.');
  return { text: lines.join('\n'), count: nr };
}
