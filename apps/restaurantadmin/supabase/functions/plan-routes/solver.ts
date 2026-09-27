// supabase/functions/plan-routes/solver.ts
// Pure planner module — no I/O. Takes orders, drivers, matrix, settings → plan.
//
// Model
// -----
// Every driver works through a sequence of tours. A tour leaves the restaurant as soon as
// the driver is back AND every order in the tour is ready, visits its customers in order,
// and returns to the restaurant. The next tour starts from that return time.
//
// The planner decides which orders go to which driver, how they are grouped into tours
// and in which order each tour is driven. It minimises one plan-wide cost, so the drivers
// are never optimised in isolation:
//
//   per order   serviceW · (handover − ready)      freshness: waiting + riding time
//             + idleW    · (departure − ready)     ready food sitting at the restaurant
//             + lateW    · late^1.5               minutes past (promised − safety buffer)
//             + earlyW   · early                  pre-orders only: before the requested window
//             + reassignW                         order moved away from the driver it was given to
//   per plan  + driveW   · driving minutes
//             + huge penalties for unassigned orders and broken hard constraints
//               (shift end, tour capacity, manual pins)
//
// Search
// ------
// ≤ exhaustiveThreshold orders: exact enumeration (every driver/tour/sequence combination),
// so the returned plan is provably optimal for the cost above.
// Larger: regret insertion → simulated annealing (relocate / swap / 2-opt / split / merge /
// move-tour) → exhaustive local-search polish, within solverTimeLimitMs.

import type {
  PlannerOrder,
  PlannerDriver,
  PlannerSettings,
  TravelTimeMatrix,
  PlannedStop,
  PlannedRoute,
  PlanResult,
  CostBreakdown,
  OrderCost,
} from "./types.ts";

const UNASSIGNED_PENALTY = 100_000;
const HARD_PENALTY = 1_000_000;
const EPS = 1e-6;

/** Tours of one driver, each an ordered list of problem-order indices. */
type Trips = number[][];

interface State {
  sched: Trips[]; // per driver
  unassigned: number[];
  costs: Float64Array; // per driver
  total: number;
}

export interface Problem {
  n: number;
  m: number;
  /** Matrix width: index 0 = restaurant, i + 1 = order i. */
  N: number;
  dur: Float64Array; // seconds, row-major N×N
  dist: Float64Array; // meters, row-major N×N
  ready: Float64Array; // epoch ms
  target: Float64Array; // epoch ms
  isPre: Uint8Array;
  pinned: Int32Array; // driver index or -1
  current: Int32Array; // driver index the order is currently committed to, or -1
  avail: Float64Array; // epoch ms the driver can leave the restaurant
  shiftLimit: Float64Array; // epoch ms the driver must be back by (Infinity = none)
  handoverMs: number;
  bufferMs: number;
  preGraceMs: number;
  lateW: number;
  earlyW: number;
  driveW: number;
  serviceW: number;
  idleW: number;
  reassignW: number;
  maxStops: number;
}

// ============================================================
// PROBLEM CONSTRUCTION
// ============================================================

/** Time the food for an order is ready (epoch ms). */
export function readyTimeMs(o: PlannerOrder, nowMs: number): number {
  const r = o.readyAt ?? o.estimatedPickupTime;
  return r ? r.getTime() : nowMs;
}

/** Time the driver can leave the restaurant with a new tour (epoch ms). */
export function driverAvailableMs(d: PlannerDriver, nowMs: number): number {
  if (d.availableAt) return Math.max(nowMs, d.availableAt.getTime());
  if (
    d.currentRouteId &&
    d.projectedReturnAt &&
    d.projectedReturnAt.getTime() > nowMs &&
    d.projectedReturnAt.getTime() - nowMs < 3 * 3600_000
  ) {
    return d.projectedReturnAt.getTime();
  }
  return nowMs;
}

/**
 * Build the numeric problem for `orders` (a subset of the orders the matrix was built for).
 * `matrixIndex[i]` is the matrix row of orders[i]; row 0 is always the restaurant.
 */
export function buildProblem(
  orders: PlannerOrder[],
  matrixIndex: number[],
  drivers: PlannerDriver[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date,
): Problem {
  const nowMs = now.getTime();
  const n = orders.length;
  const m = drivers.length;
  const N = n + 1;
  const rows = [0, ...matrixIndex];

  const dur = new Float64Array(N * N);
  const dist = new Float64Array(N * N);
  for (let a = 0; a < N; a++) {
    for (let b = 0; b < N; b++) {
      if (a === b) continue;
      const tt = matrix[rows[a]]?.[rows[b]];
      dur[a * N + b] = tt ? tt.durationSeconds : 0;
      dist[a * N + b] = tt ? tt.distanceMeters : 0;
    }
  }

  const driverIdx = new Map(drivers.map((d, k) => [d.id, k]));
  const ready = new Float64Array(n);
  const target = new Float64Array(n);
  const isPre = new Uint8Array(n);
  const pinned = new Int32Array(n).fill(-1);
  const current = new Int32Array(n).fill(-1);

  for (let i = 0; i < n; i++) {
    const o = orders[i];
    ready[i] = readyTimeMs(o, nowMs);
    target[i] = (o.requestedDeliveryTime ?? o.targetDeliveryTime).getTime();
    isPre[i] = o.requestedDeliveryTime ? 1 : 0;
    // Pins to a driver who is not available are ignored rather than stranding the order.
    if (o.pinnedDriverId && driverIdx.has(o.pinnedDriverId)) pinned[i] = driverIdx.get(o.pinnedDriverId)!;
    if (o.currentDriverId && o.deliveryStatus === "assigned_to_route" && driverIdx.has(o.currentDriverId)) {
      current[i] = driverIdx.get(o.currentDriverId)!;
    }
  }

  const avail = new Float64Array(m);
  const shiftLimit = new Float64Array(m);
  const graceMs = (settings.shiftEndGraceMinutes ?? 15) * 60_000;
  for (let k = 0; k < m; k++) {
    avail[k] = driverAvailableMs(drivers[k], nowMs);
    shiftLimit[k] = drivers[k].shiftEndAt ? drivers[k].shiftEndAt!.getTime() + graceMs : Infinity;
  }

  return {
    n,
    m,
    N,
    dur,
    dist,
    ready,
    target,
    isPre,
    pinned,
    current,
    avail,
    shiftLimit,
    handoverMs: settings.handoverTimeSecs * 1000,
    bufferMs: (settings.safetyBufferSecs ?? 120) * 1000,
    preGraceMs: settings.preorderEarlyGraceSecs * 1000,
    lateW: settings.lateWeight,
    earlyW: settings.earlyWeight,
    driveW: settings.driveWeight,
    serviceW: settings.serviceWeight ?? 0.5,
    idleW: settings.idleWeight,
    reassignW: settings.reassignWeight ?? 30,
    maxStops: settings.maxStopsPerRoute > 0 ? settings.maxStopsPerRoute : 999,
  };
}

// ============================================================
// COST FUNCTION
// ============================================================

/** Cost of handing order o over at `arrivalMs` on a tour that left at `departureMs`. */
function orderCost(p: Problem, o: number, arrivalMs: number, departureMs: number): number {
  let c = p.serviceW * (arrivalMs - p.ready[o]) / 60_000;
  const wait = departureMs - p.ready[o];
  if (wait > 0) c += p.idleW * wait / 60_000;
  const late = (arrivalMs - (p.target[o] - p.bufferMs)) / 60_000;
  if (late > 0) c += p.lateW * late * Math.sqrt(late);
  if (p.isPre[o]) {
    const early = (p.target[o] - p.preGraceMs - arrivalMs) / 60_000;
    if (early > 0) c += p.earlyW * early;
  }
  return c;
}

/** Total cost of one driver's schedule. Pure and allocation-free. */
export function driverCost(p: Problem, k: number, trips: Trips): number {
  const N = p.N;
  let t = p.avail[k];
  let cost = 0;
  let driveSecs = 0;

  for (let j = 0; j < trips.length; j++) {
    const trip = trips[j];
    if (trip.length === 0) continue;

    let dep = t;
    for (let s = 0; s < trip.length; s++) if (p.ready[trip[s]] > dep) dep = p.ready[trip[s]];

    let cur = dep;
    let prev = 0;
    for (let s = 0; s < trip.length; s++) {
      const o = trip[s];
      const d = p.dur[prev * N + o + 1];
      cur += d * 1000;
      driveSecs += d;
      cost += orderCost(p, o, cur, dep);
      cur += p.handoverMs;
      prev = o + 1;

      if (p.pinned[o] >= 0 && p.pinned[o] !== k) cost += HARD_PENALTY;
      if (p.current[o] >= 0 && p.current[o] !== k) cost += p.reassignW;
    }
    const back = p.dur[prev * N];
    cur += back * 1000;
    driveSecs += back;

    if (trip.length > p.maxStops) cost += HARD_PENALTY * (trip.length - p.maxStops);
    if (cur > p.shiftLimit[k]) cost += HARD_PENALTY + (cur - p.shiftLimit[k]) / 60_000;
    t = cur;
  }

  return cost + p.driveW * driveSecs / 60;
}

function makeState(p: Problem, sched: Trips[], unassigned: number[]): State {
  const costs = new Float64Array(p.m);
  let total = unassigned.length * UNASSIGNED_PENALTY;
  for (let k = 0; k < p.m; k++) {
    costs[k] = driverCost(p, k, sched[k]);
    total += costs[k];
  }
  return { sched, unassigned, costs, total };
}

function cloneState(s: State): State {
  return {
    sched: s.sched.map((trips) => trips.map((t) => t.slice())),
    unassigned: s.unassigned.slice(),
    costs: s.costs.slice(),
    total: s.total,
  };
}

function cloneTrips(trips: Trips): Trips {
  return trips.map((t) => t.slice());
}

function dropEmpty(trips: Trips): Trips {
  return trips.filter((t) => t.length > 0);
}

/** Where an order currently sits: driver k (−1 = unassigned), trip j, position s. */
function locate(st: State, o: number): { k: number; j: number; s: number } {
  for (let k = 0; k < st.sched.length; k++) {
    const trips = st.sched[k];
    for (let j = 0; j < trips.length; j++) {
      const s = trips[j].indexOf(o);
      if (s >= 0) return { k, j, s };
    }
  }
  return { k: -1, j: -1, s: st.unassigned.indexOf(o) };
}

/** Every way to insert o into `trips`: into an existing tour or as a new tour. */
function* insertions(trips: Trips, o: number): Generator<Trips> {
  for (let j = 0; j < trips.length; j++) {
    for (let s = 0; s <= trips[j].length; s++) {
      const t = cloneTrips(trips);
      t[j].splice(s, 0, o);
      yield t;
    }
  }
  for (let j = 0; j <= trips.length; j++) {
    const t = cloneTrips(trips);
    t.splice(j, 0, [o]);
    yield t;
  }
}

// ============================================================
// CONSTRUCTION: seed from current assignments + regret insertion
// ============================================================

function construct(p: Problem, orders: PlannerOrder[], useSeed: boolean): State {
  const sched: Trips[] = Array.from({ length: p.m }, () => []);
  const placed = new Uint8Array(p.n);

  if (useSeed) {
    // Keep what drivers were already told, in the sequence they were told.
    for (let k = 0; k < p.m; k++) {
      const mine = [];
      for (let i = 0; i < p.n; i++) if (p.current[i] === k) mine.push(i);
      mine.sort((a, b) => (orders[a].currentSequence ?? 0) - (orders[b].currentSequence ?? 0));
      if (mine.length > 0) {
        sched[k].push(mine);
        for (const i of mine) placed[i] = 1;
      }
    }
  }

  const st = makeState(p, sched, []);
  const pending: number[] = [];
  for (let i = 0; i < p.n; i++) if (!placed[i]) pending.push(i);

  while (pending.length > 0) {
    let pickIdx = -1;
    let pickRegret = -Infinity;
    let pickK = -1;
    let pickTrips: Trips | null = null;
    let pickDelta = Infinity;

    for (let pi = 0; pi < pending.length; pi++) {
      const o = pending[pi];
      let best = Infinity;
      let second = Infinity;
      let bestK = -1;
      let bestTrips: Trips | null = null;
      for (let k = 0; k < p.m; k++) {
        let bestForK = Infinity;
        let bestTripsForK: Trips | null = null;
        for (const t of insertions(st.sched[k], o)) {
          const d = driverCost(p, k, t) - st.costs[k];
          if (d < bestForK) {
            bestForK = d;
            bestTripsForK = t;
          }
        }
        if (bestForK < best) {
          second = best;
          best = bestForK;
          bestK = k;
          bestTrips = bestTripsForK;
        } else if (bestForK < second) {
          second = bestForK;
        }
      }
      // Regret: how much we lose if this order does not get its best driver.
      // Ties broken by urgency (earliest promised time first).
      const regret = (second === Infinity ? 1e9 : second - best) - p.target[o] / 1e12;
      if (regret > pickRegret) {
        pickRegret = regret;
        pickIdx = pi;
        pickK = bestK;
        pickTrips = bestTrips;
        pickDelta = best;
      }
    }

    const o = pending[pickIdx];
    pending.splice(pickIdx, 1);
    if (pickK < 0 || !pickTrips || pickDelta >= UNASSIGNED_PENALTY) {
      st.unassigned.push(o);
      st.total += UNASSIGNED_PENALTY;
      continue;
    }
    st.total += pickDelta;
    st.sched[pickK] = pickTrips;
    st.costs[pickK] += pickDelta;
  }

  return st;
}

// ============================================================
// LOCAL SEARCH POLISH (deterministic, runs to a local optimum)
// ============================================================

function polish(p: Problem, st: State, deadline: number): State {
  let improved = true;
  while (improved && Date.now() < deadline) {
    improved = false;

    // 1. Relocate every order to its best slot anywhere (incl. from "unassigned").
    for (let o = 0; o < p.n; o++) {
      const loc = locate(st, o);
      let srcTrips: Trips | null = null;
      let srcCost = 0;
      let baseDelta: number;
      if (loc.k >= 0) {
        srcTrips = cloneTrips(st.sched[loc.k]);
        srcTrips[loc.j].splice(loc.s, 1);
        srcTrips = dropEmpty(srcTrips);
        srcCost = driverCost(p, loc.k, srcTrips);
        baseDelta = srcCost - st.costs[loc.k];
      } else {
        baseDelta = -UNASSIGNED_PENALTY;
      }

      let bestDelta = -EPS;
      let bestK = -1;
      let bestTrips: Trips | null = null;
      for (let k = 0; k < p.m; k++) {
        // For the order's own driver the removal is already applied in srcTrips.
        const from = k === loc.k ? srcTrips! : st.sched[k];
        for (const t of insertions(from, o)) {
          const c = driverCost(p, k, t);
          const delta = k === loc.k ? c - st.costs[k] : baseDelta + (c - st.costs[k]);
          if (delta < bestDelta) {
            bestDelta = delta;
            bestK = k;
            bestTrips = t;
          }
        }
      }
      if (bestK >= 0 && bestTrips) {
        if (loc.k >= 0 && loc.k !== bestK) {
          st.sched[loc.k] = srcTrips!;
          st.costs[loc.k] = srcCost;
        }
        if (loc.k < 0) st.unassigned.splice(loc.s, 1);
        st.sched[bestK] = bestTrips;
        st.costs[bestK] = driverCost(p, bestK, bestTrips);
        st.total = recomputeTotal(st);
        improved = true;
      }
    }

    // 2. Swap every pair of assigned orders.
    for (let a = 0; a < p.n; a++) {
      for (let b = a + 1; b < p.n; b++) {
        const la = locate(st, a);
        const lb = locate(st, b);
        if (la.k < 0 || lb.k < 0) continue;
        if (trySwap(p, st, la, lb)) improved = true;
      }
    }

    // 3. Intra-tour 2-opt, 4. split tours, 5. merge consecutive tours.
    for (let k = 0; k < p.m; k++) {
      if (improveDriver(p, st, k)) improved = true;
    }

    // 6. Move whole tours between drivers.
    if (p.m > 1 && moveTours(p, st)) improved = true;
  }
  return st;
}

function recomputeTotal(st: State): number {
  let t = st.unassigned.length * UNASSIGNED_PENALTY;
  for (let k = 0; k < st.costs.length; k++) t += st.costs[k];
  return t;
}

function trySwap(
  p: Problem,
  st: State,
  la: { k: number; j: number; s: number },
  lb: { k: number; j: number; s: number },
): boolean {
  const a = st.sched[la.k][la.j][la.s];
  const b = st.sched[lb.k][lb.j][lb.s];
  if (la.k === lb.k) {
    const t = cloneTrips(st.sched[la.k]);
    t[la.j][la.s] = b;
    t[lb.j][lb.s] = a;
    const c = driverCost(p, la.k, t);
    if (c < st.costs[la.k] - EPS) {
      st.total += c - st.costs[la.k];
      st.sched[la.k] = t;
      st.costs[la.k] = c;
      return true;
    }
    return false;
  }
  const ta = cloneTrips(st.sched[la.k]);
  const tb = cloneTrips(st.sched[lb.k]);
  ta[la.j][la.s] = b;
  tb[lb.j][lb.s] = a;
  const ca = driverCost(p, la.k, ta);
  const cb = driverCost(p, lb.k, tb);
  const delta = ca + cb - st.costs[la.k] - st.costs[lb.k];
  if (delta < -EPS) {
    st.total += delta;
    st.sched[la.k] = ta;
    st.sched[lb.k] = tb;
    st.costs[la.k] = ca;
    st.costs[lb.k] = cb;
    return true;
  }
  return false;
}

function improveDriver(p: Problem, st: State, k: number): boolean {
  let any = false;
  let again = true;
  while (again) {
    again = false;
    const trips = st.sched[k];
    let bestC = st.costs[k] - EPS;
    let best: Trips | null = null;

    for (let j = 0; j < trips.length; j++) {
      const len = trips[j].length;
      // 2-opt: reverse every segment.
      for (let x = 0; x < len - 1; x++) {
        for (let y = x + 1; y < len; y++) {
          const t = cloneTrips(trips);
          const seg = t[j].slice(x, y + 1).reverse();
          t[j].splice(x, y - x + 1, ...seg);
          const c = driverCost(p, k, t);
          if (c < bestC) {
            bestC = c;
            best = t;
          }
        }
      }
      // Split the tour in two consecutive tours.
      for (let cut = 1; cut < len; cut++) {
        const t = cloneTrips(trips);
        const tail = t[j].splice(cut);
        t.splice(j + 1, 0, tail);
        const c = driverCost(p, k, t);
        if (c < bestC) {
          bestC = c;
          best = t;
        }
      }
      // Merge with the next tour.
      if (j + 1 < trips.length) {
        const t = cloneTrips(trips);
        t[j] = t[j].concat(t[j + 1]);
        t.splice(j + 1, 1);
        const c = driverCost(p, k, t);
        if (c < bestC) {
          bestC = c;
          best = t;
        }
      }
    }

    if (best) {
      st.total += bestC - st.costs[k];
      st.sched[k] = best;
      st.costs[k] = bestC;
      any = true;
      again = true;
    }
  }
  return any;
}

function moveTours(p: Problem, st: State): boolean {
  let any = false;
  for (let a = 0; a < p.m; a++) {
    for (let j = 0; j < st.sched[a].length; j++) {
      for (let b = 0; b < p.m; b++) {
        if (a === b) continue;
        const src = cloneTrips(st.sched[a]);
        const [tour] = src.splice(j, 1);
        const cSrc = driverCost(p, a, src);
        for (let pos = 0; pos <= st.sched[b].length; pos++) {
          const dst = cloneTrips(st.sched[b]);
          dst.splice(pos, 0, tour.slice());
          const cDst = driverCost(p, b, dst);
          const delta = cSrc + cDst - st.costs[a] - st.costs[b];
          if (delta < -EPS) {
            st.total += delta;
            st.sched[a] = src;
            st.sched[b] = dst;
            st.costs[a] = cSrc;
            st.costs[b] = cDst;
            return true; // indices changed; caller loops again
          }
        }
      }
    }
  }
  return any;
}

// ============================================================
// SIMULATED ANNEALING
// ============================================================

/** Small deterministic PRNG (mulberry32) so plans are reproducible. */
function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function anneal(p: Problem, start: State, deadline: number, seed: number): { best: State; iterations: number } {
  const rand = rng(seed);
  const ri = (n: number) => Math.floor(rand() * n);
  let cur = cloneState(start);
  let best = cloneState(start);
  const t0Ms = Date.now();
  const span = Math.max(1, deadline - t0Ms);
  const T0 = 60;
  const Tend = 0.05;
  let T = T0;
  let iterations = 0;

  while (true) {
    if ((iterations & 127) === 0) {
      const now = Date.now();
      if (now >= deadline) break;
      T = T0 * Math.pow(Tend / T0, (now - t0Ms) / span);
    }
    iterations++;

    const r = rand();
    // Candidate: new trips for up to two drivers (+ updated unassigned list).
    let ka = -1;
    let kb = -1;
    let ta: Trips | null = null;
    let tb: Trips | null = null;
    let newUnassigned: number[] | null = null;

    if (r < 0.45 || p.n < 2) {
      // Relocate a random order to a random slot.
      const o = ri(p.n);
      const loc = locate(cur, o);
      const target = ri(p.m);
      if (loc.k >= 0) {
        ka = loc.k;
        ta = cloneTrips(cur.sched[ka]);
        ta[loc.j].splice(loc.s, 1);
        ta = dropEmpty(ta);
      } else {
        newUnassigned = cur.unassigned.slice();
        newUnassigned.splice(loc.s, 1);
      }
      let dst: Trips = target === ka ? ta! : cloneTrips(cur.sched[target]);
      const slots = dst.reduce((acc, t) => acc + t.length + 1, 0) + dst.length + 1;
      let slot = ri(slots);
      let done = false;
      for (let j = 0; j < dst.length && !done; j++) {
        if (slot <= dst[j].length) {
          dst[j].splice(slot, 0, o);
          done = true;
        } else slot -= dst[j].length + 1;
      }
      if (!done) dst.splice(Math.min(slot, dst.length), 0, [o]);
      if (target === ka) ta = dst;
      else {
        kb = target;
        tb = dst;
      }
    } else if (r < 0.65) {
      // Swap two orders.
      const a = ri(p.n);
      const b = ri(p.n);
      if (a === b) continue;
      const la = locate(cur, a);
      const lb = locate(cur, b);
      if (la.k < 0 || lb.k < 0) continue;
      ka = la.k;
      ta = cloneTrips(cur.sched[ka]);
      if (lb.k === ka) {
        ta[la.j][la.s] = b;
        ta[lb.j][lb.s] = a;
      } else {
        kb = lb.k;
        tb = cloneTrips(cur.sched[kb]);
        ta[la.j][la.s] = b;
        tb[lb.j][lb.s] = a;
      }
    } else if (r < 0.8) {
      // 2-opt inside a tour.
      ka = ri(p.m);
      const trips = cur.sched[ka];
      if (trips.length === 0) continue;
      const j = ri(trips.length);
      const len = trips[j].length;
      if (len < 2) continue;
      const x = ri(len - 1);
      const y = x + 1 + ri(len - 1 - x);
      ta = cloneTrips(trips);
      const seg = ta[j].slice(x, y + 1).reverse();
      ta[j].splice(x, y - x + 1, ...seg);
    } else if (r < 0.88) {
      // Split a tour.
      ka = ri(p.m);
      const trips = cur.sched[ka];
      if (trips.length === 0) continue;
      const j = ri(trips.length);
      if (trips[j].length < 2) continue;
      ta = cloneTrips(trips);
      const tail = ta[j].splice(1 + ri(trips[j].length - 1));
      ta.splice(j + 1, 0, tail);
    } else if (r < 0.96) {
      // Merge two consecutive tours.
      ka = ri(p.m);
      const trips = cur.sched[ka];
      if (trips.length < 2) continue;
      const j = ri(trips.length - 1);
      ta = cloneTrips(trips);
      ta[j] = ta[j].concat(ta[j + 1]);
      ta.splice(j + 1, 1);
    } else {
      // Hand a whole tour to another driver.
      if (p.m < 2) continue;
      ka = ri(p.m);
      if (cur.sched[ka].length === 0) continue;
      kb = (ka + 1 + ri(p.m - 1)) % p.m;
      ta = cloneTrips(cur.sched[ka]);
      const [tour] = ta.splice(ri(ta.length), 1);
      tb = cloneTrips(cur.sched[kb]);
      tb.splice(ri(tb.length + 1), 0, tour);
    }

    let delta = 0;
    let ca = 0;
    let cb = 0;
    if (ka >= 0) {
      ca = driverCost(p, ka, ta!);
      delta += ca - cur.costs[ka];
    }
    if (kb >= 0) {
      cb = driverCost(p, kb, tb!);
      delta += cb - cur.costs[kb];
    }
    if (newUnassigned) delta -= UNASSIGNED_PENALTY;

    if (delta < 0 || rand() < Math.exp(-delta / T)) {
      if (ka >= 0) {
        cur.sched[ka] = ta!;
        cur.costs[ka] = ca;
      }
      if (kb >= 0) {
        cur.sched[kb] = tb!;
        cur.costs[kb] = cb;
      }
      if (newUnassigned) cur.unassigned = newUnassigned;
      cur.total += delta;
      if (cur.total < best.total - EPS) best = cloneState(cur);
    }
  }

  return { best, iterations };
}

// ============================================================
// EXACT ENUMERATION (small instances)
// ============================================================

/** Number of single-driver schedules over all subsets: Σ C(n,s)·s!·2^(s−1). */
function exactWork(n: number, m: number): number {
  let total = 0;
  let binom = 1;
  let fact = 1;
  for (let s = 1; s <= n; s++) {
    binom = (binom * (n - s + 1)) / s;
    fact *= s;
    total += binom * fact * Math.pow(2, s - 1);
  }
  return total * m + Math.pow(m + 1, n);
}

function* permutationsOf(items: number[]): Generator<number[]> {
  const a = items.slice();
  const c = new Array(a.length).fill(0);
  yield a.slice();
  let i = 0;
  while (i < a.length) {
    if (c[i] < i) {
      const k = i % 2 === 0 ? 0 : c[i];
      [a[k], a[i]] = [a[i], a[k]];
      yield a.slice();
      c[i]++;
      i = 0;
    } else {
      c[i] = 0;
      i++;
    }
  }
}

function exact(p: Problem): { state: State; evaluations: number } {
  const full = 1 << p.n;
  let evaluations = 0;
  // best[k][mask] = cheapest schedule of exactly the orders in mask for driver k.
  const bestCost: Float64Array[] = [];
  const bestTrips: (Trips | null)[][] = [];

  for (let k = 0; k < p.m; k++) {
    const costs = new Float64Array(full);
    const trips: (Trips | null)[] = new Array(full).fill(null);
    costs[0] = driverCost(p, k, []);
    trips[0] = [];
    for (let mask = 1; mask < full; mask++) {
      const members: number[] = [];
      let skip = false;
      for (let i = 0; i < p.n; i++) {
        if (mask & (1 << i)) {
          if (p.pinned[i] >= 0 && p.pinned[i] !== k) skip = true;
          members.push(i);
        }
      }
      if (skip) {
        costs[mask] = Infinity;
        continue;
      }
      let bc = Infinity;
      let bt: Trips | null = null;
      const cuts = 1 << (members.length - 1);
      for (const perm of permutationsOf(members)) {
        for (let cut = 0; cut < cuts; cut++) {
          const t: Trips = [[perm[0]]];
          for (let s = 1; s < perm.length; s++) {
            if (cut & (1 << (s - 1))) t.push([perm[s]]);
            else t[t.length - 1].push(perm[s]);
          }
          const c = driverCost(p, k, t);
          evaluations++;
          if (c < bc) {
            bc = c;
            bt = t;
          }
        }
      }
      costs[mask] = bc;
      trips[mask] = bt;
    }
    bestCost.push(costs);
    bestTrips.push(trips);
  }

  // Assign every order to a driver or leave it unassigned; driver costs are independent.
  let best = Infinity;
  const bestAssign = new Int32Array(p.n).fill(-1);
  const assign = new Int32Array(p.n);
  const masks = new Int32Array(p.m);
  const rec = (i: number, unassigned: number) => {
    if (i === p.n) {
      let c = unassigned * UNASSIGNED_PENALTY;
      for (let k = 0; k < p.m; k++) c += bestCost[k][masks[k]];
      if (c < best - EPS) {
        best = c;
        bestAssign.set(assign);
      }
      return;
    }
    for (let k = 0; k <= p.m; k++) {
      if (k < p.m) {
        if (p.pinned[i] >= 0 && p.pinned[i] !== k) continue;
        assign[i] = k;
        masks[k] |= 1 << i;
        rec(i + 1, unassigned);
        masks[k] &= ~(1 << i);
      } else {
        assign[i] = -1;
        rec(i + 1, unassigned + 1);
      }
    }
  };
  rec(0, 0);

  const sched: Trips[] = [];
  const unassigned: number[] = [];
  const finalMasks = new Int32Array(p.m);
  for (let i = 0; i < p.n; i++) {
    const k = bestAssign[i];
    if (k < 0) unassigned.push(i);
    else finalMasks[k] |= 1 << i;
  }
  for (let k = 0; k < p.m; k++) sched.push(cloneTrips(bestTrips[k][finalMasks[k]] ?? []));
  return { state: makeState(p, sched, unassigned), evaluations };
}

// ============================================================
// SCHEDULE → OUTPUT
// ============================================================

interface TripTimeline {
  departure: number;
  arrivals: number[];
  returnAt: number;
  driveSecs: number;
  distMeters: number;
}

function timeline(p: Problem, k: number, trips: Trips): TripTimeline[] {
  const out: TripTimeline[] = [];
  let t = p.avail[k];
  for (const trip of trips) {
    let dep = t;
    for (const o of trip) if (p.ready[o] > dep) dep = p.ready[o];
    let cur = dep;
    let prev = 0;
    let driveSecs = 0;
    let distMeters = 0;
    const arrivals: number[] = [];
    for (const o of trip) {
      const d = p.dur[prev * p.N + o + 1];
      cur += d * 1000;
      driveSecs += d;
      distMeters += p.dist[prev * p.N + o + 1];
      arrivals.push(cur);
      cur += p.handoverMs;
      prev = o + 1;
    }
    cur += p.dur[prev * p.N] * 1000;
    driveSecs += p.dur[prev * p.N];
    distMeters += p.dist[prev * p.N];
    out.push({ departure: dep, arrivals, returnAt: cur, driveSecs, distMeters });
    t = cur;
  }
  return out;
}

function breakdown(p: Problem, st: State, orders: PlannerOrder[]): CostBreakdown {
  const perOrder: OrderCost[] = [];
  let driveSecs = 0;
  let idleMs = 0;
  for (let k = 0; k < p.m; k++) {
    const tl = timeline(p, k, st.sched[k]);
    st.sched[k].forEach((trip, j) => {
      driveSecs += tl[j].driveSecs;
      trip.forEach((o, s) => {
        const arr = tl[j].arrivals[s];
        idleMs += Math.max(0, tl[j].departure - Math.max(p.ready[o], p.avail[k]));
        perOrder.push({
          orderId: orders[o].id,
          latenessMinutes: Math.max(0, (arr - p.target[o]) / 60_000),
          earlinessMinutes: p.isPre[o] ? Math.max(0, (p.target[o] - p.preGraceMs - arr) / 60_000) : 0,
          cost: orderCost(p, o, arr, tl[j].departure),
        });
      });
    });
  }
  return {
    totalCost: st.total,
    perOrder,
    totalDrivingMinutes: driveSecs / 60,
    totalIdleMinutes: idleMs / 60_000,
    unassignedCount: st.unassigned.length,
  };
}

// ============================================================
// MAIN SOLVER ENTRY POINT
// ============================================================

/** Orders the planner should schedule now (food ready within the planning horizon). */
export function isActionable(o: PlannerOrder, settings: PlannerSettings, now: Date): boolean {
  if (o.deliveryStatus === "assigned_to_route") return true;
  const nowMs = now.getTime();
  if (readyTimeMs(o, nowMs) > nowMs + settings.planningHorizonSecs * 1000) return false;
  if (o.requestedDeliveryTime) {
    const secsUntilTarget = (o.requestedDeliveryTime.getTime() - nowMs) / 1000;
    if (secsUntilTarget > settings.planningHorizonSecs + settings.preorderEarlyGraceSecs) return false;
  }
  return true;
}

/**
 * Solve the delivery routing problem.
 *
 * @param orders       All candidate orders; matrix row i + 1 belongs to orders[i]
 * @param drivers      Drivers that may receive new tours
 * @param matrix       Travel time matrix (row/column 0 = restaurant)
 * @param settings     Planner tuning parameters
 * @param now          Current timestamp
 * @param planVersion  Current plan version number
 */
export function solve(
  orders: PlannerOrder[],
  drivers: PlannerDriver[],
  matrix: TravelTimeMatrix,
  settings: PlannerSettings,
  now: Date,
  planVersion: number,
  seed = 1,
): PlanResult {
  const startMs = Date.now();

  const actionableIdx: number[] = [];
  orders.forEach((o, i) => {
    if (isActionable(o, settings, now)) actionableIdx.push(i);
  });
  const active = actionableIdx.map((i) => orders[i]);

  const empty = (): PlanResult => ({
    routes: [],
    trips: [],
    unassignedOrderIds: drivers.length === 0 ? active.map((o) => o.id) : [],
    costBreakdown: {
      totalCost: 0,
      perOrder: [],
      totalDrivingMinutes: 0,
      totalIdleMinutes: 0,
      unassignedCount: drivers.length === 0 ? active.length : 0,
    },
    planVersion: planVersion + 1,
    solverTimeMs: Date.now() - startMs,
    method: "empty",
    evaluations: 0,
  });
  if (active.length === 0 || drivers.length === 0) return empty();

  const p = buildProblem(
    active,
    actionableIdx.map((i) => i + 1),
    drivers,
    matrix,
    settings,
    now,
  );

  let best: State;
  let method: PlanResult["method"];
  let evaluations = 0;

  const threshold = Math.min(settings.exhaustiveThreshold ?? 6, 8);
  if (p.n <= threshold && exactWork(p.n, p.m) <= 400_000) {
    const res = exact(p);
    best = res.state;
    evaluations = res.evaluations;
    method = "exact";
  } else {
    const budget = Math.max(150, settings.solverTimeLimitMs || 0);
    const deadline = startMs + budget;
    const seeded = construct(p, active, true);
    const fresh = construct(p, active, false);
    best = seeded.total <= fresh.total ? seeded : fresh;

    // Two annealing runs from different starts, each polished to a local optimum.
    const half = startMs + budget * 0.45;
    const runA = anneal(p, seeded, half, seed);
    const a = polish(p, runA.best, half + budget * 0.05);
    const runB = anneal(p, fresh, deadline - budget * 0.05, seed * 7919 + 13);
    const b = polish(p, runB.best, deadline);
    evaluations = runA.iterations + runB.iterations;
    for (const cand of [a, b]) if (cand.total < best.total - EPS) best = cand;
    method = "search";
  }

  // ---- Convert to output ----
  const trips: PlannedRoute[] = [];
  for (let k = 0; k < p.m; k++) {
    const tl = timeline(p, k, best.sched[k]);
    best.sched[k].forEach((trip, j) => {
      const stops: PlannedStop[] = [];
      stops.push({
        orderId: null,
        type: "store",
        location: settings.storeLocation,
        customerName: null,
        customerAddress: null,
        matrixIndex: 0,
        plannedArrivalAt: new Date(tl[j].departure),
        targetTime: null,
        isReady: true,
      });
      trip.forEach((o, s) => {
        const order = active[o];
        stops.push({
          orderId: order.id,
          type: "customer_delivery",
          location: order.location,
          customerName: order.customerName,
          customerAddress: order.customerAddress,
          matrixIndex: actionableIdx[o] + 1,
          plannedArrivalAt: new Date(tl[j].arrivals[s]),
          targetTime: order.requestedDeliveryTime ?? order.targetDeliveryTime,
          isReady: p.ready[o] <= now.getTime(),
        });
      });
      stops.push({
        orderId: null,
        type: "store",
        location: settings.storeLocation,
        customerName: null,
        customerAddress: null,
        matrixIndex: 0,
        plannedArrivalAt: new Date(tl[j].returnAt),
        targetTime: null,
        isReady: true,
      });
      trips.push({
        driverId: drivers[k].id,
        stops,
        totalDrivingSeconds: tl[j].driveSecs,
        totalDistanceMeters: Math.round(tl[j].distMeters),
        plannedDepartureAt: new Date(tl[j].departure),
        plannedReturnAt: new Date(tl[j].returnAt),
        tripIndex: j,
      });
    });
  }

  return {
    routes: trips.filter((t) => t.tripIndex === 0),
    trips,
    unassignedOrderIds: best.unassigned.map((o) => active[o].id),
    costBreakdown: breakdown(p, best, active),
    planVersion: planVersion + 1,
    solverTimeMs: Date.now() - startMs,
    method,
    evaluations,
  };
}

// Exposed for tests: cost of an explicit schedule, and the exact optimum.
export const __test = {
  buildProblem,
  driverCost,
  exactOptimum(p: Problem): number {
    return exact(p).state.total;
  },
  scheduleCost(p: Problem, sched: number[][][], unassigned: number[] = []): number {
    return makeState(p, sched, unassigned).total;
  },
  searchOnly(p: Problem, orders: PlannerOrder[], budgetMs: number, seed = 1): number {
    const start = Date.now();
    const seeded = construct(p, orders, true);
    const fresh = construct(p, orders, false);
    let best = seeded.total <= fresh.total ? seeded : fresh;
    const half = start + budgetMs / 2;
    const a = polish(p, anneal(p, seeded, half, seed).best, half + 5);
    const b = polish(p, anneal(p, fresh, start + budgetMs, seed + 1).best, start + budgetMs + 5);
    for (const c of [a, b]) if (c.total < best.total) best = c;
    return best.total;
  },
};
