-- Add ean column to purchase_catalog_items
alter table public.purchase_catalog_items add column if not exists ean text;
