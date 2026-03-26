-- Create schedule_history table and policies (idempotent)
create extension if not exists pgcrypto;

create table if not exists public.schedule_history (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  action_type text not null check (action_type in ('add','delete','edit')),
  employee_id uuid references public.employees(id) on delete set null,
  day_key text not null check (day_key in ('mon','tue','wed','thu','fri','sat','sun')),
  start_minutes integer not null check (start_minutes >= 0 and start_minutes < 1440),
  end_minutes integer not null check (end_minutes >= 0 and end_minutes <= 1440),
  week_start date null,
  message text
);

alter table public.schedule_history enable row level security;

drop policy if exists schedule_history_select_authenticated on public.schedule_history;
create policy schedule_history_select_authenticated
  on public.schedule_history for select
  using (auth.role() = 'authenticated');

drop policy if exists schedule_history_insert_authenticated on public.schedule_history;
create policy schedule_history_insert_authenticated
  on public.schedule_history for insert
  with check (auth.role() = 'authenticated');

