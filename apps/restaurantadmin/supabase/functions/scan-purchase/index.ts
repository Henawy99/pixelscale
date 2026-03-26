/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { encode } from 'https://deno.land/std@0.208.0/encoding/base64.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let payload: any;
  try { payload = await req.json(); } catch (_) {
    return json({ error: 'Invalid JSON payload' }, 400);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing Authorization' }, 401);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  if (!GEMINI_API_KEY) return json({ error: 'Server missing Gemini configuration' }, 500);

  const { receiptImageBase64, storageSignedUrl, wholesalerHint } = payload ?? {};
  if (!receiptImageBase64 && !storageSignedUrl) {
    return json({ error: 'Provide receiptImageBase64 or storageSignedUrl' }, 400);
  }

  try {
    let base64Image = receiptImageBase64 as string | undefined;
    if (!base64Image && storageSignedUrl) {
      const arrBuf = await fetch(storageSignedUrl).then((r) => r.arrayBuffer());
      base64Image = encode(new Uint8Array(arrBuf));
    }

    // Optional operator tuning prompt stored in app_settings (reuse existing column)
    let promptHint: string | null = null;
    try {
      const { data: settingsRow } = await supabase
        .from('app_settings')
        .select('receipt_prompt_hint')
        .maybeSingle();
      promptHint = settingsRow?.receipt_prompt_hint ?? null;
    } catch (_) {}

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

    // Supplier AI rules: prefer explicit supplier, else try to resolve by hint
    let supplierRules: string | null = null;
    if (wholesalerHint) {
      const { data: supplier } = await supabase
        .from('suppliers')
        .select('id, name, ai_rules')
        .ilike('name', wholesalerHint)
        .maybeSingle();
      supplierRules = supplier?.ai_rules ?? null;
    }

    const prompt = buildPurchasePrompt(promptHint, wholesalerHint, supplierRules);
    const geminiPayload = {
      contents: [
        { parts: [ { text: prompt }, { inline_data: { mime_type: 'image/jpeg', data: base64Image } } ] }
      ],
    };

    const geminiResp = await fetch(geminiUrl, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(geminiPayload)
    });
    if (!geminiResp.ok) {
      const t = await geminiResp.text();
      console.error('[scan-purchase] Gemini error', geminiResp.status, t);
      return json({ error: 'Gemini request failed', details: t }, geminiResp.status);
    }

    const geminiResult = await geminiResp.json();
    const contentPart = geminiResult.candidates?.[0]?.content?.parts?.[0];
    let text = contentPart?.text?.replace(/```json/g, '').replace(/```/g, '').trim();
    if (!text) {
      try { await supabase.from('scan_logs').insert({ scan_type: 'purchase', raw_response: geminiResult, error: 'empty_response' }); } catch (_) {}
      return json({ error: 'Gemini response empty' }, 500);
    }

    const scanned = JSON.parse(text);
    const normalized = normalizePurchase(scanned);

    // Per requirements: do not map receipt items to materials server-side.
    // Keep items as canonical receipt text only; mapping will happen via Purchase Items in the app.

    // Log normalized for debugging

    // Resolve supplier by normalized wholesaler name (optional)
    let supplierId: string | null = null;
    let supplierName: string | null = normalized.wholesalerName ?? null;
    if (supplierName) {
      try {
        const { data: sup } = await supabase.from('suppliers').select('id, name').ilike('name', supplierName).maybeSingle();
        supplierId = sup?.id ?? null;
        supplierName = sup?.name ?? supplierName;
      } catch (_) {}
    } else if (wholesalerHint) {
      try {
        const { data: sup } = await supabase.from('suppliers').select('id, name').ilike('name', wholesalerHint).maybeSingle();
        supplierId = sup?.id ?? null;
        supplierName = sup?.name ?? wholesalerHint;
      } catch (_) {}
    }

    // Insert into DB so the app listener can auto-open the Purchase Review dialog
    const headerTotal = (typeof normalized.totalAmount === 'number' && !isNaN(normalized.totalAmount))
      ? normalized.totalAmount
      : (normalized.items || []).reduce((s: number, it: any) => s + (typeof it.total_item_price === 'number' ? it.total_item_price : 0), 0);

    const { data: headerRow, error: headerErr } = await supabase
      .from('purchases')
      .insert({
        supplier_id: supplierId,
        supplier_name: supplierName,
        receipt_date: normalized.receiptDate,
        total_amount: headerTotal || null,
        status: 'pending_review',
        notes: 'AI scanned purchase',
      })
      .select('id')
      .single();
    if (headerErr) return json({ error: 'Failed to insert purchase', details: headerErr.message }, 500);

    const purchaseId = headerRow.id as string;

    // Insert line items: only quantity and total, no mapping
    const itemsPayload = (normalized.items || []).map((it: any) => ({
      purchase_id: purchaseId,
      raw_name: it.raw_name ?? null,
      brand_name: it.brand_name ?? null,
      item_number: it.item_number ?? null,
      purchase_catalog_item_id: null,
      quantity: typeof it.quantity === 'number' ? it.quantity : null,
      total_item_price: typeof it.total_item_price === 'number' ? it.total_item_price : null,
      unit: null,
      unit_price: null,
      material_id: null,
      base_unit: null,
      conversion_ratio: null,
    }));
    if (itemsPayload.length) {
      const { error: itemsErr } = await supabase.from('purchase_items').insert(itemsPayload);
      if (itemsErr) return json({ error: 'Failed to insert purchase items', details: itemsErr.message }, 500);
    }

    try { await supabase.from('scan_logs').insert({ scan_type: 'purchase', normalized }); } catch (_) {}

    return json({ ok: true, id: purchaseId, type: 'purchase' });
  } catch (e: any) {
    try {
      console.error('[scan-purchase] Unhandled error', e?.message || e, e?.stack || '');
    } catch (_) {
      console.error('[scan-purchase] Unhandled error (logging failed)');
    }
    let details = e?.message || String(e);
    let full: any = null;
    try { full = typeof e === 'object' ? JSON.stringify(e) : null; } catch (_) { full = null; }
    return json({ error: 'Internal server error', details, full, stack: e?.stack || null }, 500);
  }
});

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function buildPurchasePrompt(hint?: string | null, wholesalerHint?: string | null, supplierRules?: string | null): string {
  const extra = hint ? `\nOperator hint:\n${hint}\n` : '';
  const who = wholesalerHint ? `Wholesaler: ${wholesalerHint}.` : '';
  const rules = supplierRules ? `\nSupplier-specific rules:\n${supplierRules}\n` : '';
  return `Analyze a WHOLESALER PURCHASE receipt image and output ONLY a VALID JSON object.${extra}
${who}${rules}
JSON Structure (omit fields if unsure):
{
  "wholesalerName": "string",
  "receiptDate": "ISO datetime (YYYY-MM-DDTHH:mm:ss or YYYY-MM-DD)",
  "totalAmount": number,
  "items": [
    { "item_name": "string", "brand": "string", "item_number": "string", "quantity": number, "unit": "string", "unit_price": number, "total_item_price": number }
  ]
}
Rules (strict):
- receiptDate: Look at the ACTUAL PRINTED DATE on the receipt/invoice document. This is typically labeled as "Datum", "Date", "Rechnungsdatum", "Invoice Date", "Belegdatum", etc. Extract this date in YYYY-MM-DD format. Do NOT use the current date - use the date printed on the document.
- item_name must be the EXACT text from the receipt line (do not translate or normalize; keep casing, spacing, punctuation, abbreviations).
- Also include receipt_text with the exact OCR snippet for the line (often the same as item_name). If uncertain, prefer the raw printed text.
- If quantity or unit price are missing, still output the line with item_name/receipt_text and whatever numbers you can see.
- METRO receipts: per-line total is labelled GESAMTPREIS; set total_item_price from that column value.
- If total_item_price not printed but both quantity and unit_price are printed, set total_item_price = quantity * unit_price.
- Return only valid JSON, no markdown, no comments.
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
    s = s.replace(/\buhr\b/gi, '').trim();
    const timeOnly = s.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
    if (timeOnly) {
      const now = new Date();
      const h = parseInt(timeOnly[1], 10) || 0;
      const m = parseInt(timeOnly[2], 10) || 0;
      const sec = timeOnly[3] ? parseInt(timeOnly[3], 10) : 0;
      const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), h, m, sec));
      return d.toISOString();
    }
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
    const parsed = new Date(s);
    if (!isNaN(parsed.getTime())) return parsed.toISOString();
  } catch (_) {}
  return null;
}

function toNumber(v: any): number | null {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  const s = String(v).replace(',', '.').replace(/[^0-9.\-]/g, '');
  const n = Number(s);
  return isNaN(n) ? null : n;
}

function normalizePurchase(scanned: any) {
  const itemsArray = Array.isArray(scanned?.items) ? scanned.items : [];
  const items = itemsArray
    .map((it: any) => {
      const qty = toNumber(it.quantity) ?? 0;
      const u = (it.unit ?? '').toString();
      const unitPrice = toNumber(it.unit_price);
      const directTotal = toNumber(it.total_item_price);
      const computedTotal = (directTotal != null) ? directTotal : ((qty != null && unitPrice != null) ? (qty * unitPrice) : null);
      return {
        raw_name: it.receipt_text ?? it.item_name ?? it.name ?? it.title ?? null,
        brand_name: it.brand ?? null,
        item_number: it.item_number ?? null,
        quantity: qty,
        unit: u,
        unit_price: unitPrice,
        total_item_price: computedTotal,
      };
    })
    .filter((x: any) => x.raw_name);

  const receiptDateIso = coerceIsoDateTime(scanned.receiptDate);
  return {
    wholesalerName: scanned.wholesalerName ?? null,
    receiptDate: receiptDateIso,
    totalAmount: toNumber(scanned.totalAmount),
    items,
  };
}
