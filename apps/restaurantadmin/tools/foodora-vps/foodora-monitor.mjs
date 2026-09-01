/**
 * Foodora Live Order Monitor
 * -------------------------------------------------------------
 * Connects to the active Foodora Partner session on port 9223.
 * Queries GraphQL API for live orders every 10 seconds.
 * Queries GetOrderDetails & GetOrderCustomer for full details.
 * Automatically dispatches new/updated orders to Supabase receive-foodora-order.
 */

import puppeteer from 'puppeteer-core';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { initSessions, markActive, markExpired, markOrderSeen, startServer } from './foodora-api-server.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const WEBHOOK_URL = process.env.FOODORA_WEBHOOK_URL || 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/receive-foodora-order';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg1NjY2NTQsImV4cCI6MjA2NDE0MjY1NH0.nGrRDPvfH0VAf_naJvR9iKqFGo0kFZxv9hmgG6acmBQ';
const POLL_INTERVAL_MS = 10000; // 10 seconds

const ACCOUNT_ID = 'foodora-main';
const PROFILE_DIR = path.join(__dirname, 'profiles', ACCOUNT_ID);

// Initialize API Server
initSessions([{ id: ACCOUNT_ID, label: 'Foodora Main', profileDir: 'profiles/' + ACCOUNT_ID }]);
startServer();

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

const GLOBAL_VENDOR_CODES = [
  { globalEntityId: 'MJM_AT', vendorId: 'vo8z' }, // Crispy Chicken Lab
  { globalEntityId: 'MJM_AT', vendorId: 'brlb' }, // The Bowl Spot
  { globalEntityId: 'MJM_AT', vendorId: 'e9nt' }, // Devils Smash Burger
  { globalEntityId: 'MJM_AT', vendorId: 'qpcb' },
  { globalEntityId: 'MJM_AT', vendorId: 'cjte' },
  { globalEntityId: 'MJM_AT', vendorId: 'zoiw' }, // Tacotastic
  { globalEntityId: 'MJM_AT', vendorId: 'tu56' },
  { globalEntityId: 'MJM_AT', vendorId: 'cexj' },
];

const EXACT_DETAIL_QUERY = `
query GetOrderDetails($params: OrderReq!, $orderIssueParams: OrderIssuePicturesReq!, $hasPhotoEvidence: Boolean!) {
  orders {
    order(input: $params) {
      returnOrderPin
      hasBillingData
      isProOrder
      isDisputeAllowed
      order {
        orderId
        placedTimestamp
        status
        globalEntityId
        vendorId
        vendorName
        orderValue
        billableStatus
        delivery {
          provider
          location {
            AddressText
            city
            district
            postCode
            __typename
          }
          __typename
        }
        items {
          ...ItemFields
          __typename
        }
        __typename
      }
      pin
      orderReceipt {
        uploadedAt
        __typename
      }
      orderStatuses {
        status
        timestamp
        detail {
          ... on Accepted {
            estimatedDeliveryTime
            commitedPickupTime
            __typename
          }
          ... on Cancelled {
            owner
            reason
            __typename
          }
          ... on Delivered {
            timestamp
            __typename
          }
          ... on PickedUpByRider {
            timestamp
            avoidableWaitTime
            __typename
          }
          ... on RiderAtVendor {
            timestamp
            __typename
          }
          __typename
        }
        __typename
      }
      billing {
        billingStatus
        isCancelled
        estimatedVendorNetRevenue
        taxTotalAmount
        inputTax
        outputTax
        vendorPayout
        payment {
          cashAmountCollectedByVendor
          paymentType
          method
          paymentFee
          __typename
        }
        expense {
          serviceFee
          totalDiscountGross
          totalDiscount
          totalVoucher
          totalVendorDiscount
          totalVendorVoucher
          jokerFeeGross
          commissionAmountGross
          __typename
        }
        revenue {
          deliveryFeeGross
          serviceFee
          __typename
        }
        __typename
      }
      __typename
    }
    orderIssuePictures(input: $orderIssueParams) @include(if: $hasPhotoEvidence) {
      urls {
        original
        compressed
        thumbnail
        __typename
      }
      __typename
    }
    __typename
  }
}

fragment ItemFields on Item {
  id: productId
  name
  parentName
  quantity
  unitPrice
  customerNotes
  lineItemTotal
  lineItemId
  options {
    id
    name
    quantity
    type
    unitPrice
    __typename
  }
  __typename
}
`;

const EXACT_CUSTOMER_QUERY = `
query GetOrderCustomer($orderCustomerParams: OrderCustomerReq!) {
  orders {
    orderCustomer(input: $orderCustomerParams) {
      customer {
        name
        phone
        address
        __typename
      }
      __typename
    }
    __typename
  }
}
`;

let browserInstance = null;
let monitorPage = null;
let isPolling = false;
let lastPollTime = null;
let monitorStatus = 'initializing';

async function dispatchWebhook(orderPayload) {
  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify(orderPayload),
    });

    const result = await response.json();
    console.log(`[Webhook] Dispatched order ${orderPayload.orderId}:`, result);
  } catch (err) {
    console.error(`[Webhook] Failed to dispatch order ${orderPayload.orderId}:`, err);
  }
}

async function getActivePage() {
  if (monitorPage && !monitorPage.isClosed()) return monitorPage;
  try {
    if (!fs.existsSync(PROFILE_DIR)) {
      fs.mkdirSync(PROFILE_DIR, { recursive: true });
    }
    
    // Launch headless Chromium on VPS
    browserInstance = await puppeteer.launch({
      executablePath: '/usr/bin/chromium-browser',
      headless: 'new', // Run headless
      userDataDir: PROFILE_DIR,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--window-size=1280,800',
        '--disable-blink-features=AutomationControlled'
      ]
    });
    const pages = await browserInstance.pages();
    monitorPage = pages[0];
    await monitorPage.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await monitorPage.goto('https://portal.restaurant.foodora.at/', { waitUntil: 'networkidle2' });
    return monitorPage;
  } catch (err) {
    console.error('[Foodora VPS] Failed to launch browser:', err.message);
    return null;
  }
}

async function pollOrders() {
  if (isPolling) return;
  isPolling = true;

  try {
    const page = await getActivePage();
    if (!page) {
      console.warn('[Foodora] Waiting for Chrome connection on port 9223...');
      return;
    }

    let result;
    try {
      result = await page.evaluate(async (vendorCodes) => {
        const jwtRegex = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/;
        let token = null;
        for (const k of Object.keys(sessionStorage)) {
          const m = (sessionStorage.getItem(k) || '').match(jwtRegex);
          if (m) { token = m[0]; break; }
        }
        if (!token) {
          for (const k of Object.keys(localStorage)) {
            const m = (localStorage.getItem(k) || '').match(jwtRegex);
            if (m) { token = m[0]; break; }
          }
        }

        if (!token) return { error: 'No auth token found in storage' };

        const now = new Date();
        const past24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        const query = `
          query ListOrders($params: ListOrdersReq!) {
            orders {
              listOrders(input: $params) {
                orders {
                  orderId
                  globalEntityId
                  vendorId
                  vendorName
                  orderStatus
                  placedTimestamp
                  subtotal
                  deliveryType
                }
              }
            }
          }
        `;

        const variables = {
          params: {
            pagination: { pageSize: 50 },
            timeFrom: past24h.toISOString(),
            timeTo: now.toISOString(),
            globalVendorCodes: vendorCodes,
          },
        };

        try {
          const res = await window.fetch('https://vagw-api.eu.prd.portal.restaurant/query', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + token,
            },
            body: JSON.stringify({ operationName: 'ListOrders', query, variables }),
          });
          const text = await res.text();
          let data = null;
          try { data = JSON.parse(text); } catch (e) { data = text; }
          return { status: res.status, data, token };
        } catch (e) {
          return { error: 'Fetch failed: ' + e.message };
        }
      }, GLOBAL_VENDOR_CODES);
    } catch (evalErr) {
      console.error('[Foodora] page.evaluate failed (connection lost?). Resetting connection:', evalErr.message);
      monitorPage = null;
      if (browserInstance) {
        try { browserInstance.disconnect(); } catch (_) {}
        browserInstance = null;
      }
      return;
    }

    lastPollTime = new Date().toISOString();

    if (result?.error) {
      console.error('[Foodora] ListOrders query error:', result.error);
      return;
    }

    if (result?.status && result.status !== 200) {
      console.error(`[Foodora VPS] API returned status ${result.status}`);
      if (result.status === 401 || result.status === 403) {
        console.log('[Foodora VPS] Token expired. Marking session as expired for VNC relogin.');
        markExpired(ACCOUNT_ID);
        try { await page.reload({ waitUntil: 'networkidle2' }); } catch(e){}
      }
      return;
    }

    if (result?.data?.data?.orders?.listOrders?.orders) {
      markActive(ACCOUNT_ID);
      const orders = result.data.data.orders.listOrders.orders;
      const token = result.token;
      monitorStatus = 'running';
      console.log(`[Foodora] 🟢 Active: Polled ${orders.length} orders across 8 ghost kitchen brands.`);

      for (const o of orders) {
        const orderId = o.orderId;
        const status = (o.orderStatus || '').toLowerCase();
        const orderKey = `${orderId}:${status}`;

        if (!seenOrders.has(orderKey)) {
          console.log(`\n🆕 [Foodora] Fetching details for order: ${orderId} (${o.vendorName || o.vendorId}) → ${status}`);

          // Fetch full order details & customer details in parallel inside page
          const { detailResult, customerResult } = await page.evaluate(async (orderId, globalEntityId, vendorId, placedTimestamp, token, detailQuery, customerQuery) => {
            const rawPlaced = placedTimestamp || new Date().toISOString();
            const formattedPlaced = rawPlaced.includes('.') ? rawPlaced : rawPlaced.replace('Z', '.000Z');

            const detailVariables = {
              params: {
                orderId,
                GlobalVendorCode: { globalEntityId, vendorId },
                placedTimestamp: formattedPlaced,
                isBillingDataFlagEnabled: true,
              },
              orderIssueParams: {
                orderId,
                GlobalVendorCode: { globalEntityId, vendorId },
              },
              hasPhotoEvidence: false,
            };

            const customerVariables = {
              orderCustomerParams: {
                GlobalVendorCode: { globalEntityId, vendorId },
                orderId,
                placedTimestamp: formattedPlaced,
              },
            };

            const headers = {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + token,
            };

            const [dRes, cRes] = await Promise.all([
              window.fetch('https://vagw-api.eu.prd.portal.restaurant/query', {
                method: 'POST',
                headers,
                body: JSON.stringify({ operationName: 'GetOrderDetails', query: detailQuery, variables: detailVariables }),
              }).then(r => r.json()).catch(e => ({ error: e.message })),
              window.fetch('https://vagw-api.eu.prd.portal.restaurant/query', {
                method: 'POST',
                headers,
                body: JSON.stringify({ operationName: 'GetOrderCustomer', query: customerQuery, variables: customerVariables }),
              }).then(r => r.json()).catch(e => ({ error: e.message })),
            ]);

            return { detailResult: dRes, customerResult: cRes };
          }, o.orderId, o.globalEntityId, o.vendorId, o.placedTimestamp, token, EXACT_DETAIL_QUERY, EXACT_CUSTOMER_QUERY);

          const fullOrder = detailResult?.data?.orders?.order?.order || {};
          const statuses = detailResult?.data?.orders?.order?.orderStatuses || [];
          const billing = detailResult?.data?.orders?.order?.billing || {};
          const customer = customerResult?.data?.orders?.orderCustomer?.customer || {};

          let estDelivery = null;
          let estPickup = null;
          for (const s of statuses) {
            if (s.detail?.estimatedDeliveryTime) estDelivery = s.detail.estimatedDeliveryTime;
            if (s.detail?.commitedPickupTime) estPickup = s.detail.commitedPickupTime;
          }

          const location = fullOrder.delivery?.location || {};
          const items = (fullOrder.items || []).map((i) => ({
            name: i.name || i.parentName,
            quantity: i.quantity || 1,
            unitPrice: i.unitPrice,
            lineItemTotal: i.lineItemTotal,
            customerNotes: i.customerNotes,
            options: i.options || [],
          }));

          console.log(`   👤 Customer: ${customer.name || 'N/A'} | 📞 ${customer.phone || 'N/A'} | 📍 ${customer.address || 'N/A'}`);
          console.log(`   📦 Extracted ${items.length} items for ${orderId}: ${items.map(i => i.name).join(', ')}`);

          const payload = {
            orderId: o.orderId,
            vendorId: o.vendorId,
            vendorName: o.vendorName,
            status: fullOrder.status || o.orderStatus,
            deliveryType: o.deliveryType || 'delivery',
            placedAt: o.placedTimestamp,
            estimatedDeliveryTime: estDelivery,
            estimatedPickupTime: estPickup,
            total: fullOrder.orderValue || o.subtotal,
            deliveryFee: billing.revenue?.deliveryFeeGross || 0,
            serviceFee: billing.revenue?.serviceFee || 0,
            paymentMethod: billing.payment?.method || billing.payment?.paymentType || 'online',
            customerName: customer.name || null,
            customerPhone: customer.phone || null,
            customerAddress: customer.address || null,
            customerStreet: location.AddressText || null,
            customerPostcode: location.postCode || null,
            customerCity: location.city || null,
            items,
            raw: { summary: o, details: detailResult?.data?.orders?.order, customer },
          };

          await dispatchWebhook(payload);
          markOrderSeen(ACCOUNT_ID);
          seenOrders.add(orderKey);
          seenOrders.add(orderId);
          saveSeenOrders();
        }
      }
    }
  } catch (err) {
    console.error('[Foodora] Polling error:', err.message);
  } finally {
    isPolling = false;
  }
}

// API Server is started at the top.

console.log(`⏱️ Starting Foodora order poller every ${POLL_INTERVAL_MS / 1000}s...`);
pollOrders();
setInterval(pollOrders, POLL_INTERVAL_MS);
