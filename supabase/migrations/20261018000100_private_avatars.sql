-- Profile photos contain personal data. Keep the bucket private and scope
-- access to objects whose first path segment is the authenticated user ID.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do update set public = false;

drop policy if exists "avatar owners read their files" on storage.objects;
create policy "avatar owners read their files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "avatar owners upload their files" on storage.objects;
create policy "avatar owners upload their files"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "avatar owners update their files" on storage.objects;
create policy "avatar owners update their files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "avatar owners delete their files" on storage.objects;
create policy "avatar owners delete their files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Restrictive policies prevent any older permissive storage policy from
-- granting cross-user access to objects in this bucket.
drop policy if exists "avatars are isolated by owner" on storage.objects;
create policy "avatars are isolated by owner"
  on storage.objects as restrictive for all to public
  using (
    bucket_id <> 'avatars'
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id <> 'avatars'
    or (storage.foldername(name))[1] = (select auth.uid())::text
  );
