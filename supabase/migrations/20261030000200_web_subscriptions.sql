create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  external_reference uuid not null unique,
  provider_subscription_id text unique,
  plan text not null check (plan in ('standard', 'premium')),
  billing_period text not null check (billing_period in ('monthly', 'annual')),
  amount_cop integer not null,
  currency text not null default 'COP' check (currency = 'COP'),
  status text not null check (
    status in (
      'checkout_pending',
      'pending',
      'authorized',
      'paused',
      'cancelled',
      'rejected',
      'expired',
      'checkout_failed'
    )
  ),
  current_period_end timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint billing_subscriptions_catalog_price check (
    (plan = 'standard' and billing_period = 'monthly' and amount_cop = 12900)
    or (plan = 'standard' and billing_period = 'annual' and amount_cop = 129000)
    or (plan = 'premium' and billing_period = 'monthly' and amount_cop = 24900)
    or (plan = 'premium' and billing_period = 'annual' and amount_cop = 249900)
  )
);

comment on table public.billing_subscriptions is
  'Mercado Pago web subscription records; only trusted server functions may write.';

alter table public.billing_subscriptions enable row level security;
revoke all on table public.billing_subscriptions from public, anon, authenticated;
grant select on table public.billing_subscriptions to authenticated;
grant all on table public.billing_subscriptions to service_role;

create policy "Users can read their own billing subscriptions"
  on public.billing_subscriptions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create unique index if not exists billing_subscriptions_one_open_per_user
  on public.billing_subscriptions (user_id)
  where status in ('checkout_pending', 'pending', 'authorized', 'paused');

create index if not exists billing_subscriptions_plan_lookup
  on public.billing_subscriptions (user_id, status, current_period_end desc);

create or replace function public.set_billing_subscription_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

revoke all on function public.set_billing_subscription_updated_at()
  from public, anon, authenticated;

drop trigger if exists set_billing_subscription_updated_at
  on public.billing_subscriptions;
create trigger set_billing_subscription_updated_at
  before update on public.billing_subscriptions
  for each row execute function public.set_billing_subscription_updated_at();

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
    (
      select subscription.plan
      from public.billing_subscriptions as subscription
      where subscription.user_id = (select auth.uid())
        and (
          subscription.status = 'authorized'
          or (
            subscription.status = 'cancelled'
            and subscription.current_period_end > statement_timestamp()
          )
        )
        and (
          subscription.current_period_end is null
          or subscription.current_period_end > statement_timestamp()
        )
      order by subscription.current_period_end desc nulls first
      limit 1
    ),
    'free'
  );
$$;

revoke all on function public.get_my_plan() from public, anon, authenticated;
grant execute on function public.get_my_plan() to authenticated;
