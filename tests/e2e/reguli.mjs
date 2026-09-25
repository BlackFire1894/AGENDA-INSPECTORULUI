// Așteptări din listele-șablon (date), nu din funcțiile de logică ale aplicației
import { NEREGULI, NEREGULI_GRAVE, DOTARI, SCHEMA_VERSION } from '../../js/model.js';
const inCat = (t) => (t.din || 1) <= SCHEMA_VERSION && !(t.retrasDin && SCHEMA_VERSION >= t.retrasDin);
const vizibile = (da, nu, grfV = false) => {
  const r = NEREGULI.filter((t) => inCat(t) && !t.doarLaNU && (!t.req || t.req.some((k) => da.includes(k)))).map((t) => t.key);
  const g = NEREGULI_GRAVE.filter((t) => inCat(t) && ((t.reqNU && nu.includes(t.reqNU)) || (t.reqGrfV && grfV))).map((t) => t.key);
  const am = NEREGULI.filter((t) => inCat(t) && t.doarLaNU && nu.includes(t.autoNU)).map((t) => t.key);
  return [...r, ...g, ...am];
};
const scen = [
  { nume: 'control nou, fără dotări', da: [], nu: [] },
  { nume: 'DA la Hidranți interiori', da: ['hidInt'], nu: [] },
  { nume: '+ DA la IDSAI', da: ['hidInt', 'idsai'], nu: [] },
  { nume: 'NU la Hidranți interiori (gravă)', da: ['idsai'], nu: ['hidInt'] },
  { nume: '+ NU la Iluminat Hint (am)', da: ['idsai'], nu: ['hidInt', 'ilumHint'] },
  { nume: '+ GRF V, regim P+1 (gravă)', da: ['idsai'], nu: ['hidInt', 'ilumHint'], grfV: true },
];
console.log(JSON.stringify({ labels: Object.fromEntries(DOTARI.map((d) => [d.key, d.label])), scen: scen.map((s) => ({ ...s, n: vizibile(s.da, s.nu, s.grfV).length, keys: vizibile(s.da, s.nu, s.grfV) })) }));
