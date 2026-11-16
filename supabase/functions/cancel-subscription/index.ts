import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { BillingDatabase } from "../_shared/billing_database.ts";

type ProviderSubscription = {
  id?: unknown;
  status?: unknown;
  external_reference?: unknown;
  preapproval_plan_id?: unknown;
};

function corsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigins = (Deno.env.get("APP_ALLOWED_ORIGINS") ??
    "https://manageyourday.app,http://localhost:5000,http://127.0.0.1:5000")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  return {
    "Access-Control-Allow-Origin":
      origin && allowedOrigins.includes(origin) ? origin : allowedOrigins[0],
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
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

function isCancelled(value: unknown): boolean {
  return value === "cancelled" || value === "canceled";
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
  if (!url || !anonKey || !serviceRoleKey || !accessToken) {
    console.error("cancel-subscription: required server configuration is missing");
    return jsonResponse({ error: "Cancellation is not configured" }, 503, headers);
  }

  const userClient = createClient<BillingDatabase>(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return jsonResponse({ error: "Authentication required" }, 401, headers);
  }

  const adminClient = createClient<BillingDatabase>(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: subscription, error: lookupError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, plan, external_reference, provider_subscription_id, provider_plan_id, checkout_url, status, trial_days",
    )
    .eq("user_id", user.id)
    .in("status", ["checkout_pending", "pending", "authorized", "paused"])
    .maybeSingle();
  if (lookupError) {
    console.error("cancel-subscription: could not find local subscription", {
      userId: user.id,
      error: lookupError.message,
    });
    return jsonResponse({ error: "Could not read subscription" }, 500, headers);
  }
  if (!subscription) {
    return jsonResponse({ error: "No cancellable subscription was found" }, 404, headers);
  }
  if (!subscription.provider_subscription_id) {
    if (
      subscription.status === "checkout_pending" &&
      subscription.trial_days === 7 &&
      subscription.provider_plan_id
    ) {
      const { data: cancelled, error: cancelError } = await adminClient
        .from("billing_subscriptions")
        .update({ status: "checkout_failed", checkout_url: null })
        .eq("id", subscription.id)
        .eq("user_id", user.id)
        .eq("status", "checkout_pending")
        .select("id")
        .maybeSingle();
      if (cancelError) {
        console.error("cancel-subscription: could not close pending Premium trial", {
          recordId: subscription.id,
          error: cancelError.message,
        });
        return jsonResponse({ error: "Could not cancel pending checkout" }, 500, headers);
      }
      if (!cancelled) {
        return jsonResponse({ error: "Checkout changed while being canceled" }, 409, headers);
      }
      return jsonResponse(
        {
          plan: subscription.plan,
          status: "cancelled",
          trialDays: subscription.trial_days,
        },
        200,
        headers,
      );
    }
    return jsonResponse({ error: "Subscription is still being prepared" }, 409, headers);
  }

  let providerResponse: Response;
  try {
    providerResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${encodeURIComponent(subscription.provider_subscription_id)}`,
      {
        headers: { Authorization: "Bearer " + accessToken },
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("cancel-subscription: provider lookup failed", {
      userId: user.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502, headers);
  }
  if (!providerResponse.ok) {
    console.error("cancel-subscription: provider lookup rejected", {
      userId: user.id,
      status: providerResponse.status,
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502, headers);
  }

  let providerSubscription: ProviderSubscription;
  try {
    providerSubscription = await providerResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid provider response" }, 502, headers);
  }
  if (
    providerSubscription.id !== subscription.provider_subscription_id ||
    (subscription.provider_plan_id === null &&
      providerSubscription.external_reference !== subscription.external_reference) ||
    (subscription.provider_plan_id !== null &&
      providerSubscription.preapproval_plan_id !== subscription.provider_plan_id)
  ) {
    console.error("cancel-subscription: provider data does not match local record", {
      recordId: subscription.id,
    });
    return jsonResponse({ error: "Subscription does not match local record" }, 422, headers);
  }

  if (!isCancelled(providerSubscription.status)) {
    let cancellationResponse: Response;
    try {
      cancellationResponse = await fetch(
        `https://api.mercadopago.com/preapproval/${encodeURIComponent(subscription.provider_subscription_id)}`,
        {
          method: "PUT",
          headers: {
            Authorization: "Bearer " + accessToken,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ status: "cancelled" }),
          signal: AbortSignal.timeout(10000),
        },
      );
    } catch (error) {
      console.error("cancel-subscription: provider cancellation failed", {
        userId: user.id,
        error: error instanceof Error ? error.message : "unknown error",
      });
      return jsonResponse({ error: "Could not cancel subscription" }, 502, headers);
    }
    if (!cancellationResponse.ok) {
      console.error("cancel-subscription: provider rejected cancellation", {
        userId: user.id,
        status: cancellationResponse.status,
      });
      return jsonResponse({ error: "Could not cancel subscription" }, 502, headers);
    }

    try {
      providerSubscription = await cancellationResponse.json();
    } catch {
      return jsonResponse({ error: "Invalid cancellation response" }, 502, headers);
    }
    if (
      providerSubscription.id !== subscription.provider_subscription_id ||
      (subscription.provider_plan_id === null &&
        providerSubscription.external_reference !== subscription.external_reference) ||
      (subscription.provider_plan_id !== null &&
        providerSubscription.preapproval_plan_id !== subscription.provider_plan_id) ||
      !isCancelled(providerSubscription.status)
    ) {
      console.error("cancel-subscription: provider did not confirm cancellation", {
        recordId: subscription.id,
      });
      return jsonResponse({ error: "Cancellation was not confirmed" }, 502, headers);
    }
  }

  const { data: updated, error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      status: "cancelled",
      current_period_end: new Date().toISOString(),
    })
    .eq("id", subscription.id)
    .eq("user_id", user.id)
    .in("status", ["pending", "authorized", "paused"])
    .select("id")
    .maybeSingle();
  if (updateError) {
    console.error("cancel-subscription: could not update local subscription", {
      recordId: subscription.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not update subscription" }, 500, headers);
  }
  if (!updated) {
    const { data: current, error: currentError } = await adminClient
      .from("billing_subscriptions")
      .select("status")
      .eq("id", subscription.id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (currentError) {
      console.error("cancel-subscription: could not verify concurrent cancellation", {
        recordId: subscription.id,
        error: currentError.message,
      });
      return jsonResponse({ error: "Could not verify cancellation" }, 500, headers);
    }
    if (current?.status !== "cancelled") {
      return jsonResponse({ error: "Subscription changed while being canceled" }, 409, headers);
    }
  }

  return jsonResponse(
    {
      plan: subscription.plan,
      status: "cancelled",
      trialDays: subscription.trial_days,
    },
    200,
    headers,
  );
});
