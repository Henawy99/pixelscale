-- ============================================================================
-- MyCut Migration 0004: Generation Jobs
-- ============================================================================
-- Tracks AI hairstyle generation requests through their lifecycle:
--   queued → running → succeeded | failed
-- Enables Supabase Realtime for push-based status updates to the client.
-- Includes server-authoritative credit deduction RPC.
-- ============================================================================

-- ─────────── Generation Job Status Type ───────────
do $$ begin
  create type public.generation_status as enum (
    'queued', 'running', 'succeeded', 'failed'
  );
exception
  when duplicate_object then null;
end $$;

-- ─────────── Generation Jobs Table ───────────
create table public.generation_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  look_id uuid not null references public.looks(id) on delete cascade,
  source_photo_id uuid references public.source_photos(id) on delete set null,
  style_key text not null,
  prompt text not null default '',
  variation_count int not null default 4
    check (variation_count between 1 and 8),
  status public.generation_status not null default 'queued',
  error_message text,
  cost_micros integer not null default 0,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

comment on table public.generation_jobs is
  'Tracks AI hairstyle generation requests through queued → running → succeeded/failed lifecycle.';
comment on column public.generation_jobs.prompt is
  'Full prompt sent to the generative model, stored for audit and reproducibility.';
comment on column public.generation_jobs.variation_count is
  'Number of preview variations requested (default 4 for the exploration grid).';
comment on column public.generation_jobs.cost_micros is
  'Generation cost in micro-dollars for billing tracking.';

-- ─────────── RLS ───────────
alter table public.generation_jobs enable row level security;

-- Users can read their own jobs (for status polling fallback)
create policy "Users can view own generation jobs"
  on public.generation_jobs for select
  using (auth.uid() = user_id);

-- Insert is service-role only (Edge Function creates jobs)
-- No insert policy for authenticated users.

-- Users cannot update or delete jobs
-- Status transitions are handled by the Edge Function via service-role.

-- ─────────── Indexes ───────────
create index idx_generation_jobs_user_created
  on public.generation_jobs (user_id, created_at desc);

create index idx_generation_jobs_status
  on public.generation_jobs (status)
  where status in ('queued', 'running');

create index idx_generation_jobs_look_id
  on public.generation_jobs (look_id);

-- ─────────── Realtime ───────────
-- Enable Realtime publication for generation_jobs so the client
-- receives instant push notifications on status changes.
alter publication supabase_realtime add table public.generation_jobs;

-- ─────────── Credit Deduction RPC ───────────
-- Atomic credit deduction. Returns the new balance, or -1 if insufficient.
-- Called by the generate-look Edge Function with service-role privileges.
create or replace function public.deduct_credit(p_user_id uuid)
returns integer as $$
declare
  v_remaining integer;
begin
  update public.profiles
  set credits_remaining = credits_remaining - 1
  where id = p_user_id
    and credits_remaining > 0
  returning credits_remaining into v_remaining;

  if not found then
    return -1;
  end if;

  return v_remaining;
end;
$$ language plpgsql security definer;

comment on function public.deduct_credit is
  'Atomically decrements credits_remaining for a user. Returns new balance or -1 if insufficient.';

-- ─────────── Credit Check RPC (read-only) ───────────
-- Lightweight check for the client to display remaining credits.
create or replace function public.get_credits(p_user_id uuid)
returns integer as $$
declare
  v_remaining integer;
begin
  select credits_remaining into v_remaining
  from public.profiles
  where id = p_user_id;

  return coalesce(v_remaining, 0);
end;
$$ language plpgsql security definer stable;

comment on function public.get_credits is
  'Returns the current credit balance for a user.';
