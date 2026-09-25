const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 1180, height: 820 }]) {
    const p = await (await b.newContext({ viewport: vp, serviceWorkers: 'block' })).newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'PV test'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    // deschisă: cuvinte întregi, fără litere; restrânsă: și literele
    const bar = () => p.locator('.cat-stingatoare .cat-title').innerText();
    ok(!/PV/.test(await bar()), 'fără constatări: nimic despre PV');
    await p.click('#ner-d .nok-btn'); await p.click('#ner-e .nok-btn'); await p.click('#ner-al .ok-btn'); await p.waitForTimeout(300);
    ok(/2 netrecute în PV/.test(await bar()), `2 constatate, netrecute: ${(await bar()).replace(/\n/g, ' · ')}`);
    await p.click('#ner-d [data-path$=".inPV"]'); await p.waitForTimeout(250);
    ok(/1 netrecută în PV/.test(await bar()), 'd trecută → „1 netrecută în PV”');
    await p.click('#ner-e [data-path$=".inPV"]'); await p.waitForTimeout(250);
    ok(/toate în PV/.test(await bar()) && /Completat/.test(await bar()), '„toate în PV” + „Completat”');
    await p.click('#ner-e [data-path$=".inPV"]'); await p.waitForTimeout(250);
    await p.click('[data-act="cat-toggle"][data-cat="stingatoare"]'); await p.waitForTimeout(250);
    ok(await p.locator('.cat-stingatoare .ner-row').count() === 0 && /1 netrecută în PV: e/.test(await bar()), 'categorie restrânsă: informația rămâne pe bară');
    if (vp.width === 820) await p.locator('.cat-stingatoare').screenshot({ path: `${S}/pvbar.png` });
    ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
