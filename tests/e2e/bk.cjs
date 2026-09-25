const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const S = process.argv[2];
const ok = (c, m) => console.log((c ? 'ok: ' : 'FAIL: ') + m);
(async () => {
  const b = await chromium.launch(); const errs = [];
  for (const [ori, vp] of [['land', { width: 1180, height: 820 }], ['port', { width: 820, height: 1180 }]]) {
    const ctx = await b.newContext({ viewport: vp, serviceWorkers: 'block', acceptDownloads: true });
    const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(e.message));
    await p.goto('http://localhost:8080/'); await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    // un singur buton de backup pe ecran: pe orizontal cel din bara laterală, pe vertical cel din antetul Panoului; fără banner
    const bq = ori === 'land' ? '.side-backup' : '.backup-quick';
    const vis = await p.locator('[data-act="backup-export"]:visible').count();
    ok(await p.locator('.banner').count() === 0 && vis === 1, `Panou: fără banner, un singur buton de backup vizibil (${vis})`);
    ok((await p.locator(bq).innerText()).includes('niciun backup încă') && await p.locator(`${bq}.stale`).count() === 1, 'Backup rapid, evidențiat (fără backup)');
    await p.screenshot({ path: `${S}/bk-${ori}-before.png` });
    const [dl] = await Promise.all([p.waitForEvent('download'), p.click(bq)]);
    ok(/^agenda-inspectorului-backup-\d{4}-\d\d-\d\d_\d\d-\d\d\.json$/.test(dl.suggestedFilename()), `fișier: ${dl.suggestedFilename()}`);
    const data = JSON.parse(require('fs').readFileSync(await dl.path(), 'utf8'));
    ok(data.controls.length === 7, 'conține toate cele 7 controale');
    await p.waitForTimeout(300);
    ok((await p.locator(bq).innerText()).includes('ultimul: azi') && await p.locator(`${bq}.stale`).count() === 0, 'după backup: „ultimul: azi”, fără evidențiere');
    if (ori === 'land') ok((await p.locator('.side-backup').innerText()).includes('ultimul: azi'), 'bara laterală: ultimul backup actualizat');
    await p.screenshot({ path: `${S}/bk-${ori}-after.png` });
    // din control
    await p.goto('http://localhost:8080/#/istoric'); await p.click('.ctl-row >> nth=0'); await p.waitForTimeout(300);
    const url = p.url();
    const [dl2] = await Promise.all([p.waitForEvent('download'), p.click('.ed-actions [data-act="backup-export"]')]);
    await p.waitForTimeout(300);
    ok(!!dl2 && p.url() === url && await p.locator('#ed-body').count() === 1, 'Backup din control: rămâne în control');
    // setări
    await p.goto('http://localhost:8080/#/setari'); await p.waitForTimeout(200);
    ok((await p.locator('.set-sec >> nth=2').innerText()).includes('face exact același export'), 'Setări explică faptul că e același backup');
    await ctx.close();
  }
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'no page errors'); await b.close();
})();
