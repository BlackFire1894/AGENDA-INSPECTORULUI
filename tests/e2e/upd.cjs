const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
// versiunea curentă (din sw.js) și una simulată „următoare” (+1 la ultima cifră)
const CUR = fs.readFileSync(`${S}/site/sw.js`, 'utf8').match(/VERSION = '([\d.]+)'/)[1];
const NEXT = CUR.replace(/\d+$/, (x) => String(+x + 1));
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 1180, height: 820 } });
  const p = await ctx.newPage();
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('http://localhost:8090/');
  await p.evaluate(() => navigator.serviceWorker.ready);
  await p.reload(); await p.waitForTimeout(500);
  ok(await p.evaluate(() => !!navigator.serviceWorker.controller), 'SW controls page');
  await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
  ok(await p.locator('#update-bar').isHidden(), 'no banner on same version');
  await p.goto('http://localhost:8090/#/setari'); await p.waitForTimeout(300);
  await p.click('[data-act="check-update"]'); await p.waitForTimeout(800);
  ok((await p.locator('#toast').innerText()).includes('cea mai nouă'), 'check says up to date');
  // publicăm versiunea următoare
  for (const f of ['sw.js', 'js/version.js']) {
    const path = `${S}/site/${f}`;
    fs.writeFileSync(path, fs.readFileSync(path, 'utf8').split(CUR).join(NEXT));
  }
  fs.writeFileSync(`${S}/site/css/app.css`, fs.readFileSync(`${S}/site/css/app.css`, 'utf8') + '\n/* versiune următoare */\n');
  await p.click('[data-act="check-update"]'); await p.waitForTimeout(1500);
  ok(await p.locator('#update-bar').isVisible(), 'banner visible after new version');
  await p.screenshot({ path: `${S}/update-bar.png` });
  await Promise.all([p.waitForEvent('load'), p.click('[data-act="apply-update"]')]);
  await p.waitForTimeout(800);
  await p.goto('http://localhost:8090/#/setari'); await p.waitForTimeout(400);
  const v = await p.locator('.set-status b').allInnerTexts();
  ok(v.includes(NEXT), `după actualizare rulează ${NEXT}: ` + v.join(' | '));
  ok(await p.locator('#update-bar').isHidden(), 'banner gone after update');
  await p.goto('http://localhost:8090/#/istoric'); await p.waitForTimeout(300);
  ok(await p.locator('.ctl-row').count() === 7, 'data intact (7 controls)');
  // offline
  await ctx.setOffline(true);
  await p.reload(); await p.waitForTimeout(500);
  ok(await p.locator('.ctl-row').count() === 7, 'works offline');
  console.log(errs.join('\n') || 'no page errors');
  await b.close();
})();
