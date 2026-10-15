import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (request: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    return new Response("Server configuration is incomplete", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: avatarError } = await adminClient.storage
    .from("avatars")
    .remove([`${user.id}/avatar.jpg`]);
  if (avatarError) {
    console.error("Could not remove account avatar", avatarError.message);
    return new Response("Could not remove account avatar", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const { error: dataError } = await adminClient.rpc("delete_user_data", {
    target_user_id: user.id,
  });
  if (dataError) {
    console.error("Could not remove account data", dataError.message);
    return new Response("Could not remove account data", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const { error } = await adminClient.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("Account deletion failed", error.message);
    return new Response("Could not delete account", {
      status: 500,
      headers: corsHeaders,
    });
  }

  return new Response(null, { status: 204, headers: corsHeaders });
});
