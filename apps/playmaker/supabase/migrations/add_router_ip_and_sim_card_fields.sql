-- Migration: Add router_ip and sim_card_number to football_fields
-- Date: 2025-11-06
-- Description: Adds router IP and SIM card number fields for camera recording setup

-- Add router_ip column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS router_ip TEXT;

-- Add sim_card_number column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS sim_card_number TEXT;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'football_fields' 
  AND column_name IN ('router_ip', 'sim_card_number')
ORDER BY column_name;











