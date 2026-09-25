// v1.18: planul lunar — activități în calendar, confirmarea în Panou, raportul lunar, backup
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  const ctx = await b.newContext({ viewport: { width: 820, height: 1180 }, serviceWorkers: 'block', acceptDownloads: true });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });          // joi, 15.10.2026
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(500);
  await p.addStyleTag({ content: '#toast{display:none!important}' });
  ok(await p.locator('#sec-act-conf .act-item').count() === 1, 'Panou: activitatea demonstrativă de ieri, planificată → „de confirmat”');
  // activitate nouă, în trecut → implicit efectuată
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
  await p.click('.cal-cell[data-date="2026-10-06"]'); await p.waitForTimeout(200);
  await p.click('[data-act="act-new"]'); await p.waitForTimeout(200);
  ok(await p.locator('#af-stare [data-st="efectuat"].on').count() === 1, 'zi trecută: starea implicită „Efectuată”');
  await p.click('#af-tip [data-tip="alta"]'); await p.click('#af-save'); await p.waitForTimeout(200);
  ok(await p.locator('#af-err').isVisible() && /descrierea/.test(await p.locator('#af-err').innerText()), '„Altă activitate” fără descriere: mesaj de eroare');
  await p.click('#af-tip [data-tip="sedinta"]'); await p.fill('#af-desc', 'Analiza lunară'); await p.fill('#af-ora', '10:00');
  await p.click('#af-save'); await p.waitForTimeout(300);
  ok(/✓ Ședință: Analiza lunară/.test(await p.locator('.cal-cell[data-date="2026-10-06"]').innerText()), 'calendar: activitatea efectuată apare în zi');
  ok(/Analiza lunară/.test(await p.locator('.day-panel .act-list').innerText()), 'ziua selectată: lista activităților');
  // planificată ieri → de confirmat; Efectuată o scoate
  await p.click('.cal-cell[data-date="2026-10-13"]'); await p.waitForTimeout(200);
  await p.click('[data-act="act-new"]'); await p.waitForTimeout(200);
  await p.click('#af-tip [data-tip="instruire"]'); await p.fill('#af-desc', 'Pregătire'); await p.click('#af-stare [data-st="planificat"]');
  await p.click('#af-save'); await p.waitForTimeout(300);
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(300);
  ok(await p.locator('#sec-act-conf .act-item').count() === 2, 'Panou: două de confirmat');
  await p.locator('#sec-act-conf .act-item:has-text("Pregătire") [data-val="efectuat"]').click(); await p.waitForTimeout(300);
  ok(await p.locator('#sec-act-conf .act-item').count() === 1, 'Efectuată → iese din „de confirmat”');
  // Reprogramează → mâine
  await p.click('#sec-act-conf [data-act="act-reprog"]'); await p.waitForTimeout(200);
  await p.fill('#af-data', '2026-10-16'); await p.click('#af-save'); await p.waitForTimeout(300);
  ok(await p.locator('#sec-act-conf').count() === 0, 'Reprogramată pe mâine → nimic de confirmat');
  // raportul lunar: cifrele corespund datelor (citite prin backup)
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(300);
  const [dl] = await Promise.all([p.waitForEvent('download'), p.click('[data-act="backup-export"]:visible')]);
  const data = JSON.parse(fs.readFileSync(await dl.path(), 'utf8'));
  ok(Array.isArray(data.activitati) && data.activitati.length === 7, `backup: conține activitățile (${data.activitati?.length})`);
  const inOct = (a) => a.data.slice(0, 7) <= '2026-10' && (a.dataSfarsit || a.data).slice(0, 7) >= '2026-10';
  const ef = data.activitati.filter((a) => inOct(a) && a.stare === 'efectuat').length;
  const pl = data.activitati.filter((a) => inOct(a) && a.stare === 'planificat').length;
  await p.goto('http://localhost:8080/#/luna/2026-10'); await p.waitForTimeout(400);
  const sum = await p.locator('.f-sum > div').allInnerTexts();
  ok(sum[3].startsWith(`${ef}\n`) && sum[4].startsWith(`${pl}\n`), `raport: ${ef} efectuate, ${pl} planificate (${sum[3].replace(/\n/g, ' ')} | ${sum[4].replace(/\n/g, ' ')})`);
  ok(/Ședință: Analiza lunară/.test(await p.locator('.fisa-doc').innerText()), 'raport: lista zi cu zi');
  await p.screenshot({ path: `${S}/activitati-raport.png`, fullPage: true });
  // backup dus-întors: Înlocuiește tot păstrează activitățile
  const path = `${S}/activitati-backup.json`; fs.writeFileSync(path, JSON.stringify(data));
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  p.once('dialog', (d) => d.accept());
  await p.click('[data-act="wipe"]'); await p.waitForTimeout(200); await p.click('.modal .btn-danger').catch(() => {}); await p.waitForTimeout(300);
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  await p.setInputFiles('[data-import]', path); await p.waitForTimeout(200);
  ok(/7<\/b> activități|și 7 activități/.test(await p.locator('.modal').innerHTML()) || /7 activități/.test(await p.locator('.modal').innerText()), 'import: arată activitățile din fișier');
  await p.click('[data-mode="replace"]'); await p.waitForTimeout(400);
  await p.goto('http://localhost:8080/#/calendar'); await p.waitForTimeout(300);
  ok(/Analiza lunară/.test(await p.locator('.cal-cell[data-date="2026-10-06"]').innerText()), 'după import: activitățile revin');
  // ștergerea datelor demonstrative ia și activitățile demonstrative
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  await p.click('[data-act="demo-remove"]'); await p.waitForTimeout(200); await p.click('.modal .btn-danger').catch(() => {}); await p.waitForTimeout(400);
  await p.goto('http://localhost:8080/#/luna/2026-10'); await p.waitForTimeout(300);
  const t = await p.locator('.fisa-doc').innerText();
  ok(/Analiza lunară/.test(t) && !/Pregătire profesională lunară|Rapoarte și corespondență/.test(t), 'ștergerea demo: rămân doar activitățile proprii');
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
