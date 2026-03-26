import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface LieferandoRating {
  ratingValue: number;
  reviewCount: number;
}

/**
 * Attempts to extract rating data from a Lieferando restaurant page.
 * Strategy 1: JSON-LD schema.org AggregateRating (most reliable, SEO-rendered)
 * Strategy 2: __NEXT_DATA__ embedded JSON (Next.js SSR)
 * Strategy 3: OpenGraph / meta tags fallback
 */
async function fetchLieferandoRating(url: string): Promise<LieferandoRating | null> {
  const response = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'de-AT,de;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cache-Control': 'no-cache',
    },
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status} fetching ${url}`);
  }

  const html = await response.text();

  // Strategy 1: JSON-LD schema.org
  const jsonLdPattern = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match: RegExpExecArray | null;
  while ((match = jsonLdPattern.exec(html)) !== null) {
    try {
      const raw = match[1].trim();
      const data = JSON.parse(raw);
      const entries: unknown[] = Array.isArray(data) ? data : [data];
      for (const entry of entries) {
        const e = entry as Record<string, unknown>;
        if (e.aggregateRating) {
          const ar = e.aggregateRating as Record<string, unknown>;
          const ratingValue = parseFloat(String(ar.ratingValue ?? '0'));
          const reviewCount = parseInt(
            String(ar.ratingCount ?? ar.reviewCount ?? '0'),
            10,
          );
          if (!isNaN(ratingValue) && ratingValue > 0) {
            return { ratingValue, reviewCount };
          }
        }
      }
    } catch {
      // malformed JSON-LD block, continue
    }
  }

  // Strategy 2: __NEXT_DATA__ embedded JSON
  const nextDataMatch = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (nextDataMatch) {
    try {
      const nextData = JSON.parse(nextDataMatch[1]);
      // Lieferando/Takeaway Next.js page structure (paths may vary between deployments)
      const candidates = [
        nextData?.props?.pageProps?.restaurant,
        nextData?.props?.pageProps?.initialState?.restaurant,
        nextData?.props?.pageProps?.restaurantData,
        nextData?.props?.pageProps?.data?.restaurant,
      ];
      for (const restaurant of candidates) {
        if (!restaurant) continue;
        // rating may be at restaurant.rating or restaurant.ratingStats
        const rating =
          restaurant.rating ??
          restaurant.ratingStats ??
          restaurant.ratingSummary;
        if (rating) {
          const score =
            parseFloat(String(rating.score ?? rating.ratingValue ?? rating.value ?? '0'));
          const count =
            parseInt(String(rating.count ?? rating.reviewCount ?? rating.total ?? '0'), 10);
          if (!isNaN(score) && score > 0) {
            return { ratingValue: score, reviewCount: count };
          }
        }
      }
    } catch {
      // malformed Next.js data
    }
  }

  // Strategy 3: Look for rating in meta tags or data attributes as last resort
  const ratingMetaMatch = html.match(/["']ratingValue["']\s*[:\s]+["']?([\d.]+)["']?/);
  const reviewMetaMatch = html.match(/["']reviewCount["']\s*[:\s]+["']?(\d+)["']?/);
  if (ratingMetaMatch) {
    const ratingValue = parseFloat(ratingMetaMatch[1]);
    const reviewCount = reviewMetaMatch ? parseInt(reviewMetaMatch[1], 10) : 0;
    if (!isNaN(ratingValue) && ratingValue > 0) {
      return { ratingValue, reviewCount };
    }
  }

  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Optionally allow fetching a single brand by passing { brand_id: "..." } in the body
    let brandIdFilter: string | null = null;
    if (req.method === 'POST') {
      try {
        const body = await req.json();
        brandIdFilter = body?.brand_id ?? null;
      } catch {
        // no body or invalid JSON — fetch all brands
      }
    }

    let query = supabase
      .from('brands')
      .select('id, name, lieferando_url')
      .not('lieferando_url', 'is', null);

    if (brandIdFilter) {
      query = query.eq('id', brandIdFilter);
    }

    const { data: brands, error: fetchError } = await query;
    if (fetchError) throw fetchError;

    const results: Array<Record<string, unknown>> = [];

    for (const brand of brands ?? []) {
      // Small delay between requests to be polite to the server
      if (results.length > 0) {
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }

      try {
        console.log(`Fetching rating for "${brand.name}" → ${brand.lieferando_url}`);
        const rating = await fetchLieferandoRating(brand.lieferando_url);

        if (rating) {
          const { error: updateError } = await supabase
            .from('brands')
            .update({
              lieferando_rating: rating.ratingValue,
              lieferando_review_count: rating.reviewCount,
              lieferando_rating_updated_at: new Date().toISOString(),
            })
            .eq('id', brand.id);

          if (updateError) {
            results.push({ brand: brand.name, status: 'db_error', error: updateError.message });
          } else {
            results.push({
              brand: brand.name,
              status: 'updated',
              rating: rating.ratingValue,
              reviews: rating.reviewCount,
            });
          }
        } else {
          results.push({ brand: brand.name, status: 'no_rating_found' });
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(`Error fetching rating for "${brand.name}": ${msg}`);
        results.push({ brand: brand.name, status: 'fetch_error', error: msg });
      }
    }

    return new Response(JSON.stringify({ success: true, processed: results.length, results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
