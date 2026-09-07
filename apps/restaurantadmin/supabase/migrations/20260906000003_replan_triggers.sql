-- =============================================================
-- Replanning triggers
-- Calls plan-routes Edge Function on new delivery orders
-- and on driver online/offline status changes.
-- =============================================================

-- NOTE: These triggers use Supabase Database Webhooks (pg_net).
-- They must be configured via the Supabase Dashboard > Database > Webhooks.
-- 
-- Alternative: use a Postgres trigger function that calls pg_net.http_post
-- to invoke the plan-routes edge function.

-- Trigger function to call plan-routes on new delivery order
CREATE OR REPLACE FUNCTION notify_plan_routes_new_order()
RETURNS trigger AS $$
DECLARE
  supabase_url TEXT;
  service_role_key TEXT;
BEGIN
  -- Only trigger for delivery orders with coordinates
  IF NEW.fulfillment_type = 'delivery' 
     AND NEW.delivery_latitude IS NOT NULL 
     AND NEW.delivery_longitude IS NOT NULL
     AND (NEW.delivery_status IS NULL OR NEW.delivery_status = 'ready_to_deliver')
  THEN
    -- Get the Supabase URL from environment or hardcode
    supabase_url := current_setting('app.supabase_url', true);
    IF supabase_url IS NULL THEN
      supabase_url := 'https://iluhlynzkgubtaswvgwt.supabase.co';
    END IF;

    service_role_key := current_setting('app.service_role_key', true);
    
    -- Use pg_net to call the edge function asynchronously
    IF service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url := supabase_url || '/functions/v1/plan-routes',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_role_key
        ),
        body := jsonb_build_object(
          'brand_id', NEW.brand_id,
          'trigger_reason', 'new_order'
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table (INSERT only)
DROP TRIGGER IF EXISTS trigger_plan_routes_new_order ON orders;
CREATE TRIGGER trigger_plan_routes_new_order
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_new_order();


-- Trigger function to call plan-routes on driver online/offline change
CREATE OR REPLACE FUNCTION notify_plan_routes_driver_status()
RETURNS trigger AS $$
DECLARE
  supabase_url TEXT;
  service_role_key TEXT;
  brand_id_val UUID;
BEGIN
  -- Only trigger when is_online changes
  IF OLD.is_online IS DISTINCT FROM NEW.is_online THEN
    supabase_url := current_setting('app.supabase_url', true);
    IF supabase_url IS NULL THEN
      supabase_url := 'https://iluhlynzkgubtaswvgwt.supabase.co';
    END IF;

    service_role_key := current_setting('app.service_role_key', true);

    -- Get a brand_id from the most recent order or delivery_settings
    SELECT ds.brand_id INTO brand_id_val
    FROM delivery_settings ds
    LIMIT 1;

    IF service_role_key IS NOT NULL AND brand_id_val IS NOT NULL THEN
      PERFORM net.http_post(
        url := supabase_url || '/functions/v1/plan-routes',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_role_key
        ),
        body := jsonb_build_object(
          'brand_id', brand_id_val,
          'trigger_reason', 'driver_status_change'
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on drivers table (UPDATE only)
DROP TRIGGER IF EXISTS trigger_plan_routes_driver_status ON drivers;
CREATE TRIGGER trigger_plan_routes_driver_status
  AFTER UPDATE ON drivers
  FOR EACH ROW
  EXECUTE FUNCTION notify_plan_routes_driver_status();
