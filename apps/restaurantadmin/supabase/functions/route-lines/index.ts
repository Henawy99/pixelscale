// supabase/functions/route-lines/index.ts
// Street geometry for the Map tab's tour lines.
//
//   POST { legs: [{ from: {lat, lng}, to: {lat, lng} }, ...] }   (at most 40 legs)
//   → { legs: [{ polyline: string | null, retry?: true }, ...] }  same order; Google encoded polyline
//
// Each leg is looked up in route_leg_cache first (coordinates rounded to 5 decimals, ~1 m) and
// only asked from Google when missing: the Directions API, or the Routes API if Directions is
// not enabled for the key. A leg with no road (or not ours to route) comes back as null and the
// app draws it straight; `retry: true` means Google failed for now and the app asks again later.
// Auth: a signed-in admin or manager (profiles.role), so the Google key can't be used by anyone
// holding the public anon key. The service-role key is accepted too (server jobs, tests).

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const MAX_LEGS = 40;
/** Legs longer than this (straight line) are not ours: the delivery area is a few km wide. */
const MAX_LEG_METERS = 80_000;
const PARALLEL = 6;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LatLng {
  lat: number;
  lng: number;
}

interface Road {
  polyline: string;
  distanceMeters: number | null;
  durationSeconds: number | null;
  source: string;
}

/** No road between the two points: a final answer, unlike a failed request. */
const NO_ROAD = "no-road" as const;
type Answer = Road | typeof NO_ROAD | null; // null = failed, try again later

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

/** The rounding of the cache columns (numeric(8, 5)), as the same text Postgres prints. */
const fixed5 = (n: number) => n.toFixed(5);

function isLatLng(p: unknown): p is LatLng {
  const q = p as LatLng;
  return !!q && Number.isFinite(q.lat) && Number.isFinite(q.lng) && Math.abs(q.lat) <= 90 && Math.abs(q.lng) <= 180;
}

function haversineMeters(a: LatLng, b: LatLng): number {
  const r = 6371000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

/** Same text as the generated route_leg_cache.leg_key column. */
const keyOf = (a: LatLng, b: LatLng) => `${fixed5(a.lat)},${fixed5(a.lng)}>${fixed5(b.lat)},${fixed5(b.lng)}`;

/** Legacy Directions API: the same API family as the planner's Distance Matrix. */
async function fromDirections(a: LatLng, b: LatLng, key: string): Promise<Answer | "denied"> {
  const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${a.lat},${a.lng}` +
    `&destination=${b.lat},${b.lng}&mode=driving&key=${key}`;
  const resp = await fetch(url);
  if (!resp.ok) return null;
  const data = await resp.json();
  if (data.status === "REQUEST_DENIED") {
    console.warn("[route-lines] Directions API denied:", data.error_message ?? "");
    return "denied";
  }
  if (data.status === "ZERO_RESULTS" || data.status === "NOT_FOUND") return NO_ROAD;
  const route = data.routes?.[0];
  if (data.status !== "OK" || !route?.overview_polyline?.points) {
    console.warn("[route-lines] Directions answered", data.status, data.error_message ?? "");
    return null;
  }
  const legs = (route.legs ?? []) as { distance?: { value: number }; duration?: { value: number } }[];
  return {
    polyline: route.overview_polyline.points,
    distanceMeters: legs.reduce((s, l) => s + (l.distance?.value ?? 0), 0) || null,
    durationSeconds: legs.reduce((s, l) => s + (l.duration?.value ?? 0), 0) || null,
    source: "directions",
  };
}

/** Routes API (computeRoutes), for keys where only the newer API is enabled. */
async function fromRoutes(a: LatLng, b: LatLng, key: string): Promise<Answer> {
  const resp = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask": "routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration",
    },
    body: JSON.stringify({
      origin: { location: { latLng: { latitude: a.lat, longitude: a.lng } } },
      destination: { location: { latLng: { latitude: b.lat, longitude: b.lng } } },
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_UNAWARE",
      polylineEncoding: "ENCODED_POLYLINE",
    }),
  });
  if (!resp.ok) {
    console.warn("[route-lines] Routes API failed:", resp.status, (await resp.text()).slice(0, 300));
    return null;
  }
  const data = await resp.json();
  const route = data.routes?.[0];
  // An empty answer from the Routes API means there is no route.
  if (!route) return NO_ROAD;
  if (!route.polyline?.encodedPolyline) return null;
  return {
    polyline: route.polyline.encodedPolyline,
    distanceMeters: route.distanceMeters ?? null,
    durationSeconds: route.duration ? parseInt(String(route.duration), 10) || null : null,
    source: "routes",
  };
}

let directionsDenied = false;

async function fetchRoad(a: LatLng, b: LatLng, key: string): Promise<Answer> {
  try {
    if (!directionsDenied) {
      const r = await fromDirections(a, b, key);
      if (r !== "denied") return r;
      directionsDenied = true;
    }
    return await fromRoutes(a, b, key);
  } catch (err) {
    console.error("[route-lines] Google request failed:", err);
    return null;
  }
}

async function callerIsAdmin(req: Request, admin: SupabaseClient): Promise<boolean> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return false;
  if (token === Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) return true;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) return false;
  const { data: profile } = await admin.from("profiles").select("role").eq("id", data.user.id).maybeSingle();
  return ["admin", "manager"].includes(profile?.role ?? "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const db = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
  if (!(await callerIsAdmin(req, db))) return json({ error: "Unauthorized" }, 401);

  let body: { legs?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const raw = Array.isArray(body.legs) ? body.legs : [];
  if (raw.length > MAX_LEGS) return json({ error: `At most ${MAX_LEGS} legs` }, 400);
  const legs = raw.map((l) => {
    const leg = l as { from?: unknown; to?: unknown };
    return isLatLng(leg?.from) && isLatLng(leg?.to) && haversineMeters(leg.from, leg.to) <= MAX_LEG_METERS
      ? { from: leg.from, to: leg.to }
      : null;
  });

  // 1. Cache.
  const wanted = new Map<string, { from: LatLng; to: LatLng }>();
  for (const l of legs) if (l) wanted.set(keyOf(l.from, l.to), l);
  // Legs with an answer: a polyline, or "" for "nothing to draw" (no road, same place).
  const found = new Map<string, string>();
  if (wanted.size > 0) {
    const { data, error } = await db
      .from("route_leg_cache")
      .select("leg_key, polyline")
      .in("leg_key", [...wanted.keys()]);
    if (error) console.error("[route-lines] cache read failed:", error.message);
    for (const row of data ?? []) found.set(row.leg_key, row.polyline);
  }

  // 2. Google for the rest.
  const missing = [...wanted.entries()].filter(([k]) => !found.has(k));
  const key = Deno.env.get("GOOGLE_MAPS_API_KEY");
  if (missing.length > 0 && key) {
    const fresh: Record<string, unknown>[] = [];
    for (let i = 0; i < missing.length; i += PARALLEL) {
      await Promise.all(missing.slice(i, i + PARALLEL).map(async ([k, l]) => {
        if (haversineMeters(l.from, l.to) < 15) {
          found.set(k, ""); // Same place: nothing to draw.
          return;
        }
        const road = await fetchRoad(l.from, l.to, key);
        if (road === null) return; // Failed: the app asks again later.
        if (road === NO_ROAD) {
          found.set(k, "");
          return;
        }
        found.set(k, road.polyline);
        fresh.push({
          // Strings, so Postgres stores exactly the rounding used in leg_key.
          from_lat: fixed5(l.from.lat),
          from_lng: fixed5(l.from.lng),
          to_lat: fixed5(l.to.lat),
          to_lng: fixed5(l.to.lng),
          polyline: road.polyline,
          distance_meters: road.distanceMeters,
          duration_seconds: road.durationSeconds,
          source: road.source,
          fetched_at: new Date().toISOString(),
        });
      }));
    }
    if (fresh.length > 0) {
      const { error } = await db.from("route_leg_cache").upsert(fresh, { onConflict: "from_lat,from_lng,to_lat,to_lng" });
      if (error) console.error("[route-lines] cache write failed:", error.message);
    }
    console.log(`[route-lines] ${wanted.size} legs: ${wanted.size - missing.length} cached, ${fresh.length} from Google`);
  } else if (missing.length > 0) {
    console.warn("[route-lines] No GOOGLE_MAPS_API_KEY — straight lines only");
  }

  return json({
    legs: legs.map((l) => {
      if (!l) return { polyline: null };
      const p = found.get(keyOf(l.from, l.to));
      if (p === undefined) return { polyline: null, retry: true };
      return { polyline: p === "" ? null : p };
    }),
  });
});
