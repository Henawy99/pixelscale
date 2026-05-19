-- Add Foodora Self-Delivery columns to brands table
-- This supports a second Foodora page per brand (self-delivery vs platform delivery)

ALTER TABLE brands ADD COLUMN IF NOT EXISTS foodora_self_url TEXT;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS foodora_self_rating DOUBLE PRECISION;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS foodora_self_review_count INTEGER;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS foodora_self_rating_updated_at TIMESTAMPTZ;
