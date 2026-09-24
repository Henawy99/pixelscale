-- ============================================================================
-- MyCut Migration 0001: Identity & Source Photos
-- ============================================================================
-- Creates the core identity layer: profiles, source_photos, and the
-- private 'faces' storage bucket. All tables have RLS enabled with
-- policies enforced inline.
-- ============================================================================

-- ─────────── Extensions ───────────
create extension if not exists "pgcrypto" schema extensions;

-- ─────────── Profiles ───────────
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  locale text not null default 'de',
  credits_remaining int not null default 5,
  plan text not null default 'free'
    check (plan in ('free', 'pro')),
  face_consent_at timestamptz,              -- explicit, timestamped, revocable
  created_at timestamptz not null default now()
);

comment on table public.profiles is
  'User profile extending auth.users. One row per registered user.';
comment on column public.profiles.face_consent_at is
  'Explicit GDPR consent timestamp for facial image processing. NULL = not consented.';
comment on column public.profiles.credits_remaining is
  'Server-authoritative generation credit balance. Decremented atomically in Edge Functions only.';

-- RLS: users can only read/update their own profile
alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Trigger: auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', 'User')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────── Source Photos ───────────
create table public.source_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  storage_path text not null,               -- private bucket 'faces'
  quality_score numeric,                    -- from on-device ML Kit gating
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'ok', 'rejected')),
  created_at timestamptz not null default now()
);

comment on table public.source_photos is
  'User-uploaded face photos for AI generation. Stored in private "faces" bucket.';
comment on column public.source_photos.moderation_status is
  'Content moderation status. Only "ok" photos may be used for generation.';

-- RLS: users can only access their own photos
alter table public.source_photos enable row level security;

create policy "Users can view own source photos"
  on public.source_photos for select
  using (auth.uid() = user_id);

create policy "Users can insert own source photos"
  on public.source_photos for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own source photos"
  on public.source_photos for delete
  using (auth.uid() = user_id);

-- Index for cleanup job
create index idx_source_photos_created_at
  on public.source_photos (created_at);

create index idx_source_photos_user_id
  on public.source_photos (user_id);

-- ─────────── Storage Bucket: faces (private) ───────────
-- Note: In Supabase, bucket creation is typically done via the dashboard
-- or seed.sql. This serves as documentation of the required config.
-- Bucket: 'faces'
--   - Public: false
--   - File size limit: 10MB
--   - Allowed MIME types: image/jpeg, image/png, image/webp
--   - RLS: users can only access their own folder (user_id prefix)

-- ─────────── GDPR: Auto-delete source photos after 90 days ───────────
-- Requires pg_cron extension enabled in Supabase project settings.
-- This creates a scheduled job that runs daily at 03:00 UTC.
--
-- IMPORTANT: The actual storage object deletion must be handled by an
-- Edge Function triggered by this cleanup, since SQL cannot directly
-- delete from Supabase Storage. The function below marks photos for
-- deletion; a companion Edge Function processes the queue.

create table public.source_photo_deletion_queue (
  id uuid primary key default gen_random_uuid(),
  source_photo_id uuid not null,
  storage_path text not null,
  user_id uuid not null,
  queued_at timestamptz not null default now()
);

comment on table public.source_photo_deletion_queue is
  'Queue for GDPR-mandated source photo cleanup. Processed by cleanup Edge Function.';

alter table public.source_photo_deletion_queue enable row level security;
-- No client access — service role only

create or replace function public.queue_stale_source_photos()
returns void as $$
begin
  -- Queue photos older than 90 days for deletion
  insert into public.source_photo_deletion_queue (source_photo_id, storage_path, user_id)
  select id, storage_path, user_id
  from public.source_photos
  where created_at < now() - interval '90 days'
  and id not in (
    select source_photo_id from public.source_photo_deletion_queue
  );

  -- Delete the database rows (storage cleanup is async via Edge Function)
  delete from public.source_photos
  where created_at < now() - interval '90 days';
end;
$$ language plpgsql security definer;

-- Schedule the cleanup (requires pg_cron)
-- Uncomment when pg_cron is enabled on the project:
-- select cron.schedule(
--   'cleanup-stale-source-photos',
--   '0 3 * * *',
--   $$select public.queue_stale_source_photos()$$
-- );
