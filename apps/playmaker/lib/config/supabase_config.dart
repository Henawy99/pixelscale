/// Supabase Configuration
/// 
/// This file contains the Supabase credentials for connecting to your database.
/// IMPORTANT: The anon key is safe to use in client-side code.
/// The service role key should ONLY be used server-side for admin operations.

class SupabaseConfig {
  // Your Supabase project URL
  static const String supabaseUrl = 'https://upooyypqhftzzwjrfyra.supabase.co';
  
  // Public anon key (safe for client-side use)
  static const String supabaseAnonKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTM3ODIsImV4cCI6MjA3NjgyOTc4Mn0.5I1xvhg0o4DeUd7uvSsCNmwzBB7FkBAy7lrnEDBncpE';
  
  // Service role key (use ONLY server-side, never expose in client code)
  // Keeping here for reference, but should be used in cloud functions only
  static const String supabaseServiceRoleKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTI1Mzc4MiwiZXhwIjoyMDc2ODI5NzgyfQ.su0cUrb0PsMWdjVfhjfGOfKsadheKVB0ygatYJdCx5o';
  
  // Project ID
  static const String projectId = 'upooyypqhftzzwjrfyra';
}


