// v1.20: filtrele din Istoric și Obiective (după informațiile de pe rândul controlului)
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [vw, vh, tema] of [[820, 1180, 'light'], [1180, 820, 'dark']]) {
    const ctx = await b.newContext({ viewport: { width: vw, height: vh }, serviceWorkers: 'block', colorScheme: tema });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    const nrRez = async () => +(await p.locator('.count').innerText()).match(/^\d+/)[0];
    const total = await nrRez();
    const btns = p.locator('#flt-hist .flt-btn:not(.flt-clear)');
    ok(await btns.count() === 10, `${vw}: Istoric: 10 filtre`);
    // fiecare filtru, singur: numărul de pe buton = rezultatele = rândurile care au pastila corespunzătoare
    const semn = { 'am-blue': /În curs/, 'am-yellow': /Termen 15 zile expirat/, 'am-red': /Trimite la ANAF/, 'am-green': /Achitat/, asi: /ASI(?!.*neînceput)/, inc: /Încărcare:/, pv: /netrecut[ăe] în PV/, grave: /grav[ăe]/, sigiliu: /[Ss]igili/, adapost: /adăpost/ };
    for (const k of Object.keys(semn)) {
      const btn = p.locator(`#flt-hist [data-val="${k}"]`);
      const n = +(await btn.locator('b').innerText());
      if (!n) { ok(await btn.isDisabled(), `${vw}: ${k}: 0 → buton inactiv`); continue; }
      await btn.click(); await p.waitForTimeout(150);
      const rows = await p.locator('#hist-list .ctl-row .chips').allInnerTexts();
      ok(await nrRez() === n && rows.length === n && rows.every((r) => semn[k].test(r)), `${vw}: ${k}: ${n} controale, toate cu pastila`);
      await p.click(`#flt-hist [data-val="${k}"]`); await p.waitForTimeout(150);
    }
    ok(await nrRez() === total, `${vw}: fără filtre → din nou ${total}`);
    // două filtre împreună: rezultatul le îndeplinește pe amândouă
    await p.click('#flt-hist [data-val="pv"]'); await p.waitForTimeout(150);
    const nAm = +(await p.locator('#flt-hist [data-val="am-red"] b').innerText());
    if (nAm) {
      await p.click('#flt-hist [data-val="am-red"]'); await p.waitForTimeout(150);
      const rows = await p.locator('#hist-list .ctl-row .chips').allInnerTexts();
      ok(rows.length === nAm && rows.every((r) => /netrecut[ăe] în PV/.test(r) && /Trimite la ANAF/.test(r)), `${vw}: PV + ANAF → ${nAm}, ambele condiții`);
      ok(/filtre: Netrecute în PV \+ Trimite la ANAF/.test(await p.locator('.count').innerText()), `${vw}: numărul spune ce filtre sunt active`);
    }
    await p.screenshot({ path: `${S}/filtre-istoric-${vw}.png` });
    await p.click('#flt-hist .flt-clear'); await p.waitForTimeout(150);
    ok(await nrRez() === total && await p.locator('#flt-hist .flt-btn.on').count() === 0, `${vw}: Șterge filtrele`);
    // Obiective: ANAF la oricare control, grave doar la ultimul control
    await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(300);
    ok(await p.locator('#flt-obj .flt-btn:not(.flt-clear)').count() === 10, `${vw}: Obiective: 10 filtre`);
    const date = await p.evaluate(async () => {
      const m = await import('./js/model.js'); const { state } = await import('./js/state.js');
      const t = '2026-10-15';
      const ob = m.objectives(state.controls);
      const grave = (c) => c.nereguli.some((n) => m.isGrav(n) && n.status !== 'ok' && m.isApplicable(c, n));
      return {
        anaf: ob.filter((o) => o.controls.some((c) => m.controlStats(c, t).fines.some((f) => f.st.level === 'red'))).map((o) => o.denumire).sort(),
        grave: ob.filter((o) => grave(o.last)).map((o) => o.denumire).sort(),
      };
    });
    const semnOb = { 'am-blue': /În curs/, 'am-yellow': /Termen 15 zile expirat/, 'am-red': /Trimite la ANAF/, 'am-green': /achitat/, asi: /ASI în curs/, inc: /neîncărcat/, pv: /în PV/, grave: /La ultimul control: \d+ nereg\S+ grav/, sigiliu: /sigiliu/, adapost: /adăpost/ };
    for (const k of Object.keys(semnOb)) {
      const btn = p.locator(`#flt-obj [data-val="${k}"]`);
      const n = +(await btn.locator('b').innerText());
      if (!n) continue;
      await btn.click(); await p.waitForTimeout(150);
      const cards = await p.locator('#obj-list .obj-card').allInnerTexts();
      ok(cards.length === n && cards.every((x) => semnOb[k].test(x)), `${vw}: Obiective ${k}: ${n}, motivul se vede pe card`);
      await btn.click(); await p.waitForTimeout(150);
    }
    for (const [k, exp] of [['am-red', date.anaf], ['grave', date.grave]]) {
      const btn = p.locator(`#flt-obj [data-val="${k}"]`);
      if (!exp.length) { ok(await btn.isDisabled(), `${vw}: Obiective ${k}: niciunul`); continue; }
      await btn.click(); await p.waitForTimeout(150);
      const got = (await p.locator('#obj-list .obj-title').allInnerTexts()).sort();
      ok(JSON.stringify(got) === JSON.stringify(exp), `${vw}: Obiective ${k}: ${got.join(', ')}`);
      await btn.click(); await p.waitForTimeout(150);
    }
    await p.click('#flt-obj [data-val="asi"]').catch(() => {}); await p.waitForTimeout(150);
    await p.screenshot({ path: `${S}/filtre-obiective-${vw}.png` });
    // căutarea păstrează filtrele și actualizează numerele
    await p.fill('[data-search="obj"]', 'zzzz'); await p.dispatchEvent('[data-search="obj"]', 'input'); await p.waitForTimeout(300);
    ok(await p.locator('#flt-obj').count() === 1 && /Niciun/.test(await p.locator('#obj-list').innerText()), `${vw}: căutare fără rezultat: filtrele rămân vizibile`);
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
