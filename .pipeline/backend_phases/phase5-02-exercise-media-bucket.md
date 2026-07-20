# BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
One owner decision documented, not blocking: sourcing licensed exercise images. The pipeline below works with ANY image set dropped into `supabase/seed/exercise-media/`; shipping real imagery is a content task, not a code task.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). Frontend spec 06-02 renders exercise thumbnails via `RemoteExerciseImage` from `ExerciseEntry.imageURL`, with a gradient fallback when the URL is empty. Today `imageURL` values are empty or point at arbitrary external hosts. This feature gives images a first-party home: a PUBLIC Supabase Storage bucket `exercise-media`, seeded from a repo folder, with catalog rows (phase5-01) carrying the public URLs. Read path is plain HTTPS — no auth, CDN-cached by Supabase.
- **Existing Patterns to Match:**
  - `supabase/migrations/0006_progress_photos_storage.sql` (phase3-01) — storage policy DDL style. New migration `supabase/migrations/0008_exercise_media_bucket.sql`.
  - `supabase/seed/generate_seed.py` (phase5-01) — the seed generator emitting catalog SQL; extend it to inject image URLs.
- **Data Schemas / Type Definitions:**
  - Object path convention: `exercise-media/{exercise_uuid}.jpg` (UUIDv5 id from phase5-01 — filename IS the join key; no DB column needed).
  - Storage policies (migration):
    ```sql
    create policy "exercise_media_public_read" on storage.objects for select
      using (bucket_id = 'exercise-media');
    -- NO insert/update/delete policies: uploads via service role only (seeding script/CLI).
    ```
  - Public URL shape consumed by the client: `https://<project-ref>.supabase.co/storage/v1/object/public/exercise-media/<uuid>.jpg` — written into each catalog row's `payload.imageURL` by the seed generator when a matching image exists; left `""` otherwise (client gradient fallback covers it).
- **API Request/Response Contracts:**
  - **Endpoint:** `GET /storage/v1/object/public/exercise-media/{uuid}.jpg`
  - **Headers:** none required (public bucket).
  - **Payload Structure:** n/a (GET).
  - **Success Response (200):** raw JPEG bytes, `Content-Type: image/jpeg`, long-lived cache headers (Supabase default).
  - **Error Responses:** 404 `{"statusCode":"404","error":"not_found","message":"Object not found"}` → client `RemoteExerciseImage` falls back to gradient (already specced in frontend 06-02 — no client change needed); 400 malformed path → same fallback.

## 📝 FILES TO MODIFY
### `supabase/seed/generate_seed.py` (from phase5-01)
- Add: scan `supabase/seed/exercise-media/` for `<normalized-name>.jpg` files; match to exercises via the same name-normalization used for UUIDv5 ids; for each match emit `payload.imageURL = <public URL>` into the catalog seed SQL, and emit an upload manifest `supabase/seed/upload_media.sh` with one `supabase storage cp ./exercise-media/<file> ss:///exercise-media/<uuid>.jpg` line per image (owner runs once after bucket creation).
- `<project-ref>` from CLI argument (`--project-ref`), never hardcoded.
### `AuraFitness/Models/ExerciseDatabase.swift`
- No structural change: `imageURL` flows through the phase5-01 catalog refresh into `RemoteExerciseImage` (frontend 06-02). Verify only that empty `imageURL` short-circuits to gradient without a network attempt (rule lives in the frontend component).

## 📄 FILES TO CREATE
### `supabase/migrations/0008_exercise_media_bucket.sql`
- **Purpose:** the public-read policy above; header documents bucket creation (`supabase storage buckets create exercise-media --public` or Dashboard) and service-role-only write posture.
### `supabase/seed/exercise-media/README.md`
- **Purpose:** folder contract: drop `<exercise-name>.jpg` (lowercase, spaces→`-`), ≤ 200 KB each, 4:3 or square, licensing must permit redistribution; then run `generate_seed.py --project-ref <ref>` and `upload_media.sh`.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Public bucket = zero-auth reads; NEVER place user content here. phase3-02's `USER_BUCKETS` list must NOT contain `exercise-media` (deliberate exclusion from delete-account cleanup).
- Write lockdown: RLS enabled + no write policies = anon/user uploads rejected; only service role writes. Verify with an anon-key upload attempt (expect 403).
- Image size discipline: 200 KB cap keeps the grid fast on cellular; generator WARNS (not fails) on oversized files.
- Missing image is a NORMAL permanent state (custom exercises, new catalog entries) — every consumer treats 404/empty URL as gradient fallback, never an error surface.
- Cache invalidation: same-path replacement may serve stale for CDN TTL — acceptable; forced refresh = upload under a new versioned name + update catalog row (documented in README).
