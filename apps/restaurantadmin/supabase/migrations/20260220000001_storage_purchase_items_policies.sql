-- Storage RLS: allow authenticated users to read, upload, and update files
-- in the purchase_items bucket (item images + category_images).
-- Fixes: "new row violates row-level security policy" / 403 on upload.
-- Run this in Supabase SQL Editor if the bucket already exists via Dashboard.

-- Allow read access
DROP POLICY IF EXISTS "purchase_items_select" ON storage.objects;
CREATE POLICY "purchase_items_select" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'purchase_items');

-- Allow authenticated users to upload (INSERT)
DROP POLICY IF EXISTS "purchase_items_insert" ON storage.objects;
CREATE POLICY "purchase_items_insert" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'purchase_items');

-- Allow authenticated users to update (e.g. replace category image with upsert)
DROP POLICY IF EXISTS "purchase_items_update" ON storage.objects;
CREATE POLICY "purchase_items_update" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'purchase_items')
  WITH CHECK (bucket_id = 'purchase_items');
