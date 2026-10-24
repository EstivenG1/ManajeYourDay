-- Remove superseded permissive avatar policies. Owner-scoped policies and the
-- restrictive owner guard remain in place from the private-avatar migration.
drop policy if exists "avatars_lectura_publica" on storage.objects;
drop policy if exists "avatars_actualizacion_propia" on storage.objects;
drop policy if exists "avatars_subida_propia" on storage.objects;

-- Remove all records belonging to a user before deleting their auth account.
-- Optional legacy tables are checked dynamically so a fresh project without
-- those modules can still apply this migration.
create or replace function public.delete_user_data(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required';
  end if;

  if to_regclass('public.notificaciones') is not null then
    execute 'delete from public.notificaciones where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.recomendaciones_ia') is not null then
    execute 'delete from public.recomendaciones_ia where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.reportes_semanales') is not null then
    execute 'delete from public.reportes_semanales where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.suscripciones') is not null then
    execute 'delete from public.suscripciones where usuario_id = $1'
      using target_user_id;
  end if;

  delete from public.aportes_ahorro where usuario_id = target_user_id;
  delete from public.movimientos_recurrentes where usuario_id = target_user_id;
  delete from public.movimientos where usuario_id = target_user_id;
  delete from public.presupuestos where usuario_id = target_user_id;
  delete from public.tareas where usuario_id = target_user_id;
  delete from public.sugerencias_texto where usuario_id = target_user_id;
  delete from public.metas_ahorro where usuario_id = target_user_id;
  delete from public.categorias where usuario_id = target_user_id;
  delete from public.perfiles where id = target_user_id;
end;
$$;

revoke all on function public.delete_user_data(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_user_data(uuid) to service_role;
