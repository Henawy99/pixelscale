-- schedule_history: persist schedule change logs
create table if not exists public.schedule_history (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  action_type text not null check (action_type in ('add','delete','edit')),
  employee_id uuid references public.employees(id) on delete set null,
  day_key text not null check (day_key in ('mon','tue','wed','thu','fri','sat','sun')),
  start_minutes integer not null,
  end_minutes integer not null,
  week_start date null,
  message text not null
);

create index if not exists schedule_history_created_at_idx on public.schedule_history(created_at desc);
create index if not exists schedule_history_day_week_idx on public.schedule_history(day_key, week_start);

alter table public.schedule_history enable row level security;

create policy "history_select" on public.schedule_history for select to authenticated using (true);
create policy "history_insert" on public.schedule_history for insert to authenticated with check (true);

