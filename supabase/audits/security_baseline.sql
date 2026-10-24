-- Read-only checks to run in the Supabase SQL Editor before release.

-- Every user-owned public table should have RLS enabled.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and (
    c.relname = 'perfiles'
    or exists (
      select 1
      from pg_attribute a
      where a.attrelid = c.oid
        and a.attname = 'usuario_id'
        and not a.attisdropped
    )
  )
order by c.relname;

-- Review the row filters and write checks for those tables and Storage.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public')
  or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

-- User-uploaded buckets must be private.
select id, name, public
from storage.buckets
where id in ('avatars', 'receipts')
order by id;

-- The legacy public avatar read policy should return no rows.
select policyname
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'avatars_lectura_publica';

-- Inspect the ownership policies used by those buckets.
select policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (qual ilike '%avatars%' or qual ilike '%receipts%'
       or with_check ilike '%avatars%' or with_check ilike '%receipts%')
order by policyname;

-- The account deletion RPC must not be executable by client roles.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as security_definer,
  p.proconfig as function_settings,
  p.proacl as privileges
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'delete_user_data';
