// supabase/functions/create-demo-order/index.ts
// Clones a random historical order as a live demo delivery order (delivery_status='preparing')
// with estimated delivery time = now + 60 minutes, then invokes plan-routes.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Create Demo Order Function Up!");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const body = await req.json().catch(() => ({}));
    const action = body.action ?? "create";

    // Primary brand_id from delivery_settings
    const { data: primarySettings } = await supabase
      .from("delivery_settings")
      .select("brand_id")
      .limit(1)
      .maybeSingle();
    const brandId = body.brand_id || primarySettings?.brand_id || "f5116077-8de3-488b-bf9d-75295f791dce";

    // ── ACTION: RESET DEMO ──────────────────────────────────────────
    if (action === "reset") {
      console.log("Resetting all demo orders, stops, and routes...");

      // 1. Get all demo order IDs
      const { data: demoOrders } = await supabase
        .from("orders")
        .select("id")
        .eq("is_demo", true);

      const demoOrderIds = (demoOrders || []).map((o: any) => o.id);

      if (demoOrderIds.length > 0) {
        // Delete route_stops referencing demo orders
        await supabase.from("route_stops").delete().in("order_id", demoOrderIds);
        // Delete order items for demo orders
        await supabase.from("order_items").delete().in("order_id", demoOrderIds);
        // Delete the demo orders themselves
        await supabase.from("orders").delete().in("id", demoOrderIds);
      }

      // Delete demo routes
      await supabase.from("delivery_routes").delete().eq("is_demo", true);

      // Reset Abunageb driver status
      await supabase
        .from("drivers")
        .update({
          current_route_id: null,
          projected_return_at: null,
          available_at: new Date().toISOString(),
          is_online: true,
        })
        .or("name.ilike.%abunageb%,is_demo.eq.true");

      // Trigger replanning to refresh system state
      try {
        await fetch(`${supabaseUrl}/functions/v1/plan-routes`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({ brand_id: brandId, trigger_reason: "demo_reset", is_demo: true }),
        });
      } catch (e) {
        console.warn("Replanning call after reset warning:", e);
      }

      return new Response(
        JSON.stringify({ success: true, message: "Demo data reset successfully." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // ── ACTION: CREATE RANDOM DEMO ORDER ─────────────────────────────
    console.log("Sampling historical past order...");

    // Fetch 30 candidates that have coordinates
    const { data: candidates, error: candErr } = await supabase
      .from("orders")
      .select("*")
      .eq("fulfillment_type", "delivery")
      .eq("is_demo", false)
      .not("delivery_latitude", "is", null)
      .not("delivery_longitude", "is", null)
      .limit(30)
      .order("created_at", { ascending: false });

    if (candErr || !candidates || candidates.length === 0) {
      throw new Error(
        `Could not find past orders with coordinates: ${candErr?.message || "none found"}`
      );
    }

    // Pick a random template
    const template = candidates[Math.floor(Math.random() * candidates.length)];
    console.log(`Picked template order: ${template.id} (${template.customer_name})`);

    // Fetch template order items
    const { data: templateItems } = await supabase
      .from("order_items")
      .select("*")
      .eq("order_id", template.id);

    const now = new Date();
    const estDelivery = new Date(now.getTime() + 60 * 60 * 1000); // exactly 60 minutes from now
    const estPickup = new Date(now.getTime() + 10 * 60 * 1000);   // 10 minutes prep time
    const demoRef = `DEMO-${Math.floor(1000 + Math.random() * 9000)}`;

    // Randomize payment method occasionally if not set to test cash vs card
    const paymentMethod = template.payment_method || (Math.random() > 0.4 ? "cash" : "card");

    // Ensure customer_street includes street / house number
    let customerStreet = (template.customer_street || "Musterstraße 12").trim();
    if (!/\d/.test(customerStreet)) {
      const rawStreetNum = template.platform_raw_data?.customer?.street_number;
      if (rawStreetNum && String(rawStreetNum).trim().length > 0) {
        customerStreet = `${customerStreet} ${String(rawStreetNum).trim()}`;
      } else {
        const randNum = Math.floor(Math.random() * 45) + 1;
        customerStreet = `${customerStreet} ${randNum}`;
      }
    }

    // Insert cloned demo order
    const { data: newOrder, error: insErr } = await supabase
      .from("orders")
      .insert({
        brand_id: brandId,
        total_price: template.total_price || 24.50,
        status: "confirmed",
        delivery_status: "preparing",
        created_at: now.toISOString(),
        customer_name: `[DEMO] ${template.customer_name || "Customer"}`,
        customer_street: customerStreet,
        customer_postcode: template.customer_postcode || "5020",
        customer_city: template.customer_city || "Salzburg",
        customer_phone: template.customer_phone || "+436601234567",
        verification_code: template.verification_code || String(Math.floor(1000 + Math.random() * 9000)),
        public_reference: demoRef,
        delivery_notes: template.delivery_notes || "Bitte anläuten, 2. Stock links",
        payment_method: paymentMethod,
        delivery_latitude: template.delivery_latitude,
        delivery_longitude: template.delivery_longitude,
        estimated_delivery_time: estDelivery.toISOString(),
        estimated_pickup_time: estPickup.toISOString(),
        is_demo: true,
        fulfillment_type: "delivery",
        order_type_name: template.order_type_name || "Lieferando",
        platform_raw_data: template.platform_raw_data,
      })
      .select()
      .single();

    if (insErr || !newOrder) {
      throw new Error(`Failed to insert demo order: ${insErr?.message}`);
    }

    console.log(`Created demo order ID: ${newOrder.id}`);

    // Clone order items
    if (templateItems && templateItems.length > 0) {
      const itemsToInsert = templateItems.map((item: any) => ({
        order_id: newOrder.id,
        brand_id: newOrder.brand_id,
        menu_item_id: item.menu_item_id,
        menu_item_name: item.menu_item_name,
        quantity: item.quantity,
        price_at_purchase: item.price_at_purchase,
        category_name: item.category_name,
        item_code: item.item_code,
        specifications: item.specifications,
        partner_product_ids: item.partner_product_ids,
        lieferando_product_id: item.lieferando_product_id,
        lieferando_menu_product_id: item.lieferando_menu_product_id,
        item_remarks: item.item_remarks,
      }));

      await supabase.from("order_items").insert(itemsToInsert);
    } else {
      // Fallback sample items if past order didn't have order_items rows
      await supabase.from("order_items").insert([
        {
          order_id: newOrder.id,
          brand_id: newOrder.brand_id,
          menu_item_name: "Cheeseburger French Taco",
          quantity: 1,
          price_at_purchase: 16.90,
        },
        {
          order_id: newOrder.id,
          brand_id: newOrder.brand_id,
          menu_item_name: "Sweet Potato Frites",
          quantity: 1,
          price_at_purchase: 7.99,
        },
      ]);
    }

    // Trigger plan-routes to immediately optimize and assign to Abunageb
    let planResult = null;
    try {
      const planRes = await fetch(`${supabaseUrl}/functions/v1/plan-routes`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({
          brand_id: newOrder.brand_id,
          trigger_reason: "demo_order_created",
          is_demo: true,
        }),
      });
      planResult = await planRes.json();

      // If order was assigned to a route, mark that route as is_demo = true
      const { data: updatedOrder } = await supabase
        .from("orders")
        .select("delivery_route_id")
        .eq("id", newOrder.id)
        .maybeSingle();

      if (updatedOrder?.delivery_route_id) {
        await supabase
          .from("delivery_routes")
          .update({ is_demo: true })
          .eq("id", updatedOrder.delivery_route_id);
      }
    } catch (e) {
      console.warn("Error invoking plan-routes:", e);
    }

    return new Response(
      JSON.stringify({
        success: true,
        order: {
          id: newOrder.id,
          customer_name: newOrder.customer_name,
          address: `${newOrder.customer_street}, ${newOrder.customer_city}`,
          phone: newOrder.customer_phone,
          payment_method: newOrder.payment_method,
          estimated_delivery_time: newOrder.estimated_delivery_time,
          public_reference: newOrder.public_reference,
        },
        plan: planResult,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error: any) {
    console.error("Error in create-demo-order:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
