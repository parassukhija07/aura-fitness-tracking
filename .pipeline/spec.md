# IMPLEMENTATION SPEC

Feature: H8 (scoped UP, full remote) — Introduce Supabase email/password auth (with email confirmation) AND full remote data sync of every user model to Supabase (keyed by `user_id`), plus real Export / Reset / Delete Account / Log Out replacing the stubs at `AuraFitness/Profile/ProfileSettingsScreens.swift`. This is the app's first network layer, first remote data, and first backend dependency.

---

## ⚠️ OPEN QUESTIONS

All five prior blocking questions are RESOLVED (see decisions below). Only genuinely-open, low-risk items remain — none block starting; the Coder proceeds with the stated defaults and flags in review if reality differs.

### RESOLVED decisions (locked)
- **R1 — Data scope: FULL REMOTE SYNC.** Every user model migrates to Supabase tables keyed by `user_id`. Sync model = **local-first with write-through** (see ARCHITECTURE). NOT auth-only.
- **R2 — Delete Account: Edge Function** `delete-account` using the `service_role` key (source written in this spec; user deploys).
- **R3 — Email confirmation REQUIRED** on sign-up. Login blocked until confirmed.
- **R4 — Pre-account local data is PRESERVED** and back-filled to Supabase on first login (one-time migration, not a wipe).
- **R5 — Secrets via `Secrets.xcconfig` → Info.plist** (git-ignored).

### STILL-OPEN (non-blocking — proceed with the stated default)
- **O1 — Exact Postgres table names.** This spec uses snake_case `aura_*` table names (below). If the user's Supabase project has a naming convention, rename consistently in the SQL migration + the `table:` string constants in `SupabaseSyncService`. Default: use the names as written.
- **O2 — `progress_photos` storage location.** `ProgressPhoto.imageData` is raw `Data` (`ProgressModels.swift:7`). Storing base64 blobs in a Postgres JSONB column is functional but heavy. Default for v1: store the row in `aura_progress_photos` with the image as base64 in the JSONB payload (simplest, matches every other table). **Flagged limitation:** if photo volume is large this should move to Supabase Storage buckets with a URL reference — OUT OF SCOPE this pass, noted for a follow-up. Proceed with base64-in-JSONB.
- **O3 — Conflict resolution granularity.** v1 uses **last-write-wins per row via `updated_at`** (see limitations). This can silently drop a concurrent edit made on another device between pulls. Accepted for v1; NOT silently — surfaced here as a known limitation. No per-field merge.

---

## 🏗️ ARCHITECTURE & PATTERNS

### Sync model: local-first with write-through (v1)
- **Local stores stay the source of truth for all UI reads.** No view is rearchitected. `ProgramDatabase.shared`, `UserPlanDatabase.shared`, `ExerciseDatabase.shared`, and `AppState`'s `@Published` collections continue to drive every screen exactly as today. This is deliberate: it avoids touching dozens of views and keeps the UI synchronous and offline-usable.
- **Write-through:** every existing mutation that already calls `persist()` (or assigns a `@Published` with a `didSet` persister) additionally enqueues a **push** of the affected row(s) to Supabase. Pushes go through a central `SupabaseSyncService` that is fire-and-forget from the caller's perspective (never blocks UI, never throws into the store).
- **Pull + reconcile:** on successful login and on app foreground/launch (while signed in), `SupabaseSyncService.pullAll()` fetches remote rows for the user and reconciles into the local stores using **last-write-wins by `updated_at`** (row-level). After reconcile, the stores re-`persist()` locally so disk matches.
- **Offline queue:** mutations while offline (or on push failure) are appended to a durable local queue (`aura_sync_queue_v1` in UserDefaults). The queue flushes on the next successful network op (login, foreground pull, or a successful push). UI never waits on the network.

### EXPLICITLY OUT OF SCOPE (state clearly to the user)
- **No real-time / live multi-device sync.** There is NO Supabase Realtime subscription. Changes on device B appear on device A only after device A next pulls (launch/foreground). A user editing on two devices simultaneously can lose the older write (last-write-wins). This is a periodic pull + write-through push model, not live sync.
- **No per-field conflict merge**, no operational transforms, no CRDTs. Row-level last-write-wins only.
- **No offline auth for a brand-new device** (email confirm + first login require network); once a session exists in Keychain the app is fully usable offline (all reads are local).

### Existing patterns to match
- **Singletons:** `ProgramDatabase` / `UserPlanDatabase` / `ExerciseDatabase` (`AuraFitness/Models/ProgramDatabase.swift`, `ExerciseDatabase.swift`): `@MainActor final class ... : ObservableObject`, `static let shared`, private `storageKey`, `private func persist()`, `private init { load() }`. New services (`AuthService`, `SupabaseSyncService`) follow this shape.
- **Root env injection:** `AuraFitnessApp.swift:5-11`.
- **Settings UI building blocks + confirm sheets:** `ProfileSettingsScreens.swift` (`SettingsScreenScaffold`, `SettingsGroup`, `SettingsRowLabel`, `ProfileConfirmSheet`), toast pattern (`ToastCenter` + `.auraToast`), `AuraPrimaryButton` / `AuraGrayButton` / `AuraDangerButton`. Reuse for auth screens.
- **All models are already `Codable`** (`ProgressModels.swift`, `LogDayModel.swift`, `WorkoutModels.swift`, `PlanModels.swift`, `ExerciseDatabase.swift`) — so each maps to a JSONB payload with zero new serialization code. This is why the schema below stores each struct as a JSONB `payload` column rather than fully-normalized columns: the structs contain nested arrays (`WorkoutLog.exercises: [Exercise]`, `QuickLog.exercises: [QuickLogExercise]`, `UserPlan.weekSchedule: [Int: UUID?]`) that would be painful and brittle to normalize, and the app never queries inside them server-side.

### Core strategy
`AuthService.shared` wraps `supabase-swift`'s `auth`. `ContentView` is gated behind `sessionState`. `SupabaseSyncService.shared` owns all table push/pull + the offline queue. Each local store gains thin `pushRow`/`applyRemote` hooks. The four `ProfileConfirmSheet` stubs get real bodies: Export (`ShareLink` over local JSON), Reset (`DataResetService` — local wipe + optional remote wipe), Delete (`AuthService.deleteAccount()` Edge Function + local+remote wipe), Log Out (`AuthService.signOut()`).

---

## 🗄️ SUPABASE SCHEMA (SQL migration — file to create, see FILES TO CREATE)

**Design rule:** one table per Codable model. Common columns on every table:
- `id uuid primary key` — the model's own `id` (UUID) where it has one; for keyed dictionaries (dayOverrides/quickLogs keyed by ISO string) and singletons (BodyStats, UserProfile) see per-table notes.
- `user_id uuid not null references auth.users(id) on delete cascade`
- `payload jsonb not null` — the full `Codable` struct encoded as JSON.
- `updated_at timestamptz not null default now()` — drives last-write-wins.
- **RLS enabled on every table**, with a single policy per table: `using (auth.uid() = user_id) with check (auth.uid() = user_id)` for all of SELECT/INSERT/UPDATE/DELETE. No row is ever visible or writable across users.

Tables (names per O1 default):

| Table | Source model (file) | `id` semantics | Cardinality per user |
|---|---|---|---|
| `aura_workout_logs` | `WorkoutLog` (`ProgressModels.swift:13`) | model `id` uuid | many |
| `aura_measurements` | `Measurement` (`ProgressModels.swift:23`) | model `id` uuid | many |
| `aura_personal_records` | `PersonalRecord` (`ProgressModels.swift:137`) | model `id` uuid | many |
| `aura_progress_photos` | `ProgressPhoto` (`ProgressModels.swift:4`) | model `id` uuid | many (see O2) |
| `aura_programs` | `Program` (`ProgramDatabase.swift` / `WorkoutModels.swift`) | model `id` uuid | many |
| `aura_plans` | `UserPlan` (`ProgramDatabase.swift` / `PlanModels.swift`) | model `id` uuid | many (≤3, L7) |
| `aura_exercises` | `ExerciseEntry` (`ExerciseDatabase.swift:5`) | model `id` uuid | many |
| `aura_day_overrides` | `DayOverride` (`LogDayModel.swift:7`) | **synthetic**: `iso` string is the natural key → PK `(user_id, day_iso text)`, no uuid | many, keyed by ISO date |
| `aura_quick_logs` | `QuickLog` (`LogDayModel.swift:36`) | **synthetic**: PK `(user_id, day_iso text)` | many, keyed by ISO date |
| `aura_body_stats` | `BodyStats` (`ProgressModels.swift:77`) | **singleton**: PK = `user_id` | exactly one |
| `aura_user_profile` | `UserProfile` (`ProgressModels.swift:122`) | **singleton**: PK = `user_id` | exactly one |
| `aura_preferences` | AppState pref scalars (see below) | **singleton**: PK = `user_id` | exactly one |

Notes:
- `aura_day_overrides` / `aura_quick_logs`: replace the `id uuid` column with `day_iso text not null`; composite PK `(user_id, day_iso)`. Payload is the `DayOverride` / `QuickLog` struct. The ISO key is `AppState.iso(date)` format `yyyy-MM-dd` (`AppState.swift:494-498`).
- `aura_body_stats` / `aura_user_profile` / `aura_preferences`: singletons — PK is `user_id` itself (upsert on conflict `user_id`). Payload is the whole struct.
- `aura_preferences` payload = the `WorkoutPrefs` blob defined at `AppState.swift:46-62` PLUS the three scalar prefs (`darkModePreference`, `calendarStartDay`, `logDisplayMode`). Mirror the existing `WorkoutPrefs` Codable shape so encoding is trivial.
- Give every table `updated_at` a `before update` trigger to bump it to `now()` (SQL function `set_updated_at()`), so server-side writes also refresh the LWW timestamp.

---

## 📄 FILES TO CREATE

### `supabase/migrations/0001_init_schema.sql`  (SQL — infra, allowed)
- **Purpose:** Create all 12 tables above, enable RLS, add the per-table `user_id = auth.uid()` policies, the `set_updated_at()` trigger function + triggers. Written per Supabase migration convention.
- Must be runnable via `supabase db push` (or pasted into the Supabase SQL editor). Document both in the deploy notes.
- For singleton/composite tables, use the PKs described above. Add index `(user_id, updated_at)` on the multi-row tables to make pull queries efficient.

### `supabase/functions/delete-account/index.ts`  (Deno / TypeScript — infra, allowed)
- **Purpose:** Server-side account deletion using `service_role`. The anon client cannot delete an auth user; this runs privileged.
- **Contract:**
  - Method `POST`, requires `Authorization: Bearer <user JWT>` (attached automatically by the app's SDK call).
  - Verify the JWT → resolve `uid`. Reject (401) if missing/invalid.
  - Using a `service_role` Supabase admin client, call `auth.admin.deleteUser(uid)`. The `on delete cascade` FKs on every `aura_*` table wipe all remote user data automatically.
  - Return `200 {"ok": true}` on success; `4xx/5xx {"error": "..."}` otherwise. Handle CORS (Supabase Edge Function standard headers).
- **Source to write in the file** (standard Supabase Edge Function shape):
  - `import { serve } from "https://deno.land/std/http/server.ts"` and `createClient` from `@supabase/supabase-js`.
  - Read `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` from `Deno.env` (auto-injected in the Edge runtime — NOT hardcoded).
  - Create an admin client with the service role key; a second client with the caller's JWT to identify the user (`auth.getUser(jwt)`), then `adminClient.auth.admin.deleteUser(user.id)`.
- **Manual deploy step (user must run — planner/coder cannot):**
  - `supabase functions deploy delete-account` (project linked via `supabase link`).
  - Document that the function inherits the project's `SERVICE_ROLE_KEY` env automatically; no secret is committed.

### `AuraFitness/Auth/AuthConfig.swift`
- Reads `SUPABASE_URL` + `SUPABASE_ANON_KEY` from `Info.plist` (injected from `Secrets.xcconfig`). No literals. `fatalError` in DEBUG if missing; non-crashing config-error gate in RELEASE. (Same as prior revision.)
- ```
  enum AuthConfig {
      static var supabaseURL: URL
      static var supabaseAnonKey: String
  }
  ```

### `AuraFitness/Auth/AuthService.swift`
- **Purpose:** Auth + session single source of truth. SDK Keychain session persistence (do not roll custom).
- ```
  @MainActor
  final class AuthService: ObservableObject {
      static let shared = AuthService()
      enum SessionState: Equatable { case loading; case signedOut; case awaitingEmailConfirmation(email: String); case signedIn(userID: String, email: String) }
      @Published private(set) var sessionState: SessionState = .loading
      @Published var lastError: String? = nil
      let client: SupabaseClient        // built from AuthConfig
      var userID: String?               // convenience for SupabaseSyncService

      private init()
      func restoreSession() async
      func signUp(email: String, password: String) async -> Bool   // → .awaitingEmailConfirmation on success (R3)
      func signIn(email: String, password: String) async -> Bool   // fails if email unconfirmed → surfaces message
      func signOut() async
      func deleteAccount() async -> Bool   // invoke("delete-account"); on success signOut
  }
  ```
- **R3 behavior:** `signUp` success sets `.awaitingEmailConfirmation(email:)`, NOT `.signedIn`. `signIn` for an unconfirmed account: map the SDK "Email not confirmed" error to a clear message ("Please confirm your email — check your inbox.") in `lastError`, keep `.signedOut`.
- **First-login migration hook (R4):** on the transition INTO `.signedIn` (from restore or signIn), call `SupabaseSyncService.shared.onSignedIn(userID:)` (see below) which decides push-backfill vs pull.
- Map SDK errors to human strings; never surface raw dumps.

### `AuraFitness/Auth/AuthGateView.swift`
- Pre-auth root. Shows splash while `.loading`; login/sign-up forms when `.signedOut`; a "Check your email to confirm your account" screen when `.awaitingEmailConfirmation` (with a "Resend"/"Back to login" affordance). Reuse `AuraPrimaryButton`, `ToastCenter`, and the field style from `AccountDetailsView.swift:121-135`. Errors → toast (match `ProfileTabView.swift:91-96`). This is a NEW screen above the tab bar.

### `AuraFitness/Sync/SupabaseSyncService.swift`
- **Purpose:** All table push/pull + the offline queue + first-login migration. Fire-and-forget from stores.
- ```
  @MainActor
  final class SupabaseSyncService: ObservableObject {
      static let shared = SupabaseSyncService()
      enum Table: String { case workoutLogs = "aura_workout_logs", measurements = "aura_measurements", personalRecords = "aura_personal_records", progressPhotos = "aura_progress_photos", programs = "aura_programs", plans = "aura_plans", exercises = "aura_exercises", dayOverrides = "aura_day_overrides", quickLogs = "aura_quick_logs", bodyStats = "aura_body_stats", userProfile = "aura_user_profile", preferences = "aura_preferences" }

      @Published private(set) var syncing = false
      @Published private(set) var lastPullAt: Date? = nil

      private init()

      /// Enqueue a write-through upsert of one encodable row (fire-and-forget; queues on failure/offline).
      func push<T: Encodable>(_ value: T, id: String, table: Table)
      /// Enqueue a delete of one row by id.
      func delete(id: String, table: Table)

      /// Pull every table for the current user and reconcile into local stores (LWW by updated_at).
      func pullAll() async

      /// Called by AuthService on first sign-in this session. Detects an empty remote
      /// (fresh account) → BACKFILL all local data up (R4). Otherwise → pullAll() reconcile.
      func onSignedIn(userID: String) async

      /// Flush the durable offline queue (aura_sync_queue_v1). Called after any successful net op.
      func flushQueue() async
  }
  ```
- **Queue durability:** `aura_sync_queue_v1` (UserDefaults) holds an ordered array of pending ops `{table, id, action(upsert|delete), payloadJSON, queuedAt}`. Coalesce duplicate (table,id) upserts (keep latest). Flush on: successful login, foreground pull, any successful push.
- **Reconcile (LWW):** for each pulled row, compare remote `updated_at` to the local record's effective timestamp. Since local models mostly lack an `updated_at` field, track a parallel local `aura_local_ts_v1` map keyed by `table:id` updated on every local mutation; if absent, treat remote as authoritative on first pull. Newer wins; write the winner to the local store (which re-persists) and, if local won, push it up.
- **onSignedIn / R4 backfill:** query counts across the user's tables. If ALL remote tables are empty for this user (fresh account) AND local stores are non-empty → push everything local up (backfill), stamping `updated_at = now()`. Otherwise run `pullAll()` reconcile (which still merges any local-only rows up via LWW). This makes pre-account local data survive and become the account's data.

### `AuraFitness/Profile/DataArchive.swift`  (unchanged from prior revision — local JSON export)
- `DataArchive` Codable aggregate of all collections + a `preferences` snapshot; `DataArchiveBuilder.writeTempFile(_:) -> URL?` for `ShareLink`. Export reads LOCAL stores (which are the source of truth), so it needs no network. (Full interface as in prior spec; unchanged.)

### `AuraFitness/Profile/DataResetService.swift`
- **Purpose:** Real `resetAll(workoutOnly:)`. Now also optionally clears REMOTE rows.
- ```
  enum DataResetService {
      @MainActor static func resetAll(workoutOnly: Bool, appState: AppState, alsoRemote: Bool)
  }
  ```
- Local wipe: identical UserDefaults key set + singleton reloads as documented in FILES TO MODIFY (see key enumeration below).
- **Remote wipe (`alsoRemote == true`):** delete the corresponding tables' rows for the current user via `SupabaseSyncService` deletes (workout-data tables for `workoutOnly`, all tables for full reset). If offline, enqueue the deletes. Delete Account does NOT use this path — it relies on the Edge Function's `on delete cascade`.

### `AuraFitness/Sync/Syncable.swift` (small helper, optional)
- A tiny protocol/util giving each store a uniform `syncPush(_:)` call and a `stringID` for the row key, to keep the per-store hooks one-liners. Not required if the Coder inlines the `SupabaseSyncService.shared.push(...)` calls.

---

## 📝 FILES TO MODIFY

### `AuraFitness/AuraFitnessApp.swift` (14 lines)
- Inject `AuthService.shared` and `SupabaseSyncService.shared` via `.environmentObject` alongside `appState`.
- Gate: `.signedIn` → `ContentView`; `.awaitingEmailConfirmation`/`.signedOut` → `AuthGateView`; `.loading` → splash. Keep `.environmentObject(appState)` on the authed view.
- On becoming active (`ScenePhase .active`) while signed in → `Task { await SupabaseSyncService.shared.pullAll() }` (foreground pull).

### `AuraFitness/Models/ProgramDatabase.swift`
- **Write-through:** in `addProgram/updateProgram/deleteProgram/addWorkout/updateWorkout/deleteWorkout/addExercise/removeExercise/reorderExercises` (lines 32-90) — after each `persist()`, call `SupabaseSyncService.shared.push(program, id: program.id.uuidString, table: .programs)` for the affected program (or `.delete` for deletes). Simplest: push the whole affected `Program` row on any change (it's one JSONB row).
- **Apply-remote:** add `func applyRemote(_ programs: [Program])` that replaces `self.programs` + `persist()` WITHOUT re-pushing (guard against push loop — add an `isApplyingRemote` flag like the existing `isLoading` guard in AppState at `AppState.swift:65`).
- **Reset:** add public `resetToSeed()` (seed = `SeedData.programs`) and `hardReset()` (drop customs); both reassign `programs` + `persist()`.
- Same set of additions to **`UserPlanDatabase`** (lines 122-258): write-through on every mutating method (`addPlan/updatePlan/deletePlan/setDefault/setWorkout/setRestDay/clearDay/addCustomWorkout/updateCustomWorkout/deleteCustomWorkout/addExercise/removeExercise/addPlan(from:)`), `applyRemote(_ plans:)`, `resetToSeed()` (re-seed default plan from `SeedData.programs.first` as boot does at lines 252-256 — never leave `plans` empty).

### `AuraFitness/Models/ExerciseDatabase.swift`
- Write-through in `add/update/delete/toggleFavorite` (lines 80-100) → push the `ExerciseEntry` row (table `.exercises`). `applyRemote(_ entries:)`. Add `hardReset()` (`entries = Self.seedEntries(); persist()`, distinct from `resetToSeed()` at line 146 which preserves customs).

### `AuraFitness/Models/AppState.swift`
- Every `@Published` collection with a persister `didSet` (`workoutLogs:181`, `dayOverrides:187`, `quickLogs:191`, `measurements:194`, `bodyStats:197`, `personalRecords:200`, `userProfile:203`, `progressPhotos:207`, and the pref scalars) additionally push through `SupabaseSyncService`:
  - Row-collections (workoutLogs, measurements, personalRecords, progressPhotos): the `didSet` fires on whole-array assignment; to push only changed rows, add small helper mutators OR (simplest v1) diff old vs new in `didSet` and push added/changed rows + delete removed rows. Flag: whole-array `didSet` makes per-row diffing the cleanest correctness path — implement a `syncDiff(old:new:table:idOf:)` helper.
  - Keyed dicts (dayOverrides, quickLogs): push per changed key using `day_iso` as the row id.
  - Singletons (bodyStats, userProfile, preferences blob): upsert the single row on change.
  - **Guard the push during `isLoading` and during remote-apply** (extend the existing `isLoading` guard at `AppState.swift:65,128,134`; add an `isApplyingRemote` flag) so pulling from Supabase doesn't immediately re-push.
- Add `func applyRemote(...)` entry points AppState-side for each collection used by `SupabaseSyncService.pullAll()`.
- The pref scalars (`weightUnit`…`googleHealthConnected`, `darkModePreference`, `calendarStartDay`, `logDisplayMode`) already funnel through `persistWorkoutPrefs()`/`persist()`; add a single `SupabaseSyncService.push(prefsBlob, id: userID, table: .preferences)` call there.

### `AuraFitness/ActiveWorkout/WorkoutPersistence.swift`
- The live-workout blob (`aura_wk`/`aura_elapsed`/`aura_run_start`/`aura_pill`/`aura_wk_version`) is transient session state, **not synced** (an in-progress workout is device-local until saved; on save it becomes a `WorkoutLog` which IS synced). Document this explicitly — no push hooks here.
- Extend `clearWorkout()` (lines 113-118) to also remove `aura_pill` + `aura_wk_version` (for the reset path), as in the prior revision.

### `AuraFitness/Profile/ProfileSettingsScreens.swift` — the stub site
- Add `@EnvironmentObject var appState: AppState` + `@EnvironmentObject var authService: AuthService` to `ProfileConfirmSheet` (line 281). Verify BOTH presentation sites (`ProfileTabView.swift:87-89`, `AccountDetailsView.swift:113-115`) re-inject the environment onto the sheet content.
- **`exportSheet` (318-334):** replace the flash button (329-331) with a `ShareLink` over `DataArchiveBuilder.writeTempFile(appState)` (built in `.task`, stored in `@State exportURL`). (Unchanged from prior revision.)
- **`resetSheet` (337-382):**
  - Workout-only (344-352) → `DataResetService.resetAll(workoutOnly: true, appState: appState, alsoRemote: true)`.
  - Reset everything (355-377) → `DataResetService.resetAll(workoutOnly: false, appState: appState, alsoRemote: true)`. Recommend a confirmation alert before the full wipe.
- **`destructiveSheet(delete:)` (385-418):**
  - Delete (408-410): `Task { if await authService.deleteAccount() { DataResetService.resetAll(workoutOnly: false, appState: appState, alsoRemote: false) } else { flash(authService.lastError ?? "Delete failed") } }`. Remote data is wiped by the Edge Function's cascade, so `alsoRemote: false` here. Order: remote delete succeeds → local wipe → sign-out (auto-gates to login). On failure: no wipe, no sign-out, show error. Update copy (399-401) to reflect that this erases the account and all synced + local data.
  - Log Out (412-414): `Task { await authService.signOut() }`. Do NOT wipe local data (it stays for the next login on this device and is already backed up remotely). Sign-out flips `sessionState` → gate shows login.
  - Wrap async calls in `Task`, guard with `@State busy` to disable buttons in-flight.

### `AuraFitness/Profile/AccountDetailsView.swift`
- Same sheet is presented here (113-115) — ensure `appState` + `authService` are injected into `ProfileConfirmSheet`. No other change.

### `AuraFitness/ContentView.swift`
- No structural change required (it renders only when signed-in). Optionally surface a subtle "syncing…" indicator bound to `SupabaseSyncService.syncing`. Not required for sign-off.

---

## 📊 EXACT UserDefaults KEYS FOR LOCAL RESET (verified — enumerate literally)

(Unchanged from prior revision — still needed for the local half of reset/delete.)

**WORKOUT-DATA keys (cleared in BOTH reset modes; matching remote tables also wiped when `alsoRemote`):**
- `aura_program_db_v1` (`ProgramDatabase.swift:13`) → table `aura_programs`
- `aura_plans_db_v1` (`ProgramDatabase.swift:128`) → `aura_plans`
- `aura_wk`,`aura_elapsed`,`aura_run_start`,`aura_pill`,`aura_wk_version` (`WorkoutPersistence.swift:9-13`) → NOT synced
- `aura_workout_logs_v1` (`AppState.swift:34`) → `aura_workout_logs`
- `aura_day_overrides_v1` (`AppState.swift:35`) → `aura_day_overrides`
- `aura_quick_logs_v1` (`AppState.swift:36`) → `aura_quick_logs`
- `aura_personal_records_v1` (`AppState.swift:39`) → `aura_personal_records`
- `aura_exercise_db_v1` (`ExerciseDatabase.swift:49`) → `aura_exercises` (reseed locally after clear)

**PROFILE / MEASUREMENT / SETTINGS keys (full-reset ONLY; KEPT in workoutOnly):**
- `aura_measurements_v1` (`AppState.swift:37`) → `aura_measurements`
- `aura_body_stats_v1` (`AppState.swift:38`) → `aura_body_stats`
- `aura_user_profile_v1` (`AppState.swift:40`) → `aura_user_profile`
- `aura_progress_photos_v1` (`AppState.swift:41`) → `aura_progress_photos`
- `aura_workout_prefs_v1` (`AppState.swift:42`) → `aura_preferences`
- `aura_dark`,`aura_calstart`,`aura_logstat` (`AppState.swift:31-33`) → folded into `aura_preferences`
- `aura_seeded_missed_v1` (dead key, `AppState.swift:28`) — remove opportunistically
- **New sync-infra keys** (cleared on full reset): `aura_sync_queue_v1`, `aura_local_ts_v1`.

**Post-clear reload (CRITICAL):** clearing a UserDefaults key does NOT update the in-memory `@Published` singletons — every reset MUST reassign store state via `resetToSeed()`/`hardReset()` and reset AppState collections to defaults; call `appState.exitWorkout()` (`AppState.swift:398`) first if a session is live; never leave `UserPlanDatabase.plans` empty (re-seed default plan).

---

## 🛡️ EDGE CASES TO HANDLE

- **Session restore flash:** `.loading` renders a splash, not the login form (authed users must not see a login flash each launch). Do not default to `.signedOut`.
- **Email-unconfirmed login (R3):** `signIn` on an unconfirmed account must surface "confirm your email", not a raw SDK error, and keep the user on the gate.
- **First-login backfill vs pull (R4):** `onSignedIn` must correctly distinguish a FRESH remote (empty → backfill local up) from a RETURNING user (non-empty → pull + LWW reconcile). Getting this wrong either loses pre-account data or clobbers cloud data. When in doubt, LWW merge (never blind-overwrite) so both directions are preserved.
- **Push loop / echo:** applying pulled remote rows into local stores triggers their `persist()`/`didSet`, which must NOT re-push. Guard every store with an `isApplyingRemote` flag (mirror the `isLoading` guard at `AppState.swift:65`). Missing this creates an infinite push↔pull loop.
- **Offline mutations:** every push is fire-and-forget; failures/offline enqueue to `aura_sync_queue_v1` and NEVER block or throw into the UI. Flush on next successful net op. Coalesce duplicate (table,id) upserts.
- **Whole-array `didSet` on AppState collections:** assigning the entire array fires one `didSet`; naive "push everything" on every keystroke is wasteful and racy. Diff old vs new and push only changed/added rows + delete removed rows.
- **Delete Account partial failure:** remote-delete (Edge Function) must SUCCEED before any local wipe or sign-out. On failure: no wipe, stay signed in, show error. Wrong order orphans an account with lost local data.
- **Reset while a workout is live:** call `appState.exitWorkout()` before clearing keys so no stale session re-persists post-wipe.
- **In-memory vs disk desync after reset:** reassign singleton `@Published` state (via new reset methods), don't just delete keys — otherwise the wiped data stays on screen.
- **`progress_photos` size (O2):** base64 blobs in JSONB can be large and slow to push/pull; keep the temp-file export path off the main thread and consider batching/limiting photo sync. Flagged as a v1 limitation; Storage-bucket migration is a follow-up.
- **LWW data loss (O3, out-of-scope realtime):** concurrent edits on two devices between pulls can silently drop the older write. This is an ACCEPTED v1 limitation of the periodic-pull + write-through model — communicated here, not hidden. No live subscription this pass.
