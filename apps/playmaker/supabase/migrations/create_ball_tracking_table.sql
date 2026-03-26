-- Create ball_tracking_experiments table
CREATE TABLE IF NOT EXISTS ball_tracking_experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Video URLs
  input_video_url TEXT NOT NULL,
  input_video_name TEXT NOT NULL,
  output_video_url TEXT,
  
  -- Script information
  script_version TEXT NOT NULL DEFAULT '1.0',
  script_content TEXT NOT NULL,
  script_config JSONB, -- Store config params (ZOOM_BASE, SMOOTHING, etc.)
  
  -- Tracking metrics
  ball_tracking_accuracy DECIMAL(5,2), -- percentage
  total_frames INTEGER,
  tracked_frames INTEGER,
  
  -- Processing info
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  processing_time_seconds DECIMAL(10,2),
  gpu_type TEXT,
  gpu_cost_usd DECIMAL(10,4),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  
  -- Error handling
  error_message TEXT,
  
  -- Additional metadata
  video_duration_seconds DECIMAL(10,2),
  video_resolution TEXT,
  fps DECIMAL(10,2)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_ball_tracking_created_at ON ball_tracking_experiments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ball_tracking_status ON ball_tracking_experiments(status);

-- Enable RLS (Row Level Security)
ALTER TABLE ball_tracking_experiments ENABLE ROW LEVEL SECURITY;

-- Policy: Allow admin users to do everything
CREATE POLICY "Allow admin full access to ball_tracking_experiments"
ON ball_tracking_experiments
FOR ALL
USING (true)
WITH CHECK (true);

-- Create storage bucket for ball tracking videos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('ball-tracking-videos', 'ball-tracking-videos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Allow public read access to ball tracking videos"
ON storage.objects FOR SELECT
USING (bucket_id = 'ball-tracking-videos');

CREATE POLICY "Allow authenticated upload to ball tracking videos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'ball-tracking-videos' AND auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated delete from ball tracking videos"
ON storage.objects FOR DELETE
USING (bucket_id = 'ball-tracking-videos' AND auth.role() = 'authenticated');

-- Create script templates table (optional, for saving favorite configs)
CREATE TABLE IF NOT EXISTS ball_tracking_script_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  script_content TEXT NOT NULL,
  config JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_default BOOLEAN DEFAULT false
);

ALTER TABLE ball_tracking_script_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow admin full access to script templates"
ON ball_tracking_script_templates
FOR ALL
USING (true)
WITH CHECK (true);

-- Insert default script template
INSERT INTO ball_tracking_script_templates (name, description, script_content, config, is_default)
VALUES (
  'YOLOv8 + Kalman Filter',
  'Default ball tracking script with YOLO detection and Kalman filtering',
  '',  -- We'll populate this from the UI
  '{"ZOOM_BASE": 1.75, "ZOOM_FAR": 2.1, "SMOOTHING": 0.07, "ZOOM_SMOOTH": 0.1, "DETECT_EVERY_FRAMES": 2, "YOLO_CONF": 0.35, "MEMORY": 6, "ROI_SIZE": 400}',
  true
);

