-- Drop existing table and recreate with correct columns matching CSV
DROP TABLE IF EXISTS albaseet_inventory;

-- Create table with columns matching the CSV file
CREATE TABLE albaseet_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "Photo" TEXT,
    "Article" TEXT,
    "EAN Code" TEXT,
    "Q" TEXT,
    "Final Price" TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on EAN Code for faster lookups
CREATE INDEX idx_albaseet_inventory_ean ON albaseet_inventory("EAN Code");

-- Create index on Article
CREATE INDEX idx_albaseet_inventory_article ON albaseet_inventory("Article");

-- Enable Row Level Security
ALTER TABLE albaseet_inventory ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anonymous read access
CREATE POLICY "Allow anonymous read access to inventory"
ON albaseet_inventory
FOR SELECT
TO anon
USING (true);

-- Create policy to allow anonymous insert access (for imports)
CREATE POLICY "Allow anonymous insert access to inventory"
ON albaseet_inventory
FOR INSERT
TO anon
WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT ON albaseet_inventory TO anon;
GRANT SELECT, INSERT ON albaseet_inventory TO authenticated;
