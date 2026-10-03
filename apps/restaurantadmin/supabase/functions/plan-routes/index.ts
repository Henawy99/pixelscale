// supabase/functions/plan-routes/index.ts
// HTTP entry point for the delivery route planner.
//
// One plan covers every brand: all brands are cooked in the same kitchen and delivered by
// the same drivers. Each run: load open delivery orders + drivers online in the app →
// travel-time matrix → solver → apply_delivery_plan() (atomic, keeps route ids stable) →
// push notification to drivers whose next tour changed.
//
// Runs are serialised with planner_try_lock/planner_release: triggers that arrive while a
// run is in progress collapse into a single follow-up run.
//
// Body (all optional): { trigger_reason, dry_run, complete_route_id }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";
import { sendToTokens } from "../_shared/fcm.ts";
import { solve } from "./solver.ts";
import { buildTravelTimeMatrix, haversineFallback } from "./travel_time.ts";
import type { PlannerOrder, PlannerDriver, PlannerSettings, LatLng, PlanResult, TravelTimeMatrix } from "./types.ts";

console.log("Plan Routes Function Up!");

const MAX_RUNS = 4;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

class StalePlanError extends Error {}

// Geocode address using Google Maps API with Nominatim fallback
async function geocodeAddress(
  street?: string | null,
  postcode?: string | null,
  city?: string | null
): Promise<{ lat: number; lng: number } | null> {
  if (!street || !street.trim()) return null;
  const q = [street, postcode, city || "Salzburg", "Austria"].filter(Boolean).join(", ");

  const googleKey = Deno.env.get("GOOGLE_GEOCODING_API_KEY");
  if (googleKey) {
    try {
      const res = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(q)}&key=${googleKey}`);
      const data = await res.json();
      const loc = data.status === "OK" ? data.results?.[0]?.geometry?.location : null;
      if (loc && typeof loc.lat === "number" && typeof loc.lng === "number") return { lat: loc.lat, lng: loc.lng };
    } catch (err) {
      console.warn("[geocodeAddress] Google Geocoding failed:", err);
    }
  }

  try {
    const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=1`, {
      headers: { "User-Agent": "restaurantadmin-planner/1.0" },
    });
    if (res.ok) {
      const arr = await res.json();
      const lat = Number(arr?.[0]?.lat);
      const lng = Number(arr?.[0]?.lon);
      if (!isNaN(lat) && !isNaN(lng)) return { lat, lng };
    }
  } catch (err) {
    console.warn("[geocodeAddress] Nominatim failed:", err);
  }
  return null;
}

function toSettings(row: any): PlannerSettings & { defaultPrepSecs: number; staleOrderMins: number } {
  return {
    lateWeight: Number(row.late_weight),
    earlyWeight: Number(row.early_weight),
    driveWeight: Number(row.drive_weight),
    idleWeight: Number(row.idle_weight),
    unassignedWeight: Number(row.unassigned_weight),
    serviceWeight: Number(row.service_weight ?? 0.5),
    reassignWeight: Number(row.reassign_weight ?? 30),
    handoverTimeSecs: row.handover_time_secs,
    earlyGraceSecs: row.early_grace_secs,
    preorderEarlyGraceSecs: row.preorder_early_grace_secs,
    bundlingWaitSecs: row.bundling_wait_secs,
    planningHorizonSecs: row.planning_horizon_secs,
    safetyBufferSecs: row.safety_buffer_secs ?? 120,
    citySpeedKmh: Number(row.city_speed_kmh),
    maxStopsPerRoute: row.max_stops_per_route ?? 999,
    maxRouteDurationSecs: row.max_route_duration_secs,
    shiftEndGraceMinutes: row.shift_end_grace_minutes ?? 15,
    solverTimeLimitMs: row.solver_time_limit_ms,
    exhaustiveThreshold: row.exhaustive_threshold,
    storeLocation: { lat: row.store_latitude, lng: row.store_longitude },
    defaultPrepSecs: row.default_prep_secs ?? 900,
    staleOrderMins: row.stale_order_mins ?? 60,
  };
}

/** Route stops still to drive for a tour that is on the road. */
interface LiveRoute {
  id: string;
  driverId: string;
  remaining: LatLng[];
}

/**
 * When a driver who is out on a tour will be back at the restaurant.
 * Fresh GPS: drive from the current position through the undelivered stops and back.
 * No fresh GPS: the same legs from the next stop, but never earlier than the plan said.
 */
function returnEta(
  live: LiveRoute,
  driverRow: any,
  settings: PlannerSettings,
  now: Date,
  plannedReturn: Date | null
): Date {
  const store = settings.storeLocation;
  const gps =
    driverRow?.last_seen_at &&
    driverRow.current_latitude != null &&
    now.getTime() - new Date(driverRow.last_seen_at).getTime() < 5 * 60_000
      ? { lat: driverRow.current_latitude, lng: driverRow.current_longitude }
      : null;
  let from: LatLng = gps ?? live.remaining[0] ?? store;
  let t = now.getTime();
  for (const stop of live.remaining) {
    t += haversineFallback(from, stop, settings.citySpeedKmh).durationSeconds * 1000 + settings.handoverTimeSecs * 1000;
    from = stop;
  }
  t += haversineFallback(from, store, settings.citySpeedKmh).durationSeconds * 1000;
  if (gps || !plannedReturn) return new Date(t);
  return new Date(Math.max(t, Math.min(plannedReturn.getTime(), t + 20 * 60_000)));
}

const fmtTime = (d: Date) =>
  new Intl.DateTimeFormat("de-AT", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Vienna" }).format(d);

// ============================================================
// ONE PLANNING RUN
// ============================================================

async function planOnce(
  supabase: SupabaseClient,
  opts: { triggerReason: string; dryRun: boolean }
) {
  const { triggerReason, dryRun } = opts;
  const now = new Date();

  // 1. Settings (one row drives the whole kitchen).
  const { data: settingsRow, error: settingsErr } = await supabase
    .from("delivery_settings")
    .select("*")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (settingsErr || !settingsRow) throw new Error(`No delivery_settings row: ${settingsErr?.message ?? "missing"}`);
  const settings = toSettings(settingsRow);

  // 2. Open delivery orders across all brands.
  const q = supabase
    .from("orders")
    .select(
      "id, brand_id, created_at, delivery_latitude, delivery_longitude, customer_name, customer_street, customer_postcode, customer_city, customer_phone, delivery_notes, estimated_delivery_time, estimated_pickup_time, requested_delivery_time, food_ready_at, status, delivery_status, delivery_route_id, assigned_driver_id, delivery_route_sequence, order_type_name, payment_method, total_price, transport_type:platform_raw_data->transport->>type"
    )
    .eq("fulfillment_type", "delivery")
    .not("status", "in", '("cancelled","delivered","completed","delivering","pending_payment")')
    .eq("is_demo", false)
    .gte("created_at", new Date(now.getTime() - 6 * 3600_000).toISOString());
  const { data: rawOrders, error: ordersErr } = await q;
  if (ordersErr) throw ordersErr;

  // Orders on a tour that is already on the road are the driver's, whatever their status says.
  const { data: onRoad } = await supabase
    .from("delivery_routes")
    .select("id")
    .eq("status", "in_progress")
    .eq("is_demo", false);
  const onRoadIds = new Set((onRoad ?? []).map((r: any) => r.id));

  const staleBefore = now.getTime() - settings.staleOrderMins * 60_000;
  const open = (rawOrders ?? []).filter((o: any) => {
    const ds = (o.delivery_status ?? "").toLowerCase();
    if (ds === "out_for_delivery" || ds === "delivered") return false;
    if (o.delivery_route_id && onRoadIds.has(o.delivery_route_id)) return false;
    // Foodora rider picks it up — not ours to deliver.
    if (o.transport_type === "PICKUP_LOGISTICS") return false;
    if (ds === "assigned_to_route") return true;
    // Promised long ago and never dispatched through the app: handled outside the system.
    const target = new Date(o.requested_delivery_time ?? o.estimated_delivery_time ?? o.created_at).getTime();
    return target >= staleBefore;
  });

  for (const o of open) {
    if ((o.delivery_latitude == null || o.delivery_longitude == null) && o.customer_street) {
      const geo = await geocodeAddress(o.customer_street, o.customer_postcode, o.customer_city);
      if (geo) {
        o.delivery_latitude = geo.lat;
        o.delivery_longitude = geo.lng;
        if (!dryRun) {
          await supabase.from("orders").update({ delivery_latitude: geo.lat, delivery_longitude: geo.lng }).eq("id", o.id);
        }
      }
    }
  }
  const noGeo = open.filter((o: any) => o.delivery_latitude == null || o.delivery_longitude == null);
  const ordersData = open.filter((o: any) => o.delivery_latitude != null && o.delivery_longitude != null);

  // 3. Manual pins set from the dispatch screen.
  const pinMap = new Map<string, string>();
  if (ordersData.length > 0) {
    const { data: pins } = await supabase
      .from("route_stops")
      .select("order_id, pinned_driver_id")
      .in("order_id", ordersData.map((o: any) => o.id))
      .not("pinned_driver_id", "is", null);
    for (const pin of pins ?? []) pinMap.set(pin.order_id, pin.pinned_driver_id);
  }

  // 4. Drivers.
  const { data: allDriverRows } = await supabase
    .from("drivers")
    .select("id, name, is_demo, is_online, last_seen_at, current_latitude, current_longitude, fcm_token");
  const driverRowById = new Map((allDriverRows ?? []).map((d: any) => [d.id, d]));

  const { data: availableData, error: availableErr } = await supabase
    .from("available_drivers")
    .select("id, name, shift_end_at");
  if (availableErr) throw availableErr;
  const availableRows: any[] = (availableData ?? []).filter((d: any) => !driverRowById.get(d.id)?.is_demo);

  // Tours already on the road decide when each driver is back.
  const liveByDriver = new Map<string, { live: LiveRoute; plannedReturn: Date | null }>();
  if (availableRows.length > 0) {
    const { data: liveRoutes } = await supabase
      .from("delivery_routes")
      .select("id, assigned_driver_id, planned_return_at, route_stops(type, status, sequence_number, latitude, longitude)")
      .eq("status", "in_progress")
      .eq("is_demo", false)
      .in("assigned_driver_id", availableRows.map((d) => d.id));
    for (const r of liveRoutes ?? []) {
      const remaining = ((r as any).route_stops ?? [])
        .filter((s: any) => s.type === "customer_delivery" && !["completed", "skipped", "failed"].includes(s.status))
        .sort((a: any, b: any) => a.sequence_number - b.sequence_number)
        .map((s: any) => ({ lat: s.latitude, lng: s.longitude }));
      liveByDriver.set(r.assigned_driver_id, {
        live: { id: r.id, driverId: r.assigned_driver_id, remaining },
        plannedReturn: r.planned_return_at ? new Date(r.planned_return_at) : null,
      });
    }
  }

  const drivers: PlannerDriver[] = availableRows.map((d: any) => {
    const row = driverRowById.get(d.id);
    const live = liveByDriver.get(d.id);
    return {
      id: d.id,
      name: d.name,
      isOnline: true,
      currentLocation: row?.current_latitude != null ? { lat: row.current_latitude, lng: row.current_longitude } : null,
      currentRouteId: live?.live.id ?? null,
      projectedReturnAt: null,
      availableAt: live ? returnEta(live.live, row, settings, now, live.plannedReturn) : now,
      shiftEndAt: d.shift_end_at ? new Date(d.shift_end_at) : null,
    };
  });

  // 5. Planner orders.
  const prepMs = settings.defaultPrepSecs * 1000;
  const orders: PlannerOrder[] = ordersData.map((o: any) => {
    const created = new Date(o.created_at).getTime();
    const requested = o.requested_delivery_time ? new Date(o.requested_delivery_time) : null;
    let readyAt: Date;
    if (o.food_ready_at) readyAt = new Date(o.food_ready_at);
    else if (o.estimated_pickup_time) readyAt = new Date(o.estimated_pickup_time);
    else if (requested) readyAt = new Date(Math.max(created + prepMs, requested.getTime() - 30 * 60_000));
    else readyAt = new Date(created + prepMs);

    return {
      id: o.id,
      brandId: o.brand_id,
      location: { lat: o.delivery_latitude, lng: o.delivery_longitude },
      customerName: o.customer_name,
      customerAddress: [o.customer_street, o.customer_postcode, o.customer_city].filter(Boolean).join(", "),
      customerPhone: o.customer_phone,
      deliveryNotes: o.delivery_notes,
      targetDeliveryTime: o.estimated_delivery_time ? new Date(o.estimated_delivery_time) : new Date(created + 60 * 60_000),
      estimatedPickupTime: o.estimated_pickup_time ? new Date(o.estimated_pickup_time) : null,
      requestedDeliveryTime: requested,
      readyAt,
      deliveryStatus: o.delivery_status,
      currentRouteId: o.delivery_route_id,
      currentDriverId: o.assigned_driver_id,
      currentSequence: o.delivery_route_sequence,
      orderTypeName: o.order_type_name,
      paymentMethod: o.payment_method,
      totalPrice: o.total_price ?? 0,
      pinnedDriverId: pinMap.get(o.id) ?? null,
    };
  });

  // 6. Travel times (only when there is something to plan).
  const locations: LatLng[] = [settings.storeLocation, ...orders.map((o) => o.location)];
  const matrix: TravelTimeMatrix =
    orders.length > 0 && drivers.length > 0
      ? await buildTravelTimeMatrix(locations, settings, supabase)
      : locations.map(() => locations.map(() => ({ durationSeconds: 0, distanceMeters: 0 })));

  // 7. Solve.
  const { data: latestLog } = await supabase
    .from("plan_log")
    .select("plan_version")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  const result: PlanResult = solve(orders, drivers, matrix, settings, now, latestLog?.plan_version ?? 0);

  console.log(
    `[plan-routes] ${triggerReason}: ${orders.length} orders, ${drivers.length} drivers → ` +
      `${result.trips.length} tours (${result.routes.length} committed), ${result.unassignedOrderIds.length} unassigned, ` +
      `${result.method} ${result.solverTimeMs}ms, cost ${result.costBreakdown.totalCost.toFixed(1)}`
  );

  // 8. Build the atomic write.
  const orderById = new Map(orders.map((o) => [o.id, o]));
  const indexById = new Map(orders.map((o, i) => [o.id, i + 1]));
  const committed = new Set(result.routes.flatMap((r) => r.stops.map((s) => s.orderId).filter(Boolean)));
  const unassigned = new Set(result.unassignedOrderIds);
  const laterArrival = new Map<string, Date>();
  for (const t of result.trips) {
    if (t.tripIndex === 0) continue;
    for (const s of t.stops) if (s.orderId) laterArrival.set(s.orderId, s.plannedArrivalAt);
  }

  const routesPayload = result.routes.map((r) => {
    const firstOrder = orderById.get(r.stops.find((s) => s.orderId)!.orderId!)!;
    return {
      driver_id: r.driverId,
      brand_id: firstOrder.brandId,
      planned_departure_at: r.plannedDepartureAt.toISOString(),
      planned_return_at: r.plannedReturnAt.toISOString(),
      total_duration_secs: Math.round((r.plannedReturnAt.getTime() - r.plannedDepartureAt.getTime()) / 1000),
      total_distance_m: r.totalDistanceMeters,
      store_lat: settings.storeLocation.lat,
      store_lng: settings.storeLocation.lng,
      stops: r.stops.map((s, idx) => {
        const next = r.stops[idx + 1];
        return {
          order_id: s.orderId,
          type: s.type,
          lat: s.location.lat,
          lng: s.location.lng,
          customer_name: s.customerName,
          customer_address: s.customerAddress,
          planned_arrival_at: s.plannedArrivalAt.toISOString(),
          target_delivery_time: s.targetTime?.toISOString() ?? null,
          travel_to_next_secs: next ? matrix[s.matrixIndex][next.matrixIndex].durationSeconds : 0,
          service_secs: s.type === "customer_delivery" ? settings.handoverTimeSecs : 0,
          pinned_driver_id: s.orderId ? pinMap.get(s.orderId) ?? null : null,
        };
      }),
    };
  });

  // 'ready_to_deliver' only when the kitchen said so (the order board treats it as "delivering");
  // the planner's own prep-time estimate never sets it.
  const kitchenReady = new Set(
    ordersData
      .filter((o: any) => o.food_ready_at && new Date(o.food_ready_at).getTime() <= now.getTime())
      .map((o: any) => o.id)
  );
  const waiting = orders
    .filter((o) => !committed.has(o.id) && !unassigned.has(o.id))
    .map((o) => ({
      order_id: o.id,
      delivery_status: kitchenReady.has(o.id) ? "ready_to_deliver" : "preparing",
      planned_arrival_at: laterArrival.get(o.id)?.toISOString() ?? null,
    }));

  const noDriverReason = "No driver is online in the driver app";
  const unassignable = [
    ...result.unassignedOrderIds.map((id) => ({
      order_id: id,
      reason: drivers.length === 0 ? noDriverReason : "No online driver can deliver it before their shift ends",
    })),
    ...noGeo.map((o: any) => ({ order_id: o.id, reason: "Address could not be located on the map" })),
  ];

  const payload = {
    is_demo: false,
    plan_version: result.planVersion,
    trigger_reason: triggerReason,
    brand_id: settingsRow.brand_id,
    planned_at: now.toISOString(),
    solver_time_ms: result.solverTimeMs,
    cost_breakdown: result.costBreakdown,
    plan_snapshot: {
      method: result.method,
      drivers: drivers.map((d) => ({ id: d.id, name: d.name, available_at: d.availableAt?.toISOString() })),
      tours: result.trips.map((t) => ({
        driver_id: t.driverId,
        trip: t.tripIndex,
        departure: t.plannedDepartureAt.toISOString(),
        return: t.plannedReturnAt.toISOString(),
        stops: t.stops
          .filter((s) => s.orderId)
          .map((s) => ({
            order_id: s.orderId,
            planned_arrival: s.plannedArrivalAt.toISOString(),
            target_time: s.targetTime?.toISOString(),
          })),
      })),
      unassigned: result.unassignedOrderIds,
      waiting: waiting.map((w) => w.order_id),
    },
    routes: routesPayload,
    waiting,
    unassignable,
  };

  if (dryRun) return { result, payload, applied: null as any };

  const { data: applied, error: applyErr } = await supabase.rpc("apply_delivery_plan", { p: payload });
  if (applyErr) throw applyErr;
  if (!applied?.ok) throw new StalePlanError(applied?.reason ?? "stale");

  // 9. Tell drivers about new or changed tours.
  const changed: string[] = applied.changed_driver_ids ?? [];
  const messages = changed
    .map((driverId) => {
      const token = driverRowById.get(driverId)?.fcm_token;
      const route = result.routes.find((r) => r.driverId === driverId);
      if (!token || !route) return null;
      const n = route.stops.filter((s) => s.orderId).length;
      const leave = route.plannedDepartureAt.getTime() <= now.getTime() + 60_000 ? "now" : `at ${fmtTime(route.plannedDepartureAt)}`;
      return {
        token,
        title: `New tour: ${n} ${n === 1 ? "order" : "orders"}`,
        body: `Leave ${leave} · back ~${fmtTime(route.plannedReturnAt)}`,
        data: { type: "driver_route", driver_id: driverId },
      };
    })
    .filter(Boolean) as { token: string; title: string; body: string; data: Record<string, string> }[];
  if (messages.length > 0) {
    await sendToTokens(supabase, messages, { androidChannelId: "driver_routes", androidTag: "driver_route" }).catch((e) =>
      console.error("[plan-routes] push failed:", e)
    );
  }

  return { result, payload, applied };
}

// ============================================================
// HTTP HANDLER
// ============================================================

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, serviceKey);

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    // No body — manual run.
  }
  const triggerReason: string = body.trigger_reason ?? "manual";
  const dryRun = body.dry_run === true;

  try {
    // Legacy driver-app path ("back at restaurant"): finish the tour as the calling driver.
    if (body.complete_route_id) {
      const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
        global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      });
      const { error } = await userClient.rpc("driver_complete_route", { p_route_id: body.complete_route_id });
      if (error) return json({ error: error.message }, 403);
      // The route trigger schedules a re-plan.
      return json({ message: "Tour completed." });
    }

    if (dryRun) {
      const { result, payload } = await planOnce(supabase, { triggerReason, dryRun: true });
      return json({ dry_run: true, method: result.method, solver_time_ms: result.solverTimeMs, payload });
    }

    const mode = "real";
    const holder = crypto.randomUUID();
    const { data: locked, error: lockErr } = await supabase.rpc("planner_try_lock", {
      p_mode: mode,
      p_holder: holder,
      p_lease_secs: 45,
    });
    if (lockErr) throw lockErr;
    if (!locked) return json({ message: "Planner busy; a follow-up run is queued.", queued: true }, 202);

    let runs = 0;
    let last: Awaited<ReturnType<typeof planOnce>> | null = null;
    try {
      while (true) {
        runs++;
        try {
          last = await planOnce(supabase, { triggerReason: runs === 1 ? triggerReason : `${triggerReason}+rerun`, dryRun: false });
        } catch (e) {
          if (!(e instanceof StalePlanError) || runs >= MAX_RUNS) throw e;
          console.log(`[plan-routes] plan went stale (${e.message}), re-planning`);
          continue;
        }
        const { data: again } = await supabase.rpc("planner_release", {
          p_mode: mode,
          p_holder: holder,
          p_allow_rerun: runs < MAX_RUNS,
          p_lease_secs: 45,
        });
        if (!again) break;
      }
    } catch (e) {
      await supabase.rpc("planner_release", { p_mode: mode, p_holder: holder, p_allow_rerun: false });
      throw e;
    }

    const r = last!.result;
    return json({
      message: "Plan created successfully.",
      plan_version: r.planVersion,
      routes_created: r.routes.length,
      tours_planned: r.trips.length,
      unassigned_orders: r.unassignedOrderIds.length,
      cost: r.costBreakdown.totalCost,
      solver_time_ms: r.solverTimeMs,
      method: r.method,
      runs,
    });
  } catch (error) {
    console.error("Error in plan-routes:", error);
    return json({ error: (error as Error).message || "Unknown error" }, 500);
  }
});
