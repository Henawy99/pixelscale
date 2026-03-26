// ============================================
// PixelScale - Shared Supabase Configuration
// All apps share a single Supabase project.
// Each app uses table prefixes for data isolation.
// ============================================

export const SUPABASE_URL = 'https://hdmycuncdlbefiiwlrca.supabase.co';
export const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkbXljdW5jZGxiZWZpaXdscmNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MTQ0NjIsImV4cCI6MjA2NTk5MDQ2Mn0.EqbT-LkOAnr7vOXlX93W5rsNF4HedWJqpvLVdPeu6l0';

// Table prefix convention per app:
//   academy-app   -> no prefix (legacy, already created)
//   amazon-manager -> amazon_  (e.g. amazon_profiles)
//   new apps      -> appname_ prefix
