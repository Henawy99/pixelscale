const https = require('https');
const fs = require('fs');

const GL_RECHT_FORM_URL = 'https://gl-recht.at/kreditvertragsgebuhren-koop/';
const GL_RECHT_FORM_ID = '15395';
const GL_RECHT_PARTNER = 'Konsumentenretter';

async function extractFormTokens() {
  return new Promise((resolve, reject) => {
    const url = `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`;
    const reqOptions = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-AT,de;q=0.9,en;q=0.8',
      }
    };
    https.get(url, reqOptions, (res) => {
      let html = '';
      res.on('data', (chunk) => html += chunk);
      res.on('end', () => {
        const nonceMatch = html.match(/name="wpforms\[nonce\]"\s+value="([^"]+)"/);
        const nonceScriptMatch = html.match(/"wpforms_settings".*?"nonce":"([^"]+)"/);
        const nonce = nonceMatch?.[1] || nonceScriptMatch?.[1] || '';

        const tokenMatch = html.match(/data-token="([^"]+)"/);
        const tokenTimeMatch = html.match(/data-token-time="([^"]+)"/);
        const token = tokenMatch?.[1] || '';
        const tokenTime = tokenTimeMatch?.[1] || '';

        const setCookies = res.headers['set-cookie'] || [];
        const cookies = setCookies.map(c => c.split(';')[0]).join('; ');

        resolve({ nonce, token, tokenTime, cookies });
      });
    }).on('error', reject);
  });
}

async function testSubmit() {
  console.log('Extracting tokens...');
  const tokens = await extractFormTokens();
  console.log('Tokens extracted:', tokens);

  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
  
  // Create mock files
  const mockFile = Buffer.from('Mock file content to test uploader', 'utf8');

  // Build multipart body
  let parts = [];

  function addField(name, value) {
    let part = `--${boundary}\r\n`;
    part += `Content-Disposition: form-data; name="${name}"\r\n\r\n`;
    part += `${value}\r\n`;
    parts.push(Buffer.from(part, 'utf8'));
  }

  function addFile(fieldName, fileName, content, type) {
    let part = `--${boundary}\r\n`;
    part += `Content-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n`;
    part += `Content-Type: ${type}\r\n\r\n`;
    parts.push(Buffer.from(part, 'utf8'));
    parts.push(content);
    parts.push(Buffer.from('\r\n', 'utf8'));
  }

  // System/Hidden fields
  addField('wpforms[id]', GL_RECHT_FORM_ID);
  if (tokens.nonce) {
    addField('wpforms[nonce]', tokens.nonce);
  }
  addField('wpforms[token]', tokens.token);
  addField('wpforms[token_time]', tokens.tokenTime);
  addField('wpforms[fields][4]', ''); // Honeypot

  // Form Fields
  addField('wpforms[fields][1]', 'Test Forwarding Antigravity');
  addField('wpforms[fields][8]', 'test_forwarding_gemini@pixelscale.at');
  
  // Birthdate
  addField('wpforms[fields][5][date][d]', '12');
  addField('wpforms[fields][5][date][m]', '6');
  addField('wpforms[fields][5][date][y]', '1990');

  // Address
  addField('wpforms[fields][6]', 'Teststrasse 123');
  addField('wpforms[fields][26]', 'Wien');
  addField('wpforms[fields][25]', '1010');
  addField('wpforms[fields][7]', '+436601234567');
  
  // Referrer and Banks
  addField('wpforms[fields][52]', '');
  addField('wpforms[fields][54][]', 'BAWAG');
  addField('wpforms[fields][54][]', 'Andere');
  addField('wpforms[fields][55]', 'Sparkasse Test Bank');

  // Legal
  addField('wpforms[fields][33][]', 'ich die unten stehenden Vollmachten sowie den Vollfinanzierungsantrag samt Anlagen gelesen und verstanden habe.');
  addField('wpforms[fields][41][]', 'ich den Newsletter erhalten möchte und mit der Verarbeitung meiner Daten zum Versand einverstanden bin.');

  // Date & Partner
  addField('wpforms[fields][3]', '12.06.2026');
  addField('wpforms[fields][46]', GL_RECHT_PARTNER);
  addField('wpforms[fields][45]', '');

  // WPForms Verification context
  addField('page_title', 'Kreditvertragsgebühren – Koop');
  addField('page_url', `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`);
  addField('url_referer', '');
  addField('page_id', '15387');
  addField('wpforms[post_id]', '15387');
  addField('wpforms[submit]', 'wpforms-submit');

  // Signature (Mock base64 signature string)
  addField('wpforms[fields][2]', 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

  // Files (Mock upload files under all candidate names to maximize compatibility)
  addFile('wpforms[fields][34][]', 'ausweis_test.pdf', mockFile, 'application/pdf');
  addFile('wpforms[fields][44][]', 'vertrag_test.pdf', mockFile, 'application/pdf');

  addFile('wpforms_15395_34[]', 'ausweis_test.pdf', mockFile, 'application/pdf');
  addFile('wpforms_15395_44[]', 'vertrag_test.pdf', mockFile, 'application/pdf');

  addFile('wpforms_15395_34', 'ausweis_test.pdf', mockFile, 'application/pdf');
  addFile('wpforms_15395_44', 'vertrag_test.pdf', mockFile, 'application/pdf');

  // End boundary
  parts.push(Buffer.from(`--${boundary}--\r\n`, 'utf8'));

  // Calculate length
  let totalLength = 0;
  for (const part of parts) {
    totalLength += part.length;
  }

  console.log('Sending submit POST request to GL-Recht...');
  const actionUrl = `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}&wpforms_form_id=${GL_RECHT_FORM_ID}`;

  const reqOptions = {
    hostname: 'gl-recht.at',
    path: `/kreditvertragsgebuhren-koop/?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}&wpforms_form_id=${GL_RECHT_FORM_ID}`,
    method: 'POST',
    headers: {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': totalLength,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Referer': `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`,
      'Origin': 'https://gl-recht.at',
      'Cookie': tokens.cookies
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', reject);

    for (const part of parts) {
      req.write(part);
    }
    req.end();
  });
}

testSubmit().then(res => {
  console.log('Response Status:', res.status);
  console.log('Response Headers:', res.headers);
  fs.writeFileSync('/Users/youssefelhenawy/Desktop/pixelscale/scratch/response.html', res.body);
  console.log('Response HTML written to scratch/response.html');
}).catch(err => {
  console.error('Error:', err);
});
