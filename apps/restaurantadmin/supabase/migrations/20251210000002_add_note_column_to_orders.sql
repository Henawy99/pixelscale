-- Migration: Add 'note' column to orders table
-- This replaces the concept of 'tip' which was incorrectly named
-- 'note' is a string field for order notes/comments

-- Add the note column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS note TEXT;

-- Add a comment for documentation
COMMENT ON COLUMN orders.note IS 'Order notes or special instructions';





