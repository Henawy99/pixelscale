-- Migration: Add all camera recording fields to football_fields
-- Date: 2025-11-07
-- Description: Adds all camera recording related fields (camera credentials, IPs, etc.)

-- Add has_camera column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS has_camera BOOLEAN DEFAULT FALSE;

-- Add camera_username column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS camera_username TEXT;

-- Add camera_password column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS camera_password TEXT;

-- Add camera_ip_address column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS camera_ip_address TEXT;

-- Add raspberry_pi_ip column
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS raspberry_pi_ip TEXT;

-- Add router_ip column (if not already added by previous migration)
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS router_ip TEXT;

-- Add sim_card_number column (if not already added by previous migration)
ALTER TABLE football_fields 
ADD COLUMN IF NOT EXISTS sim_card_number TEXT;

-- Verify all columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'football_fields' 
  AND column_name IN (
    'has_camera',
    'camera_username',
    'camera_password', 
    'camera_ip_address',
    'raspberry_pi_ip',
    'router_ip',
    'sim_card_number'
  )
ORDER BY column_name;

