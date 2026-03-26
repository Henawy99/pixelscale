-- Create table to track scanned receipt images and their resulting records
create extension if not exists pgcrypto;

create table if not exists public.scanned_receipts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  -- 'order' or 'purchase'
  scan_type text not null check (scan_type in ('order','purchase')),

  -- Path inside the 'scanned-receipts' storage bucket
  storage_path text not null,

  -- Optional context for UI
  brand_name text,
  supplier_name text,
  platform_order_id text,

  -- Link to created records (nullable)
  created_order_id uuid references public.orders(id) on delete set null,
  created_purchase_id uuid references public.purchases(id) on delete set null,

  error text
);

alter table public.scanned_receipts enable row level security;

-- Allow authenticated clients to read for the Receipt Watcher UI
drop policy if exists scanned_receipts_select_authenticated on public.scanned_receipts;
create policy scanned_receipts_select_authenticated
  on public.scanned_receipts for select
  using (auth.role() = 'authenticated');

-- Allow authenticated clients (Edge Functions with user JWT) to insert
drop policy if exists scanned_receipts_insert_authenticated on public.scanned_receipts;
create policy scanned_receipts_insert_authenticated
  on public.scanned_receipts for insert
  with check (auth.role() = 'authenticated');

-- Indexes for common queries
create index if not exists idx_scanned_receipts_created_at on public.scanned_receipts (created_at desc);
create index if not exists idx_scanned_receipts_scan_type on public.scanned_receipts (scan_type);
create index if not exists idx_scanned_receipts_order_id on public.scanned_receipts (created_order_id);
create index if not exists idx_scanned_receipts_purchase_id on public.scanned_receipts (created_purchase_id);
