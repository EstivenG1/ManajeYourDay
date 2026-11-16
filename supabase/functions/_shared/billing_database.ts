import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type BillingPlan = "standard" | "premium";
export type BillingSubscriptionStatus =
  | "checkout_pending"
  | "pending"
  | "authorized"
  | "paused"
  | "cancelled"
  | "rejected"
  | "expired"
  | "checkout_failed";
export type ProviderSubscriptionStatus = Exclude<
  BillingSubscriptionStatus,
  "checkout_pending" | "checkout_failed"
>;

type BillingSubscriptionRow = {
  id: string;
  user_id: string;
  external_reference: string;
  provider_subscription_id: string | null;
  provider_plan_id: string | null;
  checkout_url: string | null;
  plan: BillingPlan;
  billing_period: "monthly" | "annual";
  amount_cop: number;
  currency: string;
  status: BillingSubscriptionStatus;
  current_period_end: string | null;
  created_at: string;
  updated_at: string;
  upgrade_discount_pending: boolean;
  upgrade_in_progress: boolean;
  trial_days: number;
  regular_amount_cop: number | null;
  trial_started_at: string | null;
};

export type BillingDatabase = {
  __InternalSupabase?: {
    PostgrestVersion: string;
  };
  public: {
    Tables: {
      billing_subscriptions: {
        Row: BillingSubscriptionRow;
        Insert: Omit<
          BillingSubscriptionRow,
          | "id"
          | "provider_subscription_id"
          | "provider_plan_id"
          | "checkout_url"
          | "currency"
          | "current_period_end"
          | "created_at"
          | "updated_at"
          | "upgrade_discount_pending"
          | "upgrade_in_progress"
          | "trial_days"
          | "regular_amount_cop"
          | "trial_started_at"
        > &
          Partial<
            Pick<
              BillingSubscriptionRow,
              | "id"
              | "provider_subscription_id"
              | "provider_plan_id"
              | "checkout_url"
              | "currency"
              | "current_period_end"
              | "created_at"
              | "updated_at"
              | "upgrade_discount_pending"
              | "upgrade_in_progress"
              | "trial_days"
              | "regular_amount_cop"
              | "trial_started_at"
            >
          >;
        Update: Partial<BillingSubscriptionRow>;
        Relationships: [];
      };
    };
    Views: { [_ in never]: never };
    Functions: {
      get_my_plan: {
        Args: Record<PropertyKey, never>;
        Returns: "free" | BillingPlan;
      };
    };
    Enums: { [_ in never]: never };
    CompositeTypes: { [_ in never]: never };
  };
};

export type BillingClient = SupabaseClient<BillingDatabase>;
