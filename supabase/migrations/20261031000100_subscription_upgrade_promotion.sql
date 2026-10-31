alter table public.billing_subscriptions
  add column if not exists upgrade_discount_pending boolean not null default false,
  add column if not exists upgrade_in_progress boolean not null default false,
  add column if not exists trial_days integer not null default 0,
  add column if not exists regular_amount_cop integer;

alter table public.billing_subscriptions
  drop constraint if exists billing_subscriptions_trial_days;

alter table public.billing_subscriptions
  add constraint billing_subscriptions_trial_days
  check (trial_days = 0 or (plan = 'standard' and trial_days = 7));

alter table public.billing_subscriptions
  drop constraint if exists billing_subscriptions_catalog_price;

alter table public.billing_subscriptions
  add constraint billing_subscriptions_catalog_price check (
    (
      plan = 'standard'
      and upgrade_discount_pending = false
      and regular_amount_cop is null
      and (
        (billing_period = 'monthly' and amount_cop = 12900)
        or (billing_period = 'annual' and amount_cop = 129000)
      )
    )
    or (
      plan = 'premium'
      and upgrade_in_progress = false
      and billing_period = 'monthly'
      and (
        (
          upgrade_discount_pending = false
          and regular_amount_cop is null
          and amount_cop = 24900
        )
        or (
          upgrade_discount_pending = true
          and regular_amount_cop = 24900
          and amount_cop = 12450
        )
      )
    )
    or (
      plan = 'premium'
      and upgrade_in_progress = false
      and billing_period = 'annual'
      and (
        (
          upgrade_discount_pending = false
          and regular_amount_cop is null
          and amount_cop = 249900
        )
        or (
          upgrade_discount_pending = true
          and regular_amount_cop = 249900
          and amount_cop = 124950
        )
      )
    )
  );

create table if not exists public.billing_provider_plans (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'production')),
  billing_period text not null check (billing_period in ('monthly', 'annual')),
  trial_days integer not null check (trial_days = 7),
  provider_plan_id text not null unique,
  created_at timestamptz not null default statement_timestamp(),
  unique (environment, billing_period, trial_days)
);

alter table public.billing_provider_plans enable row level security;
revoke all on table public.billing_provider_plans from public, anon, authenticated;
grant all on table public.billing_provider_plans to service_role;
