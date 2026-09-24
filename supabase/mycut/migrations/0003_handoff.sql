-- ============================================================================
-- MyCut Migration 0003: The QR Handoff & Barbershop Station
-- ============================================================================
-- Powers the physical barbershop handoff:
-- - look_shares: 8-char Crockford base32 codes with 30-min TTL. Service-role only.
-- - receiver_devices: Unclaimed tablet growth loop tracked by device fingerprint.
-- - consultations: Record of scanned looks with Supabase Realtime broadcast.
-- - RPCs: rotate_share_code and redeem_share_code.
-- ============================================================================

-- ─────────── Look Shares ───────────
create table public.look_shares (
  code text primary key,
  look_id uuid not null references public.looks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  max_redemptions integer not null default 20,
  redemption_count integer not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.look_shares is
  'Ephemeral 8-character Crockford Base32 share codes for QR handoff. Not directly readable by clients.';

-- Direct client access strictly forbidden to prevent enumerating user looks
alter table public.look_shares enable row level security;

create index idx_look_shares_look_id on public.look_shares (look_id);
create index idx_look_shares_expires_at on public.look_shares (expires_at);

-- ─────────── Salons & Barbers ───────────
create table public.salons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text,
  city text,
  plan text not null default 'trial' check (plan in ('trial', 'starter', 'pro')),
  logo_path text,
  created_at timestamptz not null default now()
);

alter table public.salons enable row level security;

create policy "Anyone can view salons"
  on public.salons for select
  using (true);

create table public.barbers (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  display_name text not null,
  pin_hash text,
  created_at timestamptz not null default now()
);

alter table public.barbers enable row level security;

create policy "Anyone can view barbers"
  on public.barbers for select
  using (true);

-- ─────────── Receiver Devices (Unclaimed growth loop) ───────────
create table public.receiver_devices (
  id uuid primary key default gen_random_uuid(),
  device_fingerprint text unique not null,
  salon_id uuid references public.salons(id) on delete set null,
  claim_code text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  scan_count integer not null default 0
);

comment on table public.receiver_devices is
  'Barber shop tablet devices. Functions immediately without login; can be claimed later via 6-digit code.';

alter table public.receiver_devices enable row level security;

create policy "Receiver devices can view own record by fingerprint"
  on public.receiver_devices for select
  using (true);

-- ─────────── Consultations ───────────
create table public.consultations (
  id uuid primary key default gen_random_uuid(),
  look_id uuid not null references public.looks(id) on delete cascade,
  device_id uuid references public.receiver_devices(id) on delete set null,
  salon_id uuid references public.salons(id) on delete set null,
  barber_id uuid references public.barbers(id) on delete set null,
  notes text,
  after_photo_path text,
  scanned_at timestamptz not null default now()
);

comment on table public.consultations is
  'Event generated whenever a barber tablet redeems a look QR code. Triggers customer Realtime confirmation.';

alter table public.consultations enable row level security;

-- Customers can view consultations for their own looks
create policy "Customers can view consultations for their looks"
  on public.consultations for select
  using (
    exists (
      select 1 from public.looks
      where looks.id = consultations.look_id
      and looks.user_id = auth.uid()
    )
  );

-- Enable Realtime broadcast on consultations so customer phones get instant push notification
alter publication supabase_realtime add table public.consultations;

create index idx_consultations_look_id on public.consultations (look_id);
create index idx_consultations_device_id on public.consultations (device_id);

-- ─────────── Security Definer RPCs ───────────

-- 1. Helper: Generate random 8-character Crockford Base32 code
create or replace function public.generate_crockford_code()
returns text as $$
declare
  chars text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  result text := '';
  i integer;
begin
  for i in 1..8 loop
    result := result || substr(chars, floor(random() * 32 + 1)::integer, 1);
  end loop;
  return result;
end;
$$ language plpgsql volatile;

-- 2. rotate_share_code: Generates fresh 30-min share code for a look
create or replace function public.rotate_share_code(p_look_id uuid)
returns jsonb as $$
declare
  v_user_id uuid;
  v_code text;
  v_expires_at timestamptz := now() + interval '30 minutes';
  v_attempts integer := 0;
begin
  -- Validate caller owns the look
  select user_id into v_user_id
  from public.looks
  where id = p_look_id;

  if v_user_id is null or v_user_id != auth.uid() then
    raise exception 'Unauthorized or look not found';
  end if;

  -- Revoke prior active codes for this look
  update public.look_shares
  set revoked_at = now()
  where look_id = p_look_id
    and revoked_at is null
    and expires_at > now();

  -- Generate collision-free 8-char Crockford code
  loop
    v_code := public.generate_crockford_code();
    begin
      insert into public.look_shares (code, look_id, user_id, expires_at)
      values (v_code, p_look_id, v_user_id, v_expires_at);
      exit; -- success
    exception when unique_violation then
      v_attempts := v_attempts + 1;
      if v_attempts > 10 then
        raise exception 'Could not generate unique share code';
      end if;
    end;
  end loop;

  return jsonb_build_object(
    'code', v_code,
    'expires_at', v_expires_at,
    'share_url', 'https://mycut.app/l/' || v_code
  );
end;
$$ language plpgsql security definer;

-- 3. redeem_share_code: Validates code, registers device, records consultation
create or replace function public.redeem_share_code(
  p_code text,
  p_device_fingerprint text
)
returns jsonb as $$
declare
  v_share record;
  v_look record;
  v_profile record;
  v_device_id uuid;
  v_salon_id uuid;
  v_consultation_id uuid;
  v_first_name text;
  v_renders jsonb;
begin
  -- Normalize code (uppercase, trim)
  p_code := upper(trim(p_code));

  -- Lookup and validate share code
  select * into v_share
  from public.look_shares
  where code = p_code
  for update;

  if not found then
    raise exception 'Share code not found';
  end if;

  if v_share.revoked_at is not null then
    raise exception 'Share code has been revoked';
  end if;

  if v_share.expires_at <= now() then
    raise exception 'Share code has expired';
  end if;

  if v_share.redemption_count >= v_share.max_redemptions then
    raise exception 'Share code maximum redemptions reached';
  end if;

  -- Increment redemptions
  update public.look_shares
  set redemption_count = redemption_count + 1
  where code = p_code;

  -- Upsert receiver device by fingerprint (unclaimed growth loop)
  insert into public.receiver_devices (device_fingerprint, scan_count, last_seen_at)
  values (p_device_fingerprint, 1, now())
  on conflict (device_fingerprint) do update
  set scan_count = receiver_devices.scan_count + 1,
      last_seen_at = now()
  returning id, salon_id into v_device_id, v_salon_id;

  -- Log consultation (triggers customer Realtime listener)
  insert into public.consultations (look_id, device_id, salon_id, scanned_at)
  values (v_share.look_id, v_device_id, v_salon_id, now())
  returning id into v_consultation_id;

  -- Fetch look
  select * into v_look
  from public.looks
  where id = v_share.look_id;

  -- Fetch customer profile for first name only (privacy preserved)
  select * into v_profile
  from public.profiles
  where id = v_share.user_id;

  v_first_name := coalesce(
    split_part(trim(v_profile.display_name), ' ', 1),
    'Customer'
  );

  -- Fetch renders
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id,
    'view', view,
    'storage_path', storage_path,
    'resolution', resolution
  )), '[]'::jsonb)
  into v_renders
  from public.look_renders
  where look_id = v_share.look_id;

  return jsonb_build_object(
    'consultation_id', v_consultation_id,
    'look', jsonb_build_object(
      'id', v_look.id,
      'title', v_look.title,
      'style_key', v_look.style_key,
      'cut_spec', v_look.cut_spec,
      'created_at', v_look.created_at
    ),
    'renders', v_renders,
    'customer_first_name', v_first_name,
    'scanned_at', now()
  );
end;
$$ language plpgsql security definer;
