-- Public web ordering: menu readable by anon (optional fallback if edge fn unavailable).
-- Orders are created via create-web-order edge function (service role).

-- Menu categories & items (read-only for guests)
drop policy if exists menu_categories_public_read on public.menu_categories;
create policy menu_categories_public_read on public.menu_categories
  for select to anon, authenticated using (true);

drop policy if exists menu_items_public_read on public.menu_items;
create policy menu_items_public_read on public.menu_items
  for select to anon, authenticated using (is_available = true);

comment on policy menu_categories_public_read on public.menu_categories is
  'Allows public ordering sites to load menus (prices are not secret).';
