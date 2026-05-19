-- ============================================
-- Daily Rating Scraper Cron Job
-- ============================================
-- This sets up a pg_cron job that runs once daily at 6:00 AM UTC (8:00 AM Vienna time)
-- to scrape all platform ratings and send push alerts if any drop below 4.0
-- 
-- Prerequisites:
--   1. Enable pg_cron extension in Supabase Dashboard → Database → Extensions
--   2. Deploy the 'scrape-all-ratings' Edge Function
--   3. Set up FIREBASE_SERVICE_ACCOUNT_JSON in Supabase Function secrets
-- ============================================

-- Enable pg_cron and pg_net extensions (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule the daily scrape at 6:00 AM UTC (8:00 AM Vienna/CEST)
SELECT cron.schedule(
  'daily-rating-scrape',          -- job name (unique identifier)
  '0 6 * * *',                    -- cron expression: 6:00 AM UTC daily
  $$
  SELECT net.http_post(
    url := (SELECT CONCAT(decrypted_secret, '/functions/v1/scrape-all-ratings')
            FROM vault.decrypted_secrets
            WHERE name = 'supabase_url'
            LIMIT 1),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', CONCAT('Bearer ', (
        SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1
      ))
    ),
    body := '{}'::jsonb
  );
  $$
);

-- To check scheduled jobs:
-- SELECT * FROM cron.job;

-- To see job run history:
-- SELECT * FROM cron.job_run_detail ORDER BY start_time DESC LIMIT 20;

-- To unschedule:
-- SELECT cron.unschedule('daily-rating-scrape');

-- ============================================
-- ALTERNATIVE: Simple approach using Supabase URL directly
-- If vault secrets aren't set up, use this instead:
-- ============================================
-- 
-- SELECT cron.schedule(
--   'daily-rating-scrape',
--   '0 6 * * *',
--   $$
--   SELECT net.http_post(
--     url := 'https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/scrape-all-ratings',
--     headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
--     body := '{}'::jsonb
--   );
--   $$
-- );
