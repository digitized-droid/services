-- Descanso Comida • Cafe website content table
-- 1) Create an admin user in Supabase Dashboard > Authentication > Users.
-- 2) Copy that user's UUID and replace ADMIN_USER_UUID below.
-- 3) Run this entire script in SQL Editor.
create table if not exists public.descanso_site (
  id integer primary key check (id = 1),
  owner_id uuid not null references auth.users(id) on delete restrict,
  content jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.descanso_site enable row level security;
revoke all on public.descanso_site from anon, authenticated;
grant select on public.descanso_site to anon, authenticated;
grant update (content, updated_at) on public.descanso_site to authenticated;
drop policy if exists "Public can read cafe website content" on public.descanso_site;
create policy "Public can read cafe website content"
on public.descanso_site for select to anon, authenticated using (true);
drop policy if exists "Only site owner can update cafe website content" on public.descanso_site;
create policy "Only site owner can update cafe website content"
on public.descanso_site for update to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);
insert into public.descanso_site (id, owner_id, content)
values (1, 'ADMIN_USER_UUID'::uuid, '{}'::jsonb)
on conflict (id) do nothing;


-- Enable live notification when the administrator publishes a new official theme.
-- Run once in the Supabase SQL Editor if the table is not already in this publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'descanso_site'
  ) then
    alter publication supabase_realtime add table public.descanso_site;
  end if;
end $$;


-- Menu photos live in Supabase Storage, not localStorage or the JSON content row.
-- Replace ADMIN_USER_UUID with the same administrator UUID used above.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 10485760, array['image/jpeg'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view cafe menu photos" on storage.objects;
create policy "Public can view cafe menu photos"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'menu-images');

drop policy if exists "Cafe admin can upload menu photos" on storage.objects;
create policy "Cafe admin can upload menu photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'menu-images'
  and auth.uid() = 'ADMIN_USER_UUID'::uuid
);

drop policy if exists "Cafe admin can delete menu photos" on storage.objects;
create policy "Cafe admin can delete menu photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'menu-images'
  and auth.uid() = 'ADMIN_USER_UUID'::uuid
);
