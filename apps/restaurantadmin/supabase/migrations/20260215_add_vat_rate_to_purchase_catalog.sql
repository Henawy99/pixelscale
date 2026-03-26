-- VAT rate: 10 or 20 (percent). Null = not set.
alter table public.purchase_catalog_items add column if not exists vat_rate numeric;
