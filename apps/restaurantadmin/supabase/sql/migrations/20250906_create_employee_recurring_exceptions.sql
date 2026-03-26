-- Create employee_recurring_exceptions table to suppress a single instance of a recurring rule in a given week
create table if not exists public.employee_recurring_exceptions (
  id bigserial primary key,
  created_at timestamp with time zone default now() not null,
  employee_id text not null,
  day_key text not null check (day_key in ('mon','tue','wed','thu','fri','sat','sun')),
  start_min integer not null check (start_min >= 0 and start_min <= 1439),
  end_min integer not null check (end_min > 0 and end_min <= 1440), -- exclusive
  week_start date not null
);

-- Helpful indexes
create index if not exists idx_employee_recurring_exceptions_week on public.employee_recurring_exceptions(week_start);
create index if not exists idx_employee_recurring_exceptions_emp_day on public.employee_recurring_exceptions(employee_id, day_key);
create index if not exists idx_employee_recurring_exceptions_range on public.employee_recurring_exceptions(start_min, end_min);

-- RLS
alter table public.employee_recurring_exceptions enable row level security;

-- Simple RLS policies: allow authenticated users to read and write
create policy if not exists employee_recurring_exceptions_select on public.employee_recurring_exceptions
  for select to authenticated using (true);

create policy if not exists employee_recurring_exceptions_insert on public.employee_recurring_exceptions
  for insert to authenticated with check (true);

create policy if not exists employee_recurring_exceptions_delete on public.employee_recurring_exceptions
  for delete to authenticated using (true);

-- Optional: prevent future overlaps? (kept simple here)

