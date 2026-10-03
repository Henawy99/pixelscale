-- Street geometry for the Map tab's tour lines.
-- The route-lines edge function asks Google once per leg (from → to) and keeps the encoded
-- polyline here, so the same stop-to-stop leg is never paid for twice. Only the service role
-- (the edge function) reads or writes it.

CREATE TABLE IF NOT EXISTS public.route_leg_cache (
  from_lat numeric(8, 5) NOT NULL,
  from_lng numeric(8, 5) NOT NULL,
  to_lat numeric(8, 5) NOT NULL,
  to_lng numeric(8, 5) NOT NULL,
  polyline text NOT NULL,
  distance_meters integer,
  duration_seconds integer,
  source text NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (from_lat, from_lng, to_lat, to_lng)
);

ALTER TABLE public.route_leg_cache ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.route_leg_cache IS
  'Road polylines (Google encoded, precision 5) for tour legs drawn on the Map tab; filled by the route-lines edge function.';
