/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { v4 } from 'https://deno.land/std@0.177.0/uuid/mod.ts'
import { encode } from "https://deno.land/std@0.208.0/encoding/base64.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper for retrying with exponential backoff
async function fetchWithRetry(url: string, options: RequestInit, retries = 3, delay = 1000): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options);
      // Retry only on 503 Service Unavailable
      if (response.status !== 503) {
        return response;
      }
      console.log(`[scan-and-create-order] Gemini API overloaded (503). Retrying in ${delay / 1000}s... (${i + 1}/${retries})`);
    } catch (error) {
      // Also retry on network errors
      console.log(`[scan-and-create-order] Fetch error. Retrying in ${delay / 1000}s... (${i + 1}/${retries})`, error);
    }
    await new Promise(res => setTimeout(res, delay));
    delay *= 2; // Exponential backoff
  }
  throw new Error(`Failed to fetch from Gemini API after ${retries} retries.`);
}


Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const { imagePath } = await req.json();
  const bucketId = 'scanned-receipts';

  if (!imagePath) {
    return new Response(JSON.stringify({ error: 'Missing imagePath in request body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  console.log(`[scan-and-create-order] Processing image: ${imagePath}`);

  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  if (!GEMINI_API_KEY) {
    console.error('[scan-and-create-order] GEMINI_API_KEY is not set.');
    return new Response(JSON.stringify({ error: 'Server configuration error: Missing Gemini API Key' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}`;

  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    const { data: urlData, error: urlError } = await supabaseClient
      .storage
      .from(bucketId)
      .createSignedUrl(imagePath, 60);

    if (urlError || !urlData) {
      console.error('[scan-and-create-order] Error creating signed URL:', urlError);
      return new Response(JSON.stringify({ error: 'Failed to get image URL', details: urlError?.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const imageUrl = urlData.signedUrl;

    const geminiPrompt = `
      Analyze the following receipt image. Your task is to extract the specified information and return it as a VALID JSON object.
      Ensure all keys and string values are double-quoted. Omit any fields you cannot confidently extract.
      First, identify the brand. It must be one of: "CRISPY CHICKEN LAB", "DEVILS SMASH BURGER", "THE BOWL SPOT", "TACOTASTIC".
      Then, extract the rest of the information based on that brand's receipt format.
      JSON Structure to populate:
      {
        "brandName": "string (must be one of the brands listed above)",
        "orderTypeName": "string (e.g., 'Lieferando', 'Foodora', 'Wolt', 'Uber Eats', 'Takeaway', 'Dine-in')",
        "customerName": "string",
        "customerStreet": "string",
        "customerPostcode": "string",
        "customerCity": "string",
        "totalPrice": number,
        "serviceFee": number,
        "commissionAmount": number,
        "deliveryFee": number,
        "tip": number,
        "createdAt": "string (ISO 8601 format, e.g., 'YYYY-MM-DDTHH:mm:ss')",
        "requestedDeliveryTime": "string (ISO 8601 format)",
        "paymentMethod": "string ('cash' | 'online' | 'card_terminal' | 'unknown')",
        "platformOrderId": "string",
        "orderItems": [
          { "menuItemName": "string (Name of the item on the receipt)", "quantity": number, "price": number }
        ]
      }
      Guidelines:
      - Extract ALL fees separately (delivery, service, commission, tip) when visible.
      - Ensure totalPrice equals sum(orderItems.price*quantity) + all fees when available.
      - Use exact item names as on the receipt when possible.
    `;

    // Optional operator tuning hint and full template stored in DB settings
    let promptHint: string | null = null;
    let basePrompt: string | null = null;
    try {
      const { data: settingsRow } = await supabaseClient
        .from('app_settings')
        .select('receipt_prompt_hint, order_scan_prompt')
        .maybeSingle();
      promptHint = settingsRow?.receipt_prompt_hint ?? null;
      basePrompt = settingsRow?.order_scan_prompt ?? null;
    } catch (_) {}

    const imageBytes = await fetch(imageUrl).then(res => res.arrayBuffer());
    const base64Image = encode(new Uint8Array(imageBytes));

    const finalPrompt = (basePrompt && basePrompt.trim().length > 0 ? basePrompt : geminiPrompt)
      + (promptHint ? `\nOperator hint (use to improve extraction next time):\n${promptHint}\n` : '');

    const geminiPayload = {
      contents: [{
        parts: [
          { text: finalPrompt },
          { inline_data: { mime_type: "image/jpeg", data: base64Image } }
        ]
      }]
    };

    // Geocode helper: Salzburg, Austria default
    async function geocodeSalzburg(street?: string | null, postcode?: string | null): Promise<{ lat: number; lon: number } | null> {
      try {
        const parts: string[] = [];
        if (street && String(street).trim().length) parts.push(String(street));
        if (postcode && String(postcode).trim().length) parts.push(String(postcode));
        parts.push('Salzburg, Austria');
        const q = parts.join(', ');
        const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=1`;
        const resp = await fetch(url, { headers: { 'User-Agent': 'restaurantadmin-scan/1.0 (contact: admin@example.com)' } });
        if (!resp.ok) return null;
        const arr = await resp.json();
        if (Array.isArray(arr) && arr.length > 0) {
          const lat = Number(arr[0]?.lat);
          const lon = Number(arr[0]?.lon);
          if (!isNaN(lat) && !isNaN(lon)) return { lat, lon };
        }
      } catch (_) {}
      return null;
    }

    // Coerce comma decimals for fees


    const geminiResponse = await fetchWithRetry(GEMINI_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error('[scan-and-create-order] Gemini API error after retries:', geminiResponse.status, errorBody);
      return new Response(JSON.stringify({ error: 'Gemini API request failed after retries', details: errorBody }), {
        status: geminiResponse.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const geminiResult = await geminiResponse.json();
    const contentPart = geminiResult.candidates?.[0]?.content?.parts?.[0];
    let geminiJsonText = contentPart?.text?.replace(/```json/g, '')?.replace(/```/g, '')?.trim();

    if (!geminiJsonText) {
      console.error('[scan-and-create-order] No text in Gemini response:', JSON.stringify(geminiResult, null, 2));
      // Log empty response
      try { await supabaseClient.from('scan_logs').insert({ scan_type: 'order', brand_id: brandId ?? null, platform_order_id: null, raw_response: geminiResult, error: 'empty_response' }); } catch (_) {}
      return new Response(JSON.stringify({ error: 'Gemini response was empty or malformed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const scannedData = JSON.parse(geminiJsonText);

    // Coerce comma decimals for fees
    function toNumberOrNull(v: any): number | null {
      if (v == null) return null;
      if (typeof v === 'number') return v;
      const s = String(v).replace(',', '.').replace(/[^0-9.\-]/g, '');
      const n = Number(s);
      return isNaN(n) ? null : n;
    }
    scannedData.deliveryFee = toNumberOrNull(scannedData.deliveryFee);
    scannedData.serviceFee = toNumberOrNull(scannedData.serviceFee);
    scannedData.commissionAmount = toNumberOrNull(scannedData.commissionAmount);
    scannedData.tip = toNumberOrNull(scannedData.tip);

    // Geocode if missing; assume Salzburg, Austria
    try {
      if (!scannedData.deliveryLatitude || !scannedData.deliveryLongitude) {
        const geo = await geocodeSalzburg(scannedData.customerStreet, scannedData.customerPostcode);
        if (geo) {
          scannedData.deliveryLatitude = geo.lat;
          scannedData.deliveryLongitude = geo.lon;
        }
      }
    } catch (_) {}

    // Log raw for debugging
    try { await supabaseClient.from('scan_logs').insert({ scan_type: 'order', brand_id: brandId ?? null, platform_order_id: scannedData.platformOrderId ?? null, raw_response: geminiResult, normalized: scannedData }); } catch (_) {}

    if (!scannedData.brandName) {
        throw new Error("Gemini did not return a brandName.");
    }
    const { data: brandData, error: brandError } = await supabaseClient
        .from('brands')
        .select('id, name')
        .eq('name', scannedData.brandName)
        .single();

    if (brandError || !brandData) {
        throw new Error(`Could not find brand ID for brand: ${scannedData.brandName}`);
    }
    const brandId = brandData.id;
    const brandNameFromDB = brandData.name;

    const { data: menuItemsData, error: menuItemsError } = await supabaseClient
        .from('menu_items')
        .select('id, name, price')
        .eq('brand_id', brandId);
    if (menuItemsError) throw menuItemsError;

    const newOrderId = v4.generate();
    const orderCreatedAt = scannedData.createdAt ? new Date(scannedData.createdAt) : new Date();

    const newOrder = {
      id: newOrderId,
      brand_id: brandId,
      brand_name: brandNameFromDB,
      total_price: scannedData.totalPrice,
      status: 'pending_confirmation',
      created_at: orderCreatedAt.toISOString(),
      payment_method: scannedData.paymentMethod || 'unknown',
      order_type_name: scannedData.orderTypeName,
      customer_name: scannedData.customerName,
      customer_street: scannedData.customerStreet,
      customer_postcode: scannedData.customerPostcode,
      customer_city: scannedData.customerCity,
      requested_delivery_time: scannedData.requestedDeliveryTime ? new Date(scannedData.requestedDeliveryTime).toISOString() : null,
      platform_order_id: scannedData.platformOrderId,
    };

    const { error: orderInsertError } = await supabaseClient.from('orders').insert(newOrder);

	    // Insert scanned_receipts row for UI (image already in storage)
	    try {
	      await supabaseClient.from('scanned_receipts').insert({
	        scan_type: 'order',
	        storage_path: imagePath,
	        brand_name: brandNameFromDB,
	        platform_order_id: scannedData.platformOrderId ?? null,
	        created_order_id: newOrderId,
	      });
	    } catch (_) {}

    if (orderInsertError) throw orderInsertError;

    if (scannedData.orderItems && scannedData.orderItems.length > 0) {
      // Load menu items for fuzzy matching
      const { data: menuItemsData, error: menuItemsError } = await supabaseClient
        .from('menu_items')
        .select('id, name, price')
        .eq('brand_id', brandId);
      if (menuItemsError) console.error('[scan-and-create-order] menu_items fetch error:', menuItemsError.message);

      function bestFuzzyMatch(name: string, candidates: any[]): any | null {
        const target = String(name || '').toLowerCase().trim();
        if (!target) return null;
        const targetTokens = target.split(/[^a-z0-9]+/).filter(Boolean);
        let best: { item: any; score: number } | null = null;
        for (const c of candidates || []) {
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
        return best && best.score >= 0.5 ? best.item : null;
      }

      // Load alias mappings
      let aliasRows: any[] = [];
      try {
        const { data: aliases } = await supabaseClient
          .from('menu_item_aliases')
          .select('menu_item_id, alias')
          .eq('brand_id', brandId);
        aliasRows = Array.isArray(aliases) ? aliases : [];
      } catch (_) {}
      const aliasMap: Record<string, any> = {};
      for (const a of aliasRows) {
        const mi = (menuItemsData || []).find((m: any) => m.id === a.menu_item_id);
        if (mi && a.alias) aliasMap[String(a.alias).toLowerCase()] = mi;
      }

      const orderItemsToInsert = scannedData.orderItems.map((itemPayload: any) => {
        const name = itemPayload.menuItemName;
        const lower = String(name || '').toLowerCase();
        let match = (menuItemsData || []).find((mi: any) => mi.name.toLowerCase() === lower)
          || (menuItemsData || []).find((mi: any) => mi.name.toLowerCase().includes(lower))
          || aliasMap[lower]
          || bestFuzzyMatch(name, menuItemsData || []);

        return {
          order_id: newOrderId,
          menu_item_id: match?.id || null,
          menu_item_name: match?.name || name,
          quantity: itemPayload.quantity,
          price_at_purchase: match?.price ?? itemPayload.price ?? null,
          brand_id: brandId,
        };
      });
      const { error: itemInsertError } = await supabaseClient.from('order_items').insert(orderItemsToInsert);
      if (itemInsertError) console.error('[scan-and-create-order] Error inserting some order items:', itemInsertError);
    }

    console.log(`[scan-and-create-order] Successfully created order ${newOrderId} for brand ${brandNameFromDB}.`);
    return new Response(JSON.stringify({ success: true, orderId: newOrderId, delivery_latitude: newOrder.delivery_latitude ?? null, delivery_longitude: newOrder.delivery_longitude ?? null }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('[scan-and-create-order] Unhandled error in function:', error);
    return new Response(JSON.stringify({ error: 'Internal server error', details: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
})
