// supabase/functions/simulate-delivery/index.ts
// Standalone simulation edge function — runs the solver in-memory with
// synthetic Salzburg orders. No database writes, perfect for testing.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { solve, evaluatePlan, computeRouteTimeline } from "../plan-routes/solver.ts";
import { buildTestMatrix } from "../plan-routes/travel_time.ts";
import type {
  PlannerOrder,
  PlannerDriver,
  PlannerSettings,
  TravelTime,
  LatLng,
  PlanResult,
} from "../plan-routes/types.ts";

// ============================================================
// SALZBURG ADDRESSES
// ============================================================

const RESTAURANT: LatLng = { lat: 47.81328, lng: 13.06882 };

const SALZBURG_ADDRESSES: { name: string; location: LatLng; area: string }[] = [
  { name: "Aigen Süd",          location: { lat: 47.7918, lng: 13.0711 }, area: "south" },
  { name: "Maxglan West",       location: { lat: 47.8032, lng: 13.0198 }, area: "west"  },
  { name: "Lehen Nord",         location: { lat: 47.8180, lng: 13.0370 }, area: "north" },
  { name: "Nonntal",            location: { lat: 47.7937, lng: 13.0535 }, area: "south" },
  { name: "Liefering",          location: { lat: 47.8256, lng: 13.0160 }, area: "north" },
  { name: "Itzling",            location: { lat: 47.8195, lng: 13.0730 }, area: "east"  },
  { name: "Schallmoos",         location: { lat: 47.8130, lng: 13.0600 }, area: "east"  },
  { name: "Gneis",              location: { lat: 47.7855, lng: 13.0410 }, area: "south" },
  { name: "Parsch",             location: { lat: 47.8050, lng: 13.0780 }, area: "east"  },
  { name: "Gnigl",              location: { lat: 47.8220, lng: 13.0650 }, area: "north" },
  { name: "Morzg",              location: { lat: 47.7800, lng: 13.0600 }, area: "south" },
  { name: "Leopoldskron",       location: { lat: 47.7890, lng: 13.0330 }, area: "west"  },
  { name: "Elisabeth-Vorstadt", location: { lat: 47.8100, lng: 13.0500 }, area: "center"},
  { name: "Sam",                location: { lat: 47.8300, lng: 13.0450 }, area: "north" },
  { name: "Taxham",             location: { lat: 47.8050, lng: 13.0050 }, area: "west"  },
];

// ============================================================
// HELPERS
// ============================================================

function createRng(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

function haversineMeters(a: LatLng, b: LatLng): number {
  const R = 6371000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const sinLat = Math.sin(dLat / 2);
  const sinLng = Math.sin(dLng / 2);
  const h =
    sinLat * sinLat +
    Math.cos((a.lat * Math.PI) / 180) *
      Math.cos((b.lat * Math.PI) / 180) *
      sinLng * sinLng;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function haversineTravelTime(a: LatLng, b: LatLng, citySpeedKmh: number): TravelTime {
  const dist = haversineMeters(a, b);
  const roadDist = dist * 1.4;
  const speedMs = (citySpeedKmh * 1000) / 3600;
  const secs = speedMs > 0 ? roadDist / speedMs : 0;
  return {
    durationSeconds: Math.round(secs),
    distanceMeters: Math.round(roadDist),
  };
}

// ============================================================
// SIMULATION RUNNER
// ============================================================

interface SimulationRequest {
  num_orders?: number;
  num_drivers?: number;
  target_time?: string; // e.g. "2026-09-07T19:00:00Z" or "19:00"
  seed?: number;
  weight_overrides?: Partial<PlannerSettings>;
  custom_orders?: Array<{
    name: string;
    lat: number;
    lng: number;
    target_minutes_from_now: number;
    prep_minutes_from_now?: number;
  }>;
}

async function runSimulation(req: SimulationRequest) {
  const numOrders = req.num_orders ?? 8;
  const numDrivers = req.num_drivers ?? 2;
  const seed = req.seed ?? 42;
  const rand = createRng(seed);

  const now = new Date();
  let simTime = now;
  if (req.target_time) {
    if (req.target_time.includes("T")) {
      const parsed = new Date(req.target_time);
      if (!isNaN(parsed.getTime())) simTime = parsed;
    } else if (/^\d{1,2}:\d{2}/.test(req.target_time)) {
      const [h, m] = req.target_time.split(":").map(Number);
      simTime = new Date();
      simTime.setHours(h, m, 0, 0);
    }
  }

  const settings: PlannerSettings = {
    lateWeight: 10,
    earlyWeight: 1,
    driveWeight: 0.5,
    idleWeight: 2,
    unassignedWeight: 50,
    handoverTimeSecs: 300,
    earlyGraceSecs: 600,
    preorderEarlyGraceSecs: 900,
    bundlingWaitSecs: 240,
    planningHorizonSecs: 2700,
    citySpeedKmh: 25,
    maxStopsPerRoute: 999,
    maxRouteDurationSecs: 3600,
    shiftEndGraceMinutes: 15,
    solverTimeLimitMs: 500,
    exhaustiveThreshold: 6,
    storeLocation: RESTAURANT,
    ...req.weight_overrides,
  };

  // Generate orders
  const orders: PlannerOrder[] = [];
  const locations: LatLng[] = [RESTAURANT];

  if (req.custom_orders && req.custom_orders.length > 0) {
    // Use custom orders
    for (let i = 0; i < req.custom_orders.length; i++) {
      const co = req.custom_orders[i];
      const loc: LatLng = { lat: co.lat, lng: co.lng };
      locations.push(loc);

      orders.push({
        id: `SIM-${i + 1}`,
        brandId: "simulation",
        location: loc,
        customerName: co.name,
        customerAddress: `${co.name}, Salzburg`,
        customerPhone: null,
        deliveryNotes: null,
        targetDeliveryTime: new Date(now.getTime() + co.target_minutes_from_now * 60000),
        estimatedPickupTime: co.prep_minutes_from_now != null
          ? new Date(now.getTime() + co.prep_minutes_from_now * 60000)
          : null,
        requestedDeliveryTime: null,
        deliveryStatus: co.prep_minutes_from_now != null ? "preparing" : "ready_to_deliver",
        currentRouteId: null,
        currentDriverId: null,
        currentSequence: null,
        orderTypeName: "Simulation",
        paymentMethod: "online",
        totalPrice: 20,
      });
    }
  } else {
    // Generate random orders
    for (let i = 0; i < numOrders; i++) {
      const addrIdx = Math.floor(rand() * SALZBURG_ADDRESSES.length);
      const addr = SALZBURG_ADDRESSES[addrIdx];

      const loc: LatLng = {
        lat: addr.location.lat + (rand() - 0.5) * 0.002,
        lng: addr.location.lng + (rand() - 0.5) * 0.002,
      };
      locations.push(loc);

      const arrivalOffsetMin = Math.floor(rand() * 5); // Recently arrived
      const pickupReadyMin = arrivalOffsetMin + 3 + Math.floor(rand() * 8); // 3-11 min prep
      const targetMin = pickupReadyMin + 15 + Math.floor(rand() * 15); // 15-30 min after ready

      const isPreparing = rand() < 0.4; // 40% still preparing

      orders.push({
        id: `SIM-${i + 1}`,
        brandId: "simulation",
        location: loc,
        customerName: `${addr.name} #${i + 1}`,
        customerAddress: `${addr.name}, Salzburg`,
        customerPhone: null,
        deliveryNotes: null,
        targetDeliveryTime: new Date(now.getTime() + targetMin * 60000),
        estimatedPickupTime: isPreparing
          ? new Date(now.getTime() + pickupReadyMin * 60000)
          : null,
        requestedDeliveryTime: null,
        deliveryStatus: isPreparing ? "preparing" : "ready_to_deliver",
        currentRouteId: null,
        currentDriverId: null,
        currentSequence: null,
        orderTypeName: ["Lieferando", "Foodora", "Website"][Math.floor(rand() * 3)],
        paymentMethod: rand() < 0.6 ? "online" : "cash",
        totalPrice: 15 + Math.floor(rand() * 30),
      });
    }
  }

  // Build travel time matrix
  const n = locations.length;
  const entries = new Map<string, TravelTime>();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      entries.set(`${i},${j}`, haversineTravelTime(locations[i], locations[j], settings.citySpeedKmh));
    }
  }
  const matrix = buildTestMatrix(n, entries);

  // Create drivers: either real on-shift employees or synthetic drivers
  const drivers: PlannerDriver[] = [];
  let usedRealDrivers = false;

  if (req.target_time) {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
    if (supabaseUrl && supabaseKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseKey);
        const { data: realDrivers, error } = await supabase.rpc("available_drivers_at", {
          p_target_time: simTime.toISOString(),
        });
        if (!error && realDrivers && realDrivers.length > 0) {
          usedRealDrivers = true;
          for (const d of realDrivers) {
            drivers.push({
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
            });
          }
        }
      } catch (e) {
        console.warn("Could not query available_drivers_at:", e);
      }
    }
  }

  // Fallback to synthetic drivers if target_time was omitted or no on-shift drivers found
  if (drivers.length === 0) {
    for (let d = 0; d < numDrivers; d++) {
      drivers.push({
        id: `DRIVER-${d + 1}`,
        name: `Driver ${d + 1}`,
        isOnline: true,
        currentLocation: null,
        currentRouteId: null,
        projectedReturnAt: null,
      });
    }
  }

  // Run solver
  const result: PlanResult = solve(orders, drivers, matrix, settings, simTime, 0);

  // Build response
  const routeDetails = result.routes.map((route) => {
    const driverStops = route.stops
      .filter((s) => s.type === "customer_delivery")
      .map((s) => ({
        order_id: s.orderId,
        customer_name: s.customerName,
        customer_address: s.customerAddress,
        location: s.location,
        planned_arrival: s.plannedArrivalAt.toISOString(),
        target_time: s.targetTime?.toISOString(),
        is_ready: s.isReady,
        lateness_min: result.costBreakdown.perOrder.find((oc) => oc.orderId === s.orderId)?.latenessMinutes ?? 0,
        earliness_min: result.costBreakdown.perOrder.find((oc) => oc.orderId === s.orderId)?.earlinessMinutes ?? 0,
      }));

    return {
      driver_id: route.driverId,
      driver_name: drivers.find((d) => d.id === route.driverId)?.name ?? route.driverId,
      num_stops: driverStops.length,
      departure: route.plannedDepartureAt.toISOString(),
      return_time: route.plannedReturnAt.toISOString(),
      total_driving_minutes: Math.round(route.totalDrivingSeconds / 60 * 10) / 10,
      stops: driverStops,
      // Full stop list including depot for polyline drawing
      all_stops: route.stops.map((s) => ({
        type: s.type,
        location: s.location,
        order_id: s.orderId,
      })),
    };
  });

  const orderDetails = orders.map((o, idx) => ({
    id: o.id,
    customer_name: o.customerName,
    address: o.customerAddress,
    location: o.location,
    target_time: o.targetDeliveryTime.toISOString(),
    estimated_pickup_time: o.estimatedPickupTime?.toISOString() ?? null,
    status: o.deliveryStatus,
    is_ready: o.estimatedPickupTime === null || o.estimatedPickupTime.getTime() <= now.getTime(),
    order_type: o.orderTypeName,
    payment_method: o.paymentMethod,
    total_price: o.totalPrice,
  }));

  const latenesses = result.costBreakdown.perOrder.map((oc) => oc.latenessMinutes);
  const avgLateness = latenesses.length > 0
    ? latenesses.reduce((s, v) => s + v, 0) / latenesses.length
    : 0;
  const maxLateness = latenesses.length > 0 ? Math.max(...latenesses) : 0;

  return {
    simulation: {
      seed,
      num_orders: orders.length,
      num_drivers: drivers.length,
      used_real_drivers: usedRealDrivers,
      simulated_at: simTime.toISOString(),
      restaurant: RESTAURANT,
    },
    drivers: drivers.map((d) => ({
      id: d.id,
      name: d.name,
      shift_end_at: d.shiftEndAt?.toISOString() ?? null,
    })),
    stats: {
      avg_lateness_min: Math.round(avgLateness * 100) / 100,
      max_lateness_min: Math.round(maxLateness * 100) / 100,
      total_driving_min: Math.round(result.costBreakdown.totalDrivingMinutes * 100) / 100,
      total_idle_min: Math.round(result.costBreakdown.totalIdleMinutes * 100) / 100,
      total_cost: Math.round(result.costBreakdown.totalCost * 100) / 100,
      solver_time_ms: result.solverTimeMs,
      routes_created: result.routes.length,
      unassigned_count: result.unassignedOrderIds.length,
    },
    routes: routeDetails,
    orders: orderDetails,
    unassigned_order_ids: result.unassignedOrderIds,
    cost_breakdown: result.costBreakdown,
  };
}

// ============================================================
// HTTP HANDLER
// ============================================================

console.log("Simulate Delivery Function Up!");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let body: SimulationRequest = {};
    try {
      body = await req.json();
    } catch {
      // No body — use defaults
    }

    const result = await runSimulation(body);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Simulation error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Simulation failed" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
