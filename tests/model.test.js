import test from 'node:test';
import assert from 'node:assert/strict';
import { addDays, diffDays, parseDateQuery, zile, pasteOrtodox, zinelucratoare } from '../js/dates.js';
import {
  newControl, fineStatus, asiDeadline, matchControl, objectives, controlFromPrevious,
  normalizeControl, allFines, NEREGULI, SABLON, isApplicable, secStats, sectiuniActive, activeNereguli,
  neregulaLetter, tabOfNeregula, controlStats, constructieOf, amendaSerieNr, ACTE, emptyConstructie,
  vecheInfo, pvText, constatareLabel, todoList, NEREGULI_GRAVE, constructiiCuNU,
  fmtCoord, googleMapsUrl, gpsQuality,
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
  assert.equal(secStats(c, 'ner').total, 5 + 5 + 4 + 2 + 1); // a,b,d,e,f + aa…ae (mereu) + c,i,l,m + g,h + q
});

test('Planuri/SVSU și Protecție civilă: doar la Localitate, cu amenzi în Panou', () => {
  const o = newControl({ tip: 'OPEC', start: '2026-09-01' });
  assert.deepEqual(sectiuniActive(o), ['ner']);
  assert.equal(activeNereguli(o).length, NEREGULI.length + NEREGULI_GRAVE.length);
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

test('zile nelucrătoare: Paște ortodox, sărbători legale, weekend', () => {
  assert.equal(pasteOrtodox(2024), '2024-05-05');
  assert.equal(pasteOrtodox(2025), '2025-04-20');
  assert.equal(pasteOrtodox(2026), '2026-04-12');
  assert.equal(pasteOrtodox(2027), '2027-05-02');
  assert.match(zinelucratoare('2026-04-10'), /Vinerea Mare/);
  assert.match(zinelucratoare('2026-06-01'), /Ziua Copilului/);           // coincide cu a doua zi de Rusalii
  assert.match(zinelucratoare('2026-01-07'), /Sfântul Ioan/);
  assert.match(zinelucratoare('2026-12-01'), /Ziua Națională/);
  assert.equal(zinelucratoare('2026-10-03'), 'sâmbătă');
  assert.equal(zinelucratoare('2026-10-04'), 'duminică');
  assert.equal(zinelucratoare('2026-09-23'), '');
});

test('termenul de plată într-o zi nelucrătoare: avertizare, fără mutare', () => {
  const { c, n } = withFine('2026-09-18');                // +15 = 03.10.2026, sâmbătă
  const st = fineStatus(c, n, '2026-09-20');
  assert.equal(st.plataPana, '2026-10-03');               // nu se mută
  assert.equal(st.plataNelucr, 'sâmbătă');
  assert.match(st.nelucr, /cade sâmbătă — verifică prelungirea/);
  const ok = fineStatus(withFine('2026-09-16').c, withFine('2026-09-16').n, '2026-09-20'); // +15 = 01.10, joi
  assert.equal(ok.nelucr, '');
});

test('neregulă veche: automat din istoric, manual, doar controale anterioare', () => {
  const a = newControl({ denumire: 'X', start: '2025-03-01' });
  const b = controlFromPrevious(a, '2026-09-01');
  const later = controlFromPrevious(a, '2027-01-01');
  a.nereguli.find((n) => n.key === 'd').status = 'nok';
  later.nereguli.find((n) => n.key === 'e').status = 'nok';
  const all = [a, b, later];
  const d = b.nereguli.find((n) => n.key === 'd');
  const e = b.nereguli.find((n) => n.key === 'e');
  assert.equal(vecheInfo(all, b, d).veche, false);        // încă neconstatată acum
  d.status = 'nok';
  const vi = vecheInfo(all, b, d);
  assert.ok(vi.veche && vi.auto.id === a.id);
  e.status = 'nok';
  assert.equal(vecheInfo(all, b, e).veche, false);        // constatată doar la un control ULTERIOR
  e.vecheManual = true;
  assert.ok(vecheInfo(all, b, e).veche && !vecheInfo(all, b, e).auto);
  // rânduri adăugate: același text (fără diacritice / majuscule) = aceeași neregulă
  const ca = { ...b.nereguli[0], key: 'k1', custom: true, sec: 'ner', label: 'Căi de evacuare blocate', status: 'nok' };
  a.nereguli.push(ca);
  const cb = { ...b.nereguli[0], key: 'k2', custom: true, sec: 'ner', label: 'cai de EVACUARE blocate ', status: 'nok', vecheManual: false };
  b.nereguli.push(cb);
  assert.ok(vecheInfo(all, b, cb).auto);
});

test('text PV: numerotare, construcție, observații pe un rând, filtru netrecute', () => {
  const c = newControl({ denumire: 'Școala 1', start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Sala de sport';
  const d = c.nereguli.find((n) => n.key === 'd');
  Object.assign(d, { status: 'nok', obs: 'P6 nr. 3\nhol', constructieId: c.constructii[1].id, inPV: true });
  c.nereguli.find((n) => n.key === 'e').status = 'nok';
  c.acte.lfd.status = 'nok';
  const t = pvText(c, [c]).text;
  assert.match(t, /1\. Stingătoare expirate – construcția: Sala de sport\. P6 nr\. 3; hol/);
  assert.match(t, /2\. Stingătoare neconforme – construcția: Construcția 1/);
  assert.match(t, /Acte de autoritate și evidențe lipsă:\n3\. Dispoziție LFD/);
  const n2 = pvText(c, [c], { doarNetrecute: true, cuActe: false });
  assert.equal(n2.count, 1);
  assert.doesNotMatch(n2.text, /expirate/);
});

test('rubricile Planuri/PC neconforme apar cu formularea negativă (PV, Panou, fișă)', () => {
  const c = newControl({ tip: 'LOCALITATE', denumire: 'Comuna X', start: '2026-09-01' });
  const r = c.nereguli.find((n) => n.key === 'plEvacuare');
  assert.equal(constatareLabel(r), 'Plan evacuare conform');     // încă neverificată: numele rubricii
  r.status = 'nok';
  assert.equal(constatareLabel(r), 'Plan evacuare neconform');
  c.nereguli.find((n) => n.key === 'pcSireneNumar').status = 'nok';
  const t = pvText(c, [c]).text;
  assert.match(t, /Plan evacuare neconform/);
  assert.match(t, /Număr insuficient de sirene/);
  assert.doesNotMatch(t, /Plan evacuare conform/);
  const d = c.nereguli.find((n) => n.key === 'd'); d.status = 'nok';
  assert.equal(constatareLabel(d), 'Stingătoare expirate');       // neregulile rămân cu textul lor
});

test('„Ce mai am de făcut”: pașii rămași, în ordine, și lista goală la final', () => {
  const c = newControl({ start: '2026-09-01' });
  let t = todoList(c).map((x) => x.id);
  assert.deepEqual(t, ['denumire', 'acte', 'todo-ner', 'gps', 'close']);
  c.denumire = 'Școala 1';
  c.constructii[0].gps = { lat: 47.1335, lon: 24.4966, acc: 12, la: '2026-09-01T08:00:00.000Z' };
  for (const a of Object.values(c.acte)) a.status = 'ok';
  for (const n of c.nereguli) if (isApplicable(c, n)) n.status = 'ok';
  const d = c.nereguli.find((n) => n.key === 'd');
  d.status = 'nok'; d.amenda.aplicata = true;
  t = todoList(c);
  assert.deepEqual(t.map((x) => x.id), ['pv', 'fine-d', 'close']);
  assert.equal(t[0].focus, 'd');
  assert.match(t[1].text, /seria \/ nr\. și suma/);
  d.inPV = true; Object.assign(d.amenda, { serie: 'AB', numar: '1', suma: '500' });
  c.dataIncheiere = '2026-09-01';
  assert.deepEqual(todoList(c), []);
  // localitate: adăpostul PC contează la Protecție civilă
  const l = newControl({ tip: 'LOCALITATE', denumire: 'Comuna', start: '2026-09-01' });
  for (const n of l.nereguli) if (n.sec === 'pc') n.status = 'ok';
  const pc = todoList(l).find((x) => x.id === 'todo-pc');
  assert.ok(pc && /1 rubrică neverificată/.test(pc.text) && pc.focus === 'adapostPC');
});

test('v1.7: nereguli noi, detectori autonomi, ignifugare expirată, nereguli grave la NU', () => {
  const c = newControl({ denumire: 'Hotel', start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Anexă';
  const n = (k) => c.nereguli.find((x) => x.key === k);
  for (const k of ['aa', 'ab', 'ac', 'ad', 'ae']) assert.ok(isApplicable(c, n(k)), `${k} mereu vizibilă`);
  assert.ok(!isApplicable(c, n('af')) && !isApplicable(c, n('ag')));
  c.constructii[0].dotari.detectoriAutonomi.v = 'DA';
  c.constructii[1].dotari.ignifugare.v = 'DA';
  assert.ok(isApplicable(c, n('af')) && isApplicable(c, n('ag')));
  // NU = neregulă gravă; NEC nu
  const g = n('lipsa-hidInt');
  assert.equal(neregulaLetter(c, g), 'G1');
  assert.ok(!isApplicable(c, g));
  c.constructii[0].dotari.hidInt.v = 'NEC';
  assert.ok(!isApplicable(c, g));
  c.constructii[1].dotari.hidInt.v = 'NU';
  assert.ok(isApplicable(c, g));
  assert.equal(constructieOf(c, g).denumire, 'Anexă');               // implicit: construcția cu NU
  c.constructii[0].dotari.hidInt.v = 'NU';
  assert.deepEqual(constructiiCuNU(c, 'hidInt').map((k) => k.denumire), ['Construcția 1', 'Anexă']);
  const t = todoList(c);
  assert.equal(t[0].level, 'grav');
  assert.match(t[0].text, /lipsă hidranți interiori/);
  g.status = 'nok';
  assert.match(pvText(c, [c]).text, /Lipsă hidranți interiori – construcțiile: Construcția 1, Anexă/);
  assert.ok(!todoList(c).some((x) => x.id === 'grave'));
  // ASI / AVIZ pe NU nu generează nereguli grave (sunt documente)
  c.constructii[0].dotari.asi.v = 'NU';
  assert.ok(!c.nereguli.some((x) => x.key === 'lipsa-asi'));
});

test('v1.8: coordonate GPS pe fiecare construcție, preluate la controlul următor', () => {
  const c = newControl({ denumire: 'Școala 2', start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Sala de sport';
  let g = todoList(c).find((x) => x.id === 'gps');
  assert.match(g.text, /Construcția 1, Sala de sport/);
  assert.equal(g.focus, `gps-${c.constructii[0].id}`);
  c.constructii[0].gps = { lat: 47.1335, lon: 24.4966, acc: 12, la: '2026-09-01T08:00:00.000Z' };
  g = todoList(c).find((x) => x.id === 'gps');
  assert.equal(g.text, 'Coordonate GPS necompletate: Sala de sport');
  assert.equal(g.focus, `gps-${c.constructii[1].id}`);
  c.constructii[1].gps = { lat: 47.134, lon: 24.497, acc: 250, la: '2026-09-01T08:05:00.000Z' };
  assert.ok(!todoList(c).some((x) => x.id === 'gps'));
  const n = controlFromPrevious(c, '2027-09-01');
  assert.deepEqual(n.constructii.map((k) => k.gps?.lat), [47.1335, 47.134]);
  assert.notEqual(n.constructii[0].gps, c.constructii[0].gps);        // copie, nu referință
  assert.equal(fmtCoord(c.constructii[0].gps), '47.133500, 24.496600');
  assert.equal(googleMapsUrl(c.constructii[0].gps), 'https://www.google.com/maps/search/?api=1&query=47.133500,24.496600');
  assert.deepEqual([12, 30, 31, 100, 101].map(gpsQuality), ['buna', 'buna', 'medie', 'medie', 'slaba']);
  // date vechi: construcții fără gps → null; gps pe control (versiune de probă) → mutat la prima construcție
  const old = normalizeControl({ ...c, gps: { lat: 1, lon: 2, acc: 5 }, constructii: [{ id: 'k1', denumire: 'A' }] });
  assert.equal(old.constructii[0].gps.lat, 1);
  assert.ok(!('gps' in old));
  assert.equal(normalizeControl({ ...c, constructii: [{ id: 'k2' }] }).constructii[0].gps, null);
});
