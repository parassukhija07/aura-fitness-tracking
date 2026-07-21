-- 0006_progress_photos_storage.sql
-- Aura Fitness — owner-only policies for the `progress-photos` Storage bucket.
--
-- WHY: progress photos currently live as base64 JPEG blobs inside
-- `aura_progress_photos.payload` (the limitation flagged in 0001_init_schema.sql).
-- Every sync ships the full image through JSONB, and 0005 had to leave that
-- table's payload CHECK constraints NOT VALID because real rows already exceed
-- the cap. This migration prepares the destination: photo BYTES move to
-- Storage, and the table row keeps metadata plus a storage path.
--
-- OWNER MANUAL STEP — RUN BEFORE THIS MIGRATION:
-- the bucket itself cannot be created from SQL. Create it PRIVATE, either:
--     supabase storage buckets create progress-photos --private
-- or Dashboard -> Storage -> New bucket -> name `progress-photos`, Public OFF.
-- Applying this file without the bucket is harmless — the policies simply
-- never match anything — but uploads will 404 until it exists.
--
-- PATH CONVENTION (load-bearing, do not change):
--     progress-photos/{user_id}/{photo_uuid}.jpg
-- The FIRST path segment must be the owner's uid. Every policy below keys on
-- `(storage.foldername(name))[1] = auth.uid()::text`, so the uid prefix is
-- what enforces isolation. The client builds paths only from `auth.uid()` and
-- a freshly generated UUID — never from user input — and these policies hold
-- the line server-side regardless of what any client sends.
--
-- FOLLOW-UP once the client migration has drained (phase3-01 client half):
-- `aura_progress_photos` payloads become metadata-only, so 0005's constraints
-- can finally be validated and the 3 MB cap tightened to 64 KB:
--     alter table aura_progress_photos validate constraint aura_progress_photos_payload_is_object;
--     alter table aura_progress_photos drop constraint aura_progress_photos_payload_max_size;
--     alter table aura_progress_photos add constraint aura_progress_photos_payload_max_size
--       check (octet_length(payload::text) <= 65536);
--     alter table aura_progress_photos validate constraint aura_progress_photos_payload_max_size;
-- Do NOT run that until no row still carries base64 — it would reject every
-- legacy write and wedge those clients' sync queues.
--
-- Orphaned objects (upload succeeded, row never arrived) are swept by
-- phase3-02's delete-account/storage cleanup.
--
-- Re-runnable: every policy is dropped before being recreated.
--
-- Run via `supabase db push` (project must be linked with `supabase link`
-- first), or paste this file's contents into the Supabase Dashboard SQL editor
-- and run once.

-- MARK: - Owner-only access to progress-photos objects
--
-- Four separate policies rather than one `for all`: Storage checks SELECT on
-- download, INSERT on upload, UPDATE on upsert-overwrite, and DELETE on
-- remove, and keeping them apart makes it obvious which verb is being granted.
-- `storage.objects` already has RLS enabled by Supabase.

drop policy if exists "photos_owner_select" on storage.objects;
create policy "photos_owner_select" on storage.objects
  for select
  using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "photos_owner_insert" on storage.objects;
create policy "photos_owner_insert" on storage.objects
  for insert
  with check (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE needs BOTH clauses: `using` decides which existing rows the update can
-- see, `with check` validates the post-update row. Omitting the second would
-- let a caller move an object out of their own folder.
drop policy if exists "photos_owner_update" on storage.objects;
create policy "photos_owner_update" on storage.objects
  for update
  using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "photos_owner_delete" on storage.objects;
create policy "photos_owner_delete" on storage.objects
  for delete
  using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
