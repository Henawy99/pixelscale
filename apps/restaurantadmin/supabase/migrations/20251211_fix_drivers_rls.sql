-- Fix RLS policy for drivers table to allow admin to insert/update/delete

-- First, enable RLS if not already enabled
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to recreate them)
DROP POLICY IF EXISTS "Allow all for authenticated users" ON drivers;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON drivers;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON drivers;
DROP POLICY IF EXISTS "Allow delete for authenticated users" ON drivers;
DROP POLICY IF EXISTS "Allow select for authenticated users" ON drivers;

-- Create permissive policies for authenticated users
CREATE POLICY "Allow select for authenticated users" ON drivers
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert for authenticated users" ON drivers
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update for authenticated users" ON drivers
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete for authenticated users" ON drivers
    FOR DELETE TO authenticated USING (true);

-- Also fix worker_profiles table if it has similar issues
ALTER TABLE worker_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated users" ON worker_profiles;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON worker_profiles;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON worker_profiles;
DROP POLICY IF EXISTS "Allow delete for authenticated users" ON worker_profiles;
DROP POLICY IF EXISTS "Allow select for authenticated users" ON worker_profiles;

CREATE POLICY "Allow select for authenticated users" ON worker_profiles
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert for authenticated users" ON worker_profiles
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update for authenticated users" ON worker_profiles
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete for authenticated users" ON worker_profiles
    FOR DELETE TO authenticated USING (true);




