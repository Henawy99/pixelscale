# Delivery Route Manager — Design Document

## 1. Overview

The Delivery Route Manager assigns incoming delivery orders to **2 drivers** and sequences each driver's stops so every order arrives as close as possible to its promised delivery time. It runs as a Supabase Edge Function (`plan-routes`) invoked on every relevant event, producing a plan visible on both the POS/dispatch tablet and the drivers' phones via Supabase Realtime.

### Key Constraints
- **Peak volume**: ~10 orders/hour
- **2 drivers**, each starting/ending at the restaurant
- **No hard stop limit** — the cost function + max route duration (1 hour) naturally limit how many orders a driver carries
- **Handover time**: 5 min per stop (park, walk up, hand over)
- **Planning horizon**: 45 min look-ahead for orders still in prep
- **Solver time budget**: < 1 second for ≤ 15 open orders

---

## 2. Data Model

### Tables
- **delivery_settings**: All tunable planner parameters (weights, timings, depot coordinates)
- **drivers**: id, name, is_online, current lat/lng/heading/speed, current_route_id, projected_return_at
- **delivery_routes**: id, assigned_driver_id, brand_id, status, plan_version, planned departure/return, actual departure/return, confirmed_at
- **route_stops**: id, delivery_route_id, order_id, type (store|customer_delivery), sequence_number, lat/lng, planned_arrival_at, status
- **orders**: delivery_status, assigned_driver_id, delivery_route_id, delivery_route_sequence, planned_arrival_at
- **travel_time_cache**: bucketed lat/lng pairs + hour → cached duration/distance
- **plan_log**: audit trail with cost breakdown and plan snapshot per version

### Relationships
- brands → delivery_settings (1:1)
- drivers → delivery_routes (1:many)
- delivery_routes → route_stops (1:many)
- route_stops → orders (1:1 for customer_delivery stops)
- orders → drivers (many:1 via assigned_driver_id)

---

## 3. Order State Machine

States and transitions:

1. **preparing** → Order created, kitchen working. estimated_pickup_time is in the future. Planner can see this order and pre-plan routes.
2. **ready_to_deliver** → Kitchen marks done (estimated_pickup_time reached).
3. **assigned_to_route** → Planner assigns to a route. Has assigned_driver_id, delivery_route_id, delivery_route_sequence.
4. **assigned_to_route → ready_to_deliver** → Route cancelled/replaced (replan).
5. **out_for_delivery** → Driver departs (route status → in_progress).
6. **delivered** → Driver marks delivered.

### Key Rules
- Pickup orders (fulfillment_type = 'pickup') are IGNORED by the planner.
- An order cannot ship before food is ready: departure = max(driver.availableAt, max(estimated_pickup_time for all orders in route)).
- Orders already out_for_delivery are FROZEN — planner can re-order remaining stops but never reassign to a different driver.
- There is no hard limit on orders per route — the cost function and max route duration (1 hour) naturally constrain route size.

---

## 4. Event → Replanning Flow

### Triggers
- New order inserted (Postgres trigger via pg_net)
- Order marked ready (delivery_status change)
- Driver goes online/offline (Postgres trigger)
- Driver departs (route → in_progress)
- Stop delivered (mark-delivered edge function)
- Driver returns to restaurant
- GPS update shifts ETA > 3 min
- Manual replan button (dispatch screen)

### Flow
1. Load open orders + driver states
2. Build travel-time matrix (cached + API)
3. Run solver (cheapest insertion + local search + exhaustive if ≤ 6 unassigned)
4. Write results atomically: upsert routes, update orders, log plan_version
5. Supabase Realtime pushes to dispatch + driver screens

---

## 5. Cost Function

### Per-Order Cost
```
target_time = requested_delivery_time ?? estimated_delivery_time

lateness     = max(0, arrival - target)                    [minutes]
early_grace  = 10 min (regular), 15 min (pre-orders)
earliness    = max(0, target - arrival - early_grace)      [minutes]

order_cost   = late_w * lateness^1.5 + early_w * earliness
```

The superlinear lateness penalty (^1.5) means 20 min late costs 10 * 20^1.5 = 894, while 2x10 min late costs 2 * 10 * 10^1.5 = 632.

### Plan Cost
```
plan_cost = sum(order_cost)
          + drive_w   * total_driving_minutes
          + idle_w    * driver_waiting_at_restaurant_while_orders_ready
          + unassigned_w * (orders left unassigned past their ready time)
```

### Default Weights
| Weight | Default | Purpose |
|--------|---------|---------|
| late_w | 10 | Strongly penalizes lateness |
| early_w | 1 | Mildly penalizes excessive earliness |
| drive_w | 0.5 | Prefers shorter driving routes |
| idle_w | 2 | Penalizes wasted driver time at restaurant |
| unassigned_w | 50 | Heavy penalty for unassigned ready orders |

---

## 6. Algorithm

### Phase 1: Initialize
1. Load all orders with delivery_status IN ('ready_to_deliver', 'assigned_to_route', 'out_for_delivery') plus orders in prep within the 45-min planning horizon.
2. Load both drivers' states: location, current route, projected return time.
3. Build travel-time matrix (restaurant + all order locations) using cached Google Distance Matrix results.
4. Fix already-delivered stops and in-car orders as constraints.

### Phase 2: Cheapest Insertion Heuristic
1. Sort unassigned orders by urgency (earliest target time first).
2. For each order, evaluate every possible insertion position in every driver's route, plus "new route when driver returns".
3. Pick the insertion with lowest total plan cost.
4. Enforce constraints: max 3 stops per route, max route duration, food must be ready.

### Phase 3: Local Search (up to 200ms)
- 2-opt within a route: reverse a segment to reduce cost
- Move: move a stop from one driver's route to the other
- Swap: swap stops between drivers
- Repeat until no improvement or time budget exhausted.

### Phase 4: Exhaustive Search (if <= 6 unassigned orders)
- Enumerate all assignments (order to driver) x all permutations.
- Compare against heuristic result, keep the better one.
- Guarantees true optimum for small instances.

### Phase 5: Write Atomically
- Upsert delivery_routes and route_stops.
- Update each order's assigned_driver_id, delivery_route_id, delivery_route_sequence, planned_arrival_at.
- Emit incremented plan_version to plan_log.

---

## 7. Two-Driver Reasoning

The planner never treats drivers independently. Each candidate plan contains both drivers' routes and is scored as a whole. This makes direction-awareness work naturally.

Example: Driver 1 heading north with 2 orders. New order in the south, target +30 min.
- Adding south order to D1's north route: High cost (20 min detour, makes north orders late)
- Giving to D2 (returns in 8 min): Low cost (D2 departs +8 min, arrives south +18 min, within target)
- The cost function naturally picks D2.

---

## 8. Worked Example

### Setup
- Restaurant: (47.813, 13.069), Time: 18:00
- Drivers: D1 (free), D2 (free)
- Orders: A (north, target 18:25, 8 min away), B (north near A, target 18:35, 12 min / 5 from A), C (south, target 18:30, 6 min away)

### Optimal Plan: D1 takes A->B, D2 takes C
- D1: 18:00 depart -> 18:08 arrive A (0 late) -> 18:13 leave A -> 18:18 arrive B (0 late) -> 18:27 return
- D2: 18:00 depart -> 18:06 arrive C (0 late, 14 min early, 4 excess) -> 18:12 return
- Order cost: 4 (just C's excess earliness)
- Plan cost: ~19

### Rejected Plan: D1 takes A->B->C
- C arrives at 18:36 = 6 min late -> cost = 10 * 6^1.5 = 147
- Plan cost: ~180 — rejected due to devastating lateness penalty

### Timeline Arithmetic (S7)
```
18:00:00  Depart restaurant
18:07:00  Arrive A (7 min drive)
18:12:00  Leave A (5 min handover)
18:17:00  Arrive B (5 min drive A->B)
18:22:00  Leave B (5 min handover)
18:31:00  Back at restaurant (9 min drive B->depot)
```

---

## 9. Configuration Reference

All durations and weights live in delivery_settings (nothing hard-coded).

| Setting | Column | Default | Unit |
|---------|--------|---------|------|
| Handover time | handover_time_secs | 300 | seconds |
| Early grace | early_grace_secs | 600 | seconds |
| Early grace (pre-order) | preorder_early_grace_secs | 900 | seconds |
| Bundling wait | bundling_wait_secs | 240 | seconds |
| Planning horizon | planning_horizon_secs | 2700 | seconds |
| Max stops per route | max_stops_per_route | 999 | count (no hard limit) |
| Max route duration | max_route_duration_secs | 3600 | seconds |
| Solver time limit | solver_time_limit_ms | 200 | ms |
| Exhaustive threshold | exhaustive_threshold | 6 | count |
| Auto-assign delay | auto_assign_delay_secs | 60 | seconds |
| City speed fallback | city_speed_kmh | 25 | km/h |
| Late weight | late_weight | 10 | - |
| Early weight | early_weight | 1 | - |
| Drive weight | drive_weight | 0.5 | - |
| Idle weight | idle_weight | 2 | - |
| Unassigned weight | unassigned_weight | 50 | - |
