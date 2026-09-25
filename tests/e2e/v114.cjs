// v1.14.0: UI curat — punctele aprobate
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2] || __dirname;
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
const INFORMAL = /Ce mai ai de|Ștergi |Mai ai \d|\bconsultă\b|verifică prelungirea|Completează denumirea|Datele tale|poți modifica|Nu ai făcut|salvează un backup|Fă întâi|Scrie numele|Alege sau scrie/;
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [ori, vp, theme] of [['port', { width: 820, height: 1180 }, 'light'], ['land', { width: 1180, height: 820 }, 'dark']]) {
    const port = ori === 'port';
    console.log('--', ori);
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', colorScheme: theme });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(400);
    // ── Panou aerisit
    const head = await p.evaluate(() => {
      const d = document.querySelector('.dash-date > span:first-child').getBoundingClientRect(); const t = document.querySelector('.dash-time').getBoundingClientRect();
      const kp = [...document.querySelectorAll('.kpi')].map((k) => k.getBoundingClientRect().height);
      return { same: Math.abs(d.bottom - t.bottom) < 4, kpiMax: Math.max(...kp), fines: document.getElementById('sec-fines').getBoundingClientRect().top + scrollY - (document.getElementById('sec-act-conf')?.offsetHeight || 0), banner: document.querySelectorAll('.banner').length };
    });
    ok(head.same, 'Panou: data și ora pe același rând');
    ok(head.banner === 0 && await p.locator('[data-act="backup-export"]:visible').count() === 1, 'Panou: fără banner, un singur buton de backup pe ecran');
    // v1.15: legenda amenzilor e scrisă în cuvinte, deci caseta e ceva mai înaltă decât în v1.14
    // v1.16: a cincea casetă („De încărcat”)
    ok(head.kpiMax < (port ? 270 : 380), `Panou: casete KPI (${Math.round(head.kpiMax)}px)`);
    ok(head.fines < (port ? 780 : 520), `Panou: secțiunea Amenzi (y=${Math.round(head.fines)})`);
    const leg = (await p.locator('.kpi-fines .kpi-legend').innerText()).replace(/\s+/g, ' ');
    ok(/de trimis la ANAF/.test(leg) && /cu termen de plată expirat/.test(leg) && /în curs/.test(leg), `Panou: legenda amenzilor în cuvinte: ${leg}`);
    ok(port ? await p.locator('.dash-actions .guide-btn').isVisible() : await p.locator('.dash-actions').isHidden(), port ? 'vertical: Ghidul aplicației sus în Panou' : 'orizontal: Ghid / Backup doar în bara laterală');
    // stadiile amenzilor: aceeași pastilă (contur + punct) pentru toate
    // stadiile: aceeași pastilă, plină (fundal colorat, nu transparent)
    const fs = await p.evaluate(() => [...document.querySelectorAll('#sec-fines .item-side .pill')].map((x) => ({ c: x.className, bg: getComputedStyle(x).backgroundColor })));
    ok(fs.length >= 4 && fs.every((x) => /fine-st/.test(x.c) && !/rgba\(0, 0, 0, 0\)|transparent/.test(x.bg)), `amenzi: ${fs.length} pastile pline (${[...new Set(fs.map((x) => x.c.split(' ').pop()))].join(', ')})`);
    if (!port) ok(/\d+ amenzi urgente/.test(await p.locator('.sidebar [data-badge-text="panou"]').innerText()) && /\d+ neîncheiate/.test(await p.locator('.sidebar [data-badge-text="istoric"]').innerText()), 'bara laterală: numerele de pe meniu, în cuvinte');
    // controale neîncheiate: „început azi” / „de N zile”, nu „0 zile”
    const open = await p.locator('#sec-open .item-side').allInnerTexts();
    ok(open.some((t) => /început azi/.test(t)) && open.some((t) => /^de \d+ zile$/.test(t.trim())) && !open.some((t) => /^0\s/.test(t.trim())), `controale neîncheiate: ${open.map((t) => t.trim()).join(' | ')}`);
    // ── eticheta de tip, discretă
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(300);
    const badge = await p.locator('.badge-opec >> nth=0').evaluate((e) => getComputedStyle(e).backgroundColor);
    ok(/rgba\(0, 0, 0, 0\)|transparent/.test(badge), `eticheta OPEC / Instituție: fără fundal închis (${badge})`);
    // gramatică: „1 netrecută în PV”
    const spital = p.locator('.ctl-row:has-text("Spitalul")');
    ok(/1 netrecută în PV/.test(await spital.innerText()), 'Istoric: „1 netrecută în PV”');
    await spital.click(); await p.waitForTimeout(400);
    const id = p.url().split('/')[5];
    // ── Nereguli: primul rând la vedere, antet compact
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(400);
    const tabNer = await p.locator('.ed-tab >> nth=2').innerText();
    ok(/1 netrecută/.test(tabNer) && !/1 netrecute/.test(tabNer), `tabul Nereguli: ${tabNer.replace(/\n/g, ' · ')}`);
    // antetul controlului a rămas neschimbat (nu s-a aprobat compactarea lui): cerem ca bara primului rând să fie întreagă pe ecran
    const first = await p.locator('.ner-row >> nth=0 >> .ner-bar').evaluate((e) => ({ top: e.getBoundingClientRect().top, bottom: e.getBoundingClientRect().bottom, vh: innerHeight - (document.querySelector('.tabbar')?.offsetHeight || 0) - (document.getElementById('edit-strip')?.offsetHeight || 0) }));
    // v1.15: pe orizontal, textele scrise în taburi și în sumar coboară primul rând chiar sub marginea ecranului (≈ +60px); decizia e la utilizator
    if (port) ok(first.bottom <= first.vh && first.top < 860, `primul rând de neregulă la vedere (y=${Math.round(first.top)}–${Math.round(first.bottom)}, ecran util ${first.vh})`);
    else ok(first.top < first.vh + 80, `orizontal: primul rând de neregulă imediat sub marginea ecranului (y=${Math.round(first.top)}, ecran ${first.vh})`);
    ok(await p.locator('.sum-line').count() === 1 && await p.locator('.ner-summary').count() === 0, 'sumarul pe un rând');
    ok(!/Nereguli constatate/.test(await p.locator('#ner-results').innerText().then((t) => t.slice(0, 200))), 'fără titlul repetat „Nereguli constatate”');
    // ✓ ✗ NEC pe bară, lângă denumire
    // (rândurile grave au doar ✓ / ✗, fără NEC)
    const bar = await p.evaluate(() => { const r = [...document.querySelectorAll('.ner-row:not(.is-collapsed)')].find((x) => x.querySelector('.nec-btn')); const bar = r.querySelector('.ner-bar'); return { id: r.id, ok: !!bar.querySelector('.ok-btn'), nok: !!bar.querySelector('.nok-btn'), nec: !!bar.querySelector('.nec-btn'), body: r.querySelectorAll(':scope > .row-main .ok-btn, :scope > .row-side .ok-btn').length, h: Math.min(...[...bar.querySelectorAll('.ok-btn,.nok-btn,.nec-btn')].map((x) => x.getBoundingClientRect().height)) }; });
    ok(bar.ok && bar.nok && bar.nec && !bar.body && bar.h >= 44, `✓ ✗ NEC pe bara rândului ${bar.id} (ținte ${Math.round(bar.h)}px)`);
    // bara categoriei deschise: un singur rând
    // v1.15: bara categoriei deschise în cuvinte întregi (nu prescurtări cu explicația ascunsă)
    const bars = await p.locator('.cat-group:not(.closed) > .cat-title').allInnerTexts();
    ok(bars.length && bars.every((t) => !/necompl\.|PV ✓|^\s*[✗✕]\s*\d/m.test(t)) && bars.some((t) => /necompletat|Completat/.test(t)), `barele categoriilor, în cuvinte: ${bars[0].replace(/\s+/g, ' ')}`);
    const tabTxt = await p.locator('.ed-tab .tab-prog-txt').allInnerTexts();
    ok(tabTxt.length >= 3 && /^Dotări \d+\/\d+$/.test(tabTxt[0].trim()) && tabTxt.slice(1).every((t) => /^Verificate \d+\/\d+$/.test(t.trim())), `taburi: progresul scris (${tabTxt.map((t) => t.trim()).join(' | ')})`);
    // ⋯: rămâne și după o căutare golită
    await p.fill('#ner-search', 'hidranti'); await p.dispatchEvent('#ner-search', 'input'); await p.waitForTimeout(250);
    await p.click('[data-act="ner-q-clear"]'); await p.waitForTimeout(250);
    ok(await p.locator('[data-act="tools-more"]').count() === 1, '⋯ rămâne după căutare');
    await p.click('[data-act="tools-more"]'); await p.waitForTimeout(200);
    ok(await p.locator('.tools-menu [data-act="cats-all"]').count() === 1, '⋯ → „Restrânge categoriile”');
    await p.click('[data-act="tools-more"]'); await p.waitForTimeout(200);
    // Acte: la fel
    await p.goto(`http://localhost:8080/#/control/${id}/acte`); await p.waitForTimeout(400);
    const firstAct = await p.locator('.act-row >> nth=0 >> .ner-bar').evaluate((e) => ({ top: e.getBoundingClientRect().top, bottom: e.getBoundingClientRect().bottom, vh: innerHeight - (document.querySelector('.tabbar')?.offsetHeight || 0) - (document.getElementById('edit-strip')?.offsetHeight || 0) }));
    if (port) ok(firstAct.bottom <= firstAct.vh && firstAct.top < 820, `primul act la vedere (y=${Math.round(firstAct.top)}–${Math.round(firstAct.bottom)})`);
    else ok(firstAct.top < firstAct.vh + 80, `orizontal: primul act imediat sub marginea ecranului (y=${Math.round(firstAct.top)})`);
    ok(await p.locator('.act-row >> nth=0 >> .ner-bar .nec-btn').count() === 1, 'acte: ✓ ✗ NEC pe bară');
    // banda Anulează / Refă (vertical) — subțire, ținte ≥ 44px
    if (port) {
      await p.click('.act-row >> nth=0 >> .ok-btn'); await p.waitForTimeout(300);
      const es = await p.evaluate(() => { const s = document.getElementById('edit-strip'); return { h: s.getBoundingClientRect().height, b: Math.min(...[...s.querySelectorAll('.et-btn')].map((x) => x.getBoundingClientRect().height)) }; });
      ok(es.h <= 56 && es.b >= 44, `banda Anulează / Sus / Refă: ${Math.round(es.h)}px, butoane ${Math.round(es.b)}px`);
    }
    // ton formal: niciun text informal pe ecranele principale
    const texts = [];
    for (const r of ['#/panou', '#/obiective', '#/calendar', '#/istoric', '#/setari', '#/ghid', `#/control/${id}/obiectiv`, `#/control/${id}/acte`, `#/control/${id}/nereguli`]) {
      await p.goto('http://localhost:8080/' + r); await p.waitForTimeout(250);
      texts.push(await p.evaluate(() => document.body.innerText + [...document.querySelectorAll('[placeholder]')].map((e) => e.placeholder).join(' ')));
    }
    const bad = texts.map((t) => (t.match(INFORMAL) || [])[0]).filter(Boolean);
    ok(!bad.length, `ton formal pe toate ecranele${bad.length ? ': ' + bad.join(', ') : ''}`);
    await p.goto(`http://localhost:8080/#/control/${id}/nereguli`); await p.waitForTimeout(300);
    await p.screenshot({ path: `${S}/v114-${ori}-nereguli.png` });
    await ctx.close();
  }
  // ── bara laterală: încape la toate mărimile de text, 820 și 744 px înălțime
  for (const f of ['mare', 'mediu', 'mic']) for (const h of [820, 744]) {
    const ctx = await b.newContext({ viewport: { width: h === 744 ? 1133 : 1180, height: h }, serviceWorkers: 'block' });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.addInitScript((f) => localStorage.setItem('agenda-font', f), f);
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    await p.goto('http://localhost:8080/#/istoric'); await p.waitForTimeout(200);
    const id = (await p.locator('a[href*="#/control/"]').first().getAttribute('href')).split('/')[2];
    for (const r of ['#/panou', `#/control/${id}/nereguli`]) {
      await p.goto('http://localhost:8080/' + r); await p.waitForTimeout(250);
      const m = await p.evaluate(() => { const s = document.querySelector('.sidebar'); const set = document.querySelector('.side-settings').getBoundingClientRect(); const t = document.querySelector('.side-time').getBoundingClientRect(); return { fit: s.scrollHeight <= s.clientHeight + 1 && set.bottom <= innerHeight, clock: t.height > 0 }; });
      ok(m.fit && m.clock, `bara laterală ${f} ${h}px ${r.startsWith('#/c') ? 'control' : 'panou'}: încape, cu ceasul`);
    }
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
