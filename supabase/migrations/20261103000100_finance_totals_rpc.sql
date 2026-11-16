create or replace function public.get_my_finance_totals()
returns table (income_total numeric, expense_total numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    coalesce(
      sum(movement.monto) filter (where movement.tipo = 'ingreso'),
      0
    )::numeric,
    coalesce(
      sum(movement.monto) filter (
        where movement.tipo is distinct from 'ingreso'
      ),
      0
    )::numeric
  from public.movimientos as movement
  where movement.usuario_id = (select auth.uid());
$$;

revoke all on function public.get_my_finance_totals() from public, anon;
grant execute on function public.get_my_finance_totals() to authenticated;

create or replace function public.get_my_budget_spending()
returns table (budget_id text, spent_amount numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    budget.id::text,
    coalesce(sum(movement.monto), 0)::numeric
  from public.presupuestos as budget
  left join public.movimientos as movement
    on movement.usuario_id = budget.usuario_id
    and movement.categoria_id = budget.categoria_id
    and movement.tipo = 'gasto'
    and movement.fecha between budget.fecha_inicio and budget.fecha_fin
  where budget.usuario_id = (select auth.uid())
  group by budget.id;
$$;

revoke all on function public.get_my_budget_spending() from public, anon;
grant execute on function public.get_my_budget_spending() to authenticated;
