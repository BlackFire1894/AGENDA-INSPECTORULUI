const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const R = require('./reguli.json');
let okN = 0, failN = 0; const ok = (c, m) => { if (c) okN++; else { failN++; console.log('FAIL: ' + m); } };
(async () => {
  const b = await chromium.launch();
  const p = await (await b.newContext({ viewport: { width: 1180, height: 820 }, serviceWorkers: 'block' })).newPage();
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
  await p.fill('#nc-name', 'Reguli'); await p.click('#nc-create'); await p.waitForTimeout(400);
  const id = p.url().split('/')[5];
  const dot = (key, v) => p.locator(`.constr >> nth=0 >> .dot-row:has(.dot-label:text-is("${R.labels[key]}")) .seg-dnn button:text-is("${v}")`).click();
  const cur = { da: [], nu: [] };
  for (const s of R.scen) {
    await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
    for (const k of s.da.filter((k) => !cur.da.includes(k))) { await dot(k, 'DA'); await p.waitForTimeout(150); }
    for (const k of s.nu.filter((k) => !cur.nu.includes(k))) { await dot(k, 'NU'); await p.waitForTimeout(150); }
    if (s.grfV) { await p.fill('.constr >> nth=0 >> [data-bind$=".regimInaltime"]', 'P+1'); await p.locator('.constr >> nth=0 >> .grf-opts .chip-sel:text-is("V")').click(); await p.waitForTimeout(300); }
    cur.da = s.da; cur.nu = s.nu;
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(350);
    const keys = await p.locator('.ner-row[id^="ner-"]').evaluateAll((els) => els.map((e) => e.id.slice(4)));
    const sum = (await p.locator('.sum-line').innerText()).replace(/\s+/g, ' ');
    const tot = +(sum.match(/\d+\/(\d+) verificate/) || [])[1];
    const lipsa = s.keys.filter((k) => !keys.includes(k)); const extra = keys.filter((k) => !s.keys.includes(k));
    ok(!lipsa.length && !extra.length, `${s.nume}: rânduri lipsă [${lipsa}] / în plus [${extra}]`);
    ok(tot === s.n, `${s.nume}: total afișat ${tot}, așteptat ${s.n}`);
  }
  console.log(`ok=${okN} fail=${failN}`); console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
