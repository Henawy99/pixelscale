-- Add RLS DELETE policy for suppliers so authenticated users can delete suppliers.
-- Previously only SELECT, INSERT, UPDATE were allowed; deletes were blocked by RLS.

drop policy if exists suppliers_delete_authenticated on public.suppliers;
create policy suppliers_delete_authenticated on public.suppliers
  for delete using (auth.role() = 'authenticated');
