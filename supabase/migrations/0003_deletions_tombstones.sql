
-- 0003_deletions_tombstones.sql
-- Aura Fitness — deletion tombstones. Stops deleted rows resurrecting.
--
-- THE BUG THIS FIXES: `updated_at > since` (0002_pull_changes_rpc.sql) can only
-- describe rows that still EXIST. Device B, offline while device A deletes a
-- row, still holds that row locally; its next pull sees nothing about the
-- deletion, keeps the row, and re-pushes it on the next local write — the
-- deleted data comes back. Every hard delete now also writes a row into
-- `aura_deletions`, and pulling clients apply those tombstones BEFORE their
-- per-table merge (see SupabaseSyncService.applyDeletions).
--
-- WHY A TRIGGER (not a client-side insert): capturing the tombstone in the
-- database means out-of-band deletes — Supabase Dashboard, SQL editor, the
-- delete-account edge function, `wipeRemote` bulk deletes — all tombstone
-- correctly without every caller remembering to.
--
-- RETENTION: tombstones are kept 90 days, purged opportunistically from the
-- trigger (~1 call in 1000). A device offline for longer than that can still
-- resurrect a row; accepted, because its first pull after such a gap is a
-- watermark-less FULL pull and LWW bounds the damage.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once.

-- MARK: - Tombstone table
--
-- row_key is text (not uuid) because the 12 aura_* tables have three different
-- key shapes. It stores exactly what the client's `Table` enum keys a row by:
--   many-row tables  -> id::text
--   day-keyed tables -> day_iso            (aura_day_overrides, aura_quick_logs)
--   singleton tables -> the literal 'singleton'
--                       (aura_body_stats, aura_user_profile, aura_preferences)
create table if not exists aura_deletions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  table_name text not null,
  row_key    text not null,
  deleted_at timestamptz not null default now(),
  primary key (user_id, table_name, row_key)
);
alter table aura_deletions enable row level security;
-- Same owner-only policy every 0001 table carries. Dropped first so this
-- migration is re-runnable against a database that already has the table.
drop policy if exists "owner_all" on aura_deletions;
create policy "owner_all" on aura_deletions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- Serves the `user_id = auth.uid() and deleted_at > since` scan pull_changes does.
create index if not exists idx_aura_deletions_user_deleted on aura_deletions (user_id, deleted_at);

-- MARK: - Retention
--
-- `security definer` so it can clear EVERY user's expired tombstones: called
-- both opportunistically from record_deletion() (as some individual user) and,
-- optionally, from a pg_cron schedule. Deleting only rows older than the
-- retention window means it can never race a live sync.
create or replace function purge_old_deletions()
returns void
language sql
security definer
set search_path = public
as $$
  delete from aura_deletions where deleted_at < now() - interval '90 days';
$$;

-- MARK: - Shared after-delete trigger
--
-- SECURITY: intentionally `security invoker` (the default) — it runs as
-- whoever performed the delete and inserts `old.user_id`, which for a
-- client-initiated delete is `auth.uid()`, so the owner-only policy above
-- accepts it. Dashboard/service-role deletes bypass RLS entirely.
--
-- Fires on DELETE only, so an upsert that recreates a previously-deleted id
-- cannot re-trigger it (no loop). The stale tombstone left behind is harmless:
-- the client compares the recreated row's `updated_at` against `deleted_at`
-- and the newer one wins.
create or replace function record_deletion()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_key text;
begin
  if tg_table_name in ('aura_day_overrides', 'aura_quick_logs') then
    v_key := old.day_iso;
  elsif tg_table_name in ('aura_body_stats', 'aura_user_profile', 'aura_preferences') then
    v_key := 'singleton';
  else
    v_key := old.id::text;
  end if;

  begin
    insert into aura_deletions (user_id, table_name, row_key, deleted_at)
    values (old.user_id, tg_table_name, v_key, now())
    on conflict (user_id, table_name, row_key)
    do update set deleted_at = now();
  exception
    when foreign_key_violation then
      -- The auth.users row is already gone: this DELETE is the cascade from an
      -- account deletion. There is no client left to tell, and raising here
      -- would abort the account deletion — so drop the tombstone silently.
      return old;
  end;

  -- Opportunistic retention sweep, ~1 delete in 1000, so no single caller pays
  -- for it often and no external scheduler is required.
  if random() < 0.001 then
    perform purge_old_deletions();
  end if;

  return old;
end;
$$;

-- MARK: - Attach to all 12 aura_* tables
--
-- Enumerated in one loop rather than 12 hand-written blocks so a new table can
-- never be attached with a subtly different definition. `aura_deletions`
-- itself is deliberately absent — tombstones are not themselves tombstoned.
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
    execute format('drop trigger if exists trg_%s_record_deletion on %I', t, t);
    execute format(
      'create trigger trg_%s_record_deletion after delete on %I
         for each row execute function record_deletion()', t, t);
  end loop;
end;
$$;
