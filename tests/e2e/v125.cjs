// v1.25: „De întrebat până la finalizarea controlului”, observații generale, persoana participantă, ordinea construcțiilor,
// centralele termice pe număr (b3 / g pe centrală), „aceleași coordonate / aceeași dată”, coordonatele scrise de mână,
// iluminat Hint cu NEC (ascuns fără hidranți interiori), ascensor, actele lipsă → nereguli, fără seria amenzii, fișa
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || '.';
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 1180, height: 820 }]) {
    const W = vp.width;
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    p.on('dialog', (d) => d.accept());
    const w = (ms = 250) => p.waitForTimeout(ms);
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await w(200);
    await p.fill('#nc-name', 'Liceul Epsilon'); await p.click('#nc-create'); await w(400);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    const url = p.url().replace(/\/obiectiv.*$/, '');

    // datele obiectivului: persoana participantă lângă administrator
    ok(await p.locator('[data-bind="persoanaParticipanta"]').count() === 1, `${W}: câmpul „Persoană participantă”`);
    await p.fill('[data-bind="persoanaParticipanta"]', 'Ana Pop'); await p.dispatchEvent('[data-bind="persoanaParticipanta"]', 'input');
    // De întrebat: adaugă, scrie, apare în „Ce mai aveți de făcut”, bifă
    await p.click('[data-act="intreb-add"]'); await w();
    await p.fill('.intreb-row textarea', 'Cere contractul de mentenanță'); await p.dispatchEvent('.intreb-row textarea', 'input'); await w(700);
    await p.click('[data-act="todo-toggle"]'); await w();
    ok(/De întrebat: Cere contractul de mentenanță/.test(await p.locator('#ed-todo').innerText()), `${W}: sarcina nebifată apare în „Ce mai aveți de făcut”`);
    await p.click('[data-act="todo-toggle"]'); await w();
    await p.click('.intreb-row .intreb-bifa'); await w();
    ok(!/De întrebat:/.test(await p.locator('#ed-todo').innerText()) && await p.locator('.intreb-row.is-gata').count() === 1, `${W}: bifată → nu mai apare`);
    await p.fill('[data-bind="observatiiGenerale"]', 'Acces prin curte'); await p.dispatchEvent('[data-bind="observatiiGenerale"]', 'input'); await w(600);

    // două construcții; ordinea se schimbă cu săgețile
    await p.click('[data-act="constr-inc"]'); await w();
    const nume = async () => p.locator('.constr-name').evaluateAll((l) => l.map((x) => x.value));
    ok((await nume()).join('|') === 'Construcția 1|Construcția 2', `${W}: două construcții`);
    await p.locator('[data-act="constr-up"]').nth(1).click(); await w();
    ok((await nume()).join('|') === 'Construcția 2|Construcția 1', `${W}: ▲ mută construcția mai sus`);
    await p.locator('[data-act="constr-down"]').nth(0).click(); await w();
    ok((await nume()).join('|') === 'Construcția 1|Construcția 2', `${W}: ▼ o mută înapoi`);

    // coordonatele scrise de mână; a doua construcție: aceleași coordonate
    await p.locator('[data-act="gps-manual"]').first().click(); await w();
    await p.fill('#gps-man', 'abc'); await p.click('#gps-man-ok'); await w();
    ok(await p.locator('#gps-man-err').isVisible(), `${W}: coordonate nerecunoscute → mesaj`);
    await p.fill('#gps-man', '44°25′36″ N 26°6′9″ E'); await p.click('#gps-man-ok'); await w();
    const g0 = await p.locator('.gps-field').first().innerText();
    ok(/44\.426667, 26\.102500/.test(g0) && /introduse manual/.test(g0), `${W}: coordonatele Busolei salvate, „introduse manual”`);
    // (construcția adăugată e deja deschisă)
    await p.locator('.constr').nth(1).locator('[data-act="gps-ca-prima"]').click(); await w();
    ok(/44\.426667, 26\.102500/.test(await p.locator('.constr').nth(1).locator('.gps-field').innerText())
      && await p.locator('.constr').nth(1).locator('[data-act="gps-ca-prima"].on').count() === 1, `${W}: „Aceleași coordonate ca la Construcția 1”`);

    // dotări: iluminat Hint cu NEC, ascuns fără hidranți interiori; ascensor DA / NU
    const c1 = p.locator('.constr').first();
    ok(await c1.locator('[data-path$=".dotari.ilumHint.v"][data-val="NEC"]').count() === 1, `${W}: Iluminat Hint are NEC`);
    ok(await c1.locator('[data-path$=".dotari.ascensor.v"]').count() === 2, `${W}: Ascensor DA / NU`);
    await c1.locator('[data-path$=".dotari.hidInt.v"][data-val="NEC"]').click(); await w();
    ok(await p.locator('.constr').first().locator('[data-path$=".dotari.ilumHint.v"]').count() === 0, `${W}: Hidranți interiori NEC → fără rândul Iluminat Hint`);
    // centrala: 2 centrale, tipuri pe fiecare
    const cen = () => p.locator('.constr').first().locator('.dot-ct');
    // fără centrale: tipurile apar direct, primul tip ales declară CT 1
    ok(await cen().locator('.ct-row.is-nou [data-val="GAZOS"]').count() === 1, `${W}: fără centrale, tipurile se aleg direct`);
    await cen().locator('.ct-row.is-nou [data-val="GAZOS"]').click(); await w();
    ok(await cen().locator('.ct-row').count() === 1 && await cen().locator('.ct-row.is-nou').count() === 0
      && await cen().locator('.ct-row [data-val="GAZOS"].on').count() === 1 && /1\s*centrală/.test(await cen().locator('.step-val').innerText()), `${W}: GAZOS → CT 1 GAZOS`);
    await cen().locator('[data-act="ct-count"][data-val="1"]').click(); await w();
    ok(await cen().locator('.ct-row').count() === 2 && /CT 1[\s\S]*CT 2/.test(await cen().innerText()), `${W}: 2 centrale termice (CT 1, CT 2)`);
    await cen().locator('.ct-row').nth(1).locator('[data-val="SOLID"]').click(); await w();
    // a doua construcție: 2 centrale (pentru „Aceeași dată” pe construcție)
    const cen2 = () => p.locator('.constr').nth(1).locator('.dot-ct');
    await cen2().locator('.ct-row.is-nou [data-val="GAZOS"]').click(); await w();
    await cen2().locator('[data-act="ct-count"][data-val="1"]').click(); await w();
    ok(await cen2().locator('.ct-row').count() === 2, `${W}: Construcția 2: 2 centrale`);
    await p.addStyleTag({ content: '.edit-tools,.tabbar,.ed-tabs{display:none!important}' });
    await p.locator('.constr').first().screenshot({ path: `${S}/v125-constructie-${W}.png` });

    // actele: lipsă → nereguli (grup + separate); actul nou
    await p.goto(`${url}/acte`); await w(500);
    ok(/Dispoziție de reglementare a fumatului/.test(await p.locator('#ner-results').innerText()), `${W}: act nou „Dispoziție de reglementare a fumatului”`);
    await p.click('[data-path="acte.lfd.status"][data-val="nok"]'); await w();
    await p.click('[data-path="acte.controale.status"][data-val="nok"]'); await w();
    await p.goto(`${url}/nereguli`); await w(500);
    const ao = p.locator('#ner-ao'); const ap = p.locator('#ner-ap');
    ok(await ao.count() === 1 && /Nu a prezentat acte de autoritate \/ evidențe/.test(await ao.innerText()) && /Din tabul Acte/.test(await ao.innerText()), `${W}: ao constatată automat din actele lipsă`);
    ok(await ap.count() === 1 && /Lipsă controale proprii/.test(await ap.innerText()) && await p.locator('#ner-aq').count() === 0, `${W}: ap separat; aq doar la analiza lipsă`);
    ok(await p.locator('#ner-an').count() === 1, `${W}: rândul nou „an” (chepeng / ușă pod RF 30 / 45 minute)`);
    // verificarea CT pe fiecare centrală; aceeași dată
    const b3 = p.locator('#ner-b3');
    ok(/Construcția 1 – CT 1[\s\S]*Construcția 1 – CT 2/.test(await b3.innerText()), `${W}: b3: câte un rând pe fiecare centrală`);
    const d0 = b3.locator('.vf-row input').first();
    await d0.fill('2025-03-01'); await d0.dispatchEvent('change'); await w();
    await p.locator('#ner-b3 [data-act="verif-ca-prima"]').first().click(); await w();
    ok(await p.locator('#ner-b3 .vf-row input').nth(1).inputValue() === '2025-03-01', `${W}: „Aceeași dată ca la …” copiază data`);
    // v1.25.1: CT 2 al Construcției 2 se raportează la CT 1 al Construcției 2; CT 1 al ei, la primul rând
    ok(await p.locator('#ner-b3 [data-act="verif-ca-prima"]').count() === 2, `${W}: fără data CT 1 al Construcției 2, CT 2 al ei nu are încă butonul`);
    const d2 = p.locator('#ner-b3 .vf-row input').nth(2);
    await d2.fill('2025-06-10'); await d2.dispatchEvent('change'); await w();
    const ca = await p.locator('#ner-b3 [data-act="verif-ca-prima"]').allInnerTexts();
    ok(ca.length === 3 && /Construcția 1 – CT 1/.test(ca[0]) && /Construcția 1 – CT 1/.test(ca[1]) && /Construcția 2 – CT 1/.test(ca[2]), `${W}: referința pe construcție: ${ca.join(' | ')}`);
    await p.locator('#ner-b3 [data-act="verif-ca-prima"]').nth(2).click(); await w();
    ok(await p.locator('#ner-b3 .vf-row input').nth(3).inputValue() === '2025-06-10', `${W}: CT 2 al Construcției 2 copiază data CT 1 al Construcției 2`);
    // amenda fără seria
    await p.locator('#ner-d .nok-btn').click(); await w();
    await p.locator('#ner-d [data-path$=".amenda.aplicata"]').click(); await w();
    ok(await p.locator('[data-bind$=".amenda.serieNr"]').count() === 0, `${W}: amenda nu mai are câmpul seriei`);

    // fișa: participant, De întrebat, observații, centrale, coordonate manuale
    await p.goto(url.replace('/control/', '/fisa/')); await w(600);
    const f = await p.locator('.fisa-doc').innerText();
    ok(/Persoană participantă: Ana Pop/.test(f), `${W}: fișa: persoana participantă`);
    ok(/De întrebat până la finalizarea controlului[\s\S]*✓ Cere contractul/.test(f) && /Observații generale[\s\S]*Acces prin curte/.test(f), `${W}: fișa: De întrebat, observațiile generale`);
    ok(/Centrală termică: CT 1: GAZOS; CT 2: SOLID/.test(f) && /\(introduse manual\)/.test(f), `${W}: fișa: centralele, coordonatele manuale`);
    await ctx.close();
  }
  console.log(errs.length ? `page errors: ${errs.join(' | ')}` : 'no page errors');
  await b.close();
})();
