-- ============================================
-- Konsumentenretter – Supabase Database Schema
-- ============================================

-- Campaign types enum
CREATE TYPE campaign_type AS ENUM ('bearbeitungsgebuehren', 'servicepauschalen', 'casino');

-- Lead status enum (Pipedrive Kanban columns)
CREATE TYPE lead_status AS ENUM (
  'kooperationsvertrag', 'nur_unterschrieben', 'nur_ausweis',
  'nur_vertrag', 'unvollstaendig', 'vollstaendig',
  'zugesagt', 'warten_vollmacht', 'neue_dokumente',
  'bereit', 'abgelehnt', 'akt_anlegen', 'akt_angelegt', 'mahnung'
);

-- ============================================
-- Partners (MLM tree structure)
-- ============================================
CREATE TABLE partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  parent_partner_id UUID REFERENCES partners(id),
  commission_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
  ref_code TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'inactive', 'pending')),
  birth_date DATE,
  street TEXT,
  postal_code TEXT,
  city TEXT,
  partner_type TEXT CHECK (partner_type IN ('person', 'company')),
  company_name TEXT,
  company_address TEXT,
  contract_signed_at TIMESTAMPTZ,
  contract_signature_data TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_partners_parent ON partners(parent_partner_id);
CREATE INDEX idx_partners_ref_code ON partners(ref_code);

-- ============================================
-- Partner Invitations
-- ============================================
CREATE TABLE partner_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id UUID NOT NULL REFERENCES partners(id),
  invite_code TEXT UNIQUE NOT NULL,
  commission_percent DECIMAL(5,2) NOT NULL,
  email TEXT,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- Leads (Customer form submissions)
-- ============================================
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign campaign_type NOT NULL,
  ref_partner_id UUID REFERENCES partners(id),
  
  -- Personal data
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  birth_date DATE,
  street TEXT,
  city TEXT,
  postal_code TEXT,
  
  -- Campaign-specific data
  selections JSONB DEFAULT '[]',        -- banks, providers, or casinos
  estimated_value DECIMAL(12,2),        -- estimated losses (casino)
  has_insurance BOOLEAN DEFAULT false,
  insurance_provider TEXT,
  
  -- Confirmations
  confirmations JSONB DEFAULT '{}',
  
  -- Signature
  signature_data TEXT,
  
  -- Status
  status lead_status NOT NULL DEFAULT 'kooperationsvertrag',
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_leads_partner ON leads(ref_partner_id);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_campaign ON leads(campaign);

-- ============================================
-- Lead Files (uploaded documents)
-- ============================================
CREATE TABLE lead_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  file_type TEXT NOT NULL,               -- 'ausweis', 'kreditvertrag', 'rechnung', 'transaktionsdaten'
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,               -- Supabase Storage path
  file_size INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- Lead Status History (audit trail)
-- ============================================
CREATE TABLE lead_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  old_status lead_status,
  new_status lead_status NOT NULL,
  changed_by UUID REFERENCES partners(id),
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- Storage Buckets
-- ============================================
-- Run in Supabase Dashboard → Storage:
-- Create bucket: 'lead-documents' (private)
-- Create bucket: 'signatures' (private)

-- ============================================
-- RLS Policies (Row Level Security)
-- ============================================
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_invitations ENABLE ROW LEVEL SECURITY;

-- Partners can read their own data + their team
CREATE POLICY "Partners read own" ON partners FOR SELECT 
  USING (auth_user_id = auth.uid());

-- Leads: partners can see leads referred by them or their team
CREATE POLICY "Partners read own leads" ON leads FOR SELECT
  USING (ref_partner_id IN (
    SELECT id FROM partners WHERE auth_user_id = auth.uid()
  ));

-- Leads: anonymous insert (from customer website)
CREATE POLICY "Anyone can insert leads" ON leads FOR INSERT
  WITH CHECK (true);

-- Lead files: anonymous insert
CREATE POLICY "Anyone can insert lead files" ON lead_files FOR INSERT
  WITH CHECK (true);

-- Partners read their invitations
CREATE POLICY "Partners read own invites" ON partner_invitations FOR SELECT
  USING (inviter_id IN (
    SELECT id FROM partners WHERE auth_user_id = auth.uid()
  ));

-- ============================================
-- Seed Root Partner (Admin)
-- ============================================
INSERT INTO partners (
  id,
  first_name,
  last_name,
  email,
  commission_percent,
  ref_code,
  status,
  partner_type
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'Hashim',
  'Soliman',
  'office@konsumentenretter.at',
  35.00,
  'ref_hashim_admin',
  'active',
  'person'
) ON CONFLICT (email) DO NOTHING;

