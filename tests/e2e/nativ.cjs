// v1.24: puntea spre aplicația nativă iOS — simulată în Chromium: canalul webkit.messageHandlers.agenda
// și scriptul injectat de aplicație (extras din ios/Agenda/Punte.swift, ca testul să urmeze codul real)
const { chromium } = require('/opt/node22/lib/node_modules/playwright'); const fs = require('fs'); const path = require('path');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const swift = fs.readFileSync(path.join(__dirname, '../../ios/Agenda/Punte.swift'), 'utf8');
const i = swift.indexOf('"""') + 3; const injectat = swift.slice(i, swift.indexOf('"""', i));
(async () => {
  const b = await chromium.launch(); const errs = [];
  // 1) în browser (fără aplicația nativă): nu se trimite nimic, nu apare nicio eroare
  {
    const p = await (await b.newContext({ serviceWorkers: 'block' })).newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(1500);
    ok(await p.evaluate(() => !window.webkit && !window.AGENDA_NATIV), 'în Safari: fără punte (aplicația se comportă ca până acum)');
  }
  // 2) în aplicația nativă
  const ctx = await b.newContext({ viewport: { width: 1180, height: 820 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
  await p.addInitScript({ content: `window.__m = []; window.webkit = { messageHandlers: { agenda: { postMessage: (m) => window.__m.push(JSON.parse(JSON.stringify(m))) } } };\n${injectat}` });
  await p.clock.install({ time: new Date(2026, 9, 15, 9, 0) });
  await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(2000);
  const stari = (await p.evaluate(() => window.__m)).filter((x) => x.tip === 'stare');
  const s = stari[stari.length - 1]?.stare;
  ok(!!s && s.v === 1 && s.azi === '2026-10-15' && s.zile.length === 21, `stare trimisă (v1, azi, 21 de zile) — ${stari.length} mesaj(e) după pornire`);
  await p.goto('http://localhost:8080/#/panou'); await p.waitForTimeout(400);
  const kpi = await p.$$eval('.kpi .kpi-num', (e) => e.map((x) => +x.textContent));   // amenzi, neîncheiate, ASI, de încărcat, PV
  const z = s.zile[0];
  ok(JSON.stringify(kpi) === JSON.stringify([z.amenziActive, z.neincheiate, z.asi, z.deIncarcat, z.netrecute]), `cifrele widgetului = casetele Panoului (${kpi.join(', ')})`);
  ok(s.notificari.length > 0 && s.notificari.length <= 60 && s.notificari.every((n) => /^agenda-/.test(n.id) && n.data >= s.azi && /^\d\d:\d\d$/.test(n.ora)), `${s.notificari.length} notificări, toate în viitor, cu id „agenda-…”`);
  ok(s.urmatoare.every((t, k, a) => !k || a[k - 1].data <= t.data), 'termenele următoare, în ordinea datei');
  // o modificare → stare nouă
  await p.evaluate(() => { window.__m = []; });
  await p.click('[data-act="sarbatori-ok"]').catch(() => {});
  const id = await p.evaluate(async () => { const { state } = await import('./js/state.js'); return state.controls[0].id; });
  await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(400);
  await p.fill('[data-bind="denumire"]', 'Obiectiv redenumit'); await p.waitForTimeout(2500);
  ok((await p.evaluate(() => window.__m)).some((x) => x.tip === 'stare'), 'după o modificare salvată, aplicația nativă primește cifrele din nou');
  // partajarea (backup) și tipărirea trec prin iOS
  await p.evaluate(() => { window.__m = []; });
  await p.click('[data-act="backup-export"]:visible'); await p.waitForTimeout(800);
  const sh = (await p.evaluate(() => window.__m)).find((x) => x.tip === 'share');
  ok(sh && sh.fisiere.length === 1 && /backup.*\.json$/.test(sh.fisiere[0].nume) && JSON.parse(Buffer.from(sh.fisiere[0].date, 'base64').toString('utf8')).controls.length > 0, 'Backup rapid → fișierul ajunge la fereastra de partajare iOS, întreg');
  await p.goto(`http://localhost:8080/#/fisa/${id}`); await p.waitForTimeout(400);
  await p.evaluate(() => { window.__m = []; }); await p.click('[data-act="fisa-print"]'); await p.waitForTimeout(300);
  ok((await p.evaluate(() => window.__m)).some((x) => x.tip === 'print'), 'Tipărește / PDF → tipărirea iOS');
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
