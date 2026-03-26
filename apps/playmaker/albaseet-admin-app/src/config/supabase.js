import { createClient } from '@supabase/supabase-js'
import AsyncStorage from '@react-native-async-storage/async-storage'

const supabaseUrl = 'https://upooyypqhftzzwjrfyra.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTM3ODIsImV4cCI6MjA3NjgyOTc4Mn0.5I1xvhg0o4DeUd7uvSsCNmwzBB7FkBAy7lrnEDBncpE'

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
})

export const ALBASEET_PRODUCTS_TABLE = 'albaseet_products'
export const ALBASEET_ORDERS_TABLE = 'albaseet_orders'
export const ALBASEET_STORAGE_BUCKET = 'albaseet-images'

export const getImageUrl = (path) => {
  if (!path) return null
  if (path.startsWith('http')) return path
  const { data } = supabase.storage.from(ALBASEET_STORAGE_BUCKET).getPublicUrl(path)
  return data.publicUrl
}
