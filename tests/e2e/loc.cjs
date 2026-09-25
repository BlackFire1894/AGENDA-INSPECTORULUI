const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch();
  const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push(e.message));
    p.on('dialog', (d) => d.accept());
    await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
    await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Valea Mare'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    const tabs = await p.locator('.ed-tab .tab-txt > b').allInnerTexts();
    ok(tabs.length === 5, `localitate are 5 taburi: ${tabs.join(' | ')}`);
    await p.screenshot({ path: `${S}/loc-${ori}-tabs.png` });
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    await p.screenshot({ path: `${S}/loc-${ori}-planuri.png`, fullPage: true });
    ok(await p.locator('.cat-title').count() === 2, 'planuri: 2 grupuri (Planuri, SVSU)');
    await p.click('.ed-tab >> nth=3'); await p.waitForTimeout(300);
    await p.screenshot({ path: `${S}/loc-${ori}-pc.png`, fullPage: true });
    ok(await p.locator('#ner-adapostPC .seg-adapost button.on').innerText() === 'NU', 'adăpost PC = NU');
    // adaugă rubrică nouă în PC
    await p.click('[data-act="ner-add"][data-sec="pc"]'); await p.keyboard.type('Rubrică test PC'); await p.waitForTimeout(500);
    await p.reload(); await p.waitForTimeout(400);
    ok(await p.locator('.cat-custom .row-label-input').inputValue() === 'Rubrică test PC', 'rubrica nouă PC salvată');
    await p.click('.ed-tab >> nth=4'); await p.waitForTimeout(300);
    await p.screenshot({ path: `${S}/loc-${ori}-nereguli.png`, fullPage: true });
    // Panou: amenda din SVSU și rubrica netrecută în PV din PC
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
    const pvLinks = await p.locator('#sec-pv a').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
    ok(pvLinks.some((h) => /\/pc\/pcSireneDefecte$/.test(h)), 'Panou → link spre tabul PC');
    await p.click('#sec-pv a[href$="/pc/pcSireneDefecte"]'); await p.waitForTimeout(600);
    ok(/\/pc\/pcSireneDefecte$/.test(p.url()) && await p.locator('.ed-tab.on .tab-txt > b').innerText() === 'Protecție civilă', 'deschide tabul PC la rubrică');
    const fineLinks = await p.evaluate(() => 0);
    // OPEC: 3 taburi, filtru instalații
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Grădinița'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    ok(await p.locator('.ed-tab').count() === 3, 'OPEC are 3 taburi');
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    const before = await p.locator('.ner-row').count();
    ok(before === 15, `control nou fără dotări: ${before} nereguli vizibile`);
    ok(await p.locator('[data-act="toggle-all-ner"]').count() === 1, 'mesaj „ascunse” + buton Arată toate');
    await p.click('[data-act="toggle-all-ner"]'); await p.waitForTimeout(200);
    ok(await p.locator('.ner-row').count() === 47, 'Arată toate → 47 (fără rândurile „Lipsă …”)');
    await p.click('[data-act="toggle-all-ner"]'); await p.waitForTimeout(200);
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await p.click('.constr >> nth=0 >> .dot-row:has-text("IDSAI") >> button:has-text("DA")'); await p.waitForTimeout(200);
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    const after = await p.locator('.ner-row').count();
    ok(after === 19, `IDSAI = DA → ${after} nereguli (c, i, l, m apar)`);
    // tip schimbat în Localitate → 5 taburi
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await p.click('[data-path="tip"][data-val="LOCALITATE"]'); await p.waitForTimeout(200);
    ok(await p.locator('.ed-tab').count() === 5, 'schimbare tip → 5 taburi');
    // rută invalidă (planuri la OPEC) → obiectiv
    await p.click('[data-path="tip"][data-val="OPEC"]'); await p.waitForTimeout(200);
    const id = p.url().split('/')[5];
    await p.goto(`http://localhost:8080/#/control/${id}/planuri`); await p.waitForTimeout(300);
    ok(/\/obiectiv$/.test(p.url()), 'tab Planuri la OPEC → redirecționat la Obiectiv');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
