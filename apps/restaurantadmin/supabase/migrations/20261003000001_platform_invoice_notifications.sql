-- =============================================================
-- Push notifications for new delivery-platform invoices
--
-- The VPS jobs add Lieferando (Sundays 20:00) and Foodora (Sundays 20:30) invoices through
-- receive-lieferando-invoices. Every 10 minutes notify-platform-invoices reads Lieferando payouts
-- from the PDFs and, once a batch has stopped arriving, sends one push per platform with what each
-- restaurant gets paid out. notified_at marks the invoices already announced.
-- Requires the Vault secret 'planner_service_key' (service-role key), as request_replan does.
-- =============================================================

ALTER TABLE platform_invoices ADD COLUMN IF NOT EXISTS notified_at TIMESTAMPTZ;

-- Everything already in the table counts as announced.
UPDATE platform_invoices SET notified_at = NOW() WHERE notified_at IS NULL;

CREATE OR REPLACE FUNCTION platform_invoice_notify_tick()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_key TEXT;
BEGIN
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'planner_service_key' LIMIT 1;
  IF v_key IS NULL THEN
    RAISE WARNING 'platform_invoice_notify_tick: vault secret planner_service_key is missing';
    RETURN;
  END IF;
  PERFORM net.http_post(
    url := 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/notify-platform-invoices',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::JSONB,
    timeout_milliseconds := 60000
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'platform_invoice_notify_tick failed: %', SQLERRM;
END;
$$;
REVOKE ALL ON FUNCTION platform_invoice_notify_tick() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.schedule('platform-invoice-notifications', '*/10 * * * *', 'SELECT public.platform_invoice_notify_tick()');
END $$;
