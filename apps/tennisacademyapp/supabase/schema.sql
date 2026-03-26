-- ============================================
-- Academy App Database Schema
-- Run this in the Supabase SQL Editor
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===================== PROFILES =====================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'player' CHECK (role IN ('player', 'parent', 'coach', 'admin')),
  parent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  age INTEGER,
  level TEXT,
  language_pref TEXT NOT NULL DEFAULT 'en' CHECK (language_pref IN ('en', 'ar')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tennis levels: candy, flower, bee, pro_red, tiger, lions, pro_orange, avocado, lemons, apple, point, game, game_adult, professional, pro_matches
-- For existing DBs, run: ALTER TABLE profiles ADD COLUMN IF NOT EXISTS age INTEGER;
-- ALTER TABLE profiles ALTER COLUMN level DROP NOT NULL; ALTER TABLE profiles ALTER COLUMN level DROP DEFAULT;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ===================== ACADEMIES =====================
CREATE TABLE IF NOT EXISTS academies (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  description TEXT DEFAULT '',
  description_ar TEXT DEFAULT '',
  icon TEXT DEFAULT 'tennis',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE academies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Academies viewable by everyone" ON academies
  FOR SELECT USING (true);

CREATE POLICY "Only admins can manage academies" ON academies
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Seed default tennis academy
INSERT INTO academies (name, name_ar, description, description_ar, icon) VALUES
  ('Tennis Academy', 'أكاديمية التنس', 'Tennis training academy', 'أكاديمية تدريب التنس', 'tennis')
ON CONFLICT DO NOTHING;

-- ===================== ACADEMY STAFF =====================
CREATE TABLE IF NOT EXISTS academy_staff (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'coach')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(academy_id, user_id)
);

ALTER TABLE academy_staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff viewable by authenticated" ON academy_staff
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Only admins can manage staff" ON academy_staff
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== TRAINING SESSIONS =====================
CREATE TABLE IF NOT EXISTS training_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  coach_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  title_ar TEXT NOT NULL DEFAULT '',
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  level TEXT NOT NULL DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  max_players INTEGER NOT NULL DEFAULT 5,
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
  is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sessions viewable by authenticated" ON training_sessions
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins and coaches can manage sessions" ON training_sessions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'coach')
    )
  );

-- ===================== DISCOUNT CODES =====================
CREATE TABLE IF NOT EXISTS discount_codes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  discount_percent INTEGER NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100),
  academy_id UUID REFERENCES academies(id) ON DELETE SET NULL,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until TIMESTAMPTZ NOT NULL,
  max_uses INTEGER NOT NULL DEFAULT 100,
  current_uses INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE discount_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Active codes viewable by authenticated" ON discount_codes
  FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = TRUE);

CREATE POLICY "Admins can manage codes" ON discount_codes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== BOOKINGS =====================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'confirmed')),
  payment_method TEXT CHECK (payment_method IN ('cash', 'external')),
  discount_code_id UUID REFERENCES discount_codes(id) ON DELETE SET NULL,
  final_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  UNIQUE(player_id, session_id)
);

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players see own bookings" ON bookings
  FOR SELECT USING (
    auth.uid() = player_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'coach'))
    OR EXISTS (SELECT 1 FROM profiles WHERE id = player_id AND parent_id = auth.uid())
  );

CREATE POLICY "Players can create bookings" ON bookings
  FOR INSERT WITH CHECK (
    auth.uid() = player_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = player_id AND parent_id = auth.uid())
  );

CREATE POLICY "Admins can manage all bookings" ON bookings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== SUBSCRIPTIONS =====================
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('monthly', 'per_session')),
  level TEXT NOT NULL DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players see own subscriptions" ON subscriptions
  FOR SELECT USING (
    auth.uid() = player_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can manage subscriptions" ON subscriptions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== PAYMENTS =====================
CREATE TABLE IF NOT EXISTS payments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  amount DECIMAL(10,2) NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('cash', 'external')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed')),
  confirmed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  receipt_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players see own payments" ON payments
  FOR SELECT USING (
    auth.uid() = player_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can manage payments" ON payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== ATTENDANCE =====================
CREATE TABLE IF NOT EXISTS attendance (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'absent' CHECK (status IN ('present', 'absent')),
  marked_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, player_id)
);

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Attendance viewable by relevant users" ON attendance
  FOR SELECT USING (
    auth.uid() = player_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'coach'))
  );

CREATE POLICY "Coaches and admins can manage attendance" ON attendance
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'coach'))
  );

-- ===================== ANNOUNCEMENTS =====================
CREATE TABLE IF NOT EXISTS announcements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  academy_id UUID REFERENCES academies(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  title_ar TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  body_ar TEXT NOT NULL DEFAULT '',
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Announcements viewable by authenticated" ON announcements
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage announcements" ON announcements
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== NOTIFICATIONS =====================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  title_ar TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  body_ar TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'general',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can create notifications" ON notifications
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.uid() = user_id
  );

-- ===================== COURT SCHEDULES (admin weekly slots) =====================
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

CREATE POLICY "Authenticated can read court_schedules" ON court_schedules
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins insert court_schedules" ON court_schedules
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins update delete court_schedules" ON court_schedules
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ===================== PLAYER SLOT REGISTRATIONS (3 per player, max 4 per slot) =====================
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

CREATE POLICY "Players see own registrations" ON player_slot_registrations
  FOR SELECT USING (auth.uid() = player_id);

CREATE POLICY "Admins see all registrations" ON player_slot_registrations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Players insert own pending" ON player_slot_registrations
  FOR INSERT WITH CHECK (auth.uid() = player_id AND status = 'pending');

CREATE POLICY "Admins update registrations" ON player_slot_registrations
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Players delete own" ON player_slot_registrations
  FOR DELETE USING (auth.uid() = player_id);

-- ===================== HELPER VIEWS =====================

-- View: sessions with booking counts
CREATE OR REPLACE VIEW sessions_with_counts AS
SELECT
  ts.*,
  a.name as academy_name,
  a.name_ar as academy_name_ar,
  p.full_name as coach_name,
  COALESCE(bc.bookings_count, 0) as bookings_count
FROM training_sessions ts
LEFT JOIN academies a ON ts.academy_id = a.id
LEFT JOIN profiles p ON ts.coach_id = p.id
LEFT JOIN (
  SELECT session_id, COUNT(*) as bookings_count
  FROM bookings
  WHERE status IN ('pending', 'approved')
  GROUP BY session_id
) bc ON ts.id = bc.session_id;

-- ===================== RPC FUNCTIONS =====================

-- Increment discount code usage
CREATE OR REPLACE FUNCTION increment_discount_usage(code_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE discount_codes
  SET current_uses = current_uses + 1
  WHERE id = code_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
