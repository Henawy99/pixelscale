-- Remove the foreign key constraint on booking_id in camera_recording_schedules
-- The relationship is managed in application code, and the FK constraint
-- causes issues with database replication lag and RLS policies

DO $$
BEGIN
  -- Drop the foreign key constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'camera_recording_schedules_booking_id_fkey'
    AND table_name = 'camera_recording_schedules'
  ) THEN
    ALTER TABLE camera_recording_schedules 
    DROP CONSTRAINT camera_recording_schedules_booking_id_fkey;
    RAISE NOTICE 'Dropped foreign key constraint camera_recording_schedules_booking_id_fkey';
  ELSE
    RAISE NOTICE 'Foreign key constraint camera_recording_schedules_booking_id_fkey does not exist';
  END IF;
END $$;
