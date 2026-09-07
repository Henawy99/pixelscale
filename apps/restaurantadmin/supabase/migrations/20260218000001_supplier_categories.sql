-- Categories per supplier (e.g. Metro: Tiefkühl, Gemüse, ...). User can add/delete.
create table if not exists public.supplier_categories (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  name text not null,
  unique(supplier_id, name)
);

alter table public.supplier_categories enable row level security;

drop policy if exists supplier_categories_select on public.supplier_categories;
drop policy if exists supplier_categories_insert on public.supplier_categories;
drop policy if exists supplier_categories_update on public.supplier_categories;
drop policy if exists supplier_categories_delete on public.supplier_categories;

create policy supplier_categories_select on public.supplier_categories
  for select using (auth.role() = 'authenticated');
create policy supplier_categories_insert on public.supplier_categories
  for insert with check (auth.role() = 'authenticated');
create policy supplier_categories_update on public.supplier_categories
  for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy supplier_categories_delete on public.supplier_categories
  for delete using (auth.role() = 'authenticated');

create index if not exists idx_supplier_categories_supplier_id on public.supplier_categories(supplier_id);
