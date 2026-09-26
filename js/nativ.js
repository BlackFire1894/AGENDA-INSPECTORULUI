// Legătura cu aplicația nativă iOS (widgeturi, notificări, insigna iconiței). În browser nu face nimic.
// Aplicația nativă afișează aceeași aplicație web; aici se calculează — cu aceleași reguli ca Panoul — cifrele
// pentru fiecare din zilele următoare (ca widgetul să se schimbe singur la miezul nopții) și notificările.
// Contractul de date e descris în ios/README.md („Ce primește aplicația nativă”); `v` crește la o schimbare de format.
import { addDays, fmtDate, fmtDateLong, isISO } from './dates.js';
import {
  activeNereguli, fineStatus, asiDeadline, incarcareStatus, isIncheiat, neregulaLetter, constatareLabel,
} from './model.js';
import { deConfirmat, sfarsitActivitate, titluActivitate } from './activitati.js';

export const ZILE_WIDGET = 21;        // câte zile în avans are widgetul cifrele gata calculate
const ZILE_NOTIFICARI = 75;           // cât de departe se caută termene pentru notificări
const MAX_NOTIFICARI = 60;            // iOS păstrează cel mult 64 de notificări programate

const nume = (c) => c.denumire || 'Obiectiv fără denumire';

// Cifrele Panoului într-o zi dată
export function cifreZi(controls, activitati, d) {
  const z = { data: d, amenzi: { rosu: 0, galben: 0, albastru: 0 }, asi: 0, asiDepasite: 0, deIncarcat: 0, incarcareUrgent: 0, neincheiate: 0, netrecute: 0, deConfirmat: 0 };
  for (const c of controls) {
    if (!isIncheiat(c)) z.neincheiate++;
    for (const n of activeNereguli(c)) {
      if (n.status !== 'nok') continue;
      if (!n.inPV) z.netrecute++;
      if (!n.amenda?.aplicata) continue;
      const st = fineStatus(c, n, d);
      if (st.level === 'red') z.amenzi.rosu++;
      else if (st.level === 'yellow') z.amenzi.galben++;
      else if (st.level === 'blue') z.amenzi.albastru++;
    }
    const a = asiDeadline(c, d);
    if (a && !a.resolved && !a.pending) { z.asi++; if (a.daysLeft <= 0) z.asiDepasite++; }
    const inc = incarcareStatus(c, d);
    if (inc && !inc.gata) { z.deIncarcat++; if (inc.level === 'red') z.incarcareUrgent++; }
  }
  z.deConfirmat = deConfirmat(activitati, d).length;
  z.amenziActive = z.amenzi.rosu + z.amenzi.galben + z.amenzi.albastru;
  // „urgente”: amenzi la ANAF sau cu termenul expirat, ASI depășite, încărcare cu ultima zi azi / depășită
  z.urgente = z.amenzi.rosu + z.amenzi.galben + z.asiDepasite + z.incarcareUrgent;
  return z;
}

// Termenele următoare (pentru widgetul mare): cele mai apropiate, cu data și ce e de făcut
function termeneUrmatoare(controls, azi) {
  const out = [];
  for (const c of controls) {
    for (const n of activeNereguli(c)) {
      if (n.status !== 'nok' || !n.amenda?.aplicata || n.amenda.achitata) continue;
      const st = fineStatus(c, n, azi);
      if (!st.anafPana) continue;
      const data = st.level === 'blue' ? st.plataPana : st.anafPana;
      out.push({ data, nivel: st.level, titlu: st.level === 'blue' ? 'Plata amenzii' : 'Trimitere la ANAF', text: `${nume(c)} · ${neregulaLetter(c, n)}` });
    }
    const a = asiDeadline(c, azi);
    if (a && !a.resolved && !a.pending) out.push({ data: a.faza === 'pierdere' ? a.termenPierdere : a.deadline, nivel: 'red', titlu: a.faza === 'pierdere' ? 'ASI: pierderea valabilității' : 'ASI 90 de zile', text: nume(c) });
    const inc = incarcareStatus(c, azi);
    if (inc && !inc.gata) out.push({ data: inc.termen, nivel: inc.level, titlu: 'Încărcare în aplicație', text: nume(c) });
  }
  return out.filter((x) => isISO(x.data)).sort((x, y) => x.data.localeCompare(y.data)).slice(0, 8);
}

// Notificările: la ziua în care se schimbă stadiul unui termen (și în ziua de dinainte, la cele finale)
function notificari(controls, activitati, meta, azi) {
  const ev = [];
  const add = (id, data, ora, titlu, text) => { if (data >= azi) ev.push({ id: `agenda-${id}-${data}`, data, ora, titlu, text }); };
  const zile = Array.from({ length: ZILE_NOTIFICARI }, (_, i) => addDays(azi, i));
  for (const c of controls) {
    for (const n of activeNereguli(c)) {
      if (n.status !== 'nok' || !n.amenda?.aplicata || n.amenda.achitata) continue;
      const cine = `${nume(c)} · ${neregulaLetter(c, n)}. ${constatareLabel(n)}`;
      let prev = fineStatus(c, n, addDays(azi, -1)).level;
      for (const d of zile) {
        const st = fineStatus(c, n, d);
        if (st.level !== prev && st.anafPana) {
          add(`amenda-${c.id}-${n.key}`, d, '08:00', st.level === 'yellow' ? 'Amendă: termenul de plată a expirat' : st.level === 'red' ? 'Amendă: de trimis la ANAF' : 'Amendă', `${cine}. ${st.msg}`);
        }
        if (st.anafPana && d === addDays(st.anafPana, -1)) add(`anaf1-${c.id}-${n.key}`, d, '08:00', 'Amendă: mâine e ultima zi pentru ANAF', `${cine}. Termen: ${fmtDate(st.anafPana)}`);
        if (st.anafPana && d === st.anafPana) add(`anaf0-${c.id}-${n.key}`, d, '08:00', 'Amendă: azi e ultima zi pentru ANAF', `${cine}. ${st.msg}`);
        prev = st.level;
      }
    }
    const a = asiDeadline(c, azi);
    if (a && !a.resolved && !a.pending) {
      const t = a.faza === 'pierdere' ? a.termenPierdere : a.deadline;
      const ce = a.faza === 'pierdere' ? 'constatarea pierderii valabilității ASI' : 'prezentarea documentației ASI (90 de zile)';
      if (isISO(t)) {
        add(`asi1-${c.id}`, addDays(t, -1), '08:00', `ASI: mâine e ultima zi`, `${nume(c)}: ${ce}, până la ${fmtDateLong(t)}`);
        add(`asi0-${c.id}`, t, '08:00', `ASI: azi e ultima zi`, `${nume(c)}: ${ce}`);
      }
    }
    const inc = incarcareStatus(c, azi);
    if (inc && !inc.gata) {
      add(`inc1-${c.id}`, addDays(inc.termen, -1), '08:00', 'Încărcare: mâine e ultima zi', `${nume(c)}: încărcare în aplicație și document, până la ${fmtDateLong(inc.termen)}`);
      add(`inc0-${c.id}`, inc.termen, '08:00', 'Încărcare: azi e ultima zi', `${nume(c)}: încărcare în aplicație și document`);
    }
  }
  // activitățile planificate: în dimineața zilei; cele trecute neconfirmate: a doua zi
  for (const x of activitati) {
    if (x.stare !== 'planificat') continue;
    add(`act-${x.id}`, x.data, '07:30', 'Activitate planificată azi', `${titluActivitate(x)}${x.ora ? `, ora ${x.ora}` : ''}`);
    add(`actconf-${x.id}`, addDays(sfarsitActivitate(x), 1), '09:00', 'Activitate de confirmat', `${titluActivitate(x)}: marcați-o efectuată, reprogramați-o sau anulați-o`);
  }
  // backupul: la 7 zile de la ultimul (sau azi, dacă nu există)
  if (controls.length) {
    const ultim = meta?.lastBackup ? meta.lastBackup.slice(0, 10) : null;
    const cand = ultim && addDays(ultim, 7) > azi ? addDays(ultim, 7) : azi;
    add('backup', cand, '17:00', 'Faceți un backup', ultim ? `Ultimul backup: ${fmtDate(ultim)}. Datele există doar pe acest dispozitiv.` : 'Nu ați făcut încă niciun backup. Datele există doar pe acest dispozitiv.');
  }
  // sărbătorile legale: ca în Panou — în decembrie pentru anul următor, în ianuarie pentru anul curent
  const y = +azi.slice(0, 4), m = +azi.slice(5, 7);
  const verificate = meta?.sarbatoriVerificate || [];
  const an = m === 12 ? y + 1 : m === 1 ? y : null;
  const sarb = (a, d, ora) => add(`sarbatori-${a}`, d, ora, `Sărbătorile legale ${a}: verificați lista`, `Verificați în Panou lista sărbătorilor legale pentru ${a}: termenele țin cont de ele.`);
  if (an && !verificate.includes(an)) sarb(an, azi, '18:00');
  else if (!an && !verificate.includes(y + 1)) sarb(y + 1, `${y}-12-01`, '09:00');
  return ev.sort((x, y) => (x.data + x.ora).localeCompare(y.data + y.ora)).slice(0, MAX_NOTIFICARI);
}

// Tot ce primește aplicația nativă
export function stareNativa(controls, activitati, meta, azi, acum = new Date()) {
  const zile = Array.from({ length: ZILE_WIDGET }, (_, i) => cifreZi(controls, activitati, addDays(azi, i)));
  return {
    v: 1, generat: acum.toISOString(), azi,
    zile,
    urmatoare: termeneUrmatoare(controls, azi),
    notificari: notificari(controls, activitati, meta, azi),
    insigna: zile[0].urgente,
  };
}

// ───────── trimiterea (doar în aplicația nativă) ─────────
const canal = () => (typeof window !== 'undefined' ? window.webkit?.messageHandlers?.agenda : null);
export const inAplicatiaNativa = () => !!canal();
let timer;
export function trimiteStareNativa(sursa) {
  if (!canal()) return;
  clearTimeout(timer);
  timer = setTimeout(() => {
    try {
      const { controls, activitati, meta, azi } = sursa();
      canal().postMessage({ tip: 'stare', stare: stareNativa(controls, activitati, meta, azi) });
    } catch (e) { console.error(e); }
  }, 800);
}
