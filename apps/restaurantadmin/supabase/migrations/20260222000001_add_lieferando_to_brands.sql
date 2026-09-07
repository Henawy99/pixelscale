-- Add Lieferando integration columns to brands table
ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS lieferando_url TEXT,
  ADD COLUMN IF NOT EXISTS lieferando_rating NUMERIC(3, 1),
  ADD COLUMN IF NOT EXISTS lieferando_review_count INTEGER,
  ADD COLUMN IF NOT EXISTS lieferando_rating_updated_at TIMESTAMPTZ;

-- Pre-populate lieferando_url for known ghost kitchens
-- Tacotastic - French Tacos
UPDATE brands
SET lieferando_url = 'https://www.lieferando.at/speisekarte/tacotastic-french-tacos'
WHERE LOWER(name) LIKE '%tacotastic%'
  AND lieferando_url IS NULL;

-- Devil's Smash Burger
UPDATE brands
SET lieferando_url = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023'
WHERE (LOWER(name) LIKE '%devil%' OR LOWER(name) LIKE '%devel%' OR LOWER(name) LIKE '%smash%burger%')
  AND lieferando_url IS NULL;

-- Crispy Chicken Lab
UPDATE brands
SET lieferando_url = 'https://www.lieferando.at/en/menu/crispy-chicken-lab'
WHERE LOWER(name) LIKE '%crispy%chicken%'
  AND lieferando_url IS NULL;
