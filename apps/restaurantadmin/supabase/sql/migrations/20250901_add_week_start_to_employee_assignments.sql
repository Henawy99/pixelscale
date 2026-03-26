-- Add nullable week_start to support non-recurring assignments bound to a specific week
alter table if exists public.employee_assignments
  add column if not exists week_start date;

-- Index for week queries
create index if not exists employee_assignments_week_start_idx
  on public.employee_assignments(week_start);

