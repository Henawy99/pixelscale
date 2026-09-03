/**
 * Foodora Live Order Monitor (Passive UI & Fiber Extraction Architecture)
 * ----------------------------------------------------------------------
 * Runs 24/7 on the VPS connected to the active Chromium session on port 9223.
 * 
 * Key Design Principles for 100% Reliability:
 * 1. NEVER calls synthetic window.fetch() to https://vagw-api... (PerimeterX monkey-patches
 *    window.fetch and immediately returns 403 / triggers 'Press & hold' captchas for synthetic calls).
 * 2. Passively extracts live order summaries directly from React Fiber on the DataGrid table rows.
 * 3. Clicks order rows to open the official details drawer and extracts complete line items,
 *    delivery times, and payment details without triggering security blocks.
 * 4. Periodically clicks the UI date filter ("Today" / "Last 7 days") to prompt Foodora's own
 *    Apollo Client to fetch new orders with official PerimeterX context.
 * 5. Automatically dismisses any lingering popup dialogs.
 * 6. Dispatches all orders and line items to Supabase receive-foodora-order webhook.
 * 7. Serves /health and /api/foodora/sessions on port 3002 for Flutter app status.
 */

import puppeteer from 'puppeteer-core';
import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const WEBHOOK_URL = process.env.FOODORA_WEBHOOK_URL || 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/receive-foodora-order';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg1NjY2NTQsImV4cCI6MjA2NDE0MjY1NH0.nGrRDPvfH0VAf_naJvR9iKqFGo0kFZxv9hmgG6acmBQ';
const PORT = Number(process.env.FOODORA_MONITOR_PORT) || 3002;
const POLL_INTERVAL_MS = 15000; // 15 seconds

const ACCOUNT_ID = 'foodora-main';
const SEEN_ORDERS_FILE = path.join(__dirname, 'seen_orders.json');

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

let browserInstance = null;
let monitorPage = null;
let isPolling = false;
let lastPollTime = null;
let lastOrderSeenAt = null;
let monitorStatus = 'initializing';
let pollCycleCount = 0;

/**
 * Robust parsing of the drawer innerText to extract line items,
 * estimated delivery times, delivery fees, and payment methods.
 */
function parseDrawerText(text) {
  if (!text) return { items: [], deliveryFee: 0, paymentMethod: 'online', estDelivery: null };
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);

  let status = lines[0] || 'ACCEPTED';

  let estDelivery = null;
  const estIdx = lines.findIndex(l => l.toLowerCase().includes('estimated delivery time'));
  if (estIdx !== -1 && lines[estIdx + 1]) {
    estDelivery = lines[estIdx + 1];
  }

  let paymentMethod = 'online';
  const payIdx = lines.findIndex(l => l.toLowerCase() === 'payment method');
  if (payIdx !== -1 && lines[payIdx + 1]) {
    paymentMethod = lines[payIdx + 1].toLowerCase();
  }

  let deliveryFee = 0;
  const feeIdx = lines.findIndex(l => l.toLowerCase() === 'delivery fee');
  if (feeIdx !== -1 && lines[feeIdx + 1]) {
    const m = lines[feeIdx + 1].replace('€', '').trim();
    deliveryFee = parseFloat(m) || 0;
  }

  const startIdx = lines.findIndex(l => l.toLowerCase() === 'order details');
  const endIdx = lines.findIndex(l => l.toLowerCase() === 'final subtotal');

  const items = [];
  if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
    const itemLines = lines.slice(startIdx + 1, endIdx);
    let i = 0;
    while (i < itemLines.length) {
      const qMatch = itemLines[i].match(/^(\d+)[×x]/i);
      if (qMatch) {
        const quantity = parseInt(qMatch[1], 10);
        const name = itemLines[i + 1] || 'Item';
        let price = 0;
        let pIdx = i + 2;
        while (pIdx < itemLines.length && !itemLines[pIdx].includes('€') && !itemLines[pIdx].match(/^\d+[×x]/i)) {
          pIdx++;
        }
        if (pIdx < itemLines.length && itemLines[pIdx].includes('€')) {
          price = parseFloat(itemLines[pIdx].replace('€', '').trim()) || 0;
          i = pIdx + 1;
        } else {
          i = i + 2;
        }
        items.push({
          name,
          quantity,
          unitPrice: items.length > 0 && quantity > 1 ? +(price / quantity).toFixed(2) : price,
          lineItemTotal: price,
        });
      } else {
        i++;
      }
    }
  }

  return { status, estDelivery, paymentMethod, deliveryFee, items };
}

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
      return null;
    }
    console.log(`[Supabase] ✅ Dispatched ${payload.orderId}:`, json);
    return json;
  } catch (err) {
    console.error(`[Supabase] ❌ Network error for ${payload.orderId}:`, err.message);
    return null;
  }
}

async function getActivePage() {
  if (monitorPage && !monitorPage.isClosed()) return monitorPage;
  try {
    browserInstance = await puppeteer.connect({ browserURL: 'http://127.0.0.1:9223' });
    const pages = await browserInstance.pages();
    monitorPage = pages.find((p) => p.url().includes('foodora')) || pages[0];
    return monitorPage;
  } catch (_) {
    return null;
  }
}

async function dismissPopups(page) {
  try {
    await page.evaluate(() => {
      const btns = Array.from(document.querySelectorAll('button'));
      const closeBtn = btns.find(b => b.innerText && b.innerText.toLowerCase().trim() === 'close');
      if (closeBtn) closeBtn.click();
    });
  } catch (_) {}
}

async function triggerUIRefresh(page) {
  try {
    console.log('[Foodora] 🔄 Triggering UI date refresh...');
    await page.evaluate(() => {
      // Close any drawer first
      const closeBtns = Array.from(document.querySelectorAll('button')).filter(b => b.innerText && b.innerText.toLowerCase().trim() === 'close');
      for (const b of closeBtns) b.click();

      // Click the date filter chip
      const chip = Array.from(document.querySelectorAll('[data-testid="chip"], .MuiChip-root')).find(c => 
        c.innerText.includes('Last 7 days') || c.innerText.includes('Today') || c.innerText.includes('calendar_today')
      );
      if (chip) chip.click();
    });

    await new Promise(r => setTimeout(r, 600));

    await page.evaluate(() => {
      const item = Array.from(document.querySelectorAll('[role="menuitem"], [role="option"], .MuiMenuItem-root, li')).find(it =>
        it.innerText && (it.innerText.trim() === 'Today' || it.innerText.trim() === 'Last 7 days')
      );
      if (item) item.click();
    });
  } catch (err) {
    console.warn('[Foodora] UI refresh failed:', err.message);
  }
}

async function pollOrders() {
  if (isPolling) return;
  isPolling = true;
  pollCycleCount++;

  try {
    const page = await getActivePage();
    if (!page) {
      monitorStatus = 'waiting_for_browser';
      console.warn('[Foodora] Waiting for Chromium on port 9223...');
      return;
    }

    // Ensure we are on the orders page
    if (!page.url().includes('partner.foodora.com/orders')) {
      console.log('[Foodora] Navigating to partner.foodora.com/orders...');
      await page.goto('https://partner.foodora.com/orders', { waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => {});
      await new Promise(r => setTimeout(r, 3000));
    }

    // Dismiss any popups (e.g. promo or captcha modal close)
    await dismissPopups(page);

    // Periodically (every 3rd cycle ~45s) trigger legitimate UI refresh
    if (pollCycleCount % 3 === 0) {
      await triggerUIRefresh(page);
      await new Promise(r => setTimeout(r, 2000));
      await dismissPopups(page);
    }

    // Extract all orders from the React table
    const rows = await page.evaluate(() => {
      const rEls = Array.from(document.querySelectorAll('.MuiDataGrid-row'));
      return rEls.map(r => {
        let fiber = null;
        for (const k of Object.keys(r)) {
          if (k.startsWith('__reactFiber')) { fiber = r[k]; break; }
        }
        let cur = fiber;
        while (cur) {
          if (cur.memoizedProps?.row) return cur.memoizedProps.row;
          cur = cur.return;
        }
        return null;
      }).filter(Boolean);
    });

    lastPollTime = new Date().toISOString();
    monitorStatus = 'running';

    if (!rows || rows.length === 0) {
      return;
    }

    // Identify any orders not yet recorded in seenOrders
    const newOrUpdatedOrders = rows.filter(r => {
      const orderKey = `${r.orderId}:${(r.orderStatus || '').toLowerCase()}`;
      return !seenOrders.has(orderKey);
    });

    if (newOrUpdatedOrders.length > 0) {
      console.log(`[Foodora] 🔔 Found ${newOrUpdatedOrders.length} new/updated orders to process.`);

      for (const row of newOrUpdatedOrders) {
        const orderKey = `${row.orderId}:${(row.orderStatus || '').toLowerCase()}`;
        console.log(`[Foodora] Fetching details for ${row.orderId} (${row.vendorName})...`);

        // Click row to open details drawer
        const clicked = await page.evaluate((id) => {
          const rEls = Array.from(document.querySelectorAll('.MuiDataGrid-row'));
          const r = rEls.find(el => el.innerText.includes(id));
          if (r) {
            const cell = r.querySelector('[data-field="orderId"]') || r;
            cell.click();
            return true;
          }
          return false;
        }, row.orderId);

        let parsedDrawer = { items: [], deliveryFee: 0, paymentMethod: 'online', estDelivery: null };

        if (clicked) {
          await new Promise(r => setTimeout(r, 1200));
          const drawerText = await page.evaluate(() => {
            const d = document.querySelector('.MuiDrawer-paper') || document.querySelector('.MuiDrawer-root');
            if (!d) return '';
            const t = d.innerText;
            const closeBtn = d.querySelector('button');
            if (closeBtn) closeBtn.click();
            return t;
          });
          parsedDrawer = parseDrawerText(drawerText);
          console.log(`   📦 Extracted ${parsedDrawer.items.length} items: ${parsedDrawer.items.map(i => `${i.quantity}x ${i.name}`).join(', ')}`);
        }

        // Format estimated delivery time as valid ISO or omit
        let validEstDelivery = null;
        if (parsedDrawer.estDelivery) {
          try {
            const timeStr = parsedDrawer.estDelivery.trim();
            if (timeStr.includes('T') || timeStr.includes('-')) {
              validEstDelivery = timeStr;
            } else if (timeStr.includes(':')) {
              const placed = new Date(row.placedTimestamp);
              const parts = timeStr.split(':').map(p => parseInt(p, 10));
              if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                const estDate = new Date(placed);
                // Vienna is UTC+2 in summer (September)
                estDate.setUTCHours(parts[0] - 2, parts[1], 0, 0);
                validEstDelivery = estDate.toISOString();
              }
            }
          } catch (_) {}
        }

        const payload = {
          orderId: row.orderId,
          vendorId: row.vendorId,
          vendorName: row.vendorName,
          status: row.orderStatus,
          deliveryType: row.deliveryType || 'vendor_delivery',
          placedAt: row.placedTimestamp,
          estimatedDeliveryTime: validEstDelivery,
          total: row.subtotal,
          deliveryFee: parsedDrawer.deliveryFee,
          paymentMethod: parsedDrawer.paymentMethod,
          items: parsedDrawer.items,
          raw: row,
        };

        await dispatchWebhook(payload);
        seenOrders.add(orderKey);
        seenOrders.add(row.orderId);
        saveSeenOrders();
        lastOrderSeenAt = new Date().toISOString();
      }
    }
  } catch (err) {
    console.error('[Foodora] Polling error:', err.message);
    monitorPage = null;
    if (browserInstance) {
      try { browserInstance.disconnect(); } catch (_) {}
      browserInstance = null;
    }
  } finally {
    isPolling = false;
  }
}

// ── Express Server for Flutter App & Health Checks ──────────────────────────
const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: monitorStatus,
    platform: 'foodora',
    lastPollTime,
    lastOrderSeenAt,
    ordersTracked: seenOrders.size,
  });
});

app.get('/api/foodora/sessions', (req, res) => {
  res.json([
    {
      accountId: ACCOUNT_ID,
      restaurantName: 'Foodora Main Account (8 Branches)',
      platform: 'foodora',
      status: monitorStatus === 'running' ? 'active' : 'expired',
      lastCheckedAt: lastPollTime || new Date().toISOString(),
      lastOrderSeenAt,
      ordersTracked: seenOrders.size,
    },
  ]);
});

app.post('/api/foodora/sessions/:accountId/refresh', async (req, res) => {
  console.log('[Foodora API] Manual refresh requested.');
  if (monitorPage) {
    await triggerUIRefresh(monitorPage);
  }
  res.json({ success: true, status: 'active', message: 'Triggered orders refresh' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Foodora Monitor Service listening on http://0.0.0.0:${PORT}`);
});

console.log(`⏱️ Starting Foodora passive poller every ${POLL_INTERVAL_MS / 1000}s...`);
pollOrders();
setInterval(pollOrders, POLL_INTERVAL_MS);
