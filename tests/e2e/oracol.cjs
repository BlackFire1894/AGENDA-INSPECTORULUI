// Audit numeric: fiecare cifră afișată e comparată cu o numărătoare INDEPENDENTĂ făcută direct din date.
// Regulile (README / cerințele inspectorului): plata în 15 zile de la data aplicării (implicit data încheierii);
// albastru zilele 0–15, galben 16–39, roșu de la ziua 40; termen ANAF = ziua 45; ASI = 90 de zile de la încheiere.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const MODE = process.argv[2] || 'sintetic';
const T = '2026-10-15';
let C = [];
let okN = 0, failN = 0;
const ok = (c, m) => { if (c) okN++; else { failN++; console.log('FAIL: ' + m); } };
const eq = (got, exp, m) => ok(got === exp, `${m}: afișat ${JSON.stringify(got)}, corect ${JSON.stringify(exp)}`);
// ── utilitare independente
const dn = (iso) => { const [y, m, d] = iso.split('-').map(Number); return Date.UTC(y, m - 1, d) / 86400000; };
const days = (a, b) => dn(b) - dn(a);
const plus = (iso, n) => new Date((dn(iso) + n) * 86400000).toISOString().slice(0, 10);
const fmt = (iso) => `${iso.slice(8, 10)}.${iso.slice(5, 7)}.${iso.slice(0, 4)}`;
const isISO = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s);
const zile = (n) => { const a = Math.abs(n); if (a === 1) return `${n} zi`; const r = a % 100; return `${n} ${a && (r === 0 || r >= 20) ? 'de ' : ''}zile`; };
const inchis = (c) => isISO(c.dataIncheiere);
const secOf = (n) => n.sec || 'ner';
const activ = (c) => c.nereguli.filter((n) => secOf(n) === 'ner' || c.tip === 'LOCALITATE');
const nokOf = (c) => activ(c).filter((n) => n.status === 'nok');
function amenda(c, n) {
  const a = n.amenda;
  if (a.achitata) return { lv: 'green', msg: a.dataAchitare ? `Dovadă primită · ${fmt(a.dataAchitare)}` : 'Dovadă de plată primită' };
  const ref = isISO(a.data) ? a.data : inchis(c) ? c.dataIncheiere : '';
  if (!ref) return { lv: 'blue', msg: 'Termenele pornesc de la data încheierii controlului', pending: true };
  const e = days(ref, T); const plata = plus(ref, 15); const anaf = plus(ref, 45);
  if (e < 0) return { lv: 'blue', left: 15 - e, msg: `Data aplicării amenzii e în viitor (${fmt(ref)}); plata până la ${fmt(plata)}`, plata, anaf };
  if (e <= 15) { const l = 15 - e; return { lv: 'blue', left: l, plata, anaf, msg: l === 0 ? 'Astăzi este ultima zi de plată' : `${l === 1 ? 'Mai este 1 zi' : `Mai sunt ${zile(l)}`} din termenul de plată (${fmt(plata)})` }; }
  if (e <= 39) return { lv: 'yellow', left: 45 - e, plata, anaf, msg: `Termenul de plată a expirat de ${zile(e - 15)} (${fmt(plata)})` };
  const l = 45 - e;
  return { lv: 'red', left: l, plata, anaf, msg: l > 0 ? `Mai aveți ${zile(l)} până să o trimiteți la ANAF; consultați calculatorul de termene` : l === 0 ? 'Astăzi este ultima zi pentru trimiterea la ANAF; consultați calculatorul de termene' : `Termenul de trimitere la ANAF (${fmt(anaf)}) a fost depășit cu ${zile(-l)}` };
}
const LABEL = { blue: 'În curs', yellow: 'Termen 15 zile expirat', red: 'Trimite la ANAF', green: 'Achitată' };
let fines = [];
function asi(c) {
  const n = c.nereguli.find((x) => x.key === 'a' && !x.custom);
  if (!n || n.status !== 'nok' || !n.asiTermen) return null;
  if (n.asiPrezentat) return { resolved: true };
  if (!inchis(c)) return { pending: true };
  const dl = plus(c.dataIncheiere, 90); const left = days(T, dl);
  if (left >= 0) return { dl, left };
  if (n.asiPierdere) return { resolved: true };
  const dl2 = plus(dl, 5); return { dl, dl2, faza: true, left: days(T, dl2) };   // a doua etapă: 5 zile calendaristice
}
// încărcarea: 3 zile lucrătoare de la încheiere (zilele nelucrătoare: lista legală verificată, din dates.js)
let nelucr = () => false;
function incarcare(c) {
  if (!inchis(c)) return null;
  const i = c.incarcare || {}; const lipsa = [!i.aplicatie && 'aplicatie', !i.document && 'document'].filter(Boolean);
  if (!lipsa.length) return { gata: true };
  let d = c.dataIncheiere, k = 0; while (k < 3) { d = plus(d, 1); if (!nelucr(d)) k++; }
  let left; if (T > d) left = -days(d, T); else { left = 0; for (let x = plus(T, 1); x <= d; x = plus(x, 1)) if (!nelucr(x)) left++; }
  return { gata: false, lipsa, termen: d, left, level: left > 0 ? 'warn' : 'red' };
}
const LIPSA = { aplicatie: 'Neîncărcat în aplicație', document: 'Document neîncărcat' };
const cnt = (lv) => fines.filter((f) => f.s.lv === lv).length;
(async () => {
  const D = await import(require('path').resolve(__dirname, '../../js/dates.js')); nelucr = (x) => !!D.zinelucratoare(x);
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 1180, height: 820 }, serviceWorkers: 'block', acceptDownloads: true });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.clock.install({ time: new Date(2026, 9, 15, 10, 0) });
  if (MODE === 'demo') {
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
  } else {
    await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
    await p.setInputFiles('[data-import]', __dirname + '/date.json'); await p.waitForTimeout(300);
    await p.click('[data-mode="replace"]'); await p.waitForTimeout(500);
  }
  // datele exact cum le are aplicația (după normalizare), prin Backup
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
  const [dl] = await Promise.all([p.waitForEvent('download'), p.click('[data-act="backup-export"]:visible')]);
  C = JSON.parse(fs.readFileSync(await dl.path(), 'utf8')).controls;
  fines = C.flatMap((c) => nokOf(c).filter((n) => n.amenda?.aplicata).map((n) => ({ c, n, s: amenda(c, n) })));
  console.log(`-- ${MODE}: ${C.length} controale, ${fines.length} amenzi`);
  // ── meniul lateral
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(400);
  const urg = cnt('red') + cnt('yellow'); const open = C.filter((c) => !inchis(c)).length;
  eq(await p.locator('.sidebar [data-badge-text="panou"]').innerText(), `${urg} ${urg === 1 ? 'amendă urgentă' : 'amenzi urgente'}`, 'meniu: Panou');
  eq(await p.locator('.sidebar [data-badge-text="istoric"]').innerText(), `${open} ${open === 1 ? 'neîncheiat' : 'neîncheiate'}`, 'meniu: Istoric');
  // ── Panou: casete
  const active = fines.filter((f) => f.s.lv !== 'green');
  const asis = C.map((c) => ({ c, a: asi(c) })).filter((x) => x.a && !x.a.resolved);
  const asiAct = asis.filter((x) => !x.a.pending);
  const netrec = C.flatMap((c) => nokOf(c).filter((n) => !n.inPV));
  eq(await p.locator('.kpi-fines .kpi-num').innerText(), String(active.length), 'Panou: Amenzi active');
  eq(await p.locator('.kpi-open .kpi-num').innerText(), String(open), 'Panou: Controale neîncheiate');
  eq(await p.locator('.kpi-asi .kpi-num').innerText(), String(asiAct.length), 'Panou: Termene ASI (active)');
  eq(await p.locator('.kpi-pv .kpi-num').innerText(), String(netrec.length), 'Panou: Netrecute în PV');
  const leg = (await p.locator('.kpi-fines .kpi-legend > span').allInnerTexts()).map((s) => s.replace(/\s+/g, ' ').trim());
  const expLeg = [[cnt('red'), 'de trimis la ANAF'], [cnt('yellow'), 'cu termen de plată expirat'], [cnt('blue'), 'în curs']].filter(([n]) => n).map(([n, t]) => `${n} ${t}`);
  eq(leg.join(' | '), expLeg.join(' | '), 'Panou: legenda amenzilor');
  ok(leg.reduce((s, x) => s + parseInt(x, 10), 0) === active.length, 'Panou: legenda însumează totalul');
  eq((await p.locator('.kpi-fines .kpi-foot').innerText()).trim(), cnt('green') ? `+ ${cnt('green')} ${cnt('green') === 1 ? 'achitată' : 'achitate'} (nu intră în total)` : '', 'Panou: achitate');
  const oldest = C.filter((c) => !inchis(c)).map((c) => c.dataInceput).sort()[0];
  eq((await p.locator('.kpi-open .kpi-foot').innerText()).trim(), `cel mai vechi: ${fmt(oldest)}`, 'Panou: cel mai vechi control');
  const near = asiAct.map((x) => x.a.left).sort((a, b) => a - b)[0];
  const pend = asis.length - asiAct.length;
  eq((await p.locator('.kpi-asi .kpi-foot').innerText()).trim().replace(/\s+/g, ' '), `${near >= 0 ? `cel mai apropiat: ${near === 0 ? 'expiră azi' : zile(near)}` : `unul depășit cu ${zile(-near)}`}${pend ? ` + ${pend} ${pend === 1 ? 'neînceput' : 'neîncepute'} (control neîncheiat)` : ''}`, 'Panou: ASI cel mai apropiat');
  // ── Panou: lista amenzilor (ordine, stadiu, mesaj, sumă)
  const order = { red: 0, yellow: 1, blue: 2 };
  const expFines = [...active].sort((x, y) => order[x.s.lv] - order[y.s.lv] || (x.s.left ?? 999) - (y.s.left ?? 999));
  const shown = await p.locator('#sec-fines > .items > .item').evaluateAll((els) => els.map((e) => ({ t: e.querySelector('.item-title').innerText, sub: e.querySelector('.item-sub').innerText, msg: e.querySelector('.item-msg').innerText, st: e.querySelector('.fine-st').innerText.trim() })));
  eq(shown.length, expFines.length, 'Panou: numărul amenzilor active listate');
  expFines.forEach((f, i) => {
    const s = shown[i] || {};
    eq(`${s.t} | ${s.st} | ${s.msg}`, `${f.c.denumire} | ${LABEL[f.s.lv]} | ${f.s.msg}`, `Panou: amenda #${i + 1} (${f.c.denumire}, ${f.n.key})`);
  });
  eq(await p.locator('#sec-fines details.paid summary').innerText().catch(() => ''), cnt('green') ? `Achitate (${cnt('green')})` : '', 'Panou: achitate (listă)');
  // ── Panou: ASI
  const asiItems = await p.locator('#sec-asi .item').evaluateAll((els) => els.map((e) => ({ t: e.querySelector('.item-title').innerText, side: e.querySelector('.item-side').innerText.replace(/\s+/g, ' ').trim() })));
  const cd = (d, lucr) => { const n = Math.abs(d); const u = `${n === 1 ? 'zi' : 'zile'}${lucr && d > 0 ? ' lucrătoare' : ''}`; return `${n} ${d < 0 ? `${u} peste termen` : d === 0 ? 'ultima zi: azi' : `${u} rămase`}`; };
  const expAsi = [...asis].sort((x, y) => (x.a.left ?? 9999) - (y.a.left ?? 9999)).map(({ c, a }) => `${c.denumire} | ${a.pending ? 'neînceput' : cd(a.left)}`);
  eq(asiItems.map((x) => `${x.t} | ${x.side}`).join(' || '), expAsi.join(' || '), 'Panou: termenele ASI');
  // ── Panou: controale neîncheiate
  const openItems = await p.locator('#sec-open .item').evaluateAll((els) => els.map((e) => `${e.querySelector('.item-title').innerText} | ${e.querySelector('.item-side').innerText.trim()}`));
  const expOpen = C.filter((c) => !inchis(c)).sort((a, b) => b.dataInceput.localeCompare(a.dataInceput) || (b.createdAt || '').localeCompare(a.createdAt || '')).map((c) => { const d = days(c.dataInceput, T); return `${c.denumire} | ${d < 0 ? `începe peste ${zile(-d)}` : d === 0 ? 'început azi' : d === 1 ? 'început ieri' : `de ${zile(d)}`}`; });
  eq(openItems.join(' || '), expOpen.join(' || '), 'Panou: controale neîncheiate');
  eq(await p.locator('#sec-pv .item').count(), netrec.length, 'Panou: lista netrecutelor în PV');
  // ── Panou: de încărcat
  const inc = C.map((c) => ({ c, s: incarcare(c) })).filter((x) => x.s && !x.s.gata);
  eq(await p.locator('.kpi-inc .kpi-num').innerText(), String(inc.length), 'Panou: De încărcat');
  const incItems = await p.locator('#sec-inc .item').evaluateAll((els) => els.map((e) => `${e.querySelector('.item-title').innerText} | ${[...e.querySelectorAll('.chips .pill')].map((x) => x.innerText.trim()).join(', ')} | ${e.querySelector('.item-side').innerText.replace(/\s+/g, ' ').trim()}`));
  const expInc = [...inc].sort((x, y) => x.s.left - y.s.left).map(({ c, s: x }) => `${c.denumire} | ${x.lipsa.map((k) => LIPSA[k]).join(', ')} | ${cd(x.left, true)}`);
  eq(incItems.join(' || '), expInc.join(' || '), 'Panou: lista „De încărcat”');
  // ── Istoric: cipurile fiecărui control
  await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(400);
  const rows = await p.locator('.ctl-row').evaluateAll((els) => els.map((e) => ({ id: e.getAttribute('href').split('/')[2], t: e.querySelector('.ctl-title').innerText, chips: [...e.querySelectorAll('.chips .pill')].map((x) => x.innerText.trim()) })));
  eq(rows.length, C.length, 'Istoric: numărul controalelor');
  for (const c of C) {
    const r = rows.find((x) => x.id === c.id);
    if (!r) { ok(false, `Istoric: lipsește ${c.denumire}`); continue; }
    const nk = nokOf(c); const nr = nk.filter((n) => !n.inPV).length;
    const exp = [];
    if (nk.length) exp.push(`${nk.length} ${nk.length === 1 ? 'neregulă' : 'nereguli'}`);
    if (nr) exp.push(`${nr} ${nr === 1 ? 'netrecută' : 'netrecute'} în PV`);
    const fl = {}; nk.filter((n) => n.amenda?.aplicata).forEach((n) => { const lv = amenda(c, n).lv; fl[lv] = (fl[lv] || 0) + 1; });
    for (const lv of ['red', 'yellow', 'blue', 'green']) if (fl[lv]) exp.push(`${fl[lv]} ${fl[lv] === 1 ? 'amendă' : 'amenzi'} · ${lv === 'green' && fl[lv] > 1 ? 'Achitate' : LABEL[lv]}`);
    const a = asi(c);
    if (a && !a.resolved) {
      const cand = a.left > 0 ? (a.left === 1 ? 'mai este 1 zi' : `mai sunt ${zile(a.left)}`) : a.left === 0 ? (a.faza ? 'ultima zi azi' : 'expiră azi') : `depășit cu ${zile(-a.left)}`;
      exp.push(a.pending ? 'ASI 90 de zile: neînceput' : a.faza ? `ASI, constatarea pierderii valabilității: ${cand}` : `ASI: ${cand}`);
    }
    const ic = incarcare(c);
    if (ic?.gata) exp.push('Încărcat în aplicație · document încărcat');
    else if (ic) { ic.lipsa.forEach((k) => exp.push(LIPSA[k])); exp.push(ic.left < 0 ? `Încărcare: termen depășit cu ${zile(-ic.left)}` : ic.left === 0 ? 'Încărcare: ultima zi azi' : `Încărcare: ${ic.left === 1 ? '1 zi lucrătoare' : `${ic.left} zile lucrătoare`}`); }
    const got = r.chips.filter((x) => !/^(Încheiat|În desfășurare)$|grav|veche|vechi/.test(x));
    eq(got.join(' | '), exp.join(' | '), `Istoric: ${c.denumire}`);
    const ant = C.filter((x) => x.objectiveId === c.objectiveId && x.id !== c.id && (x.dataInceput < c.dataInceput || (x.dataInceput === c.dataInceput && (x.createdAt || '') < (c.createdAt || ''))));
    const same = (a, b2) => (a.custom || b2.custom ? a.custom && b2.custom && a.label.trim().toLowerCase() && a.label.trim().toLowerCase() === b2.label.trim().toLowerCase() : a.key === b2.key);
    const vechi = nk.filter((n) => n.vecheManual || ant.some((x) => x.nereguli.some((m) => m.status === 'nok' && same(m, n)))).length;
    eq(r.chips.find((x) => /veche|vechi/.test(x)) || '', vechi ? `${vechi} ${vechi === 1 ? 'neregulă veche' : 'nereguli vechi'}` : '', `Istoric: ${c.denumire} — nereguli vechi`);
  }
  // ── Control: taburi, sumar, bare de categorie, filtre, fișa
  for (const c of C) {
    await p.goto(`http://localhost:8080/#/control/${c.id}/nereguli`); await p.waitForTimeout(350);
    const tabs = await p.locator('.ed-tab').evaluateAll((els) => els.map((e) => ({ st: e.querySelector('.tab-txt small:not(.tab-prog-txt)').innerText.trim(), pr: e.querySelector('.tab-prog-txt').innerText.trim() })));
    // Obiectiv: construcții + dotări completate (independent, din date)
    const set = c.constructii.reduce((s, k) => s + Object.entries(k.dotari).filter(([key, v]) => (key === 'centrala' ? (v.tipuri || []).length || v.nuAre : v.v)).length, 0);
    const totD = c.constructii.reduce((s, k) => s + Object.keys(k.dotari).length, 0);
    eq(`${tabs[0].st} | ${tabs[0].pr}`, `${c.constructii.length} ${c.constructii.length === 1 ? 'construcție' : 'construcții'} | Dotări ${set}/${totD}`, `${c.denumire}: tabul Obiectiv`);
    const acte = Object.values(c.acte); const lipsa = acte.filter((a) => a.status === 'nok').length; const ver = acte.filter((a) => a.status).length;
    eq(`${tabs[1].st} | ${tabs[1].pr}`, `${lipsa} lipsă | Verificate ${ver}/${acte.length}`, `${c.denumire}: tabul Acte`);
    const secs = c.tip === 'LOCALITATE' ? ['plan', 'pc', 'ner'] : ['ner'];
    const nev = {};
    const tabKey = { plan: 'planuri', pc: 'pc', ner: 'nereguli' };
    for (const sec of secs) {
      const rowsSec = c.nereguli.filter((n) => secOf(n) === sec); const nk = rowsSec.filter((n) => n.status === 'nok'); const nr = nk.filter((n) => !n.inPV).length;
      const w = sec === 'ner' ? (nk.length === 1 ? 'constatată' : 'constatate') : (nk.length === 1 ? 'neconformă' : 'neconforme');
      const ti = ['obiectiv', 'acte', ...(c.tip === 'LOCALITATE' ? ['planuri', 'pc', 'nereguli'] : ['nereguli'])].indexOf(tabKey[sec]);
      eq(tabs[ti].st, `${nk.length} ${w}${nr ? ` · ${nr} ${nr === 1 ? 'netrecută' : 'netrecute'} în PV` : ''}`, `${c.denumire}: tabul ${tabKey[sec]}`);
      await p.goto(`http://localhost:8080/#/control/${c.id}/${tabKey[sec]}`); await p.waitForTimeout(300);
      const sum = (await p.locator('.sum-line').innerText()).replace(/\s+/g, ' ');
      const [, chk, tot] = sum.match(/(\d+)\/(\d+) verificate/) || [];
      const tabPr = (await p.locator('.ed-tab.on .tab-prog-txt').innerText()).match(/(\d+)\/(\d+)/);
      eq(`${chk}/${tot}`, `${tabPr[1]}/${tabPr[2]}`, `${c.denumire} ${sec}: sumarul = progresul tabului`);
      ok(new RegExp(`\\b${nk.length} ${sec === 'ner' ? 'constatat' : 'neconform'}`).test(sum), `${c.denumire} ${sec}: sumarul arată ${nk.length} constatate — „${sum}”`);
      if (nk.length) ok(sum.includes(`${nk.length - nr}/${nk.length} în PV`), `${c.denumire} ${sec}: în PV ${nk.length - nr}/${nk.length} — „${sum}”`);
      const nf = nk.filter((n) => n.amenda?.aplicata).length;
      if (nf) ok(sum.includes(`${nf} ${nf === 1 ? 'amendă' : 'amenzi'}`), `${c.denumire} ${sec}: ${nf} amenzi — „${sum}”`);
      const filt = await p.locator('.segmented button').allInnerTexts();
      eq(filt[2], `Neverificate (${tot - chk})`, `${c.denumire} ${sec}: filtrul Neverificate`);
      nev[sec] = tot - chk;
      eq(filt[1].replace(/\s+/g, ' '), `${sec === 'ner' ? 'Constatate' : 'Neconforme'} (${nk.length})`, `${c.denumire} ${sec}: filtrul Constatate`);
      // barele categoriilor: sumele trebuie să dea totalurile
      const bars = await p.locator('.cat-title .cat-info, .custom-toggle .cat-info').evaluateAll((els) => els.map((e) => e.innerText.replace(/\s+/g, ' ')));
      const s = (re) => bars.reduce((a, t) => a + ((t.match(re) || [])[1] | 0), 0);
      eq(s(/(\d+) necompletat/), tot - chk, `${c.denumire} ${sec}: suma „necompletate” din bare = neverificate`);
      eq(s(/(\d+) (?:constatat|neconform)/), nk.length, `${c.denumire} ${sec}: suma constatate din bare`);
      eq(s(/(\d+) netrecut/), nr, `${c.denumire} ${sec}: suma netrecute din bare`);
      eq(s(/(\d+) amendat/), nf, `${c.denumire} ${sec}: suma amendate din bare`);
    }
    // „Ce mai aveți de făcut”: neverificatele fiecărei secțiuni = filtrul Neverificate
    await p.goto(`http://localhost:8080/#/control/${c.id}/obiectiv`); await p.waitForTimeout(250);
    if (await p.locator('[data-act="todo-toggle"]').count()) { await p.click('[data-act="todo-toggle"]'); await p.waitForTimeout(200); }
    const todo = (await p.locator('.todo').innerText().catch(() => '')).replace(/\s+/g, ' ');
    const actNev = Object.values(c.acte).filter((a) => !a.status).length;
    const SL = { ner: 'Nereguli', plan: 'Planuri și SVSU', pc: 'Protecție civilă' };
    for (const [sec, k] of Object.entries(nev)) {
      if (k) ok(todo.includes(`${SL[sec]}: ${k} `), `${c.denumire}: „Ce mai aveți de făcut” → ${SL[sec]}: ${k} (= filtrul Neverificate) — „${todo.slice(0, 200)}”`);
      else ok(!todo.includes(`${SL[sec]}: `), `${c.denumire}: „Ce mai aveți de făcut” nu mai cere nimic la ${SL[sec]}`);
    }
    if (actNev) ok(todo.includes(`${actNev} ${actNev === 1 ? 'act neverificat' : 'acte neverificate'}`), `${c.denumire}: „Ce mai aveți de făcut” → ${actNev} acte neverificate — „${todo.slice(0, 160)}”`);
    // Text PV: fiecare constatare (fără NEC) și fiecare act lipsă apare o singură dată
    await p.goto(`http://localhost:8080/#/control/${c.id}/nereguli`); await p.waitForTimeout(250);
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(250);
    const pv = await p.locator('.pv-text').inputValue();
    const pvLines = pv.split('\n').filter((x) => /^\s*\d+\.\s/.test(x)).length;
    const lipsaActe = Object.values(c.acte).filter((a) => a.status === 'nok').length;
    eq(pvLines, nokOf(c).length + lipsaActe, `${c.denumire}: Text PV — rânduri numerotate (constatări + acte lipsă)`);
    await p.keyboard.press('Escape'); await p.goto('about:blank'); await p.goto(`http://localhost:8080/#/control/${c.id}/nereguli`); await p.waitForTimeout(200);
    // fișa
    await p.goto(`http://localhost:8080/#/fisa/${c.id}`); await p.waitForTimeout(300);
    const fs2 = await p.locator('.f-sum > div').evaluateAll((els) => els.map((e) => e.innerText.replace(/\s+/g, ' ').trim()));
    const nk = nokOf(c); const nr = nk.filter((n) => !n.inPV).length; const nf = nk.filter((n) => n.amenda?.aplicata).length;
    ok(fs2[0].startsWith(`${nk.length} `) && fs2[1].startsWith(`${nr} `) && fs2[2].startsWith(`${nf} `) && fs2[4].startsWith(`${lipsa} `), `${c.denumire}: fișa ${fs2.join(' | ')} (corect: ${nk.length} / ${nr} / ${nf} / acte lipsă ${lipsa})`);
  }
  // ── Calendar: termenele din octombrie 2026 și numărul controalelor lunii
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(400);
  const dots = await p.locator('.cal-cell:not(.out)').evaluateAll((els) => Object.fromEntries(els.map((e) => [e.dataset.date, e.querySelectorAll('.cal-dls .dot').length])));
  const exp = {};
  const add = (d) => { if (d.slice(0, 7) === '2026-10') exp[d] = (exp[d] || 0) + 1; };
  fines.filter((f) => f.s.lv !== 'green' && f.s.plata).forEach((f) => { add(f.s.plata); add(f.s.anaf); });
  asis.filter((x) => x.a.dl).forEach((x) => { add(x.a.dl); if (x.a.dl2) add(x.a.dl2); });
  C.map(incarcare).filter((x) => x && !x.gata).forEach((x) => add(x.termen));
  const bad = Object.keys({ ...dots, ...exp }).filter((d) => (dots[d] || 0) !== Math.min(exp[d] || 0, 4));
  ok(!bad.length, `Calendar: bulinele termenelor pe zile ${bad.map((d) => `${d}: ${dots[d] || 0} vs ${exp[d] || 0}`).join(', ')}`);
  const inMonth = C.filter((c) => { const s = c.dataInceput; let e = inchis(c) && c.dataIncheiere >= s ? c.dataIncheiere : s; if (!inchis(c) && T > s) e = T; return s <= '2026-10-31' && e >= '2026-10-01'; }).length;
  ok((await p.locator('.page-head .eyebrow').innerText()).includes(`${inMonth} ${inMonth === 1 ? 'control' : 'controale'} în această lună`), `Calendar: ${inMonth} controale în octombrie`);
  // ── Obiective: pagina obiectivului repetat
  if (MODE === 'sintetic') {
  await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(300);
  await p.click('.obj-card:has-text("Obiectiv repetat")'); await p.waitForTimeout(300);
  const st = await p.locator('.stat-row .stat').allInnerTexts();
  const rep = C.filter((c) => c.denumire === 'Obiectiv repetat');
  const rn = rep.reduce((s, c) => s + nokOf(c).length, 0);
  eq(st.map((x) => x.replace(/\s+/g, ' ')).join(' | '), `2 controale | ${rn} ${rn === 1 ? 'neregulă constatată' : 'nereguli constatate'} | 0 amenzi aplicate | 0 amenzi active`, 'Obiectiv: statistici');
  }
  console.log(`ok=${okN} fail=${failN}`);
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
