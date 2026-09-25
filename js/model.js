// Modelul de date și logica de business (fără DOM) — testabile separat.
// Structura este documentată în docs/MODEL_DATE.md (pregătită pentru portare nativă).
import {
  addDays, diffDays, isISO, todayISO, parseDateQuery, queryRange, rangesOverlap, zile,
  TERMEN_PLATA, PRAG_ROSU, TERMEN_ANAF, TERMEN_ASI, TERMEN_PIERDERE_ASI, TERMEN_INCARCARE, fmtDate, zinelucratoare, addMonths,
  addWorkingDays, workingDaysBetween, nextWorkingDay, fmtDateLong,
} from './dates.js';

export const SCHEMA_VERSION = 10; // 2: Planuri/SVSU și PC · 3: construcția neregulii, seria/nr. amenzii, acte exerciții · 4: neregulă veche · 5: nereguli noi, detectori autonomi, nereguli grave (NU la dotări) · 6: adresă, localitate, GPS · 7: mai multe construcții pe neregulă, GRF/NSI pe construcție · 8: nereguli ah, ai · 9: verificări defalcate cu date pe construcție, NEC, aj/ak, an construire, nr. ASI/aviz · 10: lista înghețată la încheiere (catalog), seria și nr. amenzii într-un câmp

export const TIP_OBIECTIV = [
  { key: 'OPEC', label: 'OPEC / Instituție' },
  { key: 'LOCALITATE', label: 'Localitate' },
];

const DNN = ['DA', 'NU', 'NEC']; // NEC = nu este cazul
const DN = ['DA', 'NU'];

// Dotări / instalații verificate pentru fiecare construcție
export const DOTARI = [
  { key: 'asi', label: 'ASI', opts: DNN, nr: 'Nr. autorizație' },   // `nr`: la DA se completează numărul
  { key: 'aviz', label: 'AVIZ', opts: DNN, nr: 'Nr. aviz' },
  { key: 'hidInt', label: 'Hidranți interiori', opts: DNN },
  { key: 'hidExt', label: 'Hidranți exteriori', opts: DNN },
  { key: 'sprinklere', label: 'Sprinklere', opts: DNN },
  { key: 'drencere', label: 'Drencere', opts: DNN },
  { key: 'instSpeciale', label: 'Instalații speciale', opts: DNN },
  { key: 'idsai', label: 'IDSAI', opts: DNN },
  { key: 'detectoriAutonomi', label: 'Detectori autonomi', opts: DNN },
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
  lipsa: 'Instalații lipsă (NU la dotări) — nereguli grave',
  grf: 'Rezistență la foc (GRF/NSI) — neregulă gravă',
  docs: 'Documentație și verificări',
  stingatoare: 'Stingătoare',
  electric: 'Instalații electrice și compartimentări',
  semnalizare: 'Semnalizare și iluminat',
  idsai: 'IDSAI',
  hidranti: 'Hidranți',
  desfumare: 'Desfumare',
  stingere: 'Sprinklere, drencere, instalații speciale',
  pompe: 'Stație de pompe / generator',
  evacuare: 'Evacuare și instrucțiuni',
  detectoare: 'Detectoare și ignifugare',
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
  // primele din listă (foarte importante); se completează automat la NU pentru ASI / AVIZ la dotări
  { key: 'ah', din: 8, cat: 'docs', label: 'Construcția funcționează fără ASI (autorizație de securitate la incendiu)', autoNU: 'asi' },
  { key: 'ai', din: 8, cat: 'docs', label: 'Lucrări de extindere / modificare a clădirii sau a instalațiilor realizate fără aviz', autoNU: 'aviz' },
  { key: 'a', cat: 'docs', label: 'Nu a prezentat documentație ASI', asi: true },
  // Verificări, defalcate pe instalație; data ultimei verificări se completează pe fiecare construcție.
  // `verif`: perioada de valabilitate în luni (b2: la alegere 12 / 24, pe construcție). b1–b3: toate construcțiile.
  { key: 'b1', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare instalații electrice', verif: 12 },
  { key: 'b2', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare împământare (IPT)', verif: 12, verifAlegeri: [12, 24] },
  { key: 'b3', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare CT (centrală termică)', verif: 24 },
  { key: 'c1', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare IDSAI', req: ['idsai'], verif: 12 },
  { key: 'c2', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare hidranți interiori', req: ['hidInt'], verif: 6 },
  { key: 'c3', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare hidranți exteriori', req: ['hidExt'], verif: 6 },
  { key: 'c4', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare desfumare', req: ['desfumare'], verif: 12 },
  { key: 'c5', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare sprinklere', req: ['sprinklere'], verif: 12 },
  { key: 'c6', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare drencere', req: ['drencere'], verif: 12 },
  { key: 'c7', din: 9, cat: 'docs', label: 'Nu a prezentat / nu are verificare instalații speciale', req: ['instSpeciale'], verif: 12 },
  // până la v1.10: verificările grupate; rămân doar în controalele în care au fost completate (retras)
  { key: 'b', cat: 'docs', label: 'Nu a prezentat / nu are verificare instalații electrice / IPT / CT', retrasDin: 9 },
  { key: 'c', cat: 'docs', label: 'Nu a prezentat / nu are verificare IDSAI / Hint / Hext / Desfumare / Sprinklere / Drencere / Instalații speciale', req: INST_C, retrasDin: 9 },
  { key: 'd', cat: 'stingatoare', label: 'Stingătoare expirate' },
  { key: 'e', cat: 'stingatoare', label: 'Stingătoare neconforme' },
  { key: 'al', din: 9, cat: 'stingatoare', label: 'Stingătoare insuficiente / lipsă' },
  { key: 'f', cat: 'electric', label: 'Instalații electrice exploatate incorect' },
  { key: 'g', cat: 'electric', label: 'Perete / planșeu / perete + planșeu cameră CT – 90 minute', req: ['centrala'] },
  { key: 'h', cat: 'electric', label: 'Ușă RF 15 minute cameră CT', req: ['centrala'] },
  { key: 'i', cat: 'electric', label: 'Ușă RF 60 minute cameră IDSAI', req: ['idsai'] },
  { key: 'j', cat: 'semnalizare', label: 'EXIT defect', req: ['exit'] },
  { key: 'aj', din: 9, cat: 'semnalizare', label: 'EXIT incomplet', req: ['exit'] },
  { key: 'k', cat: 'semnalizare', label: 'Iluminat Hint defect', req: ['ilumHint'] },
  { key: 'ak', din: 9, cat: 'semnalizare', label: 'Iluminat Hint incomplet', req: ['ilumHint'] },
  // NU la Iluminat Hint → constatată automat (ca ah / ai), vizibilă doar cât timp o construcție are NU
  { key: 'am', din: 9, cat: 'semnalizare', label: 'Lipsă iluminat Hint', autoNU: 'ilumHint', doarLaNU: true },
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
  { key: 'aa', din: 5, cat: 'evacuare', label: 'Planuri de evacuare neafișate corespunzător' },
  { key: 'ab', din: 5, cat: 'evacuare', label: 'Căi de evacuare blocate / obturate' },
  { key: 'ac', din: 5, cat: 'evacuare', label: 'Lipsă instrucțiuni de utilizare a echipamentelor de gătit' },
  { key: 'ad', din: 5, cat: 'evacuare', label: 'Lipsă instrucțiuni de comportare (turism)' },
  { key: 'ae', din: 5, cat: 'detectoare', label: 'Detector de gaz defect / inexistent' },
  { key: 'af', din: 5, cat: 'detectoare', label: 'Detectori autonomi nefuncționali', req: ['detectoriAutonomi'] },
  { key: 'ag', din: 5, cat: 'detectoare', label: 'Ignifugare expirată', req: ['ignifugare'] },
].map((n) => ({ ...n, sec: 'ner' }));

// NU la o instalație (unde NEC = „nu este cazul” e altă opțiune) = instalație necesară care lipsește → neregulă gravă.
// Pentru fiecare astfel de dotare există un rând „Lipsă …”, afișat doar cât timp cel puțin o construcție are NU.
// ASI și AVIZ sunt documente, nu instalații (lipsa lor e acoperită de neregula „a”).
export const LIPSA_DOTARI = ['hidInt', 'hidExt', 'sprinklere', 'drencere', 'instSpeciale', 'idsai', 'detectoriAutonomi',
  'exit', 'desfumare', 'ignifugare', 'rezervaApa', 'statiePompe'];
const LIPSA_LABEL = {
  hidInt: 'Lipsă hidranți interiori', hidExt: 'Lipsă hidranți exteriori', sprinklere: 'Lipsă instalație de sprinklere',
  drencere: 'Lipsă instalație de drencere', instSpeciale: 'Lipsă instalații speciale de stingere', idsai: 'Lipsă IDSAI',
  detectoriAutonomi: 'Lipsă detectori autonomi', exit: 'Lipsă marcaje EXIT', desfumare: 'Lipsă instalație de desfumare',
  ignifugare: 'Lipsă ignifugare', rezervaApa: 'Lipsă rezervă de apă', statiePompe: 'Lipsă stație de pompe',
};
export const NEREGULI_GRAVE = [
  ...LIPSA_DOTARI.map((k, i) => ({
    key: `lipsa-${k}`, din: 5, cat: 'lipsa', sec: 'ner', grav: true, reqNU: k, letter: `G${i + 1}`, label: LIPSA_LABEL[k],
  })),
  // GRF/NSI V cu regim de înălțime peste parter (P+1, P+2E, P+M…) — regula stabilită de utilizator
  { key: 'grav-grfV', din: 7, cat: 'grf', sec: 'ner', grav: true, reqGrfV: true, letter: `G${LIPSA_DOTARI.length + 1}`,
    label: 'Construcție cu GRF/NSI V și regim de înălțime peste parter' },
];

// Gradul de rezistență la foc / nivelul de stabilitate la incendiu al construcției; 'NN' = nu e necesar
export const GRF_NIVELURI = ['I', 'II', 'III', 'IV', 'V'];
export const grfText = (v) => (v === 'NN' ? 'Nu e necesar' : v || '');
// „Peste parter” = regimul de înălțime are ceva după P: P+1, P+2E, S+P+1, D+P+M, Parter + 1 etaj…
export function pesteParter(regim) {
  const s = String(regim || '').toUpperCase().replace(/PARTER/g, 'P').replace(/\s+/g, '');
  return /(^|[^A-Z])P\+[^+]/.test(s);
}
export const grfVPesteParter = (k) => k?.grf === 'V' && pesteParter(k.regimInaltime);

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
export const SABLON = [...NEREGULI_GRAVE, ...NEREGULI, ...PLANURI, ...PROTECTIE_CIVILA];
const SABLON_BY_KEY = new Map(SABLON.map((t) => [t.key, t]));
export const sablon = (key) => SABLON_BY_KEY.get(key);

export const STRUCTURI = ['Beton armat', 'Cadre din beton armat', 'Zidărie portantă', 'Structură metalică', 'Lemn', 'Mixtă'];
export const MATERIALE_PERETI = ['Cărămidă', 'BCA', 'Beton', 'Panouri sandwich', 'Gips-carton', 'Lemn', 'Mixt'];

// Suma scrisă de inspector, în lei: „2500”, „2.500”, „2 500”, „1.500,50”, „1500,5” (punct = mii, virgulă = zecimale).
// Întoarce numărul sau null dacă textul nu e o sumă.
export function parseSuma(v) {
  let x = String(v ?? '').replace(/lei/gi, '').replace(/\s/g, '');
  if (!x) return null;
  if (x.includes(',')) x = x.replace(/\./g, '').replace(',', '.');
  else if (/^\d{1,3}(\.\d{3})+$/.test(x)) x = x.replace(/\./g, '');
  const n = Number(x);
  return Number.isFinite(n) ? n : null;
}

export function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

export function emptyConstructie(nr = 1) {
  const dotari = {};
  for (const d of DOTARI) {
    dotari[d.key] = d.centrala ? { tipuri: [], nuAre: false, obs: '' } : { v: '', obs: '', ...(d.nr ? { nr: '' } : {}) };
  }
  return {
    id: uid(), denumire: `Construcția ${nr}`, suprafata: '', regimInaltime: '', nrAngajati: '', anConstruire: '',
    structura: '', materialPereti: '', dotari,
    grf: '',     // GRF/NSI: 'I'…'V' sau 'NN' (nu e necesar); '' = necompletat
    gps: null,   // { lat, lon, acc (m), la (ISO) } — coordonatele construcției, preluate la cerere cu „Completează coordonatele”
  };
}

// Neregulă (șablon sau custom). status: '' | 'ok' (conform) | 'nok' (constatată)
export function emptyNeregula(key, custom = false, sec = 'ner') {
  return {
    key, custom, sec, label: '', status: '', obs: '', inPV: false,
    constructieIds: [],  // construcțiile în care s-a constatat (una sau mai multe); [] = implicit (prima / cele cu NU)
    vecheManual: false,  // marcată manual ca „neregulă veche” (constatată și la controale anterioare)
    grav: false,         // doar la rândurile adăugate: marcată de inspector ca neregulă gravă
    sigiliu: false,      // la neregulile grave: s-a aplicat sigiliu în baza acestei nereguli
    auto: false,         // ah / ai: constatată automat din NU la ASI / AVIZ (dotări)
    verificari: {},      // rândurile de verificare: idConstrucție → { data: 'AAAA-LL-ZZ', luni } (data ultimei verificări)
    obsAuto: '',         // ultimele observații preluate automat din dotări (dacă obs === obsAuto, nu au fost editate)
    asiTermen: false, asiPrezentat: false, asiDataPrezentare: '',
    asiPierdere: false, asiDataPierdere: '',   // după cele 90 de zile: pierderea valabilității, constatată (și data)
    amenda: { aplicata: false, serieNr: '', data: '', suma: '', achitata: false, dataAchitare: '' },   // serieNr: „DB 0012345”
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
    adresa: '', localitate: '',
    dataInceput: today,
    dataIncheiere: '',
    constructii: [emptyConstructie(1)],
    acte,
    nereguli: SABLON.map((n) => emptyNeregula(n.key, false, n.sec)),
    adapostPC: { v: '', obs: '' },   // Adăpost de protecție civilă: DA / NU / NEC (doar LOCALITATE)
    // După încheiere: controlul încărcat în aplicația ISU și documentul (PV scanat) încărcat — bifa și data bifării
    incarcare: { aplicatie: false, aplicatieData: '', document: false, documentData: '' },
  };
}

// Control nou pe un obiectiv existent: preia datele de identificare și construcțiile
// (caracteristici + dotări) din ultimul control; actele și neregulile pornesc de la zero.
export function controlFromPrevious(prev, start) {
  const c = newControl({ objectiveId: prev.objectiveId, tip: prev.tip, denumire: prev.denumire, start });
  c.administrator = prev.administrator;
  c.telefon = prev.telefon;
  c.email = prev.email;
  c.adresa = prev.adresa || '';
  c.localitate = prev.localitate || '';
  const idNou = new Map();
  c.constructii = JSON.parse(JSON.stringify(prev.constructii || [])).map((k) => { const id = uid(); idNou.set(k.id, id); return { ...k, id }; });
  if (!c.constructii.length) c.constructii = [emptyConstructie(1)];
  // datele ultimelor verificări rămân valabile de la un control la altul (se actualizează la nevoie)
  for (const n of c.nereguli) {
    const p = isVerificare(n) && (prev.nereguli || []).find((x) => x.key === n.key);
    if (!p?.verificari) continue;
    for (const [kid, v] of Object.entries(p.verificari)) if (idNou.has(kid)) n.verificari[idNou.get(kid)] = { ...v };
  }
  if (prev.adapostPC) c.adapostPC = { ...prev.adapostPC };
  for (const dot of Object.keys(AUTO_NU)) syncAutoNU(c, dot);   // NU la ASI / AVIZ moștenit → neregula apare din start
  return c;
}

// ───────── NU la ASI / AVIZ (dotări) → neregulile ah / ai, completate automat ─────────
export const AUTO_NU = { asi: 'ah', aviz: 'ai', ilumHint: 'am' };

function obsDinDotari(c, list, dot) {
  const multe = (c.constructii || []).length > 1;
  return list.filter((k) => k.dotari?.[dot]?.obs?.trim())
    .map((k) => `${multe ? `${k.denumire || 'Construcție'}: ` : ''}${k.dotari[dot].obs.trim()}`).join('\n');
}

// Aduce neregula în acord cu dotările. Returnează 'added' | 'updated' | 'removed' | 'kept' | null.
// Nu pierde date: observațiile editate de inspector nu se suprascriu; o neregulă lucrată (PV, amendă,
// sigiliu, observații proprii) nu se șterge când NU dispare, doar încetează să mai fie automată.
// `obsOnly`: s-au schimbat doar observațiile din dotări → se actualizează doar observațiile.
export function syncAutoNU(c, dot, { obsOnly = false } = {}) {
  const n = c.nereguli.find((x) => x.key === AUTO_NU[dot]);
  if (!n) return null;
  const list = constructiiCuNU(c, dot);
  const obs = obsDinDotari(c, list, dot);
  const obsProprii = !!(n.obs && n.obs.trim() && n.obs !== (n.obsAuto || ''));
  if (obsOnly) {
    if (list.length && n.auto && n.status === 'nok' && !obsProprii && n.obs !== obs) { n.obs = obs; n.obsAuto = obs; return 'updated'; }
    return null;
  }
  if (list.length) {
    const nou = n.status !== 'nok';
    n.status = 'nok';
    n.auto = true;
    n.constructieIds = list.map((k) => k.id);
    if (!obsProprii) { n.obs = obs; n.obsAuto = obs; }
    return nou ? 'added' : 'updated';
  }
  if (n.auto && n.status === 'nok') {
    const lucrata = obsProprii || n.inPV || n.amenda?.aplicata || n.sigiliu || n.vecheManual;
    n.auto = false;
    if (lucrata) return 'kept';
    Object.assign(n, { status: '', obs: '', obsAuto: '', constructieIds: [] });
    return 'removed';
  }
  return null;
}

// Completează câmpurile lipsă (date importate sau versiuni vechi).
export function normalizeControl(c) {
  const base = newControl({ objectiveId: c.objectiveId, start: c.dataInceput });
  const out = { ...base, ...c };
  out.acte = { ...base.acte, ...(c.acte || {}) };
  const byKey = new Map((c.nereguli || []).filter((n) => !n.custom).map((n) => [n.key, n]));
  const tmpl = SABLON.map((t) => ({ ...emptyNeregula(t.key, false, t.sec), ...(byKey.get(t.key) || {}), sec: t.sec }));
  const custom = (c.nereguli || []).filter((n) => n.custom).map((n) => ({ ...emptyNeregula(n.key, true), ...n, sec: n.sec || 'ner' }));
  out.nereguli = [...tmpl, ...custom].map((n) => {
    // până la v1.8: o singură construcție (constructieId); de la v1.9: listă (constructieIds)
    const { constructieId, ...rest } = n;
    // (șablonul gol aduce constructieIds: [], deci lista goală nu trebuie să ascundă alegerea veche)
    const ids = n.constructieIds?.length ? [...n.constructieIds] : constructieId ? [constructieId] : [];
    // până la v1.11: seria și numărul în câmpuri separate → un singur câmp
    const { serie, numar, ...am } = n.amenda || {};
    if (!am.serieNr && (serie || numar)) am.serieNr = [serie, numar].map((x) => String(x || '').trim()).filter(Boolean).join(' ');
    return { ...rest, constructieIds: ids, amenda: { ...emptyNeregula('').amenda, ...am } };
  });
  out.constructii = (c.constructii && c.constructii.length ? c.constructii : base.constructii).map((k, i) => {
    const e = emptyConstructie(i + 1);
    const dotari = { ...e.dotari };
    for (const [key, v] of Object.entries(k.dotari || {})) dotari[key] = { ...(e.dotari[key] || {}), ...v };
    return { ...e, ...k, dotari };
  });
  // Coordonatele stăteau pe control, nu pe construcție, într-o versiune de probă: se mută la prima construcție.
  if (out.gps && !out.constructii[0].gps) out.constructii[0] = { ...out.constructii[0], gps: out.gps };
  delete out.gps;
  out.adapostPC = { ...base.adapostPC, ...(c.adapostPC || {}) };
  out.incarcare = { ...base.incarcare, ...(c.incarcare || {}) };
  out.schema = c.schema || 1;
  if (isIncheiat(out) && !out.catalog) out.catalog = out.schema;
  return out;
}

export const isIncheiat = (c) => isISO(c.dataIncheiere);

// ───────── Lista de nereguli a unui control ─────────
// Un control încheiat păstrează lista versiunii în care a fost încheiat (`catalog`): rândurile apărute după nu
// i se adaugă, cele retrase între timp îi rămân. Un control deschis folosește lista curentă. Datele completate
// se văd mereu (un rând cu status nu se ascunde niciodată).
export const catalogOf = (c) => (isIncheiat(c) ? (c.catalog || c.schema || 1) : SCHEMA_VERSION);
export function inCatalog(c, t) {
  const v = catalogOf(c);
  return (t.din || 1) <= v && !(t.retrasDin && v >= t.retrasDin);
}
// Se apelează la fiecare salvare: încheierea fixează lista, redeschiderea o eliberează.
export function fixeazaCatalog(c) {
  if (isIncheiat(c) && !c.catalog) c.catalog = SCHEMA_VERSION;
  else if (!isIncheiat(c) && c.catalog) delete c.catalog;
}

// Construcțiile în care s-a făcut constatarea, în ordinea din tabul Obiectiv. Neales nimic (sau alese
// doar construcții șterse între timp): la neregulile grave, cele cu NU la dotare; altfel, prima construcție.
export function constructiiOf(c, n) {
  const list = c.constructii || [];
  const ids = new Set(n.constructieIds || []);
  const alese = list.filter((k) => ids.has(k.id));
  if (alese.length) return alese;
  const t = n && !n.custom ? SABLON_BY_KEY.get(n.key) : null;
  const decl = (t && constructiiDeclansate(c, t)) || [];
  if (decl.length) return decl;
  const elig = constructiiEligibile(c, n);   // implicit: prima construcție care are instalația
  return elig.length ? [elig[0]] : [];
}
export const constructieOf = (c, n) => constructiiOf(c, n)[0] || null;
export const constructiiNume = (c, n) => constructiiOf(c, n).map((k) => k.denumire || `Construcția ${c.constructii.indexOf(k) + 1}`).join(', ');

// Construcțiile care declanșează o neregulă gravă (NU la dotare sau GRF/NSI V peste parter); null = nu e gravă
export function constructiiDeclansate(c, t) {
  if (t?.reqNU) return constructiiCuNU(c, t.reqNU);
  if (t?.reqGrfV) return (c.constructii || []).filter(grfVPesteParter);
  return null;
}

// Construcțiile care au NU la o dotare (instalație necesară, lipsă)
export function constructiiCuNU(c, key) {
  return (c.constructii || []).filter((k) => k.dotari?.[key]?.v === 'NU');
}

// „Seria AB nr. 123456” (gol dacă nu s-a completat nimic)
export function amendaSerieNr(a) {
  // un singur câmp („DB 0012345”, „Seria DB nr. 0012345”); datele vechi pot avea încă serie + numar
  const t = (String(a?.serieNr || '').trim() || [a?.serie, a?.numar].map((x) => String(x || '').trim()).filter(Boolean).join(' '))
    .replace(/\s+/g, ' ');
  if (!t) return '';
  const m = t.match(/^(?:seria\s*)?([a-zăâîșț]{1,5})[\s.,/-]*(?:nr\.?\s*)?(\d[\d ]*)$/i);
  if (m) return `Seria ${m[1].toUpperCase()} nr. ${m[2].replace(/ /g, '')}`;
  if (/^\d[\d ]*$/.test(t)) return `nr. ${t.replace(/ /g, '')}`;
  return t;
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

// Neregulă gravă: din listă (NU la dotări, GRF/NSI V peste parter) sau rând adăugat bifat „Neregulă gravă”
export const isGrav = (n) => (n.custom ? !!n.grav : !!sablon(n.key)?.grav);
// Sigiliul se aplică pe construcție; neregulile grave constatate (✗) cu bifa Sigiliu sunt criteriile lui.
// Mai multe criterii în aceeași construcție = un sigiliu; construcții diferite = câte un sigiliu pe fiecare.
// O neregulă constatată în mai multe construcții = sigiliu în toate. null = niciun sigiliu.
export function sigiliiControl(c) {
  const rows = activeNereguli(c).filter((n) => n.status === 'nok' && isGrav(n) && n.sigiliu);
  if (!rows.length) return null;
  const ids = new Set(rows.flatMap((n) => constructiiOf(c, n).map((k) => k.id)));
  return { criterii: rows.length, sigilii: Math.max(1, ids.size) };
}
export const criteriiText = (n) => `${n} ${n === 1 ? 'criteriu' : 'criterii'}`;
export function sigiliiText(s) {
  return s.sigilii === 1 ? `Sigiliu aplicat · ${criteriiText(s.criterii)}`
    : `${s.sigilii} sigilii (${s.sigilii} construcții) · ${criteriiText(s.criterii)}`;
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
  if (t?.letter) return t.letter;
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
  const t = sablon(n.key);
  if (t && !inCatalog(c, t)) return false;
  if (t?.doarLaNU) return constructiiCuNU(c, t.autoNU).length > 0;
  const decl = constructiiDeclansate(c, t);
  if (decl) return decl.length > 0;
  return !t?.req || t.req.some((k) => hasDotare(c, k));
}

// Rânduri ascunse doar pentru că instalația nu e bifată DA: „Arată toate” le poate afișa.
// Nu intră aici: neregulile grave, rândurile din afara listei controlului (retrase / apărute după încheiere)
// și „Lipsă iluminat Hint” (există doar la NU).
export function ascunsaDeDotari(c, n) {
  if (n.custom || isApplicable(c, n)) return false;
  const t = sablon(n.key);
  return !!t && !t.grav && inCatalog(c, t) && !t.doarLaNU;
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
    // rândurile „Lipsă …” (nereguli grave) nu sunt „ascunse”: există doar când o instalație e pe NU
    hidden: rows.filter((n) => ascunsaDeDotari(c, n)).length,
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

// Termen într-o zi nelucrătoare: avertizare + recomandarea primei zile lucrătoare (numărătoarea nu se schimbă)
export function nelucrNota(ce, iso, motiv) {
  return `${ce} (${fmtDate(iso)}) cade ${motiv} — următoarea zi lucrătoare: ${fmtDateLong(nextWorkingDay(iso))}; verificați prelungirea`;
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
    const left = TERMEN_PLATA - elapsed;   // zile până la termenul de plată (dacă data aplicării e în viitor, > 15)
    let msg;
    if (elapsed < 0) msg = `Data aplicării amenzii e în viitor (${fmtDate(d)}); plata până la ${fmtDate(plataPana)}`;
    else if (left === 0) msg = 'Astăzi este ultima zi de plată';
    else msg = `${maiSunt(left)} din termenul de plată (${fmtDate(plataPana)})`;
    return {
      level: 'blue', label: 'În curs', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: left,
      nelucr: plataNelucr ? nelucrNota('Termenul de plată', plataPana, plataNelucr) : '',
      msg,
    };
  }
  if (elapsed < PRAG_ROSU) {
    const over = elapsed - TERMEN_PLATA;
    return {
      level: 'yellow', label: 'Termen 15 zile expirat', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: leftAnaf,
      nelucr: anafNelucr ? nelucrNota('Termenul ANAF', anafPana, anafNelucr) : '',
      msg: `Termenul de plată a expirat de ${zile(over)} (${fmtDate(plataPana)})`,
    };
  }
  let msg;
  if (leftAnaf > 0) msg = `Mai aveți ${zile(leftAnaf)} până să o trimiteți la ANAF; consultați calculatorul de termene`;
  else if (leftAnaf === 0) msg = 'Astăzi este ultima zi pentru trimiterea la ANAF; consultați calculatorul de termene';
  else msg = `Termenul de trimitere la ANAF (${fmtDate(anafPana)}) a fost depășit cu ${zile(-leftAnaf)}`;
  return {
    level: 'red', label: 'Trimite la ANAF', elapsed, plataPana, anafPana, plataNelucr, anafNelucr, daysLeft: leftAnaf, msg,
    nelucr: anafNelucr && leftAnaf >= 0 ? nelucrNota('Termenul ANAF', anafPana, anafNelucr) : '',
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
  if (left >= 0) {
    const msg = left > 0 ? `${maiSunt(left)} până la ${fmtDate(deadline)}` : `Termenul expiră astăzi (${fmtDate(deadline)})`;
    const nl = zinelucratoare(deadline);
    return { deadline, daysLeft: left, msg, nelucr: nl ? nelucrNota('Termenul', deadline, nl) : '' };
  }
  // Etapa a doua: după cele 90 de zile, 5 zile calendaristice pentru constatarea pierderii valabilității
  if (n.asiPierdere) {
    return { resolved: true, pierdere: true, msg: `Pierderea valabilității constatată${isISO(n.asiDataPierdere) ? ' · ' + fmtDate(n.asiDataPierdere) : ''}` };
  }
  const termenPierdere = addDays(deadline, TERMEN_PIERDERE_ASI);
  const left2 = diffDays(today, termenPierdere);
  let msg;
  if (left2 > 0) msg = `Termenul de 90 de zile a expirat (${fmtDate(deadline)}). ${maiSunt(left2)} pentru constatarea pierderii valabilității (până la ${fmtDate(termenPierdere)})`;
  else if (left2 === 0) msg = `Astăzi este ultima zi pentru constatarea pierderii valabilității (${fmtDate(termenPierdere)})`;
  else msg = `Termenul pentru constatarea pierderii valabilității (${fmtDate(termenPierdere)}) a fost depășit cu ${zile(-left2)}`;
  const nl = zinelucratoare(termenPierdere);
  return {
    deadline, faza: 'pierdere', termenPierdere, daysLeft: left2, msg,
    nelucr: nl && left2 >= 0 ? nelucrNota('Termenul', termenPierdere, nl) : '',
  };
}

// Încărcarea după încheiere: controlul în aplicația ISU și documentul (PV scanat).
// Termen: 3 zile lucrătoare de la data încheierii (ziua încheierii nu se numără); ultima zi și depășirea = roșu.
export function incarcareStatus(c, today = todayISO()) {
  if (!isIncheiat(c)) return null;
  const inc = c.incarcare || {};
  const lipsa = [!inc.aplicatie && 'aplicatie', !inc.document && 'document'].filter(Boolean);
  if (!lipsa.length) return { gata: true, lipsa };
  const termen = addWorkingDays(c.dataIncheiere, TERMEN_INCARCARE);
  let msg, level, daysLeft;
  if (today > termen) {
    daysLeft = -diffDays(termen, today);
    level = 'red'; msg = `Termenul de încărcare (${fmtDate(termen)}) a fost depășit cu ${zile(-daysLeft)}`;
  } else {
    daysLeft = workingDaysBetween(today, termen);
    level = daysLeft === 0 ? 'red' : 'warn';
    msg = daysLeft === 0 ? `Astăzi este ultima zi pentru încărcare (${fmtDate(termen)})`
      : `${daysLeft === 1 ? 'Mai este 1 zi lucrătoare' : `Mai sunt ${daysLeft} zile lucrătoare`} pentru încărcare (până la ${fmtDate(termen)})`;
  }
  return { gata: false, lipsa, termen, daysLeft, level, msg };
}
export const LIPSA_INCARCARE = { aplicatie: 'neîncărcat în aplicație', document: 'document neîncărcat' };

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
    nereguliChecked, nereguliTotal: rows.filter((n) => isApplicable(c, n)).length,
    constatate: nok.length,
    netrecute: nok.filter((n) => !n.inPV).length,
    fines,
    asi: asiDeadline(c, today),
    incarcare: incarcareStatus(c, today),
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
      telefon: last.telefon, email: last.email, adresa: last.adresa, localitate: last.localitate,
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
  const hay = fold([c.denumire, c.administrator, c.telefon, c.email, c.adresa, c.localitate].join(' '));
  return fold(q).split(/\s+/).every((w) => hay.includes(w));
}

// Căutarea în nereguli: o literă (d, ag, G1, +2) găsește rândul exact; de la 3 caractere, textul
// (denumire, categorie, observații, construcții), fără diacritice, toate cuvintele.
// Glosar pentru căutare: abreviere, denumirea completă și expresii care o indică (fără diacritice).
// Un text care conține oricare dintre ele primește toate formele, deci „hidranti interiori” găsește „Hint” și invers.
const GLOSAR = [
  ['iluminat hint', 'instalatie de iluminare de securitate pentru marcarea hidrantilor interiori', 'marcarea hidrantilor'],
  ['idsai', 'instalatie de detectare semnalizare si alarmare la incendiu', 'detectare semnalizare'],
  ['hint', 'instalatie de stingere a incendiilor cu hidranti interiori', 'hidranti interiori'],
  ['hext', 'instalatie de stingere a incendiilor cu hidranti exteriori', 'hidranti exteriori'],
  ['exit', 'instalatie de iluminare de securitate pentru evacuare', 'iluminare de securitate pentru evacuare'],
  ['asi', 'autorizatie de securitate la incendiu', 'autorizatie de securitate'],
  ['aviz', 'aviz de securitate la incendiu', 'aviz de securitate'],
  ['ctpsi', 'cadru tehnic psi', 'cadru tehnic'],
  ['resp', 'responsabil psi', 'responsabil'],
  ['lfd', 'lucru cu foc deschis', 'foc deschis'],
];
export function cuGlosar(text) {
  const baza = fold(text);
  let rest = ` ${baza} `;
  const add = [];
  for (const forme of GLOSAR) {
    const re = forme.map((f) => new RegExp(`\\b${f}\\b`, 'g'));
    if (re.some((r) => r.test(rest))) {
      add.push(...forme);
      for (const r of re) rest = rest.replace(r, ' ');   // „iluminat hint” nu mai declanșează și „hint”
    }
  }
  return add.length ? `${baza} ${add.join(' ')}` : baza;
}
const potriviri = (hay, q) => q.split(/\s+/).every((w) => hay.includes(w));

// Căutarea în acte: numărul actului sau text (denumire, observații), cu glosar
export function matchAct(c, key, query) {
  const q = fold(query).trim();
  if (!q) return true;
  const i = ACTE.findIndex((a) => a.key === key);
  if (q === String(i + 1)) return true;
  if (q.length < 3 && !/\s/.test(q)) return false;
  return potriviri(cuGlosar([ACTE[i]?.label, c.acte[key]?.obs].join(' ')), q);
}

export function matchNeregula(c, n, query) {
  const q = fold(query).trim();
  if (!q) return true;
  const letter = fold(neregulaLetter(c, n));
  if (q === letter) return true;
  if (q.length < 3 && !/\s/.test(q)) return false;
  const hay = cuGlosar([neregulaLabel(n), constatareLabel(n), n.custom ? '' : CATEGORII[neregulaCat(n)], n.obs,
    secOf(n) === 'ner' ? constructiiNume(c, n) : ''].join(' '));
  return potriviri(hay, q);
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
      const ks = constructiiOf(c, n);
      if (sec === 'ner' && multe && ks.length) t += ` – ${ks.length > 1 ? 'construcțiile' : 'construcția'}: ${constructiiNume(c, n)}`;
      const vt = verifText(c, n);
      if (vt) t += `. ${vt[0].toUpperCase()}${vt.slice(1)}`;
      if (n.obs && n.obs.trim()) t += `. ${n.obs.trim().replace(/\s*\n\s*/g, '; ')}`;
      const extra = [];
      if (n.custom && n.grav) extra.push('neregulă gravă');
      if (isGrav(n) && n.sigiliu) extra.push('sigiliu aplicat');
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

// ───────── „Ce mai am de făcut” ─────────
// Lista pașilor rămași într-un control, în ordinea firească a lucrului.
// Fiecare pas: { id, level: 'todo' | 'warn', text, tab, focus } — focus = cheia rândului (sau „act-<cheie>”).
export function todoList(c, { includeClose = true } = {}) {
  const out = [];
  const tabOf = (sec) => SECTIUNI[sec].tab;
  if (!String(c.denumire || '').trim()) out.push({ id: 'denumire', level: 'todo', text: 'Completați denumirea obiectivului', tab: 'obiectiv', focus: 'sec-date' });

  const acteTodo = ACTE.filter((a) => !c.acte[a.key]?.status);
  if (acteTodo.length) {
    out.push({ id: 'acte', level: 'todo', text: `${acteTodo.length} ${acteTodo.length === 1 ? 'act neverificat' : 'acte neverificate'}`, tab: 'acte', focus: `act-${acteTodo[0].key}` });
  }
  const grave = c.nereguli.filter((n) => !n.custom && sablon(n.key)?.grav && !n.status && isApplicable(c, n));
  if (grave.length) {
    out.unshift({ id: 'grave', level: 'grav', text: `${grave.length === 1 ? 'O neregulă gravă' : `${grave.length} nereguli grave`}: ${grave.map((n) => { const l = neregulaLabel(n); return l[0].toLowerCase() + l.slice(1); }).join(', ')}`, tab: 'nereguli', focus: grave[0].key });
  }
  for (const sec of sectiuniActive(c)) {
    // aceeași cifră ca filtrul „Neverificate” (neregulile grave sunt incluse și, în plus, semnalate primele)
    const rows = c.nereguli.filter((n) => secOf(n) === sec && isApplicable(c, n));
    const todo = rows.filter((n) => !n.status);
    const adapost = sec === 'pc' && !c.adapostPC?.v ? 1 : 0;
    const k = todo.length + adapost;
    if (k) {
      const what = sec === 'ner' ? (k === 1 ? 'neregulă neverificată' : 'nereguli neverificate') : (k === 1 ? 'rubrică neverificată' : 'rubrici neverificate');
      out.push({ id: `todo-${sec}`, level: 'todo', text: `${SECTIUNI[sec].label}: ${k} ${what}`, tab: tabOf(sec), focus: todo[0]?.key || 'adapostPC' });
    }
  }
  const active = activeNereguli(c);
  for (const n of active.filter((x) => x.custom && x.status && !String(x.label || '').trim())) {
    out.push({ id: `label-${n.key}`, level: 'warn', text: 'Rând suplimentar fără descriere', tab: tabOf(secOf(n)), focus: n.key });
  }
  const netrec = active.filter((n) => n.status === 'nok' && !n.inPV);
  if (netrec.length) {
    out.push({ id: 'pv', level: 'warn', text: `${netrec.length} ${netrec.length === 1 ? 'constatare netrecută' : 'constatări netrecute'} în PV`, tab: tabOf(secOf(netrec[0])), focus: netrec[0].key });
  }
  for (const n of active.filter((x) => x.status === 'nok' && x.amenda?.aplicata)) {
    const lipsa = [];
    if (!amendaSerieNr(n.amenda)) lipsa.push('seria / nr.');
    if (!String(n.amenda.suma || '').trim()) lipsa.push('suma');
    if (lipsa.length) out.push({ id: `fine-${n.key}`, level: 'warn', text: `Amendă fără ${lipsa.join(' și ')}: ${constatareLabel(n)}`, tab: tabOf(secOf(n)), focus: n.key });
  }
  const faraGps = (c.constructii || []).filter((k) => !k.gps);
  if (faraGps.length) {
    const nume = faraGps.map((k) => k.denumire || `Construcția ${c.constructii.indexOf(k) + 1}`).join(', ');
    out.push({ id: 'gps', level: 'warn', text: `Coordonate GPS necompletate: ${nume}`, tab: 'obiectiv', focus: `gps-${faraGps[0].id}` });
  }
  // verificări expirate care nu sunt (încă) constatate — inspectorul decide
  for (const n of c.nereguli.filter((x) => isVerificare(x) && isApplicable(c, x) && x.status !== 'nok' && x.status !== 'nec')) {
    const exp = verifExpirate(c, n);
    if (exp.length) out.push({ id: `verif-${n.key}`, level: 'warn', text: `Verificare expirată (${n.key}, ${neregulaLabel(n).replace(/^Nu a prezentat \/ nu are verificare /, '')}): ${exp.map((k) => k.denumire).join(', ')}`, tab: 'nereguli', focus: n.key });
  }
  if (includeClose && !isISO(c.dataIncheiere)) out.push({ id: 'close', level: 'todo', text: 'Controlul nu este încheiat', tab: 'obiectiv', focus: 'sec-perioada' });
  // după încheiere: încărcarea în aplicația ISU și a documentului
  const inc = incarcareStatus(c);
  if (inc && !inc.gata) {
    const ce = inc.lipsa.map((k) => LIPSA_INCARCARE[k]).join(', ');
    out.push({ id: 'incarcare', level: 'warn', text: `${ce[0].toUpperCase()}${ce.slice(1)} — ${inc.daysLeft < 0 ? 'termen depășit' : inc.daysLeft === 0 ? 'ultima zi azi' : `${inc.daysLeft === 1 ? '1 zi lucrătoare' : `${inc.daysLeft} zile lucrătoare`}`}`, tab: 'obiectiv', focus: 'sec-incarcare' });
  }
  // ASI: după cele 90 de zile, constatarea pierderii valabilității
  const asi = asiDeadline(c);
  if (asi?.faza === 'pierdere') out.push({ id: 'asi-pierdere', level: 'warn', text: `ASI: constatați pierderea valabilității — ${asi.daysLeft < 0 ? 'termen depășit' : asi.daysLeft === 0 ? 'ultima zi azi' : `${zile(asi.daysLeft)}`}`, tab: 'nereguli', focus: 'a' });
  return out;
}

// ───────── Coordonate GPS ─────────
export const fmtCoord = (g) => (g ? `${g.lat.toFixed(6)}, ${g.lon.toFixed(6)}` : '');
export const googleMapsUrl = (g) => `https://www.google.com/maps/search/?api=1&query=${g.lat.toFixed(6)},${g.lon.toFixed(6)}`;
export const appleMapsUrl = (g, label = '') => `https://maps.apple.com/?ll=${g.lat.toFixed(6)},${g.lon.toFixed(6)}&q=${encodeURIComponent(label || fmtCoord(g))}`;
// Precizia: sub 30 m bună, până la 100 m acceptabilă, peste 100 m slabă (de regulă în interior sau fără GPS)
export const gpsQuality = (acc) => (acc <= 30 ? 'buna' : acc <= 100 ? 'medie' : 'slaba');

// ───────── Verificări pe instalații: data ultimei verificări, pe construcție ─────────
// Construcțiile relevante pentru un rând: cele cu DA la instalația cerută (dacă rândul ține de o instalație),
// altfel toate. Dacă niciuna nu are DA (rând afișat cu „Arată toate”), toate.
export function constructiiEligibile(c, n) {
  const list = c.constructii || [];
  const t = n && !n.custom ? sablon(n.key) : null;
  if (!t?.req || t.grav) return list;
  const cu = list.filter((k) => t.req.some((r) => (r === 'centrala' ? (k.dotari?.centrala?.tipuri || []).length > 0 : k.dotari?.[r]?.v === 'DA')));
  return cu.length ? cu : list;
}

export const isVerificare = (n) => !n.custom && !!sablon(n.key)?.verif;

// Starea verificării unei construcții, față de data controlului (data începerii).
export function verifStare(c, n, k) {
  const t = sablon(n.key);
  const v = n.verificari?.[k.id] || {};
  const luni = t.verifAlegeri?.includes(Number(v.luni)) ? Number(v.luni) : t.verif;
  if (!isISO(v.data)) return { data: '', luni, stare: 'lipsa' };
  const expira = addMonths(v.data, luni);
  const ref = isISO(c.dataInceput) ? c.dataInceput : todayISO();
  return { data: v.data, luni, expira, stare: expira < ref ? 'expirata' : 'valabila' };
}

export const verifExpirate = (c, n) => (isVerificare(n) ? constructiiEligibile(c, n).filter((k) => verifStare(c, n, k).stare === 'expirata') : []);

// Textul pentru PV / fișă: datele ultimei verificări la construcțiile alese
export function verifText(c, n) {
  if (!isVerificare(n)) return '';
  const multe = (c.constructii || []).length > 1;
  return constructiiOf(c, n).map((k) => {
    const s = verifStare(c, n, k);
    const cum = s.stare === 'lipsa' ? 'fără verificare prezentată'
      : `ultima verificare ${fmtDate(s.data)}${s.stare === 'expirata' ? `, expirată (era valabilă până la ${fmtDate(s.expira)})` : ''}`;
    return multe ? `${k.denumire || 'construcție'}: ${cum}` : cum;
  }).join('; ');
}

// ───────── Ce s-a schimbat între două stări ale controlului (Anulează / Refă) ─────────
// Returnează primul loc schimbat: tabul, elementul de adus în vizor și o descriere scurtă.
export function schimbare(a, b) {
  const eq = (x, y) => JSON.stringify(x) === JSON.stringify(y);
  const na = new Map((a.nereguli || []).map((n) => [n.key, n]));
  const nb = new Map((b.nereguli || []).map((n) => [n.key, n]));
  for (const key of new Set([...na.keys(), ...nb.keys()])) {
    if (eq(na.get(key), nb.get(key))) continue;
    const y = nb.get(key);
    const n = y || na.get(key);
    const sec = secOf(n);
    if (!y) return { tab: SECTIUNI[sec].tab, focus: `add-${sec}`, text: 'rândul adăugat' };
    return { tab: SECTIUNI[sec].tab, focus: key, text: `${neregulaLetter(b, y)}. ${constatareLabel(y)}` };
  }
  for (const act of ACTE) {
    if (!eq(a.acte?.[act.key], b.acte?.[act.key])) return { tab: 'acte', focus: `act-${act.key}`, text: act.label };
  }
  const ka = new Map((a.constructii || []).map((k) => [k.id, k]));
  const kb = new Map((b.constructii || []).map((k) => [k.id, k]));
  for (const id of new Set([...ka.keys(), ...kb.keys()])) {
    if (eq(ka.get(id), kb.get(id))) continue;
    const k = kb.get(id);
    return k ? { tab: 'obiectiv', focus: `constr-${id}`, text: k.denumire || 'construcția' } : { tab: 'obiectiv', focus: 'sec-constructii', text: 'construcțiile' };
  }
  if (!eq(a.adapostPC, b.adapostPC)) return { tab: 'pc', focus: 'adapostPC', text: 'Adăpost de protecție civilă' };
  if (a.dataInceput !== b.dataInceput || a.dataIncheiere !== b.dataIncheiere) return { tab: 'obiectiv', focus: 'sec-perioada', text: 'perioada controlului' };
  return { tab: 'obiectiv', focus: 'sec-date', text: 'datele obiectivului' };
}
