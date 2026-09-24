// Supabase Edge Function: generate-look
// Orchestrates AI hairstyle generation via Gemini with identity preservation.
//
// Flow: authenticate → validate → deduct credit → create job → download source
//       → build prompt → call Gemini → upload results → update job status.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─────────── Style Catalog (prompt fragments) ───────────
const STYLE_PROMPTS: Record<string, string> = {
  low_fade:
    "a clean low fade with a gradual taper starting just above the ear, blending from skin at the temple to longer hair at the parietal ridge",
  mid_fade:
    "a mid fade with the blend starting at the mid-point of the sides, creating a balanced transition from short to long",
  high_fade:
    "a high fade with the shortest length starting high on the head near the temples, creating dramatic contrast with the top",
  skin_fade:
    "a skin fade (bald fade) with the sides taken down to bare skin at the lowest point, gradually blending upward",
  drop_fade:
    "a drop fade that drops behind the ear in a curved arc, creating a dramatic swooping line around the back of the head",
  burst_fade:
    "a burst fade radiating outward from behind the ear in a circular pattern, leaving length at the neckline",
  taper_fade:
    "a classic taper fade with a subtle, gradual blend from the natural hairline upward, conservative and professional",
  temple_fade:
    "a temple fade (temp fade) with only the temple and sideburn area faded, keeping the sides relatively longer",
  pompadour:
    "a classic pompadour with voluminous height on top swept back and up, clean tapered sides, inspired by 1950s styling",
  slick_back:
    "a slick back style with hair combed straight back from the forehead, sleek and polished with a wet-look finish",
  side_part:
    "a classic side part with a defined part line, hair combed to one side on top with neatly blended sides",
  comb_over:
    "a modern comb over with longer hair on top swept to one side, blended into a fade on the shorter side",
  crew_cut:
    "a classic crew cut with short, uniform length on the sides and slightly longer on top, brushed forward",
  ivy_league:
    "an ivy league (Princeton) cut with enough length on top to part and style, tapered sides and back",
  textured_crop:
    "a textured crop with choppy, layered texture on top falling forward, paired with a sharp fade on the sides",
  french_crop:
    "a French crop with a short, textured fringe falling forward over the forehead, tight faded sides",
  messy_fringe:
    "a messy fringe style with tousled, piece-y bangs falling naturally across the forehead, relaxed texture throughout",
  textured_quiff:
    "a textured quiff with volume lifted at the front and textured throughout, modern and effortless looking",
  buzz_cut:
    "a uniform buzz cut with a single clipper guard length all over, clean and minimal",
  induction_buzz:
    "an induction buzz (zero guard) with hair taken down to the shortest clipper setting all over the head",
  butch_cut:
    "a butch cut with a slightly longer uniform buzz on top (about 1/4 inch) and shorter sides",
  man_bun:
    "a man bun with enough length to gather hair at the crown into a neat bun, undercut or tapered sides",
  curtains:
    "curtain bangs (e-boy style) with a center part, hair falling to each side of the face, medium length",
  flow:
    "a flow hairstyle with medium-to-long hair swept back naturally, volume and movement throughout",
};

// ─────────── Gemini API Helper ───────────
interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        inlineData?: { mimeType: string; data: string };
        text?: string;
      }>;
    };
  }>;
  error?: { message: string };
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const len = bytes.byteLength;
  const chunkSize = 8192;
  for (let i = 0; i < len; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, len));
    for (let j = 0; j < chunk.length; j++) {
      binary += String.fromCharCode(chunk[j]);
    }
  }
  return btoa(binary);
}

async function callGemini(
  apiKey: string,
  prompt: string,
  sourcePhotoBase64: string,
  sourcePhotoMimeType: string,
): Promise<Uint8Array[]> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`;

  // Generate 4 variations in parallel
  const variationPromises = [0, 1, 2, 3].map(async (i) => {
    const variationPrompt = `${prompt}\n\nVariation ${i + 1} of 4: Generate a unique interpretation while strictly maintaining the exact same face, bone structure, skin tone, and facial hair.`;

    const requestBody = {
      contents: [
        {
          parts: [
            {
              inlineData: {
                mimeType: sourcePhotoMimeType,
                data: sourcePhotoBase64,
              },
            },
            { text: variationPrompt },
          ],
        },
      ],
    };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Gemini API error (${response.status}): ${errText}`);
    }

    const data: GeminiResponse = await response.json();

    if (data.error) {
      throw new Error(`Gemini error: ${data.error.message}`);
    }

    const imagePart = data.candidates?.[0]?.content?.parts?.find(
      (p) => p.inlineData,
    );

    if (!imagePart?.inlineData?.data) {
      throw new Error(`Gemini returned no image for variation ${i + 1}`);
    }

    // Decode base64 to Uint8Array
    const binaryString = atob(imagePart.inlineData.data);
    const bytes = new Uint8Array(binaryString.length);
    for (let j = 0; j < binaryString.length; j++) {
      bytes[j] = binaryString.charCodeAt(j);
    }
    return bytes;
  });

  return await Promise.all(variationPromises);
}

// ─────────── Main Handler ───────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Service-role client for privileged operations (credit deduction, job creation)
  const serviceClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // User-scoped client for auth verification
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization")! },
      },
    },
  );

  try {
    // 1. Authenticate
    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Parse & validate request
    const { lookId, sourcePhotoId, styleKey, variations = 4 } = await req.json();

    if (!lookId || !sourcePhotoId || !styleKey) {
      return new Response(
        JSON.stringify({
          error: "lookId, sourcePhotoId, and styleKey are required",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const stylePrompt = STYLE_PROMPTS[styleKey];
    if (!stylePrompt) {
      return new Response(
        JSON.stringify({ error: `Unknown style: ${styleKey}` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. Deduct credit atomically
    const { data: newBalance, error: creditError } = await serviceClient.rpc(
      "deduct_credit",
      { p_user_id: user.id },
    );

    if (creditError) {
      return new Response(
        JSON.stringify({ error: `Credit check failed: ${creditError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (newBalance === -1) {
      return new Response(
        JSON.stringify({
          error: "Insufficient credits",
          credits_remaining: 0,
        }),
        {
          status: 402,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 4. Build the identity-preserving prompt
    const fullPrompt = [
      "Generate a photorealistic hairstyle visualization of the person in this photo.",
      "",
      "CRITICAL IDENTITY PRESERVATION RULES:",
      "- Preserve the person's face EXACTLY — same facial features, bone structure, skin tone, complexion.",
      "- Preserve facial hair (beard, mustache, stubble) exactly as shown.",
      "- Preserve the head shape, ear visibility, and facial expression.",
      "- Do NOT change the person's ethnicity, age, or any facial characteristics.",
      "- ONLY modify the hair on top of the head and the sides/back.",
      "",
      `DESIRED HAIRSTYLE: ${stylePrompt}.`,
      "",
      "TECHNICAL REQUIREMENTS:",
      "- Output a single photorealistic portrait at 512x512 pixels.",
      "- Front-facing camera angle, neutral studio background.",
      "- Natural lighting, professional barbershop quality result.",
      "- The hairstyle should look freshly cut and styled.",
    ].join("\n");

    // 5. Create the generation job
    const { data: job, error: jobError } = await serviceClient
      .from("generation_jobs")
      .insert({
        user_id: user.id,
        look_id: lookId,
        source_photo_id: sourcePhotoId,
        style_key: styleKey,
        prompt: fullPrompt,
        variation_count: variations,
        status: "queued",
      })
      .select()
      .single();

    if (jobError) {
      // Refund the credit since job creation failed
      await serviceClient.rpc("deduct_credit", { p_user_id: user.id }); // TODO: create refund RPC
      return new Response(
        JSON.stringify({ error: `Job creation failed: ${jobError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 6. Mark job as running
    await serviceClient
      .from("generation_jobs")
      .update({ status: "running", started_at: new Date().toISOString() })
      .eq("id", job.id);

    // 7. Download the source photo
    const { data: sourcePhoto } = await serviceClient
      .from("source_photos")
      .select("storage_path")
      .eq("id", sourcePhotoId)
      .single();

    if (!sourcePhoto?.storage_path) {
      await serviceClient
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: "Source photo not found",
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);

      return new Response(
        JSON.stringify({ error: "Source photo not found", job }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: photoData, error: downloadError } = await serviceClient.storage
      .from("faces")
      .download(sourcePhoto.storage_path);

    if (downloadError || !photoData) {
      await serviceClient
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: `Photo download failed: ${downloadError?.message}`,
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);

      return new Response(
        JSON.stringify({ error: "Failed to download source photo", job }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Convert to base64 safely without stack overflow
    const photoBuffer = await photoData.arrayBuffer();
    const photoBase64 = toBase64(new Uint8Array(photoBuffer));
    const mimeType = photoData.type || "image/jpeg";

    // 8. Call Gemini API
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      await serviceClient
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: "GEMINI_API_KEY not configured",
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);

      return new Response(
        JSON.stringify({ error: "AI provider not configured", job }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let generatedImages: Uint8Array[];
    try {
      generatedImages = await callGemini(
        geminiApiKey,
        fullPrompt,
        photoBase64,
        mimeType,
      );
    } catch (genError: any) {
      await serviceClient
        .from("generation_jobs")
        .update({
          status: "failed",
          error_message: genError.message,
          completed_at: new Date().toISOString(),
        })
        .eq("id", job.id);

      return new Response(
        JSON.stringify({ error: genError.message, job }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 9. Upload results to renders bucket and create look_renders records
    const renders = [];
    for (let i = 0; i < generatedImages.length; i++) {
      const storagePath = `${user.id}/${lookId}/preview_${styleKey}_v${i}_${Date.now()}.png`;

      const { error: uploadError } = await serviceClient.storage
        .from("renders")
        .upload(storagePath, generatedImages[i], {
          contentType: "image/png",
          upsert: false,
        });

      if (uploadError) {
        console.error(`Upload error for variation ${i}:`, uploadError);
        continue;
      }

      const { data: render, error: renderError } = await serviceClient
        .from("look_renders")
        .insert({
          look_id: lookId,
          view: "front",
          storage_path: storagePath,
          provider: "gemini",
          resolution: "preview",
          cost_micros: 0,
        })
        .select()
        .single();

      if (!renderError && render) {
        renders.push(render);
      }
    }

    // 10. Mark job as succeeded
    await serviceClient
      .from("generation_jobs")
      .update({
        status: renders.length > 0 ? "succeeded" : "failed",
        error_message:
          renders.length === 0 ? "No images were successfully generated" : null,
        completed_at: new Date().toISOString(),
      })
      .eq("id", job.id);

    // 11. Return result
    return new Response(
      JSON.stringify({
        job: {
          ...job,
          status: renders.length > 0 ? "succeeded" : "failed",
          completed_at: new Date().toISOString(),
        },
        renders,
        credits_remaining: newBalance,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
