-- Create al_baseet_visits table for tracking page visitors
-- This table stores visitor data for the Al Baseet promo app

CREATE TABLE IF NOT EXISTS al_baseet_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT,
    platform TEXT DEFAULT 'android',
    visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_duration_seconds INT DEFAULT 0,
    screen_viewed TEXT DEFAULT 'home',
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_al_baseet_visits_visited_at ON al_baseet_visits(visited_at);
CREATE INDEX IF NOT EXISTS idx_al_baseet_visits_device_id ON al_baseet_visits(device_id);
CREATE INDEX IF NOT EXISTS idx_al_baseet_visits_platform ON al_baseet_visits(platform);

-- Enable Row Level Security
ALTER TABLE al_baseet_visits ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert visits (anonymous tracking)
CREATE POLICY "Anyone can track visits" ON al_baseet_visits
    FOR INSERT
    WITH CHECK (true);

-- Policy: Anyone can read total count (for display)
CREATE POLICY "Anyone can read visit counts" ON al_baseet_visits
    FOR SELECT
    USING (true);

-- Function to get total visitor count
CREATE OR REPLACE FUNCTION get_al_baseet_visitor_count()
RETURNS BIGINT AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM al_baseet_visits);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get today's visitor count
CREATE OR REPLACE FUNCTION get_al_baseet_today_visitors()
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) 
        FROM al_baseet_visits 
        WHERE visited_at >= CURRENT_DATE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unique visitors (by device_id)
CREATE OR REPLACE FUNCTION get_al_baseet_unique_visitors()
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT device_id) 
        FROM al_baseet_visits 
        WHERE device_id IS NOT NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT ALL ON al_baseet_visits TO anon;
GRANT ALL ON al_baseet_visits TO authenticated;
GRANT EXECUTE ON FUNCTION get_al_baseet_visitor_count() TO anon;
GRANT EXECUTE ON FUNCTION get_al_baseet_visitor_count() TO authenticated;
GRANT EXECUTE ON FUNCTION get_al_baseet_today_visitors() TO anon;
GRANT EXECUTE ON FUNCTION get_al_baseet_today_visitors() TO authenticated;
GRANT EXECUTE ON FUNCTION get_al_baseet_unique_visitors() TO anon;
GRANT EXECUTE ON FUNCTION get_al_baseet_unique_visitors() TO authenticated;
