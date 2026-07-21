// supabase/functions/delete-account/index.ts
//
// H8 R2 — server-side account deletion using the service_role key. The anon
// client cannot delete an auth user; this Edge Function runs privileged.
//
// Contract:
//   POST, requires `Authorization: Bearer <user JWT>` (the app's SDK attaches
//   this automatically via `client.functions.invoke("delete-account")`).
//   - Verifies the JWT -> resolves uid. 401 if missing/invalid.
//   - Purges the user's Storage objects (phase3-02) — see USER_BUCKETS below.
//     FK cascade covers TABLE rows only; Storage has no foreign key to
//     auth.users, so without this a deleted account leaks its progress photos
//     forever, with nobody left who could authorize removing them.
//   - Uses a service_role admin client to call auth.admin.deleteUser(uid).
//     The `on delete cascade` FKs on every aura_* table wipe all remote user
//     data automatically — no per-table cleanup needed here.
//   - Returns 200 {"ok": true} on success; 4xx/5xx {"error": "..."} otherwise.
//
// ORDERING IS A SECURITY PROPERTY: storage purge FIRST, auth deletion LAST.
// A failure midway leaves an account that still exists and can retry. The
// reverse order would leave objects nobody can ever authenticate to delete.
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

// Buckets whose contents belong to exactly ONE user, stored under a `{uid}/`
// prefix. Every entry here is purged wholesale on account deletion, so a
// bucket may only be added if that prefix genuinely means sole ownership.
//
// SHARED buckets must NEVER appear here — deleting one user's account would
// destroy other users' objects. The public shared bucket introduced by
// phase5-02 is the specific thing this list must keep out.
const USER_BUCKETS = ["progress-photos"];

// Supabase Storage caps `list` at 1000 rows per call, so > 1000 photos need
// pagination — silently truncating would leave objects behind and defeat the
// whole function.
const LIST_PAGE_SIZE = 1000;
// `remove` takes an array of paths; keeping batches small bounds the request
// body and makes a partial failure cheap to report.
const REMOVE_BATCH_SIZE = 100;
// Hard stop so a pagination bug (or a listing that never shrinks) cannot spin
// forever inside a request. 50 x 1000 = 50,000 objects per bucket, far beyond
// any plausible photo library.
const MAX_LIST_PAGES = 50;

/// A missing bucket is not an error here: this function may be deployed to a
/// project where the owner has not created `progress-photos` yet (phase3-01 is
/// a manual step). Nothing to purge means nothing to fail.
function isBucketMissing(
  error: { message?: string; status?: number; statusCode?: string | number } | null,
): boolean {
  if (!error) return false;
  const text = (error.message ?? "").toLowerCase();
  return text.includes("bucket not found") ||
    error.status === 404 ||
    `${error.statusCode ?? ""}` === "404";
}

/// Removes every object under `{uid}/` in each of USER_BUCKETS.
///
/// Lists ALL pages before removing any: deleting while paginating shifts the
/// offsets of everything after the deleted rows, which would skip objects.
///
/// Failure messages carry counts and bucket names only — never object paths,
/// and never anything derived from the service-role key.
async function purgeUserStorage(
  adminClient: ReturnType<typeof createClient>,
  uid: string,
): Promise<{ ok: true; removed: number } | { ok: false; message: string }> {
  let removed = 0;

  for (const bucket of USER_BUCKETS) {
    const paths: string[] = [];

    for (let page = 0; page < MAX_LIST_PAGES; page++) {
      const { data, error } = await adminClient.storage
        .from(bucket)
        .list(uid, { limit: LIST_PAGE_SIZE, offset: page * LIST_PAGE_SIZE });

      if (error) {
        if (isBucketMissing(error)) {
          console.log(`delete-account: bucket "${bucket}" not present — nothing to purge`);
          break;
        }
        return {
          ok: false,
          message: `Storage listing failed for bucket "${bucket}": ${error.message}`,
        };
      }

      const entries = data ?? [];
      for (const entry of entries) {
        // Storage returns a null `id` for a prefix (pseudo-folder) rather than
        // a real object — the declared type says `string`, so test truthiness
        // instead of comparing to null. The path convention is flat anyway
        // ({uid}/{photo_uuid}.jpg), so a prefix here is never a photo and
        // `remove` would no-op on it regardless; skipping just keeps the
        // reported count honest.
        if (!entry.id) continue;
        paths.push(`${uid}/${entry.name}`);
      }

      if (entries.length < LIST_PAGE_SIZE) break;

      if (page === MAX_LIST_PAGES - 1) {
        return {
          ok: false,
          message:
            `Storage cleanup aborted: bucket "${bucket}" holds more than ` +
            `${MAX_LIST_PAGES * LIST_PAGE_SIZE} objects for this user`,
        };
      }
    }

    for (let i = 0; i < paths.length; i += REMOVE_BATCH_SIZE) {
      const batch = paths.slice(i, i + REMOVE_BATCH_SIZE);
      const { error } = await adminClient.storage.from(bucket).remove(batch);
      if (error) {
        return {
          ok: false,
          message:
            `Storage deletion failed for bucket "${bucket}" after ` +
            `${removed} of ${paths.length} object(s): ${error.message}`,
        };
      }
      removed += batch.length;
    }
  }

  return { ok: true, removed };
}

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

    // Privileged admin client — purges Storage, then deletes the auth user;
    // cascade FKs wipe all aura_* rows for this user automatically.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Storage FIRST. Bailing out here leaves the account intact and retryable;
    // the objects are still owned by someone who can authorize another attempt.
    const purge = await purgeUserStorage(adminClient, uid);
    if (!purge.ok) {
      return new Response(JSON.stringify({ error: purge.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    console.log(`delete-account: purged ${purge.removed} storage object(s)`);

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
