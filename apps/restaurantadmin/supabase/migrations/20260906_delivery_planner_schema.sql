-- =============================================================
-- Delivery Route Planner Schema
-- Creates tables for settings, travel-time cache, and plan log.
-- Adds columns to existing delivery_routes, route_stops, orders, drivers.
-- =============================================================

-- 1. delivery_settings — tunable planner parameters
CREATE TABLE IF NOT EXISTS delivery_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,

  -- Cost function weights
  late_weight        NUMERIC NOT NULL DEFAULT 10,
  early_weight       NUMERIC NOT NULL DEFAULT 1,
  drive_weight       NUMERIC NOT NULL DEFAULT 0.5,
  idle_weight        NUMERIC NOT NULL DEFAULT 2,
  unassigned_weight  NUMERIC NOT NULL DEFAULT 50,

  -- Timing parameters (seconds)
  handover_time_secs         INT NOT NULL DEFAULT 300,    -- 5 min at each customer stop
  early_grace_secs           INT NOT NULL DEFAULT 600,    -- 10 min early is OK
  preorder_early_grace_secs  INT NOT NULL DEFAULT 900,    -- 15 min early for pre-orders
  bundling_wait_secs         INT NOT NULL DEFAULT 240,    -- Wait up to 4 min to bundle
  planning_horizon_secs      INT NOT NULL DEFAULT 2700,   -- Look 45 min ahead for in-prep orders

  -- Speed fallback when API fails
  city_speed_kmh  NUMERIC NOT NULL DEFAULT 25,

  -- Solver limits
  max_route_duration_secs  INT NOT NULL DEFAULT 3600,     -- 1 hour max per route
  solver_time_limit_ms     INT NOT NULL DEFAULT 200,      -- Local search budget
  exhaustive_threshold     INT NOT NULL DEFAULT 6,        -- Brute-force if ≤ N unassigned

  -- Restaurant coordinates (depot)
  store_latitude   DOUBLE PRECISION NOT NULL DEFAULT 47.81328,
  store_longitude  DOUBLE PRECISION NOT NULL DEFAULT 13.06882,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(brand_id)
);

-- Enable RLS
ALTER TABLE delivery_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated on delivery_settings"
  ON delivery_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- 2. travel_time_cache — avoid repeated Distance Matrix calls
CREATE TABLE IF NOT EXISTS travel_time_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_lat_bucket    NUMERIC NOT NULL,   -- rounded to 3 decimals (~111m)
  origin_lng_bucket    NUMERIC NOT NULL,
  dest_lat_bucket      NUMERIC NOT NULL,
  dest_lng_bucket      NUMERIC NOT NULL,
  hour_bucket          INT NOT NULL,        -- 0-23
  duration_seconds     INT NOT NULL,
  distance_meters      INT NOT NULL,
  fetched_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(origin_lat_bucket, origin_lng_bucket, dest_lat_bucket, dest_lng_bucket, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_ttc_lookup
  ON travel_time_cache(origin_lat_bucket, origin_lng_bucket, dest_lat_bucket, dest_lng_bucket, hour_bucket);

ALTER TABLE travel_time_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for service_role on travel_time_cache"
  ON travel_time_cache FOR ALL USING (true) WITH CHECK (true);


-- 3. plan_log — audit trail for planning decisions
CREATE TABLE IF NOT EXISTS plan_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID REFERENCES brands(id) ON DELETE SET NULL,
  plan_version INT NOT NULL,
  trigger_reason TEXT,
  cost_breakdown JSONB,
  plan_snapshot JSONB,
  solver_time_ms INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plan_log_brand_version
  ON plan_log(brand_id, plan_version DESC);

ALTER TABLE plan_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated on plan_log"
  ON plan_log FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- 4. Alter delivery_routes — add plan tracking columns
ALTER TABLE delivery_routes ADD COLUMN IF NOT EXISTS plan_version INT DEFAULT 0;
ALTER TABLE delivery_routes ADD COLUMN IF NOT EXISTS planned_departure_at TIMESTAMPTZ;
ALTER TABLE delivery_routes ADD COLUMN IF NOT EXISTS planned_return_at TIMESTAMPTZ;
ALTER TABLE delivery_routes ADD COLUMN IF NOT EXISTS actual_departure_at TIMESTAMPTZ;
ALTER TABLE delivery_routes ADD COLUMN IF NOT EXISTS actual_return_at TIMESTAMPTZ;


-- 5. Alter route_stops — add planned_arrival_at
ALTER TABLE route_stops ADD COLUMN IF NOT EXISTS planned_arrival_at TIMESTAMPTZ;


-- 6. Alter orders — add planned_arrival_at
ALTER TABLE orders ADD COLUMN IF NOT EXISTS planned_arrival_at TIMESTAMPTZ;


-- 7. Alter drivers — add projected_return_at and employee_id FK
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS projected_return_at TIMESTAMPTZ;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employees(id) ON DELETE SET NULL;


-- 8. Seed default delivery_settings for the first brand
INSERT INTO delivery_settings (brand_id, store_latitude, store_longitude)
SELECT id, 47.81328, 13.06882
FROM brands
LIMIT 1
ON CONFLICT (brand_id) DO NOTHING;
