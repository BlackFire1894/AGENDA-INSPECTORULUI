// v1.23: telefonul (css/telefon.css) — iPhone 12 Pro Max (428×926, 926×428), iPhone obișnuit (390×844), SE (375×667);
// nimic nu iese din ecran, bara de jos cu 5 butoane, Setări din Panou, calendarul cu buline, taburile derulabile;
// iar pe tabletă foaia pentru telefon nu se aplică deloc.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  const iese = (p) => p.evaluate(() => {
    const w = document.documentElement.clientWidth; const bad = [];
    document.querySelectorAll('body *').forEach((e) => {
      const r = e.getBoundingClientRect(); if (!r.width || r.right <= w + 1 || getComputedStyle(e).position === 'fixed') return;
      for (let x = e.parentElement; x && x !== document.body; x = x.parentElement) { const o = getComputedStyle(x).overflowX; if (o === 'auto' || o === 'scroll' || o === 'hidden') return; }
      bad.push(`${e.tagName}.${[...e.classList].join('.')}`);
    });
    return { lat: document.documentElement.scrollWidth > w, bad: bad.slice(0, 5) };
  });
  for (const [W, H] of [[428, 926], [926, 428], [390, 844], [375, 667]]) {
    const ctx = await b.newContext({ viewport: { width: W, height: H }, isMobile: true, hasTouch: true, deviceScaleFactor: 2, serviceWorkers: 'block' });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    const ids = await p.evaluate(async () => { const { state } = await import('./js/state.js'); return { opec: state.controls.find((c) => c.tip === 'OPEC').id, loc: state.controls.find((c) => c.tip === 'LOCALITATE').id }; });
    const ecrane = ['#/panou', '#/obiective', '#/istoric', '#/calendar', '#/setari', '#/luna/2026-10', '#/ghid',
      ...['obiectiv', 'acte', 'nereguli'].map((t) => `#/control/${ids.opec}/${t}`), ...['planuri', 'pc'].map((t) => `#/control/${ids.loc}/${t}`), `#/fisa/${ids.loc}`];
    const rele = [];
    for (const h of ecrane) { await p.goto(`http://localhost:8080/${h}`); await p.waitForTimeout(350); const r = await iese(p); if (r.lat || r.bad.length) rele.push(`${h}: ${r.bad.join(', ')}`); }
    ok(!rele.length, `${W}×${H}: ${ecrane.length} ecrane, nimic nu iese din ecran${rele.length ? ` — ${rele.join(' | ')}` : ''}`);
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
    ok(await p.evaluate(() => [...document.querySelectorAll('.tabbar > *')].filter((e) => getComputedStyle(e).display !== 'none').length) === 5, `${W}×${H}: bara de jos are 5 butoane`);
    ok(await p.locator('.dash-actions .set-btn').isVisible(), `${W}×${H}: Setări din Panou`);
    ok(/telefonului/.test(await p.locator('.dash-head .eyebrow').innerText()), `${W}×${H}: „Data și ora telefonului”`);
    ok(await p.evaluate(() => getComputedStyle(document.documentElement).fontSize) === '17px', `${W}×${H}: text „Mare” = 17px`);
    await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
    const ev = p.locator('.cal-cell .cal-ev').first();
    ok(await ev.evaluate((e) => { const r = e.getBoundingClientRect(); return r.width < 14 && getComputedStyle(e).borderRadius === '50%'; }), `${W}×${H}: calendarul arată buline`);
    await p.goto(`http://localhost:8080/#/control/${ids.loc}/pc`); await p.waitForTimeout(500);
    ok(await p.evaluate(() => { const bar = document.getElementById('ed-tabs'); const on = bar.querySelector('.ed-tab.on').getBoundingClientRect(); const r = bar.getBoundingClientRect(); return on.left >= r.left - 1 && on.right <= r.right + 1; }), `${W}×${H}: tabul curent (Protecție civilă) e în vedere`);
    await p.screenshot({ path: `${S}/telefon-${W}x${H}.png` });
    await ctx.close();
  }
  // tableta: foaia pentru telefon nu se aplică
  for (const [W, H] of [[820, 1180], [1180, 820], [744, 1133]]) {
    const ctx = await b.newContext({ viewport: { width: W, height: H }, serviceWorkers: 'block' });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(400);
    const r = await p.evaluate(() => ({
      aplicata: [...document.styleSheets].some((s) => /telefon\.css/.test(s.href || '') && !s.disabled && matchMedia(s.media.mediaText).matches),
      font: getComputedStyle(document.documentElement).fontSize,
      setari: !!document.querySelector('.tabbar a[data-nav="setari"]') && getComputedStyle(document.querySelector('.tabbar a[data-nav="setari"]')).display !== 'none',
      eyebrow: document.querySelector('.dash-head .eyebrow')?.innerText,
    }));
    ok(!r.aplicata && r.font === '18px' && (W >= 1000 || r.setari) && /tabletei/.test(r.eyebrow || ''), `tabletă ${W}×${H}: fără foaia pentru telefon (text 18px, Setări în bara de jos, „Data și ora tabletei”)`);
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
