import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { v4 as uuidv4 } from 'https://deno.land/std@0.177.0/uuid/mod.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { deliveryZoneForPostcode } from '../_shared/delivery_zones.ts';
import { resolveBrandSlug } from '../_shared/online_brands.ts';

interface CartLine {
  menuItemId: string;
  quantity: number;
}

interface WebOrderBody {
  brandSlug: string;
  items: CartLine[];
  fulfillmentType: 'pickup' | 'delivery';
  paymentMethod?: 'cash' | 'online';
  customerName?: string;
  customerStreet?: string;
  customerPostcode?: string;
  customerCity?: string;
  customerPhone?: string;
  note?: string;
  requestedDeliveryTime?: string;
  deliveryLatitude?: number;
  deliveryLongitude?: number;
}

async function generateOrderId(supabase: ReturnType<typeof createClient>) {
  const now = new Date();
  const day = String(now.getDate()).padStart(2, '0');
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const year = String(now.getFullYear());

  const { count: totalCount } = await supabase
    .from('orders')
    .select('id', { count: 'exact', head: true });

  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(todayStart);
  todayEnd.setDate(todayEnd.getDate() + 1);

  const { count: todayCount } = await supabase
    .from('orders')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', todayStart.toISOString())
    .lt('created_at', todayEnd.toISOString());

  const total = (totalCount ?? 0) + 1;
  const daily = (todayCount ?? 0) + 1;
  const orderNumber =
    `${day}${month}${year}${String(total).padStart(6, '0')}${String(daily).padStart(2, '0')}`;

  return { orderNumber, dailyOrderNumber: daily };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as WebOrderBody;

    if (!body.brandSlug || !body.items?.length) {
      return new Response(JSON.stringify({ error: 'Invalid order payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!body.fulfillmentType || !['pickup', 'delivery'].includes(body.fulfillmentType)) {
      return new Response(JSON.stringify({ error: 'Select pickup or delivery' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (body.fulfillmentType === 'delivery') {
      if (!body.customerName?.trim() || !body.customerStreet?.trim() ||
        !body.customerPostcode?.trim() || !body.customerCity?.trim()) {
        return new Response(JSON.stringify({ error: 'Delivery address required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const brand = resolveBrandSlug(body.brandSlug);
    if (!brand) {
      return new Response(JSON.stringify({ error: 'Unknown brand' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const menuItemIds = [...new Set(body.items.map((i) => i.menuItemId))];
    const { data: menuItems, error: menuErr } = await supabase
      .from('menu_items')
      .select('id, name, price, brand_id, is_available')
      .in('id', menuItemIds)
      .eq('brand_id', brand.id);

    if (menuErr) throw menuErr;

    const menuById = new Map((menuItems ?? []).map((m) => [m.id, m]));
    let totalPrice = 0;
    const orderLines: {
      menuItemId: string;
      name: string;
      quantity: number;
      price: number;
    }[] = [];

    for (const line of body.items) {
      if (!line.quantity || line.quantity < 1) continue;
      const item = menuById.get(line.menuItemId);
      if (!item || !item.is_available) {
        return new Response(
          JSON.stringify({ error: `Item unavailable: ${line.menuItemId}` }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      const price = Number(item.price);
      totalPrice += price * line.quantity;
      orderLines.push({
        menuItemId: item.id,
        name: item.name,
        quantity: line.quantity,
        price,
      });
    }

    if (orderLines.length === 0) {
      return new Response(JSON.stringify({ error: 'Cart is empty' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const subtotal = totalPrice;
    let deliveryFee = 0;

    if (body.fulfillmentType === 'delivery') {
      const zone = deliveryZoneForPostcode(body.customerPostcode);
      if (!zone) {
        return new Response(
          JSON.stringify({
            error:
              'Leider liefern wir nicht in diese Postleitzahl. Bitte wähle Abholung oder eine unserer Liefergebiete (PLZ 5020, 5023, 5026, 5061, 5071, 5101, 5161, 5201, 5300, 5301, 5321).',
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      if (subtotal < zone.minimumOrder - 0.001) {
        const remaining = (zone.minimumOrder - subtotal).toFixed(2);
        return new Response(
          JSON.stringify({
            error: `Mindestbestellwert für PLZ ${zone.plz}: €${zone.minimumOrder.toFixed(2)}. Noch €${remaining} bis zur Bestellung.`,
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      deliveryFee = zone.deliveryFee;
      totalPrice = subtotal + deliveryFee;
    }

    const orderId = uuidv4();
    const { orderNumber, dailyOrderNumber } = await generateOrderId(supabase);
    const paymentMethod = body.paymentMethod === 'online' ? 'online' : 'cash';
    const status = paymentMethod === 'online' ? 'pending_online_payment' : 'confirmed';

    const phoneNote = body.customerPhone?.trim()
      ? `Tel: ${body.customerPhone.trim()}`
      : null;
    const combinedNote = [body.note?.trim(), phoneNote].filter(Boolean).join(' | ') || null;

    const orderRow = {
      id: orderId,
      order_number: orderNumber,
      daily_order_number: dailyOrderNumber,
      brand_id: brand.id,
      total_price: totalPrice,
      status,
      created_at: new Date().toISOString(),
      profit: totalPrice,
      delivery_fee: deliveryFee > 0 ? deliveryFee : null,
      order_type_name: 'Website',
      payment_method: paymentMethod,
      fulfillment_type: body.fulfillmentType,
      customer_name: body.customerName?.trim() || null,
      customer_street: body.customerStreet?.trim() || null,
      customer_postcode: body.customerPostcode?.trim() || null,
      customer_city: body.customerCity?.trim() || null,
      requested_delivery_time: body.requestedDeliveryTime ?? null,
      delivery_latitude: body.deliveryLatitude ?? null,
      delivery_longitude: body.deliveryLongitude ?? null,
      note: combinedNote,
      platform_order_id: `WEB-${orderNumber}`,
    };

    const { error: orderErr } = await supabase.from('orders').insert(orderRow);
    if (orderErr) throw orderErr;

    for (const line of orderLines) {
      const { error: itemErr } = await supabase.from('order_items').insert({
        order_id: orderId,
        menu_item_id: line.menuItemId,
        menu_item_name: line.name,
        quantity: line.quantity,
        price_at_purchase: line.price,
        brand_id: brand.id,
      });
      if (itemErr) throw itemErr;
    }

    // Best-effort inventory deduction
    for (const line of orderLines) {
      const { data: materials } = await supabase
        .from('menu_item_materials')
        .select('material_id, quantity_used')
        .eq('menu_item_id', line.menuItemId);

      for (const mat of materials ?? []) {
        const qty = Number(mat.quantity_used) * line.quantity;
        const { data: stock } = await supabase
          .from('material')
          .select('id, current_quantity, name')
          .eq('id', mat.material_id)
          .maybeSingle();

        if (stock) {
          const newQty = Math.max(0, Number(stock.current_quantity) - qty);
          await supabase
            .from('material')
            .update({ current_quantity: newQty })
            .eq('id', mat.material_id);
        }
      }
    }

    return new Response(
      JSON.stringify({
        orderId,
        orderNumber,
        dailyOrderNumber,
        totalPrice,
        subtotal,
        deliveryFee,
        brandName: brand.name,
        status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('[create-web-order]', e);
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : 'Server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
