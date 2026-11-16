update public.billing_subscriptions
set trial_days = 0
where plan = 'standard'
  and trial_days = 7
  and status = 'checkout_failed'
  and provider_subscription_id is null;

alter table public.billing_subscriptions
  add column if not exists provider_plan_id text unique,
  add column if not exists checkout_url text,
  add column if not exists trial_started_at timestamptz;

alter table public.billing_subscriptions
  drop constraint if exists billing_subscriptions_trial_days;

alter table public.billing_subscriptions
  add constraint billing_subscriptions_trial_days
  check (
    trial_days = 0
    or (plan = 'premium' and billing_period = 'monthly' and trial_days = 7)
  );

create unique index if not exists billing_subscriptions_one_premium_trial_per_user
  on public.billing_subscriptions (user_id)
  where trial_days = 7
    and status in ('pending', 'authorized', 'paused', 'cancelled');
