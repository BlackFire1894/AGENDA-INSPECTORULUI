// v1.14: observațiile apar doar când au text; „+ Obs.” deschide câmpul; gol → revine la buton
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || __dirname;
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Spitalul'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    const id = p.url().split('/')[5];
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
    // numai observațiile scrise au câmp; restul au „+ Obs.”
    const r = await p.evaluate(() => {
      const rows = [...document.querySelectorAll('.ner-row')];
      const bad = rows.filter((row) => { const ta = row.querySelector('textarea.obs'); const btn = row.querySelector('[data-act="obs-open"]'); return ta ? ((!ta.value.trim() && !row.classList.contains('is-nok')) || btn) : !btn; }).map((x) => x.id);
      return { rows: rows.length, ta: document.querySelectorAll('.ner-row textarea.obs').length, bad };
    });
    ok(r.rows > 20 && r.ta > 0 && r.ta < r.rows && !r.bad.length, `nereguli: ${r.ta} câmpuri (scrise sau la rânduri constatate) din ${r.rows} rânduri; restul „+ Obs.” ${r.bad.length ? 'GREȘIT: ' + r.bad.join(',') : ''}`);
    // v1.15: la ✗ câmpul de observații apare deschis, fără focus (fără tastatură)
    const tinta = await p.evaluate(() => [...document.querySelectorAll('.ner-row:not(.is-nok):not(.is-collapsed)')].find((x) => x.querySelector('.nok-btn') && x.querySelector('[data-act="obs-open"]'))?.id);
    await p.click(`#${tinta} .nok-btn`); await p.waitForTimeout(300);
    ok(await p.locator(`#${tinta} textarea.obs`).count() === 1 && await p.evaluate(() => document.activeElement?.tagName !== 'TEXTAREA'), `✗ la ${tinta}: observațiile apar deschise, fără tastatură`);
    await p.click('#edit-strip [data-act="undo"]:visible, #side-edit [data-act="undo"]:visible'); await p.waitForTimeout(400);
    ok(await p.locator(`#${tinta} textarea.obs`).count() === 0 && await p.locator(`#${tinta} [data-act="obs-open"]`).count() === 1, `Anulează ✗ la ${tinta}: câmpul gol dispare din nou`);
    ok(await p.locator('.obs-hide, [data-act="obs-toggle"]').count() === 0 && !/Ascunde observațiile/.test(await p.locator('#ed-body').innerText()), 'fără săgeți de ascundere și fără „Ascunde observațiile”');
    ok(await p.locator('#ner-q textarea.obs').inputValue() === 'Hidrant exterior H2 fără presiune', 'q: observația scrisă e afișată');
    // deschide, scrie, persistă
    await p.click('#ner-b1 [data-act="obs-open"]'); await p.waitForTimeout(250);
    ok(await p.evaluate(() => document.activeElement.matches('#ner-b1 textarea.obs')), 'b1: „+ Obs.” deschide și focalizează câmpul');
    await p.keyboard.type('PRAM 2025 lipsă'); await p.waitForTimeout(500);
    await p.reload(); await p.waitForTimeout(400);
    ok(await p.locator('#ner-b1 textarea.obs').inputValue() === 'PRAM 2025 lipsă', 'b1: textul se salvează; după reîncărcare câmpul e afișat');
    // golit → revine la „+ Obs.” la următoarea redesenare
    await p.fill('#ner-b1 textarea.obs', ''); await p.dispatchEvent('#ner-b1 textarea.obs', 'input'); await p.waitForTimeout(300);
    await p.click('.sum-line'); await p.click('[data-act="ner-filter"][data-val="ALL"]'); await p.waitForTimeout(300);
    ok(await p.locator('#ner-b1 textarea.obs').count() === 0 && await p.locator('#ner-b1 [data-act="obs-open"]').count() === 1, 'b1 golit → înapoi la „+ Obs.”');
    // Anulează readuce textul (și câmpul)
    await p.click('#edit-strip [data-act="undo"]:visible, #side-edit [data-act="undo"]:visible'); await p.waitForTimeout(500);
    ok(await p.locator('#ner-b1 textarea.obs').count() === 1 && await p.locator('#ner-b1 textarea.obs').inputValue() === 'PRAM 2025 lipsă', 'Anulează → observația revine, cu câmpul ei');
    // rândul fără corp (Planuri și SVSU, la o localitate): „+ Obs.” stă în bară; ținta ≥ 44px
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Comuna Valea Mare'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    await p.goto(`http://localhost:8080/#/control/${p.url().split('/')[5]}/planuri`); await p.waitForTimeout(300);
    const lone = await p.evaluate(() => { const row = [...document.querySelectorAll('.ner-row:not(.is-nok)')].find((x) => x.querySelector('.ner-bar [data-act="obs-open"]') && !x.querySelector(':scope > .row-main')); if (!row) return null; const btn = row.querySelector('.ner-bar [data-act="obs-open"]'); const a = window.getComputedStyle(btn, '::after'); const rb = btn.getBoundingClientRect(); return { id: row.id, h: rb.height, hit: rb.height - 2 * parseFloat(a.top) }; });
    ok(lone && lone.hit >= 43.5, `rând fără corp (${lone && lone.id}): „+ Obs.” în bară, țintă ${lone && Math.round(lone.hit)}px`);
    await p.screenshot({ path: `${S}/obsind-${ori}.png` });
    // dotări
    await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
    const d = await p.evaluate(() => { const rows = [...document.querySelectorAll('.constr:not(.closed) .dot-row, .dot-row')]; return { n: rows.length, bad: rows.filter((row) => { const ta = row.querySelector('textarea'); const btn = row.querySelector('[data-act="obs-open"]'); return ta ? !ta.value.trim() : !btn; }).length }; });
    ok(d.n > 10 && d.bad === 0, `dotări: ${d.n} rânduri, câmp doar unde e text`);
    // acte
    await p.goto(`http://localhost:8080/#/control/${id}/acte`); await p.waitForTimeout(300);
    ok(await p.locator('.act-row [data-act="obs-open"]').count() + await p.locator('.act-row textarea.obs').count() === 14, 'acte: fiecare act are fie câmp (scris sau la Lipsă), fie „+ Obs.”');
    await p.click('.act-row >> nth=0 >> [data-act="obs-open"]'); await p.waitForTimeout(250);
    const ta = p.locator('.act-row >> nth=0 >> textarea');
    const b0 = await ta.boundingBox(); await ta.fill('a\nb\nc\nd'); await ta.dispatchEvent('input'); await p.waitForTimeout(100);
    const b1 = await ta.boundingBox();
    ok(Math.abs(b0.width - b1.width) < 1 && b1.height > b0.height + 40, 'câmpul crește în jos, lățime fixă');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
