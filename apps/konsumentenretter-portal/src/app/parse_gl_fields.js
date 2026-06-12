async function main() {
  const url = 'https://gl-recht.at/kreditvertragsgebuhren-koop/?wpf15395_46=Konsumentenretter';
  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
    });
    const html = await response.text();

    console.log('--- FORM FIELDS FOUND IN HTML ---');

    // Let's find the main form
    const formStart = html.indexOf('<form id="wpforms-form-15395"');
    if (formStart === -1) {
      console.log('Could not find form #wpforms-form-15395');
      return;
    }
    const formEnd = html.indexOf('</form>', formStart);
    const formHtml = html.slice(formStart, formEnd + 7);

    // Find all inputs, selects, textareas, and canvas
    // Match name="..." and id="..."
    const inputRegex = /<(input|select|textarea)[^>]*name="([^"]+)"[^>]*/g;
    let match;
    const fields = [];
    while ((match = inputRegex.exec(formHtml)) !== null) {
      const tag = match[1];
      const name = match[2];
      
      // Extract type and id if present
      const typeMatch = match[0].match(/type="([^"]+)"/);
      const type = typeMatch ? typeMatch[1] : '';
      
      const idMatch = match[0].match(/id="([^"]+)"/);
      const id = idMatch ? idMatch[1] : '';

      fields.push({ tag, name, type, id });
    }

    console.table(fields);

    // Also look for elements with class wpforms-field to check field IDs
    const fieldIdRegex = /id="wpforms-15395-field_(\d+)-container"/g;
    const fieldIds = new Set();
    while ((match = fieldIdRegex.exec(formHtml)) !== null) {
      fieldIds.add(match[1]);
    }
    console.log('Detected Field IDs:', Array.from(fieldIds).join(', '));
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
