import puppeteer from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

puppeteer.use(StealthPlugin());

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const OUTPUT_DIR = path.join(__dirname, 'output');
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const PROFILE_DIR = path.join(__dirname, 'foodora-profile');
if (!fs.existsSync(PROFILE_DIR)) {
  fs.mkdirSync(PROFILE_DIR, { recursive: true });
}

async function start() {
  console.log('🚀 Launching Chrome for Foodora inspection...');
  console.log(`📁 User Data Directory: ${PROFILE_DIR}`);

  const browser = await puppeteer.launch({
    headless: false,
    userDataDir: PROFILE_DIR,
    defaultViewport: null,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--start-maximized',
      '--disable-blink-features=AutomationControlled',
    ],
  });

  const page = (await browser.pages())[0] || (await browser.newPage());

  // Listen to all network requests & responses
  page.on('request', (request) => {
    const url = request.url();
    const postData = request.postData();

    if (postData && (url.includes('graphql') || url.includes('query') || postData.includes('order') || postData.includes('Order'))) {
      console.log(`\n📤 [REQUEST] ${request.method()} ${url}`);
      try {
        const parsed = JSON.parse(postData);
        console.log(`   Operation: ${parsed.operationName || 'Unnamed'}`);
        fs.appendFileSync(
          path.join(OUTPUT_DIR, 'requests.jsonl'),
          JSON.stringify({ timestamp: new Date().toISOString(), url, headers: request.headers(), postData: parsed }) + '\n'
        );
      } catch (_) {
        console.log(`   Post Data: ${postData.substring(0, 150)}...`);
      }
    }
  });

  page.on('response', async (response) => {
    const url = response.url();
    const request = response.request();
    const contentType = response.headers()['content-type'] || '';

    if (contentType.includes('application/json')) {
      try {
        const text = await response.text();
        if (
          text.includes('order') ||
          text.includes('Order') ||
          text.includes('listOrderChanges') ||
          url.includes('graphql') ||
          url.includes('query')
        ) {
          const parsed = JSON.parse(text);
          console.log(`\n📥 [RESPONSE] ${response.status()} ${url}`);

          // Check if this has order data
          if (text.includes('customer') || text.includes('products') || text.includes('items') || text.includes('total')) {
            console.log('   🎉 Captured order details!');
            fs.writeFileSync(path.join(OUTPUT_DIR, 'latest_order_response.json'), JSON.stringify(parsed, null, 2));
          }

          fs.appendFileSync(
            path.join(OUTPUT_DIR, 'responses.jsonl'),
            JSON.stringify({ timestamp: new Date().toISOString(), url, status: response.status(), data: parsed }) + '\n'
          );
        }
      } catch (_) {}
    }
  });

  console.log('🌐 Navigating to https://partner.foodora.com/orders ...');
  await page.goto('https://partner.foodora.com/orders', { waitUntil: 'networkidle2' });

  console.log('\n✅ Browser opened! Please log into Foodora if prompted.');
  console.log('👀 I am intercepting all GraphQL queries and order responses in real-time.\n');
}

start().catch(console.error);
