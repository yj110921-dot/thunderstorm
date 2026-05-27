-- Supabase SQL Editor에서 한 번 실행하세요.
-- Storage bucket 이름: archive-images
-- Public bucket으로 생성하거나 아래 insert 구문을 실행합니다.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'archive-images',
  'archive-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

create table if not exists public.archive_images (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  storage_path text not null unique,
  original_name text not null,
  width integer not null,
  height integer not null,
  aspect_ratio numeric not null,
  owner_id uuid references auth.users(id) on delete set null,
  owner_email text,
  created_at timestamptz not null default now()
);

alter table public.archive_images enable row level security;

create or replace function public.is_archive_admin()
returns boolean
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) in (
    'yj110921@gmail.com',
    'yejin11090@naver.com'
  );
$$;

drop policy if exists "Archive images are public" on public.archive_images;
create policy "Archive images are public"
on public.archive_images
for select
using (true);

drop policy if exists "Anyone can insert archive images" on public.archive_images;
create policy "Anyone can insert archive images"
on public.archive_images
for insert
with check (owner_id is null or owner_id = auth.uid());

drop policy if exists "Owners and admins can delete archive images" on public.archive_images;
create policy "Owners and admins can delete archive images"
on public.archive_images
for delete
using (public.is_archive_admin() or owner_id = auth.uid());

drop policy if exists "Public can view archive storage" on storage.objects;
create policy "Public can view archive storage"
on storage.objects
for select
using (bucket_id = 'archive-images');

drop policy if exists "Anyone can upload archive storage" on storage.objects;
create policy "Anyone can upload archive storage"
on storage.objects
for insert
with check (bucket_id = 'archive-images');

drop policy if exists "Owners and admins can delete archive storage" on storage.objects;
create policy "Owners and admins can delete archive storage"
on storage.objects
for delete
using (
  bucket_id = 'archive-images'
  and exists (
    select 1
    from public.archive_images image
    where image.storage_path = storage.objects.name
      and (public.is_archive_admin() or image.owner_id = auth.uid())
  )
);
