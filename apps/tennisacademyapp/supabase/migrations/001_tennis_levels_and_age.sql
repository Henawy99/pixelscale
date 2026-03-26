-- Run this in Supabase SQL Editor if you already have the academy-app database.
-- Adds age, makes level nullable and supports tennis level IDs.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS age INTEGER;

ALTER TABLE profiles ALTER COLUMN level DROP NOT NULL;
ALTER TABLE profiles ALTER COLUMN level DROP DEFAULT;

-- Optional: update academies to tennis if you had football/padel
UPDATE academies SET icon = 'tennis', name = 'Tennis Academy', name_ar = 'أكاديمية التنس',
  description = 'Tennis training academy', description_ar = 'أكاديمية تدريب التنس'
WHERE icon IN ('football', 'padel');
