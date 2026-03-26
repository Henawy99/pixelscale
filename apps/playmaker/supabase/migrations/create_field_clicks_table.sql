-- Create field_clicks table for tracking user interactions with football fields
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS field_clicks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    field_id TEXT NOT NULL,
    user_id TEXT,
    clicked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    source VARCHAR(50) DEFAULT 'app' -- 'app', 'map', 'search', 'recommendation'
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_field_clicks_field_id ON field_clicks(field_id);
CREATE INDEX IF NOT EXISTS idx_field_clicks_user_id ON field_clicks(user_id);
CREATE INDEX IF NOT EXISTS idx_field_clicks_clicked_at ON field_clicks(clicked_at);
CREATE INDEX IF NOT EXISTS idx_field_clicks_field_date ON field_clicks(field_id, clicked_at);
CREATE INDEX IF NOT EXISTS idx_field_clicks_source ON field_clicks(source);

-- Enable Row Level Security
ALTER TABLE field_clicks ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert (track clicks)
CREATE POLICY "Anyone can track clicks" ON field_clicks
    FOR INSERT WITH CHECK (true);

-- Policy: Only admins can read all clicks (for analytics)
CREATE POLICY "Admins can read all clicks" ON field_clicks
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admin_devices 
            WHERE admin_email = auth.jwt() ->> 'email'
        )
        OR auth.role() = 'service_role'
    );

-- Policy: Users can read their own clicks
CREATE POLICY "Users can read own clicks" ON field_clicks
    FOR SELECT USING (user_id = auth.uid()::TEXT);

-- Function to get field click statistics
CREATE OR REPLACE FUNCTION get_field_click_stats(p_field_id TEXT)
RETURNS TABLE (
    total_clicks BIGINT,
    clicks_today BIGINT,
    clicks_this_week BIGINT,
    clicks_this_month BIGINT,
    unique_users BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_clicks,
        COUNT(*) FILTER (WHERE clicked_at >= CURRENT_DATE)::BIGINT as clicks_today,
        COUNT(*) FILTER (WHERE clicked_at >= DATE_TRUNC('week', CURRENT_DATE))::BIGINT as clicks_this_week,
        COUNT(*) FILTER (WHERE clicked_at >= DATE_TRUNC('month', CURRENT_DATE))::BIGINT as clicks_this_month,
        COUNT(DISTINCT user_id)::BIGINT as unique_users
    FROM field_clicks
    WHERE field_id = p_field_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get recent clicks for a field (for admin view)
CREATE OR REPLACE FUNCTION get_recent_field_clicks(p_field_id TEXT, p_limit INT DEFAULT 50)
RETURNS TABLE (
    id UUID,
    user_id TEXT,
    user_name TEXT,
    user_email TEXT,
    clicked_at TIMESTAMP WITH TIME ZONE,
    source VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fc.id,
        fc.user_id,
        COALESCE(pp.name, 'Anonymous')::TEXT as user_name,
        COALESCE(pp.email, 'N/A')::TEXT as user_email,
        fc.clicked_at,
        fc.source
    FROM field_clicks fc
    LEFT JOIN player_profiles pp ON fc.user_id = pp.id
    WHERE fc.field_id = p_field_id
    ORDER BY fc.clicked_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_field_click_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recent_field_clicks(TEXT, INT) TO authenticated;
