-- Migration: 20260907000008_fix_trigger_loop.sql
-- Purpose: Break the recursive trigger cascade loop between orders/delivery_routes and plan-routes.

-- 1. Fix order event trigger: DO NOT trigger on delivery_status changes (which plan-routes itself updates)
CREATE OR REPLACE FUNCTION notify_plan_routes_order_event()
RETURNS trigger AS $$
DECLARE
  supabase_url TEXT := 'https://iluhlynzkgubtaswvgwt.supabase.co';
  service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODU2NjY1NCwiZXhwIjoyMDY0MTQyNjU0fQ.37EjOyT9otsKJx9lsEI1xzZjMvz8XGOucyi35ePUq_8';
  should_trigger BOOLEAN := false;
BEGIN
  -- Only delivery orders
  IF NEW.fulfillment_type = 'delivery' AND NEW.status NOT IN ('cancelled', 'delivered', 'completed') THEN
    IF TG_OP = 'INSERT' THEN
      should_trigger := true;
    ELSIF TG_OP = 'UPDATE' THEN
      -- Trigger ONLY when order status transitions into an active kitchen status,
      -- or when customer coordinates are added/updated.
      -- CRITICAL: Never trigger on delivery_status changes because plan-routes itself updates delivery_status!
      IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'preparing', 'ready_to_deliver'))
         OR (OLD.delivery_latitude IS NULL AND NEW.delivery_latitude IS NOT NULL)
         OR (OLD.delivery_longitude IS NULL AND NEW.delivery_longitude IS NOT NULL)
      THEN
        should_trigger := true;
      END IF;
    END IF;
  END IF;

  IF should_trigger THEN
    PERFORM net.http_post(
      url := supabase_url || '/functions/v1/plan-routes',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'brand_id', NEW.brand_id,
        'trigger_reason', 'order_event_' || lower(TG_OP),
        'is_demo', COALESCE(NEW.is_demo, false)
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_plan_routes_order_event error: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_plan_routes_order_event ON orders;
CREATE TRIGGER trigger_plan_routes_order_event
  AFTER INSERT OR UPDATE OF status, delivery_latitude, delivery_longitude, fulfillment_type
  ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_order_event();


-- 2. Fix route change trigger: ONLY trigger when a route is 'completed'
-- CRITICAL: NEVER trigger on 'cancelled' because plan-routes itself cancels older routes!
CREATE OR REPLACE FUNCTION notify_plan_routes_on_route_change()
RETURNS trigger AS $$
DECLARE
  supabase_url TEXT := 'https://iluhlynzkgubtaswvgwt.supabase.co';
  service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODU2NjY1NCwiZXhwIjoyMDY0MTQyNjU0fQ.37EjOyT9otsKJx9lsEI1xzZjMvz8XGOucyi35ePUq_8';
BEGIN
  -- When route completes, re-plan so pending preparing orders are assigned to the returned driver
  IF (OLD.status IS DISTINCT FROM NEW.status) AND NEW.status = 'completed' THEN
    PERFORM net.http_post(
      url := supabase_url || '/functions/v1/plan-routes',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'brand_id', NEW.brand_id,
        'trigger_reason', 'route_completed',
        'is_demo', COALESCE(NEW.is_demo, false)
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_plan_routes_on_route_change error: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_plan_routes_on_route_change ON delivery_routes;
CREATE TRIGGER trigger_plan_routes_on_route_change
  AFTER UPDATE OF status ON delivery_routes
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_on_route_change();

-- 3. Delete ghost routes from today that have no stops
DELETE FROM delivery_routes
WHERE status = 'cancelled'
  AND id NOT IN (SELECT DISTINCT delivery_route_id FROM route_stops WHERE delivery_route_id IS NOT NULL);
