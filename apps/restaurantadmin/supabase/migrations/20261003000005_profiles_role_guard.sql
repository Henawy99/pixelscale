-- Who is an admin is decided by profiles.role (RLS policies, _caller_is_admin, edge functions).
-- The "own profile" policies let any signed-in user update or insert their own row, role
-- included, so a driver account could make itself admin. From now on only the server (service
-- role, SECURITY DEFINER functions, the dashboard) can change a role or create an admin/manager.

CREATE OR REPLACE FUNCTION public.guard_profile_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- PostgREST runs app requests as anon/authenticated; server code runs as other roles.
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP = 'UPDATE' AND NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Only an admin can change a role' USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'INSERT' AND NEW.role IN ('admin', 'manager') THEN
      RAISE EXCEPTION 'Only an admin can grant this role' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_guard_role ON public.profiles;
CREATE TRIGGER profiles_guard_role
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_role();
