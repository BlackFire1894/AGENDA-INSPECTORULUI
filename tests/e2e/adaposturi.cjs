// v1.22: adăposturile de protecție civilă (OPEC: tabul Obiectiv + Nereguli; Localitate: tabul Protecție civilă),
// cele 4 rubrici noi de protecție civilă, bara controlului, filtrul și fișa
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 1180, height: 820 }]) {
    const W = vp.width;
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    p.on('dialog', (d) => d.accept());
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Școala Delta'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    // OPEC: secțiunea din tabul Obiectiv
    const sec = p.locator('#sec-adaposturi');
    ok(await sec.count() === 1 && await sec.locator('.adp-count').count() === 0, `${W}: OPEC: secțiunea Adăposturi în tabul Obiectiv; fără DA nu se cere numărul`);
    await sec.locator('[data-path="adapostPC.v"][data-val="DA"]').click(); await p.waitForTimeout(200);
    ok(/Câte adăposturi\?/.test(await sec.innerText()), `${W}: DA → „Câte adăposturi?”`);
    for (let i = 0; i < 3; i++) { await sec.locator('[data-act="adp-count"][data-val="1"]').click(); await p.waitForTimeout(150); }
    ok(await sec.locator('.ner-row').count() === 3 && /A1[\s\S]*A2[\s\S]*A3/.test(await sec.innerText()), `${W}: 3 adăposturi → rândurile A1–A3`);
    const locs = ['Subsol corp A', 'Subsol corp B', 'Demisol sală de sport'];
    for (let i = 0; i < 3; i++) { await sec.locator('.adp-loc').nth(i).fill(locs[i]); await sec.locator('.adp-loc').nth(i).dispatchEvent('input'); }
    await p.waitForTimeout(500);
    const rows = sec.locator('.ner-row');
    await rows.nth(0).locator('.ok-btn').click(); await p.waitForTimeout(200);
    await rows.nth(1).locator('.ok-btn').click(); await p.waitForTimeout(200);
    await sec.locator('.ner-row').nth(2).locator('.nok-btn').click(); await p.waitForTimeout(200);
    ok(/3 adăposturi: 2 conforme, 1 neconform/.test(await sec.locator('.adp-sum').innerText()), `${W}: sumarul: 3 adăposturi: 2 conforme, 1 neconform`);
    const a3 = sec.locator('.ner-row').nth(2);
    ok(await a3.locator('[data-path$=".inPV"]').count() === 1 && await a3.locator('[data-path$=".amenda.aplicata"]').count() === 1 && await a3.locator('[data-path$=".grav"]').count() === 0, `${W}: neconform = neregulă: PV și amendă (fără „Neregulă gravă”)`);
    await a3.locator('.row-obs textarea, textarea').first().fill('Ușa etanșă lipsă'); await a3.locator('textarea').first().dispatchEvent('input'); await p.waitForTimeout(500);
    await p.addStyleTag({ content: '.edit-tools,.tabbar,.ed-tabs{display:none!important}' });
    await sec.screenshot({ path: `${S}/adp-obiectiv-${W}.png` });
    // tabul Nereguli: grupul Adăposturi, neconformul constatat
    const url = p.url().replace(/\/obiectiv.*$/, '');
    await p.goto(`${url}/nereguli`); await p.waitForTimeout(500);
    const g = p.locator('.cat-group.cat-adapost');
    ok(await g.count() === 1 && /Adăposturi de protecție civilă/.test(await g.locator('.cat-title').innerText()) && /1 constatată/.test(await g.locator('.cat-title').innerText()), `${W}: Nereguli: grupul „Adăposturi de protecție civilă”, 1 constatată`);
    // Text PV
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(300);
    const pv = await p.locator('.pv-text').inputValue();
    ok(/Adăpost de protecție civilă neconform – Demisol sală de sport\. Ușa etanșă lipsă/.test(pv) && !/Subsol corp A/.test(pv), `${W}: Text PV: doar adăpostul neconform, cu locația și observația`);
    await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {}); await p.waitForTimeout(200);
    // Istoric: bara + filtru
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(400);
    ok(/3 adăposturi: 2 conforme, 1 neconform/.test(await p.locator('.ctl-row:has-text("Școala Delta") .chips').innerText()), `${W}: Istoric: bara arată adăposturile`);
    ok(+(await p.locator('#flt-hist [data-val="adapost"] b').innerText()) === 1, `${W}: filtrul „Adăposturi PC”: 1`);
    await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(300);
    ok(/La ultimul control: 3 adăposturi: 2 conforme, 1 neconform/.test(await p.locator('.obj-card:has-text("Școala Delta")').innerText()), `${W}: Obiective: cardul arată adăposturile ultimului control`);
    await p.click('#flt-obj [data-val="adapost"]'); await p.waitForTimeout(200);
    ok(await p.locator('#obj-list .obj-card').count() === 1, `${W}: Obiective: filtrul „Adăposturi PC” → 1 obiectiv`);
    // fișa
    await p.goto(`${url.replace('#/control/', '#/fisa/')}`); await p.waitForTimeout(400);
    const f = await p.locator('.fisa-doc').innerText();
    ok(/Adăposturi de protecție civilă:\s*DA — 3 adăposturi: 2 conforme, 1 neconform/.test(f) && /A3\s+Demisol sală de sport\s+Neconform\s+Ușa etanșă lipsă/.test(f), `${W}: Fișa: adăposturile, cu tabel`);
    // NU → confirmare, adăposturile se șterg
    await p.goto(`${url}/obiectiv/sec-adaposturi`); await p.waitForTimeout(500);
    await p.click('#sec-adaposturi [data-path="adapostPC.v"][data-val="NU"]'); await p.waitForTimeout(300);
    await p.click('.modal .btn-danger').catch(() => {}); await p.waitForTimeout(300);
    ok(await p.locator('#sec-adaposturi .ner-row').count() === 0 && await p.locator('#sec-adaposturi .adp-count').count() === 0, `${W}: NU → adăposturile se șterg (după confirmare)`);
    // Localitate: tabul Protecție civilă — rubricile noi și adăposturile
    await p.goto('http://localhost:8080/#/panou'); await p.reload(); await p.waitForTimeout(400);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    await p.click('[data-act="new-control"]:visible'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Comuna Epsilon'); await p.click('#nc-create'); await p.waitForTimeout(400);
    await p.click('[data-path="tip"][data-val="LOCALITATE"]'); await p.waitForTimeout(300);
    ok(await p.locator('#sec-adaposturi').count() === 0, `${W}: Localitate: fără secțiunea din tabul Obiectiv`);
    await p.goto(p.url().replace(/\/obiectiv.*$/, '/pc')); await p.waitForTimeout(500);
    const org = p.locator('.cat-group.cat-pcorg');
    const orgT = await org.innerText().catch(() => '');
    ok(/Organizare protecție civilă/.test(orgT) && /Agent de inundații stabilit/.test(orgT) && /Inspector de protecție civilă stabilit/.test(orgT) && /Taxa de protecție civilă stabilită/.test(orgT) && /Convenții cu OPEC/.test(orgT), `${W}: PC: categoria „Organizare protecție civilă” cu cele 4 rubrici`);
    await org.locator('.ner-row').nth(3).locator('.nok-btn').click(); await p.waitForTimeout(200);
    await p.click('#ner-adapostPC [data-val="DA"]'); await p.waitForTimeout(200);
    await p.click('#ner-adapostPC [data-act="adp-count"][data-val="1"]'); await p.waitForTimeout(200);
    await p.locator('.cat-pcdotare .adp-loc').first().fill('Subsol primărie'); await p.locator('.cat-pcdotare .adp-loc').first().dispatchEvent('input'); await p.waitForTimeout(400);
    await p.locator('.cat-pcdotare .ner-row:has(.adp-loc) .nok-btn').click(); await p.waitForTimeout(300);
    await p.addStyleTag({ content: '.edit-tools,.tabbar,.ed-tabs{display:none!important}' });
    await p.locator('.cat-group.cat-pcdotare').screenshot({ path: `${S}/adp-pc-${W}.png` });
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(300);
    const pv2 = await p.locator('.pv-text').inputValue();
    ok(/Lipsă convenții cu OPEC/.test(pv2) && /Adăpost de protecție civilă neconform – Subsol primărie/.test(pv2), `${W}: PV (Localitate): „Lipsă convenții cu OPEC” și adăpostul neconform`);
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
