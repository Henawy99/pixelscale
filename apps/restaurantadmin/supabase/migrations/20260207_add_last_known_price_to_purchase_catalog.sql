-- Add last_known_price (in euros) to purchase_catalog_items
alter table public.purchase_catalog_items add column if not exists last_known_price numeric;
