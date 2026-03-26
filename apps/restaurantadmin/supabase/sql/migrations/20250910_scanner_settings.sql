-- Table to hold editable Gemini prompt for scanner classification
create table if not exists public.scanner_settings (
  id text primary key,
  prompt text,
  updated_at timestamptz not null default now()
);

alter table public.scanner_settings enable row level security;

create policy if not exists scanner_settings_select
  on public.scanner_settings for select to authenticated
  using (true);

create policy if not exists scanner_settings_upsert
  on public.scanner_settings for insert to authenticated
  with check (true);

create policy if not exists scanner_settings_update
  on public.scanner_settings for update to authenticated
  using (true) with check (true);

insert into public.scanner_settings (id, prompt)
values ('default', 'You are classifying a scanned receipt image as either order or purchase. Return only JSON {"classification":"order|purchase","confidence":0..1,"signals":["..."]}. Prefer platform names/logos (Lieferando, Wolt, Foodora) for orders; prefer known suppliers for purchases.')
on conflict (id) do nothing;

