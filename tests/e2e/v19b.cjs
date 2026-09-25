const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) {
  console.log('--', vp.width);
  const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
  await p.fill('#nc-name', 'Depozit Beta'); await p.click('#nc-create'); await p.waitForTimeout(400);
  // GRF/NSI
  ok(await p.locator('.grf-opts .chip-sel').count() === 6, 'GRF/NSI: I–V + Nu e necesar');
  await p.fill('[data-bind$=".regimInaltime"]', 'P'); await p.click('[data-bind$=".nrAngajati"]'); await p.waitForTimeout(200);
  await p.click('.grf-opts [data-val="V"]'); await p.waitForTimeout(300);
  ok(await p.locator('.grf-field .grav-note').count() === 0 && await p.locator('.constr-head .pill-red:visible').count() === 0, 'V la parter: fără avertizare');
  await p.fill('[data-bind$=".regimInaltime"]', 'P+1'); await p.click('[data-bind$=".nrAngajati"]'); await p.waitForTimeout(400);
  ok(/Neregulă gravă: .*GRF\/NSI V și regim P\+1/.test(await p.locator('#toast').innerText()), 'P+1 → alertă „Neregulă gravă” cu Vezi');
  ok(await p.locator('.grf-field .grav-note').count() === 1 && /GRF\/NSI V peste parter/.test(await p.locator('.constr-head').innerText()), 'notă roșie + pastilă în antetul construcției');
  ok(await p.evaluate(() => document.activeElement?.dataset?.bind || '').then((x) => x.endsWith('.nrAngajati')), 'focusul rămâne în câmpul atins');
  await p.click('.grf-field .grav-note a'); await p.waitForTimeout(700);
  ok(/\/nereguli\/grav-grfV$/.test(p.url()) && await p.locator('#ner-grav-grfV').count() === 1, 'Vezi → rândul G din Nereguli');
  const gl = await p.locator('#ner-grav-grfV .row-idx').innerText();
  console.log(JSON.stringify(await p.locator('#ner-grav-grfV').innerText()));
  ok(/^G\d+$/.test(gl) && /GRF\/NSI V peste parter în:\s*Construcția 1 \(P\+1\)/.test(await p.locator('#ner-grav-grfV').innerText()), `rând ${gl}, cu construcția și regimul`);
  // sigiliu pe neregula gravă
  ok(await p.locator('#ner-grav-grfV [data-path$=".sigiliu"]').count() === 0, 'Sigiliu apare doar la constatat');
  await p.click('#ner-grav-grfV .nok-btn'); await p.waitForTimeout(200);
  await p.click('#ner-grav-grfV [data-path$=".sigiliu"]'); await p.waitForTimeout(200);
  ok(/Sigiliu/.test(await p.locator('#ner-grav-grfV .chips').innerText()), 'Sigiliu bifat → pastilă „Sigiliu”');
  ok(await p.locator('#ner-d [data-path$=".sigiliu"]').count() === 0, 'neregulă obișnuită: fără Sigiliu');
  // rând adăugat
  await p.click('[data-act="ner-add"][data-sec="ner"]'); await p.keyboard.type('Butelii GPL depozitate în subsol'); await p.waitForTimeout(400);
  const cr = p.locator('.cat-custom .ner-row').first();
  ok((await cr.getAttribute('class')).includes('is-nok'), 'rândul adăugat pornește „Constatat”');
  console.log(await cr.getAttribute('class'), await cr.locator('button').allInnerTexts());
  ok(await cr.locator('[data-path$=".grav"]').count() === 1 && await cr.locator('[data-path$=".sigiliu"]').count() === 0, 'rând adăugat: bifa „Neregulă gravă”, fără Sigiliu încă');
  await cr.locator('[data-path$=".grav"]').click(); await p.waitForTimeout(200);
  ok(await cr.locator('[data-path$=".sigiliu"]').count() === 1 && await p.locator('.cat-custom .ner-row.is-grav-custom').count() === 1, 'bifat grav → apare Sigiliu, rândul devine roșu');
  await cr.locator('[data-path$=".sigiliu"]').click(); await p.waitForTimeout(200);
  await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
  const pv = await p.locator('.pv-text').inputValue();
  ok(/Construcție cu GRF\/NSI V[^\n]*\(sigiliu aplicat\)/.test(pv) && /Butelii GPL depozitate în subsol \(neregulă gravă; sigiliu aplicat\)/.test(pv), 'Text PV: sigiliu + neregulă gravă');
  await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {}); await p.waitForTimeout(200);
  await cr.locator('[data-path$=".grav"]').click(); await p.waitForTimeout(200);
  ok(await cr.locator('[data-path$=".sigiliu"]').count() === 0, 'debifat grav → Sigiliu dispare');
  await cr.locator('[data-path$=".grav"]').click(); await p.waitForTimeout(200);
  ok(!(await cr.locator('[data-path$=".sigiliu"]').getAttribute('class')).includes(' on'), '…și nu rămâne bifat pe ascuns');
  // Restul conform: confirmare manuală, fără neregulile grave
  await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
  await p.locator('.dot-row:has-text("Hidranți interiori") button:has-text("NU")').click(); await p.waitForTimeout(300);
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
  const restLbl = await p.locator('[data-act="rest-ok"]').innerText();
  await p.click('[data-act="rest-ok"]'); await p.waitForTimeout(300);
  const items = await p.locator('.bulk-list li').count();
  ok(restLbl.includes(`(${items})`), `butonul (${restLbl.trim()}) = lista din fereastră (${items})`);
  ok(!/Lipsă hidranți|GRF/.test(await p.locator('.bulk-list').innerText()) && /grav/i.test(await p.locator('.bulk-grav').innerText()), 'neregulile grave nu sunt în listă; mesaj că se marchează individual');
  ok(await p.locator('.modal [data-r="1"]').isDisabled(), 'butonul de marcare e inactiv fără bifă');
  await p.locator('.modal [data-r="1"]').click({ force: true }); await p.waitForTimeout(200);
  ok(await p.locator('#ner-results .ner-row.is-ok').count() === 0, 'atingerea pe butonul inactiv nu marchează nimic');
  if (!(await p.locator('#bulk-ok').count())) { await p.click('[data-act="rest-ok"]'); await p.waitForTimeout(300); }
  await p.screenshot({ path: `${S}/v19b-bulk-${vp.width}.png` });
  await p.click('#bulk-ok'); await p.waitForTimeout(100);
  ok(!(await p.locator('.modal [data-r="1"]').isDisabled()), 'după bifă: activ');
  await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  ok(/marcate „Conform”/.test(await p.locator('#toast').innerText()), 'marcate, cu Anulează');
  ok(!(await p.locator('#ner-lipsa-hidInt').getAttribute('class')).includes('is-ok'), 'G „Lipsă hidranți” rămâne nemarcată');
  // fișa
  const id = await p.evaluate(() => location.hash.split('/')[2]);
  await p.goto(`http://localhost:8080/#/fisa/${id}`); await p.waitForTimeout(300);
  const f = await p.locator('.fisa-doc').textContent();
  ok(/GRF \/ NSI\s*V\s*neregulă gravă/.test(f) && f.includes('Sigiliu aplicat'), 'fișa: GRF/NSI V + neregulă gravă + sigiliu');
  // V → IV: dispare
  await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
  await p.click('.grf-opts [data-val="IV"]'); await p.waitForTimeout(300);
  ok(await p.locator('.grf-field .grav-note').count() === 0 && await p.locator('.constr-head .pill-red:visible').count() === 1, 'IV → avertizarea GRF dispare (rămâne doar „instalație lipsă”)');
  await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
  ok(/Nu mai e GRF\/NSI V peste parter/.test(await p.locator('#ner-grav-grfV').innerText()), 'rândul constatat rămâne (date păstrate), marcat „Nu mai e GRF/NSI V”');
  ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
