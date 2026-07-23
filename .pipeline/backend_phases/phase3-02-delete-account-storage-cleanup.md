# BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Depends on `phase3-01` (the `progress-photos` bucket); safe to ship before it (empty list = no-op).

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). `supabase/functions/delete-account/index.ts` deletes the auth user; FK `on delete cascade` wipes all `aura_*` TABLE rows — but Storage objects are NOT covered by FK cascade, so once photos live in the `progress-photos` bucket (phase3-01) a deleted account would leak its photos forever. This feature extends the Edge Function to purge the user's storage folder BEFORE deleting the auth user. Supports frontend Phase 5 (Profile → Delete Account) and GDPR-style completeness.
- **Existing Patterns to Match:**
  - `supabase/functions/delete-account/index.ts` — keep its exact structure: CORS headers, OPTIONS/405 handling, JWT→uid resolution via anon client, privileged `adminClient` (service role), JSON error envelope `{"error": "..."}`.
- **Data Schemas / Type Definitions:** none new.
- **API Request/Response Contracts:** (unchanged externally)
  - **Endpoint:** `POST /functions/v1/delete-account`
  - **Headers:** `Authorization: Bearer <user JWT>` (SDK attaches via `client.functions.invoke("delete-account")`)
  - **Payload Structure:** none (empty body)
  - **Success Response (200):** `{"ok": true}`
  - **Error Responses:** 401 `{"error":"Missing Authorization header"}` / `{"error":"Invalid or expired session"}`; 405 `{"error":"Method not allowed"}`; 500 `{"error":"<storage or auth deletion failure message>"}` — client behaviour stays: wipe local ONLY on 200.

## 📝 FILES TO MODIFY
### `supabase/functions/delete-account/index.ts`
- After resolving `uid`, BEFORE `auth.admin.deleteUser(uid)`:
  1. `const { data: objects } = await adminClient.storage.from("progress-photos").list(uid, { limit: 1000 })` — loop with `offset` pagination until fewer than `limit` returned.
  2. Collect paths `` `${uid}/${o.name}` `` and `await adminClient.storage.from("progress-photos").remove(paths)` in batches ≤ 100.
  3. Bucket-missing error (bucket not yet created): treat as success (log, continue) — forward-compatible with pre-phase3-01 deployments.
  4. Any OTHER storage failure: return 500 WITHOUT deleting the auth user (user can retry; auth deletion happens last).
- Keep every existing code path byte-compatible otherwise (CORS, 401s, response shapes).
- Maintain an explicit `USER_BUCKETS = ["progress-photos"]` const and iterate it — future per-user buckets append here; the public shared bucket from `phase5-02` must NEVER be listed.

## 📄 FILES TO CREATE
None.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Order is the security property: storage purge FIRST, auth-user deletion LAST — a mid-failure leaves a retryable account, never orphaned data with no owner able to authorize retry.
- Pagination: > 1000 objects must not silently truncate (loop until done); cap loop iterations (e.g. 50) and 500 with a clear error if exceeded.
- Service-role key never logged; error messages carry counts, not full storage paths.
- Concurrent double-invoke (user taps twice): second call's `getUser` fails after first completes → clean 401; `remove` on already-removed paths is a no-op — idempotent overall.
- Owner redeploy note: `supabase functions deploy delete-account` (manual, same as initial deploy).
