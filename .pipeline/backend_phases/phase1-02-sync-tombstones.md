# BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Retention decision pre-made: tombstones kept 90 days, purged opportunistically (pg_cron noted as owner option).

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). Current delete flow: client `SupabaseSyncService.delete(id:table:)` hard-deletes the remote row. Bug class: device B, offline during the delete, still holds the row locally; its next `pullAll()` LWW merge sees a local-only row and RE-PUSHES it — deleted data resurrects. Fix: record every delete in an `aura_deletions` tombstone table; pulling clients apply tombstones BEFORE the local-only re-push step. Hardens sync for all frontend phases; pairs with `phase1-01` delta pull.
- **Existing Patterns to Match:**
  - `supabase/migrations/0001_init_schema.sql` — table/RLS/trigger boilerplate style. New migration `supabase/migrations/0003_deletions_tombstones.sql`.
  - `AuraFitness/Sync/SupabaseSyncService.swift` — `delete(id:table:)` (~line 109), `deleteRemote` (~line 143), offline `QueueOp` replay (~line 187), `pullAll()` local-winner re-push (~line 388 comment).
- **Data Schemas / Type Definitions:**
  ```sql
  create table if not exists aura_deletions (
    user_id    uuid not null references auth.users(id) on delete cascade,
    table_name text not null,        -- rawValue of the client Table enum, e.g. 'aura_workout_logs'
    row_key    text not null,        -- uuid string, or day-ISO for keyed tables, or 'singleton'
    deleted_at timestamptz not null default now(),
    primary key (user_id, table_name, row_key)
  );
  ```
  RLS: same owner-only `for all using (auth.uid() = user_id) with check (auth.uid() = user_id)` policy as every 0001 table. Index: `(user_id, deleted_at)`.
  Tombstone WRITES happen server-side via trigger — one `after delete` row trigger on EACH of the 12 `aura_*` tables calling a shared `record_deletion()` plpgsql function inserting `(old.user_id, TG_TABLE_NAME, <key expr>, now())` with `on conflict do update set deleted_at = now()`. Key expr: `old.id::text` for uuid tables, `old.day_iso` for keyed tables, `'singleton'` for the 3 singleton tables. Trigger-side capture means even out-of-band deletes (dashboard, reset flows) tombstone correctly.
- **API Request/Response Contracts:**
  - **Endpoint:** no new endpoint — `pull_changes` (from `phase1-01`) gains one more key.
  - **Success Response addition:** `"aura_deletions": [ { "table_name": "aura_workout_logs", "row_key": "5D2A...", "deleted_at": "2026-07-18T10:00:00.000Z" } ]` — rows where `user_id = auth.uid() AND deleted_at > since`.
  - **Errors:** same ladder as `phase1-01` (401 signed-out; 404 → full-pull fallback, which then CANNOT see tombstones — acceptable degraded mode, note it in code).

## 📝 FILES TO MODIFY
### `supabase/migrations/0002_pull_changes_rpc.sql`
- If `phase1-01` already merged: create `0004_pull_changes_v2.sql` replacing the function (`create or replace`, same name/signature) to add the `aura_deletions` key. If implementing together, fold into 0002 directly.
### `AuraFitness/Sync/SupabaseSyncService.swift`
- Merge order inside the delta-pull handling: (1) apply tombstones — remove matching local row (table + key) IF the local row's last-local-change stamp is OLDER than `deleted_at` (LWW applies to deletes too: a local edit NEWER than the tombstone wins, re-pushes, recreates the remote row — correct); (2) run the normal per-table merge; (3) the local-only re-push step MUST SKIP rows matching a tombstone applied this cycle.
- `deleteRemote` stays unchanged (server trigger records the tombstone).
- Guest-mode local deletes (signed out): keep current behaviour; sign-in migration path re-pushes local state — no tombstone interaction.

## 📄 FILES TO CREATE
### `supabase/migrations/0003_deletions_tombstones.sql`
- **Purpose:** `aura_deletions` table + RLS + index, `record_deletion()` trigger function, 12 `after delete` triggers, and the 90-day purge.
- **Signatures/Interfaces:** `record_deletion() returns trigger`; `purge_old_deletions() returns void` (standalone maintenance function: `delete from aura_deletions where deleted_at < now() - interval '90 days'`). Inside `record_deletion`, run the purge opportunistically guarded to ~1/1000 calls via `random()`.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Delete-then-recreate same id: tombstone `deleted_at` vs row `updated_at` ordering decides; upsert path must NOT be blocked by an old tombstone (trigger fires only on DELETE — no loop).
- Reset-all flow (`DataResetService` remote wipe; `SupabaseSyncService` ~line 451 bulk deletes): generates up to 12×N tombstones — acceptable; row triggers fire per row, fine at this scale.
- Trigger inserts pass RLS: they run as the invoking user and insert `old.user_id == auth.uid()` for client-initiated deletes; dashboard/service-role deletes bypass RLS anyway.
- Tombstone for a row the puller never had: "remove if exists" is a silent no-op, never an error.
- Device offline > 90 days can still resurrect (purged tombstones) — accepted: its first pull is watermark-less FULL pull (phase1-01), LWW bounds damage. Note in code comment.
