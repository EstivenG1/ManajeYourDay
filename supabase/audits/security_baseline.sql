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
  and c.relname in (
    'perfiles', 'categorias', 'movimientos', 'presupuestos', 'tareas',
    'metas_ahorro', 'aportes_ahorro', 'sugerencias_texto',
    'movimientos_recurrentes'
  )
order by c.relname;

-- Review the row filters and write checks for those tables and Storage.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in (
    'perfiles', 'categorias', 'movimientos', 'presupuestos', 'tareas',
    'metas_ahorro', 'aportes_ahorro', 'sugerencias_texto',
    'movimientos_recurrentes'
  ))
  or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

-- The avatars bucket must be private.
select id, name, public
from storage.buckets
where id = 'avatars';

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
