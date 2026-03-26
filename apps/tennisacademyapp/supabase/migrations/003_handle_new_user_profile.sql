-- ============================================================
-- FIX SIGNUP: Create profile automatically when a user signs up
-- Run this ONCE in Supabase → SQL Editor (fixes "RLS policy" error)
-- ============================================================

-- 1) Allow profile level to be NULL so trigger can insert without level issues
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_level_check;
ALTER TABLE profiles ALTER COLUMN level DROP NOT NULL;

-- 2) Trigger: when a new user is created in auth.users, create their profile row
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  meta JSONB := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  full_name_val TEXT := COALESCE(meta->>'full_name', 'User');
  phone_val TEXT := (meta->>'phone')::TEXT;
  role_val TEXT := COALESCE(meta->>'role', 'player');
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role, language_pref, level)
  VALUES (
    NEW.id,
    full_name_val,
    NULLIF(trim(phone_val), ''),
    role_val,
    'en',
    NULL
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
