-- =============================================================
-- ANIMIGHT — Supabase Setup
-- Run this once in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/hdmycuncdlbefiiwlrca/sql/new
-- =============================================================

-- 1. Wallpapers table (admin-uploaded)
CREATE TABLE IF NOT EXISTS animight_wallpapers (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  name         TEXT        NOT NULL,
  bluetooth_name TEXT      NOT NULL DEFAULT '',
  image_url    TEXT        NOT NULL,
  is_coming_soon BOOLEAN   DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE animight_wallpapers ENABLE ROW LEVEL SECURITY;

-- Anyone can read wallpapers
CREATE POLICY "animight_wallpapers_read"
  ON animight_wallpapers FOR SELECT USING (true);

-- Only authenticated users (admin) can insert / update / delete
CREATE POLICY "animight_wallpapers_insert"
  ON animight_wallpapers FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "animight_wallpapers_delete"
  ON animight_wallpapers FOR DELETE USING (auth.role() = 'authenticated');

-- 2. Daily visitors table
CREATE TABLE IF NOT EXISTS animight_visitors (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  visited_at  TIMESTAMPTZ DEFAULT NOW(),
  visit_date  DATE        DEFAULT CURRENT_DATE
);

ALTER TABLE animight_visitors ENABLE ROW LEVEL SECURITY;

-- Anyone can insert a visit (app open)
CREATE POLICY "animight_visitors_insert"
  ON animight_visitors FOR INSERT WITH CHECK (true);

-- Only authenticated users (admin) can read visitor counts
CREATE POLICY "animight_visitors_read"
  ON animight_visitors FOR SELECT USING (true);
