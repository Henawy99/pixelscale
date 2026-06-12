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

  // Find id="wpforms-15395-field_34-container" (Ausweis)
  const idx34 = html.indexOf('data-field-id="34"');
  if (idx34 !== -1) {
    console.log('--- FOUND AUSWEIS (34) CONTAINER ---');
    console.log(html.slice(idx34 - 100, idx34 + 800));
  }

  // Find id="wpforms-15395-field_44-container" (Kreditvertrag)
  const idx44 = html.indexOf('data-field-id="44"');
  if (idx44 !== -1) {
    console.log('--- FOUND VERTREG (44) CONTAINER ---');
    console.log(html.slice(idx44 - 100, idx44 + 800));
  }
}

main();
