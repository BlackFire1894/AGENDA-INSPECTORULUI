const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await p.waitForTimeout(200);
    await p.fill('#nc-name', 'Pensiunea Test'); await p.click('#nc-create'); await p.waitForTimeout(400);
    const id = p.url().split('/')[5];
    ok(await p.locator('.dot-row:has-text("Detectori autonomi")').count() === 1, 'dotare nouă: Detectori autonomi');
    // nereguli noi mereu vizibile
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
    const labels = await p.locator('.ner-row .row-label').allInnerTexts();
    ok(['Planuri de evacuare neafișate corespunzător', 'Căi de evacuare blocate / obturate', 'Lipsă instrucțiuni de utilizare a echipamentelor de gătit', 'Lipsă instrucțiuni de comportare (turism)', 'Detector de gaz defect / inexistent'].every((t) => labels.includes(t)), 'cele 5 nereguli noi apar');
    ok(!labels.includes('Detectori autonomi nefuncționali') && !labels.includes('Ignifugare expirată'), 'af/ag ascunse fără DA la dotări');
    // DA la detectori și ignifugare
    await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
    await p.click('.dot-row:has-text("Detectori autonomi") button:has-text("DA")');
    await p.click('.dot-row:has-text("Ignifugare") button:has-text("DA")'); await p.waitForTimeout(200);
    // NU la hidranți interiori → avertizare
    await p.click('.dot-row:has-text("Hidranți interiori") button:has-text("NU")'); await p.waitForTimeout(300);
    ok((await p.locator('#toast').innerText()).includes('Neregulă gravă: lipsă hidranți interiori'), 'avertizare imediată la NU');
    ok(await p.locator('.dot-row.is-grav:has-text("Hidranți interiori")').count() === 1, 'rândul de dotare marcat roșu „Neregulă gravă”');
    ok((await p.locator('.constr-head').innerText()).includes('1 instalație lipsă'), 'antetul construcției: 1 instalație lipsă');
    ok(/gravă/.test(await p.locator('.todo .todo-item >> nth=0').innerText()), 'bara: neregula gravă pe primul loc');
    await p.screenshot({ path: `${S}/v17-${ori}-dotari.png` });
    // NEC nu e gravă
    await p.click('.dot-row:has-text("Sprinklere") button:has-text("NEC")'); await p.waitForTimeout(200);
    ok(await p.locator('.dot-row.is-grav').count() === 1, 'NEC nu e neregulă gravă');
    // din toast → Nereguli
    await p.click('.dot-row:has-text("Hidranți exteriori") button:has-text("NU")'); await p.waitForTimeout(300);
    await p.click('.toast-btn'); await p.waitForTimeout(600);
    ok(/\/nereguli\/lipsa-hidExt$/.test(p.url()), '„Vezi” din avertizare → neregula gravă');
    const cats = await p.locator('.cat-title .cat-name').allInnerTexts();
    ok(cats[0].startsWith('Instalații lipsă'), `primul grup: ${cats[0]}`);
    ok(await p.locator('#ner-lipsa-hidInt .row-idx').innerText() === 'G1' && await p.locator('#ner-lipsa-hidExt .row-idx').innerText() === 'G2', 'numerotare G1, G2');
    ok(/NU la dotări în:\s*Construcția 1/.test(await p.locator('#ner-lipsa-hidInt').innerText()), 'construcția cu NU afișată');
    const labels2 = await p.locator('.ner-row .row-label').allInnerTexts();
    ok(labels2.includes('Detectori autonomi nefuncționali') && labels2.includes('Ignifugare expirată'), 'af/ag apar după DA la dotări');
    await p.screenshot({ path: `${S}/v17-${ori}-nereguli.png` });
    // fișa: gravele apar și neverificate
    await p.goto(`http://localhost:8080/#/fisa/${id}`); await p.waitForTimeout(300);
    const f = await p.locator('.fisa-doc').textContent();
    ok(f.includes('Lipsă hidranți interiori') && f.includes('Neverificată — gravă'), 'fișa: nereguli grave, chiar neverificate');
    // lista controalelor: pill „nereguli grave”
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    ok((await p.locator('.ctl-row').innerText()).includes('2 nereguli grave'), 'Istoric: „2 nereguli grave”');
    // DA în loc de NU → rândul grav dispare (neverificat)
    await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(300);
    await p.click('.dot-row:has-text("Hidranți exteriori") button:has-text("DA")'); await p.waitForTimeout(200);
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
    ok(await p.locator('#ner-lipsa-hidExt').count() === 0, 'NU → DA: neregula gravă neverificată dispare');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
