const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [w, h, sch] of [[820, 1180, 'light'], [1180, 820, 'dark']]) {
    console.log('--', w, sch);
    const p = await (await b.newContext({ viewport: { width: w, height: h }, serviceWorkers: 'block', colorScheme: sch })).newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
    // Panou: patru culori distincte, aceeași culoare pe casetă și pe secțiunea ei
    const col = (sel) => p.locator(sel).evaluate((e) => getComputedStyle(e).borderTopColor);
    const lc = (sel) => p.locator(sel).evaluate((e) => getComputedStyle(e).borderLeftColor);
    const k = { fines: await col('.kpi-fines'), open: await col('.kpi-open'), asi: await col('.kpi-asi'), pv: await col('.kpi-pv') };
    ok(new Set(Object.values(k)).size === 4, `patru culori diferite: ${Object.values(k).join(' / ')}`);
    ok(k.fines === await lc('#sec-fines') && k.open === await lc('#sec-open') && k.asi === await lc('#sec-asi') && k.pv === await lc('#sec-pv'), 'fiecare secțiune are culoarea casetei ei');
    const iconCol = await p.locator('.kpi-fines .kpi-ic').evaluate((e) => getComputedStyle(e).color);
    ok(iconCol === k.fines, 'pictograma are culoarea statisticii');
    // taburile controlului
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    const id = (await p.locator('a[href*="#/control/"]').first().getAttribute('href')).split('/')[2];
    await p.goto(`http://localhost:8080/#/control/${id}/acte`); await p.waitForTimeout(400);
    const band = await p.locator('#ed-tabs').evaluate((e) => getComputedStyle(e).backgroundColor);
    const bg = await p.evaluate(() => getComputedStyle(document.body).backgroundColor);
    ok(band !== bg && band !== 'rgba(0, 0, 0, 0)', `bara taburilor se deosebește de fundal (${band} vs ${bg})`);
    const on = p.locator('.ed-tab.on');
    ok(await on.count() === 1 && /Acte/.test(await on.innerText()) && await on.getAttribute('aria-current') === 'page', 'tabul curent marcat (și pentru cititoare de ecran)');
    const onBg = await on.evaluate((e) => getComputedStyle(e).backgroundColor);
    const offBg = await p.locator('.ed-tab:not(.on)').first().evaluate((e) => getComputedStyle(e).backgroundColor);
    ok(onBg !== offBg, `tabul curent e plin, diferit de celelalte (${onBg})`);
    const pr = await p.locator('.ed-tab .tab-prog i').evaluateAll((a) => a.map((i) => i.style.width));
    ok(pr.length >= 3 && pr.every((x) => /^\d+%$/.test(x)), `bare de progres pe taburi: ${pr.join(', ')}`);
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(200);
    if (w > 1000) ok(await p.locator('.side-guide span').evaluate((s) => s.scrollWidth <= s.clientWidth + 0.5), '„Ghidul aplicației” încape întreg în bara laterală');
    ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
