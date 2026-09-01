import puppeteer from 'puppeteer-core';
(async () => {
  const browser = await puppeteer.connect({ browserURL: 'http://127.0.0.1:9223' });
  const targets = await browser.targets();
  for (let i = 0; i < targets.length; i++) {
    const t = targets[i];
    console.log(`Target ${i}: ${t.type()} - ${t.url()}`);
    if (t.type() === 'page') {
      try {
        const p = await t.page();
        if (p) {
          const result = await p.evaluate(() => {
            return {
              url: window.location.href,
              html: document.body ? document.body.innerText : 'NO BODY'
            };
          });
          console.log(`  -> Storage: `, result);
        }
      } catch (e) {
        console.log(`  -> sessionStorage ERROR: ${e.message}`);
      }
    }
  }
  process.exit(0);
})();
