const GL_RECHT_FORM_URL = 'https://gl-recht.at/kreditvertragsgebuhren-koop/';
const GL_RECHT_FORM_ID = '15395';
const GL_RECHT_PARTNER = 'Konsumentenretter';

async function main() {
  const url = `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`;
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    },
  });
  const html = await response.text();

  console.log('--- NONCE SEARCH ---');
  
  // Search for "nonce" case-insensitively
  let idx = 0;
  while (true) {
    const nextIdx = html.toLowerCase().indexOf('nonce', idx);
    if (nextIdx === -1) break;
    
    console.log(`\nOccurrence at index ${nextIdx}:`);
    console.log(html.slice(Math.max(0, nextIdx - 50), Math.min(html.length, nextIdx + 150)));
    idx = nextIdx + 5;
    if (idx > html.length) break;
  }
}

main();
