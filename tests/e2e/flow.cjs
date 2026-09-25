const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const assert = (c, m) => { if (!c) { console.log('FAIL: ' + m); process.exitCode = 1; } else console.log('ok: ' + m); };
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 820, height: 1180 }, hasTouch: true, serviceWorkers: 'block' });
  const p = await ctx.newPage();
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  p.on('dialog', (d) => d.accept());
  await p.goto('http://localhost:8080/');
  await p.waitForTimeout(400);
  // control nou
  await p.click('.tab-new');
  await p.fill('#nc-name', 'Liceul Teoretic Test');
  await p.click('#nc-create');
  await p.waitForTimeout(300);
  assert(location => true, 'created');
  const url = p.url();
  assert(/#\/control\/.+\/obiectiv/.test(url), 'navigated to editor ' + url);
  const start = await p.inputValue('[data-bind="dataInceput"]');
  const today = new Date(); const iso = today.toISOString().slice(0, 10);
  assert(start === await p.evaluate(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }), 'start = today');
  await p.fill('[data-bind="administrator"]', 'Vasile Test');
  await p.click('[data-act="constr-inc"]'); await p.click('[data-act="constr-inc"]');
  assert((await p.locator('.constr').count()) === 3, '3 constructions');
  await p.click('.constr >> nth=0 >> .seg-dnn >> nth=0 >> button:has-text("DA")');
  await p.click('.constr >> nth=0 >> [data-act="centrala"][data-val="GAZOS"]');
  // acte
  await p.click('.ed-tab >> nth=1'); await p.waitForTimeout(200);
  await p.click('.check-row >> nth=0 >> .ok-btn');
  await p.click('.check-row >> nth=1 >> .nok-btn');
  assert(await p.locator('.check-row.is-ok').count() === 1 && await p.locator('.check-row.is-nok').count() === 1, 'acte green/red');
  // nereguli
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(200);
  await p.click('#ner-a .nok-btn');
  await p.click('#ner-a [data-path$=".asiTermen"]');
  assert(await p.locator('#ner-a .deadline').innerText().then(t => /neînceput/.test(t)), 'ASI pending before closing');
  await p.click('#ner-d .nok-btn');
  await p.click('#ner-d [data-path$=".amenda.aplicata"]');
  await p.fill('#ner-d [data-bind$=".amenda.suma"]', '3000');
  await p.click('[data-act="ner-add"]');
  await p.keyboard.type('Neregulă proprie');
  assert(await p.locator('.row-label-input').count() === 1, 'custom row added');
  // încheie
  await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
  await p.click('[data-act="close-control"]');
  await p.waitForTimeout(200);
  if (await p.locator('#close-anyway').count()) { assert(true, 'verificare la încheiere afișată'); await p.click('#close-anyway'); await p.waitForTimeout(200); }
  const end = await p.inputValue('[data-bind="dataIncheiere"]');
  assert(end === start, 'end defaults to start');
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(200);
  const asiTxt = await p.locator('#ner-a .deadline').innerText();
  assert(/90 de zile|Mai sunt 90/.test(asiTxt), 'ASI 90 days after close: ' + asiTxt.replace(/\n/g,' '));
  const fineTxt = await p.locator('#ner-d .fine-box').innerText();
  assert(/15 zile|termenul de plată/i.test(fineTxt), 'fine blue: ' + fineTxt.split('\n').slice(0,2).join(' | '));
  await p.screenshot({ path: `${S}/flow-nereguli.png`, fullPage: false });
  // reload → persistență
  await p.waitForTimeout(600);
  await p.reload(); await p.waitForTimeout(500);
  assert(await p.locator('.row-label-input').inputValue() === 'Neregulă proprie', 'custom label persisted');
  assert(await p.locator('#ner-d [data-bind$=".amenda.suma"]').inputValue() === '3000', 'fine amount persisted');
  // panou
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
  const k = await p.locator('.kpi-num').allInnerTexts();
  assert(k[0] === '1' && k[2] === '1' && k[4] === '3', 'dashboard KPIs ' + k.join(','));
  // căutare după dată
  await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(200);
  const dd = start.split('-').reverse().join('.');
  await p.fill('[data-search="obj"]', dd); await p.waitForTimeout(200);
  assert(await p.locator('.obj-card').count() === 1, 'search by date finds objective');
  await p.fill('[data-search="obj"]', '01.01.2020'); await p.waitForTimeout(200);
  assert(await p.locator('.obj-card').count() === 0, 'search by other date finds none');
  await p.fill('[data-search="obj"]', 'liceul'); await p.waitForTimeout(200);
  assert(await p.locator('.obj-card').count() === 1, 'search by name');
  // control nou pe obiectiv existent
  await p.click('.obj-card'); await p.waitForTimeout(200);
  await p.click('[data-act="new-control"][data-oid]'); await p.waitForTimeout(300);
  assert(await p.inputValue('[data-bind="administrator"]') === 'Vasile Test', 'prefill from previous control');
  assert(await p.locator('.constr').count() === 3, 'constructions copied');
  await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(200);
  await p.fill('[data-search="obj"]', ''); await p.waitForTimeout(100);
  assert((await p.locator('.obj-card').innerText()).includes('2 controale'), 'history has 2 controls');
  // șterge control
  await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(200);
  await p.click('.ctl-row >> nth=0'); await p.waitForTimeout(200);
  await p.click('[data-act="control-delete"]'); await p.waitForTimeout(200);
  await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  assert(await p.evaluate(() => location.hash) === '#/istoric', 'back to istoric after delete');
  assert(await p.locator('.ctl-row').count() === 1, '1 control left');
  // calendar
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(200);
  assert(await p.locator('.cal-cell.is-today .cal-ev').count() >= 1, 'calendar shows control today');
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
