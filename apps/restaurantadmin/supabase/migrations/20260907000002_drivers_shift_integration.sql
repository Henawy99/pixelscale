-- =============================================================
-- Migration: Drivers & Shifts Integration
-- Associates available delivery drivers with on-shift employees.
-- =============================================================

-- 1. Add shift_end_grace_minutes to delivery_settings
ALTER TABLE delivery_settings 
ADD COLUMN IF NOT EXISTS shift_end_grace_minutes INT NOT NULL DEFAULT 15;

-- 2. Add pinned_driver_id to route_stops (for operator manual overrides)
ALTER TABLE route_stops 
ADD COLUMN IF NOT EXISTS pinned_driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL;

-- 3. Add shift & clock-in tracking columns to drivers
ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES employee_shifts(id) ON DELETE SET NULL;

ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS shift_start_at TIMESTAMPTZ;

ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS shift_end_at TIMESTAMPTZ;

ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS clocked_in_at TIMESTAMPTZ;

ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS clocked_out_at TIMESTAMPTZ;

ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS available_at TIMESTAMPTZ;

-- 4. Add unassignable flag & reason to orders
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS is_unassignable BOOLEAN DEFAULT FALSE;

ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS unassignable_reason TEXT;

-- 5. Create unique index on drivers(employee_id) for safe upserts
CREATE UNIQUE INDEX IF NOT EXISTS idx_drivers_employee_id_unique 
ON drivers(employee_id) WHERE employee_id IS NOT NULL;

-- 6. Function: available_drivers_at(p_target_time TIMESTAMPTZ)
-- Returns all driver-capable employees who have an active shift covering p_target_time
-- and have not clocked out (or are currently finishing an in-flight route).
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
BEGIN
  v_target_date := (p_target_time AT TIME ZONE v_tz)::date;
  v_target_time := (p_target_time AT TIME ZONE v_tz)::time;

  RETURN QUERY
  SELECT
    COALESCE(d.id, e.id) AS id,
    e.id AS employee_id,
    e.name,
    COALESCE(d.is_online, true) AS is_online,
    COALESCE(d.current_latitude, ds.store_latitude, 47.81328) AS current_latitude,
    COALESCE(d.current_longitude, ds.store_longitude, 13.06882) AS current_longitude,
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
  LEFT JOIN delivery_settings ds ON true
  WHERE e.is_driver = TRUE
    AND e.active = TRUE
    AND s.date = v_target_date
    AND (
      (s.start_time <= s.end_time AND s.start_time <= v_target_time AND v_target_time < s.end_time)
      OR
      (s.start_time > s.end_time AND (v_target_time >= s.start_time OR v_target_time < s.end_time))
    )
    -- If driver clocked out for this shift and has no in-flight route, exclude from new planning
    AND NOT (
      d.clocked_out_at IS NOT NULL 
      AND (d.clocked_in_at IS NULL OR d.clocked_out_at >= d.clocked_in_at)
      AND d.clocked_out_at >= ((s.date || ' ' || s.start_time)::timestamp AT TIME ZONE v_tz)
      AND d.current_route_id IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 7. View: available_drivers (current real-time pool)
CREATE OR REPLACE VIEW available_drivers AS
SELECT * FROM available_drivers_at(NOW());

-- Grant access to view and function
GRANT SELECT ON available_drivers TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION available_drivers_at(TIMESTAMPTZ) TO authenticated, anon, service_role;

-- Allow user_id on drivers to be nullable for employees without auth accounts
ALTER TABLE drivers ALTER COLUMN user_id DROP NOT NULL;

-- 8. Auto-sync trigger from employees to drivers
CREATE OR REPLACE FUNCTION sync_employee_to_drivers()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_driver = TRUE THEN
    INSERT INTO drivers (id, employee_id, user_id, name, is_online)
    VALUES (NEW.id, NEW.id, NEW.auth_user_id, NEW.name, TRUE)
    ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name,
        employee_id = EXCLUDED.employee_id,
        user_id = COALESCE(EXCLUDED.user_id, drivers.user_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_employee_to_drivers ON employees;
CREATE TRIGGER trigger_sync_employee_to_drivers
  AFTER INSERT OR UPDATE OF is_driver, name, auth_user_id ON employees
  FOR EACH ROW
  EXECUTE FUNCTION sync_employee_to_drivers();
