import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isTestUpgradePromotionEnabled } from "../_shared/mercadopago_config.ts";
import type {
  BillingDatabase,
  ProviderSubscriptionStatus,
} from "../_shared/billing_database.ts";

type ProviderSubscription = {
  id?: unknown;
  status?: unknown;
  external_reference?: unknown;
  preapproval_plan_id?: unknown;
  auto_recurring?: {
    frequency?: unknown;
    frequency_type?: unknown;
    transaction_amount?: unknown;
    currency_id?: unknown;
  };
  next_payment_date?: unknown;
};

function jsonResponse(body: unknown, status: number, origin: string | null): Response {
  const headers = corsHeaders(origin);
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

function corsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigins = (Deno.env.get("APP_ALLOWED_ORIGINS") ??
    "https://manageyourday.app,http://localhost:5000,http://127.0.0.1:5000")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const allowedOrigin = origin && allowedOrigins.includes(origin)
    ? origin
    : allowedOrigins[0];
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function providerStatus(value: unknown): ProviderSubscriptionStatus | null {
  switch (value) {
    case "pending":
    case "authorized":
    case "paused":
    case "rejected":
    case "expired":
      return value;
    case "cancelled":
    case "canceled":
      return "cancelled";
    default:
      return null;
  }
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("Origin");
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders(origin),
    });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required" }, 401, origin);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accessToken = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
  const paymentEnvironment = Deno.env.get("MERCADOPAGO_ENVIRONMENT");
  const upgradePromotionSetting = Deno.env.get(
    "MERCADOPAGO_TEST_UPGRADE_PROMOTION_ENABLED",
  );
  if (!url || !anonKey || !serviceRoleKey || !accessToken) {
    console.error("sync-subscription: required server configuration is missing");
    return jsonResponse({ error: "Subscription sync is not configured" }, 503, origin);
  }
  const upgradePromotionAvailable = isTestUpgradePromotionEnabled(
    paymentEnvironment,
    upgradePromotionSetting,
  );

  const userClient = createClient<BillingDatabase>(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return jsonResponse({ error: "Authentication required" }, 401, origin);
  }

  const adminClient = createClient<BillingDatabase>(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: current, error: lookupError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, provider_subscription_id, provider_plan_id, external_reference, plan, billing_period, amount_cop, status, current_period_end, trial_days, trial_started_at",
    )
    .eq("user_id", user.id)
    .in("status", ["checkout_pending", "pending", "authorized", "paused"])
    .maybeSingle();
  if (lookupError) {
    console.error("sync-subscription: could not find local subscription", {
      userId: user.id,
      error: lookupError.message,
    });
    return jsonResponse({ error: "Could not read subscription" }, 500, origin);
  }
  if (!current) {
    return jsonResponse({ status: "none", upgradePromotionAvailable }, 200, origin);
  }
  if (!current.provider_subscription_id && !current.provider_plan_id) {
    return jsonResponse(
      { status: current.status, upgradePromotionAvailable },
      200,
      origin,
    );
  }

  let providerResponse: Response;
  try {
    const providerUrl = current.provider_subscription_id
      ? `https://api.mercadopago.com/preapproval/${encodeURIComponent(current.provider_subscription_id)}`
      : `https://api.mercadopago.com/preapproval/search?preapproval_plan_id=${encodeURIComponent(current.provider_plan_id!)}`;
    providerResponse = await fetch(providerUrl, {
      headers: { Authorization: "Bearer " + accessToken },
      signal: AbortSignal.timeout(10000),
    });
  } catch (error) {
    console.error("sync-subscription: provider lookup failed", {
      userId: user.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502, origin);
  }
  if (!providerResponse.ok) {
    console.error("sync-subscription: provider lookup rejected", {
      userId: user.id,
      status: providerResponse.status,
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502, origin);
  }

  let provider: ProviderSubscription | null;
  try {
    const responseData: unknown = await providerResponse.json();
    if (current.provider_subscription_id) {
      provider = responseData as ProviderSubscription;
    } else {
      const results = responseData &&
          typeof responseData === "object" &&
          "results" in responseData &&
          Array.isArray(responseData.results)
        ? responseData.results
        : null;
      provider = Array.isArray(results)
        ? (results[0] as ProviderSubscription | undefined) ?? null
        : null;
    }
  } catch {
    return jsonResponse({ error: "Invalid provider response" }, 502, origin);
  }
  if (!provider) {
    return jsonResponse({ status: current.status, upgradePromotionAvailable }, 200, origin);
  }
  const status = providerStatus(provider.status);
  const recurring = provider.auto_recurring;
  if (
    typeof provider.id !== "string" ||
    (current.provider_subscription_id !== null &&
      provider.id !== current.provider_subscription_id) ||
    (current.provider_plan_id === null &&
      provider.external_reference !== current.external_reference) ||
    (current.provider_plan_id !== null &&
      provider.preapproval_plan_id !== current.provider_plan_id) ||
    !status ||
    recurring?.frequency !== (current.billing_period === "annual" ? 12 : 1) ||
    recurring.frequency_type !== "months" ||
    recurring.transaction_amount !== current.amount_cop ||
    recurring.currency_id !== "COP"
  ) {
    console.error("sync-subscription: provider data does not match local checkout", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Subscription does not match checkout" }, 422, origin);
  }

  let currentPeriodEnd = current.current_period_end as string | null;
  if (status === "cancelled") {
    currentPeriodEnd = new Date().toISOString();
  } else if (typeof provider.next_payment_date === "string") {
    const parsedDate = new Date(provider.next_payment_date);
    if (!Number.isFinite(parsedDate.getTime())) {
      return jsonResponse({ error: "Invalid subscription period" }, 422, origin);
    }
    currentPeriodEnd = parsedDate.toISOString();
  } else {
    currentPeriodEnd = null;
  }

  const { error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      provider_subscription_id: provider.id,
      status,
      current_period_end: currentPeriodEnd,
      trial_started_at: current.trial_days === 7 &&
          status === "authorized" && current.trial_started_at === null
        ? new Date().toISOString()
        : current.trial_started_at,
    })
    .eq("id", current.id)
    .eq("user_id", user.id)
    .neq("status", "cancelled");
  if (updateError) {
    console.error("sync-subscription: could not update subscription", {
      recordId: current.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not update subscription" }, 500, origin);
  }

  return jsonResponse({ status, upgradePromotionAvailable }, 200, origin);
});
