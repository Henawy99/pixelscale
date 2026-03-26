-- Add booking_id column to camera_recording_schedules to link recordings to bookings
-- This enables automatic camera recording when users book fields with cameras

-- Add the booking_id column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'camera_recording_schedules' 
    AND column_name = 'booking_id'
  ) THEN
    ALTER TABLE camera_recording_schedules 
    ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL;
    
    -- Add index for faster lookups
    CREATE INDEX IF NOT EXISTS camera_recording_schedules_booking_id_idx 
    ON camera_recording_schedules(booking_id);
    
    RAISE NOTICE 'Added booking_id column to camera_recording_schedules';
  ELSE
    RAISE NOTICE 'booking_id column already exists in camera_recording_schedules';
  END IF;
END $$;

-- Also ensure the recording_schedule_id column exists in bookings table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' 
    AND column_name = 'recording_schedule_id'
  ) THEN
    ALTER TABLE bookings 
    ADD COLUMN recording_schedule_id UUID;
    
    -- Add index for faster lookups
    CREATE INDEX IF NOT EXISTS bookings_recording_schedule_id_idx 
    ON bookings(recording_schedule_id);
    
    RAISE NOTICE 'Added recording_schedule_id column to bookings';
  ELSE
    RAISE NOTICE 'recording_schedule_id column already exists in bookings';
  END IF;
END $$;
