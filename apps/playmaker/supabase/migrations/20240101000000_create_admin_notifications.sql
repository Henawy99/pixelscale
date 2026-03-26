-- =====================================================
-- ADMIN PUSH NOTIFICATIONS SETUP
-- =====================================================
-- This migration sets up the infrastructure for sending
-- push notifications to admin devices when new users sign up
-- =====================================================

-- 1. Create table to store admin device tokens
CREATE TABLE IF NOT EXISTS admin_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email TEXT NOT NULL,
  fcm_token TEXT NOT NULL UNIQUE,
  device_name TEXT,
  last_active TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_admin_devices_email ON admin_devices(admin_email);
CREATE INDEX IF NOT EXISTS idx_admin_devices_token ON admin_devices(fcm_token);

-- Enable RLS (Row Level Security)
ALTER TABLE admin_devices ENABLE ROW LEVEL SECURITY;

-- Policy: Allow admins to insert/update their own tokens
CREATE POLICY admin_devices_insert_policy ON admin_devices
  FOR INSERT
  WITH CHECK (true); -- We'll validate admin email in the app

CREATE POLICY admin_devices_select_policy ON admin_devices
  FOR SELECT
  USING (true);

CREATE POLICY admin_devices_update_policy ON admin_devices
  FOR UPDATE
  USING (true);

-- 2. Create notification queue table (to be processed by Edge Function)
CREATE TABLE IF NOT EXISTS admin_notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_name TEXT,
  user_email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_admin_notification_queue_processed ON admin_notification_queue(processed);

-- Enable RLS
ALTER TABLE admin_notification_queue ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service role to manage queue
CREATE POLICY admin_notification_queue_policy ON admin_notification_queue
  FOR ALL
  USING (true);

-- 3. Create function to queue admin notification
CREATE OR REPLACE FUNCTION notify_admin_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Add new user to notification queue
  INSERT INTO admin_notification_queue (user_id, user_name, user_email)
  VALUES (NEW.id, NEW.name, NEW.email);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger on player_profiles insert
DROP TRIGGER IF EXISTS trigger_notify_admin_new_user ON player_profiles;
CREATE TRIGGER trigger_notify_admin_new_user
  AFTER INSERT ON player_profiles
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_new_user();

-- 4. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON admin_devices TO postgres, anon, authenticated, service_role;
GRANT ALL ON admin_notification_queue TO postgres, anon, authenticated, service_role;

COMMENT ON TABLE admin_devices IS 'Stores FCM tokens for admin devices to receive push notifications';
COMMENT ON TABLE admin_notification_queue IS 'Queue for processing admin notifications about new users';
COMMENT ON FUNCTION notify_admin_new_user() IS 'Queues push notification to admin when new user signs up';

