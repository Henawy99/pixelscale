-- Create employee_assignments table (idempotent) and RLS policies
create extension if not exists pgcrypto;

create table if not exists public.employee_assignments (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  day_key text not null check (day_key in ('mon','tue','wed','thu','fri','sat','sun')),
  slot_minutes integer not null check (slot_minutes >= 0 and slot_minutes < 1440),
  employee_id uuid not null references public.employees(id) on delete cascade,
  week_start date null
);

-- Helpful indexes
create index if not exists employee_assignments_day_slot_idx on public.employee_assignments(day_key, slot_minutes);
create index if not exists employee_assignments_employee_idx on public.employee_assignments(employee_id);
create index if not exists employee_assignments_week_start_idx on public.employee_assignments(week_start);

-- Uniqueness: prevent duplicates for both recurring and week-bound cases
-- 1) For week-bound rows (week_start is not null), the quadruple must be unique
create unique index if not exists employee_assignments_unique_week
  on public.employee_assignments(day_key, slot_minutes, employee_id, week_start)
  where week_start is not null;
-- 2) For recurring rows (week_start is null), the triple must be unique
create unique index if not exists employee_assignments_unique_recurring
  on public.employee_assignments(day_key, slot_minutes, employee_id)
  where week_start is null;

alter table public.employee_assignments enable row level security;

-- Basic policies (adjust to your security model). Allow authenticated read/write.
drop policy if exists employee_assignments_select_authenticated on public.employee_assignments;
create policy employee_assignments_select_authenticated
  on public.employee_assignments for select
  using (auth.role() = 'authenticated');

drop policy if exists employee_assignments_insert_authenticated on public.employee_assignments;
create policy employee_assignments_insert_authenticated
  on public.employee_assignments for insert
  with check (auth.role() = 'authenticated');

drop policy if exists employee_assignments_delete_authenticated on public.employee_assignments;
create policy employee_assignments_delete_authenticated
  on public.employee_assignments for delete
  using (auth.role() = 'authenticated');

