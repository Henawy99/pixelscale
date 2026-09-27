# Delivery Route Manager — Design Document

## 1. Overview

The Delivery Route Manager assigns every self-delivered order to the drivers who are online in the driver app, groups orders into tours and sequences each tour so orders arrive fresh and before their promised time. It runs as the Supabase Edge Function `plan-routes`, triggered by database events plus a 1-minute tick. Drivers see their next tour in the driver app (`lib/main_driver.dart`, built with `./build_driver_apk.sh`); dispatch sees all tours on the Delivery Monitor, both via Supabase Realtime.

### Key decisions
- **One plan for all brands.** All brands are cooked in the same kitchen and delivered by the same drivers, so the planner never splits by brand.
- **Availability = online in the app.** A driver can receive tours when they switched "Online" in the driver app and their phone sent a heartbeat in the last 15 min (`driver_heartbeat_timeout_mins`). A scheduled shift is not required; if one exists, its end limits new tours.
- **Multi-tour per driver.** Each driver has a sequence of tours. Only the next tour is committed (written as a route the driver sees); later tours are planned for cost accuracy and shown in `plan_log`.
- **Food must be ready.** A tour leaves at `max(driver back at restaurant, food ready for every order in it)`.
- **Out of scope for our drivers:** pickup orders, and Foodora orders with `transport.type = PICKUP_LOGISTICS` (a Foodora rider collects them).

---

## 2. Data Model

### Tables
- **delivery_settings**: tunable parameters (weights, timings, depot). The planner and the settings screen use the oldest row.
- **drivers**: `is_online`, `last_seen_at`, position, `fcm_token` (push), `current_route_id`, `projected_return_at`.
- **driver_device_keys**: per-driver key the Android background service uses for heartbeats (no user session in that isolate).
- **delivery_routes**: one row per tour; `status` assigned → in_progress → completed. Route ids stay stable across re-plans.
- **route_stops**: store → customers → store, with planned arrival times and manual `pinned_driver_id`.
- **orders**: `delivery_status`, `assigned_driver_id`, `delivery_route_id`, `delivery_route_sequence`, `planned_arrival_at`, `is_unassignable`, optional `food_ready_at` (kitchen signal).
- **travel_time_cache**: ~100 m buckets; durations are reused across hours and refreshed after 30 days.
- **plan_log**: audit trail with cost breakdown and all planned tours (no-op ticks are not logged).
- **planner_lock**: serialises planner runs (see §4).

---

## 3. Order and Tour States

Order `delivery_status` (planner-owned except where noted):

1. **preparing** — waiting for a tour (the planner never infers "ready" on its own).
2. **ready_to_deliver** — only when the kitchen set `food_ready_at`.
3. **assigned_to_route** — on a driver's next tour.
4. **out_for_delivery** — driver pressed "Start tour" (`driver_start_route`). Frozen: the planner never touches it again.
5. **delivered** — `mark-delivered` or `driver_complete_route`.

Tour: `assigned` (re-plannable) → `in_progress` (driver left) → `completed` (driver back, `driver_complete_route`).

Food-ready time used by the planner: `food_ready_at` → `estimated_pickup_time` → pre-order: `max(created + prep, requested − 30 min)` → `created + default_prep_secs` (15 min).

Orders promised more than `stale_order_mins` (60) ago that were never dispatched through the app are ignored (handled outside the system).

---

## 4. Event → Re-planning Flow

### Triggers (all call `request_replan()`, which reads the key from Vault secret `planner_service_key`)
- Order inserted, confirmed, cancelled, geocoded, or `food_ready_at` changed
- Driver goes online / offline
- Tour started or completed
- Stop delivered (`mark-delivered`)
- Every minute while there are open orders and an online driver, or a committed tour (`planner_tick`, pg_cron)
- Manual replan button on the Delivery Monitor

### Flow
1. `planner_try_lock`: if a run is active, mark "re-run requested" and return 202. Bursts collapse into one follow-up run.
2. Load open delivery orders (all brands), manual pins, available drivers, and tours on the road.
3. For drivers on the road: return ETA from the last GPS fix through the undelivered stops.
4. Travel-time matrix: one cache query; missing pairs from Google Distance Matrix (≤25 destinations per request), haversine fallback.
5. Solve (§6).
6. `apply_delivery_plan(p)` in one transaction: reuse each driver's `assigned` route row, replace stops only if the order sequence changed, release dropped orders, flag unassignable ones, log. Aborts if the world changed meanwhile (e.g. a tour started) and the planner re-plans.
7. Push "New tour: N orders · Leave at HH:MM" to drivers whose next tour is new or changed (FCM, Android channel `driver_routes`).
8. `planner_release`: run again if a trigger arrived during this run.

---

## 5. Cost Function

```
per order  serviceW · (handover − ready)        freshness (waiting + riding)      default 0.5 / min
         + idleW    · (departure − ready)       ready food sitting at the store   default 2 / min
         + lateW    · late^1.5                  late = handover − (promised − safety buffer 2 min)   default 10
         + earlyW   · early                     pre-orders only, before requested − 15 min           default 1 / min
         + reassignW                            moved away from the driver it was committed to       default 30
per plan + driveW   · driving minutes                                                                default 0.5 / min
         + 100 000 per unassigned order, 1 000 000 per broken hard constraint (shift end, tour capacity, pin)
```

Early delivery of ASAP orders is not penalised. The superlinear lateness term makes one order 20 min late (894) worse than two orders 10 min late (632). With these weights the planner bundles orders a few minutes apart and sends orders in different directions with different drivers.

---

## 6. Algorithm

- **≤ `exhaustive_threshold` actionable orders (default 6): exact.** Every driver × tour split × sequence is enumerated (best schedule per driver and order subset, then every assignment), so the plan is provably optimal for the cost above.
- **Larger:** regret-2 insertion (seeded with current commitments, and from scratch) → simulated annealing within `solver_time_limit_ms` (relocate, swap, 2-opt, split tour, merge tours, move tour to another driver) → deterministic local-search polish to a local optimum. Two runs, best kept.
- Tests (`solver_test.ts`): the search matches the exact optimum on 60/60 random instances; 14 orders solve in ~400 ms.

Measured against the previous planner on the same simulated evenings (`deno run` in `plan-routes/`): with 8 open orders, late orders dropped from 3.2 to 0.3 on average and food age from 36 to 26 min, with less driving.

---

## 7. Driver App

- Separate entrypoint `lib/main_driver.dart` → only the driver screens are compiled in; login is empty (no pre-filled credentials); non-driver accounts are refused.
- Online toggle starts an Android foreground service that sends heartbeats + position via `driver_heartbeat` (device key), at most every 15 s.
- New or changed tour: sound, vibration and notification (FCM push when the app is closed, local notification when open; both share the tag `driver_route` so they collapse).
- "Start tour" → `driver_start_route`; "Back at restaurant" → `driver_complete_route` (SECURITY DEFINER RPCs that check the caller owns the tour).
- Build: `./build_driver_apk.sh` (builds with an empty `.env` so the service-role key is never in the APK; version code increases every build).

---

## 8. Configuration Reference

All live in `delivery_settings` (editable on the Delivery Settings screen unless noted).

| Setting | Column | Default | Unit |
|---------|--------|---------|------|
| Kitchen prep time | default_prep_secs | 900 | seconds |
| Handover time | handover_time_secs | 300 | seconds |
| Safety buffer | safety_buffer_secs | 120 | seconds (DB only) |
| Early grace (pre-order) | preorder_early_grace_secs | 900 | seconds |
| Planning horizon | planning_horizon_secs | 2700 | seconds |
| Ignore undispatched orders promised more than | stale_order_mins | 60 | minutes (DB only) |
| Driver heartbeat timeout | driver_heartbeat_timeout_mins | 15 | minutes (DB only) |
| Shift end grace | shift_end_grace_minutes | 15 | minutes |
| Max stops per tour | max_stops_per_route | 999 | count (hard limit) |
| Solver time limit | solver_time_limit_ms | 400 | ms |
| Exhaustive threshold | exhaustive_threshold | 6 | orders |
| City speed fallback | city_speed_kmh | 25 | km/h |
| Late weight | late_weight | 10 | - |
| Early weight | early_weight | 1 | - |
| Drive weight | drive_weight | 0.5 | - |
| Idle (food waiting) weight | idle_weight | 2 | - |
| Freshness weight | service_weight | 0.5 | - |
| Reassign penalty | reassign_weight | 30 | - |
