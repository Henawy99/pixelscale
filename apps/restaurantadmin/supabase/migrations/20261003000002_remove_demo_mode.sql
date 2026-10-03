-- =============================================================
-- Production only: the demo mode is gone
--
-- The app's LIVE/DEMO switch, the demo driver and create-demo-order created fake orders and tours
-- (is_demo = true) that the planner handled separately. That is removed from the app and the edge
-- functions; this deletes the remaining demo data and makes sure none can be created again.
-- The is_demo columns stay (always false) because the dispatch functions still filter on them.
-- =============================================================

DELETE FROM delivery_routes WHERE is_demo;   -- route_stops follow (ON DELETE CASCADE)
DELETE FROM orders WHERE is_demo;            -- order_items follow (ON DELETE CASCADE)
DELETE FROM planner_lock WHERE mode = 'demo';

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_no_demo;
ALTER TABLE orders ADD CONSTRAINT orders_no_demo CHECK (NOT COALESCE(is_demo, FALSE));
ALTER TABLE delivery_routes DROP CONSTRAINT IF EXISTS delivery_routes_no_demo;
ALTER TABLE delivery_routes ADD CONSTRAINT delivery_routes_no_demo CHECK (NOT COALESCE(is_demo, FALSE));
ALTER TABLE drivers DROP CONSTRAINT IF EXISTS drivers_no_demo;
ALTER TABLE drivers ADD CONSTRAINT drivers_no_demo CHECK (NOT COALESCE(is_demo, FALSE));
