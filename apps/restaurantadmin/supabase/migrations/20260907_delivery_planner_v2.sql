-- =============================================================
-- Delivery Planner Schema V2
-- Adds max_stops_per_route, auto_assign_delay_secs to delivery_settings
-- Adds confirmed_at to delivery_routes
-- =============================================================

-- 1. Add max_stops_per_route to delivery_settings
ALTER TABLE delivery_settings
  ADD COLUMN IF NOT EXISTS max_stops_per_route INT NOT NULL DEFAULT 3;

-- 2. Add auto_assign_delay_secs to delivery_settings
ALTER TABLE delivery_settings
  ADD COLUMN IF NOT EXISTS auto_assign_delay_secs INT NOT NULL DEFAULT 60;

-- 3. Add confirmed_at to delivery_routes (for suggest → confirm flow)
ALTER TABLE delivery_routes
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;

-- 4. Add target_delivery_time to route_stops for display purposes
ALTER TABLE route_stops
  ADD COLUMN IF NOT EXISTS target_delivery_time TIMESTAMPTZ;
