// v1.25.1: coordonatele când GPS-ul precis nu răspunde (poziția aproximativă, apoi fereastra cu variantele)
// și motivul exact în fereastra „Activați localizarea”
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
// răspunsurile simulate ale localizării, pe rând: {err: cod} sau {acc: metri}
const simulare = (raspunsuri, standalone = false) => `
  window.__cereri = []; const lista = ${JSON.stringify(raspunsuri)};
  ${standalone ? "Object.defineProperty(navigator, 'standalone', { value: true });" : ''}
  navigator.geolocation.getCurrentPosition = (ok, err, opt) => {
    window.__cereri.push(opt); const r = lista.shift() || { err: 2 };
    setTimeout(() => r.err ? err({ code: r.err, message: 'simulat' }) : ok({ coords: { latitude: 45.65, longitude: 25.6, accuracy: r.acc } }), 50);
  };`;
(async () => {
  const b = await chromium.launch(); const errs = [];
  const porneste = async (raspunsuri, standalone) => {
    const ctx = await b.newContext({ viewport: { width: 428, height: 926 }, isMobile: true, hasTouch: true, serviceWorkers: 'block' });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.addInitScript({ content: simulare(raspunsuri, standalone) });
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(300);
    await p.fill('#nc-name', 'Test GPS'); await p.click('#nc-create'); await p.waitForTimeout(500);
    await p.addStyleTag({ content: '#toast{visibility:visible}' });
    await p.click('[data-act="gps-get"]'); await p.waitForTimeout(600);
    return { p, ctx };
  };
  // 1) fără semnal GPS la timp → a doua cerere, aproximativă → coordonate cu „precizie slabă”
  { const { p, ctx } = await porneste([{ err: 3 }, { acc: 900 }]);
    const cereri = await p.evaluate(() => window.__cereri);
    ok(cereri.length === 2 && cereri[0].enableHighAccuracy === true && cereri[1].enableHighAccuracy === false, 'fără semnal precis: se cere poziția aproximativă');
    ok(/45\.650000, 25\.600000/.test(await p.locator('.gps-field').first().innerText()), 'poziția aproximativă e salvată');
    ok(await p.locator('.gps-field .gps-warn').count() === 1 && /precizie slabă/.test(await p.locator('#toast').innerText()), 'marcată „precizie slabă”, cu îndemnul „Actualizează” afară');
    await ctx.close(); }
  // 2) poziție indisponibilă (cod 2) → aproximativ reușește
  { const { p, ctx } = await porneste([{ err: 2 }, { acc: 60 }]);
    ok(/45\.650000/.test(await p.locator('.gps-field').first().innerText()) && await p.locator('.modal').count() === 0, 'cod 2 (fără poziție precisă): poziția aproximativă, fără fereastra de permisiuni');
    await ctx.close(); }
  // 3) nici aproximativ la timp → fereastra cu variantele (coordonatele de mână), nu pașii de permisiune
  { const { p, ctx } = await porneste([{ err: 3 }, { err: 3 }]);
    const m = await p.locator('.modal').innerText().catch(() => '');
    ok(/Nu s-a găsit semnal la timp/.test(m) && await p.locator('#gps-man-open').count() === 1 && !/Activați localizarea/.test(m) && !/45\.65/.test(await p.locator('.gps-field').first().innerText()),
      'fără niciun semnal: fereastra cu variantele (Introdu coordonatele), coordonatele rămân necompletate');
    await ctx.close(); }
  // 3b) fără poziție nici aproximativ (cod 2) → „Poziția nu a putut fi aflată”
  { const { p, ctx } = await porneste([{ err: 2 }, { err: 2 }]);
    ok(/Poziția nu a putut fi aflată/.test(await p.locator('.modal').innerText().catch(() => '')), 'cod 2 de două ori: „Poziția nu a putut fi aflată”, cu variantele');
    await ctx.close(); }
  // 3c) refuz la a doua cerere → pașii de permisiune
  { const { p, ctx } = await porneste([{ err: 3 }, { err: 1 }]);
    ok(/Activați localizarea/.test(await p.locator('.modal').innerText().catch(() => '')), 'refuz la cererea aproximativă: fereastra „Activați localizarea”');
    await ctx.close(); }
  // 4) permisiune refuzată → fereastra cu motivul exact, o singură cerere
  { const { p, ctx } = await porneste([{ err: 1 }]);
    const m = await p.locator('.modal').innerText().catch(() => '');
    ok(/nu dă aplicației permisiunea de localizare/.test(m) && /Site-uri Safari/.test(m) && (await p.evaluate(() => window.__cereri.length)) === 1, 'refuz: fereastra spune „nu dă aplicației permisiunea”, cu pașii');
    ok(!/refuz mai vechi/.test(m), 'în Safari (nu de pe ecranul principal): fără pasul cu iconița');
    await ctx.close(); }
  // 5) refuz în aplicația de pe ecranul principal → și pasul cu iconița (după backup)
  { const { p, ctx } = await porneste([{ err: 1 }], true);
    const m = await p.locator('.modal').innerText().catch(() => '');
    ok(/refuz mai vechi/.test(m) && /Backup rapid/.test(m), 'de pe ecranul principal: pasul „ștergeți iconița și adăugați-o din nou”, după backup');
    await ctx.close(); }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
