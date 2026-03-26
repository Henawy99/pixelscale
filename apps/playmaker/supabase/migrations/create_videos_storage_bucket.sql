-- Create videos storage bucket for ball tracking
-- Run this in Supabase Dashboard > SQL Editor

-- Create bucket (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('videos', 'videos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for videos bucket

-- Allow authenticated users to upload videos
CREATE POLICY "Allow authenticated uploads to videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'videos');

-- Allow public to read videos
CREATE POLICY "Allow public downloads from videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'videos');

-- Allow authenticated users to update their videos
CREATE POLICY "Allow authenticated updates to videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'videos');

-- Allow authenticated users to delete their videos
CREATE POLICY "Allow authenticated deletes from videos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'videos');

-- Allow service role full access (for Modal.com)
CREATE POLICY "Service role full access to videos"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id = 'videos');

-- Set bucket limits (optional)
-- Max file size: 500MB
-- Allowed MIME types: video files only







