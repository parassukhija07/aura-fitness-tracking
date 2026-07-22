-- 0007_function_hardening.sql
-- Aura Fitness — closes the four findings the Supabase database linter reports
-- against 0001/0003/0004. No schema, contract, or client change: every function
-- keeps its name, signature, and return shape, so nothing in
-- SupabaseSyncService has to move.
--
-- THE ONE THAT ACTUALLY MATTERED (lints 0028 + 0029):
--   `purge_old_deletions()` is `security definer` and, like every freshly
--   created function, was left with the PostgreSQL default of `EXECUTE` granted
--   to PUBLIC. PostgREST exposes anything in the `public` schema, so it was
--   reachable as `POST /rest/v1/rpc/purge_old_deletions` by BOTH `anon` and
--   `authenticated` — i.e. by anyone holding the anon key, which ships inside
--   the app binary. Running as definer, it then deleted tombstones for EVERY
--   user, not just the caller's.
--   Bounded, but not acceptable: it only removes rows already older than the
--   90-day retention window, which 0003's header explicitly treats as
--   expendable. The worst outcome is that a device offline for >90 days
--   resurrects a row — a case 0003 already documents as accepted.
--
-- WHY `record_deletion()` FLIPS TO `security definer` IN THE SAME FILE:
--   It is `security invoker` and calls `perform purge_old_deletions()`. Revoke
--   EXECUTE from `authenticated` on its own and that nested call starts
--   throwing `permission denied for function purge_old_deletions` — inside an
--   AFTER DELETE trigger, which aborts the DELETE. Because the call is gated on
--   `random() < 0.001`, roughly one delete in a thousand would fail, at random,
--   for one user at a time. The two changes are only safe together.
--
--   Definer is safe here on its own merits: the function returns `trigger`, so
--   PostgREST cannot expose it as an RPC; it fires only from AFTER DELETE on
--   the 12 aura_* tables, whose RLS policies already decide which rows a caller
--   may delete; and the value it inserts (`old.user_id`) is read off the row
--   that was actually deleted, never from caller-supplied input. Running as
--   owner also removes the previous dependency on the `owner_all` policy
--   accepting the insert.
--
-- THE OTHER TWO (lint 0011, `function_search_path_mutable`):
--   `set_updated_at()` and `pull_changes()` had no `search_path` pinned. Both
--   are `security invoker`, so the classic search-path hijack (shadow a table
--   or operator, get it resolved with the definer's rights) does not apply —
--   this is hygiene, not an open hole. Pinned anyway, matching the
--   `set search_path = public` already used by 0003's functions.
--
-- ⚠️ SUPERSEDES the function definitions in 0001 and 0003. Re-running 0003
-- alone would restore `record_deletion()` to `security invoker` and reintroduce
-- the intermittent-delete failure described above. Re-run this file after it.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once. Safe to re-run.

-- MARK: - Lint 0011 — pin search_path on set_updated_at (0001)
--
-- Body is byte-identical to 0001; only the `set search_path` clause is new.
create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- MARK: - Lint 0011 — pin search_path on pull_changes (0004)
--
-- `alter function` rather than a full `create or replace`: the body is ~100
-- lines of jsonb_build_object that 0004 owns, and duplicating it here would
-- create two definitions to keep in step. This changes only the config, so
-- 0004 remains the single source of truth for the contract.
alter function pull_changes(timestamptz) set search_path = public;

-- MARK: - Lints 0028/0029 — make record_deletion run as owner (0003)
--
-- Body is byte-identical to 0003 apart from the added `security definer`.
-- MUST be applied before the revoke below, so no delete can land in the window
-- where EXECUTE is gone but the trigger still runs as the caller.
create or replace function record_deletion()
returns trigger
language plpgsql
security definer
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
  -- for it often and no external scheduler is required. Reaches
  -- purge_old_deletions() through this function's owner rights, which is why
  -- the revoke below does not break it.
  if random() < 0.001 then
    perform purge_old_deletions();
  end if;

  return old;
end;
$$;

-- MARK: - Lints 0028/0029 — take purge_old_deletions off the public API
--
-- `from public` is the one that matters: PostgreSQL grants EXECUTE to PUBLIC on
-- every new function, and `anon`/`authenticated` inherit it. The two explicit
-- revokes cover the case where a grant was also made directly to those roles.
-- `create or replace` preserves an existing ACL, so re-running 0003 will NOT
-- silently re-open this.
--
-- Nothing loses a capability it should have had: the only intended caller is
-- record_deletion() (now definer-owned, above), plus any pg_cron schedule,
-- which runs as a superuser.
revoke execute on function purge_old_deletions() from public;
revoke execute on function purge_old_deletions() from anon;
revoke execute on function purge_old_deletions() from authenticated;
