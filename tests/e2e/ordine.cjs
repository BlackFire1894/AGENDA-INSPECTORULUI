// v1.21: în Panou, secțiunile cu ceva de rezolvat urcă primele; cele goale coboară
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const FIX = ['sec-fines', 'sec-asi', 'sec-inc', 'sec-open', 'sec-pv'];
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 1180, height: 820 }]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block' });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });
    await p.goto('http://localhost:8080/');
    // un singur control, încheiat ieri, fără nereguli → doar „De încărcat” are conținut
    await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Magazin Test'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.evaluate(async () => {
      const { state } = await import('./js/state.js'); const st = await import('./js/store.js');
      const c = state.controls[0]; c.dataInceput = '2026-10-14'; c.dataIncheiere = '2026-10-14';
      await st.saveControl(c);
    });
    await p.goto('http://localhost:8080/#/panou'); await p.reload(); await p.waitForTimeout(500);
    const ord = async () => p.locator('.dash-grid > section').evaluateAll((els) => els.map((e) => e.id));
    const o1 = await ord();
    const plin = async (id) => (await p.locator(`#${id} .items`).count()) > 0;
    const pline = []; for (const id of o1) if (await plin(id)) pline.push(id);
    ok(o1[0] === 'sec-inc' && pline.length === 1 && pline[0] === 'sec-inc', `${vp.width}: doar „De încărcat” are conținut → primul (${o1.join(', ')})`);
    ok(JSON.stringify(o1.slice(1)) === JSON.stringify(FIX.filter((x) => x !== 'sec-inc')), `${vp.width}: cele goale păstrează ordinea obișnuită`);
    await p.screenshot({ path: `${S}/ordine-${vp.width}.png` });
    // cu datele demonstrative: toate cele cu conținut înaintea celor goale, fiecare grup în ordinea fixă
    await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
    await p.click('[data-act="demo-load"]'); await p.waitForTimeout(200); await p.click('.modal .btn-primary').catch(() => {}); await p.waitForTimeout(500);
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(400);
    const o2 = await ord(); const f = []; for (const id of o2) f.push(await plin(id));
    const k = f.indexOf(false);
    ok(k === -1 || f.slice(k).every((x) => !x), `${vp.width}: demo: întâi cele cu conținut (${o2.map((id, i) => `${id}${f[i] ? '*' : ''}`).join(', ')})`);
    const grp = (arr) => JSON.stringify(arr) === JSON.stringify(FIX.filter((x) => arr.includes(x)));
    ok(grp(o2.filter((_, i) => f[i])) && grp(o2.filter((_, i) => !f[i])), `${vp.width}: demo: ordinea fixă în fiecare grup`);
    await p.click('.kpi-inc'); await p.waitForTimeout(500);
    ok(await p.locator('#sec-inc').isVisible(), `${vp.width}: caseta „De încărcat” duce tot la secțiunea ei`);
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
