-- Create employee_shifts table for storing daily shifts
CREATE TABLE IF NOT EXISTS employee_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups by date and employee
CREATE INDEX IF NOT EXISTS idx_employee_shifts_date ON employee_shifts(date);
CREATE INDEX IF NOT EXISTS idx_employee_shifts_employee ON employee_shifts(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_shifts_date_employee ON employee_shifts(date, employee_id);

-- Add email column to employees table if it doesn't exist
ALTER TABLE employees ADD COLUMN IF NOT EXISTS email TEXT;

-- Enable RLS
ALTER TABLE employee_shifts ENABLE ROW LEVEL SECURITY;

-- Policy to allow all operations (adjust as needed for your auth setup)
CREATE POLICY "Allow all operations on employee_shifts" ON employee_shifts
    FOR ALL USING (true) WITH CHECK (true);

-- Add comment
COMMENT ON TABLE employee_shifts IS 'Stores daily work shifts for employees (max 2 per day per employee)';





