# BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Bucket creation itself is an owner-manual step (Dashboard or `supabase` CLI) — the migration below creates the policies; document the bucket-creation command in the migration header.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). Progress photos currently live as base64 JPEG blobs inside `aura_progress_photos.payload` JSONB (and as blobs in UserDefaults locally) — flagged limitation in `0001_init_schema.sql` (~line 66). This feature moves photo BYTES to a private Storage bucket `progress-photos`; the table row keeps metadata + storage path only. Unblocks frontend Phase 4 (Progress tab photo compare, spec `04-04`) at real photo volumes.
- **Existing Patterns to Match:**
  - `supabase/migrations/0001_init_schema.sql` — DDL style. New migration `supabase/migrations/0006_progress_photos_storage.sql`.
  - `AuraFitness/Sync/SupabaseSyncService.swift` — error classification + offline queue idioms (photo uploads get the same retry semantics).
  - `AuraFitness/Progress/ProgressPhotosView.swift` + the photo model in `AuraFitness/Models/ProgressModels.swift` (`ProgressPhoto`) — current fields and blob read/write sites.
- **Data Schemas / Type Definitions:**
  - Storage object path convention (exact): `progress-photos/{user_id}/{photo_uuid}.jpg` — first path segment MUST be the uid for the policies below.
  - Storage RLS policies (in migration, on `storage.objects`):
    ```sql
    create policy "photos_owner_select" on storage.objects for select
      using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);
    -- same shape for insert (with check), update, delete
    ```
  - `ProgressPhoto` model change: add `var storagePath: String? = nil`; base64 field becomes optional/legacy (kept for decode compatibility). Rows with `storagePath` set carry NO base64.
- **API Request/Response Contracts:**
  - **Endpoint:** `POST /storage/v1/object/progress-photos/{uid}/{uuid}.jpg` (SDK: `client.storage.from("progress-photos").upload(path:data:)`); download `.download(path:)`; delete `.remove(paths:)`.
  - **Headers:** `Authorization: Bearer <user JWT>`, `Content-Type: image/jpeg`
  - **Payload:** raw JPEG bytes (client compresses to ≤ 1 MB target, quality-stepped down until under cap).
  - **Success (200):** `{"Key":"progress-photos/<uid>/<uuid>.jpg"}`
  - **Errors:** 403 `{"statusCode":"403","error":"Unauthorized","message":"new row violates row-level security policy"}` (path uid ≠ auth uid — treat as bug, never retry); 404 `{"statusCode":"404","error":"Bucket not found","message":"..."}` → photo stays local + base64 fallback (bucket not yet created by owner); 413 payload too large → recompress harder once, then keep local-only.

## 📝 FILES TO MODIFY
### `AuraFitness/Models/ProgressModels.swift` + photo store (where `progressPhotos` persists in `AppState`)
- Add `storagePath`; on save of a NEW photo: write locally as today, then async upload → on success set `storagePath`, strip base64 from the synced payload, `syncPush` metadata row.
- Lazy migration of EXISTING photos: on launch (signed-in), for each photo with base64 and no `storagePath`: upload, update row, strip base64. Max 3 concurrent; resume next launch if interrupted.
### `AuraFitness/Progress/ProgressPhotosView.swift`
- Display path: local cache first; else download by `storagePath` (cache to `FileManager` caches dir); else legacy base64.
### `AuraFitness/Sync/SupabaseSyncService.swift`
- Pull-merge for `aura_progress_photos`: a row with `storagePath` and no local bytes triggers background download ON DEMAND (not eagerly during sync).

## 📄 FILES TO CREATE
### `supabase/migrations/0006_progress_photos_storage.sql`
- **Purpose:** the 4 owner-only storage policies + header documenting: bucket creation (`supabase storage buckets create progress-photos --private` or Dashboard), path convention, and that `phase1-03`'s 3 MB payload cap on `aura_progress_photos` can be validated + tightened to 64 KB in a follow-up once migration completes.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Path traversal: client constructs paths ONLY from `auth.uid()` + fresh UUID — never user input; policies enforce the uid prefix server-side regardless.
- Upload succeeded but metadata push failed (crash between): reconcile on launch — photo with local `storagePath` but remote row lacking it re-pushes metadata; orphaned storage objects are cleaned by phase3-02's sweep (cross-ref).
- Offline: photo saves never block on upload; pending-upload queue survives relaunch (persist pending photo ids alongside the existing sync-queue pattern).
- Guest (signed-out) users: photos stay local-only; sign-in triggers the lazy migration sweep.
- Delete photo: remove storage object AND table row; if object removal fails, retry opportunistically (phase3-02 orphan sweep is the backstop).
