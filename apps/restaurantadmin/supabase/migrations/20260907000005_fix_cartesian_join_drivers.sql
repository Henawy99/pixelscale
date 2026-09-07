-- Migration: 20260907000005_fix_cartesian_join_drivers.sql
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

  -- B. Demo drivers (active/online without requiring calendar shifts)
  SELECT
    d.id,
    d.employee_id,
    d.name,
    d.is_online,
    COALESCE(d.current_latitude, v_store_lat) AS current_latitude,
    COALESCE(d.current_longitude, v_store_lng) AS current_longitude,
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
  WHERE d.is_demo = TRUE
    AND d.is_online = TRUE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
