-- Purchases and Purchase Items schema with optional Suppliers table
-- Safe, idempotent: uses IF NOT EXISTS and avoids failing if re-run

create extension if not exists pgcrypto;

-- Suppliers master (optional, can remain empty and use supplier_name on purchases)
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  name text not null unique,
  contact_name text,
  email text,
  phone text,
  notes text
);

alter table public.suppliers enable row level security;

-- Recreate policies idempotently (IF NOT EXISTS not supported for policies)
drop policy if exists suppliers_select_authenticated on public.suppliers;
drop policy if exists suppliers_insert_authenticated on public.suppliers;
drop policy if exists suppliers_update_authenticated on public.suppliers;

create policy suppliers_select_authenticated on public.suppliers for select using (auth.role() = 'authenticated');
create policy suppliers_insert_authenticated on public.suppliers for insert with check (auth.role() = 'authenticated');
create policy suppliers_update_authenticated on public.suppliers for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Purchases header
create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  brand_id uuid references public.brands(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  supplier_name text,

  receipt_date timestamptz,
  total_amount numeric(12,2),
  currency text,

  status text not null default 'pending_review',
  notes text
);

alter table public.purchases enable row level security;

drop policy if exists purchases_select_authenticated on public.purchases;
drop policy if exists purchases_insert_authenticated on public.purchases;
drop policy if exists purchases_update_authenticated on public.purchases;

create policy purchases_select_authenticated on public.purchases for select using (auth.role() = 'authenticated');
create policy purchases_insert_authenticated on public.purchases for insert with check (auth.role() = 'authenticated');
create policy purchases_update_authenticated on public.purchases for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create index if not exists idx_purchases_receipt_date on public.purchases (receipt_date desc nulls last);
create index if not exists idx_purchases_created_at on public.purchases (created_at desc);
create index if not exists idx_purchases_brand_id on public.purchases (brand_id);
create index if not exists idx_purchases_supplier_id on public.purchases (supplier_id);

-- Purchase line items
create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  purchase_id uuid not null references public.purchases(id) on delete cascade,

  -- Raw receipt data
  raw_name text not null,
  brand_name text,
  item_number text,

  -- Mapping to internal material (optional)
  material_id uuid references public.material(id) on delete set null,
  base_unit text,
  conversion_ratio numeric,

  -- Quantities & pricing
  quantity numeric,
  unit text,
  unit_price numeric,
  total_item_price numeric
);

alter table public.purchase_items enable row level security;

drop policy if exists purchase_items_select_authenticated on public.purchase_items;
drop policy if exists purchase_items_insert_authenticated on public.purchase_items;
drop policy if exists purchase_items_update_authenticated on public.purchase_items;

create policy purchase_items_select_authenticated on public.purchase_items for select using (auth.role() = 'authenticated');
create policy purchase_items_insert_authenticated on public.purchase_items for insert with check (auth.role() = 'authenticated');
create policy purchase_items_update_authenticated on public.purchase_items for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create index if not exists idx_purchase_items_purchase_id on public.purchase_items (purchase_id);
create index if not exists idx_purchase_items_material_id on public.purchase_items (material_id);

