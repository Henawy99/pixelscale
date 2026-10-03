-- route-lines looks legs up by their exact key instead of every row with the same origin latitude
-- (every tour starts at the restaurant, so that set only grows).
ALTER TABLE public.route_leg_cache
  ADD COLUMN IF NOT EXISTS leg_key text
  GENERATED ALWAYS AS (from_lat::text || ',' || from_lng::text || '>' || to_lat::text || ',' || to_lng::text) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS route_leg_cache_leg_key ON public.route_leg_cache (leg_key);
