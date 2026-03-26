-- ============================================================
-- Run this in Supabase Dashboard → SQL Editor → New query
-- Paste all below and click "Run"
-- ============================================================

-- Court schedules (admin-created recurring slots)
CREATE TABLE IF NOT EXISTS court_schedules (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  court_number SMALLINT NOT NULL CHECK (court_number IN (1, 2, 3, 4)),
  level TEXT NOT NULL,
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_recurring BOOLEAN NOT NULL DEFAULT TRUE,
  recurring_weekdays SMALLINT[],
  end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE court_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read court_schedules" ON court_schedules;
CREATE POLICY "Anyone authenticated can read court_schedules" ON court_schedules
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admins insert court_schedules" ON court_schedules;
CREATE POLICY "Admins insert court_schedules" ON court_schedules
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admins update delete court_schedules" ON court_schedules;
CREATE POLICY "Admins update delete court_schedules" ON court_schedules
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Player slot registrations (3 per player, recurring week; max 4 per slot)
CREATE TABLE IF NOT EXISTS player_slot_registrations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  court_number SMALLINT NOT NULL CHECK (court_number IN (1, 2, 3, 4)),
  level TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  weekday SMALLINT NOT NULL CHECK (weekday >= 0 AND weekday <= 6),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(player_id, court_number, level, start_time, end_time, weekday)
);

ALTER TABLE player_slot_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players see own registrations" ON player_slot_registrations;
CREATE POLICY "Players see own registrations" ON player_slot_registrations
  FOR SELECT USING (auth.uid() = player_id);

DROP POLICY IF EXISTS "Admins see all registrations" ON player_slot_registrations;
CREATE POLICY "Admins see all registrations" ON player_slot_registrations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Players can insert own (pending)" ON player_slot_registrations;
CREATE POLICY "Players can insert own (pending)" ON player_slot_registrations
  FOR INSERT WITH CHECK (auth.uid() = player_id AND status = 'pending');

DROP POLICY IF EXISTS "Admins can update status" ON player_slot_registrations;
CREATE POLICY "Admins can update status" ON player_slot_registrations
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Players delete own pending" ON player_slot_registrations;
CREATE POLICY "Players delete own pending" ON player_slot_registrations
  FOR DELETE USING (auth.uid() = player_id);
