-- 0004_pull_changes_v2.sql
-- Aura Fitness — pull_changes v2: same contract as 0002_pull_changes_rpc.sql
-- plus one new key, `aura_deletions`, so a delta pull can finally describe
-- rows that were DELETED since the watermark (0003_deletions_tombstones.sql).
--
-- `create or replace` with the identical name/signature, so no client change
-- is needed beyond decoding the extra key — nothing has to re-point at a v2
-- endpoint. 0002 stays in the tree as the historical record of the delta pull
-- landing; this file is the live definition.
--
-- CONTRACT DELTA vs 0002 (everything else is unchanged — see that file's header):
--   'aura_deletions': [ { "table_name": <text>, "row_key": <text>,
--                         "deleted_at": "<iso>" }, ... ]
--   Rows where `user_id = auth.uid() AND deleted_at > since`. `row_key` is the
--   deleted row's client-side key: id::text, day_iso, or 'singleton'.
--   Like every other key it is ALWAYS present — `[]` when nothing was deleted.
--
-- ORDERING REQUIREMENT (enforced client-side in
-- SupabaseSyncService.applyDeletions): tombstones must be applied BEFORE the
-- per-table merge, and the local-only re-push must skip anything tombstoned in
-- the same cycle — otherwise the pull that carries a deletion is also the pull
-- that pushes the row straight back up.
--
-- SECURITY: still `security invoker` — `aura_deletions` carries the same
-- owner-only RLS policy as every other table, so a forged `since` can no more
-- surface another user's deletions than it can their rows.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once.

create or replace function pull_changes(since timestamptz)
returns jsonb
language sql
security invoker
stable
as $$
  select jsonb_build_object(
    -- MARK: Many-row tables (own uuid id)
    'aura_workout_logs', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_workout_logs where user_id = auth.uid() and updated_at > since
    ),
    'aura_measurements', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_measurements where user_id = auth.uid() and updated_at > since
    ),
    'aura_personal_records', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_personal_records where user_id = auth.uid() and updated_at > since
    ),
    'aura_progress_photos', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_progress_photos where user_id = auth.uid() and updated_at > since
    ),
    'aura_programs', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_programs where user_id = auth.uid() and updated_at > since
    ),
    'aura_plans', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_plans where user_id = auth.uid() and updated_at > since
    ),
    'aura_exercises', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_exercises where user_id = auth.uid() and updated_at > since
    ),
    -- MARK: Day-keyed tables (day_iso instead of id)
    'aura_day_overrides', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day_iso', day_iso, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_day_overrides where user_id = auth.uid() and updated_at > since
    ),
    'aura_quick_logs', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day_iso', day_iso, 'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_quick_logs where user_id = auth.uid() and updated_at > since
    ),
    -- MARK: Singleton tables (one row per user; no id/day_iso emitted)
    'aura_body_stats', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_body_stats where user_id = auth.uid() and updated_at > since
    ),
    'aura_user_profile', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_user_profile where user_id = auth.uid() and updated_at > since
    ),
    'aura_preferences', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'payload', payload,
        'updated_at', to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_preferences where user_id = auth.uid() and updated_at > since
    ),
    -- MARK: Tombstones (0003) — deletions, not rows. No payload to carry.
    'aura_deletions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'table_name', table_name, 'row_key', row_key,
        'deleted_at', to_char(deleted_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )), '[]'::jsonb)
      from aura_deletions where user_id = auth.uid() and deleted_at > since
    )
  );
$$;
