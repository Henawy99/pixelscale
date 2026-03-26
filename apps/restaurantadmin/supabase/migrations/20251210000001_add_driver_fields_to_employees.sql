-- Add is_driver and auth_user_id columns to employees table
ALTER TABLE employees ADD COLUMN IF NOT EXISTS is_driver BOOLEAN DEFAULT FALSE;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- Add comments for documentation
COMMENT ON COLUMN employees.is_driver IS 'Whether this employee is a delivery driver who can login to the driver app';
COMMENT ON COLUMN employees.auth_user_id IS 'Reference to the auth.users record for login credentials';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_employees_auth_user_id ON employees(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_employees_is_driver ON employees(is_driver) WHERE is_driver = TRUE;





