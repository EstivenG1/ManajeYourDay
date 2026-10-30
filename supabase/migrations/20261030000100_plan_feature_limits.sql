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
    else
      raise exception 'Unknown plan resource';
  end case;
end;
$$;

revoke all on function public.get_plan_resource_limit(text, text)
  from public, anon, authenticated;
grant execute on function public.get_plan_resource_limit(text, text)
  to authenticated;

create or replace function public.can_create_plan_resource(p_resource text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  current_plan text;
  resource_limit integer;
  current_usage bigint;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  current_plan := public.get_my_plan();
  resource_limit := public.get_plan_resource_limit(current_plan, p_resource);

  case p_resource
    when 'tasks_monthly' then
      select count(*) into current_usage
      from public.tareas
      where usuario_id = current_user_id
        and creado_en >= date_trunc('month', statement_timestamp());
    when 'transactions_monthly' then
      select count(*) into current_usage
      from public.movimientos
      where usuario_id = current_user_id
        and creado_en >= date_trunc('month', statement_timestamp());
    when 'active_budgets' then
      select count(*) into current_usage
      from public.presupuestos
      where usuario_id = current_user_id
        and fecha_fin >= current_date;
    when 'active_goals' then
      select count(*) into current_usage
      from public.metas_ahorro
      where usuario_id = current_user_id
        and estado = 'activa';
    when 'active_recurring' then
      select count(*) into current_usage
      from public.movimientos_recurrentes
      where usuario_id = current_user_id
        and activo;
    when 'receipts_monthly' then
      select count(*) into current_usage
      from storage.objects
      where bucket_id = 'receipts'
        and (storage.foldername(name))[1] = current_user_id::text
        and created_at >= date_trunc('month', statement_timestamp());
  end case;

  return resource_limit is null or current_usage < resource_limit;
end;
$$;

revoke all on function public.can_create_plan_resource(text)
  from public, anon, authenticated;
grant execute on function public.can_create_plan_resource(text)
  to authenticated;

create or replace function public.enforce_plan_resource_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  resource_name text;
  resource_limit integer;
  current_usage bigint;
  excluded_id text;
begin
  if tg_op = 'UPDATE' then
    excluded_id := old.id::text;
  end if;

  if tg_table_schema = 'storage' then
    if new.bucket_id <> 'receipts' or current_user_id is null then
      return new;
    end if;
    if (storage.foldername(new.name))[1] <> current_user_id::text then
      return new;
    end if;
    resource_name := 'receipts_monthly';
    resource_limit := public.get_plan_resource_limit(
      public.get_my_plan(),
      resource_name
    );
    select count(*) into current_usage
    from storage.objects
    where bucket_id = 'receipts'
      and (storage.foldername(name))[1] = current_user_id::text
      and created_at >= date_trunc('month', statement_timestamp())
      and (excluded_id is null or id::text <> excluded_id);
  else
    if current_user_id is null or new.usuario_id <> current_user_id then
      return new;
    end if;

    case tg_table_name
      when 'tareas' then
        resource_name := 'tasks_monthly';
        select count(*) into current_usage
        from public.tareas
        where usuario_id = current_user_id
          and creado_en >= date_trunc('month', statement_timestamp());
      when 'movimientos' then
        resource_name := 'transactions_monthly';
        select count(*) into current_usage
        from public.movimientos
        where usuario_id = current_user_id
          and creado_en >= date_trunc('month', statement_timestamp());
      when 'presupuestos' then
        if new.fecha_fin < current_date then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.fecha_fin >= current_date then
            return new;
          end if;
        end if;
        resource_name := 'active_budgets';
        select count(*) into current_usage
        from public.presupuestos
        where usuario_id = current_user_id
          and fecha_fin >= current_date
          and (excluded_id is null or id::text <> excluded_id);
      when 'metas_ahorro' then
        if new.estado <> 'activa' then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.estado = 'activa' then
            return new;
          end if;
        end if;
        resource_name := 'active_goals';
        select count(*) into current_usage
        from public.metas_ahorro
        where usuario_id = current_user_id
          and estado = 'activa'
          and (excluded_id is null or id::text <> excluded_id);
      when 'movimientos_recurrentes' then
        if not new.activo then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.activo then
            return new;
          end if;
        end if;
        resource_name := 'active_recurring';
        select count(*) into current_usage
        from public.movimientos_recurrentes
        where usuario_id = current_user_id
          and activo
          and (excluded_id is null or id::text <> excluded_id);
      else
        raise exception 'Unsupported plan-limited table';
    end case;

    resource_limit := public.get_plan_resource_limit(
      public.get_my_plan(),
      resource_name
    );
  end if;

  if resource_limit is not null and current_usage >= resource_limit then
    raise exception 'PLAN_LIMIT_REACHED:%', resource_name
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_plan_resource_limit()
  from public, anon, authenticated;

drop trigger if exists enforce_plan_limit_tasks on public.tareas;
create trigger enforce_plan_limit_tasks
  before insert on public.tareas
  for each row execute function public.enforce_plan_resource_limit();

drop trigger if exists enforce_plan_limit_transactions on public.movimientos;
create trigger enforce_plan_limit_transactions
  before insert on public.movimientos
  for each row execute function public.enforce_plan_resource_limit();

drop trigger if exists enforce_plan_limit_budgets on public.presupuestos;
create trigger enforce_plan_limit_budgets
  before insert or update on public.presupuestos
  for each row execute function public.enforce_plan_resource_limit();

drop trigger if exists enforce_plan_limit_goals on public.metas_ahorro;
create trigger enforce_plan_limit_goals
  before insert or update on public.metas_ahorro
  for each row execute function public.enforce_plan_resource_limit();

drop trigger if exists enforce_plan_limit_recurring on public.movimientos_recurrentes;
create trigger enforce_plan_limit_recurring
  before insert or update on public.movimientos_recurrentes
  for each row execute function public.enforce_plan_resource_limit();

drop trigger if exists enforce_plan_limit_receipts on storage.objects;
create trigger enforce_plan_limit_receipts
  before insert or update on storage.objects
  for each row execute function public.enforce_plan_resource_limit();
