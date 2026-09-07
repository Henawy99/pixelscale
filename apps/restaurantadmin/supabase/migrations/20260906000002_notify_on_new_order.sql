-- ==========================================================
-- Migration: Automatic Push Notifications for New Orders
-- ==========================================================
-- Whenever a new order is confirmed in public.orders (from Foodora,
-- Lieferando, Web Ordering, Scanned Receipt, POS, etc.), this trigger
-- asynchronously calls the send-push-notification Edge Function via pg_net.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.notify_on_new_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  brand_name text := '';
  order_source text := '';
  price_text text := '';
  body_text text := '';
  title_text text := '';
  order_ref text := '';
  should_notify boolean := false;
BEGIN
  -- Determine whether we should notify:
  -- 1. On INSERT: Notify if status is confirmed (or any status other than pending_payment / cancelled)
  -- 2. On UPDATE: Notify if status transitioned from pending_payment to confirmed
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NULL OR (NEW.status <> 'pending_payment' AND NEW.status <> 'cancelled') THEN
      should_notify := true;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'pending_payment' AND NEW.status = 'confirmed' THEN
      should_notify := true;
    END IF;
  END IF;

  IF NOT should_notify THEN
    RETURN NEW;
  END IF;

  -- Lookup brand name if brand_id is set
  IF NEW.brand_id IS NOT NULL THEN
    SELECT name INTO brand_name FROM public.brands WHERE id = NEW.brand_id;
  END IF;

  -- Determine platform / order source (e.g. Foodora, Lieferando, Web, Store, etc.)
  order_source := COALESCE(NULLIF(TRIM(NEW.order_type_name), ''), '');

  -- Format price as €XX.XX
  IF NEW.total_price IS NOT NULL THEN
    price_text := '€' || TO_CHAR(NEW.total_price, 'FM999999990.00');
  ELSE
    price_text := '€0.00';
  END IF;

  -- Title: e.g. "🔔 New Foodora Order (€24.50)" or "🔔 New Order: DEVILS SMASH BURGER"
  IF order_source <> '' AND brand_name <> '' THEN
    title_text := '🔔 New ' || order_source || ' Order (' || price_text || ')';
  ELSIF order_source <> '' THEN
    title_text := '🔔 New ' || order_source || ' Order (' || price_text || ')';
  ELSIF brand_name <> '' THEN
    title_text := '🔔 New Order: ' || brand_name || ' (' || price_text || ')';
  ELSE
    title_text := '🔔 New Order (' || price_text || ')';
  END IF;

  -- Order identifier (daily number #X or order number)
  IF NEW.daily_order_number IS NOT NULL THEN
    order_ref := '#' || NEW.daily_order_number::text;
  ELSIF NEW.order_number IS NOT NULL AND NEW.order_number <> '' THEN
    order_ref := '#' || NEW.order_number;
  ELSIF NEW.public_reference IS NOT NULL AND NEW.public_reference <> '' THEN
    order_ref := '#' || NEW.public_reference;
  ELSIF NEW.platform_order_id IS NOT NULL AND NEW.platform_order_id <> '' THEN
    order_ref := '#' || NEW.platform_order_id;
  END IF;

  -- Build body text: "DEVILS SMASH BURGER • Delivery • #5 • John Doe"
  body_text := '';
  IF brand_name <> '' THEN
    body_text := brand_name;
  END IF;

  IF NEW.fulfillment_type IS NOT NULL AND NEW.fulfillment_type <> '' THEN
    IF body_text <> '' THEN
      body_text := body_text || ' • ' || INITCAP(NEW.fulfillment_type);
    ELSE
      body_text := INITCAP(NEW.fulfillment_type);
    END IF;
  END IF;

  IF order_ref <> '' THEN
    IF body_text <> '' THEN
      body_text := body_text || ' • ' || order_ref;
    ELSE
      body_text := order_ref;
    END IF;
  END IF;

  IF NEW.customer_name IS NOT NULL AND TRIM(NEW.customer_name) <> '' THEN
    IF body_text <> '' THEN
      body_text := body_text || ' • ' || TRIM(NEW.customer_name);
    ELSE
      body_text := TRIM(NEW.customer_name);
    END IF;
  END IF;

  IF body_text = '' THEN
    body_text := 'New order received for ' || price_text;
  END IF;

  -- Asynchronously post to send-push-notification Edge Function via pg_net
  PERFORM net.http_post(
    url := 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODU2NjY1NCwiZXhwIjoyMDY0MTQyNjU0fQ.37EjOyT9otsKJx9lsEI1xzZjMvz8XGOucyi35ePUq_8'
    ),
    body := jsonb_build_object(
      'title', title_text,
      'body', body_text,
      'data', jsonb_build_object(
        'type', 'order',
        'order_id', NEW.id::text,
        'brand_id', COALESCE(NEW.brand_id::text, ''),
        'platform', order_source,
        'price', price_text
      )
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Non-fatal: do not block order creation if notification dispatch fails
  RAISE WARNING 'notify_on_new_order trigger error: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Attach trigger to public.orders table
DROP TRIGGER IF EXISTS trigger_notify_on_new_order ON public.orders;
CREATE TRIGGER trigger_notify_on_new_order
  AFTER INSERT OR UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_order();
