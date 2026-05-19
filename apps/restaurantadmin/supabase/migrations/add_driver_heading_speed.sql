-- Add heading and speed columns to drivers table for smooth map animation
-- heading: GPS bearing in degrees (0-360, 0=North)
-- speed: Speed in meters per second

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS current_heading double precision DEFAULT NULL;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS current_speed double precision DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN drivers.current_heading IS 'GPS heading/bearing in degrees (0-360, 0=North). Used for smooth car marker rotation on the delivery monitor map.';
COMMENT ON COLUMN drivers.current_speed IS 'Current speed in meters per second. Used for smooth position interpolation on the delivery monitor map.';
