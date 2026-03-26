-- Adding new profile columns for the User App
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS started_playing_year INT,
  ADD COLUMN IF NOT EXISTS dominant_hand TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Reload schema caches after altering tables by running:
NOTIFY pgrst, 'reload schema';
