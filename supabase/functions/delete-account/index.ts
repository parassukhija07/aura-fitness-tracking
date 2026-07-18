// supabase/functions/delete-account/index.ts
//
// H8 R2 — server-side account deletion using the service_role key. The anon
// client cannot delete an auth user; this Edge Function runs privileged.
//
// Contract:
//   POST, requires `Authorization: Bearer <user JWT>` (the app's SDK attaches
//   this automatically via `client.functions.invoke("delete-account")`).
//   - Verifies the JWT -> resolves uid. 401 if missing/invalid.
//   - Uses a service_role admin client to call auth.admin.deleteUser(uid).
//     The `on delete cascade` FKs on every aura_* table wipe all remote user
//     data automatically — no per-table cleanup needed here.
//   - Returns 200 {"ok": true} on success; 4xx/5xx {"error": "..."} otherwise.
//
// Manual deploy step (cannot be run from this environment):
//   supabase link --project-ref <your-project-ref>
//   supabase functions deploy delete-account
// The function inherits SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY automatically
// from the linked project's Edge Function runtime env — no secret is committed
// here or anywhere in this repo.

import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const jwt = authHeader.replace("Bearer ", "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Client scoped to the caller's own JWT — used only to resolve identity.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const uid = userData.user.id;

    // Privileged admin client — deletes the auth user; cascade FKs wipe all
    // aura_* rows for this user automatically.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { error: deleteErr } = await adminClient.auth.admin.deleteUser(uid);
    if (deleteErr) {
      return new Response(JSON.stringify({ error: deleteErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
