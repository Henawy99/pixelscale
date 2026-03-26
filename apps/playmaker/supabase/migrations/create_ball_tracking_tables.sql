-- Ball Tracking Jobs Table
CREATE TABLE IF NOT EXISTS ball_tracking_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Video Info
  input_video_url TEXT NOT NULL,
  output_video_url TEXT,
  video_name TEXT NOT NULL,
  video_duration_seconds DECIMAL,
  video_size_mb DECIMAL,
  
  -- Processing Status
  status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
  progress_percent INTEGER DEFAULT 0,
  error_message TEXT,
  
  -- Script Configuration
  script_config JSONB NOT NULL, -- stores all YOLO params
  script_version TEXT DEFAULT '1.0',
  
  -- Metrics
  tracking_accuracy_percent INTEGER,
  frames_tracked INTEGER,
  total_frames INTEGER,
  processing_time_seconds DECIMAL,
  gpu_cost_usd DECIMAL,
  gpu_type TEXT,
  
  -- Logs
  processing_logs TEXT
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS ball_tracking_jobs_status_idx ON ball_tracking_jobs(status);
CREATE INDEX IF NOT EXISTS ball_tracking_jobs_created_at_idx ON ball_tracking_jobs(created_at DESC);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE ball_tracking_jobs;

-- RLS Policies (Admin only)
ALTER TABLE ball_tracking_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin can do everything on ball_tracking_jobs"
  ON ball_tracking_jobs
  FOR ALL
  USING (true)
  WITH CHECK (true);







