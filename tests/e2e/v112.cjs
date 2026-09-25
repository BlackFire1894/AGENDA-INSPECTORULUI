const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const inView = (p, sel) => p.locator(sel).evaluate((e) => { const r = e.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; });
// backup cu un control încheiat în v1.10 (schema 8) și unul deschis din v1.10
const ctl = (id, incheiat) => ({ id, objectiveId: `o-${id}`, schema: 8, tip: 'OPEC', denumire: `Vechi ${id}`, dataInceput: '2026-09-23', dataIncheiere: incheiat ? '2026-09-23' : '',
  constructii: [{ id: `k-${id}`, denumire: 'Corp', dotari: { hidInt: { v: 'DA', obs: '' } } }],
  nereguli: [{ key: 'b', status: 'ok', obs: 'PRAM 2025' }, { key: 'd', status: 'nok', inPV: true, amenda: { aplicata: true, serie: 'DB', numar: '0000777', suma: '1000' } }], acte: {} });
fs.writeFileSync(`${S}/v10.json`, JSON.stringify({ app: 'agenda-inspectorului', schema: 8, controls: [ctl('inch', true), ctl('desc', false)] }));
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 1180, height: 820 }]) {
  const port = vp.width < 1000;
  console.log('--', vp.width);
  const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block' });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
  await p.fill('#nc-name', 'SC Test SRL'); await p.click('#nc-create'); await p.waitForTimeout(400);
  // ── Anulează / Sus / Refă: la îndemână, în zona potrivită
  const strip = p.locator('#edit-strip'); const side = p.locator('#side-edit');
  ok(port ? await strip.isVisible() && !(await side.isVisible()) : await side.isVisible() && !(await strip.isVisible()), port ? 'vertical: banda de deasupra barei de jos' : 'orizontal: în bara laterală');
  ok(await p.locator('.ed-head [data-act="undo"], #ed-head [data-act="undo"]').count() === 0, 'nu mai sunt în antet');
  const U = p.locator('[data-act="undo"]:visible'); const R = p.locator('[data-act="redo"]:visible'); const SUS = p.locator('[data-act="scroll-top"]:visible');
  if (port) {
    const sb = await strip.boundingBox(); const tb = await p.locator('.tabbar').boundingBox();
    ok(Math.abs(sb.y + sb.height - tb.y) < 2, 'banda stă lipită deasupra barei de jos');
  }
  // ── Nereguli: rânduri, bare, auto-restrângere
  await p.locator('.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("Hidranți interiori")) button:has-text("DA")').click(); await p.waitForTimeout(250);
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
  await p.click('#ner-e .ok-btn'); await p.waitForTimeout(250);
  ok((await p.locator('#ner-e').getAttribute('class')).includes('is-collapsed') && /Conform/.test(await p.locator('#ner-e .ner-bar').innerText()), '✓ Conform → rândul se strânge, bara arată „Conform”');
  await p.click('#ner-al .nec-btn'); await p.waitForTimeout(250);
  ok((await p.locator('#ner-al').getAttribute('class')).includes('is-collapsed') && /NEC/.test(await p.locator('#ner-al .ner-bar').innerText()), 'NEC → rândul se strânge');
  await p.click('#ner-d .nok-btn'); await p.waitForTimeout(250);
  ok(!(await p.locator('#ner-d').getAttribute('class')).includes('is-collapsed'), 'Constatat → rămâne deschis');
  await p.click('#ner-d [data-path$=".amenda.aplicata"]'); await p.waitForTimeout(200);
  ok(await p.locator('#ner-d [data-bind$=".amenda.serieNr"]').count() === 1 && await p.locator('#ner-d [data-bind$=".amenda.serie"], #ner-d [data-bind$=".amenda.numar"]').count() === 0, 'amendă: un singur câmp „Seria și nr.”');
  await p.fill('#ner-d [data-bind$=".amenda.serieNr"]', 'DB 0012345'); await p.fill('#ner-d [data-bind$=".amenda.suma"]', '2500'); await p.waitForTimeout(500);
  await p.click('#ner-d .row-tgl'); await p.waitForTimeout(250);
  const dBar = await p.locator('#ner-d .ner-bar').innerText();
  ok(/Constatat/.test(dBar) && /Netrecut în PV/.test(dBar) && /Amendă/.test(dBar), `d strâns: bara arată ${dBar.replace(/\n/g, ' · ')}`);
  await p.click('#ner-d .bar-main'); await p.waitForTimeout(250);
  ok(!(await p.locator('#ner-d').getAttribute('class')).includes('is-collapsed'), 'atingerea pe titlu redeschide rândul');
  // deschisă: cuvinte întregi, fără litere; restrânsă: și literele rândurilor
  const stT = (await p.locator('.cat-stingatoare .cat-title').innerText()).replace(/\n/g, ' · ');
  ok(/Completat/.test(stT) && /1 constatată/.test(stT) && /1 netrecută în PV/.test(stT) && /1 amendată/.test(stT) && !/: d/.test(stT), `bara categoriei deschise, în cuvinte: ${stT}`);
  const docT = (await p.locator('.cat-docs .cat-title').innerText()).replace(/\n/g, ' · ');
  ok(/\d+ necompletate/.test(docT) && !/necompl\./.test(docT), `bara categoriei deschise: „N necompletate”: ${docT}`);
  await p.click('.cat-stingatoare .cat-title'); await p.click('.cat-docs .cat-title'); await p.waitForTimeout(250);
  const stC = await p.locator('.cat-stingatoare .cat-title').innerText();
  ok(/Completat/.test(stC) && /1 constatată/.test(stC) && /1 amendată: d/.test(stC), `bara categoriei restrânse: ${stC.replace(/\n/g, ' · ')}`);
  const docC = await p.locator('.cat-docs .cat-title').innerText();
  ok(/necompletate: ah, ai, a, b1, b2, b3/.test(docC), `bara categoriei restrânse arată care sunt necompletate: ${docC.replace(/\n/g, ' · ')}`);
  await p.click('.cat-stingatoare .cat-title'); await p.click('.cat-docs .cat-title'); await p.waitForTimeout(250);
  // Restrânge completate
  await p.click('#ner-f .ok-btn'); await p.waitForTimeout(200);
  await p.click('#ner-f .row-tgl'); await p.waitForTimeout(200);
  ok(await p.locator('[data-act="rows-collapse"]').count() === 0, 'opțiunile de afișare stau în meniul ⋯ (închis implicit)');
  await p.click('[data-act="tools-more"]'); await p.waitForTimeout(200);
  ok(/Restrânge completate \(2\)/.test(await p.locator('[data-act="rows-collapse"]').innerText()), '„Restrânge completate (2)”');
  await p.click('[data-act="rows-collapse"]'); await p.waitForTimeout(250);
  ok((await p.locator('#ner-d').getAttribute('class')).includes('is-collapsed') && (await p.locator('#ner-f').getAttribute('class')).includes('is-collapsed'), 'rândurile completate se strâng toate');
  await p.click('[data-act="rows-expand"]'); await p.waitForTimeout(250);
  ok(await p.locator('.ner-row.is-collapsed').count() === 0, '„Deschide rândurile”');
  // glosar
  await p.fill('#ner-search', 'hidranti interiori'); await p.dispatchEvent('#ner-search', 'input'); await p.waitForTimeout(250);
  const g = await p.locator('#ner-results .ner-row .row-idx').allInnerTexts();
  ok(['c2', 'n', 'o'].every((k) => g.includes(k)), `„hidranti interiori” → ${g.join(', ')}`);
  await p.click('[data-act="ner-q-clear"]'); await p.waitForTimeout(200);
  // bare fixe la derulare
  await p.locator('#ner-b2').scrollIntoViewIfNeeded(); await p.evaluate(() => window.scrollBy(0, 220)); await p.waitForTimeout(300);
  const tabsH = await p.locator('.ed-tabs').evaluate((e) => e.getBoundingClientRect().bottom);
  const catTop = await p.locator('.cat-docs .cat-title').evaluate((e) => e.getBoundingClientRect().top);
  ok(Math.abs(catTop - tabsH) < 3, `bara categoriei rămâne sub taburi (${Math.round(catTop)} ≈ ${Math.round(tabsH)})`);
  const catBottom = await p.locator('.cat-docs .cat-title').evaluate((e) => e.getBoundingClientRect().bottom);
  // un rând care trece pe sub bara categoriei (începe deasupra ei și se termină mult sub ea) își ține bara lipită dedesubt
  const stuck = await p.evaluate(async () => {
    for (let i = 0; i < 60; i++) {
      const y = document.querySelector('.cat-docs .cat-title').getBoundingClientRect().bottom;   // la fiecare pas: bara categoriei se lipește sus abia după o derulare
      const row = [...document.querySelectorAll('.cat-docs .ner-row')].find((r) => { const b = r.getBoundingClientRect(); const h = r.querySelector('.ner-bar').offsetHeight; const pad = parseFloat(getComputedStyle(r).paddingTop); return b.top + pad < y - 5 && b.bottom > y + h + 20; });
      if (row) { const t = row.querySelector('.ner-bar').getBoundingClientRect().top; if (Math.abs(t - y) >= 3) console.log('DBG', row.id, t, y); const bar = row.querySelector('.ner-bar'); const g = row.closest('.cat-group'); const ti = g.querySelector(':scope > .cat-title'); return Math.abs(t - y) < 3 || `${row.id}: bara la ${Math.round(t)}, categoria se termină la ${Math.round(y)} [top css ${getComputedStyle(bar).top}, --cat-h ${g.style.getPropertyValue('--cat-h')}, titlu ${ti.offsetHeight}/${ti.getBoundingClientRect().height}, --st-cat ${document.documentElement.style.getPropertyValue('--st-cat')}, mt ${getComputedStyle(bar).marginTop}, rowpad ${getComputedStyle(row).paddingTop}]`; }
      window.scrollBy(0, 15); await new Promise((r) => requestAnimationFrame(r));
    }
    return 'niciun rând găsit';
  });
  ok(stuck === true, `bara neregulii curente rămâne sub bara categoriei ${stuck === true ? '' : stuck}`);
  // Sus
  await SUS.click(); await p.waitForTimeout(900);
  ok(await p.evaluate(() => window.scrollY) < 5, '„Sus” duce la începutul paginii');
  // ── Anulează: merge la locul schimbat (alt tab), îl deschide și îl evidențiază
  await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(300);
  await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight)); await p.waitForTimeout(200);
  await U.click(); await p.waitForTimeout(700);
  ok(/\/nereguli\/f$/.test(p.url()) && /Anulat: f\./.test(await p.locator('#toast').innerText()), 'Anulează din tabul Obiectiv → tabul Nereguli, rândul f');
  ok(await inView(p, '#ner-f') && (await p.locator('#ner-f').getAttribute('class')).includes('flash-undo'), 'rândul f e în vizor și evidențiat');
  ok(!(await p.locator('#ner-f').getAttribute('class')).includes('is-ok'), 'f nu mai e Conform');
  await R.click(); await p.waitForTimeout(700);
  ok((await p.locator('#ner-f').getAttribute('class')).includes('is-ok') && /Refăcut: f\./.test(await p.locator('#toast').innerText()), 'Refă → f din nou Conform');
  // o modificare în fișă, anulată din tabul Nereguli → tabul Obiectiv, construcția
  await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(250);
  await p.fill('[data-bind$=".anConstruire"]', '1990'); await p.waitForTimeout(400);
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(250);
  await U.click(); await p.waitForTimeout(700);
  ok(/\/obiectiv\/constr-/.test(p.url()) && await p.inputValue('[data-bind$=".anConstruire"]') === '' && await inView(p, '.constr >> nth=0'), 'Anulează text din fișă → tabul Obiectiv, construcția în vizor');
  // ── Acte: același comportament
  await p.click('.ed-tab >> nth=1'); await p.waitForTimeout(300);
  ok(await p.locator('#act-lfd .nec-btn').count() === 1, 'acte: NEC');
  await p.click('#act-ctpsi .ok-btn'); await p.waitForTimeout(250);
  ok((await p.locator('#act-ctpsi').getAttribute('class')).includes('is-collapsed') && /Prezentat/.test(await p.locator('#act-ctpsi .ner-bar').innerText()), 'acte: ✓ → se strânge, bara „Prezentat”');
  await p.click('#act-lfd .nok-btn'); await p.waitForTimeout(250);
  const aT = await p.locator('.cat-acte .cat-title').innerText();
  ok(/12 necompl\./.test(aT) && /1 lipsă/.test(aT), `bara actelor deschise (prescurtat): ${aT.replace(/\n/g, ' · ')}`);
  await p.fill('#ner-search', 'foc deschis'); await p.dispatchEvent('#ner-search', 'input'); await p.waitForTimeout(250);
  ok(await p.locator('#ner-results .act-row').count() === 1 && await p.locator('#act-lfd').count() === 1, 'acte: căutare „foc deschis” → LFD');
  await p.click('[data-act="ner-q-clear"]'); await p.waitForTimeout(200);
  await p.click('[data-act="cat-toggle"][data-cat="acte"]'); await p.waitForTimeout(200);
  ok(await p.locator('.act-row').count() === 0 && /lipsă: 2/.test(await p.locator('.cat-acte .cat-title').innerText()), 'acte: lista se strânge, bara păstrează informațiile');
  await p.click('[data-act="cat-toggle"][data-cat="acte"]'); await p.waitForTimeout(200);
  // PV: seria și nr.
  await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
  ok(/sancționat cu amendă Seria DB nr\. 0012345/.test(await p.locator('.pv-text').inputValue()), 'Text PV: „Seria DB nr. 0012345”');
  await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {});
  // bandă doar în control
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
  ok(!(await strip.isVisible()) && !(await side.isVisible()), 'în afara controlului: fără Anulează / Refă');
  // ── controale din v1.10: cel încheiat rămâne cum era, cel deschis primește lista nouă
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
  await p.setInputFiles('[data-import]', `${S}/v10.json`); await p.waitForTimeout(200); await p.click('[data-mode="merge"]'); await p.waitForTimeout(400);
  await p.goto('http://localhost:8080/#/control/inch/nereguli'); await p.waitForTimeout(400);
  ok(await p.locator('#ner-b').count() === 1 && await p.locator('#ner-c').count() === 1 && await p.locator('#ner-b1, #ner-c2, #ner-aj, #ner-al').count() === 0, 'încheiat în v1.10: b și c, fără b1–c7 / aj–am');
  ok(/Seria DB nr\. 0000777/.test(await p.locator('#ner-d').innerText()), 'amenda veche (serie + nr.) apare corect');
  await p.goto('http://localhost:8080/#/control/desc/nereguli'); await p.waitForTimeout(400);
  ok(await p.locator('#ner-b').count() === 1 && await p.locator('#ner-b1').count() === 1 && await p.locator('#ner-c').count() === 0, 'deschis: lista nouă (b1…), b rămâne fiindcă e completat');
  ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  if (port) { await p.goto('http://localhost:8080/#/control/desc/nereguli'); await p.waitForTimeout(300); await p.screenshot({ path: `${S}/v112-port.png` }); }
  await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
