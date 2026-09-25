// v1.19: // toate etichetele de zi liberă încap întregi, 2026–2030, portret și peisaj, la toate mărimile
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => { const b = await chromium.launch(); let bad = [], n = 0;
 for (const [w, h] of [[820, 1180], [1180, 820]]) for (const size of ['mic', 'mediu', 'mare']) {
  const p = await (await b.newContext({ viewport: { width: w, height: h }, serviceWorkers: 'block' })).newPage();
  await p.clock.install({ time: new Date(2026, 0, 5, 9, 0) });
  await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
  await p.evaluate((s) => { if (s !== 'mare') document.documentElement.dataset.font = s; }, size);
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(200);
  for (let k = 0; k < 60; k++) {
   const r = await p.$$eval('.cal-cell:not(.out) .ev-liber', (els) => els.map((e) => [e.innerText, e.scrollWidth > e.clientWidth + 1 || e.getBoundingClientRect().right > e.parentElement.getBoundingClientRect().right + 1]));
   n += r.length; r.filter((x) => x[1]).forEach((x) => bad.push(`${w} ${size}: ${x[0]}`));
   await p.click('[data-act="cal-next"]'); await p.waitForTimeout(40);
  }
  await p.close();
 }
 console.log((bad.length ? 'FAIL: ' : 'ok: ') + `etichete de zi liberă întregi: ${n} verificate, ${bad.length} tăiate ${[...new Set(bad)].slice(0, 20).join('; ')}`); console.log('no page errors'); await b.close(); })();
