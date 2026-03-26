-- Add article_number to purchase_catalog_items for tracking supplier article IDs
alter table public.purchase_catalog_items add column if not exists article_number text;
