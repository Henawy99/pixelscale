import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Trigger Route Optimization Function Up!");

// Define interfaces for expected request body and stop/route data
interface OrderStop {
  order_id: string;
  latitude: number;
  longitude: number;
  customer_name?: string;
  customer_address?: string;
  requested_delivery_time?: string | null;
}

interface RouteLeg {
  duration_seconds: number;
  distance_meters: number;
}

interface OptimizedRouteResult {
  ordered_stops: OrderStop[]; // Includes store start/end
  total_duration_seconds: number;
  total_distance_meters: number;
  polyline_points: string; // Encoded polyline
  legs: RouteLeg[]; // Duration/distance for each leg
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { order_ids, driver_id, store_latitude, store_longitude } = await req.json();
    console.log("trigger-route-optimization received driver_id:", driver_id, "order_ids:", order_ids); // Added log

    if (!order_ids || !Array.isArray(order_ids) || order_ids.length === 0) {
      return new Response(JSON.stringify({ error: "Missing or invalid 'order_ids' array." }), {
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
    if (store_latitude == null || store_longitude == null) {
      return new Response(JSON.stringify({ error: "Missing 'store_latitude' or 'store_longitude'." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const supabaseClient = createClient( // This client operates under the user's authorization
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "", // Or SUPABASE_SERVICE_ROLE_KEY if all ops should be admin
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    );

    // Create a separate admin client for operations requiring service_role privileges
    const supabaseAdminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      // No specific auth header needed here, service role key grants full access
    );

    console.log(`Received request to optimize route for orders: ${order_ids.join(", ")} for driver: ${driver_id}`);

    // 1. Fetch order details from Supabase (can use user-context client if RLS allows user to see these orders)
    const { data: ordersData, error: ordersError } = await supabaseClient
      .from("orders")
      .select("id, brand_id, delivery_latitude, delivery_longitude, customer_name, customer_street, customer_postcode, customer_city, requested_delivery_time") // Added brand_id
      .in("id", order_ids);

    if (ordersError) throw ordersError;
    if (!ordersData || ordersData.length === 0) {
      return new Response(JSON.stringify({ error: "No orders found for the provided IDs or orders already routed." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404,
      });
    }
    
    // Filter out orders that might already have a delivery_route_id (should have been pre-filtered by client, but good to double check)
    // Also ensure they have coordinates
    const validOrdersForRouting = ordersData.filter(o => o.delivery_latitude != null && o.delivery_longitude != null);
    if (validOrdersForRouting.length !== order_ids.length) {
        console.warn("Some orders were filtered out due to missing coordinates or already being routed.");
        if (validOrdersForRouting.length === 0) {
            return new Response(JSON.stringify({ error: "None of the provided orders are valid for routing (missing coordinates or already routed)." }), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
                status: 400,
            });
        }
    }

    // Extract brand_id from the first valid order (assuming all orders in the batch share the same brand_id for the route)
    const brandIdForRoute = validOrdersForRouting[0]?.brand_id;
    if (!brandIdForRoute) {
        console.error("Could not determine brand_id for the route from the provided orders.", validOrdersForRouting);
        return new Response(JSON.stringify({ error: "Could not determine brand_id for the route." }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 400,
        });
    }
    console.log(`Using brand_id: ${brandIdForRoute} for the new route.`);


    // 2. Construct waypoints for the routing API
    const storeLocationString = `${store_latitude},${store_longitude}`;
    const waypoints: OrderStop[] = [
      { order_id: "STORE_START", latitude: store_latitude, longitude: store_longitude }, // Store start
      ...validOrdersForRouting.map(order => ({
        order_id: order.id,
        latitude: order.delivery_latitude!,
        longitude: order.delivery_longitude!,
        customer_name: order.customer_name,
        customer_address: `${order.customer_street || ''}, ${order.customer_postcode || ''} ${order.customer_city || ''}`.trim(),
        requested_delivery_time: order.requested_delivery_time
      })),
      { order_id: "STORE_END", latitude: store_latitude, longitude: store_longitude } // Store end
    ];
    
    console.log("Waypoints for optimization:", JSON.stringify(waypoints, null, 2));

    // 3. Call Route Optimization Service (Placeholder for Google Maps Directions API or similar)
    // const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY_SERVER");
    // if (!googleMapsApiKey) {
    //   console.error("GOOGLE_MAPS_API_KEY_SERVER environment variable not set.");
    //   return new Response(JSON.stringify({ error: "Routing service API key not configured." }), {
    //     headers: { ...corsHeaders, "Content-Type": "application/json" },
    //     status: 500,
    //   });
    // }
    //
    // 3. Call Google Maps Directions API
    const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY"); // Using existing env var name
    if (!googleMapsApiKey) {
      console.error("GOOGLE_MAPS_API_KEY environment variable not set.");
      return new Response(JSON.stringify({ error: "Routing service API key not configured." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      });
    }

    const origin = `${store_latitude},${store_longitude}`;
    const destination = origin; // Route ends back at the store

    // Customer waypoints (excluding store start/end which are handled by origin/destination)
    const customerWaypoints = waypoints.slice(1, -1).map(wp => `${wp.latitude},${wp.longitude}`).join('|');
    
    let directionsUrl = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin}&destination=${destination}&key=${googleMapsApiKey}`;
    if (customerWaypoints) {
      directionsUrl += `&waypoints=optimize:true|${customerWaypoints}`;
    }
    
    console.log("Requesting Directions API URL:", directionsUrl);
    const directionsResponse = await fetch(directionsUrl);
    if (!directionsResponse.ok) {
      const errorBody = await directionsResponse.text();
      console.error("Google Maps Directions API request failed:", directionsResponse.status, errorBody);
      return new Response(JSON.stringify({ error: `Directions API request failed: ${directionsResponse.statusText} - ${errorBody}` }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      });
    }

    const directionsResult = await directionsResponse.json();
    console.log("Google Maps Directions API Raw Result:", JSON.stringify(directionsResult, null, 2).substring(0, 1000) + "...");


    if (directionsResult.status !== "OK" || !directionsResult.routes || directionsResult.routes.length === 0) {
      console.error("Directions API did not return a valid route. Status:", directionsResult.status, "Error Message:", directionsResult.error_message);
      return new Response(JSON.stringify({ error: `Directions API error: ${directionsResult.status} - ${directionsResult.error_message || 'No route found.'}` }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400, // Or 500 if it's an API issue
      });
    }

    const route = directionsResult.routes[0];
    const overviewPolyline = route.overview_polyline.points;
    let totalDurationSeconds = 0;
    let totalDistanceMeters = 0;
    const legsFromApi: RouteLeg[] = [];

    route.legs.forEach((leg: any) => {
      totalDurationSeconds += leg.duration.value;
      totalDistanceMeters += leg.distance.value;
      legsFromApi.push({
        duration_seconds: leg.duration.value,
        distance_meters: leg.distance.value,
      });
    });
    
    // Reconstruct ordered_stops based on waypoint_order from API
    // The waypoints array initially was [STORE_START, customer1, customer2, ..., STORE_END]
    // The customerWaypoints sent to API were [customer1, customer2, ...]
    // route.waypoint_order gives the optimized permutation of the *customerWaypoints*
    
    const reorderedCustomerStops: OrderStop[] = [];
    if (route.waypoint_order && route.waypoint_order.length > 0) {
        route.waypoint_order.forEach((originalIndex: number) => {
            reorderedCustomerStops.push(waypoints[originalIndex + 1]); // +1 to skip STORE_START
        });
    } else { // If only one customer stop, waypoint_order might be empty
        if (waypoints.length === 3) { // STORE_START, CUSTOMER, STORE_END
            reorderedCustomerStops.push(waypoints[1]);
        }
    }

    const finalOrderedStops: OrderStop[] = [
        waypoints[0], // STORE_START
        ...reorderedCustomerStops,
        waypoints[waypoints.length - 1] // STORE_END
    ];
    
    const optimizedRouteResult: OptimizedRouteResult = {
      ordered_stops: finalOrderedStops,
      total_duration_seconds: totalDurationSeconds,
      total_distance_meters: totalDistanceMeters,
      polyline_points: overviewPolyline,
      legs: legsFromApi,
    };
    
    console.log("Processed Optimized Route Result:", JSON.stringify(optimizedRouteResult, null, 2));

    // 4. Constraint Check (1-hour limit) - This can be adjusted or made more dynamic
    const MAX_ROUTE_DURATION_SECONDS = 3600; // 1 hour
    if (optimizedRouteResult.total_duration_seconds > MAX_ROUTE_DURATION_SECONDS) {
      return new Response(JSON.stringify({ error: `Route exceeds 1-hour limit (${(optimizedRouteResult.total_duration_seconds / 60).toFixed(0)} mins). Select fewer orders.` }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    // 5. Database Transactions (Ideally, use Supabase transactions if available/easy in Deno edge functions)
    // For simplicity here, performing sequential operations with error checks.

    // 5.1 Create delivery_routes record (use admin client to ensure it can be created)
    const { data: routeData, error: routeError } = await supabaseAdminClient
      .from("delivery_routes")
      .insert({
        assigned_driver_id: driver_id,
        brand_id: brandIdForRoute, // Added brand_id
        status: "assigned", // Or 'in_progress'
        total_estimated_duration_seconds: optimizedRouteResult.total_duration_seconds,
        total_estimated_distance_meters: optimizedRouteResult.total_distance_meters,
        polyline_points: optimizedRouteResult.polyline_points,
        store_latitude: store_latitude,
        store_longitude: store_longitude,
        // created_at is handled by default value in DB
      })
      .select()
      .single();

    if (routeError) throw routeError;
    if (!routeData) throw new Error("Failed to create delivery route record.");
    const newRouteId = routeData.id;
    console.log("Created delivery_routes record:", newRouteId);

    // 5.2 Create route_stops records
    // Define the type for a route stop based on your table schema
    type RouteStopInsert = {
      delivery_route_id: string;
      order_id: string | null;
      type: "store" | "customer_delivery"; // Aligned with DB constraint
      sequence_number: number;
      latitude: number;
      longitude: number;
      customer_name?: string | null;
      customer_address?: string | null;
      estimated_arrival_time: string;
      status: string;
      estimated_travel_time_to_next_stop_seconds: number; // Changed to non-nullable
    };

    const routeStopsToInsert: RouteStopInsert[] = [];
    let cumulativeTimeSeconds = 0;
    const routeStartTime = new Date(); // Or from routeData.created_at if fetched precisely

    for (let i = 0; i < optimizedRouteResult.ordered_stops.length; i++) {
      const stop = optimizedRouteResult.ordered_stops[i];
      const leg = i > 0 ? optimizedRouteResult.legs[i-1] : { duration_seconds: 0 }; // First stop has 0 duration from start
      if (i > 0) cumulativeTimeSeconds += leg.duration_seconds;
      
      const estimatedArrivalTime = new Date(routeStartTime.getTime() + cumulativeTimeSeconds * 1000);

      // Duration to the *next* stop. 0 for the last stop as it has no "next" leg.
      const travelTimeToNextStopSeconds = (i < optimizedRouteResult.legs.length) 
                                          ? optimizedRouteResult.legs[i].duration_seconds 
                                          : 0; 

      routeStopsToInsert.push({
        delivery_route_id: newRouteId,
        order_id: (stop.order_id.startsWith("STORE_") ? null : stop.order_id),
        type: (stop.order_id.startsWith("STORE_") ? "store" : "customer_delivery") as "store" | "customer_delivery", // Aligned with DB constraint
        sequence_number: i,
        latitude: stop.latitude,
        longitude: stop.longitude,
        customer_name: stop.customer_name,
        customer_address: stop.customer_address,
        estimated_arrival_time: estimatedArrivalTime.toISOString(),
        status: "pending",
        estimated_travel_time_to_next_stop_seconds: travelTimeToNextStopSeconds,
      });
    }
    
    const { error: stopsError } = await supabaseAdminClient // Use admin client
        .from("route_stops")
        .insert(routeStopsToInsert);
    if (stopsError) throw stopsError;
    console.log(`Inserted ${routeStopsToInsert.length} route_stops records.`);

    // 5.3 Update orders table (use admin client)
    const orderUpdates = validOrdersForRouting.map(order => ({
      id: order.id,
      delivery_route_id: newRouteId,
      delivery_status: "assigned_to_route", // Or 'out_for_delivery'
    }));

    for (const update of orderUpdates) {
        const { error: orderUpdateError } = await supabaseAdminClient // Use admin client
            .from("orders")
            .update({ delivery_route_id: update.delivery_route_id, delivery_status: update.delivery_status })
            .eq("id", update.id);
        if (orderUpdateError) console.error(`Error updating order ${update.id}:`, orderUpdateError); // Log and continue or throw
    }
    console.log(`Updated ${orderUpdates.length} orders.`);


    // 5.4 Update drivers table (use admin client)
    const { error: driverUpdateError } = await supabaseAdminClient // Use admin client
      .from("drivers")
      .update({ current_route_id: newRouteId })
      .eq("id", driver_id);
    if (driverUpdateError) throw driverUpdateError;
    console.log(`Updated driver ${driver_id} with new route ${newRouteId}.`);


    return new Response(JSON.stringify({ message: "Route created successfully!", route_id: newRouteId }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error in trigger-route-optimization:", error);
    return new Response(JSON.stringify({ error: error.message || "An unexpected error occurred." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
