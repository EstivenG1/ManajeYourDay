drop index if exists public.billing_subscriptions_one_premium_trial;
drop index if exists public.billing_subscriptions_one_premium_trial_per_user;

create unique index billing_subscriptions_one_premium_trial_per_user
  on public.billing_subscriptions (user_id)
  where trial_days = 7
    and trial_started_at is not null;
