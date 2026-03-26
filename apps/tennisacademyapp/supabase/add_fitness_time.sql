-- Add fitness time columns to sessions (both tables just in case, based on earlier schema check)
ALTER TABLE public.training_sessions
ADD COLUMN IF NOT EXISTS fitness_start_time TIME,
ADD COLUMN IF NOT EXISTS fitness_end_time TIME;

ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS fitness_start_time TIME,
ADD COLUMN IF NOT EXISTS fitness_end_time TIME;
