-- Update Tacotastic Menu - Signature Tacos Category
-- Run this SQL in your Supabase SQL Editor or via CLI

-- First, find the Tacotastic brand ID
-- Replace 'BRAND_ID_HERE' with the actual ID from this query:
-- SELECT id, name FROM brands WHERE LOWER(name) LIKE '%taco%';

-- Step 1: Create "Signature Tacos" category (if it doesn't exist)
INSERT INTO menu_categories (brand_id, name, display_order, created_at)
SELECT 
  id as brand_id,
  'Signature Tacos' as name,
  0 as display_order,
  NOW() as created_at
FROM brands 
WHERE LOWER(name) LIKE '%taco%'
ON CONFLICT DO NOTHING;

-- Step 2: Get the category ID for inserting items
-- You'll need this for the next step

-- Step 3: Insert menu items
-- Replace CATEGORY_ID_HERE and BRAND_ID_HERE with actual values

WITH brand_info AS (
  SELECT id as brand_id FROM brands WHERE LOWER(name) LIKE '%taco%' LIMIT 1
),
category_info AS (
  SELECT id as category_id FROM menu_categories 
  WHERE name = 'Signature Tacos' 
  AND brand_id = (SELECT brand_id FROM brand_info)
  LIMIT 1
)
INSERT INTO menu_items (category_id, brand_id, name, price, description, display_order, created_at)
SELECT 
  (SELECT category_id FROM category_info),
  (SELECT brand_id FROM brand_info),
  item.name,
  item.price,
  item.description,
  item.display_order,
  NOW()
FROM (VALUES
  ('Philly Cheese French Taco', 16.90, NULL, 0),
  ('Grilled Chicken French Taco', 15.90, NULL, 1),
  ('Freaky Tenders French Taco', 16.90, 'French Taco mit knusprigen Chicken Tenders, Putenschinken und unserer hausgemachten Cheese Sauce.', 2),
  ('Chicken Nuggets French Taco', 15.90, NULL, 3),
  ('Cheesy Bacon French Taco', 15.90, NULL, 4),
  ('Falafel French Taco', 15.90, NULL, 5)
) AS item(name, price, description, display_order);

-- Verify the items were added
SELECT 
  b.name as brand_name,
  c.name as category_name,
  mi.name as item_name,
  mi.price,
  mi.description
FROM menu_items mi
JOIN menu_categories c ON mi.category_id = c.id
JOIN brands b ON mi.brand_id = b.id
WHERE c.name = 'Signature Tacos'
ORDER BY mi.display_order;

