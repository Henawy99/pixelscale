-- Migration: 20260907000003_demo_driver_and_orders.sql
-- Description: Add demo support for drivers, orders, routes, and update available_drivers_at

-- 1. Add is_demo column to drivers, orders, and delivery_routes if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='drivers' AND column_name='is_demo') THEN
    ALTER TABLE drivers ADD COLUMN is_demo BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='is_demo') THEN
    ALTER TABLE orders ADD COLUMN is_demo BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_routes' AND column_name='is_demo') THEN
    ALTER TABLE delivery_routes ADD COLUMN is_demo BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

-- 2. Configure Abunageb as Demo Driver
UPDATE drivers
SET 
  is_demo = TRUE,
  is_online = TRUE,
  name = 'Abunageb (Demo)',
  employee_id = 'd77c3d82-9e89-4d2a-aa74-b1ea2ded0262'
WHERE user_id = '2635e2b2-26fd-4656-bf95-ff7e0d5afa52' 
   OR id = '4ece59ec-5d06-4b1f-adc4-c15090418eea';

-- 3. Update available_drivers_at function to include scheduled employees AND online demo drivers
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
  -- A. Real scheduled drivers on shift
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
    AND NOT (
      d.clocked_out_at IS NOT NULL 
      AND (d.clocked_in_at IS NULL OR d.clocked_out_at >= d.clocked_in_at)
      AND d.clocked_out_at >= ((s.date || ' ' || s.start_time)::timestamp AT TIME ZONE v_tz)
      AND d.current_route_id IS NULL
    )

  UNION ALL

  -- B. Demo drivers (active/online without requiring calendar shifts)
  SELECT
    d.id,
    d.employee_id,
    d.name,
    d.is_online,
    COALESCE(d.current_latitude, ds.store_latitude, 47.81328) AS current_latitude,
    COALESCE(d.current_longitude, ds.store_longitude, 13.06882) AS current_longitude,
    d.current_heading,
    d.current_speed,
    d.current_route_id,
    d.projected_return_at,
    COALESCE(d.available_at, d.projected_return_at, p_target_time) AS available_at,
    NULL::UUID AS shift_id,
    (p_target_time - INTERVAL '2 hours') AS shift_start_at,
    (p_target_time + INTERVAL '8 hours') AS shift_end_at,
    NOW() AS clocked_in_at,
    NULL::TIMESTAMPTZ AS clocked_out_at
  FROM drivers d
  LEFT JOIN delivery_settings ds ON true
  WHERE d.is_demo = TRUE
    AND d.is_online = TRUE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 4. Refresh view
CREATE OR REPLACE VIEW available_drivers AS
SELECT * FROM available_drivers_at(NOW());

GRANT SELECT ON available_drivers TO authenticated, anon, service_role;
