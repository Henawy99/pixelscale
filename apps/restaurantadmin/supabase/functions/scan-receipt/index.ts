/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { encode, decode as b64decode } from 'https://deno.land/std@0.208.0/encoding/base64.ts';
import { sendPushNotification } from '../_shared/fcm.ts';


const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-scanner-secret',
};

// Known brand mapping (ghost kitchens)
const BRAND_ID_MAP: Record<string, string> = {
  'DEVILS SMASH BURGER': '4446a388-aaa7-402f-be4d-b82b23797415',
  'CRISPY CHICKEN LAB': '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
  'THE BOWL SPOT': '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
  'TACOTASTIC': 'f5116077-8de3-488b-bf9d-75295f791dce',
};

function findBrandIdByName(name?: string | null): { id: string | null; normalizedName?: string } {
  if (!name) return { id: null };
  const upper = String(name).trim().toUpperCase();
  for (const key of Object.keys(BRAND_ID_MAP)) {
    if (upper.includes(key)) return { id: BRAND_ID_MAP[key], normalizedName: key };
  }
  return { id: null };
}

type ScanType = 'order' | 'purchase' | 'unknown';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: 'Invalid JSON payload' }, 400);
  }

  // Scanner secret path for headless bridges (no JWT required)
  const scannerSecretHeader = req.headers.get('x-scanner-secret') ?? req.headers.get('X-Scanner-Secret');
  const configuredScannerSecret = Deno.env.get('SCANNER_SECRET') || '';

  // Two clients: service (bypass RLS) and user (JWT). Use service ONLY for storage upload & scanned_receipts.
  const supabaseService = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  // Default to requiring either a valid scanner secret or a user Authorization header
  const authHeader = req.headers.get('Authorization');
  let supabaseUser: any;
  if (scannerSecretHeader && configuredScannerSecret && scannerSecretHeader === configuredScannerSecret) {
    // Headless scanner: use service role for main ops too
    supabaseUser = supabaseService;
  } else if (authHeader) {
    supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );
  } else {
    return json({ error: 'Missing Authorization or invalid scanner secret' }, 401);
  }
  // Keep existing code references working
  const supabase = supabaseUser;

  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  if (!GEMINI_API_KEY) {
    console.error('[scan-receipt] Missing GEMINI_API_KEY');
    return json({ error: 'Server missing Gemini configuration' }, 500);
  }

  const {
    brandId,
    brandName,
    receiptImageBase64,
    storageSignedUrl,
    platformOrderId,
    idempotencyKey,
    noSave, // Add a flag to prevent saving
  } = payload ?? {};

  if (!receiptImageBase64 && !storageSignedUrl) {
    return json({ error: 'Provide receiptImageBase64 or storageSignedUrl' }, 400);
  }

  // Idempotency: optional example using a receipts_processed table
  if (idempotencyKey) {
    try {
      const { data: existing, error } = await supabase
        .from('receipts_processed')
        .select('created_id, created_type')
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();
      if (error) console.log('[scan-receipt] idempotency lookup error:', error.message);
      if (existing?.created_id) {
        return json({ ok: true, id: existing.created_id, type: existing.created_type, duplicate: true });
      }
    } catch (e) {
      console.log('[scan-receipt] idempotency lookup exception:', e);
    }
  }

  try {
    // Load image bytes
    let base64Image = receiptImageBase64 as string | undefined;
    if (!base64Image && storageSignedUrl) {
      const arrBuf = await fetch(storageSignedUrl).then((r) => r.arrayBuffer());
      base64Image = encode(new Uint8Array(arrBuf));
    }

    // Optional operator tuning and template stored in DB settings

	    // Path of uploaded image in storage for UI linking
	    let storagePath: string | null = null;

    // Load prompt from scanner_settings
    let orderPrompt: string | null = null;
    let purchasePrompt: string | null = null;
    let suppliersList: string = '';
    try {
      const { data: sRow } = await supabase
        .from('scanner_settings')
        .select('order_prompt, purchase_prompt')
        .eq('id', 'default')
        .maybeSingle();
      orderPrompt = (sRow?.order_prompt as string | null) ?? null;
      purchasePrompt = (sRow?.purchase_prompt as string | null) ?? null;
    } catch (_) {}

    // Build suppliers CSV to include as context
    try {
      const { data: supplierRows } = await supabase
        .from('suppliers')
        .select('name');
      if (Array.isArray(supplierRows) && supplierRows.length) {
        suppliersList = supplierRows.map((r: any) => r?.name).filter(Boolean).join(', ');
      }
    } catch (_) {}

    // Always persist image for UI viewing using whatever source (base64 or signed URL)
    if (!storagePath) {
      try {
        const now = new Date();
        const y = now.getUTCFullYear();
        const m = String(now.getUTCMonth() + 1).padStart(2, '0');
        const d = String(now.getUTCDate()).padStart(2, '0');
        const uuid = crypto.randomUUID();
        storagePath = `incoming/${y}/${m}/${d}/${uuid}.jpg`;
        const bytes = base64Image ? Uint8Array.from(atob(base64Image), c => c.charCodeAt(0)) : new Uint8Array();
        const { error: upErr } = await supabaseService.storage
          .from('scanned-receipts')
          .upload(storagePath, new Blob([bytes], { type: 'image/jpeg' }), {
            contentType: 'image/jpeg',
            upsert: false,
          } as any);
        if (upErr) {
          console.log('[scan-receipt] storage upload failed', upErr.message);
          storagePath = null;
        }
      } catch (e) {
        console.log('[scan-receipt] storage upload exception', e);
        storagePath = null;
      }
    }

    // Call Gemini for classification only - using v1beta API with Gemini 2.5 Flash
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    const extractionPrompt = buildExtractionPrompt(orderPrompt, purchasePrompt, suppliersList);
    const geminiPayload = {
      contents: [
        {
          parts: [
            { text: extractionPrompt },
            { 
              inlineData: { 
                mimeType: 'image/jpeg', 
                data: base64Image 
              } 
            },
          ],
        },
      ],
    };

    const geminiResp = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResp.ok) {
      const t = await geminiResp.text();
      console.error('[scan-receipt] Gemini error', geminiResp.status, t);
      return json({ error: 'Gemini request failed', details: t }, geminiResp.status);
    }

    const geminiResult = await geminiResp.json();
    const contentPart = geminiResult.candidates?.[0]?.content?.parts?.[0];
    let text = contentPart?.text?.trim();
    if (!text) {
      // Log empty response
      try { await supabase.from('scan_logs').insert({ scan_type: null, brand_id: brandId ?? null, platform_order_id: platformOrderId ?? null, raw_response: geminiResult, error: 'empty_response' }); } catch (_) {}
      return json({ error: 'Gemini response empty' }, 500);
    }
    
    // Defensive parsing: find the JSON block within the response text
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const jsonString = jsonMatch ? jsonMatch[0] : text;

    let extractedJson: any = {};
    try {
      extractedJson = JSON.parse(jsonString);
    } catch (e) {
      console.error('[scan-receipt] Gemini JSON parse error', e, text);
      return json({ error: 'Failed to parse Gemini JSON response', details: text }, 500);
    }

    const classification = extractedJson.classification;
    let scan_type: ScanType;
    if (classification === 'purchase') {
      scan_type = 'purchase';
    } else if (classification === 'order') {
      scan_type = 'order';
    } else {
      scan_type = 'unknown';
    }
    
    // Geocode address if it's a delivery order
    if (scan_type === 'order' && extractedJson.fulfillmentType === 'delivery') {
      const { customerStreet, customerPostcode } = extractedJson;
      if (customerStreet) {
        const coords = await geocodeSalzburg(supabase, customerStreet, customerPostcode);
        if (coords) {
          extractedJson.deliveryLatitude = coords.lat;
          extractedJson.deliveryLongitude = coords.lon;
        }
      }
    }

    // Persist a scanned_receipts row for UI only if not a dry run
    if (storagePath && !noSave) {
      try {
        const brandName = scan_type === 'order' ? extractedJson.brandName : null;
        const supplierName = scan_type === 'purchase' ? extractedJson.supplierName : null;

        await supabaseService.from('scanned_receipts').insert({
          scan_type,
          storage_path: storagePath,
          raw_json: text,
          extracted_data: extractedJson,
          brand_name: brandName,
          supplier_name: supplierName,
        });
      } catch (e) {
        console.error('[scan-receipt] failed to insert scanned_receipts row', e);
        // Don't fail the whole request, just log it.
      }
    }

    // Record idempotency keyed by classification (best-effort)
    if (!noSave) {
      const createdId = storagePath || crypto.randomUUID();
      await recordIdempotency({ supabase, idempotencyKey, createdId, type: scan_type });
    }

    try { await supabase.from('scan_logs').insert({ scan_type, brand_id: brandId ?? null, platform_order_id: platformOrderId ?? null, raw_response: geminiResult, normalized: extractedJson }); } catch (_) {}

    // Send push notification for successfully processed receipts
    if (!noSave && (scan_type === 'order' || scan_type === 'purchase')) {
      try {
        const isOrder = scan_type === 'order';
        const amount = isOrder ? extractedJson.totalPrice : extractedJson.totalAmount;
        const formattedAmount = amount != null ? `€${Number(amount).toFixed(2)}` : 'N/A';
        
        const notificationTitle = isOrder ? 'New Order Scanned' : 'New Purchase Scanned';
        const notificationBody = isOrder 
          ? `New Order, Total ${formattedAmount}`
          : `New Purchase, Total ${formattedAmount}`;
        
        await sendPushNotification(supabaseService, {
          title: notificationTitle,
          body: notificationBody,
          data: {
            type: scan_type,
            amount: String(amount || 0),
            storagePath: storagePath || '',
          },
        });
        
        console.log(`[scan-receipt] Push notification sent for ${scan_type}`);
      } catch (notificationError) {
        console.error('[scan-receipt] Failed to send push notification:', notificationError);
        // Don't fail the request if push notification fails
      }
    }

    return json({ ok: true, type: scan_type, storage_path: storagePath, extracted_data: extractedJson });
  } catch (e: any) {
    console.error('[scan-receipt] Unhandled error', e?.message || e);
    return json({ error: 'Internal server error', details: e?.message || String(e) }, 500);
  }
});

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}


// Geocode helper with caching in Supabase (Salzburg, Austria default city)
async function geocodeSalzburg(supabase: any, street?: string | null, postcode?: string | null): Promise<{ lat: number, lon: number } | null> {
  try {
    const s = (street ?? '').trim();
    const p = (postcode ?? '').trim();
    const city = 'Salzburg';
    const key = `${s}|${p}|${city}`.toLowerCase();

    // 1) Try cache
    try {
      const { data: cached } = await supabase
        .from('geocode_cache')
        .select('lat, lon, id, hit_count')
        .eq('key', key)
        .maybeSingle();
      if (cached?.lat != null && cached?.lon != null) {
        // update hit count asynchronously (do not block)
        supabase.from('geocode_cache').update({ hit_count: (cached.hit_count ?? 0) + 1, last_hit_at: new Date().toISOString() }).eq('id', cached.id);
        return { lat: Number(cached.lat), lon: Number(cached.lon) };
      }
    } catch (_) {}

    // 2) Call Nominatim
    const parts: string[] = [];
    if (s.length) parts.push(s);
    if (p.length) parts.push(p);
    parts.push('Salzburg, Austria');
    const q = parts.join(', ');
    const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=1`;
    const resp = await fetch(url, { headers: { 'User-Agent': 'restaurantadmin-scan/1.0 (contact: admin@example.com)' } });
    if (!resp.ok) return null;
    const arr = await resp.json();
    if (Array.isArray(arr) && arr.length > 0) {
      const lat = Number(arr[0]?.lat);
      const lon = Number(arr[0]?.lon);
      if (!isNaN(lat) && !isNaN(lon)) {
        // 3) Save to cache (fire-and-forget)
        try {
          await supabase.from('geocode_cache').insert({ key, street: s || null, postcode: p || null, city: 'Salzburg', lat, lon, last_hit_at: new Date().toISOString() });
        } catch (_) {}
        return { lat, lon };
      }
    }
  } catch (_) {}
  return null;
}

function buildExtractionPrompt(orderPrompt: string | null, purchasePrompt: string | null, suppliersCsv?: string): string {
  const supplierSection = suppliersCsv && suppliersCsv.trim().length > 0
    ? `\nList of known suppliers: ${suppliersCsv}\n`
    : '';
  
  const finalOrderPrompt = orderPrompt && orderPrompt.trim().length > 0
    ? orderPrompt
    : `For an "order" receipt (e.g., from Lieferando, Wolt, Uber Eats), use this JSON structure:
{
  "classification": "order",
  "brandName": "string | null",
  "platformOrderId": "string | null",
  "orderDate": "string (YYYY-MM-DDTHH:mm:ssZ) | null",
  "fulfillmentType": "'delivery' | 'pickup' | null",
  "totalPrice": "number | null",
  "deliveryFee": "number | null",
  "paymentMethod": "'online' | 'cash' | 'card' | 'unknown' | null",
  "customerName": "string | null",
  "customerStreet": "string | null",
  "customerPostcode": "string | null",
  "customerCity": "string | null",
  "deliveryLatitude": "number | null",
  "deliveryLongitude": "number | null",
  "orderItems": [
    {
      "name": "string",
      "quantity": "number",
      "price": "number | null"
    }
  ],
  "tip": "number | null",
  "fixedServiceFee": "number | null",
  "commissionAmount": "number | null",
  "orderTypeName": "string | null"
}`;

  const finalPurchasePrompt = purchasePrompt && purchasePrompt.trim().length > 0
    ? purchasePrompt
    : `For a "purchase" receipt (e.g., from a supplier like Metro, Spar), use this JSON structure:
{
  "classification": "purchase",
  "supplierName": "string | null",
  "totalAmount": "number | null",
  "receiptDate": "string (YYYY-MM-DD) | null"
}

IMPORTANT: For receiptDate, look at the actual printed date on the receipt/invoice document.
This is typically found near the top of the document, labeled as "Datum", "Date", "Rechnungsdatum", "Invoice Date", etc.
Extract this date in YYYY-MM-DD format. Do NOT use the current date - use the date printed on the document.`;

  // Default prompt
  return `You are an intelligent receipt processing agent. Your task is to analyze a receipt image and return a structured JSON object.
Your entire response must be ONLY the raw JSON object, without any surrounding text, comments, explanations, or markdown syntax like \`\`\`json.

Here are the required JSON structures based on the receipt type:
${supplierSection}
${finalOrderPrompt}

${finalPurchasePrompt}

If the image is NOT a receipt, use this JSON structure:
{
  "classification": "unknown",
  "comment": "A brief explanation of what the image is, and why it is not a receipt."
}

General rules:
- Adhere strictly to the JSON-only output format. Do not add any conversational text.
- All monetary values should be numbers, not strings. Use a period as the decimal separator.
- If a value is not found, use null.
- "brandName" is the name of the restaurant on the receipt (e.g., 'Devil's Smash Burger').
- "supplierName" is the name of the store or supplier where goods were purchased.
- "receiptDate" should be in YYYY-MM-DD format.
- "orderDate" should be a full ISO 8601 timestamp (YYYY-MM-DDTHH:mm:ssZ).
- "deliveryFee" corresponds to "Lieferkosten".
- "totalPrice" corresponds to "Gesamt".
- For "paymentMethod": if the text says "Bestellung online bezahlt", use "online". If it says "Bestellung nicht bezahlt", use "cash".
- "fulfillmentType" is "delivery" if the receipt says "Lieferung".
- "orderItems" should be a list of all items, including their quantity, name, and price. Extract quantity even if it's written like "1x".
- Customer details like "customerName", "customerStreet", etc., should be extracted from the delivery address section.
- Use "unknown" classification if you are confident the image is not a receipt. In the "comment" field, briefly explain why.
`;
}

function coerceIsoDateTime(input: any): string | null {
  if (input == null) return null;
  try {
    if (typeof input === 'number') {
      const d = new Date(input);
      return isNaN(d.getTime()) ? null : d.toISOString();
    }
    let s = String(input).trim();
    if (!s) return null;
    // Strip common locale suffixes like "Uhr"
    s = s.replace(/\buhr\b/gi, '').trim();

    // Time-only formats: HH:mm or HH:mm:ss
    const timeOnly = s.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
    if (timeOnly) {
      const now = new Date();
      const h = parseInt(timeOnly[1], 10) || 0;
      const m = parseInt(timeOnly[2], 10) || 0;
      const sec = timeOnly[3] ? parseInt(timeOnly[3], 10) : 0;
      const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), h, m, sec));
      return d.toISOString();
    }

    // dd.mm.yyyy or dd/mm/yyyy (optional time)
    const dmy = s.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{2,4})(?:[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/);
    if (dmy) {
      const day = parseInt(dmy[1], 10) || 1;
      const mon = (parseInt(dmy[2], 10) || 1) - 1;
      let year = parseInt(dmy[3], 10) || new Date().getFullYear();
      if (year < 100) year += 2000;
      const h = dmy[4] ? parseInt(dmy[4], 10) : 0;
      const m = dmy[5] ? parseInt(dmy[5], 10) : 0;
      const sec = dmy[6] ? parseInt(dmy[6], 10) : 0;
      const d = new Date(Date.UTC(year, mon, day, h, m, sec));
      return d.toISOString();
    }

    // yyyy-mm-dd (optional time)
    const ymd = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/);
    if (ymd) {
      const year = parseInt(ymd[1], 10) || new Date().getFullYear();
      const mon = (parseInt(ymd[2], 10) || 1) - 1;
      const day = parseInt(ymd[3], 10) || 1;
      const h = ymd[4] ? parseInt(ymd[4], 10) : 0;
      const m = ymd[5] ? parseInt(ymd[5], 10) : 0;
      const sec = ymd[6] ? parseInt(ymd[6], 10) : 0;
      const d = new Date(Date.UTC(year, mon, day, h, m, sec));
      return d.toISOString();
    }

    // Fallback to Date.parse
    const parsed = new Date(s);
    if (!isNaN(parsed.getTime())) return parsed.toISOString();
  } catch (_) {}
  return null;
}


async function normalizeAndResolve({ supabase, scannedData, brandId, brandName }: any) {
  // Brand resolution (prefer explicit IDs for known ghost kitchens)
  let resolvedBrandId = brandId;
  let resolvedBrandName = brandName ?? scannedData.brandName;
  if (!resolvedBrandId) {
    const mapped = findBrandIdByName(resolvedBrandName);
    if (mapped.id) {
      resolvedBrandId = mapped.id;
      resolvedBrandName = mapped.normalizedName ?? resolvedBrandName;
    }
  }
  if (!resolvedBrandId && resolvedBrandName) {
    const { data } = await supabase
      .from('brands')
      .select('id, name')
      .ilike('name', resolvedBrandName)
      .maybeSingle();
    resolvedBrandId = data?.id ?? null;
    resolvedBrandName = data?.name ?? resolvedBrandName;
  }

  // Normalize items: combine from multiple possible keys used by different platforms
  const arrays = [
    scannedData.orderItems,
    scannedData.items,
    scannedData.products,
    scannedData.lines,
    scannedData.orderLines,
    scannedData.order_lines,
  ].filter((a: any) => Array.isArray(a));
  const rawItems = ([] as any[]).concat(...arrays);


  function parseQuantity(q: any): number {
    if (typeof q === 'number') return Number(q) || 1;
    const s = String(q ?? '').trim();
    // common patterns: "2x Burger", "Burger x2", "2 Burger"
    const m = s.match(/^(\d+)\s*x\b|\bx\s*(\d+)$|^(\d+)\b/);
    if (m) {
      const n = Number(m[1] || m[2] || m[3]);
      return isNaN(n) ? 1 : n;
    }
    return m ? Number(m[0]) || 1 : 1;
  }

  const items = rawItems
    .map((it: any) => ({
      menuItemId: it.menuItemId ?? it.menu_item_id ?? null,
      menuItemName: it.menuItemName ?? it.menu_item_name ?? it.item_name ?? it.title ?? it.name ?? null,
      quantity: parseQuantity(it.quantity),
      price: it.price ?? it.item_price ?? it.unit_price ?? it.amount ?? it.total ?? it.line_total ?? null,
    }))
    .filter((x: any) => x.menuItemId || x.menuItemName);

  // Resolve items by name within brand
  const resolvedItems: any[] = [];
  if (items.length && !resolvedBrandId) {
    // Fallback: brand unknown => pass-through items so order still contains lines
    for (const it of items) {
      if (!it.menuItemName) continue;
      resolvedItems.push({
        menu_item_id: null,
        menu_item_name: it.menuItemName,
        quantity: it.quantity,
        price_at_purchase: it.price ?? null,
        brand_id: null,
      });
    }
  } else if (resolvedBrandId && items.length) {
    const { data: menuItems } = await supabase
      .from('menu_items')
      .select('id, name, price')
      .eq('brand_id', resolvedBrandId);

    // Load alias mappings if table exists (optional)
    let aliasRows: any[] = [];
    try {
      const { data: aliases } = await supabase
        .from('menu_item_aliases')
        .select('menu_item_id, alias')
        .eq('brand_id', resolvedBrandId);
      aliasRows = Array.isArray(aliases) ? aliases : [];
    } catch (_) {}

    const aliasMap: Record<string, any> = {};
    for (const a of aliasRows) {
      const mi = (menuItems || []).find((m: any) => m.id === a.menu_item_id);
      if (mi && a.alias) aliasMap[String(a.alias).toLowerCase()] = mi;
    }

    // Simple fuzzy matcher based on token overlap score, with alias first
    function bestFuzzyMatch(name: string, candidates: any[]): any | null {
      const target = String(name).toLowerCase().trim();
      if (!target) return null;
      if (aliasMap[target]) return aliasMap[target]; // alias exact
      const targetTokens = target.split(/[^a-z0-9]+/).filter(Boolean);
      let best: { item: any; score: number } | null = null;
      for (const c of candidates) {
        const cand = String(c.name || '').toLowerCase().trim();
        if (!cand) continue;
        if (cand === target) return c; // perfect match
        if (cand.includes(target) || target.includes(cand)) {
          const score = Math.min(target.length, cand.length) / Math.max(target.length, cand.length);
          if (!best || score > best.score) best = { item: c, score };
          continue;
        }
        const candTokens = cand.split(/[^a-z0-9]+/).filter(Boolean);
        const common = targetTokens.filter(t => candTokens.some(ct => ct === t || ct.includes(t) || t.includes(ct)));
        const score = common.length / Math.max(1, Math.max(targetTokens.length, candTokens.length));
        if (score > 0 && (!best || score > best.score)) best = { item: c, score };
      }
      // Only accept reasonably similar matches
      return best && best.score >= 0.5 ? best.item : null;
    }

    const unmatched: string[] = [];
    for (const it of items) {
      let match = it.menuItemId ? menuItems?.find((m: any) => m.id === it.menuItemId) : undefined;
      if (!match && it.menuItemName) {
        let nameLower = String(it.menuItemName).toLowerCase().trim();
        // Foodora receipts often include qty like "2x Burger"; strip common patterns
        nameLower = nameLower.replace(/^\d+\s*x\s*/i, '').replace(/\s*x\s*\d+$/i, '').trim();
        // Also strip trailing price fragments like "- 4,50" or "€4,50"
        nameLower = nameLower.replace(/[-€]\s*\d+[\.,]\d+$/, '').trim();

        match = menuItems?.find((m: any) => m.name.toLowerCase() === nameLower)
          || menuItems?.find((m: any) => m.name.toLowerCase().includes(nameLower))
          || aliasMap[nameLower]
          || bestFuzzyMatch(nameLower, menuItems || []);
      }
      if (match || it.menuItemName) {
        resolvedItems.push({
          menu_item_id: match?.id ?? null,
          menu_item_name: match?.name ?? it.menuItemName,
          quantity: it.quantity,
          price_at_purchase: it.price ?? match?.price ?? null,
          brand_id: resolvedBrandId,
        });
        if (!match && it.menuItemName) unmatched.push(String(it.menuItemName));
      }
    }

    // Log unmatched names for later alias configuration (ignore errors)
    if (unmatched.length) {
      try {
        await supabase.from('unmatched_menu_items').insert(
          unmatched.map(n => ({ brand_id: resolvedBrandId, raw_name: n, created_at: new Date().toISOString() }))
        );
      } catch (_) {}
    }
  }

  const platformName = scannedData.platformName ?? null;
  const orderTypeName = scannedData.orderTypeName ?? platformName ?? null;

  // Coerce datetimes to ISO; handle cases like "20:51" by anchoring to today
  const createdAtIso = coerceIsoDateTime(scannedData.createdAt) ?? new Date().toISOString();
  const requestedIso = coerceIsoDateTime(scannedData.requestedDeliveryTime);
  return {
    brandId: resolvedBrandId,
    brandName: resolvedBrandName,
    totalPrice: scannedData.totalPrice ?? null,
    createdAt: createdAtIso,
    paymentMethod: scannedData.paymentMethod ?? 'unknown',
    orderTypeName,
    customerName: scannedData.customerName ?? null,
    customerStreet: scannedData.customerStreet ?? null,
    customerPostcode: scannedData.customerPostcode ?? null,
    customerCity: scannedData.customerCity ?? null,
    requestedDeliveryTime: requestedIso,
    platformOrderId: scannedData.platformOrderId ?? null,
    serviceFee: scannedData.serviceFee ?? null,
    commissionAmount: scannedData.commissionAmount ?? null,
    deliveryFee: scannedData.deliveryFee ?? null,
    fulfillmentType: scannedData.fulfillmentType ?? null,
    deliveryLatitude: scannedData.deliveryLatitude ?? null,
    deliveryLongitude: scannedData.deliveryLongitude ?? null,
    orderItems: resolvedItems,
  };
}

async function computeTotalMaterialCost(supabase: any, resolvedItems: any[]): Promise<number | null> {
  try {
    let total = 0;
    for (const it of resolvedItems) {
      if (!it.menu_item_id || !it.quantity) continue;
      const { data: mim } = await supabase
        .from('menu_item_materials')
        .select('quantity_used, material_id(average_unit_cost)')
        .eq('menu_item_id', it.menu_item_id);
      if (Array.isArray(mim)) {
        for (const row of mim) {
          const q = Number(row.quantity_used) || 0;
          const wac = Number(row.material_id?.average_unit_cost) || 0;
          total += q * wac * Number(it.quantity);
        }
      }
    }
    return total;
  } catch (e) {
    console.log('[scan-receipt] computeTotalMaterialCost error', e);
    return null;
  }
}

async function generateCustomOrderId(supabase: any, orderDate: Date): Promise<{ orderId: string; dailyOrderNumber: number }> {
  try {
    const day = String(orderDate.getDate()).padStart(2, '0');
    const month = String(orderDate.getMonth() + 1).padStart(2, '0');
    const year = String(orderDate.getFullYear());
    
    // Get total order count
    const { count: totalCount } = await supabase
      .from('orders')
      .select('id', { count: 'exact', head: true });
    
    const totalOrders = (totalCount ?? 0) + 1;
    const totalStr = String(totalOrders).padStart(6, '0');
    
    // Get today's order count
    const todayStart = new Date(orderDate.getFullYear(), orderDate.getMonth(), orderDate.getDate());
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);
    
    const { count: todayCount } = await supabase
      .from('orders')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', todayStart.toISOString())
      .lt('created_at', todayEnd.toISOString());
    
    const dailyOrderNumber = (todayCount ?? 0) + 1;
    const dailyStr = String(dailyOrderNumber).padStart(2, '0');
    
    const orderId = `${day}${month}${year}${totalStr}${dailyStr}`;
    
    return { orderId, dailyOrderNumber };
  } catch (e) {
    console.error('[generateCustomOrderId] Error:', e);
    // Fallback: use timestamp
    const fallbackId = orderDate.toISOString().replace(/[-:T.Z]/g, '').substring(0, 14);
    return { orderId: fallbackId, dailyOrderNumber: 0 };
  }
}

async function insertOrder({ supabase, data, platformOrderId }: any): Promise<string> {
  const newOrderId = crypto.randomUUID();
  
  // Generate custom order number
  const orderDate = coerceIsoDateTime(data.createdAt) ? new Date(coerceIsoDateTime(data.createdAt)!) : new Date();
  const { orderId: customOrderId, dailyOrderNumber } = await generateCustomOrderId(supabase, orderDate);
  
  const newOrder: any = {
    id: newOrderId,
    order_number: customOrderId,
    daily_order_number: dailyOrderNumber,
    brand_id: data.brandId,
    total_price: data.totalPrice,
    status: 'pending_confirmation',
    created_at: orderDate.toISOString(),
    scanned_date: new Date().toISOString(),
    payment_method: data.paymentMethod,
    order_type_name: data.orderTypeName,
    customer_name: data.customerName,
    customer_street: data.customerStreet,
    customer_postcode: data.customerPostcode,
    customer_city: data.customerCity,
    requested_delivery_time: coerceIsoDateTime(data.requestedDeliveryTime),
    platform_order_id: platformOrderId ?? data.platformOrderId,
  };
  // Optional fields if your schema supports them
  if (data.fulfillmentType) newOrder.fulfillment_type = data.fulfillmentType;
  if (data.deliveryLatitude != null) newOrder.delivery_latitude = data.deliveryLatitude;
  if (data.deliveryLongitude != null) newOrder.delivery_longitude = data.deliveryLongitude;
  if (data.serviceFee != null) newOrder.fixed_service_fee = data.serviceFee;
  if (data.commissionAmount != null) newOrder.commission_amount = data.commissionAmount;
  if (data.deliveryFee != null) newOrder.delivery_fee = data.deliveryFee;

  // Compute and set total material cost (optional)
  const computedTotalMaterialCost = await computeTotalMaterialCost(supabase, data.orderItems || []);
  if (computedTotalMaterialCost != null) newOrder.total_material_cost = computedTotalMaterialCost;

  // Insert with fallback if delivery_fee column missing
  let { error: orderErr } = await supabase.from('orders').insert(newOrder);
  if (orderErr && String(orderErr.message || '').toLowerCase().includes('delivery_fee')) {
    try { delete (newOrder as any).delivery_fee; } catch (_) {}
    const retry = await supabase.from('orders').insert(newOrder);
    orderErr = retry.error;
  }
  if (orderErr) {
    console.error('[scan-receipt] orders insert error:', orderErr.message, newOrder);
    throw new Error(`order_insert_failed: ${orderErr.message} :: payload=${JSON.stringify(newOrder)}`);
  }

  if (data.orderItems?.length) {
    const items = data.orderItems.map((it: any) => ({ ...it, order_id: newOrderId }));
    const { error: itemsErr } = await supabase.from('order_items').insert(items);
    if (itemsErr) console.log('[scan-receipt] order_items insert error', itemsErr.message);

    // Auto-create helpful alias suggestions for unmatched items
    try {
      const suggestions = data.orderItems
        .filter((it: any) => !it.menu_item_id && it.menu_item_name && data.brandId)
        .map((it: any) => ({ brand_id: data.brandId, alias: it.menu_item_name }));
      if (suggestions.length) {
        // insert only those aliases that don't exist yet
        const { data: existing } = await supabase
          .from('menu_item_alias_suggestions')
          .select('brand_id, alias')
          .eq('brand_id', data.brandId);
        const existingSet = new Set((existing || []).map((r: any) => `${r.brand_id}|${(r.alias || '').toLowerCase()}`));
        const toInsert = suggestions.filter((s: any) => !existingSet.has(`${s.brand_id}|${String(s.alias).toLowerCase()}`));
        if (toInsert.length) await supabase.from('menu_item_alias_suggestions').insert(toInsert);
      }
    } catch (_) {}

  }
  return newOrderId;
}

async function insertPurchase({ supabase, data }: any): Promise<string> {
  // Note: assumes purchases and purchase_items tables exist
  const newId = crypto.randomUUID();
  // Resolve supplier by name if possible
  let supplierId: string | null = null;
  const supplierName = data.brandName ?? null;
  if (supplierName) {
    try {
      const { data: s } = await supabase
        .from('suppliers')
        .select('id')
        .ilike('name', supplierName)
        .maybeSingle();
      supplierId = s?.id ?? null;
    } catch (_) {}
  }

  const purchase = {
    id: newId,
    brand_id: data.brandId,
    supplier_id: supplierId,
    supplier_name: supplierName,
    total_amount: (typeof data.totalPrice === 'number') ? data.totalPrice : null,
    receipt_date: coerceIsoDateTime(data.createdAt) ?? new Date().toISOString(),
    notes: 'AI scanned purchase',
  };
  const { error: pErr } = await supabase.from('purchases').insert(purchase);
  if (pErr) throw pErr;

  let computedSum = 0;
  if (data.orderItems?.length) {
    const items = [] as any[];
    for (const it of data.orderItems) {
      const raw = it.menu_item_name ?? it.name ?? null;
      // Per requirements: do not pre-map to catalog or materials; only store qty and total
      const qty = it.quantity ?? null;
      const unitPrice = it.price_at_purchase ?? it.price ?? null;
      const lineTotal = (typeof it.total === 'number') ? it.total : (qty && unitPrice ? Number(qty) * Number(unitPrice) : null);
      if (typeof lineTotal === 'number') computedSum += Number(lineTotal);
      items.push({
        purchase_id: newId,
        raw_name: raw,
        purchase_catalog_item_id: null,
        brand_name: null,
        item_number: null,
        material_id: null,
        base_unit: null,
        conversion_ratio: null,
        quantity: qty,
        unit: null,
        unit_price: null,
        total_item_price: lineTotal,
      });
    }
    const { error: piErr } = await supabase.from('purchase_items').insert(items);
    if (piErr) console.log('[scan-receipt] purchase_items insert error', piErr.message);
  }
  // Final guard: if header total missing, backfill from items sum
  if (purchase.total_amount == null && computedSum > 0) {
    await supabase.from('purchases').update({ total_amount: computedSum }).eq('id', newId);
  }
  return newId;
}

async function recordIdempotency({ supabase, idempotencyKey, createdId, type }: any) {
  if (!idempotencyKey) return;
  await supabase.from('receipts_processed').insert({
    idempotency_key: idempotencyKey,
    created_id: createdId,
    created_type: type,
  });
}

