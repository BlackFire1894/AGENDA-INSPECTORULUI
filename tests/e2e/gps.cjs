const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) {
  console.log('--', vp.width);
  const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block' });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.addInitScript(() => { const o = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation); window.__geo = 0; navigator.geolocation.getCurrentPosition = (...a) => { window.__geo++; return o(...a); }; navigator.geolocation.watchPosition = () => { window.__watch = 1; return 0; }; });
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
  await p.fill('#nc-name', 'Școala GPS'); await p.click('#nc-create'); await p.waitForTimeout(400);
  await p.fill('[data-bind$="adresa"]', 'Str. Libertății 12'); await p.fill('[data-bind$="localitate"]', 'Bistrița');
  await p.click('[data-act="constr-inc"]'); await p.waitForTimeout(300);
  await p.fill('.constr >> nth=1 >> .constr-name', 'Sala de sport'); await p.waitForTimeout(400);
  ok(await p.evaluate(() => window.__geo) === 0, 'nicio citire de poziție la deschidere');
  ok(await p.locator('.constr >> nth=0 >> .gps-cell.is-empty').innerText() === 'Necompletat', 'construcția 1: celulă Necompletat');
  ok(await p.locator('.constr >> nth=1 >> .gps-field').count() === 1, 'construcție nouă: deschisă, cu celula GPS');
  await p.click('.constr >> nth=1 >> [data-act="constr-toggle"]'); await p.waitForTimeout(300);
  ok(await p.locator('.constr >> nth=1 >> .gps-field').count() === 0, 'construcția 2 restrânsă');
  const todoTxt = await p.locator('.todo').innerText();
  // Refuz → prompt
  await p.click('.constr >> nth=0 >> button:has-text("Completează coordonatele")'); await p.waitForTimeout(800);
  const modal = await p.locator('.modal').innerText().catch(() => '');
  ok(/Activați localizarea/.test(modal) && /Site-uri Safari/.test(modal), 'refuzat → prompt „Activați localizarea”');
  await ctx.grantPermissions(['geolocation']); await ctx.setGeolocation({ latitude: 47.1335, longitude: 24.4966, accuracy: 12 });
  await p.click('#gps-retry'); await p.waitForTimeout(800);
  ok(await p.locator('.constr >> nth=0 >> .gps-coord').innerText() === '47.133500, 24.496600', 'construcția 1 completată');
  // „Ce mai ai de făcut” → Sala de sport (restrânsă) se deschide la coordonate
  await p.click('[data-act="todo-toggle"]'); await p.waitForTimeout(300);
  const item = p.locator('.todo-item:has-text("Coordonate GPS necompletate")');
  ok(await item.innerText() === 'Coordonate GPS necompletate: Sala de sport', `todo: ${await item.innerText()}`);
  await item.click(); await p.waitForTimeout(800);
  ok(await p.locator('.constr >> nth=1 >> .gps-field').isVisible(), 'todo deschide construcția 2 la coordonate');
  await ctx.setGeolocation({ latitude: 47.1341, longitude: 24.4972, accuracy: 350 });
  await p.click('.constr >> nth=1 >> button:has-text("Completează coordonatele")'); await p.waitForTimeout(800);
  ok(await p.locator('.constr >> nth=1 >> .gps-coord').innerText() === '47.134100, 24.497200', 'construcția 2 completată, separat');
  ok(await p.locator('.constr >> nth=1 >> .gps-warn').count() === 1, 'precizie slabă → avertizare');
  ok(await p.locator('.constr >> nth=0 >> .gps-coord').innerText() === '47.133500, 24.496600', 'construcția 1 neschimbată');
  ok(!/Coordonate GPS/.test(await p.locator('.todo').innerText()), 'todo: coordonatele nu mai apar');
  ok(await p.evaluate(() => window.__geo) === 3 && !(await p.evaluate(() => window.__watch)), 'exact 3 citiri, doar la apăsare; fără urmărire');
  await p.screenshot({ path: `gps-${vp.width}.png`, fullPage: false });
  const id = await p.evaluate(() => location.hash.split('/')[2]);
  await p.goto(`http://localhost:8080/#/fisa/${id}`); await p.waitForTimeout(400);
  const f = await p.locator('.fisa-doc').textContent();
  ok(f.includes('Str. Libertății 12') && f.includes('47.133500, 24.496600') && f.includes('47.134100, 24.497200'), 'fișa: adresă + coordonatele ambelor construcții');
  await p.goto('http://localhost:8080/#/obiective'); await p.waitForTimeout(300);
  await p.fill('input[type="search"]', 'bistrita'); await p.waitForTimeout(400);
  ok(/Școala GPS/.test(await p.locator('main').innerText()), 'căutare după localitate');
  await p.locator('text=Școala GPS').first().click(); await p.waitForTimeout(300);
  const og = await p.locator('.gps-list').innerText(); console.log(JSON.stringify(og)); await p.locator('.info-grid').screenshot({ path: 'og.png' });
  ok(/Construcția 1:\s*47\.133500, 24\.496600/.test(og) && /Sala de sport:\s*47\.134100, 24\.497200/.test(og), 'pagina obiectivului: coordonate pe construcții');
  await p.click('text=Control nou pe acest obiectiv'); await p.waitForTimeout(300);
  if (await p.locator('#nc-create').count()) { await p.click('#nc-create'); await p.waitForTimeout(400); }
  ok((await p.locator('.constr >> nth=0 >> .gps-coord').innerText().catch(() => '')) === '47.133500, 24.496600', 'control nou: coordonate preluate');
  ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'fără scroll orizontal');
  await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
