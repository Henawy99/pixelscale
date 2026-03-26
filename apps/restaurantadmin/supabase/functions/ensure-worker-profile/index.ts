/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export async function onRequest(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') as string;
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') as string;
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

  try {
    const body = await req.json().catch(() => ({}));
    const userId = String(body.userId || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const fullName = String(body.fullName || 'Kitchen Worker');

    if (!userId || !email) {
      return new Response(
        JSON.stringify({ error: 'Missing userId or email' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // 1) Delete conflicting profile rows with same email but different id
    await supabase
      .from('profiles')
      .delete()
      .eq('email', email)
      .neq('id', userId);

    // 2) Upsert the correct profile row (id = auth user id)
    const { error: upsertError } = await supabase
      .from('profiles')
      .upsert({ id: userId, role: 'worker', email, full_name: fullName })
      .select()
      .single();

    if (upsertError) {
      return new Response(
        JSON.stringify({ error: 'Upsert failed', details: upsertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: 'Unhandled error', details: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
}

