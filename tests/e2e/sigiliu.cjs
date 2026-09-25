// v1.20: sigiliul în bara categoriei și pe rândul controlului din liste
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Depozit Sigma'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    await p.fill('[data-bind$=".regimInaltime"]', 'P+1'); await p.click('[data-bind$=".nrAngajati"]'); await p.waitForTimeout(200);
    await p.click('.grf-opts [data-val="V"]'); await p.waitForTimeout(300);
    await p.click('.grf-field .grav-note a'); await p.waitForTimeout(700);
    const gl = await p.locator('#ner-grav-grfV .row-idx').innerText();
    await p.click('#ner-grav-grfV .nok-btn'); await p.waitForTimeout(200);
    const grp = p.locator('.cat-group', { has: p.locator('#ner-grav-grfV') });
    const cat = await grp.getAttribute('class').then((x) => x.match(/cat-(\S+)/g).find((k) => k !== 'cat-group').slice(4));
    ok(await grp.locator('> .cat-title .cat-sigiliu').count() === 0, `${vp.width}: constatat fără sigiliu → bara categoriei fără sigiliu`);
    await p.click('#ner-grav-grfV [data-path$=".sigiliu"]'); await p.waitForTimeout(200);
    const t1 = await grp.locator('> .cat-title .cat-sigiliu').innerText().catch(() => '');
    ok(/^1 criteriu de sigilare$/.test(t1.trim()), `${vp.width}: categoria deschisă → „${t1.trim()}”`);
    await p.click(`.cat-title[data-cat="${cat}"]`); await p.waitForTimeout(300);
    const t2 = await p.locator(`.cat-group.cat-${cat} > .cat-title .cat-sigiliu`).innerText().catch(() => '');
    ok(t2.trim() === `1 criteriu de sigilare: ${gl}`, `${vp.width}: categoria restrânsă → „${t2.trim()}” (litera ${gl})`);
    const bg = await p.locator(`.cat-group.cat-${cat} > .cat-title .cat-sigiliu`).evaluate((e) => getComputedStyle(e).backgroundColor);
    ok(bg !== 'rgba(0, 0, 0, 0)', `${vp.width}: pastila e plină (roșie): ${bg}`);
    await p.click(`.cat-title[data-cat="${cat}"]`); await p.waitForTimeout(300);
    // rând adăugat, grav, cu sigiliu → bara „rânduri adăugate”
    await p.click('[data-act="ner-add"][data-sec="ner"]'); await p.keyboard.type('Butelii GPL în subsol'); await p.waitForTimeout(400);
    const cr = p.locator('.cat-custom .ner-row').first();
    await cr.locator('[data-path$=".grav"]').click(); await p.waitForTimeout(200);
    await cr.locator('[data-path$=".sigiliu"]').click(); await p.waitForTimeout(300);
    ok(/1 criteriu de sigilare/.test(await p.locator('#add-ner .cat-sigiliu').innerText().catch(() => '')), `${vp.width}: bara rândurilor adăugate → „1 criteriu de sigilare”`);
    await p.screenshot({ path: `${S}/sigiliu-cat-${vp.width}.png` });
    // rândul controlului din liste
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(400);
    const chips = await p.locator('.ctl-row:has-text("Depozit Sigma") .chips').innerText();
    ok(/Sigiliu aplicat · 2 criterii/.test(chips), `${vp.width}: Istoric, aceeași construcție → „Sigiliu aplicat · 2 criterii” (${chips.replace(/\n/g, ' | ')})`);
    ok(/^2 nereguli grave\nSigiliu aplicat · 2 criterii/.test(chips), `${vp.width}: după „2 nereguli grave” (G13 + rândul adăugat grav)`);
    await p.screenshot({ path: `${S}/sigiliu-istoric-${vp.width}.png` });
    await p.click('#flt-hist [data-val="sigiliu"]'); await p.waitForTimeout(200);
    ok(await p.locator('#hist-list .ctl-row').count() === 1 && /Depozit Sigma/.test(await p.locator('#hist-list').innerText()), `${vp.width}: filtrul „Sigiliu aplicat” → Depozit Sigma`);
    await p.click('#flt-hist [data-val="sigiliu"]'); await p.waitForTimeout(200);
    await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(400);
    ok(/Sigiliu aplicat · 2 criterii/.test(await p.locator('#sec-open .item:has-text("Depozit Sigma")').innerText()), `${vp.width}: Panou, Controale neîncheiate → același indicator`);
    await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(300);
    ok(/La ultimul control: sigiliu aplicat · 2 criterii/.test(await p.locator('.obj-card:has-text("Depozit Sigma")').innerText()), `${vp.width}: Obiective → „La ultimul control: sigiliu aplicat · 2 criterii”`);
    await p.screenshot({ path: `${S}/sigiliu-obiective-${vp.width}.png` });
    await p.click('.obj-card:has-text("Depozit Sigma")'); await p.waitForTimeout(300);
    ok(/Sigiliu aplicat · 2 criterii/.test(await p.locator('.tl-item .ctl-row').first().innerText()), `${vp.width}: pagina obiectivului → rândul controlului`);
    // sigiliu retras: rândul G trecut pe ✓ → nu mai numără
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    await p.click('.ctl-row:has-text("Depozit Sigma")'); await p.waitForTimeout(400);
    await p.goto(p.url().replace(/\/obiectiv.*$/, '/nereguli/grav-grfV')); await p.waitForTimeout(600);
    await p.click('#ner-grav-grfV .ok-btn'); await p.waitForTimeout(300);
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    ok(/Sigiliu aplicat · 1 criteriu/.test(await p.locator('.ctl-row:has-text("Depozit Sigma") .chips').innerText()), `${vp.width}: rândul G trecut pe Conform → „Sigiliu aplicat · 1 criteriu”`);
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
