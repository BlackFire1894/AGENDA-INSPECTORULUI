// v1.26: Construcții — căutarea (denumire sau dotare DA) și „Filtre” (DA, NU, dotări necompletate, instalații lipsă);
// Acte / Nereguli — butonul „Filtre” (stare, construcție, afișare), etichetele ✕, „Netrecute în PV”, filtrul pe construcție;
// „Ce mai aveți de făcut” → constatările netrecute în PV se deschid cu filtrul lor
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const vp of [{ width: 820, height: 1180 }, { width: 428, height: 926 }]) {
    const W = vp.width;
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', hasTouch: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    p.on('dialog', (d) => d.accept());
    const w = (ms = 250) => p.waitForTimeout(ms);
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="new-control"]'); await w(200);
    await p.fill('#nc-name', 'Spitalul Test'); await p.click('#nc-create'); await w(400);
    await p.addStyleTag({ content: '#toast{display:none!important}' });
    const url = p.url().replace(/\/obiectiv.*$/, '');
    for (let i = 0; i < 4; i++) { await p.click('[data-act="constr-inc"]'); await w(150); }
    // 5 construcții: dotările și câteva constatări, scrise direct în date
    const chei = await p.evaluate(async () => {
      const S = await import('/js/state.js'); const M = await import('/js/model.js');
      const c = S.state.controls.find((x) => location.hash.includes(x.id));
      const [k1, k2, k3, k4, k5] = c.constructii;
      ['Pavilion central', 'Ambulatoriu', 'Bloc operator', 'Spălătorie', 'Morgă'].forEach((n, i) => { c.constructii[i].denumire = n; });
      // Pavilion central: complet (NEC peste tot, IDSAI și sprinklere DA, fără centrală)
      for (const d of M.dotariVizibile(c, k1)) { if (d.centrala) k1.dotari.centrala.nuAre = true; else k1.dotari[d.key].v = d.opts.includes('NEC') ? 'NEC' : 'NU'; }
      k1.dotari.idsai.v = 'DA'; k1.dotari.sprinklere.v = 'DA'; k1.dotari.ilumHint.v = '';
      k2.dotari.hidInt.v = 'DA'; k2.dotari.idsai.v = 'DA';
      k3.dotari.sprinklere.v = 'DA'; k3.dotari.hidExt.v = 'NU';
      k5.dotari.idsai.v = 'NU';
      M.normalizeControl(c);
      // constatări: d în Bloc operator (netrecută în PV), e în Pavilion central (trecută), un rând de hidranți interiori (doar Ambulatoriu)
      const d = c.nereguli.find((n) => n.key === 'd'); d.status = 'nok'; d.constructieIds = [k3.id]; d.inPV = false;
      const e = c.nereguli.find((n) => n.key === 'e'); e.status = 'nok'; e.constructieIds = [k1.id]; e.inPV = true;
      const hid = c.nereguli.find((n) => !n.custom && !M.sablon(n.key)?.grav && (M.sablon(n.key)?.req || []).join() === 'hidInt');
      const gen = c.nereguli.find((n) => !n.custom && M.secOf(n) === 'ner' && M.isApplicable(c, n) && !M.sablon(n.key)?.req && !M.sablon(n.key)?.reqNU && !M.sablon(n.key)?.autoActe && !n.status && n.key !== 'd' && n.key !== 'e');
      S.touch(c, true);
      return { hid: hid.key, gen: gen.key, k: c.constructii.map((x) => x.id) };
    });
    await p.goto(`${url}/acte`); await w(300); await p.goto(`${url}/obiectiv`); await w(400);
    const art = () => p.locator('#constr-results article.constr');
    const cauta = async (q) => { await p.fill('#constr-search', q); await p.dispatchEvent('#constr-search', 'input'); await w(200); };
    const nr = async () => (await p.locator('#constr-results .flt-count').count() ? (await p.locator('#constr-results .flt-count').innerText()).trim() : '');

    // ───── Construcții: căutarea ─────
    ok(await p.locator('#constr-search').count() === 1 && await p.locator('[data-act="constr-filtre"]').count() === 1, `${W}: Construcții — căutare și „Filtre”`);
    await cauta('bloc');
    ok(await art().count() === 1 && await p.locator('#constr-results article.constr.open').count() === 1 && await nr() === '1 din 5 construcții', `${W}: „bloc” → Bloc operator, deschisă (${await nr()})`);
    await cauta('sprinkl');
    ok(await art().count() === 2 && await p.locator('#constr-results article.constr.open').count() === 0, `${W}: „sprinkl” → cele 2 cu sprinklere DA, restrânse (listă de antete)`);
    await p.locator('#constr-results [data-act="constr-toggle"]').nth(1).click(); await w();
    ok(/Sprinklere/.test(await p.locator('#constr-results .dot-row.is-match').innerText()) && await p.locator('#constr-results .dot-row.is-match').count() === 1, `${W}: rândul Sprinklere evidențiat în construcția deschisă`);
    await cauta('hidranti');
    ok(await art().count() === 1 && /Ambulatoriu/.test(await p.locator('#constr-results .constr-name').inputValue()) && /Hidranți interiori/.test(await p.locator('.dot-row.is-match').innerText()), `${W}: „hidranti” (fără diacritice) → doar construcția cu hidranți DA (NU nu contează)`);
    await cauta('xyz');
    ok(await art().count() === 0 && /Nicio construcție nu se potrivește cu „xyz”/.test(await p.locator('#constr-results').innerText()), `${W}: nimic găsit → mesaj`);
    await p.click('[data-act="constr-q-clear"]'); await w();
    ok(await art().count() === 5 && await p.locator('#constr-results .flt-active').count() === 0, `${W}: ✕ golește căutarea → toate 5`);

    // ───── Construcții: „Filtre” ─────
    await p.click('[data-act="constr-filtre"]'); await w();
    const panou = await p.locator('.filtre-panel').innerText();
    ok(/DOTATE CU \(DA\)/i.test(panou) && /FĂRĂ \(NU\)/i.test(panou) && /STARE/i.test(panou), `${W}: panoul are „Dotate cu”, „Fără”, „Stare”`);
    ok(/IDSAI\s*2/.test(panou) && /Sprinklere\s*2/.test(panou) && !/Drencere/.test(panou.split(/FĂRĂ/i)[0]), `${W}: „Dotate cu” — doar dotările existente, cu numărul construcțiilor`);
    ok(/Hidranți exteriori\s*1/.test(panou.split(/FĂRĂ/i)[1]) && /Instalații lipsă\s*2/.test(panou) && /Dotări necompletate\s*4/.test(panou), `${W}: „Fără” și „Stare” cu numerele lor`);
    await p.click('[data-act="constr-flt"][data-val="da:idsai"]'); await w();
    ok(await art().count() === 2 && await nr() === '2 din 5 construcții' && /IDSAI: DA/.test(await p.locator('#constr-results .flt-chip').innerText()), `${W}: IDSAI DA → 2 construcții, eticheta „IDSAI: DA”`);
    ok((await p.locator('[data-act="constr-filtre"] .flt-n').innerText()).trim() === '1', `${W}: „Filtre” arată 1 filtru activ`);
    await p.click('.filtre-panel [data-act="constr-flt"][data-val="necomplet"]'); await w();
    ok(await art().count() === 1 && /Ambulatoriu/.test(await p.locator('#constr-results .constr-name').inputValue()) && await p.locator('#constr-results article.constr.open').count() === 1, `${W}: + dotări necompletate → doar Ambulatoriu (deschisă)`);
    await p.locator('#constr-results .flt-chip', { hasText: 'IDSAI' }).click(); await w();
    ok(await art().count() === 4 && await p.locator('#constr-results .flt-chip').count() === 1, `${W}: ✕ pe „IDSAI: DA” → rămâne doar „Dotări necompletate” (4)`);
    await p.locator('#constr-results .flt-chip').click(); await w();
    await p.click('.filtre-panel [data-act="constr-flt"][data-val="lipsa"]'); await w();
    ok((await p.locator('#constr-results .constr-name').evaluateAll((l) => l.map((x) => x.value))).join('|') === 'Bloc operator|Morgă', `${W}: „Instalații lipsă” → Bloc operator (hidranți exteriori NU) și Morgă (IDSAI NU)`);
    await p.locator('#constr-results .flt-chip').click(); await w();
    await p.click('.filtre-panel [data-act="constr-flt"][data-val="nu:idsai"]'); await w();
    ok(await art().count() === 1 && /Morgă/.test(await p.locator('#constr-results .constr-name').inputValue()) && /IDSAI: NU/.test(await p.locator('#constr-results .flt-chip').innerText()), `${W}: „Fără” IDSAI → Morgă`);
    await p.locator('#constr-results .flt-chip').click(); await w();
    ok(await art().count() === 5, `${W}: fără filtre → toate construcțiile`);
    await p.click('[data-act="constr-filtre"]'); await w();
    ok(await p.locator('.filtre-panel').count() === 0, `${W}: „Filtre” închide panoul`);

    // ───── Nereguli: „Filtre” ─────
    await p.goto(`${url}/nereguli`); await w(400);
    ok(await p.locator('[data-act="tools-more"]').innerText() === 'Filtre' && await p.locator('.toolbar .segmented').count() === 0, `${W}: Nereguli — „Filtre” în locul filtrelor la vedere`);
    await p.click('[data-act="tools-more"]'); await w();
    const st = await p.locator('.filtre-panel .segmented button').allInnerTexts();
    ok(st.length === 4 && st[2].replace(/\s+/g, ' ') === 'Netrecute în PV (1)', `${W}: stare — ${st.join(' / ').replace(/\s+/g, ' ')}`);
    ok(await p.locator('.filtre-panel [data-act="ner-constr"]').count() === 6 && await p.locator('.filtre-panel [data-act="cats-all"]').count() === 1, `${W}: „Construcția” (Toate + 5) și „Afișare” în panou`);
    if (W < 600) {
      const cols = await p.locator('.filtre-panel .segmented').evaluate((e) => getComputedStyle(e).gridTemplateColumns.split(' ').length);
      ok(cols === 2, `${W}: telefon — starea pe două coloane`);
    }
    await p.click('.filtre-panel [data-act="ner-filter"][data-val="PV"]'); await w();
    const vizibile = async () => p.locator('#ner-results .ner-row').evaluateAll((l) => l.map((x) => x.id));
    ok((await vizibile()).join() === 'ner-d', `${W}: „Netrecute în PV” → doar d (${(await vizibile()).join()})`);
    ok(/Netrecute în PV \(1\)/.test(await p.locator('.toolbar .flt-chip').innerText()) && (await p.locator('[data-act="tools-more"] .flt-n').innerText()).trim() === '1', `${W}: eticheta ✕ și cifra pe „Filtre”`);
    await p.click('.toolbar .flt-chip'); await w();
    ok((await vizibile()).length > 5 && await p.locator('.toolbar .flt-chip').count() === 0, `${W}: ✕ → toate rândurile`);
    // filtrul pe construcție
    await p.click(`.filtre-panel [data-act="ner-constr"][data-val="${chei.k[0]}"]`); await w();
    let v = await vizibile();
    ok(v.includes('ner-e') && !v.includes('ner-d') && !v.includes(`ner-${chei.hid}`) && v.includes(`ner-${chei.gen}`), `${W}: Pavilion central → e (constatată aici), rândurile generale (${chei.gen}); fără d și fără hidranții interiori`);
    ok(!v.some((x) => /^ner-lipsa-/.test(x)), `${W}: Pavilion central → fără neregulile grave declanșate în alte construcții`);
    await p.click(`.filtre-panel [data-act="ner-constr"][data-val="${chei.k[2]}"]`); await w();
    ok((await vizibile()).includes('ner-lipsa-hidExt') && !(await vizibile()).includes('ner-lipsa-idsai'), `${W}: Bloc operator → neregula gravă a hidranților exteriori (NU la ea), fără cea de la Morgă`);
    ok(/3\. Bloc operator/.test(await p.locator(".toolbar .flt-chip").innerText()), `${W}: eticheta construcției`);
    await p.click(`.filtre-panel [data-act="ner-constr"][data-val="${chei.k[1]}"]`); await w();
    v = await vizibile();
    ok(v.includes(`ner-${chei.hid}`) && !v.includes('ner-e'), `${W}: Ambulatoriu → și rândul hidranților interiori`);
    await p.click('.filtre-panel [data-act="ner-filter"][data-val="PV"]'); await w();
    ok((await vizibile()).length === 0 && /Nimic de afișat/.test(await p.locator('#ner-results').innerText()) && (await p.locator('[data-act="tools-more"] .flt-n').innerText()).trim() === '2', `${W}: Ambulatoriu + netrecute → nimic; „Filtre” 2`);
    // filtrul pe construcție rămâne între taburile aceluiași control; se golește la alt control
    await p.goto(`${url}/acte`); await w(300);
    ok(await p.locator('.toolbar .flt-chip').count() === 0, `${W}: Acte — fără filtrul pe construcție`);
    await p.click('[data-act="tools-more"]'); await w();
    ok((await p.locator('.filtre-panel .segmented button').allInnerTexts()).length === 3 && await p.locator('.filtre-panel [data-act="ner-constr"]').count() === 0, `${W}: Acte — Toate / Lipsă / Neverificate, fără „Construcția”`);
    await p.goto(`${url}/nereguli`); await w(300);
    ok(/Ambulatoriu/.test(await p.locator('.toolbar .flt-chip').innerText()), `${W}: înapoi la Nereguli — construcția rămâne aleasă`);
    await p.goto('http://localhost:8080/#/panou'); await w(300); await p.goto(`${url}/nereguli`); await w(300);
    ok(await p.locator('.toolbar .flt-chip').count() === 0, `${W}: după ieșirea din control, filtrele se golesc`);

    // „Ce mai aveți de făcut”: constatările netrecute în PV → tabul, cu filtrul „Netrecute în PV”
    await p.goto(`${url}/obiectiv`); await w(300);
    await p.click('[data-act="todo-toggle"]'); await w();
    await p.click('.todo-list [data-act="todo-go"][data-flt="PV"]'); await w(500);
    ok(/\/nereguli/.test(p.url()) && /Netrecute în PV/.test(await p.locator('.toolbar').innerText()) && (await vizibile()).join() === 'ner-d', `${W}: „constatare netrecută în PV” → Nereguli cu filtrul (${(await vizibile()).join()})`);
    ok(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${W}: fără derulare orizontală`);
    await p.screenshot({ path: `${process.argv[2] || '.'}/v126-${W}.png` });
    await ctx.close();
  }
  ok(!errs.length, `fără erori JS ${errs.slice(0, 3).join(' | ')}`);
  await b.close();
})();
