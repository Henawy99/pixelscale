-- Setup for server prompt storage, alias mapping, and unmatched item logging
-- Safe to run multiple times; uses IF NOT EXISTS where possible

-- Enable UUID generation if not already enabled
create extension if not exists pgcrypto;

-- 1) Global app settings used by Edge Functions for prompts
create table if not exists public.app_settings (
  id int primary key check (id = 1) default 1,
  receipt_prompt_hint text,          -- short, additive instructions (e.g., "Liefergebühr = deliveryFee")
  order_scan_prompt   text,          -- optional full prompt template (overrides default)
  updated_at          timestamptz not null default now()
);

-- Seed a single row (id = 1)
insert into public.app_settings (id)
values (1)
on conflict (id) do nothing;

-- RLS and policies
alter table public.app_settings enable row level security;

-- Allow authenticated users to read/update
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='app_settings' and policyname='app_settings_select_authenticated'
  ) then
    create policy app_settings_select_authenticated
      on public.app_settings for select
      using (auth.role() = 'authenticated');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='app_settings' and policyname='app_settings_insert_authenticated'
  ) then
    create policy app_settings_insert_authenticated
      on public.app_settings for insert
      with check (auth.role() = 'authenticated');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='app_settings' and policyname='app_settings_update_authenticated'
  ) then
    create policy app_settings_update_authenticated
      on public.app_settings for update
      using (auth.role() = 'authenticated')
      with check (auth.role() = 'authenticated');
  end if;
end $$;

-- 2) Alias table to improve menu item matching
create table if not exists public.menu_item_aliases (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete cascade,
  alias text not null,
  created_at timestamptz not null default now(),
  unique (brand_id, alias)
);

create index if not exists menu_item_aliases_brand_alias_idx on public.menu_item_aliases (brand_id, alias);

alter table public.menu_item_aliases enable row level security;

-- Minimal policies (adjust as needed)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='menu_item_aliases' and policyname='menu_item_aliases_select_authenticated'
  ) then
    create policy menu_item_aliases_select_authenticated
      on public.menu_item_aliases for select
      using (auth.role() = 'authenticated');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='menu_item_aliases' and policyname='menu_item_aliases_write_authenticated'
  ) then
    create policy menu_item_aliases_write_authenticated
      on public.menu_item_aliases for all
      using (auth.role() = 'authenticated')
      with check (auth.role() = 'authenticated');
  end if;
end $$;

-- 3) Unmatched items log to discover needed aliases
create table if not exists public.unmatched_menu_items (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands(id) on delete cascade,
  raw_name text not null,
  created_at timestamptz not null default now()
);


-- 4) Suggested aliases collected from scans (operator can review/approve later)
create table if not exists public.menu_item_alias_suggestions (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands(id) on delete cascade,
  alias text not null,
  created_at timestamptz not null default now(),
  unique (brand_id, alias)
);


create index if not exists unmatched_menu_items_brand_created_idx
  on public.unmatched_menu_items (brand_id, created_at desc);

alter table public.unmatched_menu_items enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='unmatched_menu_items' and policyname='unmatched_menu_items_select_authenticated'
  ) then
    create policy unmatched_menu_items_select_authenticated
      on public.unmatched_menu_items for select
      using (auth.role() = 'authenticated');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='unmatched_menu_items' and policyname='unmatched_menu_items_insert_authenticated'
  ) then
    create policy unmatched_menu_items_insert_authenticated
      on public.unmatched_menu_items for insert
      with check (auth.role() = 'authenticated');
  end if;
end $$;

