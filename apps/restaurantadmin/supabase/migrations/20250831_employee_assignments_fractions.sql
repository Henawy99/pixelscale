-- Add per-slot fraction columns so partial fills persist across reloads
-- Safe, idempotent: uses IF NOT EXISTS and defaults

alter table if exists public.employee_assignments
  add column if not exists start_fraction double precision not null default 0;

alter table if exists public.employee_assignments
  add column if not exists end_fraction double precision not null default 1;

-- Optional: narrow index to speed up weekly queries
create index if not exists idx_employee_assignments_week_start
  on public.employee_assignments (week_start);

