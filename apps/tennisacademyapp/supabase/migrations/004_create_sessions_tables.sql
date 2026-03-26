-- Enable UUID extension if not already enabled
create extension if not exists "uuid-ossp";

-- Sessions Table
create table if not exists public.sessions (
  id uuid default uuid_generate_v4() primary key,
  date date not null,
  court_id integer not null check (court_id between 1 and 4),
  name text not null, -- 'Professional', 'Game', etc.
  start_time time not null,
  end_time time not null,
  max_capacity integer default 4 not null,
  created_at timestamptz default now()
);

-- Session Registrations Table (Users joining sessions)
create table if not exists public.session_registrations (
  id uuid default uuid_generate_v4() primary key,
  session_id uuid references public.sessions(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  status text check (status in ('pending', 'approved', 'rejected')) default 'pending',
  created_at timestamptz default now(),
  unique(session_id, user_id) -- Prevent duplicate booking
);

-- Enable RLS
alter table public.sessions enable row level security;
alter table public.session_registrations enable row level security;

-- Policies for Sessions
create policy "Sessions are viewable by everyone" 
  on public.sessions for select using (true);

create policy "Admins can insert sessions" 
  on public.sessions for insert with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can update sessions" 
  on public.sessions for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can delete sessions" 
  on public.sessions for delete using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Policies for Registrations
create policy "Users can view own registrations" 
  on public.session_registrations for select using (
    auth.uid() = user_id
  );

create policy "Admins can view all registrations" 
  on public.session_registrations for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Users can insert own pending registration" 
  on public.session_registrations for insert with check (
    auth.uid() = user_id
  );

create policy "Users can delete own registration (cancel)" 
  on public.session_registrations for delete using (
    auth.uid() = user_id
  );

create policy "Admins can update registration status" 
  on public.session_registrations for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Function to handle joining a session safely (Race Condition Handling)
create or replace function public.join_session(
  p_session_id uuid,
  p_user_id uuid
) returns jsonb as $$
declare
  v_count integer;
  v_capacity integer;
  v_status text;
begin
  -- Lock the session row to prevent race conditions
  perform 1 from public.sessions where id = p_session_id for update;

  -- Check capacity (count only approved registrations?) 
  -- Prompt says: "When a session reaches 4 players... It must be marked as FULL".
  -- "Request to join session ONLY if players < 4".
  -- Does "players" mean approved or pending? Usually pending counts towards capacity to avoid overbooking.
  -- Let's count both pending and approved.
  
  select count(*) into v_count
  from public.session_registrations
  where session_id = p_session_id
  and status in ('pending', 'approved');

  select max_capacity into v_capacity
  from public.sessions
  where id = p_session_id;

  if v_count >= v_capacity then
    return jsonb_build_object('success', false, 'message', 'Session is full');
  end if;

  -- Insert registration
  insert into public.session_registrations (session_id, user_id, status)
  values (p_session_id, p_user_id, 'pending');

  return jsonb_build_object('success', true, 'message', 'Requested to join. Waiting for approval.');
exception
  when unique_violation then
    return jsonb_build_object('success', false, 'message', 'Already registered');
  when others then
    return jsonb_build_object('success', false, 'message', SQLERRM);
end;
$$ language plpgsql security definer;
