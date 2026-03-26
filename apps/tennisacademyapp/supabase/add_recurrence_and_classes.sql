-- Add recurrence fields to sessions table
ALTER TABLE public.sessions 
  ADD COLUMN IF NOT EXISTS recurrence_id UUID,
  ADD COLUMN IF NOT EXISTS recurrence_rule TEXT;

-- Create table for dynamic levels and classes
CREATE TABLE IF NOT EXISTS public.academy_classes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  level_id TEXT NOT NULL UNIQUE, -- e.g., 'green'
  label TEXT NOT NULL, -- e.g., 'Green'
  color_value TEXT NOT NULL, -- e.g., '0xFF2E7D32'
  classes JSONB NOT NULL DEFAULT '[]'::jsonb, -- e.g., '["Avocado", "Lemons"]'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Note: We use string for color_value to keep JSON payload simple.

ALTER TABLE public.academy_classes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Classes viewable by everyone" ON public.academy_classes
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage classes" ON public.academy_classes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Insert initial values if table is empty
INSERT INTO public.academy_classes (level_id, label, color_value, classes)
SELECT 'green', 'Green', '0xFF2E7D32', '["Avocado", "Lemons"]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.academy_classes WHERE level_id = 'green');

INSERT INTO public.academy_classes (level_id, label, color_value, classes)
SELECT 'red', 'Red', '0xFFC62828', '["Bee", "Candy", "Flower", "Pro Red"]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.academy_classes WHERE level_id = 'red');

INSERT INTO public.academy_classes (level_id, label, color_value, classes)
SELECT 'yellow', 'Yellow', '0xFFF9A825', '["Point", "Game Adult", "Game", "Point Adult", "Professional"]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.academy_classes WHERE level_id = 'yellow');

INSERT INTO public.academy_classes (level_id, label, color_value, classes)
SELECT 'orange', 'Orange', '0xFFE65100', '["Lions", "Pro Orange"]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.academy_classes WHERE level_id = 'orange');

NOTIFY pgrst, 'reload schema';
