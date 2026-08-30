-- Migration: Add Lieferando order fields (phone, verification code, public reference, delivery notes)
-- These fields come directly from the Lieferando API response.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS customer_phone    TEXT,           -- Customer real phone number
  ADD COLUMN IF NOT EXISTS verification_code TEXT,           -- Lieferando masking/verification code (shown in Kitchen app)
  ADD COLUMN IF NOT EXISTS public_reference  TEXT,           -- Short order reference e.g. "3FPDK7"
  ADD COLUMN IF NOT EXISTS delivery_notes    TEXT;           -- Floor / door / buzzer instructions from customer
