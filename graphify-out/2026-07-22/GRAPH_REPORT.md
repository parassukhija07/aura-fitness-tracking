# Graph Report - Aura Fitness Tracker  (2026-07-22)

## Corpus Check
- 183 files · ~765,162 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2329 nodes · 5428 edges · 132 communities (125 shown, 7 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 383 edges (avg confidence: 0.75)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `30b98720`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Exercise
- .secondary
- WorkoutEditorView
- support.js
- app.jsx
- AuraTab
- Foundation
- UnitFormatter
- .persist
- MyPlansView
- WorkoutSessionState
- LogSheetsView
- String
- AppState
- PlanComponents.swift
- View
- ExerciseDatabase
- ProfileSheet
- PlanDay
- ProgramEditorView
- Workout
- store.jsx
- AuraComponents.swift
- PlanWorkoutEditorView
- .jakarta
- ToastCenter
- .row
- DataImportService
- .scheduleRestComplete
- Color
- .parse
- .importJSONArchive
- SwiftUI
- SupersetView
- QuickLogExercise
- LogSheet
- UserPlanDatabase
- Table
- PlanLibExercise
- PlanEditorExercise
- WorkoutModal
- ExerciseEntryDetailView
- WorkoutExerciseOption
- ToastCenter
- AuraTab
- PlanExerciseDetail
- PlanProgramsBody
- tweaks-panel.jsx
- ui.jsx
- .editableLogCard
- AuthService
- .programRow
- UUID
- AuraColors.swift
- HealthKitService
- PersistenceRoundTripTests
- IMPLEMENTATION SPEC
- WorkoutEditorComponents.swift
- AuraFitnessApp
- AuraScreenScroll
- Program
- Aura Fitness — Manual Steps Required
- DayState
- BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage
- BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change
- BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only)
- BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure
- IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker
- IMPLEMENTATION SPEC: YouTube Tap-to-Play + Remote Exercise Images
- .cell
- NutritionView
- AuraFitnessApp
- CI Build Failure — Root Cause & Fix
- BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection
- IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign
- IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar
- IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming
- IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity
- IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity
- IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources
- IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast
- Aura Fitness Tracker — Audit Report v2 (Fix Verification)
- AuraSheetModifier
- IMPLEMENTATION SPEC
- BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC
- BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit
- BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only
- IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity
- IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate
- IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity
- IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets
- SessionState
- Foundation
- .exerciseCell
- CodingKeys
- BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup
- IMPLEMENTATION SUMMARY
- IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes
- IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity
- Aura Fitness — Developer Handover
- CSVRoundTripTests.swift
- AuraToggleStyle
- Aura Fitness — Remaining Build: Phase Index
- TEST EXECUTION REPORT
- PlanBodyMap
- WeekStripView
- SessionState
- PlanSheet
- IMPLEMENTATION SUMMARY
- FINAL ARCHITECTURE REVIEW
- TEST EXECUTION REPORT
- FINAL ARCHITECTURE REVIEW
- ResumeBanner
- data.jsx
- DataArchive
- .programCard
- icons.js
- 00-INDEX.md
- push_changes.sh
- index.ts
- ResumeBanner
- get_first_yt_link
- .weekStrip
- .programRow

## God Nodes (most connected - your core abstractions)
1. `AppState` - 145 edges
2. `Exercise` - 71 edges
3. `SwiftUI` - 68 edges
4. `WorkoutSessionState` - 66 edges
5. `Color` - 65 edges
6. `Workout` - 64 edges
7. `LogSheetsView` - 51 edges
8. `SupabaseSyncService` - 47 edges
9. `MuscleRegion` - 32 edges
10. `ProgressPhotoStorage` - 32 edges

## Surprising Connections (you probably didn't know these)
- `AuthFormView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `ForgotPasswordSheet` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `SetNewPasswordSheet` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `AwaitingConfirmationView` --calls--> `ToastCenter`  [INFERRED]
  AuraFitness/Auth/AuthGateView.swift → AuraFitness/DesignSystem/AuraComponents.swift
- `AuraShadowToken` --calls--> `Color`  [INFERRED]
  AuraFitness/DesignSystem/AuraSpacing.swift → AuraFitness/DesignSystem/AuraColors.swift

## Import Cycles
- None detected.

## Communities (132 total, 7 thin omitted)

### Community 0 - "Exercise"
Cohesion: 0.09
Nodes (23): CatalogMetaRow, CatalogRow, ExerciseDatabase, ExerciseEntry, ExerciseWarmupProtocol, FailableDecodable, GymExerciseJSON, Bool (+15 more)

### Community 1 - ".secondary"
Cohesion: 0.18
Nodes (13): CSVArchiveBuilder, Bool, Date, Double, ExerciseEntry, Int, ISO8601DateFormatter, Measurement (+5 more)

### Community 2 - "WorkoutEditorView"
Cohesion: 0.05
Nodes (39): EditorExercisePicker, EditorPickerMode, addAfter, substitute, supersetNew, Bool, ExerciseEntry, String (+31 more)

### Community 3 - "support.js"
Cohesion: 0.08
Nodes (42): boot(), collectProps(), compileAttr(), compileTemplate(), createComponentFactory(), createExternalModules(), createHelmetManager(), createPseudoSheet() (+34 more)

### Community 4 - "app.jsx"
Cohesion: 0.07
Nodes (45): AddPlanSheet(), App(), AssignSheet(), DayMenuSheet(), ExercisePicker(), ExercisesView(), MyPlansView(), ProgramDetailView() (+37 more)

### Community 5 - "AuraTab"
Cohesion: 0.05
Nodes (40): ContentView, AuraQuickAction, logMeasurement, progressPhoto, startWorkout, AuraTab, log, plan (+32 more)

### Community 6 - "Foundation"
Cohesion: 0.28
Nodes (7): Date, Double, Int, String, WorkoutLog, WeeklyVolumeView, WeekPoint

### Community 7 - "UnitFormatter"
Cohesion: 0.07
Nodes (27): ArraySlice, Double, String, UnitFormatter, MeasurementsView, Date, Double, Int (+19 more)

### Community 8 - ".persist"
Cohesion: 0.08
Nodes (17): programs, ProgramDatabase, SeedIDMigration, SeedPurgeMigration, Bool, Double, IndexSet, Int (+9 more)

### Community 9 - "MyPlansView"
Cohesion: 0.09
Nodes (33): AnyView, PlanCatalogGrid, PlanEmptyState, PlanFilterChip, PlanIconButton, PlanLibraryCard, PlanList, PlanNavbar (+25 more)

### Community 10 - "WorkoutSessionState"
Cohesion: 0.08
Nodes (21): String, AuraFont, Face, SectionLabelStyle, CGFloat, Content, Font, String (+13 more)

### Community 11 - "LogSheetsView"
Cohesion: 0.12
Nodes (15): AuraPrimaryButton, LogSheetsView, Binding, Bool, Date, ExerciseEntry, Int, Program (+7 more)

### Community 12 - "String"
Cohesion: 0.20
Nodes (19): ActiveWorkoutSeed, ExerciseLibrary, Bool, Exercise, Program, PRRecord, SetHistory, Bool (+11 more)

### Community 13 - "AppState"
Cohesion: 0.06
Nodes (15): App, AuraFitnessApp, AppState, Measurement, PersonalRecord, ProgressPhoto, Set, UserPlan (+7 more)

### Community 14 - "PlanComponents.swift"
Cohesion: 0.07
Nodes (41): MuscleAnatomy, MuscleEmphasis, primary, secondary, MuscleMapOrientation, back, front, MuscleRegion (+33 more)

### Community 15 - "View"
Cohesion: 0.11
Nodes (16): IntBox, Mode, create, edit, ProgramEditorView, Binding, Bool, Int (+8 more)

### Community 16 - "ExerciseDatabase"
Cohesion: 0.09
Nodes (32): AnyJSON, T, AppStateBridge, DeletionRow, OwnershipRow, PullChangesResponse, QueueAction, delete (+24 more)

### Community 17 - "ProfileSheet"
Cohesion: 0.10
Nodes (27): AvatarCircle, fmtRest(), ProfileScreen, account, connected, general, notifications, support (+19 more)

### Community 18 - "PlanDay"
Cohesion: 0.15
Nodes (14): ProgressPhotoStorage, Bool, CGFloat, Data, Error, ProgressPhoto, Set, String (+6 more)

### Community 19 - "ProgramEditorView"
Cohesion: 0.24
Nodes (17): BodyStats, MacroTargets, Measurement, NutritionConstants, PersonalRecord, ProgressPhoto, Bool, ClosedRange (+9 more)

### Community 20 - "Workout"
Cohesion: 0.25
Nodes (7): Do not put user content here, `exercise-media/` — source images for the public catalog bucket, Filename contract, Image requirements, Replacing an image (cache caveat), What a missing image does, Workflow

### Community 21 - "store.jsx"
Cohesion: 0.10
Nodes (13): addDays(), DOW, EXERCISES, freshState(), iso(), MONTHS, PROGRAMS, Store (+5 more)

### Community 22 - "AuraComponents.swift"
Cohesion: 0.08
Nodes (43): AuraColorNamespace, Color, dyn(), dynA(), CGFloat, String, UIColor, AuraAxisChart (+35 more)

### Community 23 - "PlanWorkoutEditorView"
Cohesion: 0.14
Nodes (17): ToastCenter, ConnectedAppsView, GeneralSettingsView, NotificationsSettingsView, OptionalToast, ProfileConfirmSheet, SettingsScreenScaffold, SupportView (+9 more)

### Community 24 - ".jakarta"
Cohesion: 0.12
Nodes (12): ExerciseLoggingView, Bool, Double, Int, String, AuraCard, AuraTabBar, Int (+4 more)

### Community 25 - "ToastCenter"
Cohesion: 0.11
Nodes (19): CreatePlanView, CreateWorkoutIcon, MyPlanSheet, addPlan, addWorkout, assign, createWorkout, dayMenu (+11 more)

### Community 26 - ".row"
Cohesion: 0.23
Nodes (10): DataImportService, ImportSummary, Bool, Date, Double, Int, Set, String (+2 more)

### Community 27 - "DataImportService"
Cohesion: 0.19
Nodes (13): WorkoutTheme, PlanData, PlanEditorExercise, PlanMusclePalette, PlanProgram, planWkIcon(), planWkStyle(), PlanWorkout (+5 more)

### Community 28 - ".scheduleRestComplete"
Cohesion: 0.14
Nodes (7): NotificationScheduler, Bool, Int, String, RestPillView, CGSize, GeometryProxy

### Community 29 - "Color"
Cohesion: 0.26
Nodes (8): ActiveWorkoutData, MuscleGroupOption, String, WorkoutExerciseOption, EmptyOverviewView, Bool, String, Void

### Community 30 - ".parse"
Cohesion: 0.19
Nodes (8): CSVError, malformed, CSVParser, Int, String, CSVRoundTripTests, Error, XCTestCase

### Community 31 - ".importJSONArchive"
Cohesion: 0.21
Nodes (6): AuthService, Bool, Error, String, SupabaseClient, URL

### Community 32 - "SwiftUI"
Cohesion: 0.10
Nodes (10): WorkoutSummaryView, PlanBodyMap, String, SaveEditScopeSheet, Void, SupersetPickSheet, Void, BodyView (+2 more)

### Community 33 - "SupersetView"
Cohesion: 0.21
Nodes (8): SupersetSetRow, SupersetView, Binding, Bool, Double, Int, String, Void

### Community 34 - "QuickLogExercise"
Cohesion: 0.10
Nodes (24): CodingKeys, durationMinutes, exercises, time, DayOverride, Kind, added, edited (+16 more)

### Community 35 - "LogSheet"
Cohesion: 0.25
Nodes (9): ExerciseDetailView, ExerciseEntry, ExerciseEntryDetailView, Binding, Bool, ExerciseEntry, Int, String (+1 more)

### Community 36 - "UserPlanDatabase"
Cohesion: 0.21
Nodes (10): Col, MinimalZipReader, Data, ZipError, malformed, unsupportedCompression, Compression, UInt16 (+2 more)

### Community 37 - "Table"
Cohesion: 0.33
Nodes (10): HistSession, HistSet, PBs, PlanExerciseDetail, planNum(), Double, Int, String (+2 more)

### Community 38 - "PlanLibExercise"
Cohesion: 0.21
Nodes (10): Int, String, Void, WorkoutModal, addExercise, createSuperset, removeSuperset, substitute (+2 more)

### Community 39 - "PlanEditorExercise"
Cohesion: 0.36
Nodes (5): AuraRadius, AuraShadowToken, AuraSpacing, CGFloat, View

### Community 40 - "WorkoutModal"
Cohesion: 0.14
Nodes (23): build_sql(), build_upload_script(), difficulty_for(), entry_for(), exercise_id(), main(), media_object_name(), public_image_url() (+15 more)

### Community 41 - "ExerciseEntryDetailView"
Cohesion: 0.21
Nodes (14): AddRoute, pickWorkout, targetWorkout, PlanExerciseDetailView, PlanOverviewTab, PlanWorkoutCtx, PlanWorkoutTab, Bool (+6 more)

### Community 42 - "WorkoutExerciseOption"
Cohesion: 0.33
Nodes (9): convert(), exercise_type(), main(), muscles_for(), `3/4 sit-up` -> `3/4 Sit-Up`. Capitalises across spaces, slashes,     hyphens an, Primary target first, then synergist, then secondaries — deduplicated     while, The app's `type` vocabulary is Compound / Machine / Warm Up. Upstream     has no, title_case() (+1 more)

### Community 43 - "ToastCenter"
Cohesion: 0.27
Nodes (9): ExerciseMenuSheet, ExercisePickerSheet, IndexWrapper, Bool, Double, Int, String, Void (+1 more)

### Community 44 - "AuraTab"
Cohesion: 0.07
Nodes (27): CalendarDayIcon, LogSheet, add, buildFromLibrary, calendar, edit, editLog, logPast (+19 more)

### Community 45 - "PlanExerciseDetail"
Cohesion: 0.09
Nodes (20): Coordinator, ExerciseVideoView, Bool, CGFloat, String, YouTubePlayerView, ImageMemoryCache, RemoteExerciseImage (+12 more)

### Community 46 - "PlanProgramsBody"
Cohesion: 0.15
Nodes (13): AuthFormView, AuthGateView, AwaitingConfirmationView, ForgotPasswordSheet, Mode, login, signUp, SetNewPasswordSheet (+5 more)

### Community 48 - "ui.jsx"
Cohesion: 0.21
Nodes (8): Icon(), Nav, NavBar(), Row(), Search(), Sheet(), TabBar(), useNav()

### Community 49 - ".editableLogCard"
Cohesion: 0.19
Nodes (5): CGPoint, Date, Int, WorkoutPersistence, CGPoint

### Community 50 - "AuthService"
Cohesion: 0.15
Nodes (9): CelebrationData, Bool, Date, Double, IndexSet, Int, String, WorkoutSessionState (+1 more)

### Community 51 - ".programRow"
Cohesion: 0.16
Nodes (6): AuraFitness, PersistenceRoundTripTests, String, T, UserDefaults, XCTest

### Community 52 - "UUID"
Cohesion: 0.27
Nodes (8): PickerMode, add, ssNew, sub, PlanExercisePickerView, Bool, String, Void

### Community 53 - "AuraColors.swift"
Cohesion: 0.32
Nodes (10): ExerciseHistoryTab, HistSet, Session, SessionRow, SetRow, Summary, Date, Double (+2 more)

### Community 54 - "HealthKitService"
Cohesion: 0.18
Nodes (8): HealthKitService, Bool, Date, Double, Int, HealthKit, HKObjectType, HKQuantityType

### Community 55 - "PersistenceRoundTripTests"
Cohesion: 0.20
Nodes (9): PlanDay, fri, mon, sat, sun, thu, tue, wed (+1 more)

### Community 56 - "IMPLEMENTATION SPEC"
Cohesion: 0.14
Nodes (13): 🏗️ ARCHITECTURE & PATTERNS, ASSUMPTIONS (defaults chosen — safe to proceed), `AuraFitness/Plan/PlanTabView.swift`, `AuraFitness/Plan/SaveEditScopeSheet.swift`, `AuraFitness.xcodeproj/project.pbxproj`  — register 10 files (9 orphans + `SaveEditScopeSheet.swift`), 🛡️ EDGE CASES TO HANDLE, 📄 FILES TO CREATE, 🗑️ FILES TO DELETE (+5 more)

### Community 57 - "WorkoutEditorComponents.swift"
Cohesion: 0.43
Nodes (4): PlanHistoryTab, CGFloat, Double, Font

### Community 58 - "AuraFitnessApp"
Cohesion: 0.33
Nodes (6): SetType, drop, failure, normal, partials, restPause

### Community 59 - "AuraScreenScroll"
Cohesion: 0.28
Nodes (6): AuraScreenScroll, ScrollOffsetKey, CGFloat, Content, String, PreferenceKey

### Community 60 - "Program"
Cohesion: 0.17
Nodes (11): DataArchive, DataArchiveBuilder, Date, ExerciseEntry, Measurement, PersonalRecord, Program, ProgressPhoto (+3 more)

### Community 61 - "Aura Fitness — Manual Steps Required"
Cohesion: 0.13
Nodes (14): Aura Fitness — Manual Steps Required, Quick checklist, Step 10 (optional) — Seed the global exercise catalog (≈3 min), Step 11 (optional) — Host exercise images yourself (≈5 min), Step 1 — Create the Supabase project (≈10 min), Step 2 — Apply the database schema (≈5 min), Step 3 — Wire the secrets into Xcode (≈10 min, needs your Mac), Step 4 — Deploy the delete-account Edge Function (≈5 min, needs Supabase CLI) (+6 more)

### Community 62 - "DayState"
Cohesion: 0.07
Nodes (27): DarkModePreference, auto, off, on, DayInfo, Keys, PlanSubtabTarget, workouts (+19 more)

### Community 63 - "BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ProgressModels.swift` + photo store (where `progressPhotos` persists in `AppState`), `AuraFitness/Progress/ProgressPhotosView.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Progress Photos → Supabase Storage, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS (+2 more)

### Community 64 - "BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change"
Cohesion: 0.18
Nodes (10): `AuraFitness/AuraFitnessApp.swift`, `AuraFitness/Auth/AuthGateView.swift`, `AuraFitness/Auth/AuthService.swift`, `AuraFitness/Profile/AccountDetailsView.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Auth Flows Completion — Password Reset + Email Change, 📄 FILES TO CREATE, 📝 FILES TO MODIFY (+2 more)

### Community 65 - "BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only)"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Global Exercise Catalog Table (Versioned, Read-Only), 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0007_exercise_catalog.sql` (+2 more)

### Community 66 - "BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure"
Cohesion: 0.18
Nodes (10): `AuraFitness/Models/ExerciseDatabase.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Public `exercise-media` Bucket + Seeding Procedure, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0008_exercise_media_bucket.sql`, `supabase/seed/exercise-media/README.md` (+2 more)

### Community 67 - "IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker"
Cohesion: 0.18
Nodes (10): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/EditorExercisePicker.swift`, `AuraFitness/Plan/SupersetPickSheet.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Editor — Supersets + 3-Mode Exercise Picker (+2 more)

### Community 68 - "IMPLEMENTATION SPEC: YouTube Tap-to-Play + Remote Exercise Images"
Cohesion: 0.18
Nodes (10): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/ActiveWorkout/ExerciseLoggingView.swift`, `AuraFitness/DesignSystem/RemoteExerciseImage.swift`, `AuraFitness/Plan/ExerciseDetailView.swift`, `AuraFitness/Plan/PlanSubtabViews.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY (+2 more)

### Community 69 - ".cell"
Cohesion: 0.33
Nodes (4): ProgramDetailView, Bool, Program, String

### Community 70 - "NutritionView"
Cohesion: 0.25
Nodes (9): NutritionView, Binding, Bool, ClosedRange, Date, Double, Int, String (+1 more)

### Community 71 - "AuraFitnessApp"
Cohesion: 0.38
Nodes (4): ProgramLibraryView, Bool, Program, String

### Community 72 - "CI Build Failure — Root Cause & Fix"
Cohesion: 0.20
Nodes (9): 1. `LogDayModel.swift` / `ResumeBanner.swift` shared the same UUID in `project.pbxproj`, 1. Push and re-run CI (no local action needed beyond that), 2. HealthKit capability (carried over from the earlier audit-fix session, still open), 2. Xcode 15.4's compiler can't build `xctest-dynamic-overlay` (a transitive dependency), 3. Nothing else is currently known to block CI, CI Build Failure — Root Cause & Fix, What broke it, What's committed (+1 more)

### Community 73 - "BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection"
Cohesion: 0.20
Nodes (9): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Deletion Tombstones — Stop Deleted-Row Resurrection, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0002_pull_changes_rpc.sql`, `supabase/migrations/0003_deletions_tombstones.sql` (+1 more)

### Community 74 - "IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/WorkoutEditorComponents.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Workout Editor — Design-Faithful Redesign, ⚠️ OPEN QUESTIONS (+1 more)

### Community 75 - "IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ExerciseDetailView.swift` (struct `ExerciseEntryDetailView`), `AuraFitness/Plan/PlanTabView.swift`, `AuraFitness/Plan/WorkoutEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Exercise Detail — History Tab, Workout Tab, Action Bar (+1 more)

### Community 76 - "IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/MyPlansView.swift`, `AuraFitness/Plan/PlanComponents.swift`, `AuraFitness/Plan/PlanSubtabViews.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Plan Sheets, Create-Workout Grid, Keyword Theming (+1 more)

### Community 77 - "IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/DesignSystem/AuraComponents.swift` — ADD `AuraAxisChart`, `AuraFitness/Progress/PersonalRecordsView.swift`, `AuraFitness/Progress/StatsView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Exercise Trends Labelled Chart + PR List Fidelity (+1 more)

### Community 78 - "IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/ProfileSettingsScreens.swift` (General, Notifications), `AuraFitness/Profile/ProfileTabView.swift` (root hub), `AuraFitness/Profile/WorkoutSettingsView.swift` (Workout), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Profile Hub + General/Workout/Notifications — Design Fidelity (+1 more)

### Community 79 - "IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness.xcodeproj/project.pbxproj`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, `gym_exercise_library.json` → move to `AuraFitness/Resources/gym_exercise_library.json`, IMPLEMENTATION SPEC: Bundle gym_exercise_library.json into App Resources (+1 more)

### Community 80 - "IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast"
Cohesion: 0.20
Nodes (9): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ProgramEditorView.swift` (audit L5) — and any other `deleteProgram` call site, `AuraFitness/Progress/ConsistencyHeatmapView.swift` + `AuraFitness/Log/LogSheetsView.swift` (audit L8), Dead-code candidates (verify each, then delete file + pbxproj entries), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Cleanup — Dead Mock Plan Layer, ForEach IDs, Delete Toast (+1 more)

### Community 81 - "Aura Fitness Tracker — Audit Report v2 (Fix Verification)"
Cohesion: 0.22
Nodes (8): Aura Fitness Tracker — Audit Report v2 (Fix Verification), CI / GitHub Actions status, Critical, High, Low, Medium, New findings (this verification pass), Recommended fix order for what remains

### Community 82 - "AuraSheetModifier"
Cohesion: 0.29
Nodes (7): Keys, SavedExercise, SavedWorkout, Bool, String, UUID, CoreGraphics

### Community 83 - "IMPLEMENTATION SPEC"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, 🛡️ EDGE CASES TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC, ⚠️ OPEN QUESTIONS, `path/to/existing/file.js`, `path/to/new/file.js`

### Community 84 - "BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC"
Cohesion: 0.22
Nodes (8): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Incremental Sync — `pull_changes(since)` RPC, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0002_pull_changes_rpc.sql`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 85 - "BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit"
Cohesion: 0.22
Nodes (8): `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: JSONB Payload Guardrails + Index Audit, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/migrations/0005_payload_guardrails.sql`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 86 - "BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only"
Cohesion: 0.22
Nodes (8): `AuraFitness/Models/ProgramDatabase.swift` + `AuraFitness/Models/ExerciseDatabase.swift`, `AuraFitness/Sync/SupabaseSyncService.swift`, 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: Predefined Content Sync Policy — User-Owned Rows Only, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 87 - "IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Plan/ProgramDetailView.swift`, `AuraFitness/Plan/ProgramEditorView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Program Detail + Program Editor — Design Fidelity, ⚠️ OPEN QUESTIONS

### Community 88 - "IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/ProfileSettingsScreens.swift`, `AuraFitness/Progress/StatsView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Strength Score / Balance Cards — Profile Setting Gate, ⚠️ OPEN QUESTIONS

### Community 89 - "IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/MeasurementsView.swift`, `AuraFitness/Progress/ProgressPhotosView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Body → Measurements & Photos — Design Fidelity, ⚠️ OPEN QUESTIONS

### Community 90 - "IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets"
Cohesion: 0.22
Nodes (8): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Profile/AccountDetailsView.swift`, `AuraFitness/Profile/ProfileSettingsScreens.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Profile — Account/Units/Connected/Support + Confirm Sheets, ⚠️ OPEN QUESTIONS

### Community 92 - "SessionState"
Cohesion: 0.32
Nodes (3): fail(), insert_log_row(), rls_isolation_test.sh script

### Community 93 - "Foundation"
Cohesion: 0.12
Nodes (9): AuthConfig, Bool, String, URL, SeedData, Program, DataResetService, CryptoKit (+1 more)

### Community 94 - ".exerciseCell"
Cohesion: 0.40
Nodes (5): ActiveWorkoutScreen, exercise, overview, summary, superset

### Community 95 - "CodingKeys"
Cohesion: 0.40
Nodes (3): LogMeasurementSheet, Binding, String

### Community 96 - "BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup"
Cohesion: 0.25
Nodes (7): 🛡️ BACKEND EDGE CASES & SECURITY CONSTRAINTS, BACKEND IMPLEMENTATION SPEC: delete-account Edge Function — Storage Cleanup, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, ⚠️ OPEN QUESTIONS & ARCHITECTURAL BLOCKS, `supabase/functions/delete-account/index.ts`, 🏗️ SYSTEM ARCHITECTURE & DATA CONTRACTS

### Community 97 - "IMPLEMENTATION SUMMARY"
Cohesion: 0.25
Nodes (7): ⚠️ DEVIATION FROM SPEC (coordinator-approved), IMPLEMENTATION SUMMARY, 📁 MODIFIED FILES, 🆕 NEW FILES, ✅ PBXPROJ VALIDATION CHECKLIST — ALL PASSED, 🎯 TESTER FOCUS AREAS, 🔄 WHAT CHANGED

### Community 98 - "IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes"
Cohesion: 0.25
Nodes (7): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/ConsistencyHeatmapView.swift`, 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Consistency Heatmap — 5-Level Real Outcomes, ⚠️ OPEN QUESTIONS

### Community 99 - "IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity"
Cohesion: 0.25
Nodes (7): 🏗️ ARCHITECTURE & PATTERNS, `AuraFitness/Progress/NutritionView.swift` (and the `NutritionConstants` definition file), 🛡️ EDGE CASES & CONSTRAINTS TO HANDLE, 📄 FILES TO CREATE, 📝 FILES TO MODIFY, IMPLEMENTATION SPEC: Nutrition Calculator — Exact Formulas + Layout Parity, ⚠️ OPEN QUESTIONS

### Community 101 - "Aura Fitness — Developer Handover"
Cohesion: 0.29
Nodes (6): Aura Fitness — Developer Handover, Chapters, Fidelity, How to use this, Source files (in `../`), Target stack notes

### Community 102 - "CSVRoundTripTests.swift"
Cohesion: 0.24
Nodes (7): AccountDetailsView, Binding, Bool, Date, Double, String, UIKeyboardType

### Community 103 - "AuraToggleStyle"
Cohesion: 0.50
Nodes (3): Exercise library data — `AuraFitness/Resources/gym_exercise_library.json`, The upstream images and videos are NOT imported, and must not be, Third-Party Notices

### Community 104 - "Aura Fitness — Remaining Build: Phase Index"
Cohesion: 0.29
Nodes (6): Aura Fitness — Remaining Build: Phase Index, Out of scope for specs (owner-manual steps, from `MANUAL_STEPS.md`), Phase 3 — Plan tab completion (design ch. 4, largest chapter), Phase 4 — Progress tab fidelity (design ch. 6), Phase 5 — Profile tab fidelity (design ch. 7), Phase 6 — Data & platform completion

### Community 105 - "TEST EXECUTION REPORT"
Cohesion: 0.29
Nodes (6): 🛑 BLOCKERS (If Failed), 📝 EXECUTION LOG, Notes (non-blocking, informational only), 📊 STATUS, TEST EXECUTION REPORT, 🧪 TESTS IMPLEMENTED

### Community 106 - "PlanBodyMap"
Cohesion: 0.29
Nodes (10): ExerciseEditCard, ExerciseEditMenuSheet, nearestLadderIndex(), restLabel(), RestLadderPicker, SupersetConnector, Bool, Int (+2 more)

### Community 107 - "WeekStripView"
Cohesion: 0.38
Nodes (11): ExerciseEntry, Measurement, PersonalRecord, Program, ProgressPhoto, Bool, String, Syncable (+3 more)

### Community 108 - "SessionState"
Cohesion: 0.25
Nodes (7): SessionState, awaitingEmailConfirmation, guest, loading, signedIn, signedOut, Supabase

### Community 110 - "IMPLEMENTATION SUMMARY"
Cohesion: 0.33
Nodes (5): IMPLEMENTATION SUMMARY, 📁 MODIFIED FILES, 🆕 NEW FILES, 🎯 TESTER FOCUS AREAS, 🔄 WHAT CHANGED

### Community 111 - "FINAL ARCHITECTURE REVIEW"
Cohesion: 0.33
Nodes (5): 🛠️ ACTION ITEMS (If NEEDS WORK or BLOCK), 🔍 DIFF ANALYSIS, FINAL ARCHITECTURE REVIEW, 🛡️ QUALITY & SECURITY AUDIT, ⚖️ VERDICT

### Community 112 - "TEST EXECUTION REPORT"
Cohesion: 0.33
Nodes (5): 🛑 BLOCKERS (If Failed), 📝 EXECUTION LOG, 📊 STATUS, TEST EXECUTION REPORT, 🧪 TESTS IMPLEMENTED

### Community 113 - "FINAL ARCHITECTURE REVIEW"
Cohesion: 0.33
Nodes (5): 🛠️ ACTION ITEMS, 🔍 DIFF ANALYSIS, FINAL ARCHITECTURE REVIEW, 🛡️ QUALITY & SECURITY AUDIT, ⚖️ VERDICT

### Community 114 - "ResumeBanner"
Cohesion: 0.21
Nodes (8): SetRowView, SetTypeMenuSheet, Binding, Bool, Double, Int, String, Void

### Community 115 - "data.jsx"
Cohesion: 0.40
Nodes (4): ADD_OPTIONS, SET_TYPES, SUB_OPTIONS, WORKOUT

### Community 116 - "DataArchive"
Cohesion: 0.50
Nodes (3): Binding, String, WorkoutSettingsView

### Community 126 - "index.ts"
Cohesion: 0.50
Nodes (4): corsHeaders, isBucketMissing(), purgeUserStorage(), USER_BUCKETS

### Community 133 - "get_first_yt_link"
Cohesion: 0.67
Nodes (3): get_youtube_link(), main(), Attempts to extract the first direct YouTube video URL.     Falls back to a dir

### Community 135 - ".weekStrip"
Cohesion: 0.40
Nodes (5): Int, String, Void, WeekStripDayTile, WeekStripView

### Community 138 - ".programRow"
Cohesion: 0.50
Nodes (3): ActiveWorkoutView, EndWorkoutSheet, Bool

## Knowledge Gaps
- **418 isolated node(s):** `TODAY`, `DOW`, `MONTHS`, `EXERCISES`, `WORKOUTS` (+413 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppState` connect `AppState` to `Exercise`, `.secondary`, `AuraTab`, `Foundation`, `UnitFormatter`, `.persist`, `.programRow`, `LogSheetsView`, `String`, `WorkoutSessionState`, `View`, `ExerciseDatabase`, `ProfileSheet`, `ProgramEditorView`, `PlanWorkoutEditorView`, `.jakarta`, `ToastCenter`, `.row`, `Color`, `.parse`, `SwiftUI`, `SupersetView`, `QuickLogExercise`, `LogSheet`, `ToastCenter`, `AuraTab`, `.editableLogCard`, `AuthService`, `AuraColors.swift`, `HealthKitService`, `WorkoutEditorComponents.swift`, `Program`, `DayState`, `.cell`, `NutritionView`, `AuraFitnessApp`, `CodingKeys`, `CSVRoundTripTests.swift`, `ResumeBanner`, `DataArchive`?**
  _High betweenness centrality (0.148) - this node is a cross-community bridge._
- **Why does `Workout` connect `String` to `QuickLogExercise`, `WorkoutEditorView`, `AuraTab`, `.weekStrip`, `.persist`, `MyPlansView`, `LogSheetsView`, `View`, `.editableLogCard`, `AuraSheetModifier`, `AuthService`, `ProgramEditorView`, `.jakarta`, `ToastCenter`, `.row`, `DataImportService`, `Foundation`, `DayState`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `WorkoutSessionState` connect `AuthService` to `SwiftUI`, `SupersetView`, `PlanLibExercise`, `.persist`, `.programRow`, `ToastCenter`, `String`, `PlanSheet`, `AppState`, `.editableLogCard`, `ResumeBanner`, `.jakarta`, `.scheduleRestComplete`, `Color`, `.exerciseCell`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `AppState` (e.g. with `.confirmBuildFromLibrary()` and `.loadForm()`) actually correct?**
  _`AppState` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `Exercise` (e.g. with `.importCustomWorkouts()` and `.importPrograms()`) actually correct?**
  _`Exercise` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `WorkoutSessionState` (e.g. with `.setRows()` and `.addRound()`) actually correct?**
  _`WorkoutSessionState` has 9 INFERRED edges - model-reasoned connections that need verification._
- **What connects `TODAY`, `DOW`, `MONTHS` to the rest of the system?**
  _418 weakly-connected nodes found - possible documentation gaps or missing edges._