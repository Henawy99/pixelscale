import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { resolveBrandSlug } from '../_shared/online_brands.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const slug = url.searchParams.get('slug') ?? (await req.json().catch(() => ({}))).slug;

    if (!slug || typeof slug !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing slug' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const brand = resolveBrandSlug(slug);
    if (!brand) {
      return new Response(JSON.stringify({ error: 'Unknown brand' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const { data: categories, error: catErr } = await supabase
      .from('menu_categories')
      .select('id, brand_id, name, description, display_order, created_at')
      .eq('brand_id', brand.id)
      .order('display_order', { ascending: true });

    if (catErr) throw catErr;

    const categoryIds = (categories ?? []).map((c) => c.id);
    if (categoryIds.length === 0) {
      return new Response(
        JSON.stringify({ brand, categories: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { data: items, error: itemErr } = await supabase
      .from('menu_items')
      .select(
        'id, brand_id, category_id, name, description, price, image_url, attributes, display_order, is_available, created_at',
      )
      .in('category_id', categoryIds)
      .eq('is_available', true)
      .order('display_order', { ascending: true });

    if (itemErr) throw itemErr;

    const itemsByCategory = new Map<string, typeof items>();
    for (const item of items ?? []) {
      const list = itemsByCategory.get(item.category_id) ?? [];
      list.push(item);
      itemsByCategory.set(item.category_id, list);
    }

    const payload = (categories ?? []).map((cat) => ({
      category: cat,
      items: itemsByCategory.get(cat.id) ?? [],
    }));

    return new Response(
      JSON.stringify({ brand, categories: payload }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('[get-public-menu]', e);
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : 'Server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
