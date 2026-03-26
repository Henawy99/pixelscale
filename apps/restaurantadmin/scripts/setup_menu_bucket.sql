-- Run this SQL in Supabase SQL Editor to create the 'menus' storage bucket
-- This will allow you to host your menu website files

-- Create the storage bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'menus',
  'menus',
  true,  -- Public bucket so anyone can view the menu
  10485760,  -- 10MB file size limit
  ARRAY['text/html', 'text/css', 'application/javascript', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO NOTHING;

-- Create a policy to allow public read access
CREATE POLICY "Public menu access" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'menus');

-- Create a policy to allow authenticated users to upload
CREATE POLICY "Authenticated users can upload menus" ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'menus' AND auth.role() = 'authenticated');


