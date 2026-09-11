/**
 * Foodora Live Order Relay (Windows POS Edition)
 * -------------------------------------------------------------------------
 * Runs locally on the restaurant's Windows POS PC on the local Austrian Wi-Fi.
 * 
 * Features:
 * 1. Connects to Foodora Live Orders portal (https://partner.foodora.com/live-orders).
 * 2. Captures Bearer JWT token and streams deliveries directly from Foodora's 
 *    live deliveries endpoint (vendor-api-gdp.eu.restaurant-partners.com).
 * 3. 100% complete customer extraction: Name, Phone, Street, House Number, Floor, 
 *    Apartment, Postcode, City, Delivery Notes, and Line Items.
 * 4. Automatic PerimeterX human verification bypass and login persistence.
 * 5. Syncs in real time directly to Supabase Edge Function (receive-foodora-order).
 */

import puppeteer from 'puppeteer-core';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Supabase Webhook Configuration
const WEBHOOK_URL = 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/receive-foodora-order';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg1NjY2NTQsImV4cCI6MjA2NDE0MjY1NH0.nGrRDPvfH0VAf_naJvR9iKqFGo0kFZxv9hmgG6acmBQ';
const POLL_INTERVAL_MS = 15000; // 15 seconds

const PROFILE_DIR = path.join(__dirname, 'foodora-profile');
const SEEN_ORDERS_FILE = path.join(__dirname, 'seen_orders.json');

// Find Chrome or Edge executable on Windows
function findBrowserExecutable() {
  const possiblePaths = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    path.join(process.env.LOCALAPPDATA || '', 'Google\\Chrome\\Application\\chrome.exe'),
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    path.join(process.env.LOCALAPPDATA || '', 'Microsoft\\Edge\\Application\\msedge.exe'),
  ];

  for (const p of possiblePaths) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error('Neither Google Chrome nor Microsoft Edge was found on this PC.');
}

// Load seen orders
let seenOrders = new Set();
try {
  if (fs.existsSync(SEEN_ORDERS_FILE)) {
    const data = JSON.parse(fs.readFileSync(SEEN_ORDERS_FILE, 'utf8'));
    seenOrders = new Set(data);
  }
} catch (_) {}

function saveSeenOrders() {
  try {
    fs.writeFileSync(SEEN_ORDERS_FILE, JSON.stringify([...seenOrders], null, 2));
  } catch (_) {}
}

/**
 * Dispatch an order payload to Supabase
 */
async function dispatchWebhook(payload) {
  try {
    const res = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify(payload),
    });
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch (_) { json = text; }
    if (!res.ok) {
      console.error(`[Supabase] ⚠️ HTTP ${res.status} for ${payload.orderId}:`, json);
      return false;
    }
    console.log(`[Supabase] ✅ Successfully synced ${payload.orderId} (${payload.vendorName}) - ${payload.customerName || 'No Name'} | ${payload.customerPhone || 'No Phone'}`);
    return true;
  } catch (err) {
    console.error(`[Supabase] ❌ Network error for ${payload.orderId}:`, err.message);
    return false;
  }
}

/**
 * Process a delivery item from Foodora Deliveries API
 */
async function processDelivery(d) {
  const orderId = d.externalId || d.id;
  if (!orderId) return;

  const state = d.state || 'UNKNOWN';
  const customerName = (d.customer?.firstName || d.customer?.lastName)
    ? `${d.customer.firstName || ''} ${d.customer.lastName || ''}`.trim()
    : null;
  const customerPhone = d.customer?.phone || null;

  let street = d.address?.street || '';
  if (d.address?.building) street += ` ${d.address.building}`;
  street = street.trim() || null;

  const postcode = d.address?.zip || null;
  const city = d.address?.city || null;
  const note = [
    d.address?.info,
    d.address?.apartment ? `Apt: ${d.address.apartment}` : '',
    d.address?.floor ? `Floor: ${d.address.floor}` : ''
  ].filter(Boolean).join(' | ') || null;

  const dedupeKey = `${orderId}:${state.toLowerCase()}:${customerName || 'none'}`;
  if (seenOrders.has(dedupeKey)) {
    return; // Already processed
  }

  const items = (d.items || []).map(it => ({
    name: it.name,
    quantity: it.amount || 1,
    unitPrice: it.price || 0,
    lineItemTotal: it.total || it.price || 0
  }));

  const payload = {
    orderId,
    vendorId: d.externalRestaurantId || d.lpvId,
    vendorName: d.vendorName,
    status: state,
    deliveryType: d.transport?.type || 'restaurant_delivery',
    placedAt: d.timestamp,
    estimatedDeliveryTime: d.deliverAt || d.promisedTime,
    total: d.payment?.total || d.payment?.itemsTotalPrice || 0,
    deliveryFee: d.fees?.find(f => f.name === 'DeliveryFee')?.value || 0,
    paymentMethod: d.payment?.paymentMethod || d.payment?.paymentType || 'ONLINE',
    customerName,
    customerPhone,
    customerStreet: street,
    customerPostcode: postcode,
    customerCity: city,
    note,
    deliveryNotes: note,
    items,
    raw: d
  };

  console.log(`\n🔔 Processing Order: ${orderId} (${d.vendorName}) [${state}]`);
  console.log(`   👤 Customer: ${customerName || 'N/A'} | 📞 ${customerPhone || 'N/A'}`);
  console.log(`   📍 Address: ${street || 'N/A'}, ${postcode || ''} ${city || ''}`);

  const success = await dispatchWebhook(payload);
  if (success) {
    seenOrders.add(dedupeKey);
    saveSeenOrders();
  }
}

/**
 * Solve or dismiss PerimeterX captcha if it ever appears
 */
async function handleCaptchaIfPresent(page) {
  try {
    const selectors = [
      '#px-captcha',
      '#px-captcha-wrapper',
      '[aria-label*="Press & Hold"]',
      '[aria-label*="Drücken und halten"]',
      '[aria-label*="halten"]',
      'div[id*="px-captcha"]',
    ];

    let target = null;

    for (const frame of [page, ...page.frames()]) {
      for (const sel of selectors) {
        try {
          const el = await frame.$(sel);
          if (!el) continue;

          const isVis = await el.evaluate(node => {
            const rect = node.getBoundingClientRect();
            const s = window.getComputedStyle(node);
            return rect.width > 20 && rect.height > 20 && s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0';
          }).catch(() => false);

          if (isVis) {
            target = { el, sel };
            break;
          }
        } catch (_) {}
      }
      if (target) break;
    }

    if (!target) return;

    const box = await target.el.boundingBox();
    if (!box || box.width < 15 || box.height < 15) return;

    console.log(`[Security] Human verification modal detected via "${target.sel}" (${Math.round(box.width)}x${Math.round(box.height)})! Solving automatically...`);
    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;

    await page.mouse.move(centerX, centerY, { steps: 5 });
    await page.mouse.down();
    await new Promise(r => setTimeout(r, 6500));
    await page.mouse.up();
    console.log('[Security] Hold completed. Verifying release...');
    await new Promise(r => setTimeout(r, 2500));
  } catch (err) {
    console.warn('[Security] Captcha notice:', err.message);
  }
}

/**
 * Dismiss promotional or system popups
 */
async function dismissPopups(page) {
  try {
    await page.evaluate(() => {
      const dismissTexts = ['got it', 'close', 'accept', 'dismiss', 'schließen', 'verstanden', 'ok'];
      const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
      for (const btn of buttons) {
        const t = (btn.innerText || '').toLowerCase().trim();
        if (dismissTexts.includes(t)) {
          btn.click();
        }
      }
    });
  } catch (_) {}
}

/**
 * Main relay runner
 */
async function run() {
  const browserPath = findBrowserExecutable();
  console.log('====================================================');
  console.log('  Foodora Live Order Relay — Windows POS Edition');
  console.log('====================================================');
  console.log('Browser:', browserPath);
  console.log('Profile:', PROFILE_DIR);
  console.log('Webhook:', WEBHOOK_URL);
  console.log('Starting browser on Austrian local network...');

  const browser = await puppeteer.launch({
    executablePath: browserPath,
    userDataDir: PROFILE_DIR,
    headless: false,
    defaultViewport: null,
    args: [
      '--start-maximized',
      '--disable-blink-features=AutomationControlled',
      '--remote-debugging-port=9222',
    ],
  });

  const pages = await browser.pages();
  const page = pages[0] || (await browser.newPage());

  // Mask automated browser indicators
  await page.evaluateOnNewDocument(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    window.chrome = window.chrome || { runtime: {} };
  });

  // Track latest Bearer token and headers
  let currentAuthHeader = null;
  let currentVendorId = 'TUpNX0FULXFwY2I';

  page.on('request', (req) => {
    const url = req.url();
    if (url.includes('deliveries-web') || url.includes('restaurant-partners.com')) {
      const auth = req.headers()['authorization'];
      if (auth && auth.startsWith('Bearer ')) {
        currentAuthHeader = auth;
      }
      const vid = req.headers()['x-vendor-id'];
      if (vid) currentVendorId = vid;
    }
  });

  // Intercept responses from Foodora Deliveries API
  page.on('response', async (res) => {
    try {
      const url = res.url();
      if (!url.includes('deliveries-web')) return;
      const ct = res.headers()['content-type'] || '';
      if (!ct.includes('application/json')) return;

      const bodyText = await res.text().catch(() => null);
      if (!bodyText) return;

      let json = null;
      try { json = JSON.parse(bodyText); } catch (_) {}
      if (!json || !Array.isArray(json)) return;

      for (const d of json) {
        await processDelivery(d);
      }
    } catch (_) {}
  });

  console.log('Navigating to Foodora Live Orders...');
  await page.goto('https://partner.foodora.com/live-orders', {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  }).catch(() => {});

  console.log('\n>>> If this is your first time starting, please LOG IN on the browser window. <<<');
  console.log('>>> Your session will be saved automatically for future restarts. <<<\n');

  let pollCount = 0;

  while (true) {
    try {
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      pollCount++;

      if (page.isClosed()) {
        console.warn('Browser page was closed. Re-opening...');
        break;
      }

      await handleCaptchaIfPresent(page);
      await dismissPopups(page);

      // Periodically (every 2 minutes) refresh live orders page to maintain websocket connection
      if (pollCount % 8 === 0) {
        await page.evaluate(() => {
          if (window.location.pathname !== '/live-orders') {
            window.location.href = '/live-orders';
          }
        }).catch(() => {});
      }

      // Direct polling of deliveries-web endpoint using authentic captured Bearer token
      if (currentAuthHeader) {
        const from = new Date(Date.now() - 48 * 3600 * 1000).toISOString();
        const apiUrl = `https://vendor-api-gdp.eu.restaurant-partners.com/api/2/deliveries-web?from=${from}`;

        try {
          const apiRes = await fetch(apiUrl, {
            headers: {
              'authorization': currentAuthHeader,
              'x-global-entity-id': 'MJM_AT',
              'x-vendor-id': currentVendorId,
              'x-app-name': 'oneweb',
              'x-app-version': '5.1.11',
              'x-rps-client-app-name': 'OneWeb',
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'accept': 'application/json, text/plain, */*'
            }
          });

          if (apiRes.ok) {
            const deliveries = await apiRes.json();
            if (pollCount % 4 === 1) {
              console.log(`[Status #${pollCount}] Live API active: ${deliveries.length} orders tracked in past 48h.`);
            }
            for (const d of deliveries) {
              await processDelivery(d);
            }
          } else if (apiRes.status === 401 || apiRes.status === 403) {
            // Token expired, reload page to refresh token
            console.log('[Auth] Token expired, refreshing live orders page...');
            currentAuthHeader = null;
            await page.reload({ waitUntil: 'domcontentloaded' }).catch(() => {});
          }
        } catch (fetchErr) {
          console.warn('[Poll] Fetch notice:', fetchErr.message);
        }
      } else {
        if (pollCount % 2 === 1) {
          console.log(`[Status #${pollCount}] Waiting for Bearer token from live-orders page...`);
        }
      }
    } catch (err) {
      console.error('Polling error (will retry):', err.message);
    }
  }

  setTimeout(run, 5000);
}

run().catch(err => {
  console.error('Fatal error:', err);
  setTimeout(run, 10000);
});
