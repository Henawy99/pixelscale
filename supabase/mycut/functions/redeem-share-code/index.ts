// Supabase Edge Function: redeem-share-code
// Validates share code, logs consultation, generates 15-min signed URLs for renders,
// and returns look details + customer first name. Never discloses phone/email.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { code, deviceFingerprint } = await req.json();
    if (!code || !deviceFingerprint) {
      return new Response(
        JSON.stringify({ error: "code and deviceFingerprint are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Call database RPC to perform atomic redemption & logging
    const { data, error } = await supabaseAdmin.rpc("redeem_share_code", {
      p_code: code,
      p_device_fingerprint: deviceFingerprint,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Generate signed URLs (15-min TTL) for all renders
    const rendersWithSignedUrls = await Promise.all(
      (data.renders || []).map(async (render: any) => {
        const { data: signedData } = await supabaseAdmin.storage
          .from("renders")
          .createSignedUrl(render.storage_path, 900); // 15 minutes = 900 seconds

        return {
          ...render,
          signed_url: signedData?.signedUrl ?? null,
        };
      })
    );

    return new Response(
      JSON.stringify({
        ...data,
        renders: rendersWithSignedUrls,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
