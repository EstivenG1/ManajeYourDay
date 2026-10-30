import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
  adminClient: ReturnType<typeof createClient>,
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
  if (!url || !anonKey || !serviceRoleKey || !accessToken || !webUrl) {
    console.error("start-subscription: required server configuration is missing");
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

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user?.email || !user.email_confirmed_at) {
    return jsonResponse({ error: "A verified account email is required" }, 401, headers);
  }

  let selection: { plan?: unknown; billingPeriod?: unknown };
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
    (selection.billingPeriod !== "monthly" && selection.billingPeriod !== "annual")
  ) {
    return jsonResponse({ error: "Unsupported subscription option" }, 400, headers);
  }

  const plan = selection.plan;
  const billingPeriod = selection.billingPeriod;
  const offer = CATALOG[plan][billingPeriod];
  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: openSubscription, error: openSubscriptionError } = await adminClient
    .from("billing_subscriptions")
    .select("id")
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
    return jsonResponse(
      { error: "An existing subscription must be resolved before starting another" },
      409,
      headers,
    );
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

  const frequency = billingPeriod === "annual" ? 12 : 1;
  let providerResponse: Response;
  try {
    providerResponse = await fetch("https://api.mercadopago.com/preapproval", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        reason: offer.reason,
        external_reference: externalReference,
        payer_email: user.email,
        auto_recurring: {
          frequency,
          frequency_type: "months",
          transaction_amount: offer.amount,
          currency_id: "COP",
        },
        back_url: backUrl.toString(),
        status: "pending",
      }),
      signal: AbortSignal.timeout(15000),
    });
  } catch (error) {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    console.error("start-subscription: Mercado Pago request failed", {
      userId: user.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not contact the payment provider" }, 502, headers);
  }

  if (!providerResponse.ok) {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    let providerError: Record<string, unknown> | null = null;
    try {
      providerError = providerErrorSummary(await providerResponse.json());
    } catch (error) {
      console.error("start-subscription: could not parse Mercado Pago error response", {
        userId: user.id,
        error: error instanceof Error ? error.message : "unknown error",
      });
    }
    console.error("start-subscription: Mercado Pago rejected checkout", {
      userId: user.id,
      status: providerResponse.status,
      providerError,
    });
    return jsonResponse({ error: "Could not create payment checkout" }, 502, headers);
  }

  let providerSubscription: { id?: unknown; init_point?: unknown };
  try {
    providerSubscription = await providerResponse.json();
  } catch {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    console.error("start-subscription: Mercado Pago returned invalid JSON", {
      userId: user.id,
    });
    return jsonResponse({ error: "Invalid response from payment provider" }, 502, headers);
  }
  const providerId = providerSubscription.id;
  const checkoutUrl = providerSubscription.init_point;
  if (typeof providerId !== "string" || typeof checkoutUrl !== "string") {
    await markCheckoutFailed(adminClient, checkout.id, user.id);
    console.error("start-subscription: Mercado Pago response is missing checkout fields", {
      userId: user.id,
    });
    return jsonResponse({ error: "Invalid response from payment provider" }, 502, headers);
  }

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

  const { error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      provider_subscription_id: providerId,
      status: "pending",
    })
    .eq("id", checkout.id);
  if (updateError) {
    console.error("start-subscription: could not persist provider subscription", {
      userId: user.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not prepare payment checkout" }, 500, headers);
  }

  return jsonResponse({ checkoutUrl }, 200, headers);
});
