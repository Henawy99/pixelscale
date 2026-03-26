import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

// Shared Supabase config — all PixelScale apps use the same project
const supabaseUrl = 'https://hdmycuncdlbefiiwlrca.supabase.co';
const supabaseAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkbXljdW5jZGxiZWZpaXdscmNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MTQ0NjIsImV4cCI6MjA2NTk5MDQ2Mn0.EqbT-LkOAnr7vOXlX93W5rsNF4HedWJqpvLVdPeu6l0';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
