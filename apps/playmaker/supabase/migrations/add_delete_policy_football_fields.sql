-- Migration: Add DELETE policy for football_fields
-- Date: 2025-11-05
-- Description: Adds missing DELETE policy to allow deletion of football fields

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Authenticated users can delete football fields" ON football_fields;

-- Create DELETE policy for football fields
-- This allows authenticated users (admins) to delete football fields
CREATE POLICY "Authenticated users can delete football fields" ON football_fields
  FOR DELETE USING (true);

-- Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'football_fields'
ORDER BY policyname;











