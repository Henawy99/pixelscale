-- Add class_name to profiles for registered players
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS class_name TEXT;

-- Add new fields to offline players table
ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS started_playing_year INT,
  ADD COLUMN IF NOT EXISTS dominant_hand TEXT;

-- Reload schema caches
NOTIFY pgrst, 'reload schema';
