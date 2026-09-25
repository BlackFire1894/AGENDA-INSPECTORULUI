const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const catsAll = async (p) => { if (!(await p.locator('[data-act="cats-all"]').count())) { await p.click('[data-act="tools-more"]'); await p.waitForTimeout(150); } await p.click('[data-act="cats-all"]'); };
const obsVal = async (p, sel) => ((await p.locator(sel).count()) ? p.locator(sel).inputValue() : '');
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) {
  console.log('--', vp.width);
  const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block' });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.clock.install({ time: new Date(2026, 8, 24, 10, 0) });
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
  await p.fill('#nc-name', 'SC Omega SRL'); await p.click('#nc-create'); await p.waitForTimeout(400);
  // ── Fișa: an construire, nr. ASI la DA, a doua construcție cu hidranți interiori
  ok(await p.locator('[data-bind$=".anConstruire"]').count() === 1, 'câmp „Anul construirii”');
  await p.fill('[data-bind$=".anConstruire"]', '1978'); await p.waitForTimeout(400);
  const asi = p.locator('.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("ASI"))');
  ok(await asi.locator('.dot-nr').count() === 0, 'nr. autorizație ascuns fără DA');
  await asi.locator('button:has-text("DA")').click(); await p.waitForTimeout(300);
  ok(await asi.locator('.dot-nr .lbl').innerText() === 'Nr. autorizație', 'ASI = DA → „Nr. autorizație”');
  await asi.locator('.dot-nr input').fill('2150 din 14.03.2018'); await p.waitForTimeout(500);
  const aviz = p.locator('.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("AVIZ"))');
  await aviz.locator('button:has-text("DA")').click(); await p.waitForTimeout(300);
  ok(await aviz.locator('.dot-nr .lbl').innerText() === 'Nr. aviz', 'AVIZ = DA → „Nr. aviz”');
  await p.click('[data-act="constr-inc"]'); await p.waitForTimeout(300);
  await p.fill('.constr >> nth=1 >> .constr-name', 'Depozit'); await p.waitForTimeout(400);
  await p.locator('.constr >> nth=1 >> .dot-row:has(.dot-label:text-is("Hidranți interiori")) button:has-text("DA")').click(); await p.waitForTimeout(250);
  await p.locator('.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("EXIT")) button:has-text("DA")').click(); await p.waitForTimeout(250);
  const ih = p.locator('.constr >> nth=1 >> .dot-row:has(.dot-label:text-is("Iluminat Hint"))');
  await ih.locator('button:has-text("NU")').click(); await p.waitForTimeout(300);
  ok(/Neregulă trecută automat \(am\)/.test(await p.locator('#toast').innerText()), 'NU la Iluminat Hint → „Neregulă trecută automat (am)”');
  // ── Nereguli
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
  ok(await p.locator('#ner-b').count() === 0 && await p.locator('#ner-c').count() === 0, 'b și c vechi nu mai apar');
  ok(['b1', 'b2', 'b3', 'c2', 'al', 'aj', 'am'].every(Boolean) && await p.locator('#ner-b1, #ner-b2, #ner-b3, #ner-c2, #ner-al, #ner-aj, #ner-am').count() === 7, 'b1, b2, b3, c2 (Hint), al, aj (EXIT), am (Lipsă iluminat Hint)');
  ok(await p.locator('#ner-c1').count() === 0 && await p.locator('#ner-ak').count() === 0, 'c1 (IDSAI) și ak (Hint incomplet) nu apar fără DA');
  ok((await p.locator('#ner-am').getAttribute('class')).includes('is-nok') && /Din fișa obiectivului: NU la Iluminat Hint/.test(await p.locator('#ner-am').innerText()), 'am constatată, din fișă');
  // verificări: date pe construcție
  ok(await p.locator('#ner-b1 .vf-row').count() === 2 && await p.locator('#ner-c2 .vf-row').count() === 1, 'b1: 2 construcții; c2: doar Depozit (cu hidranți interiori)');
  ok(/Depozit/.test(await p.locator('#ner-c2 .vf-row').innerText()), 'c2 → Depozit');
  await p.locator('#ner-b1 .vf-row >> nth=0 >> input[type=date]').fill('2025-06-10'); await p.dispatchEvent('#ner-b1 .vf-row >> nth=0 >> input[type=date]', 'change'); await p.waitForTimeout(300);
  await p.locator('#ner-b1 .vf-row >> nth=1 >> input[type=date]').fill('2026-02-01'); await p.dispatchEvent('#ner-b1 .vf-row >> nth=1 >> input[type=date]', 'change'); await p.waitForTimeout(300);
  ok(/expirată — era valabilă până la 10\.06\.2026/.test(await p.locator('#ner-b1 .vf-row >> nth=0').innerText()) && /valabilă până la 01\.02\.2027/.test(await p.locator('#ner-b1 .vf-row >> nth=1').innerText()), 'b1: 10.06.2025 + 12 luni → expirată; 01.02.2026 → valabilă');
  ok(/Verificare expirată: Construcția 1/.test(await p.locator('#ner-b1 .vf-propune').innerText()), 'propune „Constatat” pentru Construcția 1');
  await p.click('[data-act="todo-toggle"]'); await p.waitForTimeout(300);
  ok(/Verificare expirată \(b1, instalații electrice\): Construcția 1/.test(await p.locator('.todo-list').innerText()), 'apare în „Ce mai ai de făcut”: „Verificare expirată (b1, instalații electrice): Construcția 1”');
  await p.click('[data-act="todo-toggle"]'); await p.waitForTimeout(200);
  // b2: 12 / 24 luni
  await p.locator('#ner-b2 .vf-row >> nth=0 >> input[type=date]').fill('2025-03-01'); await p.dispatchEvent('#ner-b2 .vf-row >> nth=0 >> input[type=date]', 'change'); await p.waitForTimeout(300);
  ok(/expirată/.test(await p.locator('#ner-b2 .vf-row >> nth=0').innerText()) && (await p.locator('#ner-b2 .vf-row >> nth=0 >> .vf-luni button.on').innerText()) === '12 luni', 'b2: implicit 12 luni → expirată');
  await p.click('#ner-b2 .vf-row >> nth=0 >> .vf-luni button:has-text("24 luni")'); await p.waitForTimeout(300);
  ok(/valabilă până la 01\.03\.2027/.test(await p.locator('#ner-b2 .vf-row >> nth=0').innerText()), 'b2: 24 luni → valabilă până la 01.03.2027');
  // propunere → constatat pentru construcția expirată
  await p.click('#ner-b1 [data-act="verif-nok"]'); await p.waitForTimeout(300);
  ok((await p.locator('#ner-b1').getAttribute('class')).includes('is-nok') && /Construcția\s+Construcția 1/.test(await p.locator('#ner-b1 .constr-sel-btn').innerText()), '„Constatat pentru aceasta” → b1 constatat, Construcția 1');
  await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
  const pv = await p.locator('.pv-text').inputValue();
  ok(/verificare instalații electrice – construcția: Construcția 1\. Construcția 1: ultima verificare 10\.06\.2025, expirată \(era valabilă până la 10\.06\.2026\)/.test(pv), 'Text PV: data și expirarea');
  ok(/Lipsă iluminat Hint – construcția: Depozit/.test(pv), 'Text PV: am, cu construcția');
  await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {}); await p.waitForTimeout(200);
  // meniul de construcții: doar cele cu instalația
  ok(await p.locator('#ner-o .constr-sel-btn').isDisabled() && /Depozit/.test(await p.locator('#ner-o .constr-sel-btn').innerText()), 'o (Hint nefuncțional): doar Depozit → meniu inactiv, Depozit');
  // ── NEC
  ok(await p.locator('#ner-d .nec-btn').count() === 1 && await p.locator('#ner-b3 .nec-btn').count() === 1, 'NEC la nereguli și verificări');
  await p.click('#ner-b3 .nec-btn'); await p.waitForTimeout(300);
  ok((await p.locator('#ner-b3').getAttribute('class')).includes('is-nec') && await p.locator('#ner-b3 .verif-block').count() === 0, 'b3 NEC: rând tăiat, fără date de verificare');
  // ── Anulează / Refă
  const undoBtn = p.locator('[data-act="undo"]:visible'); const redoBtn = p.locator('[data-act="redo"]:visible');
  ok(!(await undoBtn.isDisabled()) && await redoBtn.isDisabled(), 'Anulează activ, Refă inactiv');
  await undoBtn.click(); await p.waitForTimeout(300);
  ok(!(await p.locator('#ner-b3').getAttribute('class')).includes('is-nec') && !(await redoBtn.isDisabled()), 'Anulează → b3 revine (fără NEC); Refă activ');
  await redoBtn.click(); await p.waitForTimeout(300);
  ok((await p.locator('#ner-b3').getAttribute('class')).includes('is-nec'), 'Refă → b3 din nou NEC');
  // text tastat + atingere = doi pași
  await p.click('#ner-d [data-act="obs-open"]'); await p.waitForTimeout(200);
  await p.locator('#ner-d textarea.row-obs').fill('lipsă 2 stingătoare'); await p.dispatchEvent('#ner-d textarea.row-obs', 'input'); await p.waitForTimeout(200);
  await p.click('#ner-d .nok-btn'); await p.waitForTimeout(300);
  await undoBtn.click(); await p.waitForTimeout(300);
  ok(!(await p.locator('#ner-d').getAttribute('class')).includes('is-nok') && await p.locator('#ner-d textarea.row-obs').inputValue() === 'lipsă 2 stingătoare', 'Anulează: întâi atingerea, textul rămâne');
  await undoBtn.click(); await p.waitForTimeout(300);
  ok(await obsVal(p, '#ner-d textarea.row-obs') === '', 'al doilea Anulează: și textul');
  await p.reload(); await p.waitForTimeout(500);
  ok(await obsVal(p, '#ner-d textarea.row-obs') === '' && await p.locator('#ner-d textarea.row-obs').count() === 0 && (await p.locator('#ner-b3').getAttribute('class')).includes('is-nec'), 'starea după Anulează e salvată (rezistă la reîncărcare)');
  // ── rânduri adăugate: secțiunea se restrânge
  await p.click('[data-act="ner-add"][data-sec="ner"]'); await p.keyboard.type('Ușă de evacuare blocată'); await p.waitForTimeout(400);
  await p.click('.custom-toggle'); await p.waitForTimeout(300);
  { const tt = await p.locator('.custom-toggle').innerText(); ok(await p.locator('.cat-custom').count() === 0 && /1 rând/.test(tt) && /Completat/.test(tt) && /1 constatată/.test(tt), `rânduri adăugate restrânse: ${tt.replace(/\n/g, ' · ')}`); }
  await p.reload(); await p.waitForTimeout(400);
  ok(await p.locator('.cat-custom').count() === 0, 'rămân restrânse după reîncărcare');
  await p.click('.custom-toggle'); await p.waitForTimeout(300);
  ok(await p.locator('.cat-custom .ner-row').count() === 1, 'se deschid din nou');
  // bara categoriei: completat / necompletat, și când e restrânsă
  await catsAll(p); await p.waitForTimeout(300);
  const stingT = await p.locator('.cat-stingatoare .cat-title').innerText();
  ok(/3 rânduri/.test(stingT) && /3 necompletate/.test(stingT), `Stingătoare restrânsă: ${stingT.replace(/\n/g, ' · ')}`);
  for (const k of ['d', 'e', 'al']) { await catsAll(p); await p.waitForTimeout(200); await p.click(`#ner-${k} .ok-btn`); await p.waitForTimeout(200); await catsAll(p); await p.waitForTimeout(200); }
  ok(/Completat/.test(await p.locator('.cat-stingatoare .cat-title').innerText()), 'după completare: „✓ Completat”');
  ok(/Completat/.test(await p.locator('.custom-toggle').innerText()), 'rânduri adăugate: „✓ Completat”');
  await catsAll(p); await p.waitForTimeout(200);
  if (vp.width === 820) { await p.locator('#ner-b1').scrollIntoViewIfNeeded(); await p.screenshot({ path: `${S}/v111-verif.png` }); }
  // ── fișa
  const id = await p.evaluate(() => location.hash.split('/')[2]);
  await p.goto(`http://localhost:8080/#/fisa/${id}`); await p.waitForTimeout(400);
  const f = await p.locator('.fisa-doc').textContent();
  ok(f.includes('1978') && f.includes('Nr. autorizație (ASI): 2150 din 14.03.2018'), 'fișa: anul construirii, nr. ASI');
  ok(/Ultima verificare:\s*Construcția 1: 10\.06\.2025 \(12 luni\) — expirată \(era valabilă până la 10\.06\.2026\); Depozit: 01\.02\.2026 \(12 luni\)/.test(f), 'fișa: datele verificărilor');
  ok(/NEC \(nu este cazul\)/.test(f), 'fișa: NEC');
  ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
