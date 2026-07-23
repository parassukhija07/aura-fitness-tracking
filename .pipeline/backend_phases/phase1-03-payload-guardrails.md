# BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Size caps pre-decided below. One caveat: if production rows already exceed a cap (plausible only for `aura_progress_photos` base64 blobs), that constraint is added `not valid` (existing rows skipped; new writes enforced); `phase3-01` migrates the blobs away.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). All 12 `aura_*` tables store an opaque `payload jsonb` with NO size or shape constraints — a buggy or malicious client can write arbitrarily large or non-object payloads, bloating the DB and breaking other devices' decoders. This feature adds defense-in-depth CHECK constraints. Supports every frontend phase (shared sync engine).
- **Existing Patterns to Match:**
  - `supabase/migrations/0001_init_schema.sql` — DDL style, MARK sections. New migration `supabase/migrations/0005_payload_guardrails.sql` (or next free number).
- **Data Schemas / Type Definitions:** Per-table CHECK constraints (names exact, so later migrations can drop/alter):
  ```sql
  -- every table: payload must be a JSON object
  alter table aura_workout_logs add constraint aura_workout_logs_payload_is_object
    check (jsonb_typeof(payload) = 'object') not valid;
  -- size caps via pg_column_size(payload):
  --   aura_progress_photos: 3 MB   (base64 blob until phase3-01 lands)
  --   aura_workout_logs:    256 KB
  --   all other tables:     64 KB
  alter table aura_workout_logs add constraint aura_workout_logs_payload_max_size
    check (pg_column_size(payload) <= 262144) not valid;
  ```
  Repeat both constraints for all 12 tables with the stated caps. After adding, `alter table ... validate constraint ...` for each table EXCEPT `aura_progress_photos` (stays `not valid` until phase3-01 completes).
  Index audit (same migration): confirm the 0001 `(user_id, updated_at)` indexes exist on all 9 non-singleton tables; add any missing. Add `aura_deletions (user_id, deleted_at)` if `phase1-02` landed without it.
- **API Request/Response Contracts:**
  - **Endpoint:** none new. Violations surface through existing PostgREST upserts:
  - **Error Response (400):** `{"code":"23514","message":"new row for relation \"aura_workout_logs\" violates check constraint \"aura_workout_logs_payload_max_size\"","details":"..."}` — client `SupabaseSyncService` must treat code `23514` as PERMANENT (drop queued op + os_log error), never retry-forever.

## 📝 FILES TO MODIFY
### `AuraFitness/Sync/SupabaseSyncService.swift`
- In push/queue error handling (`upsertRemote` catch path and queue replay ~line 187): classify errors — network/5xx = retryable (keep queued); `23514` or any 4xx constraint/validation = permanent (drop op, log with table + row id). Grep current catch blocks first; extend, don't rewrite.

## 📄 FILES TO CREATE
### `supabase/migrations/0005_payload_guardrails.sql`
- **Purpose:** The CHECK constraints + validations + index audit above; header comment states each cap and why `aura_progress_photos` stays `not valid` until phase3-01.
- **Signatures/Interfaces:** pure DDL; constraint naming `"<table>_payload_is_object"` / `"<table>_payload_max_size"`.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- `validate constraint` takes a full-table scan lock — acceptable at current scale; note in the migration header.
- Client permanent-failure handling must not drop LOCAL data — only the remote queue op; local stores stay authoritative.
- 3 MB photo cap vs client JPEG compression: verify the client's compression target (`ProgressPhotosView`/`AppState`) stays under 3 MB; if not, clamp client-side quality — cross-reference in phase3-01.
- Do NOT add payload SHAPE validation beyond `is_object` (schemas evolve client-side; deep JSON-schema checks would break forward compatibility).
