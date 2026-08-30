/**
 * monitor.js  (PATCHED — adds api-server.js integration)
 *
 * This is the updated version of monitor.js that hooks into api-server.js
 * to expose live session-health data to the Flutter POS "Platforms" screen.
 *
 * CHANGES FROM ORIGINAL:
 *   1. Requires and starts api-server.js on port 3001 (configurable via API_PORT env var)
 *   2. Calls markActive / markExpired / markOrderSeen when those events occur
 *   3. WEBHOOK_URL now points to your Supabase receive-lieferando-order function
 *   4. Order payload is enriched with customer address fields for geocoding
 *
 * SETUP:
 *   1. Copy tools/lieferando-api-server.js → lieferando-multi-account/api-server.js
 *   2. npm install express  (in the lieferando-multi-account directory)
 *   3. Add to .env:
 *        WEBHOOK_URL=https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/receive-lieferando-order
 *        VPS_PUBLIC_IP=<your VPS IP>
 *        VNC_PORT=5901
 *        API_PORT=3001
 *   4. On your VPS, before starting:
 *        Xvfb :1 -screen 0 1280x800x24 &
 *        x11vnc -display :1 -nopw -listen 0.0.0.0 -xkb -forever &
 *        DISPLAY=:1 node monitor.js
 */

require('dotenv').config();
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// ── Load api-server module ───────────────────────────────────────────────────
const apiServer = require('./api-server');

const accounts = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'accounts.config.json'), 'utf-8'),
);

// Boot the API server and initialise session state for all accounts
apiServer.initSessions(accounts);
apiServer.startServer();

// ── Config ───────────────────────────────────────────────────────────────────
const ORDER_URL_PATTERN = /live-orders-api\.takeaway\.com\/api\/orders/i;
const ACTIVE_STATUSES = ['new', 'pending', 'received', 'accepted', 'preparing', 'ready', 'confirmed', 'kitchen', 'in_kitchen', 'created', 'sent', 'in_delivery'];
const WEBHOOK_URL = process.env.WEBHOOK_URL || null;
const RELOAD_INTERVAL_MS = 60 * 1000;
const OUTPUT_DIR = path.join(__dirname, 'output');
fs.mkdirSync(OUTPUT_DIR, { recursive: true });

// ── Order extraction (enriched with customer address fields) ─────────────────
function extractOrders(json, accountId) {
  const list = Array.isArray(json) ? json : json.orders || json.data || [];
  if (!Array.isArray(list)) return [];

  return list.map((o) => {
    const customer = o.customer || {};
    const extraNotes = Array.isArray(customer.extra) ? customer.extra.filter(Boolean) : [];

    return {
      accountId,
      orderId: o.id,
      publicReference: o.public_reference,
      status: o.status,
      deliveryType: o.delivery_type || 'delivery', // 'delivery' or 'pickup'
      placedAt: o.placed_date,
      confirmedAt: o.confirmed_at,
      total: o.customer_total,
      subtotal: o.subtotal,
      restaurantTotal: o.restaurant_total,
      deliveryFee: o.delivery_fee ?? 0,
      serviceFee: o.service_fee ?? 0,
      currency: o.currency,
      orderRemarks: o.remarks || null,
      deliveryNotes: extraNotes,
      // Customer identity
      customerName: customer.full_name || null,
      customerPhone: customer.phone_number || null,
      customerDisplayPhone: customer.display_phone_number || null,
      verificationCode: customer.phone_masking_code || null,
      // Customer address
      customerStreet: [customer.street, customer.street_number].filter(Boolean).join(' ') || null,
      customerPostcode: customer.postcode || null,
      customerCity: customer.city || null,
      // Order metadata & times
      estimatedDeliveryTime: o.restaurant_estimated_delivery_time || null,
      estimatedPickupTime: o.restaurant_estimated_pickup_time || null,
      requestedTime: o.requested_time || null,
      couriers: o.couriers || [],
      foodPrepDuration: o.food_preparation_duration ?? null,
      withAlcohol: o.with_alcohol ?? false,
      // Full product list with ALL Lieferando fields
      items: (o.products || []).map((p) => ({
        lieferandoProductId: p.id,
        code: p.code || null,
        name: p.name,
        categoryName: p.category_name || null,
        quantity: p.quantity,
        amount: p.amount, // unit price
        price: p.amount ?? (p.total_amount && p.quantity ? p.total_amount / p.quantity : p.total_amount), // unit price
        totalAmount: p.total_amount, // line total
        remarks: p.remarks || null,
        isAvailable: p.is_available,
        specifications: p.specifications || [],
        partnerProductIds: p.partner_product_ids || [],
        menuProductId: p.menu_product_id || null,
      })),
      // Full raw object — nothing lost
      raw: o,
      seenAt: new Date().toISOString(),
    };
  });
}

function isNewOrChanged(order, seenStatuses) {
  const prevStatus = seenStatuses.get(order.orderId);
  if (prevStatus === undefined) return true;
  return prevStatus !== order.status;
}

async function sendWebhook(order) {
  if (!WEBHOOK_URL) return;
  const anonKey = process.env.SUPABASE_ANON_KEY || '';
  try {
    const resp = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${anonKey}`,
        'apikey': anonKey,
      },
      body: JSON.stringify(order),
    });
    if (!resp.ok) {
      const body = await resp.text();
      console.error(`[${order.accountId}] webhook ${resp.status}:`, body.slice(0, 200));
    }
  } catch (err) {
    console.error(`[${order.accountId}] webhook failed:`, err.message);
  }
}

function appendOrder(order) {
  const file = path.join(OUTPUT_DIR, `${order.accountId}.jsonl`);
  fs.appendFileSync(file, JSON.stringify(order) + '\n');
}

// ── Per-account runner ───────────────────────────────────────────────────────
async function runAccount(account) {
  const profileDir = path.resolve(__dirname, account.profileDir);
  const seenStatuses = new Map();

  if (!fs.existsSync(profileDir)) {
    console.warn(
      `[${account.id}] No saved session found. Run: node login.js --account ${account.id}`,
    );
    apiServer.markExpired(account.id);
    return;
  }

  console.log(`[${account.id}] starting...`);

  const context = await chromium.launchPersistentContext(profileDir, {
    headless: true,
  });

  const page = context.pages()[0] || (await context.newPage());

  function handleOrder(order) {
    if (!isNewOrChanged(order, seenStatuses)) return;
    const isBrandNew = !seenStatuses.has(order.orderId);
    seenStatuses.set(order.orderId, order.status);

    if (isBrandNew && !ACTIVE_STATUSES.includes(order.status)) {
      appendOrder(order);
      return;
    }

    console.log(
      `[${order.accountId}] ${isBrandNew ? '🆕 NEW ORDER' : '🔄 STATUS CHANGE'}:`,
      order.orderId,
      '→',
      order.status,
    );
    appendOrder(order);
    sendWebhook(order);

    // ✅ Tell the API server an order was seen for this account
    apiServer.markOrderSeen(order.accountId);
  }

  // Intercept HTTP polling responses
  page.on('response', async (response) => {
    try {
      const url = response.url();
      if (!ORDER_URL_PATTERN.test(url)) return;
      const contentType = response.headers()['content-type'] || '';
      if (!contentType.includes('application/json')) return;
      const json = await response.json();
      const orders = extractOrders(json, account.id);

      // ✅ Mark account active whenever we get a valid API response
      if (orders.length >= 0) apiServer.markActive(account.id);

      orders.forEach(handleOrder);
    } catch {
      // non-JSON or unrelated response
    }
  });

  // WebSocket fallback
  page.on('websocket', (ws) => {
    ws.on('framereceived', (frame) => {
      try {
        const json = JSON.parse(frame.payload);
        extractOrders(json, account.id).forEach(handleOrder);
      } catch {
        // ignore non-JSON frames
      }
    });
  });

  await page.goto(account.ordersUrl, { waitUntil: 'domcontentloaded' });

  // Detect expired session (redirected to login page)
  if (/login|signin/i.test(page.url())) {
    console.warn(
      `[${account.id}] ⚠️  Session appears expired (redirected to login). ` +
      `Use the POS "Platforms" screen → Reconnect, or run: node login.js --account ${account.id}`,
    );
    // ❌ Mark as expired in the API
    apiServer.markExpired(account.id);
  } else {
    // ✅ First successful page load
    apiServer.markActive(account.id);
  }

  // Periodic reload to re-trigger polling
  setInterval(async () => {
    try {
      await page.reload({ waitUntil: 'domcontentloaded' });
      // Re-check for login redirect after reload
      if (/login|signin/i.test(page.url())) {
        apiServer.markExpired(account.id);
      }
    } catch (err) {
      console.error(`[${account.id}] reload failed:`, err.message);
    }
  }, RELOAD_INTERVAL_MS);

  console.log(`[${account.id}] ✅ monitoring live.`);
}

// ── Boot ─────────────────────────────────────────────────────────────────────
(async () => {
  console.log(`\n🚀 Starting monitor for ${accounts.length} accounts...\n`);
  await Promise.all(
    accounts.map((a) =>
      runAccount(a).catch((err) => {
        console.error(`[${a.id}] fatal:`, err);
        apiServer.markExpired(a.id);
      }),
    ),
  );
  console.log('\n✅ All accounts launched. Monitor is running.');
  console.log('   Leave this process alive (pm2 / systemd recommended).\n');
})();
