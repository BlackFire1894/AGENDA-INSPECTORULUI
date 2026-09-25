const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const catsAll = async (p) => { if (!(await p.locator('[data-act="cats-all"]').count())) { await p.click('[data-act="tools-more"]'); await p.waitForTimeout(150); } await p.click('[data-act="cats-all"]'); };
(async () => {
  const b = await chromium.launch();
  const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
    await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    // 5. Panou arată seria amenzii
    ok((await p.locator('#sec-fines').innerText()).includes('Amenda Seria DB nr. 0012345'), 'Panou: seria și nr. amenzii');
    // 1. acte noi
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Spitalul'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    const id = p.url().split('/')[5];
    await p.goto(`http://localhost:8080/#/control/${id}/acte`); await p.waitForTimeout(300);
    const acte = await p.locator('.check-row .row-label').allInnerTexts();
    ok(acte.length === 14 && acte.includes('Exerciții efectuate') && acte.includes('Rapoarte exerciții'), `acte: ${acte.length} rânduri, cu exercițiile`);
    // 4. observații: câmpul gol nu apare — „+ Obs.” îl deschide; Enter = rând nou, lățime constantă, crește în jos
    const lipsaN = await p.locator('.act-row.is-nok').count();   // la Lipsă, câmpul e deschis din start
    ok(await p.locator('.act-row textarea.row-obs').count() === lipsaN && await p.locator('.act-row [data-act="obs-open"]').count() === 14 - lipsaN, `acte: câmp gol doar la Lipsă (${lipsaN}); restul „+ Obs.”`);
    await p.click('.act-row >> nth=0 >> [data-act="obs-open"]'); await p.waitForTimeout(250);
    ok(await p.evaluate(() => document.activeElement.tagName) === 'TEXTAREA', '„+ Obs.” deschide și focalizează câmpul');
    const ta = p.locator('.check-row >> nth=0 >> textarea.row-obs');
    const b0 = await ta.boundingBox();
    await p.keyboard.type('Rândul 1'); await p.keyboard.press('Enter'); await p.keyboard.type('Rândul 2'); await p.keyboard.press('Enter'); await p.keyboard.type('Rândul 3');
    await p.waitForTimeout(500);
    const b1 = await ta.boundingBox();
    ok(Math.abs(b1.width - b0.width) < 1 && b1.height > b0.height + 30, `obs crește în jos: ${Math.round(b0.width)}x${Math.round(b0.height)} → ${Math.round(b1.width)}x${Math.round(b1.height)}`);
    ok((await ta.inputValue()) === 'Rândul 1\nRândul 2\nRândul 3', 'obs păstrează rândurile noi');
    // text lung, fără Enter → se împachetează, lățimea rămâne
    await p.click('.act-row >> nth=1 >> [data-act="obs-open"]'); await p.waitForTimeout(250);
    const ta2 = p.locator('.check-row >> nth=1 >> textarea.row-obs');
    const w2 = (await ta2.boundingBox()).width;
    await ta2.fill('Text foarte lung '.repeat(20)); await ta2.dispatchEvent('input'); await p.waitForTimeout(200);
    const bb2 = await ta2.boundingBox();
    ok(Math.abs(bb2.width - w2) < 1 && bb2.height > 60, 'text lung: lățime fixă, crește în jos');
    // 3. deschis și lăsat gol → revine la „+ Obs.”
    await p.click('.act-row >> nth=2 >> [data-act="obs-open"]'); await p.waitForTimeout(250);
    ok(await p.locator('.act-row >> nth=2 >> textarea.row-obs').count() === 1, 'al treilea act: câmpul deschis');
    // la ieșirea din câmp nu se redesenează imediat (ca atingerea următoare să nu „sară”); se strânge la următoarea redesenare
    await p.click('.sum-line'); await p.waitForTimeout(200);
    await p.click('[data-act="ner-filter"][data-val="ALL"]'); await p.waitForTimeout(300);
    ok(await p.locator('.act-row >> nth=2 >> textarea.row-obs').count() === 0 && await p.locator('.act-row >> nth=2 >> [data-act="obs-open"]').count() === 1, 'lăsat gol, câmpul se strânge la loc în „+ Obs.”');
    ok(await p.locator('.act-row textarea.row-obs').count() === 2 + lipsaN, `rămân vizibile doar observațiile scrise (2) și cele de la Lipsă (${lipsaN})`);
    // persistă după reload
    await p.reload(); await p.waitForTimeout(400);
    ok((await p.locator('.check-row >> nth=0 >> textarea.row-obs').inputValue()).includes('Rândul 3'), 'obs pe mai multe rânduri salvate');
    ok((await p.locator('.check-row >> nth=0 >> textarea.row-obs').boundingBox()).height > 70, 'după reload, câmpul are înălțimea conținutului');
    // 2. construcția neregulii
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
    const sel = p.locator('#ner-q .constr-sel-btn');
    ok(await sel.count() === 1 && await sel.isDisabled() && (await sel.innerText()).includes('Pavilion central'), 'q (Hext): doar Pavilion central are hidranți exteriori → fără alte opțiuni');
    const sel2 = p.locator('#ner-o .constr-sel-btn');
    ok((await sel2.innerText()).includes('Pavilion central'), 'o (Hint): implicit prima construcție cu hidranți interiori');
    await sel2.click(); await p.waitForTimeout(200);
    const opts = await p.locator('#ner-o .constr-opt').allInnerTexts();
    ok(opts.length === 2, `opțiuni = construcțiile cu Hint: ${opts.join(' | ')}`);
    await p.click('#ner-o .constr-opt >> nth=1'); await p.click('#ner-o .constr-opt >> nth=0'); await p.waitForTimeout(800);
    await p.reload(); await p.waitForTimeout(400);
    ok(/Construcția\s+Ambulatoriu/.test(await p.locator('#ner-o .constr-sel-btn').innerText()), 'construcția aleasă se salvează');
    // 5. seria și nr. în amendă
    ok(await p.locator('#ner-q [data-bind$=".amenda.serieNr"]').inputValue() === 'DB 0012377', 'un singur câmp „Seria și nr.”: DB 0012377');
    await p.fill('#ner-q [data-bind$=".amenda.serieNr"]', 'DB 0099999'); await p.waitForTimeout(500);
    await p.reload(); await p.waitForTimeout(400);
    ok(await p.locator('#ner-q [data-bind$=".amenda.serieNr"]').inputValue() === 'DB 0099999' && /Seria DB nr\. 0099999/.test(await p.locator('#ner-q .fine-status').innerText()), 'seria și nr. salvate, afișate „Seria DB nr. 0099999”');
    ok((await p.locator('#ner-q .fine-status b').innerText()).includes('Seria DB nr. 0099999'), 'seria/nr. afișate în caseta amenzii');
    // 3. categorii pliabile
    const cats = await p.locator('.cat-title').count();
    await p.click('.cat-title >> nth=0'); await p.waitForTimeout(200);
    ok(await p.locator('.cat-group.closed').count() === 1, 'o categorie restrânsă');
    await catsAll(p); await p.waitForTimeout(200);
    ok(await p.locator('.cat-group.closed').count() === cats && await p.locator('.ner-row').count() === 0, `toate restrânse (${cats}); rămâne doar rândul suplimentar`);
    await p.screenshot({ path: `${S}/v14-${ori}-cats-closed.png` });
    await p.reload(); await p.waitForTimeout(300);
    ok(await p.locator('.cat-group.closed').count() === cats, 'starea categoriilor se păstrează');
    // link din Panou spre o neregulă dintr-o categorie restrânsă → se deschide
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
    await p.click(`#sec-fines a[href$="/${id}/nereguli/q"]`); await p.waitForTimeout(600);
    ok(await p.locator('#ner-q').isVisible(), 'link din Panou deschide categoria restrânsă');
    await catsAll(p); await p.waitForTimeout(200);
    if (await p.locator('.cat-group.closed').count()) { await catsAll(p); await p.waitForTimeout(200); }
    ok(await p.locator('.cat-group.closed').count() === 0, 'Extinde categoriile');
    await p.screenshot({ path: `${S}/v14-${ori}-nereguli.png`, fullPage: true });
    // 6. calendar: an
    await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
    const y0 = await p.locator('.page-head h1').innerText();
    await p.click('[data-act="cal-year-next"]'); await p.waitForTimeout(200);
    const y1 = await p.locator('.page-head h1').innerText();
    await p.click('[data-act="cal-year-prev"]'); await p.click('[data-act="cal-year-prev"]'); await p.waitForTimeout(200);
    const y2 = await p.locator('.page-head h1').innerText();
    ok(/2026/.test(y0) && /2027/.test(y1) && /2025/.test(y2), `an: ${y0} → ${y1} → ${y2}`);
    await p.click('[data-act="cal-today"]'); await p.waitForTimeout(200);
    await p.screenshot({ path: `${S}/v14-${ori}-cal.png`, clip: { x: 0, y: 0, width: vp.width, height: 360 } });
    // obiectiv: dotări cu textarea
    await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
    ok(await p.locator('textarea.dot-obs').count() + await p.locator('.dot-row [data-act="obs-open"]').count() > 10 && await p.locator('.dot-row textarea').evaluateAll((t) => t.every((x) => x.value.trim())), 'dotări: observații (câmp doar unde e text, altfel „+ Obs.”)');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
