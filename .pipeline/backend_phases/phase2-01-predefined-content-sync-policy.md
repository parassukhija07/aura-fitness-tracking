# BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only

## ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS
None. Policy pre-decided: predefined (seeded) programs and bundled catalog exercises NEVER sync per-user; only user-created or user-modified copies do. Rationale: every device re-seeds identical predefined content locally, so pushing it wastes rows/bandwidth for zero information.

## 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS
- **Context for Opus 4.8:** Aura Fitness (SwiftUI iOS + Supabase). `ProgramDatabase` seeds predefined programs on device (`Program.isPredefined == true`); `ExerciseDatabase` seeds the bundled exercise library (`ExerciseEntry.isCustom == false`). The sync layer (`AuraFitness/Sync/Syncable.swift` + write-through `syncPush` hooks in the stores) currently pushes ANY saved row to `aura_programs`/`aura_exercises` — including predefined/bundled content. This feature scopes sync to user-owned rows and cleans up already-duplicated remote rows. Unblocks frontend Phase 3 (Plan tab) at scale.
- **Existing Patterns to Match:**
  - `AuraFitness/Sync/Syncable.swift` — `syncPush(table:)` helper.
  - `AuraFitness/Models/ProgramDatabase.swift` / `AuraFitness/Models/ExerciseDatabase.swift` — locate every `syncPush` / `SupabaseSyncService.shared.push` call site (grep) plus the pull-merge entry points where remote rows land back in the stores.
  - `AuraFitness/Models/WorkoutModels.swift` — `Program.isPredefined`; `AuraFitness/Models/ExerciseDatabase.swift` — `ExerciseEntry.isCustom`.
- **Data Schemas / Type Definitions:** No schema change. Ownership predicate (client-side, single source of truth — add as extensions):
  - `Program.isSyncable: Bool` → `!isPredefined`
  - `ExerciseEntry.isSyncable: Bool` → `isCustom`
  - `UserPlan`: always syncable (user-owned by definition). Plans reference workouts by id — verify `weekSchedule` resolves on a FRESH device after pull, which requires predefined content to re-seed with STABLE ids. If seeded UUIDs are random per install, that is a BLOCKER to fix first: seed with deterministic UUIDs (UUIDv5 of a fixed namespace + program/workout name — check `SeedData.swift`/`ProgramDatabase.swift`) and migrate local stores.
- **API Request/Response Contracts:**
  - **Endpoint:** none new. One-time remote cleanup via existing PostgREST deletes:
  - `DELETE /rest/v1/aura_programs?user_id=eq.<uid>&payload->>isPredefined=eq.true`
  - `DELETE /rest/v1/aura_exercises?user_id=eq.<uid>&payload->>isCustom=eq.false`
  - **Success:** 204 (or 200) empty body. **Errors:** 401 (signed out — skip cleanup, retry next session); network failure — retry next launch. Guard with UserDefaults flag `aura_predefined_cleanup_done_v1`, set ONLY on success.

## 📝 FILES TO MODIFY
### `AuraFitness/Models/ProgramDatabase.swift` + `AuraFitness/Models/ExerciseDatabase.swift`
- Gate every push call site: `guard item.isSyncable else { return }` (or filter in bulk-push loops).
- Pull-merge side: when a remote row decodes to `isPredefined == true` / `isCustom == false` (legacy rows from devices predating this fix), IGNORE it (don't overwrite local seed) — belt-and-braces against stale remote data.
### `AuraFitness/Sync/SupabaseSyncService.swift`
- Add `func cleanupPredefinedRemoteRows() async` implementing the two deletes behind the `aura_predefined_cleanup_done_v1` flag; call once from the post-sign-in sync path (same place the backfill runs).
- Note: these deletes generate tombstones via phase1-02 triggers — harmless (pull-side ignore rule above also covers them).

## 📄 FILES TO CREATE
None.

## 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS
- Deterministic seed ids are the load-bearing assumption for cross-device plan references — VERIFY before shipping (fresh-install simulator + existing account: default plan's week schedule must resolve every workout). Random-per-install ids → implement UUIDv5 seeding first.
- User EDITS a predefined program: the edit flow must produce a user-owned copy (the existing "add to My Plans to edit" flow should already enforce this — if any path mutates a predefined `Program` in place, route it through a copy instead).
- Cleanup deletes use `payload->>` JSON filters — verify supabase-swift's filter builder supports arrow operators with proper URL encoding; else fall back to fetch-ids-then-delete-by-id.
- Cleanup idempotent and safe to re-run (flag set only on confirmed success; deletes naturally idempotent).
