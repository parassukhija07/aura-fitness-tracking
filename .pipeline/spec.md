# IMPLEMENTATION SPEC

Feature 1: Guest mode + local-to-cloud migration on first sign-in.
Feature 2: Round-trippable CSV templates for all 5 backup categories.

This spec is grounded in the real repo. Every path below was verified to exist (or is a
new sibling of a verified file). The Coder must not invent additional files or types.

---

## ⚠️ OPEN QUESTIONS

These are genuine blocking ambiguities. Where an answer is needed to proceed, a **DEFAULT
DECISION** is stated so the Coder is never blocked — implement the default unless a human
overrides it before coding.

1. **CSV vs existing JSON archive — is CSV a REPLACEMENT or an ADDITION?**
   The existing export (`DataArchive.swift` + `ProfileSettingsScreens.swift` export sheet)
   produces a single JSON file via `ShareLink`. Feature 2 asks for CSVs.
   **DEFAULT DECISION:** ADD CSV export/import alongside the existing JSON archive. Do NOT
   remove or alter the JSON path. CSV is a second export option (5 CSV files, zipped) and a
   new import option. The JSON archive remains the loss-less full backup (it carries binary
   progress-photo blobs and preferences that do not belong in CSV).

2. **Round-trip fidelity limit.** `WorkoutLog.exercises` and `Program.workouts[].exercises`
   are deeply nested (`Exercise` has `sets`, `warmup`, `history`, `lastPR`, `target`).
   A flat CSV cannot losslessly represent arbitrary nesting without a serialization convention.
   **DEFAULT DECISION:** CSV is row-per-set for workout history and row-per-exercise for
   programs/custom-workouts, using the explicit column schemas in section "CSV SCHEMAS" below.
   Fields not present as columns are NOT round-tripped through CSV (they are only in the JSON
   archive). This is acceptable because CSV's stated purpose is the 5 human-readable data
   categories, not a byte-exact clone.

3. **Guest sign-in conflict when the account already has cloud data.** A guest accumulates
   local data, then signs into an EXISTING account that already has rows in Supabase.
   **DEFAULT DECISION (stated explicitly, kept simple):** UNION-MERGE, local-wins-on-id-collision
   is NOT used; instead reuse the existing engine — see "MERGE / UPLOAD STRATEGY". No new
   conflict UI. All local guest rows keep their existing UUIDs and are pushed up; the existing
   `SupabaseSyncService.onSignedIn` reconcile (LWW by `updated_at`) decides per-row winners.
   Distinct ids (the normal case for guest-created data) never collide, so both sets survive.

If a human wants different behavior for (1)/(3), flag before coding. Otherwise proceed with defaults.

---

## 🏗️ ARCHITECTURE & PATTERNS

- **Existing patterns to match (copy style/shape from these EXACT files):**
  - Singleton store shape (`@MainActor final class ... : ObservableObject { static let shared }`):
    `AuraFitness/Models/ProgramDatabase.swift`, `AuraFitness/Models/ExerciseDatabase.swift`,
    `AuraFitness/Sync/SupabaseSyncService.swift`.
  - Export builder writing a temp file off-main-thread for `ShareLink`:
    `AuraFitness/Profile/DataArchive.swift` (`DataArchiveBuilder.writeTempFile`).
  - Auth session state machine + first-login hook:
    `AuraFitness/Auth/AuthService.swift` (`SessionState`, `transitionToSignedIn` → `SupabaseSyncService.shared.onSignedIn`).
  - Root gate switch on `authService.sessionState`:
    `AuraFitness/AuraFitnessApp.swift` (`switch authService.sessionState { case .signedIn: ContentView() ... default: AuthGateView() }`).
  - Pre-auth screen UI + `AuraPrimaryButton` / `AuraGrayButton` usage:
    `AuraFitness/Auth/AuthGateView.swift`.
  - Reset / key-enumeration authority (source of truth for every UserDefaults key):
    `AuraFitness/Profile/DataResetService.swift`.
  - Local→cloud backfill already exists:
    `AuraFitness/Sync/SupabaseSyncService.swift` (`onSignedIn`, `backfillLocalToRemote`, `hasAnyLocalData`).

- **Core strategy:**
  - **Feature 1:** Guest mode is a THIRD terminal auth state (`.guest`) alongside `.signedIn`.
    The entire app already runs against LOCAL stores (all UI reads local; sync is fire-and-forget),
    so guest mode is simply: skip the login screen, set a persisted `aura_guest_mode_v1` flag, and
    render `ContentView` without a `userID`. Every existing local store already works with no
    `userID` (`SupabaseSyncService.push` early-returns `guard let uid = userID else { return }`).
    On first successful sign-in from guest, the ALREADY-EXISTING `onSignedIn` → `backfillLocalToRemote`
    / `pullAll` path performs the local-to-cloud migration with zero new merge logic.
  - **Feature 2:** New `CSVArchive` builder + parser, invoked from the existing Export sheet
    (new "Export as CSV" button) and a new "Import Data" sheet (file picker). Reuses the same
    local stores that `DataArchiveBuilder` reads and the same store CRUD methods for import.

---

## 📝 FILES TO MODIFY

### `AuraFitness/Auth/AuthService.swift`
- **Changes:**
  - Add case `case guest` to `enum SessionState: Equatable`.
  - Add persisted guest flag. Add `private let guestKey = "aura_guest_mode_v1"`.
  - Add `func continueAsGuest()`: sets `UserDefaults.standard.set(true, forKey: guestKey)` and
    `sessionState = .guest`. No network. Must be `@MainActor` (class already is).
  - In `restoreSession()`: BEFORE trying `client.auth.session`, if
    `UserDefaults.standard.bool(forKey: guestKey) == true` AND there is no restorable session,
    set `sessionState = .guest` and return. Order: try Keychain session first (a real session
    always beats guest); on the `catch` branch, check the guest flag → `.guest` if set, else `.signedOut`.
  - In `signIn(...)` and `signUp→signIn` success path (i.e. `transitionToSignedIn`): after a
    successful sign-in, clear the guest flag: `UserDefaults.standard.set(false, forKey: guestKey)`.
    (Migration itself is already triggered inside `transitionToSignedIn` via `onSignedIn`.)
  - In `signOut()`: also clear the guest flag (a signed-out user is neither guest nor signed-in;
    they return to `.signedOut` / the login form).
  - `userID` computed property stays as-is (returns nil for `.guest`) — this is what makes every
    `SupabaseSyncService.push` a local-only no-op while in guest mode.

### `AuraFitness/AuraFitnessApp.swift`
- **Changes:**
  - Extend the root `switch authService.sessionState`: add `case .guest: ContentView().environmentObject(appState)`
    (identical to the `.signedIn` arm). The `default:` arm continues to show `AuthGateView()`.
  - In the `.onChange(of: scenePhase)` foreground-pull block, the existing
    `guard phase == .active, authService.userID != nil else { return }` already correctly SKIPS the
    pull for guests (`userID == nil`). No change needed there — but add a code comment stating that
    guest mode intentionally does not pull.

### `AuraFitness/Auth/AuthGateView.swift`
- **Changes:**
  - Add a `.guest` arm to the `switch authService.sessionState` (mirror the existing `.signedIn`
    comment: unreachable because `AuraFitnessApp` gates it directly; keep `splash` for exhaustiveness).
  - In `AuthFormView.body`, below the existing "Don't have an account? Sign up" button, add a
    tertiary `Button` labeled **"Skip for now — use as guest"** styled like the existing accent link
    (`AuraFont.secondary()`, `.foregroundColor(.aura.text2)`). Its action calls
    `authService.continueAsGuest()`.
  - No new dependencies; reuse existing `AuraSpacing`, `AuraFont`, `.aura.*` colors.

### `AuraFitness/Profile/ProfileSettingsScreens.swift`
- **Changes:**
  - In `enum` of sheet `kind` (the one with `.export/.reset/.delete/.logout`), add `case importData`.
  - Add a matching `detentHeight` value for `.importData` (use `360`).
  - Add a `content` switch arm: `case .importData: importSheet`.
  - Extend `exportSheet`: add a second button **"Export as CSV"** beneath the existing JSON
    `ShareLink`. It builds via `CSVArchiveBuilder.writeTempZip(appState)` (new, section below) and
    wraps the resulting `URL` in a `ShareLink`. Follow the EXACT `.task { exportURL = await ... }`
    + `ShareLink(item:)` pattern already used for JSON. Use a separate `@State private var csvExportURL: URL?`.
  - Add `importSheet` (new computed view): explains "Import a JSON archive or CSV files exported
    from Aura." with a single button **"Choose File"** that presents a `.fileImporter`
    (see MOBILE CONCERNS for allowed content types). On selection, calls
    `DataImportService.importFile(at:appState:)` (new). Show the returned summary via the existing
    `flash(...)` helper (e.g. "Imported 42 workouts, 3 programs").
  - Add an entry point to open the import sheet: in whatever Settings list row group currently
    opens the export sheet, add a sibling row "Import Data" that sets the sheet kind to `.importData`.
    (The Coder must locate the row that triggers `.export` in this same file and mirror it.)
  - For guest users, the export/import rows must be VISIBLE and functional (guest data is local and
    fully exportable). No gating on `authService.userID` for these rows.

### `AuraFitness/Profile/DataArchive.swift`
- **Changes:** None to the struct. Add nothing here. (CSV lives in a new file to keep this file
  the single JSON-archive authority.)

---

## 📄 FILES TO CREATE

### `AuraFitness/Profile/CSVArchive.swift`
- **Purpose:** Build the 5 CSV files from local stores and zip them for `ShareLink`. Mirrors
  `DataArchiveBuilder.writeTempFile` (off-main-thread, returns `URL?`, nil on failure).
- **Signatures/Interfaces:**
  ```swift
  enum CSVArchiveBuilder {
      /// Writes 5 CSV files into a temp folder, zips them, returns the zip URL.
      /// Returns nil on failure so the caller degrades gracefully.
      @MainActor static func writeTempZip(_ appState: AppState) async -> URL?

      /// Individual category serializers (pure, testable, no I/O).
      /// Each returns a full CSV string INCLUDING the header row.
      static func workoutHistoryCSV(_ logs: [WorkoutLog]) -> String
      static func programsCSV(_ programs: [Program]) -> String          // custom (isPredefined == false) only
      static func customWorkoutsCSV(_ plans: [UserPlan]) -> String       // plan.customWorkouts flattened
      static func customExercisesCSV(_ entries: [ExerciseEntry]) -> String // isCustom == true only
      static func measurementsCSV(_ measurements: [Measurement]) -> String
  }
  ```
- **Rules:**
  - Zip filename: `AuraFitness-CSV-Export-<epoch>.zip`. Inner files named exactly:
    `workout_history.csv`, `programs.csv`, `custom_workouts.csv`, `custom_exercises.csv`,
    `body_measurements.csv`.
  - Zipping: use `Foundation`'s `FileManager` + Apple's `NSFileCoordinator` `.forUploading` trick to
    zip a directory (no third-party dependency). If the Coder cannot zip without a dependency,
    **DEFAULT DECISION:** produce 5 separate CSV files and return a folder URL is NOT allowed by
    `ShareLink(item:)` for multiple files cleanly — so fall back to a single combined CSV bundle is
    also not desired. Use `NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: folderURL, options: .forUploading, ...)` which yields a single `.zip` URL. This is a stdlib-only zip and MUST be used.
  - CSV escaping: RFC-4180. Any field containing `,` `"` newline is wrapped in double quotes and
    internal `"` doubled. Provide one shared `csvField(_ s: String) -> String` helper.
  - Dates: ISO-8601 (`yyyy-MM-dd'T'HH:mm:ssZ`) using a single shared `ISO8601DateFormatter`, matching
    `DataArchiveBuilder`'s `.iso8601` JSON strategy so JSON and CSV agree.
  - Numeric optionals (`Double?`, `Int?`): empty string when nil (NOT "0", so round-trip distinguishes
    "no value" from "zero").

### `AuraFitness/Profile/CSVParser.swift`
- **Purpose:** Parse a single CSV string into `[[String]]` rows, RFC-4180 compliant (handles quoted
  fields, embedded commas/newlines/escaped quotes). Pure, no I/O, unit-testable.
- **Signatures/Interfaces:**
  ```swift
  enum CSVParser {
      /// Returns rows of fields. First row is the header. Throws on malformed quoting.
      static func parse(_ text: String) throws -> [[String]]
      enum CSVError: Error { case malformed(line: Int) }
  }
  ```

### `AuraFitness/Profile/DataImportService.swift`
- **Purpose:** Single entry point for importing either a JSON archive OR a CSV file/zip. Maps parsed
  rows back into the real stores using their existing CRUD (so sync + persistence fire correctly).
- **Signatures/Interfaces:**
  ```swift
  @MainActor
  enum DataImportService {
      struct ImportSummary { var workouts = 0; var programs = 0; var customWorkouts = 0
                             var customExercises = 0; var measurements = 0; var skipped = 0 }

      /// Detects file type by extension/UTType, routes to the right importer,
      /// returns a human summary string for the toast. Never throws into UI —
      /// returns a summary with a failure note on error.
      static func importFile(at url: URL, appState: AppState) async -> String

      // Internal, per-category (each MERGE-not-replace; see IMPORT SEMANTICS):
      static func importJSONArchive(_ data: Data, appState: AppState) -> ImportSummary
      static func importWorkoutHistory(_ rows: [[String]], appState: AppState) -> Int
      static func importPrograms(_ rows: [[String]]) -> Int
      static func importCustomWorkouts(_ rows: [[String]]) -> Int
      static func importCustomExercises(_ rows: [[String]]) -> Int
      static func importMeasurements(_ rows: [[String]], appState: AppState) -> Int
  }
  ```
- **IMPORT SEMANTICS (must be implemented exactly):**
  - **Security-scoped resource:** files from `.fileImporter` require
    `let ok = url.startAccessingSecurityScopedResource()` before reading and
    `defer { if ok { url.stopAccessingSecurityScopedResource() } }`. Failing to do this makes the
    read silently return empty on-device.
  - **Zip:** if the picked file is a `.zip`, unzip to a temp dir (reuse the `NSFileCoordinator`
    approach in reverse, or `Archive`-free: iterate expected inner filenames). Then import each
    inner CSV by filename → category. Unknown inner files are skipped (count into `skipped`).
  - **Row → store mapping:**
    - Workout history rows → group by `workout_log_id`; reconstruct a `WorkoutLog` per group with an
      `Exercise` per distinct `exercise_name` within the group and a `WorkoutSet` per row. Append via
      `appState.workoutLogs.append(...)` ONLY if a log with that id does not already exist (dedupe by id).
    - Programs rows → group by `program_id`; build `Program(isPredefined: false)` with `Workout`s and
      `Exercise`s; call `ProgramDatabase.shared.addProgram(_:)` if id absent, else `updateProgram(_:)`.
    - Custom-workout rows → group by `custom_workout_id`; each row is one exercise. Attach to the plan
      identified by `plan_id`; if the plan id is unknown locally, skip the group (count into `skipped`)
      — do NOT fabricate a plan.
    - Custom-exercise rows → build `ExerciseEntry(isCustom: true)`; `ExerciseDatabase.shared.add(_:)`
      if id absent else `update(_:)`.
    - Measurement rows → build `Measurement`; append to `appState.measurements` if id absent.
  - **ID handling:** if a CSV `*_id` field is blank or not a valid UUID, generate a fresh `UUID()` so
    the row is imported as new (never crash on bad ids).
  - Use the store CRUD methods (`addProgram`, `add`, etc.) rather than mutating internal arrays, so
    write-through sync + persistence run automatically for signed-in users, and local persistence runs
    for guests.

### `AuraFitnessTests/CSVRoundTripTests.swift`
- **Purpose:** Prove round-trip: build CSV from a fixture, parse it back, assert equality on the
  columns that CSV is responsible for (per section (2) fidelity limit). Mirror the existing
  `AuraFitnessTests/PersistenceRoundTripTests.swift` style.
- Cover at minimum: measurements (with nil vs 0 distinction), one custom exercise, one custom program
  with one workout/two exercises, one workout-history log with 2 exercises × 2 sets, and CSV escaping
  of a name containing a comma and a quote.

---

## 🗄️ DATA MODEL / SCHEMA

### Guest-mode local flag
- **Key:** `aura_guest_mode_v1` (UserDefaults, `Bool`).
- **Semantics:** `true` ⇔ user chose "Skip for now" and has not since signed in. Set by
  `continueAsGuest()`, cleared by successful sign-in and by `signOut()`.
- **Precedence on launch (`restoreSession`):** real Keychain session > guest flag > signed-out.
- **NOTE for the Coder:** add `aura_guest_mode_v1` to `DataResetService.resetAll` full-reset key
  removal list (the `!workoutOnly` block, alongside `aura_sync_queue_v1` / `aura_local_ts_v1`), so
  "Reset everything" also drops guest status. Do NOT remove it in the workout-only branch.

### CSV schemas (literal — column names, types, one example row each)

Conventions: types are logical (all serialized as CSV text). `UUID` = 36-char lowercased UUID string.
`ISO8601` = `2026-07-19T14:32:05Z`. Empty cell = nil/absent. Booleans = `true`/`false`.

#### 1. `workout_history.csv` (historical workout data — ROW PER SET)
Columns:
`workout_log_id (UUID), log_date (ISO8601), workout_name (String), duration_seconds (Int), session_notes (String), exercise_name (String), primary_muscle (String), equipment (String), set_index (Int), set_type (String: normal|drop|restPause|failure|partials), weight (Double?), reps (Int?), done (Bool), set_note (String)`

Example row:
```
3f1a2b7c-0e11-4a5b-9c33-2d4e6f8a1b22,2026-07-15T18:20:00Z,Push Day A,3480,Felt strong,Barbell Bench Press,Chest,Barbell,0,normal,80.0,8,true,
```

#### 2. `programs.csv` (custom programs — ROW PER EXERCISE within a workout within a program)
Only programs with `isPredefined == false` are exported.
Columns:
`program_id (UUID), program_name (String), days_per_week (Int), level (String), style (String), program_description (String), workout_id (UUID), workout_name (String), workout_order (Int), estimated_minutes (Int), rest_between_sets (Int), rest_between_exercises (Int), exercise_id (UUID), exercise_name (String), primary_muscle (String), equipment (String), rep_range (String), planned_sets (Int), exercise_order (Int)`

Example row:
```
a11b0000-1111-2222-3333-444455556666,My PPL,6,Intermediate,Hypertrophy,Custom split,b22c0000-1111-2222-3333-444455556666,Push A,0,58,60,90,c33d0000-1111-2222-3333-444455556666,Barbell Bench Press,Chest,Barbell,6–8,4,0
```

#### 3. `custom_workouts.csv` (custom workouts living inside UserPlan.customWorkouts — ROW PER EXERCISE)
Columns:
`plan_id (UUID), plan_name (String), custom_workout_id (UUID), workout_name (String), estimated_minutes (Int), rest_between_sets (Int), rest_between_exercises (Int), exercise_id (UUID), exercise_name (String), primary_muscle (String), equipment (String), rep_range (String), planned_sets (Int), exercise_order (Int)`

Example row:
```
d44e0000-aaaa-bbbb-cccc-000011112222,My Plan,e55f0000-aaaa-bbbb-cccc-000011112222,Leg Burner,55,60,90,f66a0000-aaaa-bbbb-cccc-000011112222,Barbell Squat,Legs,Barbell,6–8,4,0
```

#### 4. `custom_exercises.csv` (user-created exercises — ROW PER EXERCISE, `isCustom == true` only)
`musclesTargeted` and `proTips` are `[String]`: serialize as `|`-joined single cell.
Columns:
`exercise_id (UUID), name (String), category (String), equipment (String), muscles_targeted (String, pipe-joined), type (String), difficulty (String), rep_range (String), youtube_url (String), image_url (String), pro_tips (String, pipe-joined), is_cable (Bool), pulley (String: single|double), planned_sets (Int), notes (String), is_favorite (Bool)`

Example row:
```
0a1b2c3d-4e5f-6071-8293-a4b5c6d7e8f9,My Cable Row,Back,Cable,Latissimus Dorsi|Biceps Brachii,Machine,Intermediate,10–12,,,Keep chest up|Squeeze at the back,true,double,3,From my coach,false
```

#### 5. `body_measurements.csv` (historical body measurements — ROW PER MEASUREMENT)
Columns:
`measurement_id (UUID), date (ISO8601), weight (Double?), body_fat_pct (Double?), neck (Double?), chest (Double?), waist (Double?), hips (Double?), arms (Double?), thighs (Double?), shoulders (Double?)`

Example row:
```
9f8e7d6c-5b4a-3210-fedc-ba9876543210,2026-07-01T08:00:00Z,78.4,14.2,38.0,104.0,82.0,,40.5,60.0,
```

**Unit note:** weights/lengths are stored raw in the user's current units (kg/cm or lb/in per
`RemotePrefs.weightUnit`/`lengthUnit`). CSV does NOT convert units. Add a code comment stating that
importing under a different unit preference will not auto-convert (matches JSON archive behavior).

---

## 🔀 MERGE / UPLOAD STRATEGY (guest → sign-in)

**Chosen strategy (explicit, simple, reuses existing engine — no new merge code):**

1. When a guest signs in, `AuthService.transitionToSignedIn` runs (already wired) and calls
   `SupabaseSyncService.shared.onSignedIn(userID:)`.
2. `onSignedIn` already does exactly what's needed:
   - `isRemoteEmpty(uid)` && `hasAnyLocalData()` → **`backfillLocalToRemote(uid)`**: pushes ALL local
     guest rows up (programs, plans, exercises, workoutLogs, measurements, PRs, photos, dayOverrides,
     quickLogs, bodyStats, userProfile, preferences). This is the fresh-account guest→cloud migration.
   - Otherwise → **`pullAll()`**: LWW reconcile by `updated_at`. Guest local rows have distinct UUIDs
     from any pre-existing cloud rows, so the union-merge `applyRemote*` helpers keep BOTH. Any local
     row with a newer `aura_local_ts_v1` stamp is re-pushed; remote-newer rows are applied locally.
3. **Conflict handling (existing-account case):** same-id collisions are resolved by LWW
   (`updated_at` vs `aura_local_ts_v1`) — no user-facing prompt. Because guest data is created offline
   with fresh UUIDs, real collisions are effectively impossible; the practical result is a UNION of
   guest data and account data. This is the intended, simplest correct behavior.
4. **The only NEW requirement for guest→cloud correctness:** guest mutations must be stamped so LWW
   treats them as "recent local edits" rather than losing to older remote rows.
   - **Verified gap:** `SupabaseSyncService.push()` calls `stampLocalChange(...)` but early-returns
     BEFORE stamping when `userID == nil` (guest). So guest edits are never timestamped.
   - **REQUIRED CHANGE in `AuraFitness/Sync/SupabaseSyncService.swift`:** in `push(_:id:table:)`, move
     `stampLocalChange(table:id:)` to run **before** the `guard let uid = userID else { return }` so
     that guest-mode edits ARE timestamped locally even though no network push occurs. This guarantees
     that on later sign-in, `pullAll`'s reconcile sees guest rows as newer-than-remote (their stamp
     time > any older remote `updated_at`) and pushes them up instead of overwriting them.
     (This is the single load-bearing fix; without it, a guest who signs into a pre-existing account
     could have guest edits silently lost to older cloud rows.)

No new "migration" class is needed. Do not write one.

---

## 📱 MOBILE-SPECIFIC CONCERNS (must be handled)

- **Offline guest sign-in:** if the network is down when a guest taps Sign In, `AuthService.signIn`
  already surfaces "No network connection." and stays on `.signedOut`. The guest flag must NOT be
  cleared on a FAILED sign-in (only on success) — otherwise a failed attempt would strand the user on
  the login screen with no way back to their guest data. Verify the flag clear is inside the success
  branch only.
- **Offline after successful sign-in:** `backfillLocalToRemote`/`pullAll` push through the existing
  durable offline queue (`aura_sync_queue_v1`); failures enqueue and flush later. No special handling
  needed — but do NOT block the UI on migration; `onSignedIn` is already `async` and fire-and-forget
  from the gate's perspective.
- **Large export files (photo-heavy):** CSV export EXCLUDES progress-photo binary blobs entirely
  (photos are not one of the 5 CSV categories), so CSV stays small. The JSON archive keeps photos
  (already noted as a size concern in `DataArchive.swift`). Build both off the main thread via
  `Task.detached` exactly like `DataArchiveBuilder`. Never encode on the main thread.
- **iOS share sheet (export):** reuse `ShareLink(item: URL)` exactly as the existing export sheet does.
  The CSV zip and JSON file are both temp-directory URLs.
- **iOS file picker (import):** use SwiftUI `.fileImporter(isPresented:allowedContentTypes:onCompletion:)`
  with `allowedContentTypes: [.json, .commaSeparatedText, .zip]` (import `UniformTypeIdentifiers`).
  `allowsMultipleSelection: false`.
- **Security-scoped URLs:** MANDATORY `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()` around every read of a picked file (see DataImportService).
- **Malformed import file:** `CSVParser.parse` throws on bad quoting; `DataImportService.importFile`
  must catch and return a friendly summary string ("Couldn't read that file") rather than crash.
- **Import responsiveness:** parse + map on a background `Task`, then apply store mutations on
  `@MainActor` (the stores are `@MainActor`). Show the "Preparing…"/busy state on the button, mirroring
  the export sheet's `busy` flag.
- **Guest + reset interaction:** confirm `aura_guest_mode_v1` is cleared on full reset (see DATA MODEL
  note) so a post-reset relaunch shows the login screen, not a silent guest session.

---

## ✅ ACCEPTANCE CRITERIA (Coder self-check)

1. Fresh install → login screen shows a "Skip for now — use as guest" option; tapping it enters the
   app; force-quit + relaunch returns to the app in guest mode (not the login screen).
2. Guest creates a custom program, logs a workout, adds a measurement → all persist locally and survive
   relaunch with no network.
3. Guest signs into a brand-new account → all guest data appears in Supabase (backfill path).
4. Guest signs into an existing account that already has cloud data → both datasets are present after
   sync (union), nothing lost.
5. Export as CSV produces a zip with exactly the 5 named files, each with the exact header row above.
6. Importing that same zip on a fresh install reproduces the workouts/programs/custom-workouts/custom-
   exercises/measurements (per the section-(2) fidelity limit); re-importing is idempotent (dedupe by id).
7. Existing JSON archive export/import path is unchanged and still works.
8. `CSVRoundTripTests` pass.
