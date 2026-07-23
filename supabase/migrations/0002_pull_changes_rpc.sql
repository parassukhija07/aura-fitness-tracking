-- 0002_pull_changes_rpc.sql
-- Aura Fitness — B1 incremental sync: one RPC returns every row changed since a
-- client-held watermark, replacing the 12 full-table pulls `pullAll()` does on
-- every foreground/login with a single request.
--
-- CONTRACT (mirrored by the Swift client in SupabaseSyncService.pullChanges):
--   pull_changes(since timestamptz) -> jsonb
--   Returns ONE json object keyed by table name. Every one of the 12 aura_*
--   tables is ALWAYS present as a key — an empty array when nothing changed —
--   so the client decoder is total and never special-cases a missing key.
--   Each array element is:
--     many-row tables : { "id": <uuid>,      "payload": {...}, "updated_at": "<iso>" }
--     day-keyed tables: { "day_iso": <text>, "payload": {...}, "updated_at": "<iso>" }
--                       (aura_day_overrides, aura_quick_logs)
--     singleton tables: { "payload": {...}, "updated_at": "<iso>" }  (no id/day_iso)
--                       (aura_body_stats, aura_user_profile, aura_preferences)
--   Rows are scoped to `user_id = auth.uid() AND updated_at > since`.
--   `updated_at` is emitted as an ISO-8601 UTC millisecond string
--   (YYYY-MM-DDTHH24:MI:SS.mmmZ) so the client parses it without ambiguity.
--   First pull sends since = '1970-01-01T00:00:00.000Z' (pull everything).
--
-- SECURITY: `security invoker` (NEVER definer) — the function runs as the
-- caller, so the existing owner-only RLS on every table keeps enforcing
-- per-user isolation. A forged `since` can never surface another user's rows.
--
-- LIMITATION: `updated_at > since` cannot express deletions — a row deleted
-- since the watermark simply won't appear, so a stale client keeps it. This is
-- EXPECTED and fixed by the companion tombstones migration (phase1-02). Do NOT
-- add ad-hoc delete detection here.
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
    )
  );
$$;
