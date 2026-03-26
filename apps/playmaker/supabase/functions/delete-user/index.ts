// Supabase Edge Function to delete user account
// This uses admin privileges to delete the auth user

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with SERVICE ROLE (admin privileges)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Create client with user's JWT to verify identity
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Verify the user's identity
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    
    if (userError || !user) {
      throw new Error('Unauthorized: Invalid token')
    }

    console.log(`Deleting user account: ${user.id}`)

    // Step 1: Delete user profile and related data from database
    // The CASCADE rules should handle related data (bookings, squads, etc.)
    const { error: profileError } = await supabaseAdmin
      .from('player_profiles')
      .delete()
      .eq('id', user.id)

    if (profileError) {
      console.error('Error deleting profile:', profileError)
      // Continue anyway - profile might already be deleted
    }

    // Step 2: Delete user from Supabase Auth using admin privileges
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.error('Error deleting auth user:', deleteError)
      throw new Error(`Failed to delete auth user: ${deleteError.message}`)
    }

    console.log(`✅ Successfully deleted user: ${user.id}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Account deleted successfully',
        userId: user.id 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('Error in delete-user function:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Unknown error occurred' 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})



