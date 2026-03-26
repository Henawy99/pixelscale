-- ==========================================
-- CAMERA STATUS TABLE
-- ==========================================
-- This table tracks the health status of Raspberry Pi
-- camera recorders at each field.

-- Create camera_status table for heartbeat monitoring
CREATE TABLE IF NOT EXISTS camera_status (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    field_id TEXT NOT NULL UNIQUE REFERENCES football_fields(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'offline',  -- 'online', 'offline', 'recording', 'error'
    last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
    details JSONB DEFAULT '{}',  -- Additional status info
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_camera_status_field_id ON camera_status(field_id);
CREATE INDEX IF NOT EXISTS idx_camera_status_last_heartbeat ON camera_status(last_heartbeat);

-- Enable Row Level Security
ALTER TABLE camera_status ENABLE ROW LEVEL SECURITY;

-- Allow read access for authenticated users
CREATE POLICY "Allow read access for authenticated users"
    ON camera_status
    FOR SELECT
    USING (true);

-- Allow insert/update for service role (from Pi scripts)
CREATE POLICY "Allow insert for service role"
    ON camera_status
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow update for service role"
    ON camera_status
    FOR UPDATE
    USING (true);

-- ==========================================
-- ADD COLUMNS TO BALL_TRACKING_JOBS TABLE
-- ==========================================
-- Add booking_id and field_id to link jobs to bookings

ALTER TABLE ball_tracking_jobs 
ADD COLUMN IF NOT EXISTS booking_id TEXT,
ADD COLUMN IF NOT EXISTS field_id TEXT;

-- Add indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_ball_tracking_booking_id ON ball_tracking_jobs(booking_id);
CREATE INDEX IF NOT EXISTS idx_ball_tracking_field_id ON ball_tracking_jobs(field_id);

-- ==========================================
-- FUNCTION TO AUTO-UPDATE CAMERA STATUS
-- ==========================================
-- Automatically mark cameras as offline if no heartbeat in 5 minutes

CREATE OR REPLACE FUNCTION check_camera_offline()
RETURNS void AS $$
BEGIN
    UPDATE camera_status 
    SET status = 'offline'
    WHERE last_heartbeat < NOW() - INTERVAL '5 minutes'
    AND status != 'offline';
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run every minute (requires pg_cron extension)
-- Note: You may need to enable pg_cron in your Supabase dashboard
-- SELECT cron.schedule('check-camera-offline', '* * * * *', 'SELECT check_camera_offline()');

-- ==========================================
-- VIEW FOR ADMIN DASHBOARD
-- ==========================================
-- Quick view of all camera statuses with field info

CREATE OR REPLACE VIEW camera_status_with_fields AS
SELECT 
    cs.id,
    cs.field_id,
    ff.football_field_name,
    ff.location_name,
    ff.camera_ip_address,
    ff.raspberry_pi_ip,
    cs.status,
    cs.last_heartbeat,
    cs.details,
    CASE 
        WHEN cs.last_heartbeat > NOW() - INTERVAL '2 minutes' THEN 'healthy'
        WHEN cs.last_heartbeat > NOW() - INTERVAL '5 minutes' THEN 'warning'
        ELSE 'critical'
    END as health_status
FROM camera_status cs
JOIN football_fields ff ON cs.field_id = ff.id;

-- Grant access to the view
GRANT SELECT ON camera_status_with_fields TO authenticated;
GRANT SELECT ON camera_status_with_fields TO service_role;

-- ==========================================
-- NOTIFICATION LOGS TABLE
-- ==========================================
-- Track all recording-related notifications sent

CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    booking_id TEXT,
    event_type TEXT NOT NULL,
    title TEXT,
    body TEXT,
    user_ids TEXT[],
    device_count INTEGER DEFAULT 0,
    fcm_response JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for querying by booking
CREATE INDEX IF NOT EXISTS idx_notification_logs_booking ON notification_logs(booking_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_created ON notification_logs(created_at);

-- Enable RLS
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Service role full access to notification_logs"
    ON notification_logs
    FOR ALL
    USING (true);

