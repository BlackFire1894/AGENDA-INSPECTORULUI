// Așteptări din listele-șablon (date), nu din funcțiile de logică ale aplicației
import { NEREGULI, NEREGULI_GRAVE, DOTARI, SCHEMA_VERSION } from '../../js/model.js';
const inCat = (t) => (t.din || 1) <= SCHEMA_VERSION && !(t.retrasDin && SCHEMA_VERSION >= t.retrasDin);
// v1.25: fără hidranți interiori (NU / NEC), „Iluminat Hint” nu se mai completează (NU-ul rămas nu contează);
// neregulile actelor lipsă (autoActe) apar doar când un act e „Lipsă” (scenariile nu bifează acte)
const vizibile = (da, nu0, grfV = false, nec = []) => {
  const nu = nu0.filter((k) => !(k === 'ilumHint' && (nu0.includes('hidInt') || nec.includes('hidInt'))));
  const r = NEREGULI.filter((t) => inCat(t) && !t.doarLaNU && !t.autoActe && (!t.req || t.req.some((k) => da.includes(k)))).map((t) => t.key);
  const g = NEREGULI_GRAVE.filter((t) => inCat(t) && ((t.reqNU && nu.includes(t.reqNU)) || (t.reqGrfV && grfV))).map((t) => t.key);
  const am = NEREGULI.filter((t) => inCat(t) && t.doarLaNU && nu.includes(t.autoNU)).map((t) => t.key);
  return [...r, ...g, ...am];
};
const scen = [
  { nume: 'control nou, fără dotări', da: [], nu: [] },
  { nume: 'DA la Hidranți interiori', da: ['hidInt'], nu: [] },
  { nume: '+ DA la IDSAI', da: ['hidInt', 'idsai'], nu: [] },
  { nume: 'NU la Hidranți interiori (gravă)', da: ['idsai'], nu: ['hidInt'] },
  { nume: 'DA la Hidranți interiori, NU la Iluminat Hint (am)', da: ['idsai', 'hidInt'], nu: ['ilumHint'] },
  { nume: '+ GRF V, regim P+1 (gravă)', da: ['idsai', 'hidInt'], nu: ['ilumHint'], grfV: true },
  { nume: 'NEC la Hidranți interiori → Iluminat Hint ascuns, am retrasă', da: ['idsai'], nu: ['ilumHint'], nec: ['hidInt'], grfV: true },
];
console.log(JSON.stringify({ labels: Object.fromEntries(DOTARI.map((d) => [d.key, d.label])), scen: scen.map((s) => ({ ...s, n: vizibile(s.da, s.nu, s.grfV, s.nec).length, keys: vizibile(s.da, s.nu, s.grfV, s.nec) })) }));
