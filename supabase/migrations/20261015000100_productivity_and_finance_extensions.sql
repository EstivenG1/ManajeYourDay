alter table public.tareas
  add column if not exists recurrencia text not null default 'ninguna',
  add column if not exists recurrencia_padre_id text;

alter table public.tareas
  drop constraint if exists tareas_recurrencia_check;

alter table public.tareas
  add constraint tareas_recurrencia_check
  check (recurrencia in ('ninguna', 'diaria', 'semanal', 'mensual'));

create unique index if not exists tareas_recurrencia_padre_unico
  on public.tareas (recurrencia_padre_id)
  where recurrencia_padre_id is not null;

alter table public.metas_ahorro
  add column if not exists aporte_programado numeric not null default 0,
  add column if not exists frecuencia_aporte text not null default 'mensual',
  add column if not exists proximo_aporte date;

alter table public.metas_ahorro
  drop constraint if exists metas_ahorro_frecuencia_aporte_check;

alter table public.metas_ahorro
  add constraint metas_ahorro_frecuencia_aporte_check
  check (frecuencia_aporte in ('semanal', 'quincenal', 'mensual'));

create table if not exists public.movimientos_recurrentes (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('ingreso', 'gasto')),
  monto numeric not null check (monto > 0),
  categoria_id bigint not null,
  descripcion text,
  frecuencia text not null check (frecuencia in ('semanal', 'quincenal', 'mensual')),
  proxima_fecha date not null,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create index if not exists movimientos_recurrentes_usuario_fecha_idx
  on public.movimientos_recurrentes (usuario_id, proxima_fecha)
  where activo;

alter table public.movimientos_recurrentes enable row level security;

drop policy if exists "usuarios gestionan sus movimientos recurrentes"
  on public.movimientos_recurrentes;

create policy "usuarios gestionan sus movimientos recurrentes"
  on public.movimientos_recurrentes
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

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

revoke all on function public.delete_user_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_user_data(uuid) to service_role;
