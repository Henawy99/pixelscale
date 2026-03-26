-- Run this in Supabase SQL Editor to remove the items added via bulk add.
-- Optionally restrict to one supplier by uncommenting and setting the supplier name.

DELETE FROM public.purchase_catalog_items
WHERE article_number IN (
  '4547', '4752', '4469', '4585', '4668', '4973', '2255', '1208', '0194', '0180',
  '4055', '2864', '0175', '0363', '4297', '3356', '0312', '3061', '0196', '4159',
  '0170', '0181', '4365', '4366', '2959', '4295', '0941', '0659', '2554', '0964',
  '0252', '4912', '4460', '2828'
);
-- To delete only for a specific supplier (e.g. S&G import export), use this instead:
-- DELETE FROM public.purchase_catalog_items
-- WHERE supplier_id = (SELECT id FROM public.suppliers WHERE name ILIKE '%S&G%' LIMIT 1)
-- AND article_number IN ( ... same list ... );
