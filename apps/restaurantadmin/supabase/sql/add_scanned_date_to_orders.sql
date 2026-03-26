-- Adds scanned_date column to orders table if it doesn't exist yet
alter table if exists public.orders
  add column if not exists scanned_date timestamptz;

-- Helpful index for latest-scanned sorting
create index if not exists idx_orders_scanned_date
  on public.orders (scanned_date desc);

