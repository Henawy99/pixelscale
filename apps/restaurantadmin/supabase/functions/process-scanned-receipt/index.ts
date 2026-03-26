/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { v4 as uuidv4 } from 'https://deno.land/std@0.177.0/uuid/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // This function is now called directly by the client script
  const { imagePath } = await req.json();
  const bucketId = 'scanned-receipts';

  if (!imagePath) {
    return new Response(JSON.stringify({ error: 'Missing imagePath in request body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  console.log(`Processing new image via direct call: ${imagePath}`);

  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  if (!GEMINI_API_KEY) {
    console.error('GEMINI_API_KEY is not set.');
    return new Response(JSON.stringify({ error: 'Server configuration error: Missing Gemini API Key' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=${GEMINI_API_KEY}`;

  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    // 1. Get a signed URL for the uploaded image to pass to Gemini
    const { data: urlData, error: urlError } = await supabaseClient
      .storage
      .from(bucketId)
      .createSignedUrl(imagePath, 60); // URL is valid for 60 seconds

    if (urlError || !urlData) {
      console.error('Error creating signed URL:', urlError);
      return new Response(JSON.stringify({ error: 'Failed to get image URL', details: urlError?.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const imageUrl = urlData.signedUrl;

    // 2. Call Gemini Vision API with the image
    const geminiPrompt = `
      Analyze the following receipt image. Your task is to extract the specified information and return it as a VALID JSON object.
      Ensure all keys and string values are double-quoted. Omit any fields you cannot confidently extract.

      First, identify the brand. It must be one of: "CRISPY CHICKEN LAB", "DEVILS SMASH BURGER", "THE BOWL SPOT".
      Then, extract the rest of the information based on that brand's receipt format.

      JSON Structure to populate:
      {
        "brandName": "string (must be one of the three brands listed above)",
        "orderTypeName": "string (e.g., 'Lieferando', 'Takeaway', 'Dine-in')",
        "customerName": "string",
        "customerStreet": "string",
        "customerPostcode": "string",
        "customerCity": "string",
        "totalPrice": "number",
        "createdAt": "string (ISO 8601 format, e.g., 'YYYY-MM-DDTHH:mm:ss')",
        "requestedDeliveryTime": "string (ISO 8601 format)",
        "paymentMethod": "string ('cash' or 'online')",
        "platformOrderId": "string",
        "orderItems": [
          { "menuItemName": "string (Name of the item on the receipt)", "quantity": "integer" }
        ]
      }
    `;

    const imageBytes = await fetch(imageUrl).then(res => res.arrayBuffer());
    const base64Image = btoa(String.fromCharCode(...new Uint8Array(imageBytes)));

    const geminiPayload = {
      contents: [{
        parts: [
          { text: geminiPrompt },
          { inline_data: { mime_type: "image/jpeg", data: base64Image } }
        ]
      }]
    };

    const geminiResponse = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiPayload),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error('Gemini API error:', geminiResponse.status, errorBody);
      return new Response(JSON.stringify({ error: 'Gemini API request failed', details: errorBody }), {
        status: geminiResponse.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const geminiResult = await geminiResponse.json();
    const contentPart = geminiResult.candidates?.[0]?.content?.parts?.[0];
    let geminiJsonText = contentPart?.text?.replace(/```json/g, '')?.replace(/```/g, '')?.trim();

    if (!geminiJsonText) {
      console.error('No text in Gemini response:', JSON.stringify(geminiResult, null, 2));
      return new Response(JSON.stringify({ error: 'Gemini response was empty or malformed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const scannedData = JSON.parse(geminiJsonText);

    // 3. Get Brand ID from brandName
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

    // Log raw AI output to scan_logs for debugging
    try {
      await supabaseClient.from('scan_logs').insert({
        scan_type: 'order_image',
        brand_id: brandId,
        raw_response: geminiResult,
        normalized: scannedData,
        notes: 'process-scanned-receipt raw output',
      });
    } catch (_) {}


    // 4. Fetch menu items for item matching
    const { data: menuItemsData, error: menuItemsError } = await supabaseClient
        .from('menu_items')
        .select('id, name, price')
        .eq('brand_id', brandId);
    if (menuItemsError) throw menuItemsError;

    // 4.5 Normalize items (Foodora-friendly) and resolve to menu items
    // Merge possible arrays used by different platform JSONs
    const itemArrays = [
      scannedData.orderItems,
      scannedData.items,
      scannedData.products,
      scannedData.lines,
      scannedData.orderLines,
      scannedData.order_lines,
    ].filter((a: any) => Array.isArray(a));
    const rawItems: any[] = ([] as any[]).concat(...itemArrays);

    function parseQuantity(q: any): number {
      if (typeof q === 'number') return Number(q) || 1;
      const s = String(q ?? '').trim();
      // common patterns: "2x Burger", "Burger x2", "2 Burger"
      const m = s.match(/^(\d+)\s*x\b|\bx\s*(\d+)$|^(\d+)\b/);
      if (m) {
        const n = Number(m[1] || m[2] || m[3]);
        return isNaN(n) ? 1 : n;
      }
      const digits = s.match(/\d+/);
      return digits ? Number(digits[0]) || 1 : 1;
    }

    const items = rawItems
      .map((it: any) => ({
        menuItemName: it.menuItemName ?? it.menu_item_name ?? it.item_name ?? it.title ?? it.name ?? null,
        quantity: parseQuantity(it.quantity),
        price: it.price ?? it.item_price ?? it.unit_price ?? it.amount ?? it.total ?? it.line_total ?? null,
      }))
      .filter((x: any) => x.menuItemName);

    // Build alias map
    let aliasMap: Record<string, any> = {};
    try {
      const { data: aliases } = await supabaseClient
        .from('menu_item_aliases')
        .select('menu_item_id, alias')
        .eq('brand_id', brandId);
      const byId: Record<string, any> = {};
      for (const mi of (menuItemsData || [])) byId[mi.id] = mi;
      for (const a of (aliases || [])) {
        const mi = byId[a.menu_item_id];
        if (mi && a.alias) aliasMap[String(a.alias).toLowerCase()] = mi;
      }
    } catch (_) {}

    function bestFuzzyMatch(name: string, candidates: any[]): any | null {
      const target = String(name).toLowerCase().trim();
      if (!target) return null;
      if (aliasMap[target]) return aliasMap[target];
      const targetTokens = target.split(/[^a-z0-9]+/).filter(Boolean);
      let best: { item: any; score: number } | null = null;
      for (const c of candidates) {
        const cand = String(c.name || '').toLowerCase().trim();
        if (!cand) continue;
        if (cand === target) return c;
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

    // Try to resolve items by cleaned name
    const normalizedItems: any[] = [];
    for (const it of items) {
      let nameLower = String(it.menuItemName).toLowerCase().trim();
      // strip qty prefixes/suffixes and trailing price fragments
      nameLower = nameLower.replace(/^\d+\s*x\s*/i, '').replace(/\s*x\s*\d+$/i, '').trim();
      nameLower = nameLower.replace(/[-€]\s*\d+[\.,]\d+$/, '').trim();

      let match = (menuItemsData || []).find((m: any) => m.name.toLowerCase() === nameLower)
        || (menuItemsData || []).find((m: any) => m.name.toLowerCase().includes(nameLower))
        || aliasMap[nameLower]
        || bestFuzzyMatch(nameLower, menuItemsData || []);

      normalizedItems.push({
        menu_item_id: match?.id ?? null,
        menu_item_name: match?.name ?? it.menuItemName,
        quantity: it.quantity,
        price_at_purchase: it.price ?? match?.price ?? null,
        brand_id: brandId,
      });
    }

    // If no items resolved but raw items exist, keep them as free-text lines
    const itemsForInsert = normalizedItems.length ? normalizedItems : items.map(it => ({
      menu_item_id: null,
      menu_item_name: it.menuItemName,
      quantity: it.quantity,
      price_at_purchase: it.price ?? null,
      brand_id: brandId,
    }));

    // 5. Create Order and Order Items
    const newOrderId = uuidv4();
    const orderCreatedAt = scannedData.createdAt ? new Date(scannedData.createdAt) : new Date();

    const newOrder = {
      id: newOrderId,
      brand_id: brandId,
      brand_name: brandNameFromDB,
      total_price: scannedData.totalPrice,
      status: 'pending_confirmation',
      created_at: orderCreatedAt.toISOString(),
      scanned_date: new Date().toISOString(),
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
    if (orderInsertError) throw orderInsertError;

    // Insert items using normalized items (or pass-through free-text lines)
    if (itemsForInsert.length > 0) {
      const { error: itemInsertError } = await supabaseClient.from('order_items').insert(
        itemsForInsert.map(it => ({ ...it, order_id: newOrderId }))
      );
      if (itemInsertError) console.error('Error inserting some order items:', itemInsertError);

      // Auto-create alias suggestions for unmatched items
      try {
        const suggestions = itemsForInsert
          .filter(it => !it.menu_item_id && it.menu_item_name)
          .map(it => ({ brand_id: brandId, alias: it.menu_item_name }));
        if (suggestions.length) {
          const { data: existing } = await supabaseClient
            .from('menu_item_alias_suggestions')
            .select('brand_id, alias')
            .eq('brand_id', brandId);
          const existingSet = new Set((existing || []).map((r: any) => `${r.brand_id}|${(r.alias || '').toLowerCase()}`));
          const toInsert = suggestions.filter((s: any) => !existingSet.has(`${s.brand_id}|${String(s.alias).toLowerCase()}`));
          if (toInsert.length) await supabaseClient.from('menu_item_alias_suggestions').insert(toInsert);
        }
      } catch (_) {}
    }

    console.log(`Successfully created order ${newOrderId} for brand ${brandNameFromDB}.`);

    // Link imagePath to scanned_receipts for UI
    try {
      await supabaseClient.from('scanned_receipts').insert({
        scan_type: 'order',
        storage_path: imagePath,
        brand_name: brandNameFromDB,
        platform_order_id: scannedData.platformOrderId ?? null,
        created_order_id: newOrderId,
      });
    } catch (_) {}

    return new Response(JSON.stringify({ success: true, orderId: newOrderId }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Unhandled error in function:', error);
    return new Response(JSON.stringify({ error: 'Internal server error', details: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
})
