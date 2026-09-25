const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => { const b = await chromium.launch(); const errs = [];
  const p = await (await b.newContext({ viewport: { width: 820, height: 1180 }, serviceWorkers: 'block' })).newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.clock.install({ time: new Date(2026, 11, 2, 9, 0) });   // 2 decembrie 2026
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
  await p.addStyleTag({ content: '#toast{display:none!important}' });
  ok(await p.locator('.hol-rem').count() === 1 && /2027/.test(await p.locator('.hol-rem h2').innerText()), 'decembrie: Panoul cere verificarea listei pentru 2027');
  await p.click('.hol-rem summary'); await p.waitForTimeout(200);
  const lista = await p.locator('.hol-rem .hol-list li').allInnerTexts();
  ok(lista.length === 17 && lista.some((x) => /6 ianuarie 2027.*Boboteaza/.test(x)) && lista.some((x) => /30 aprilie 2027.*Vinerea Mare/.test(x)), `lista 2027: ${lista.length} zile`);
  await p.screenshot({ path: `${process.argv[2] || '.'}/hol-rem.png` });
  await p.click('.hol-rem [data-act="sarbatori-ok"]'); await p.waitForTimeout(400);
  ok(await p.locator('.hol-rem').count() === 0, 'după „Am verificat”, reminderul dispare');
  await p.reload(); await p.waitForTimeout(500);
  ok(await p.locator('.hol-rem').count() === 0, 'confirmarea rezistă la reîncărcare');
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
  ok(/2027 — 17 zile · verificată/.test(await p.locator('#sarbatori').innerText()), 'Setări: 2027 verificată');
  await p.clock.setSystemTime(new Date(2026, 9, 3, 9, 0)); await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(400);
  ok(await p.locator('.hol-rem').count() === 0, 'octombrie: fără reminder');
  // recomandarea zilei lucrătoare: amendă cu termenul de plată sâmbătă
  const t = await p.locator('#sec-fines').innerText();
  ok(!/verifici/.test(t), 'fără ton informal');
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close(); })();
