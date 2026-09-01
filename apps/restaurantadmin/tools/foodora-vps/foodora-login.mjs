import puppeteer from 'puppeteer-core';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const accountId = process.argv.includes('--account') 
  ? process.argv[process.argv.indexOf('--account') + 1] 
  : 'foodora-main';

const profileDir = path.join(__dirname, 'profiles', accountId);
if (!fs.existsSync(profileDir)) {
  fs.mkdirSync(profileDir, { recursive: true });
}

console.log(`[Foodora Login] Starting headed browser for ${accountId}...`);

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/chromium-browser', // Standard path on Linux VPS
    headless: false, // MUST be false for VNC
    userDataDir: profileDir,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1280,800',
      '--start-maximized',
      '--disable-blink-features=AutomationControlled' // Helps bypass basic bot checks
    ],
    defaultViewport: null,
  });

  const page = await browser.newPage();
  
  // Set fake user agent to help with Cloudflare
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

  try {
    await page.goto('https://portal.restaurant.foodora.at/', { waitUntil: 'networkidle2', timeout: 60000 });
  } catch (err) {
    console.error('[Foodora Login] Timeout or error loading Foodora portal:', err.message);
  }

  console.log(`[Foodora Login] Browser opened for ${accountId}. Waiting 5 minutes for VNC manual login...`);

  // Wait 5 minutes to allow the user to connect via VNC and log in
  await new Promise(r => setTimeout(r, 5 * 60 * 1000));

  console.log(`[Foodora Login] 5 minutes elapsed. Closing browser for ${accountId}.`);
  await browser.close();
})();
