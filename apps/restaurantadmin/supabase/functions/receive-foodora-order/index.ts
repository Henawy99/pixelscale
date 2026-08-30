// Supabase Edge Function: receive-foodora-order
// Ingests live Foodora (Delivery Hero) orders from the foodora-monitor script,
// maps vendor codes/names to POS brand IDs, geocodes Salzburg addresses,
// and inserts orders and order items directly into Supabase with 'confirmed' status.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

// Static brand mapping (vendorId / vendorCode / vendorName -> Brand UUID)
const VENDOR_BRAND_MAP: Record<string, string> = {
  // DEVIL'S SMASH BURGER
  'e9nt': '4446a388-aaa7-402f-be4d-b82b23797415',
  'devil': '4446a388-aaa7-402f-be4d-b82b23797415',
  // TACOTASTIC
  'zoiw': 'f5116077-8de3-488b-bf9d-75295f791dce',
  'taco': 'f5116077-8de3-488b-bf9d-75295f791dce',
  // CRISPY CHICKEN LAB
  'vo8z': '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
  'crispy': '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
  // THE BOWL SPOT
  'brlb': '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
  'bowl': '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
}

/**
 * Geocode a street address in Salzburg using Nominatim (OSM).
 */
async function geocodeSalzburg(
  street: string | null | undefined,
  postcode: string | null | undefined,
): Promise<{ lat: number; lon: number } | null> {
  if (!street) return null
  try {
    const q = [street, postcode || '5020', 'Salzburg', 'Austria'].filter(Boolean).join(', ')
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&limit=1`
    const res = await fetch(url, {
      headers: { 'User-Agent': 'RestaurantAdmin-Foodora/1.0' },
    })
    if (!res.ok) return null
    const data = await res.json()
    if (data && data.length > 0) {
      return { lat: parseFloat(data[0].lat), lon: parseFloat(data[0].lon) }
    }
  } catch (e) {
    console.warn('[geocodeSalzburg] Failed:', e)
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  let body: any
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const {
    orderId,
    vendorId,
    vendorName,
    status: foodoraStatus,
    deliveryType,
    placedAt,
    estimatedDeliveryTime,
    estimatedPickupTime,
    total,
    deliveryFee,
    serviceFee,
    paymentMethod,
    customerName,
    customerPhone,
    customerAddress,
    customerStreet,
    customerPostcode,
    customerCity,
    note,
    deliveryNotes,
    items = [],
    raw,
  } = body

  if (!orderId || total === undefined) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: orderId, total' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  // Parse combined address string if provided (e.g. "Vogelweiderstraße 89 - 5020, Salzburg")
  let parsedStreet = customerStreet || null
  let parsedPostcode = customerPostcode || null
  let parsedCity = customerCity || null

  if (customerAddress && typeof customerAddress === 'string') {
    // Match "Street - Postcode, City" or "Street, Postcode City"
    const match = customerAddress.match(/^(.*?)(?:\s*-\s*|\s*,\s*)(\d{4,5})\s*,?\s*(.*)$/)
    if (match) {
      parsedStreet = parsedStreet || match[1]?.trim()
      parsedPostcode = parsedPostcode || match[2]?.trim()
      parsedCity = parsedCity || match[3]?.trim()
    } else {
      parsedStreet = parsedStreet || customerAddress.trim()
    }
  }

  // Deduplicate / Update
  const { data: existing } = await supabase
    .from('orders')
    .select('id, status')
    .eq('platform_order_id', String(orderId))
    .maybeSingle()

  if (existing) {
    console.log(`[receive-foodora-order] Order ${orderId} exists — updating details.`)
    const updatePayload: Record<string, any> = {
      updated_at: new Date().toISOString(),
      platform_raw_data: raw ?? body,
    }
    if (customerName) updatePayload.customer_name = customerName
    if (customerPhone) updatePayload.customer_phone = customerPhone
    if (parsedStreet) updatePayload.customer_street = parsedStreet
    if (parsedPostcode) updatePayload.customer_postcode = parsedPostcode
    if (parsedCity) updatePayload.customer_city = parsedCity
    if (estimatedDeliveryTime) updatePayload.estimated_delivery_time = new Date(estimatedDeliveryTime).toISOString()
    if (estimatedPickupTime) updatePayload.estimated_pickup_time = new Date(estimatedPickupTime).toISOString()
    if (foodoraStatus && foodoraStatus.toLowerCase().includes('cancel')) updatePayload.status = 'cancelled'

    await supabase.from('orders').update(updatePayload).eq('id', existing.id)

    return new Response(JSON.stringify({ success: true, updated: true, orderId: existing.id }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Resolve Brand ID
  let brandId: string | null = null
  const cleanVendorId = (vendorId || '').toString().toLowerCase().trim()
  const cleanVendorName = (vendorName || '').toString().toLowerCase().trim()

  if (VENDOR_BRAND_MAP[cleanVendorId]) {
    brandId = VENDOR_BRAND_MAP[cleanVendorId]
  } else {
    for (const [key, bId] of Object.entries(VENDOR_BRAND_MAP)) {
      if (cleanVendorName.includes(key)) {
        brandId = bId
        break
      }
    }
  }

  // If still not found, search in brands table by name
  if (!brandId && vendorName) {
    const { data: brandRow } = await supabase
      .from('brands')
      .select('id')
      .ilike('name', `%${vendorName}%`)
      .maybeSingle()
    brandId = brandRow?.id ?? null
  }

  if (!brandId) {
    const { data: anyBrand } = await supabase
      .from('brands')
      .select('id')
      .order('name')
      .limit(1)
      .maybeSingle()
    brandId = anyBrand?.id ?? null
  }

  if (!brandId) {
    return new Response(
      JSON.stringify({ error: `Cannot resolve brand for Foodora vendor: ${vendorId || vendorName}` }),
      { status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  // Determine fulfillment type
  const rawDeliveryType = (deliveryType || raw?.deliveryType || '').toString().toLowerCase()
  const fulfillmentType = (rawDeliveryType.includes('pickup') || rawDeliveryType.includes('pick') || rawDeliveryType.includes('takeaway') || rawDeliveryType.includes('self'))
    ? 'pickup'
    : 'delivery'

  // Geocode address for delivery
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

  const newOrderId = crypto.randomUUID()
  const orderCreatedAt = placedAt ? new Date(placedAt).toISOString() : new Date().toISOString()
  const parsedTotalPrice = Number(total ?? 0)
  const parsedDeliveryFee = Number(deliveryFee ?? 0)
  const parsedServiceFee = Number(serviceFee ?? 0)

  const newOrder = {
    id: newOrderId,
    brand_id: brandId,
    total_price: parsedTotalPrice,
    delivery_fee: parsedDeliveryFee > 0 ? parsedDeliveryFee : null,
    fixed_service_fee: parsedServiceFee > 0 ? parsedServiceFee : null,
    status: 'confirmed',
    created_at: orderCreatedAt,
    payment_method: paymentMethod ? paymentMethod.toLowerCase() : 'online',
    order_type_name: 'Foodora',
    fulfillment_type: fulfillmentType,
    platform_order_id: String(orderId),
    public_reference: String(orderId),
    note: note ? String(note).trim() : null,
    delivery_notes: deliveryNotes ? String(deliveryNotes).trim() : null,
    customer_name: customerName ?? null,
    customer_phone: customerPhone ?? null,
    customer_street: parsedStreet ?? null,
    customer_postcode: parsedPostcode ?? null,
    customer_city: parsedCity ?? null,
    estimated_delivery_time: estimatedDeliveryTime ? new Date(estimatedDeliveryTime).toISOString() : null,
    estimated_pickup_time: estimatedPickupTime ? new Date(estimatedPickupTime).toISOString() : null,
    delivery_latitude: deliveryLatitude,
    delivery_longitude: deliveryLongitude,
    platform_raw_data: raw ?? body,
  }

  const { error: orderInsertError } = await supabase.from('orders').insert(newOrder)

  if (orderInsertError) {
    console.error('[receive-foodora-order] Failed to insert order:', orderInsertError)
    return new Response(JSON.stringify({ error: orderInsertError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Insert order items
  if (Array.isArray(items) && items.length > 0) {
    const orderItemsToInsert = items.map((item: any) => {
      const quantity = Number(item.quantity ?? 1)
      const unitPrice = Number(item.unitPrice ?? item.price ?? (item.lineItemTotal ? item.lineItemTotal / quantity : 0))

      return {
        id: crypto.randomUUID(),
        order_id: newOrderId,
        menu_item_name: item.name || item.parentName || 'Unknown Item',
        quantity,
        price_at_purchase: unitPrice,
        category_name: item.categoryName ?? null,
        specifications: item.options && item.options.length > 0 ? item.options : null,
        item_remarks: item.customerNotes ?? item.remarks ?? null,
      }
    })

    const { error: itemsError } = await supabase.from('order_items').insert(orderItemsToInsert)
    if (itemsError) {
      console.error('[receive-foodora-order] Failed to insert items:', itemsError)
    }
  }

  console.log(`[receive-foodora-order] Successfully created Foodora order ${orderId} (${newOrderId}) for brand ${brandId}`)

  return new Response(
    JSON.stringify({ success: true, orderId: newOrderId }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
})
