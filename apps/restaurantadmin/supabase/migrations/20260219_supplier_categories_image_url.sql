-- Image for each category card (e.g. Fruit & Veg, Bakery)
alter table public.supplier_categories add column if not exists image_url text;
