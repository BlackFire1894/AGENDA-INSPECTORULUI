import test from 'node:test';
import assert from 'node:assert/strict';
import { addDays, diffDays, parseDateQuery, zile } from '../js/dates.js';
import {
  newControl, fineStatus, asiDeadline, matchControl, objectives, controlFromPrevious,
  normalizeControl, allFines, NEREGULI, SABLON, isApplicable, secStats, sectiuniActive, activeNereguli,
  neregulaLetter, tabOfNeregula, controlStats, constructieOf, amendaSerieNr, ACTE, emptyConstructie,
} from '../js/model.js';

function withFine(data, extra = {}) {
  const c = newControl({ denumire: 'Școala Gimnazială nr. 1', start: '2026-09-01' });
  c.dataIncheiere = data;
  const n = c.nereguli[3];
  n.status = 'nok';
  n.amenda = { aplicata: true, data: '', suma: '', achitata: false, dataAchitare: '', ...extra };
  return { c, n };
}

test('aritmetica datelor trece corect peste schimbarea orei și anii bisecți', () => {
  assert.equal(addDays('2026-10-20', 15), '2026-11-04');
  assert.equal(addDays('2028-02-20', 10), '2028-03-01');
  assert.equal(diffDays('2026-03-28', '2026-03-30'), 2);
  assert.equal(zile(1), '1 zi');
  assert.equal(zile(5), '5 zile');
  assert.equal(zile(20), '20 de zile');
});

test('amenda: albastru până în ziua 15 inclusiv (termenul curge de la data+1)', () => {
  const { c, n } = withFine('2026-09-01');
  assert.equal(fineStatus(c, n, '2026-09-01').level, 'blue');
  const last = fineStatus(c, n, '2026-09-16');
  assert.equal(last.level, 'blue');
  assert.equal(last.daysLeft, 0);
  assert.equal(last.plataPana, '2026-09-16');
});

test('amenda: galben din ziua 16 până în ziua 39', () => {
  const { c, n } = withFine('2026-09-01');
  assert.equal(fineStatus(c, n, '2026-09-17').level, 'yellow');
  assert.equal(fineStatus(c, n, '2026-10-10').level, 'yellow'); // ziua 39
});

test('amenda: roșu după 25 de zile peste cele 15 → „Mai ai 5 zile”', () => {
  const { c, n } = withFine('2026-09-01');
  const st = fineStatus(c, n, '2026-10-11'); // ziua 40
  assert.equal(st.level, 'red');
  assert.equal(st.daysLeft, 5);
  assert.match(st.msg, /Mai ai 5 zile până să o trimiți la ANAF, consultă calculatorul de termene/);
  assert.equal(st.anafPana, '2026-10-16');
  assert.match(fineStatus(c, n, '2026-10-20').msg, /depășit cu 4 zile/);
});

test('amenda: verde când e achitată, indiferent de termen', () => {
  const { c, n } = withFine('2026-09-01', { achitata: true });
  assert.equal(fineStatus(c, n, '2026-12-01').level, 'green');
});

test('amenda: data proprie a amenzii are prioritate față de data încheierii', () => {
  const { c, n } = withFine('2026-09-01', { data: '2026-09-10' });
  assert.equal(fineStatus(c, n, '2026-09-20').level, 'blue');
});

test('amenda: control neîncheiat și fără dată → în curs, termen neînceput', () => {
  const { c, n } = withFine('');
  const st = fineStatus(c, n, '2026-12-01');
  assert.equal(st.level, 'blue');
  assert.ok(st.pending);
});

test('ASI: termen de 90 de zile de la data încheierii + 1', () => {
  const c = newControl({ start: '2026-09-01' });
  c.dataIncheiere = '2026-09-02';
  const a = c.nereguli.find((n) => n.key === 'a');
  a.status = 'nok';
  assert.equal(asiDeadline(c, '2026-09-10'), null);
  a.asiTermen = true;
  const d = asiDeadline(c, '2026-09-10');
  assert.equal(d.deadline, '2026-12-01');
  assert.equal(d.daysLeft, 82);
  a.asiPrezentat = true;
  assert.ok(asiDeadline(c, '2026-09-10').resolved);
});

test('căutare după nume (fără diacritice) și după dată', () => {
  const c = newControl({ denumire: 'Școala Gimnazială Țicleni', start: '2026-09-01' });
  c.dataIncheiere = '2026-09-03';
  assert.ok(matchControl(c, 'scoala ticleni'));
  assert.ok(!matchControl(c, 'spital'));
  assert.ok(matchControl(c, '02.09.2026'));
  assert.ok(!matchControl(c, '04.09.2026'));
  assert.ok(matchControl(c, '09.2026'));
  assert.ok(matchControl(c, '2026-09-01'));
  assert.deepEqual(parseDateQuery('31.02.2026'), null);
});

test('control nou pe obiectiv existent preia datele, resetează constatările', () => {
  const prev = newControl({ denumire: 'Primăria X', start: '2026-01-10' });
  prev.administrator = 'Ion Popescu';
  prev.constructii[0].suprafata = '1200';
  prev.nereguli[0].status = 'nok';
  const next = controlFromPrevious(prev, '2026-09-01');
  assert.equal(next.objectiveId, prev.objectiveId);
  assert.equal(next.administrator, 'Ion Popescu');
  assert.equal(next.constructii[0].suprafata, '1200');
  assert.notEqual(next.constructii[0].id, prev.constructii[0].id);
  assert.equal(next.nereguli[0].status, '');
  const objs = objectives([prev, next]);
  assert.equal(objs.length, 1);
  assert.equal(objs[0].controls.length, 2);
  assert.equal(objs[0].last.id, next.id);
});

test('normalizare: completează câmpurile lipsă și păstrează neregulile custom', () => {
  const c = normalizeControl({ id: 'x', objectiveId: 'o', dataInceput: '2026-01-01',
    nereguli: [{ key: 'b', status: 'nok' }, { key: 'k1', custom: true, label: 'Test' }] });
  assert.equal(c.nereguli.length, SABLON.length + 1);
  assert.equal(c.nereguli.find((n) => n.key === 'b').sec, 'ner');
  assert.equal(c.nereguli.at(-1).sec, 'ner');
  assert.deepEqual(c.adapostPC, { v: '', obs: '' });
  assert.equal(c.nereguli.find((n) => n.key === 'b').status, 'nok');
  assert.equal(c.nereguli.at(-1).label, 'Test');
  assert.ok(c.nereguli.at(-1).amenda);
});

test('allFines sortează după urgență', () => {
  const a = withFine('2026-09-01');
  const b = withFine('2026-09-20');
  const list = allFines([b.c, a.c], '2026-10-12');
  assert.equal(list[0].st.level, 'red');
  assert.equal(list[1].st.level, 'yellow');
});

test('versiunea din sw.js coincide cu js/version.js și toate modulele sunt în cache-ul offline', async () => {
  const fs = await import('node:fs');
  const { APP_VERSION } = await import('../js/version.js');
  const sw = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8');
  assert.equal(sw.match(/const VERSION = '([^']+)'/)[1], APP_VERSION);
  for (const f of fs.readdirSync(new URL('../js/', import.meta.url))) {
    assert.ok(sw.includes(`./js/${f}`), `sw.js nu pune în cache js/${f}`);
  }
});

test('nereguli de instalații: apar doar dacă instalația e bifată DA la dotări', () => {
  const c = newControl({ start: '2026-09-01' });
  const n = (k) => c.nereguli.find((x) => x.key === k);
  assert.ok(isApplicable(c, n('a')));          // documentație: mereu
  assert.ok(!isApplicable(c, n('m')));         // IDSAI nefuncțional: fără IDSAI
  assert.ok(!isApplicable(c, n('c')));
  assert.ok(!isApplicable(c, n('g')));         // cameră CT: fără centrală
  c.constructii[0].dotari.idsai.v = 'NEC';
  assert.ok(!isApplicable(c, n('m')));
  c.constructii[0].dotari.idsai.v = 'DA';
  assert.ok(isApplicable(c, n('m')) && isApplicable(c, n('i')) && isApplicable(c, n('c')));
  c.constructii[0].dotari.centrala.tipuri = ['GAZOS'];
  assert.ok(isApplicable(c, n('g')) && isApplicable(c, n('h')));
  // un rând completat nu dispare, chiar dacă instalația e scoasă
  n('q').status = 'nok';
  assert.ok(isApplicable(c, n('q')));
  assert.equal(secStats(c, 'ner').total, 5 + 4 + 2 + 1); // a,b,d,e,f + c,i,l,m + g,h + q
});

test('Planuri/SVSU și Protecție civilă: doar la Localitate, cu amenzi în Panou', () => {
  const o = newControl({ tip: 'OPEC', start: '2026-09-01' });
  assert.deepEqual(sectiuniActive(o), ['ner']);
  assert.equal(activeNereguli(o).length, NEREGULI.length);
  const l = newControl({ tip: 'LOCALITATE', start: '2026-09-01' });
  l.dataIncheiere = '2026-09-01';
  assert.deepEqual(sectiuniActive(l), ['ner', 'plan', 'pc']);
  const s = l.nereguli.find((n) => n.key === 'pcSireneDefecte');
  assert.equal(tabOfNeregula(s), 'pc');
  assert.equal(neregulaLetter(l, s), '4');
  assert.equal(neregulaLetter(l, l.nereguli.find((n) => n.key === 'svsuSef')), '2');
  s.status = 'nok';
  s.amenda.aplicata = true;
  assert.equal(allFines([l], '2026-09-05').length, 1);
  assert.equal(secStats(l, 'pc').constatate, 1);
  assert.equal(secStats(l, 'pc').total, 7); // 6 rubrici + adăpost
  // schimbat în OPEC: rubricile de localitate nu mai contează (datele rămân)
  l.tip = 'OPEC';
  assert.equal(allFines([l], '2026-09-05').length, 0);
  assert.equal(controlStats(l).constatate, 0);
  assert.equal(l.nereguli.find((n) => n.key === 'pcSireneDefecte').status, 'nok');
});

test('v1.4: acte exerciții, construcția neregulii, seria și nr. amenzii', () => {
  assert.ok(['exercitii', 'registreExercitii', 'rapoarteExercitii'].every((k) => ACTE.some((a) => a.key === k)));
  const c = newControl({ start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2));
  const n = c.nereguli.find((x) => x.key === 'd');
  assert.equal(constructieOf(c, n).id, c.constructii[0].id);      // implicit prima construcție
  n.constructieId = c.constructii[1].id;
  assert.equal(constructieOf(c, n).id, c.constructii[1].id);
  c.constructii.splice(1, 1);                                     // construcția aleasă e ștearsă
  assert.equal(constructieOf(c, n).id, c.constructii[0].id);
  assert.equal(amendaSerieNr({ serie: ' AB ', numar: '123' }), 'Seria AB nr. 123');
  assert.equal(amendaSerieNr({ serie: '', numar: '9' }), 'nr. 9');
  assert.equal(amendaSerieNr({}), '');
  // date vechi (schema 2): câmpurile noi apar goale
  const old = normalizeControl({ id: 'x', objectiveId: 'o', dataInceput: '2026-01-01',
    acte: { ctpsi: { status: 'ok', obs: '' } },
    nereguli: [{ key: 'b', status: 'nok', amenda: { aplicata: true, data: '', suma: '100', achitata: false, dataAchitare: '' } }] });
  const b = old.nereguli.find((x) => x.key === 'b');
  assert.equal(b.constructieId, '');
  assert.equal(b.amenda.serie, '');
  assert.equal(b.amenda.suma, '100');
  assert.deepEqual(old.acte.exercitii, { status: '', obs: '' });
  assert.equal(old.acte.ctpsi.status, 'ok');
});
