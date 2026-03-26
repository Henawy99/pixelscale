-- 1) Add missing column
alter table public.suppliers add column if not exists ai_rules text;

-- 2) Ensure pgcrypto exists for gen_random_uuid()
create extension if not exists pgcrypto;

-- 3) Purchase catalog table
create table if not exists public.purchase_catalog_items (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  name text not null,
  receipt_name text,
  unit text,
  default_quantity double precision,
  material_id uuid references public.material(id) on delete set null,
  base_unit text,
  conversion_ratio double precision,
  notes text,
  created_at timestamptz default now()
);

-- 4) Link purchase_items to catalog
alter table public.purchase_items
  add column if not exists purchase_catalog_item_id uuid
  references public.purchase_catalog_items(id) on delete set null;

-- 5) (Optional) If purchases.supplier_id isn’t there yet
alter table public.purchases
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;

-- 6) Helpful indexes
create index if not exists idx_purchase_catalog_items_supplier on public.purchase_catalog_items(supplier_id);
create index if not exists idx_purchase_items_catalog on public.purchase_items(purchase_catalog_item_id);