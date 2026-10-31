import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ProviderSubscription = {
  id?: unknown;
  status?: unknown;
  external_reference?: unknown;
  auto_recurring?: {
    frequency?: unknown;
    frequency_type?: unknown;
    transaction_amount?: unknown;
    currency_id?: unknown;
  };
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

function providerStatus(value: unknown): string | null {
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
  if (!url || !anonKey || !serviceRoleKey || !accessToken) {
    console.error("upgrade-subscription: required server configuration is missing");
    return jsonResponse({ error: "Upgrade is not configured" }, 503, origin);
  }
  if (paymentEnvironment !== "test") {
    return jsonResponse(
      { error: "The upgrade promotion is available only in the test environment" },
      403,
      origin,
    );
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return jsonResponse({ error: "Authentication required" }, 401, origin);
  }

  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: current, error: lookupError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, provider_subscription_id, external_reference, plan, billing_period, amount_cop, status, current_period_end, upgrade_discount_pending, upgrade_in_progress, regular_amount_cop",
    )
    .eq("user_id", user.id)
    .in("status", ["authorized", "paused"])
    .maybeSingle();
  if (lookupError) {
    console.error("upgrade-subscription: could not read current subscription", {
      userId: user.id,
      error: lookupError.message,
    });
    return jsonResponse({ error: "Could not read current subscription" }, 500, origin);
  }
  const periodEnd = current?.current_period_end === null
    ? null
    : new Date(current?.current_period_end).getTime();
  if (
    !current ||
    current.plan !== "standard" ||
    current.status !== "authorized" ||
    !current.provider_subscription_id ||
    (periodEnd !== null &&
      (!Number.isFinite(periodEnd) || periodEnd <= Date.now()))
  ) {
    return jsonResponse(
      { error: "An active Standard subscription is required for this offer" },
      409,
      origin,
    );
  }

  const regularAmount = current.billing_period === "monthly"
    ? 24900
    : current.billing_period === "annual"
    ? 249900
    : null;
  if (!regularAmount) {
    console.error("upgrade-subscription: subscription has unsupported billing period", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Unsupported billing period" }, 422, origin);
  }
  const discountedAmount = regularAmount / 2;
  if (!Number.isInteger(discountedAmount) || current.upgrade_discount_pending) {
    return jsonResponse({ error: "Upgrade promotion is already in progress" }, 409, origin);
  }

  let providerResponse: Response;
  try {
    providerResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${encodeURIComponent(current.provider_subscription_id)}`,
      {
        headers: { Authorization: "Bearer " + accessToken },
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("upgrade-subscription: provider lookup failed", {
      userId: user.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify current subscription" }, 502, origin);
  }
  if (!providerResponse.ok) {
    console.error("upgrade-subscription: provider lookup rejected", {
      userId: user.id,
      status: providerResponse.status,
    });
    return jsonResponse({ error: "Could not verify current subscription" }, 502, origin);
  }

  let provider: ProviderSubscription;
  try {
    provider = await providerResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid provider response" }, 502, origin);
  }
  const recurring = provider.auto_recurring;
  if (
    provider.id !== current.provider_subscription_id ||
    provider.external_reference !== current.external_reference ||
    providerStatus(provider.status) !== "authorized" ||
    recurring?.frequency !== (current.billing_period === "annual" ? 12 : 1) ||
    recurring.frequency_type !== "months" ||
    (recurring.transaction_amount !== current.amount_cop &&
      !(current.upgrade_in_progress &&
        recurring.transaction_amount === discountedAmount)) ||
    recurring.currency_id !== "COP"
  ) {
    console.error("upgrade-subscription: provider subscription does not match local data", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Could not verify current subscription" }, 422, origin);
  }

  if (current.upgrade_in_progress) {
    if (recurring.transaction_amount === discountedAmount) {
      const { error: finalizeError } = await finalizeUpgrade(
        adminClient,
        current.id,
        user.id,
        discountedAmount,
        regularAmount,
      );
      if (finalizeError) {
        console.error("upgrade-subscription: could not finalize reserved upgrade", {
          recordId: current.id,
          error: finalizeError.message,
        });
        return jsonResponse({ error: "Could not finalize upgrade" }, 500, origin);
      }
      return jsonResponse({
        plan: "premium",
        billingPeriod: current.billing_period,
        nextAmountCop: discountedAmount,
        regularAmountCop: regularAmount,
      }, 200, origin);
    }

    const { error: releaseError } = await adminClient
      .from("billing_subscriptions")
      .update({ upgrade_in_progress: false })
      .eq("id", current.id)
      .eq("upgrade_in_progress", true);
    if (releaseError) {
      console.error("upgrade-subscription: could not release stale reservation", {
        recordId: current.id,
        error: releaseError.message,
      });
      return jsonResponse({ error: "Could not prepare upgrade" }, 500, origin);
    }
  } else if (current.regular_amount_cop !== null) {
    return jsonResponse({ error: "Upgrade promotion is already in progress" }, 409, origin);
  }

  const { data: reserved, error: reserveError } = await adminClient
    .from("billing_subscriptions")
    .update({ upgrade_in_progress: true })
    .eq("id", current.id)
    .eq("user_id", user.id)
    .eq("plan", "standard")
    .eq("status", "authorized")
    .eq("upgrade_discount_pending", false)
    .eq("upgrade_in_progress", false)
    .select("id")
    .maybeSingle();
  if (reserveError) {
    console.error("upgrade-subscription: could not reserve promotion", {
      recordId: current.id,
      error: reserveError.message,
    });
    return jsonResponse({ error: "Could not prepare upgrade" }, 500, origin);
  }
  if (!reserved) {
    return jsonResponse({ error: "Upgrade promotion is already in progress" }, 409, origin);
  }

  let updateResponse: Response;
  try {
    updateResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${encodeURIComponent(current.provider_subscription_id)}`,
      {
        method: "PUT",
        headers: {
          Authorization: "Bearer " + accessToken,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          auto_recurring: {
            transaction_amount: discountedAmount,
            currency_id: "COP",
          },
        }),
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("upgrade-subscription: provider update failed", {
      recordId: current.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not update payment amount" }, 502, origin);
  }
  if (!updateResponse.ok) {
    console.error("upgrade-subscription: provider update rejected", {
      recordId: current.id,
      status: updateResponse.status,
    });
    await releaseReservation(adminClient, current.id, user.id);
    return jsonResponse({ error: "Could not update payment amount" }, 502, origin);
  }

  let updatedProvider: ProviderSubscription;
  try {
    updatedProvider = await updateResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid provider response" }, 502, origin);
  }
  if (
    updatedProvider.id !== current.provider_subscription_id ||
    updatedProvider.external_reference !== current.external_reference ||
    updatedProvider.auto_recurring?.transaction_amount !== discountedAmount ||
    updatedProvider.auto_recurring.currency_id !== "COP"
  ) {
    console.error("upgrade-subscription: provider did not confirm discounted amount", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Could not verify updated payment amount" }, 502, origin);
  }

  const { error: finalizeError } = await finalizeUpgrade(
    adminClient,
    current.id,
    user.id,
    discountedAmount,
    regularAmount,
  );
  if (finalizeError) {
    console.error("upgrade-subscription: provider updated but local upgrade is pending reconciliation", {
      recordId: current.id,
      error: finalizeError.message,
    });
    return jsonResponse({ error: "Could not finalize upgrade" }, 500, origin);
  }

  return jsonResponse({
    plan: "premium",
    billingPeriod: current.billing_period,
    nextAmountCop: discountedAmount,
    regularAmountCop: regularAmount,
  }, 200, origin);
});

async function finalizeUpgrade(
  adminClient: ReturnType<typeof createClient>,
  subscriptionId: string,
  userId: string,
  discountedAmount: number,
  regularAmount: number,
): Promise<{ error: Error | null }> {
  const { error, data } = await adminClient
    .from("billing_subscriptions")
    .update({
      plan: "premium",
      amount_cop: discountedAmount,
      regular_amount_cop: regularAmount,
      upgrade_discount_pending: true,
      upgrade_in_progress: false,
    })
    .eq("id", subscriptionId)
    .eq("user_id", userId)
    .eq("plan", "standard")
    .eq("upgrade_in_progress", true)
    .select("id")
    .maybeSingle();
  if (error) {
    return { error };
  }
  if (!data) {
    const { data: existing, error: lookupError } = await adminClient
      .from("billing_subscriptions")
      .select("id")
      .eq("id", subscriptionId)
      .eq("user_id", userId)
      .eq("plan", "premium")
      .eq("upgrade_discount_pending", true)
      .maybeSingle();
    if (lookupError) return { error: lookupError };
    if (!existing) {
      return { error: new Error("Upgrade reservation is no longer available.") };
    }
  }
  return { error: null };
}

async function releaseReservation(
  adminClient: ReturnType<typeof createClient>,
  subscriptionId: string,
  userId: string,
): Promise<void> {
  const { error } = await adminClient
    .from("billing_subscriptions")
    .update({ upgrade_in_progress: false })
    .eq("id", subscriptionId)
    .eq("user_id", userId)
    .eq("upgrade_in_progress", true);
  if (error) {
    console.error("upgrade-subscription: failed to release promotion reservation", {
      recordId: subscriptionId,
      error: error.message,
    });
  }
}
