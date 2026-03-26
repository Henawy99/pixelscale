-- Create table to track scanner heartbeats for monitoring scanner status
CREATE TABLE IF NOT EXISTS public.scanner_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scanner_id TEXT NOT NULL UNIQUE,
    scanner_name TEXT,
    hostname TEXT,
    watch_path TEXT,
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'online' CHECK (status IN ('online', 'offline')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.scanner_heartbeats ENABLE ROW LEVEL SECURITY;

-- Allow all operations for authenticated users (admin app)
CREATE POLICY "Allow all for authenticated users" ON public.scanner_heartbeats
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Allow scanner service to upsert heartbeats (via service role or scanner secret)
CREATE POLICY "Allow scanner heartbeats" ON public.scanner_heartbeats
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Create index for quick status lookups
CREATE INDEX IF NOT EXISTS idx_scanner_heartbeats_status ON public.scanner_heartbeats(status);
CREATE INDEX IF NOT EXISTS idx_scanner_heartbeats_last_heartbeat ON public.scanner_heartbeats(last_heartbeat);

-- Function to check and mark scanners as offline if no heartbeat in 60 seconds
CREATE OR REPLACE FUNCTION check_scanner_status()
RETURNS void AS $$
DECLARE
    offline_scanner RECORD;
BEGIN
    -- Find scanners that haven't sent heartbeat in 60 seconds and mark them offline
    FOR offline_scanner IN
        SELECT id, scanner_id, scanner_name
        FROM public.scanner_heartbeats
        WHERE status = 'online'
        AND last_heartbeat < NOW() - INTERVAL '60 seconds'
    LOOP
        UPDATE public.scanner_heartbeats
        SET status = 'offline', updated_at = NOW()
        WHERE id = offline_scanner.id;
        
        -- Log the status change
        RAISE NOTICE 'Scanner % (%) marked as offline', offline_scanner.scanner_name, offline_scanner.scanner_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Comment on table
COMMENT ON TABLE public.scanner_heartbeats IS 'Tracks heartbeats from receipt scanner services to monitor online/offline status';
