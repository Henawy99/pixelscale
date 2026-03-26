import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("create-driver function invoked");

// Define a helper type for the request body for better type safety
interface CreateDriverRequestBody {
  email?: string;
  password?: string;
  name?: string;
}

// Define a helper type for the user metadata
interface UserMetadata {
  full_name: string;
  role: string;
}


serve(async (req: Request) => {
  // Set up CORS headers for all responses
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*', // Or your specific app's origin in production
    'Access-Control-Allow-Methods': 'POST, OPTIONS', // Allow POST and OPTIONS
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', // Crucial headers used by Supabase client
  };

  // Handle OPTIONS preflight request
  if (req.method === 'OPTIONS') {
    console.log("Handling OPTIONS preflight request");
    return new Response('ok', { headers: corsHeaders });
  }

  // Handle POST request
  if (req.method === 'POST') {
    console.log("Handling POST request");
    let name, email, password;
    try {
      const body: CreateDriverRequestBody = await req.json();
      name = body.name;
      email = body.email;
      password = body.password;

      if (!name || !email || !password) {
        console.error('Missing parameters:', { name: !!name, email: !!email, password: !!password });
        throw new Error('Missing name, email, or password in request body');
      }
      console.log('Request body parsed:', { name, email }); // Log email, not password
    } catch (e: any) {
      console.error('Bad request:', e.message);
      return new Response(JSON.stringify({ error: `Bad request: ${e.message}` }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, // Add CORS
      });
    }

    try {
      // 2. Create Supabase client with SERVICE_ROLE_KEY for admin operations
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

      if (!supabaseUrl || !serviceRoleKey) {
        console.error('Missing Supabase URL or Service Role Key in environment variables.');
        throw new Error('Server configuration error: Supabase credentials not found.');
      }

      const supabaseAdmin: SupabaseClient = createClient(supabaseUrl, serviceRoleKey);
      console.log('Supabase admin client initialized.');

      // 3. Create the user in Supabase Auth
      console.log(`Attempting to create auth user for: ${email}`);
      const userMetadata: UserMetadata = { full_name: name, role: 'driver' };
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true, // Auto-confirm email for drivers created via admin interface
        user_metadata: userMetadata,
      });

      if (authError) {
        console.error('Auth Error during user creation:', authError);
        throw new Error(`Auth error: ${authError.message}`);
      }
      if (!authData || !authData.user) {
        console.error('User creation failed in Auth, no user data returned.');
        throw new Error('User creation failed in Auth.');
      }
      const userId = authData.user.id;
      console.log(`Auth user created successfully: ${userId}`);

      // 4. Insert into 'profiles' table
      console.log(`Attempting to insert into profiles for user ID: ${userId}`);
      const { error: profileError } = await supabaseAdmin
        .from('profiles')
        .insert({
          id: userId, 
          full_name: name, 
          email: email,    
          role: 'driver',  
        });

      if (profileError) {
        console.error('Profile Insert Error:', profileError);
        // Potentially clean up the auth user if profile insert fails
        // console.log(`Attempting to delete auth user ${userId} due to profile insert error.`);
        // await supabaseAdmin.auth.admin.deleteUser(userId);
        throw new Error(`Profile insert error: ${profileError.message}`);
      }
      console.log(`Profile inserted successfully for user ID: ${userId}`);

      // 5. Insert into 'drivers' table
      console.log(`Attempting to insert into drivers for user ID: ${userId}`);
      const { data: driverData, error: driverError } = await supabaseAdmin
        .from('drivers')
        .insert({
          user_id: userId, 
          name: name,      
          is_online: false, 
        })
        .select() // Optionally select the created driver record
        .single(); // Assuming user_id should be unique or you want the first match

      if (driverError) {
        console.error('Driver Insert Error:', driverError);
        // Potentially clean up auth user and profile if driver insert fails
        throw new Error(`Driver insert error: ${driverError.message}`);
      }
      console.log(`Driver record inserted successfully for user ID: ${userId}`, driverData);

      // 6. Return success
      return new Response(JSON.stringify({ message: 'Driver created successfully', userId: userId, driverRecord: driverData }), {
        status: 201, // 201 Created
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, // Add CORS
      });

    } catch (error: any) {
      console.error('Overall Error in create-driver function:', error.message, error.stack);
      return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, // Add CORS
      });
    }
  } // End of POST handling

  // Fallback for other methods if any slip through (though OPTIONS and POST should be primary)
  console.error('Method Not Allowed (fallback):', req.method);
  return new Response(JSON.stringify({ error: `Method ${req.method} Not Allowed` }), {
    status: 405,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }, // Add CORS
  });
})
