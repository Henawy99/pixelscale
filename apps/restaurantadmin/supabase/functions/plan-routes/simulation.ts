// supabase/functions/plan-routes/simulation.ts
// Replays a synthetic busy hour (10 orders, 2 drivers, random Salzburg addresses).
// Prints average lateness, max lateness, driving minutes, plan time.
//
// Run: deno run --allow-all simulation.ts

import { solve, evaluatePlan, computeRouteTimeline } from "./solver.ts";
import { buildTestMatrix } from "./travel_time.ts";
import type {
  PlannerOrder,
  PlannerDriver,
  PlannerSettings,
  TravelTimeMatrix,
  TravelTime,
  LatLng,
  PlanResult,
} from "./types.ts";

// ============================================================
// CONFIG
// ============================================================

const RESTAURANT: LatLng = { lat: 47.81328, lng: 13.06882 };

// Realistic Salzburg delivery addresses (5020/5023/5026 postcodes)
const SALZBURG_ADDRESSES: { name: string; location: LatLng }[] = [
  { name: "Aigen Süd",           location: { lat: 47.7918, lng: 13.0711 } },
  { name: "Maxglan West",        location: { lat: 47.8032, lng: 13.0198 } },
  { name: "Lehen Nord",          location: { lat: 47.8180, lng: 13.0370 } },
  { name: "Nonntal",             location: { lat: 47.7937, lng: 13.0535 } },
  { name: "Liefering",           location: { lat: 47.8256, lng: 13.0160 } },
  { name: "Itzling",             location: { lat: 47.8195, lng: 13.0730 } },
  { name: "Schallmoos",          location: { lat: 47.8130, lng: 13.0600 } },
  { name: "Gneis",               location: { lat: 47.7855, lng: 13.0410 } },
  { name: "Parsch",              location: { lat: 47.8050, lng: 13.0780 } },
  { name: "Gnigl",               location: { lat: 47.8220, lng: 13.0650 } },
  { name: "Morzg",               location: { lat: 47.7800, lng: 13.0600 } },
  { name: "Leopoldskron",        location: { lat: 47.7890, lng: 13.0330 } },
  { name: "Elisabeth-Vorstadt",  location: { lat: 47.8100, lng: 13.0500 } },
  { name: "Sam",                 location: { lat: 47.8300, lng: 13.0450 } },
  { name: "Taxham",              location: { lat: 47.8050, lng: 13.0050 } },
];

// ============================================================
// SEEDED RANDOM
// ============================================================

function createRng(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

// ============================================================
// HAVERSINE (for building realistic travel times)
// ============================================================

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
  const roadDist = dist * 1.4; // City driving factor
  const speedMs = (citySpeedKmh * 1000) / 3600;
  const secs = speedMs > 0 ? roadDist / speedMs : 0;
  return {
    durationSeconds: Math.round(secs),
    distanceMeters: Math.round(roadDist),
  };
}

// ============================================================
// SIMULATION
// ============================================================

interface SimulationResult {
  seed: number;
  numOrders: number;
  avgLatenessMin: number;
  maxLatenessMin: number;
  totalDrivingMin: number;
  planTimeMs: number;
  unassignedCount: number;
  routeCount: number;
  weightProfile: string;
}

function runSimulation(
  seed: number,
  numOrders: number,
  weightOverrides: Partial<PlannerSettings> = {},
  weightProfileName: string = "default"
): SimulationResult {
  const rand = createRng(seed);
  const now = new Date("2026-01-01T18:00:00Z");

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
    maxStopsPerRoute: 3,
    maxRouteDurationSecs: 3600,
    solverTimeLimitMs: 200,
    exhaustiveThreshold: 6,
    storeLocation: RESTAURANT,
    ...weightOverrides,
  };

  // Generate random orders arriving over 60 minutes
  const orders: PlannerOrder[] = [];
  const locations: LatLng[] = [RESTAURANT]; // index 0 = depot

  for (let i = 0; i < numOrders; i++) {
    const addrIdx = Math.floor(rand() * SALZBURG_ADDRESSES.length);
    const addr = SALZBURG_ADDRESSES[addrIdx];

    // Add slight randomization to location
    const loc: LatLng = {
      lat: addr.location.lat + (rand() - 0.5) * 0.002,
      lng: addr.location.lng + (rand() - 0.5) * 0.002,
    };
    locations.push(loc);

    // Order arrives at a random time in the hour
    const arrivalOffsetMin = Math.floor(rand() * 50); // 0-50 min into the hour
    const pickupReadyMin = arrivalOffsetMin + 5 + Math.floor(rand() * 10); // 5-15 min prep
    const targetMin = pickupReadyMin + 15 + Math.floor(rand() * 15); // 15-30 min after ready

    const isPreorder = rand() < 0.1; // 10% chance of pre-order

    orders.push({
      id: `O${i + 1}`,
      brandId: "test-brand",
      location: loc,
      customerName: `Customer ${addr.name}`,
      customerAddress: `${addr.name}, Salzburg`,
      customerPhone: null,
      deliveryNotes: null,
      targetDeliveryTime: new Date(now.getTime() + targetMin * 60000),
      estimatedPickupTime:
        pickupReadyMin <= 0
          ? null
          : new Date(now.getTime() + pickupReadyMin * 60000),
      requestedDeliveryTime: isPreorder
        ? new Date(now.getTime() + (60 + Math.floor(rand() * 30)) * 60000)
        : null,
      deliveryStatus: pickupReadyMin <= 0 ? "ready_to_deliver" : null as any,
      currentRouteId: null,
      currentDriverId: null,
      currentSequence: null,
      orderTypeName: ["Lieferando", "Foodora", "Website"][Math.floor(rand() * 3)],
      paymentMethod: rand() < 0.6 ? "online" : "cash",
      totalPrice: 15 + Math.floor(rand() * 30),
    });
  }

  // Build travel time matrix using haversine
  const n = locations.length;
  const entries = new Map<string, TravelTime>();
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      const tt = haversineTravelTime(locations[i], locations[j], settings.citySpeedKmh);
      entries.set(`${i},${j}`, tt);
    }
  }
  const matrix = buildTestMatrix(n, entries);

  // Create 2 drivers
  const drivers: PlannerDriver[] = [
    {
      id: "D1",
      name: "Driver 1",
      isOnline: true,
      currentLocation: null,
      currentRouteId: null,
      projectedReturnAt: null,
    },
    {
      id: "D2",
      name: "Driver 2",
      isOnline: true,
      currentLocation: null,
      currentRouteId: null,
      projectedReturnAt: null,
    },
  ];

  // Run solver
  const result: PlanResult = solve(orders, drivers, matrix, settings, now, 0);

  // Compute stats
  const latenesses = result.costBreakdown.perOrder.map((oc) => oc.latenessMinutes);
  const avgLateness =
    latenesses.length > 0
      ? latenesses.reduce((s, v) => s + v, 0) / latenesses.length
      : 0;
  const maxLateness = latenesses.length > 0 ? Math.max(...latenesses) : 0;

  return {
    seed,
    numOrders,
    avgLatenessMin: Math.round(avgLateness * 100) / 100,
    maxLatenessMin: Math.round(maxLateness * 100) / 100,
    totalDrivingMin: Math.round(result.costBreakdown.totalDrivingMinutes * 100) / 100,
    planTimeMs: result.solverTimeMs,
    unassignedCount: result.unassignedOrderIds.length,
    routeCount: result.routes.length,
    weightProfile: weightProfileName,
  };
}

// ============================================================
// MAIN
// ============================================================

console.log("=".repeat(80));
console.log("DELIVERY ROUTE PLANNER — SIMULATION");
console.log("=".repeat(80));
console.log();

// Run with default weights
console.log("--- Default Weights (late=10, early=1, drive=0.5, idle=2, unassigned=50) ---");
const defaultResults: SimulationResult[] = [];
for (let seed = 1; seed <= 10; seed++) {
  const result = runSimulation(seed, 10, {}, "default");
  defaultResults.push(result);
  console.log(
    `  Seed ${seed.toString().padStart(2)}: ` +
    `avg_late=${result.avgLatenessMin.toFixed(1).padStart(5)}min  ` +
    `max_late=${result.maxLatenessMin.toFixed(1).padStart(5)}min  ` +
    `driving=${result.totalDrivingMin.toFixed(1).padStart(6)}min  ` +
    `routes=${result.routeCount}  ` +
    `unassigned=${result.unassignedCount}  ` +
    `plan_time=${result.planTimeMs}ms`
  );
}

const avgAvgLate = defaultResults.reduce((s, r) => s + r.avgLatenessMin, 0) / defaultResults.length;
const avgMaxLate = defaultResults.reduce((s, r) => s + r.maxLatenessMin, 0) / defaultResults.length;
const avgDriving = defaultResults.reduce((s, r) => s + r.totalDrivingMin, 0) / defaultResults.length;
const avgPlanTime = defaultResults.reduce((s, r) => s + r.planTimeMs, 0) / defaultResults.length;

console.log();
console.log(`  AVERAGES: avg_late=${avgAvgLate.toFixed(2)}min  max_late=${avgMaxLate.toFixed(2)}min  driving=${avgDriving.toFixed(1)}min  plan_time=${avgPlanTime.toFixed(0)}ms`);

// Run with aggressive lateness penalty
console.log();
console.log("--- Aggressive Late Weight (late=20, early=0.5) ---");
const aggressiveResults: SimulationResult[] = [];
for (let seed = 1; seed <= 5; seed++) {
  const result = runSimulation(seed, 10, { lateWeight: 20, earlyWeight: 0.5 }, "aggressive_late");
  aggressiveResults.push(result);
  console.log(
    `  Seed ${seed.toString().padStart(2)}: ` +
    `avg_late=${result.avgLatenessMin.toFixed(1).padStart(5)}min  ` +
    `max_late=${result.maxLatenessMin.toFixed(1).padStart(5)}min  ` +
    `driving=${result.totalDrivingMin.toFixed(1).padStart(6)}min  ` +
    `routes=${result.routeCount}  ` +
    `plan_time=${result.planTimeMs}ms`
  );
}

// Run with high driving weight (efficiency focus)
console.log();
console.log("--- Efficiency Focus (drive=2, late=5) ---");
const efficiencyResults: SimulationResult[] = [];
for (let seed = 1; seed <= 5; seed++) {
  const result = runSimulation(seed, 10, { driveWeight: 2, lateWeight: 5 }, "efficiency");
  efficiencyResults.push(result);
  console.log(
    `  Seed ${seed.toString().padStart(2)}: ` +
    `avg_late=${result.avgLatenessMin.toFixed(1).padStart(5)}min  ` +
    `max_late=${result.maxLatenessMin.toFixed(1).padStart(5)}min  ` +
    `driving=${result.totalDrivingMin.toFixed(1).padStart(6)}min  ` +
    `routes=${result.routeCount}  ` +
    `plan_time=${result.planTimeMs}ms`
  );
}

console.log();
console.log("=".repeat(80));
console.log("SIMULATION COMPLETE");
console.log("=".repeat(80));
