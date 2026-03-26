-- Drop and recreate albaseet_inventory with correct column names from CSV
DROP TABLE IF EXISTS albaseet_inventory;

CREATE TABLE albaseet_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "EAN CODE" TEXT,
    "Item Genaric" TEXT,
    "Description" TEXT,
    "Final Retail price" TEXT,
    "Qty" TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE albaseet_inventory ENABLE ROW LEVEL SECURITY;

-- Create policies for public access
DROP POLICY IF EXISTS "Allow public read" ON albaseet_inventory;
DROP POLICY IF EXISTS "Allow public insert" ON albaseet_inventory;

CREATE POLICY "Allow public read" ON albaseet_inventory FOR SELECT TO anon USING (true);
CREATE POLICY "Allow public insert" ON albaseet_inventory FOR INSERT TO anon WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT ON albaseet_inventory TO anon;
