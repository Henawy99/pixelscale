// supabase/functions/plan-routes/travel_time.ts
// Builds a travel-time matrix using Google Distance Matrix API with caching.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import type { LatLng, TravelTime, TravelTimeMatrix, PlannerSettings } from "./types.ts";

/** Round coordinate to 3 decimal places (~111m bucket). */
function bucket(coord: number): number {
  return Math.round(coord * 1000) / 1000;
}

/** Haversine distance in meters. */
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

interface CacheKey {
  originLatBucket: number;
  originLngBucket: number;
  destLatBucket: number;
  destLngBucket: number;
  hourBucket: number;
}

function makeCacheKey(from: LatLng, to: LatLng, hour: number): CacheKey {
  return {
    originLatBucket: bucket(from.lat),
    originLngBucket: bucket(from.lng),
    destLatBucket: bucket(to.lat),
    destLngBucket: bucket(to.lng),
    hourBucket: hour,
  };
}

/**
 * Look up cached travel times from the database.
 * Returns a Map keyed by "olat,olng,dlat,dlng,h" → TravelTime.
 */
async function fetchCached(
  supabase: SupabaseClient,
  keys: CacheKey[]
): Promise<Map<string, TravelTime>> {
  const result = new Map<string, TravelTime>();
  if (keys.length === 0) return result;

  // Batch query: fetch all matching rows
  // Build an OR filter for each key
  const filters = keys.map(
    (k) =>
      `origin_lat_bucket.eq.${k.originLatBucket},origin_lng_bucket.eq.${k.originLngBucket},dest_lat_bucket.eq.${k.destLatBucket},dest_lng_bucket.eq.${k.destLngBucket},hour_bucket.eq.${k.hourBucket}`
  );

  // Supabase doesn't support complex OR on multiple columns easily,
  // so we query for each unique key. For our scale (<100 pairs) this is fine.
  for (const k of keys) {
    const { data, error } = await supabase
      .from("travel_time_cache")
      .select("duration_seconds, distance_meters")
      .eq("origin_lat_bucket", k.originLatBucket)
      .eq("origin_lng_bucket", k.originLngBucket)
      .eq("dest_lat_bucket", k.destLatBucket)
      .eq("dest_lng_bucket", k.destLngBucket)
      .eq("hour_bucket", k.hourBucket)
      .limit(1)
      .maybeSingle();

    if (!error && data) {
      const key = `${k.originLatBucket},${k.originLngBucket},${k.destLatBucket},${k.destLngBucket},${k.hourBucket}`;
      result.set(key, {
        durationSeconds: data.duration_seconds,
        distanceMeters: data.distance_meters,
      });
    }
  }

  return result;
}

/** Store travel times in the cache. */
async function storeInCache(
  supabase: SupabaseClient,
  entries: { key: CacheKey; tt: TravelTime }[]
): Promise<void> {
  if (entries.length === 0) return;

  const rows = entries.map((e) => ({
    origin_lat_bucket: e.key.originLatBucket,
    origin_lng_bucket: e.key.originLngBucket,
    dest_lat_bucket: e.key.destLatBucket,
    dest_lng_bucket: e.key.destLngBucket,
    hour_bucket: e.key.hourBucket,
    duration_seconds: e.tt.durationSeconds,
    distance_meters: e.tt.distanceMeters,
  }));

  const { error } = await supabase
    .from("travel_time_cache")
    .upsert(rows, {
      onConflict:
        "origin_lat_bucket,origin_lng_bucket,dest_lat_bucket,dest_lng_bucket,hour_bucket",
    });

  if (error) {
    console.error("Failed to cache travel times:", error);
  }
}

/**
 * Fetch travel times from Google Distance Matrix API.
 * origins and destinations are arrays of LatLng.
 * Returns a 2D array: result[originIdx][destIdx] = TravelTime.
 */
async function fetchFromGoogleDistanceMatrix(
  origins: LatLng[],
  destinations: LatLng[],
  apiKey: string,
  citySpeedKmh: number
): Promise<TravelTime[][]> {
  if (origins.length === 0 || destinations.length === 0) return [];

  const originsStr = origins.map((o) => `${o.lat},${o.lng}`).join("|");
  const destsStr = destinations.map((d) => `${d.lat},${d.lng}`).join("|");

  const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originsStr}&destinations=${destsStr}&mode=driving&key=${apiKey}`;

  try {
    const resp = await fetch(url);
    if (!resp.ok) {
      console.error(`Distance Matrix HTTP ${resp.status}`);
      throw new Error(`HTTP ${resp.status}`);
    }

    const data = await resp.json();
    if (data.status !== "OK") {
      console.error("Distance Matrix API error:", data.status, data.error_message);
      throw new Error(`API status: ${data.status}`);
    }

    const result: TravelTime[][] = [];
    for (let i = 0; i < data.rows.length; i++) {
      const row: TravelTime[] = [];
      for (let j = 0; j < data.rows[i].elements.length; j++) {
        const elem = data.rows[i].elements[j];
        if (elem.status === "OK") {
          row.push({
            durationSeconds: elem.duration.value,
            distanceMeters: elem.distance.value,
          });
        } else {
          // Fallback for this pair
          console.warn(
            `Distance Matrix element [${i}][${j}] status: ${elem.status}, using haversine fallback`
          );
          row.push(haversineFallback(origins[i], destinations[j], citySpeedKmh));
        }
      }
      result.push(row);
    }
    return result;
  } catch (err) {
    console.error("Distance Matrix fetch failed, using full haversine fallback:", err);
    // Return haversine fallback for everything
    return origins.map((o) =>
      destinations.map((d) => haversineFallback(o, d, citySpeedKmh))
    );
  }
}

/**
 * Build the full NxN travel time matrix for all locations.
 * locations[0] = store, locations[1..N-1] = order delivery points.
 *
 * Uses cache where available, fetches missing from Google, caches results.
 */
export async function buildTravelTimeMatrix(
  locations: LatLng[],
  settings: PlannerSettings,
  supabase: SupabaseClient
): Promise<TravelTimeMatrix> {
  const n = locations.length;
  const now = new Date();
  const currentHour = now.getHours(); // 0-23

  // Initialize matrix
  const matrix: TravelTimeMatrix = Array.from({ length: n }, () =>
    Array.from({ length: n }, () => ({ durationSeconds: 0, distanceMeters: 0 }))
  );

  // Self-to-self is always 0
  // Build list of pairs we need
  interface PairRequest {
    fromIdx: number;
    toIdx: number;
    cacheKey: CacheKey;
    cacheKeyStr: string;
  }

  const pairs: PairRequest[] = [];
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue;
      const ck = makeCacheKey(locations[i], locations[j], currentHour);
      const ckStr = `${ck.originLatBucket},${ck.originLngBucket},${ck.destLatBucket},${ck.destLngBucket},${ck.hourBucket}`;
      pairs.push({ fromIdx: i, toIdx: j, cacheKey: ck, cacheKeyStr: ckStr });
    }
  }

  // Fetch from cache
  const uniqueKeys = [...new Map(pairs.map((p) => [p.cacheKeyStr, p.cacheKey])).values()];
  const cached = await fetchCached(supabase, uniqueKeys);

  // Fill matrix from cache and identify misses
  const missingPairs: PairRequest[] = [];
  for (const pair of pairs) {
    const cachedTT = cached.get(pair.cacheKeyStr);
    if (cachedTT) {
      matrix[pair.fromIdx][pair.toIdx] = cachedTT;
    } else {
      missingPairs.push(pair);
    }
  }

  console.log(
    `Travel time matrix: ${pairs.length} pairs, ${pairs.length - missingPairs.length} cached, ${missingPairs.length} to fetch`
  );

  if (missingPairs.length === 0) return matrix;

  // Fetch missing from Google Distance Matrix API
  const apiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  if (!apiKey) {
    console.warn("No GOOGLE_MAPS_API_KEY, using haversine fallback for all missing pairs");
    for (const pair of missingPairs) {
      matrix[pair.fromIdx][pair.toIdx] = haversineFallback(
        locations[pair.fromIdx],
        locations[pair.toIdx],
        settings.citySpeedKmh
      );
    }
    return matrix;
  }

  // Google Distance Matrix supports max 25 origins × 25 destinations per request.
  // For our scale (≤12 locations), we can do all at once.
  // But we only fetch the missing pairs. Simplest: fetch full NxN if many are missing.
  if (missingPairs.length > n) {
    // Fetch full matrix from Google
    const googleResult = await fetchFromGoogleDistanceMatrix(
      locations,
      locations,
      apiKey,
      settings.citySpeedKmh
    );

    const toCache: { key: CacheKey; tt: TravelTime }[] = [];
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        if (i === j) continue;
        if (googleResult[i] && googleResult[i][j]) {
          matrix[i][j] = googleResult[i][j];
          // Cache this result
          const ck = makeCacheKey(locations[i], locations[j], currentHour);
          toCache.push({ key: ck, tt: googleResult[i][j] });
        }
      }
    }

    await storeInCache(supabase, toCache);
  } else {
    // Fetch only missing pairs individually (small number)
    // Group by origin for efficiency
    const byOrigin = new Map<number, number[]>();
    for (const p of missingPairs) {
      if (!byOrigin.has(p.fromIdx)) byOrigin.set(p.fromIdx, []);
      byOrigin.get(p.fromIdx)!.push(p.toIdx);
    }

    const toCache: { key: CacheKey; tt: TravelTime }[] = [];
    for (const [fromIdx, toIndices] of byOrigin) {
      const origins = [locations[fromIdx]];
      const destinations = toIndices.map((j) => locations[j]);
      const result = await fetchFromGoogleDistanceMatrix(
        origins,
        destinations,
        apiKey,
        settings.citySpeedKmh
      );
      for (let dIdx = 0; dIdx < toIndices.length; dIdx++) {
        const j = toIndices[dIdx];
        if (result[0] && result[0][dIdx]) {
          matrix[fromIdx][j] = result[0][dIdx];
          const ck = makeCacheKey(locations[fromIdx], locations[j], currentHour);
          toCache.push({ key: ck, tt: result[0][dIdx] });
        }
      }
    }

    await storeInCache(supabase, toCache);
  }

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
