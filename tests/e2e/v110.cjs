const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) {
    const p = await (await b.newContext({ viewport: vp, serviceWorkers: 'block' })).newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Hotel Gama'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    const docs = await p.locator('.cat-docs').innerText();
    ok(/ah\s*Construcția funcționează fără ASI/.test(docs) && /ai\s*Lucrări de extindere \/ modificare/.test(docs), 'ah, ai în „Documentație și verificări”');
    await p.fill('#ner-search', 'fara asi'); await p.dispatchEvent('#ner-search', 'input'); await p.waitForTimeout(200);
    ok(await p.locator('#ner-results .ner-row').count() === 1 && await p.locator('#ner-ah').count() === 1, 'căutare „fara asi” → ah');
    await p.fill('#ner-search', 'ai'); await p.dispatchEvent('#ner-search', 'input'); await p.waitForTimeout(200);
    ok(await p.locator('#ner-results .ner-row').count() === 1 && await p.locator('#ner-ai').count() === 1, 'literă „ai” → ai');
    await p.click('[data-act="ner-q-clear"]'); await p.waitForTimeout(200);
    await p.click('#ner-ah .nok-btn'); await p.click('#ner-ai .nok-btn'); await p.waitForTimeout(300);
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
    const pv = await p.locator('.pv-text').inputValue();
    ok(/Construcția funcționează fără ASI/.test(pv) && /Lucrări de extindere \/ modificare a clădirii sau a instalațiilor realizate fără aviz/.test(pv), 'Text PV: ambele');
    await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {});
    // NU la ASI (construcția 2, cu observații) → ah constatată automat
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await p.click('[data-act="constr-inc"]'); await p.waitForTimeout(300);
    await p.fill('.constr >> nth=1 >> .constr-name', 'Anexă'); await p.waitForTimeout(400);
    const asiRow = p.locator('.constr >> nth=1 >> .dot-row:has(.dot-label:text-is("ASI"))');
    await asiRow.locator('button:has-text("NU")').click(); await p.waitForTimeout(300);
    ok(/Neregula ah actualizată din fișă/.test(await p.locator("#toast").innerText()), "NU la ASI, ah deja constatată manual → mesaj „actualizată din fișă”");
    await asiRow.locator('[data-act="obs-open"]').click(); await p.waitForTimeout(200);
    await asiRow.locator('textarea').fill('Documentație depusă, ASI neemisă'); await p.waitForTimeout(500);
    const avizRow = p.locator('.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("AVIZ"))');
    await avizRow.locator('button:has-text("NU")').click(); await p.waitForTimeout(300);
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    const ah = await p.locator('#ner-ah').innerText();
    ok(/Din fișa obiectivului: NU la ASI/.test(ah) && /Anexă/.test(ah) && await p.locator('#ner-ah textarea.obs').inputValue() === 'Anexă: Documentație depusă, ASI neemisă', 'ah: constatată, construcția Anexă, observațiile din fișă');
    ok(/NU la AVIZ/.test(await p.locator('#ner-ai').innerText()) && (await p.locator('#ner-ai').getAttribute('class')).includes('is-nok'), 'ai: constatată din NU la AVIZ');
    const first = await p.locator('#ner-results .ner-row .row-idx').allInnerTexts();
    ok(first[0] === 'ah' && first[1] === 'ai', `primele rânduri: ${first.slice(0, 3).join(', ')}`);
    // retragere: DA la AVIZ → ai dispare (nelucrată)
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await avizRow.locator('button:has-text("DA")').click(); await p.waitForTimeout(300);
    ok(/retrasă/.test(await p.locator('#toast').innerText()), 'DA la AVIZ → ai retrasă');
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    ok(!(await p.locator('#ner-ai').getAttribute('class')).includes('is-nok'), 'ai: necompletată din nou');
    await p.goto('http://localhost:8080/'); await p.locator('[data-act="new-control"]:visible').first().click(); await p.waitForTimeout(300);
    await p.fill('#nc-name', 'Magazin Delta'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.locator('.dot-row:has(.dot-label:text-is("ASI")) button:has-text("NU")').first().click(); await p.waitForTimeout(300);
    ok(/Neregulă trecută automat \(ah\)/.test(await p.locator('#toast').innerText()), 'control nou: NU la ASI → „Neregulă trecută automat (ah)”');
    await p.click('.toast-btn'); await p.waitForTimeout(800);
    ok(/\/nereguli\/ah$/.test(p.url()) && (await p.locator('#ner-ah').getAttribute('class')).includes('is-nok'), 'Vezi → ah constatată');
    if (vp.width === 820) { await p.locator('#ner-ah').scrollIntoViewIfNeeded(); await p.screenshot({ path: `${S}/v110.png` }); }
    ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
