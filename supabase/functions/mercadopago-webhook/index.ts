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
  next_payment_date?: unknown;
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function parseSignature(value: string): { timestamp: string; v1: string } | null {
  const fields: Record<string, string> = {};
  for (const part of value.split(",")) {
    const separator = part.indexOf("=");
    if (separator < 0) continue;
    fields[part.slice(0, separator).trim()] = part.slice(separator + 1).trim();
  }
  const timestamp = fields.ts;
  const v1 = fields.v1;
  return timestamp && v1 ? { timestamp, v1 } : null;
}

function bytesToHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

async function signatureMatches(
  secret: string,
  signature: string,
  requestId: string,
  dataId: string,
): Promise<boolean> {
  const parsed = parseSignature(signature);
  if (!parsed || !/^[a-f0-9]{64}$/i.test(parsed.v1)) return false;
  const manifest =
    `id:${dataId};request-id:${requestId};ts:${parsed.timestamp};`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = bytesToHex(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(manifest)),
  );
  let difference = digest.length ^ parsed.v1.length;
  for (let index = 0; index < Math.min(digest.length, parsed.v1.length); index++) {
    difference |= digest.charCodeAt(index) ^ parsed.v1.toLowerCase().charCodeAt(index);
  }
  return difference === 0;
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
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accessToken = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
  const webhookSecret = Deno.env.get("MERCADOPAGO_WEBHOOK_SECRET");
  if (!url || !serviceRoleKey || !accessToken || !webhookSecret) {
    console.error("mercadopago-webhook: required server configuration is missing");
    return jsonResponse({ error: "Webhook is not configured" }, 503);
  }

  const requestUrl = new URL(request.url);
  const dataId = requestUrl.searchParams.get("data.id");
  const signature = request.headers.get("x-signature");
  const requestId = request.headers.get("x-request-id");
  if (!dataId || !signature || !requestId) {
    return jsonResponse({ error: "Invalid webhook headers" }, 400);
  }

  let isAuthentic: boolean;
  try {
    isAuthentic = await signatureMatches(
      webhookSecret,
      signature,
      requestId,
      dataId,
    );
  } catch (error) {
    console.error("mercadopago-webhook: signature validation failed", {
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not validate webhook" }, 500);
  }
  if (!isAuthentic) return jsonResponse({ error: "Invalid signature" }, 401);

  let notification: { type?: unknown; action?: unknown };
  try {
    notification = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid webhook body" }, 400);
  }
  if (
    notification.type !== "subscription_preapproval" &&
    notification.action !== "subscription_preapproval"
  ) {
    return jsonResponse({ received: true }, 200);
  }

  let providerResponse: Response;
  try {
    providerResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${encodeURIComponent(dataId)}`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("mercadopago-webhook: provider lookup failed", {
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502);
  }
  if (!providerResponse.ok) {
    console.error("mercadopago-webhook: provider lookup rejected", {
      status: providerResponse.status,
    });
    return jsonResponse({ error: "Could not verify subscription" }, 502);
  }

  let subscription: ProviderSubscription;
  try {
    subscription = await providerResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid provider response" }, 502);
  }

  const status = providerStatus(subscription.status);
  const externalReference = subscription.external_reference;
  const providerId = subscription.id;
  const recurring = subscription.auto_recurring;
  if (
    !status ||
    typeof externalReference !== "string" ||
    typeof providerId !== "string" ||
    providerId !== dataId ||
    typeof recurring?.frequency !== "number" ||
    recurring.frequency_type !== "months" ||
    typeof recurring?.transaction_amount !== "number" ||
    recurring.currency_id !== "COP"
  ) {
    console.error("mercadopago-webhook: provider subscription data is invalid", {
      providerId: typeof providerId === "string" ? providerId : null,
    });
    return jsonResponse({ error: "Invalid subscription data" }, 422);
  }

  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: current, error: lookupError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, provider_subscription_id, amount_cop, billing_period, current_period_end",
    )
    .eq("external_reference", externalReference)
    .maybeSingle();
  if (lookupError) {
    console.error("mercadopago-webhook: could not find local subscription", {
      error: lookupError.message,
    });
    return jsonResponse({ error: "Could not reconcile subscription" }, 500);
  }
  if (!current) return jsonResponse({ received: true }, 200);
  if (
    current.amount_cop !== recurring.transaction_amount ||
    recurring.frequency !== (current.billing_period === "annual" ? 12 : 1) ||
    (current.provider_subscription_id !== null &&
      current.provider_subscription_id !== providerId)
  ) {
    console.error("mercadopago-webhook: provider data does not match checkout", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Subscription does not match checkout" }, 422);
  }

  let currentPeriodEnd = current.current_period_end as string | null;
  if (typeof subscription.next_payment_date === "string") {
    const parsedDate = new Date(subscription.next_payment_date);
    if (!Number.isFinite(parsedDate.getTime())) {
      return jsonResponse({ error: "Invalid subscription period" }, 422);
    }
    currentPeriodEnd = parsedDate.toISOString();
  } else if (status !== "cancelled") {
    currentPeriodEnd = null;
  }

  const { error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      provider_subscription_id: providerId,
      status,
      current_period_end: currentPeriodEnd,
    })
    .eq("id", current.id);
  if (updateError) {
    console.error("mercadopago-webhook: could not update subscription", {
      recordId: current.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not update subscription" }, 500);
  }

  return jsonResponse({ received: true }, 200);
});
