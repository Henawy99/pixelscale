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

    // If the driver skipped "Start tour", the tour is on the road now: advance it and
    // mark its other orders as out for delivery so the planner leaves them alone.
    const { data: started } = await supabase
      .from("delivery_routes")
      .update({
        status: "in_progress",
        started_at: now,
      })
      .eq("id", routeStop.delivery_route_id)
      .eq("status", "assigned")
      .select("id, assigned_driver_id");
    if (started && started.length > 0) {
      const { data: routeOrders } = await supabase
        .from("route_stops")
        .select("order_id")
        .eq("delivery_route_id", routeStop.delivery_route_id)
        .not("order_id", "is", null);
      const others = (routeOrders ?? []).map((r: any) => r.order_id).filter((id: string) => id !== effectiveOrderId);
      if (others.length > 0) {
        await supabase
          .from("orders")
          .update({ delivery_status: "out_for_delivery", status: "delivering" })
          .in("id", others)
          .not("status", "in", '("cancelled","delivered","completed")');
      }
      await supabase
        .from("drivers")
        .update({ current_route_id: routeStop.delivery_route_id })
        .eq("id", started[0].assigned_driver_id);
    }

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
      console.log(`Route ${routeStop.delivery_route_id}: all customer deliveries done, driver heading back.`);
    }

    // 5. The driver's return time changed: re-plan everyone (one plan covers all brands).
    const { data: routeInfo } = await supabase
      .from("delivery_routes")
      .select("is_demo")
      .eq("id", routeStop.delivery_route_id)
      .single();
    const replan = fetch(`${supabaseUrl}/functions/v1/plan-routes`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${supabaseServiceKey}` },
      body: JSON.stringify({ trigger_reason: "mark_delivered", is_demo: routeInfo?.is_demo ?? false }),
    }).catch((e) => console.error("Replan trigger failed:", e));
    // Keep the request alive after responding.
    (globalThis as any).EdgeRuntime?.waitUntil?.(replan);

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
