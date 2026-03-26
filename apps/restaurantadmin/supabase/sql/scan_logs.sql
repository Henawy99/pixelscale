-- Optional table to log raw Gemini output and normalized data for debugging scans
create table if not exists public.scan_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  scan_type text check (scan_type in ('order','purchase')),
  brand_id uuid,
  platform_order_id text,
  raw_response jsonb,
  normalized jsonb,
  error text
);

alter table public.scan_logs enable row level security;

create policy if not exists scan_logs_select_authenticated
  on public.scan_logs for select
  using (auth.role() = 'authenticated');

create policy if not exists scan_logs_insert_authenticated
  on public.scan_logs for insert
  with check (auth.role() = 'authenticated');

