import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const KV_RATE_LIMIT = "delete_account_rate_limit";
const KV_IDEMPOTENCY = "delete_account_idempotency";
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000; // 15 minutos
const RATE_LIMIT_MAX = 3; // máximo 3 solicitudes por ventana
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000; // 24 horas

function corsHeaders(origin: string | null, allowedOrigins: string[]): Record<string, string> {
  const allowOrigin = origin && allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function jsonResponse(body: unknown, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

async function checkRateLimit(kv: Deno.Kv, userId: string): Promise<boolean> {
  const key = [KV_RATE_LIMIT, userId];
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  const existing = (await kv.get<{ attempts: number[] }>(key))?.value ?? { attempts: [] };
  const recent = existing.attempts.filter((t) => t > windowStart);

  if (recent.length >= RATE_LIMIT_MAX) {
    return false;
  }

  recent.push(now);
  await kv.set(key, { attempts: recent }, { expireIn: RATE_LIMIT_WINDOW_MS });
  return true;
}

async function checkIdempotency(
  kv: Deno.Kv,
  idempotencyKey: string,
): Promise<{ status: number; body: unknown } | null> {
  const stored = await kv.get<{ status: number; body: unknown }>([KV_IDEMPOTENCY, idempotencyKey]);
  if (stored?.value) {
    return stored.value;
  }
  return null;
}

async function storeIdempotency(
  kv: Deno.Kv,
  idempotencyKey: string,
  status: number,
  body: unknown,
): Promise<void> {
  await kv.set([KV_IDEMPOTENCY, idempotencyKey], { status, body }, {
    expireIn: IDEMPOTENCY_TTL_MS,
  });
}

Deno.serve(async (request: Request) => {
  const rawAllowed = Deno.env.get("ALLOWED_ORIGINS") ?? "https://manageyourday.app";
  const allowedOrigins = rawAllowed.split(",").map((o) => o.trim()).filter(Boolean);
  const origin = request.headers.get("Origin");
  const headers = corsHeaders(origin, allowedOrigins);

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers });
  }
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers });
  }

  const idempotencyKey = request.headers.get("Idempotency-Key");
  const kv = await Deno.openKv();

  if (idempotencyKey) {
    const cached = await checkIdempotency(kv, idempotencyKey);
    if (cached) {
      return jsonResponse(cached.body, cached.status, headers);
    }
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    const body = { error: "Unauthorized" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 401, body);
    return jsonResponse(body, 401, headers);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    const body = { error: "Server configuration is incomplete" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
    return jsonResponse(body, 500, headers);
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    const body = { error: "Unauthorized" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 401, body);
    return jsonResponse(body, 401, headers);
  }

  // Rate limiting por usuario.
  if (!(await checkRateLimit(kv, user.id))) {
    const body = { error: "Too many requests. Try again later." };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 429, body);
    return jsonResponse(body, 429, headers);
  }

  // Verificar reautenticación reciente (token emitido hace menos de 10 minutos).
  const tokenIssuedAt = user.issued_at ? new Date(user.issued_at).getTime() : 0;
  const tenMinutesAgo = Date.now() - 10 * 60 * 1000;
  if (tokenIssuedAt < tenMinutesAgo) {
    const body = { error: "Reauthentication required. Please sign in again." };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 403, body);
    return jsonResponse(body, 403, headers);
  }

  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Listar recibos del usuario.
  const { data: movements, error: movementError } = await adminClient
    .from("movimientos")
    .select("comprobante_path")
    .eq("usuario_id", user.id)
    .not("comprobante_path", "is", null);
  if (movementError) {
    console.error("delete_account: could not list receipts", { userId: user.id, error: movementError.message });
    const body = { error: "Could not remove account data" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
    return jsonResponse(body, 500, headers);
  }

  const receiptPaths = (movements ?? [])
    .map((movement) => movement.comprobante_path as string)
    .filter(Boolean);
  for (let start = 0; start < receiptPaths.length; start += 100) {
    const { error: receiptError } = await adminClient.storage
      .from("receipts")
      .remove(receiptPaths.slice(start, start + 100));
    if (receiptError) {
      console.error("delete_account: could not remove receipts", { userId: user.id, error: receiptError.message });
      const body = { error: "Could not remove account data" };
      if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
      return jsonResponse(body, 500, headers);
    }
  }

  const { error: avatarError } = await adminClient.storage
    .from("avatars")
    .remove([`${user.id}/avatar.jpg`, `${user.id}/cover.jpg`]);
  if (avatarError) {
    console.error("delete_account: could not remove profile images", { userId: user.id, error: avatarError.message });
    const body = { error: "Could not remove account data" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
    return jsonResponse(body, 500, headers);
  }

  const { error: dataError } = await adminClient.rpc("delete_user_data", {
    target_user_id: user.id,
  });
  if (dataError) {
    console.error("delete_account: could not remove user data", { userId: user.id, error: dataError.message });
    const body = { error: "Could not remove account data" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
    return jsonResponse(body, 500, headers);
  }

  const { error } = await adminClient.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete_account: account deletion failed", { userId: user.id, error: error.message });
    const body = { error: "Could not delete account" };
    if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 500, body);
    return jsonResponse(body, 500, headers);
  }

  // Evento de auditoría sin datos sensibles del usuario.
  console.info("delete_account: account deleted", {
    userId: user.id,
    deletedAt: new Date().toISOString(),
    receiptsRemoved: receiptPaths.length,
  });

  const body = null;
  if (idempotencyKey) await storeIdempotency(kv, idempotencyKey, 204, body);
  return new Response(null, { status: 204, headers });
});
