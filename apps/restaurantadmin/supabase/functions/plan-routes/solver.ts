// supabase/functions/plan-routes/solver.ts
// Pure planner module — no I/O. Takes orders, drivers, matrix, settings → plan.
// Implements cheapest insertion + 2-opt + move/swap local search + exhaustive.

import type {
  PlannerOrder,
  PlannerDriver,
  PlannerSettings,
  TravelTimeMatrix,
  TravelTime,
  PlannedStop,
  PlannedRoute,
  PlanResult,
  CostBreakdown,
  OrderCost,
  CandidateRoute,
  CandidatePlan,
  LatLng,
} from "./types.ts";

// ============================================================
// COST FUNCTION
// ============================================================

/**
 * Compute per-order cost given arrival vs target time.
 * lateness^1.5 makes being 20 min late much worse than 2×10 min late.
 */
function orderCost(
  arrivalTime: Date,
  targetTime: Date,
  isPreorder: boolean,
  settings: PlannerSettings
): { latenessMin: number; earlinessMin: number; cost: number } {
  const arrivalMs = arrivalTime.getTime();
  const targetMs = targetTime.getTime();
  const diffMin = (arrivalMs - targetMs) / 60000; // positive = late

  const latenessMin = Math.max(0, diffMin);
  const graceMin =
    (isPreorder ? settings.preorderEarlyGraceSecs : settings.earlyGraceSecs) / 60;
  const earlinessMin = Math.max(0, -diffMin - graceMin);

  const cost =
    settings.lateWeight * Math.pow(latenessMin, 1.5) +
    settings.earlyWeight * earlinessMin;

  return { latenessMin, earlinessMin, cost };
}

/**
 * Evaluate the full cost of a candidate plan.
 * Returns total cost and per-order breakdown.
 */
export function evaluatePlan(
  plan: CandidatePlan,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CostBreakdown {
  const orderMap = new Map(orders.map((o) => [o.id, o]));
  const perOrder: OrderCost[] = [];
  let totalDrivingSecs = 0;
  let totalIdleSecs = 0;
  const assignedOrderIds = new Set<string>();

  for (const route of plan.routes) {
    if (route.stopOrderIndices.length === 0) continue;

    // When does this driver depart?
    const departureTime = route.availableAt;
    let currentTime = departureTime.getTime();
    let prevIdx = 0; // depot (restaurant)

    // Check if driver is waiting while orders are ready
    const readyOrders = route.stopOrderIds.filter((oid) => {
      const o = orderMap.get(oid);
      return o && (o.estimatedPickupTime === null || o.estimatedPickupTime.getTime() <= now.getTime());
    });
    // If driver is at restaurant and orders are ready but departure is delayed, that's idle time
    // (For now, idle is time the driver waits at restaurant after the first order is ready)

    for (let i = 0; i < route.stopOrderIndices.length; i++) {
      const matrixIdx = route.stopOrderIndices[i];
      const orderId = route.stopOrderIds[i];
      const order = orderMap.get(orderId);
      if (!order) continue;

      assignedOrderIds.add(orderId);

      // Travel from previous stop
      const travelTime = matrix[prevIdx][matrixIdx];
      totalDrivingSecs += travelTime.durationSeconds;
      currentTime += travelTime.durationSeconds * 1000;

      // Arrival at this stop
      const arrivalAt = new Date(currentTime);

      // Wait for food if not ready yet
      if (order.estimatedPickupTime && order.estimatedPickupTime.getTime() > departureTime.getTime()) {
        // Food not ready at departure; this affects when we can deliver
        // The planner should ideally not dispatch until food is ready
        // But if bundled, we might wait
      }

      // Cost for this order
      const isPreorder = order.requestedDeliveryTime !== null;
      const oc = orderCost(arrivalAt, order.targetDeliveryTime, isPreorder, settings);
      perOrder.push({
        orderId,
        latenessMinutes: oc.latenessMin,
        earlinessMinutes: oc.earlinessMin,
        cost: oc.cost,
      });

      // Handover time at this stop
      currentTime += settings.handoverTimeSecs * 1000;
      prevIdx = matrixIdx;
    }

    // Return to depot
    const returnTravel = matrix[prevIdx][0];
    totalDrivingSecs += returnTravel.durationSeconds;
  }

  // Unassigned orders (past ready time)
  const unassignedPastReady = orders.filter(
    (o) =>
      !assignedOrderIds.has(o.id) &&
      (o.deliveryStatus === "ready_to_deliver" ||
        o.deliveryStatus === "assigned_to_route") &&
      (o.estimatedPickupTime === null || o.estimatedPickupTime.getTime() <= now.getTime())
  );

  const totalDrivingMin = totalDrivingSecs / 60;
  const totalIdleMin = totalIdleSecs / 60;
  const orderCostSum = perOrder.reduce((s, oc) => s + oc.cost, 0);

  const totalCost =
    orderCostSum +
    settings.driveWeight * totalDrivingMin +
    settings.idleWeight * totalIdleMin +
    settings.unassignedWeight * unassignedPastReady.length;

  return {
    totalCost,
    perOrder,
    totalDrivingMinutes: totalDrivingMin,
    totalIdleMinutes: totalIdleMin,
    unassignedCount: unassignedPastReady.length,
  };
}

/**
 * Compute the arrival time at each stop for a single route.
 */
export function computeRouteTimeline(
  route: CandidateRoute,
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  orders?: PlannerOrder[]
): { arrivalTimes: Date[]; returnTime: Date; totalDrivingSecs: number; departureTime: Date } {
  // Compute departure time: max(driver availability, latest pickup time of orders in route)
  let departureMs = route.availableAt.getTime();

  if (orders) {
    const orderMap = new Map(orders.map((o) => [o.id, o]));
    for (const oid of route.stopOrderIds) {
      const order = orderMap.get(oid);
      if (order?.estimatedPickupTime) {
        departureMs = Math.max(departureMs, order.estimatedPickupTime.getTime());
      }
    }
  }

  const arrivalTimes: Date[] = [];
  let currentTime = departureMs;
  let prevIdx = 0; // depot
  let totalDrivingSecs = 0;
  let totalDistanceMeters = 0;

  for (const matrixIdx of route.stopOrderIndices) {
    const travel = matrix[prevIdx][matrixIdx];
    totalDrivingSecs += travel.durationSeconds;
    totalDistanceMeters += travel.distanceMeters ?? 0;
    currentTime += travel.durationSeconds * 1000;
    arrivalTimes.push(new Date(currentTime));
    currentTime += settings.handoverTimeSecs * 1000;
    prevIdx = matrixIdx;
  }

  // Return to depot (whole route is from restaurant to last stop and back to restaurant)
  const returnTravel = matrix[prevIdx][0];
  totalDrivingSecs += returnTravel.durationSeconds;
  totalDistanceMeters += returnTravel.distanceMeters ?? 0;
  currentTime += returnTravel.durationSeconds * 1000;

  return {
    arrivalTimes,
    returnTime: new Date(currentTime),
    totalDrivingSecs,
    totalDistanceMeters,
    departureTime: new Date(departureMs),
  };
}

/**
 * Check route duration constraint.
 */
function routeDurationOk(
  route: CandidateRoute,
  matrix: TravelTimeMatrix,
  settings: PlannerSettings
): boolean {
  const { returnTime } = computeRouteTimeline(route, matrix, settings);

  // NOTE: Route duration (maxRouteDurationSecs) is not a hard blocker.
  // Routes can exceed 60 minutes if necessary to deliver orders near estimated delivery time.

  // Shift end awareness:
  // Do not assign new orders to a driver whose projected return is after their
  // shift end + configurable grace (delivery_settings.shift_end_grace_minutes, default 15).
  if (route.shiftEndAt && route.stopOrderIndices.length > route.frozenStopCount) {
    const graceMs = (settings.shiftEndGraceMinutes ?? 15) * 60 * 1000;
    if (returnTime.getTime() > route.shiftEndAt.getTime() + graceMs) {
      return false;
    }
  }

  return true;
}

// ============================================================
// CHEAPEST INSERTION
// ============================================================

/**
 * Try inserting an order at every position in a route.
 * Returns the best insertion position and incremental cost, or null if infeasible.
 */
function bestInsertion(
  route: CandidateRoute,
  orderMatrixIdx: number,
  order: PlannerOrder,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date,
  allRoutes: CandidateRoute[]
): { position: number; cost: number } | null {
  let bestPos = -1;
  let bestCost = Infinity;

  const orderMap = new Map(orders.map((o) => [o.id, o]));
  const startPos = route.frozenStopCount; // Can't insert before frozen stops

  // Respect manual driver pinning
  if (order.pinnedDriverId && order.pinnedDriverId !== route.driverId) {
    return null;
  }

  // NOTE: maxStopsPerRoute is no longer a hard constraint.
  // Route duration (maxRouteDurationSecs) and the cost function naturally
  // limit how many orders a single driver should carry.

  for (let pos = startPos; pos <= route.stopOrderIndices.length; pos++) {
    // Create trial route with insertion
    const trial: CandidateRoute = {
      ...route,
      stopOrderIndices: [
        ...route.stopOrderIndices.slice(0, pos),
        orderMatrixIdx,
        ...route.stopOrderIndices.slice(pos),
      ],
      stopOrderIds: [
        ...route.stopOrderIds.slice(0, pos),
        order.id,
        ...route.stopOrderIds.slice(pos),
      ],
    };

    // Check duration constraint
    if (!routeDurationOk(trial, matrix, settings)) continue;

    // Evaluate cost of plan with this trial route
    const trialPlan: CandidatePlan = {
      routes: allRoutes.map((r) => (r.driverId === route.driverId ? trial : r)),
    };

    const cb = evaluatePlan(trialPlan, orders, matrix, settings, now);
    if (cb.totalCost < bestCost) {
      bestCost = cb.totalCost;
      bestPos = pos;
    }
  }

  return bestPos >= 0 ? { position: bestPos, cost: bestCost } : null;
}

/**
 * Cheapest insertion heuristic.
 * Sort unassigned orders by urgency, insert each into the cheapest position.
 */
function cheapestInsertion(
  initialRoutes: CandidateRoute[],
  unassignedOrders: PlannerOrder[],
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan {
  // Sort by target time (most urgent first)
  const sorted = [...unassignedOrders].sort(
    (a, b) => a.targetDeliveryTime.getTime() - b.targetDeliveryTime.getTime()
  );

  const routes = initialRoutes.map((r) => ({ ...r }));

  // Build order → matrix index mapping
  const orderMatrixIndex = new Map<string, number>();
  for (let i = 0; i < orders.length; i++) {
    orderMatrixIndex.set(orders[i].id, i + 1); // +1 because index 0 is depot
  }

  for (const order of sorted) {
    const matrixIdx = orderMatrixIndex.get(order.id);
    if (matrixIdx === undefined) continue;

    // Skip pre-orders that are too far out
    if (order.requestedDeliveryTime) {
      const readyInSecs =
        (order.requestedDeliveryTime.getTime() - now.getTime()) / 1000;
      if (readyInSecs > settings.planningHorizonSecs + settings.preorderEarlyGraceSecs * 60) {
        continue; // Too far out, skip for now
      }
    }

    // Try every driver's route
    let bestRouteIdx = -1;
    let bestPos = -1;
    let bestCost = Infinity;

    for (let rIdx = 0; rIdx < routes.length; rIdx++) {
      const result = bestInsertion(
        routes[rIdx],
        matrixIdx,
        order,
        orders,
        matrix,
        settings,
        now,
        routes
      );
      if (result && result.cost < bestCost) {
        bestCost = result.cost;
        bestPos = result.position;
        bestRouteIdx = rIdx;
      }
    }

    if (bestRouteIdx >= 0 && bestPos >= 0) {
      // Insert into best position
      routes[bestRouteIdx] = {
        ...routes[bestRouteIdx],
        stopOrderIndices: [
          ...routes[bestRouteIdx].stopOrderIndices.slice(0, bestPos),
          matrixIdx,
          ...routes[bestRouteIdx].stopOrderIndices.slice(bestPos),
        ],
        stopOrderIds: [
          ...routes[bestRouteIdx].stopOrderIds.slice(0, bestPos),
          order.id,
          ...routes[bestRouteIdx].stopOrderIds.slice(bestPos),
        ],
      };
    }
    // If no feasible insertion, order remains unassigned
  }

  return { routes };
}

// ============================================================
// LOCAL SEARCH (2-opt, move, swap)
// ============================================================

/**
 * 2-opt within a single route: reverse a segment to reduce cost.
 */
function twoOptImprove(
  plan: CandidatePlan,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan {
  let bestPlan = plan;
  let bestCost = evaluatePlan(plan, orders, matrix, settings, now).totalCost;
  let improved = true;

  while (improved) {
    improved = false;
    for (let rIdx = 0; rIdx < bestPlan.routes.length; rIdx++) {
      const route = bestPlan.routes[rIdx];
      const n = route.stopOrderIndices.length;
      const start = route.frozenStopCount;

      for (let i = start; i < n - 1; i++) {
        for (let j = i + 1; j < n; j++) {
          // Reverse segment [i, j]
          const newIndices = [...route.stopOrderIndices];
          const newIds = [...route.stopOrderIds];
          const segIndices = newIndices.slice(i, j + 1).reverse();
          const segIds = newIds.slice(i, j + 1).reverse();
          newIndices.splice(i, j - i + 1, ...segIndices);
          newIds.splice(i, j - i + 1, ...segIds);

          const trialRoute: CandidateRoute = {
            ...route,
            stopOrderIndices: newIndices,
            stopOrderIds: newIds,
          };

          if (!routeDurationOk(trialRoute, matrix, settings)) continue;

          const trialPlan: CandidatePlan = {
            routes: bestPlan.routes.map((r, idx) =>
              idx === rIdx ? trialRoute : r
            ),
          };

          const cost = evaluatePlan(trialPlan, orders, matrix, settings, now).totalCost;
          if (cost < bestCost - 0.001) {
            bestCost = cost;
            bestPlan = trialPlan;
            improved = true;
          }
        }
      }
    }
  }

  return bestPlan;
}

/**
 * Move a stop from one route to another.
 */
function moveImprove(
  plan: CandidatePlan,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan {
  let bestPlan = plan;
  let bestCost = evaluatePlan(plan, orders, matrix, settings, now).totalCost;

  for (let fromR = 0; fromR < plan.routes.length; fromR++) {
    const fromRoute = plan.routes[fromR];
    for (
      let i = fromRoute.frozenStopCount;
      i < fromRoute.stopOrderIndices.length;
      i++
    ) {
      const movedIdx = fromRoute.stopOrderIndices[i];
      const movedId = fromRoute.stopOrderIds[i];
      const movedOrder = orders.find((o) => o.id === movedId);

      // Remove from source route
      const srcRoute: CandidateRoute = {
        ...fromRoute,
        stopOrderIndices: [
          ...fromRoute.stopOrderIndices.slice(0, i),
          ...fromRoute.stopOrderIndices.slice(i + 1),
        ],
        stopOrderIds: [
          ...fromRoute.stopOrderIds.slice(0, i),
          ...fromRoute.stopOrderIds.slice(i + 1),
        ],
      };

      for (let toR = 0; toR < plan.routes.length; toR++) {
        if (toR === fromR) continue;
        const toRoute = plan.routes[toR];

        // Respect manual driver pinning
        if (movedOrder?.pinnedDriverId && movedOrder.pinnedDriverId !== toRoute.driverId) {
          continue;
        }

        for (
          let j = toRoute.frozenStopCount;
          j <= toRoute.stopOrderIndices.length;
          j++
        ) {
          const dstRoute: CandidateRoute = {
            ...toRoute,
            stopOrderIndices: [
              ...toRoute.stopOrderIndices.slice(0, j),
              movedIdx,
              ...toRoute.stopOrderIndices.slice(j),
            ],
            stopOrderIds: [
              ...toRoute.stopOrderIds.slice(0, j),
              movedId,
              ...toRoute.stopOrderIds.slice(j),
            ],
          };

          if (!routeDurationOk(dstRoute, matrix, settings)) continue;

          const trialPlan: CandidatePlan = {
            routes: plan.routes.map((r, idx) => {
              if (idx === fromR) return srcRoute;
              if (idx === toR) return dstRoute;
              return r;
            }),
          };

          const cost = evaluatePlan(
            trialPlan,
            orders,
            matrix,
            settings,
            now
          ).totalCost;
          if (cost < bestCost - 0.001) {
            bestCost = cost;
            bestPlan = trialPlan;
          }
        }
      }
    }
  }

  return bestPlan;
}

/**
 * Swap two stops between different routes.
 */
function swapImprove(
  plan: CandidatePlan,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan {
  let bestPlan = plan;
  let bestCost = evaluatePlan(plan, orders, matrix, settings, now).totalCost;

  for (let r1 = 0; r1 < plan.routes.length; r1++) {
    for (let r2 = r1 + 1; r2 < plan.routes.length; r2++) {
      const route1 = plan.routes[r1];
      const route2 = plan.routes[r2];

      for (
        let i = route1.frozenStopCount;
        i < route1.stopOrderIndices.length;
        i++
      ) {
        for (
          let j = route2.frozenStopCount;
          j < route2.stopOrderIndices.length;
          j++
        ) {
          // Respect manual driver pinning
          const o1 = orders.find((o) => o.id === route1.stopOrderIds[i]);
          const o2 = orders.find((o) => o.id === route2.stopOrderIds[j]);
          if (o1?.pinnedDriverId && o1.pinnedDriverId !== route2.driverId) continue;
          if (o2?.pinnedDriverId && o2.pinnedDriverId !== route1.driverId) continue;

          // Swap stops
          const newRoute1: CandidateRoute = {
            ...route1,
            stopOrderIndices: [...route1.stopOrderIndices],
            stopOrderIds: [...route1.stopOrderIds],
          };
          const newRoute2: CandidateRoute = {
            ...route2,
            stopOrderIndices: [...route2.stopOrderIndices],
            stopOrderIds: [...route2.stopOrderIds],
          };

          // Perform swap
          [newRoute1.stopOrderIndices[i], newRoute2.stopOrderIndices[j]] = [
            newRoute2.stopOrderIndices[j],
            newRoute1.stopOrderIndices[i],
          ];
          [newRoute1.stopOrderIds[i], newRoute2.stopOrderIds[j]] = [
            newRoute2.stopOrderIds[j],
            newRoute1.stopOrderIds[i],
          ];

          if (
            !routeDurationOk(newRoute1, matrix, settings) ||
            !routeDurationOk(newRoute2, matrix, settings)
          )
            continue;

          const trialPlan: CandidatePlan = {
            routes: plan.routes.map((r, idx) => {
              if (idx === r1) return newRoute1;
              if (idx === r2) return newRoute2;
              return r;
            }),
          };

          const cost = evaluatePlan(
            trialPlan,
            orders,
            matrix,
            settings,
            now
          ).totalCost;
          if (cost < bestCost - 0.001) {
            bestCost = cost;
            bestPlan = trialPlan;
          }
        }
      }
    }
  }

  return bestPlan;
}

/**
 * Run local search until no improvement or time limit.
 */
function localSearch(
  plan: CandidatePlan,
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan {
  const startMs = Date.now();
  let current = plan;
  let improved = true;

  while (improved && Date.now() - startMs < settings.solverTimeLimitMs) {
    improved = false;

    // 2-opt
    const after2opt = twoOptImprove(current, orders, matrix, settings, now);
    if (
      evaluatePlan(after2opt, orders, matrix, settings, now).totalCost <
      evaluatePlan(current, orders, matrix, settings, now).totalCost - 0.001
    ) {
      current = after2opt;
      improved = true;
    }

    if (Date.now() - startMs >= settings.solverTimeLimitMs) break;

    // Move
    const afterMove = moveImprove(current, orders, matrix, settings, now);
    if (
      evaluatePlan(afterMove, orders, matrix, settings, now).totalCost <
      evaluatePlan(current, orders, matrix, settings, now).totalCost - 0.001
    ) {
      current = afterMove;
      improved = true;
    }

    if (Date.now() - startMs >= settings.solverTimeLimitMs) break;

    // Swap
    const afterSwap = swapImprove(current, orders, matrix, settings, now);
    if (
      evaluatePlan(afterSwap, orders, matrix, settings, now).totalCost <
      evaluatePlan(current, orders, matrix, settings, now).totalCost - 0.001
    ) {
      current = afterSwap;
      improved = true;
    }
  }

  return current;
}

// ============================================================
// EXHAUSTIVE SEARCH (for small instances)
// ============================================================

/**
 * Generate all permutations of an array.
 */
function* permutations<T>(arr: T[]): Generator<T[]> {
  if (arr.length <= 1) {
    yield [...arr];
    return;
  }
  for (let i = 0; i < arr.length; i++) {
    const rest = [...arr.slice(0, i), ...arr.slice(i + 1)];
    for (const perm of permutations(rest)) {
      yield [arr[i], ...perm];
    }
  }
}

/**
 * Generate all ways to split N items into K non-empty groups (partitions).
 * We need: all ways to assign N orders to K drivers (including empty assignments).
 */
function* partitions(
  items: number[],
  k: number
): Generator<number[][]> {
  if (items.length === 0) {
    yield Array.from({ length: k }, () => []);
    return;
  }

  const [first, ...rest] = items;
  for (const sub of partitions(rest, k)) {
    for (let bucket = 0; bucket < k; bucket++) {
      const copy = sub.map((g) => [...g]);
      copy[bucket].push(first);
      yield copy;
    }
  }
}

/**
 * Exhaustive search: enumerate all assignments × all permutations.
 * Only feasible for ≤ 6 unassigned orders.
 */
function exhaustiveSearch(
  initialRoutes: CandidateRoute[],
  unassignedOrders: PlannerOrder[],
  orders: PlannerOrder[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date
): CandidatePlan | null {
  const n = unassignedOrders.length;
  const k = initialRoutes.length;
  if (n === 0) return { routes: initialRoutes };
  if (n > 8) return null; // Safety

  const orderIndices = unassignedOrders.map((_, i) => i);
  const orderMatrixIndices = unassignedOrders.map(
    (o) => orders.findIndex((oo) => oo.id === o.id) + 1
  );

  let bestPlan: CandidatePlan | null = null;
  let bestCost = Infinity;

  for (const partition of partitions(orderIndices, k)) {
    // For each partition, try all permutations within each group
    const permArrays: number[][][] = partition.map((group) =>
      group.length <= 1 ? [group] : [...permutations(group)]
    );

    // Cartesian product of permutation arrays
    function* cartesian(
      arrs: number[][][],
      idx: number,
      current: number[][]
    ): Generator<number[][]> {
      if (idx === arrs.length) {
        yield current;
        return;
      }
      for (const perm of arrs[idx]) {
        yield* cartesian(arrs, idx + 1, [...current, perm]);
      }
    }

    for (const combo of cartesian(permArrays, 0, [])) {
      // Respect manual driver pinning
      let pinViolation = false;
      for (let rIdx = 0; rIdx < combo.length; rIdx++) {
        const dId = initialRoutes[rIdx].driverId;
        for (const oIdx of combo[rIdx]) {
          const ord = unassignedOrders[oIdx];
          if (ord.pinnedDriverId && ord.pinnedDriverId !== dId) {
            pinViolation = true;
            break;
          }
        }
        if (pinViolation) break;
      }
      if (pinViolation) continue;

      const routes: CandidateRoute[] = initialRoutes.map((r, rIdx) => {
        const assignedIndices = combo[rIdx];
        return {
          ...r,
          stopOrderIndices: [
            ...r.stopOrderIndices,
            ...assignedIndices.map((i) => orderMatrixIndices[i]),
          ],
          stopOrderIds: [
            ...r.stopOrderIds,
            ...assignedIndices.map((i) => unassignedOrders[i].id),
          ],
        };
      });

      // Check duration constraint (max stops is no longer a hard limit)
      const allOk = routes.every(
        (r) => routeDurationOk(r, matrix, settings)
      );
      if (!allOk) continue;

      const plan: CandidatePlan = { routes };
      const cost = evaluatePlan(plan, orders, matrix, settings, now).totalCost;
      if (cost < bestCost) {
        bestCost = cost;
        bestPlan = plan;
      }
    }
  }

  return bestPlan;
}

// ============================================================
// BUNDLING WAIT LOGIC
// ============================================================

/**
 * Compass bearing from point A to point B (in degrees, 0=North).
 */
function bearing(from: LatLng, to: LatLng): number {
  const dLng = ((to.lng - from.lng) * Math.PI) / 180;
  const lat1 = (from.lat * Math.PI) / 180;
  const lat2 = (to.lat * Math.PI) / 180;

  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  const theta = Math.atan2(y, x);
  return ((theta * 180) / Math.PI + 360) % 360;
}

/**
 * Check if two bearings are within a tolerance (in degrees).
 */
function sameDirection(bearing1: number, bearing2: number, toleranceDeg: number): boolean {
  let diff = Math.abs(bearing1 - bearing2);
  if (diff > 180) diff = 360 - diff;
  return diff <= toleranceDeg;
}

/**
 * Check if we should wait to bundle a second order with the first.
 * Returns true if we should delay departure to wait for the second order.
 */
function shouldBundle(
  readyOrder: PlannerOrder,
  pendingOrder: PlannerOrder,
  settings: PlannerSettings,
  now: Date
): boolean {
  // Pending order must be ready within bundling_wait_secs
  if (!pendingOrder.estimatedPickupTime) return false;
  const waitSecs =
    (pendingOrder.estimatedPickupTime.getTime() - now.getTime()) / 1000;
  if (waitSecs <= 0 || waitSecs > settings.bundlingWaitSecs) return false;

  // Must be in the same direction (within 30°)
  const b1 = bearing(settings.storeLocation, readyOrder.location);
  const b2 = bearing(settings.storeLocation, pendingOrder.location);
  if (!sameDirection(b1, b2, 30)) return false;

  // Both orders must still be deliverable on time if we wait
  return true;
}

// ============================================================
// MAIN SOLVER ENTRY POINT
// ============================================================

/**
 * Solve the delivery routing problem.
 *
 * @param orders       All eligible orders (ready, assigned, or nearly ready)
 * @param drivers      All available drivers
 * @param matrix       NxN travel time matrix (index 0 = depot)
 * @param settings     Planner tuning parameters
 * @param now          Current timestamp
 * @param planVersion  Current plan version number
 *
 * @returns The optimal plan with routes, cost breakdown, and metadata.
 */
export function solve(
  orders: PlannerOrder[],
  drivers: PlannerDriver[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date,
  planVersion: number
): PlanResult {
  const startMs = Date.now();

  // 1. Build initial routes from current state
  const initialRoutes: CandidateRoute[] = drivers.map((driver) => {
    // Only pending assigned orders at the restaurant belong to this planned tour.
    // (In-progress / out_for_delivery orders are already on the road in an active route).
    const pendingOrders = orders.filter(
      (o) =>
        o.currentDriverId === driver.id &&
        o.deliveryStatus === "assigned_to_route" &&
        (!o.pinnedDriverId || o.pinnedDriverId === driver.id)
    );

    pendingOrders.sort(
      (a, b) => (a.currentSequence ?? 0) - (b.currentSequence ?? 0)
    );

    // Calculate when this driver is available at the restaurant depot:
    // If driver is currently out on a route, they become available when they return to the restaurant
    let driverAvailableAt = now;
    if (
      driver.currentRouteId &&
      driver.projectedReturnAt &&
      driver.projectedReturnAt.getTime() > now.getTime() &&
      driver.projectedReturnAt.getTime() - now.getTime() < 3 * 60 * 60 * 1000 // Max 3 hours out
    ) {
      driverAvailableAt = driver.projectedReturnAt;
    }

    return {
      driverId: driver.id,
      stopOrderIndices: pendingOrders.map(
        (o) => orders.indexOf(o) + 1 // +1 for depot at index 0
      ),
      stopOrderIds: pendingOrders.map((o) => o.id),
      isCurrentlyOut: driver.currentRouteId !== null,
      availableAt: driverAvailableAt,
      frozenStopCount: 0,
      shiftEndAt: driver.shiftEndAt ?? null,
    };
  });

  // 2. Identify unassigned orders
  const assignedIds = new Set(
    initialRoutes.flatMap((r) => r.stopOrderIds)
  );
  const unassignedOrders = orders.filter(
    (o) =>
      !assignedIds.has(o.id) &&
      (o.deliveryStatus === "preparing" ||
        o.deliveryStatus === "ready_to_deliver" ||
        o.deliveryStatus === "assigned_to_route" ||
        o.deliveryStatus === null ||
        o.deliveryStatus === undefined) &&
      // Only include if food is ready or will be ready within planning horizon
      (o.estimatedPickupTime === null ||
        o.estimatedPickupTime.getTime() <=
          now.getTime() + settings.planningHorizonSecs * 1000)
  );

  // 3. Skip pre-orders that are too far out
  const actionableOrders = unassignedOrders.filter((o) => {
    if (!o.requestedDeliveryTime) return true;
    const secsUntilTarget =
      (o.requestedDeliveryTime.getTime() - now.getTime()) / 1000;
    return (
      secsUntilTarget <=
      settings.planningHorizonSecs + settings.preorderEarlyGraceSecs
    );
  });

  console.log(
    `Solver: ${orders.length} total orders, ${actionableOrders.length} unassigned actionable, ${drivers.length} drivers`
  );

  // 4. Run cheapest insertion heuristic
  let heuristicPlan = cheapestInsertion(
    initialRoutes,
    actionableOrders,
    orders,
    matrix,
    settings,
    now
  );

  // 5. Local search improvement
  heuristicPlan = localSearch(heuristicPlan, orders, matrix, settings, now);

  let finalPlan = heuristicPlan;

  // 6. Exhaustive search for small instances
  if (actionableOrders.length <= settings.exhaustiveThreshold) {
    const exhaustivePlan = exhaustiveSearch(
      initialRoutes,
      actionableOrders,
      orders,
      matrix,
      settings,
      now
    );

    if (exhaustivePlan) {
      const heuristicCost = evaluatePlan(
        heuristicPlan,
        orders,
        matrix,
        settings,
        now
      ).totalCost;
      const exhaustiveCost = evaluatePlan(
        exhaustivePlan,
        orders,
        matrix,
        settings,
        now
      ).totalCost;

      console.log(
        `Exhaustive cost: ${exhaustiveCost.toFixed(2)}, Heuristic cost: ${heuristicCost.toFixed(2)}`
      );

      if (exhaustiveCost < heuristicCost) {
        finalPlan = exhaustivePlan;
      }
    }
  }

  // 7. Evaluate final plan
  const costBreakdown = evaluatePlan(finalPlan, orders, matrix, settings, now);
  const solverTimeMs = Date.now() - startMs;

  // 8. Convert to output format
  const orderMap = new Map(orders.map((o) => [o.id, o]));
  const routes: PlannedRoute[] = finalPlan.routes
    .filter((r) => r.stopOrderIndices.length > 0)
    .map((r) => {
      const timeline = computeRouteTimeline(r, matrix, settings, orders);

      const stops: PlannedStop[] = [];

      // Start at depot
      stops.push({
        orderId: null,
        type: "store",
        location: settings.storeLocation,
        customerName: null,
        customerAddress: null,
        matrixIndex: 0,
        plannedArrivalAt: timeline.departureTime,
        targetTime: null,
        isReady: true,
      });

      // Customer stops
      for (let i = 0; i < r.stopOrderIndices.length; i++) {
        const order = orderMap.get(r.stopOrderIds[i]);
        if (!order) continue;
        stops.push({
          orderId: order.id,
          type: "customer_delivery",
          location: order.location,
          customerName: order.customerName,
          customerAddress: order.customerAddress,
          matrixIndex: r.stopOrderIndices[i],
          plannedArrivalAt: timeline.arrivalTimes[i],
          targetTime: order.targetDeliveryTime,
          isReady:
            order.estimatedPickupTime === null ||
            order.estimatedPickupTime.getTime() <= now.getTime(),
        });
      }

      // End at depot
      stops.push({
        orderId: null,
        type: "store",
        location: settings.storeLocation,
        customerName: null,
        customerAddress: null,
        matrixIndex: 0,
        plannedArrivalAt: timeline.returnTime,
        targetTime: null,
        isReady: true,
      });

      return {
        driverId: r.driverId,
        stops,
        totalDrivingSeconds: timeline.totalDrivingSecs,
        totalDistanceMeters: Math.round(timeline.totalDistanceMeters),
        plannedDepartureAt: timeline.departureTime,
        plannedReturnAt: timeline.returnTime,
      };
    });

  // Find unassigned
  const allAssigned = new Set(
    finalPlan.routes.flatMap((r) => r.stopOrderIds)
  );
  const unassignedIds = actionableOrders
    .filter((o) => !allAssigned.has(o.id))
    .map((o) => o.id);

  return {
    routes,
    unassignedOrderIds: unassignedIds,
    costBreakdown,
    planVersion: planVersion + 1,
    solverTimeMs,
  };
}
