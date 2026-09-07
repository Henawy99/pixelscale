-- Remove decimal from article_number for METRO purchase items only.
-- e.g. "72616.0" -> "72616", "143510.6" -> "143510" (integer part only).
UPDATE public.purchase_catalog_items p
SET article_number = split_part(p.article_number, '.', 1)
FROM public.suppliers s
WHERE p.supplier_id = s.id
  AND s.name ILIKE '%metro%'
  AND p.article_number ~ '\.[0-9]+$';
