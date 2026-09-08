-- Migration: 20260907000007_fix_auto_plan_triggers.sql
-- Purpose: Seamless automatic route planning when orders are in preparing / ready,
-- and when driver status or route status updates.

-- 1. Function to call plan-routes Edge Function
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
      -- Trigger on status changes, coordinates becoming available, or delivery status changes
      IF (OLD.status IS DISTINCT FROM NEW.status)
         OR (OLD.delivery_status IS DISTINCT FROM NEW.delivery_status)
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

-- Recreate trigger on orders
DROP TRIGGER IF EXISTS trigger_plan_routes_new_order ON orders;
DROP TRIGGER IF EXISTS trigger_plan_routes_order_event ON orders;
CREATE TRIGGER trigger_plan_routes_order_event
  AFTER INSERT OR UPDATE OF status, delivery_status, delivery_latitude, delivery_longitude, fulfillment_type
  ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_order_event();


-- 2. Trigger on delivery_routes completion or cancellation to immediately re-plan for available driver
CREATE OR REPLACE FUNCTION notify_plan_routes_on_route_change()
RETURNS trigger AS $$
DECLARE
  supabase_url TEXT := 'https://iluhlynzkgubtaswvgwt.supabase.co';
  service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODU2NjY1NCwiZXhwIjoyMDY0MTQyNjU0fQ.37EjOyT9otsKJx9lsEI1xzZjMvz8XGOucyi35ePUq_8';
BEGIN
  -- When route completes or is cancelled, re-plan so pending preparing orders are assigned
  IF (OLD.status IS DISTINCT FROM NEW.status) AND NEW.status IN ('completed', 'cancelled') THEN
    PERFORM net.http_post(
      url := supabase_url || '/functions/v1/plan-routes',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'brand_id', NEW.brand_id,
        'trigger_reason', 'route_status_' || NEW.status,
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


-- 3. Update available_drivers_at to preserve real current_route_id and projected_return_at
CREATE OR REPLACE FUNCTION available_drivers_at(p_target_time TIMESTAMPTZ DEFAULT NOW())
RETURNS TABLE (
  id UUID,
  employee_id UUID,
  name TEXT,
  is_online BOOLEAN,
  current_latitude DOUBLE PRECISION,
  current_longitude DOUBLE PRECISION,
  current_heading DOUBLE PRECISION,
  current_speed DOUBLE PRECISION,
  current_route_id UUID,
  projected_return_at TIMESTAMPTZ,
  available_at TIMESTAMPTZ,
  shift_id UUID,
  shift_start_at TIMESTAMPTZ,
  shift_end_at TIMESTAMPTZ,
  clocked_in_at TIMESTAMPTZ,
  clocked_out_at TIMESTAMPTZ
) AS $$
DECLARE
  v_tz TEXT := 'Europe/Vienna';
  v_target_date DATE;
  v_target_time TIME;
  v_store_lat DOUBLE PRECISION := 47.81328;
  v_store_lng DOUBLE PRECISION := 13.06882;
BEGIN
  v_target_date := (p_target_time AT TIME ZONE v_tz)::date;
  v_target_time := (p_target_time AT TIME ZONE v_tz)::time;

  SELECT store_latitude, store_longitude 
  INTO v_store_lat, v_store_lng 
  FROM delivery_settings 
  WHERE store_latitude IS NOT NULL 
  LIMIT 1;

  RETURN QUERY
  -- A. Real scheduled drivers on shift (excluding demo drivers)
  SELECT
    COALESCE(d.id, e.id) AS id,
    e.id AS employee_id,
    e.name,
    COALESCE(d.is_online, true) AS is_online,
    COALESCE(d.current_latitude, v_store_lat) AS current_latitude,
    COALESCE(d.current_longitude, v_store_lng) AS current_longitude,
    d.current_heading,
    d.current_speed,
    d.current_route_id,
    d.projected_return_at,
    COALESCE(d.available_at, d.projected_return_at, p_target_time) AS available_at,
    s.id AS shift_id,
    ((s.date || ' ' || s.start_time)::timestamp AT TIME ZONE v_tz) AS shift_start_at,
    (CASE 
       WHEN s.end_time > s.start_time THEN ((s.date || ' ' || s.end_time)::timestamp AT TIME ZONE v_tz)
       ELSE (((s.date + INTERVAL '1 day')::date || ' ' || s.end_time)::timestamp AT TIME ZONE v_tz)
     END) AS shift_end_at,
    d.clocked_in_at,
    d.clocked_out_at
  FROM employees e
  JOIN employee_shifts s ON s.employee_id = e.id
  LEFT JOIN drivers d ON d.employee_id = e.id
  WHERE e.is_driver = TRUE
    AND e.active = TRUE
    AND (d.is_demo IS NULL OR d.is_demo = FALSE)
    AND s.date = v_target_date
    AND (
      (s.start_time <= s.end_time AND s.start_time <= v_target_time AND v_target_time < s.end_time)
      OR
      (s.start_time > s.end_time AND (v_target_time >= s.start_time OR v_target_time < s.end_time))
    )
    AND NOT (
      d.clocked_out_at IS NOT NULL 
      AND (d.clocked_in_at IS NULL OR d.clocked_out_at >= d.clocked_in_at)
      AND d.clocked_out_at >= ((s.date || ' ' || s.start_time)::timestamp AT TIME ZONE v_tz)
      AND d.current_route_id IS NULL
    )

  UNION ALL

  -- B. Demo drivers: ALWAYS online, 24/7 virtual shift, reflecting active route return time if out
  SELECT
    d.id,
    d.employee_id,
    d.name,
    TRUE AS is_online,
    COALESCE(d.current_latitude, v_store_lat) AS current_latitude,
    COALESCE(d.current_longitude, v_store_lng) AS current_longitude,
    d.current_heading,
    d.current_speed,
    d.current_route_id,
    d.projected_return_at,
    COALESCE(d.available_at, d.projected_return_at, p_target_time) AS available_at,
    NULL::UUID AS shift_id,
    (p_target_time - INTERVAL '12 hours') AS shift_start_at,
    (p_target_time + INTERVAL '24 hours') AS shift_end_at,
    NOW() AS clocked_in_at,
    NULL::TIMESTAMPTZ AS clocked_out_at
  FROM drivers d
  WHERE d.is_demo = TRUE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
