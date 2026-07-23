# BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Requires a linked Supabase project to apply (`supabase db push`) — writing the migration + client code does not.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness is a SwiftUI iOS app whose entire backend is Supabase. The client (`AuraFitness/Sync/SupabaseSyncService.swift`) currently syncs by full-table pulls of 12 `aura_*` tables on every `pullAll()` — 12 requests, all rows, every time. This feature adds a single Postgres RPC returning only rows changed since a client-held watermark, cutting sync to one request. It hardens the sync engine that frontend Phases 1–2 (Log tab + Active Workout, already shipped) depend on.
- **Existing Patterns to Match:**
  - `supabase/migrations/0001_init_schema.sql` — migration file style (header comment, `create or replace function`, MARK sections). New migration = `supabase/migrations/0002_pull_changes_rpc.sql`.
  - `AuraFitness/Sync/SupabaseSyncService.swift` — `Table` enum (line ~13, `CaseIterable`, rawValue = table name), `pullAll()` (~line 300) with its LWW merge (compares `updated_at` vs local change stamps; local winner re-pushes), `lastPullAt` published var (~line 35).
- **Data Schemas / Type Definitions:** No new tables. RPC (SQL, in the migration):
  - `create or replace function pull_changes(since timestamptz) returns jsonb language sql security invoker stable` — returns one JSONB object: `{ "<table_name>": [ {"id"|"day_iso": ..., "payload": {...}, "updated_at": "..."}, ... ], ... }`, one key per `aura_*` table, each array = rows where `user_id = auth.uid() AND updated_at > since`. ALWAYS include all 12 keys (empty array when none) so the client decoder is total — document this in the SQL header.
  - `security invoker` is REQUIRED (RLS keeps enforcing owner-only). Never `security definer`.
  - Swift client type: `struct PullChangesResponse: Decodable` with one array property per table; row type mirrors the decoding approach already used inside `pullAll()` (reuse its row structs if present).
- **API Request/Response Contracts:**
  - **Endpoint:** `POST /rest/v1/rpc/pull_changes` (via supabase-swift: `client.rpc("pull_changes", params: ["since": "..."])`)
  - **Headers:** `apikey: <anon key>`, `Authorization: Bearer <user JWT>` (SDK attaches both)
  - **Payload Structure:** `{ "since": "2026-07-01T10:00:00Z" }` (first pull sends `"1970-01-01T00:00:00Z"`)
  - **Success Response (200):**
    ```json
    { "aura_workout_logs": [ { "id": "5D2A...", "payload": { "...": "..." }, "updated_at": "2026-07-18T09:12:44.120Z" } ],
      "aura_day_overrides": [ { "day_iso": "2026-07-17", "payload": { "...": "..." }, "updated_at": "2026-07-18T08:00:01.000Z" } ],
      "aura_body_stats": [], "aura_user_profile": [], "aura_preferences": [], "aura_measurements": [],
      "aura_personal_records": [], "aura_progress_photos": [], "aura_programs": [], "aura_plans": [],
      "aura_exercises": [], "aura_quick_logs": [] }
    ```
  - **Error Responses:** 401 `{"message":"JWT expired"}` (PostgREST shape — client treats as signed-out, no retry loop); 404 `{"message":"function public.pull_changes(since => timestamptz) does not exist"}` → client MUST fall back to legacy `pullAll()` full pull (migration not yet applied); 400 `{"message":"invalid input syntax for type timestamp with time zone"}` → client falls back to full pull once.

## 📝 FILES TO MODIFY
### `AuraFitness/Sync/SupabaseSyncService.swift`
- Persist the watermark: `private var lastDeltaPullAt: Date` backed by UserDefaults key `aura_sync_last_delta_pull_v1`; clear it wherever the service clears state on sign-out/remote-reset.
- Add `func pullChanges() async`: calls the RPC with `since = lastDeltaPullAt`; on success routes each returned row through the SAME per-table LWW merge logic `pullAll()` uses (extract that merge into a shared private helper rather than duplicating); advances the watermark ONLY after a fully successful merge; keeps `lastPullAt` semantics for UI.
- Watermark rule: new watermark = **max `updated_at` seen in the response** (never client clock — avoids clock-skew gaps). Empty response → watermark unchanged.
- Call sites: where `pullAll()` runs on foreground/login (grep for call sites), switch to `pullChanges()`; keep `pullAll()` for first-login backfill (no watermark) and as the 404 fallback.

## 📄 FILES TO CREATE
### `supabase/migrations/0002_pull_changes_rpc.sql`
- **Purpose:** Defines `pull_changes(since timestamptz)` returning the per-table JSONB delta described above.
- **Signatures/Interfaces:** one SQL function; body = `jsonb_build_object('aura_workout_logs', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'payload', payload, 'updated_at', updated_at)), '[]'::jsonb) from aura_workout_logs where user_id = auth.uid() and updated_at > since), ...)` repeated for all 12 tables (`day_iso` instead of `id` for `aura_day_overrides`/`aura_quick_logs`; singleton tables `aura_body_stats`/`aura_user_profile`/`aura_preferences` emit no `id`). Header comment documents the contract + the always-include-all-keys decision.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- `security invoker` + existing RLS = a forged `since` can never leak other users' rows; verify with two test users if a linked project is available.
- Clock skew: server `updated_at` is trigger-set (`set_updated_at()` in 0001) — never trust client-sent `updated_at` for the watermark; use response max as specified.
- Large first delta (user returns after months): response may be MBs — client merges without blocking the main thread (follow `pullAll`'s existing actor/queue pattern).
- Missed-delete blindness: `updated_at > since` cannot express deletions — EXPECTED; fixed by companion `phase1-02` tombstones. Do not invent ad-hoc delete detection here.
- Fallback ladder must terminate: RPC 404 → one legacy full pull → done (no retry storm).
