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

type AuthorizedPayment = {
  preapproval_id?: unknown;
  transaction_amount?: unknown;
  payment?: {
    status?: unknown;
  };
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

async function finalizeUpgradeDiscount(
  adminClient: ReturnType<typeof createClient>,
  accessToken: string,
  paymentId: string,
): Promise<Response> {
  let paymentResponse: Response;
  try {
    paymentResponse = await fetch(
      `https://api.mercadopago.com/authorized_payments/${encodeURIComponent(paymentId)}`,
      {
        headers: { Authorization: "Bearer " + accessToken },
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("mercadopago-webhook: authorized payment lookup failed", {
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify authorized payment" }, 502);
  }
  if (!paymentResponse.ok) {
    console.error("mercadopago-webhook: authorized payment lookup rejected", {
      status: paymentResponse.status,
    });
    return jsonResponse({ error: "Could not verify authorized payment" }, 502);
  }

  let payment: AuthorizedPayment;
  try {
    payment = await paymentResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid authorized payment response" }, 502);
  }
  if (payment.payment?.status !== "approved") {
    return jsonResponse({ received: true }, 200);
  }
  if (typeof payment.preapproval_id !== "string") {
    return jsonResponse({ error: "Invalid authorized payment data" }, 422);
  }
  const paidAmount = typeof payment.transaction_amount === "number"
    ? payment.transaction_amount
    : typeof payment.transaction_amount === "string"
    ? Number(payment.transaction_amount)
    : NaN;
  if (!Number.isSafeInteger(paidAmount)) {
    return jsonResponse({ error: "Invalid authorized payment amount" }, 422);
  }

  const { data: current, error: lookupError } = await adminClient
    .from("billing_subscriptions")
    .select(
      "id, provider_subscription_id, external_reference, billing_period, amount_cop, regular_amount_cop, upgrade_discount_pending",
    )
    .eq("provider_subscription_id", payment.preapproval_id)
    .eq("upgrade_discount_pending", true)
    .maybeSingle();
  if (lookupError) {
    console.error("mercadopago-webhook: could not find upgrade promotion", {
      error: lookupError.message,
    });
    return jsonResponse({ error: "Could not reconcile upgrade payment" }, 500);
  }
  if (!current) return jsonResponse({ received: true }, 200);
  if (
    current.regular_amount_cop === null ||
    paidAmount !== current.amount_cop ||
    current.provider_subscription_id !== payment.preapproval_id
  ) {
    console.error("mercadopago-webhook: payment does not match pending upgrade discount", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Payment does not match upgrade discount" }, 422);
  }

  let subscriptionResponse: Response;
  try {
    subscriptionResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${encodeURIComponent(current.provider_subscription_id)}`,
      {
        headers: { Authorization: "Bearer " + accessToken },
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("mercadopago-webhook: upgrade subscription lookup failed", {
      recordId: current.id,
      error: error instanceof Error ? error.message : "unknown error",
    });
    return jsonResponse({ error: "Could not verify upgraded subscription" }, 502);
  }
  if (!subscriptionResponse.ok) {
    console.error("mercadopago-webhook: upgrade subscription lookup rejected", {
      recordId: current.id,
      status: subscriptionResponse.status,
    });
    return jsonResponse({ error: "Could not verify upgraded subscription" }, 502);
  }

  let subscription: ProviderSubscription;
  try {
    subscription = await subscriptionResponse.json();
  } catch {
    return jsonResponse({ error: "Invalid upgraded subscription response" }, 502);
  }
  const recurring = subscription.auto_recurring;
  if (
    subscription.id !== current.provider_subscription_id ||
    subscription.external_reference !== current.external_reference ||
    providerStatus(subscription.status) !== "authorized" ||
    recurring?.currency_id !== "COP" ||
    (recurring.transaction_amount !== current.amount_cop &&
      recurring.transaction_amount !== current.regular_amount_cop)
  ) {
    console.error("mercadopago-webhook: upgraded subscription does not match local data", {
      recordId: current.id,
    });
    return jsonResponse({ error: "Upgraded subscription does not match" }, 422);
  }

  if (recurring.transaction_amount !== current.regular_amount_cop) {
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
              transaction_amount: current.regular_amount_cop,
              currency_id: "COP",
            },
          }),
          signal: AbortSignal.timeout(10000),
        },
      );
    } catch (error) {
      console.error("mercadopago-webhook: could not restore regular Premium price", {
        recordId: current.id,
        error: error instanceof Error ? error.message : "unknown error",
      });
      return jsonResponse({ error: "Could not restore regular subscription price" }, 502);
    }
    if (!updateResponse.ok) {
      console.error("mercadopago-webhook: regular Premium price update rejected", {
        recordId: current.id,
        status: updateResponse.status,
      });
      return jsonResponse({ error: "Could not restore regular subscription price" }, 502);
    }

    let updatedSubscription: ProviderSubscription;
    try {
      updatedSubscription = await updateResponse.json();
    } catch {
      return jsonResponse({ error: "Invalid updated subscription response" }, 502);
    }
    if (
      updatedSubscription.id !== current.provider_subscription_id ||
      updatedSubscription.auto_recurring?.transaction_amount !==
        current.regular_amount_cop ||
      updatedSubscription.auto_recurring.currency_id !== "COP"
    ) {
      console.error("mercadopago-webhook: regular Premium price was not confirmed", {
        recordId: current.id,
      });
      return jsonResponse({ error: "Could not verify regular subscription price" }, 502);
    }
  }

  const { error: updateError } = await adminClient
    .from("billing_subscriptions")
    .update({
      amount_cop: current.regular_amount_cop,
      regular_amount_cop: null,
      upgrade_discount_pending: false,
    })
    .eq("id", current.id)
    .eq("upgrade_discount_pending", true)
    .eq("amount_cop", current.amount_cop);
  if (updateError) {
    console.error("mercadopago-webhook: could not finalize upgrade promotion", {
      recordId: current.id,
      error: updateError.message,
    });
    return jsonResponse({ error: "Could not finalize upgrade promotion" }, 500);
  }

  return jsonResponse({ received: true }, 200);
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
    notification.type === "subscription_authorized_payment" ||
    (typeof notification.action === "string" &&
      notification.action.startsWith("subscription_authorized_payment"))
  ) {
    const adminClient = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    return await finalizeUpgradeDiscount(adminClient, accessToken, dataId);
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
