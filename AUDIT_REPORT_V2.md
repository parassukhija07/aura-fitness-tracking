# Aura Fitness Tracker — Audit Report v2 (Fix Verification)

Date: 2026-07-18 · Verified by: full source read of all 77 Swift files on branch `fix/c1-merge-corruption` (HEAD `58c8ebd`), plus CI log analysis of run #20.

This document re-verifies every finding from `AUDIT_REPORT.md` (2026-07-17) against the current code, adds newly discovered issues (N-series), and records what remains.

**Legend**
- ✅ FIXED — verified in code, nothing left to do
- 🟡 PARTIAL — code fix in place but something remains (see "Further fixes needed")
- ❌ OPEN — not fixed
- 🔧 MANUAL — code done; requires a manual step by you (see `MANUAL_STEPS.md`)

---

## Critical

| ID | Problem | Fix explained (what was needed) | Fix applied (what the code now does) | Status | Further fixes needed | Fix together with |
|----|---------|--------------------------------|--------------------------------------|--------|----------------------|-------------------|
| C1 | Merge-conflict corruption: duplicate members in `AppState`/`LogTabView`, two incompatible `DayOverride` types — app could not compile | Redo the merge: keep the `LogDayModel.DayOverride` + `dayInfo(for:)` engine, delete legacy duplicates | `AppState.swift` has single clean implementations; `LogTabView.swift` has one `body`; exactly one `DayOverride` lives in `Models/LogDayModel.swift`; all call sites use the `kind:`/`workoutId:` API | ✅ FIXED | None | — |
| C2 | Starting any workout launched the hardcoded "Push Day A" demo | Build session from the actual selected `Workout`; demo behind DEBUG | `AppState.startWorkout` calls `buildSession(from:)` which seeds `plannedSets` empty sets and enriches PR/history/target from real user data; `pushDayA()` only exists inside `#if DEBUG` via `debugStartPushDayDemo()` | ✅ FIXED | None | — |
| C3 | No persistence for user data (logs, measurements, PRs, prefs all lost on relaunch) | Persist all AppState collections and load in `init` | Every `@Published` collection has a `didSet` → `persistCodable` writer with matching `aura_*_v1` UserDefaults key, all loaded in `AppState.init`; `isLoading` guard prevents write-during-load | ✅ FIXED | Long-term: `progressPhotos` stores JPEG blobs in UserDefaults (size pressure — TODO already noted in code). Consider file storage later | — |
| C4 | Dual sources of truth: Log tab read immutable `SeedData.programs`, not the editable databases | Route all Log reads through `ProgramDatabase.shared` / `UserPlanDatabase.shared` | `dayInfo(for:)`, `todayWorkout()`, `LogSheetsView.programWorkouts` all resolve via `ProgramDatabase.shared`; `AppState.userPlans` is a forwarding computed property over `UserPlanDatabase.shared`; both DBs' `objectWillChange` are bridged into AppState | ✅ FIXED | The *Plan tab* half of this problem still exists — see **N2** | N2 |

---

## High

| ID | Problem | Fix explained | Fix applied | Status | Further fixes needed | Fix together with |
|----|---------|---------------|-------------|--------|----------------------|-------------------|
| H1 | Completed workout never linked to day state; past days defaulted to "done" | Derive past-day state from real logs; stamp `.logged` on save | `saveWorkout` stamps a `.logged` `DayOverride` (idempotent — won't clobber a quick-log's workoutId); `dayInfo` derives past planned days from `hasLog(for:)` → `.done` or `.missed`; `seededMissed` demo mechanism deleted | ✅ FIXED | None | — |
| H2 | Elapsed + rest timers froze when the app backgrounded | Wall-clock based timing; refresh on foreground; local notification for rest end | Elapsed = `baseElapsed + Date().timeIntervalSince(runStart)` (persisted); rest countdown derived from `restEndDate`; `refreshOnForeground()` called on `scenePhase == .active`; `NotificationScheduler` schedules the rest-complete notification at rest-start | ✅ FIXED | None | — |
| H3 | `createPlan(from:)` scheduled from Tuesday and never saved the plan | Correct start day; insert + persist inside the call | Renamed to `@discardableResult addPlan(from:program:startDay:)`, defaults `startDay: 1` (Mon), callers pass `appState.calendarStartDay`; inserts, sets default if first, persists, sync-pushes | ✅ FIXED | None | — |
| H4 | PR/target/history/warm-ups existed only in demo seed | Compute from `personalRecords`/`workoutLogs` at session build time; synthesize warm-ups for exercises 1–2 | `buildSession(from:)` enriches `lastPR` (from PR log), `history` (most recent matching `WorkoutLog`), derives `target`, and `synthesizedWarmup(forExerciseIndex:)` gives a 4-set ladder to exercise 0, 2-set to exercise 1, none after | ✅ FIXED | None | — |
| H5 | `addRestTime` broke progress ring; superset limited to one pair; wrong index flagged | Bump `restTotal` too; shared pair UUID; recompute source index after move | `addRestTime` bumps `restLeft`, `restTotal`, and `restEndDate`; supersets use `supersetGroupID: UUID?` (multiple pairs possible); `createSuperset` dissolves prior groups and recomputes the leader index when `targetIndex < sourceIndex` | ✅ FIXED | None | — |
| H6 | Two parallel Log sheet implementations (`LogSheets.swift` + `LogSheetsView.swift`) | Delete the stale file | `LogSheets.swift` deleted; only `LogSheetsView.swift` exists and is the one referenced | ✅ FIXED | The same *pattern* still exists in the Plan tab — see **N2** | N2 |
| H7 | Unit settings cosmetic — all displays hardcoded kg/cm | Central converter; store metric canonically | `UnitFormatter` (canonical kg/cm, converts display + parses input) used across SetRow, Superset, celebrations, Measurements, Nutrition, PRs, Stats, summaries, Profile | ✅ FIXED | None (was failing CI only because the file wasn't in the Xcode target — fixed in N1) | N1 |
| H8 | Export/reset/delete/logout were stubs; no auth existed | Real auth + export + reset + account deletion | Full Supabase email auth (`AuthService`, `AuthGateView`, session restore); `DataArchiveBuilder` exports a real JSON archive via ShareLink; `DataResetService.resetAll(workoutOnly:alsoRemote:)` wipes exact key set + singletons + remote tables; Delete Account invokes the `delete-account` Edge Function first, wipes local only on success | 🔧 MANUAL | Requires your Supabase project setup + `Secrets.xcconfig` + schema migration + Edge Function deploy — see `MANUAL_STEPS.md` steps 1–4 | — |

---

## Medium

| ID | Problem | Fix explained | Fix applied | Status | Further fixes needed | Fix together with |
|----|---------|---------------|-------------|--------|----------------------|-------------------|
| M1 | `.added` past days forced `.done`; edit-override on unresolvable workout silently dropped data | Derive from logs; synthesize placeholder workout | Past `.added` days now go through `hasLog` (else `.missed`); when `editedExercises` exists but workout lookup fails, `dayInfo` synthesizes a "Custom Workout" placeholder | ✅ FIXED | None | — |
| M2 | PR update deleted history; e1RM-only comparison | Append-only PR log; dual-criterion comparison | `personalRecords` is append-only; a set counts as PR if it beats best e1RM **or** raw weight; "current best" derived at read time (`bestPR`, `PersonalRecordsView` grouping) | ✅ FIXED | None | — |
| M3 | Rest timer skipped only on positional last set | Check completion state, not index | `onSetCompleted` checks `ex.sets.contains { !$0.done }` — rest fires only if any set is still incomplete | ✅ FIXED | None | — |
| M4 | Auto-rest setting disabled manual/between-exercise rest too | Gate only automatic call sites | `startRest(duration:automatic:)` — the `autoRestTimer` guard applies only when `automatic: true`; between-exercise and superset-complete rests pass `automatic: false` | ✅ FIXED | None | — |
| M5 | Weight-trend graphs were gray placeholders | Wire real charts to `measurements` | `AuraLineChart` (custom Path chart) renders real sorted measurement data in both `MeasurementsView` and `NutritionView`, with an empty-state fallback | ✅ FIXED | None | — |
| M6 | "How to measure" helper missing | Add help content | `MeasurementsView` has a `?` button opening a "How to Measure" sheet with 6 measurement guides | ✅ FIXED | None | — |
| M7 | Body↔Profile age/sex not synced | Bidirectional sync | `syncBodyAndProfile()` (birthday/gender → age/sex) and `syncProfileFromBodyStats()` (age/sex → approx birthday/gender), wired to `onChange` in `AccountDetailsView` and Nutrition's edit sheet | ✅ FIXED | None | — |
| M8 | Missing Log features: duration edit, future-day view, library-workout resolution | Add each | Quick-log form has an editable duration (min) field (`QuickLog.durationMinutes` with backward-compatible decoder); `viewWorkout` sheet gives a real read-only future-day preview; build-from-library writes `editedExercises` overrides that `dayInfo`'s placeholder synthesis resolves | ✅ FIXED | None | — |
| M9 | In-workout edits never offered "today vs permanent" choice | Wire save-scope prompt | `WorkoutSessionState.pendingScopePrompt` set on add/remove/substitute; alert in `WorkoutOverviewView`; "Save Permanently" writes back via `AppState.savePermanently` into the owning Program/UserPlan | ✅ FIXED | None | — |
| M10 | Notifications settings inert | Real UNUserNotificationCenter integration | `NotificationScheduler` requests authorization (on toggle enable) and schedules/cancels the rest-complete notification; gated by the Profile toggle | ✅ FIXED | Custom sounds ("Ding"/"Alarm clock") both map to `.default` — needs sound assets or Critical Alerts entitlement later (deliberate, documented in code) | — |
| M11 | Connected apps were fake toggles (`appleHealthConnected` defaulted true) | Real HealthKit, honest default | `HealthKitService` does real `HKHealthStore` authorization; `appleHealthConnected` defaults `false` and only flips on a real grant; Google Health UI removed | 🔧 MANUAL | You must add the HealthKit capability in Xcode (runtime-only requirement, doesn't block CI) — see `MANUAL_STEPS.md` step 5 | — |
| M12 | Exercise Library: activation % authenticity, image caching, inline YouTube | Verify/implement | Activation data is curated static content (per-exercise + per-muscle defaults) — acceptable for v1 per the original audit. YouTube URLs are stored but there is **no tap-to-play wiring anywhere** (zero `openURL` calls); no image caching layer | 🟡 PARTIAL | (a) wire play buttons to open `youtubeURL`; (b) add `AsyncImage`/caching if remote images get used; both small standalone tasks | N4 (library data) |

---

## Low

| ID | Problem | Fix applied | Status | Further fixes needed |
|----|---------|-------------|--------|----------------------|
| L1 | `iso()` could emit wrong dates on non-Gregorian device calendars | `AppState.iso` pins `Calendar(identifier: .gregorian)` | ✅ FIXED | None |
| L2 | "Log a Past Workout" hardcoded yesterday instead of selected day | Non-today days pass `info.iso`; the yesterday default remains only on *today's* shortcut (sensible, and the sheet lets you pick any date) | ✅ FIXED | None |
| L3 | Rest pill default position off-screen on small devices | `RestPillView` clamps x/y against live `GeometryReader` bounds on render and drag | ✅ FIXED | None |
| L4 | `exerciseRows` ForEach used `id: \.offset` | Now `id: \.element.id` | ✅ FIXED | None |
| L5 | `deleteProgram` silently no-ops on predefined programs | Returns `Bool` now, but the only caller discards it; no toast | 🟡 PARTIAL | Surface a toast at call sites. Low priority: the calling view (`ProgramEditorView`) is currently not even in the build target (see N2) — fix together with N2 |
| L6 | Workout restore matched by index+name; broke after substitution | `WorkoutPersistence.restore` matches by stable exercise `id` with name-at-index fallback for old blobs | ✅ FIXED | None |
| L7 | My Plans 3-plan cap unenforced | `UserPlanDatabase.maxPlans = 3` enforced in `addPlan` (returns `false` at cap) | ✅ FIXED | None |
| L8 | Duplicate "S"/"T" day labels with `id: \.self`; Monday-start reorder | Week bar reorders correctly for Mon-start. Duplicate-label `ForEach(id: \.self)` still present in `ConsistencyHeatmapView` day header and `LogSheetsView` calendar header | 🟡 PARTIAL | Use `Array(enumerated())` with `id: \.offset` for the two static day-label rows. Cosmetic — rows are static so no runtime misbehavior today |
| L9 | Demo code shipping (`seedElapsed`, `seededMissed`) | Both DEBUG-gated or deleted (`seededMissed` fully removed, keys documented as orphaned) | ✅ FIXED | None |

---

## New findings (this verification pass)

| ID | Level | Problem | Fix applied / needed | Status | Fix together with |
|----|-------|---------|----------------------|--------|-------------------|
| N1 | CRITICAL | **CI build failed** (run #20, all 36 errors): 13 Swift files existed on disk but were never registered in `project.pbxproj` — `ProgramDatabase.swift`, `ExerciseDatabase.swift`, `UnitFormatter.swift`, `WeeklyVolumeView.swift` plus the 9 legacy Plan views. Every "cannot find X in scope" error traced to these | The 4 files required by compiled code were added to the target (commit `58c8ebd`: PBXBuildFile + PBXFileReference + group + Sources phase, fresh non-colliding UUIDs). The 9 legacy Plan views were **deliberately left out**: `WorkoutEditorView.swift` references `SaveEditScopeSheet`, which is not defined anywhere in the repo — adding them would break the build again | ✅ FIXED (monitor new CI run) | N2 decides the 9 orphans' fate |
| N2 | HIGH | **Plan tab is a non-functional prototype mirror.** `PlanTabView` renders hardcoded mock data (`PlanData` — fake workouts/programs/schedule in local `@State`). Edits there touch nothing real. Meanwhile a complete, database-backed Plan layer exists on disk (`MyPlansView`, `ProgramLibraryView`, `ProgramDetailView`, `ProgramEditorView`, `WorkoutLibraryView`, `WorkoutEditorView`, `ExerciseLibraryTabView`, `ExerciseEntryDetailView`, `CreateExerciseView`) but is orphaned — not in the build target and not routed from any UI | Decide + implement: either (a) route the real DB-backed views into `PlanTabView`'s four subtabs, define the missing `SaveEditScopeSheet`, and add the 9 files to the Xcode target; or (b) rewire the v9-mirror UI to read/write `ProgramDatabase`/`UserPlanDatabase`/`ExerciseDatabase` and delete the orphans. Until then, users can only manage plans indirectly (Log tab's switch/pick flows work correctly against real data) | ❌ OPEN | C4, H6, L5 — same "duplicate layer" root cause; one coherent refactor |
| N3 | MEDIUM | `StatsView` Strength Score (266), Strength Balance (75%), per-muscle scores, and the Exercise Trends card ("62.0 kg", "+1.2 kg", chart placeholder) are **hardcoded numbers**, not derived from user data | Derive from `personalRecords`/`workoutLogs` (e1RM by muscle group vs. bodyweight-relative standards), or hide the cards until real data backs them | ❌ OPEN | Standalone |
| N4 | LOW | `gym_exercise_library.json` (full exercise library, repo root) is **not bundled** — the Xcode Resources phase is empty, so `ExerciseDatabase` silently falls back to its 11 hardcoded exercises | Add the JSON to the app target via Xcode (safest; see `MANUAL_STEPS.md` step 6) | 🔧 MANUAL | M12 |
| N5 | INFO | `Package.resolved` is not committed — CI re-resolves all SPM package versions every run. This already caused one breakage (`xctest-dynamic-overlay` resolving to a version needing a newer compiler) | Commit `Package.resolved` after a successful local resolve for reproducible CI builds | 🔧 MANUAL (optional) | — |

---

## CI / GitHub Actions status

| Item | Status |
|------|--------|
| Workflow config (`.github/workflows/ci.yml`) | ✅ macos-15 + Xcode 16.1 pinned, unsigned Release build, .ipa artifact upload — configuration is sound |
| pbxproj UUID collision (LogDayModel/ResumeBanner) | ✅ Fixed in earlier commit `ea674d6`, re-verified: no duplicate IDs anywhere |
| Run #20 (`a767d16`) | ❌ Failed — 36 compile errors, all caused by N1 |
| Fix for N1 | ✅ Pushed as `58c8ebd`; new CI run triggered on push |
| Residual risk | Two of the 36 errors were "compiler unable to type-check in reasonable time" (`AppState.swift`, `LogSheetsView.swift`). These are expected to disappear once the missing types resolve (type-checker falls back to expensive search paths when symbols are missing). If the new run still hits them, the fix is to split the flagged expressions into sub-expressions |

---

## Recommended fix order for what remains

1. **Confirm CI green** on `58c8ebd` (N1 verification — nothing to do if green).
2. **N2 cluster** (with C4/H6/L5 context): unify the Plan tab onto the real databases. Biggest remaining functional gap.
3. **N3**: real stats or hide placeholder cards (App Store credibility).
4. **M12 + N4**: bundle the JSON library, wire YouTube playback.
5. **L8**: ForEach id cleanup (5-minute cosmetic fix).
6. **Manual steps** (`MANUAL_STEPS.md`): Supabase setup is required before auth/sync works at runtime at all.
