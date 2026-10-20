alter table public.movimientos
  add column if not exists comprobante_path text;

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do update set public = false;

drop policy if exists "receipt owners read their files" on storage.objects;
create policy "receipt owners read their files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "receipt owners upload their files" on storage.objects;
create policy "receipt owners upload their files"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "receipt owners update their files" on storage.objects;
create policy "receipt owners update their files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "receipt owners delete their files" on storage.objects;
create policy "receipt owners delete their files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "receipts are isolated by owner" on storage.objects;
create policy "receipts are isolated by owner"
  on storage.objects as restrictive for all to public
  using (
    bucket_id <> 'receipts'
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id <> 'receipts'
    or (storage.foldername(name))[1] = (select auth.uid())::text
  );
