-- Migration: Add profile fields and recurring session support
-- Created at: 2026-02-21 12:00:00

-- 1. Update profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS started_playing_year INT,
ADD COLUMN IF NOT EXISTS dominant_hand TEXT CHECK (dominant_hand IN ('Right', 'Left', 'Both')),
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Update sessions table for recurrence
ALTER TABLE sessions
ADD COLUMN IF NOT EXISTS recurrence_id UUID, -- Links recurring sessions together
ADD COLUMN IF NOT EXISTS recurrence_rule TEXT; -- e.g., 'daily', 'weekly'

-- 3. Add constraint to started_playing_year
ALTER TABLE profiles
ADD CONSTRAINT check_started_playing_year
CHECK (started_playing_year <= EXTRACT(YEAR FROM CURRENT_DATE));

-- 4. Enable RLS for updates if not already (assuming profiles policies exist)
-- Policy to allow users to update their own profile
CREATE POLICY "Users can update own profile" ON profiles
FOR UPDATE USING (auth.uid() = id);

-- 5. Policy for storage (avatars)
-- Assuming 'avatars' bucket exists. If not, create it via dashboard or API.
-- (SQL cannot easily create buckets in standard Supabase setup without storage extension access,
-- usually done via UI, but we can add RLS for objects)
