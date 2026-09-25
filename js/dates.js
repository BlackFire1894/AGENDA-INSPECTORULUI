// Utilitare pentru date calendaristice și calculul termenelor.
// Toate datele sunt stocate ca șiruri ISO „AAAA-LL-ZZ” (fără oră), în ora locală a tabletei.

export const MONTHS = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie',
  'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
export const MONTHS_SHORT = ['ian', 'feb', 'mar', 'apr', 'mai', 'iun', 'iul', 'aug', 'sep', 'oct', 'nov', 'dec'];
export const WEEKDAYS = ['duminică', 'luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă'];
export const WEEKDAYS_SHORT = ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'];

// Termene (zile). Se numără de la data de referință + 1 (ziua 1 = ziua următoare).
export const TERMEN_PLATA = 15;          // plata amenzii
export const PRAG_ROSU = 15 + 25;        // 25 de zile trecute după cele 15 inițiale
export const TERMEN_ANAF = 15 + 30;      // 30 de zile de la expirarea termenului de plată
export const TERMEN_ASI = 90;            // prezentare documentație ASI

const pad = (n) => String(n).padStart(2, '0');

export function toISO(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function todayISO(now = new Date()) {
  return toISO(now);
}

export function isISO(s) {
  return typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s);
}

// Număr de zile de la 1970-01-01 (UTC), imun la schimbarea orei de vară.
function dayNumber(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / 86400000);
}

export function diffDays(fromISO, toISO_) {
  return dayNumber(toISO_) - dayNumber(fromISO);
}

export function addDays(iso, n) {
  const [y, m, d] = iso.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + n));
  return `${dt.getUTCFullYear()}-${pad(dt.getUTCMonth() + 1)}-${pad(dt.getUTCDate())}`;
}

// + n luni; ziua se limitează la ultima zi a lunii (31.01 + 1 lună = 28/29.02)
export function addMonths(iso, n) {
  const [y, m, d] = iso.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1 + n, 1));
  const last = new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth() + 1, 0)).getUTCDate();
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(Math.min(d, last))}`;
}

export function fmtDate(iso) {
  if (!isISO(iso)) return '—';
  const [y, m, d] = iso.split('-');
  return `${d}.${m}.${y}`;
}

export function fmtDateLong(iso) {
  if (!isISO(iso)) return '—';
  const [y, m, d] = iso.split('-').map(Number);
  const wd = new Date(y, m - 1, d).getDay();
  return `${WEEKDAYS[wd]}, ${d} ${MONTHS[m - 1]} ${y}`;
}

export function ucfirst(s) {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

export function fmtDateMedium(iso) {
  if (!isISO(iso)) return '—';
  const [y, m, d] = iso.split('-').map(Number);
  return `${d} ${MONTHS_SHORT[m - 1]} ${y}`;
}

export function plural(n, one, many) {
  const a = Math.abs(n);
  if (a === 1) return `${n} ${one}`;
  // În română: „20 de zile”, „100 de zile”, „120 de zile”, dar „101 zile”, „115 zile” (n % 100 >= 20 sau 0).
  const r = a % 100;
  const de = a !== 0 && (r === 0 || r >= 20) ? 'de ' : '';
  return `${n} ${de}${many}`;
}
export const zile = (n) => plural(n, 'zi', 'zile');

// Interpretează text introdus de utilizator ca dată.
// Returnează {kind:'day', iso} | {kind:'month', year, month} | {kind:'year', year} | null
export function parseDateQuery(q, now = new Date()) {
  const s = String(q || '').trim();
  let m;
  if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/))) {
    return mkDay(+m[1], +m[2], +m[3]);
  }
  if ((m = s.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{2}|\d{4})$/))) {
    let y = +m[3];
    if (y < 100) y += 2000;
    return mkDay(y, +m[2], +m[1]);
  }
  if ((m = s.match(/^(\d{1,2})[./-](\d{1,2})$/))) {
    const a = +m[1], b = +m[2];
    // „05.2026” nu intră aici; „12.03” = 12 martie anul curent
    return mkDay(now.getFullYear(), b, a);
  }
  if ((m = s.match(/^(\d{1,2})[./-](\d{4})$/))) {
    const mo = +m[1];
    if (mo >= 1 && mo <= 12) return { kind: 'month', year: +m[2], month: mo };
  }
  if ((m = s.match(/^(20\d{2})$/))) return { kind: 'year', year: +m[1] };
  return null;

  function mkDay(y, mo, d) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    const dt = new Date(y, mo - 1, d);
    if (dt.getMonth() !== mo - 1) return null;
    return { kind: 'day', iso: toISO(dt) };
  }
}

// Intervalul [start, end] (ISO) acoperit de o interogare de dată.
export function queryRange(dq) {
  if (!dq) return null;
  if (dq.kind === 'day') return [dq.iso, dq.iso];
  if (dq.kind === 'month') {
    const start = `${dq.year}-${pad(dq.month)}-01`;
    const end = addDays(dq.month === 12 ? `${dq.year + 1}-01-01` : `${dq.year}-${pad(dq.month + 1)}-01`, -1);
    return [start, end];
  }
  return [`${dq.year}-01-01`, `${dq.year}-12-31`];
}

export function rangesOverlap(a1, a2, b1, b2) {
  return a1 <= b2 && b1 <= a2;
}

// ───────── Zile nelucrătoare (România) ─────────
// Sărbătorile legale din Codul muncii, art. 139 (inclusiv 6 și 7 ianuarie, din 2024).
// Paștele ortodox: algoritmul Meeus (calendar iulian) + 13 zile (valabil 1900–2099).
export function pasteOrtodox(year) {
  const a = year % 4, b = year % 7, c = year % 19;
  const d = (19 * c + 15) % 30;
  const e = (2 * a + 4 * b - d + 34) % 7;
  const month = Math.floor((d + e + 114) / 31);
  const day = ((d + e + 114) % 31) + 1;
  return addDays(`${year}-${pad(month)}-${pad(day)}`, 13);
}

const holidayCache = new Map();
export function sarbatoriLegale(year) {
  if (holidayCache.has(year)) return holidayCache.get(year);
  const p = pasteOrtodox(year);
  const list = [
    [`${year}-01-01`, 'Anul Nou'], [`${year}-01-02`, 'Anul Nou'],
    [`${year}-01-06`, 'Boboteaza'], [`${year}-01-07`, 'Sfântul Ioan Botezătorul'],
    [`${year}-01-24`, 'Ziua Unirii'],
    [addDays(p, -2), 'Vinerea Mare'], [p, 'Paștele'], [addDays(p, 1), 'a doua zi de Paște'],
    [`${year}-05-01`, 'Ziua Muncii'], [`${year}-06-01`, 'Ziua Copilului'],
    [addDays(p, 49), 'Rusaliile'], [addDays(p, 50), 'a doua zi de Rusalii'],
    [`${year}-08-15`, 'Adormirea Maicii Domnului'], [`${year}-11-30`, 'Sfântul Andrei'],
    [`${year}-12-01`, 'Ziua Națională'], [`${year}-12-25`, 'Crăciunul'], [`${year}-12-26`, 'a doua zi de Crăciun'],
  ];
  const map = new Map();
  for (const [d, name] of list) map.set(d, map.has(d) ? `${map.get(d)} / ${name}` : name);
  holidayCache.set(year, map);
  return map;
}

// Dacă ziua e nelucrătoare, întoarce motivul („sâmbătă”, „sărbătoare legală – Crăciunul”), altfel ''.
export function zinelucratoare(iso) {
  if (!isISO(iso)) return '';
  const hol = sarbatoriLegale(+iso.slice(0, 4)).get(iso);
  if (hol) return `sărbătoare legală – ${hol}`;
  const [y, m, d] = iso.split('-').map(Number);
  const wd = new Date(y, m - 1, d).getDay();
  if (wd === 6) return 'sâmbătă';
  if (wd === 0) return 'duminică';
  return '';
}
