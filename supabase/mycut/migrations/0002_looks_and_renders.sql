-- ============================================================================
-- MyCut Migration 0002: Looks & Look Renders
-- ============================================================================
-- Stores customer-saved looks and their multi-angle visual renders.
-- Storage bucket 'renders' is private; clients access files via signed URLs.
-- ============================================================================

-- ─────────── Looks Table ───────────
create table public.looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  source_photo_id uuid references public.source_photos(id) on delete set null,
  title text not null default 'My Look',
  style_key text not null default 'custom',
  prompt_snapshot jsonb not null default '{}'::jsonb,
  cut_spec jsonb,
  is_archived boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.looks is
  'Saved customer looks with associated cut specifications and style metadata.';

alter table public.looks enable row level security;

create policy "Users can view own looks"
  on public.looks for select
  using (auth.uid() = user_id);

create policy "Users can insert own looks"
  on public.looks for insert
  with check (auth.uid() = user_id);

create policy "Users can update own looks"
  on public.looks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own looks"
  on public.looks for delete
  using (auth.uid() = user_id);

create index idx_looks_user_id on public.looks (user_id);
create index idx_looks_created_at on public.looks (created_at desc);

-- ─────────── Look Renders Table ───────────
create table public.look_renders (
  id uuid primary key default gen_random_uuid(),
  look_id uuid not null references public.looks(id) on delete cascade,
  view text not null check (view in ('front', 'side_left', 'side_right', 'back', 'isometric')),
  storage_path text not null,
  provider text not null default 'manual-upload',
  resolution text not null default 'final' check (resolution in ('preview', 'final')),
  cost_micros integer default 0,
  created_at timestamptz not null default now()
);

comment on table public.look_renders is
  'Image renders for a look across viewing angles. Stored in private "renders" bucket.';

alter table public.look_renders enable row level security;

create policy "Users can view own look renders"
  on public.look_renders for select
  using (
    exists (
      select 1 from public.looks
      where looks.id = look_renders.look_id
      and looks.user_id = auth.uid()
    )
  );

create policy "Users can insert renders for own looks"
  on public.look_renders for insert
  with check (
    exists (
      select 1 from public.looks
      where looks.id = look_renders.look_id
      and looks.user_id = auth.uid()
    )
  );

create policy "Users can delete renders for own looks"
  on public.look_renders for delete
  using (
    exists (
      select 1 from public.looks
      where looks.id = look_renders.look_id
      and looks.user_id = auth.uid()
    )
  );

create index idx_look_renders_look_id on public.look_renders (look_id);
