-- Cache table for geocoding results to reduce external calls and speed up scans
create table if not exists public.geocode_cache (
  id uuid primary key default gen_random_uuid(),
  key text not null unique, -- normalized composite key: street|postcode|city
  street text,
  postcode text,
  city text,
  lat double precision not null,
  lon double precision not null,
  hit_count int not null default 0,
  last_hit_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists geocode_cache_key_idx on public.geocode_cache (key);

alter table public.geocode_cache enable row level security;

create policy if not exists geocode_cache_select_authenticated
  on public.geocode_cache for select
  using (auth.role() = 'authenticated');

create policy if not exists geocode_cache_insert_authenticated
  on public.geocode_cache for insert
  with check (auth.role() = 'authenticated');

create policy if not exists geocode_cache_update_authenticated
  on public.geocode_cache for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

