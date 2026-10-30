create table if not exists public.developer_plan_overrides (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null check (plan in ('free', 'standard', 'premium')),
  expires_at timestamptz,
  note text,
  updated_at timestamptz not null default now()
);

comment on table public.developer_plan_overrides is
  'Admin-managed plan overrides for developer testing. Never writable by app users.';

alter table public.developer_plan_overrides enable row level security;

revoke all on table public.developer_plan_overrides
  from public, anon, authenticated;
grant all on table public.developer_plan_overrides to service_role;

create or replace function public.get_my_plan()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select override.plan
      from public.developer_plan_overrides as override
      where override.user_id = (select auth.uid())
        and (
          override.expires_at is null
          or override.expires_at > statement_timestamp()
        )
      limit 1
    ),
    'free'
  );
$$;

revoke all on function public.get_my_plan() from public, anon, authenticated;
grant execute on function public.get_my_plan() to authenticated;
