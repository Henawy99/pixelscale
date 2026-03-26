-- Create new table for Al Baseet inventory that matches CSV structure
-- The column names EXACTLY match your CSV headers so import will work

CREATE TABLE IF NOT EXISTS albaseet_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "EAN CODE" TEXT,
    "Item Genaric" TEXT,
    "Description" TEXT,
    "Final Retail price" TEXT,
    "Qty" TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_albaseet_inventory_ean ON albaseet_inventory("EAN CODE");
CREATE INDEX IF NOT EXISTS idx_albaseet_inventory_item ON albaseet_inventory("Item Genaric");

-- Enable Row Level Security
ALTER TABLE albaseet_inventory ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read inventory
CREATE POLICY "Anyone can read inventory" ON albaseet_inventory 
    FOR SELECT USING (true);

-- Allow anyone to insert inventory (for CSV import)
CREATE POLICY "Anyone can insert inventory" ON albaseet_inventory 
    FOR INSERT WITH CHECK (true);

-- Grant permissions
GRANT ALL ON albaseet_inventory TO anon;
GRANT ALL ON albaseet_inventory TO authenticated;
