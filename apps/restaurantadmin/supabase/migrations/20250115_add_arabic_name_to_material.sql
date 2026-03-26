-- Add arabic_name column to material table for Arabic translations
alter table if exists public.material 
add column if not exists arabic_name text;

-- Add comment to document the column
comment on column public.material.arabic_name is 'Arabic translation of the material name for worker interface';

-- Create index for better performance on Arabic name searches
create index if not exists idx_material_arabic_name on public.material (arabic_name) where arabic_name is not null;
