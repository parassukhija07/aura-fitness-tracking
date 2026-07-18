-- 0001_init_schema.sql
-- Aura Fitness — H8 full remote sync schema.
-- One table per Codable model. Every table has: id (or composite/singleton PK),
-- user_id (FK -> auth.users, cascade delete), payload jsonb, updated_at timestamptz.
-- RLS is enabled on every table with a single "owner only" policy for all commands.
--
-- Run via `supabase db push` (project must be linked with `supabase link` first),
-- or paste this file's contents into the Supabase Dashboard SQL editor and run once.

-- MARK: - Shared trigger: bump updated_at on every UPDATE so LWW timestamps are
-- always server-truth, even if a client forgets to set it.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- MARK: - Many-row tables (own uuid id)

create table if not exists aura_workout_logs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_workout_logs enable row level security;
create policy "owner_all" on aura_workout_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_workout_logs_user_updated on aura_workout_logs (user_id, updated_at);
create trigger trg_aura_workout_logs_updated_at
  before update on aura_workout_logs
  for each row execute function set_updated_at();

create table if not exists aura_measurements (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_measurements enable row level security;
create policy "owner_all" on aura_measurements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_measurements_user_updated on aura_measurements (user_id, updated_at);
create trigger trg_aura_measurements_updated_at
  before update on aura_measurements
  for each row execute function set_updated_at();

create table if not exists aura_personal_records (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_personal_records enable row level security;
create policy "owner_all" on aura_personal_records
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_personal_records_user_updated on aura_personal_records (user_id, updated_at);
create trigger trg_aura_personal_records_updated_at
  before update on aura_personal_records
  for each row execute function set_updated_at();

-- O2 default: base64 image blob lives inside the JSONB payload (simplest v1).
-- Flagged limitation: large photo volume should migrate to Supabase Storage +
-- a URL reference in a follow-up pass; out of scope this pass.
create table if not exists aura_progress_photos (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_progress_photos enable row level security;
create policy "owner_all" on aura_progress_photos
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_progress_photos_user_updated on aura_progress_photos (user_id, updated_at);
create trigger trg_aura_progress_photos_updated_at
  before update on aura_progress_photos
  for each row execute function set_updated_at();

create table if not exists aura_programs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_programs enable row level security;
create policy "owner_all" on aura_programs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_programs_user_updated on aura_programs (user_id, updated_at);
create trigger trg_aura_programs_updated_at
  before update on aura_programs
  for each row execute function set_updated_at();

create table if not exists aura_plans (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_plans enable row level security;
create policy "owner_all" on aura_plans
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_plans_user_updated on aura_plans (user_id, updated_at);
create trigger trg_aura_plans_updated_at
  before update on aura_plans
  for each row execute function set_updated_at();

create table if not exists aura_exercises (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_exercises enable row level security;
create policy "owner_all" on aura_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_exercises_user_updated on aura_exercises (user_id, updated_at);
create trigger trg_aura_exercises_updated_at
  before update on aura_exercises
  for each row execute function set_updated_at();

-- MARK: - Keyed-by-ISO-date tables (composite PK, no uuid)

create table if not exists aura_day_overrides (
  user_id uuid not null references auth.users(id) on delete cascade,
  day_iso text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, day_iso)
);
alter table aura_day_overrides enable row level security;
create policy "owner_all" on aura_day_overrides
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_day_overrides_user_updated on aura_day_overrides (user_id, updated_at);
create trigger trg_aura_day_overrides_updated_at
  before update on aura_day_overrides
  for each row execute function set_updated_at();

create table if not exists aura_quick_logs (
  user_id uuid not null references auth.users(id) on delete cascade,
  day_iso text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, day_iso)
);
alter table aura_quick_logs enable row level security;
create policy "owner_all" on aura_quick_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_aura_quick_logs_user_updated on aura_quick_logs (user_id, updated_at);
create trigger trg_aura_quick_logs_updated_at
  before update on aura_quick_logs
  for each row execute function set_updated_at();

-- MARK: - Singleton tables (PK = user_id, exactly one row per user)

create table if not exists aura_body_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_body_stats enable row level security;
create policy "owner_all" on aura_body_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_aura_body_stats_updated_at
  before update on aura_body_stats
  for each row execute function set_updated_at();

create table if not exists aura_user_profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_user_profile enable row level security;
create policy "owner_all" on aura_user_profile
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_aura_user_profile_updated_at
  before update on aura_user_profile
  for each row execute function set_updated_at();

create table if not exists aura_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table aura_preferences enable row level security;
create policy "owner_all" on aura_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger trg_aura_preferences_updated_at
  before update on aura_preferences
  for each row execute function set_updated_at();
