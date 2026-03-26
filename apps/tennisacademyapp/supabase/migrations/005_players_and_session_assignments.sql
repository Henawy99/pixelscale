-- Players roster (name, level color, class)
create table if not exists public.players (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  level text not null check (level in ('green', 'red', 'yellow', 'orange')),
  class_name text not null,
  created_at timestamptz default now()
);

-- Session slot assignments: which roster player is in which slot (1-4)
create table if not exists public.session_assignments (
  id uuid default uuid_generate_v4() primary key,
  session_id uuid references public.sessions(id) on delete cascade not null,
  player_id uuid references public.players(id) on delete cascade not null,
  slot integer not null check (slot between 1 and 4),
  created_at timestamptz default now(),
  unique(session_id, slot),
  unique(session_id, player_id)
);

alter table public.players enable row level security;
alter table public.session_assignments enable row level security;

create policy "Admins can manage players"
  on public.players for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can manage session_assignments"
  on public.session_assignments for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Anyone can read players"
  on public.players for select using (true);

create policy "Anyone can read session_assignments"
  on public.session_assignments for select using (true);
