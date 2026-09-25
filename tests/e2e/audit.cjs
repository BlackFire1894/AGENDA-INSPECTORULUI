// Audit final: toate ecranele și taburile tuturor controalelor, 3 mărimi × 2 orientări × 2 teme;
// erori JS, scroll orizontal, text tăiat, ținte de atingere, câmpuri < 16px; plus date vechi și ciclu backup.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const S = process.argv[2];
const problems = []; let checks = 0;
(async () => {
  const b = await chromium.launch();
  for (const scheme of ['light', 'dark']) for (const [ori, vp] of [['L', { width: 1180, height: 820 }], ['P', { width: 820, height: 1180 }]]) for (const size of ['mare', 'mediu', 'mic']) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true, colorScheme: scheme });
    const p = await ctx.newPage();
    const errs = []; p.on('pageerror', (e) => errs.push(e.message)); p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
    await p.goto('http://localhost:8080/'); await p.evaluate((s) => localStorage.setItem('agenda-font', s), size); await p.reload();
    await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    const ids = await p.evaluate(() => new Promise((res) => { const r = indexedDB.open('agenda-inspectorului'); r.onsuccess = () => { const q = r.result.transaction('controls').objectStore('controls').getAll(); q.onsuccess = () => res(q.result.map((c) => [c.id, c.tip])); }; }));
    const routes = ['#/panou', '#/obiective', '#/calendar', '#/istoric', '#/setari', '#/ghid'];
    for (const [id, tip] of ids) {
      for (const t of (tip === 'LOCALITATE' ? ['obiectiv', 'acte', 'planuri', 'pc', 'nereguli'] : ['obiectiv', 'acte', 'nereguli'])) routes.push(`#/control/${id}/${t}`);
      routes.push(`#/fisa/${id}`);
    }
    const oid = await p.evaluate(() => document.querySelector('a.obj-card')?.getAttribute('href'));
    for (const r of routes) {
      await p.goto(`http://localhost:8080/${r}`); await p.waitForTimeout(120);
      const res = await p.evaluate(() => {
        const out = [];
        if (document.documentElement.scrollWidth > innerWidth + 1) out.push(`scroll orizontal ${document.documentElement.scrollWidth - innerWidth}px`);
        document.querySelectorAll('#main button, #main a.btn, #main .icon-btn, #main .ed-tab, #main .toggle, #main .chip-btn, #main select, #main .todo-item').forEach((el) => {
          const rc = el.getBoundingClientRect();
          if (!rc.width || getComputedStyle(el).visibility === 'hidden' || el.closest('.fisa-doc')) return;
          // ținta reală de atingere: include extinderea prin ::after (hit-test, nu doar dreptunghiul vizibil)
          const reach = (vert) => { el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' }); const r2 = el.getBoundingClientRect(); const n = []; const c = vert ? r2.left + r2.width / 2 : r2.top + r2.height / 2; const a = vert ? r2.top : r2.left; const L = vert ? r2.height : r2.width;
            for (let d = -12; d <= L + 12; d++) { const x = vert ? c : a + d; const y = vert ? a + d : c; if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) { n.push(d >= 0 && d < L ? 1 : 0); continue; } const h = document.elementFromPoint(x, y); n.push(h && (h === el || el.contains(h)) ? 1 : 0); }
            return n.lastIndexOf(1) - n.indexOf(1) + 1; };
          const H = rc.height < 43.5 ? reach(true) : rc.height; const W = rc.width < 43.5 ? reach(false) : rc.width;
          if (H < 43.5 || W < 43.5) out.push(`țintă mică ${el.className || el.tagName} ${Math.round(W)}x${Math.round(H)} (vizibil ${Math.round(rc.width)}x${Math.round(rc.height)})`);
        });
        document.querySelectorAll('#main input:not([type=date]):not([type=file]), #main textarea, #main select').forEach((el) => {
          if (parseFloat(getComputedStyle(el).fontSize) < 16) out.push(`câmp < 16px (${el.className})`);
        });
        document.querySelectorAll('#main .btn, #main .pill, #main .tab-txt b, #main .tab-txt small, #main .segmented button, #main .ok-btn, #main .nok-btn, #main .cat-title, #main .todo-item, #main .kpi-label, #main h1').forEach((el) => {
          if (el.scrollWidth > el.clientWidth + 2) out.push(`text tăiat: ${el.textContent.trim().slice(0, 28)}`);
        });
        const h1 = document.querySelector('.ed-title h1');
        if (h1 && h1.getBoundingClientRect().height / parseFloat(getComputedStyle(h1).lineHeight) > 2.2) out.push('titlu înghesuit');
        return [...new Set(out)];
      });
      checks++;
      res.forEach((x) => problems.push(`${scheme} ${ori} ${size} ${r.replace(/[a-z0-9]{12,}/, 'X')}: ${x}`));
    }
    if (oid) { await p.goto(`http://localhost:8080/${oid}`); await p.waitForTimeout(100); checks++; }
    if (size === 'mare') for (const r of ['#/panou', ids[2] && `#/control/${ids[2][0]}/nereguli`].filter(Boolean)) {
      await p.goto(`http://localhost:8080/${r}`); await p.waitForTimeout(150);
      await p.screenshot({ path: `${S}/audit-${scheme}-${ori}-${r.split('/')[1]}.png` });
    }
    errs.forEach((e) => problems.push(`${scheme} ${ori} ${size}: EROARE JS ${e}`));
    await ctx.close();
  }
  // Date vechi (schema 1, fără câmpurile noi) + ciclu export → ștergere → import
  const ctx = await b.newContext({ viewport: { width: 1180, height: 820 }, serviceWorkers: 'block', acceptDownloads: true });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('http://localhost:8080/');
  const v1 = { app: 'agenda-inspectorului', schema: 1, controls: [{ id: 'old1', objectiveId: 'ob1', tip: 'OPEC', denumire: 'Control vechi v1.0', dataInceput: '2025-05-10', dataIncheiere: '2025-05-10',
    constructii: [{ id: 'k1', denumire: 'Corp', dotari: { hidInt: { v: 'NU', obs: '' } } }], acte: { ctpsi: { status: 'ok', obs: '' } },
    nereguli: [{ key: 'd', status: 'nok', obs: 'vechi', inPV: true, amenda: { aplicata: true, data: '', suma: '300', achitata: false, dataAchitare: '' } }] }] };
  fs.writeFileSync(`${S}/v1.json`, JSON.stringify(v1));
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  await p.setInputFiles('[data-import]', `${S}/v1.json`); await p.waitForTimeout(200); await p.click('[data-mode="merge"]'); await p.waitForTimeout(300);
  for (const t of ['obiectiv', 'acte', 'nereguli']) { await p.goto(`http://localhost:8080/#/control/old1/${t}`); await p.waitForTimeout(200); }
  const g1 = await p.locator('#ner-lipsa-hidInt').count(); checks++;
  // v1.12: control încheiat în v1 → păstrează lista de atunci (fără rândurile G, apărute în v1.7)
  if (g1) problems.push('date v1: control încheiat, dar a primit rânduri apărute după încheiere (G1)');
  await p.goto('http://localhost:8080/#/fisa/old1'); await p.waitForTimeout(200); checks++;
  await p.goto('http://localhost:8080/'); await p.click('[data-act="demo-load"] >> nth=0').catch(() => {}); await p.waitForTimeout(300);
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  const before = await p.evaluate(() => new Promise((res) => { const r = indexedDB.open('agenda-inspectorului'); r.onsuccess = () => { const q = r.result.transaction('controls').objectStore('controls').getAll(); q.onsuccess = () => res(q.result); }; }));
  const [dl] = await Promise.all([p.waitForEvent('download'), p.click('[data-act="backup-export"] >> nth=0')]);
  const path = `${S}/audit-backup.json`; await dl.saveAs(path);
  await p.click('#main [data-act="wipe"]'); await p.click('.modal [data-r="1"]'); await p.waitForTimeout(300);
  await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
  await p.setInputFiles('[data-import]', path); await p.waitForTimeout(200); await p.click('[data-mode="replace"]'); await p.waitForTimeout(300);
  const after = await p.evaluate(() => new Promise((res) => { const r = indexedDB.open('agenda-inspectorului'); r.onsuccess = () => { const q = r.result.transaction('controls').objectStore('controls').getAll(); q.onsuccess = () => res(q.result); }; }));
  const norm = (a) => JSON.stringify([...a].sort((x, y) => x.id.localeCompare(y.id)));
  checks++;
  if (norm(before) !== norm(after)) problems.push(`backup: datele diferă după export → ștergere → import (${before.length} vs ${after.length})`);
  errs.forEach((e) => problems.push(`import/backup: EROARE JS ${e}`));
  await b.close();
  console.log(`verificări de ecran: ${checks}`);
  console.log(problems.length ? `PROBLEME (${problems.length}):\n` + [...new Set(problems)].slice(0, 60).join('\n') : 'nicio problemă găsită');
})();
