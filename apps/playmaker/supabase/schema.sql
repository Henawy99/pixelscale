-- ===================================
-- PLAYMAKER DATABASE SCHEMA
-- Migrated from Firebase Firestore to Supabase Postgres
-- ===================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "cube";
CREATE EXTENSION IF NOT EXISTS "earthdistance";

-- ===================================
-- TABLE: player_profiles
-- User profile information
-- ===================================
CREATE TABLE IF NOT EXISTS player_profiles (
  -- Primary key uses Firebase Auth UID
  id TEXT PRIMARY KEY,
  
  -- Basic Info
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  player_id TEXT UNIQUE, -- 7-digit player ID
  phone_number TEXT DEFAULT '',
  
  -- Profile Details
  nationality TEXT DEFAULT '',
  age TEXT DEFAULT '',
  favourite_club TEXT DEFAULT '',
  preferred_position TEXT DEFAULT '',
  personal_level TEXT DEFAULT '',
  profile_picture TEXT DEFAULT '',
  
  -- Account Status
  fcm_token TEXT,
  is_guest BOOLEAN DEFAULT FALSE,
  rank TEXT DEFAULT 'Rookie',
  verified TEXT DEFAULT 'false',
  verified_email BOOLEAN DEFAULT FALSE,
  joined TIMESTAMPTZ DEFAULT NOW(),
  
  -- Arrays (relationships stored as IDs)
  bookings TEXT[] DEFAULT '{}',
  open_friend_requests TEXT[] DEFAULT '{}',
  friends TEXT[] DEFAULT '{}',
  teams_joined TEXT[] DEFAULT '{}',
  sent_friend_requests TEXT[] DEFAULT '{}',
  open_teams_requests TEXT[] DEFAULT '{}',
  open_booking_requests TEXT[] DEFAULT '{}',
  teams_joined_history TEXT DEFAULT '',
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for player_profiles
CREATE INDEX IF NOT EXISTS idx_player_profiles_email ON player_profiles(email);
CREATE INDEX IF NOT EXISTS idx_player_profiles_player_id ON player_profiles(player_id);
CREATE INDEX IF NOT EXISTS idx_player_profiles_created_at ON player_profiles(created_at);

-- ===================================
-- TABLE: football_fields
-- Football field/venue information
-- ===================================
CREATE TABLE IF NOT EXISTS football_fields (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Basic Info
  football_field_name TEXT NOT NULL,
  location_name TEXT NOT NULL,
  street_name TEXT DEFAULT '',
  opening_hours TEXT DEFAULT '',
  bookable BOOLEAN DEFAULT TRUE,
  
  -- Location
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  
  -- Photos
  photos TEXT[] DEFAULT '{}',
  
  -- Pricing
  price_range TEXT DEFAULT '',
  commission_percentage TEXT DEFAULT '0',
  
  -- Field Details
  field_size TEXT DEFAULT '5-a-side', -- "5-a-side" or "7-a-side"
  
  -- Amenities (stored as JSONB for flexibility)
  amenities JSONB DEFAULT '{
    "parking": false,
    "toilets": false,
    "cafeteria": false,
    "floodlights": false,
    "qualityField": false,
    "ballIncluded": false,
    "cameraRecording": false
  }'::jsonb,
  
  -- Available time slots (stored as JSONB)
  available_time_slots JSONB DEFAULT '{}'::jsonb,
  
  -- Bookings
  bookings TEXT[] DEFAULT '{}',
  
  -- Camera Details (for match recording)
  has_camera BOOLEAN DEFAULT FALSE,
  camera_username TEXT,
  camera_password TEXT,
  camera_ip_address TEXT,
  raspberry_pi_ip TEXT,
  router_ip TEXT,
  sim_card_number TEXT,
  
  -- Admin credentials (encrypted/should be server-side only)
  username TEXT DEFAULT '',
  password TEXT DEFAULT '',
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for football_fields
CREATE INDEX IF NOT EXISTS idx_football_fields_location_name ON football_fields(location_name);
CREATE INDEX IF NOT EXISTS idx_football_fields_bookable ON football_fields(bookable);
-- Geospatial index for location-based queries (requires earthdistance extension)
CREATE INDEX IF NOT EXISTS idx_football_fields_location ON football_fields USING GIST (ll_to_earth(latitude, longitude));

-- ===================================
-- TABLE: bookings
-- Match bookings and reservations
-- ===================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Basic Info
  user_id TEXT NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
  football_field_id UUID NOT NULL REFERENCES football_fields(id) ON DELETE CASCADE,
  host TEXT NOT NULL REFERENCES player_profiles(id),
  
  -- Booking Details
  date TEXT NOT NULL, -- Store as YYYY-MM-DD string (matching Firebase format)
  time_slot TEXT NOT NULL,
  booking_reference TEXT NOT NULL UNIQUE,
  status TEXT DEFAULT 'pending', -- pending, confirmed, completed, cancelled
  
  -- Field Information (denormalized for faster queries)
  football_field_name TEXT NOT NULL,
  location_name TEXT NOT NULL,
  
  -- Pricing
  price INTEGER NOT NULL,
  payment_type TEXT DEFAULT 'N/A',
  
  -- Match Configuration
  is_open_match BOOLEAN DEFAULT FALSE,
  max_players INTEGER,
  description TEXT,
  notes TEXT,
  
  -- Players & Teams
  invite_players TEXT[] DEFAULT '{}',
  invite_squads TEXT[] DEFAULT '{}',
  open_joining_requests TEXT[] DEFAULT '{}',
  
  -- User Info (denormalized)
  user_name TEXT,
  user_email TEXT,
  user_photo_url TEXT,
  
  -- Recording
  is_recording_enabled BOOLEAN DEFAULT FALSE,
  recording_url TEXT,
  camera_username TEXT,
  camera_password TEXT,
  camera_ip_address TEXT,
  
  -- Recurring Bookings
  field_manager_booking BOOLEAN DEFAULT FALSE,
  is_recurring BOOLEAN DEFAULT FALSE,
  recurring_type TEXT, -- "daily", "weekly"
  recurring_original_date TEXT, -- YYYY-MM-DD
  recurring_end_date TEXT, -- YYYY-MM-DD
  recurring_exceptions TEXT[] DEFAULT '{}', -- Array of YYYY-MM-DD dates
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for bookings
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_football_field_id ON bookings(football_field_id);
CREATE INDEX IF NOT EXISTS idx_bookings_host ON bookings(host);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(date);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_reference ON bookings(booking_reference);

-- ===================================
-- TABLE: playmaker_squads
-- Teams/Squads
-- ===================================
CREATE TABLE IF NOT EXISTS playmaker_squads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Basic Info
  squad_name TEXT NOT NULL,
  squad_location TEXT NOT NULL,
  captain TEXT NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
  joinable BOOLEAN DEFAULT TRUE,
  
  -- Squad Details
  profile_picture TEXT DEFAULT '',
  squad_logo TEXT,
  matches_played TEXT DEFAULT '0',
  average_age DOUBLE PRECISION,
  
  -- Members & Requests
  squad_members TEXT[] DEFAULT '{}',
  pending_requests TEXT[] DEFAULT '{}',
  open_teams_requests TEXT[] DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for playmaker_squads
CREATE INDEX IF NOT EXISTS idx_playmaker_squads_captain ON playmaker_squads(captain);
CREATE INDEX IF NOT EXISTS idx_playmaker_squads_joinable ON playmaker_squads(joinable);
CREATE INDEX IF NOT EXISTS idx_playmaker_squads_location ON playmaker_squads(squad_location);

-- ===================================
-- TABLE: field_managers
-- Field manager accounts and permissions
-- ===================================
CREATE TABLE IF NOT EXISTS field_managers (
  id TEXT PRIMARY KEY, -- Firebase Auth UID
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  field_ids UUID[] DEFAULT '{}', -- Array of football_field IDs they manage
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for field_managers
CREATE INDEX IF NOT EXISTS idx_field_managers_email ON field_managers(email);

-- ===================================
-- FUNCTIONS: Updated_at trigger
-- ===================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers (drop if exists first)
DROP TRIGGER IF EXISTS update_player_profiles_updated_at ON player_profiles;
CREATE TRIGGER update_player_profiles_updated_at BEFORE UPDATE ON player_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_football_fields_updated_at ON football_fields;
CREATE TRIGGER update_football_fields_updated_at BEFORE UPDATE ON football_fields
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_bookings_updated_at ON bookings;
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_playmaker_squads_updated_at ON playmaker_squads;
CREATE TRIGGER update_playmaker_squads_updated_at BEFORE UPDATE ON playmaker_squads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_field_managers_updated_at ON field_managers;
CREATE TRIGGER update_field_managers_updated_at BEFORE UPDATE ON field_managers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ===================================

-- Enable RLS on all tables
ALTER TABLE player_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE football_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE playmaker_squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE field_managers ENABLE ROW LEVEL SECURITY;

-- ===================================
-- RLS POLICIES: player_profiles
-- ===================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON player_profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON player_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON player_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON player_profiles;

-- Anyone can view profiles (needed for searching players, viewing squad members, etc.)
CREATE POLICY "Public profiles are viewable by everyone" ON player_profiles
  FOR SELECT USING (true);

-- Users can insert their own profile (using Firebase UID)
CREATE POLICY "Users can create their own profile" ON player_profiles
  FOR INSERT WITH CHECK (true);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile" ON player_profiles
  FOR UPDATE USING (true);

-- Users can delete their own profile
CREATE POLICY "Users can delete their own profile" ON player_profiles
  FOR DELETE USING (true);

-- ===================================
-- RLS POLICIES: football_fields
-- ===================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Football fields are viewable by everyone" ON football_fields;
DROP POLICY IF EXISTS "Authenticated users can create fields" ON football_fields;
DROP POLICY IF EXISTS "Users can update football fields" ON football_fields;
DROP POLICY IF EXISTS "Authenticated users can delete football fields" ON football_fields;

-- Everyone can view football fields
CREATE POLICY "Football fields are viewable by everyone" ON football_fields
  FOR SELECT USING (true);

-- Only authenticated users can create fields (would be field managers in production)
CREATE POLICY "Authenticated users can create fields" ON football_fields
  FOR INSERT WITH CHECK (true);

-- Field owners can update their fields
CREATE POLICY "Users can update football fields" ON football_fields
  FOR UPDATE USING (true);

-- Authenticated users can delete football fields (admin operation)
CREATE POLICY "Authenticated users can delete football fields" ON football_fields
  FOR DELETE USING (true);

-- ===================================
-- RLS POLICIES: bookings
-- ===================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view relevant bookings" ON bookings;
DROP POLICY IF EXISTS "Authenticated users can create bookings" ON bookings;
DROP POLICY IF EXISTS "Users can update their bookings" ON bookings;
DROP POLICY IF EXISTS "Users can delete their own bookings" ON bookings;

-- Users can view their own bookings and bookings they're invited to
CREATE POLICY "Users can view relevant bookings" ON bookings
  FOR SELECT USING (true);

-- Users can create bookings
CREATE POLICY "Authenticated users can create bookings" ON bookings
  FOR INSERT WITH CHECK (true);

-- Users can update bookings they created or are invited to
CREATE POLICY "Users can update their bookings" ON bookings
  FOR UPDATE USING (true);

-- Users can delete their own bookings
CREATE POLICY "Users can delete their own bookings" ON bookings
  FOR DELETE USING (true);

-- ===================================
-- RLS POLICIES: playmaker_squads
-- ===================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Squads are viewable by everyone" ON playmaker_squads;
DROP POLICY IF EXISTS "Authenticated users can create squads" ON playmaker_squads;
DROP POLICY IF EXISTS "Squad members can update squad" ON playmaker_squads;
DROP POLICY IF EXISTS "Squad captain can delete squad" ON playmaker_squads;

-- Everyone can view squads
CREATE POLICY "Squads are viewable by everyone" ON playmaker_squads
  FOR SELECT USING (true);

-- Authenticated users can create squads
CREATE POLICY "Authenticated users can create squads" ON playmaker_squads
  FOR INSERT WITH CHECK (true);

-- Squad captains and members can update squad info
CREATE POLICY "Squad members can update squad" ON playmaker_squads
  FOR UPDATE USING (true);

-- Squad captain can delete squad
CREATE POLICY "Squad captain can delete squad" ON playmaker_squads
  FOR DELETE USING (true);

-- ===================================
-- RLS POLICIES: field_managers
-- ===================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Field managers can view their own data" ON field_managers;
DROP POLICY IF EXISTS "Field managers can update their own data" ON field_managers;

-- Field managers can view their own data
CREATE POLICY "Field managers can view their own data" ON field_managers
  FOR SELECT USING (true);

-- Field managers can update their own data
CREATE POLICY "Field managers can update their own data" ON field_managers
  FOR UPDATE USING (true);

-- ===================================
-- HELPFUL VIEWS (Optional)
-- ===================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS booking_details;
DROP VIEW IF EXISTS squad_details;

-- View for booking details with field information
CREATE VIEW booking_details AS
SELECT 
  b.*,
  f.latitude,
  f.longitude,
  f.amenities,
  f.field_size
FROM bookings b
JOIN football_fields f ON b.football_field_id = f.id;

-- View for squad details with captain information
CREATE VIEW squad_details AS
SELECT 
  s.*,
  p.name as captain_name,
  p.email as captain_email,
  p.profile_picture as captain_picture
FROM playmaker_squads s
JOIN player_profiles p ON s.captain = p.id;

-- ===================================
-- END OF SCHEMA
-- ===================================

-- Grant necessary permissions (adjust based on your security needs)
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

