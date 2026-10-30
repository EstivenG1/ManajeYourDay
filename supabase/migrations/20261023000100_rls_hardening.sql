-- Enable RLS and owner-scoped policies on all user-owned tables.
-- Run this on the production Supabase project before release.

-- perfiles
alter table if exists public.perfiles enable row level security;
drop policy if exists "perfiles owner access" on public.perfiles;
create policy "perfiles owner access"
  on public.perfiles
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- tareas
alter table if exists public.tareas enable row level security;
drop policy if exists "tareas owner access" on public.tareas;
create policy "tareas owner access"
  on public.tareas
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- movimientos
alter table if exists public.movimientos enable row level security;
drop policy if exists "movimientos owner access" on public.movimientos;
create policy "movimientos owner access"
  on public.movimientos
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- presupuestos
alter table if exists public.presupuestos enable row level security;
drop policy if exists "presupuestos owner access" on public.presupuestos;
create policy "presupuestos owner access"
  on public.presupuestos
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- metas_ahorro
alter table if exists public.metas_ahorro enable row level security;
drop policy if exists "metas_ahorro owner access" on public.metas_ahorro;
create policy "metas_ahorro owner access"
  on public.metas_ahorro
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- categorias
alter table if exists public.categorias enable row level security;
drop policy if exists "categorias owner access" on public.categorias;
create policy "categorias owner access"
  on public.categorias
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- aportes_ahorro
alter table if exists public.aportes_ahorro enable row level security;
drop policy if exists "aportes_ahorro owner access" on public.aportes_ahorro;
create policy "aportes_ahorro owner access"
  on public.aportes_ahorro
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- sugerencias_texto
alter table if exists public.sugerencias_texto enable row level security;
drop policy if exists "sugerencias_texto owner access" on public.sugerencias_texto;
create policy "sugerencias_texto owner access"
  on public.sugerencias_texto
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- movimientos_recurrentes (already has RLS, re-apply to be safe)
alter table if exists public.movimientos_recurrentes enable row level security;
drop policy if exists "movimientos_recurrentes owner access" on public.movimientos_recurrentes;
create policy "movimientos_recurrentes owner access"
  on public.movimientos_recurrentes
  for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- notificaciones (optional table)
do $$
begin
  if to_regclass('public.notificaciones') is not null then
    alter table public.notificaciones enable row level security;
    drop policy if exists "notificaciones owner access" on public.notificaciones;
    create policy "notificaciones owner access"
      on public.notificaciones
      for all
      using (auth.uid() = usuario_id)
      with check (auth.uid() = usuario_id);
  end if;
end $$;

-- reportes_semanales (optional table)
do $$
begin
  if to_regclass('public.reportes_semanales') is not null then
    alter table public.reportes_semanales enable row level security;
    drop policy if exists "reportes_semanales owner access" on public.reportes_semanales;
    create policy "reportes_semanales owner access"
      on public.reportes_semanales
      for all
      using (auth.uid() = usuario_id)
      with check (auth.uid() = usuario_id);
  end if;
end $$;

-- suscripciones (optional table)
do $$
begin
  if to_regclass('public.suscripciones') is not null then
    alter table public.suscripciones enable row level security;
    drop policy if exists "suscripciones owner access" on public.suscripciones;
    create policy "suscripciones owner access"
      on public.suscripciones
      for all
      using (auth.uid() = usuario_id)
      with check (auth.uid() = usuario_id);
  end if;
end $$;

-- recomendaciones_ia (optional table)
do $$
begin
  if to_regclass('public.recomendaciones_ia') is not null then
    alter table public.recomendaciones_ia enable row level security;
    drop policy if exists "recomendaciones_ia owner access" on public.recomendaciones_ia;
    create policy "recomendaciones_ia owner access"
      on public.recomendaciones_ia
      for all
      using (auth.uid() = usuario_id)
      with check (auth.uid() = usuario_id);
  end if;
end $$;

-- Ensure delete_user_data RPC is only executable by service_role.
revoke all on function public.delete_user_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_user_data(uuid) to service_role;
