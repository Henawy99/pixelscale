// supabase/functions/mark-delivered/index.ts
// Called by driver app when a delivery is completed.
// Updates route_stop + order status, then triggers replanning for remaining orders.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Mark Delivered Function Up!");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const {
      route_stop_id,
      order_id,
      driver_latitude,
      driver_longitude,
    } = await req.json();

    if (!route_stop_id) {
      return new Response(
        JSON.stringify({ error: "Missing route_stop_id." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const now = new Date().toISOString();

    // 1. Update route_stop to completed
    const { data: routeStop, error: stopErr } = await supabase
      .from("route_stops")
      .update({
        status: "completed",
        actual_arrival_time: now,
        departure_time: now,
      })
      .eq("id", route_stop_id)
      .select("id, delivery_route_id, order_id, sequence_number, type")
      .single();

    if (stopErr || !routeStop) {
      console.error("Failed to update route stop:", stopErr);
      return new Response(
        JSON.stringify({ error: "Route stop not found." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
      );
    }

    // 2. Update the order to delivered
    const effectiveOrderId = order_id || routeStop.order_id;
    if (effectiveOrderId && routeStop.type === "customer_delivery") {
      const { error: orderErr } = await supabase
        .from("orders")
        .update({
          delivery_status: "delivered",
          status: "delivered",
          actual_delivery_time: now,
        })
        .eq("id", effectiveOrderId);

      if (orderErr) {
        console.error(`Failed to update order ${effectiveOrderId}:`, orderErr);
      }
    }

    // If route was still 'assigned', advance it to 'in_progress'
    await supabase
      .from("delivery_routes")
      .update({
        status: "in_progress",
        started_at: now,
      })
      .eq("id", routeStop.delivery_route_id)
      .eq("status", "assigned");

    // 3. Update driver location if provided
    if (driver_latitude && driver_longitude) {
      const { data: route } = await supabase
        .from("delivery_routes")
        .select("assigned_driver_id")
        .eq("id", routeStop.delivery_route_id)
        .single();

      if (route?.assigned_driver_id) {
        await supabase
          .from("drivers")
          .update({
            current_latitude: driver_latitude,
            current_longitude: driver_longitude,
            last_seen_at: now,
          })
          .eq("id", route.assigned_driver_id);
      }
    }

    // 4. Check if all customer stops in this route are done
    const { data: remainingStops } = await supabase
      .from("route_stops")
      .select("id, type, status")
      .eq("delivery_route_id", routeStop.delivery_route_id)
      .eq("type", "customer_delivery")
      .in("status", ["pending", "in_progress"]);

    const allCustomerStopsDone = !remainingStops || remainingStops.length === 0;

    if (allCustomerStopsDone) {
      console.log(`Route ${routeStop.delivery_route_id}: All customer deliveries completed. Driver heading back to restaurant.`);
    } else {
      console.log(
        `Route ${routeStop.delivery_route_id} has ${remainingStops.length} remaining stops.`
      );

      // 5. Trigger replanning for remaining orders
      const { data: routeInfo } = await supabase
        .from("delivery_routes")
        .select("brand_id, is_demo")
        .eq("id", routeStop.delivery_route_id)
        .single();

      if (routeInfo?.brand_id) {
        try {
          const planUrl = `${supabaseUrl}/functions/v1/plan-routes`;
          fetch(planUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${supabaseServiceKey}`,
            },
            body: JSON.stringify({
              brand_id: routeInfo.brand_id,
              trigger_reason: "mark_delivered",
              is_demo: routeInfo.is_demo ?? false,
            }),
          }).catch((e) => console.error("Replan trigger failed:", e));
        } catch (e) {
          console.error("Failed to trigger replan:", e);
        }
      }
    }


    return new Response(
      JSON.stringify({
        message: "Delivery marked successfully.",
        route_stop_id: routeStop.id,
        remaining_stops: remainingStops?.length ?? 0,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error) {
    console.error("Error in mark-delivered:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Unknown error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
