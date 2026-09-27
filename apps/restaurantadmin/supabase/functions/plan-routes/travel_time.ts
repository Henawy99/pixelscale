// supabase/functions/plan-routes/travel_time.ts
// Builds a travel-time matrix using Google Distance Matrix API with caching.
//
// Cache: travel_time_cache keyed by ~100 m buckets. Durations are fetched without traffic,
// so an entry from any hour is reused; the same-hour row wins when present. Entries older
// than 30 days are refreshed.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import type { LatLng, TravelTime, TravelTimeMatrix, PlannerSettings } from "./types.ts";

const CACHE_MAX_AGE_MS = 30 * 24 * 3600_000;
/** Google Distance Matrix limits: ≤25 destinations and ≤100 elements per request. */
const MAX_DESTS_PER_REQUEST = 25;

/** Round coordinate to 3 decimal places (~111m bucket). */
function bucket(coord: number): number {
  return Math.round(coord * 1000) / 1000;
}

/** Haversine distance in meters. */
export function haversineMeters(a: LatLng, b: LatLng): number {
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

/** Fallback travel time using haversine and city speed. */
export function haversineFallback(
  a: LatLng,
  b: LatLng,
  citySpeedKmh: number
): TravelTime {
  const dist = haversineMeters(a, b);
  // City driving factor: ~1.4x straight-line distance
  const roadDist = dist * 1.4;
  const speedMs = (citySpeedKmh * 1000) / 3600;
  const secs = speedMs > 0 ? roadDist / speedMs : 0;
  return {
    durationSeconds: Math.round(secs),
    distanceMeters: Math.round(roadDist),
  };
}

function pairKey(from: LatLng, to: LatLng): string {
  return `${bucket(from.lat)},${bucket(from.lng)}>${bucket(to.lat)},${bucket(to.lng)}`;
}

/**
 * One query for every cached pair among the given locations.
 * Returns pairKey → best TravelTime (same hour preferred, else most recent).
 */
async function fetchCached(
  supabase: SupabaseClient,
  locations: LatLng[],
  hour: number
): Promise<Map<string, TravelTime>> {
  const result = new Map<string, TravelTime>();
  const lats = [...new Set(locations.map((l) => bucket(l.lat)))];
  const lngs = [...new Set(locations.map((l) => bucket(l.lng)))];
  if (lats.length === 0) return result;

  const { data, error } = await supabase
    .from("travel_time_cache")
    .select("origin_lat_bucket, origin_lng_bucket, dest_lat_bucket, dest_lng_bucket, hour_bucket, duration_seconds, distance_meters, fetched_at")
    .in("origin_lat_bucket", lats)
    .in("origin_lng_bucket", lngs)
    .in("dest_lat_bucket", lats)
    .in("dest_lng_bucket", lngs)
    .gte("fetched_at", new Date(Date.now() - CACHE_MAX_AGE_MS).toISOString())
    .limit(10000);

  if (error) {
    console.error("[travel_time] cache read failed:", error.message);
    return result;
  }

  const rank = new Map<string, { sameHour: boolean; at: number }>();
  for (const row of data ?? []) {
    const key = `${Number(row.origin_lat_bucket)},${Number(row.origin_lng_bucket)}>${Number(row.dest_lat_bucket)},${Number(row.dest_lng_bucket)}`;
    const sameHour = row.hour_bucket === hour;
    const at = new Date(row.fetched_at).getTime();
    const prev = rank.get(key);
    if (!prev || (sameHour && !prev.sameHour) || (sameHour === prev.sameHour && at > prev.at)) {
      rank.set(key, { sameHour, at });
      result.set(key, { durationSeconds: row.duration_seconds, distanceMeters: row.distance_meters });
    }
  }
  return result;
}

/** Store travel times in the cache. */
async function storeInCache(
  supabase: SupabaseClient,
  entries: { from: LatLng; to: LatLng; tt: TravelTime }[],
  hour: number
): Promise<void> {
  if (entries.length === 0) return;
  const seen = new Set<string>();
  const rows = [];
  for (const e of entries) {
    const k = pairKey(e.from, e.to);
    if (seen.has(k)) continue;
    seen.add(k);
    rows.push({
      origin_lat_bucket: bucket(e.from.lat),
      origin_lng_bucket: bucket(e.from.lng),
      dest_lat_bucket: bucket(e.to.lat),
      dest_lng_bucket: bucket(e.to.lng),
      hour_bucket: hour,
      duration_seconds: e.tt.durationSeconds,
      distance_meters: e.tt.distanceMeters,
      fetched_at: new Date().toISOString(),
    });
  }

  const { error } = await supabase
    .from("travel_time_cache")
    .upsert(rows, {
      onConflict:
        "origin_lat_bucket,origin_lng_bucket,dest_lat_bucket,dest_lng_bucket,hour_bucket",
    });

  if (error) {
    console.error("[travel_time] Failed to cache travel times:", error.message);
  }
}

/**
 * One origin → up to 25 destinations from Google Distance Matrix.
 * Returns null when the request fails as a whole (caller falls back to haversine).
 */
async function fetchRow(
  origin: LatLng,
  destinations: LatLng[],
  apiKey: string
): Promise<(TravelTime | null)[] | null> {
  const destsStr = destinations.map((d) => `${d.lat},${d.lng}`).join("|");
  const url =
    `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin.lat},${origin.lng}` +
    `&destinations=${encodeURIComponent(destsStr)}&mode=driving&key=${apiKey}`;
  try {
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = await resp.json();
    if (data.status !== "OK") throw new Error(`${data.status} ${data.error_message ?? ""}`);
    return (data.rows?.[0]?.elements ?? []).map((el: any) =>
      el.status === "OK"
        ? { durationSeconds: el.duration.value, distanceMeters: el.distance.value }
        : null
    );
  } catch (err) {
    console.error("[travel_time] Distance Matrix request failed:", err);
    return null;
  }
}

/**
 * Build the full NxN travel time matrix for all locations.
 * locations[0] = store, locations[1..N-1] = order delivery points.
 *
 * Uses cache where available, fetches missing pairs from Google, caches results,
 * and falls back to a haversine estimate for anything still unknown.
 */
export async function buildTravelTimeMatrix(
  locations: LatLng[],
  settings: PlannerSettings,
  supabase: SupabaseClient
): Promise<TravelTimeMatrix> {
  const n = locations.length;
  const hour = new Date().getUTCHours();
  const matrix: TravelTimeMatrix = Array.from({ length: n }, () =>
    Array.from({ length: n }, () => ({ durationSeconds: 0, distanceMeters: 0 }))
  );

  const cached = await fetchCached(supabase, locations, hour);

  // Missing pairs grouped by origin. Points in the same bucket are treated as the same place.
  const missing = new Map<number, number[]>();
  let hits = 0;
  let total = 0;
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      total++;
      const k = pairKey(locations[i], locations[j]);
      const hit = cached.get(k);
      if (hit) {
        matrix[i][j] = hit;
        hits++;
      } else if (k.split(">")[0] === k.split(">")[1]) {
        matrix[i][j] = haversineFallback(locations[i], locations[j], settings.citySpeedKmh);
      } else {
        if (!missing.has(i)) missing.set(i, []);
        missing.get(i)!.push(j);
      }
    }
  }

  const missingCount = [...missing.values()].reduce((s, a) => s + a.length, 0);
  console.log(`[travel_time] ${total} pairs: ${hits} cached, ${missingCount} to fetch`);
  if (missingCount === 0) return matrix;

  const apiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  const toCache: { from: LatLng; to: LatLng; tt: TravelTime }[] = [];

  const jobs: Promise<void>[] = [];
  for (const [i, dests] of missing) {
    for (let c = 0; c < dests.length; c += MAX_DESTS_PER_REQUEST) {
      const chunk = dests.slice(c, c + MAX_DESTS_PER_REQUEST);
      jobs.push((async () => {
        const row = apiKey ? await fetchRow(locations[i], chunk.map((j) => locations[j]), apiKey) : null;
        chunk.forEach((j, idx) => {
          const tt = row?.[idx] ?? null;
          if (tt) {
            matrix[i][j] = tt;
            toCache.push({ from: locations[i], to: locations[j], tt });
          } else {
            matrix[i][j] = haversineFallback(locations[i], locations[j], settings.citySpeedKmh);
          }
        });
      })());
    }
  }
  await Promise.all(jobs);
  if (!apiKey) console.warn("[travel_time] No GOOGLE_MAPS_API_KEY — used haversine estimates");

  await storeInCache(supabase, toCache, hour);
  return matrix;
}

/**
 * Build a travel time matrix from a pre-built map (for testing).
 * Used by unit tests to inject deterministic travel times.
 */
export function buildTestMatrix(
  n: number,
  entries: Map<string, TravelTime>
): TravelTimeMatrix {
  const matrix: TravelTimeMatrix = Array.from({ length: n }, () =>
    Array.from({ length: n }, () => ({ durationSeconds: 0, distanceMeters: 0 }))
  );
  for (const [key, tt] of entries) {
    const [i, j] = key.split(",").map(Number);
    matrix[i][j] = tt;
  }
  return matrix;
}
