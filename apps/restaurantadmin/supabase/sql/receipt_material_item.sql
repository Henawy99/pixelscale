-- Mapping table from wholesaler receipt lines to internal materials
create table if not exists public.receiptmaterialitem (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Raw fields from receipts
  raw_name text not null,                -- e.g., "Aviko Steakhouse Fries 2.5kg"
  brand_name text,                       -- Wholesaler or brand shown on receipt (optional)
  item_number text,                      -- SKU/article number from receipt (optional)

  -- Mapping to materials
  material_id uuid references public.material(id) on delete set null,

  -- Measurement/conversion for quantity matching
  receipt_unit text,                     -- e.g., "box", "kg", "piece"
  base_unit text,                        -- matching material unit_of_measure
  conversion_ratio numeric,              -- how many base_unit per 1 receipt_unit (e.g., 2.5kg per bag => 2.5)

  notes text
);

alter table public.receiptmaterialitem enable row level security;

-- Basic RLS policies
create policy if not exists receiptmaterialitem_select_authenticated
  on public.receiptmaterialitem for select
  using (auth.role() = 'authenticated');

create policy if not exists receiptmaterialitem_write_authenticated
  on public.receiptmaterialitem for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

create trigger trg_receiptmaterialitem_updated
before update on public.receiptmaterialitem
for each row execute function public.set_updated_at();

