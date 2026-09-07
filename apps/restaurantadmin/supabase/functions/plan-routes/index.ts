// supabase/functions/plan-routes/index.ts
// HTTP entry point for the delivery route planner.
// Loads data from Supabase, runs the solver, writes results atomically.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";
import { solve, evaluatePlan } from "./solver.ts";
import { buildTravelTimeMatrix } from "./travel_time.ts";
import type {
  PlannerOrder,
  PlannerDriver,
  PlannerSettings,
  LatLng,
  PlannedRoute,
  PlanResult,
} from "./types.ts";

console.log("Plan Routes Function Up!");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // Parse trigger reason from body (optional)
    let triggerReason = "manual";
    let brandId: string | null = null;
    try {
      const body = await req.json();
      triggerReason = body.trigger_reason ?? "manual";
      brandId = body.brand_id ?? null;
    } catch {
      // No body or invalid JSON — that's fine
    }

    const now = new Date();

    // 1. Load delivery_settings
    let settingsQuery = supabase.from("delivery_settings").select("*");
    if (brandId) {
      settingsQuery = settingsQuery.eq("brand_id", brandId);
    }
    let { data: settingsRows, error: settingsErr } = await settingsQuery.limit(1).maybeSingle();
    if (!settingsRows) {
      // Fallback to primary delivery_settings if brand specific not found
      const { data: fallbackRows } = await supabase.from("delivery_settings").select("*").limit(1).maybeSingle();
      settingsRows = fallbackRows;
    }
    if (!settingsRows) {
      console.error("Failed to load delivery_settings:", settingsErr);
      return new Response(
        JSON.stringify({ error: "No delivery_settings found. Create one first." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    brandId = brandId ?? settingsRows.brand_id;

    const settings: PlannerSettings = {
      lateWeight: Number(settingsRows.late_weight),
      earlyWeight: Number(settingsRows.early_weight),
      driveWeight: Number(settingsRows.drive_weight),
      idleWeight: Number(settingsRows.idle_weight),
      unassignedWeight: Number(settingsRows.unassigned_weight),
      handoverTimeSecs: settingsRows.handover_time_secs,
      earlyGraceSecs: settingsRows.early_grace_secs,
      preorderEarlyGraceSecs: settingsRows.preorder_early_grace_secs,
      bundlingWaitSecs: settingsRows.bundling_wait_secs,
      planningHorizonSecs: settingsRows.planning_horizon_secs,
      citySpeedKmh: Number(settingsRows.city_speed_kmh),
      maxStopsPerRoute: settingsRows.max_stops_per_route ?? 999,
      maxRouteDurationSecs: settingsRows.max_route_duration_secs,
      shiftEndGraceMinutes: settingsRows.shift_end_grace_minutes ?? 15,
      solverTimeLimitMs: settingsRows.solver_time_limit_ms,
      exhaustiveThreshold: settingsRows.exhaustive_threshold,
      storeLocation: {
        lat: settingsRows.store_latitude,
        lng: settingsRows.store_longitude,
      },
    };

    // 2. Load eligible orders
    const horizonCutoff = new Date(
      now.getTime() + settings.planningHorizonSecs * 1000
    );

    const { data: ordersData, error: ordersErr } = await supabase
      .from("orders")
      .select(
        "id, brand_id, delivery_latitude, delivery_longitude, customer_name, customer_street, customer_postcode, customer_city, customer_phone, delivery_notes, estimated_delivery_time, estimated_pickup_time, requested_delivery_time, delivery_status, delivery_route_id, assigned_driver_id, delivery_route_sequence, order_type_name, payment_method, total_price, fulfillment_type"
      )
      .eq("brand_id", brandId)
      .eq("fulfillment_type", "delivery")
      .in("delivery_status", [
        "preparing",
        "ready_to_deliver",
        "assigned_to_route",
        "out_for_delivery",
      ])
      .not("delivery_latitude", "is", null)
      .not("delivery_longitude", "is", null);

    if (ordersErr) throw ordersErr;

    // Also fetch orders in prep that will be ready within the planning horizon
    const { data: prepOrders, error: prepErr } = await supabase
      .from("orders")
      .select(
        "id, brand_id, delivery_latitude, delivery_longitude, customer_name, customer_street, customer_postcode, customer_city, customer_phone, delivery_notes, estimated_delivery_time, estimated_pickup_time, requested_delivery_time, delivery_status, delivery_route_id, assigned_driver_id, delivery_route_sequence, order_type_name, payment_method, total_price, fulfillment_type"
      )
      .eq("brand_id", brandId)
      .eq("fulfillment_type", "delivery")
      .is("delivery_status", null)
      .not("delivery_latitude", "is", null)
      .not("delivery_longitude", "is", null)
      .lte("estimated_pickup_time", horizonCutoff.toISOString());

    if (!prepErr && prepOrders) {
      ordersData?.push(...prepOrders);
    }

    if (!ordersData || ordersData.length === 0) {
      console.log("No eligible orders to plan.");
      return new Response(
        JSON.stringify({ message: "No eligible orders.", plan_version: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Fetch existing driver pins from route_stops
    const orderIds = ordersData.map((o: any) => o.id);
    const { data: pinsData } = await supabase
      .from("route_stops")
      .select("order_id, pinned_driver_id")
      .in("order_id", orderIds)
      .not("pinned_driver_id", "is", null);

    const pinMap = new Map<string, string>();
    if (pinsData) {
      for (const p of pinsData) {
        if (p.order_id && p.pinned_driver_id) {
          pinMap.set(p.order_id, p.pinned_driver_id);
        }
      }
    }

    // Convert to PlannerOrder
    const orders: PlannerOrder[] = ordersData.map((o: any) => ({
      id: o.id,
      brandId: o.brand_id,
      location: { lat: o.delivery_latitude, lng: o.delivery_longitude },
      customerName: o.customer_name,
      customerAddress: [o.customer_street, o.customer_postcode, o.customer_city]
        .filter(Boolean)
        .join(", "),
      customerPhone: o.customer_phone,
      deliveryNotes: o.delivery_notes,
      targetDeliveryTime: o.estimated_delivery_time
        ? new Date(o.estimated_delivery_time)
        : new Date(now.getTime() + 30 * 60000), // Default 30 min if missing
      estimatedPickupTime: o.estimated_pickup_time
        ? new Date(o.estimated_pickup_time)
        : null,
      requestedDeliveryTime: o.requested_delivery_time
        ? new Date(o.requested_delivery_time)
        : null,
      deliveryStatus: o.delivery_status,
      currentRouteId: o.delivery_route_id,
      currentDriverId: o.assigned_driver_id,
      currentSequence: o.delivery_route_sequence,
      orderTypeName: o.order_type_name,
      paymentMethod: o.payment_method,
      totalPrice: o.total_price ?? 0,
      pinnedDriverId: pinMap.get(o.id) ?? null,
    }));

    // 3. Load available drivers (on-shift employees)
    const { data: driversData, error: driversErr } = await supabase
      .from("available_drivers")
      .select(
        "id, employee_id, name, is_online, current_latitude, current_longitude, current_route_id, projected_return_at, available_at, shift_end_at"
      );

    if (driversErr) throw driversErr;
    if (!driversData || driversData.length === 0) {
      console.log("No drivers on shift available.");
      return new Response(
        JSON.stringify({ message: "No drivers on shift available.", plan_version: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const drivers: PlannerDriver[] = driversData.map((d: any) => ({
      id: d.id,
      name: d.name,
      isOnline: d.is_online ?? true,
      currentLocation:
        d.current_latitude && d.current_longitude
          ? { lat: d.current_latitude, lng: d.current_longitude }
          : null,
      currentRouteId: d.current_route_id,
      projectedReturnAt: d.projected_return_at
        ? new Date(d.projected_return_at)
        : null,
      availableAt: d.available_at ? new Date(d.available_at) : null,
      shiftEndAt: d.shift_end_at ? new Date(d.shift_end_at) : null,
    }));

    // 4. Build travel time matrix
    //    Index 0 = depot (restaurant), then one index per order
    const locations: LatLng[] = [
      settings.storeLocation,
      ...orders.map((o) => o.location),
    ];

    console.log(
      `Building travel time matrix for ${locations.length} locations...`
    );
    const matrix = await buildTravelTimeMatrix(locations, settings, supabase);

    // 5. Get current plan version
    const { data: latestLog } = await supabase
      .from("plan_log")
      .select("plan_version")
      .eq("brand_id", brandId)
      .order("plan_version", { ascending: false })
      .limit(1)
      .maybeSingle();

    const currentPlanVersion = latestLog?.plan_version ?? 0;

    // 6. Run solver
    console.log("Running solver...");
    const result: PlanResult = solve(
      orders,
      drivers,
      matrix,
      settings,
      now,
      currentPlanVersion
    );

    console.log(
      `Solver finished in ${result.solverTimeMs}ms. Plan version: ${result.planVersion}. ` +
      `Routes: ${result.routes.length}. Unassigned: ${result.unassignedOrderIds.length}. ` +
      `Cost: ${result.costBreakdown.totalCost.toFixed(2)}`
    );

    // 7. Write results atomically

    // 7a. Cancel existing assigned (not in_progress) routes for this brand
    const { data: existingRoutes } = await supabase
      .from("delivery_routes")
      .select("id")
      .eq("brand_id", brandId)
      .eq("status", "assigned");

    if (existingRoutes && existingRoutes.length > 0) {
      const routeIds = existingRoutes.map((r: any) => r.id);
      await supabase
        .from("delivery_routes")
        .update({ status: "replaced" })
        .in("id", routeIds);

      // Clear old route_stops
      await supabase
        .from("route_stops")
        .delete()
        .in("delivery_route_id", routeIds);

      // Unlink orders from old routes
      await supabase
        .from("orders")
        .update({
          delivery_route_id: null,
          assigned_driver_id: null,
          delivery_route_sequence: null,
          planned_arrival_at: null,
          delivery_status: "ready_to_deliver",
        })
        .in("delivery_route_id", routeIds)
        .eq("delivery_status", "assigned_to_route");
    }

    // 7b. Create new routes and stops
    for (const route of result.routes) {
      // Create delivery_routes record
      const { data: routeRecord, error: routeErr } = await supabase
        .from("delivery_routes")
        .insert({
          assigned_driver_id: route.driverId,
          brand_id: brandId,
          status: "assigned",
          total_estimated_duration_seconds:
            (route.plannedReturnAt.getTime() - route.plannedDepartureAt.getTime()) / 1000,
          total_estimated_distance_meters: route.totalDistanceMeters,
          store_latitude: settings.storeLocation.lat,
          store_longitude: settings.storeLocation.lng,
          plan_version: result.planVersion,
          planned_departure_at: route.plannedDepartureAt.toISOString(),
          planned_return_at: route.plannedReturnAt.toISOString(),
        })
        .select("id")
        .single();

      if (routeErr || !routeRecord) {
        console.error("Failed to create delivery route:", routeErr);
        continue;
      }

      const routeId = routeRecord.id;

      // Create route_stops
      const stopsToInsert = route.stops.map((stop, idx) => ({
        delivery_route_id: routeId,
        order_id: stop.orderId,
        type: stop.type === "store" ? "store" : "customer_delivery",
        sequence_number: idx,
        latitude: stop.location.lat,
        longitude: stop.location.lng,
        customer_name: stop.customerName,
        customer_address: stop.customerAddress,
        estimated_arrival_time: stop.plannedArrivalAt.toISOString(),
        planned_arrival_at: stop.plannedArrivalAt.toISOString(),
        status: "pending",
        pinned_driver_id: stop.orderId ? pinMap.get(stop.orderId) ?? null : null,
        estimated_travel_time_to_next_stop_seconds:
          idx < route.stops.length - 1
            ? matrix[stop.matrixIndex][route.stops[idx + 1].matrixIndex]
                .durationSeconds
            : 0,
      }));

      const { error: stopsErr } = await supabase
        .from("route_stops")
        .insert(stopsToInsert);

      if (stopsErr) {
        console.error("Failed to insert route stops:", stopsErr);
      }

      // Update orders with route assignment
      for (let i = 0; i < route.stops.length; i++) {
        const stop = route.stops[i];
        if (!stop.orderId) continue;

        const { error: orderErr } = await supabase
          .from("orders")
          .update({
            assigned_driver_id: route.driverId,
            delivery_route_id: routeId,
            delivery_route_sequence: i,
            delivery_status: "assigned_to_route",
            planned_arrival_at: stop.plannedArrivalAt.toISOString(),
            is_unassignable: false,
            unassignable_reason: null,
          })
          .eq("id", stop.orderId);

        if (orderErr) {
          console.error(`Failed to update order ${stop.orderId}:`, orderErr);
        }
      }

      // Update driver's projected return
      await supabase
        .from("drivers")
        .update({
          current_route_id: routeId,
          projected_return_at: route.plannedReturnAt.toISOString(),
        })
        .eq("id", route.driverId);
    }

    // 7c. Mark unassigned orders visibly if nobody on shift can take them
    for (const unassignedId of result.unassignedOrderIds) {
      await supabase
        .from("orders")
        .update({
          is_unassignable: true,
          unassignable_reason:
            "No available driver on shift can reach customer before cutoff or shift end",
        })
        .eq("id", unassignedId)
        .neq("delivery_status", "out_for_delivery");
    }

    // 7d. Log the plan
    await supabase.from("plan_log").insert({
      brand_id: brandId,
      plan_version: result.planVersion,
      trigger_reason: triggerReason,
      cost_breakdown: result.costBreakdown,
      plan_snapshot: {
        routes: result.routes.map((r) => ({
          driver_id: r.driverId,
          stops: r.stops.map((s) => ({
            order_id: s.orderId,
            type: s.type,
            planned_arrival: s.plannedArrivalAt.toISOString(),
            target_time: s.targetTime?.toISOString(),
          })),
          departure: r.plannedDepartureAt.toISOString(),
          return: r.plannedReturnAt.toISOString(),
        })),
        unassigned: result.unassignedOrderIds,
      },
      solver_time_ms: result.solverTimeMs,
    });

    console.log(`Plan v${result.planVersion} written successfully.`);

    return new Response(
      JSON.stringify({
        message: "Plan created successfully.",
        plan_version: result.planVersion,
        routes_created: result.routes.length,
        unassigned_orders: result.unassignedOrderIds.length,
        cost: result.costBreakdown.totalCost,
        solver_time_ms: result.solverTimeMs,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error in plan-routes:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Unknown error" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
