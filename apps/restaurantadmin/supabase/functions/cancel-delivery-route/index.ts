import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Cancel Delivery Route Function Up!");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { route_id, driver_id, order_ids } = await req.json();

    if (!route_id) {
      return new Response(JSON.stringify({ error: "Missing 'route_id'." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }
    if (!driver_id) {
      return new Response(JSON.stringify({ error: "Missing 'driver_id'." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }
     if (!order_ids || !Array.isArray(order_ids)) {
      console.warn("Warning: 'order_ids' was missing or not an array. Proceeding to cancel route and driver assignment, but orders won't be unlinked.");
      // Allow proceeding without order_ids for now, but log it.
      // In a stricter implementation, you might require order_ids if the route has orders.
    }


    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    );

    console.log(`Attempting to cancel route: ${route_id} for driver: ${driver_id}. Orders to update: ${order_ids?.join(", ")}`);

    // 1. Update delivery_routes table: Set status to 'cancelled'
    const { error: routeUpdateError } = await supabaseClient
      .from("delivery_routes")
      .update({ status: "cancelled", assigned_driver_id: null }) // Also unassign driver from route
      .eq("id", route_id);

    if (routeUpdateError) {
      console.error("Error updating delivery_routes status:", routeUpdateError);
      throw new Error(`Failed to update route status: ${routeUpdateError.message}`);
    }
    console.log(`Route ${route_id} status updated to cancelled.`);

    // 2. Update drivers table: Set current_route_id to null for the driver
    const { error: driverUpdateError } = await supabaseClient
      .from("drivers")
      .update({ current_route_id: null })
      .eq("id", driver_id);

    if (driverUpdateError) {
      console.error("Error updating driver's current_route_id:", driverUpdateError);
      // Non-critical if route is already cancelled, but log it.
      // Depending on desired atomicity, you might choose to throw here.
    } else {
      console.log(`Driver ${driver_id} current_route_id set to null.`);
    }
    

    // 3. Update orders table: Set delivery_route_id to null and delivery_status for associated orders
    if (order_ids && order_ids.length > 0) {
      const orderUpdates = order_ids.map((orderId: string) => ({
        id: orderId,
        delivery_route_id: null,
        delivery_status: null, // Or 'pending_routing' or your default routable status
      }));

      for (const update of orderUpdates) {
        const { error: orderUpdateError } = await supabaseClient
          .from("orders")
          .update({ delivery_route_id: update.delivery_route_id, delivery_status: update.delivery_status })
          .eq("id", update.id);
        if (orderUpdateError) {
          console.error(`Error updating order ${update.id} during route cancellation:`, orderUpdateError);
          // Log and continue, or collect errors to return
        }
      }
      console.log(`Updated ${orderUpdates.length} orders, unlinking from route ${route_id}.`);
    } else {
      console.log("No order_ids provided, skipping order updates for route cancellation.");
    }

    // (Optional) 4. Delete associated route_stops records
    // For now, we'll leave them for audit, or they can be cleaned up by a batch job.
    // If you want to delete them:
    // const { error: deleteStopsError } = await supabaseClient
    //   .from("route_stops")
    //   .delete()
    //   .eq("delivery_route_id", route_id);
    // if (deleteStopsError) console.error("Error deleting route_stops:", deleteStopsError);

    return new Response(JSON.stringify({ message: `Route ${route_id} cancelled successfully.` }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error in cancel-delivery-route function:", error);
    return new Response(JSON.stringify({ error: error.message || "An unexpected error occurred during route cancellation." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
