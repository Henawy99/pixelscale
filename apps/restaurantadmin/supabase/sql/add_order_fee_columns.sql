-- Adds missing fee-related columns to orders table if needed
alter table public.orders add column if not exists delivery_fee numeric(10,2);
alter table public.orders add column if not exists fixed_service_fee numeric(10,2);
alter table public.orders add column if not exists commission_amount numeric(10,2);
alter table public.orders add column if not exists tip numeric(10,2);

