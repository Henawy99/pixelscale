-- Category for purchase catalog items (e.g. Metro: Tiefkühl, Gemüse, Getränke, ...)
alter table public.purchase_catalog_items add column if not exists category text;
