-- =============================================================
-- Delivery dispatch v3
--
-- * One plan across ALL brands (same kitchen, same drivers).
-- * A driver is available when they are online in the driver app with a fresh
--   heartbeat — no calendar shift required (a scheduled shift still limits the end).
-- * Plans are written atomically by apply_delivery_plan() and keep route ids stable.
-- * Driver actions (start / finish tour, background heartbeat) are SECURITY DEFINER
--   RPCs, so they no longer fail silently on RLS.
-- * Triggers call plan-routes through one helper that reads the key from Vault,
--   plus a 1-minute tick so time-based changes (food ready, drivers returning) are planned.
-- * Realtime is enabled for the dispatch tables.
--
-- Requires a Vault secret named 'planner_service_key' holding the service-role key:
--   select vault.create_secret('<service role key>', 'planner_service_key');
-- =============================================================

-- 1. Settings -------------------------------------------------
ALTER TABLE delivery_settings
  ADD COLUMN IF NOT EXISTS service_weight NUMERIC NOT NULL DEFAULT 0.5,
  ADD COLUMN IF NOT EXISTS reassign_weight NUMERIC NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS safety_buffer_secs INT NOT NULL DEFAULT 120,
  ADD COLUMN IF NOT EXISTS default_prep_secs INT NOT NULL DEFAULT 900,
  ADD COLUMN IF NOT EXISTS stale_order_mins INT NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS driver_heartbeat_timeout_mins INT NOT NULL DEFAULT 15;

-- The new solver needs a slightly larger budget than the old 200 ms default.
UPDATE delivery_settings SET solver_time_limit_ms = 400 WHERE solver_time_limit_ms = 200;

-- 2. Orders: optional "food is ready" signal from the kitchen ---
ALTER TABLE orders ADD COLUMN IF NOT EXISTS food_ready_at TIMESTAMPTZ;

-- 3. Drivers: push token -----------------------------------------
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ;

-- 4. Device keys: let the Android background service send heartbeats
--    without holding the user's session.
CREATE TABLE IF NOT EXISTS driver_device_keys (
  driver_id UUID PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
  device_key UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE driver_device_keys ENABLE ROW LEVEL SECURITY;
-- No policies: only reachable through the SECURITY DEFINER functions below.

-- 5. Planner lock (serialises plan runs; bursts of triggers collapse into one re-run)
CREATE TABLE IF NOT EXISTS planner_lock (
  mode TEXT PRIMARY KEY,
  holder TEXT,
  locked_until TIMESTAMPTZ,
  rerun_requested BOOLEAN NOT NULL DEFAULT FALSE
);
INSERT INTO planner_lock (mode) VALUES ('real'), ('demo') ON CONFLICT DO NOTHING;
ALTER TABLE planner_lock ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION planner_try_lock(p_mode TEXT, p_holder TEXT, p_lease_secs INT DEFAULT 45)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE planner_lock
     SET holder = p_holder,
         locked_until = NOW() + make_interval(secs => p_lease_secs),
         rerun_requested = FALSE
   WHERE mode = p_mode AND (locked_until IS NULL OR locked_until < NOW());
  IF FOUND THEN
    RETURN TRUE;
  END IF;
  UPDATE planner_lock SET rerun_requested = TRUE WHERE mode = p_mode;
  RETURN FALSE;
END;
$$;

-- Returns TRUE when another trigger arrived during the run and p_allow_rerun is set:
-- the caller keeps the lock and plans once more. Otherwise the lock is released.
CREATE OR REPLACE FUNCTION planner_release(p_mode TEXT, p_holder TEXT, p_allow_rerun BOOLEAN DEFAULT TRUE, p_lease_secs INT DEFAULT 45)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rerun BOOLEAN;
BEGIN
  SELECT rerun_requested INTO v_rerun FROM planner_lock WHERE mode = p_mode AND holder = p_holder FOR UPDATE;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  IF v_rerun AND p_allow_rerun THEN
    UPDATE planner_lock
       SET rerun_requested = FALSE, locked_until = NOW() + make_interval(secs => p_lease_secs)
     WHERE mode = p_mode;
    RETURN TRUE;
  END IF;
  UPDATE planner_lock SET holder = NULL, locked_until = NULL WHERE mode = p_mode;
  RETURN FALSE;
END;
$$;

-- 6. Atomic plan write ----------------------------------------------
-- p = {
--   is_demo, plan_version, trigger_reason, brand_id, planned_at, solver_time_ms,
--   cost_breakdown, plan_snapshot,
--   routes: [{ driver_id, brand_id, planned_departure_at, planned_return_at,
--              total_duration_secs, total_distance_m, store_lat, store_lng,
--              stops: [{ order_id, type, lat, lng, customer_name, customer_address,
--                        planned_arrival_at, target_delivery_time, travel_to_next_secs,
--                        service_secs, pinned_driver_id }] }],
--   waiting:      [{ order_id, delivery_status, planned_arrival_at }],
--   unassignable: [{ order_id, reason }]
-- }
-- Returns { ok, changed_driver_ids, route_ids } or { ok: false, reason } when the
-- world changed since the plan was computed (caller re-plans).
CREATE OR REPLACE FUNCTION apply_delivery_plan(p JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_is_demo BOOLEAN := COALESCE((p->>'is_demo')::BOOLEAN, FALSE);
  v_planned_at TIMESTAMPTZ := COALESCE((p->>'planned_at')::TIMESTAMPTZ, NOW());
  r JSONB;
  v_driver UUID;
  v_route_id UUID;
  v_old_orders UUID[];
  v_new_orders UUID[];
  v_planned UUID[] := '{}';
  v_kept UUID[] := '{}';
  v_changed UUID[] := '{}';
  v_insert BOOLEAN;
  v_stale INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('delivery_planner'));

  -- 0. Is the plan still valid?
  SELECT COUNT(*) INTO v_stale
    FROM jsonb_array_elements(COALESCE(p->'routes', '[]'::JSONB)) AS rr(v),
         jsonb_array_elements(rr.v->'stops') AS st(s),
         orders o
   WHERE st.s->>'order_id' IS NOT NULL
     AND o.id = (st.s->>'order_id')::UUID
     AND (COALESCE(o.delivery_status, '') IN ('out_for_delivery', 'delivered')
          OR o.status IN ('cancelled', 'delivered', 'completed', 'delivering'));
  IF v_stale > 0 THEN
    RETURN jsonb_build_object('ok', FALSE, 'reason', 'orders_changed', 'count', v_stale);
  END IF;

  IF EXISTS (SELECT 1 FROM delivery_routes
              WHERE is_demo = v_is_demo AND status = 'in_progress' AND started_at > v_planned_at) THEN
    RETURN jsonb_build_object('ok', FALSE, 'reason', 'route_started');
  END IF;

  -- 1. One committed tour per driver. Reuse the driver's current 'assigned' route row.
  FOR r IN SELECT x.v FROM jsonb_array_elements(COALESCE(p->'routes', '[]'::JSONB)) AS x(v) LOOP
    v_driver := (r->>'driver_id')::UUID;

    SELECT COALESCE(array_agg((x.s->>'order_id')::UUID ORDER BY x.ord), '{}')
      INTO v_new_orders
      FROM jsonb_array_elements(r->'stops') WITH ORDINALITY AS x(s, ord)
     WHERE x.s->>'order_id' IS NOT NULL;
    v_planned := v_planned || v_new_orders;

    SELECT id INTO v_route_id
      FROM delivery_routes
     WHERE assigned_driver_id = v_driver AND status = 'assigned' AND is_demo = v_is_demo
     ORDER BY created_at DESC
     LIMIT 1;

    IF v_route_id IS NOT NULL THEN
      SELECT COALESCE(array_agg(order_id ORDER BY sequence_number), '{}')
        INTO v_old_orders
        FROM route_stops
       WHERE delivery_route_id = v_route_id AND order_id IS NOT NULL;

      UPDATE delivery_routes SET
        brand_id = COALESCE((r->>'brand_id')::UUID, brand_id),
        plan_version = (p->>'plan_version')::INT,
        planned_departure_at = (r->>'planned_departure_at')::TIMESTAMPTZ,
        planned_return_at = (r->>'planned_return_at')::TIMESTAMPTZ,
        total_estimated_duration_seconds = (r->>'total_duration_secs')::INT,
        total_estimated_distance_meters = (r->>'total_distance_m')::INT,
        store_latitude = (r->>'store_lat')::DOUBLE PRECISION,
        store_longitude = (r->>'store_lng')::DOUBLE PRECISION
      WHERE id = v_route_id;

      v_insert := v_old_orders IS DISTINCT FROM v_new_orders;
      IF v_insert THEN
        DELETE FROM route_stops WHERE delivery_route_id = v_route_id;
        v_changed := v_changed || v_driver;
      ELSE
        -- Same tour: only refresh the times.
        UPDATE route_stops rs SET
          planned_arrival_at = (x.s->>'planned_arrival_at')::TIMESTAMPTZ,
          estimated_arrival_time = (x.s->>'planned_arrival_at')::TIMESTAMPTZ,
          target_delivery_time = NULLIF(x.s->>'target_delivery_time', '')::TIMESTAMPTZ,
          estimated_travel_time_to_next_stop_seconds = (x.s->>'travel_to_next_secs')::INT
        FROM jsonb_array_elements(r->'stops') WITH ORDINALITY AS x(s, ord)
        WHERE rs.delivery_route_id = v_route_id AND rs.sequence_number = x.ord - 1;
      END IF;
    ELSE
      INSERT INTO delivery_routes (
        assigned_driver_id, brand_id, status, is_demo, plan_version,
        planned_departure_at, planned_return_at,
        total_estimated_duration_seconds, total_estimated_distance_meters,
        store_latitude, store_longitude
      ) VALUES (
        v_driver, (r->>'brand_id')::UUID, 'assigned', v_is_demo, (p->>'plan_version')::INT,
        (r->>'planned_departure_at')::TIMESTAMPTZ, (r->>'planned_return_at')::TIMESTAMPTZ,
        (r->>'total_duration_secs')::INT, (r->>'total_distance_m')::INT,
        (r->>'store_lat')::DOUBLE PRECISION, (r->>'store_lng')::DOUBLE PRECISION
      ) RETURNING id INTO v_route_id;
      v_insert := TRUE;
      v_changed := v_changed || v_driver;
    END IF;

    IF v_insert THEN
      INSERT INTO route_stops (
        delivery_route_id, order_id, type, sequence_number, latitude, longitude,
        customer_name, customer_address, estimated_arrival_time, planned_arrival_at,
        target_delivery_time, status, pinned_driver_id,
        estimated_travel_time_to_next_stop_seconds, estimated_service_time_seconds
      )
      SELECT v_route_id,
             NULLIF(x.s->>'order_id', '')::UUID,
             x.s->>'type',
             (x.ord - 1)::INT,
             (x.s->>'lat')::DOUBLE PRECISION,
             (x.s->>'lng')::DOUBLE PRECISION,
             x.s->>'customer_name',
             x.s->>'customer_address',
             (x.s->>'planned_arrival_at')::TIMESTAMPTZ,
             (x.s->>'planned_arrival_at')::TIMESTAMPTZ,
             NULLIF(x.s->>'target_delivery_time', '')::TIMESTAMPTZ,
             'pending',
             NULLIF(x.s->>'pinned_driver_id', '')::UUID,
             (x.s->>'travel_to_next_secs')::INT,
             COALESCE((x.s->>'service_secs')::INT, 0)
        FROM jsonb_array_elements(r->'stops') WITH ORDINALITY AS x(s, ord);
    END IF;

    v_kept := v_kept || v_route_id;

    UPDATE orders o SET
      assigned_driver_id = v_driver,
      delivery_route_id = v_route_id,
      delivery_route_sequence = (x.ord - 1)::INT,
      delivery_status = 'assigned_to_route',
      planned_arrival_at = (x.s->>'planned_arrival_at')::TIMESTAMPTZ,
      is_unassignable = FALSE,
      unassignable_reason = NULL
    FROM jsonb_array_elements(r->'stops') WITH ORDINALITY AS x(s, ord)
    WHERE x.s->>'order_id' IS NOT NULL AND o.id = (x.s->>'order_id')::UUID;
  END LOOP;

  -- 2. Every other 'assigned' route in this mode is obsolete.
  FOR v_route_id IN
    SELECT id FROM delivery_routes
     WHERE status = 'assigned' AND is_demo = v_is_demo AND NOT (id = ANY (v_kept))
  LOOP
    IF EXISTS (SELECT 1 FROM orders WHERE delivery_route_id = v_route_id AND delivery_status = 'out_for_delivery') THEN
      -- A driver is already on the road with it (legacy app could not flip the status): keep it.
      UPDATE delivery_routes SET status = 'in_progress', started_at = COALESCE(started_at, NOW()) WHERE id = v_route_id;
      CONTINUE;
    END IF;
    UPDATE orders SET
      delivery_route_id = NULL, assigned_driver_id = NULL, delivery_route_sequence = NULL,
      planned_arrival_at = NULL, delivery_status = 'preparing'
     WHERE delivery_route_id = v_route_id AND delivery_status = 'assigned_to_route';
    DELETE FROM delivery_routes WHERE id = v_route_id; -- stops cascade
  END LOOP;

  -- 3. Orders dropped from a kept route go back to the pool.
  UPDATE orders SET
    delivery_route_id = NULL, assigned_driver_id = NULL, delivery_route_sequence = NULL,
    planned_arrival_at = NULL, delivery_status = 'preparing'
   WHERE delivery_route_id = ANY (v_kept)
     AND delivery_status = 'assigned_to_route'
     AND NOT (id = ANY (v_planned));

  -- 4. Orders planned for a later tour, or not ready to be planned yet.
  UPDATE orders o SET
    delivery_status = w.item->>'delivery_status',
    planned_arrival_at = NULLIF(w.item->>'planned_arrival_at', '')::TIMESTAMPTZ,
    is_unassignable = FALSE,
    unassignable_reason = NULL
  FROM jsonb_array_elements(COALESCE(p->'waiting', '[]'::JSONB)) AS w(item)
  WHERE o.id = (w.item->>'order_id')::UUID
    AND o.delivery_route_id IS NULL
    AND COALESCE(o.delivery_status, '') NOT IN ('out_for_delivery', 'delivered');

  -- 5. Orders nobody can take.
  UPDATE orders o SET
    is_unassignable = TRUE,
    unassignable_reason = u.item->>'reason',
    delivery_status = CASE WHEN o.delivery_route_id IS NULL THEN COALESCE(NULLIF(o.delivery_status, 'assigned_to_route'), 'preparing') ELSE o.delivery_status END
  FROM jsonb_array_elements(COALESCE(p->'unassignable', '[]'::JSONB)) AS u(item)
  WHERE o.id = (u.item->>'order_id')::UUID
    AND COALESCE(o.delivery_status, '') NOT IN ('out_for_delivery', 'delivered');

  -- 6. Audit trail (skip no-op ticks to keep plan_log small).
  IF cardinality(v_changed) > 0 OR COALESCE(p->>'trigger_reason', '') <> 'tick' THEN
    INSERT INTO plan_log (brand_id, plan_version, trigger_reason, cost_breakdown, plan_snapshot, solver_time_ms)
    VALUES (
      NULLIF(p->>'brand_id', '')::UUID,
      (p->>'plan_version')::INT,
      p->>'trigger_reason',
      p->'cost_breakdown',
      p->'plan_snapshot',
      (p->>'solver_time_ms')::INT
    );
  END IF;

  RETURN jsonb_build_object('ok', TRUE, 'changed_driver_ids', to_jsonb(v_changed), 'route_ids', to_jsonb(v_kept));
END;
$$;

-- 7. Driver RPCs -----------------------------------------------------
CREATE OR REPLACE FUNCTION _caller_driver_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM drivers WHERE user_id = auth.uid() ORDER BY is_demo, created_at LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION _caller_is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'manager'));
$$;

-- Driver leaves the restaurant with the tour.
CREATE OR REPLACE FUNCTION driver_start_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_route delivery_routes%ROWTYPE;
  v_duration INTERVAL;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('delivery_planner'));

  SELECT * INTO v_route FROM delivery_routes WHERE id = p_route_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This tour was just re-planned. Pull down to refresh.';
  END IF;
  IF v_route.assigned_driver_id IS DISTINCT FROM _caller_driver_id() AND NOT _caller_is_admin() THEN
    RAISE EXCEPTION 'This tour belongs to another driver';
  END IF;
  IF v_route.status = 'in_progress' THEN
    RETURN jsonb_build_object('ok', TRUE, 'route_id', p_route_id, 'already_started', TRUE);
  END IF;
  IF v_route.status <> 'assigned' THEN
    RAISE EXCEPTION 'This tour is %', v_route.status;
  END IF;

  v_duration := COALESCE(
    v_route.planned_return_at - v_route.planned_departure_at,
    make_interval(secs => COALESCE(v_route.total_estimated_duration_seconds, 1800))
  );

  UPDATE delivery_routes
     SET status = 'in_progress', started_at = NOW(), actual_departure_at = NOW(),
         confirmed_at = COALESCE(confirmed_at, NOW())
   WHERE id = p_route_id;

  UPDATE orders
     SET delivery_status = 'out_for_delivery', status = 'delivering',
         assigned_driver_id = v_route.assigned_driver_id
   WHERE id IN (SELECT order_id FROM route_stops WHERE delivery_route_id = p_route_id AND order_id IS NOT NULL)
     AND status NOT IN ('cancelled', 'delivered', 'completed');

  UPDATE drivers
     SET current_route_id = p_route_id,
         projected_return_at = NOW() + v_duration,
         available_at = NOW() + v_duration
   WHERE id = v_route.assigned_driver_id;

  RETURN jsonb_build_object('ok', TRUE, 'route_id', p_route_id);
END;
$$;

-- Driver is back at the restaurant: close the tour (fires a re-plan via trigger).
CREATE OR REPLACE FUNCTION driver_complete_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_route delivery_routes%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('delivery_planner'));

  SELECT * INTO v_route FROM delivery_routes WHERE id = p_route_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tour not found';
  END IF;
  IF v_route.assigned_driver_id IS DISTINCT FROM _caller_driver_id() AND NOT _caller_is_admin() THEN
    RAISE EXCEPTION 'This tour belongs to another driver';
  END IF;
  IF v_route.status = 'completed' THEN
    RETURN jsonb_build_object('ok', TRUE, 'already_completed', TRUE);
  END IF;
  IF v_route.status <> 'in_progress' THEN
    RAISE EXCEPTION 'This tour has not started yet';
  END IF;

  UPDATE orders
     SET delivery_status = 'delivered', status = 'delivered',
         actual_delivery_time = COALESCE(actual_delivery_time, NOW())
   WHERE id IN (SELECT order_id FROM route_stops WHERE delivery_route_id = p_route_id AND order_id IS NOT NULL)
     AND delivery_status = 'out_for_delivery';

  UPDATE route_stops
     SET status = 'completed', actual_arrival_time = COALESCE(actual_arrival_time, NOW())
   WHERE delivery_route_id = p_route_id AND status IN ('pending', 'in_progress');

  UPDATE drivers
     SET current_route_id = NULL, projected_return_at = NULL, available_at = NOW(), last_seen_at = NOW()
   WHERE id = v_route.assigned_driver_id;

  UPDATE delivery_routes
     SET status = 'completed', completed_at = NOW(), actual_return_at = NOW()
   WHERE id = p_route_id;

  RETURN jsonb_build_object('ok', TRUE);
END;
$$;

-- Key the Android background service uses for heartbeats.
CREATE OR REPLACE FUNCTION driver_get_device_key()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_driver UUID := _caller_driver_id();
  v_key UUID;
BEGIN
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'No driver profile for this account';
  END IF;
  INSERT INTO driver_device_keys (driver_id) VALUES (v_driver) ON CONFLICT (driver_id) DO NOTHING;
  SELECT device_key INTO v_key FROM driver_device_keys WHERE driver_id = v_driver;
  RETURN jsonb_build_object('driver_id', v_driver, 'device_key', v_key);
END;
$$;

-- Location + liveness from the background service. Only works while the driver is online.
CREATE OR REPLACE FUNCTION driver_heartbeat(
  p_driver_id UUID,
  p_device_key UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_heading DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL,
  p_go_offline BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM driver_device_keys WHERE driver_id = p_driver_id AND device_key = p_device_key) THEN
    RETURN FALSE;
  END IF;
  IF p_go_offline THEN
    UPDATE drivers SET is_online = FALSE, last_seen_at = NOW() WHERE id = p_driver_id;
    RETURN TRUE;
  END IF;
  UPDATE drivers SET
    current_latitude = COALESCE(p_lat, current_latitude),
    current_longitude = COALESCE(p_lng, current_longitude),
    current_heading = CASE WHEN p_heading BETWEEN 0 AND 360 THEN p_heading ELSE current_heading END,
    current_speed = CASE WHEN p_speed >= 0 THEN p_speed ELSE current_speed END,
    last_seen_at = NOW()
  WHERE id = p_driver_id AND is_online;
  RETURN FOUND;
END;
$$;

-- 8. Who can receive tours right now -----------------------------------
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
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tz TEXT := 'Europe/Vienna';
  v_store_lat DOUBLE PRECISION := 47.81328;
  v_store_lng DOUBLE PRECISION := 13.06882;
  v_timeout INT := 15;
  v_local_date DATE := (p_target_time AT TIME ZONE 'Europe/Vienna')::DATE;
BEGIN
  SELECT ds.store_latitude, ds.store_longitude, ds.driver_heartbeat_timeout_mins
    INTO v_store_lat, v_store_lng, v_timeout
    FROM delivery_settings ds
   ORDER BY ds.created_at
   LIMIT 1;

  RETURN QUERY
  -- A. Real drivers: online in the app with a fresh heartbeat.
  SELECT
    d.id,
    d.employee_id,
    d.name,
    d.is_online,
    COALESCE(d.current_latitude, v_store_lat),
    COALESCE(d.current_longitude, v_store_lng),
    d.current_heading,
    d.current_speed,
    d.current_route_id,
    d.projected_return_at,
    d.available_at,
    sh.shift_id,
    sh.shift_start_at,
    sh.shift_end_at,
    d.clocked_in_at,
    d.clocked_out_at
  FROM drivers d
  LEFT JOIN employees e ON e.id = d.employee_id
  LEFT JOIN LATERAL (
    SELECT x.shift_id, x.shift_start_at, x.shift_end_at
      FROM (
        SELECT s.id AS shift_id,
               ((s.date || ' ' || s.start_time)::TIMESTAMP AT TIME ZONE v_tz) AS shift_start_at,
               CASE WHEN s.end_time > s.start_time
                    THEN ((s.date || ' ' || s.end_time)::TIMESTAMP AT TIME ZONE v_tz)
                    ELSE (((s.date + 1) || ' ' || s.end_time)::TIMESTAMP AT TIME ZONE v_tz)
               END AS shift_end_at
          FROM employee_shifts s
         WHERE s.employee_id = d.employee_id
           AND s.date BETWEEN v_local_date - 1 AND v_local_date
      ) x
     WHERE p_target_time >= x.shift_start_at AND p_target_time < x.shift_end_at
     ORDER BY x.shift_end_at DESC
     LIMIT 1
  ) sh ON TRUE
  WHERE d.is_demo = FALSE
    AND d.is_online = TRUE
    AND d.user_id IS NOT NULL
    AND (e.id IS NULL OR e.active IS NOT FALSE)
    AND d.last_seen_at > p_target_time - make_interval(mins => COALESCE(v_timeout, 15))

  UNION ALL

  -- B. Demo drivers: always available (used only by demo planning runs).
  SELECT
    d.id,
    d.employee_id,
    d.name,
    TRUE,
    COALESCE(d.current_latitude, v_store_lat),
    COALESCE(d.current_longitude, v_store_lng),
    d.current_heading,
    d.current_speed,
    d.current_route_id,
    d.projected_return_at,
    COALESCE(d.available_at, d.projected_return_at, p_target_time),
    NULL::UUID,
    (p_target_time - INTERVAL '12 hours'),
    (p_target_time + INTERVAL '24 hours'),
    NOW(),
    NULL::TIMESTAMPTZ
  FROM drivers d
  WHERE d.is_demo = TRUE;
END;
$$;

CREATE OR REPLACE VIEW available_drivers AS
SELECT * FROM available_drivers_at(NOW());

-- 9. Re-plan triggers -------------------------------------------------
CREATE OR REPLACE FUNCTION request_replan(p_reason TEXT, p_is_demo BOOLEAN DEFAULT FALSE)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_key TEXT;
BEGIN
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'planner_service_key' LIMIT 1;
  IF v_key IS NULL THEN
    RAISE WARNING 'request_replan: vault secret planner_service_key is missing';
    RETURN;
  END IF;
  PERFORM net.http_post(
    url := 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/plan-routes',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := jsonb_build_object('trigger_reason', p_reason, 'is_demo', COALESCE(p_is_demo, FALSE)),
    timeout_milliseconds := 15000
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'request_replan failed: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION notify_plan_routes_order_event()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.fulfillment_type = 'delivery'
       AND NEW.status NOT IN ('cancelled', 'delivered', 'completed', 'pending_payment') THEN
      PERFORM request_replan('order_insert', COALESCE(NEW.is_demo, FALSE));
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.fulfillment_type IS DISTINCT FROM 'delivery' AND OLD.fulfillment_type IS DISTINCT FROM 'delivery' THEN
    RETURN NEW;
  END IF;

  -- Never on delivery_status: plan-routes writes that column itself.
  IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'preparing', 'cancelled'))
     OR (OLD.delivery_latitude IS NULL AND NEW.delivery_latitude IS NOT NULL)
     OR (OLD.fulfillment_type IS DISTINCT FROM NEW.fulfillment_type)
     OR (OLD.food_ready_at IS DISTINCT FROM NEW.food_ready_at) THEN
    PERFORM request_replan('order_update', COALESCE(NEW.is_demo, FALSE));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_plan_routes_order_event ON orders;
CREATE TRIGGER trigger_plan_routes_order_event
  AFTER INSERT OR UPDATE OF status, delivery_latitude, delivery_longitude, fulfillment_type, food_ready_at
  ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_order_event();

CREATE OR REPLACE FUNCTION notify_plan_routes_on_route_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- A driver left (in_progress) or came back (completed). Never on 'cancelled'/'assigned':
  -- plan-routes writes those itself.
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('in_progress', 'completed') THEN
    PERFORM request_replan('route_' || NEW.status, COALESCE(NEW.is_demo, FALSE));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_plan_routes_on_route_change ON delivery_routes;
CREATE TRIGGER trigger_plan_routes_on_route_change
  AFTER UPDATE OF status ON delivery_routes
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_on_route_change();

CREATE OR REPLACE FUNCTION notify_plan_routes_driver_status()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.is_online IS DISTINCT FROM NEW.is_online THEN
    PERFORM request_replan(CASE WHEN NEW.is_online THEN 'driver_online' ELSE 'driver_offline' END, COALESCE(NEW.is_demo, FALSE));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_plan_routes_driver_status ON drivers;
CREATE TRIGGER trigger_plan_routes_driver_status
  AFTER UPDATE OF is_online ON drivers
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_driver_status();

-- 10. Planner tick: re-plan every minute while there is something to plan ----
CREATE OR REPLACE FUNCTION planner_tick()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM delivery_routes WHERE status = 'assigned' AND NOT is_demo)
     OR (
       EXISTS (SELECT 1 FROM drivers WHERE NOT is_demo AND is_online AND last_seen_at > NOW() - INTERVAL '30 minutes')
       AND EXISTS (
         SELECT 1 FROM orders
          WHERE fulfillment_type = 'delivery'
            AND NOT COALESCE(is_demo, FALSE)
            AND created_at > NOW() - INTERVAL '4 hours'
            AND status NOT IN ('cancelled', 'delivered', 'completed', 'delivering', 'pending_payment')
            AND COALESCE(delivery_status, '') NOT IN ('out_for_delivery', 'delivered')
       )
     )
  THEN
    PERFORM request_replan('tick', FALSE);
  END IF;
END;
$$;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'delivery-planner-tick';
  PERFORM cron.schedule('delivery-planner-tick', '* * * * *', 'SELECT public.planner_tick()');
END $$;

-- 11. Privileges --------------------------------------------------------
REVOKE ALL ON FUNCTION planner_try_lock(TEXT, TEXT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION planner_release(TEXT, TEXT, BOOLEAN, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION apply_delivery_plan(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION request_replan(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION planner_tick() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION _caller_driver_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION _caller_is_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION driver_start_route(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION driver_complete_route(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION driver_get_device_key() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION driver_start_route(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION driver_complete_route(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION driver_get_device_key() TO authenticated;
GRANT EXECUTE ON FUNCTION driver_heartbeat(UUID, UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN) TO anon, authenticated;
GRANT SELECT ON available_drivers TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION available_drivers_at(TIMESTAMPTZ) TO authenticated, service_role;

-- 12. Realtime for the dispatch tables ---------------------------------
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['delivery_routes', 'route_stops', 'drivers', 'plan_log'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- 13. Legacy function no longer used by any trigger.
DROP FUNCTION IF EXISTS notify_plan_routes_new_order();
