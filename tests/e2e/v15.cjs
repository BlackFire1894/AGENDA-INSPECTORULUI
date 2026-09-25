const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
(async () => {
  const b = await chromium.launch();
  const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true, permissions: ['clipboard-read', 'clipboard-write'] });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.waitForTimeout(300);
    await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    // neregulă veche automată în Panou (Școala: d la ambele controale)
    ok((await p.locator('#sec-fines .item', { hasText: 'Școala' }).innerText()).includes('Neregulă veche'), 'Panou: marcaj neregulă veche');
    await p.click('#sec-fines .item:has-text("Școala")'); await p.waitForTimeout(600);
    ok(await p.locator('#ner-d .pill-veche').count() === 1 && await p.locator('#ner-d.is-veche').count() === 1, 'rândul d: indicator clar „Neregulă veche”');
    ok((await p.locator('#ner-d .veche-note').innerText()).includes('din istoric'), 'detaliu: detectată automat din istoric');
    // manual pe j
    await p.click('#ner-j [data-path$=".vecheManual"]'); await p.waitForTimeout(300);
    ok(await p.locator('#ner-j .pill-veche').count() === 1, 'bifă manuală „Neregulă veche”');
    const id = p.url().split('/')[5];
    await p.screenshot({ path: `${S}/v15-${ori}-veche.png` });
    // termen în zi nelucrătoare: aleg data amenzii astfel încât +15 să fie sâmbătă, în ultimele 10 zile
    let dd; for (let k = 0; k < 14; k++) { const x = new Date(); x.setDate(x.getDate() - k); const y = new Date(x); y.setDate(y.getDate() + 15); if (y.getDay() === 6) { dd = iso(x); break; } }
    await p.locator('#ner-d [data-bind$=".amenda.data"]').fill(dd); await p.locator('#ner-d [data-bind$=".amenda.data"]').dispatchEvent('change'); await p.waitForTimeout(400);
    ok((await p.locator('#ner-d .nelucr-warn').innerText()).includes('cade sâmbătă — următoarea zi lucrătoare: luni,') && (await p.locator('#ner-d .nelucr-warn').innerText()).includes('verificați prelungirea'), `avertizare termen sâmbătă (amendă din ${dd})`);
    // text PV
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(300);
    const txt = await p.locator('.pv-text').inputValue();
    ok(/1\. Construcția funcționează fără ASI[^\n]*Sala de sport \(neregulă veche\)\n2\. Lucrări de extindere[^\n]*\n3\. Stingătoare expirate – construcția: Corp A.*neregulă veche; sancționat cu amendă Seria DB nr\. 0012345/.test(txt), 'text PV: neregulă, construcție, veche, amendă');
    ok(/Acte de autoritate și evidențe lipsă:/.test(txt), 'text PV: acte lipsă');
    await p.click('[data-pv="copy"]'); await p.waitForTimeout(200);
    ok((await p.evaluate(() => navigator.clipboard.readText())) === txt, 'Copiază → clipboard');
    await p.click('[data-opt="doarNetrecute"]'); await p.waitForTimeout(100);
    { const t2 = await p.locator('.pv-text').inputValue(); ok(!/Stingătoare expirate|EXIT defect/.test(t2) && /Acte de autoritate/.test(t2), 'filtru doar netrecute: dispar cele trecute în PV'); }
    await p.screenshot({ path: `${S}/v15-${ori}-pv.png` });
    await p.click('.modal [data-act="modal-close"]'); await p.waitForTimeout(200);
    // marchează trecute: la spital (q netrecut)
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Spitalul'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    const sid = p.url().split('/')[5];
    await p.click('[data-act="pv-text"]'); await p.waitForTimeout(200);
    await p.click('[data-opt="doarNetrecute"]'); await p.waitForTimeout(100);
    ok((await p.locator('.pv-text').inputValue()).includes('Hext nefuncțional'), 'netrecute: Hext nefuncțional');
    await p.click('[data-pv="mark"]'); await p.waitForTimeout(300);
    await p.click('.modal [data-act="modal-close"]'); await p.waitForTimeout(200);
    await p.goto(`http://localhost:8080/#/control/${sid}/nereguli`); await p.reload(); await p.waitForTimeout(400);
    ok(await p.locator('#ner-q [data-path$=".inPV"].on').count() === 1, 'Marchează-le trecute în PV → salvat');
    // fișa
    await p.goto(`http://localhost:8080/#/fisa/${sid}`); await p.waitForTimeout(400);
    const f = await p.locator('.fisa-doc').textContent();
    ok(f.includes('Fișa controlului') && f.includes('Pavilion central') && f.includes('Acte de autoritate') && f.includes('Hext nefuncțional') && f.includes('Seria DB nr. 0012377'), 'fișa: date, construcții, acte, nereguli, amendă');
    ok(await p.locator('[data-act="fisa-print"]').count() === 1 && await p.locator('[data-act="fisa-share"]').count() === 1, 'butoane Tipărește / Partajează');
    await p.screenshot({ path: `${S}/v15-${ori}-fisa.png` });
    if (ori === 'land') {
      await p.emulateMedia({ media: 'print' });
      await p.screenshot({ path: `${S}/v15-print.png`, fullPage: true });
      const pdf = await p.pdf({ format: 'A4', printBackground: true });
      require('fs').writeFileSync(`${S}/fisa.pdf`, pdf);
      ok(pdf.length > 20000, `PDF generat din tipărire (${Math.round(pdf.length / 1024)} KB)`);
      ok(await p.locator('.sidebar').isHidden() && await p.locator('.fisa-actions').isHidden(), 'la tipărire: fără meniu și butoane');
      await p.emulateMedia({ media: 'screen' });
    }
    // Localitate: fișa are Planuri/PC și adăpost
    await p.goto('http://localhost:8080/#/istoric'); await p.fill('[data-search="hist"]', 'Valea Mare'); await p.waitForTimeout(200);
    await p.click('#hist-list .ctl-row'); await p.waitForTimeout(300);
    await p.goto(`http://localhost:8080/#/fisa/${p.url().split('/')[5]}`); await p.waitForTimeout(300);
    const fl = await p.locator('.fisa-doc').textContent();
    ok(fl.includes('Planuri și SVSU') && fl.includes('Protecție civilă') && /Adăpost de protecție civilă:\s*NU/.test(fl), 'fișa localitate: Planuri, PC, adăpost');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors');
  await b.close();
})();
