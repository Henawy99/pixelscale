import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Helper to check if Supabase is configured
export const isSupabaseConfigured = () => {
  return supabaseUrl && 
         supabaseUrl !== 'your_supabase_url_here' && 
         supabaseUrl.startsWith('http') &&
         supabaseAnonKey && 
         supabaseAnonKey !== 'your_supabase_anon_key_here';
};

// Lazy-init: only create client when properly configured
let _supabase = null;
export const supabase = new Proxy({}, {
  get(_, prop) {
    if (!_supabase) {
      if (!isSupabaseConfigured()) {
        // Return a stub that won't crash
        return typeof prop === 'string' ? (() => ({ data: null, error: { message: 'Supabase not configured' } })) : undefined;
      }
      _supabase = createClient(supabaseUrl, supabaseAnonKey);
    }
    return _supabase[prop];
  }
});
