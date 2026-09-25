import test from 'node:test';
import assert from 'node:assert/strict';
import { addDays, addMonths, diffDays, parseDateQuery, zile, pasteOrtodox, zinelucratoare } from '../js/dates.js';
import {
  newControl, fineStatus, asiDeadline, matchControl, objectives, controlFromPrevious,
  normalizeControl, allFines, NEREGULI, SABLON, isApplicable, secStats, sectiuniActive, activeNereguli,
  neregulaLetter, tabOfNeregula, controlStats, constructieOf, amendaSerieNr, ACTE, emptyConstructie,
  vecheInfo, pvText, constatareLabel, todoList, NEREGULI_GRAVE, constructiiCuNU,
  fmtCoord, googleMapsUrl, gpsQuality, constructiiOf, constructiiNume, matchNeregula, pesteParter, grfVPesteParter, sablon, isGrav, syncAutoNU,
  constructiiEligibile, verifStare, verifExpirate, verifText, catalogOf, fixeazaCatalog, schimbare, SCHEMA_VERSION, matchAct,
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

test('amenda: roșu după 25 de zile peste cele 15 → „Mai aveți 5 zile”', () => {
  const { c, n } = withFine('2026-09-01');
  const st = fineStatus(c, n, '2026-10-11'); // ziua 40
  assert.equal(st.level, 'red');
  assert.equal(st.daysLeft, 5);
  assert.match(st.msg, /Mai aveți 5 zile până să o trimiteți la ANAF; consultați calculatorul de termene/);
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
  assert.ok(!isApplicable(c, n('c1')));
  assert.ok(!isApplicable(c, n('g')));         // cameră CT: fără centrală
  c.constructii[0].dotari.idsai.v = 'NEC';
  assert.ok(!isApplicable(c, n('m')));
  c.constructii[0].dotari.idsai.v = 'DA';
  assert.ok(isApplicable(c, n('m')) && isApplicable(c, n('i')) && isApplicable(c, n('c1')));
  c.constructii[0].dotari.centrala.tipuri = ['GAZOS'];
  assert.ok(isApplicable(c, n('g')) && isApplicable(c, n('h')));
  // un rând completat nu dispare, chiar dacă instalația e scoasă
  n('q').status = 'nok';
  assert.ok(isApplicable(c, n('q')));
  assert.equal(secStats(c, 'ner').total, 8 + 5 + 2 + 4 + 2 + 1); // a,b1,b2,b3,d,e,f,al + aa…ae + ah,ai (mereu) + c1,i,l,m + g,h + q
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
  n.constructieIds = [c.constructii[1].id];
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
  assert.deepEqual(b.constructieIds, []);
  assert.ok(!('constructieId' in b));
  assert.equal(b.amenda.serieNr, '');
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
  assert.match(st.nelucr, /cade sâmbătă — verificați prelungirea/);
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
  Object.assign(d, { status: 'nok', obs: 'P6 nr. 3\nhol', constructieIds: [c.constructii[1].id], inPV: true });
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

test('v1.9: o neregulă în mai multe construcții; migrarea din constructieId', () => {
  const c = newControl({ denumire: 'SC Alfa SRL', start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2), emptyConstructie(3));
  c.constructii[1].denumire = 'Hală';
  c.constructii[2].denumire = 'Depozit';
  const d = c.nereguli.find((n) => n.key === 'd');
  assert.deepEqual(constructiiOf(c, d).map((k) => k.denumire), ['Construcția 1']);   // implicit prima
  d.constructieIds = [c.constructii[2].id, c.constructii[1].id];                    // ordinea din tabul Obiectiv
  assert.equal(constructiiNume(c, d), 'Hală, Depozit');
  d.status = 'nok';
  assert.match(pvText(c, [c]).text, /Stingătoare expirate – construcțiile: Hală, Depozit/);
  c.constructii.splice(2, 1);                                                       // Depozit ștearsă
  assert.equal(constructiiNume(c, d), 'Hală');
  assert.match(pvText(c, [c]).text, /Stingătoare expirate – construcția: Hală/);
  c.constructii.splice(1, 1);                                                       // și Hala
  assert.equal(constructiiNume(c, d), 'Construcția 1');
  // gravă: implicit toate construcțiile cu NU
  const g = newControl({ start: '2026-09-01' });
  g.constructii.push(emptyConstructie(2), emptyConstructie(3));
  g.constructii[0].dotari.hidInt.v = 'NU'; g.constructii[2].dotari.hidInt.v = 'NU';
  assert.equal(constructiiNume(g, g.nereguli.find((n) => n.key === 'lipsa-hidInt')), 'Construcția 1, Construcția 3');
  // date vechi (schema 6)
  const old = normalizeControl({ ...c, nereguli: [{ key: 'd', status: 'nok', constructieId: 'k9' }, { key: 'e', constructieId: '' }] });
  assert.deepEqual(old.nereguli.find((n) => n.key === 'd').constructieIds, ['k9']);
  assert.deepEqual(old.nereguli.find((n) => n.key === 'e').constructieIds, []);
  assert.ok(old.nereguli.every((n) => !('constructieId' in n)));
});

test('v1.9: căutarea în nereguli — literă exactă sau text fără diacritice', () => {
  const c = newControl({ start: '2026-09-01' });
  const by = (k) => c.nereguli.find((n) => n.key === k);
  const hits = (q) => c.nereguli.filter((n) => n.sec === 'ner' && matchNeregula(c, n, q)).map((n) => n.key);
  assert.deepEqual(hits('d'), ['d']);                           // literă: doar rândul d, nu toate care conțin „d”
  assert.deepEqual(hits('AG'), ['ag']);
  assert.ok(hits('G1').length === 1 && hits('G1')[0].startsWith('lipsa-'));
  assert.ok(hits('stingatoare').includes('d') && hits('stingatoare').includes('e'));
  assert.ok(hits('STINGĂTOARE expirate').includes('d') && !hits('stingatoare expirate').includes('e'));
  assert.deepEqual(hits('xyzq'), []);
  by('e').obs = 'la etajul 2, hol';
  assert.ok(hits('etajul').includes('e'));
  assert.ok(matchNeregula(c, by('d'), '  '));                  // căutare goală = tot
  const custom = { key: 'c1', custom: true, sec: 'ner', label: 'Ușă blocată la subsol', obs: '', status: '' };
  c.nereguli.push(custom);
  assert.ok(matchNeregula(c, custom, '+1') && matchNeregula(c, custom, 'usa blocata'));
});

test('v1.9: GRF/NSI V cu regim peste parter = neregulă gravă', () => {
  for (const r of ['P+1', 'P+2E', 'S+P+1', 'D+P+1E+M', 'p + 3', 'P+M', 'Parter + 1 etaj', 'S+P+10']) assert.ok(pesteParter(r), r);
  for (const r of ['P', 'S+P', 'D+P', '', 'parter', 'Sp']) assert.ok(!pesteParter(r), r || '(gol)');
  const c = newControl({ denumire: 'Depozit', start: '2026-09-01' });
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Birouri';
  const g = c.nereguli.find((n) => n.key === 'grav-grfV');
  assert.ok(g && !isApplicable(c, g));
  assert.equal(neregulaLetter(c, g), `G${NEREGULI_GRAVE.length}`);
  c.constructii[1].grf = 'V';
  c.constructii[1].regimInaltime = 'P';
  assert.ok(!isApplicable(c, g), 'V la parter: nu');
  c.constructii[1].regimInaltime = 'P+1';
  assert.ok(grfVPesteParter(c.constructii[1]) && isApplicable(c, g), 'V la P+1: da');
  assert.equal(constructiiNume(c, g), 'Birouri');                 // implicit: construcția care o declanșează
  const t = todoList(c).find((x) => x.id === 'grave');
  assert.match(t.text, /GRF\/NSI V/);
  c.constructii[1].grf = 'IV';
  assert.ok(!isApplicable(c, g), 'IV: nu');
  c.constructii[1].grf = 'NN';
  assert.ok(!isApplicable(c, g));
  // date vechi: construcțiile primesc grf ''
  assert.equal(normalizeControl({ ...c, constructii: [{ id: 'k' }] }).constructii[0].grf, '');
});

test('v1.9: „Restul conform” nu atinge neregulile grave', () => {
  const c = newControl({ start: '2026-09-01' });
  c.constructii[0].dotari.hidInt.v = 'NU';
  const g = c.nereguli.find((n) => n.key === 'lipsa-hidInt');
  assert.ok(isApplicable(c, g) && sablon(g.key).grav);
});

test('v1.9: sigiliu la neregulile grave; rând adăugat marcat „Neregulă gravă”', () => {
  const c = newControl({ denumire: 'Hală', start: '2026-09-01' });
  c.constructii[0].dotari.hidInt.v = 'NU';
  const g = c.nereguli.find((n) => n.key === 'lipsa-hidInt');
  assert.ok(isGrav(g) && !isGrav(c.nereguli.find((n) => n.key === 'd')));
  Object.assign(g, { status: 'nok', sigiliu: true });
  const custom = { ...normalizeControl({ ...c, nereguli: [{ key: 'x1', custom: true, label: 'Depozitare butelii în subsol', status: 'nok' }] }).nereguli.find((n) => n.key === 'x1') };
  assert.equal(custom.grav, false); assert.equal(custom.sigiliu, false);
  assert.ok(!isGrav(custom));
  c.nereguli.push({ ...custom, grav: true, sigiliu: true });
  const t = pvText(c, [c]).text;
  assert.match(t, /Lipsă hidranți interiori[^\n]*\(sigiliu aplicat\)/);
  assert.match(t, /Depozitare butelii în subsol \(neregulă gravă; sigiliu aplicat\)/);
});

test('v1.10: nereguli ah (fără ASI) și ai (lucrări fără aviz), mereu vizibile, în „Documentație”', () => {
  const c = newControl({ start: '2026-09-01' });
  for (const k of ['ah', 'ai']) {
    const n = c.nereguli.find((x) => x.key === k);
    assert.ok(n && isApplicable(c, n), `${k} vizibilă`);
    assert.equal(sablon(k).cat, 'docs');
    assert.equal(neregulaLetter(c, n), k);
  }
  assert.ok(matchNeregula(c, c.nereguli.find((x) => x.key === 'ah'), 'fara asi'));
  assert.ok(matchNeregula(c, c.nereguli.find((x) => x.key === 'ai'), 'aviz extindere'));
  // date vechi (schema 7): rândurile noi apar, necompletate
  const old = normalizeControl({ ...c, nereguli: c.nereguli.filter((x) => !['ah', 'ai'].includes(x.key)) });
  assert.equal(old.nereguli.find((x) => x.key === 'ah').status, '');
  assert.ok(old.nereguli.some((x) => x.key === 'ai'));
});

test('v1.10: ah / ai primele în listă; NU la ASI / AVIZ le constată automat, cu observațiile', () => {
  const c = newControl({ denumire: 'Hotel', start: '2026-09-01' });
  const ner = c.nereguli.filter((n) => n.sec === 'ner' && !sablon(n.key).grav).map((n) => n.key);
  assert.deepEqual(ner.slice(0, 3), ['ah', 'ai', 'a']);
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Anexă';
  const ah = c.nereguli.find((n) => n.key === 'ah');
  // NU la ASI pe Anexă, cu observații
  c.constructii[1].dotari.asi.v = 'NU';
  c.constructii[1].dotari.asi.obs = 'ASI solicitată în 2025, nefinalizată';
  assert.equal(syncAutoNU(c, 'asi'), 'added');
  assert.equal(ah.status, 'nok');
  assert.equal(constructiiNume(c, ah), 'Anexă');
  assert.equal(ah.obs, 'Anexă: ASI solicitată în 2025, nefinalizată');
  // observațiile din dotări se actualizează cât timp inspectorul nu le-a editat
  c.constructii[1].dotari.asi.obs = 'fără ASI';
  assert.equal(syncAutoNU(c, 'asi', { obsOnly: true }), 'updated');
  assert.equal(ah.obs, 'Anexă: fără ASI');
  // a doua construcție cu NU
  c.constructii[0].dotari.asi.v = 'NU';
  assert.equal(syncAutoNU(c, 'asi'), 'updated');
  assert.equal(constructiiNume(c, ah), 'Construcția 1, Anexă');
  // inspectorul editează observațiile → nu se mai suprascriu
  ah.obs = 'Funcționează fără ASI din 2024';
  c.constructii[1].dotari.asi.obs = 'altceva';
  syncAutoNU(c, 'asi', { obsOnly: true });
  syncAutoNU(c, 'asi');
  assert.equal(ah.obs, 'Funcționează fără ASI din 2024');
  // NU dispare: neregula lucrată rămâne (kept), cea nelucrată e retrasă (removed)
  c.constructii[0].dotari.asi.v = 'DA'; c.constructii[1].dotari.asi.v = 'DA';
  assert.equal(syncAutoNU(c, 'asi'), 'kept');
  assert.equal(ah.status, 'nok');
  const ai = c.nereguli.find((n) => n.key === 'ai');
  c.constructii[0].dotari.aviz.v = 'NU';
  assert.equal(syncAutoNU(c, 'aviz'), 'added');
  c.constructii[0].dotari.aviz.v = 'NEC';
  assert.equal(syncAutoNU(c, 'aviz'), 'removed');
  assert.equal(ai.status, '');
  assert.equal(syncAutoNU(c, 'aviz'), null);
  // control nou pe același obiectiv: NU moștenit → ai constatată din start
  c.constructii[1].dotari.aviz.v = 'NU';
  const n2 = controlFromPrevious(c, '2027-09-01');
  const ai2 = n2.nereguli.find((n) => n.key === 'ai');
  assert.equal(ai2.status, 'nok');
  assert.deepEqual(ai2.constructieIds, [n2.constructii[1].id]);
});

test('v1.11: addMonths — capăt de lună și an bisect', () => {
  assert.equal(addMonths('2025-03-12', 12), '2026-03-12');
  assert.equal(addMonths('2025-01-31', 1), '2025-02-28');
  assert.equal(addMonths('2024-01-31', 1), '2024-02-29');
  assert.equal(addMonths('2025-08-31', 6), '2026-02-28');
  assert.equal(addMonths('2025-11-15', 24), '2027-11-15');
});

test('v1.11: verificări defalcate, date pe construcție, expirare față de data controlului', () => {
  const c = newControl({ denumire: 'Hotel', start: '2026-09-24' });
  c.constructii.push(emptyConstructie(2));
  c.constructii[1].denumire = 'Anexă';
  const [k1, k2] = c.constructii;
  const n = (k) => c.nereguli.find((x) => x.key === k);
  // b1–b3 la toate construcțiile, mereu; c* doar cu DA; b și c vechi retrase
  for (const k of ['b1', 'b2', 'b3']) { assert.ok(isApplicable(c, n(k))); assert.equal(constructiiEligibile(c, n(k)).length, 2); }
  assert.ok(!isApplicable(c, n('c2')) && !isApplicable(c, n('b')) && !isApplicable(c, n('c')));
  k2.dotari.hidInt.v = 'DA';
  assert.ok(isApplicable(c, n('c2')));
  assert.deepEqual(constructiiEligibile(c, n('c2')).map((k) => k.denumire), ['Anexă']);
  assert.equal(constructiiNume(c, n('c2')), 'Anexă');                 // implicit: prima cu instalația
  assert.equal(constructiiNume(c, n('o')), 'Anexă');                  // la fel la neregulile de instalații
  // electrice 12 luni: 23.09.2025 → expiră 23.09.2026 < 24.09.2026
  n('b1').verificari[k1.id] = { data: '2025-09-23' };
  n('b1').verificari[k2.id] = { data: '2025-09-24' };
  assert.equal(verifStare(c, n('b1'), k1).stare, 'expirata');
  assert.equal(verifStare(c, n('b1'), k2).stare, 'valabila');            // expiră exact azi: încă valabilă
  assert.deepEqual(verifExpirate(c, n('b1')).map((k) => k.denumire), ['Construcția 1']);
  // împământare: 12 implicit, 24 la alegere
  n('b2').verificari[k1.id] = { data: '2025-03-01' };
  assert.equal(verifStare(c, n('b2'), k1).stare, 'expirata');
  n('b2').verificari[k1.id].luni = 24;
  assert.equal(verifStare(c, n('b2'), k1).stare, 'valabila');
  n('b1').verificari[k1.id].luni = 24;                                  // alegerea nu contează unde nu e permisă
  assert.equal(verifStare(c, n('b1'), k1).luni, 12);
  // CT 24, hidranți 6
  n('b3').verificari[k1.id] = { data: '2024-09-25' };
  assert.equal(verifStare(c, n('b3'), k1).stare, 'valabila');
  n('c2').verificari[k2.id] = { data: '2026-03-23' };
  assert.equal(verifStare(c, n('c2'), k2).stare, 'expirata');
  // „Ce mai aveți de făcut” semnalează verificările expirate neconstatate
  const t = todoList(c).filter((x) => x.id.startsWith('verif-')).map((x) => x.id);
  assert.deepEqual(t, ['verif-b1', 'verif-c2']);                   // b2 e pe 24 luni: valabilă
  // PV: datele la construcțiile alese
  Object.assign(n('b1'), { status: 'nok', constructieIds: [k1.id] });
  assert.match(pvText(c, [c]).text, /Nu a prezentat \/ nu are verificare instalații electrice – construcția: Construcția 1\. Construcția 1: ultima verificare 23\.09\.2025, expirată \(era valabilă până la 23\.09\.2026\)/);
  assert.ok(!todoList(c).some((x) => x.id === 'verif-b1'));
  // NEC: verificat, fără PV, fără semnalare
  n('b2').status = 'nec';
  assert.ok(!todoList(c).some((x) => x.id === 'verif-b2'));
  assert.doesNotMatch(pvText(c, [c]).text, /împământare/);
  // control nou: datele verificărilor se preiau, pe construcțiile noi
  const urm = controlFromPrevious(c, '2027-10-01');
  const b1 = urm.nereguli.find((x) => x.key === 'b1');
  assert.equal(b1.status, '');
  assert.deepEqual(Object.values(b1.verificari).map((v) => v.data).sort(), ['2025-09-23', '2025-09-24']);
  assert.equal(b1.verificari[urm.constructii[0].id].data, '2025-09-23');
  assert.equal(verifText(urm, { ...b1, status: 'nok' }), 'Construcția 1: ultima verificare 23.09.2025, expirată (era valabilă până la 23.09.2026)');
});

test('v1.11: NEC, aj/ak, rânduri vechi b/c, an construire, nr. ASI — compatibilitate', () => {
  const c = newControl({ start: '2026-09-01' });
  const n = (k) => c.nereguli.find((x) => x.key === k);
  c.constructii[0].dotari.exit.v = 'DA';
  c.constructii[0].dotari.ilumHint.v = 'DA';
  assert.ok(isApplicable(c, n('aj')) && isApplicable(c, n('ak')));
  assert.equal(sablon('aj').label, 'EXIT incomplet');
  assert.equal(sablon('ak').label, 'Iluminat Hint incomplet');
  // NEC contează ca verificat
  const st0 = secStats(c, 'ner');
  n('d').status = 'nec';
  assert.equal(secStats(c, 'ner').checked, st0.checked + 1);
  assert.equal(secStats(c, 'ner').constatate, 0);
  // date vechi: b constatat rămâne vizibil; construcția primește anConstruire; ASI primește nr
  const old = normalizeControl({ ...c, nereguli: [{ key: 'b', status: 'nok', obs: 'PRAM lipsă' }],
    constructii: [{ id: 'k', denumire: 'Corp', dotari: { asi: { v: 'DA', obs: '' } } }] });
  const b = old.nereguli.find((x) => x.key === 'b');
  assert.ok(isApplicable(old, b) && b.obs === 'PRAM lipsă');
  assert.deepEqual(b.verificari, {});
  assert.equal(old.constructii[0].anConstruire, '');
  assert.equal(old.constructii[0].dotari.asi.nr, '');
  assert.equal(old.constructii[0].dotari.asi.v, 'DA');
});

test('v1.11: al (stingătoare insuficiente) mereu; NU la Iluminat Hint → am, constatată automat', () => {
  const c = newControl({ denumire: 'Școala', start: '2026-09-01' });
  const n = (k) => c.nereguli.find((x) => x.key === k);
  assert.ok(isApplicable(c, n('al')) && sablon('al').cat === 'stingatoare');
  assert.ok(!isApplicable(c, n('am')));                            // ascunsă cât nu e NU
  c.constructii[0].dotari.ilumHint.v = 'NU';
  c.constructii[0].dotari.ilumHint.obs = 'hol etaj 1';
  assert.equal(syncAutoNU(c, 'ilumHint'), 'added');
  assert.ok(isApplicable(c, n('am')) && n('am').status === 'nok' && n('am').obs === 'hol etaj 1');
  c.constructii[0].dotari.ilumHint.v = 'DA';
  assert.equal(syncAutoNU(c, 'ilumHint'), 'removed');
  assert.ok(!isApplicable(c, n('am')));
});

test('v1.12: lista de nereguli înghețată la încheiere; controalele vechi rămân cum au fost', () => {
  // control creat și încheiat în v1.10 (schema 8), salvat înainte de v1.12 (fără `catalog`)
  const vechi = normalizeControl({ id: 'x', objectiveId: 'o', schema: 8, dataInceput: '2026-09-23', dataIncheiere: '2026-09-23',
    constructii: [{ id: 'k1', denumire: 'Corp', dotari: { hidInt: { v: 'DA', obs: '' }, ilumHint: { v: 'DA', obs: '' } } }],
    nereguli: [{ key: 'b', status: 'ok' }, { key: 'd', status: 'nok' }] });
  const n = (c, k) => c.nereguli.find((x) => x.key === k);
  assert.equal(catalogOf(vechi), 8);
  assert.ok(isApplicable(vechi, n(vechi, 'b')) && isApplicable(vechi, n(vechi, 'c')), 'b și c, ca în v1.10');
  for (const k of ['b1', 'b2', 'b3', 'c2', 'aj', 'ak', 'al']) assert.ok(!isApplicable(vechi, n(vechi, k)), `${k} nu apare`);
  assert.ok(isApplicable(vechi, n(vechi, 'ah')) && isApplicable(vechi, n(vechi, 'ai')), 'ah, ai existau în v1.10');
  const goale = vechi.nereguli.filter((x) => x.sec === 'ner' && !x.status && isApplicable(vechi, x)).map((x) => x.key);
  assert.deepEqual(goale, ['ah', 'ai', 'a', 'c', 'e', 'f', 'k', 'n', 'o', 'aa', 'ab', 'ac', 'ad', 'ae']);   // exact lista din v1.10
  assert.ok(!todoList(vechi).some((x) => x.id.startsWith('verif-')));
  // un rând completat nu se ascunde niciodată
  n(vechi, 'b1').status = 'ok';
  assert.ok(isApplicable(vechi, n(vechi, 'b1')));
  // control deschis: lista curentă; la încheiere se fixează, la redeschidere se eliberează
  const c = newControl({ start: '2026-09-25' });
  assert.equal(catalogOf(c), SCHEMA_VERSION);
  assert.ok(isApplicable(c, n(c, 'b1')) && !isApplicable(c, n(c, 'b')));
  c.dataIncheiere = '2026-09-25';
  fixeazaCatalog(c);
  assert.equal(c.catalog, SCHEMA_VERSION);
  c.dataIncheiere = '';
  fixeazaCatalog(c);
  assert.ok(!('catalog' in c));
});

test('v1.12: seria și nr. amenzii într-un singur câmp', () => {
  assert.equal(amendaSerieNr({ serieNr: 'DB 0012345' }), 'Seria DB nr. 0012345');
  assert.equal(amendaSerieNr({ serieNr: 'db0012345' }), 'Seria DB nr. 0012345');
  assert.equal(amendaSerieNr({ serieNr: 'seria CJ nr. 45 678' }), 'Seria CJ nr. 45678');
  assert.equal(amendaSerieNr({ serieNr: '0099' }), 'nr. 0099');
  assert.equal(amendaSerieNr({ serieNr: 'PV 12/2026' }), 'PV 12/2026');   // formă liberă: rămâne cum e scrisă
  assert.equal(amendaSerieNr({ serieNr: '  ' }), '');
  // date vechi: seria + numărul → un câmp, același text în PV
  const c = normalizeControl({ id: 'x', objectiveId: 'o', dataInceput: '2026-09-01',
    nereguli: [{ key: 'd', status: 'nok', amenda: { aplicata: true, serie: 'DB', numar: '0012345', suma: '2500' } }] });
  const d = c.nereguli.find((x) => x.key === 'd');
  assert.equal(d.amenda.serieNr, 'DB 0012345');
  assert.ok(!('serie' in d.amenda) && !('numar' in d.amenda));
  assert.match(pvText(c, [c]).text, /sancționat cu amendă Seria DB nr\. 0012345/);
  // „Ce mai aveți de făcut”: lipsa seriei / nr.
  d.amenda.serieNr = '';
  assert.ok(todoList(c).some((x) => x.id === 'fine-d' && /seria \/ nr\./.test(x.text)));
});

test('v1.12: Anulează / Refă — locul schimbat', () => {
  const a = newControl({ denumire: 'X', start: '2026-09-25' });
  a.constructii.push(emptyConstructie(2));
  const clone = () => JSON.parse(JSON.stringify(a));
  let b = clone(); b.nereguli.find((x) => x.key === 'd').status = 'nok';
  assert.deepEqual(schimbare(a, b), { tab: 'nereguli', focus: 'd', text: 'd. Stingătoare expirate' });
  b = clone(); b.acte.lfd.status = 'ok';
  assert.equal(schimbare(a, b).focus, 'act-lfd');
  b = clone(); b.constructii[1].dotari.hidInt.v = 'DA';
  assert.deepEqual(schimbare(a, b), { tab: 'obiectiv', focus: `constr-${a.constructii[1].id}`, text: 'Construcția 2' });
  b = clone(); b.dataIncheiere = '2026-09-25';
  assert.equal(schimbare(a, b).focus, 'sec-perioada');
  b = clone(); b.administrator = 'Ion';
  assert.equal(schimbare(a, b).focus, 'sec-date');
  // rând adăugat, apoi anulat: se arată secțiunea de rânduri adăugate
  const cu = clone(); cu.nereguli.push({ key: 'x1', custom: true, sec: 'ner', label: 'test', status: 'nok' });
  assert.deepEqual(schimbare(cu, a), { tab: 'nereguli', focus: 'add-ner', text: 'rândul adăugat' });
});

test('v1.12: glosar în căutare (Hint ↔ hidranți interiori, IDSAI, LFD, CTPSI…) și căutarea în acte', () => {
  const c = newControl({ start: '2026-09-25' });
  const hits = (q) => c.nereguli.filter((n) => n.sec === 'ner' && !n.custom && matchNeregula(c, n, q)).map((n) => n.key);
  assert.ok(hits('hidranti interiori').includes('n') && hits('hidranti interiori').includes('o'), 'Hint ← hidranți interiori');
  assert.ok(hits('hint').includes('c2'), 'verificare hidranți interiori ← hint');
  assert.ok(hits('hidranti exteriori').includes('q') && hits('hext').includes('c3'));
  assert.ok(hits('detectare').includes('m') && hits('alarmare').includes('l'), 'IDSAI');
  assert.ok(hits('evacuare').includes('j'), 'EXIT = iluminare de securitate pentru evacuare');
  assert.ok(hits('marcarea hidrantilor').includes('k') && !hits('marcarea hidrantilor').includes('n'), 'Iluminat Hint, fără Hint');
  assert.ok(hits('autorizatie').includes('ah'));
  assert.ok(!hits('asigurare').length, '„asi” nu se potrivește în mijlocul cuvintelor');
  assert.ok(matchAct(c, 'lfd', 'foc deschis') && matchAct(c, 'ctpsi', 'cadru tehnic') && matchAct(c, 'ctpsi', 'responsabil'));
  assert.ok(matchAct(c, 'lfd', '2') && !matchAct(c, 'lfd', '3'), 'numărul actului');
  assert.ok(!matchAct(c, 'instruire', 'foc deschis'));
});
