const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true, permissions: ['geolocation'], geolocation: { latitude: 45.65, longitude: 25.6, accuracy: 10 } });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
    ok(await p.locator('.welcome a[href="#/ghid"]').count() === 1, 'ecranul gol: buton „Ghidul aplicației”');
    await p.screenshot({ path: `${S}/v16-${ori}-welcome.png`, fullPage: true });
    // control nou gol → bara de pași
    await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(250);
    await p.click('#nc-create'); await p.waitForTimeout(400);
    const first = await p.locator('.todo-head .todo-item').innerText();
    ok(/Completați denumirea/.test(first), `bara „Ce mai ai de făcut”: ${first}`);
    await p.click('.todo-more'); await p.waitForTimeout(200);
    const all = await p.locator('.todo-list .todo-item').allInnerTexts();
    ok(all.length === 5 && /acte neverificate/.test(all[1]) && /Nereguli: 15 nereguli neverificate/.test(all[2]) && /Coordonate GPS necompletate: Construcția 1/.test(all[3]) && /nu este încheiat/.test(all[4]), `lista completă: ${all.join(' | ')}`);
    await p.fill('[data-bind="denumire"]', 'Liceul Test'); await p.waitForTimeout(500);
    ok(!/denumirea/.test(await p.locator('#ed-todo').innerText()), 'bara se actualizează la tastare');
    // du-mă la acte
    await p.click('.todo-list .todo-item >> nth=0'); await p.waitForTimeout(600);
    ok(/\/acte\/act-ctpsi$/.test(p.url()), 'atingere → tabul Acte, la primul act neverificat');
    // restul prezentate + anulare
    await p.click('.check-row >> nth=1 >> .nok-btn'); await p.waitForTimeout(200);
    await p.click('[data-act="rest-ok"]'); await p.waitForTimeout(200);
    ok((await p.locator('.modal h2').innerText()).includes('13 acte'), 'confirmare: 13 acte (unul e deja Lipsă)');
    ok(await p.locator('.bulk-list li').count() === 13 && await p.locator('.modal [data-r="1"]').isDisabled(), 'lista: 13 acte; butonul inactiv până la bifă');
    await p.click('#bulk-ok'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
    ok(await p.locator('.check-row.is-ok').count() === 13 && await p.locator('.check-row.is-nok').count() === 1, 'Restul prezentate: 13 ✓, „Lipsă” neatins');
    await p.click('.toast-btn'); await p.waitForTimeout(300);
    ok(await p.locator('.check-row.is-ok').count() === 0 && await p.locator('.check-row.is-nok').count() === 1, 'Anulează → revine exact la starea anterioară');
    await p.click('[data-act="rest-ok"]'); await p.click('#bulk-ok'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
    // nereguli: restul conform
    await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
    await p.click('#ner-d .nok-btn'); await p.waitForTimeout(200);
    await p.click('[data-act="rest-ok"]'); await p.click('#bulk-ok'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
    ok(await p.locator('.ner-row.is-ok').count() === 14 && await p.locator('#ner-d.is-nok').count() === 1, 'Nereguli: restul conform (14), d rămâne constatat');
    ok(await p.locator('.btn-rest').count() === 0, 'butonul dispare când nu mai e nimic de bifat');
    // bara arată acum PV
    const now = await p.locator('.todo .todo-item >> nth=0').innerText();
    ok(/netrecută în PV/.test(now), `pasul următor: ${now}`);
    // încheiere cu omisiuni
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await p.click('[data-act="close-control"]'); await p.waitForTimeout(300);
    ok((await p.locator('.modal').innerText()).includes('netrecută în PV'), 'verificare la încheiere: arată omisiunea');
    await p.click('.modal .todo-item'); await p.waitForTimeout(600);
    ok(/\/nereguli\/d$/.test(p.url()) && await p.locator('.modal').count() === 0, 'din verificare → direct la neregulă');
    await p.click('#ner-d [data-path$=".inPV"]'); await p.waitForTimeout(200);
    await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
    await p.click('button:has-text("Completează coordonatele")'); await p.waitForTimeout(500);
    await p.click('[data-act="close-control"]'); await p.waitForTimeout(300);
    ok(await p.locator('.modal').count() === 0 && await p.locator('[data-bind="dataIncheiere"]').count() === 1, 'fără omisiuni: se încheie direct');
    // v1.16: după încheiere mai rămâne încărcarea (aplicația ISU + documentul), 3 zile lucrătoare
    ok(/Neîncărcat în aplicație, document neîncărcat/.test(await p.locator('.todo').innerText()) && await p.locator('#sec-incarcare').count() === 1, 'după încheiere: „Neîncărcat în aplicație, document neîncărcat”');
    await p.click('[data-path="incarcare.aplicatie"]'); await p.waitForTimeout(200); await p.click('[data-path="incarcare.document"]'); await p.waitForTimeout(300);
    ok(/Încărcat în aplicație și document încărcat/.test(await p.locator('#sec-incarcare').innerText()), 'bifele de încărcare → „Încărcat în aplicație și document încărcat”');
    ok((await p.locator('.todo-done').innerText()).includes('Totul e completat'), 'bara: „Totul e completat”');
    await p.screenshot({ path: `${S}/v16-${ori}-done.png` });
    // Ghidul aplicației (manualul) în locul butoanelor „?”
    for (const route of ['panou', 'obiective', 'calendar', 'istoric', 'setari']) {
      await p.goto(`http://localhost:8080/#/${route}`); await p.waitForTimeout(200);
      ok(await p.locator('[data-act="help"]').count() === 0 && !(await p.locator('#main').innerText()).match(/^\?$/m), `fără „?” pe ${route}`);
    }
    await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
    await p.click('#main a[href="#/ghid"]'); await p.waitForTimeout(300);
    ok(/Ghidul aplicației/.test(await p.locator('h1').innerText()) && await p.locator('.m-cap').count() === 17, 'Setări → Ghidul aplicației: 17 capitole');
    const ctrl = p.locator('#ghid-control');
    ok(await ctrl.locator('.m-btn:has-text("Anulează") svg').count() === 1 && await ctrl.locator('.m-btn:has-text("Refă") svg').count() === 1 && await ctrl.locator('.m-btn:has-text("Text PV") svg').count() === 1, 'butoanele sunt desenate cu pictogramele din aplicație (Anulează, Refă, Text PV…)');
    await p.fill('[data-search="ghid"]', 'sigiliu'); await p.dispatchEvent('[data-search="ghid"]', 'input'); await p.waitForTimeout(200);
    const caps = await p.locator('.m-cap h2').allInnerTexts();
    ok(caps.length >= 1 && caps.length < 16 && caps.every((t) => t.length) && await p.evaluate(() => document.activeElement?.dataset?.search) === 'ghid', `căutare „sigiliu” → ${caps.length} capitole, focusul rămâne`);
    await p.click('[data-act="search-clear"][data-key="ghid"]'); await p.waitForTimeout(200);
    ok(await p.locator('.m-cap').count() === 17, '✕ golește căutarea');
    await p.click('.m-toc-item[href="#/ghid/verificari"]'); await p.waitForTimeout(400);
    ok(await p.locator('#ghid-verificari').evaluate((e) => { const r = e.getBoundingClientRect(); return r.top >= -2 && r.top < 200; }), 'cuprins → capitolul „Verificări”');
    await p.click('[data-act="ghid-back"]'); await p.waitForTimeout(400);
    ok(/#\/ghid$/.test(p.url()) || /#\/setari$/.test(p.url()), 'Înapoi');
    if (ori === 'land') {
      await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(200);
      await p.click('.side-guide'); await p.waitForTimeout(300);
      ok(/#\/ghid$/.test(p.url()) && (await p.locator('.side-guide').getAttribute('class')).includes('on'), 'bara laterală: „Ghidul aplicației”, marcat activ');
    } else {
      await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(200);
      await p.click('.dash-actions a[href="#/ghid"]'); await p.waitForTimeout(300);
      ok(/#\/ghid$/.test(p.url()), 'Panou (vertical): „Ghidul aplicației”');
    }
    await p.screenshot({ path: `${S}/v16-${ori}-guide.png` });
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
