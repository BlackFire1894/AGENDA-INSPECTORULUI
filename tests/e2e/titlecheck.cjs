const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => {
  const b = await chromium.launch(); let bad = 0;
  for (const vp of [{ width: 1180, height: 820 }, { width: 820, height: 1180 }]) for (const size of ['mare', 'mediu', 'mic']) {
    const p = await b.newPage({ viewport: vp });
    await p.goto('http://localhost:8080/'); await p.evaluate((s) => localStorage.setItem('agenda-font', s), size); await p.reload();
    await p.click('.welcome [data-act="demo-load"]'); await p.waitForTimeout(300);
    const ids = await p.evaluate(async () => { const r = indexedDB.open('agenda-inspectorului'); return new Promise((res) => { r.onsuccess = () => { const q = r.result.transaction('controls').objectStore('controls').getAll(); q.onsuccess = () => res(q.result.map((c) => c.id)); }; }); });
    for (const id of ids) {
      await p.goto(`http://localhost:8080/#/control/${id}/obiectiv`); await p.waitForTimeout(150);
      const w = await p.evaluate(() => { const h = document.querySelector('.ed-title h1'); return h.getBoundingClientRect().height / parseFloat(getComputedStyle(h).lineHeight); });
      if (w > 2.2) { bad++; console.log('narrow title', vp.width, size, id, w.toFixed(2)); }
    }
    await p.close();
  }
  console.log('titluri înghesuite:', bad); await b.close();
})();
