# BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only)

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Seeding is owner-run (one SQL file generated from the repo JSON); catalog updates ship as new seed runs bumping `catalog_version`.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). The exercise library ships as a bundled JSON (`AuraFitness/Resources/gym_exercise_library.json` after frontend spec 06-01; repo root before). Bundled-only means catalog fixes/additions require an App Store release. This feature adds a global, read-only `aura_exercise_catalog` table + a version marker so clients refresh the catalog over the air, with the bundled JSON as offline seed/fallback. Supports frontend Phase 6 (specs 06-01/06-02).
- **Existing Patterns to Match:**
  - `supabase/migrations/0001_init_schema.sql` — DDL style. New migration `supabase/migrations/0007_exercise_catalog.sql`.
  - `AuraFitness/Models/ExerciseDatabase.swift` — `ExerciseEntry` Codable (name, category, equipment, musclesTargeted, type, difficulty, repRange, youtubeURL, imageURL, proTips, warmupProtocol, isCable, pulley) and its bundled-JSON load path; remote refresh merges through the same decode.
- **Data Schemas / Type Definitions:**
  ```sql
  create table if not exists aura_exercise_catalog (
    id uuid primary key,               -- deterministic UUIDv5 of exercise name (matches client seed ids)
    payload jsonb not null,            -- one ExerciseEntry, same JSON shape as the bundled file
    updated_at timestamptz not null default now()
  );
  alter table aura_exercise_catalog enable row level security;
  create policy "catalog_read_all" on aura_exercise_catalog for select using (true);
  -- NO insert/update/delete policies: writes only via service role / migrations.
  create table if not exists aura_catalog_meta (
    key text primary key,              -- single row: 'catalog_version'
    value text not null,
    updated_at timestamptz not null default now()
  );
  alter table aura_catalog_meta enable row level security;
  create policy "meta_read_all" on aura_catalog_meta for select using (true);
  ```
  Client: stored catalog version (UserDefaults key `aura_catalog_version_v1`); bundled JSON gets a version constant beside the loader (`let bundledCatalogVersion = "1"`).
- **API Request/Response Contracts:**
  - **Endpoint:** `GET /rest/v1/aura_catalog_meta?key=eq.catalog_version&select=value` — **Success (200):** `[{"value":"2"}]`; `[]` when unseeded (client keeps bundled catalog).
  - **Endpoint:** `GET /rest/v1/aura_exercise_catalog?select=id,payload,updated_at` (fetched only when remote version ≠ local) — **Success (200):** `[{"id":"...","payload":{"...ExerciseEntry JSON...":"..."},"updated_at":"..."}]`.
  - **Headers:** `apikey` + `Authorization: Bearer <anon or user JWT>` (public read works for both).
  - **Errors:** 401 only if keys misconfigured (client: keep bundled, log); network failure → keep bundled catalog silently.

## 📝 FILES TO MODIFY
### `AuraFitness/Models/ExerciseDatabase.swift`
- On launch (after bundled load, background priority): fetch `catalog_version`; if different from stored, fetch full catalog, decode payloads into `[ExerciseEntry]`, REPLACE all non-custom entries (`isCustom == false`), keep custom entries untouched, persist entries + new version. Decode failure → keep current catalog (never partial-apply).
### `AuraFitness/Sync/SupabaseSyncService.swift`
- Nothing — catalog is NOT per-user sync; do NOT add it to the `Table` enum (no `user_id` column). Fetch via the shared `client` directly from `ExerciseDatabase`.

## 📄 FILES TO CREATE
### `supabase/migrations/0007_exercise_catalog.sql`
- **Purpose:** Both tables + read-only policies; header documents the write path (service role only) and version-bump procedure. Include phase1-03-style CHECK constraints on `payload` (`is_object`, 64 KB cap).
### `supabase/seed/seed_exercise_catalog.sql` (generated, committed) + `supabase/seed/generate_seed.py`
- **Purpose:** idempotent seed — `insert ... on conflict (id) do update set payload = excluded.payload` rows generated from `gym_exercise_library.json`, plus `insert into aura_catalog_meta (key, value) values ('catalog_version','1') on conflict (key) do update set value = excluded.value`. Generator script runs locally; output committed. UUIDv5 namespace = fixed constant UUID documented in the script — MUST equal the deterministic-id scheme `phase2-01` establishes client-side.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Read-only enforcement is policy-based: RLS enabled + no write policies = anon/user writes rejected (`42501`). Verify with an anon-key write attempt.
- Version check cheap and non-blocking: one tiny GET on launch, background, no retry loop (next launch retries naturally).
- Replacing non-custom entries must not break references: deterministic UUIDv5 ids keep workout→exercise references valid across catalog updates; never re-key an existing exercise (name change = new id, keep old row).
- Seed wraps in a single transaction; `on conflict` keeps it idempotent/re-runnable.
