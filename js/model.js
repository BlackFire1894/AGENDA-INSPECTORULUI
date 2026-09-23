// Modelul de date și logica de business (fără DOM) — testabile separat.
// Structura este documentată în docs/MODEL_DATE.md (pregătită pentru portare nativă).
import {
  addDays, diffDays, isISO, todayISO, parseDateQuery, queryRange, rangesOverlap, zile,
  TERMEN_PLATA, PRAG_ROSU, TERMEN_ANAF, TERMEN_ASI, fmtDate,
} from './dates.js';

export const SCHEMA_VERSION = 1;

export const TIP_OBIECTIV = [
  { key: 'OPEC', label: 'OPEC / Instituție' },
  { key: 'LOCALITATE', label: 'Localitate' },
];

const DNN = ['DA', 'NU', 'NEC'];
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
];

export const NEREGULI = [
  { key: 'a', label: 'Nu a prezentat documentație ASI', asi: true },
  { key: 'b', label: 'Nu a prezentat / nu are verificare instalații electrice / IPT / CT' },
  { key: 'c', label: 'Nu a prezentat / nu are verificare IDSAI / Hint / Hext / Desfumare / Sprinklere / Drencere / Instalații speciale' },
  { key: 'd', label: 'Stingătoare expirate' },
  { key: 'e', label: 'Stingătoare neconforme' },
  { key: 'f', label: 'Instalații electrice exploatate incorect' },
  { key: 'g', label: 'Perete / planșeu / perete + planșeu cameră CT – 90 minute' },
  { key: 'h', label: 'Ușă RF 15 minute cameră CT' },
  { key: 'i', label: 'Ușă RF 60 minute cameră IDSAI' },
  { key: 'j', label: 'EXIT defect' },
  { key: 'k', label: 'Iluminat Hint defect' },
  { key: 'l', label: 'Erori IDSAI' },
  { key: 'm', label: 'IDSAI nefuncțional' },
  { key: 'n', label: 'Probleme Hint' },
  { key: 'o', label: 'Hint nefuncțional' },
  { key: 'p', label: 'Probleme Hext' },
  { key: 'q', label: 'Hext nefuncțional' },
  { key: 'r', label: 'Probleme desfumare' },
  { key: 's', label: 'Desfumare nefuncțională' },
  { key: 'ș', label: 'Probleme sprinklere' },
  { key: 't', label: 'Sprinklere nefuncționale' },
  { key: 'ț', label: 'Probleme drencere' },
  { key: 'u', label: 'Drencere nefuncționale' },
  { key: 'v', label: 'Probleme instalații speciale' },
  { key: 'x', label: 'Instalații speciale nefuncționale' },
  { key: 'y', label: 'Probleme stație de pompe / generator' },
  { key: 'z', label: 'Stație de pompe / generator nefuncțional' },
];

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
export function emptyNeregula(key, custom = false) {
  return {
    key, custom, label: '', status: '', obs: '', inPV: false,
    asiTermen: false, asiPrezentat: false, asiDataPrezentare: '',
    amenda: { aplicata: false, data: '', suma: '', achitata: false, dataAchitare: '' },
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
    nereguli: NEREGULI.map((n) => emptyNeregula(n.key)),
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
  return c;
}

// Completează câmpurile lipsă (date importate sau versiuni vechi).
export function normalizeControl(c) {
  const base = newControl({ objectiveId: c.objectiveId, start: c.dataInceput });
  const out = { ...base, ...c };
  out.acte = { ...base.acte, ...(c.acte || {}) };
  const byKey = new Map((c.nereguli || []).map((n) => [n.key, n]));
  const tmpl = NEREGULI.map((n) => ({ ...emptyNeregula(n.key), ...(byKey.get(n.key) || {}) }));
  const custom = (c.nereguli || []).filter((n) => n.custom).map((n) => ({ ...emptyNeregula(n.key, true), ...n }));
  out.nereguli = [...tmpl, ...custom].map((n) => ({ ...n, amenda: { ...emptyNeregula('').amenda, ...(n.amenda || {}) } }));
  out.constructii = (c.constructii && c.constructii.length ? c.constructii : base.constructii).map((k, i) => {
    const e = emptyConstructie(i + 1);
    return { ...e, ...k, dotari: { ...e.dotari, ...(k.dotari || {}) } };
  });
  return out;
}

export const isIncheiat = (c) => isISO(c.dataIncheiere);

export function neregulaLabel(n) {
  if (n.custom) return n.label || 'Neregulă suplimentară';
  return NEREGULI.find((t) => t.key === n.key)?.label || n.label;
}

export function neregulaLetter(c, n) {
  if (!n.custom) return n.key;
  const idx = c.nereguli.filter((x) => x.custom).indexOf(n);
  return `+${idx + 1}`;
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
  const leftAnaf = TERMEN_ANAF - elapsed;
  if (elapsed <= TERMEN_PLATA) {
    const left = TERMEN_PLATA - Math.max(elapsed, 0);
    return {
      level: 'blue', label: 'În curs', elapsed, plataPana, anafPana, daysLeft: left,
      msg: left === 0 ? 'Astăzi este ultima zi de plată' : `${maiSunt(left)} din termenul de plată (${fmtDate(plataPana)})`,
    };
  }
  if (elapsed < PRAG_ROSU) {
    const over = elapsed - TERMEN_PLATA;
    return {
      level: 'yellow', label: 'Termen 15 zile expirat', elapsed, plataPana, anafPana, daysLeft: leftAnaf,
      msg: `Termenul de plată a expirat de ${zile(over)} (${fmtDate(plataPana)})`,
    };
  }
  let msg;
  if (leftAnaf > 0) msg = `Mai ai ${zile(leftAnaf)} până să o trimiți la ANAF, consultă calculatorul de termene`;
  else if (leftAnaf === 0) msg = 'Astăzi este ultima zi pentru trimiterea la ANAF, consultă calculatorul de termene';
  else msg = `Termenul de trimitere la ANAF (${fmtDate(anafPana)}) a fost depășit cu ${zile(-leftAnaf)}`;
  return { level: 'red', label: 'Trimite la ANAF', elapsed, plataPana, anafPana, daysLeft: leftAnaf, msg };
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
  return { deadline, daysLeft: left, msg };
}

// Statistici pentru un control
export function controlStats(c, today = todayISO()) {
  const nok = c.nereguli.filter((n) => n.status === 'nok');
  const acteDone = ACTE.filter((a) => c.acte[a.key]?.status).length;
  const acteNok = ACTE.filter((a) => c.acte[a.key]?.status === 'nok').length;
  const nereguliChecked = c.nereguli.filter((n) => n.status).length;
  const fines = nok.filter((n) => n.amenda?.aplicata).map((n) => ({ n, st: fineStatus(c, n, today) }));
  return {
    acteDone, acteTotal: ACTE.length, acteNok,
    nereguliChecked, nereguliTotal: c.nereguli.length,
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
    for (const n of c.nereguli) {
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
