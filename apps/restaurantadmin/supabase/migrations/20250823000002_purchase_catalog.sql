-- Supplier AI rules and Purchase Catalog Items

-- Add ai_rules column to suppliers
alter table public.suppliers add column if not exists ai_rules text;

-- Catalog of canonical purchase items (per supplier), linked to materials
create table if not exists public.purchase_catalog_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  supplier_id uuid references public.suppliers(id) on delete cascade,
  name text not null,
  receipt_name text,
  unit text,
  default_quantity numeric,

  material_id uuid references public.material(id) on delete set null,
  base_unit text,
  conversion_ratio numeric,
  notes text
);

alter table public.purchase_catalog_items enable row level security;
drop policy if exists pci_select_authenticated on public.purchase_catalog_items;
drop policy if exists pci_insert_authenticated on public.purchase_catalog_items;
drop policy if exists pci_update_authenticated on public.purchase_catalog_items;
create policy pci_select_authenticated on public.purchase_catalog_items for select using (auth.role() = 'authenticated');
create policy pci_insert_authenticated on public.purchase_catalog_items for insert with check (auth.role() = 'authenticated');
create policy pci_update_authenticated on public.purchase_catalog_items for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create index if not exists idx_pci_supplier_id on public.purchase_catalog_items (supplier_id);
create index if not exists idx_pci_material_id on public.purchase_catalog_items (material_id);

-- Link from per-purchase lines to catalog
alter table public.purchase_items add column if not exists purchase_catalog_item_id uuid references public.purchase_catalog_items(id) on delete set null;
create index if not exists idx_purchase_items_catalog_id on public.purchase_items (purchase_catalog_item_id);

