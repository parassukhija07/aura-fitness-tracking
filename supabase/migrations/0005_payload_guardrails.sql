-- 0005_payload_guardrails.sql
-- Aura Fitness — defense-in-depth guardrails on the opaque `payload jsonb`
-- column, plus an index audit.
--
-- WHY: all 12 aura_* tables accept an arbitrary jsonb payload with no size or
-- shape limit. A buggy or hostile client can write a 50 MB blob, or a bare
-- string/array where every other device's decoder expects an object — bloating
-- the database and breaking sync for that user's other devices. These CHECK
-- constraints reject both at the edge; the client turns the resulting `23514`
-- into a permanent (non-retried) failure rather than an infinite queue loop.
--
-- SIZE CAPS (per row payload):
--   aura_progress_photos  3 MB    — base64 JPEG blob lives in the payload
--                                   until phase3-01 moves photos to Storage
--   aura_workout_logs     256 KB  — biggest legitimate row (sets x exercises)
--   every other table     64 KB   — generous for what these actually store
--
-- HOW SIZE IS MEASURED — deviation from the phase spec, deliberate:
-- the spec drafted `pg_column_size(payload)`, but that function is STABLE and
-- Postgres refuses non-IMMUTABLE functions inside a CHECK constraint
-- ("functions in check constraint must be marked IMMUTABLE"), so that DDL
-- would not apply. `octet_length(payload::text)` is immutable and, being the
-- uncompressed JSON text length, measures the wire size a client actually has
-- to ship and decode — which is the thing that breaks other devices. It is
-- also strictly more conservative than pg_column_size, which reports the
-- TOAST-COMPRESSED stored size and would let a much larger payload through
-- the same numeric cap.
--
-- NOT VALID / VALIDATE: constraints are added NOT VALID (new writes enforced,
-- existing rows not scanned) and then validated per table — EXCEPT
-- `aura_progress_photos`, which stays NOT VALID because production rows may
-- already hold oversized base64 blobs. phase3-01 migrates those to Storage;
-- validate it after that lands.
--
-- LOCKING: `validate constraint` takes a SHARE UPDATE EXCLUSIVE lock and scans
-- the whole table. Fine at current scale (single-digit users); revisit before
-- it stops being.
--
-- SHAPE VALIDATION IS DELIBERATELY SHALLOW: `is_object` and nothing more.
-- The payload schema evolves client-side with every app release; a deep
-- JSON-schema check here would reject payloads from a newer app version and
-- break forward compatibility.
--
-- Re-runnable: every constraint is dropped before being re-added, and every
-- index uses `if not exists`.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once.

-- MARK: - Shape: payload must be a JSON object (all 12 tables)
do $$
declare
  t text;
begin
  foreach t in array array[
    'aura_workout_logs', 'aura_measurements', 'aura_personal_records',
    'aura_progress_photos', 'aura_programs', 'aura_plans', 'aura_exercises',
    'aura_day_overrides', 'aura_quick_logs',
    'aura_body_stats', 'aura_user_profile', 'aura_preferences'
  ]
  loop
    execute format('alter table %I drop constraint if exists %I', t, t || '_payload_is_object');
    execute format(
      'alter table %I add constraint %I check (jsonb_typeof(payload) = ''object'') not valid',
      t, t || '_payload_is_object');
  end loop;
end;
$$;

-- MARK: - Size caps
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('aura_progress_photos',  3145728),   -- 3 MB
      ('aura_workout_logs',      262144),   -- 256 KB
      ('aura_measurements',       65536),   -- 64 KB from here down
      ('aura_personal_records',   65536),
      ('aura_programs',           65536),
      ('aura_plans',              65536),
      ('aura_exercises',          65536),
      ('aura_day_overrides',      65536),
      ('aura_quick_logs',         65536),
      ('aura_body_stats',         65536),
      ('aura_user_profile',       65536),
      ('aura_preferences',        65536)
    ) as v(tbl, cap)
  loop
    execute format('alter table %I drop constraint if exists %I', r.tbl, r.tbl || '_payload_max_size');
    execute format(
      'alter table %I add constraint %I check (octet_length(payload::text) <= %s) not valid',
      r.tbl, r.tbl || '_payload_max_size', r.cap);
  end loop;
end;
$$;

-- MARK: - Validate against existing rows
--
-- aura_progress_photos is absent on purpose — see the NOT VALID note in the
-- header. Its constraints still govern every new write; they just don't
-- assert anything about rows already stored.
do $$
declare
  t text;
begin
  foreach t in array array[
    'aura_workout_logs', 'aura_measurements', 'aura_personal_records',
    'aura_programs', 'aura_plans', 'aura_exercises',
    'aura_day_overrides', 'aura_quick_logs',
    'aura_body_stats', 'aura_user_profile', 'aura_preferences'
  ]
  loop
    execute format('alter table %I validate constraint %I', t, t || '_payload_is_object');
    execute format('alter table %I validate constraint %I', t, t || '_payload_max_size');
  end loop;
end;
$$;

-- MARK: - Index audit
--
-- Re-asserting the 0001 indexes rather than trusting them: every delta pull
-- filters `user_id = auth.uid() and updated_at > since`, so a missing index
-- here degrades every sync. `if not exists` makes each a no-op when 0001
-- already created it. The 3 singleton tables need none — their primary key IS
-- user_id and they hold exactly one row per user.
create index if not exists idx_aura_workout_logs_user_updated     on aura_workout_logs     (user_id, updated_at);
create index if not exists idx_aura_measurements_user_updated     on aura_measurements     (user_id, updated_at);
create index if not exists idx_aura_personal_records_user_updated on aura_personal_records (user_id, updated_at);
create index if not exists idx_aura_progress_photos_user_updated  on aura_progress_photos  (user_id, updated_at);
create index if not exists idx_aura_programs_user_updated         on aura_programs         (user_id, updated_at);
create index if not exists idx_aura_plans_user_updated            on aura_plans            (user_id, updated_at);
create index if not exists idx_aura_exercises_user_updated        on aura_exercises        (user_id, updated_at);
create index if not exists idx_aura_day_overrides_user_updated    on aura_day_overrides    (user_id, updated_at);
create index if not exists idx_aura_quick_logs_user_updated       on aura_quick_logs       (user_id, updated_at);

-- Tombstones (0003) are scanned the same way, by `deleted_at > since`.
create index if not exists idx_aura_deletions_user_deleted on aura_deletions (user_id, deleted_at);
