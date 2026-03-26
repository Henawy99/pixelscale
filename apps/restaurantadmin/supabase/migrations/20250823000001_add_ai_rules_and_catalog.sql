-- Add ai_rules to suppliers
alter table if exists public.suppliers
  add column if not exists ai_rules text;

-- Ensure extension for UUIDs (gen_random_uuid)
create extension if not exists pgcrypto;

-- Purchase catalog items table
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

-- Link purchase_items to purchase catalog
alter table if exists public.purchase_items
  add column if not exists purchase_catalog_item_id uuid
  references public.purchase_catalog_items(id) on delete set null;

-- Add supplier_id to purchases if not present
alter table if exists public.purchases
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;

-- Helpful indexes
create index if not exists idx_purchase_catalog_items_supplier on public.purchase_catalog_items(supplier_id);
create index if not exists idx_purchase_items_catalog on public.purchase_items(purchase_catalog_item_id);

