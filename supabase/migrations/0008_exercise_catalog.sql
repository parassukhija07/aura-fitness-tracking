-- 0008_exercise_catalog.sql
-- Aura Fitness — global, read-only exercise catalog + a version marker so
-- clients can refresh the bundled library over the air.
--
-- NUMBERING: the phase spec drafted this as `0007_exercise_catalog.sql`, but
-- 0007 was already taken by `0007_function_hardening.sql`. Migrations are
-- applied in filename order and a duplicate prefix is ambiguous, so this ships
-- as 0008. Nothing else about the spec changed.
--
-- WHY: the exercise library ships inside the app bundle
-- (`AuraFitness/Resources/gym_exercise_library.json`). Bundled-only means a
-- typo, a dead YouTube link, or a new exercise needs an App Store release to
-- reach users. These two tables let the client pull a newer catalog at launch,
-- with the bundled JSON still serving as the offline seed and the fallback
-- whenever the fetch fails.
--
-- NOT PER-USER SYNC: neither table has a `user_id` column and neither belongs
-- in `SupabaseSyncService.Table`. This is one global catalog every client
-- reads; it is deliberately outside the delta-pull/tombstone machinery.
--
-- WRITE PATH — service role only:
--   RLS is enabled with SELECT-only policies and NO insert/update/delete
--   policy, so anon and authenticated writes are rejected with `42501`. The
--   only supported writers are (a) this migration, (b) the generated seed in
--   `supabase/seed/seed_exercise_catalog.sql`, both run by the project owner
--   against the service role. Grants are revoked as well (defense in depth):
--   Supabase's default privileges hand anon/authenticated full DML on new
--   public tables, and a future policy added by mistake should not be the only
--   thing standing between a user and the global catalog.
--
-- VERSION-BUMP PROCEDURE (shipping a catalog update):
--   1. Edit `AuraFitness/Resources/gym_exercise_library.json`.
--   2. Bump `CATALOG_VERSION` in `supabase/seed/generate_seed.py`.
--   3. Run the generator; commit the regenerated
--      `supabase/seed/seed_exercise_catalog.sql`.
--   4. Run that seed against the project. It upserts every row and bumps
--      `aura_catalog_meta.catalog_version` in one transaction; clients notice
--      the new version on their next launch and pull the full catalog.
--   Never re-key an existing exercise. Ids are a UUIDv5 of the exercise NAME,
--   so a rename produces a NEW id — ship the new row and leave the old one in
--   place rather than updating the id of an existing row.
--
-- Re-runnable: `create table if not exists`, and every policy/constraint is
-- dropped before being re-created.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once.

-- MARK: - Catalog rows

create table if not exists aura_exercise_catalog (
  -- Deterministic UUIDv5 of "exercise:<name>" under the frozen namespace in
  -- `StableID` (AuraFitness/Models/SeedData.swift). Matches the id the client
  -- computes for the same exercise, which is what makes a remote row REPLACE
  -- its bundled counterpart instead of duplicating it.
  id         uuid        primary key,
  -- One `ExerciseEntry` as the Swift client decodes it (camelCase keys — the
  -- generator translates the snake_case bundled JSON on the way in).
  payload    jsonb       not null,
  updated_at timestamptz not null default now()
);

-- MARK: - Version marker
--
-- Single logical row: key = 'catalog_version'. A table rather than a setting
-- so the client can read it over PostgREST with the same anon key it already
-- has, and so the version bump is transactional with the rows it describes.
create table if not exists aura_catalog_meta (
  key        text        primary key,
  value      text        not null,
  updated_at timestamptz not null default now()
);

-- MARK: - Payload guardrails (same shape as 0005)
--
-- Shallow on purpose: `is_object` and a size cap, nothing about the schema.
-- The payload schema evolves with the app, and a deep check here would reject
-- a catalog written for a newer client. 64 KB is the same cap 0005 puts on
-- `aura_exercises`; the largest real entry is well under 4 KB.
alter table aura_exercise_catalog drop constraint if exists aura_exercise_catalog_payload_is_object;
alter table aura_exercise_catalog add  constraint aura_exercise_catalog_payload_is_object
  check (jsonb_typeof(payload) = 'object');

alter table aura_exercise_catalog drop constraint if exists aura_exercise_catalog_payload_max_size;
alter table aura_exercise_catalog add  constraint aura_exercise_catalog_payload_max_size
  check (octet_length(payload::text) <= 65536);

-- The version marker is a short opaque string the client compares for
-- equality; nothing needs to parse it, and nothing needs it to be long.
alter table aura_catalog_meta drop constraint if exists aura_catalog_meta_value_max_size;
alter table aura_catalog_meta add  constraint aura_catalog_meta_value_max_size
  check (length(value) between 1 and 64);

-- MARK: - RLS: world-readable, nobody-writable

alter table aura_exercise_catalog enable row level security;
alter table aura_catalog_meta     enable row level security;

drop policy if exists "catalog_read_all" on aura_exercise_catalog;
create policy "catalog_read_all" on aura_exercise_catalog
  for select using (true);

drop policy if exists "meta_read_all" on aura_catalog_meta;
create policy "meta_read_all" on aura_catalog_meta
  for select using (true);

-- No insert/update/delete policy on either table, by design. With RLS on, the
-- absence of a policy IS the denial — see the write-path note in the header.

-- MARK: - Grants (defense in depth behind the policies)

revoke insert, update, delete, truncate on aura_exercise_catalog from anon, authenticated;
revoke insert, update, delete, truncate on aura_catalog_meta     from anon, authenticated;
grant select on aura_exercise_catalog to anon, authenticated;
grant select on aura_catalog_meta     to anon, authenticated;
