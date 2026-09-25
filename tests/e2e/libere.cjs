// v1.19: zilele libere implicite (weekend, sărbători legale) în calendar și în raportul lunii
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [vw, vh, tema] of [[820, 1180, 'light'], [1180, 820, 'dark']]) {
    const ctx = await b.newContext({ viewport: { width: vw, height: vh }, serviceWorkers: 'block', colorScheme: tema });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });          // joi, 15.10.2026
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
    const cell = (d) => p.locator(`.cal-cell[data-date="${d}"]`);
    ok(await cell('2026-10-10').evaluate((e) => e.classList.contains('is-liber')) && /✓ Liber/.test(await cell('2026-10-10').innerText()), `${vw}: sâmbătă trecută → „✓ Liber”`);
    ok(!(await cell("2026-10-15").evaluate((e) => e.classList.contains("is-liber"))) && !/Liber/.test(await cell("2026-10-15").innerText()), `${vw}: azi, joi → zi lucrătoare`);
    const viit = await cell('2026-10-18').innerText();
    ok(/Liber/.test(viit) && !/✓/.test(viit.split('\n').find((l) => /Liber/.test(l))), `${vw}: duminică viitoare → planificată, fără ✓`);
    ok(await p.locator('.cal-grid .cal-cell.is-liber:not(.out)').count() === 9, `${vw}: octombrie 2026 are 9 zile libere`);
    await cell('2026-10-18').click(); await p.waitForTimeout(200);
    const nota = await p.locator('.day-panel .liber-note').innerText();
    ok(/Zi liberă \(duminică\)/.test(nota) && /Planificată/.test(nota), `${vw}: ziua selectată: motivul și starea (${nota.replace(/\n/g, ' ')})`);
    ok(/zi liberă/.test(await p.locator('.cal-legend').innerText()), `${vw}: legenda explică zilele libere`);
    await p.screenshot({ path: `${S}/libere-cal-${vw}.png`, fullPage: true });
    await p.click('[data-act="cal-next"]'); await p.waitForTimeout(300);
    ok(/Sf\. Andrei/.test(await cell('2026-11-30').innerText()) && await cell('2026-11-30').evaluate((e) => e.classList.contains('is-liber')), `${vw}: 30 noiembrie → Sfântul Andrei`);
    await cell('2026-11-30').click(); await p.waitForTimeout(200);
    ok(/Sărbătoare legală: Sfântul Andrei/.test(await p.locator('.day-panel .liber-note').innerText()), `${vw}: ziua selectată: numele sărbătorii`);
    await cell('2026-11-11').click(); await p.waitForTimeout(200);
    ok(await p.locator('.day-panel .liber-note').count() === 0, `${vw}: zi lucrătoare → fără notă`);
    await p.goto('http://localhost:8080/#/luna/2026-10'); await p.waitForTimeout(300);
    const sum = await p.locator('.f-sum > div').allInnerTexts();
    ok(sum.length === 6 && /^9\nzile libere \(22 lucrătoare\)/.test(sum[5]), `${vw}: raport: 9 zile libere, 22 lucrătoare (${sum[5]?.replace(/\n/g, ' ')})`);
    const doc = await p.locator('.fisa-doc').innerText();
    ok(/Zile libere/.test(doc) && /Efectuate \(până azi\)\s+4/.test(doc) && /Planificate\s+5/.test(doc), `${vw}: raport: 4 efectuate (3, 4, 10, 11), 5 planificate`);
    await p.goto('http://localhost:8080/#/luna/2026-12'); await p.waitForTimeout(300);
    const dec = await p.locator('.fisa-doc').innerText();
    ok(/Sărbători legale: Ziua Națională \(01\.12\.2026\), Crăciunul \(25\.12\.2026\), a doua zi de Crăciun \(26\.12\.2026\)\s+3/.test(dec), `${vw}: decembrie: cele 3 sărbători, cu data`);
    ok(/Zile lucrătoare în lună\s+21/.test(dec), `${vw}: decembrie: 21 de zile lucrătoare`);
    await p.screenshot({ path: `${S}/libere-raport-${vw}.png`, fullPage: true });
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
