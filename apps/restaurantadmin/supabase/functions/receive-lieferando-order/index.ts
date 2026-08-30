/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── accountId → brandId mapping ───────────────────────────────────────────
const ACCOUNT_BRAND_MAP: Record<string, string> = {
  'account1': '4446a388-aaa7-402f-be4d-b82b23797415', // DEVILS SMASH BURGER
  'account2': 'f5116077-8de3-488b-bf9d-75295f791dce', // TACOTASTIC
  'account3': '8ec82a94-89f5-4603-bb35-c47c78d66d2a', // CRISPY CHICKEN LAB
  'account4': '59bf0f09-ab58-48a0-9b3f-13c7709c8600', // THE BOWL SPOT
  // account5 (STACK'D) will be resolved by name lookup below
}

// ─── Geocode helper (Salzburg default) ─────────────────────────────────────
async function geocodeSalzburg(
  street?: string | null,
  postcode?: string | null,
): Promise<{ lat: number; lon: number } | null> {
  try {
    const parts: string[] = []
    if (street && String(street).trim().length) parts.push(String(street))
    if (postcode && String(postcode).trim().length) parts.push(String(postcode))
    parts.push('Salzburg, Austria')
    const q = parts.join(', ')
    const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=1`
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'restaurantadmin-lieferando/1.0 (contact: admin@example.com)' },
    })
    if (!resp.ok) return null
    const arr = await resp.json()
    if (Array.isArray(arr) && arr.length > 0) {
      const lat = Number(arr[0]?.lat)
      const lon = Number(arr[0]?.lon)
      if (!isNaN(lat) && !isNaN(lon)) return { lat, lon }
    }
  } catch (_) {}
  return null
}

// ─── Fuzzy menu-item match (same logic as scan-and-create-order) ───────────
function bestFuzzyMatch(name: string, candidates: any[]): any | null {
  const target = String(name || '').toLowerCase().trim()
  if (!target) return null
  const targetTokens = target.split(/[^a-z0-9]+/).filter(Boolean)
  let best: { item: any; score: number } | null = null
  for (const c of candidates || []) {
    const cand = String(c.name || '').toLowerCase().trim()
    if (!cand) continue
    if (cand === target) return c
    if (cand.includes(target) || target.includes(cand)) {
      const score = Math.min(target.length, cand.length) / Math.max(target.length, cand.length)
      if (!best || score > best.score) best = { item: c, score }
      continue
    }
    const candTokens = cand.split(/[^a-z0-9]+/).filter(Boolean)
    const common = targetTokens.filter((t) =>
      candTokens.some((ct) => ct === t || ct.includes(t) || t.includes(ct)),
    )
    const score = common.length / Math.max(1, Math.max(targetTokens.length, candTokens.length))
    if (score > 0 && (!best || score > best.score)) best = { item: c, score }
  }
  return best && best.score >= 0.5 ? best.item : null
}

// ─── Main handler ───────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Only accept POST
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  let body: any
  try {
    body = await req.json()
  } catch (_) {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const {
    accountId,
    orderId,
    publicReference,
    status: lieferandoStatus,
    deliveryType,
    placedAt,
    total,
    subtotal,
    restaurantTotal,
    deliveryFee,
    serviceFee,
    currency,
    orderRemarks,
    deliveryNotes,
    customerName,
    customerPhone,
    customerDisplayPhone,
    verificationCode,
    customerStreet,
    customerPostcode,
    customerCity,
    estimatedDeliveryTime,
    estimatedPickupTime,
    requestedTime,
    couriers,
    foodPrepDuration,
    withAlcohol,
    items,
    raw,
  } = body

  // ── Validate required fields ─────────────────────────────────────────────
  if (!accountId || !orderId || total === undefined) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: accountId, orderId, total' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  // ── Deduplicate: skip if this platform order already exists ───────────────
  const { data: existing } = await supabase
    .from('orders')
    .select('id')
    .eq('platform_order_id', orderId)
    .maybeSingle()

  if (existing) {
    console.log(`[receive-lieferando-order] Order ${orderId} already exists — skipping.`)
    return new Response(JSON.stringify({ success: true, skipped: true, reason: 'duplicate' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // ── Resolve brandId ──────────────────────────────────────────────────────
  let brandId: string | null = ACCOUNT_BRAND_MAP[accountId] ?? null

  // If not in static map, try to look up by accountId label stored in brands table
  if (!brandId) {
    const { data: brandRow } = await supabase
      .from('brands')
      .select('id')
      .ilike('name', `%${accountId}%`)
      .maybeSingle()
    brandId = brandRow?.id ?? null
  }

  if (!brandId) {
    console.error(`[receive-lieferando-order] No brandId found for accountId: ${accountId}`)
    // Still create the order but log the issue — use a fallback default brand
    // so orders are never silently dropped.
    const { data: anyBrand } = await supabase
      .from('brands')
      .select('id')
      .order('name')
      .limit(1)
      .maybeSingle()
    brandId = anyBrand?.id ?? null
    if (!brandId) {
      return new Response(
        JSON.stringify({ error: `Cannot resolve brand for accountId: ${accountId}` }),
        { status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }
  }

  // ── Determine fulfillment type ───────────────────────────────────────────
  const rawDeliveryType = (deliveryType || raw?.delivery_type || '').toString().toLowerCase()
  const fulfillmentType = (rawDeliveryType.includes('pickup') || rawDeliveryType.includes('takeaway') || rawDeliveryType.includes('self'))
    ? 'pickup'
    : 'delivery'

  // ── Build note from remarks (delivery notes stored in separate column) ───────
  const note = (orderRemarks && String(orderRemarks).trim()) ? String(orderRemarks).trim() : null

  // Build delivery_notes string from floor/door/buzzer array
  const deliveryNotesStr = Array.isArray(deliveryNotes) && deliveryNotes.length > 0
    ? deliveryNotes.filter(Boolean).join(' • ')
    : (deliveryNotes && String(deliveryNotes).trim()) ? String(deliveryNotes).trim() : null

  // ── Geocode customer address (only for delivery) ──────────────────────────
  let deliveryLatitude: number | null = null
  let deliveryLongitude: number | null = null
  if (fulfillmentType === 'delivery') {
    try {
      const geo = await geocodeSalzburg(customerStreet, customerPostcode)
      if (geo) {
        deliveryLatitude = geo.lat
        deliveryLongitude = geo.lon
      }
    } catch (_) {}
  }

  // ── Insert order ─────────────────────────────────────────────────────────
  const newOrderId = crypto.randomUUID()
  const orderCreatedAt = placedAt ? new Date(placedAt).toISOString() : new Date().toISOString()
  const parsedTotalPrice = Number(total ?? raw?.customer_total ?? raw?.restaurant_total ?? 0)
  const parsedDeliveryFee = Number(deliveryFee ?? raw?.delivery_fee ?? 0)
  const parsedServiceFee = Number(serviceFee ?? raw?.service_fee ?? 0)

  const newOrder = {
    id: newOrderId,
    brand_id: brandId,
    total_price: parsedTotalPrice,
    delivery_fee: parsedDeliveryFee > 0 ? parsedDeliveryFee : null,
    fixed_service_fee: parsedServiceFee > 0 ? parsedServiceFee : null,
    status: 'confirmed',
    created_at: orderCreatedAt,
    payment_method: 'online',
    order_type_name: 'Lieferando',
    fulfillment_type: fulfillmentType,
    platform_order_id: String(orderId),
    public_reference: publicReference ?? raw?.public_reference ?? null,
    note,
    delivery_notes: deliveryNotesStr,
    customer_name: customerName ?? null,
    customer_phone: customerPhone ?? customerDisplayPhone ?? null,
    verification_code: verificationCode ? String(verificationCode) : (raw?.customer?.phone_masking_code ? String(raw.customer.phone_masking_code) : null),
    customer_street: customerStreet ?? null,
    customer_postcode: customerPostcode ?? null,
    customer_city: customerCity ?? null,
    estimated_delivery_time: estimatedDeliveryTime ?? raw?.restaurant_estimated_delivery_time ?? null,
    estimated_pickup_time: estimatedPickupTime ?? raw?.restaurant_estimated_pickup_time ?? null,
    requested_delivery_time: requestedTime ?? raw?.requested_time ?? null,
    delivery_latitude: deliveryLatitude,
    delivery_longitude: deliveryLongitude,
    // Full raw Lieferando order — nothing lost
    platform_raw_data: raw ?? null,
    couriers: couriers ?? null,
    food_prep_duration: foodPrepDuration ?? raw?.food_preparation_duration ?? null,
    with_alcohol: withAlcohol ?? raw?.with_alcohol ?? false,
  }

  const { error: orderInsertError } = await supabase.from('orders').insert(newOrder)
  if (orderInsertError) {
    console.error('[receive-lieferando-order] Order insert error:', orderInsertError)
    return new Response(
      JSON.stringify({ error: 'Failed to insert order', details: orderInsertError.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  // ── Insert order items ───────────────────────────────────────────────────
  if (Array.isArray(items) && items.length > 0) {
    // Load menu items for this brand for fuzzy matching
    const { data: menuItemsData } = await supabase
      .from('menu_items')
      .select('id, name, price')
      .eq('brand_id', brandId)

    // Load alias mappings
    let aliasRows: any[] = []
    try {
      const { data: aliases } = await supabase
        .from('menu_item_aliases')
        .select('menu_item_id, alias')
        .eq('brand_id', brandId)
      aliasRows = Array.isArray(aliases) ? aliases : []
    } catch (_) {}

    const aliasMap: Record<string, any> = {}
    for (const a of aliasRows) {
      const mi = (menuItemsData || []).find((m: any) => m.id === a.menu_item_id)
      if (mi && a.alias) aliasMap[String(a.alias).toLowerCase()] = mi
    }

    const orderItemsToInsert = items.map((item: any) => {
      const name = item.name ?? ''
      const lower = String(name).toLowerCase()
      const match =
        (menuItemsData || []).find((mi: any) => mi.name.toLowerCase() === lower) ||
        (menuItemsData || []).find((mi: any) => mi.name.toLowerCase().includes(lower)) ||
        aliasMap[lower] ||
        bestFuzzyMatch(name, menuItemsData || [])

      const qty = Number(item.quantity) || 1
      // Calculate unit price: prefer item.amount (unit price in Lieferando), or total / qty
      const unitPrice = item.amount !== undefined && item.amount !== null
        ? Number(item.amount)
        : (item.price !== undefined && item.price !== null
            ? (qty > 1 && item.totalAmount ? Number(item.totalAmount) / qty : Number(item.price))
            : (match?.price ?? null))

      return {
        order_id: newOrderId,
        menu_item_id: match?.id ?? null,
        menu_item_name: match?.name ?? name,
        quantity: qty,
        price_at_purchase: unitPrice,
        brand_id: brandId,
        // Full Lieferando product fields
        category_name: item.categoryName ?? null,
        item_code: item.code ?? null,
        specifications: item.specifications?.length ? item.specifications : null,
        partner_product_ids: item.partnerProductIds?.length ? item.partnerProductIds : null,
        lieferando_product_id: item.lieferandoProductId ?? null,
        lieferando_menu_product_id: item.menuProductId ?? null,
        item_remarks: item.remarks ?? null,
      }
    })

    const { error: itemsError } = await supabase.from('order_items').insert(orderItemsToInsert)
    if (itemsError) {
      console.error('[receive-lieferando-order] Items insert error:', itemsError.message)
    }
  }

  console.log(`[receive-lieferando-order] ✅ Created order ${newOrderId} from account ${accountId} (lieferando ref: ${orderId})`)

  return new Response(
    JSON.stringify({ success: true, orderId: newOrderId }),
    { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
})
