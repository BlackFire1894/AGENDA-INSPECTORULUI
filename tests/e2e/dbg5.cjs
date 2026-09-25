const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => { const b = await chromium.launch();
for (const f of ['mare', 'mediu', 'mic']) for (const h of [820, 744]) {
  const p = await (await b.newContext({ viewport: { width: h === 744 ? 1133 : 1180, height: h }, serviceWorkers: 'block' })).newPage();
  await p.addInitScript((f) => localStorage.setItem('agenda-font', f), f);
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(400);
  await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(200);
  const id = (await p.locator('a[href*="#/control/"]').first().getAttribute('href')).split('/')[2];
  for (const r of ['#/panou', `#/control/${id}/nereguli`]) {
    await p.goto('http://localhost:8080/' + r); await p.waitForTimeout(300);
    const m = await p.evaluate(() => { const s = document.querySelector('.sidebar'); const set = document.querySelector('.side-settings'); const r = set.getBoundingClientRect(); return { sideScroll: s.scrollHeight, sideH: s.clientHeight, setBottom: Math.round(r.bottom), vh: innerHeight }; });
    console.log(f.padEnd(6), `${h}px`, r.startsWith('#/c') ? 'control' : 'panou  ', JSON.stringify(m), m.setBottom > m.vh ? 'SETĂRI ÎN AFARA ECRANULUI' : 'ok');
  }
}
await b.close(); })();
