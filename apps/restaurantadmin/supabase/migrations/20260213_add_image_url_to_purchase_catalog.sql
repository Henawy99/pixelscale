-- Add image_url column to purchase_catalog_items
alter table public.purchase_catalog_items add column if not exists image_url text;
