-- ==========================================
-- CAMERA LOGS TABLE
-- ==========================================
-- Stores real-time logs from Raspberry Pi cameras

CREATE TABLE IF NOT EXISTS camera_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    field_id UUID NOT NULL REFERENCES football_fields(id) ON DELETE CASCADE,
    level TEXT NOT NULL, -- 'INFO', 'WARNING', 'ERROR'
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast retrieval (we'll query by field_id + created_at)
CREATE INDEX IF NOT EXISTS idx_camera_logs_field_created ON camera_logs(field_id, created_at DESC);

-- Enable RLS
ALTER TABLE camera_logs ENABLE ROW LEVEL SECURITY;

-- Allow all access (Pi needs to INSERT, Admin needs to SELECT)
CREATE POLICY "Allow all access to camera_logs" 
    ON camera_logs 
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- Auto-cleanup function (keep logs for 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_logs()
RETURNS void AS $$
BEGIN
    DELETE FROM camera_logs 
    WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;


