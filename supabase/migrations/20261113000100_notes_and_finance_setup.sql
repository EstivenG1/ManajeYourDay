alter table public.perfiles
  add column if not exists finanzas_activas boolean not null default true;

alter table public.perfiles
  alter column finanzas_activas set default false;

create table if not exists public.notas (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  titulo text not null check (char_length(btrim(titulo)) between 1 and 80),
  contenido text not null check (char_length(btrim(contenido)) between 1 and 5000),
  color text not null default '#FFF3C4'
    check (color ~ '^#[0-9A-Fa-f]{6}$'),
  emoji text not null default 'note'
    check (char_length(emoji) between 1 and 32),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists notas_usuario_actualizado_idx
  on public.notas (usuario_id, actualizado_en desc);

alter table public.notas enable row level security;

create policy "notas owner access"
  on public.notas
  for all
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

grant select, insert, update, delete on public.notas to authenticated;

create or replace function public.get_plan_resource_limit(
  p_plan text,
  p_resource text
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_plan not in ('free', 'standard', 'premium') then
    raise exception 'Unknown plan';
  end if;

  case p_resource
    when 'tasks_monthly' then
      return case p_plan when 'free' then 50 when 'standard' then 500 else null end;
    when 'transactions_monthly' then
      return case p_plan when 'free' then 100 when 'standard' then 1000 else null end;
    when 'active_budgets' then
      return case p_plan when 'free' then 2 when 'standard' then 10 else null end;
    when 'active_goals' then
      return case p_plan when 'free' then 2 when 'standard' then 10 else null end;
    when 'active_recurring' then
      return case p_plan when 'free' then 3 when 'standard' then 25 else null end;
    when 'receipts_monthly' then
      return case p_plan when 'free' then 3 when 'standard' then 30 else 100 end;
    when 'notes_total' then
      return case p_plan when 'free' then 20 when 'standard' then 100 else null end;
    else
      raise exception 'Unknown plan resource';
  end case;
end;
$$;

create or replace function public.can_create_note()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  note_limit integer;
  note_count bigint;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  note_limit := public.get_plan_resource_limit(public.get_my_plan(), 'notes_total');
  select count(*) into note_count
  from public.notas
  where usuario_id = current_user_id;

  return note_limit is null or note_count < note_limit;
end;
$$;

revoke all on function public.can_create_note() from public, anon, authenticated;
grant execute on function public.can_create_note() to authenticated;

create or replace function public.enforce_note_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid := (select auth.uid());
  note_limit integer;
  note_count bigint;
begin
  if tg_op = 'UPDATE' then
    return new;
  end if;

  if owner_id is null or new.usuario_id <> owner_id then
    return new;
  end if;

  note_limit := public.get_plan_resource_limit(public.get_my_plan(), 'notes_total');
  select count(*) into note_count
  from public.notas
  where usuario_id = owner_id;

  if note_limit is not null and note_count >= note_limit then
    raise exception 'PLAN_LIMIT_REACHED: notes_total';
  end if;

  return new;
end;
$$;

create trigger enforce_plan_limit_notes
  before insert on public.notas
  for each row execute function public.enforce_note_limit();

create or replace function public.update_note_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger update_note_timestamp
  before update on public.notas
  for each row execute function public.update_note_timestamp();

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

  delete from public.notas where usuario_id = target_user_id;
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
