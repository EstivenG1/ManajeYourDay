import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  isMercadoPagoEnvironment,
} from "../_shared/mercadopago_config.ts";
import type {
  BillingClient,
  BillingDatabase,
  ProviderSubscriptionStatus,
} from "../_shared/billing_database.ts";

const CATALOG = {
  standard: {
    monthly: { amount: 12900, reason: "MYD Estándar mensual" },
    annual: { amount: 129000, reason: "MYD Estándar anual" },
  },
  premium: {
    monthly: { amount: 24900, reason: "MYD Premium mensual" },
    annual: { amount: 249900, reason: "MYD Premium anual" },
  },
} as const;

type ProviderSubscription = {
  id?: unknown;
  init_point?: unknown;
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

function isTrustedCheckoutUrl(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const checkoutUrl = new URL(value);
    return checkoutUrl.protocol === "https:" &&
      (checkoutUrl.hostname === "mercadopago.com.co" ||
        checkoutUrl.hostname.endsWith(".mercadopago.com.co"));
  } catch {
    return false;
  }
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
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function jsonResponse(
  body: unknown,
  status: number,
  headers: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

function safeProviderText(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  return value
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted-email]")
    .replace(/\b(?:APP_USR|TEST)-[A-Z0-9-]+\b/gi, "[redacted-token]")
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/gi, "[redacted-id]")
    .slice(0, 240);
}

function providerErrorSummary(value: unknown): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const providerError = value as Record<string, unknown>;
  const summary: Record<string, unknown> = {};
  const error = safeProviderText(providerError.error);
  const message = safeProviderText(providerError.message);
  if (error) summary.error = error;
  if (message) summary.message = message;

  if (Array.isArray(providerError.cause)) {
    summary.causes = providerError.cause.slice(0, 5).map((cause) => {
      if (cause === null || typeof cause !== "object" || Array.isArray(cause)) {
        return {};
      }
      const item = cause as Record<string, unknown>;
      return {
        code: safeProviderText(item.code),
        description: safeProviderText(item.description),
      };
    });
  }

  return Object.keys(summary).length > 0 ? summary : null;
}

async function markCheckoutFailed(
  adminClient: BillingClient,
  checkoutId: string,
  userId: string,
): Promise<void> {
  const { error } = await adminClient
    .from("billing_subscriptions")
    .update({ status: "checkout_failed" })
    .eq("id", checkoutId);
  if (error) {
    console.error("start-subscription: could not mark checkout as failed", {
      userId,
      error: error.message,
    });
  }
}

async function createSubscriptionPlan(
  accessToken: string,
  backUrl: URL,
  reason: string,
  frequency: number,
  amount: number,
  trialDays: number,
): Promise<{ id: string; initPoint: string }> {
  const response = await fetch("https://api.mercadopago.com/preapproval_plan", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      reason,
      auto_recurring: {
        frequency,
        frequency_type: "months",
        transaction_amount: amount,
        currency_id: "COP",
        ...(trialDays === 7
          ? { free_trial: { frequency: 7, frequency_type: "days" } }
          : {}),
      },
      back_url: backUrl.toString(),
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    let providerError: Record<string, unknown> | null = null;
    try {
      providerError = providerErrorSummary(await response.json());
    } catch (error) {
      console.error("start-subscription: could not parse trial plan error", {
        error: error instanceof Error ? error.message : "unknown error",
      });
    }
    console.error("start-subscription: Mercado Pago rejected trial plan", {
      status: response.status,
      providerError,
    });
    throw new Error("Could not create subscription plan");
  }

  let providerPlan: { id?: unknown; init_point?: unknown };
  try {
    providerPlan = await response.json();
  } catch {
    throw new Error("Invalid subscription plan response");
  }
  if (
    typeof providerPlan.id !== "string" ||
    providerPlan.id.length === 0 ||
    typeof providerPlan.init_point !== "string"
  ) {
    throw new Error("Subscription plan response is missing checkout fields");
  }

  return { id: providerPlan.id, initPoint: providerPlan.init_point };
}

Deno.serve(async (request: Request) => {
  const headers = corsHeaders(request.headers.get("Origin"));
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, headers);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required" }, 401, headers);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accessToken = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
  const webUrl = Deno.env.get("MYD_WEB_URL");
  const paymentEnvironment = Deno.env.get("MERCADOPAGO_ENVIRONMENT");
  if (
    !url || !anonKey || !serviceRoleKey || !accessToken || !webUrl ||
    !paymentEnvironment
  ) {
    console.error("start-subscription: required server configuration is missing");
    return jsonResponse({ error: "Payment service is not configured" }, 503, headers);
  }
  if (!isMercadoPagoEnvironment(paymentEnvironment)) {
    console.error("start-subscription: MERCADOPAGO_ENVIRONMENT is invalid");
    return jsonResponse({ error: "Payment service is not configured" }, 503, headers);
  }

  let backUrl: URL;
  try {
    backUrl = new URL(webUrl);
  } catch {
    console.error("start-subscription: MYD_WEB_URL is invalid");
    return jsonResponse({ error: "Payment service is not configured" }, 503, headers);
  }
  backUrl.searchParams.set("subscription", "return");
  if (
    backUrl.protocol !== "https:" &&
    backUrl.hostname !== "localhost" &&
    backUrl.hostname !== "127.0.0.1"
  ) {
    console.error("start-subscription: MYD_WEB_URL must use HTTPS");
    return jsonResponse({ error: "Payment service is not configured" }, 503, headers);
  }

  const userClient = createClient<BillingDatabase>(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user?.email || !user.email_confirmed_at) {
    return jsonResponse({ error: "A verified account email is required" }, 401, headers);
  }
  let selection: {
    plan?: unknown;
    billingPeriod?: unknown;
    trialDays?: unknown;
  };
  try {
    if (Number(request.headers.get("Content-Length") ?? "0") > 2048) {
      return jsonResponse({ error: "Invalid request" }, 413, headers);
    }
    selection = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400, headers);
  }

  if (
    (selection.plan !== "standard" && selection.plan !== "premium") ||
    (selection.billingPeriod !== "monthly" && selection.billingPeriod !== "annual") ||
    (selection.trialDays !== undefined &&
      selection.trialDays !== 0 &&
      selection.trialDays !== 7)
  ) {
    return jsonResponse({ error: "Unsupported subscription option" }, 400, headers);
  }

  const plan = selection.plan;
  const billingPeriod = selection.billingPeriod;
  const trialDays = selection.trialDays === 7 ? 7 : 0;
  if (
    trialDays === 7 &&
    (plan !== "premium" || billingPeriod !== "monthly")
  ) {
    return jsonResponse({ error: "Unsupported subscription trial" }, 400, headers);
  }
  if (trialDays === 7) {
    const { data: currentPlan, error: currentPlanError } = await userClient.rpc(
      "get_my_plan",
    );
    if (currentPlanError) {
      console.error("start-subscription: could not verify trial eligibility", {
        userId: user.id,
        error: currentPlanError.message,
      });
      return jsonResponse({ error: "Could not verify trial eligibility" }, 500, headers);
    }
    if (currentPlan !== "free") {
      return jsonResponse(
        { error: "The Premium free trial is only available to Free accounts" },
        409,
        headers,
      );
    }
  }

  const offer = CATALOG[plan][billingPeriod];
  const frequency = billingPeriod === "annual" ? 12 : 1;
  const adminClient = createClient<BillingDatabase>(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: openSubscription, error: openSubscriptionError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, external_reference, provider_subscription_id, provider_plan_id, checkout_url, plan, billing_period, amount_cop, status, trial_days, created_at, current_period_end",
    )
    .eq("user_id", user.id)
    .in("status", ["checkout_pending", "pending", "authorized", "paused"])
    .maybeSingle();
  if (openSubscriptionError) {
    console.error("start-subscription: could not check existing subscription", {
      userId: user.id,
      error: openSubscriptionError.message,
    });
    return jsonResponse({ error: "Could not start checkout" }, 500, headers);
  }
  if (openSubscription) {
    if (
      openSubscription.status === "checkout_pending" &&
      openSubscription.provider_plan_id &&
      isTrustedCheckoutUrl(openSubscription.checkout_url) &&
      openSubscription.plan === plan &&
      openSubscription.billing_period === billingPeriod &&
      openSubscription.trial_days === trialDays
    ) {
      return jsonResponse(
        { checkoutUrl: openSubscription.checkout_url, trialDays },
        200,
        headers,
      );
    }
    if (
      openSubscription.status === "checkout_pending" &&
      !openSubscription.provider_subscription_id
    ) {
      const createdAt = new Date(openSubscription.created_at).getTime();
      if (!Number.isFinite(createdAt)) {
        console.error("start-subscription: existing checkout has invalid creation time", {
          recordId: openSubscription.id,
        });
        return jsonResponse({ error: "Could not start checkout" }, 500, headers);
      }
      if (Date.now() - createdAt < 5 * 60 * 1000) {
        return jsonResponse(
          { error: "Checkout is being prepared. Please try again shortly." },
          409,
          headers,
        );
      }
      const { error: expireError } = await adminClient
        .from("billing_subscriptions")
        .update({ status: "checkout_failed" })
        .eq("id", openSubscription.id)
        .eq("status", "checkout_pending");
      if (expireError) {
        console.error("start-subscription: could not expire stale checkout", {
          recordId: openSubscription.id,
          error: expireError.message,
        });
        return jsonResponse({ error: "Could not start checkout" }, 500, headers);
      }
    } else if (openSubscription.provider_subscription_id) {
      let existingResponse: Response;
      try {
        existingResponse = await fetch(
          `https://api.mercadopago.com/preapproval/${encodeURIComponent(openSubscription.provider_subscription_id)}`,
          {
            headers: { Authorization: "Bearer " + accessToken },
            signal: AbortSignal.timeout(10000),
          },
        );
      } catch (error) {
        console.error("start-subscription: could not inspect existing checkout", {
          userId: user.id,
          error: error instanceof Error ? error.message : "unknown error",
        });
        return jsonResponse({ error: "Could not verify existing checkout" }, 502, headers);
      }
      if (!existingResponse.ok) {
        console.error("start-subscription: existing checkout lookup failed", {
          userId: user.id,
          status: existingResponse.status,
        });
        return jsonResponse({ error: "Could not verify existing checkout" }, 502, headers);
      }

      let existing: ProviderSubscription;
      try {
        existing = await existingResponse.json();
      } catch {
        return jsonResponse({ error: "Invalid response from payment provider" }, 502, headers);
      }
      const existingStatus = providerStatus(existing.status);
      const recurring = existing.auto_recurring;
      if (
        existing.id !== openSubscription.provider_subscription_id ||
        existing.external_reference !== openSubscription.external_reference ||
        !existingStatus ||
        recurring?.frequency !==
          (openSubscription.billing_period === "annual" ? 12 : 1) ||
        recurring.frequency_type !== "months" ||
        recurring.transaction_amount !== openSubscription.amount_cop ||
        recurring.currency_id !== "COP"
      ) {
        console.error("start-subscription: existing checkout does not match local record", {
          recordId: openSubscription.id,
        });
        return jsonResponse({ error: "Could not verify existing checkout" }, 422, headers);
      }

      let currentPeriodEnd = openSubscription.current_period_end as string | null;
      if (existingStatus === "cancelled") {
        currentPeriodEnd = new Date().toISOString();
      } else if (typeof existing.next_payment_date === "string") {
        const parsedDate = new Date(existing.next_payment_date);
        if (!Number.isFinite(parsedDate.getTime())) {
          return jsonResponse({ error: "Invalid subscription period" }, 422, headers);
        }
        currentPeriodEnd = parsedDate.toISOString();
      } else {
        currentPeriodEnd = null;
      }
      if (existingStatus !== openSubscription.status) {
        const { error: updateError } = await adminClient
          .from("billing_subscriptions")
          .update({ status: existingStatus, current_period_end: currentPeriodEnd })
          .eq("id", openSubscription.id)
          .neq("status", "cancelled");
        if (updateError) {
          console.error("start-subscription: could not refresh existing subscription", {
            recordId: openSubscription.id,
            error: updateError.message,
          });
          return jsonResponse({ error: "Could not refresh subscription" }, 500, headers);
        }
      }

      if (existingStatus === "pending") {
        if (
          openSubscription.plan !== plan ||
          openSubscription.billing_period !== billingPeriod ||
          openSubscription.trial_days !== trialDays
        ) {
          return jsonResponse(
            { error: "Resume or resolve your existing checkout before choosing another plan" },
            409,
            headers,
          );
        }
        if (!isTrustedCheckoutUrl(existing.init_point)) {
          return jsonResponse({ error: "Invalid checkout URL from payment provider" }, 502, headers);
        }
        if (openSubscription.trial_days !== 0 && openSubscription.trial_days !== 7) {
          return jsonResponse({ error: "Invalid subscription trial" }, 422, headers);
        }
        return jsonResponse(
          { checkoutUrl: existing.init_point, trialDays: openSubscription.trial_days },
          200,
          headers,
        );
      }

      if (existingStatus === "authorized" || existingStatus === "paused") {
        return jsonResponse(
          { error: "An active subscription must be resolved before starting another" },
          409,
          headers,
        );
      }
      const { error: closeError } = await adminClient
        .from("billing_subscriptions")
        .update({ status: existingStatus, current_period_end: currentPeriodEnd })
        .eq("id", openSubscription.id);
      if (closeError) {
        console.error("start-subscription: could not close existing checkout", {
          recordId: openSubscription.id,
          error: closeError.message,
        });
        return jsonResponse({ error: "Could not start checkout" }, 500, headers);
      }
    } else {
      return jsonResponse(
        { error: "An active subscription must be resolved before starting another" },
        409,
        headers,
      );
    }
  }

  if (trialDays === 7) {
    const { data: usedTrial, error: trialLookupError } = await adminClient
      .from("billing_subscriptions")
      .select("id")
      .eq("user_id", user.id)
      .eq("plan", "premium")
      .eq("billing_period", "monthly")
      .eq("trial_days", 7)
      .in("status", ["pending", "authorized", "paused", "cancelled"])
      .limit(1)
      .maybeSingle();
    if (trialLookupError) {
      console.error("start-subscription: could not check Premium trial eligibility", {
        userId: user.id,
        error: trialLookupError.message,
      });
      return jsonResponse({ error: "Could not verify trial eligibility" }, 500, headers);
    }
    if (usedTrial) {
      return jsonResponse(
        { error: "The Premium free trial is available once per account" },
        409,
        headers,
      );
    }
  }

  const externalReference = crypto.randomUUID();
  const { data: checkout, error: insertError } = await adminClient
    .from("billing_subscriptions")
    .insert({
      user_id: user.id,
      external_reference: externalReference,
      plan,
      billing_period: billingPeriod,
      amount_cop: offer.amount,
      trial_days: trialDays,
      status: "checkout_pending",
    })
    .select("id")
    .single();
  if (insertError || !checkout) {
    if (insertError?.code === "23505") {
      return jsonResponse(
        { error: "An existing subscription must be resolved before starting another" },
        409,
        headers,
      );
    }
    console.error("start-subscription: could not create checkout record", {
      userId: user.id,
      error: insertError?.message,
    });
    return jsonResponse({ error: "Could not start checkout" }, 500, headers);
  }

  let providerPlan: { id: string; initPoint: string };
  try {
    providerPlan = await createSubscriptionPlan(
      accessToken,
      backUrl,
      offer.reason,
      frequency,
      offer.amount,
      trialDays,
    );
  } catch (error) {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    console.error("start-subscription: could not create Mercado Pago plan", {
      userId: user.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not prepare payment checkout" }, 502, headers);
  }

  const checkoutUrl = providerPlan.initPoint;
  let parsedCheckoutUrl: URL;
  try {
    parsedCheckoutUrl = new URL(checkoutUrl);
  } catch {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    return jsonResponse({ error: "Invalid checkout URL from payment provider" }, 502, headers);
  }
  if (
    parsedCheckoutUrl.protocol !== "https:" ||
    (parsedCheckoutUrl.hostname !== "mercadopago.com.co" &&
      !parsedCheckoutUrl.hostname.endsWith(".mercadopago.com.co"))
  ) {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    console.error("start-subscription: unexpected Mercado Pago checkout host", {
      host: parsedCheckoutUrl.hostname,
    });
    return jsonResponse({ error: "Invalid checkout URL from payment provider" }, 502, headers);
  }

  const { data: persisted, error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      provider_plan_id: providerPlan.id,
      checkout_url: checkoutUrl,
    })
    .eq("id", checkout.id)
    .eq("status", "checkout_pending")
    .select("id")
    .maybeSingle();
  if (updateError) {
    console.error("start-subscription: could not persist provider plan", {
      userId: user.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not prepare payment checkout" }, 500, headers);
  }
  if (!persisted) {
    const { data: concurrentUpdate, error: concurrentLookupError } = await adminClient
      .from("billing_subscriptions")
      .select("provider_plan_id, checkout_url, status")
      .eq("id", checkout.id)
      .maybeSingle();
    if (
      concurrentLookupError ||
      !concurrentUpdate ||
      concurrentUpdate.provider_plan_id !== providerPlan.id ||
      concurrentUpdate.checkout_url !== checkoutUrl ||
      concurrentUpdate.status !== "checkout_pending"
    ) {
      console.error("start-subscription: checkout changed before it could be saved", {
        userId: user.id,
        recordId: checkout.id,
        error: concurrentLookupError?.message,
      });
      return jsonResponse({ error: "Could not prepare payment checkout" }, 409, headers);
    }
  }

  return jsonResponse({ checkoutUrl, trialDays }, 200, headers);
});
