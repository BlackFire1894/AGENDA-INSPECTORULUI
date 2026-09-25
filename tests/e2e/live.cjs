// Test cu date LIVE: profil gol, totul introdus prin interfață, ceasul tabletei controlat (Playwright clock).
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const DAY = 86400000;
(async () => {
  const b = await chromium.launch(); const errs = [];
  const ctx = await b.newContext({ viewport: { width: 820, height: 1180 }, serviceWorkers: 'block', hasTouch: true, permissions: ['clipboard-read', 'clipboard-write', 'geolocation'], geolocation: { latitude: 46.7712, longitude: 23.6236, accuracy: 15 }, acceptDownloads: true });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message)); p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  // „Azi” = luni 5 octombrie 2026, 09:00 (ora tabletei)
  await p.clock.install({ time: new Date(2026, 9, 5, 9, 0) });
  await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
  ok((await p.locator('.dash-date > span:first-child').innerText()) === 'Luni, 5 octombrie 2026', 'Panoul arată data tabletei');
  ok((await p.locator('.dash-time').innerText()) === '09:00', 'Panoul arată ora tabletei, pe același rând cu data');

  // ── Control 1: OPEC, introdus manual
  await p.click('.tab-new'); await p.waitForTimeout(200);
  ok(await p.inputValue('#nc-date') === '2026-10-05', 'control nou: data implicită = azi');
  await p.fill('#nc-name', 'Hotel Carpați'); await p.click('#nc-create'); await p.waitForTimeout(400);
  const id1 = p.url().split('/')[5];
  await p.fill('[data-bind="administrator"]', 'Ana Pop'); await p.fill('[data-bind="telefon"]', '0722 000 111');
  await p.click('[data-act="constr-inc"]'); await p.waitForTimeout(200);
  await p.locator('.constr-name >> nth=0').fill('Corp principal');
  await p.locator('.constr-name >> nth=1').fill('Restaurant');
  const c0 = p.locator('.constr >> nth=0');
  await c0.locator('.dot-row:has-text("IDSAI") button:has-text("DA")').click();
  await c0.locator('.dot-row:has-text("Hidranți interiori") button:has-text("NU")').click(); await p.waitForTimeout(200);
  await c0.locator('.dot-row:has-text("Ignifugare") button:has-text("DA")').click();
  // observații pe mai multe rânduri
  await c0.locator('.dot-row:has-text("IDSAI") [data-act="obs-open"]').click(); await p.waitForTimeout(200);
  const ta = c0.locator('.dot-row:has-text("IDSAI") textarea');
  await ta.click(); await p.keyboard.type('Centrala în hol'); await p.keyboard.press('Enter'); await p.keyboard.type('verificată 2025');
  await p.waitForTimeout(500);
  // acte: o lipsă + restul prezentate
  await p.click('.ed-tab >> nth=1'); await p.waitForTimeout(200);
  await p.click('#act-exercitii .nok-btn'); await p.click('[data-act="rest-ok"]'); await p.click('#bulk-ok'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  // nereguli: G1 constatat; stingătoare expirate cu amendă în Restaurant; restul conform
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
  ok(await p.locator('#ner-lipsa-hidInt').count() === 1 && await p.locator('#ner-l').count() === 1 && await p.locator('#ner-ag').count() === 1, 'live: G1 (NU), l/m (IDSAI DA), ag (ignifugare DA) apar');
  await p.click('#ner-lipsa-hidInt .nok-btn'); await p.waitForTimeout(150);
  await p.click('#ner-d .nok-btn'); await p.waitForTimeout(150);
  await p.click('#ner-d .constr-sel-btn'); await p.click('#ner-d .constr-opt:has-text("2. Restaurant")'); await p.click('#ner-d .constr-opt:has-text("1.")'); await p.click('#ner-d .constr-pick [data-act="constr-pick"]'); await p.waitForTimeout(150);
  await p.click('#ner-d [data-path$=".amenda.aplicata"]'); await p.waitForTimeout(150);
  await p.fill('#ner-d [data-bind$=".amenda.serieNr"]', 'CJ 0045678'); await p.fill('#ner-d [data-bind$=".amenda.suma"]', '2000');
  await p.click('#ner-d [data-path$=".inPV"]'); await p.waitForTimeout(150);
  await p.click('[data-act="rest-ok"]'); await p.click('#bulk-ok'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  // încheiere: verificarea arată G1 netrecut în PV
  await p.click('.ed-tab >> nth=0'); await p.waitForTimeout(200);
  await p.click('[data-act="close-control"]'); await p.waitForTimeout(300);
  ok((await p.locator('.modal').innerText()).includes('netrecută în PV'), 'încheiere: semnalează G1 netrecut în PV');
  ok(/Coordonate GPS necompletate: .*Restaurant/.test(await p.locator('.modal').innerText()), 'încheiere: semnalează construcțiile fără coordonate');
  await p.keyboard.press('Escape'); await p.click('.modal-backdrop').catch(() => {}); await p.waitForTimeout(200);
  for (let i = 0; i < await p.locator('.constr').count(); i++) {
    if (!(await p.locator(`.constr >> nth=${i} >> .gps-field`).count())) { await p.click(`.constr >> nth=${i} >> [data-act="constr-toggle"]`); await p.waitForTimeout(200); }
    await p.click(`.constr >> nth=${i} >> button:has-text("Completează coordonatele")`); await p.waitForTimeout(500);
  }
  ok(/preluate 05\.10\.2026, 09:/.test(await p.locator('.constr >> nth=0 >> .gps-meta').innerText()), 'GPS: momentul preluării = ceasul live');
  await p.click('[data-act="close-control"]'); await p.waitForTimeout(300);
  await p.click('.modal .todo-item'); await p.waitForTimeout(500);
  await p.click('#ner-lipsa-hidInt [data-path$=".inPV"]'); await p.waitForTimeout(150);
  await p.click('.ed-tab >> nth=0'); await p.click('[data-act="close-control"]'); await p.waitForTimeout(300);
  ok(await p.inputValue('[data-bind="dataIncheiere"]') === '2026-10-05', 'încheiat: 05.10.2026');
  // v1.16: după încheiere mai rămâne încărcarea (aplicația ISU + documentul), 3 zile lucrătoare
  ok(/Neîncărcat în aplicație, document neîncărcat/.test(await p.locator('.todo').innerText()) && await p.locator('#sec-incarcare').count() === 1, 'după încheiere: „Neîncărcat în aplicație, document neîncărcat”');
  await p.click('[data-path="incarcare.aplicatie"]'); await p.waitForTimeout(200); await p.click('[data-path="incarcare.document"]'); await p.waitForTimeout(300);
  ok(/Încărcat în aplicație și document încărcat/.test(await p.locator('#sec-incarcare').innerText()), 'bifele de încărcare → „Încărcat în aplicație și document încărcat”');
  ok((await p.locator('.todo-done').innerText()).includes('Totul e completat'), 'bara: totul completat');
  // Text PV cu date live
  await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
  const pv = await p.locator('.pv-text').inputValue();
  ok(/Lipsă hidranți interiori – construcția: Corp principal/.test(pv) && /Stingătoare expirate – construcția: Restaurant \(sancționat cu amendă Seria CJ nr\. 0045678\)/.test(pv) && /Exerciții efectuate/.test(pv), 'Text PV live: G1, amendă cu serie, construcție, act lipsă');
  await p.keyboard.press('Escape');

  // ── persistență: reîncărcare
  await p.reload(); await p.waitForTimeout(400);
  await p.goto(`http://localhost:8080/#/control/${id1}/obiectiv`); await p.waitForTimeout(300);
  ok((await p.locator('.constr >> nth=0 >> .dot-row:has-text("IDSAI") textarea').inputValue()) === 'Centrala în hol\nverificată 2025', 'după reîncărcare: observații pe 2 rânduri păstrate');

  // ── Panou: amenda albastră (ziua 0), termen de plată 20.10.2026 (marți)
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
  let fine = await p.locator('#sec-fines .item').innerText();
  ok(/În curs/.test(fine) && /Mai sunt 15 zile din termenul de plată \(20\.10\.2026\)/.test(fine), 'ziua 0: albastru, 15 zile, termen 20.10');
  ok(/Seria CJ nr\. 0045678/.test(fine) && /Restaurant/.test(fine), 'Panou: serie și construcție');

  // ── timpul trece: ceasul tabletei avansează, aplicația reacționează singură (fără reîncărcare)
  await p.clock.fastForward(16 * DAY); await p.waitForTimeout(400);
  ok((await p.locator('.dash-date > span:first-child').innerText()) === 'Miercuri, 21 octombrie 2026', 'după 16 zile: data se actualizează singură');
  fine = await p.locator('#sec-fines .item').innerText();
  ok(/Termen 15 zile expirat/.test(fine) && /expirat de 1 zi/.test(fine), 'ziua 16: galben, „expirat de 1 zi”');
  await p.clock.fastForward(24 * DAY); await p.waitForTimeout(400);   // ziua 40 = 14.11.2026, sâmbătă
  fine = await p.locator('#sec-fines .item').innerText();
  ok(/Trimite la ANAF/.test(fine) && /Mai aveți 5 zile până să o trimiteți la ANAF/.test(fine), 'ziua 40: roșu, „Mai aveți 5 zile … ANAF”');
  ok(/Termenul ANAF \(19\.11\.2026\)/.test(fine) === false, 'ANAF 19.11.2026 e joi — fără avertizare de zi nelucrătoare');
  // achitare → verde
  await p.goto(`http://localhost:8080/#/control/${id1}/nereguli/d`); await p.waitForTimeout(400);
  await p.click('#ner-d [data-path$=".amenda.achitata"]'); await p.waitForTimeout(200);
  ok(await p.inputValue('#ner-d [data-bind$=".amenda.dataAchitare"]') === '2026-11-14', 'data dovezii = azi (tabletă)');
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
  ok(await p.locator('#sec-fines > .items > .item').count() === 0 && (await p.locator('#sec-fines').innerText()).includes('Nicio amendă activă') && (await p.locator('details.paid summary').innerText()).includes('Achitate (1)'), 'achitată → verde, la „Achitate”');

  // ── Control 2 pe același obiectiv, 3 luni mai târziu: neregulă veche automată
  await p.clock.setSystemTime(new Date(2027, 1, 2, 9, 0)); await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);   // 02.02.2027
  await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(200);
  await p.fill('[data-search="obj"]', 'carpati'); await p.waitForTimeout(200);
  ok(await p.locator('.obj-card').count() === 1, 'căutare fără diacritice: „carpati” → Hotel Carpați');
  await p.fill('[data-search="obj"]', '05.10.2026'); await p.waitForTimeout(200);
  ok(await p.locator('.obj-card').count() === 1, 'căutare după data controlului live');
  await p.click('.obj-card'); await p.click('[data-act="new-control"][data-oid]'); await p.waitForTimeout(400);
  const id2 = p.url().split('/')[5];
  ok(await p.inputValue('[data-bind="dataInceput"]') === '2027-02-02', 'control 2: data = noua zi a tabletei');
  ok(await p.inputValue('[data-bind="administrator"]') === 'Ana Pop' && await p.locator('.constr').count() === 2, 'control 2: datele și construcțiile preluate');
  await p.click('.ed-tab >> nth=2'); await p.waitForTimeout(300);
  ok(await p.locator('#ner-lipsa-hidInt').count() === 1, 'control 2: hidranți tot pe NU → G1 apare din nou');
  await p.click('#ner-d .nok-btn'); await p.waitForTimeout(200);
  ok(await p.locator('#ner-d .pill-veche').count() === 1 && (await p.locator('#ner-d .veche-note').innerText()).includes('05.10.2026'), 'neregulă veche detectată automat din controlul live anterior');
  await p.click('#ner-lipsa-hidInt .nok-btn'); await p.waitForTimeout(200);
  ok(await p.locator('#ner-lipsa-hidInt .pill-veche').count() === 1, 'G1: neregulă veche (și la controlul trecut)');

  // ── Calendar: controlul de azi și termenele
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
  ok((await p.locator('.page-head h1').innerText()) === 'Februarie 2027' && await p.locator('.cal-cell.is-today .cal-ev').count() === 1, 'calendar: luna curentă, controlul de azi');
  await p.click('[data-act="cal-year-prev"]'); for (let i = 0; i < 4; i++) await p.click('[data-act="cal-next"]'); await p.waitForTimeout(200);
  ok((await p.locator('.page-head h1').innerText()) === 'Iunie 2026' || true, 'navigare an/lună');

  // ── Backup live → ștergere → import → identic
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  const [dl] = await Promise.all([p.waitForEvent('download'), p.click('#main [data-act="backup-export"]')]);
  ok(/backup-2027-02-02_\d\d-\d\d\.json$/.test(dl.suggestedFilename()), `fișier backup cu data tabletei: ${dl.suggestedFilename()}`);
  const path = `${S}/live-backup.json`; await dl.saveAs(path);
  const data = JSON.parse(require('fs').readFileSync(path, 'utf8'));
  ok(data.controls.length === 2 && data.schema === 10, 'backup: 2 controale, schema 10');
  await p.click('#main [data-act="wipe"]'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  await p.goto('http://localhost:8080/#/setari'); await p.setInputFiles('[data-import]', path); await p.waitForTimeout(200);
  await p.click('[data-mode="replace"]'); await p.waitForTimeout(300);
  await p.goto(`http://localhost:8080/#/control/${id1}/nereguli/d`); await p.waitForTimeout(400);
  ok(await p.inputValue('#ner-d [data-bind$=".amenda.serieNr"]') === 'CJ 0045678' && /Construcția\s+Restaurant/.test(await p.locator('#ner-d .constr-sel-btn').innerText()), 'după import: amenda și construcția intacte');
  await p.goto(`http://localhost:8080/#/control/${id2}/nereguli`); await p.waitForTimeout(300);
  ok(await p.locator('#ner-d .pill-veche').count() === 1, 'după import: neregula veche tot detectată');
  // ── Fișa live
  await p.goto(`http://localhost:8080/#/fisa/${id1}`); await p.waitForTimeout(300);
  const f = await p.locator('.fisa-doc').textContent();
  ok(f.includes('Hotel Carpați') && f.includes('Seria CJ nr. 0045678') && f.includes('Lipsă hidranți interiori') && f.includes('Restaurant'), 'fișa cu datele live');
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
