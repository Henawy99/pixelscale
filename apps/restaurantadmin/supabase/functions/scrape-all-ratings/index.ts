import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { sendPushNotification } from '../_shared/fcm.ts';

const RATING_THRESHOLD = 4.0;

interface RatingResult {
  rating: number | null;
  reviewCount: number | null;
}

// ─────────────────────────────────────────
// Lightweight rating extraction (direct fetch only, no ScraperAPI)
// ─────────────────────────────────────────

function extractRatingFromHtml(html: string): RatingResult {
  // 1. JSON-LD schema.org AggregateRating
  const jsonLdPattern = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match: RegExpExecArray | null;
  while ((match = jsonLdPattern.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1].trim());
      const entries = Array.isArray(data) ? data : [data];
      for (const entry of entries) {
        const e = entry as Record<string, unknown>;
        if (e.aggregateRating) {
          const ar = e.aggregateRating as Record<string, unknown>;
          const ratingValue = parseFloat(String(ar.ratingValue ?? '0'));
          const reviewCount = parseInt(String(ar.ratingCount ?? ar.reviewCount ?? '0'), 10);
          if (!isNaN(ratingValue) && ratingValue > 0) {
            return { rating: ratingValue, reviewCount };
          }
        }
      }
    } catch { /* skip */ }
  }

  // 2. __NEXT_DATA__ (Lieferando/Foodora/Wolt use Next.js)
  const nextDataMatch = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (nextDataMatch) {
    try {
      const nextData = JSON.parse(nextDataMatch[1]);
      const candidates = [
        nextData?.props?.pageProps?.restaurant,
        nextData?.props?.pageProps?.initialState?.restaurant,
        nextData?.props?.pageProps?.restaurantData,
        nextData?.props?.pageProps?.data?.restaurant,
        nextData?.props?.pageProps?.venue,
      ];
      for (const restaurant of candidates) {
        if (!restaurant) continue;
        const rating = restaurant.rating ?? restaurant.ratingStats ?? restaurant.ratingSummary;
        if (rating) {
          const score = parseFloat(String(rating.score ?? rating.ratingValue ?? rating.value ?? '0'));
          const count = parseInt(String(rating.count ?? rating.reviewCount ?? rating.total ?? '0'), 10);
          if (!isNaN(score) && score > 0) {
            return { rating: score, reviewCount: count };
          }
        }
      }
    } catch { /* skip */ }
  }

  // 3. "ratingValue" anywhere in JSON
  const rvMatch = html.match(/"ratingValue"\s*:\s*"?([1-5]\.[0-9]|[1-5])"?/i);
  if (rvMatch) {
    const val = parseFloat(rvMatch[1]);
    if (!isNaN(val) && val > 0) {
      const rcMatch = html.match(/"reviewCount"\s*:\s*"?(\d+)"?/i);
      return { rating: val, reviewCount: rcMatch ? parseInt(rcMatch[1], 10) : null };
    }
  }

  // 4. "score" in JSON
  const scoreMatch = html.match(/"score"\s*:\s*([1-5]\.[0-9]|[1-5])/i);
  if (scoreMatch) {
    const val = parseFloat(scoreMatch[1]);
    if (!isNaN(val) && val > 0) return { rating: val, reviewCount: null };
  }

  // 5. Last resort regex
  const lastResort = html.match(/([1-5]\.[0-9])\s*(star|rating|bewertung|sterne)/i);
  if (lastResort) return { rating: parseFloat(lastResort[1]), reviewCount: null };

  return { rating: null, reviewCount: null };
}

async function scrapeRating(url: string): Promise<RatingResult> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000); // 12s timeout per request
    
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-AT,de;q=0.9,en;q=0.8',
      },
    });
    clearTimeout(timeout);

    if (!response.ok) return { rating: null, reviewCount: null };
    const html = await response.text();
    return extractRatingFromHtml(html);
  } catch (e) {
    console.error(`Fetch error for ${url}:`, e instanceof Error ? e.message : e);
    return { rating: null, reviewCount: null };
  }
}

// ─────────────────────────────────────────
// Main Edge Function
// ─────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const { data: brands, error: fetchError } = await supabase
      .from('brands')
      .select('id, name, lieferando_url, foodora_url, wolt_url, google_url, lieferando_rating, foodora_rating, wolt_rating, google_rating');

    if (fetchError) throw fetchError;

    const results: Array<Record<string, unknown>> = [];
    const alerts: Array<{ brand: string; platform: string; rating: number }> = [];

    for (const brand of brands ?? []) {
      console.log(`\n═══ "${brand.name}" ═══`);
      const updates: Record<string, unknown> = {};
      const now = new Date().toISOString();

      const platforms = [
        { key: 'lieferando', url: brand.lieferando_url },
        { key: 'foodora', url: brand.foodora_url },
        { key: 'wolt', url: brand.wolt_url },
        { key: 'google', url: brand.google_url },
      ];

      for (const p of platforms) {
        if (!p.url) continue;

        console.log(`  → ${p.key}...`);
        const { rating, reviewCount } = await scrapeRating(p.url);

        if (rating !== null) {
          updates[`${p.key}_rating`] = rating;
          updates[`${p.key}_rating_updated_at`] = now;
          if (reviewCount !== null) updates[`${p.key}_review_count`] = reviewCount;
          console.log(`  ✅ ${p.key}: ${rating} (${reviewCount ?? '?'} reviews)`);

          if (rating < RATING_THRESHOLD) {
            alerts.push({ brand: brand.name, platform: p.key, rating });
          }
        } else {
          console.log(`  ❌ ${p.key}: no rating found`);
        }
      }

      if (Object.keys(updates).length > 0) {
        const { error: updateError } = await supabase
          .from('brands').update(updates).eq('id', brand.id);
        if (updateError) console.error(`  DB error: ${updateError.message}`);
      }

      results.push({ brand: brand.name, updates: Object.keys(updates).length / 2 });
    }

    // Send push notification if any rating < 4.0
    if (alerts.length > 0) {
      const body = alerts.map(a => `⚠️ ${a.brand} → ${a.platform}: ${a.rating.toFixed(1)}`).join('\n');
      try {
        await sendPushNotification(supabase, {
          title: `🚨 ${alerts.length} rating${alerts.length > 1 ? 's' : ''} below ${RATING_THRESHOLD}`,
          body,
          data: { type: 'rating_alert' },
        });
        console.log('🔔 Push notification sent');
      } catch (e) {
        console.error('Push failed:', e);
      }
    }

    return new Response(
      JSON.stringify({ success: true, brands: results.length, alerts: alerts.length, alertDetails: alerts }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
