// supabase/functions/plan-routes/solver_test.ts
// Unit tests for the multi-tour route planner.
//
// Run: deno test --allow-all supabase/functions/plan-routes/solver_test.ts

import { assert, assertEquals, assertAlmostEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";

import { solve, __test } from "./solver.ts";
import { haversineFallback } from "./travel_time.ts";
import type { PlannerOrder, PlannerDriver, PlannerSettings, TravelTimeMatrix, LatLng, PlanResult } from "./types.ts";

// ============================================================
// HELPERS
// ============================================================

const STORE: LatLng = { lat: 47.81328, lng: 13.06882 };
const NOW = new Date("2026-09-27T18:00:00Z");

function settings(overrides: Partial<PlannerSettings> = {}): PlannerSettings {
  return {
    lateWeight: 10,
    earlyWeight: 1,
    driveWeight: 0.5,
    idleWeight: 2,
    unassignedWeight: 50,
    serviceWeight: 0.5,
    reassignWeight: 30,
    handoverTimeSecs: 300,
    earlyGraceSecs: 600,
    preorderEarlyGraceSecs: 900,
    bundlingWaitSecs: 240,
    planningHorizonSecs: 2700,
    safetyBufferSecs: 120,
    citySpeedKmh: 25,
    maxStopsPerRoute: 999,
    maxRouteDurationSecs: 3600,
    solverTimeLimitMs: 300,
    exhaustiveThreshold: 6,
    storeLocation: STORE,
    ...overrides,
  };
}

function order(
  id: string,
  location: LatLng,
  targetMin: number,
  opts: { readyMin?: number; preorder?: boolean } & Partial<PlannerOrder> = {},
): PlannerOrder {
  const { readyMin, preorder, ...rest } = opts;
  const target = new Date(NOW.getTime() + targetMin * 60_000);
  return {
    id,
    brandId: "brand",
    location,
    customerName: id,
    customerAddress: id,
    customerPhone: null,
    deliveryNotes: null,
    targetDeliveryTime: target,
    estimatedPickupTime: null,
    requestedDeliveryTime: preorder ? target : null,
    readyAt: readyMin === undefined ? null : new Date(NOW.getTime() + readyMin * 60_000),
    deliveryStatus: "ready_to_deliver",
    currentRouteId: null,
    currentDriverId: null,
    currentSequence: null,
    orderTypeName: "Lieferando",
    paymentMethod: "online",
    totalPrice: 20,
    ...rest,
  };
}

function driver(id: string, opts: Partial<PlannerDriver> = {}): PlannerDriver {
  return {
    id,
    name: id,
    isOnline: true,
    currentLocation: STORE,
    currentRouteId: null,
    projectedReturnAt: null,
    availableAt: null,
    shiftEndAt: null,
    ...opts,
  };
}

/** Road matrix from straight-line distance (×1.4 at 25 km/h), row 0 = store. */
function matrixFor(orders: PlannerOrder[]): TravelTimeMatrix {
  const pts = [STORE, ...orders.map((o) => o.location)];
  return pts.map((a) => pts.map((b) => (a === b ? { durationSeconds: 0, distanceMeters: 0 } : haversineFallback(a, b, 25))));
}

/** Matrix with explicit minutes: minutes[i][j], row/col 0 = store. */
function matrixMinutes(minutes: number[][]): TravelTimeMatrix {
  return minutes.map((row) => row.map((m) => ({ durationSeconds: m * 60, distanceMeters: m * 400 })));
}

function tourOf(res: PlanResult, orderId: string) {
  return res.trips.find((t) => t.stops.some((s) => s.orderId === orderId));
}

function arrivalMin(res: PlanResult, orderId: string): number {
  for (const t of res.trips) {
    const s = t.stops.find((x) => x.orderId === orderId);
    if (s) return (s.plannedArrivalAt.getTime() - NOW.getTime()) / 60_000;
  }
  throw new Error(`order ${orderId} not planned`);
}

// Salzburg-ish points around the restaurant.
const NORTH_A = { lat: 47.8330, lng: 13.0650 };
const NORTH_B = { lat: 47.8360, lng: 13.0600 };
const SOUTH_C = { lat: 47.7900, lng: 13.0700 };
const WEST_D = { lat: 47.8100, lng: 13.0200 };
const EAST_E = { lat: 47.8150, lng: 13.0950 };

// ============================================================
// BEHAVIOUR
// ============================================================

Deno.test("two free drivers: nearby north orders bundled, south order to the other driver", () => {
  const orders = [order("A", NORTH_A, 35), order("B", NORTH_B, 40), order("C", SOUTH_C, 35)];
  const res = solve(orders, [driver("D1"), driver("D2")], matrixFor(orders), settings(), NOW, 0);

  assertEquals(res.unassignedOrderIds, []);
  assertEquals(tourOf(res, "A")!.driverId, tourOf(res, "B")!.driverId, "A and B should share a driver");
  assert(tourOf(res, "C")!.driverId !== tourOf(res, "A")!.driverId, "C goes with the other driver");
  for (const oc of res.costBreakdown.perOrder) assertEquals(oc.latenessMinutes, 0, `${oc.orderId} late`);
});

Deno.test("both drivers are planned together: busy driver's direction is respected", () => {
  // D1 is out and back in 25 min; D2 is free. A new urgent order must go to D2.
  const orders = [order("S", SOUTH_C, 20)];
  const drivers = [
    driver("D1", { availableAt: new Date(NOW.getTime() + 25 * 60_000), currentRouteId: "r1" }),
    driver("D2"),
  ];
  const res = solve(orders, drivers, matrixFor(orders), settings(), NOW, 0);
  assertEquals(tourOf(res, "S")!.driverId, "D2");
});

Deno.test("ready order leaves now instead of waiting 20 min for a not-ready neighbour", () => {
  const orders = [order("A", NORTH_A, 45), order("B", NORTH_B, 70, { readyMin: 20 })];
  const res = solve(orders, [driver("D1"), driver("D2")], matrixFor(orders), settings(), NOW, 0);
  const a = tourOf(res, "A")!;
  assertAlmostEquals(a.plannedDepartureAt.getTime(), NOW.getTime(), 1000);
  assert(!a.stops.some((s) => s.orderId === "B"), "A should not wait for B");
});

Deno.test("food not ready yet: tour departs when the food is ready, never earlier", () => {
  const orders = [order("A", NORTH_A, 60, { readyMin: 12 })];
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings(), NOW, 0);
  assertAlmostEquals(res.routes[0].plannedDepartureAt.getTime(), NOW.getTime() + 12 * 60_000, 1000);
});

Deno.test("pre-order far in the future is deferred, not dispatched", () => {
  const orders = [order("P", NORTH_A, 120, { preorder: true, readyMin: 90 }), order("A", SOUTH_C, 40)];
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings(), NOW, 0);
  assert(!tourOf(res, "P"), "pre-order must not be planned yet");
  assert(!res.unassignedOrderIds.includes("P"), "deferred is not the same as unassigned");
  assert(tourOf(res, "A"));
});

Deno.test("timeline arithmetic: drive + 5 min handover per stop + return", () => {
  // store→A 7, A→B 5, B→store 9 (minutes)
  const orders = [order("A", NORTH_A, 30), order("B", NORTH_B, 40)];
  const m = matrixMinutes([
    [0, 7, 12],
    [7, 0, 5],
    [9, 5, 0],
  ]);
  const res = solve(orders, [driver("D1")], m, settings({ exhaustiveThreshold: 6 }), NOW, 0);
  assertEquals(res.routes.length, 1);
  const r = res.routes[0];
  assertEquals(r.stops.map((s) => s.orderId), [null, "A", "B", null]);
  assertEquals(arrivalMin(res, "A"), 7);
  assertEquals(arrivalMin(res, "B"), 17); // 7 + 5 handover + 5 drive
  assertEquals((r.plannedReturnAt.getTime() - NOW.getTime()) / 60_000, 31); // 17 + 5 + 9
});

Deno.test("one driver, orders ready at different times → two tours, second leaves on return", () => {
  const orders = [order("A", WEST_D, 30), order("B", EAST_E, 75, { readyMin: 30 })];
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings(), NOW, 0);
  const tours = res.trips.filter((t) => t.driverId === "D1");
  assertEquals(tours.length, 2);
  assertEquals(res.routes.length, 1, "only the next tour is committed");
  assertEquals(res.routes[0].stops[1].orderId, "A");
  assert(tours[1].plannedDepartureAt.getTime() >= tours[0].plannedReturnAt.getTime());
});

Deno.test("shift ending soon: the tour goes to the driver who stays", () => {
  const orders = [order("A", WEST_D, 40)];
  const drivers = [
    driver("Short", { shiftEndAt: new Date(NOW.getTime() + 5 * 60_000) }),
    driver("Long", { shiftEndAt: new Date(NOW.getTime() + 3 * 3600_000) }),
  ];
  const res = solve(orders, drivers, matrixFor(orders), settings({ shiftEndGraceMinutes: 5 }), NOW, 0);
  assertEquals(tourOf(res, "A")!.driverId, "Long");
});

Deno.test("only driver's shift ends before the tour could return → order flagged unassigned", () => {
  const orders = [order("A", WEST_D, 40)];
  const drivers = [driver("Short", { shiftEndAt: new Date(NOW.getTime() + 2 * 60_000) })];
  const res = solve(orders, drivers, matrixFor(orders), settings({ shiftEndGraceMinutes: 0 }), NOW, 0);
  assertEquals(res.unassignedOrderIds, ["A"]);
});

Deno.test("manual pin is respected even when the other driver would be better", () => {
  const orders = [order("A", NORTH_A, 40, { pinnedDriverId: "D2" })];
  const drivers = [driver("D1"), driver("D2", { availableAt: new Date(NOW.getTime() + 10 * 60_000) })];
  const res = solve(orders, drivers, matrixFor(orders), settings(), NOW, 0);
  assertEquals(tourOf(res, "A")!.driverId, "D2");
});

Deno.test("pin to a driver who went offline does not strand the order", () => {
  const orders = [order("A", NORTH_A, 40, { pinnedDriverId: "gone" })];
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings(), NOW, 0);
  assertEquals(tourOf(res, "A")!.driverId, "D1");
});

Deno.test("stability: a committed order stays with its driver unless the gain is real", () => {
  // D2 frees up 1 minute later than D1; the order was already given to D2.
  const orders = [
    order("A", NORTH_A, 45, { deliveryStatus: "assigned_to_route", currentDriverId: "D2", currentSequence: 1 }),
  ];
  const drivers = [driver("D1"), driver("D2", { availableAt: new Date(NOW.getTime() + 60_000) })];
  const res = solve(orders, drivers, matrixFor(orders), settings(), NOW, 0);
  assertEquals(tourOf(res, "A")!.driverId, "D2");
});

Deno.test("stability does not block a big improvement", () => {
  // Committed to D2 but D2 is now 40 minutes away; D1 is free → move it.
  const orders = [
    order("A", NORTH_A, 25, { deliveryStatus: "assigned_to_route", currentDriverId: "D2", currentSequence: 1 }),
  ];
  const drivers = [driver("D1"), driver("D2", { availableAt: new Date(NOW.getTime() + 40 * 60_000) })];
  const res = solve(orders, drivers, matrixFor(orders), settings(), NOW, 0);
  assertEquals(tourOf(res, "A")!.driverId, "D1");
});

Deno.test("orders of different brands share tours (same kitchen, same drivers)", () => {
  const orders = [order("A", NORTH_A, 35, { brandId: "tacos" }), order("B", NORTH_B, 35, { brandId: "burgers" })];
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings(), NOW, 0);
  assertEquals(res.routes.length, 1);
  assertEquals(res.routes[0].stops.filter((s) => s.orderId).length, 2);
});

Deno.test("tour capacity is a hard limit", () => {
  const pts = [NORTH_A, NORTH_B, { lat: 47.834, lng: 13.063 }, { lat: 47.835, lng: 13.061 }];
  const orders = pts.map((p, i) => order(`N${i}`, p, 50));
  const res = solve(orders, [driver("D1")], matrixFor(orders), settings({ maxStopsPerRoute: 2 }), NOW, 0);
  for (const t of res.trips) assert(t.stops.filter((s) => s.orderId).length <= 2);
  assertEquals(res.unassignedOrderIds, []);
});

// ============================================================
// OPTIMALITY & PERFORMANCE
// ============================================================

function randomInstance(seed: number, n: number) {
  let a = seed;
  const rand = () => {
    a = (a * 1103515245 + 12345) & 0x7fffffff;
    return a / 0x7fffffff;
  };
  const orders: PlannerOrder[] = [];
  for (let i = 0; i < n; i++) {
    const loc = { lat: STORE.lat + (rand() - 0.5) * 0.06, lng: STORE.lng + (rand() - 0.5) * 0.09 };
    const readyMin = Math.floor(rand() * 25) - 5;
    orders.push(order(`O${i}`, loc, readyMin + 30 + Math.floor(rand() * 30), { readyMin }));
  }
  const drivers = [driver("D1"), driver("D2", { availableAt: new Date(NOW.getTime() + Math.floor(rand() * 20) * 60_000) })];
  return { orders, drivers };
}

Deno.test("search finds the proven optimum on random small instances", () => {
  let matched = 0;
  const cases = 30;
  for (let seed = 1; seed <= cases; seed++) {
    const n = 4 + (seed % 3); // 4..6 orders
    const { orders, drivers } = randomInstance(seed, n);
    const p = __test.buildProblem(orders, orders.map((_, i) => i + 1), drivers, matrixFor(orders), settings(), NOW);
    const optimum = __test.exactOptimum(p);
    const found = __test.searchOnly(p, orders, 120, seed);
    assert(found >= optimum - 1e-6, "search cannot beat a proven optimum");
    if (found <= optimum + 1e-6) matched++;
  }
  assert(matched >= cases - 1, `search matched the optimum in ${matched}/${cases} cases`);
});

Deno.test("busy hour: 14 orders, 2 drivers — solved fast, everything planned, better than one-by-one", () => {
  const { orders } = randomInstance(99, 14);
  const drivers = [driver("D1"), driver("D2")];
  const m = matrixFor(orders);
  const t0 = Date.now();
  const res = solve(orders, drivers, m, settings({ solverTimeLimitMs: 400 }), NOW, 0);
  const took = Date.now() - t0;

  assert(took < 1500, `solver took ${took}ms`);
  assertEquals(res.method, "search");
  assertEquals(res.unassignedOrderIds, []);
  const planned = res.trips.flatMap((t) => t.stops.filter((s) => s.orderId).map((s) => s.orderId));
  assertEquals(new Set(planned).size, 14);

  // Baseline: each order its own tour, alternating drivers in promised-time order.
  const p = __test.buildProblem(orders, orders.map((_, i) => i + 1), drivers, m, settings(), NOW);
  const byTarget = orders.map((_, i) => i).sort((a, b) => orders[a].targetDeliveryTime.getTime() - orders[b].targetDeliveryTime.getTime());
  const baseline: number[][][] = [[], []];
  byTarget.forEach((i, k) => baseline[k % 2].push([i]));
  const baselineCost = __test.scheduleCost(p, baseline);
  assert(res.costBreakdown.totalCost < baselineCost, `plan ${res.costBreakdown.totalCost} vs baseline ${baselineCost}`);
});

Deno.test("no drivers: nothing planned, actionable orders reported unassigned", () => {
  const orders = [order("A", NORTH_A, 30)];
  const res = solve(orders, [], matrixFor(orders), settings(), NOW, 0);
  assertEquals(res.routes, []);
  assertEquals(res.unassignedOrderIds, ["A"]);
});

// ============================================================
// OVERDUE ORDERS FIRST
// ============================================================

Deno.test("only one order fits before the shift ends: the overdue order is kept, the fresh one waits", () => {
  // A was promised 20 min ago (overdue), B is fresh. Together they would end the shift late.
  const orders = [order("A", SOUTH_C, -20, { readyMin: 0 }), order("B", NORTH_A, 40, { readyMin: 0 })];
  const drivers = [driver("Only", { shiftEndAt: new Date(NOW.getTime() + 30 * 60_000) })];
  const res = solve(orders, drivers, matrixFor(orders), settings({ shiftEndGraceMinutes: 0 }), NOW, 0);
  assertEquals(res.unassignedOrderIds, ["B"]);
  assert(tourOf(res, "A"), "the overdue order is planned");
});

Deno.test("an overdue order is delivered before a fresh order, even when the fresh one is on the way", () => {
  // store→A 15 min, store→B 2 min, A↔B 14 min. A is 11 min overdue, B is due in 10 min.
  // On cost alone B first is cheaper (B on time, A a bit later); the rule puts A first.
  const orders = [order("A", WEST_D, -11, { readyMin: 0 }), order("B", EAST_E, 10, { readyMin: 0 })];
  const m = matrixMinutes([
    [0, 15, 2],
    [15, 0, 14],
    [2, 14, 0],
  ]);
  const res = solve(orders, [driver("D")], m, settings(), NOW, 0);
  const trip = tourOf(res, "A")!;
  assertEquals(trip.stops.filter((s) => s.orderId).map((s) => s.orderId), ["A", "B"]);
});

Deno.test("orders that are not late yet keep the efficient order (no seniority)", () => {
  // Same layout, but A is due in 5 min (not late): delivering the close order B first is fine.
  const orders = [order("A", WEST_D, 5, { readyMin: 0 }), order("B", EAST_E, 10, { readyMin: 0 })];
  const m = matrixMinutes([
    [0, 15, 2],
    [15, 0, 14],
    [2, 14, 0],
  ]);
  const p = __test.buildProblem(orders, [1, 2], [driver("D")], m, settings(), NOW);
  assertEquals([...p.overdue], [0, 0]);
  const res = solve(orders, [driver("D")], m, settings(), NOW, 0);
  assertEquals(tourOf(res, "A")!.stops.filter((s) => s.orderId).map((s) => s.orderId), ["B", "A"]);
});

Deno.test("search and exact agree with overdue orders in the mix", () => {
  let matched = 0;
  const cases = 20;
  for (let seed = 101; seed < 101 + cases; seed++) {
    const n = 4 + (seed % 3);
    const { orders, drivers } = randomInstance(seed, n);
    // Make every other order 15 min overdue.
    const mixed = orders.map((o, i) =>
      i % 2 === 0 ? { ...o, targetDeliveryTime: new Date(NOW.getTime() - 15 * 60_000) } : o
    );
    const p = __test.buildProblem(mixed, mixed.map((_, i) => i + 1), drivers, matrixFor(mixed), settings(), NOW);
    const optimum = __test.exactOptimum(p);
    const found = __test.searchOnly(p, mixed, 120, seed);
    assert(found >= optimum - 1e-6, "search cannot beat a proven optimum");
    if (found <= optimum + 1e-6) matched++;
  }
  assert(matched >= cases - 1, `search matched the optimum in ${matched}/${cases} cases`);
});
